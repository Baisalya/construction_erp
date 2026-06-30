import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_gate.dart';
import '../../features/auth/presentation/company_setup_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_owner_screen.dart';
import '../../features/staff/presentation/role_permission_screen.dart';
import '../../sync/presentation/sync_status_screen.dart';
import '../../sync/presentation/sync_conflicts_screen.dart';

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
        builder: (context, state) => const CompanySetupScreen(),
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
