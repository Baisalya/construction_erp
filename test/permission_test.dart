import 'package:construction_erp/core/permissions/permission_key.dart';
import 'package:construction_erp/core/permissions/staff_status.dart';
import 'package:construction_erp/features/staff/domain/staff_access_policy.dart';
import 'package:construction_erp/features/staff/domain/staff_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('revoked staff cannot use permissions', () {
    const staff = StaffProfile(
      id: 'staff-1',
      companyId: 'company-1',
      name: 'Site User',
      status: StaffStatus.revoked,
    );
    const policy = StaffAccessPolicy(
      staff: staff,
      allowedPermissions: {PermissionKey.materialEntry},
    );

    expect(policy.can(PermissionKey.materialEntry), isFalse);
  });

  test('active staff only receives explicitly allowed permissions', () {
    const staff = StaffProfile(
      id: 'staff-2',
      companyId: 'company-1',
      name: 'Accountant',
      status: StaffStatus.active,
    );
    const policy = StaffAccessPolicy(
      staff: staff,
      allowedPermissions: {PermissionKey.billingEntry},
    );

    expect(policy.can(PermissionKey.billingEntry), isTrue);
    expect(policy.can(PermissionKey.staffManagement), isFalse);
  });
}
