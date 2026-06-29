import 'package:construction_erp_phase5/core/domain/write_context.dart';
import 'package:construction_erp_phase5/core/value_objects/money.dart';
import 'package:construction_erp_phase5/core/value_objects/quantity.dart';
import 'package:construction_erp_phase5/database/local_database.dart';
import 'package:construction_erp_phase5/features/billing/data/billing_repository.dart';
import 'package:construction_erp_phase5/features/fuel/data/fuel_repository.dart';
import 'package:construction_erp_phase5/features/fuel/domain/fuel_records.dart';
import 'package:construction_erp_phase5/features/project/data/project_repository.dart';
import 'package:construction_erp_phase5/features/project/domain/project_record.dart';
import 'package:construction_erp_phase5/features/work/data/work_repository.dart';
import 'package:construction_erp_phase5/features/work/domain/work_records.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ConstructionDatabase database;
  late ProjectRepository projects;
  late WorkRepository work;
  late FuelRepository fuel;
  late BillingRepository billing;
  const context = WriteContext(
    companyId: 'company-1',
    userId: 'owner-1',
    deviceId: 'device-1',
    nowMillis: 1700000000000,
  );

  setUp(() {
    database = ConstructionDatabase(NativeDatabase.memory());
    projects = ProjectRepository(database: database);
    work = WorkRepository(database: database);
    fuel = FuelRepository(database: database);
    billing = BillingRepository(database: database);
  });
  tearDown(() => database.close());

  test('work days support create, update and soft delete', () async {
    final projectId = await _project(projects, context);
    final id = await work.createWorkDay(
        WorkDayDraft(
            projectId: projectId,
            workDate: context.timestamp,
            siteName: 'North site',
            weather: 'Sunny'),
        context);
    await work.updateWorkDay(
        id,
        WorkDayDraft(
            projectId: projectId,
            workDate: context.timestamp,
            siteName: 'Main site',
            weather: 'Cloudy',
            notes: 'Foundation'),
        context);
    final updated =
        (await work.listWorkDays(context.companyId, projectId: projectId))
            .single;
    expect(updated.siteName, 'Main site');
    expect(updated.notes, 'Foundation');
    await work.deleteWorkDay(id, context);
    expect(await work.listWorkDays(context.companyId, projectId: projectId),
        isEmpty);
  });

  test('project expense CRUD updates payable and project cost', () async {
    final projectId = await _project(projects, context);
    final id = await work.createExpense(
        ProjectExpenseDraft(
          projectId: projectId,
          expenseDate: context.timestamp,
          category: ProjectExpenseCategory.site,
          description: 'Site electricity',
          amount: Money.rupees(5000),
          paidAmount: Money.rupees(2000),
        ),
        context);
    var summary = await billing.loadBillingSummary(context.companyId,
        projectId: projectId);
    expect(summary.otherExpenseCost, Money.rupees(5000));
    expect(summary.totalPayable, Money.rupees(3000));

    await work.updateExpense(
        id,
        ProjectExpenseDraft(
          projectId: projectId,
          expenseDate: context.timestamp,
          category: ProjectExpenseCategory.electricity,
          amount: Money.rupees(6000),
          paidAmount: Money.rupees(2500),
        ),
        context);
    summary = await billing.loadBillingSummary(context.companyId,
        projectId: projectId);
    expect(summary.otherExpenseCost, Money.rupees(6000));
    expect(summary.totalPayable, Money.rupees(3500));
    await work.deleteExpense(id, context);
    summary = await billing.loadBillingSummary(context.companyId,
        projectId: projectId);
    expect(summary.otherExpenseCost, Money.zero);
  });

  test('fuel entries support correction and soft delete', () async {
    final projectId = await _project(projects, context);
    final typeId = await fuel.createFuelType(
        FuelTypeDraft(name: 'Diesel', defaultRate: Money.rupees(90)), context);
    final id = await fuel.createFuelEntry(
        FuelEntryDraft(
          projectId: projectId,
          fuelDate: context.timestamp,
          fuelTypeId: typeId,
          quantity: DecimalQuantity.parse('10'),
          rate: Money.rupees(90),
          usedForType: FuelUsedForType.projectGeneral,
        ),
        context);
    await fuel.updateFuelEntry(
        id,
        FuelEntryDraft(
          projectId: projectId,
          fuelDate: context.timestamp,
          fuelTypeId: typeId,
          quantity: DecimalQuantity.parse('12'),
          rate: Money.rupees(95),
          usedForType: FuelUsedForType.materialTransport,
          paidAmount: Money.rupees(500),
        ),
        context);
    final updated =
        (await fuel.listFuelEntries(context.companyId, projectId: projectId))
            .single;
    expect(updated.totalAmount, Money.rupees(1140));
    expect(updated.pendingAmount, Money.rupees(640));
    await fuel.deleteFuelEntry(id, context);
    expect(await fuel.listFuelEntries(context.companyId, projectId: projectId),
        isEmpty);
  });
}

Future<String> _project(ProjectRepository repository, WriteContext context) =>
    repository.createProject(
        ProjectDraft(
          projectName: 'Test project',
          agreementGrossValue: Money.rupees(100000),
        ),
        context);
