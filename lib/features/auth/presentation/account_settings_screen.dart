import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/presentation/app_feedback.dart';
import '../data/auth_providers.dart';
import '../domain/app_user.dart';
import '../domain/auth_failure.dart';

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  bool _busy = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final providers = user?.linkedProviders.toSet() ?? const <String>{};
    final photoUrl = _validNetworkPhotoUrl(user?.photoUrl);
    return Scaffold(
      appBar: AppBar(title: const Text('Account settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                foregroundImage:
                    photoUrl == null ? null : NetworkImage(photoUrl),
                onForegroundImageError: photoUrl == null ? null : (_, __) {},
                child: const Icon(Icons.person_outline),
              ),
              title: Text(
                user?.displayName?.isNotEmpty == true
                    ? user!.displayName!
                    : 'Account',
              ),
              subtitle: Text(user?.email ?? 'No email found'),
              trailing: IconButton(
                tooltip: 'Edit profile',
                onPressed:
                    _busy || user == null ? null : () => _editProfile(user),
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Linked sign-in methods',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (providers.isEmpty)
                    const Text('No sign-in method is connected.')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final provider in providers)
                          InputChip(
                            label: Text(_providerName(provider)),
                            onDeleted: providers.length <= 1 || _busy
                                ? null
                                : () => _unlink(provider),
                            deleteButtonTooltipMessage:
                                'Disconnect ${_providerName(provider)}',
                          ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy || providers.contains('google.com')
                            ? null
                            : _linkGoogle,
                        icon: const Icon(Icons.link_outlined),
                        label: const Text('Link Google'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ||
                                user?.email == null ||
                                providers.contains('password')
                            ? null
                            : () => _addPassword(user!),
                        icon: const Icon(Icons.password_outlined),
                        label: const Text('Add password'),
                      ),
                      if (providers.contains('password'))
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _changePassword,
                          icon: const Icon(Icons.lock_reset_outlined),
                          label: const Text('Change password'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'For safety, the last sign-in method cannot be removed.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.swap_horiz_outlined),
                  title: const Text('Default company / switch company'),
                  subtitle: const Text(
                    'The company you switch to becomes your default company.',
                  ),
                  onTap: () => context.push('/company/switcher'),
                ),
                ListTile(
                  leading: const Icon(Icons.filter_alt_outlined),
                  title: const Text('Project filter'),
                  onTap: () => context.push('/project/switcher'),
                ),
                ListTile(
                  leading: const Icon(Icons.logout_outlined),
                  title: const Text('Sign out'),
                  onTap: _busy ? null : _signOut,
                ),
              ],
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(
              _message!,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editProfile(AppUser user) async {
    final name = TextEditingController(text: user.displayName);
    final photo = TextEditingController(text: user.photoUrl);
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit account'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name *'),
                ),
                TextField(
                  controller: photo,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Photo URL (optional)',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Login email: ${user.email ?? 'Not available'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(context, [name.text, photo.text]);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    name.dispose();
    photo.dispose();
    if (result == null) return;
    await _run(() async {
      final updated = await ref.read(authRepositoryProvider).updateProfile(
            displayName: result[0],
            photoUrl: result[1],
          );
      await ref.read(companyRepositoryProvider).syncUserProfile(updated);
      return 'Account details updated.';
    });
  }

  Future<void> _linkGoogle() => _run(() async {
        final updated =
            await ref.read(authRepositoryProvider).linkGoogleToCurrentUser();
        await ref.read(companyRepositoryProvider).syncUserProfile(updated);
        return 'Google sign-in is now connected.';
      });

  Future<void> _addPassword(AppUser user) async {
    final password = await _passwordDialog(
      title: 'Add password',
      label: 'New password',
    );
    if (password == null) return;
    await _run(() async {
      final updated = await ref
          .read(authRepositoryProvider)
          .linkPasswordToCurrentUser(email: user.email!, password: password);
      await ref.read(companyRepositoryProvider).syncUserProfile(updated);
      return 'Email password is now connected.';
    });
  }

  Future<void> _changePassword() async {
    final current = await _passwordDialog(
      title: 'Confirm current password',
      label: 'Current password',
    );
    if (current == null) return;
    final next = await _passwordDialog(
      title: 'Choose new password',
      label: 'New password',
    );
    if (next == null) return;
    await _run(() async {
      await ref.read(authRepositoryProvider).changePassword(
            currentPassword: current,
            newPassword: next,
          );
      return 'Password changed successfully.';
    });
  }

  Future<void> _unlink(String providerId) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Disconnect ${_providerName(providerId)}?'),
            content: const Text(
              'You will no longer be able to use this method to sign in.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Disconnect'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await _run(() async {
      await ref.read(authRepositoryProvider).unlinkProvider(providerId);
      final updated =
          await ref.read(authRepositoryProvider).reloadCurrentUser();
      if (updated != null) {
        await ref.read(companyRepositoryProvider).syncUserProfile(updated);
      }
      return '${_providerName(providerId)} disconnected.';
    });
  }

  Future<String?> _passwordDialog({
    required String title,
    required String label,
  }) async {
    final controller = TextEditingController();
    String? validation;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: label,
              errorText: validation,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.length < 6) {
                  setDialogState(() {
                    validation = 'Use at least 6 characters.';
                  });
                  return;
                }
                Navigator.pop(context, controller.text);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sign out?'),
            content:
                const Text('Local company data will remain on this device.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) await ref.read(authRepositoryProvider).signOut();
  }

  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final message = await action();
      if (mounted) setState(() => _message = message);
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _message = failure.message);
    } catch (error) {
      if (mounted) setState(() => _message = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _providerName(String providerId) =>
      providerId == 'password' ? 'Email password' : 'Google';
}

String? _validNetworkPhotoUrl(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.host.isEmpty) {
    return null;
  }
  return uri.toString();
}
