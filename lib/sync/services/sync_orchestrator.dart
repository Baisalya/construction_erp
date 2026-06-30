import '../data/device_identity_service.dart';
import '../data/local_sync_queue_repository.dart';
import '../data/sync_download_service.dart';
import '../data/sync_upload_service.dart';
import '../domain/sync_models.dart';
import '../domain/sync_remote_data_source.dart';
import '../domain/sync_permission_guard.dart';

class SyncOrchestrator {
  SyncOrchestrator(
      {required SyncUploadService uploadService,
      required SyncDownloadService downloadService,
      required LocalSyncQueueRepository localQueue,
      required DeviceIdentityService deviceIdentityService,
      required SyncDeltaRemoteDataSource remote,
      required SyncPermissionGuard permissionGuard})
      : _uploadService = uploadService,
        _downloadService = downloadService,
        _localQueue = localQueue,
        _deviceIdentityService = deviceIdentityService,
        _remote = remote,
        _permissionGuard = permissionGuard;
  final SyncUploadService _uploadService;
  final SyncDownloadService _downloadService;
  final LocalSyncQueueRepository _localQueue;
  final DeviceIdentityService _deviceIdentityService;
  final SyncDeltaRemoteDataSource _remote;
  final SyncPermissionGuard _permissionGuard;

  Future<SyncRunResult> syncNow(SyncContext context) async {
    final decision = await _permissionGuard.canRunCompanySync(context);
    if (!decision.allowed) {
      throw StateError(decision.reason ?? 'Sync is not allowed.');
    }
    final resolvedDeviceId = await _deviceIdentityService.ensureDevice(
        companyId: context.companyId,
        firebaseUid: context.userId,
        existingDeviceId: context.deviceId);
    final resolvedContext = SyncContext(
        companyId: context.companyId,
        userId: context.userId,
        staffId: context.staffId,
        deviceId: resolvedDeviceId,
        schemaVersion: context.schemaVersion);
    final failedBefore =
        (await _localQueue.statusCounts(context.companyId)).failed;
    final uploaded = await _uploadService.uploadPending(resolvedContext);
    final downloaded = await _downloadService.downloadAndApply(resolvedContext);
    final now = DateTime.now().millisecondsSinceEpoch;
    await _localQueue.markDeviceSynced(
      resolvedContext.companyId,
      resolvedContext.deviceId,
    );
    await _remote.updateDeviceLastSync(
      companyId: resolvedContext.companyId,
      deviceId: resolvedContext.deviceId,
      userId: resolvedContext.userId,
      lastSyncAt: now,
    );
    final counts = await _localQueue.statusCounts(context.companyId);
    return SyncRunResult(
        uploaded: uploaded,
        downloaded: downloaded.downloaded,
        applied: downloaded.applied,
        conflicts: downloaded.conflicts,
        failed: downloaded.failed + (counts.failed - failedBefore),
        message: 'Sync completed.');
  }
}
