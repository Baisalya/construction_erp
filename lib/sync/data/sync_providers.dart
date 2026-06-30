import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../features/auth/data/auth_providers.dart';
import '../domain/sync_models.dart';
import '../domain/sync_permission_guard.dart';
import '../firebase/firestore_sync_delta_remote_data_source.dart';
import '../services/sync_apply_service.dart';
import '../services/conflict_resolution_service.dart';
import '../services/sync_orchestrator.dart';
import 'device_identity_service.dart';
import 'local_sync_queue_repository.dart';
import 'sync_delta_factory.dart';
import 'sync_download_service.dart';
import 'sync_upload_service.dart';

final localSyncQueueRepositoryProvider = Provider<LocalSyncQueueRepository>(
    (ref) =>
        LocalSyncQueueRepository(database: ref.watch(localDatabaseProvider)));
final syncDeltaFactoryProvider = Provider<SyncDeltaFactory>(
    (ref) => SyncDeltaFactory(database: ref.watch(localDatabaseProvider)));
final firestoreSyncDeltaRemoteDataSourceProvider =
    Provider<FirestoreSyncDeltaRemoteDataSource>(
        (ref) => FirestoreSyncDeltaRemoteDataSource());
final deviceIdentityServiceProvider = Provider<DeviceIdentityService>((ref) =>
    DeviceIdentityService(
        localQueue: ref.watch(localSyncQueueRepositoryProvider)));
final syncPermissionGuardProvider = Provider<SyncPermissionGuard>((ref) =>
    SyncPermissionGuard(
        accessRepository: ref.watch(localStaffAccessRepositoryProvider)));
final syncApplyServiceProvider = Provider<SyncApplyService>((ref) =>
    SyncApplyService(localQueue: ref.watch(localSyncQueueRepositoryProvider)));
final syncUploadServiceProvider = Provider<SyncUploadService>((ref) =>
    SyncUploadService(
        localQueue: ref.watch(localSyncQueueRepositoryProvider),
        remote: ref.watch(firestoreSyncDeltaRemoteDataSourceProvider),
        permissionGuard: ref.watch(syncPermissionGuardProvider)));
final syncDownloadServiceProvider = Provider<SyncDownloadService>((ref) =>
    SyncDownloadService(
        remote: ref.watch(firestoreSyncDeltaRemoteDataSourceProvider),
        localQueue: ref.watch(localSyncQueueRepositoryProvider),
        permissionGuard: ref.watch(syncPermissionGuardProvider),
        applyService: ref.watch(syncApplyServiceProvider)));
final syncOrchestratorProvider = Provider<SyncOrchestrator>((ref) =>
    SyncOrchestrator(
        uploadService: ref.watch(syncUploadServiceProvider),
        downloadService: ref.watch(syncDownloadServiceProvider),
        localQueue: ref.watch(localSyncQueueRepositoryProvider),
        deviceIdentityService: ref.watch(deviceIdentityServiceProvider),
        remote: ref.watch(firestoreSyncDeltaRemoteDataSourceProvider),
        permissionGuard: ref.watch(syncPermissionGuardProvider)));
final syncStatusSummaryProvider = FutureProvider.family<SyncCounts, String>(
    (ref, companyId) =>
        ref.watch(localSyncQueueRepositoryProvider).statusCounts(companyId));

final conflictResolutionServiceProvider = Provider<ConflictResolutionService>(
  (ref) => ConflictResolutionService(
    database: ref.watch(localDatabaseProvider),
    localQueue: ref.watch(localSyncQueueRepositoryProvider),
    accessRepository: ref.watch(localStaffAccessRepositoryProvider),
  ),
);

final openSyncConflictsProvider = FutureProvider.family(
    (ref, ({String companyId, String userId, String deviceId}) input) {
  return ref.watch(conflictResolutionServiceProvider).openConflicts(
        SyncContext(
          companyId: input.companyId,
          userId: input.userId,
          deviceId: input.deviceId,
        ),
      );
});
