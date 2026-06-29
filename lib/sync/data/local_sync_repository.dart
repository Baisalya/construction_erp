import 'package:drift/drift.dart';

import '../../database/local_database.dart';
import '../domain/sync_delta.dart';
import '../domain/sync_repository.dart';

class LocalSyncRepository implements SyncRepository {
  const LocalSyncRepository({required this.database});

  final ConstructionDatabase database;

  @override
  Future<void> queueDelta(SyncDelta delta) async {
    await database.ensureSchema();
    await database.customStatement(
      '''
      INSERT INTO sync_queue (
        id, company_id, created_at, updated_at, created_by_user_id,
        updated_by_user_id, is_deleted, sync_status, version,
        entity_type, entity_id, operation, payload_json, device_id,
        schema_version, status, error_message
      ) VALUES (?, ?, ?, ?, ?, ?, 0, ?, 1, ?, ?, ?, ?, ?, ?, ?, NULL);
      ''',
      [
        Variable<String>(delta.deltaId),
        Variable<String>(delta.companyId),
        Variable<int>(delta.createdAt),
        Variable<int>(delta.createdAt),
        Variable<String>(delta.createdByUserId),
        Variable<String>(delta.createdByUserId),
        Variable<String>(delta.status),
        Variable<String>(delta.entityType),
        Variable<String>(delta.entityId),
        Variable<String>(delta.operation),
        Variable<String>(delta.payloadJson),
        Variable<String>(delta.deviceId),
        Variable<int>(delta.schemaVersion),
        Variable<String>(delta.status),
      ],
    );
  }

  @override
  Future<int> pendingUploadCount(String companyId) async {
    await database.ensureSchema();
    final row = await database.customSelect(
      '''
      SELECT COUNT(*) AS total
      FROM sync_queue
      WHERE company_id = ? AND is_deleted = 0 AND status = 'pendingUpload';
      ''',
      variables: [Variable<String>(companyId)],
    ).getSingle();
    return row.read<int>('total');
  }

  @override
  Future<bool> canSyncStaff(String companyId, String staffId) async {
    await database.ensureSchema();
    final row = await database.customSelect(
      '''
      SELECT status
      FROM staff_access_cache
      WHERE company_id = ? AND staff_id = ? AND is_deleted = 0
      ORDER BY updated_at DESC
      LIMIT 1;
      ''',
      variables: [Variable<String>(companyId), Variable<String>(staffId)],
    ).getSingleOrNull();
    if (row == null) {
      return false;
    }
    return row.read<String>('status') == 'active';
  }
}
