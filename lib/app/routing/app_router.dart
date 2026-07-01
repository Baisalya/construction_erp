import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/access_denied_screen.dart';
import '../../features/auth/presentation/account_settings_screen.dart';
import '../../features/auth/presentation/auth_gate.dart';
import '../../features/auth/presentation/company_onboarding_screen.dart';
import '../../features/auth/presentation/company_settings_screen.dart';
import '../../features/auth/presentation/company_setup_screen.dart';
import '../../features/auth/presentation/company_switcher_screen.dart';
import '../../features/auth/presentation/join_company_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/project_access_management_screen.dart';
import '../../features/auth/presentation/project_switcher_screen.dart';
import '../../features/auth/presentation/register_owner_screen.dart';
import '../../features/auth/presentation/session_revoked_screen.dart';
import '../../features/staff/presentation/role_permission_screen.dart';
import '../../sync/presentation/sync_conflicts_screen.dart';
import '../../sync/presentation/sync_status_screen.dart';

final appRouterProvider = Provider((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'authGate',
        builder: (context, state) => const AuthGate(),
      ),
      GoRoute(
        path: '/auth/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register-owner',
        name: 'registerOwner',
        builder: (context, state) => const RegisterOwnerScreen(),
      ),
      GoRoute(
        path: '/company/setup',
        name: 'companySetup',
        builder: (context, state) => const CompanyOnboardingScreen(),
      ),
      GoRoute(
        path: '/company/create',
        name: 'companyCreate',
        builder: (context, state) => const CompanySetupScreen(),
      ),
      GoRoute(
        path: '/company/join',
        name: 'companyJoin',
        builder: (context, state) => const JoinCompanyScreen(),
      ),
      GoRoute(
        path: '/company/switcher',
        name: 'companySwitcher',
        builder: (context, state) => const CompanySwitcherScreen(),
      ),
      GoRoute(
        path: '/company/settings',
        name: 'companySettings',
        builder: (context, state) => const CompanySettingsScreen(),
      ),
      GoRoute(
        path: '/project/switcher',
        name: 'projectSwitcher',
        builder: (context, state) => const ProjectSwitcherScreen(),
      ),
      GoRoute(
        path: '/project/access',
        name: 'projectAccess',
        builder: (context, state) => const ProjectAccessManagementScreen(),
      ),
      GoRoute(
        path: '/account/settings',
        name: 'accountSettings',
        builder: (context, state) => const AccountSettingsScreen(),
      ),
      GoRoute(
        path: '/access-denied',
        name: 'accessDenied',
        builder: (context, state) => const AccessDeniedScreen(),
      ),
      GoRoute(
        path: '/session/revoked',
        name: 'sessionRevoked',
        builder: (context, state) => const SessionRevokedScreen(),
      ),
      GoRoute(
        path: '/roles',
        name: 'roles',
        builder: (context, state) => const RolePermissionScreen(),
      ),
      GoRoute(
        path: '/sync',
        name: 'syncStatus',
        builder: (context, state) => const SyncStatusScreen(),
      ),
      GoRoute(
        path: '/sync/conflicts',
        name: 'syncConflicts',
        builder: (context, state) => const SyncConflictsScreen(),
      ),
    ],
  );
});
