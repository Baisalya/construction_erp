import '../../../core/domain/write_context.dart';
import 'agreement_deduction.dart';
import 'project_agreement_summary.dart';
import 'project_agreement_update.dart';
import 'project_milestone.dart';
import 'project_record.dart';

abstract interface class ProjectModuleContract {
  String get moduleName;
  String get phaseResponsibility;

  Future<List<ProjectRecord>> listProjects(String companyId);
  Future<ProjectDashboardStats> loadStats(String companyId);
  Future<ProjectRecord?> findProject(String companyId, String projectId);
  Future<String> createProject(ProjectDraft draft, WriteContext context);

  Future<ProjectAgreementSummary?> loadAgreementSummary(
      String companyId, String projectId);
  Future<void> updateAgreement(
      ProjectAgreementUpdateDraft draft, WriteContext context);

  Future<String> addAgreementDeduction(
      AgreementDeductionDraft draft, WriteContext context);
  Future<List<AgreementDeduction>> listAgreementDeductions(
      String companyId, String projectId);

  Future<String> addMilestone(
      ProjectMilestoneDraft draft, WriteContext context);
  Future<List<ProjectMilestone>> listMilestones(
      String companyId, String projectId);
}
