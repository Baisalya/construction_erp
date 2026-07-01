import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth_providers.dart';

class SessionRevokedScreen extends ConsumerWidget {
  const SessionRevokedScreen({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Company access removed')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_off_outlined, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Your access to this company has been removed.',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message ??
                      'You can switch to another company where you are still active, or sign out.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () => context.go('/company/switcher'),
                      icon: const Icon(Icons.swap_horiz_outlined),
                      label: const Text('Switch company'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(authRepositoryProvider).signOut(),
                      icon: const Icon(Icons.logout_outlined),
                      label: const Text('Sign out'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
