import 'dart:convert';

class CompanyMembership {
  const CompanyMembership({
    required this.id,
    required this.uid,
    required this.companyId,
    required this.companyName,
    this.roleId,
    this.roleName,
    required this.status,
    required this.isOwner,
    required this.canAccessAllProjects,
    this.assignedProjectIds = const <String>[],
    this.lastAccessAt,
    required this.updatedAt,
  });

  final String id;
  final String uid;
  final String companyId;
  final String companyName;
  final String? roleId;
  final String? roleName;
  final String status;
  final bool isOwner;
  final bool canAccessAllProjects;
  final List<String> assignedProjectIds;
  final int? lastAccessAt;
  final int updatedAt;

  bool get isActive => status == 'active';
  bool get isBlocked => status == 'revoked' || status == 'suspended';
  String get assignedProjectIdsJson => jsonEncode(assignedProjectIds.toList());
}

class ActiveWorkspace {
  const ActiveWorkspace({
    required this.uid,
    this.activeCompanyId,
    this.activeProjectId,
    required this.updatedAt,
  });

  final String uid;
  final String? activeCompanyId;
  final String? activeProjectId;
  final int updatedAt;
}
