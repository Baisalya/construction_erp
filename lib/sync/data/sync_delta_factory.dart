import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../database/local_database.dart';
import '../../database/schema/app_schema_sql.dart';
import '../domain/sync_delta.dart';
import '../domain/sync_entity_registry.dart';
import '../domain/sync_models.dart';

class SyncDeltaFactory {
  SyncDeltaFactory({required ConstructionDatabase database, Uuid? uuid})
      : _database = database,
        _uuid = uuid ?? const Uuid();
  final ConstructionDatabase _database;
  final Uuid _uuid;

  Future<SyncDelta> createFromLocalRow(
      {required SyncContext context,
      required String entityType,
      required String entityId,
      required String operation,
      String? payloadJson}) async {
    final config = SyncEntityRegistry.requireConfig(entityType);
    final now = DateTime.now().millisecondsSinceEpoch;
    final rowPayload =
        payloadJson ?? await _payloadFor(config.tableName, entityId);
    final decoded = jsonDecode(rowPayload);
    final version = decoded is Map<String, dynamic>
        ? _int(decoded['version'], fallback: 1)
        : 1;
    final baseVersion = operation == SyncOperations.insert
        ? 0
        : version > 0
            ? version - 1
            : 0;
    return SyncDelta(
      deltaId: _uuid.v4(),
      companyId: context.companyId,
      entityType: config.entityType,
      entityId: entityId,
      operation: operation,
      payloadJson: rowPayload,
      baseVersion: baseVersion,
      newVersion: version,
      createdAt: now,
      createdByUserId: context.userId,
      deviceId: context.deviceId,
      schemaVersion: AppSchemaSql.schemaVersion,
      status: SyncStatuses.pendingUpload,
    );
  }

  Future<String> _payloadFor(String tableName, String entityId) async {
    if (!SyncEntityRegistry.isAllowedSqlIdentifier(tableName)) {
      throw ArgumentError.value(tableName, 'tableName', 'Unsafe table name');
    }
    final rows = await _database.customSelect(
        'SELECT * FROM $tableName WHERE id = ? LIMIT 1',
        variables: [Variable<String>(entityId)],
        readsFrom: const {}).get();
    if (rows.isEmpty) {
      return jsonEncode({'id': entityId, 'is_deleted': 1, 'version': 1});
    }
    return jsonEncode(rows.first.data);
  }

  int _int(Object? value, {required int fallback}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }
}
