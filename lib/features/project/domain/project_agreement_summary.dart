import '../../../core/value_objects/money.dart';
import 'agreement_calculation_plan.dart';
import 'agreement_deduction.dart';
import 'project_milestone.dart';
import 'project_record.dart';

class ProjectAgreementSummary {
  const ProjectAgreementSummary({
    required this.project,
    required this.deductions,
    required this.milestones,
    required this.calculation,
  });

  final ProjectRecord project;
  final List<AgreementDeduction> deductions;
  final List<ProjectMilestone> milestones;
  final AgreementCalculationResult calculation;
}

class ProjectDashboardStats {
  const ProjectDashboardStats({
    required this.totalProjects,
    required this.runningProjects,
    required this.plannedProjects,
    required this.completedProjects,
    required this.totalAgreementGrossValue,
    required this.totalAgreementFinalValue,
    required this.totalSecurityDeposit,
    required this.totalAdvanceReceived,
  });

  factory ProjectDashboardStats.empty() {
    return const ProjectDashboardStats(
      totalProjects: 0,
      runningProjects: 0,
      plannedProjects: 0,
      completedProjects: 0,
      totalAgreementGrossValue: Money.zero,
      totalAgreementFinalValue: Money.zero,
      totalSecurityDeposit: Money.zero,
      totalAdvanceReceived: Money.zero,
    );
  }

  final int totalProjects;
  final int runningProjects;
  final int plannedProjects;
  final int completedProjects;
  final Money totalAgreementGrossValue;
  final Money totalAgreementFinalValue;
  final Money totalSecurityDeposit;
  final Money totalAdvanceReceived;
}
