class StaffRole {
  const StaffRole({
    required this.id,
    required this.companyId,
    required this.name,
    this.description,
    this.isSystemRole = true,
  });

  final String id;
  final String companyId;
  final String name;
  final String? description;
  final bool isSystemRole;
}
