import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth_providers.dart';

class CompanyOnboardingScreen extends ConsumerWidget {
  const CompanyOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose company setup'),
        actions: [
          TextButton.icon(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            icon: const Icon(Icons.logout_outlined),
            label: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Welcome${user?.displayName == null ? '' : ', ${user!.displayName}'}',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a new construction company or join an existing company using an invitation.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: [
                      _OnboardingCard(
                        icon: Icons.apartment_outlined,
                        title: 'Create New Company',
                        body:
                            'Use this if you are the owner/admin and want to start your own company workspace.',
                        buttonText: 'Create company',
                        onPressed: () => context.go('/company/create'),
                      ),
                      _OnboardingCard(
                        icon: Icons.mark_email_read_outlined,
                        title: 'Join Company With Invite Code',
                        body:
                            'Use this if an owner invited you as staff, accountant, supervisor, or viewer.',
                        buttonText: 'Join company',
                        onPressed: () => context.go('/company/join'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String body;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(icon, size: 40),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(body),
              const SizedBox(height: 20),
              FilledButton(onPressed: onPressed, child: Text(buttonText)),
            ],
          ),
        ),
      ),
    );
  }
}
