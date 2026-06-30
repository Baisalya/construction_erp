import '../../../core/permissions/permission_key.dart';
import 'staff_access_policy.dart';

class PermissionService {
  const PermissionService(this.policy);

  final StaffAccessPolicy policy;

  bool can(PermissionKey permission) => policy.can(permission);

  bool canAccessProject(String projectId) => policy.canAccessProject(projectId);

  bool isOwnerOrAdmin() => policy.isOwnerOrAdmin;

  void requirePermission(PermissionKey permission) {
    policy.requirePermission(permission);
  }

  void requireActiveStaff() {
    policy.requireActiveStaff();
  }
}
