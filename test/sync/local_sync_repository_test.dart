import 'package:construction_erp_phase5/database/local_database.dart';
import 'package:construction_erp_phase5/sync/data/local_sync_repository.dart';
import 'package:construction_erp_phase5/sync/domain/sync_delta.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ConstructionDatabase database;
  late LocalSyncRepository repository;

  setUp(() {
    database = ConstructionDatabase(NativeDatabase.memory());
    repository = LocalSyncRepository(database: database);
  });

  tearDown(() => database.close());

  test('local write delta is queued for upload', () async {
    await repository.queueDelta(const SyncDelta(
      deltaId: 'delta-1',
      companyId: 'company-1',
      entityType: 'tenders',
      entityId: 'tender-1',
      operation: 'insert',
      payloadJson: '{"id":"tender-1"}',
      createdAt: 1700000000000,
      createdByUserId: 'owner-1',
      deviceId: 'device-1',
      schemaVersion: 1,
      status: 'pendingUpload',
    ));

    expect(await repository.pendingUploadCount('company-1'), 1);
  });

  test('revoked or missing staff cannot sync', () async {
    await database.ensureSchema();
    await database.customStatement('''
      INSERT INTO staff_access_cache (
        id, company_id, created_at, updated_at, is_deleted, sync_status,
        version, staff_id, permission_json, assigned_project_ids_json,
        status, cached_at
      ) VALUES (?, ?, ?, ?, 0, 'localOnly', 1, ?, '{}', '[]', ?, ?);
    ''', [
      'cache-1',
      'company-1',
      1700000000000,
      1700000000000,
      'staff-1',
      'revoked',
      1700000000000,
    ]);

    expect(await repository.canSyncStaff('company-1', 'staff-1'), isFalse);
    expect(await repository.canSyncStaff('company-1', 'missing'), isFalse);
  });
}
