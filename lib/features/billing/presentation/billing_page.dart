import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/value_objects/money.dart';
import '../../../core/value_objects/quantity.dart';
import '../../../shared/presentation/app_feedback.dart';
import '../../project/domain/project_record.dart';
import '../domain/billing_records.dart';

final billingProjectsProvider =
    FutureProvider.autoDispose<List<ProjectRecord>>((ref) async {
  final context = ref.watch(localWriteContextProvider);
  return ref.watch(projectRepositoryProvider).listProjects(context.companyId);
});

final billingSummaryProvider =
    FutureProvider.autoDispose<BillingDashboardSummary>((ref) async {
  final context = ref.watch(localWriteContextProvider);
  return ref
      .watch(billingRepositoryProvider)
      .loadBillingSummary(context.companyId);
});

final billingEstimatesProvider =
    FutureProvider.autoDispose<List<ProjectEstimateRecord>>((ref) async {
  final context = ref.watch(localWriteContextProvider);
  return ref.watch(billingRepositoryProvider).listEstimates(context.companyId);
});

final billingBillsProvider =
    FutureProvider.autoDispose<List<ProjectBillRecord>>((ref) async {
  final context = ref.watch(localWriteContextProvider);
  return ref.watch(billingRepositoryProvider).listBills(context.companyId);
});

final billingGstEntriesProvider =
    FutureProvider.autoDispose<List<GstEntryRecord>>((ref) async {
  final context = ref.watch(localWriteContextProvider);
  return ref.watch(billingRepositoryProvider).listGstEntries(context.companyId);
});

class BillingPage extends ConsumerWidget {
  const BillingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(billingSummaryProvider);
    final projects = ref.watch(billingProjectsProvider);
    final bills = ref.watch(billingBillsProvider);
    final estimates = ref.watch(billingEstimatesProvider);
    final gstEntries = ref.watch(billingGstEntriesProvider);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _Header(),
          const SizedBox(height: 14),
          summary.when(
            data: (data) => _SummaryGrid(summary: data),
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) =>
                _ErrorCard(message: friendlyErrorMessage(error)),
          ),
          const SizedBox(height: 14),
          projects.when(
            data: (projectData) => bills.when(
              data: (billData) =>
                  _Forms(projects: projectData, bills: billData),
              loading: () => _Forms(
                  projects: projectData, bills: const <ProjectBillRecord>[]),
              error: (error, stackTrace) =>
                  _ErrorCard(message: friendlyErrorMessage(error)),
            ),
            loading: () => const _InfoCard(text: 'Loading projects...'),
            error: (error, stackTrace) =>
                _ErrorCard(message: friendlyErrorMessage(error)),
          ),
          const SizedBox(height: 14),
          estimates.when(
            data: (data) => _EstimateList(estimates: data),
            loading: () => const _InfoCard(text: 'Loading estimates...'),
            error: (error, stackTrace) =>
                _ErrorCard(message: friendlyErrorMessage(error)),
          ),
          const SizedBox(height: 14),
          bills.when(
            data: (data) => _BillList(bills: data),
            loading: () => const _InfoCard(text: 'Loading bills...'),
            error: (error, stackTrace) =>
                _ErrorCard(message: friendlyErrorMessage(error)),
          ),
          const SizedBox(height: 14),
          gstEntries.when(
            data: (data) => _GstList(entries: data),
            loading: () => const _InfoCard(text: 'Loading GST entries...'),
            error: (error, stackTrace) =>
                _ErrorCard(message: friendlyErrorMessage(error)),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Wrap(
          spacing: 18,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Billing, GST and Profit/Loss',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text(
                      'Create estimates, running/final bills, GST entries and receipts. Profit/loss is calculated from local ledger records.'),
                ],
              ),
            ),
            const Chip(label: Text('Billing and GST')),
          ],
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final BillingDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _Stat('Agreement value', summary.agreementValue),
      _Stat('Latest estimate', summary.latestEstimateTotal),
      _Stat('Estimated profit', summary.estimatedProfit, highlight: true),
      _Stat('Material cost', summary.materialCost),
      _Stat('Labor cost', summary.laborCost),
      _Stat('Machinery cost', summary.machineryCost),
      _Stat('Fuel cost', summary.fuelCost),
      _Stat('Repair cost', summary.repairCost),
      _Stat('Other expenses', summary.otherExpenseCost),
      _Stat('Actual cost', summary.totalActualCost),
      _Stat('GST input', summary.gstInput),
      _Stat('GST output', summary.gstOutput),
      _Stat('Total billed', summary.totalBilled),
      _Stat('Total received', summary.totalReceived),
      _Stat('Pending receivable', summary.pendingReceivable),
      _Stat('Total payable', summary.totalPayable),
      _Stat('Profit by agreement', summary.actualProfitByAgreement,
          highlight: true),
      _Stat('Profit by received', summary.actualProfitByReceived,
          highlight: true),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final count = width >= 1200
          ? 6
          : width >= 900
              ? 4
              : width >= 560
                  ? 2
                  : 1;
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: count,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: count == 1 ? 4.2 : 1.65,
        children: cards.map((item) => _StatCard(stat: item)).toList(),
      );
    });
  }
}

class _Forms extends StatelessWidget {
  const _Forms({required this.projects, required this.bills});

  final List<ProjectRecord> projects;
  final List<ProjectBillRecord> bills;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: projects.isEmpty
            ? const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Create a project first'),
                subtitle:
                    Text('Create a project before adding estimates or bills.'),
              )
            : Column(
                children: [
                  _EstimateTile(projects: projects),
                  const Divider(height: 1),
                  _BillTile(projects: projects),
                  const Divider(height: 1),
                  _ReceiptTile(projects: projects, bills: bills),
                  const Divider(height: 1),
                  _GstTile(projects: projects),
                ],
              ),
      ),
    );
  }
}

class _EstimateTile extends ConsumerStatefulWidget {
  const _EstimateTile({required this.projects});
  final List<ProjectRecord> projects;
  @override
  ConsumerState<_EstimateTile> createState() => _EstimateTileState();
}

class _EstimateTileState extends ConsumerState<_EstimateTile> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _title = TextEditingController(text: 'Project Estimate');
  final _item = TextEditingController(text: 'Work item');
  final _qty = TextEditingController(text: '1');
  final _rate = TextEditingController();
  final _labor = TextEditingController();
  final _machinery = TextEditingController();
  final _other = TextEditingController();
  String? _projectId;
  bool _saving = false;

  @override
  void dispose() {
    _number.dispose();
    _title.dispose();
    _item.dispose();
    _qty.dispose();
    _rate.dispose();
    _labor.dispose();
    _machinery.dispose();
    _other.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedProject = _projectId ?? widget.projects.first.id;
    return ExpansionTile(
      leading: const Icon(Icons.calculate_outlined),
      title: const Text('Create estimate'),
      subtitle: const Text('Estimate item total and expected profit'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Form(
            key: _formKey,
            child: _FormGrid(children: [
              _ProjectDropdown(
                  projects: widget.projects,
                  value: selectedProject,
                  onChanged: (value) => setState(() => _projectId = value)),
              TextFormField(
                  controller: _number,
                  decoration:
                      const InputDecoration(labelText: 'Estimate number')),
              TextFormField(
                  controller: _title,
                  decoration:
                      const InputDecoration(labelText: 'Estimate title *'),
                  validator: _required),
              TextFormField(
                  controller: _item,
                  decoration: const InputDecoration(labelText: 'Main item *'),
                  validator: _required),
              TextFormField(
                  controller: _qty,
                  decoration: const InputDecoration(labelText: 'Quantity *'),
                  keyboardType: TextInputType.number,
                  validator: _positiveQuantity),
              TextFormField(
                  controller: _rate,
                  decoration: const InputDecoration(labelText: 'Rate ₹ *'),
                  keyboardType: TextInputType.number,
                  validator: _moneyRequired),
              TextFormField(
                  controller: _labor,
                  decoration:
                      const InputDecoration(labelText: 'Estimated labor ₹'),
                  keyboardType: TextInputType.number),
              TextFormField(
                  controller: _machinery,
                  decoration:
                      const InputDecoration(labelText: 'Estimated machinery ₹'),
                  keyboardType: TextInputType.number),
              TextFormField(
                  controller: _other,
                  decoration:
                      const InputDecoration(labelText: 'Estimated other ₹'),
                  keyboardType: TextInputType.number),
              FilledButton.icon(
                  onPressed: _saving ? null : () => _save(selectedProject),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save estimate')),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _save(String selectedProject) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(billingRepositoryProvider).createEstimate(
            ProjectEstimateDraft(
              projectId: selectedProject,
              estimateNumber: _number.text,
              estimateDate: DateTime.now().millisecondsSinceEpoch,
              title: _title.text,
              items: [
                EstimateItemDraft(
                    itemName: _item.text,
                    quantity: DecimalQuantity.parse(_qty.text),
                    rate: _parseMoney(_rate.text))
              ],
              estimatedLaborCost: _parseMoney(_labor.text),
              estimatedMachineryCost: _parseMoney(_machinery.text),
              estimatedOtherCost: _parseMoney(_other.text),
            ),
            ref.read(localWriteContextProvider),
          );
      _number.clear();
      _refresh(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Estimate saved locally.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _BillTile extends ConsumerStatefulWidget {
  const _BillTile({required this.projects});
  final List<ProjectRecord> projects;
  @override
  ConsumerState<_BillTile> createState() => _BillTileState();
}

class _BillTileState extends ConsumerState<_BillTile> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _gross = TextEditingController();
  final _gst = TextEditingController(text: '18');
  final _tds = TextEditingController();
  final _retention = TextEditingController();
  final _received = TextEditingController();
  String? _projectId;
  BillType _type = BillType.runningBill;
  bool _saving = false;

  @override
  void dispose() {
    _number.dispose();
    _gross.dispose();
    _gst.dispose();
    _tds.dispose();
    _retention.dispose();
    _received.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedProject = _projectId ?? widget.projects.first.id;
    return ExpansionTile(
      leading: const Icon(Icons.receipt_long_outlined),
      title: const Text('Create bill'),
      subtitle: const Text('Running/final bill with GST, TDS and retention'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Form(
            key: _formKey,
            child: _FormGrid(children: [
              _ProjectDropdown(
                  projects: widget.projects,
                  value: selectedProject,
                  onChanged: (value) => setState(() => _projectId = value)),
              DropdownButtonFormField<BillType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Bill type'),
                  items: BillType.values
                      .map((item) => DropdownMenuItem(
                          value: item, child: Text(item.label)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _type = value ?? BillType.runningBill)),
              TextFormField(
                  controller: _number,
                  decoration: const InputDecoration(labelText: 'Bill number *'),
                  validator: _required),
              TextFormField(
                  controller: _gross,
                  decoration:
                      const InputDecoration(labelText: 'Gross amount ₹ *'),
                  keyboardType: TextInputType.number,
                  validator: _moneyRequired),
              TextFormField(
                  controller: _gst,
                  decoration: const InputDecoration(labelText: 'GST rate %'),
                  keyboardType: TextInputType.number),
              TextFormField(
                  controller: _tds,
                  decoration: const InputDecoration(labelText: 'TDS ₹'),
                  keyboardType: TextInputType.number),
              TextFormField(
                  controller: _retention,
                  decoration: const InputDecoration(labelText: 'Retention ₹'),
                  keyboardType: TextInputType.number),
              TextFormField(
                  controller: _received,
                  decoration:
                      const InputDecoration(labelText: 'Received now ₹'),
                  keyboardType: TextInputType.number),
              FilledButton.icon(
                  onPressed: _saving ? null : () => _save(selectedProject),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save bill')),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _save(String selectedProject) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(billingRepositoryProvider).createBill(
            ProjectBillDraft(
              projectId: selectedProject,
              billNumber: _number.text,
              billDate: DateTime.now().millisecondsSinceEpoch,
              billType: _type,
              grossBillAmount: _parseMoney(_gross.text),
              gstRateBasisPoints: _percentToBasisPoints(_gst.text),
              tdsAmount: _parseMoney(_tds.text),
              retentionAmount: _parseMoney(_retention.text),
              initialReceivedAmount: _parseMoney(_received.text),
              status: BillStatus.approved,
            ),
            ref.read(localWriteContextProvider),
          );
      _number.clear();
      _gross.clear();
      _tds.clear();
      _retention.clear();
      _received.clear();
      _refresh(ref);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Bill saved locally.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ReceiptTile extends ConsumerStatefulWidget {
  const _ReceiptTile({required this.projects, required this.bills});
  final List<ProjectRecord> projects;
  final List<ProjectBillRecord> bills;
  @override
  ConsumerState<_ReceiptTile> createState() => _ReceiptTileState();
}

class _ReceiptTileState extends ConsumerState<_ReceiptTile> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  String? _projectId;
  String? _billId;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedProject = _projectId ?? widget.projects.first.id;
    final pendingBills = widget.bills
        .where((bill) =>
            bill.projectId == selectedProject && bill.pendingAmount.paise > 0)
        .toList(growable: false);
    final selectedBill =
        _billId != null && pendingBills.any((bill) => bill.id == _billId)
            ? _billId
            : (pendingBills.isEmpty ? null : pendingBills.first.id);
    return ExpansionTile(
      leading: const Icon(Icons.payments_outlined),
      title: const Text('Add receipt'),
      subtitle: const Text('Reduce pending receivable when payment comes'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Form(
            key: _formKey,
            child: _FormGrid(children: [
              _ProjectDropdown(
                  projects: widget.projects,
                  value: selectedProject,
                  onChanged: (value) => setState(() {
                        _projectId = value;
                        _billId = null;
                      })),
              DropdownButtonFormField<String>(
                  initialValue: selectedBill,
                  decoration: const InputDecoration(labelText: 'Pending bill'),
                  items: pendingBills
                      .map((bill) => DropdownMenuItem(
                          value: bill.id,
                          child: Text(
                              '${bill.billNumber} • ${bill.pendingAmount.format()} pending')))
                      .toList(),
                  onChanged: (value) => setState(() => _billId = value),
                  validator: (value) =>
                      value == null ? 'Create a pending bill first' : null),
              TextFormField(
                  controller: _amount,
                  decoration:
                      const InputDecoration(labelText: 'Received amount ₹ *'),
                  keyboardType: TextInputType.number,
                  validator: _moneyRequired),
              TextFormField(
                  controller: _reference,
                  decoration: const InputDecoration(
                      labelText: 'Reference / UTR / cheque')),
              FilledButton.icon(
                  onPressed: _saving
                      ? null
                      : () => _save(selectedProject, selectedBill),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save receipt')),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _save(String selectedProject, String? selectedBill) async {
    if (!(_formKey.currentState?.validate() ?? false) || selectedBill == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(billingRepositoryProvider).addBillReceipt(
            ProjectBillReceiptDraft(
                projectId: selectedProject,
                billId: selectedBill,
                receiptDate: DateTime.now().millisecondsSinceEpoch,
                amount: _parseMoney(_amount.text),
                referenceNumber: _reference.text),
            ref.read(localWriteContextProvider),
          );
      _amount.clear();
      _reference.clear();
      _refresh(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Receipt saved locally.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _GstTile extends ConsumerStatefulWidget {
  const _GstTile({required this.projects});
  final List<ProjectRecord> projects;
  @override
  ConsumerState<_GstTile> createState() => _GstTileState();
}

class _GstTileState extends ConsumerState<_GstTile> {
  final _formKey = GlobalKey<FormState>();
  final _taxable = TextEditingController();
  final _gstRate = TextEditingController(text: '18');
  final _notes = TextEditingController();
  String? _projectId;
  GstType _type = GstType.input;
  bool _saving = false;

  @override
  void dispose() {
    _taxable.dispose();
    _gstRate.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedProject = _projectId ?? widget.projects.first.id;
    return ExpansionTile(
      leading: const Icon(Icons.percent_outlined),
      title: const Text('Add manual GST entry'),
      subtitle: const Text('Input/output GST adjustment entry'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Form(
            key: _formKey,
            child: _FormGrid(children: [
              _ProjectDropdown(
                  projects: widget.projects,
                  value: selectedProject,
                  onChanged: (value) => setState(() => _projectId = value)),
              DropdownButtonFormField<GstType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'GST type'),
                  items: GstType.values
                      .map((item) => DropdownMenuItem(
                          value: item, child: Text(item.label)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _type = value ?? GstType.input)),
              TextFormField(
                  controller: _taxable,
                  decoration:
                      const InputDecoration(labelText: 'Taxable amount ₹ *'),
                  keyboardType: TextInputType.number,
                  validator: _moneyRequired),
              TextFormField(
                  controller: _gstRate,
                  decoration: const InputDecoration(labelText: 'GST rate %'),
                  keyboardType: TextInputType.number),
              TextFormField(
                  controller: _notes,
                  decoration: const InputDecoration(labelText: 'Notes')),
              FilledButton.icon(
                  onPressed: _saving ? null : () => _save(selectedProject),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save GST')),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _save(String selectedProject) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final taxable = _parseMoney(_taxable.text);
      final rate = _percentToBasisPoints(_gstRate.text);
      await ref.read(billingRepositoryProvider).createGstEntry(
            GstEntryDraft(
                projectId: selectedProject,
                sourceId: 'manual-${DateTime.now().millisecondsSinceEpoch}',
                gstType: _type,
                gstRateBasisPoints: rate,
                taxableAmount: taxable,
                gstAmount:
                    const BillingCalculator().calculateGst(taxable, rate),
                entryDate: DateTime.now().millisecondsSinceEpoch,
                notes: _notes.text),
            ref.read(localWriteContextProvider),
          );
      _taxable.clear();
      _notes.clear();
      _refresh(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('GST entry saved locally.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _EstimateList extends StatelessWidget {
  const _EstimateList({required this.estimates});
  final List<ProjectEstimateRecord> estimates;
  @override
  Widget build(BuildContext context) => _SectionCard(
      title: 'Estimates',
      empty: 'No estimates yet.',
      isEmpty: estimates.isEmpty,
      child: Column(
          children: estimates
              .map((e) => ListTile(
                  leading: const Icon(Icons.calculate_outlined),
                  title: Text(e.estimateNumber ?? e.title),
                  subtitle: Text(
                      'Total ${e.totalEstimatedCost.format()} • Profit ${e.estimatedProfit.format()}')))
              .toList()));
}

class _BillList extends StatelessWidget {
  const _BillList({required this.bills});
  final List<ProjectBillRecord> bills;
  @override
  Widget build(BuildContext context) => _SectionCard(
      title: 'Bills and receivables',
      empty: 'No bills yet.',
      isEmpty: bills.isEmpty,
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth >= 800) {
          return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Bill')),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Net')),
                    DataColumn(label: Text('Received')),
                    DataColumn(label: Text('Pending')),
                    DataColumn(label: Text('Status'))
                  ],
                  rows: bills
                      .map((bill) => DataRow(cells: [
                            DataCell(Text(bill.billNumber)),
                            DataCell(Text(bill.billType.label)),
                            DataCell(Text(bill.netReceivableAmount.format())),
                            DataCell(Text(bill.receivedAmount.format())),
                            DataCell(Text(bill.pendingAmount.format())),
                            DataCell(Text(bill.status.label))
                          ]))
                      .toList()));
        }
        return Column(
            children: bills
                .map((bill) => ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text('${bill.billNumber} • ${bill.status.label}'),
                    subtitle: Text(
                        'Net ${bill.netReceivableAmount.format()} • Pending ${bill.pendingAmount.format()}')))
                .toList());
      }));
}

class _GstList extends StatelessWidget {
  const _GstList({required this.entries});
  final List<GstEntryRecord> entries;
  @override
  Widget build(BuildContext context) => _SectionCard(
      title: 'GST entries',
      empty: 'No GST entries yet.',
      isEmpty: entries.isEmpty,
      child: Column(
          children: entries
              .map((entry) => ListTile(
                  leading: Icon(entry.gstType == GstType.input
                      ? Icons.south_west_outlined
                      : Icons.north_east_outlined),
                  title: Text(
                      '${entry.gstType.label} • ${entry.gstAmount.format()}'),
                  subtitle: Text(
                      'Taxable ${entry.taxableAmount.format()} • Source ${entry.sourceType.value}')))
              .toList()));
}

class _SectionCard extends StatelessWidget {
  const _SectionCard(
      {required this.title,
      required this.empty,
      required this.isEmpty,
      required this.child});
  final String title;
  final String empty;
  final bool isEmpty;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            if (isEmpty) Text(empty) else child
          ])));
}

class _ProjectDropdown extends StatelessWidget {
  const _ProjectDropdown(
      {required this.projects, required this.value, required this.onChanged});
  final List<ProjectRecord> projects;
  final String value;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Project'),
      items: projects
          .map((project) => DropdownMenuItem(
              value: project.id, child: Text(project.projectName)))
          .toList(),
      onChanged: onChanged);
}

class _FormGrid extends StatelessWidget {
  const _FormGrid({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1000
            ? 3
            : width >= 640
                ? 2
                : 1;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final child in children)
            SizedBox(
                width: columns == 1
                    ? width
                    : (width - (12 * (columns - 1))) / columns,
                child: child)
        ]);
      });
}

class _Stat {
  const _Stat(this.label, this.value, {this.highlight = false});
  final String label;
  final Money value;
  final bool highlight;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});
  final _Stat stat;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
        color: stat.highlight ? theme.colorScheme.primaryContainer : null,
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(stat.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              const Spacer(),
              Text(stat.value.format(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900))
            ])));
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(padding: const EdgeInsets.all(18), child: Text(text)));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(padding: const EdgeInsets.all(18), child: Text(message)));
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;

String? _positiveQuantity(String? value) {
  if (value == null || value.trim().isEmpty) return 'Required';
  try {
    final parsed = DecimalQuantity.parse(value);
    return parsed.isZero || parsed.isNegative
        ? 'Must be greater than zero'
        : null;
  } catch (_) {
    return 'Enter a valid number';
  }
}

String? _moneyRequired(String? value) {
  if (value == null || value.trim().isEmpty) return 'Required';
  try {
    final money = Money.parseRupees(value);
    return money.paise < 0 ? 'Cannot be negative' : null;
  } catch (_) {
    return 'Enter a valid amount';
  }
}

Money _parseMoney(String value) =>
    value.trim().isEmpty ? Money.zero : Money.parseRupees(value);

int _percentToBasisPoints(String value) {
  final cleaned = value.trim();
  if (cleaned.isEmpty) return 0;
  final parts = cleaned.split('.');
  if (parts.length > 2 || parts.first.isEmpty) {
    throw FormatException('Invalid percent', value);
  }
  final whole = int.parse(parts.first);
  final fraction = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
  if (fraction.length > 2) {
    throw FormatException('Percent supports up to 2 decimal places', value);
  }
  return (whole * 100) + int.parse(fraction);
}

void _refresh(WidgetRef ref) {
  ref.invalidate(billingSummaryProvider);
  ref.invalidate(billingEstimatesProvider);
  ref.invalidate(billingBillsProvider);
  ref.invalidate(billingGstEntriesProvider);
}
