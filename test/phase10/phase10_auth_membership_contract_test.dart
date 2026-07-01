import 'dart:convert';

import 'package:construction_erp/features/auth/domain/app_user.dart';
import 'package:construction_erp/features/auth/domain/app_user_profile.dart';
import 'package:construction_erp/features/auth/domain/company_membership.dart';
import 'package:construction_erp/features/staff/domain/staff_access_policy.dart';
import 'package:construction_erp/features/staff/domain/staff_profile.dart';
import 'package:construction_erp/core/permissions/role_type.dart';
import 'package:construction_erp/core/permissions/permission_key.dart';
import 'package:construction_erp/core/permissions/staff_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 10 auth and membership contract', () {
    test('same email is normalized before lookup or invitation matching', () {
      expect(normalizeEmail(' SamePerson@Gmail.COM '), 'sameperson@gmail.com');
    });

    test('same Firebase UID can own one company and be staff in another', () {
      const uid = 'uid_same_person';
      const owner = CompanyMembership(
        id: 'uid_same_person_company_a',
        uid: uid,
        companyId: 'company_a',
        companyName: 'Company A',
        roleId: 'owner',
        roleName: 'Owner',
        status: 'active',
        isOwner: true,
        canAccessAllProjects: true,
        updatedAt: 1,
      );
      const accountant = CompanyMembership(
        id: 'uid_same_person_company_b',
        uid: uid,
        companyId: 'company_b',
        companyName: 'Company B',
        roleId: 'accountant',
        roleName: 'Accountant',
        status: 'active',
        isOwner: false,
        canAccessAllProjects: false,
        assignedProjectIds: ['project_1'],
        updatedAt: 1,
      );

      expect(owner.uid, accountant.uid);
      expect(owner.isOwner, isTrue);
      expect(accountant.isOwner, isFalse);
      expect(accountant.assignedProjectIds, contains('project_1'));
    });

    test('project restricted staff cannot access unassigned project', () {
      const staff = StaffProfile(
        id: 'staff_1',
        companyId: 'company_a',
        name: 'Site supervisor',
        roleId: 'siteSupervisor',
        roleType: RoleType.siteSupervisor,
        status: StaffStatus.active,
      );
      const policy = StaffAccessPolicy(
        staff: staff,
        allowedPermissions: <PermissionKey>{},
        assignedProjectIds: {'project_allowed'},
      );

      expect(policy.canAccessProject('project_allowed'), isTrue);
      expect(policy.canAccessProject('project_blocked'), isFalse);
    });

    test('all-project flag overrides selected project list', () {
      const staff = StaffProfile(
        id: 'staff_2',
        companyId: 'company_a',
        name: 'Admin',
        roleId: 'admin',
        roleType: RoleType.admin,
        status: StaffStatus.active,
      );
      const policy = StaffAccessPolicy(
        staff: staff,
        allowedPermissions: <PermissionKey>{},
        canAccessAllProjects: true,
      );

      expect(policy.canAccessProject('any_project'), isTrue);
    });

    test('company membership stores assigned projects as JSON', () {
      const membership = CompanyMembership(
        id: 'membership_1',
        uid: 'uid_1',
        companyId: 'company_1',
        companyName: 'Demo Company',
        status: 'active',
        isOwner: false,
        canAccessAllProjects: false,
        assignedProjectIds: ['p1', 'p2'],
        updatedAt: 1,
      );
      expect(jsonDecode(membership.assignedProjectIdsJson), ['p1', 'p2']);
    });

    test('AppUser exposes linked providers and normalized email', () {
      const user = AppUser(
        uid: 'uid_1',
        email: 'OWNER@Example.COM',
        linkedProviders: ['password', 'google.com'],
      );
      expect(user.normalizedEmail, 'owner@example.com');
      expect(user.linkedProviders, contains('google.com'));
    });

    test('fresh Auth mappings for the same UID keep one provider identity', () {
      const first = AppUser(
        uid: 'uid_1',
        email: 'owner@example.com',
        displayName: 'Owner',
      );
      const refreshed = AppUser(
        uid: 'uid_1',
        email: 'OWNER@example.com',
        displayName: 'Updated owner name',
      );

      expect(refreshed, first);
      expect(refreshed.hashCode, first.hashCode);
      expect(<AppUser>{first, refreshed}, hasLength(1));
    });
  });
}
