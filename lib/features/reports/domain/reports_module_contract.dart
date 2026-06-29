import 'project_cost_summary.dart';

abstract interface class ReportsModuleContract {
  String get moduleName;
  String get phaseResponsibility;

  Future<ProjectCostSummary> loadProjectCostSummary(
      String companyId, String projectId);
}
