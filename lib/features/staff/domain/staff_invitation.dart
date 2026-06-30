class StaffInvitation {
  const StaffInvitation({
    required this.id,
    required this.companyId,
    required this.inviteCode,
    required this.roleId,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.email,
    this.phone,
    this.assignedProjectIds = const <String>[],
    this.createdByUid,
    this.acceptedByUid,
    this.acceptedAt,
  });

  final String id;
  final String companyId;
  final String inviteCode;
  final String roleId;
  final String status;
  final int createdAt;
  final int expiresAt;
  final String? email;
  final String? phone;
  final List<String> assignedProjectIds;
  final String? createdByUid;
  final String? acceptedByUid;
  final int? acceptedAt;
}
