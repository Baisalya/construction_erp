import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../shared/presentation/app_feedback.dart';
import '../data/sync_providers.dart';
import '../domain/sync_models.dart';

class SyncStatusScreen extends ConsumerStatefulWidget {
  const SyncStatusScreen({super.key});
  @override
  ConsumerState<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends ConsumerState<SyncStatusScreen> {
  bool _isSyncing = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final writeContext = ref.watch(localWriteContextProvider);
    final syncContext = SyncContext(
      companyId: writeContext.companyId,
      userId: writeContext.userId,
      deviceId: writeContext.deviceId,
    );
    final summary = ref.watch(syncStatusSummaryProvider(syncContext.companyId));
    return Scaffold(
      appBar: AppBar(title: const Text('Data sync')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(syncStatusSummaryProvider(syncContext.companyId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Keep this device up to date with your company’s other signed-in devices. Your work stays saved on this device first.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              summary.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _StatusError(
                      message: friendlyErrorMessage(e,
                          fallback: 'Sync status could not be loaded.')),
                  data: (counts) => _StatusGrid(counts: counts)),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(_message!, style: Theme.of(context).textTheme.bodyMedium)
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                  onPressed: _isSyncing ? null : () => _runSync(syncContext),
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync),
                  label: Text(_isSyncing ? 'Syncing...' : 'Sync now')),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => context.push('/sync/conflicts'),
                icon: const Icon(Icons.rule_folder_outlined),
                label: const Text('Review items needing attention'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runSync(SyncContext syncContext) async {
    setState(() {
      _isSyncing = true;
      _message = null;
    });
    try {
      final result =
          await ref.read(syncOrchestratorProvider).syncNow(syncContext);
      setState(() => _message = result.failed > 0
          ? 'Sync finished with ${result.failed} item${result.failed == 1 ? '' : 's'} that could not be updated. Your local work is safe.'
          : result.conflicts > 0
              ? 'Sync finished. ${result.conflicts} item${result.conflicts == 1 ? '' : 's'} need your review.'
              : 'Sync complete. ${result.uploaded} change${result.uploaded == 1 ? '' : 's'} sent and ${result.applied} received.');
      ref.invalidate(syncStatusSummaryProvider(syncContext.companyId));
    } catch (error) {
      setState(() => _message = _humanError(error));
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  String _humanError(Object error) {
    final text = error.toString();
    if (text.contains('revoked')) {
      return 'Your staff access is revoked, so sync is blocked.';
    }
    if (text.contains('Permission') || text.contains('permission')) {
      return 'Your role does not allow this sync action.';
    }
    if (text.contains('network') || text.contains('unavailable')) {
      return 'Internet or Firebase is unavailable. Your local work is safe.';
    }
    return friendlyErrorMessage(error,
        fallback: 'Sync could not finish. Your local work is safe.');
  }
}

class _StatusGrid extends StatelessWidget {
  const _StatusGrid({required this.counts});
  final SyncCounts counts;

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatusItem('Waiting to send', counts.pendingUploads.toString(),
          Icons.cloud_upload_outlined),
      _StatusItem(
          'Sent', counts.uploaded.toString(), Icons.cloud_done_outlined),
      _StatusItem('Received', counts.downloaded.toString(),
          Icons.download_done_outlined),
      _StatusItem('Updated locally', counts.applied.toString(),
          Icons.check_circle_outline),
      _StatusItem(
          'Could not update', counts.failed.toString(), Icons.error_outline),
      _StatusItem('Needs review', counts.conflicts.toString(),
          Icons.warning_amber_outlined),
      _StatusItem(
          'Last sync', _formatTime(counts.lastSyncAt), Icons.access_time),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final columns = width >= 900
          ? 4
          : width >= 600
              ? 3
              : 2;
      final cardWidth = (width - (columns - 1) * 12) / columns;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        for (final item in items)
          SizedBox(width: cardWidth, child: _StatusCard(item: item)),
        for (final error in counts.errors)
          SizedBox(width: width, child: _StatusError(message: error)),
      ]);
    });
  }

  static String _formatTime(int? millis) => millis == null || millis == 0
      ? 'Not synced yet'
      : _dateTime(DateTime.fromMillisecondsSinceEpoch(millis).toLocal());

  static String _dateTime(DateTime value) {
    final date =
        '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
    final hour = value.hour == 0
        ? 12
        : value.hour > 12
            ? value.hour - 12
            : value.hour;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$date, $hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _StatusItem {
  const _StatusItem(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.item});
  final _StatusItem item;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(item.icon),
            const SizedBox(height: 10),
            Text(item.value, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(item.label, overflow: TextOverflow.ellipsis)
          ])));
}

class _StatusError extends StatelessWidget {
  const _StatusError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: 10),
            Expanded(child: Text(message))
          ])));
}
