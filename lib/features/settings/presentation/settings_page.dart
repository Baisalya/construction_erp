import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/presentation/app_feedback.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Backup and Restore',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text(
                    'Save a copy of your company records to a file on this device. Sign-in and staff access settings are not included.',
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _working ? null : _createBackup,
                        icon: const Icon(Icons.save_alt),
                        label: const Text('Create backup'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _working ? null : _restoreBackup,
                        icon: const Icon(Icons.restore),
                        label: const Text('Restore backup'),
                      ),
                    ],
                  ),
                  if (_working) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Restore adds missing records and updates matching records in this company. Your current sign-in and staff access stay unchanged.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createBackup() async {
    await _run(() async {
      final writeContext = ref.read(localWriteContextProvider);
      final bytes =
          await ref.read(localBackupServiceProvider).createBackup(writeContext);
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final path = await ref.read(localFileServiceProvider).save(
            fileName: 'construction_erp_backup_$date.json',
            extension: 'json',
            bytes: bytes,
          );
      if (path != null) _show('Backup saved successfully.');
    });
  }

  Future<void> _restoreBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore local backup?'),
        content: const Text(
          'Matching records will be updated from the backup. Current authentication and staff access will not be changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      final bytes =
          await ref.read(localFileServiceProvider).pick(extension: 'json');
      if (bytes == null) return;
      final result = await ref.read(localBackupServiceProvider).restoreBackup(
            bytes,
            ref.read(localWriteContextProvider),
          );
      _show(
        'Restore complete: ${result.inserted} added, ${result.updated} updated.',
      );
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _working = true);
    try {
      await action();
    } catch (error) {
      _show(friendlyErrorMessage(error,
          fallback: 'The backup action could not be completed.'));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
