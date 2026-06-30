import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/domain/write_context.dart';
import '../../../core/permissions/permission_key.dart';
import '../../../core/permissions/repository_write_guard.dart';
import '../../../core/value_objects/money.dart';
import '../../../database/local_database.dart';
import '../../../database/schema/app_schema_sql.dart';
import '../domain/agreement_calculation_plan.dart';
import '../domain/agreement_deduction.dart';
import '../domain/agreement_deduction_type.dart';
import '../domain/project_agreement_summary.dart';
import '../domain/project_agreement_update.dart';
import '../domain/project_milestone.dart';
import '../domain/project_milestone_status.dart';
import '../domain/project_module_contract.dart';
import '../domain/project_record.dart';
import '../domain/project_status.dart';

class ProjectRepository implements ProjectModuleContract {
  ProjectRepository({
    required this.database,
    ProjectAgreementService agreementService = const ProjectAgreementService(),
    RepositoryWriteGuard writeGuard = const AllowAllRepositoryWriteGuard(),
    Uuid uuid = const Uuid(),
  })  : _agreementService = agreementService,
        _writeGuard = writeGuard,
        _uuid = uuid;

  final ConstructionDatabase database;
  final ProjectAgreementService _agreementService;
  final RepositoryWriteGuard _writeGuard;
  final Uuid _uuid;

  @override
  String get moduleName => 'Project';

  @override
  String get phaseResponsibility =>
      'Phase 4: projects, agreement value calculator, deductions, milestones, and project dashboard.';

  @override
  Future<List<ProjectRecord>> listProjects(String companyId) async {
    await database.ensureSchema();
    final rows = await database.customSelect(
      '''
      SELECT *
      FROM projects
      WHERE company_id = ? AND is_deleted = 0
      ORDER BY updated_at DESC, project_name COLLATE NOCASE;
      ''',
      variables: [Variable<String>(companyId)],
    ).get();
    return rows
        .map(_projectFromRow)
        .where((project) => _writeGuard.canAccessProject(project.id))
        .toList(growable: false);
  }

  @override
  Future<ProjectDashboardStats> loadStats(String companyId) async {
    final projects = await listProjects(companyId);
    if (projects.isEmpty) {
      return ProjectDashboardStats.empty();
    }

    var planned = 0;
    var running = 0;
    var completed = 0;
    var grossPaise = 0;
    var finalPaise = 0;
    var securityPaise = 0;
    var advancePaise = 0;

    for (final project in projects) {
      grossPaise += project.agreementGrossValue.paise;
      finalPaise += project.agreementFinalValue.paise;
      securityPaise += project.securityDepositAmount.paise;
      advancePaise += project.advanceReceived.paise;
      switch (project.projectStatus) {
        case ProjectStatus.planned:
          planned++;
          break;
        case ProjectStatus.running:
          running++;
          break;
        case ProjectStatus.completed:
          completed++;
          break;
        case ProjectStatus.paused:
        case ProjectStatus.cancelled:
          break;
      }
    }

    return ProjectDashboardStats(
      totalProjects: projects.length,
      runningProjects: running,
      plannedProjects: planned,
      completedProjects: completed,
      totalAgreementGrossValue: Money.fromPaise(grossPaise),
      totalAgreementFinalValue: Money.fromPaise(finalPaise),
      totalSecurityDeposit: Money.fromPaise(securityPaise),
      totalAdvanceReceived: Money.fromPaise(advancePaise),
    );
  }

  @override
  Future<ProjectRecord?> findProject(String companyId, String projectId) async {
    if (!_writeGuard.canAccessProject(projectId)) {
      return null;
    }
    await database.ensureSchema();
    final row = await database.customSelect(
      '''
      SELECT *
      FROM projects
      WHERE company_id = ? AND id = ? AND is_deleted = 0
      LIMIT 1;
      ''',
      variables: [Variable<String>(companyId), Variable<String>(projectId)],
    ).getSingleOrNull();
    return row == null ? null : _projectFromRow(row);
  }

  @override
  Future<String> createProject(ProjectDraft draft, WriteContext context) async {
    _writeGuard.require(PermissionKey.projectCreate);
    if (draft.projectName.trim().isEmpty) {
      throw ArgumentError.value(
          draft.projectName, 'projectName', 'Project name is required.');
    }
    _assertMoneyIsSafe('agreementGrossValue', draft.agreementGrossValue);
    _assertMoneyIsSafe('securityDepositAmount', draft.securityDepositAmount);

    await database.ensureSchema();
    final projectId = _uuid.v4();
    final now = context.timestamp;
    final finalValue = _agreementService
        .calculate(
          AgreementCalculationInput(
            grossValue: draft.agreementGrossValue,
            securityDepositAmount: draft.securityDepositAmount,
            deductions: const <AgreementDeduction>[],
          ),
        )
        .finalValue;

    await database.transaction(() async {
      await database.customStatement(
        '''
        INSERT INTO projects (
          id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
          is_deleted, sync_status, version, tender_id, project_code, project_name,
          client_name, department_name, site_location, start_date, expected_end_date, actual_end_date,
          project_status, tender_quoted_price_paise, approved_tender_amount_paise,
          agreement_gross_value_paise, agreement_final_value_paise, gst_rate_basis_points,
          retention_percent_basis_points, security_deposit_amount_paise,
          performance_guarantee_amount_paise, advance_received_paise, notes
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          Variable<String>(projectId),
          Variable<String>(context.companyId),
          Variable<int>(now),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.userId),
          Variable<String>(_clean(draft.tenderId)),
          Variable<String>(_clean(draft.projectCode)),
          Variable<String>(draft.projectName.trim()),
          Variable<String>(_clean(draft.clientName)),
          Variable<String>(_clean(draft.departmentName)),
          Variable<String>(_clean(draft.siteLocation)),
          Variable<int>(draft.startDate),
          Variable<int>(draft.expectedEndDate),
          Variable<String>(draft.projectStatus.value),
          Variable<int>(draft.tenderQuotedPrice.paise),
          Variable<int>(draft.approvedTenderAmount.paise),
          Variable<int>(draft.agreementGrossValue.paise),
          Variable<int>(finalValue.paise),
          Variable<int>(draft.gstRateBasisPoints),
          Variable<int>(draft.retentionPercentBasisPoints),
          Variable<int>(draft.securityDepositAmount.paise),
          Variable<int>(draft.performanceGuaranteeAmount.paise),
          Variable<int>(draft.advanceReceived.paise),
          Variable<String>(_clean(draft.notes)),
        ],
      );
      await _queueDelta(
        context: context,
        now: now,
        entityType: 'projects',
        entityId: projectId,
        operation: 'insert',
        payload: {
          'id': projectId,
          ...draft.toPayload(agreementFinalValue: finalValue),
          ...context.toAuditJson()
        },
      );
    });
    return projectId;
  }

  @override
  Future<ProjectAgreementSummary?> loadAgreementSummary(
      String companyId, String projectId) async {
    final project = await findProject(companyId, projectId);
    if (project == null) {
      return null;
    }
    final deductions = await listAgreementDeductions(companyId, projectId);
    final milestones = await listMilestones(companyId, projectId);
    final calculation = _agreementService.calculate(
      AgreementCalculationInput(
        grossValue: project.agreementGrossValue,
        securityDepositAmount: project.securityDepositAmount,
        deductions: deductions,
      ),
    );
    return ProjectAgreementSummary(
      project: project,
      deductions: deductions,
      milestones: milestones,
      calculation: calculation,
    );
  }

  @override
  Future<void> updateAgreement(
      ProjectAgreementUpdateDraft draft, WriteContext context) async {
    _writeGuard.require(PermissionKey.projectEdit, projectId: draft.projectId);
    _assertMoneyIsSafe('agreementGrossValue', draft.agreementGrossValue);
    await database.ensureSchema();
    final project = await findProject(context.companyId, draft.projectId);
    if (project == null) {
      throw StateError('Project not found.');
    }
    final deductions =
        await listAgreementDeductions(context.companyId, draft.projectId);
    final securityDeposit =
        draft.securityDepositAmount ?? project.securityDepositAmount;
    final finalValue = _agreementService
        .calculate(
          AgreementCalculationInput(
            grossValue: draft.agreementGrossValue,
            securityDepositAmount: securityDeposit,
            deductions: deductions,
          ),
        )
        .finalValue;
    final now = context.timestamp;

    await database.transaction(() async {
      await database.customStatement(
        '''
        UPDATE projects
        SET agreement_gross_value_paise = ?, agreement_final_value_paise = ?,
            approved_tender_amount_paise = ?, gst_rate_basis_points = ?,
            retention_percent_basis_points = ?, security_deposit_amount_paise = ?,
            performance_guarantee_amount_paise = ?, advance_received_paise = ?,
            project_status = ?, notes = COALESCE(?, notes),
            updated_at = ?, updated_by_user_id = ?, sync_status = 'pendingUpload', version = version + 1
        WHERE company_id = ? AND id = ? AND is_deleted = 0;
        ''',
        [
          Variable<int>(draft.agreementGrossValue.paise),
          Variable<int>(finalValue.paise),
          Variable<int>(
              (draft.approvedTenderAmount ?? project.approvedTenderAmount)
                  .paise),
          Variable<int>(draft.gstRateBasisPoints ?? project.gstRateBasisPoints),
          Variable<int>(draft.retentionPercentBasisPoints ??
              project.retentionPercentBasisPoints),
          Variable<int>(securityDeposit.paise),
          Variable<int>((draft.performanceGuaranteeAmount ??
                  project.performanceGuaranteeAmount)
              .paise),
          Variable<int>(
              (draft.advanceReceived ?? project.advanceReceived).paise),
          Variable<String>(
              (draft.projectStatus ?? project.projectStatus).value),
          Variable<String>(_clean(draft.notes)),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.companyId),
          Variable<String>(draft.projectId),
        ],
      );
      await _queueDelta(
        context: context,
        now: now,
        entityType: 'projects',
        entityId: draft.projectId,
        operation: 'update',
        payload: {
          'id': draft.projectId,
          'agreementGrossValuePaise': draft.agreementGrossValue.paise,
          'agreementFinalValuePaise': finalValue.paise,
          'approvedTenderAmountPaise':
              (draft.approvedTenderAmount ?? project.approvedTenderAmount)
                  .paise,
          'gstRateBasisPoints':
              draft.gstRateBasisPoints ?? project.gstRateBasisPoints,
          'retentionPercentBasisPoints': draft.retentionPercentBasisPoints ??
              project.retentionPercentBasisPoints,
          'securityDepositAmountPaise': securityDeposit.paise,
          'performanceGuaranteeAmountPaise':
              (draft.performanceGuaranteeAmount ??
                      project.performanceGuaranteeAmount)
                  .paise,
          'advanceReceivedPaise':
              (draft.advanceReceived ?? project.advanceReceived).paise,
          'projectStatus': (draft.projectStatus ?? project.projectStatus).value,
          'notes': _clean(draft.notes),
          ...context.toAuditJson(),
        },
      );
    });
  }

  @override
  Future<String> addAgreementDeduction(
      AgreementDeductionDraft draft, WriteContext context) async {
    _writeGuard.require(PermissionKey.projectEdit, projectId: draft.projectId);
    _assertMoneyIsSafe('amount', draft.amount);
    await database.ensureSchema();
    final project = await findProject(context.companyId, draft.projectId);
    if (project == null) {
      throw StateError('Project not found.');
    }

    final id = _uuid.v4();
    final now = context.timestamp;
    await database.transaction(() async {
      await database.customStatement(
        '''
        INSERT INTO project_agreement_deductions (
          id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
          is_deleted, sync_status, version, project_id, deduction_date, deduction_type,
          description, amount_paise, is_recoverable, notes
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          Variable<String>(id),
          Variable<String>(context.companyId),
          Variable<int>(now),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.userId),
          Variable<String>(draft.projectId),
          Variable<int>(draft.deductionDate),
          Variable<String>(draft.deductionType.value),
          Variable<String>(_clean(draft.description)),
          Variable<int>(draft.amount.paise),
          Variable<int>(draft.isRecoverable ? 1 : 0),
          Variable<String>(_clean(draft.notes)),
        ],
      );
      await _queueDelta(
        context: context,
        now: now,
        entityType: 'project_agreement_deductions',
        entityId: id,
        operation: 'insert',
        payload: {'id': id, ...draft.toPayload(), ...context.toAuditJson()},
      );
      await _recalculateProjectAgreementFinalValue(draft.projectId, context,
          now: now);
    });
    return id;
  }

  @override
  Future<List<AgreementDeduction>> listAgreementDeductions(
      String companyId, String projectId) async {
    await database.ensureSchema();
    final rows = await database.customSelect(
      '''
      SELECT *
      FROM project_agreement_deductions
      WHERE company_id = ? AND project_id = ? AND is_deleted = 0
      ORDER BY deduction_date DESC, updated_at DESC;
      ''',
      variables: [Variable<String>(companyId), Variable<String>(projectId)],
    ).get();
    return rows.map(_deductionFromRow).toList(growable: false);
  }

  @override
  Future<String> addMilestone(
      ProjectMilestoneDraft draft, WriteContext context) async {
    _writeGuard.require(PermissionKey.projectEdit, projectId: draft.projectId);
    if (draft.title.trim().isEmpty) {
      throw ArgumentError.value(
          draft.title, 'title', 'Milestone title is required.');
    }
    _assertMoneyIsSafe('paymentLinkedAmount', draft.paymentLinkedAmount);
    await database.ensureSchema();
    final project = await findProject(context.companyId, draft.projectId);
    if (project == null) {
      throw StateError('Project not found.');
    }

    final id = _uuid.v4();
    final now = context.timestamp;
    await database.transaction(() async {
      await database.customStatement(
        '''
        INSERT INTO project_milestones (
          id, company_id, created_at, updated_at, created_by_user_id, updated_by_user_id,
          is_deleted, sync_status, version, project_id, title, description,
          planned_date, completed_date, status, payment_linked_amount_paise
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          Variable<String>(id),
          Variable<String>(context.companyId),
          Variable<int>(now),
          Variable<int>(now),
          Variable<String>(context.userId),
          Variable<String>(context.userId),
          Variable<String>(draft.projectId),
          Variable<String>(draft.title.trim()),
          Variable<String>(_clean(draft.description)),
          Variable<int>(draft.plannedDate),
          Variable<int>(draft.completedDate),
          Variable<String>(draft.status.value),
          Variable<int>(draft.paymentLinkedAmount.paise),
        ],
      );
      await _queueDelta(
        context: context,
        now: now,
        entityType: 'project_milestones',
        entityId: id,
        operation: 'insert',
        payload: {'id': id, ...draft.toPayload(), ...context.toAuditJson()},
      );
    });
    return id;
  }

  @override
  Future<List<ProjectMilestone>> listMilestones(
      String companyId, String projectId) async {
    await database.ensureSchema();
    final rows = await database.customSelect(
      '''
      SELECT *
      FROM project_milestones
      WHERE company_id = ? AND project_id = ? AND is_deleted = 0
      ORDER BY COALESCE(planned_date, created_at), title COLLATE NOCASE;
      ''',
      variables: [Variable<String>(companyId), Variable<String>(projectId)],
    ).get();
    return rows.map(_milestoneFromRow).toList(growable: false);
  }

  Future<void> _recalculateProjectAgreementFinalValue(
      String projectId, WriteContext context,
      {required int now}) async {
    final project = await findProject(context.companyId, projectId);
    if (project == null) {
      return;
    }
    final deductions =
        await listAgreementDeductions(context.companyId, projectId);
    final calculation = _agreementService.calculate(
      AgreementCalculationInput(
        grossValue: project.agreementGrossValue,
        securityDepositAmount: project.securityDepositAmount,
        deductions: deductions,
      ),
    );
    await database.customStatement(
      '''
      UPDATE projects
      SET agreement_final_value_paise = ?, updated_at = ?, updated_by_user_id = ?,
          sync_status = 'pendingUpload', version = version + 1
      WHERE company_id = ? AND id = ? AND is_deleted = 0;
      ''',
      [
        Variable<int>(calculation.finalValue.paise),
        Variable<int>(now),
        Variable<String>(context.userId),
        Variable<String>(context.companyId),
        Variable<String>(projectId),
      ],
    );
    await _queueDelta(
      context: context,
      now: now,
      entityType: 'projects',
      entityId: projectId,
      operation: 'update',
      payload: {
        'id': projectId,
        'agreementFinalValuePaise': calculation.finalValue.paise,
        'recalculatedBecause': 'agreement_deduction_changed',
        ...context.toAuditJson(),
      },
    );
  }

  Future<void> _queueDelta({
    required WriteContext context,
    required int now,
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) async {
    final deltaId = _uuid.v4();
    await database.customStatement(
      '''
      INSERT INTO sync_queue (
        id, company_id, created_at, updated_at, created_by_user_id,
        updated_by_user_id, is_deleted, sync_status, version,
        entity_type, entity_id, operation, payload_json, device_id,
        schema_version, status, error_message
      ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, 'pendingUpload', NULL);
      ''',
      [
        Variable<String>(deltaId),
        Variable<String>(context.companyId),
        Variable<int>(now),
        Variable<int>(now),
        Variable<String>(context.userId),
        Variable<String>(context.userId),
        Variable<String>(entityType),
        Variable<String>(entityId),
        Variable<String>(operation),
        Variable<String>(jsonEncode(payload)),
        Variable<String>(context.deviceId),
        Variable<int>(AppSchemaSql.schemaVersion),
      ],
    );
  }

  ProjectRecord _projectFromRow(QueryRow row) {
    return ProjectRecord(
      id: row.data['id'] as String,
      companyId: row.data['company_id'] as String,
      tenderId: row.data['tender_id'] as String?,
      projectCode: row.data['project_code'] as String?,
      projectName: row.data['project_name'] as String,
      clientName: row.data['client_name'] as String?,
      departmentName: row.data['department_name'] as String?,
      siteLocation: row.data['site_location'] as String?,
      startDate: row.data['start_date'] as int?,
      expectedEndDate: row.data['expected_end_date'] as int?,
      actualEndDate: row.data['actual_end_date'] as int?,
      projectStatus:
          ProjectStatus.fromValue(row.data['project_status'] as String),
      tenderQuotedPrice:
          Money.fromPaise(row.data['tender_quoted_price_paise'] as int),
      approvedTenderAmount:
          Money.fromPaise(row.data['approved_tender_amount_paise'] as int),
      agreementGrossValue:
          Money.fromPaise(row.data['agreement_gross_value_paise'] as int),
      agreementFinalValue:
          Money.fromPaise(row.data['agreement_final_value_paise'] as int),
      gstRateBasisPoints: row.data['gst_rate_basis_points'] as int,
      retentionPercentBasisPoints:
          row.data['retention_percent_basis_points'] as int,
      securityDepositAmount:
          Money.fromPaise(row.data['security_deposit_amount_paise'] as int),
      performanceGuaranteeAmount: Money.fromPaise(
          row.data['performance_guarantee_amount_paise'] as int),
      advanceReceived:
          Money.fromPaise(row.data['advance_received_paise'] as int),
      notes: row.data['notes'] as String?,
      version: row.data['version'] as int? ?? 1,
    );
  }

  AgreementDeduction _deductionFromRow(QueryRow row) {
    return AgreementDeduction(
      id: row.data['id'] as String,
      companyId: row.data['company_id'] as String,
      projectId: row.data['project_id'] as String,
      deductionDate: row.data['deduction_date'] as int,
      deductionType: AgreementDeductionType.fromValue(
          row.data['deduction_type'] as String),
      description: row.data['description'] as String?,
      amount: Money.fromPaise(row.data['amount_paise'] as int),
      isRecoverable: (row.data['is_recoverable'] as int) == 1,
      notes: row.data['notes'] as String?,
    );
  }

  ProjectMilestone _milestoneFromRow(QueryRow row) {
    return ProjectMilestone(
      id: row.data['id'] as String,
      companyId: row.data['company_id'] as String,
      projectId: row.data['project_id'] as String,
      title: row.data['title'] as String,
      description: row.data['description'] as String?,
      plannedDate: row.data['planned_date'] as int?,
      completedDate: row.data['completed_date'] as int?,
      status: ProjectMilestoneStatus.fromValue(row.data['status'] as String?),
      paymentLinkedAmount:
          Money.fromPaise(row.data['payment_linked_amount_paise'] as int),
    );
  }

  void _assertMoneyIsSafe(String fieldName, Money money) {
    if (money.paise < 0) {
      throw ArgumentError.value(
          money.paise, fieldName, 'Money amount cannot be negative.');
    }
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
