import 'dart:convert';

import 'package:drift/drift.dart';

import '../../database/local_database.dart';
import '../domain/sync_delta.dart';
import '../domain/sync_entity_registry.dart';
import '../domain/sync_models.dart';
import '../services/sync_outbox_signal.dart';

class LocalSyncQueueRepository {
  LocalSyncQueueRepository({required ConstructionDatabase database})
      : _database = database;

  final ConstructionDatabase _database;
  final Map<String, Set<String>> _columnCache = {};

  ConstructionDatabase get database => _database;

  Future<void> queueDelta(SyncDelta delta) async {
    await _database.ensureSchema();
    await _writeQueue(delta, SyncStatuses.pendingUpload);
    SyncOutboxSignal.notify(delta.companyId);
  }

  Future<void> recordDownloadedDelta(SyncDelta delta) async {
    await _database.ensureSchema();
    await _writeQueue(delta, SyncStatuses.downloaded, replace: false);
  }

  Future<void> _writeQueue(
    SyncDelta delta,
    String status, {
    bool replace = true,
  }) async {
    final data = delta.toLocalMap(localStatus: status);
    await _database.customStatement('''
      INSERT ${replace ? 'OR REPLACE' : 'OR IGNORE'} INTO sync_queue (
        id, company_id, project_id, created_at, updated_at, created_by_user_id,
        updated_by_user_id, is_deleted, sync_status, version, entity_type,
        entity_id, operation, payload_json, base_version, new_version,
        device_id, schema_version, status, error_message
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      data['id'],
      data['company_id'],
      data['project_id'],
      data['created_at'],
      data['updated_at'],
      data['created_by_user_id'],
      data['updated_by_user_id'],
      data['is_deleted'],
      status,
      data['version'],
      data['entity_type'],
      data['entity_id'],
      data['operation'],
      data['payload_json'],
      data['base_version'],
      data['new_version'],
      data['device_id'],
      data['schema_version'],
      status,
      data['error_message'],
    ]);
  }

  Future<List<SyncDelta>> pendingUploadDeltas(
    String companyId, {
    int limit = 100,
  }) async {
    await _database.ensureSchema();
    final rows = await _database.customSelect('''
      SELECT * FROM sync_queue
      WHERE company_id = ? AND is_deleted = 0
        AND status IN ('pendingUpload', 'failed', 'uploading')
      ORDER BY created_at ASC, entity_type ASC, entity_id ASC,
        base_version ASC, new_version ASC
      LIMIT ?
    ''', variables: [Variable(companyId), Variable(limit)]).get();
    return rows
        .map((row) => SyncDelta.fromLocalMap(row.data))
        .toList(growable: false);
  }

  Future<int> pendingUploadCount(String companyId) async {
    await _database.ensureSchema();
    final row = await _database.customSelect('''
      SELECT COUNT(*) AS c FROM sync_queue
      WHERE company_id = ? AND is_deleted = 0
        AND status IN ('pendingUpload', 'failed', 'uploading')
    ''', variables: [Variable(companyId)]).getSingle();
    return _int(row.data['c']);
  }

  Future<SyncDelta> canonicalizeForUpload(SyncDelta queued) async {
    Map<String, Object?>? queuedPayload;
    try {
      final decoded = jsonDecode(queued.payloadJson);
      if (decoded is Map<String, dynamic> &&
          decoded.containsKey('company_id') &&
          decoded.containsKey('version')) {
        queuedPayload = Map<String, Object?>.from(decoded);
      }
    } catch (_) {
      // Legacy queue payloads are rebuilt from the current local row below.
    }
    final row =
        queuedPayload ?? await localRecord(queued.entityType, queued.entityId);
    if (row == null) {
      throw StateError(
        'Local ${queued.entityType} record ${queued.entityId} was not found.',
      );
    }
    final version = _int(row['version']);
    final baseVersion = queuedPayload == null
        ? (queued.operation == SyncOperations.insert
            ? 0
            : (version > 0 ? version - 1 : 0))
        : queued.baseVersion;
    String? projectId = SyncEntityRegistry.projectIdFromMap(
      queued.entityType,
      row,
    );
    if (projectId == null &&
        SyncEntityRegistry.normalize(queued.entityType) ==
            'project_estimate_items') {
      final estimateId = row['estimate_id']?.toString();
      if (estimateId != null) {
        final parent = await _database.customSelect(
          'SELECT project_id FROM project_estimates WHERE id = ? LIMIT 1',
          variables: [Variable(estimateId)],
        ).getSingleOrNull();
        projectId = parent?.data['project_id']?.toString();
      }
    }
    final canonical = queued.copyWith(
      payloadJson: jsonEncode(row),
      baseVersion: baseVersion,
      newVersion: version == 0 ? 1 : version,
      projectId: projectId,
      errorMessage: '',
    );
    await _writeQueue(canonical, SyncStatuses.pendingUpload);
    return canonical;
  }

  Future<void> markStatus(
    String deltaId,
    String status, {
    String? errorMessage,
  }) async {
    await _database.ensureSchema();
    await _database.customStatement('''
      UPDATE sync_queue
      SET status = ?, sync_status = ?, error_message = ?, updated_at = ?
      WHERE id = ?
    ''', [
      status,
      status,
      errorMessage,
      DateTime.now().millisecondsSinceEpoch,
      deltaId,
    ]);
  }

  Future<void> markEntityUploaded(SyncDelta delta) async {
    final config = SyncEntityRegistry.requireConfig(delta.entityType);
    await _database.customStatement('''
      UPDATE ${config.tableName} SET sync_status = 'uploaded'
      WHERE id = ? AND ${config.tableName == 'companies' ? 'id' : 'company_id'} = ?
        AND version = ?
    ''', [delta.entityId, delta.companyId, delta.newVersion]);
  }

  Future<bool> isDeltaApplied(String companyId, String deltaId) async {
    await _database.ensureSchema();
    final row = await _database.customSelect('''
      SELECT COUNT(*) AS c FROM sync_deltas_applied
      WHERE company_id = ? AND delta_id = ? AND is_deleted = 0
    ''', variables: [Variable(companyId), Variable(deltaId)]).getSingle();
    return _int(row.data['c']) > 0;
  }

  Future<void> recordAppliedDelta(SyncDelta delta) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.customStatement('''
      INSERT OR IGNORE INTO sync_deltas_applied (
        id, company_id, created_at, updated_at, created_by_user_id,
        updated_by_user_id, is_deleted, sync_status, version, delta_id,
        entity_type, entity_id, operation, applied_at, device_id, source_user_id
      ) VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      delta.deltaId,
      delta.companyId,
      now,
      now,
      delta.createdByUserId,
      delta.createdByUserId,
      SyncStatuses.applied,
      delta.newVersion,
      delta.deltaId,
      delta.entityType,
      delta.entityId,
      delta.operation,
      now,
      delta.deviceId,
      delta.createdByUserId,
    ]);
  }

  Future<Map<String, Object?>?> localRecord(
    String entityType,
    String entityId,
  ) async {
    await _database.ensureSchema();
    final config = SyncEntityRegistry.requireConfig(entityType);
    final rows = await _database.customSelect(
      'SELECT * FROM ${config.tableName} WHERE id = ? LIMIT 1',
      variables: [Variable(entityId)],
    ).get();
    return rows.isEmpty ? null : rows.first.data;
  }

  Future<void> insertConflict({
    required SyncDelta delta,
    required Map<String, Object?>? localPayload,
    required String reason,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.customStatement('''
      INSERT OR REPLACE INTO sync_conflicts (
        id, company_id, project_id, created_at, updated_at, created_by_user_id,
        updated_by_user_id, is_deleted, sync_status, version, entity_type,
        entity_id, remote_delta_id, remote_operation, local_payload_json,
        remote_payload_json, local_version, remote_version, status, resolution
      ) VALUES (
        ?, ?, ?, ?, ?, ?, ?, 0,
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
      )
    ''', [
      '${delta.deltaId}_conflict',
      delta.companyId,
      delta.projectId,
      now,
      now,
      delta.createdByUserId,
      delta.createdByUserId,
      SyncStatuses.conflict,
      delta.newVersion,
      delta.entityType,
      delta.entityId,
      delta.deltaId,
      delta.operation,
      jsonEncode(localPayload ?? {}),
      delta.payloadJson,
      _int(localPayload?['version']),
      delta.newVersion,
      'open',
      reason,
    ]);
    await markStatus(delta.deltaId, SyncStatuses.conflict,
        errorMessage: reason);
  }

  Future<void> upsertRemotePayload(SyncDelta delta) async {
    final config = SyncEntityRegistry.requireConfig(delta.entityType);
    final decoded = jsonDecode(delta.payloadJson);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Remote payload is not a JSON object.');
    }
    final allowed = await _columns(config.tableName);
    final payload = <String, Object?>{
      for (final entry in decoded.entries)
        if (allowed.contains(entry.key)) entry.key: entry.value,
    };
    payload['id'] = delta.entityId;
    if (allowed.contains('company_id')) payload['company_id'] = delta.companyId;
    if (allowed.contains('version')) payload['version'] = delta.newVersion;
    if (allowed.contains('sync_status')) {
      payload['sync_status'] = delta.status == SyncStatuses.pendingUpload
          ? SyncStatuses.pendingUpload
          : SyncStatuses.applied;
    }
    if (allowed.contains('updated_at')) {
      payload['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    }
    if (allowed.contains('created_at')) {
      payload.putIfAbsent('created_at', () => delta.createdAt);
    }
    if (allowed.contains('is_deleted')) {
      payload.putIfAbsent('is_deleted', () => 0);
    }

    final columns = payload.keys.toList(growable: false);
    final updates = columns
        .where((column) => column != 'id' && column != 'created_at')
        .map((column) => '$column = excluded.$column')
        .join(', ');
    await _database.customStatement('''
      INSERT INTO ${config.tableName} (${columns.join(', ')})
      VALUES (${List.filled(columns.length, '?').join(', ')})
      ON CONFLICT(id) DO UPDATE SET $updates
    ''', columns.map((column) => payload[column]).toList(growable: false));
  }

  Future<void> softDeleteRemote(SyncDelta delta) async {
    final config = SyncEntityRegistry.requireConfig(delta.entityType);
    await _database.customStatement('''
      UPDATE ${config.tableName}
      SET is_deleted = 1, sync_status = ?, version = ?, updated_at = ?
      WHERE id = ? AND ${config.tableName == 'companies' ? 'id' : 'company_id'} = ?
    ''', [
      SyncStatuses.applied,
      delta.newVersion,
      DateTime.now().millisecondsSinceEpoch,
      delta.entityId,
      delta.companyId,
    ]);
  }

  Future<T> transaction<T>(Future<T> Function() action) =>
      _database.transaction(action);

  Future<String?> existingDeviceId(String companyId, String firebaseUid) async {
    await _database.ensureSchema();
    final row = await _database.customSelect('''
      SELECT device_id FROM device_registry
      WHERE company_id = ? AND firebase_uid = ? AND is_deleted = 0
      ORDER BY updated_at DESC LIMIT 1
    ''', variables: [
      Variable(companyId),
      Variable(firebaseUid)
    ]).getSingleOrNull();
    return row?.data['device_id']?.toString();
  }

  Future<void> upsertDevice({
    required String companyId,
    required String deviceId,
    required String firebaseUid,
    required String deviceName,
    required String platform,
    bool synced = false,
  }) async {
    await _database.ensureSchema();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.customStatement('''
      INSERT INTO device_registry (
        id, company_id, created_at, updated_at, created_by_user_id,
        updated_by_user_id, is_deleted, sync_status, version, device_id,
        firebase_uid, device_name, platform, last_sync_at, status
      ) VALUES (?, ?, ?, ?, ?, ?, 0, ?, 1, ?, ?, ?, ?, ?, 'active')
      ON CONFLICT(id) DO UPDATE SET
        updated_at = excluded.updated_at,
        firebase_uid = excluded.firebase_uid,
        device_name = excluded.device_name,
        platform = excluded.platform,
        last_sync_at = CASE WHEN excluded.last_sync_at IS NULL
          THEN device_registry.last_sync_at ELSE excluded.last_sync_at END,
        status = 'active'
    ''', [
      deviceId,
      companyId,
      now,
      now,
      firebaseUid,
      firebaseUid,
      SyncStatuses.applied,
      deviceId,
      firebaseUid,
      deviceName,
      platform,
      synced ? now : null,
    ]);
  }

  Future<void> markDeviceSynced(String companyId, String deviceId) async {
    await _database.customStatement('''
      UPDATE device_registry SET last_sync_at = ?, updated_at = ?
      WHERE company_id = ? AND device_id = ?
    ''', [
      DateTime.now().millisecondsSinceEpoch,
      DateTime.now().millisecondsSinceEpoch,
      companyId,
      deviceId,
    ]);
  }

  Future<SyncCounts> statusCounts(String companyId) async {
    await _database.ensureSchema();
    final row = await _database.customSelect('''
      SELECT
        SUM(CASE WHEN status IN ('pendingUpload','uploading') THEN 1 ELSE 0 END) AS pending,
        SUM(CASE WHEN status = 'uploaded' THEN 1 ELSE 0 END) AS uploaded,
        SUM(CASE WHEN status = 'downloaded' THEN 1 ELSE 0 END) AS downloaded,
        SUM(CASE WHEN status = 'applied' THEN 1 ELSE 0 END) AS applied,
        SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) AS failed
      FROM sync_queue WHERE company_id = ? AND is_deleted = 0
    ''', variables: [Variable(companyId)]).getSingle();
    final conflicts = await _database.customSelect('''
      SELECT COUNT(*) AS c FROM sync_conflicts
      WHERE company_id = ? AND status = 'open' AND is_deleted = 0
    ''', variables: [Variable(companyId)]).getSingle();
    final device = await _database.customSelect('''
      SELECT MAX(last_sync_at) AS last_sync FROM device_registry
      WHERE company_id = ? AND is_deleted = 0
    ''', variables: [Variable(companyId)]).getSingle();
    final errorRows = await _database.customSelect('''
      SELECT error_message FROM sync_queue
      WHERE company_id = ? AND error_message IS NOT NULL
        AND error_message != '' AND is_deleted = 0
      ORDER BY updated_at DESC LIMIT 5
    ''', variables: [Variable(companyId)]).get();
    final errors = errorRows
        .map((entry) => entry.data['error_message']?.toString() ?? '')
        .where((message) => message.isNotEmpty)
        .toList(growable: false);
    return SyncCounts(
      pendingUploads: _int(row.data['pending']),
      uploaded: _int(row.data['uploaded']),
      downloaded: _int(row.data['downloaded']),
      applied: _int(row.data['applied']),
      failed: _int(row.data['failed']),
      conflicts: _int(conflicts.data['c']),
      lastSyncAt: device.data['last_sync'] == null
          ? null
          : _int(device.data['last_sync']),
      errors: errors,
    );
  }

  Future<Set<String>> _columns(String tableName) async {
    final cached = _columnCache[tableName];
    if (cached != null) return cached;
    final rows =
        await _database.customSelect('PRAGMA table_info($tableName)').get();
    final columns = rows
        .map((row) => row.data['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();
    _columnCache[tableName] = columns;
    return columns;
  }

  int _int(Object? value) => value == null
      ? 0
      : value is int
          ? value
          : value is num
              ? value.toInt()
              : int.tryParse(value.toString()) ?? 0;
}
