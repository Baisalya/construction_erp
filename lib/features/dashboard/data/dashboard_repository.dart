import 'package:drift/drift.dart';

import '../../../core/value_objects/money.dart';
import '../../../database/local_database.dart';
import '../../billing/data/billing_repository.dart';
import '../../billing/domain/billing_records.dart';
import '../../project/data/project_repository.dart';
import '../../tender/data/tender_repository.dart';
import '../domain/dashboard_kpis.dart';

class DashboardRepository {
  const DashboardRepository({
    required this.database,
    required this.tenders,
    required this.projects,
    required this.billing,
  });

  final ConstructionDatabase database;
  final TenderRepository tenders;
  final ProjectRepository projects;
  final BillingRepository billing;

  Future<DashboardKpis> load(
    String companyId, {
    Set<String>? allowedProjectIds,
    String? activeProjectId,
  }) async {
    await database.ensureSchema();
    final projectFilter =
        activeProjectId == null ? allowedProjectIds : <String>{activeProjectId};
    if (projectFilter != null && projectFilter.isEmpty) {
      return DashboardKpis.empty();
    }

    final tenderStats = await tenders.loadStats(companyId);
    final runningProjects = projectFilter == null
        ? (await projects.loadStats(companyId)).runningProjects
        : (await _loadScopedProjectStats(companyId, projectFilter))
            .runningProjects;
    final finances = projectFilter == null
        ? await billing.loadBillingSummary(companyId)
        : await _loadScopedBilling(companyId, projectFilter);
    final supplier = await _sum(companyId, 'material_purchases', projectFilter);
    final labor = await _sum(companyId, 'labor_work_entries', projectFilter);
    final machinery = await _sum(
          companyId,
          'machine_usage_entries',
          projectFilter,
        ) +
        await _sum(companyId, 'machine_repair_entries', projectFilter);
    return DashboardKpis(
      activeTenders: tenderStats.activeTenders,
      selectedTenders: tenderStats.selectedTenders,
      runningProjects: runningProjects,
      pendingSupplier: supplier,
      pendingLabor: labor,
      pendingMachinery: machinery,
      totalProjectValue: finances.agreementValue,
      totalExpense: finances.totalActualCost,
      profitByAgreement: finances.actualProfitByAgreement,
      gstInput: finances.gstInput,
      gstOutput: finances.gstOutput,
    );
  }

  Future<_ScopedProjectStats> _loadScopedProjectStats(
    String companyId,
    Set<String> projectIds,
  ) async {
    final where = _projectFilterSql(projectIds, column: 'id');
    final row = await database.customSelect('''
      SELECT COUNT(*) AS running
      FROM projects
      WHERE company_id = ? AND is_deleted = 0
        AND project_status IN ('running', 'active')
        ${where.sql};
    ''', variables: [
      Variable<String>(companyId),
      ...where.variables,
    ]).getSingle();
    return _ScopedProjectStats(row.read<int>('running'));
  }

  Future<BillingDashboardSummary> _loadScopedBilling(
    String companyId,
    Set<String> projectIds,
  ) async {
    final agreement = await _sumColumn(
      companyId,
      'projects',
      'agreement_final_value_paise',
      projectIds: projectIds,
      projectColumn: 'id',
    );
    final material = await _sumColumn(
      companyId,
      'material_purchases',
      'total_amount_paise',
      projectIds: projectIds,
    );
    final labor = await _sumColumn(
      companyId,
      'labor_work_entries',
      'total_amount_paise',
      projectIds: projectIds,
    );
    final machinery = await _sumColumn(
      companyId,
      'machine_usage_entries',
      'total_amount_paise',
      projectIds: projectIds,
    );
    final fuel = await _sumColumn(
      companyId,
      'fuel_entries',
      'total_amount_paise',
      projectIds: projectIds,
    );
    final repair = await _sumColumn(
      companyId,
      'machine_repair_entries',
      'total_cost_paise',
      projectIds: projectIds,
    );
    final expense = await _sumColumn(
      companyId,
      'project_expenses',
      'amount_paise',
      projectIds: projectIds,
    );
    final billed = await _sumColumn(
      companyId,
      'project_bills',
      'net_receivable_amount_paise',
      projectIds: projectIds,
    );
    final pendingReceivable = await _sumColumn(
      companyId,
      'project_bills',
      'pending_amount_paise',
      projectIds: projectIds,
    );
    final received = await _sumColumn(
      companyId,
      'project_bill_receipts',
      'amount_paise',
      projectIds: projectIds,
    );
    final gstInput = await _sumGst(companyId, projectIds, 'input');
    final gstOutput = await _sumGst(companyId, projectIds, 'output');
    final latestEstimateTotal =
        await _latestEstimateTotal(companyId, projectIds);
    final totalActual = material + labor + machinery + fuel + repair + expense;
    final totalPayable = await _sumColumn(
            companyId, 'material_purchases', 'pending_amount_paise',
            projectIds: projectIds) +
        await _sumColumn(
            companyId, 'labor_work_entries', 'pending_amount_paise',
            projectIds: projectIds) +
        await _sumColumn(
            companyId, 'machine_usage_entries', 'pending_amount_paise',
            projectIds: projectIds) +
        await _sumColumn(companyId, 'fuel_entries', 'pending_amount_paise',
            projectIds: projectIds) +
        await _sumColumn(
            companyId, 'machine_repair_entries', 'pending_amount_paise',
            projectIds: projectIds) +
        await _sumColumn(companyId, 'project_expenses', 'pending_amount_paise',
            projectIds: projectIds);
    return BillingDashboardSummary(
      agreementValue: agreement,
      latestEstimateTotal: latestEstimateTotal,
      estimatedProfit: agreement - latestEstimateTotal,
      materialCost: material,
      laborCost: labor,
      machineryCost: machinery,
      fuelCost: fuel,
      repairCost: repair,
      otherExpenseCost: expense,
      totalActualCost: totalActual,
      gstInput: gstInput,
      gstOutput: gstOutput,
      totalBilled: billed,
      totalReceived: received,
      pendingReceivable: pendingReceivable,
      totalPayable: totalPayable,
      actualProfitByAgreement: agreement - totalActual,
      actualProfitByReceived: received - totalActual,
    );
  }

  Future<Money> _sum(
    String companyId,
    String table,
    Set<String>? projectIds,
  ) async {
    const allowed = {
      'material_purchases',
      'labor_work_entries',
      'machine_usage_entries',
      'machine_repair_entries',
    };
    if (!allowed.contains(table)) throw ArgumentError('Unsupported table.');
    return _sumColumn(
      companyId,
      table,
      'pending_amount_paise',
      projectIds: projectIds,
    );
  }

  Future<Money> _sumColumn(
    String companyId,
    String table,
    String column, {
    Set<String>? projectIds,
    String projectColumn = 'project_id',
  }) async {
    final where = projectIds == null
        ? _SqlFilter.empty()
        : _projectFilterSql(projectIds, column: projectColumn);
    final row = await database.customSelect('''
      SELECT COALESCE(SUM($column), 0) AS total
      FROM $table
      WHERE company_id = ? AND is_deleted = 0 ${where.sql};
    ''', variables: [
      Variable<String>(companyId),
      ...where.variables,
    ]).getSingle();
    return Money.fromPaise(row.read<int>('total'));
  }

  Future<Money> _sumGst(
    String companyId,
    Set<String> projectIds,
    String type,
  ) async {
    final where = _projectFilterSql(projectIds);
    final row = await database.customSelect('''
      SELECT COALESCE(SUM(gst_amount_paise), 0) AS total
      FROM gst_entries
      WHERE company_id = ? AND is_deleted = 0 AND gst_type = ? ${where.sql};
    ''', variables: [
      Variable<String>(companyId),
      Variable<String>(type),
      ...where.variables,
    ]).getSingle();
    return Money.fromPaise(row.read<int>('total'));
  }

  Future<Money> _latestEstimateTotal(
    String companyId,
    Set<String> projectIds,
  ) async {
    final where = _projectFilterSql(projectIds, column: 'estimate.project_id');
    final row = await database.customSelect('''
      SELECT COALESCE(SUM(estimate.total_estimated_cost_paise), 0) AS total
      FROM project_estimates estimate
      WHERE estimate.company_id = ? AND estimate.is_deleted = 0 ${where.sql}
        AND NOT EXISTS (
          SELECT 1 FROM project_estimates newer
          WHERE newer.company_id = estimate.company_id
            AND newer.project_id = estimate.project_id
            AND newer.is_deleted = 0
            AND (newer.estimate_date > estimate.estimate_date
              OR (newer.estimate_date = estimate.estimate_date
                AND newer.updated_at > estimate.updated_at))
        );
    ''', variables: [
      Variable<String>(companyId),
      ...where.variables,
    ]).getSingle();
    return Money.fromPaise(row.read<int>('total'));
  }

  _SqlFilter _projectFilterSql(Set<String> projectIds,
      {String column = 'project_id'}) {
    final placeholders = List.filled(projectIds.length, '?').join(', ');
    return _SqlFilter(
      'AND $column IN ($placeholders)',
      [for (final projectId in projectIds) Variable<String>(projectId)],
    );
  }
}

class _ScopedProjectStats {
  const _ScopedProjectStats(this.runningProjects);
  final int runningProjects;
}

class _SqlFilter {
  const _SqlFilter(this.sql, this.variables);
  factory _SqlFilter.empty() => const _SqlFilter('', []);
  final String sql;
  final List<Variable<String>> variables;
}
