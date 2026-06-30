import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../database/local_database.dart';
import '../../database/schema/app_schema_sql.dart';
import '../../features/auth/data/local_staff_access_repository.dart';
import '../data/local_sync_queue_repository.dart';
import '../domain/sync_conflict.dart';
import '../domain/sync_delta.dart';
import '../domain/sync_models.dart';

class ConflictResolutionService {
  ConflictResolutionService({
    required ConstructionDatabase database,
    required LocalSyncQueueRepository localQueue,
    required LocalStaffAccessRepository accessRepository,
    Uuid uuid = const Uuid(),
  })  : _database = database,
        _localQueue = localQueue,
        _accessRepository = accessRepository,
        _uuid = uuid;

  final ConstructionDatabase _database;
  final LocalSyncQueueRepository _localQueue;
  final LocalStaffAccessRepository _accessRepository;
  final Uuid _uuid;

  Future<List<SyncConflict>> openConflicts(SyncContext context) async {
    await _requireManager(context);
    await _database.ensureSchema();
    final rows = await _database.customSelect('''
      SELECT * FROM sync_conflicts
      WHERE company_id = ? AND status = 'open' AND is_deleted = 0
      ORDER BY created_at DESC
    ''', variables: [Variable(context.companyId)]).get();
    return rows.map((row) => _fromRow(row.data)).toList(growable: false);
  }

  Future<void> resolve({
    required SyncContext context,
    required String conflictId,
    required ConflictResolutionChoice choice,
    String? manualPayloadJson,
  }) async {
    await _requireManager(context);
    final conflict = await _loadOpen(context.companyId, conflictId);
    if (choice == ConflictResolutionChoice.manual &&
        (manualPayloadJson == null || manualPayloadJson.trim().isEmpty)) {
      throw ArgumentError('Manual merge JSON is required.');
    }

    final incoming = SyncDelta(
      deltaId: conflict.remoteDeltaId,
      companyId: conflict.companyId,
      entityType: conflict.entityType,
      entityId: conflict.entityId,
      operation: conflict.remoteOperation,
      payloadJson: conflict.remotePayloadJson,
      baseVersion: conflict.localVersion,
      newVersion: conflict.remoteVersion,
      createdAt: conflict.createdAt,
      createdByUserId: context.userId,
      deviceId: 'remote-conflict',
      schemaVersion: AppSchemaSql.schemaVersion,
      status: SyncStatuses.downloaded,
    );

    await _localQueue.transaction(() async {
      if (choice == ConflictResolutionChoice.remote) {
        if (incoming.operation == SyncOperations.delete) {
          await _localQueue.softDeleteRemote(incoming);
        } else {
          await _localQueue.upsertRemotePayload(incoming);
        }
      } else {
        final selected = choice == ConflictResolutionChoice.local
            ? conflict.localPayload
            : _decodeManual(manualPayloadJson!);
        final newVersion =
            max(conflict.localVersion, conflict.remoteVersion) + 1;
        final merged = <String, Object?>{
          ...selected,
          'id': conflict.entityId,
          'company_id': conflict.companyId,
          'version': newVersion,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
          'updated_by_user_id': context.userId,
          'sync_status': SyncStatuses.pendingUpload,
        };
        final operation =
            _isDeleted(merged) ? SyncOperations.delete : SyncOperations.update;
        final resolvedLocal = SyncDelta(
          deltaId: _uuid.v4(),
          companyId: conflict.companyId,
          entityType: conflict.entityType,
          entityId: conflict.entityId,
          operation: operation,
          payloadJson: jsonEncode(merged),
          baseVersion: conflict.remoteVersion,
          newVersion: newVersion,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          createdByUserId: context.userId,
          deviceId: context.deviceId,
          schemaVersion: AppSchemaSql.schemaVersion,
          status: SyncStatuses.pendingUpload,
        );
        if (operation == SyncOperations.delete) {
          await _localQueue.softDeleteRemote(resolvedLocal);
        } else {
          await _localQueue.upsertRemotePayload(resolvedLocal);
        }
        await _localQueue.queueDelta(resolvedLocal);
      }
      await _localQueue.recordAppliedDelta(incoming);
      await _localQueue.markStatus(incoming.deltaId, SyncStatuses.applied);
      await _database.customStatement('''
        UPDATE sync_conflicts SET status = 'resolved', resolution = ?,
          resolved_by_user_id = ?, resolved_at = ?, updated_at = ?,
          sync_status = 'applied'
        WHERE id = ? AND company_id = ? AND status = 'open'
      ''', [
        choice.name,
        context.userId,
        DateTime.now().millisecondsSinceEpoch,
        DateTime.now().millisecondsSinceEpoch,
        conflict.id,
        conflict.companyId,
      ]);
    });
  }

  Future<void> _requireManager(SyncContext context) async {
    final policy =
        await _accessRepository.readCachedPolicyForUid(context.userId);
    if (policy == null || !policy.isActive || !policy.isOwnerOrAdmin) {
      throw StateError('Only an active owner or admin can resolve conflicts.');
    }
    if (policy.staff.companyId != context.companyId) {
      throw StateError('Conflict belongs to another company.');
    }
  }

  Future<SyncConflict> _loadOpen(String companyId, String conflictId) async {
    final row = await _database.customSelect('''
      SELECT * FROM sync_conflicts
      WHERE id = ? AND company_id = ? AND status = 'open' AND is_deleted = 0
      LIMIT 1
    ''', variables: [
      Variable(conflictId),
      Variable(companyId)
    ]).getSingleOrNull();
    if (row == null) throw StateError('Open conflict was not found.');
    return _fromRow(row.data);
  }

  SyncConflict _fromRow(Map<String, Object?> data) => SyncConflict(
        id: data['id']?.toString() ?? '',
        companyId: data['company_id']?.toString() ?? '',
        entityType: data['entity_type']?.toString() ?? '',
        entityId: data['entity_id']?.toString() ?? '',
        remoteDeltaId: data['remote_delta_id']?.toString() ??
            (data['id']?.toString() ?? '').replaceFirst('_conflict', ''),
        remoteOperation:
            data['remote_operation']?.toString() ?? SyncOperations.update,
        localPayloadJson: data['local_payload_json']?.toString() ?? '{}',
        remotePayloadJson: data['remote_payload_json']?.toString() ?? '{}',
        localVersion: _int(data['local_version']),
        remoteVersion: _int(data['remote_version']),
        createdAt: _int(data['created_at']),
        status: data['status']?.toString() ?? 'open',
        reason: data['resolution']?.toString(),
      );

  Map<String, Object?> _decodeManual(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Manual merge must be a JSON object.');
    }
    return Map<String, Object?>.from(decoded);
  }

  bool _isDeleted(Map<String, Object?> payload) {
    final value = payload['is_deleted'];
    return value == 1 || value == true || value?.toString() == '1';
  }

  int _int(Object? value) => value is int
      ? value
      : value is num
          ? value.toInt()
          : int.tryParse(value?.toString() ?? '') ?? 0;
}
