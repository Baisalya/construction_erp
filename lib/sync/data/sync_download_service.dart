import '../domain/sync_models.dart';
import '../domain/sync_permission_guard.dart';
import '../domain/sync_remote_data_source.dart';
import '../services/sync_apply_service.dart';
import 'local_sync_queue_repository.dart';

class SyncDownloadService {
  SyncDownloadService(
      {required SyncDeltaRemoteDataSource remote,
      required LocalSyncQueueRepository localQueue,
      required SyncPermissionGuard permissionGuard,
      required SyncApplyService applyService})
      : _remote = remote,
        _localQueue = localQueue,
        _permissionGuard = permissionGuard,
        _applyService = applyService;
  final SyncDeltaRemoteDataSource _remote;
  final LocalSyncQueueRepository _localQueue;
  final SyncPermissionGuard _permissionGuard;
  final SyncApplyService _applyService;

  Future<({int downloaded, int applied, int conflicts, int failed})>
      downloadAndApply(SyncContext context) async {
    final syncDecision = await _permissionGuard.canRunCompanySync(context);
    if (!syncDecision.allowed) {
      throw StateError(syncDecision.reason ?? 'Sync is not allowed.');
    }
    var downloaded = 0;
    var applied = 0;
    var conflicts = 0;
    var failed = 0;
    final scope = await _permissionGuard.downloadScope(context);
    final deltas = (await _remote.downloadDeltas(
      context.companyId,
      scope: scope,
    ))
        .toList()
      ..sort((left, right) {
        final time = left.createdAt.compareTo(right.createdAt);
        if (time != 0) return time;
        final entity = left.entityType.compareTo(right.entityType);
        if (entity != 0) return entity;
        final id = left.entityId.compareTo(right.entityId);
        if (id != 0) return id;
        return left.newVersion.compareTo(right.newVersion);
      });
    for (final delta in deltas) {
      if (delta.deviceId == context.deviceId) continue;
      if (await _localQueue.isDeltaApplied(delta.companyId, delta.deltaId)) {
        continue;
      }
      downloaded++;
      await _localQueue.recordDownloadedDelta(delta);
      final decision = await _permissionGuard.canSyncDelta(
        context,
        delta,
        direction: SyncDirection.download,
      );
      if (!decision.allowed) {
        failed++;
        await _localQueue.markStatus(
          delta.deltaId,
          SyncStatuses.failed,
          errorMessage: decision.reason,
        );
        continue;
      }
      final outcome = await _applyService.applyRemoteDelta(
        delta.copyWith(status: SyncStatuses.downloaded),
        context,
      );
      switch (outcome) {
        case SyncApplyOutcome.applied:
          applied++;
        case SyncApplyOutcome.skipped:
          break;
        case SyncApplyOutcome.conflict:
          conflicts++;
        case SyncApplyOutcome.failed:
          failed++;
      }
    }
    return (
      downloaded: downloaded,
      applied: applied,
      conflicts: conflicts,
      failed: failed,
    );
  }
}
