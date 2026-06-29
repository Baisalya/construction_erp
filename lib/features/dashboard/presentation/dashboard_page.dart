import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../domain/dashboard_kpis.dart';

final dashboardKpisProvider = FutureProvider.autoDispose<DashboardKpis>((ref) {
  final context = ref.watch(localWriteContextProvider);
  return ref.watch(dashboardRepositoryProvider).load(context.companyId);
});

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dashboardKpisProvider);
    return SafeArea(
        child: data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text('Unable to load dashboard: $error')),
      data: (kpis) => RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardKpisProvider.future),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Construction ERP Overview',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        const Text(
                            'Tender → Project → Work cost → Billing → GST → Profit/Loss. All totals come from the local ledger.'),
                      ]))),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1150
                ? 4
                : constraints.maxWidth >= 720
                    ? 3
                    : constraints.maxWidth >= 480
                        ? 2
                        : 1;
            final cards = <_Kpi>[
              _Kpi('Active tenders', '${kpis.activeTenders}',
                  Icons.description_outlined),
              _Kpi('Selected tenders', '${kpis.selectedTenders}',
                  Icons.task_alt_outlined),
              _Kpi('Running projects', '${kpis.runningProjects}',
                  Icons.construction_outlined),
              _Kpi('Pending suppliers', kpis.pendingSupplier.format(),
                  Icons.inventory_2_outlined),
              _Kpi('Pending labor', kpis.pendingLabor.format(),
                  Icons.engineering_outlined),
              _Kpi('Pending machinery', kpis.pendingMachinery.format(),
                  Icons.precision_manufacturing_outlined),
              _Kpi('Total project value', kpis.totalProjectValue.format(),
                  Icons.account_balance_wallet_outlined),
              _Kpi('Total actual expense', kpis.totalExpense.format(),
                  Icons.payments_outlined),
              _Kpi(
                  kpis.profitByAgreement.isNegative
                      ? 'Loss by agreement'
                      : 'Profit by agreement',
                  kpis.profitByAgreement.format(),
                  kpis.profitByAgreement.isNegative
                      ? Icons.trending_down
                      : Icons.trending_up,
                  highlight: true),
              _Kpi('GST input', kpis.gstInput.format(), Icons.south_west),
              _Kpi('GST output', kpis.gstOutput.format(), Icons.north_east),
              _Kpi('Net GST', (kpis.gstOutput - kpis.gstInput).format(),
                  Icons.receipt_long_outlined),
            ];
            return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cards.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 138),
                itemBuilder: (context, index) => _KpiCard(item: cards[index]));
          }),
        ]),
      ),
    ));
  }
}

class _Kpi {
  const _Kpi(this.label, this.value, this.icon, {this.highlight = false});
  final String label;
  final String value;
  final IconData icon;
  final bool highlight;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.item});
  final _Kpi item;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
        color: item.highlight ? theme.colorScheme.primaryContainer : null,
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(item.icon),
              const Spacer(),
              Text(item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900)),
              Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis)
            ])));
  }
}
