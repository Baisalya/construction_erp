class CompanyProfile {
  const CompanyProfile({
    required this.id,
    required this.name,
    this.gstNumber,
    this.panNumber,
    this.address,
    this.phone,
    this.email,
    this.logoPath,
    this.financialYearStart,
    this.financialYearEnd,
  });

  final String id;
  final String name;
  final String? gstNumber;
  final String? panNumber;
  final String? address;
  final String? phone;
  final String? email;
  final String? logoPath;
  final int? financialYearStart;
  final int? financialYearEnd;
}
