import '../../../core/value_objects/money.dart';
import 'project_milestone_status.dart';

class ProjectMilestone {
  const ProjectMilestone({
    required this.id,
    required this.companyId,
    required this.projectId,
    required this.title,
    required this.status,
    required this.paymentLinkedAmount,
    this.description,
    this.plannedDate,
    this.completedDate,
  });

  final String id;
  final String companyId;
  final String projectId;
  final String title;
  final String? description;
  final int? plannedDate;
  final int? completedDate;
  final ProjectMilestoneStatus status;
  final Money paymentLinkedAmount;
}

class ProjectMilestoneDraft {
  const ProjectMilestoneDraft({
    required this.projectId,
    required this.title,
    this.description,
    this.plannedDate,
    this.completedDate,
    this.status = ProjectMilestoneStatus.planned,
    this.paymentLinkedAmount = Money.zero,
  });

  final String projectId;
  final String title;
  final String? description;
  final int? plannedDate;
  final int? completedDate;
  final ProjectMilestoneStatus status;
  final Money paymentLinkedAmount;

  Map<String, Object?> toPayload() {
    return {
      'projectId': projectId,
      'title': title,
      'description': description,
      'plannedDate': plannedDate,
      'completedDate': completedDate,
      'status': status.value,
      'paymentLinkedAmountPaise': paymentLinkedAmount.paise,
    };
  }
}
