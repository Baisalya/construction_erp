enum ProjectStatus {
  planned('planned', 'Planned'),
  running('running', 'Running'),
  paused('paused', 'Paused'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled');

  const ProjectStatus(this.value, this.label);

  final String value;
  final String label;

  static ProjectStatus fromValue(String value) {
    return ProjectStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ProjectStatus.planned,
    );
  }
}
