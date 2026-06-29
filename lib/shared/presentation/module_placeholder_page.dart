import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_module.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/domain/module_summary.dart';
import '../../shared/responsive/responsive_breakpoints.dart';

class ModulePlaceholderPage extends ConsumerWidget {
  const ModulePlaceholderPage({required this.module, super.key});

  final AppModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(moduleSummaryRepositoryProvider);
    return FutureBuilder<ModuleSummary>(
      future: repository.loadModuleSummary(module),
      builder: (context, snapshot) {
        final summary = snapshot.data ?? ModuleSummary.empty(module);
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                  maxWidth: ResponsiveBreakpoints.wideContentMax),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _ModuleHeader(summary: summary),
                  const SizedBox(height: 16),
                  const _FoundationCard(),
                  const SizedBox(height: 16),
                  _NextPhaseCard(module: module),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ModuleHeader extends StatelessWidget {
  const _ModuleHeader({required this.summary});

  final ModuleSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Wrap(
          spacing: 18,
          runSpacing: 16,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 28,
                    child: Icon(summary.module.icon),
                  ),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(summary.module.title,
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(summary.description),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Chip(
              avatar: const Icon(Icons.storage_outlined, size: 18),
              label: Text(summary.label),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoundationCard extends StatelessWidget {
  const _FoundationCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phase 5 foundation',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const Text(
                'This screen is intentionally empty. The database table, repository boundary, sync audit fields, and navigation route are ready before business UI is added.'),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                Chip(label: Text('Local-first')),
                Chip(label: Text('Repository layer')),
                Chip(label: Text('No UI business logic')),
                Chip(label: Text('Firebase-ready')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NextPhaseCard extends StatelessWidget {
  const _NextPhaseCard({required this.module});

  final AppModule module;

  @override
  Widget build(BuildContext context) {
    final nextAction = switch (module) {
      AppModule.tender =>
        'Tender module is active in Phase 4 with bidder profiles, expenses, documents, and tender-to-project conversion.',
      AppModule.project =>
        'Project agreement calculator is active from Phase 3.',
      AppModule.material ||
      AppModule.labor ||
      AppModule.machinery ||
      AppModule.fuel ||
      AppModule.work =>
        'Work cost entries, fuel, repair and payments are active from Phase 4.',
      AppModule.billing ||
      AppModule.reports =>
        'Billing and Reports are active in Phase 5 with estimate, GST, receivable and profit/loss summaries.',
      AppModule.staff =>
        'Phase 6 will add Firebase auth, invitation, role, permission, and staff access workflows.',
      AppModule.settings =>
        'Later phases will add backup, restore, export, and release settings.',
      AppModule.dashboard =>
        'Dashboard, Tender, Project, Work and Billing are active through Phase 5.',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.timeline_outlined),
            const SizedBox(width: 12),
            Expanded(child: Text(nextAction)),
          ],
        ),
      ),
    );
  }
}
