import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/domain/write_context.dart';
import '../../../core/value_objects/money.dart';
import '../../../core/value_objects/quantity.dart';
import '../../../database/local_database.dart';
import '../../../database/schema/app_schema_sql.dart';
import '../domain/material_module_contract.dart';
import '../domain/material_records.dart';

class MaterialRepository implements MaterialModuleContract {
  MaterialRepository({
    required this.database,
    MaterialCalculator calculator = const MaterialCalculator(),
    Uuid uuid = const Uuid(),
  })  : _calculator = calculator,
        _uuid = uuid;

  final ConstructionDatabase database;
  final MaterialCalculator _calculator;
  final Uuid _uuid;

  @override
  String get moduleName => 'Material';

  @override
  String get phaseResponsibility =>
      'Phase 4: suppliers, material purchases, item totals, supplier payments, and pending amount tracking.';

  @override
  Future<String> createSupplier(
      SupplierDraft draft, WriteContext context) async {
    if (draft.supplierName.trim().isEmpty) {
      throw ArgumentError.value(
          draft.supplierName, 'supplierName', 'Supplier name is required.');
    }
    _assertNonNegative('openingBalance', draft.openingBalance);
    await database.ensureSchema();
    final id = _uuid.v4();
    final now = context.timestamp;
    await database.transaction(() async {
      await database.customStatement(
        '''
        INSERT INTO suppliers (
          id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
          is_deleted, sync_status, version, supplier_name, contact_person, phone,
          gst_number, address, opening_balance_paise, notes
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          Variable<String>(id),
          Variable<String>(context.companyId),
          Variable<int>(now),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.userId),
          Variable<String>(draft.supplierName.trim()),
          Variable<String>(_clean(draft.contactPerson)),
          Variable<String>(_clean(draft.phone)),
          Variable<String>(_clean(draft.gstNumber)),
          Variable<String>(_clean(draft.address)),
          Variable<int>(draft.openingBalance.paise),
          Variable<String>(_clean(draft.notes)),
        ],
      );
      await _queueDelta(
        context: context,
        now: now,
        entityType: 'suppliers',
        entityId: id,
        operation: 'insert',
        payload: {'id': id, ...draft.toPayload(), ...context.toAuditJson()},
      );
    });
    return id;
  }

  @override
  Future<List<SupplierRecord>> listSuppliers(String companyId) async {
    await database.ensureSchema();
    final rows = await database.customSelect(
      '''
      SELECT *
      FROM suppliers
      WHERE company_id = ? AND is_deleted = 0
      ORDER BY supplier_name COLLATE NOCASE;
      ''',
      variables: [Variable<String>(companyId)],
    ).get();
    return rows.map(_supplierFromRow).toList(growable: false);
  }

  @override
  Future<String> createPurchase(
      MaterialPurchaseDraft draft, WriteContext context) async {
    if (draft.projectId.trim().isEmpty) {
      throw ArgumentError.value(
          draft.projectId, 'projectId', 'Project is required.');
    }
    for (final item in draft.items) {
      _validateItem(item);
    }
    final totals = _calculator.calculatePurchase(draft.items, draft.paidAmount);
    await database.ensureSchema();
    final purchaseId = _uuid.v4();
    final now = context.timestamp;
    await database.transaction(() async {
      await database.customStatement(
        '''
        INSERT INTO material_purchases (
          id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
          is_deleted, sync_status, version, project_id, supplier_id, purchase_date,
          bill_number, invoice_number, vehicle_number, delivery_location,
          total_before_tax_paise, gst_amount_paise, total_amount_paise,
          paid_amount_paise, pending_amount_paise, payment_status, notes, bill_image_path
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          Variable<String>(purchaseId),
          Variable<String>(context.companyId),
          Variable<int>(now),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.userId),
          Variable<String>(draft.projectId),
          Variable<String>(_clean(draft.supplierId)),
          Variable<int>(draft.purchaseDate),
          Variable<String>(_clean(draft.billNumber)),
          Variable<String>(_clean(draft.invoiceNumber)),
          Variable<String>(_clean(draft.vehicleNumber)),
          Variable<String>(_clean(draft.deliveryLocation)),
          Variable<int>(totals.totalBeforeTax.paise),
          Variable<int>(totals.gstAmount.paise),
          Variable<int>(totals.totalAmount.paise),
          Variable<int>(totals.paidAmount.paise),
          Variable<int>(totals.pendingAmount.paise),
          Variable<String>(totals.paymentStatus.value),
          Variable<String>(_clean(draft.notes)),
          Variable<String>(_clean(draft.billImagePath)),
        ],
      );

      final itemPayloads = <Map<String, Object?>>[];
      for (final item in draft.items) {
        final itemId = _uuid.v4();
        final itemTotals = _calculator.calculateItem(item);
        await database.customStatement(
          '''
          INSERT INTO material_purchase_items (
            id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
            is_deleted, sync_status, version, purchase_id, project_id, material_name,
            details, unit, quantity_decimal, rate_paise, amount_paise,
            gst_rate_basis_points, gst_amount_paise, total_amount_paise
          ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
          ''',
          [
            Variable<String>(itemId),
            Variable<String>(context.companyId),
            Variable<int>(now),
            Variable<int>(now),
            Variable<String>(context.userId),
            Variable<String>(context.userId),
            Variable<String>(purchaseId),
            Variable<String>(draft.projectId),
            Variable<String>(item.materialName.trim()),
            Variable<String>(_clean(item.details)),
            Variable<String>(_clean(item.unit) ?? 'piece'),
            Variable<String>(item.quantity.toStorageString()),
            Variable<int>(item.rate.paise),
            Variable<int>(itemTotals.amount.paise),
            Variable<int>(item.gstRateBasisPoints),
            Variable<int>(itemTotals.gstAmount.paise),
            Variable<int>(itemTotals.totalAmount.paise),
          ],
        );
        itemPayloads.add({
          'id': itemId,
          'purchaseId': purchaseId,
          ...item.toPayload(
              amount: itemTotals.amount,
              gstAmount: itemTotals.gstAmount,
              totalAmount: itemTotals.totalAmount)
        });
      }

      await _queueDelta(
        context: context,
        now: now,
        entityType: 'material_purchases',
        entityId: purchaseId,
        operation: 'insert',
        payload: {
          'id': purchaseId,
          'projectId': draft.projectId,
          'supplierId': draft.supplierId,
          'purchaseDate': draft.purchaseDate,
          'totalBeforeTaxPaise': totals.totalBeforeTax.paise,
          'gstAmountPaise': totals.gstAmount.paise,
          'totalAmountPaise': totals.totalAmount.paise,
          'paidAmountPaise': totals.paidAmount.paise,
          'pendingAmountPaise': totals.pendingAmount.paise,
          'paymentStatus': totals.paymentStatus.value,
          'items': itemPayloads,
          ...context.toAuditJson(),
        },
      );
    });
    return purchaseId;
  }

  @override
  Future<List<MaterialPurchaseRecord>> listPurchases(String companyId,
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
      FROM material_purchases
      WHERE company_id = ? AND is_deleted = 0 $whereProject
      ORDER BY purchase_date DESC, updated_at DESC;
      ''',
      variables: variables,
    ).get();
    final records = <MaterialPurchaseRecord>[];
    for (final row in rows) {
      final purchase = _purchaseFromRow(row);
      records.add(purchase
          .copyWithItems(await _listPurchaseItems(companyId, purchase.id)));
    }
    return records;
  }

  @override
  Future<String> recordSupplierPayment(
      SupplierPaymentDraft draft, WriteContext context) async {
    if (draft.amount.paise <= 0) {
      throw ArgumentError.value(
          draft.amount, 'amount', 'Payment amount must be greater than zero.');
    }
    await database.ensureSchema();
    final id = _uuid.v4();
    final now = context.timestamp;
    await database.transaction(() async {
      await database.customStatement(
        '''
        INSERT INTO supplier_payments (
          id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
          is_deleted, sync_status, version, supplier_id, project_id, purchase_id,
          payment_date, amount_paise, payment_mode, reference_number, notes
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          Variable<String>(id),
          Variable<String>(context.companyId),
          Variable<int>(now),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.userId),
          Variable<String>(draft.supplierId),
          Variable<String>(_clean(draft.projectId)),
          Variable<String>(_clean(draft.purchaseId)),
          Variable<int>(draft.paymentDate),
          Variable<int>(draft.amount.paise),
          Variable<String>(draft.paymentMode.value),
          Variable<String>(_clean(draft.referenceNumber)),
          Variable<String>(_clean(draft.notes)),
        ],
      );
      if (_clean(draft.purchaseId) != null) {
        await _applyPaymentToPurchase(draft.purchaseId!, draft.amount, context,
            now: now);
      } else {
        await _applyPaymentAcrossPurchases(draft, context, now: now);
      }
      await _queueDelta(
        context: context,
        now: now,
        entityType: 'supplier_payments',
        entityId: id,
        operation: 'insert',
        payload: {'id': id, ...draft.toPayload(), ...context.toAuditJson()},
      );
    });
    return id;
  }

  Future<void> _applyPaymentToPurchase(
      String purchaseId, Money amount, WriteContext context,
      {required int now}) async {
    final row = await database.customSelect(
      '''
      SELECT id, paid_amount_paise, total_amount_paise
      FROM material_purchases
      WHERE company_id = ? AND id = ? AND is_deleted = 0
      LIMIT 1;
      ''',
      variables: [
        Variable<String>(context.companyId),
        Variable<String>(purchaseId)
      ],
    ).getSingleOrNull();
    if (row == null) {
      throw StateError('Material purchase not found.');
    }
    final total = row.data['total_amount_paise'] as int;
    final currentPaid = row.data['paid_amount_paise'] as int;
    final newPaid = currentPaid + amount.paise;
    if (newPaid > total) {
      throw ArgumentError.value(
          amount, 'amount', 'Payment exceeds pending supplier amount.');
    }
    final pending = total - newPaid;
    final status = pending == 0
        ? MaterialPaymentStatus.paid
        : MaterialPaymentStatus.partial;
    await database.customStatement(
      '''
      UPDATE material_purchases
      SET paid_amount_paise = ?, pending_amount_paise = ?, payment_status = ?,
          updated_at = ?, updated_by_user_id = ?, sync_status = 'pendingUpload', version = version + 1
      WHERE company_id = ? AND id = ? AND is_deleted = 0;
      ''',
      [
        Variable<int>(newPaid),
        Variable<int>(pending),
        Variable<String>(status.value),
        Variable<int>(now),
        Variable<String>(context.userId),
        Variable<String>(context.companyId),
        Variable<String>(purchaseId),
      ],
    );
    await _queuePurchaseBalanceDelta(
      purchaseId: purchaseId,
      paidPaise: newPaid,
      pendingPaise: pending,
      status: status,
      context: context,
      now: now,
    );
  }

  Future<void> _applyPaymentAcrossPurchases(
      SupplierPaymentDraft draft, WriteContext context,
      {required int now}) async {
    final projectFilter = draft.projectId == null ? '' : 'AND project_id = ?';
    final rows = await database.customSelect(
      '''
      SELECT id, paid_amount_paise, pending_amount_paise
      FROM material_purchases
      WHERE company_id = ? AND supplier_id = ? AND is_deleted = 0
        AND pending_amount_paise > 0 $projectFilter
      ORDER BY purchase_date, created_at, id;
      ''',
      variables: [
        Variable<String>(context.companyId),
        Variable<String>(draft.supplierId),
        if (draft.projectId != null) Variable<String>(draft.projectId!),
      ],
    ).get();
    final available = rows.fold<int>(
        0, (total, row) => total + row.read<int>('pending_amount_paise'));
    if (draft.amount.paise > available) {
      throw ArgumentError.value(draft.amount, 'amount',
          'Payment exceeds the selected outstanding supplier balance.');
    }

    var remaining = draft.amount.paise;
    for (final row in rows) {
      if (remaining == 0) {
        break;
      }
      final purchaseId = row.read<String>('id');
      final currentPaid = row.read<int>('paid_amount_paise');
      final currentPending = row.read<int>('pending_amount_paise');
      final applied = remaining < currentPending ? remaining : currentPending;
      final paid = currentPaid + applied;
      final pending = currentPending - applied;
      final status = pending == 0
          ? MaterialPaymentStatus.paid
          : MaterialPaymentStatus.partial;
      await database.customStatement(
        '''
        UPDATE material_purchases
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
          Variable<String>(purchaseId),
        ],
      );
      await _queuePurchaseBalanceDelta(
        purchaseId: purchaseId,
        paidPaise: paid,
        pendingPaise: pending,
        status: status,
        context: context,
        now: now,
      );
      remaining -= applied;
    }
  }

  Future<void> _queuePurchaseBalanceDelta({
    required String purchaseId,
    required int paidPaise,
    required int pendingPaise,
    required MaterialPaymentStatus status,
    required WriteContext context,
    required int now,
  }) {
    return _queueDelta(
      context: context,
      now: now,
      entityType: 'material_purchases',
      entityId: purchaseId,
      operation: 'update',
      payload: {
        'id': purchaseId,
        'paidAmountPaise': paidPaise,
        'pendingAmountPaise': pendingPaise,
        'paymentStatus': status.value,
        ...context.toAuditJson(),
      },
    );
  }

  Future<List<MaterialPurchaseItemRecord>> _listPurchaseItems(
      String companyId, String purchaseId) async {
    final rows = await database.customSelect(
      '''
      SELECT *
      FROM material_purchase_items
      WHERE company_id = ? AND purchase_id = ? AND is_deleted = 0
      ORDER BY material_name COLLATE NOCASE;
      ''',
      variables: [Variable<String>(companyId), Variable<String>(purchaseId)],
    ).get();
    return rows.map(_itemFromRow).toList(growable: false);
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

  void _validateItem(MaterialPurchaseItemDraft item) {
    if (item.materialName.trim().isEmpty) {
      throw ArgumentError.value(
          item.materialName, 'materialName', 'Material name is required.');
    }
    if (item.quantity.isZero || item.quantity.isNegative) {
      throw ArgumentError.value(
          item.quantity, 'quantity', 'Quantity must be greater than zero.');
    }
    _assertNonNegative('rate', item.rate);
    if (item.gstRateBasisPoints < 0) {
      throw ArgumentError.value(item.gstRateBasisPoints, 'gstRateBasisPoints',
          'GST rate cannot be negative.');
    }
  }

  void _assertNonNegative(String field, Money value) {
    if (value.paise < 0) {
      throw ArgumentError.value(value, field, '$field cannot be negative.');
    }
  }

  SupplierRecord _supplierFromRow(QueryRow row) {
    return SupplierRecord(
      id: row.data['id'] as String,
      companyId: row.data['company_id'] as String,
      supplierName: row.data['supplier_name'] as String,
      contactPerson: row.data['contact_person'] as String?,
      phone: row.data['phone'] as String?,
      gstNumber: row.data['gst_number'] as String?,
      address: row.data['address'] as String?,
      openingBalance: Money.fromPaise(row.data['opening_balance_paise'] as int),
      notes: row.data['notes'] as String?,
    );
  }

  MaterialPurchaseRecord _purchaseFromRow(QueryRow row) {
    return MaterialPurchaseRecord(
      id: row.data['id'] as String,
      companyId: row.data['company_id'] as String,
      projectId: row.data['project_id'] as String,
      supplierId: row.data['supplier_id'] as String?,
      purchaseDate: row.data['purchase_date'] as int,
      billNumber: row.data['bill_number'] as String?,
      invoiceNumber: row.data['invoice_number'] as String?,
      vehicleNumber: row.data['vehicle_number'] as String?,
      deliveryLocation: row.data['delivery_location'] as String?,
      totalBeforeTax:
          Money.fromPaise(row.data['total_before_tax_paise'] as int),
      gstAmount: Money.fromPaise(row.data['gst_amount_paise'] as int),
      totalAmount: Money.fromPaise(row.data['total_amount_paise'] as int),
      paidAmount: Money.fromPaise(row.data['paid_amount_paise'] as int),
      pendingAmount: Money.fromPaise(row.data['pending_amount_paise'] as int),
      paymentStatus:
          MaterialPaymentStatus.fromValue(row.data['payment_status'] as String),
      notes: row.data['notes'] as String?,
      billImagePath: row.data['bill_image_path'] as String?,
    );
  }

  MaterialPurchaseItemRecord _itemFromRow(QueryRow row) {
    return MaterialPurchaseItemRecord(
      id: row.data['id'] as String,
      purchaseId: row.data['purchase_id'] as String,
      projectId: row.data['project_id'] as String,
      materialName: row.data['material_name'] as String,
      details: row.data['details'] as String?,
      unit: row.data['unit'] as String? ?? 'piece',
      quantity: DecimalQuantity.parse(row.data['quantity_decimal'] as String),
      rate: Money.fromPaise(row.data['rate_paise'] as int),
      amount: Money.fromPaise(row.data['amount_paise'] as int),
      gstRateBasisPoints: row.data['gst_rate_basis_points'] as int,
      gstAmount: Money.fromPaise(row.data['gst_amount_paise'] as int),
      totalAmount: Money.fromPaise(row.data['total_amount_paise'] as int),
    );
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

extension on MaterialPurchaseRecord {
  MaterialPurchaseRecord copyWithItems(List<MaterialPurchaseItemRecord> items) {
    return MaterialPurchaseRecord(
      id: id,
      companyId: companyId,
      projectId: projectId,
      supplierId: supplierId,
      purchaseDate: purchaseDate,
      billNumber: billNumber,
      invoiceNumber: invoiceNumber,
      vehicleNumber: vehicleNumber,
      deliveryLocation: deliveryLocation,
      totalBeforeTax: totalBeforeTax,
      gstAmount: gstAmount,
      totalAmount: totalAmount,
      paidAmount: paidAmount,
      pendingAmount: pendingAmount,
      paymentStatus: paymentStatus,
      notes: notes,
      billImagePath: billImagePath,
      items: items,
    );
  }
}
