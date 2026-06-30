import '../domain/sync_models.dart';
import '../domain/sync_permission_guard.dart';
import '../domain/sync_remote_data_source.dart';
import 'local_sync_queue_repository.dart';

class SyncUploadService {
  SyncUploadService(
      {required LocalSyncQueueRepository localQueue,
      required SyncDeltaRemoteDataSource remote,
      required SyncPermissionGuard permissionGuard})
      : _localQueue = localQueue,
        _remote = remote,
        _permissionGuard = permissionGuard;
  final LocalSyncQueueRepository _localQueue;
  final SyncDeltaRemoteDataSource _remote;
  final SyncPermissionGuard _permissionGuard;

  Future<int> uploadPending(SyncContext context, {int limit = 100}) async {
    final syncDecision = await _permissionGuard.canRunCompanySync(context);
    if (!syncDecision.allowed) {
      throw StateError(syncDecision.reason ?? 'Sync is not allowed.');
    }
    var uploaded = 0;
    final pending =
        await _localQueue.pendingUploadDeltas(context.companyId, limit: limit);
    for (final queued in pending) {
      try {
        final delta = await _localQueue.canonicalizeForUpload(queued);
        final decision = await _permissionGuard.canSyncDelta(
          context,
          delta,
          direction: SyncDirection.upload,
        );
        if (!decision.allowed) {
          await _localQueue.markStatus(
            delta.deltaId,
            SyncStatuses.failed,
            errorMessage: decision.reason,
          );
          continue;
        }
        await _localQueue.markStatus(delta.deltaId, SyncStatuses.uploading);
        await _remote
            .uploadDelta(delta.copyWith(status: SyncStatuses.uploaded));
        await _localQueue.markStatus(delta.deltaId, SyncStatuses.uploaded);
        await _localQueue.markEntityUploaded(delta);
        uploaded++;
      } catch (error) {
        await _localQueue.markStatus(
          queued.deltaId,
          SyncStatuses.failed,
          errorMessage: _readableError(error),
        );
      }
    }
    return uploaded;
  }

  String _readableError(Object error) {
    final text = error.toString();
    if (text.contains('unavailable') || text.contains('network')) {
      return 'Firebase is unavailable. The local change is safe and will retry.';
    }
    return text
        .replaceFirst('Exception: ', '')
        .replaceFirst('StateError: ', '');
  }
}
