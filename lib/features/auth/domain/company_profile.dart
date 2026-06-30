class CompanyProfile {
  const CompanyProfile({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.gstNumber,
    this.panNumber,
    this.address,
    this.phone,
    this.email,
    this.logoPath,
    this.financialYearStart,
    this.financialYearEnd,
    this.ownerUid,
    this.status = 'active',
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
  final String? ownerUid;
  final String status;
  final int createdAt;
  final int updatedAt;
}
