import 'package:construction_erp_phase5/core/permissions/permission_key.dart';
import 'package:construction_erp_phase5/core/domain/write_context.dart';
import 'package:construction_erp_phase5/core/permissions/repository_write_guard.dart';
import 'package:construction_erp_phase5/core/permissions/role_type.dart';
import 'package:construction_erp_phase5/core/permissions/staff_status.dart';
import 'package:construction_erp_phase5/core/value_objects/money.dart';
import 'package:construction_erp_phase5/database/local_database.dart';
import 'package:construction_erp_phase5/features/auth/data/firebase_auth_repository.dart';
import 'package:construction_erp_phase5/features/auth/data/firebase_company_repository.dart';
import 'package:construction_erp_phase5/features/auth/data/local_staff_access_repository.dart';
import 'package:construction_erp_phase5/features/auth/domain/app_user.dart';
import 'package:construction_erp_phase5/features/auth/domain/auth_failure.dart';
import 'package:construction_erp_phase5/features/material/data/material_repository.dart';
import 'package:construction_erp_phase5/features/material/domain/material_records.dart';
import 'package:construction_erp_phase5/features/staff/domain/default_role_permissions.dart';
import 'package:construction_erp_phase5/features/staff/domain/permission_service.dart';
import 'package:construction_erp_phase5/features/staff/domain/staff_access_policy.dart';
import 'package:construction_erp_phase5/features/staff/domain/staff_profile.dart';
import 'package:drift/native.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  late ConstructionDatabase database;

  setUp(() {
    database = ConstructionDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  StaffAccessPolicy policy({
    RoleType role = RoleType.owner,
    StaffStatus status = StaffStatus.active,
    Set<String> projects = const {},
  }) {
    final staff = StaffProfile(
      id: 'staff-1',
      companyId: 'company-1',
      name: 'Test staff',
      firebaseUid: 'uid-1',
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

  test('owner company setup creates company, owner, roles and metadata cache',
      () async {
    final repository = FirebaseCompanyRepository(
      database: database,
      enableRemoteMetadata: false,
    );
    const owner = AppUser(uid: 'owner-uid', email: 'owner@example.com');

    final company = await repository.createOwnerCompany(
      owner: owner,
      companyName: 'Safe Build Pvt Ltd',
      gstNumber: 'GST123',
    );

    expect(await database.countRows('companies'), 1);
    expect(await database.countRows('staff_users'), 1);
    expect(await database.countRows('roles'), RoleType.values.length);
    expect(
      await database.countRows('permissions'),
      RoleType.values.length * PermissionKey.values.length,
    );
    expect(await database.countRows('staff_access_cache'), 1);
    expect(await database.countRows('device_registry'), 1);
    expect(company.name, 'Safe Build Pvt Ltd');
  });

  test('active offline cache is allowed and revoked refresh is blocked',
      () async {
    final cache = LocalStaffAccessRepository(database: database);
    await cache.cacheAccessPolicy(policy(role: RoleType.siteSupervisor));

    var cached = await cache.readCachedPolicyForUid('uid-1');
    expect(cached!.isActive, isTrue);
    expect(cached.isOfflineCache, isTrue);

    await cache.cacheAccessPolicy(
      policy(role: RoleType.siteSupervisor, status: StaffStatus.revoked),
    );
    cached = await cache.readCachedPolicyForUid('uid-1');
    expect(cached!.isActive, isFalse);
    expect(cached.can(PermissionKey.materialEntry), isFalse);
  });

  test('permission refresh replaces local cached permission set', () async {
    final cache = LocalStaffAccessRepository(database: database);
    final initial = policy(role: RoleType.viewer);
    await cache.cacheAccessPolicy(initial);
    await cache.cacheAccessPolicy(
      StaffAccessPolicy(
        staff: initial.staff
            .copyWith(roleType: RoleType.accountant, roleId: 'accountant'),
        allowedPermissions: const {PermissionKey.billingEntry},
      ),
    );

    final refreshed = await cache.readCachedPolicyForUid('uid-1');
    expect(refreshed!.can(PermissionKey.billingEntry), isTrue);
    expect(refreshed.can(PermissionKey.materialEntry), isFalse);
  });

  test('staff.manage is required for staff management', () {
    final viewer = PermissionService(policy(role: RoleType.viewer));
    expect(
      () => viewer.requirePermission(PermissionKey.staffManagement),
      throwsA(isA<PermissionDeniedException>()),
    );
  });

  test('repository write is blocked when permission is missing', () async {
    final repository = MaterialRepository(
      database: database,
      writeGuard: StaffPolicyWriteGuard(policy(role: RoleType.viewer)),
    );

    expect(
      () => repository.createSupplier(
        SupplierDraft(
            supplierName: 'Blocked supplier', openingBalance: Money.zero),
        const WriteContext(
          companyId: 'company-1',
          userId: 'uid-1',
          deviceId: 'device-1',
        ),
      ),
      throwsA(isA<PermissionDeniedException>()),
    );
  });

  test('Firebase auth errors map to readable failures', () {
    final invalid = mapFirebaseAuthException(
      FirebaseAuthException(code: 'invalid-email'),
    );
    final network = mapFirebaseAuthException(
      FirebaseAuthException(code: 'network-request-failed'),
    );

    expect(invalid.code, AuthFailureCode.invalidEmail);
    expect(invalid.message, contains('valid email'));
    expect(network.code, AuthFailureCode.networkUnavailable);
    expect(network.message, contains('Network unavailable'));
  });

  test('Google sign-in cancellation maps to a readable failure', () {
    final failure = mapGoogleSignInException(
      const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      ),
    );

    expect(failure.code, AuthFailureCode.signInCancelled);
    expect(failure.message, contains('cancelled'));
  });

  test('existing-provider collision requests account linking', () {
    final failure = mapFirebaseAuthException(
      FirebaseAuthException(
        code: 'account-exists-with-different-credential',
        email: 'owner@example.com',
      ),
    );

    expect(failure.code, AuthFailureCode.accountLinkRequired);
    expect(failure.email, 'owner@example.com');
  });
}
