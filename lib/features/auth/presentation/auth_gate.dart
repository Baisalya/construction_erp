import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/presentation/app_feedback.dart';
import '../../../shared/presentation/app_shell.dart';
import '../../../core/firebase/firestore_setup_error.dart';
import '../data/auth_providers.dart';
import 'blocked_access_screen.dart';
import 'company_onboarding_screen.dart';
import 'company_switcher_screen.dart';
import 'firebase_setup_error_screen.dart';
import 'login_screen.dart';
import 'session_revoked_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebaseState = ref.watch(firebaseBootstrapProvider);
    if (!firebaseState.isReady) {
      return FirebaseSetupErrorScreen(
        errorMessage:
            firebaseState.errorMessage ?? 'Firebase is not configured.',
      );
    }

    final authState = ref.watch(authStateProvider);
    return authState.when(
      data: (user) {
        if (user == null) {
          return const LoginScreen();
        }
        final membershipsState =
            ref.watch(userCompanyMembershipsProvider(user));
        return membershipsState.when(
          data: (memberships) {
            final activeMemberships =
                memberships.where((membership) => membership.isActive).toList();
            if (activeMemberships.isEmpty) {
              return const CompanyOnboardingScreen();
            }
            final workspaceState = ref.watch(activeWorkspaceProvider(user));
            final activeCompanyId = workspaceState.valueOrNull?.activeCompanyId;
            if (activeMemberships.length > 1 && activeCompanyId == null) {
              return const CompanySwitcherScreen();
            }
            final accessState = ref.watch(userAccessPolicyProvider(user));
            return accessState.when(
              data: (policy) {
                if (policy == null) {
                  return activeMemberships.length == 1
                      ? const SessionRevokedScreen(
                          message:
                              'Your company membership could not be verified. Ask the owner to restore access.',
                        )
                      : const CompanySwitcherScreen();
                }
                if (!policy.isActive) {
                  return const SessionRevokedScreen();
                }
                return const AppShell();
              },
              loading: () =>
                  const _GateLoading(message: 'Checking company access...'),
              error: (error, stackTrace) =>
                  _accessErrorScreen(error, status: 'error'),
            );
          },
          loading: () => const _GateLoading(message: 'Loading companies...'),
          error: (error, stackTrace) =>
              _accessErrorScreen(error, status: 'company_error'),
        );
      },
      loading: () => const _GateLoading(message: 'Checking login...'),
      error: (error, stackTrace) =>
          _accessErrorScreen(error, status: 'auth_error'),
    );
  }
}

Widget _accessErrorScreen(Object error, {required String status}) {
  if (isMissingStaffLookupIndexError(error)) {
    return const FirebaseSetupErrorScreen(
      title: 'Firebase setup required',
      userMessage: missingStaffLookupIndexMessage,
      errorMessage: missingStaffLookupIndexDeveloperDetails,
    );
  }
  return BlockedAccessScreen(
    status: status,
    message: friendlyErrorMessage(error),
  );
}

class _GateLoading extends StatelessWidget {
  const _GateLoading({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
}
