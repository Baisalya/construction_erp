import '../../../core/permissions/permission_key.dart';
import '../../../core/permissions/role_type.dart';
import '../../../core/permissions/staff_status.dart';
import 'staff_profile.dart';

class StaffAccessPolicy {
  const StaffAccessPolicy({
    required this.staff,
    required this.allowedPermissions,
    this.assignedProjectIds = const <String>{},
    this.canAccessAllProjects = false,
    this.cachedAt,
    this.isOfflineCache = false,
  });

  final StaffProfile staff;
  final Set<PermissionKey> allowedPermissions;
  final Set<String> assignedProjectIds;
  final bool canAccessAllProjects;
  final int? cachedAt;
  final bool isOfflineCache;

  bool get isActive => staff.canUseCompanyData;

  bool get isOwnerOrAdmin =>
      staff.roleType == RoleType.owner ||
      staff.roleType == RoleType.admin ||
      staff.roleId == RoleType.owner.storageKey ||
      staff.roleId == RoleType.admin.storageKey;

  bool can(PermissionKey permission) {
    if (!staff.canUseCompanyData) {
      return false;
    }
    if (staff.isOwner) {
      return true;
    }
    return allowedPermissions.contains(permission);
  }

  bool canAccessProject(String projectId) {
    if (!staff.canUseCompanyData) {
      return false;
    }
    if (staff.isOwner || staff.isAdmin || canAccessAllProjects) {
      return true;
    }
    if (assignedProjectIds.isEmpty) {
      return false;
    }
    return assignedProjectIds.contains(projectId);
  }

  void requirePermission(PermissionKey permission) {
    if (!can(permission)) {
      throw PermissionDeniedException(permission);
    }
  }

  void requireActiveStaff() {
    if (!staff.canUseCompanyData) {
      throw StaffAccessBlockedException(staff.status.storageKey);
    }
  }
}

class PermissionDeniedException implements Exception {
  const PermissionDeniedException(this.permission);

  final PermissionKey permission;

  @override
  String toString() => 'Permission denied: ${permission.storageKey}';
}

class StaffAccessBlockedException implements Exception {
  const StaffAccessBlockedException(this.status);

  final String status;

  @override
  String toString() => 'Staff access blocked: $status';
}
