import 'dart:convert';

import 'package:construction_erp/core/permissions/role_type.dart';
import 'package:construction_erp/core/permissions/staff_status.dart';
import 'package:construction_erp/core/domain/write_context.dart';
import 'package:construction_erp/database/local_database.dart';
import 'package:construction_erp/features/auth/data/local_staff_access_repository.dart';
import 'package:construction_erp/features/staff/domain/default_role_permissions.dart';
import 'package:construction_erp/features/staff/domain/staff_access_policy.dart';
import 'package:construction_erp/features/staff/domain/staff_profile.dart';
import 'package:construction_erp/sync/data/local_sync_queue_repository.dart';
import 'package:construction_erp/sync/data/local_delta_writer.dart';
import 'package:construction_erp/sync/data/sync_download_service.dart';
import 'package:construction_erp/sync/data/sync_upload_service.dart';
import 'package:construction_erp/sync/domain/sync_delta.dart';
import 'package:construction_erp/sync/domain/sync_models.dart';
import 'package:construction_erp/sync/domain/sync_permission_guard.dart';
import 'package:construction_erp/sync/domain/sync_remote_data_source.dart';
import 'package:construction_erp/sync/services/sync_apply_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ConstructionDatabase database;
  late LocalSyncQueueRepository queue;
  late LocalStaffAccessRepository access;
  late SyncPermissionGuard guard;
  late _FakeRemote remote;
  late SyncApplyService apply;
  late SyncDownloadService downloader;

  const context = SyncContext(
    companyId: 'company-1',
    userId: 'uid-1',
    deviceId: 'device-local',
    staffId: 'staff-1',
  );

  setUp(() async {
    database = ConstructionDatabase(NativeDatabase.memory());
    queue = LocalSyncQueueRepository(database: database);
    access = LocalStaffAccessRepository(database: database);
    guard = SyncPermissionGuard(accessRepository: access);
    remote = _FakeRemote();
    apply = SyncApplyService(localQueue: queue);
    downloader = SyncDownloadService(
      remote: remote,
      localQueue: queue,
      permissionGuard: guard,
      applyService: apply,
    );
    await _cachePolicy(access, role: RoleType.owner);
  });

  tearDown(() => database.close());

  test('upload marks a canonical local delta uploaded', () async {
    await _insertProject(database, version: 1);
    await queue.queueDelta(_delta(operation: SyncOperations.insert));
    final service = SyncUploadService(
      localQueue: queue,
      remote: remote,
      permissionGuard: guard,
    );

    expect(await service.uploadPending(context), 1);
    expect(remote.uploaded.single.newVersion, 1);
    expect(
        jsonDecode(remote.uploaded.single.payloadJson)['project_name'], 'P1');
    expect(await _queueStatus(database, 'delta-1'), SyncStatuses.uploaded);
    expect(
      (await queue.localRecord('projects', 'project-1'))!['sync_status'],
      SyncStatuses.uploaded,
    );
  });

  test('successive local writes keep exact base and new versions', () async {
    await _insertProject(database, version: 1);
    await database.customStatement(
      "UPDATE projects SET version = 2, project_name = 'V2' WHERE id = 'project-1'",
    );
    await LocalDeltaWriter.queue(
      database: database,
      context: const WriteContext(
        companyId: 'company-1',
        userId: 'uid-1',
        deviceId: 'device-local',
      ),
      createdAt: 101,
      entityType: 'projects',
      entityId: 'project-1',
      operation: SyncOperations.update,
    );
    await database.customStatement(
      "UPDATE projects SET version = 3, project_name = 'V3' WHERE id = 'project-1'",
    );
    await LocalDeltaWriter.queue(
      database: database,
      context: const WriteContext(
        companyId: 'company-1',
        userId: 'uid-1',
        deviceId: 'device-local',
      ),
      createdAt: 102,
      entityType: 'projects',
      entityId: 'project-1',
      operation: SyncOperations.update,
    );

    final deltas = await queue.pendingUploadDeltas('company-1');
    expect(
      deltas.map((delta) => (delta.baseVersion, delta.newVersion)),
      [(1, 2), (2, 3)],
    );
  });

  test('failed upload keeps delta and readable error', () async {
    await _insertProject(database, version: 1);
    await queue.queueDelta(_delta(operation: SyncOperations.insert));
    remote.failUpload = true;
    final service = SyncUploadService(
      localQueue: queue,
      remote: remote,
      permissionGuard: guard,
    );

    expect(await service.uploadPending(context), 0);
    expect(await _queueStatus(database, 'delta-1'), SyncStatuses.failed);
    expect(await queue.pendingUploadCount('company-1'), 1);
    expect((await queue.statusCounts('company-1')).errors.single, isNotEmpty);
  });

  test('download skips a delta created by this device', () async {
    remote.downloaded = [_delta(deviceId: 'device-local')];
    final result = await downloader.downloadAndApply(context);
    expect(result.downloaded, 0);
    expect(await database.countRows('projects'), 0);
  });

  test('download skips an already applied delta', () async {
    final delta = _delta(deviceId: 'device-remote');
    await queue.recordAppliedDelta(delta);
    remote.downloaded = [delta];
    final result = await downloader.downloadAndApply(context);
    expect(result.downloaded, 0);
  });

  test('remote insert applies idempotently', () async {
    remote.downloaded = [_delta(deviceId: 'device-remote')];
    final first = await downloader.downloadAndApply(context);
    final second = await downloader.downloadAndApply(context);
    expect(first.applied, 1);
    expect(second.downloaded, 0);
    expect(await database.countRows('projects'), 1);
  });

  test('remote compatible update applies locally', () async {
    await _insertProject(database, version: 1, name: 'Old');
    remote.downloaded = [
      _delta(
        operation: SyncOperations.update,
        deviceId: 'device-remote',
        baseVersion: 1,
        newVersion: 2,
        name: 'Updated',
      ),
    ];
    expect((await downloader.downloadAndApply(context)).applied, 1);
    expect((await queue.localRecord('projects', 'project-1'))!['project_name'],
        'Updated');
  });

  test('remote delete soft-deletes locally', () async {
    await _insertProject(database, version: 1);
    remote.downloaded = [
      _delta(
        operation: SyncOperations.delete,
        deviceId: 'device-remote',
        baseVersion: 1,
        newVersion: 2,
      ),
    ];
    expect((await downloader.downloadAndApply(context)).applied, 1);
    final row = await queue.localRecord('projects', 'project-1');
    expect(row!['is_deleted'], 1);
    expect(row['version'], 2);
  });

  test('version mismatch creates an open conflict without overwrite', () async {
    await _insertProject(database, version: 3, name: 'Local');
    remote.downloaded = [
      _delta(
        operation: SyncOperations.update,
        deviceId: 'device-remote',
        baseVersion: 1,
        newVersion: 4,
        name: 'Remote',
      ),
    ];
    final result = await downloader.downloadAndApply(context);
    expect(result.conflicts, 1);
    expect(await database.countRows('sync_conflicts'), 1);
    expect((await queue.localRecord('projects', 'project-1'))!['project_name'],
        'Local');
  });

  test('revoked staff cannot run sync', () async {
    await _cachePolicy(access,
        role: RoleType.siteSupervisor, status: StaffStatus.revoked);
    expect((await guard.canRunCompanySync(context)).allowed, isFalse);
  });

  test('inactive staff cannot run sync', () async {
    await _cachePolicy(access,
        role: RoleType.siteSupervisor, status: StaffStatus.inactive);
    expect((await guard.canRunCompanySync(context)).allowed, isFalse);
  });

  test('permission guard blocks a disallowed entity type', () async {
    await _cachePolicy(access, role: RoleType.accountant);
    final decision = await guard.canSyncDelta(
      context,
      _delta(entityType: 'labor_work_entries'),
    );
    expect(decision.allowed, isFalse);
    expect(decision.reason, contains('labor.entry'));
  });

  test('assigned project is allowed for permitted staff', () async {
    await _cachePolicy(
      access,
      role: RoleType.siteSupervisor,
      projects: {'project-1'},
    );
    final decision = await guard.canSyncDelta(
      context,
      _delta(entityType: 'material_purchases'),
    );
    expect(decision.allowed, isTrue);
    final scope = await guard.downloadScope(context);
    expect(scope.allCompanyData, isFalse);
    expect(scope.entityTypes, contains('material_purchases'));
    expect(scope.projectIds, {'project-1'});
  });

  test('unassigned project is blocked for staff', () async {
    await _cachePolicy(
      access,
      role: RoleType.siteSupervisor,
      projects: {'project-other'},
    );
    final decision = await guard.canSyncDelta(
      context,
      _delta(entityType: 'material_purchases'),
    );
    expect(decision.allowed, isFalse);
    expect(decision.reason, contains('not assigned'));
  });

  test('viewer can download assigned records but cannot upload', () async {
    await _cachePolicy(access, role: RoleType.viewer, projects: {'project-1'});
    final delta = _delta(entityType: 'material_purchases');
    expect(
      (await guard.canSyncDelta(
        context,
        delta,
        direction: SyncDirection.download,
      ))
          .allowed,
      isTrue,
    );
    expect((await guard.canSyncDelta(context, delta)).allowed, isFalse);
  });

  test('unknown entity type fails without crashing download', () async {
    remote.downloaded = [
      _delta(entityType: 'unknown_table', deviceId: 'device-remote'),
    ];
    final result = await downloader.downloadAndApply(context);
    expect(result.failed, 1);
    expect(await _queueStatus(database, 'delta-1'), SyncStatuses.failed);
  });
}

Future<void> _cachePolicy(
  LocalStaffAccessRepository access, {
  required RoleType role,
  StaffStatus status = StaffStatus.active,
  Set<String> projects = const {},
}) {
  return access.cacheAccessPolicy(StaffAccessPolicy(
    staff: StaffProfile(
      id: 'staff-1',
      companyId: 'company-1',
      name: 'Sync tester',
      firebaseUid: 'uid-1',
      roleId: role.storageKey,
      roleType: role,
      status: status,
    ),
    allowedPermissions: DefaultRolePermissions.permissionsFor(role),
    assignedProjectIds: projects,
  ));
}

Future<void> _insertProject(
  ConstructionDatabase database, {
  required int version,
  String name = 'P1',
}) async {
  await database.ensureSchema();
  await database.customStatement('''
    INSERT INTO projects (
      id, company_id, created_at, updated_at, is_deleted, sync_status,
      version, project_name, project_status
    ) VALUES (?, ?, ?, ?, 0, 'pendingUpload', ?, ?, 'running')
  ''', ['project-1', 'company-1', 100, 100, version, name]);
}

SyncDelta _delta({
  String entityType = 'projects',
  String operation = SyncOperations.insert,
  String deviceId = 'device-local',
  int baseVersion = 0,
  int newVersion = 1,
  String name = 'P1',
}) {
  final projectScoped = entityType != 'tenders';
  return SyncDelta(
    deltaId: 'delta-1',
    companyId: 'company-1',
    entityType: entityType,
    entityId: 'project-1',
    operation: operation,
    payloadJson: jsonEncode({
      'id': 'project-1',
      'company_id': 'company-1',
      'created_at': 100,
      'updated_at': 100,
      'is_deleted': operation == SyncOperations.delete ? 1 : 0,
      'sync_status': 'uploaded',
      'version': newVersion,
      'project_name': name,
      'project_status': 'running',
      if (projectScoped) 'project_id': 'project-1',
    }),
    baseVersion: baseVersion,
    newVersion: newVersion,
    createdAt: 100,
    createdByUserId: 'uid-remote',
    deviceId: deviceId,
    schemaVersion: 2,
    status: SyncStatuses.uploaded,
    projectId: projectScoped ? 'project-1' : null,
  );
}

Future<String?> _queueStatus(
    ConstructionDatabase database, String deltaId) async {
  final row = await database.customSelect(
    'SELECT status FROM sync_queue WHERE id = ?',
    variables: [Variable(deltaId)],
  ).getSingleOrNull();
  return row?.data['status']?.toString();
}

class _FakeRemote implements SyncDeltaRemoteDataSource {
  bool failUpload = false;
  List<SyncDelta> uploaded = [];
  List<SyncDelta> downloaded = [];

  @override
  Future<List<SyncDelta>> downloadDeltas(
    String companyId, {
    int? afterCreatedAt,
    SyncDownloadScope? scope,
  }) async =>
      downloaded
          .where((delta) => delta.companyId == companyId)
          .where((delta) =>
              scope == null ||
              scope.allCompanyData ||
              scope.entityTypes.contains(delta.entityType))
          .toList();

  @override
  Future<void> uploadDelta(SyncDelta delta) async {
    if (failUpload) throw StateError('network unavailable');
    uploaded.add(delta);
  }

  @override
  Future<void> updateDeviceLastSync({
    required String companyId,
    required String deviceId,
    required String userId,
    required int lastSyncAt,
  }) async {}
}
