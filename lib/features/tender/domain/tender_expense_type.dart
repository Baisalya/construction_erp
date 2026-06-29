enum TenderExpenseType {
  tenderFee('tenderFee'),
  emd('emd'),
  document('document'),
  travel('travel'),
  staff('staff'),
  misc('misc');

  const TenderExpenseType(this.value);

  final String value;

  static TenderExpenseType fromValue(String value) {
    return TenderExpenseType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => TenderExpenseType.misc,
    );
  }
}
