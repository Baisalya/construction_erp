import '../../../core/permissions/permission_key.dart';
import 'staff_profile.dart';

class StaffAccessPolicy {
  const StaffAccessPolicy(
      {required this.staff, required this.allowedPermissions});

  final StaffProfile staff;
  final Set<PermissionKey> allowedPermissions;

  bool can(PermissionKey permission) {
    if (!staff.canUseCompanyData) {
      return false;
    }
    return allowedPermissions.contains(permission);
  }
}
