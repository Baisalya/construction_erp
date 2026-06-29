import 'package:drift/drift.dart';

import '../../../core/value_objects/money.dart';
import '../../../database/local_database.dart';
import '../domain/project_cost_summary.dart';
import '../domain/reports_module_contract.dart';

class ReportsRepository implements ReportsModuleContract {
  const ReportsRepository({required this.database});

  final ConstructionDatabase database;

  @override
  String get moduleName => 'Reports';

  @override
  String get phaseResponsibility =>
      'Phase 5: ledger-based cost summary plus billing/GST/profit-loss reporting foundation.';

  @override
  Future<ProjectCostSummary> loadProjectCostSummary(
      String companyId, String projectId) async {
    await database.ensureSchema();
    final materialCost = await _sum(
        companyId, 'material_purchase_items', 'total_amount_paise',
        projectId: projectId);
    final laborCost = await _sum(
        companyId, 'labor_work_entries', 'total_amount_paise',
        projectId: projectId);
    final machineryCost = await _sum(
        companyId, 'machine_usage_entries', 'total_amount_paise',
        projectId: projectId);
    final fuelCost = await _sum(companyId, 'fuel_entries', 'total_amount_paise',
        projectId: projectId);
    final repairCost = await _sum(
        companyId, 'machine_repair_entries', 'total_cost_paise',
        projectId: projectId, nullableProject: true);
    final otherExpenseCost = await _sum(
        companyId, 'project_expenses', 'amount_paise',
        projectId: projectId);
    final agreementFinalValue = await _projectMoney(
        companyId, projectId, 'agreement_final_value_paise');
    final totalReceivedAmount = await _sum(
        companyId, 'project_bill_receipts', 'amount_paise',
        projectId: projectId);
    return ProjectCostSummary(
      materialCost: materialCost,
      laborCost: laborCost,
      machineryCost: machineryCost,
      fuelCost: fuelCost,
      repairCost: repairCost,
      otherExpenseCost: otherExpenseCost,
      agreementFinalValue: agreementFinalValue,
      totalReceivedAmount: totalReceivedAmount,
    );
  }

  Future<Money> _sum(String companyId, String tableName, String columnName,
      {required String projectId, bool nullableProject = false}) async {
    final projectClause =
        nullableProject ? 'AND project_id = ?' : 'AND project_id = ?';
    final row = await database.customSelect(
      '''
      SELECT COALESCE(SUM($columnName), 0) AS total
      FROM $tableName
      WHERE company_id = ? AND is_deleted = 0 $projectClause;
      ''',
      variables: [Variable<String>(companyId), Variable<String>(projectId)],
    ).getSingle();
    return Money.fromPaise(row.data['total'] as int? ?? 0);
  }

  Future<Money> _projectMoney(
      String companyId, String projectId, String columnName) async {
    final row = await database.customSelect(
      '''
      SELECT $columnName AS amount
      FROM projects
      WHERE company_id = ? AND id = ? AND is_deleted = 0
      LIMIT 1;
      ''',
      variables: [Variable<String>(companyId), Variable<String>(projectId)],
    ).getSingleOrNull();
    return Money.fromPaise(row?.data['amount'] as int? ?? 0);
  }
}
