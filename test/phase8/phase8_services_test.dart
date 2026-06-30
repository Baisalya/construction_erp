import 'dart:convert';

import 'package:construction_erp/core/domain/write_context.dart';
import 'package:construction_erp/core/permissions/repository_write_guard.dart';
import 'package:construction_erp/core/permissions/role_type.dart';
import 'package:construction_erp/core/permissions/staff_status.dart';
import 'package:construction_erp/core/value_objects/money.dart';
import 'package:construction_erp/database/local_database.dart';
import 'package:construction_erp/features/auth/data/local_staff_access_repository.dart';
import 'package:construction_erp/features/billing/domain/billing_records.dart';
import 'package:construction_erp/features/reports/data/report_export_service.dart';
import 'package:construction_erp/features/settings/data/local_backup_service.dart';
import 'package:construction_erp/features/staff/domain/default_role_permissions.dart';
import 'package:construction_erp/features/staff/domain/staff_access_policy.dart';
import 'package:construction_erp/features/staff/domain/staff_profile.dart';
import 'package:construction_erp/sync/data/local_sync_queue_repository.dart';
import 'package:construction_erp/sync/domain/sync_conflict.dart';
import 'package:construction_erp/sync/domain/sync_delta.dart';
import 'package:construction_erp/sync/domain/sync_models.dart';
import 'package:construction_erp/sync/services/conflict_resolution_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ConstructionDatabase database;
  late LocalSyncQueueRepository queue;
  late LocalStaffAccessRepository access;
  late ConflictResolutionService conflicts;

  const write = WriteContext(
    companyId: 'company-1',
    userId: 'uid-1',
    deviceId: 'device-1',
  );
  const syncContext = SyncContext(
    companyId: 'company-1',
    userId: 'uid-1',
    deviceId: 'device-1',
  );

  setUp(() async {
    database = ConstructionDatabase(NativeDatabase.memory());
    queue = LocalSyncQueueRepository(database: database);
    access = LocalStaffAccessRepository(database: database);
    conflicts = ConflictResolutionService(
      database: database,
      localQueue: queue,
      accessRepository: access,
    );
    await access.cacheAccessPolicy(_policy(RoleType.owner));
  });

  tearDown(() => database.close());

  test('remote conflict resolution replaces local row and closes conflict',
      () async {
    await _insertProject(database, name: 'Local', version: 2);
    final remote = _remoteDelta(name: 'Remote', newVersion: 3);
    await queue.recordDownloadedDelta(remote);
    await queue.insertConflict(
      delta: remote,
      localPayload: await queue.localRecord('projects', 'project-1'),
      reason: 'test conflict',
    );

    await conflicts.resolve(
      context: syncContext,
      conflictId: 'remote-delta_conflict',
      choice: ConflictResolutionChoice.remote,
    );

    expect((await queue.localRecord('projects', 'project-1'))!['project_name'],
        'Remote');
    expect(await conflicts.openConflicts(syncContext), isEmpty);
    expect(await queue.isDeltaApplied('company-1', 'remote-delta'), isTrue);
  });

  test('local conflict resolution creates a higher-version outbound delta',
      () async {
    await _insertProject(database, name: 'Local', version: 2);
    final remote = _remoteDelta(name: 'Remote', newVersion: 3);
    await queue.recordDownloadedDelta(remote);
    await queue.insertConflict(
      delta: remote,
      localPayload: await queue.localRecord('projects', 'project-1'),
      reason: 'test conflict',
    );

    await conflicts.resolve(
      context: syncContext,
      conflictId: 'remote-delta_conflict',
      choice: ConflictResolutionChoice.local,
    );

    final row = await queue.localRecord('projects', 'project-1');
    expect(row!['project_name'], 'Local');
    expect(row['version'], 4);
    final pending = await queue.pendingUploadDeltas('company-1');
    expect(pending.single.baseVersion, 3);
    expect(pending.single.newVersion, 4);
  });

  test('manual merge protects identity fields and applies edited values',
      () async {
    await _insertProject(database, name: 'Local', version: 2);
    final remote = _remoteDelta(name: 'Remote', newVersion: 3);
    await queue.recordDownloadedDelta(remote);
    await queue.insertConflict(
      delta: remote,
      localPayload: await queue.localRecord('projects', 'project-1'),
      reason: 'test conflict',
    );

    await conflicts.resolve(
      context: syncContext,
      conflictId: 'remote-delta_conflict',
      choice: ConflictResolutionChoice.manual,
      manualPayloadJson: jsonEncode({
        'id': 'malicious-id',
        'company_id': 'other-company',
        'project_name': 'Merged',
        'project_status': 'running',
      }),
    );

    final row = await queue.localRecord('projects', 'project-1');
    expect(row!['id'], 'project-1');
    expect(row['company_id'], 'company-1');
    expect(row['project_name'], 'Merged');
    expect(row['version'], 4);
  });

  test('viewer cannot resolve conflicts', () async {
    await access.cacheAccessPolicy(_policy(RoleType.viewer));
    await _insertProject(database, name: 'Local', version: 2);
    final remote = _remoteDelta(name: 'Remote', newVersion: 3);
    await queue.recordDownloadedDelta(remote);
    await queue.insertConflict(
      delta: remote,
      localPayload: await queue.localRecord('projects', 'project-1'),
      reason: 'test conflict',
    );
    expect(
      () => conflicts.openConflicts(syncContext),
      throwsStateError,
    );
    expect(
      () => conflicts.resolve(
        context: syncContext,
        conflictId: 'remote-delta_conflict',
        choice: ConflictResolutionChoice.local,
      ),
      throwsStateError,
    );
  });

  test('company backup restores business rows and creates sync delta',
      () async {
    await _insertCompany(database);
    await _insertProject(database, name: 'Backed up', version: 2);
    final backup = LocalBackupService(
      database: database,
      localQueue: queue,
      writeGuard: const AllowAllRepositoryWriteGuard(),
    );
    final bytes = await backup.createBackup(write);

    await database.customStatement('DELETE FROM projects');
    await database.customStatement('DELETE FROM companies');
    await database.customStatement('DELETE FROM sync_queue');
    final restoredQueue = LocalSyncQueueRepository(database: database);
    final restore = LocalBackupService(
      database: database,
      localQueue: restoredQueue,
      writeGuard: const AllowAllRepositoryWriteGuard(),
    );
    final result = await restore.restoreBackup(bytes, write);

    expect(result.inserted, greaterThanOrEqualTo(2));
    expect(
        (await restoredQueue.localRecord(
            'projects', 'project-1'))!['project_name'],
        'Backed up');
    expect(await restoredQueue.pendingUploadCount('company-1'), 1);
  });

  test('backup excludes staff access and rejects another company', () async {
    await _insertCompany(database);
    final backup = LocalBackupService(
      database: database,
      localQueue: queue,
      writeGuard: const AllowAllRepositoryWriteGuard(),
    );
    final bytes = await backup.createBackup(write);
    final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final tables = decoded['tables'] as Map<String, dynamic>;
    expect(tables, isNot(contains('staff_access_cache')));
    expect(tables, isNot(contains('device_registry')));
    expect(
      () => backup.restoreBackup(
        bytes,
        const WriteContext(
          companyId: 'company-2',
          userId: 'uid-1',
          deviceId: 'device-1',
        ),
      ),
      throwsFormatException,
    );
  });

  test('PDF and Excel exports produce valid file signatures', () async {
    await _insertCompany(database);
    final exporter = ReportExportService(
      database: database,
      writeGuard: const AllowAllRepositoryWriteGuard(),
    );
    final pdf = await exporter.createPdf(
      companyId: 'company-1',
      summary: _summary(),
    );
    final excel = await exporter.createExcel(
      companyId: 'company-1',
      summary: _summary(),
    );

    expect(ascii.decode(pdf.bytes.take(4).toList()), '%PDF');
    expect(excel.bytes.take(2), [0x50, 0x4b]);
    expect(pdf.fileName, endsWith('.pdf'));
    expect(excel.fileName, endsWith('.xlsx'));
  });

  test('viewer cannot export reports or create backups', () async {
    await _insertCompany(database);
    final viewerGuard = StaffPolicyWriteGuard(_policy(RoleType.viewer));
    final exporter = ReportExportService(
      database: database,
      writeGuard: viewerGuard,
    );
    final backup = LocalBackupService(
      database: database,
      localQueue: queue,
      writeGuard: viewerGuard,
    );

    expect(
      () => exporter.createPdf(companyId: 'company-1', summary: _summary()),
      throwsA(isA<PermissionDeniedException>()),
    );
    expect(
      () => backup.createBackup(write),
      throwsA(isA<PermissionDeniedException>()),
    );
  });
}

StaffAccessPolicy _policy(RoleType role) => StaffAccessPolicy(
      staff: StaffProfile(
        id: 'staff-1',
        companyId: 'company-1',
        name: 'Phase 8 tester',
        firebaseUid: 'uid-1',
        roleId: role.storageKey,
        roleType: role,
        status: StaffStatus.active,
      ),
      allowedPermissions: DefaultRolePermissions.permissionsFor(role),
      assignedProjectIds: const {'project-1'},
    );

Future<void> _insertCompany(ConstructionDatabase database) async {
  await database.ensureSchema();
  await database.customStatement('''
    INSERT OR REPLACE INTO companies (
      id, created_at, updated_at, is_deleted, sync_status, version, name
    ) VALUES ('company-1', 1, 1, 0, 'localOnly', 1, 'Safe Build')
  ''');
}

Future<void> _insertProject(
  ConstructionDatabase database, {
  required String name,
  required int version,
}) async {
  await database.ensureSchema();
  await database.customStatement('''
    INSERT INTO projects (
      id, company_id, created_at, updated_at, is_deleted, sync_status,
      version, project_name, project_status
    ) VALUES ('project-1', 'company-1', 1, 1, 0, 'pendingUpload', ?, ?, 'running')
  ''', [version, name]);
}

SyncDelta _remoteDelta({required String name, required int newVersion}) =>
    SyncDelta(
      deltaId: 'remote-delta',
      companyId: 'company-1',
      entityType: 'projects',
      entityId: 'project-1',
      operation: SyncOperations.update,
      payloadJson: jsonEncode({
        'id': 'project-1',
        'company_id': 'company-1',
        'created_at': 1,
        'updated_at': 2,
        'is_deleted': 0,
        'sync_status': 'uploaded',
        'version': newVersion,
        'project_name': name,
        'project_status': 'running',
      }),
      baseVersion: 1,
      newVersion: newVersion,
      createdAt: 2,
      createdByUserId: 'uid-remote',
      deviceId: 'device-remote',
      schemaVersion: 3,
      status: SyncStatuses.uploaded,
      projectId: 'project-1',
    );

BillingDashboardSummary _summary() => BillingDashboardSummary(
      agreementValue: Money.fromPaise(100000),
      latestEstimateTotal: Money.fromPaise(70000),
      estimatedProfit: Money.fromPaise(30000),
      materialCost: Money.fromPaise(20000),
      laborCost: Money.fromPaise(15000),
      machineryCost: Money.fromPaise(10000),
      fuelCost: Money.fromPaise(5000),
      repairCost: Money.fromPaise(3000),
      otherExpenseCost: Money.fromPaise(2000),
      totalActualCost: Money.fromPaise(55000),
      gstInput: Money.fromPaise(1800),
      gstOutput: Money.fromPaise(3600),
      totalBilled: Money.fromPaise(90000),
      totalReceived: Money.fromPaise(80000),
      pendingReceivable: Money.fromPaise(10000),
      totalPayable: Money.fromPaise(5000),
      actualProfitByAgreement: Money.fromPaise(45000),
      actualProfitByReceived: Money.fromPaise(25000),
    );
