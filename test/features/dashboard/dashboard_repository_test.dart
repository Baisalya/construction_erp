import 'package:construction_erp/core/value_objects/money.dart';
import 'package:construction_erp/database/local_database.dart';
import 'package:construction_erp/features/dashboard/data/dashboard_repository.dart';
import 'package:construction_erp/features/project/data/project_repository.dart';
import 'package:construction_erp/features/tender/data/tender_repository.dart';
import 'package:construction_erp/features/billing/data/billing_repository.dart';
import 'package:construction_erp/core/domain/write_context.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ConstructionDatabase database;
  late DashboardRepository repository;
  late ProjectRepository projectRepository;
  late TenderRepository tenderRepository;
  late BillingRepository billingRepository;

  const companyId = 'company-1';
  const context = WriteContext(
    companyId: companyId,
    userId: 'user-1',
    deviceId: 'device-1',
    nowMillis: 1700000000000,
  );

  setUp(() {
    database = ConstructionDatabase(NativeDatabase.memory());
    projectRepository = ProjectRepository(database: database);
    tenderRepository = TenderRepository(database: database);
    billingRepository = BillingRepository(database: database);
    repository = DashboardRepository(
      database: database,
      projects: projectRepository,
      tenders: tenderRepository,
      billing: billingRepository,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('load with activeProjectId (scoped) does not crash and returns stats', () async {
    // 1. Create a project
    await database.customStatement('''
      INSERT INTO projects (
        id, company_id, created_at, updated_at, project_name, project_status, is_deleted
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ''', [
      'proj-1', companyId, 1700000000000, 1700000000000, 'Project 1', 'running', 0
    ]);

    // 2. Load dashboard for this specific project
    // This calls _loadScopedProjectStats internally which had the bug
    final kpis = await repository.load(
      companyId,
      activeProjectId: 'proj-1',
    );

    expect(kpis.runningProjects, 1);
  });

  test('load with allowedProjectIds (scoped) does not crash and returns stats', () async {
    // 1. Create multiple projects
    await database.customStatement('''
      INSERT INTO projects (
        id, company_id, created_at, updated_at, project_name, project_status, is_deleted
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ''', [
      'proj-1', companyId, 1700000000000, 1700000000000, 'Project 1', 'running', 0
    ]);
    await database.customStatement('''
      INSERT INTO projects (
        id, company_id, created_at, updated_at, project_name, project_status, is_deleted
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ''', [
      'proj-2', companyId, 1700000000000, 1700000000000, 'Project 2', 'running', 0
    ]);

    // 2. Load dashboard for a subset of projects
    final kpis = await repository.load(
      companyId,
      allowedProjectIds: {'proj-1'},
    );

    expect(kpis.runningProjects, 1);
  });
}
