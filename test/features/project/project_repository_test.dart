import 'package:construction_erp_phase5/core/domain/write_context.dart';
import 'package:construction_erp_phase5/core/value_objects/money.dart';
import 'package:construction_erp_phase5/database/local_database.dart';
import 'package:construction_erp_phase5/features/project/data/project_repository.dart';
import 'package:construction_erp_phase5/features/project/domain/agreement_deduction.dart';
import 'package:construction_erp_phase5/features/project/domain/agreement_deduction_type.dart';
import 'package:construction_erp_phase5/features/project/domain/project_agreement_update.dart';
import 'package:construction_erp_phase5/features/project/domain/project_milestone.dart';
import 'package:construction_erp_phase5/features/project/domain/project_milestone_status.dart';
import 'package:construction_erp_phase5/features/project/domain/project_record.dart';
import 'package:construction_erp_phase5/features/project/domain/project_status.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ConstructionDatabase database;
  late ProjectRepository repository;
  const context = WriteContext(
    companyId: 'company-1',
    userId: 'owner-1',
    deviceId: 'device-1',
    nowMillis: 1700000000000,
  );

  setUp(() {
    database = ConstructionDatabase(NativeDatabase.memory());
    repository = ProjectRepository(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  test('creates project and calculates final agreement after security deposit',
      () async {
    final projectId = await repository.createProject(
      ProjectDraft(
        projectName: 'Canal Road Work',
        projectCode: 'PRJ-001',
        agreementGrossValue: Money.rupees(1000000),
        approvedTenderAmount: Money.rupees(1000000),
        securityDepositAmount: Money.rupees(50000),
        advanceReceived: Money.rupees(100000),
      ),
      context,
    );

    final project = await repository.findProject(context.companyId, projectId);

    expect(project, isNotNull);
    expect(project!.agreementGrossValue.paise, 100000000);
    expect(project.agreementFinalValue.paise, 95000000);
    expect(project.advanceReceived.paise, 10000000);
    expect(await database.countRows('sync_queue'), 1);
  });

  test(
      'non-recoverable deductions reduce final value but recoverable deductions do not',
      () async {
    final projectId = await repository.createProject(
      ProjectDraft(
        projectName: 'Bridge Work',
        agreementGrossValue: Money.rupees(500000),
        securityDepositAmount: Money.rupees(25000),
      ),
      context,
    );

    await repository.addAgreementDeduction(
      AgreementDeductionDraft(
        projectId: projectId,
        deductionDate: context.timestamp,
        deductionType: AgreementDeductionType.tenderCost,
        amount: Money.rupees(10000),
      ),
      context,
    );
    await repository.addAgreementDeduction(
      AgreementDeductionDraft(
        projectId: projectId,
        deductionDate: context.timestamp,
        deductionType: AgreementDeductionType.wageAdvance,
        amount: Money.rupees(5000),
        isRecoverable: true,
      ),
      context,
    );

    final summary =
        await repository.loadAgreementSummary(context.companyId, projectId);

    expect(summary, isNotNull);
    expect(summary!.calculation.nonRecoverableDeductions.paise, 1000000);
    expect(summary.calculation.recoverableDeductions.paise, 500000);
    expect(summary.calculation.finalValue.paise, 46500000);
    expect(
        (await repository.findProject(context.companyId, projectId))!
            .agreementFinalValue
            .paise,
        46500000);
    expect(await database.countRows('sync_queue'), 5);
  });

  test('updates agreement value and project status', () async {
    final projectId = await repository.createProject(
      ProjectDraft(
          projectName: 'School Building',
          agreementGrossValue: Money.rupees(200000)),
      context,
    );

    await repository.updateAgreement(
      ProjectAgreementUpdateDraft(
        projectId: projectId,
        agreementGrossValue: Money.rupees(240000),
        securityDepositAmount: Money.rupees(40000),
        projectStatus: ProjectStatus.running,
        gstRateBasisPoints: 1800,
      ),
      context,
    );

    final project = await repository.findProject(context.companyId, projectId);

    expect(project!.agreementGrossValue.paise, 24000000);
    expect(project.agreementFinalValue.paise, 20000000);
    expect(project.projectStatus, ProjectStatus.running);
    expect(project.gstRateBasisPoints, 1800);
  });

  test('adds milestone and project dashboard stats', () async {
    final firstProjectId = await repository.createProject(
      ProjectDraft(
        projectName: 'Drainage Work',
        agreementGrossValue: Money.rupees(300000),
        securityDepositAmount: Money.rupees(30000),
        projectStatus: ProjectStatus.running,
      ),
      context,
    );
    await repository.createProject(
      ProjectDraft(
          projectName: 'Village Road',
          agreementGrossValue: Money.rupees(200000),
          projectStatus: ProjectStatus.planned),
      context,
    );

    await repository.addMilestone(
      ProjectMilestoneDraft(
        projectId: firstProjectId,
        title: 'Earthwork complete',
        status: ProjectMilestoneStatus.planned,
        paymentLinkedAmount: Money.rupees(75000),
      ),
      context,
    );

    final milestones =
        await repository.listMilestones(context.companyId, firstProjectId);
    final stats = await repository.loadStats(context.companyId);

    expect(milestones, hasLength(1));
    expect(milestones.single.paymentLinkedAmount.paise, 7500000);
    expect(stats.totalProjects, 2);
    expect(stats.runningProjects, 1);
    expect(stats.plannedProjects, 1);
    expect(stats.totalAgreementGrossValue.paise, 50000000);
    expect(stats.totalAgreementFinalValue.paise, 47000000);
  });
}
