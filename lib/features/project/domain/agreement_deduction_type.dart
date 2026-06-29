enum AgreementDeductionType {
  tenderCost('tenderCost', 'Tender cost'),
  securityDeposit('securityDeposit', 'Security deposit'),
  gst('gst', 'GST'),
  tds('tds', 'TDS'),
  retention('retention', 'Retention'),
  document('document', 'Document'),
  wageAdvance('wageAdvance', 'Wage advance'),
  misc('misc', 'Miscellaneous');

  const AgreementDeductionType(this.value, this.label);

  final String value;
  final String label;

  static AgreementDeductionType fromValue(String value) {
    return AgreementDeductionType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => AgreementDeductionType.misc,
    );
  }
}
