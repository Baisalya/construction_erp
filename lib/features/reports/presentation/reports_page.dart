import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/presentation/app_feedback.dart';
import '../../../core/permissions/permission_key.dart';
import '../../auth/data/auth_providers.dart';
import '../../billing/domain/billing_records.dart';

final profitLossSummaryProvider =
    FutureProvider.autoDispose<BillingDashboardSummary>((ref) async {
  final context = ref.watch(localWriteContextProvider);
  return ref
      .watch(billingRepositoryProvider)
      .loadBillingSummary(context.companyId);
});

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(profitLossSummaryProvider);
    final canExport = ref
            .watch(permissionServiceProvider)
            .valueOrNull
            ?.can(PermissionKey.exportReports) ??
        false;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Header(
            canExport: canExport,
            onPdf: summary.valueOrNull == null
                ? null
                : () => _export(context, ref, summary.valueOrNull!, pdf: true),
            onExcel: summary.valueOrNull == null
                ? null
                : () => _export(context, ref, summary.valueOrNull!, pdf: false),
          ),
          const SizedBox(height: 14),
          summary.when(
            data: (data) => _ReportBody(summary: data),
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => Card(
                child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(friendlyErrorMessage(error,
                        fallback: 'Reports could not be loaded.')))),
          ),
        ],
      ),
    );
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    BillingDashboardSummary summary, {
    required bool pdf,
  }) async {
    try {
      final companyId = ref.read(localWriteContextProvider).companyId;
      final service = ref.read(reportExportServiceProvider);
      final document = pdf
          ? await service.createPdf(companyId: companyId, summary: summary)
          : await service.createExcel(companyId: companyId, summary: summary);
      final path = await ref.read(localFileServiceProvider).save(
            fileName: document.fileName,
            extension: document.extension,
            bytes: document.bytes,
          );
      if (path != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${document.extension.toUpperCase()} saved.')),
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

class _Header extends StatelessWidget {
  const _Header({
    required this.canExport,
    required this.onPdf,
    required this.onExcel,
  });

  final bool canExport;
  final VoidCallback? onPdf;
  final VoidCallback? onExcel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profit/Loss Reports',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text(
                'A clear summary of agreement value, project costs, billing, GST, pending amounts and profit or loss.'),
            if (canExport) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: onPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Export PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onExcel,
                    icon: const Icon(Icons.table_view_outlined),
                    label: const Text('Export Excel'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.summary});

  final BillingDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 820;
        final cards = [
          _ReportCard(title: 'Revenue', rows: [
            _RowItem('Agreement value', summary.agreementValue.format()),
            _RowItem('Total billed', summary.totalBilled.format()),
            _RowItem('Total received', summary.totalReceived.format()),
            _RowItem('Pending receivable', summary.pendingReceivable.format()),
          ]),
          _ReportCard(title: 'Actual cost', rows: [
            _RowItem('Estimated project cost',
                summary.latestEstimateTotal.format()),
            _RowItem('Material', summary.materialCost.format()),
            _RowItem('Labor', summary.laborCost.format()),
            _RowItem('Machinery', summary.machineryCost.format()),
            _RowItem('Fuel', summary.fuelCost.format()),
            _RowItem('Repair', summary.repairCost.format()),
            _RowItem('Other expenses', summary.otherExpenseCost.format()),
            _RowItem('Total actual cost', summary.totalActualCost.format()),
          ]),
          _ReportCard(title: 'GST', rows: [
            _RowItem('GST input', summary.gstInput.format()),
            _RowItem('GST output', summary.gstOutput.format()),
            _RowItem('Net GST position',
                (summary.gstOutput - summary.gstInput).format()),
          ]),
          _ReportCard(title: 'Profit / Loss', highlight: true, rows: [
            _RowItem('Estimated profit', summary.estimatedProfit.format()),
            _RowItem('Actual profit by agreement',
                summary.actualProfitByAgreement.format()),
            _RowItem('Actual profit by received',
                summary.actualProfitByReceived.format()),
            _RowItem('Total payable', summary.totalPayable.format()),
          ]),
        ];
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final card in cards)
              SizedBox(
                width: twoColumns
                    ? (constraints.maxWidth - 14) / 2
                    : constraints.maxWidth,
                child: card,
              ),
          ],
        );
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard(
      {required this.title, required this.rows, this.highlight = false});

  final String title;
  final List<_RowItem> rows;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: highlight ? theme.colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(row.label)),
                    Text(row.value,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RowItem {
  const _RowItem(this.label, this.value);
  final String label;
  final String value;
}
