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
import '../domain/machinery_module_contract.dart';
import '../domain/machinery_records.dart';

class MachineryRepository implements MachineryModuleContract {
  MachineryRepository({
    required this.database,
    MachineryCalculator calculator = const MachineryCalculator(),
    RepositoryWriteGuard writeGuard = const AllowAllRepositoryWriteGuard(),
    Uuid uuid = const Uuid(),
  })  : _calculator = calculator,
        _writeGuard = writeGuard,
        _uuid = uuid;

  final ConstructionDatabase database;
  final MachineryCalculator _calculator;
  final RepositoryWriteGuard _writeGuard;
  final Uuid _uuid;

  @override
  String get moduleName => 'Machinery';

  @override
  String get phaseResponsibility =>
      'Phase 4: machine master, own/rental usage, rental payments, and repair entries.';

  @override
  Future<String> createMachine(MachineDraft draft, WriteContext context) async {
    _writeGuard.require(PermissionKey.machineryEntry);
    if (draft.machineName.trim().isEmpty) {
      throw ArgumentError.value(
          draft.machineName, 'machineName', 'Machine name is required.');
    }
    if (draft.ownershipType == MachineOwnershipType.rental &&
        _clean(draft.ownerName) == null) {
      throw ArgumentError.value(draft.ownerName, 'ownerName',
          'Owner name is required for rental machines.');
    }
    if (draft.defaultChargeRate.paise < 0) {
      throw ArgumentError.value(draft.defaultChargeRate, 'defaultChargeRate',
          'Default charge rate cannot be negative.');
    }
    await database.ensureSchema();
    final id = _uuid.v4();
    final now = context.timestamp;
    await database.transaction(() async {
      await database.customStatement(
        '''
        INSERT INTO machines (
          id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
          is_deleted, sync_status, version, machine_name, machine_type, ownership_type,
          owner_name, owner_phone, registration_number, default_charge_type,
          default_charge_rate_paise, notes
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          Variable<String>(id),
          Variable<String>(context.companyId),
          Variable<int>(now),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.userId),
          Variable<String>(draft.machineName.trim()),
          Variable<String>(_clean(draft.machineType)),
          Variable<String>(draft.ownershipType.value),
          Variable<String>(_clean(draft.ownerName)),
          Variable<String>(_clean(draft.ownerPhone)),
          Variable<String>(_clean(draft.registrationNumber)),
          Variable<String>(draft.defaultChargeType.value),
          Variable<int>(draft.defaultChargeRate.paise),
          Variable<String>(_clean(draft.notes)),
        ],
      );
      await _queueDelta(
        context: context,
        now: now,
        entityType: 'machines',
        entityId: id,
        operation: 'insert',
        payload: {'id': id, ...draft.toPayload(), ...context.toAuditJson()},
      );
    });
    return id;
  }

  Future<void> _applyPaymentToUsageEntries(
      MachineRentalPaymentDraft draft, WriteContext context,
      {required int now}) async {
    final projectFilter = draft.projectId == null ? '' : 'AND project_id = ?';
    final rows = await database.customSelect(
      '''
      SELECT id, paid_amount_paise, pending_amount_paise
      FROM machine_usage_entries
      WHERE company_id = ? AND machine_id = ? AND is_deleted = 0
        AND pending_amount_paise > 0 $projectFilter
      ORDER BY usage_date, created_at, id;
      ''',
      variables: [
        Variable<String>(context.companyId),
        Variable<String>(draft.machineId),
        if (draft.projectId != null) Variable<String>(draft.projectId!),
      ],
    ).get();
    final available = rows.fold<int>(
        0, (total, row) => total + row.read<int>('pending_amount_paise'));
    if (draft.amount.paise > available) {
      throw ArgumentError.value(draft.amount, 'amount',
          'Machine payment exceeds the selected outstanding balance.');
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
      final status = pending == 0
          ? MachinePaymentStatus.paid
          : MachinePaymentStatus.partial;
      await database.customStatement(
        '''
        UPDATE machine_usage_entries
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
        entityType: 'machine_usage_entries',
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
  Future<List<MachineRecord>> listMachines(String companyId) async {
    await database.ensureSchema();
    final rows = await database.customSelect(
      '''
      SELECT *
      FROM machines
      WHERE company_id = ? AND is_deleted = 0
      ORDER BY machine_name COLLATE NOCASE;
      ''',
      variables: [Variable<String>(companyId)],
    ).get();
    return rows.map(_machineFromRow).toList(growable: false);
  }

  @override
  Future<String> createUsageEntry(
      MachineUsageDraft draft, WriteContext context) async {
    _writeGuard.require(PermissionKey.machineryEntry,
        projectId: draft.projectId);
    if (draft.projectId.trim().isEmpty || draft.machineId.trim().isEmpty) {
      throw ArgumentError('Project and machine are required.');
    }
    final totals = _calculator.calculateUsage(draft);
    await database.ensureSchema();
    final id = _uuid.v4();
    final now = context.timestamp;
    await database.transaction(() async {
      await database.customStatement(
        '''
        INSERT INTO machine_usage_entries (
          id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
          is_deleted, sync_status, version, project_id, machine_id, usage_date,
          work_description, charge_type, hours_used_decimal, days_used_decimal,
          quantity_decimal, rate_paise, total_amount_paise, paid_amount_paise,
          pending_amount_paise, payment_status, notes
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          Variable<String>(id),
          Variable<String>(context.companyId),
          Variable<int>(now),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.userId),
          Variable<String>(draft.projectId),
          Variable<String>(draft.machineId),
          Variable<int>(draft.usageDate),
          Variable<String>(_clean(draft.workDescription)),
          Variable<String>(draft.chargeType.value),
          Variable<String>(draft.hoursUsed?.toStorageString()),
          Variable<String>(draft.daysUsed?.toStorageString()),
          Variable<String>(draft.quantity?.toStorageString()),
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
        entityType: 'machine_usage_entries',
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
  Future<List<MachineUsageRecord>> listUsageEntries(String companyId,
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
      FROM machine_usage_entries
      WHERE company_id = ? AND is_deleted = 0 $whereProject
      ORDER BY usage_date DESC, updated_at DESC;
      ''',
      variables: variables,
    ).get();
    return rows.map(_usageFromRow).toList(growable: false);
  }

  @override
  Future<String> recordRentalPayment(
      MachineRentalPaymentDraft draft, WriteContext context) async {
    _writeGuard.require(PermissionKey.machineryEntry,
        projectId: draft.projectId);
    if (draft.amount.paise <= 0) {
      throw ArgumentError.value(
          draft.amount, 'amount', 'Machine payment must be greater than zero.');
    }
    await database.ensureSchema();
    final id = _uuid.v4();
    final now = context.timestamp;
    await database.transaction(() async {
      await _applyPaymentToUsageEntries(draft, context, now: now);
      await database.customStatement(
        '''
        INSERT INTO machine_rental_payments (
          id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
          is_deleted, sync_status, version, machine_id, project_id, owner_name,
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
          Variable<String>(draft.machineId),
          Variable<String>(_clean(draft.projectId)),
          Variable<String>(_clean(draft.ownerName)),
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
        entityType: 'machine_rental_payments',
        entityId: id,
        operation: 'insert',
        payload: {
          'id': id,
          'machineId': draft.machineId,
          'projectId': draft.projectId,
          'ownerName': draft.ownerName,
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
  Future<String> recordRepair(
      MachineRepairDraft draft, WriteContext context) async {
    _writeGuard.require(PermissionKey.machineryEntry,
        projectId: draft.projectId);
    if (draft.machineId.trim().isEmpty) {
      throw ArgumentError.value(
          draft.machineId, 'machineId', 'Machine is required.');
    }
    final totals = _calculator.calculateRepair(draft);
    await database.ensureSchema();
    final id = _uuid.v4();
    final now = context.timestamp;
    await database.transaction(() async {
      await database.customStatement(
        '''
        INSERT INTO machine_repair_entries (
          id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
          is_deleted, sync_status, version, machine_id, project_id, repair_date,
          repair_description, mechanic_name, parts_cost_paise, labor_cost_paise,
          total_cost_paise, paid_amount_paise, pending_amount_paise, notes
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          Variable<String>(id),
          Variable<String>(context.companyId),
          Variable<int>(now),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.userId),
          Variable<String>(draft.machineId),
          Variable<String>(_clean(draft.projectId)),
          Variable<int>(draft.repairDate),
          Variable<String>(_clean(draft.repairDescription)),
          Variable<String>(_clean(draft.mechanicName)),
          Variable<int>(draft.partsCost.paise),
          Variable<int>(draft.laborCost.paise),
          Variable<int>(totals.totalCost.paise),
          Variable<int>(draft.paidAmount.paise),
          Variable<int>(totals.pendingAmount.paise),
          Variable<String>(_clean(draft.notes)),
        ],
      );
      await _queueDelta(
        context: context,
        now: now,
        entityType: 'machine_repair_entries',
        entityId: id,
        operation: 'insert',
        payload: {
          'id': id,
          ...draft.toPayload(
              totalCost: totals.totalCost, pendingAmount: totals.pendingAmount),
          ...context.toAuditJson()
        },
      );
    });
    return id;
  }

  @override
  Future<List<MachineRepairRecord>> listRepairs(String companyId,
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
      FROM machine_repair_entries
      WHERE company_id = ? AND is_deleted = 0 $whereProject
      ORDER BY repair_date DESC, updated_at DESC;
      ''',
      variables: variables,
    ).get();
    return rows.map(_repairFromRow).toList(growable: false);
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

  MachineRecord _machineFromRow(QueryRow row) {
    return MachineRecord(
      id: row.data['id'] as String,
      companyId: row.data['company_id'] as String,
      machineName: row.data['machine_name'] as String,
      machineType: row.data['machine_type'] as String?,
      ownershipType:
          MachineOwnershipType.fromValue(row.data['ownership_type'] as String),
      ownerName: row.data['owner_name'] as String?,
      ownerPhone: row.data['owner_phone'] as String?,
      registrationNumber: row.data['registration_number'] as String?,
      defaultChargeType: MachineChargeType.fromValue(
          row.data['default_charge_type'] as String?),
      defaultChargeRate:
          Money.fromPaise(row.data['default_charge_rate_paise'] as int),
      notes: row.data['notes'] as String?,
    );
  }

  MachineUsageRecord _usageFromRow(QueryRow row) {
    final hours = row.data['hours_used_decimal'] as String?;
    final days = row.data['days_used_decimal'] as String?;
    final quantity = row.data['quantity_decimal'] as String?;
    return MachineUsageRecord(
      id: row.data['id'] as String,
      companyId: row.data['company_id'] as String,
      projectId: row.data['project_id'] as String,
      machineId: row.data['machine_id'] as String,
      usageDate: row.data['usage_date'] as int,
      workDescription: row.data['work_description'] as String?,
      chargeType:
          MachineChargeType.fromValue(row.data['charge_type'] as String?),
      hoursUsed: hours == null ? null : DecimalQuantity.parse(hours),
      daysUsed: days == null ? null : DecimalQuantity.parse(days),
      quantity: quantity == null ? null : DecimalQuantity.parse(quantity),
      rate: Money.fromPaise(row.data['rate_paise'] as int),
      totalAmount: Money.fromPaise(row.data['total_amount_paise'] as int),
      paidAmount: Money.fromPaise(row.data['paid_amount_paise'] as int),
      pendingAmount: Money.fromPaise(row.data['pending_amount_paise'] as int),
      paymentStatus:
          MachinePaymentStatus.fromValue(row.data['payment_status'] as String),
      notes: row.data['notes'] as String?,
    );
  }

  MachineRepairRecord _repairFromRow(QueryRow row) {
    return MachineRepairRecord(
      id: row.data['id'] as String,
      companyId: row.data['company_id'] as String,
      machineId: row.data['machine_id'] as String,
      projectId: row.data['project_id'] as String?,
      repairDate: row.data['repair_date'] as int,
      repairDescription: row.data['repair_description'] as String?,
      mechanicName: row.data['mechanic_name'] as String?,
      partsCost: Money.fromPaise(row.data['parts_cost_paise'] as int),
      laborCost: Money.fromPaise(row.data['labor_cost_paise'] as int),
      totalCost: Money.fromPaise(row.data['total_cost_paise'] as int),
      paidAmount: Money.fromPaise(row.data['paid_amount_paise'] as int),
      pendingAmount: Money.fromPaise(row.data['pending_amount_paise'] as int),
      notes: row.data['notes'] as String?,
    );
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
