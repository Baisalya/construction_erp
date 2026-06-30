import 'sync_delta.dart';

abstract class SyncRepository {
  Future<void> queueDelta(SyncDelta delta);
  Future<int> pendingUploadCount(String companyId);
  Future<bool> canSyncStaff(String companyId, String staffId);
}
