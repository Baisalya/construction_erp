import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/domain/write_context.dart';
import '../../../core/permissions/permission_key.dart';
import '../../../core/permissions/repository_write_guard.dart';
import '../../../core/value_objects/money.dart';
import '../../../core/value_objects/quantity.dart';
import '../../../database/local_database.dart';
import '../../../database/schema/app_schema_sql.dart';
import '../domain/labor_module_contract.dart';
import '../domain/labor_records.dart';

class LaborRepository implements LaborModuleContract {
  LaborRepository({
    required this.database,
    LaborCalculator calculator = const LaborCalculator(),
    RepositoryWriteGuard writeGuard = const AllowAllRepositoryWriteGuard(),
    Uuid uuid = const Uuid(),
  })  : _calculator = calculator,
        _writeGuard = writeGuard,
        _uuid = uuid;

  final ConstructionDatabase database;
  final LaborCalculator _calculator;
  final RepositoryWriteGuard _writeGuard;
  final Uuid _uuid;

  @override
  String get moduleName => 'Labor';

  @override
  String get phaseResponsibility =>
      'Phase 4: labor master, daywise/thika/hourly/piecework entries, payments, and advances.';

  @override
  Future<String> createLaborer(LaborerDraft draft, WriteContext context) async {
    _writeGuard.require(PermissionKey.laborEntry);
    if (draft.name.trim().isEmpty) {
      throw ArgumentError.value(draft.name, 'name', 'Labor name is required.');
    }
    if (draft.defaultRate.paise < 0) {
      throw ArgumentError.value(
          draft.defaultRate, 'defaultRate', 'Default rate cannot be negative.');
    }
    await database.ensureSchema();
    final id = _uuid.v4();
    final now = context.timestamp;
    await database.transaction(() async {
      await database.customStatement(
        '''
        INSERT INTO laborers (
          id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
          is_deleted, sync_status, version, name, phone, address, labor_type,
          default_work_type, default_rate_paise, notes
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          Variable<String>(id),
          Variable<String>(context.companyId),
          Variable<int>(now),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.userId),
          Variable<String>(draft.name.trim()),
          Variable<String>(_clean(draft.phone)),
          Variable<String>(_clean(draft.address)),
          Variable<String>(draft.laborType.value),
          Variable<String>(draft.defaultWorkType.value),
          Variable<int>(draft.defaultRate.paise),
          Variable<String>(_clean(draft.notes)),
        ],
      );
      await _queueDelta(
        context: context,
        now: now,
        entityType: 'laborers',
        entityId: id,
        operation: 'insert',
        payload: {'id': id, ...draft.toPayload(), ...context.toAuditJson()},
      );
    });
    return id;
  }

  Future<void> _applyPaymentToWorkEntries(
      LaborPaymentDraft draft, WriteContext context,
      {required int now}) async {
    final projectFilter = draft.projectId == null ? '' : 'AND project_id = ?';
    final rows = await database.customSelect(
      '''
      SELECT id, paid_amount_paise, pending_amount_paise
      FROM labor_work_entries
      WHERE company_id = ? AND labor_id = ? AND is_deleted = 0
        AND pending_amount_paise > 0 $projectFilter
      ORDER BY work_date, created_at, id;
      ''',
      variables: [
        Variable<String>(context.companyId),
        Variable<String>(draft.laborId),
        if (draft.projectId != null) Variable<String>(draft.projectId!),
      ],
    ).get();
    final available = rows.fold<int>(
        0, (total, row) => total + row.read<int>('pending_amount_paise'));
    if (draft.amount.paise > available) {
      throw ArgumentError.value(draft.amount, 'amount',
          'Labor payment exceeds the selected outstanding balance.');
    }

    var remaining = draft.amount.paise;
    for (final row in rows) {
      if (remaining == 0) {
        break;
      }
      final entryId = row.read<String>('id');
      final currentPaid = row.read<int>('paid_amount_paise');
      final currentPending = row.read<int>('pending_amount_paise');
      final applied = remaining < currentPending ? remaining : currentPending;
      final paid = currentPaid + applied;
      final pending = currentPending - applied;
      final status =
          pending == 0 ? LaborPaymentStatus.paid : LaborPaymentStatus.partial;
      await database.customStatement(
        '''
        UPDATE labor_work_entries
        SET paid_amount_paise = ?, pending_amount_paise = ?, payment_status = ?,
            updated_at = ?, updated_by_user_id = ?, sync_status = 'pendingUpload',
            version = version + 1
        WHERE company_id = ? AND id = ? AND is_deleted = 0;
        ''',
        [
          Variable<int>(paid),
          Variable<int>(pending),
          Variable<String>(status.value),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.companyId),
          Variable<String>(entryId),
        ],
      );
      await _queueDelta(
        context: context,
        now: now,
        entityType: 'labor_work_entries',
        entityId: entryId,
        operation: 'update',
        payload: {
          'id': entryId,
          'paidAmountPaise': paid,
          'pendingAmountPaise': pending,
          'paymentStatus': status.value,
          ...context.toAuditJson(),
        },
      );
      remaining -= applied;
    }
  }

  @override
  Future<List<LaborerRecord>> listLaborers(String companyId) async {
    await database.ensureSchema();
    final rows = await database.customSelect(
      '''
      SELECT *
      FROM laborers
      WHERE company_id = ? AND is_deleted = 0
      ORDER BY name COLLATE NOCASE;
      ''',
      variables: [Variable<String>(companyId)],
    ).get();
    return rows.map(_laborerFromRow).toList(growable: false);
  }

  @override
  Future<String> createWorkEntry(
      LaborWorkEntryDraft draft, WriteContext context) async {
    _writeGuard.require(PermissionKey.laborEntry, projectId: draft.projectId);
    if (draft.projectId.trim().isEmpty || draft.laborId.trim().isEmpty) {
      throw ArgumentError('Project and labor are required.');
    }
    final totals = _calculator.calculateEntry(draft);
    await database.ensureSchema();
    final id = _uuid.v4();
    final now = context.timestamp;
    await database.transaction(() async {
      await database.customStatement(
        '''
        INSERT INTO labor_work_entries (
          id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
          is_deleted, sync_status, version, project_id, labor_id, work_date,
          work_description, work_type, quantity_decimal, unit, rate_paise,
          total_amount_paise, paid_amount_paise, pending_amount_paise, payment_status, notes
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          Variable<String>(id),
          Variable<String>(context.companyId),
          Variable<int>(now),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.userId),
          Variable<String>(draft.projectId),
          Variable<String>(draft.laborId),
          Variable<int>(draft.workDate),
          Variable<String>(_clean(draft.workDescription)),
          Variable<String>(draft.workType.value),
          Variable<String>(draft.quantity.toStorageString()),
          Variable<String>(_clean(draft.unit) ?? 'day'),
          Variable<int>(draft.rate.paise),
          Variable<int>(totals.totalAmount.paise),
          Variable<int>(draft.paidAmount.paise),
          Variable<int>(totals.pendingAmount.paise),
          Variable<String>(totals.paymentStatus.value),
          Variable<String>(_clean(draft.notes)),
        ],
      );
      await _queueDelta(
        context: context,
        now: now,
        entityType: 'labor_work_entries',
        entityId: id,
        operation: 'insert',
        payload: {
          'id': id,
          ...draft.toPayload(
              totalAmount: totals.totalAmount,
              pendingAmount: totals.pendingAmount,
              paymentStatus: totals.paymentStatus),
          ...context.toAuditJson()
        },
      );
    });
    return id;
  }

  @override
  Future<List<LaborWorkEntryRecord>> listWorkEntries(String companyId,
      {String? projectId}) async {
    await database.ensureSchema();
    final whereProject = projectId == null ? '' : 'AND project_id = ?';
    final variables = <Variable>[Variable<String>(companyId)];
    if (projectId != null) {
      variables.add(Variable<String>(projectId));
    }
    final rows = await database.customSelect(
      '''
      SELECT *
      FROM labor_work_entries
      WHERE company_id = ? AND is_deleted = 0 $whereProject
      ORDER BY work_date DESC, updated_at DESC;
      ''',
      variables: variables,
    ).get();
    return rows.map(_workEntryFromRow).toList(growable: false);
  }

  @override
  Future<String> recordLaborPayment(
      LaborPaymentDraft draft, WriteContext context) async {
    _writeGuard.require(PermissionKey.laborEntry, projectId: draft.projectId);
    if (draft.amount.paise <= 0) {
      throw ArgumentError.value(
          draft.amount, 'amount', 'Labor payment must be greater than zero.');
    }
    await database.ensureSchema();
    final id = _uuid.v4();
    final now = context.timestamp;
    await database.transaction(() async {
      await _applyPaymentToWorkEntries(draft, context, now: now);
      await database.customStatement(
        '''
        INSERT INTO labor_payments (
          id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
          is_deleted, sync_status, version, labor_id, project_id, payment_date,
          amount_paise, payment_mode, reference_number, notes
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          Variable<String>(id),
          Variable<String>(context.companyId),
          Variable<int>(now),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.userId),
          Variable<String>(draft.laborId),
          Variable<String>(_clean(draft.projectId)),
          Variable<int>(draft.paymentDate),
          Variable<int>(draft.amount.paise),
          Variable<String>(draft.paymentMode.value),
          Variable<String>(_clean(draft.referenceNumber)),
          Variable<String>(_clean(draft.notes)),
        ],
      );
      await _queueDelta(
        context: context,
        now: now,
        entityType: 'labor_payments',
        entityId: id,
        operation: 'insert',
        payload: {
          'id': id,
          'laborId': draft.laborId,
          'projectId': draft.projectId,
          'paymentDate': draft.paymentDate,
          'amountPaise': draft.amount.paise,
          'paymentMode': draft.paymentMode.value,
          'referenceNumber': draft.referenceNumber,
          'notes': draft.notes,
          ...context.toAuditJson(),
        },
      );
    });
    return id;
  }

  @override
  Future<String> recordLaborAdvance(
      LaborAdvanceDraft draft, WriteContext context) async {
    _writeGuard.require(PermissionKey.laborEntry, projectId: draft.projectId);
    final balance = _calculator.calculateAdvanceBalance(draft);
    await database.ensureSchema();
    final id = _uuid.v4();
    final now = context.timestamp;
    await database.transaction(() async {
      await database.customStatement(
        '''
        INSERT INTO labor_advances (
          id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
          is_deleted, sync_status, version, labor_id, project_id, advance_date,
          amount_paise, recovered_amount_paise, balance_amount_paise, notes
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          Variable<String>(id),
          Variable<String>(context.companyId),
          Variable<int>(now),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.userId),
          Variable<String>(draft.laborId),
          Variable<String>(_clean(draft.projectId)),
          Variable<int>(draft.advanceDate),
          Variable<int>(draft.amount.paise),
          Variable<int>(draft.recoveredAmount.paise),
          Variable<int>(balance.paise),
          Variable<String>(_clean(draft.notes)),
        ],
      );
      await _queueDelta(
        context: context,
        now: now,
        entityType: 'labor_advances',
        entityId: id,
        operation: 'insert',
        payload: {
          'id': id,
          'laborId': draft.laborId,
          'projectId': draft.projectId,
          'advanceDate': draft.advanceDate,
          'amountPaise': draft.amount.paise,
          'recoveredAmountPaise': draft.recoveredAmount.paise,
          'balanceAmountPaise': balance.paise,
          'notes': draft.notes,
          ...context.toAuditJson(),
        },
      );
    });
    return id;
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

  LaborerRecord _laborerFromRow(QueryRow row) {
    return LaborerRecord(
      id: row.data['id'] as String,
      companyId: row.data['company_id'] as String,
      name: row.data['name'] as String,
      phone: row.data['phone'] as String?,
      address: row.data['address'] as String?,
      laborType: LaborType.fromValue(row.data['labor_type'] as String?),
      defaultWorkType:
          LaborWorkType.fromValue(row.data['default_work_type'] as String?),
      defaultRate: Money.fromPaise(row.data['default_rate_paise'] as int),
      notes: row.data['notes'] as String?,
    );
  }

  LaborWorkEntryRecord _workEntryFromRow(QueryRow row) {
    return LaborWorkEntryRecord(
      id: row.data['id'] as String,
      companyId: row.data['company_id'] as String,
      projectId: row.data['project_id'] as String,
      laborId: row.data['labor_id'] as String,
      workDate: row.data['work_date'] as int,
      workDescription: row.data['work_description'] as String?,
      workType: LaborWorkType.fromValue(row.data['work_type'] as String?),
      quantity: DecimalQuantity.parse(row.data['quantity_decimal'] as String),
      unit: row.data['unit'] as String? ?? 'day',
      rate: Money.fromPaise(row.data['rate_paise'] as int),
      totalAmount: Money.fromPaise(row.data['total_amount_paise'] as int),
      paidAmount: Money.fromPaise(row.data['paid_amount_paise'] as int),
      pendingAmount: Money.fromPaise(row.data['pending_amount_paise'] as int),
      paymentStatus:
          LaborPaymentStatus.fromValue(row.data['payment_status'] as String),
      notes: row.data['notes'] as String?,
    );
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
