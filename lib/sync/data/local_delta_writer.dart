import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/domain/write_context.dart';
import '../../database/local_database.dart';
import '../../database/schema/app_schema_sql.dart';
import '../domain/sync_entity_registry.dart';
import '../domain/sync_models.dart';

class LocalDeltaWriter {
  const LocalDeltaWriter._();

  static Future<void> queue({
    required ConstructionDatabase database,
    required WriteContext context,
    required int createdAt,
    required String entityType,
    required String entityId,
    required String operation,
    Map<String, Object?> fallbackPayload = const {},
  }) async {
    final config = SyncEntityRegistry.requireConfig(entityType);
    final row = await database.customSelect(
      'SELECT * FROM ${config.tableName} WHERE id = ? LIMIT 1',
      variables: [Variable(entityId)],
    ).getSingleOrNull();
    final payload = row?.data ??
        <String, Object?>{
          'id': entityId,
          ...fallbackPayload,
          ...context.toAuditJson(),
        };
    final version = _int(payload['version'], fallback: 1);
    final baseVersion = operation == SyncOperations.insert
        ? 0
        : version > 0
            ? version - 1
            : 0;
    await database.customStatement('''
      INSERT INTO sync_queue (
        id, company_id, created_at, updated_at, created_by_user_id,
        updated_by_user_id, is_deleted, sync_status, version, entity_type,
        entity_id, operation, payload_json, base_version, new_version,
        device_id, schema_version, status, error_message
      ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, ?, ?, 'pendingUpload', NULL)
    ''', [
      const Uuid().v4(),
      context.companyId,
      createdAt,
      createdAt,
      context.userId,
      context.userId,
      config.entityType,
      entityId,
      operation,
      jsonEncode(payload),
      baseVersion,
      version,
      context.deviceId,
      AppSchemaSql.schemaVersion,
    ]);
  }

  static int _int(Object? value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
