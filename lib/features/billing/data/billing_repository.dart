import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/domain/write_context.dart';
import '../../../core/permissions/permission_key.dart';
import '../../../core/permissions/repository_write_guard.dart';
import '../../../core/value_objects/money.dart';
import '../../../core/value_objects/quantity.dart';
import '../../../database/local_database.dart';
import '../../../sync/data/local_delta_writer.dart';
import '../domain/billing_module_contract.dart';
import '../domain/billing_records.dart';

class BillingRepository implements BillingModuleContract {
  BillingRepository({
    required this.database,
    BillingCalculator calculator = const BillingCalculator(),
    RepositoryWriteGuard writeGuard = const AllowAllRepositoryWriteGuard(),
    Uuid uuid = const Uuid(),
  })  : _calculator = calculator,
        _writeGuard = writeGuard,
        _uuid = uuid;

  final ConstructionDatabase database;
  final BillingCalculator _calculator;
  final RepositoryWriteGuard _writeGuard;
  final Uuid _uuid;

  @override
  String get moduleName => 'Billing';

  @override
  String get phaseResponsibility =>
      'Phase 5: estimates, bills, receipts, GST entries, payable/receivable, and profit/loss calculation UI.';

  Future<String> createEstimate(
      ProjectEstimateDraft draft, WriteContext context) async {
    _writeGuard.require(PermissionKey.billingEntry, projectId: draft.projectId);
    if (draft.projectId.trim().isEmpty) {
      throw ArgumentError.value(
          draft.projectId, 'projectId', 'Project is required.');
    }
    if (draft.title.trim().isEmpty) {
      throw ArgumentError.value(
          draft.title, 'title', 'Estimate title is required.');
    }
    if (draft.items.isEmpty) {
      throw ArgumentError('At least one estimate item is required.');
    }
    for (final item in draft.items) {
      _validateEstimateItem(item);
    }

    await database.ensureSchema();
    final agreementValue = await _projectMoney(
        context.companyId, draft.projectId, 'agreement_final_value_paise');
    final totals = _calculator.calculateEstimate(draft, agreementValue);
    final estimateId = _uuid.v4();
    final now = context.timestamp;
    final itemPayloads = <Map<String, Object?>>[];

    await database.transaction(() async {
      await database.customStatement(
        '''
        INSERT INTO project_estimates (
          id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
          is_deleted, sync_status, version, project_id, estimate_number, estimate_date, title,
          total_estimated_material_cost_paise, total_estimated_labor_cost_paise,
          total_estimated_machinery_cost_paise, total_estimated_other_cost_paise,
          total_estimated_cost_paise, estimated_profit_paise, notes
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          Variable<String>(estimateId),
          Variable<String>(context.companyId),
          Variable<int>(now),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.userId),
          Variable<String>(draft.projectId.trim()),
          Variable<String>(_clean(draft.estimateNumber)),
          Variable<int>(draft.estimateDate),
          Variable<String>(draft.title.trim()),
          Variable<int>(totals.materialCost.paise),
          Variable<int>(totals.laborCost.paise),
          Variable<int>(totals.machineryCost.paise),
          Variable<int>(totals.otherCost.paise),
          Variable<int>(totals.totalEstimatedCost.paise),
          Variable<int>(totals.estimatedProfit.paise),
          Variable<String>(_clean(draft.notes)),
        ],
      );

      for (final item in draft.items) {
        final itemId = _uuid.v4();
        final amount = _calculator.calculateAmount(item.quantity, item.rate);
        itemPayloads.add({'id': itemId, ...item.toPayload(amount: amount)});
        await database.customStatement(
          '''
          INSERT INTO project_estimate_items (
            id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
            is_deleted, sync_status, version, estimate_id, item_name, description, unit,
            quantity_decimal, rate_paise, amount_paise
          ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, ?);
          ''',
          [
            Variable<String>(itemId),
            Variable<String>(context.companyId),
            Variable<int>(now),
            Variable<int>(now),
            Variable<String>(context.userId),
            Variable<String>(context.userId),
            Variable<String>(estimateId),
            Variable<String>(item.itemName.trim()),
            Variable<String>(_clean(item.description)),
            Variable<String>(_clean(item.unit) ?? 'piece'),
            Variable<String>(item.quantity.toStorageString()),
            Variable<int>(item.rate.paise),
            Variable<int>(amount.paise),
          ],
        );
        await _queueDelta(
          context: context,
          now: now,
          entityType: 'project_estimate_items',
          entityId: itemId,
          operation: 'insert',
          payload: {
            ...itemPayloads.last,
            'estimateId': estimateId,
            'projectId': draft.projectId,
          },
        );
      }

      await _queueDelta(
        context: context,
        now: now,
        entityType: 'project_estimates',
        entityId: estimateId,
        operation: 'insert',
        payload: {
          'id': estimateId,
          'projectId': draft.projectId,
          'estimateNumber': draft.estimateNumber,
          'estimateDate': draft.estimateDate,
          'title': draft.title,
          'totalEstimatedCostPaise': totals.totalEstimatedCost.paise,
          'estimatedProfitPaise': totals.estimatedProfit.paise,
          'items': itemPayloads,
          ...context.toAuditJson(),
        },
      );
    });

    return estimateId;
  }

  Future<List<ProjectEstimateRecord>> listEstimates(String companyId,
      {String? projectId}) async {
    await database.ensureSchema();
    final scope = _projectReadScope(projectId);
    final rows = await database.customSelect(
      '''
      SELECT *
      FROM project_estimates
      WHERE company_id = ? AND is_deleted = 0 ${scope.sql}
      ORDER BY estimate_date DESC, updated_at DESC;
      ''',
      variables: [
        Variable<String>(companyId),
        ...scope.variables,
      ],
    ).get();

    final estimates = <ProjectEstimateRecord>[];
    for (final row in rows) {
      final estimate = _estimateFromRow(row);
      final items = await _listEstimateItems(companyId, estimate.id);
      estimates.add(_copyEstimateWithItems(estimate, items));
    }
    return estimates;
  }

  Future<String> createBill(
      ProjectBillDraft draft, WriteContext context) async {
    _writeGuard.require(PermissionKey.billingEntry, projectId: draft.projectId);
    if (draft.projectId.trim().isEmpty) {
      throw ArgumentError.value(
          draft.projectId, 'projectId', 'Project is required.');
    }
    if (draft.billNumber.trim().isEmpty) {
      throw ArgumentError.value(
          draft.billNumber, 'billNumber', 'Bill number is required.');
    }
    final totals = _calculator.calculateBill(draft);
    await database.ensureSchema();
    final billId = _uuid.v4();
    final now = context.timestamp;

    await database.transaction(() async {
      await database.customStatement(
        '''
        INSERT INTO project_bills (
          id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
          is_deleted, sync_status, version, project_id, bill_number, bill_date, bill_type,
          gross_bill_amount_paise, gst_rate_basis_points, gst_amount_paise, total_bill_amount_paise,
          tds_amount_paise, retention_amount_paise, other_deduction_amount_paise,
          net_receivable_amount_paise, received_amount_paise, pending_amount_paise, status, notes
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          Variable<String>(billId),
          Variable<String>(context.companyId),
          Variable<int>(now),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.userId),
          Variable<String>(draft.projectId.trim()),
          Variable<String>(draft.billNumber.trim()),
          Variable<int>(draft.billDate),
          Variable<String>(draft.billType.value),
          Variable<int>(draft.grossBillAmount.paise),
          Variable<int>(draft.gstRateBasisPoints),
          Variable<int>(totals.gstAmount.paise),
          Variable<int>(totals.totalBillAmount.paise),
          Variable<int>(draft.tdsAmount.paise),
          Variable<int>(draft.retentionAmount.paise),
          Variable<int>(draft.otherDeductionAmount.paise),
          Variable<int>(totals.netReceivableAmount.paise),
          Variable<int>(totals.receivedAmount.paise),
          Variable<int>(totals.pendingAmount.paise),
          Variable<String>(totals.status.value),
          Variable<String>(_clean(draft.notes)),
        ],
      );

      if (totals.gstAmount.paise > 0) {
        final gstEntryId = _uuid.v4();
        await _insertGstEntry(
          id: gstEntryId,
          context: context,
          now: now,
          draft: GstEntryDraft(
            projectId: draft.projectId,
            sourceType: GstSourceType.projectBill,
            sourceId: billId,
            gstType: GstType.output,
            gstRateBasisPoints: draft.gstRateBasisPoints,
            taxableAmount: draft.grossBillAmount,
            gstAmount: totals.gstAmount,
            entryDate: draft.billDate,
            notes: 'Auto GST from bill ${draft.billNumber}',
          ),
        );
        await _queueDelta(
          context: context,
          now: now,
          entityType: 'gst_entries',
          entityId: gstEntryId,
          operation: 'insert',
          payload: {
            'id': gstEntryId,
            'projectId': draft.projectId,
            'sourceType': GstSourceType.projectBill.value,
            'sourceId': billId,
            'gstType': GstType.output.value,
            'gstAmountPaise': totals.gstAmount.paise,
            ...context.toAuditJson(),
          },
        );
      }

      await _queueDelta(
        context: context,
        now: now,
        entityType: 'project_bills',
        entityId: billId,
        operation: 'insert',
        payload: {
          'id': billId,
          'projectId': draft.projectId,
          'billNumber': draft.billNumber,
          'billDate': draft.billDate,
          'billType': draft.billType.value,
          'grossBillAmountPaise': draft.grossBillAmount.paise,
          'gstAmountPaise': totals.gstAmount.paise,
          'totalBillAmountPaise': totals.totalBillAmount.paise,
          'netReceivableAmountPaise': totals.netReceivableAmount.paise,
          'receivedAmountPaise': totals.receivedAmount.paise,
          'pendingAmountPaise': totals.pendingAmount.paise,
          'status': totals.status.value,
          ...context.toAuditJson(),
        },
      );
    });

    return billId;
  }

  Future<List<ProjectBillRecord>> listBills(String companyId,
      {String? projectId}) async {
    await database.ensureSchema();
    final scope = _projectReadScope(projectId);
    final rows = await database.customSelect(
      '''
      SELECT *
      FROM project_bills
      WHERE company_id = ? AND is_deleted = 0 ${scope.sql}
      ORDER BY bill_date DESC, updated_at DESC;
      ''',
      variables: [
        Variable<String>(companyId),
        ...scope.variables,
      ],
    ).get();
    return rows.map(_billFromRow).toList(growable: false);
  }

  Future<ProjectBillRecord?> findBill(String companyId, String billId) async {
    await database.ensureSchema();
    final row = await database.customSelect(
      '''
      SELECT * FROM project_bills
      WHERE company_id = ? AND id = ? AND is_deleted = 0
      LIMIT 1;
      ''',
      variables: [Variable<String>(companyId), Variable<String>(billId)],
    ).getSingleOrNull();
    if (row == null) return null;
    final bill = _billFromRow(row);
    return _writeGuard.canAccessProject(bill.projectId) ? bill : null;
  }

  Future<String> addBillReceipt(
      ProjectBillReceiptDraft draft, WriteContext context) async {
    _writeGuard.require(PermissionKey.billingEntry, projectId: draft.projectId);
    if (draft.projectId.trim().isEmpty) {
      throw ArgumentError.value(
          draft.projectId, 'projectId', 'Project is required.');
    }
    if (draft.billId.trim().isEmpty) {
      throw ArgumentError.value(draft.billId, 'billId', 'Bill is required.');
    }
    _assertNonNegative('amount', draft.amount);
    if (draft.amount.isZero) {
      throw ArgumentError.value(
          draft.amount, 'amount', 'Receipt amount must be greater than zero.');
    }

    await database.ensureSchema();
    final bill = await findBill(context.companyId, draft.billId);
    if (bill == null) {
      throw StateError('Bill not found.');
    }
    final newReceived = bill.receivedAmount + draft.amount;
    if (newReceived.paise > bill.netReceivableAmount.paise) {
      throw ArgumentError('Receipt is more than pending receivable.');
    }
    final newPending = bill.netReceivableAmount - newReceived;
    final newStatus =
        _calculator.statusFromReceipt(bill.netReceivableAmount, newReceived);
    final receiptId = _uuid.v4();
    final now = context.timestamp;

    await database.transaction(() async {
      await database.customStatement(
        '''
        INSERT INTO project_bill_receipts (
          id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
          is_deleted, sync_status, version, project_id, bill_id, receipt_date, amount_paise,
          payment_mode, reference_number, notes
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          Variable<String>(receiptId),
          Variable<String>(context.companyId),
          Variable<int>(now),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.userId),
          Variable<String>(draft.projectId.trim()),
          Variable<String>(draft.billId.trim()),
          Variable<int>(draft.receiptDate),
          Variable<int>(draft.amount.paise),
          Variable<String>(_clean(draft.paymentMode)),
          Variable<String>(_clean(draft.referenceNumber)),
          Variable<String>(_clean(draft.notes)),
        ],
      );
      await database.customStatement(
        '''
        UPDATE project_bills
        SET received_amount_paise = ?, pending_amount_paise = ?, status = ?,
            updated_at = ?, updated_by_user_id = ?, sync_status = 'pendingUpload', version = version + 1
        WHERE company_id = ? AND id = ? AND project_id = ? AND is_deleted = 0;
        ''',
        [
          Variable<int>(newReceived.paise),
          Variable<int>(newPending.paise),
          Variable<String>(newStatus.value),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.companyId),
          Variable<String>(draft.billId.trim()),
          Variable<String>(draft.projectId.trim()),
        ],
      );
      await _queueDelta(
        context: context,
        now: now,
        entityType: 'project_bill_receipts',
        entityId: receiptId,
        operation: 'insert',
        payload: {
          'id': receiptId,
          'projectId': draft.projectId,
          'billId': draft.billId,
          'receiptDate': draft.receiptDate,
          'amountPaise': draft.amount.paise,
          'paymentMode': draft.paymentMode,
          ...context.toAuditJson(),
        },
      );
    });

    return receiptId;
  }

  Future<String> createGstEntry(
      GstEntryDraft draft, WriteContext context) async {
    _writeGuard.require(PermissionKey.billingEntry, projectId: draft.projectId);
    _assertNonNegative('taxableAmount', draft.taxableAmount);
    _assertNonNegative('gstAmount', draft.gstAmount);
    await database.ensureSchema();
    final id = _uuid.v4();
    final now = context.timestamp;
    await database.transaction(() async {
      await _insertGstEntry(id: id, context: context, now: now, draft: draft);
      await _queueDelta(
        context: context,
        now: now,
        entityType: 'gst_entries',
        entityId: id,
        operation: 'insert',
        payload: {
          'id': id,
          'projectId': draft.projectId,
          'sourceType': draft.sourceType.value,
          'sourceId': draft.sourceId,
          'gstType': draft.gstType.value,
          'gstRateBasisPoints': draft.gstRateBasisPoints,
          'taxableAmountPaise': draft.taxableAmount.paise,
          'gstAmountPaise': draft.gstAmount.paise,
          'entryDate': draft.entryDate,
          ...context.toAuditJson(),
        },
      );
    });
    return id;
  }

  Future<List<GstEntryRecord>> listGstEntries(String companyId,
      {String? projectId}) async {
    await database.ensureSchema();
    final scope = _projectReadScope(projectId);
    final rows = await database.customSelect(
      '''
      SELECT *
      FROM gst_entries
      WHERE company_id = ? AND is_deleted = 0 ${scope.sql}
      ORDER BY entry_date DESC, updated_at DESC;
      ''',
      variables: [
        Variable<String>(companyId),
        ...scope.variables,
      ],
    ).get();
    return rows.map(_gstFromRow).toList(growable: false);
  }

  Future<BillingDashboardSummary> loadBillingSummary(String companyId,
      {String? projectId}) async {
    await database.ensureSchema();
    final agreementValue = await _sum(
      companyId,
      'projects',
      'agreement_final_value_paise',
      projectId: projectId,
      projectColumn: 'id',
    );
    final latestEstimateTotal =
        await _latestEstimateTotal(companyId, projectId: projectId);

    final materialCost = await _sum(
        companyId, 'material_purchase_items', 'total_amount_paise',
        projectId: projectId);
    final laborCost = await _sum(
        companyId, 'labor_work_entries', 'total_amount_paise',
        projectId: projectId);
    final machineryCost = await _sum(
        companyId, 'machine_usage_entries', 'total_amount_paise',
        projectId: projectId);
    final fuelCost = await _sum(companyId, 'fuel_entries', 'total_amount_paise',
        projectId: projectId);
    final repairCost = await _sum(
        companyId, 'machine_repair_entries', 'total_cost_paise',
        projectId: projectId);
    final otherExpenseCost = await _sum(
        companyId, 'project_expenses', 'amount_paise',
        projectId: projectId);
    final totalActualCost = materialCost +
        laborCost +
        machineryCost +
        fuelCost +
        repairCost +
        otherExpenseCost;

    final gstInput = await _sumWithType(companyId, 'gst_entries',
        'gst_amount_paise', 'gst_type', GstType.input.value,
        projectId: projectId);
    final gstOutput = await _sumWithType(companyId, 'gst_entries',
        'gst_amount_paise', 'gst_type', GstType.output.value,
        projectId: projectId);
    final totalBilled = await _sum(
        companyId, 'project_bills', 'net_receivable_amount_paise',
        projectId: projectId);
    final totalReceived = await _sum(
        companyId, 'project_bill_receipts', 'amount_paise',
        projectId: projectId);
    final pendingReceivable = await _sum(
        companyId, 'project_bills', 'pending_amount_paise',
        projectId: projectId);
    final totalPayable =
        await _loadTotalPayable(companyId, projectId: projectId);

    return BillingDashboardSummary(
      agreementValue: agreementValue,
      latestEstimateTotal: latestEstimateTotal,
      estimatedProfit: agreementValue - latestEstimateTotal,
      materialCost: materialCost,
      laborCost: laborCost,
      machineryCost: machineryCost,
      fuelCost: fuelCost,
      repairCost: repairCost,
      otherExpenseCost: otherExpenseCost,
      totalActualCost: totalActualCost,
      gstInput: gstInput,
      gstOutput: gstOutput,
      totalBilled: totalBilled,
      totalReceived: totalReceived,
      pendingReceivable: pendingReceivable,
      totalPayable: totalPayable,
      actualProfitByAgreement: agreementValue - totalActualCost,
      actualProfitByReceived: totalReceived - totalActualCost,
    );
  }

  Future<void> _insertGstEntry(
      {required String id,
      required WriteContext context,
      required int now,
      required GstEntryDraft draft}) async {
    await database.customStatement(
      '''
      INSERT INTO gst_entries (
        id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
        is_deleted, sync_status, version, project_id, source_type, source_id, gst_type,
        gst_rate_basis_points, taxable_amount_paise, gst_amount_paise, entry_date, notes
      ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      ''',
      [
        Variable<String>(id),
        Variable<String>(context.companyId),
        Variable<int>(now),
        Variable<int>(now),
        Variable<String>(context.userId),
        Variable<String>(context.userId),
        Variable<String>(_clean(draft.projectId)),
        Variable<String>(draft.sourceType.value),
        Variable<String>(draft.sourceId.trim()),
        Variable<String>(draft.gstType.value),
        Variable<int>(draft.gstRateBasisPoints),
        Variable<int>(draft.taxableAmount.paise),
        Variable<int>(draft.gstAmount.paise),
        Variable<int>(draft.entryDate),
        Variable<String>(_clean(draft.notes)),
      ],
    );
  }

  Future<Money> _loadTotalPayable(String companyId, {String? projectId}) async {
    final supplier = await _sum(
        companyId, 'material_purchases', 'pending_amount_paise',
        projectId: projectId);
    final labor = await _sum(
        companyId, 'labor_work_entries', 'pending_amount_paise',
        projectId: projectId);
    final machinery = await _sum(
        companyId, 'machine_usage_entries', 'pending_amount_paise',
        projectId: projectId);
    final fuel = await _sum(companyId, 'fuel_entries', 'pending_amount_paise',
        projectId: projectId);
    final repair = await _sum(
        companyId, 'machine_repair_entries', 'pending_amount_paise',
        projectId: projectId);
    final other = await _sum(
        companyId, 'project_expenses', 'pending_amount_paise',
        projectId: projectId);
    return supplier + labor + machinery + fuel + repair + other;
  }

  Future<Money> _latestEstimateTotal(String companyId,
      {String? projectId}) async {
    final scope = _projectReadScope(projectId, column: 'estimate.project_id');
    final row = await database.customSelect(
      '''
      SELECT COALESCE(SUM(estimate.total_estimated_cost_paise), 0) AS total
      FROM project_estimates estimate
      WHERE estimate.company_id = ? AND estimate.is_deleted = 0 ${scope.sql}
        AND NOT EXISTS (
          SELECT 1 FROM project_estimates newer
          WHERE newer.company_id = estimate.company_id
            AND newer.project_id = estimate.project_id
            AND newer.is_deleted = 0
            AND (newer.estimate_date > estimate.estimate_date
              OR (newer.estimate_date = estimate.estimate_date
                AND newer.updated_at > estimate.updated_at))
        );
      ''',
      variables: [
        Variable<String>(companyId),
        ...scope.variables,
      ],
    ).getSingle();
    return Money.fromPaise(row.data['total'] as int? ?? 0);
  }

  Future<Money> _projectMoney(
      String companyId, String projectId, String columnName) async {
    final row = await database.customSelect(
      '''
      SELECT $columnName AS amount
      FROM projects
      WHERE company_id = ? AND id = ? AND is_deleted = 0
      LIMIT 1;
      ''',
      variables: [Variable<String>(companyId), Variable<String>(projectId)],
    ).getSingleOrNull();
    return Money.fromPaise(row?.data['amount'] as int? ?? 0);
  }

  Future<Money> _sum(String companyId, String tableName, String columnName,
      {String? projectId, String projectColumn = 'project_id'}) async {
    final scope = _projectReadScope(projectId, column: projectColumn);
    final row = await database.customSelect(
      '''
      SELECT COALESCE(SUM($columnName), 0) AS total
      FROM $tableName
      WHERE company_id = ? AND is_deleted = 0 ${scope.sql};
      ''',
      variables: [
        Variable<String>(companyId),
        ...scope.variables,
      ],
    ).getSingle();
    return Money.fromPaise(row.data['total'] as int? ?? 0);
  }

  Future<Money> _sumWithType(String companyId, String tableName,
      String columnName, String typeColumn, String typeValue,
      {String? projectId}) async {
    final scope = _projectReadScope(projectId);
    final row = await database.customSelect(
      '''
      SELECT COALESCE(SUM($columnName), 0) AS total
      FROM $tableName
      WHERE company_id = ? AND is_deleted = 0 AND $typeColumn = ? ${scope.sql};
      ''',
      variables: [
        Variable<String>(companyId),
        Variable<String>(typeValue),
        ...scope.variables,
      ],
    ).getSingle();
    return Money.fromPaise(row.data['total'] as int? ?? 0);
  }

  _ProjectReadScope _projectReadScope(
    String? projectId, {
    String column = 'project_id',
  }) {
    if (projectId != null) {
      if (!_writeGuard.canAccessProject(projectId)) {
        return const _ProjectReadScope('AND 1 = 0', <Variable<String>>[]);
      }
      return _ProjectReadScope(
        'AND $column = ?',
        <Variable<String>>[Variable<String>(projectId)],
      );
    }
    if (_writeGuard.canAccessAllProjects) {
      return const _ProjectReadScope('', <Variable<String>>[]);
    }
    final ids = _writeGuard.allowedProjectIds;
    if (ids.isEmpty) {
      return const _ProjectReadScope('AND 1 = 0', <Variable<String>>[]);
    }
    final placeholders = List<String>.filled(ids.length, '?').join(', ');
    return _ProjectReadScope(
      'AND $column IN ($placeholders)',
      ids.map(Variable<String>.new).toList(growable: false),
    );
  }

  Future<List<EstimateItemRecord>> _listEstimateItems(
      String companyId, String estimateId) async {
    final rows = await database.customSelect(
      '''
      SELECT *
      FROM project_estimate_items
      WHERE company_id = ? AND estimate_id = ? AND is_deleted = 0
      ORDER BY created_at ASC;
      ''',
      variables: [Variable<String>(companyId), Variable<String>(estimateId)],
    ).get();
    return rows.map(_estimateItemFromRow).toList(growable: false);
  }

  Future<void> _queueDelta({
    required WriteContext context,
    required int now,
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) async {
    await LocalDeltaWriter.queue(
      database: database,
      context: context,
      createdAt: now,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      fallbackPayload: payload,
    );
  }

  ProjectEstimateRecord _copyEstimateWithItems(
      ProjectEstimateRecord estimate, List<EstimateItemRecord> items) {
    return ProjectEstimateRecord(
      id: estimate.id,
      companyId: estimate.companyId,
      projectId: estimate.projectId,
      estimateNumber: estimate.estimateNumber,
      estimateDate: estimate.estimateDate,
      title: estimate.title,
      totalEstimatedMaterialCost: estimate.totalEstimatedMaterialCost,
      totalEstimatedLaborCost: estimate.totalEstimatedLaborCost,
      totalEstimatedMachineryCost: estimate.totalEstimatedMachineryCost,
      totalEstimatedOtherCost: estimate.totalEstimatedOtherCost,
      totalEstimatedCost: estimate.totalEstimatedCost,
      estimatedProfit: estimate.estimatedProfit,
      notes: estimate.notes,
      items: items,
    );
  }

  ProjectEstimateRecord _estimateFromRow(QueryRow row) {
    return ProjectEstimateRecord(
      id: row.data['id'] as String,
      companyId: row.data['company_id'] as String,
      projectId: row.data['project_id'] as String,
      estimateNumber: row.data['estimate_number'] as String?,
      estimateDate: row.data['estimate_date'] as int,
      title: row.data['title'] as String? ?? 'Estimate',
      totalEstimatedMaterialCost: Money.fromPaise(
          row.data['total_estimated_material_cost_paise'] as int),
      totalEstimatedLaborCost:
          Money.fromPaise(row.data['total_estimated_labor_cost_paise'] as int),
      totalEstimatedMachineryCost: Money.fromPaise(
          row.data['total_estimated_machinery_cost_paise'] as int),
      totalEstimatedOtherCost:
          Money.fromPaise(row.data['total_estimated_other_cost_paise'] as int),
      totalEstimatedCost:
          Money.fromPaise(row.data['total_estimated_cost_paise'] as int),
      estimatedProfit:
          Money.fromPaise(row.data['estimated_profit_paise'] as int),
      notes: row.data['notes'] as String?,
    );
  }

  EstimateItemRecord _estimateItemFromRow(QueryRow row) {
    return EstimateItemRecord(
      id: row.data['id'] as String,
      estimateId: row.data['estimate_id'] as String,
      itemName: row.data['item_name'] as String,
      description: row.data['description'] as String?,
      unit: row.data['unit'] as String? ?? 'piece',
      quantity: DecimalQuantity.parse(row.data['quantity_decimal'] as String),
      rate: Money.fromPaise(row.data['rate_paise'] as int),
      amount: Money.fromPaise(row.data['amount_paise'] as int),
    );
  }

  ProjectBillRecord _billFromRow(QueryRow row) {
    return ProjectBillRecord(
      id: row.data['id'] as String,
      companyId: row.data['company_id'] as String,
      projectId: row.data['project_id'] as String,
      billNumber: row.data['bill_number'] as String,
      billDate: row.data['bill_date'] as int,
      billType: BillType.fromValue(row.data['bill_type'] as String),
      grossBillAmount:
          Money.fromPaise(row.data['gross_bill_amount_paise'] as int),
      gstRateBasisPoints: row.data['gst_rate_basis_points'] as int,
      gstAmount: Money.fromPaise(row.data['gst_amount_paise'] as int),
      totalBillAmount:
          Money.fromPaise(row.data['total_bill_amount_paise'] as int),
      tdsAmount: Money.fromPaise(row.data['tds_amount_paise'] as int),
      retentionAmount:
          Money.fromPaise(row.data['retention_amount_paise'] as int),
      otherDeductionAmount:
          Money.fromPaise(row.data['other_deduction_amount_paise'] as int),
      netReceivableAmount:
          Money.fromPaise(row.data['net_receivable_amount_paise'] as int),
      receivedAmount: Money.fromPaise(row.data['received_amount_paise'] as int),
      pendingAmount: Money.fromPaise(row.data['pending_amount_paise'] as int),
      status: BillStatus.fromValue(row.data['status'] as String),
      notes: row.data['notes'] as String?,
    );
  }

  GstEntryRecord _gstFromRow(QueryRow row) {
    return GstEntryRecord(
      id: row.data['id'] as String,
      companyId: row.data['company_id'] as String,
      projectId: row.data['project_id'] as String?,
      sourceType: GstSourceType.fromValue(row.data['source_type'] as String),
      sourceId: row.data['source_id'] as String,
      gstType: GstType.fromValue(row.data['gst_type'] as String),
      gstRateBasisPoints: row.data['gst_rate_basis_points'] as int,
      taxableAmount: Money.fromPaise(row.data['taxable_amount_paise'] as int),
      gstAmount: Money.fromPaise(row.data['gst_amount_paise'] as int),
      entryDate: row.data['entry_date'] as int,
      notes: row.data['notes'] as String?,
    );
  }

  void _validateEstimateItem(EstimateItemDraft item) {
    if (item.itemName.trim().isEmpty) {
      throw ArgumentError.value(
          item.itemName, 'itemName', 'Estimate item name is required.');
    }
    if (item.quantity.isZero || item.quantity.isNegative) {
      throw ArgumentError.value(
          item.quantity, 'quantity', 'Quantity must be greater than zero.');
    }
    _assertNonNegative('rate', item.rate);
  }

  void _assertNonNegative(String field, Money value) {
    if (value.paise < 0) {
      throw ArgumentError.value(value, field, '$field cannot be negative.');
    }
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class _ProjectReadScope {
  const _ProjectReadScope(this.sql, this.variables);

  final String sql;
  final List<Variable<String>> variables;
}
