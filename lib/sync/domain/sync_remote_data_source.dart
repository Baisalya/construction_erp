import 'sync_delta.dart';
import 'sync_models.dart';

abstract interface class SyncDeltaRemoteDataSource {
  Future<void> uploadDelta(SyncDelta delta);

  Future<List<SyncDelta>> downloadDeltas(
    String companyId, {
    int? afterCreatedAt,
    SyncDownloadScope? scope,
  });

  Future<void> updateDeviceLastSync({
    required String companyId,
    required String deviceId,
    required String userId,
    required int lastSyncAt,
  });
}
