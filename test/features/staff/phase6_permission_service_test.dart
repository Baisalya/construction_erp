import 'package:construction_erp/core/permissions/permission_key.dart';
import 'package:construction_erp/core/permissions/role_type.dart';
import 'package:construction_erp/core/permissions/staff_status.dart';
import 'package:construction_erp/features/staff/domain/default_role_permissions.dart';
import 'package:construction_erp/features/staff/domain/permission_service.dart';
import 'package:construction_erp/features/staff/domain/staff_access_policy.dart';
import 'package:construction_erp/features/staff/domain/staff_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  StaffAccessPolicy policyFor({
    required RoleType role,
    StaffStatus status = StaffStatus.active,
    Set<String> projects = const <String>{},
  }) {
    final staff = StaffProfile(
      id: 'staff-${role.storageKey}',
      companyId: 'company-1',
      name: role.storageKey,
      roleId: role.storageKey,
      roleType: role,
      status: status,
    );
    return StaffAccessPolicy(
      staff: staff,
      allowedPermissions: DefaultRolePermissions.permissionsFor(role),
      assignedProjectIds: projects,
    );
  }

  test('owner has all permissions', () {
    final service = PermissionService(policyFor(role: RoleType.owner));
    for (final permission in PermissionKey.values) {
      expect(service.can(permission), isTrue, reason: permission.storageKey);
    }
  });

  test('viewer is read-only and cannot create entries', () {
    final service = PermissionService(policyFor(role: RoleType.viewer));
    expect(service.can(PermissionKey.viewOnlyProjectAccess), isTrue);
    expect(service.can(PermissionKey.materialEntry), isFalse);
    expect(service.can(PermissionKey.billingEntry), isFalse);
  });

  test('revoked staff cannot access company data', () {
    final service = PermissionService(
      policyFor(role: RoleType.siteSupervisor, status: StaffStatus.revoked),
    );
    expect(service.can(PermissionKey.materialEntry), isFalse);
    expect(() => service.requireActiveStaff(), throwsException);
  });

  test('inactive staff cannot access company data', () {
    final service = PermissionService(
      policyFor(role: RoleType.accountant, status: StaffStatus.inactive),
    );
    expect(service.can(PermissionKey.gstReports), isFalse);
  });

  test('assigned project access is enforced for non-admin staff', () {
    final service = PermissionService(
      policyFor(role: RoleType.siteSupervisor, projects: {'project-1'}),
    );
    expect(service.canAccessProject('project-1'), isTrue);
    expect(service.canAccessProject('project-2'), isFalse);
  });

  test('admin can access all projects', () {
    final service = PermissionService(policyFor(role: RoleType.admin));
    expect(service.canAccessProject('any-project'), isTrue);
  });

  test('offline cache still blocks revoked staff', () {
    final staff = StaffProfile(
      id: 'staff-offline',
      companyId: 'company-1',
      name: 'Offline user',
      roleId: RoleType.siteSupervisor.storageKey,
      roleType: RoleType.siteSupervisor,
      status: StaffStatus.revoked,
    );
    final policy = StaffAccessPolicy(
      staff: staff,
      allowedPermissions:
          DefaultRolePermissions.permissionsFor(RoleType.siteSupervisor),
      isOfflineCache: true,
    );
    final service = PermissionService(policy);
    expect(service.can(PermissionKey.materialEntry), isFalse);
  });
}
