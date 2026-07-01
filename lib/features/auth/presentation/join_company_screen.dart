import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/presentation/app_feedback.dart';
import '../data/auth_providers.dart';
import '../data/firebase_company_repository.dart';

class JoinCompanyScreen extends ConsumerStatefulWidget {
  const JoinCompanyScreen({super.key});

  @override
  ConsumerState<JoinCompanyScreen> createState() => _JoinCompanyScreenState();
}

class _JoinCompanyScreenState extends ConsumerState<JoinCompanyScreen> {
  final _inviteController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  int _refreshKey = 0;

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Join company')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Accept staff invitation',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Enter the invite code shared by the owner. Your signed-in email must match the invitation.',
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _inviteController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Invite code *',
                                prefixIcon: Icon(Icons.key_outlined),
                              ),
                              onSubmitted: (_) => _acceptCode(),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: _isLoading ? null : _acceptCode,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle_outline),
                              label: const Text('Accept invitation'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Invitations for your email',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (user != null)
                      FutureBuilder<List<PendingCompanyInvitation>>(
                        key: ValueKey(_refreshKey),
                        future: ref
                            .read(companyRepositoryProvider)
                            .listPendingInvitations(user),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return Text(friendlyErrorMessage(snapshot.error!));
                          }
                          final invitations = snapshot.data ?? const [];
                          if (invitations.isEmpty) {
                            return const Card(
                              child: ListTile(
                                leading: Icon(Icons.mark_email_read_outlined),
                                title: Text('No pending invitations'),
                                subtitle: Text(
                                  'Ask the company owner to invite your signed-in email.',
                                ),
                              ),
                            );
                          }
                          return Column(
                            children: [
                              for (final invitation in invitations)
                                Card(
                                  child: ListTile(
                                    leading: const Icon(
                                      Icons.apartment_outlined,
                                    ),
                                    title: Text(invitation.companyName),
                                    subtitle: Text(
                                      'Role: ${invitation.roleName}',
                                    ),
                                    trailing: FilledButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () => _acceptPending(invitation),
                                      child: const Text('Join'),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => context.go('/company/setup'),
                      icon: const Icon(Icons.arrow_back_outlined),
                      label: const Text('Back to company setup'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptCode() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    if (_inviteController.text.trim().isEmpty) {
      setState(() => _error = 'Invite code is required.');
      return;
    }
    await _runAccept(
      () => ref.read(companyRepositoryProvider).acceptInvitationByCode(
            user: user,
            inviteCode: _inviteController.text,
          ),
    );
  }

  Future<void> _acceptPending(PendingCompanyInvitation invitation) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    await _runAccept(
      () => ref.read(companyRepositoryProvider).acceptPendingInvitation(
            user: user,
            companyId: invitation.companyId,
            invitationId: invitation.invitationId,
          ),
    );
  }

  Future<void> _runAccept(Future<Object?> Function() action) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(userCompanyMembershipsProvider(user));
      ref.invalidate(activeWorkspaceProvider(user));
      ref.invalidate(userAccessPolicyProvider(user));
      ref.invalidate(permissionServiceProvider);
      if (mounted) context.go('/');
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = friendlyErrorMessage(
            error,
            fallback: 'Invitation could not be accepted.',
          );
          _refreshKey++;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
