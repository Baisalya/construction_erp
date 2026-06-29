enum TenderStatus {
  draft('draft'),
  applied('applied'),
  submitted('submitted'),
  selected('selected'),
  rejected('rejected'),
  cancelled('cancelled');

  const TenderStatus(this.value);

  final String value;

  static TenderStatus fromValue(String value) {
    return TenderStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => TenderStatus.draft,
    );
  }

  bool get canConvertToProject => this == TenderStatus.selected;
}
