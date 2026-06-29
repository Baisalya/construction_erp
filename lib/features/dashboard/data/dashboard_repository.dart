import 'package:drift/drift.dart';

import '../../../core/value_objects/money.dart';
import '../../../database/local_database.dart';
import '../../billing/data/billing_repository.dart';
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

  Future<DashboardKpis> load(String companyId) async {
    await database.ensureSchema();
    final tenderStats = await tenders.loadStats(companyId);
    final projectStats = await projects.loadStats(companyId);
    final finances = await billing.loadBillingSummary(companyId);
    final supplier = await _sum(companyId, 'material_purchases');
    final labor = await _sum(companyId, 'labor_work_entries');
    final machinery = await _sum(companyId, 'machine_usage_entries') +
        await _sum(companyId, 'machine_repair_entries');
    return DashboardKpis(
      activeTenders: tenderStats.activeTenders,
      selectedTenders: tenderStats.selectedTenders,
      runningProjects: projectStats.runningProjects,
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

  Future<Money> _sum(String companyId, String table) async {
    const allowed = {
      'material_purchases',
      'labor_work_entries',
      'machine_usage_entries',
      'machine_repair_entries',
    };
    if (!allowed.contains(table)) throw ArgumentError('Unsupported table.');
    final row = await database.customSelect('''
      SELECT COALESCE(SUM(pending_amount_paise), 0) AS total
      FROM $table WHERE company_id = ? AND is_deleted = 0;
    ''', variables: [Variable<String>(companyId)]).getSingle();
    return Money.fromPaise(row.read<int>('total'));
  }
}
