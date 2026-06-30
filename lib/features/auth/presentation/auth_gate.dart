import 'package:construction_erp/core/permissions/staff_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/presentation/app_feedback.dart';

import '../../../shared/presentation/app_shell.dart';
import '../data/auth_providers.dart';
import 'blocked_access_screen.dart';
import 'company_setup_screen.dart';
import 'firebase_setup_error_screen.dart';
import 'login_screen.dart';

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
        final accessState = ref.watch(userAccessPolicyProvider(user));
        return accessState.when(
          data: (policy) {
            if (policy == null) {
              return const CompanySetupScreen();
            }
            if (!policy.isActive) {
              return BlockedAccessScreen(
                status: policy.staff.status.storageKey,
              );
            }
            return const AppShell();
          },
          loading: () =>
              const _GateLoading(message: 'Checking company access...'),
          error: (error, stackTrace) => BlockedAccessScreen(
            status: 'error',
            message: friendlyErrorMessage(error),
          ),
        );
      },
      loading: () => const _GateLoading(message: 'Checking login...'),
      error: (error, stackTrace) => BlockedAccessScreen(
        status: 'auth_error',
        message: friendlyErrorMessage(error),
      ),
    );
  }
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
