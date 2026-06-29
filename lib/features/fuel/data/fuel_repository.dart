import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/domain/write_context.dart';
import '../../../core/value_objects/money.dart';
import '../../../core/value_objects/quantity.dart';
import '../../../database/local_database.dart';
import '../../../database/schema/app_schema_sql.dart';
import '../domain/fuel_module_contract.dart';
import '../domain/fuel_records.dart';

class FuelRepository implements FuelModuleContract {
  FuelRepository({
    required this.database,
    FuelCalculator calculator = const FuelCalculator(),
    Uuid uuid = const Uuid(),
  })  : _calculator = calculator,
        _uuid = uuid;

  final ConstructionDatabase database;
  final FuelCalculator _calculator;
  final Uuid _uuid;

  @override
  String get moduleName => 'Fuel';

  @override
  String get phaseResponsibility =>
      'Phase 4: diesel, petrol, and custom fuel types/entries linked to machinery, labor, transport, or general project work.';

  @override
  Future<String> createFuelType(
      FuelTypeDraft draft, WriteContext context) async {
    if (draft.name.trim().isEmpty) {
      throw ArgumentError.value(
          draft.name, 'name', 'Fuel type name is required.');
    }
    if (draft.defaultRate.paise < 0) {
      throw ArgumentError.value(draft.defaultRate, 'defaultRate',
          'Default fuel rate cannot be negative.');
    }
    await database.ensureSchema();
    final id = _uuid.v4();
    final now = context.timestamp;
    await database.transaction(() async {
      await database.customStatement(
        '''
        INSERT INTO fuel_types (
          id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
          is_deleted, sync_status, version, name, unit, default_rate_paise
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?);
        ''',
        [
          Variable<String>(id),
          Variable<String>(context.companyId),
          Variable<int>(now),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.userId),
          Variable<String>(draft.name.trim()),
          Variable<String>(_clean(draft.unit) ?? 'liter'),
          Variable<int>(draft.defaultRate.paise),
        ],
      );
      await _queueDelta(
        context: context,
        now: now,
        entityType: 'fuel_types',
        entityId: id,
        operation: 'insert',
        payload: {'id': id, ...draft.toPayload(), ...context.toAuditJson()},
      );
    });
    return id;
  }

  @override
  Future<List<FuelTypeRecord>> listFuelTypes(String companyId) async {
    await database.ensureSchema();
    final rows = await database.customSelect(
      '''
      SELECT *
      FROM fuel_types
      WHERE company_id = ? AND is_deleted = 0
      ORDER BY name COLLATE NOCASE;
      ''',
      variables: [Variable<String>(companyId)],
    ).get();
    return rows.map(_fuelTypeFromRow).toList(growable: false);
  }

  @override
  Future<String> createFuelEntry(
      FuelEntryDraft draft, WriteContext context) async {
    if (draft.projectId.trim().isEmpty || draft.fuelTypeId.trim().isEmpty) {
      throw ArgumentError('Project and fuel type are required.');
    }
    if (draft.usedForType == FuelUsedForType.machinery &&
        _clean(draft.machineId) == null) {
      throw ArgumentError.value(draft.machineId, 'machineId',
          'Machine is required when fuel is used for machinery.');
    }
    final totals = _calculator.calculateEntry(draft);
    await database.ensureSchema();
    final id = _uuid.v4();
    final now = context.timestamp;
    await database.transaction(() async {
      await database.customStatement(
        '''
        INSERT INTO fuel_entries (
          id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
          is_deleted, sync_status, version, project_id, fuel_date, fuel_type_id,
          quantity_decimal, rate_paise, total_amount_paise, used_for_type,
          machine_id, labor_id, supplier_id, vehicle_name, description,
          paid_amount_paise, pending_amount_paise, payment_status, notes
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          Variable<String>(id),
          Variable<String>(context.companyId),
          Variable<int>(now),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.userId),
          Variable<String>(draft.projectId),
          Variable<int>(draft.fuelDate),
          Variable<String>(draft.fuelTypeId),
          Variable<String>(draft.quantity.toStorageString()),
          Variable<int>(draft.rate.paise),
          Variable<int>(totals.totalAmount.paise),
          Variable<String>(draft.usedForType.value),
          Variable<String>(_clean(draft.machineId)),
          Variable<String>(_clean(draft.laborId)),
          Variable<String>(_clean(draft.supplierId)),
          Variable<String>(_clean(draft.vehicleName)),
          Variable<String>(_clean(draft.description)),
          Variable<int>(draft.paidAmount.paise),
          Variable<int>(totals.pendingAmount.paise),
          Variable<String>(totals.paymentStatus.value),
          Variable<String>(_clean(draft.notes)),
        ],
      );
      await _queueDelta(
        context: context,
        now: now,
        entityType: 'fuel_entries',
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
  Future<List<FuelEntryRecord>> listFuelEntries(String companyId,
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
      FROM fuel_entries
      WHERE company_id = ? AND is_deleted = 0 $whereProject
      ORDER BY fuel_date DESC, updated_at DESC;
      ''',
      variables: variables,
    ).get();
    return rows.map(_fuelEntryFromRow).toList(growable: false);
  }

  @override
  Future<void> updateFuelEntry(
      String id, FuelEntryDraft draft, WriteContext context) async {
    if (draft.projectId.trim().isEmpty || draft.fuelTypeId.trim().isEmpty) {
      throw ArgumentError('Project and fuel type are required.');
    }
    if (draft.usedForType == FuelUsedForType.machinery &&
        _clean(draft.machineId) == null) {
      throw ArgumentError('Machine is required for machinery fuel.');
    }
    final totals = _calculator.calculateEntry(draft);
    await database.ensureSchema();
    await database.transaction(() async {
      final changed = await database.customUpdate('''
        UPDATE fuel_entries SET project_id = ?, fuel_date = ?, fuel_type_id = ?,
          quantity_decimal = ?, rate_paise = ?, total_amount_paise = ?,
          used_for_type = ?, machine_id = ?, labor_id = ?, supplier_id = ?,
          vehicle_name = ?, description = ?, paid_amount_paise = ?,
          pending_amount_paise = ?, payment_status = ?, notes = ?,
          updated_at = ?, updated_by_user_id = ?, sync_status = 'pendingUpload',
          version = version + 1
        WHERE id = ? AND company_id = ? AND is_deleted = 0;
      ''', variables: [
        Variable<String>(draft.projectId),
        Variable<int>(draft.fuelDate),
        Variable<String>(draft.fuelTypeId),
        Variable<String>(draft.quantity.toStorageString()),
        Variable<int>(draft.rate.paise),
        Variable<int>(totals.totalAmount.paise),
        Variable<String>(draft.usedForType.value),
        Variable<String>(_clean(draft.machineId)),
        Variable<String>(_clean(draft.laborId)),
        Variable<String>(_clean(draft.supplierId)),
        Variable<String>(_clean(draft.vehicleName)),
        Variable<String>(_clean(draft.description)),
        Variable<int>(draft.paidAmount.paise),
        Variable<int>(totals.pendingAmount.paise),
        Variable<String>(totals.paymentStatus.value),
        Variable<String>(_clean(draft.notes)),
        Variable<int>(context.timestamp),
        Variable<String>(context.userId),
        Variable<String>(id),
        Variable<String>(context.companyId),
      ]);
      if (changed != 1) throw StateError('Fuel entry not found.');
      await _queueDelta(
        context: context,
        now: context.timestamp,
        entityType: 'fuel_entries',
        entityId: id,
        operation: 'update',
        payload: {
          'id': id,
          ...draft.toPayload(
              totalAmount: totals.totalAmount,
              pendingAmount: totals.pendingAmount,
              paymentStatus: totals.paymentStatus),
          ...context.toAuditJson(),
        },
      );
    });
  }

  @override
  Future<void> deleteFuelEntry(String id, WriteContext context) async {
    await database.ensureSchema();
    await database.transaction(() async {
      final changed = await database.customUpdate('''
        UPDATE fuel_entries SET is_deleted = 1, updated_at = ?,
          updated_by_user_id = ?, sync_status = 'pendingUpload',
          version = version + 1
        WHERE id = ? AND company_id = ? AND is_deleted = 0;
      ''', variables: [
        Variable<int>(context.timestamp),
        Variable<String>(context.userId),
        Variable<String>(id),
        Variable<String>(context.companyId),
      ]);
      if (changed != 1) throw StateError('Fuel entry not found.');
      await _queueDelta(
        context: context,
        now: context.timestamp,
        entityType: 'fuel_entries',
        entityId: id,
        operation: 'delete',
        payload: {'id': id, ...context.toAuditJson()},
      );
    });
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

  FuelTypeRecord _fuelTypeFromRow(QueryRow row) {
    return FuelTypeRecord(
      id: row.data['id'] as String,
      companyId: row.data['company_id'] as String,
      name: row.data['name'] as String,
      unit: row.data['unit'] as String,
      defaultRate: Money.fromPaise(row.data['default_rate_paise'] as int),
    );
  }

  FuelEntryRecord _fuelEntryFromRow(QueryRow row) {
    return FuelEntryRecord(
      id: row.data['id'] as String,
      companyId: row.data['company_id'] as String,
      projectId: row.data['project_id'] as String,
      fuelDate: row.data['fuel_date'] as int,
      fuelTypeId: row.data['fuel_type_id'] as String,
      quantity: DecimalQuantity.parse(row.data['quantity_decimal'] as String),
      rate: Money.fromPaise(row.data['rate_paise'] as int),
      totalAmount: Money.fromPaise(row.data['total_amount_paise'] as int),
      usedForType:
          FuelUsedForType.fromValue(row.data['used_for_type'] as String),
      machineId: row.data['machine_id'] as String?,
      laborId: row.data['labor_id'] as String?,
      supplierId: row.data['supplier_id'] as String?,
      vehicleName: row.data['vehicle_name'] as String?,
      description: row.data['description'] as String?,
      paidAmount: Money.fromPaise(row.data['paid_amount_paise'] as int),
      pendingAmount: Money.fromPaise(row.data['pending_amount_paise'] as int),
      paymentStatus:
          FuelPaymentStatus.fromValue(row.data['payment_status'] as String),
      notes: row.data['notes'] as String?,
    );
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
