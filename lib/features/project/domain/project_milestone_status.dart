enum ProjectMilestoneStatus {
  planned('planned', 'Planned'),
  inProgress('inProgress', 'In progress'),
  completed('completed', 'Completed'),
  blocked('blocked', 'Blocked');

  const ProjectMilestoneStatus(this.value, this.label);

  final String value;
  final String label;

  static ProjectMilestoneStatus fromValue(String? value) {
    return ProjectMilestoneStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ProjectMilestoneStatus.planned,
    );
  }
}
