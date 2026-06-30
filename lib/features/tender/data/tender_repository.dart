import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/domain/write_context.dart';
import '../../../core/permissions/permission_key.dart';
import '../../../core/permissions/repository_write_guard.dart';
import '../../../core/value_objects/money.dart';
import '../../../database/local_database.dart';
import '../../../database/schema/app_schema_sql.dart';
import '../domain/bidder_profile.dart';
import '../domain/tender_application.dart';
import '../domain/tender_business_service.dart';
import '../domain/tender_document.dart';
import '../domain/tender_expense.dart';
import '../domain/tender_expense_type.dart';
import '../domain/tender_module_contract.dart';
import '../domain/tender_status.dart';
import '../domain/tender_summary.dart';
import '../domain/tender_to_project_conversion.dart';

class TenderRepository implements TenderModuleContract {
  TenderRepository({
    required this.database,
    TenderBusinessService businessService = const TenderBusinessService(),
    RepositoryWriteGuard writeGuard = const AllowAllRepositoryWriteGuard(),
    Uuid uuid = const Uuid(),
  })  : _businessService = businessService,
        _writeGuard = writeGuard,
        _uuid = uuid;

  final ConstructionDatabase database;
  final TenderBusinessService _businessService;
  final RepositoryWriteGuard _writeGuard;
  final Uuid _uuid;

  @override
  String get moduleName => 'Tender';

  @override
  String get phaseResponsibility =>
      'Phase 4: bidder profiles, tender entries, expenses, documents, and selected tender conversion.';

  @override
  Future<List<BidderProfile>> listBidderProfiles(String companyId) async {
    await database.ensureSchema();
    final rows = await database.customSelect(
      '''
      SELECT id, company_id, profile_name, portal_name, username,
             registered_mobile, registered_email, notes
      FROM bidder_profiles
      WHERE company_id = ? AND is_deleted = 0
      ORDER BY profile_name COLLATE NOCASE;
      ''',
      variables: [Variable<String>(companyId)],
    ).get();
    return rows.map(_bidderProfileFromRow).toList(growable: false);
  }

  @override
  Future<String> createBidderProfile(
      BidderProfileDraft draft, WriteContext context) async {
    _writeGuard.require(PermissionKey.tenderCreate);
    if (draft.profileName.trim().isEmpty) {
      throw ArgumentError.value(
          draft.profileName, 'profileName', 'Bidder profile name is required.');
    }
    await database.ensureSchema();
    final id = _uuid.v4();
    final now = context.timestamp;
    await database.transaction(() async {
      await database.customStatement(
        '''
        INSERT INTO bidder_profiles (
          id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
          is_deleted, sync_status, version, profile_name, portal_name, username,
          registered_mobile, registered_email, notes
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?);
        ''',
        [
          Variable<String>(id),
          Variable<String>(context.companyId),
          Variable<int>(now),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.userId),
          Variable<String>(draft.profileName.trim()),
          Variable<String>(_clean(draft.portalName)),
          Variable<String>(_clean(draft.username)),
          Variable<String>(_clean(draft.registeredMobile)),
          Variable<String>(_clean(draft.registeredEmail)),
          Variable<String>(_clean(draft.notes)),
        ],
      );
      await _queueDelta(
        context: context,
        now: now,
        entityType: 'bidder_profiles',
        entityId: id,
        operation: 'insert',
        payload: {'id': id, ...draft.toPayload(), ...context.toAuditJson()},
      );
    });
    return id;
  }

  @override
  Future<List<TenderListItem>> listTenders(String companyId) async {
    await database.ensureSchema();
    final rows = await database.customSelect(
      '''
      SELECT
        t.id,
        t.tender_title,
        t.tender_number,
        t.client_name,
        t.location,
        t.status,
        t.quoted_tender_price_paise,
        t.estimated_tender_value_paise,
        t.tender_fee_paise,
        t.document_fee_paise,
        t.processing_cost_paise,
        t.other_application_cost_paise,
        b.profile_name AS bidder_profile_name,
        COALESCE((
          SELECT SUM(e.amount_paise)
          FROM tender_expenses e
          WHERE e.company_id = t.company_id AND e.tender_id = t.id AND e.is_deleted = 0
        ), 0) AS extra_expense_total_paise
      FROM tenders t
      LEFT JOIN bidder_profiles b ON b.id = t.bidder_profile_id AND b.is_deleted = 0
      WHERE t.company_id = ? AND t.is_deleted = 0
      ORDER BY COALESCE(t.submission_date, t.application_date, t.updated_at) DESC;
      ''',
      variables: [Variable<String>(companyId)],
    ).get();
    return rows.map(_tenderListItemFromRow).toList(growable: false);
  }

  @override
  Future<TenderDashboardStats> loadStats(String companyId) async {
    final tenders = await listTenders(companyId);
    if (tenders.isEmpty) {
      return TenderDashboardStats.empty();
    }
    var active = 0;
    var selected = 0;
    var rejected = 0;
    var quotedPaise = 0;
    var applicationCostPaise = 0;
    for (final tender in tenders) {
      quotedPaise += tender.quotedPrice.paise;
      applicationCostPaise += tender.totalApplicationCost.paise;
      switch (tender.status) {
        case TenderStatus.selected:
          selected++;
          break;
        case TenderStatus.rejected:
          rejected++;
          break;
        case TenderStatus.cancelled:
          break;
        case TenderStatus.draft:
        case TenderStatus.applied:
        case TenderStatus.submitted:
          active++;
          break;
      }
    }
    return TenderDashboardStats(
      totalTenders: tenders.length,
      activeTenders: active,
      selectedTenders: selected,
      rejectedTenders: rejected,
      totalQuotedValue: Money.fromPaise(quotedPaise),
      totalApplicationCost: Money.fromPaise(applicationCostPaise),
    );
  }

  @override
  Future<TenderApplication?> findTender(
      String companyId, String tenderId) async {
    await database.ensureSchema();
    final row = await database.customSelect(
      '''
      SELECT *
      FROM tenders
      WHERE company_id = ? AND id = ? AND is_deleted = 0
      LIMIT 1;
      ''',
      variables: [Variable<String>(companyId), Variable<String>(tenderId)],
    ).getSingleOrNull();
    return row == null ? null : _tenderApplicationFromRow(row);
  }

  @override
  Future<String> createTender(TenderDraft draft, WriteContext context) async {
    _writeGuard.require(PermissionKey.tenderCreate);
    _businessService.validateTenderDraft(draft);
    await database.ensureSchema();
    if (draft.bidderProfileId != null) {
      await _assertBidderProfileExists(
          context.companyId, draft.bidderProfileId!);
    }
    final id = _uuid.v4();
    final now = context.timestamp;
    await database.transaction(() async {
      await database.customStatement(
        '''
        INSERT INTO tenders (
          id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
          is_deleted, sync_status, version, bidder_profile_id, tender_number, tender_title,
          department_name, client_name, location, tender_type, tender_category,
          application_date, submission_date, opening_date, result_date,
          estimated_tender_value_paise, quoted_tender_price_paise, emd_amount_paise,
          tender_fee_paise, document_fee_paise, processing_cost_paise, other_application_cost_paise,
          status, selected_date, rejection_reason, notes
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          Variable<String>(id),
          Variable<String>(context.companyId),
          Variable<int>(now),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.userId),
          Variable<String>(draft.bidderProfileId),
          Variable<String>(_clean(draft.tenderNumber)),
          Variable<String>(draft.tenderTitle.trim()),
          Variable<String>(_clean(draft.departmentName)),
          Variable<String>(_clean(draft.clientName)),
          Variable<String>(_clean(draft.location)),
          Variable<String>(_clean(draft.tenderType)),
          Variable<String>(_clean(draft.tenderCategory)),
          Variable<int>(draft.applicationDate),
          Variable<int>(draft.submissionDate),
          Variable<int>(draft.openingDate),
          Variable<int>(draft.resultDate),
          Variable<int>(draft.estimatedTenderValue.paise),
          Variable<int>(draft.quotedTenderPrice.paise),
          Variable<int>(draft.emdAmount.paise),
          Variable<int>(draft.tenderFee.paise),
          Variable<int>(draft.documentFee.paise),
          Variable<int>(draft.processingCost.paise),
          Variable<int>(draft.otherApplicationCost.paise),
          Variable<String>(draft.status.value),
          Variable<int>(draft.selectedDate),
          Variable<String>(_clean(draft.rejectionReason)),
          Variable<String>(_clean(draft.notes)),
        ],
      );
      await _queueDelta(
        context: context,
        now: now,
        entityType: 'tenders',
        entityId: id,
        operation: 'insert',
        payload: {'id': id, ...draft.toPayload(), ...context.toAuditJson()},
      );
    });
    return id;
  }

  @override
  Future<void> updateTenderStatus({
    required String tenderId,
    required TenderStatus status,
    required WriteContext context,
    int? selectedDate,
    String? rejectionReason,
  }) async {
    _writeGuard.require(PermissionKey.tenderEdit);
    await database.ensureSchema();
    await _assertTenderExists(context.companyId, tenderId);
    final now = context.timestamp;
    final effectiveSelectedDate =
        status == TenderStatus.selected ? selectedDate ?? now : selectedDate;
    await database.transaction(() async {
      await database.customStatement(
        '''
        UPDATE tenders
        SET status = ?, selected_date = ?, rejection_reason = ?,
            updated_at = ?, updated_by_user_id = ?, sync_status = 'pendingUpload', version = version + 1
        WHERE company_id = ? AND id = ? AND is_deleted = 0;
        ''',
        [
          Variable<String>(status.value),
          Variable<int>(effectiveSelectedDate),
          Variable<String>(_clean(rejectionReason)),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.companyId),
          Variable<String>(tenderId),
        ],
      );
      await _queueDelta(
        context: context,
        now: now,
        entityType: 'tenders',
        entityId: tenderId,
        operation: 'update',
        payload: {
          'id': tenderId,
          'status': status.value,
          'selectedDate': effectiveSelectedDate,
          'rejectionReason': _clean(rejectionReason),
          ...context.toAuditJson(),
        },
      );
    });
  }

  @override
  Future<String> addTenderExpense(
      TenderExpenseDraft draft, WriteContext context) async {
    _writeGuard.require(PermissionKey.tenderEdit);
    if (draft.amount.paise < 0) {
      throw ArgumentError.value(
          draft.amount.paise, 'amount', 'Tender expense cannot be negative.');
    }
    await database.ensureSchema();
    await _assertTenderExists(context.companyId, draft.tenderId);
    final id = _uuid.v4();
    final now = context.timestamp;
    await database.transaction(() async {
      await database.customStatement(
        '''
        INSERT INTO tender_expenses (
          id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
          is_deleted, sync_status, version, tender_id, expense_date, expense_type,
          description, amount_paise, paid_to, payment_mode, receipt_path, notes
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          Variable<String>(id),
          Variable<String>(context.companyId),
          Variable<int>(now),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.userId),
          Variable<String>(draft.tenderId),
          Variable<int>(draft.expenseDate),
          Variable<String>(draft.expenseType.value),
          Variable<String>(_clean(draft.description)),
          Variable<int>(draft.amount.paise),
          Variable<String>(_clean(draft.paidTo)),
          Variable<String>(_clean(draft.paymentMode)),
          Variable<String>(_clean(draft.receiptPath)),
          Variable<String>(_clean(draft.notes)),
        ],
      );
      await _queueDelta(
        context: context,
        now: now,
        entityType: 'tender_expenses',
        entityId: id,
        operation: 'insert',
        payload: {'id': id, ...draft.toPayload(), ...context.toAuditJson()},
      );
    });
    return id;
  }

  @override
  Future<List<TenderExpense>> listTenderExpenses(
      String companyId, String tenderId) async {
    await database.ensureSchema();
    final rows = await database.customSelect(
      '''
      SELECT *
      FROM tender_expenses
      WHERE company_id = ? AND tender_id = ? AND is_deleted = 0
      ORDER BY expense_date DESC, updated_at DESC;
      ''',
      variables: [Variable<String>(companyId), Variable<String>(tenderId)],
    ).get();
    return rows.map(_tenderExpenseFromRow).toList(growable: false);
  }

  @override
  Future<String> addTenderDocument(
      TenderDocumentDraft draft, WriteContext context) async {
    _writeGuard.require(PermissionKey.tenderEdit);
    if (draft.fileName.trim().isEmpty) {
      throw ArgumentError.value(
          draft.fileName, 'fileName', 'Document file name is required.');
    }
    await database.ensureSchema();
    await _assertTenderExists(context.companyId, draft.tenderId);
    final id = _uuid.v4();
    final now = context.timestamp;
    await database.transaction(() async {
      await database.customStatement(
        '''
        INSERT INTO tender_documents (
          id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
          is_deleted, sync_status, version, tender_id, document_type, file_name,
          local_path, firebase_storage_path, content_hash, uploaded_at
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          Variable<String>(id),
          Variable<String>(context.companyId),
          Variable<int>(now),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.userId),
          Variable<String>(draft.tenderId),
          Variable<String>(_clean(draft.documentType)),
          Variable<String>(draft.fileName.trim()),
          Variable<String>(_clean(draft.localPath)),
          Variable<String>(_clean(draft.firebaseStoragePath)),
          Variable<String>(_clean(draft.contentHash)),
          Variable<int>(draft.uploadedAt),
        ],
      );
      await _queueDelta(
        context: context,
        now: now,
        entityType: 'tender_documents',
        entityId: id,
        operation: 'insert',
        payload: {'id': id, ...draft.toPayload(), ...context.toAuditJson()},
      );
    });
    return id;
  }

  @override
  Future<List<TenderDocument>> listTenderDocuments(
      String companyId, String tenderId) async {
    await database.ensureSchema();
    final rows = await database.customSelect(
      '''
      SELECT *
      FROM tender_documents
      WHERE company_id = ? AND tender_id = ? AND is_deleted = 0
      ORDER BY updated_at DESC;
      ''',
      variables: [Variable<String>(companyId), Variable<String>(tenderId)],
    ).get();
    return rows.map(_tenderDocumentFromRow).toList(growable: false);
  }

  @override
  Future<TenderProjectConversionResult> convertSelectedTenderToProject(
    TenderProjectConversionDraft draft,
    WriteContext context,
  ) async {
    _writeGuard.require(PermissionKey.tenderEdit);
    _writeGuard.require(PermissionKey.projectCreate);
    await database.ensureSchema();
    final tender = await findTender(context.companyId, draft.tenderId);
    if (tender == null) {
      throw StateError('Tender not found.');
    }
    _businessService.ensureCanConvert(tender);

    final existing = await database.customSelect(
      '''
      SELECT id, project_code, project_name
      FROM projects
      WHERE company_id = ? AND tender_id = ? AND is_deleted = 0
      LIMIT 1;
      ''',
      variables: [
        Variable<String>(context.companyId),
        Variable<String>(draft.tenderId)
      ],
    ).getSingleOrNull();
    if (existing != null) {
      return TenderProjectConversionResult(
        projectId: existing.data['id'] as String,
        tenderId: draft.tenderId,
        projectCode:
            (existing.data['project_code'] as String?) ?? draft.projectCode,
        projectName: existing.data['project_name'] as String,
      );
    }

    final projectId = _uuid.v4();
    final now = context.timestamp;
    final projectName = _clean(draft.projectName) ?? tender.tenderTitle;
    await database.transaction(() async {
      await database.customStatement(
        '''
        INSERT INTO projects (
          id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
          is_deleted, sync_status, version, tender_id, project_code, project_name,
          client_name, department_name, site_location, start_date, expected_end_date, actual_end_date,
          project_status, tender_quoted_price_paise, approved_tender_amount_paise,
          agreement_gross_value_paise, agreement_final_value_paise, gst_rate_basis_points,
          retention_percent_basis_points, security_deposit_amount_paise,
          performance_guarantee_amount_paise, advance_received_paise, notes
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, ?, ?, NULL, 'planned', ?, ?, ?, ?, 0, 0, 0, 0, 0, ?);
        ''',
        [
          Variable<String>(projectId),
          Variable<String>(context.companyId),
          Variable<int>(now),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.userId),
          Variable<String>(draft.tenderId),
          Variable<String>(draft.projectCode.trim()),
          Variable<String>(projectName),
          Variable<String>(tender.clientName),
          Variable<String>(tender.departmentName),
          Variable<String>(tender.location),
          Variable<int>(draft.startDate),
          Variable<int>(draft.expectedEndDate),
          Variable<int>(tender.quotedTenderPrice.paise),
          Variable<int>(tender.quotedTenderPrice.paise),
          Variable<int>(tender.quotedTenderPrice.paise),
          Variable<int>(tender.quotedTenderPrice.paise),
          Variable<String>(_clean(draft.notes)),
        ],
      );
      await _queueDelta(
        context: context,
        now: now,
        entityType: 'projects',
        entityId: projectId,
        operation: 'insert',
        payload: {
          'id': projectId,
          'tenderId': draft.tenderId,
          'projectCode': draft.projectCode,
          'projectName': projectName,
          'clientName': tender.clientName,
          'departmentName': tender.departmentName,
          'siteLocation': tender.location,
          'tenderQuotedPricePaise': tender.quotedTenderPrice.paise,
          'approvedTenderAmountPaise': tender.quotedTenderPrice.paise,
          'agreementGrossValuePaise': tender.quotedTenderPrice.paise,
          'agreementFinalValuePaise': tender.quotedTenderPrice.paise,
          ...context.toAuditJson(),
        },
      );
    });
    return TenderProjectConversionResult(
      projectId: projectId,
      tenderId: draft.tenderId,
      projectCode: draft.projectCode,
      projectName: projectName,
    );
  }

  Future<void> _assertBidderProfileExists(
      String companyId, String profileId) async {
    final row = await database.customSelect(
      '''
      SELECT id FROM bidder_profiles
      WHERE company_id = ? AND id = ? AND is_deleted = 0
      LIMIT 1;
      ''',
      variables: [Variable<String>(companyId), Variable<String>(profileId)],
    ).getSingleOrNull();
    if (row == null) {
      throw StateError('Bidder profile not found.');
    }
  }

  Future<void> _assertTenderExists(String companyId, String tenderId) async {
    final row = await database.customSelect(
      '''
      SELECT id FROM tenders
      WHERE company_id = ? AND id = ? AND is_deleted = 0
      LIMIT 1;
      ''',
      variables: [Variable<String>(companyId), Variable<String>(tenderId)],
    ).getSingleOrNull();
    if (row == null) {
      throw StateError('Tender not found.');
    }
  }

  Future<void> _queueDelta({
    required WriteContext context,
    required int now,
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) async {
    final deltaId = _uuid.v4();
    await database.customStatement(
      '''
      INSERT INTO sync_queue (
        id, company_id, created_at, updated_at, created_by_user_id,
        updated_by_user_id, is_deleted, sync_status, version,
        entity_type, entity_id, operation, payload_json, device_id,
        schema_version, status, error_message
      ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, 'pendingUpload', NULL);
      ''',
      [
        Variable<String>(deltaId),
        Variable<String>(context.companyId),
        Variable<int>(now),
        Variable<int>(now),
        Variable<String>(context.userId),
        Variable<String>(context.userId),
        Variable<String>(entityType),
        Variable<String>(entityId),
        Variable<String>(operation),
        Variable<String>(jsonEncode(payload)),
        Variable<String>(context.deviceId),
        Variable<int>(AppSchemaSql.schemaVersion),
      ],
    );
  }

  BidderProfile _bidderProfileFromRow(QueryRow row) {
    return BidderProfile(
      id: row.data['id'] as String,
      companyId: row.data['company_id'] as String,
      profileName: row.data['profile_name'] as String,
      portalName: row.data['portal_name'] as String?,
      username: row.data['username'] as String?,
      registeredMobile: row.data['registered_mobile'] as String?,
      registeredEmail: row.data['registered_email'] as String?,
      notes: row.data['notes'] as String?,
    );
  }

  TenderApplication _tenderApplicationFromRow(QueryRow row) {
    return TenderApplication(
      id: row.data['id'] as String,
      companyId: row.data['company_id'] as String,
      bidderProfileId: row.data['bidder_profile_id'] as String?,
      tenderNumber: row.data['tender_number'] as String?,
      tenderTitle: row.data['tender_title'] as String,
      departmentName: row.data['department_name'] as String?,
      clientName: row.data['client_name'] as String?,
      location: row.data['location'] as String?,
      tenderType: row.data['tender_type'] as String?,
      tenderCategory: row.data['tender_category'] as String?,
      applicationDate: row.data['application_date'] as int?,
      submissionDate: row.data['submission_date'] as int?,
      openingDate: row.data['opening_date'] as int?,
      resultDate: row.data['result_date'] as int?,
      estimatedTenderValue:
          Money.fromPaise(row.data['estimated_tender_value_paise'] as int),
      quotedTenderPrice:
          Money.fromPaise(row.data['quoted_tender_price_paise'] as int),
      emdAmount: Money.fromPaise(row.data['emd_amount_paise'] as int),
      tenderFee: Money.fromPaise(row.data['tender_fee_paise'] as int),
      documentFee: Money.fromPaise(row.data['document_fee_paise'] as int),
      processingCost: Money.fromPaise(row.data['processing_cost_paise'] as int),
      otherApplicationCost:
          Money.fromPaise(row.data['other_application_cost_paise'] as int),
      status: TenderStatus.fromValue(row.data['status'] as String),
      selectedDate: row.data['selected_date'] as int?,
      rejectionReason: row.data['rejection_reason'] as String?,
      notes: row.data['notes'] as String?,
      version: row.data['version'] as int? ?? 1,
    );
  }

  TenderListItem _tenderListItemFromRow(QueryRow row) {
    final inlineCostPaise = (row.data['tender_fee_paise'] as int) +
        (row.data['document_fee_paise'] as int) +
        (row.data['processing_cost_paise'] as int) +
        (row.data['other_application_cost_paise'] as int);
    return TenderListItem(
      id: row.data['id'] as String,
      title: row.data['tender_title'] as String,
      tenderNumber: row.data['tender_number'] as String?,
      clientName: row.data['client_name'] as String?,
      location: row.data['location'] as String?,
      bidderProfileName: row.data['bidder_profile_name'] as String?,
      status: TenderStatus.fromValue(row.data['status'] as String),
      quotedPrice:
          Money.fromPaise(row.data['quoted_tender_price_paise'] as int),
      estimatedValue:
          Money.fromPaise(row.data['estimated_tender_value_paise'] as int),
      inlineApplicationCost: Money.fromPaise(inlineCostPaise),
      extraExpenseTotal:
          Money.fromPaise(row.data['extra_expense_total_paise'] as int),
    );
  }

  TenderExpense _tenderExpenseFromRow(QueryRow row) {
    return TenderExpense(
      id: row.data['id'] as String,
      companyId: row.data['company_id'] as String,
      tenderId: row.data['tender_id'] as String,
      expenseDate: row.data['expense_date'] as int,
      expenseType:
          TenderExpenseType.fromValue(row.data['expense_type'] as String),
      description: row.data['description'] as String?,
      amount: Money.fromPaise(row.data['amount_paise'] as int),
      paidTo: row.data['paid_to'] as String?,
      paymentMode: row.data['payment_mode'] as String?,
      receiptPath: row.data['receipt_path'] as String?,
      notes: row.data['notes'] as String?,
    );
  }

  TenderDocument _tenderDocumentFromRow(QueryRow row) {
    return TenderDocument(
      id: row.data['id'] as String,
      companyId: row.data['company_id'] as String,
      tenderId: row.data['tender_id'] as String,
      documentType: row.data['document_type'] as String?,
      fileName: row.data['file_name'] as String,
      localPath: row.data['local_path'] as String?,
      firebaseStoragePath: row.data['firebase_storage_path'] as String?,
      contentHash: row.data['content_hash'] as String?,
      uploadedAt: row.data['uploaded_at'] as int?,
    );
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
