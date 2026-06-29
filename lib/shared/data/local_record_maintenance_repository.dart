import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/domain/write_context.dart';
import '../../database/local_database.dart';
import '../../database/schema/app_schema_sql.dart';

class LocalRecordMaintenanceRepository {
  LocalRecordMaintenanceRepository(
      {required this.database, Uuid uuid = const Uuid()})
      : _uuid = uuid;

  final ConstructionDatabase database;
  final Uuid _uuid;

  static const _deletable = {
    'material_purchases',
    'labor_work_entries',
    'machine_usage_entries',
    'machine_repair_entries',
  };

  Future<void> softDelete(String table, String id, WriteContext context) async {
    if (!_deletable.contains(table)) {
      throw ArgumentError.value(table, 'table', 'Deletion is not supported.');
    }
    await database.ensureSchema();
    await database.transaction(() async {
      final changed = await database.customUpdate('''
        UPDATE $table SET is_deleted = 1, updated_at = ?,
          updated_by_user_id = ?, sync_status = 'pendingUpload',
          version = version + 1
        WHERE id = ? AND company_id = ? AND is_deleted = 0;
      ''', variables: [
        Variable<int>(context.timestamp),
        Variable<String>(context.userId),
        Variable<String>(id),
        Variable<String>(context.companyId),
      ]);
      if (changed != 1) throw StateError('Record not found.');
      if (table == 'material_purchases') {
        await database.customUpdate('''
          UPDATE material_purchase_items SET is_deleted = 1, updated_at = ?,
            updated_by_user_id = ?, sync_status = 'pendingUpload',
            version = version + 1
          WHERE purchase_id = ? AND company_id = ? AND is_deleted = 0;
        ''', variables: [
          Variable<int>(context.timestamp),
          Variable<String>(context.userId),
          Variable<String>(id),
          Variable<String>(context.companyId),
        ]);
      }
      await database.customStatement('''
        INSERT INTO sync_queue (
          id, company_id, created_at, updated_at, created_by_user_id,
          updated_by_user_id, is_deleted, sync_status, version, entity_type,
          entity_id, operation, payload_json, device_id, schema_version,
          status, error_message
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, 'delete', ?, ?, ?, 'pendingUpload', NULL);
      ''', [
        Variable<String>(_uuid.v4()),
        Variable<String>(context.companyId),
        Variable<int>(context.timestamp),
        Variable<int>(context.timestamp),
        Variable<String>(context.userId),
        Variable<String>(context.userId),
        Variable<String>(table),
        Variable<String>(id),
        Variable<String>(jsonEncode({'id': id, ...context.toAuditJson()})),
        Variable<String>(context.deviceId),
        Variable<int>(AppSchemaSql.schemaVersion),
      ]);
    });
  }
}
