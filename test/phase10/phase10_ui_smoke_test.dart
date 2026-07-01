import 'package:construction_erp/core/permissions/permission_key.dart';
import 'package:construction_erp/core/permissions/role_type.dart';
import 'package:construction_erp/core/permissions/staff_status.dart';
import 'package:construction_erp/database/database_providers.dart';
import 'package:construction_erp/database/local_database.dart';
import 'package:construction_erp/features/auth/data/auth_providers.dart';
import 'package:construction_erp/features/auth/domain/app_user.dart';
import 'package:construction_erp/features/auth/domain/auth_repository_contract.dart';
import 'package:construction_erp/features/auth/domain/company_membership.dart';
import 'package:construction_erp/features/auth/presentation/access_denied_screen.dart';
import 'package:construction_erp/features/auth/presentation/account_settings_screen.dart';
import 'package:construction_erp/features/auth/presentation/company_onboarding_screen.dart';
import 'package:construction_erp/features/auth/presentation/company_switcher_screen.dart';
import 'package:construction_erp/features/auth/presentation/project_switcher_screen.dart';
import 'package:construction_erp/features/auth/presentation/session_revoked_screen.dart';
import 'package:construction_erp/features/staff/domain/staff_access_policy.dart';
import 'package:construction_erp/features/staff/domain/staff_profile.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const user = AppUser(
    uid: 'user-1',
    email: 'owner@example.com',
    displayName: 'Owner',
    photoUrl: '',
    linkedProviders: ['password', 'google.com'],
  );
  const policy = StaffAccessPolicy(
    staff: StaffProfile(
      id: 'user-1',
      companyId: 'company-1',
      name: 'Owner',
      firebaseUid: 'user-1',
      roleId: 'owner',
      roleType: RoleType.owner,
      status: StaffStatus.active,
    ),
    allowedPermissions: <PermissionKey>{},
    canAccessAllProjects: true,
  );

  late ConstructionDatabase database;
  late _FakeAuthRepository auth;

  setUp(() {
    database = ConstructionDatabase(NativeDatabase.memory());
    auth = _FakeAuthRepository(user);
  });
  tearDown(() => database.close());

  Widget app(Widget child) => ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          authRepositoryProvider.overrideWithValue(auth),
          userCompanyMembershipsProvider.overrideWith(
            (ref, user) async => const [
              CompanyMembership(
                id: 'user-1-company-1',
                uid: 'user-1',
                companyId: 'company-1',
                companyName: 'BuildRight Ltd',
                roleId: 'owner',
                roleName: 'Owner',
                status: 'active',
                isOwner: true,
                canAccessAllProjects: true,
                updatedAt: 1,
              ),
            ],
          ),
          activeWorkspaceProvider.overrideWith(
            (ref, user) async => const ActiveWorkspace(
              uid: 'user-1',
              activeCompanyId: 'company-1',
              updatedAt: 1,
            ),
          ),
          userAccessPolicyProvider.overrideWith((ref, user) async => policy),
        ],
        child: MaterialApp(home: child),
      );

  testWidgets('company onboarding opens', (tester) async {
    await tester.pumpWidget(app(const CompanyOnboardingScreen()));
    expect(find.text('Create New Company'), findsOneWidget);
    expect(find.text('Join Company With Invite Code'), findsOneWidget);
  });

  testWidgets('company switcher shows company role and status', (tester) async {
    await tester.pumpWidget(app(const CompanySwitcherScreen()));
    await tester.pumpAndSettle();
    expect(find.text('BuildRight Ltd'), findsOneWidget);
    expect(find.textContaining('Owner • Owner • Active'), findsOneWidget);
  });

  testWidgets('project switcher opens with all-project option', (tester) async {
    await tester.pumpWidget(app(const ProjectSwitcherScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Select project'), findsOneWidget);
    expect(find.text('All allowed projects'), findsOneWidget);
  });

  testWidgets('account settings exposes providers and security actions',
      (tester) async {
    await tester.pumpWidget(app(const AccountSettingsScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.text('Linked sign-in methods'), findsOneWidget);
    expect(find.text('Email password'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
  });

  testWidgets('friendly access denied and revoked pages open', (tester) async {
    await tester.pumpWidget(app(const AccessDeniedScreen()));
    expect(
      find.text('You do not have permission to open this page.'),
      findsOneWidget,
    );
    await tester.pumpWidget(app(const SessionRevokedScreen()));
    expect(
      find.text('Your access to this company has been removed.'),
      findsOneWidget,
    );
  });
}

class _FakeAuthRepository implements AuthRepositoryContract {
  _FakeAuthRepository(this._user);

  AppUser? _user;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> authStateChanges() => Stream<AppUser?>.value(_user);

  @override
  Future<void> signOut() async => _user = null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
