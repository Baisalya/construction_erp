import '../data/local_sync_queue_repository.dart';
import '../domain/sync_delta.dart';
import '../domain/sync_entity_registry.dart';
import '../domain/sync_models.dart';

class SyncApplyService {
  SyncApplyService({required LocalSyncQueueRepository localQueue})
      : _localQueue = localQueue;

  final LocalSyncQueueRepository _localQueue;

  Future<SyncApplyOutcome> applyRemoteDelta(
    SyncDelta delta,
    SyncContext context,
  ) async {
    if (delta.companyId != context.companyId) {
      await _fail(delta, 'A delta from another company was rejected.');
      return SyncApplyOutcome.failed;
    }
    if (await _localQueue.isDeltaApplied(delta.companyId, delta.deltaId)) {
      return SyncApplyOutcome.skipped;
    }
    try {
      SyncEntityRegistry.requireConfig(delta.entityType);
      if (!const {
        SyncOperations.insert,
        SyncOperations.update,
        SyncOperations.delete,
      }.contains(delta.operation)) {
        throw StateError('Unknown sync operation: ${delta.operation}.');
      }

      final local = await _localQueue.localRecord(
        delta.entityType,
        delta.entityId,
      );
      final localVersion = _int(local?['version']);
      if (local != null && localVersion >= delta.newVersion) {
        await _localQueue.transaction(() async {
          await _localQueue.recordAppliedDelta(delta);
          await _localQueue.markStatus(delta.deltaId, SyncStatuses.applied);
        });
        return SyncApplyOutcome.skipped;
      }

      final compatible = switch (delta.operation) {
        SyncOperations.insert => local == null,
        SyncOperations.update ||
        SyncOperations.delete =>
          local != null && localVersion == delta.baseVersion,
        _ => false,
      };
      if (!compatible) {
        await _localQueue.insertConflict(
          delta: delta,
          localPayload: local,
          reason: 'Version mismatch: local version $localVersion, '
              'remote base version ${delta.baseVersion}.',
        );
        return SyncApplyOutcome.conflict;
      }

      await _localQueue.transaction(() async {
        if (delta.operation == SyncOperations.delete) {
          await _localQueue.softDeleteRemote(delta);
        } else {
          await _localQueue.upsertRemotePayload(delta);
        }
        await _localQueue.recordAppliedDelta(delta);
        await _localQueue.markStatus(delta.deltaId, SyncStatuses.applied);
      });
      return SyncApplyOutcome.applied;
    } catch (error) {
      await _fail(delta, error.toString());
      return SyncApplyOutcome.failed;
    }
  }

  Future<void> _fail(SyncDelta delta, String reason) => _localQueue.markStatus(
        delta.deltaId,
        SyncStatuses.failed,
        errorMessage: reason.replaceFirst('Invalid argument', 'Unsupported'),
      );

  int _int(Object? value) => value == null
      ? 0
      : value is int
          ? value
          : value is num
              ? value.toInt()
              : int.tryParse(value.toString()) ?? 0;
}
