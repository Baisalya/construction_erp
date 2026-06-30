import 'package:drift/drift.dart';

import '../domain/sync_repository.dart';
import 'local_sync_queue_repository.dart';

class LocalSyncRepository extends LocalSyncQueueRepository
    implements SyncRepository {
  LocalSyncRepository({required super.database});

  @override
  Future<bool> canSyncStaff(String companyId, String staffId) async {
    await database.ensureSchema();
    final rows = await database.customSelect(
        'SELECT status FROM staff_access_cache WHERE company_id = ? AND staff_id = ? LIMIT 1',
        variables: [Variable<String>(companyId), Variable<String>(staffId)],
        readsFrom: const {}).get();
    return rows.isNotEmpty && rows.first.data['status'] == 'active';
  }
}
