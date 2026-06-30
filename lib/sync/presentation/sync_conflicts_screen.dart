import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/permissions/permission_key.dart';
import '../../core/providers/app_providers.dart';
import '../../features/auth/data/auth_providers.dart';
import '../../shared/presentation/app_feedback.dart';
import '../data/sync_providers.dart';
import '../domain/sync_conflict.dart';
import '../domain/sync_models.dart';

class SyncConflictsScreen extends ConsumerWidget {
  const SyncConflictsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final writeContext = ref.watch(localWriteContextProvider);
    final canResolve = ref
            .watch(permissionServiceProvider)
            .valueOrNull
            ?.can(PermissionKey.settingsManage) ??
        false;
    if (!canResolve) {
      return Scaffold(
        appBar: AppBar(title: const Text('Items needing attention')),
        body: const Center(
          child: Text('Only the owner or an admin can review conflicts.'),
        ),
      );
    }
    final conflictKey = (
      companyId: writeContext.companyId,
      userId: writeContext.userId,
      deviceId: writeContext.deviceId,
    );
    final conflicts = ref.watch(openSyncConflictsProvider(conflictKey));
    return Scaffold(
      appBar: AppBar(title: const Text('Items needing attention')),
      body: SafeArea(
        child: conflicts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
              child: Text(friendlyErrorMessage(error,
                  fallback: 'These items could not be loaded.'))),
          data: (items) => items.isEmpty
              ? const Center(child: Text('Everything is up to date.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _ConflictCard(
                    conflict: items[index],
                    canResolve: canResolve,
                    onResolve: (choice, manualJson) => _resolve(
                      context,
                      ref,
                      items[index],
                      choice,
                      manualJson,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _resolve(
    BuildContext context,
    WidgetRef ref,
    SyncConflict conflict,
    ConflictResolutionChoice choice,
    String? manualJson,
  ) async {
    final write = ref.read(localWriteContextProvider);
    try {
      await ref.read(conflictResolutionServiceProvider).resolve(
            context: SyncContext(
              companyId: write.companyId,
              userId: write.userId,
              deviceId: write.deviceId,
            ),
            conflictId: conflict.id,
            choice: choice,
            manualPayloadJson: manualJson,
          );
      ref.invalidate(openSyncConflictsProvider((
        companyId: write.companyId,
        userId: write.userId,
        deviceId: write.deviceId,
      )));
      ref.invalidate(syncStatusSummaryProvider(write.companyId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The selected copy is now saved.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyErrorMessage(error))));
      }
    }
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.conflict,
    required this.canResolve,
    required this.onResolve,
  });

  final SyncConflict conflict;
  final bool canResolve;
  final Future<void> Function(ConflictResolutionChoice, String?) onResolve;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: Text(
            '${_entityLabel(conflict.entityType)} was changed on two devices'),
        subtitle: const Text('Choose which copy should be kept.'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (kDebugMode)
            LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final local = _JsonPanel(
                title: 'Local version',
                json: conflict.localPayloadJson,
              );
              final remote = _JsonPanel(
                title: 'Remote version',
                json: conflict.remotePayloadJson,
              );
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: local),
                        const SizedBox(width: 12),
                        Expanded(child: remote),
                      ],
                    )
                  : Column(
                      children: [local, const SizedBox(height: 12), remote]);
            }),
          const SizedBox(height: 14),
          if (!canResolve)
            const Text('Only the owner or an admin can resolve conflicts.')
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      onResolve(ConflictResolutionChoice.local, null),
                  icon: const Icon(Icons.phone_android_outlined),
                  label: const Text('Keep this device’s copy'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () =>
                      onResolve(ConflictResolutionChoice.remote, null),
                  icon: const Icon(Icons.devices_other_outlined),
                  label: const Text('Use the other device’s copy'),
                ),
                if (kDebugMode)
                  FilledButton(
                    onPressed: () => _manual(context),
                    child: const Text('Developer merge'),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _manual(BuildContext context) async {
    final controller =
        TextEditingController(text: _pretty(conflict.localPayloadJson));
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Developer merge'),
        content: SizedBox(
          width: 720,
          child: TextField(
            controller: controller,
            minLines: 12,
            maxLines: 20,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              helperText:
                  'Debug tool: protected identity fields cannot be changed.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Apply merge'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) await onResolve(ConflictResolutionChoice.manual, value);
  }
}

class _JsonPanel extends StatelessWidget {
  const _JsonPanel({required this.title, required this.json});
  final String title;
  final String json;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SelectableText('$title\n${_pretty(json)}'),
      );
}

String _pretty(String source) {
  try {
    return const JsonEncoder.withIndent('  ').convert(jsonDecode(source));
  } catch (_) {
    return source;
  }
}

String _entityLabel(String value) {
  const labels = <String, String>{
    'tenders': 'Tender',
    'projects': 'Project',
    'material_purchases': 'Material purchase',
    'labor_work_entries': 'Labor entry',
    'machine_usage_entries': 'Machinery entry',
    'fuel_entries': 'Fuel entry',
    'project_bills': 'Bill',
    'project_expenses': 'Project expense',
  };
  return labels[value] ?? 'Company record';
}
