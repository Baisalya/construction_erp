import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/value_objects/money.dart';
import '../domain/bidder_profile.dart';
import '../domain/tender_application.dart';
import '../domain/tender_document.dart';
import '../domain/tender_expense.dart';
import '../domain/tender_expense_type.dart';
import '../domain/tender_status.dart';
import '../domain/tender_summary.dart';
import '../domain/tender_to_project_conversion.dart';

final tenderStatsProvider = FutureProvider<TenderDashboardStats>((ref) async {
  final context = ref.watch(localWriteContextProvider);
  final repository = ref.watch(tenderRepositoryProvider);
  return repository.loadStats(context.companyId);
});

final bidderProfilesProvider = FutureProvider<List<BidderProfile>>((ref) async {
  final context = ref.watch(localWriteContextProvider);
  final repository = ref.watch(tenderRepositoryProvider);
  return repository.listBidderProfiles(context.companyId);
});

final tenderListProvider = FutureProvider<List<TenderListItem>>((ref) async {
  final context = ref.watch(localWriteContextProvider);
  final repository = ref.watch(tenderRepositoryProvider);
  return repository.listTenders(context.companyId);
});

class TenderPage extends ConsumerWidget {
  const TenderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(tenderStatsProvider);
    final profiles = ref.watch(bidderProfilesProvider);
    final tenders = ref.watch(tenderListProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _TenderHeader(),
          const SizedBox(height: 14),
          stats.when(
            data: (data) => _TenderStatsCards(stats: data),
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) =>
                _InlineError(message: error.toString()),
          ),
          const SizedBox(height: 14),
          profiles.when(
            data: (data) => _TenderForms(profiles: data),
            loading: () => const Card(
                child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('Loading bidder profiles...'))),
            error: (error, stackTrace) =>
                _InlineError(message: error.toString()),
          ),
          const SizedBox(height: 14),
          tenders.when(
            data: (data) => _TenderList(tenders: data),
            loading: () => const Card(
                child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('Loading tenders...'))),
            error: (error, stackTrace) =>
                _InlineError(message: error.toString()),
          ),
        ],
      ),
    );
  }
}

class _TenderHeader extends StatelessWidget {
  const _TenderHeader();

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
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tender Module',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text(
                      'Manage tender usernames, tender prices, application expenses, documents, result status, and convert selected tenders into projects.'),
                ],
              ),
            ),
            const Chip(label: Text('Phase 4')),
          ],
        ),
      ),
    );
  }
}

class _TenderStatsCards extends StatelessWidget {
  const _TenderStatsCards({required this.stats});

  final TenderDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _SmallStat(label: 'Total tenders', value: stats.totalTenders.toString()),
      _SmallStat(label: 'Active', value: stats.activeTenders.toString()),
      _SmallStat(label: 'Selected', value: stats.selectedTenders.toString()),
      _SmallStat(label: 'Rejected', value: stats.rejectedTenders.toString()),
      _SmallStat(label: 'Quoted value', value: stats.totalQuotedValue.format()),
      _SmallStat(
          label: 'Application cost',
          value: stats.totalApplicationCost.format()),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1000
            ? 6
            : width >= 720
                ? 3
                : width >= 460
                    ? 2
                    : 1;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: crossAxisCount == 1 ? 4.2 : 1.65,
          children: cards,
        );
      },
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _TenderForms extends StatelessWidget {
  const _TenderForms({required this.profiles});

  final List<BidderProfile> profiles;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            _AddBidderProfileTile(),
            const Divider(height: 1),
            _AddTenderTile(profiles: profiles),
          ],
        ),
      ),
    );
  }
}

class _AddBidderProfileTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AddBidderProfileTile> createState() =>
      _AddBidderProfileTileState();
}

class _AddBidderProfileTileState extends ConsumerState<_AddBidderProfileTile> {
  final _formKey = GlobalKey<FormState>();
  final _profileName = TextEditingController();
  final _portalName = TextEditingController();
  final _username = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _profileName.dispose();
    _portalName.dispose();
    _username.dispose();
    _mobile.dispose();
    _email.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.person_add_alt_1_outlined),
      title: const Text('Add bidder username/profile'),
      subtitle:
          const Text('Example: GEM portal login, state tender portal account'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Form(
            key: _formKey,
            child: _ResponsiveFormGrid(
              children: [
                TextFormField(
                  controller: _profileName,
                  decoration:
                      const InputDecoration(labelText: 'Profile name *'),
                  validator: _required,
                ),
                TextFormField(
                    controller: _portalName,
                    decoration:
                        const InputDecoration(labelText: 'Portal name')),
                TextFormField(
                    controller: _username,
                    decoration: const InputDecoration(labelText: 'Username')),
                TextFormField(
                    controller: _mobile,
                    decoration:
                        const InputDecoration(labelText: 'Registered mobile')),
                TextFormField(
                    controller: _email,
                    decoration:
                        const InputDecoration(labelText: 'Registered email')),
                TextFormField(
                    controller: _notes,
                    decoration: const InputDecoration(labelText: 'Notes')),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined),
                    label: const Text('Save bidder profile'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(tenderRepositoryProvider).createBidderProfile(
            BidderProfileDraft(
              profileName: _profileName.text,
              portalName: _portalName.text,
              username: _username.text,
              registeredMobile: _mobile.text,
              registeredEmail: _email.text,
              notes: _notes.text,
            ),
            ref.read(localWriteContextProvider),
          );
      _profileName.clear();
      _portalName.clear();
      _username.clear();
      _mobile.clear();
      _email.clear();
      _notes.clear();
      _refreshTenderProviders(ref);
      if (mounted) {
        _showMessage(context, 'Bidder profile saved.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(context, error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _AddTenderTile extends ConsumerStatefulWidget {
  const _AddTenderTile({required this.profiles});

  final List<BidderProfile> profiles;

  @override
  ConsumerState<_AddTenderTile> createState() => _AddTenderTileState();
}

class _AddTenderTileState extends ConsumerState<_AddTenderTile> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _number = TextEditingController();
  final _client = TextEditingController();
  final _department = TextEditingController();
  final _location = TextEditingController();
  final _estimated = TextEditingController();
  final _quoted = TextEditingController();
  final _emd = TextEditingController();
  final _tenderFee = TextEditingController();
  final _documentFee = TextEditingController();
  final _processingCost = TextEditingController();
  final _otherCost = TextEditingController();
  final _notes = TextEditingController();
  String? _bidderProfileId;
  TenderStatus _status = TenderStatus.draft;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _number.dispose();
    _client.dispose();
    _department.dispose();
    _location.dispose();
    _estimated.dispose();
    _quoted.dispose();
    _emd.dispose();
    _tenderFee.dispose();
    _documentFee.dispose();
    _processingCost.dispose();
    _otherCost.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.description_outlined),
      title: const Text('Add tender'),
      subtitle:
          const Text('Tender number, amount, application cost, and status'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Form(
            key: _formKey,
            child: _ResponsiveFormGrid(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _bidderProfileId,
                  decoration: const InputDecoration(
                      labelText: 'Bidder profile / username'),
                  items: [
                    for (final profile in widget.profiles)
                      DropdownMenuItem(
                          value: profile.id,
                          child: Text(profile.profileName,
                              overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (value) =>
                      setState(() => _bidderProfileId = value),
                ),
                TextFormField(
                    controller: _title,
                    decoration:
                        const InputDecoration(labelText: 'Tender title *'),
                    validator: _required),
                TextFormField(
                    controller: _number,
                    decoration:
                        const InputDecoration(labelText: 'Tender number')),
                TextFormField(
                    controller: _client,
                    decoration:
                        const InputDecoration(labelText: 'Client name')),
                TextFormField(
                    controller: _department,
                    decoration: const InputDecoration(labelText: 'Department')),
                TextFormField(
                    controller: _location,
                    decoration: const InputDecoration(labelText: 'Location')),
                TextFormField(
                    controller: _estimated,
                    decoration:
                        const InputDecoration(labelText: 'Estimated value ₹'),
                    keyboardType: TextInputType.number),
                TextFormField(
                    controller: _quoted,
                    decoration:
                        const InputDecoration(labelText: 'Quoted price ₹'),
                    keyboardType: TextInputType.number),
                TextFormField(
                    controller: _emd,
                    decoration: const InputDecoration(labelText: 'EMD ₹'),
                    keyboardType: TextInputType.number),
                TextFormField(
                    controller: _tenderFee,
                    decoration:
                        const InputDecoration(labelText: 'Tender fee ₹'),
                    keyboardType: TextInputType.number),
                TextFormField(
                    controller: _documentFee,
                    decoration:
                        const InputDecoration(labelText: 'Document fee ₹'),
                    keyboardType: TextInputType.number),
                TextFormField(
                    controller: _processingCost,
                    decoration:
                        const InputDecoration(labelText: 'Processing cost ₹'),
                    keyboardType: TextInputType.number),
                TextFormField(
                    controller: _otherCost,
                    decoration: const InputDecoration(
                        labelText: 'Other application cost ₹'),
                    keyboardType: TextInputType.number),
                DropdownButtonFormField<TenderStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    for (final status in TenderStatus.values)
                      DropdownMenuItem(
                          value: status, child: Text(status.value)),
                  ],
                  onChanged: (value) =>
                      setState(() => _status = value ?? TenderStatus.draft),
                ),
                TextFormField(
                    controller: _notes,
                    decoration: const InputDecoration(labelText: 'Notes')),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined),
                    label: const Text('Save tender'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(tenderRepositoryProvider).createTender(
            TenderDraft(
              bidderProfileId: _bidderProfileId,
              tenderTitle: _title.text,
              tenderNumber: _number.text,
              clientName: _client.text,
              departmentName: _department.text,
              location: _location.text,
              estimatedTenderValue: _parseMoney(_estimated.text),
              quotedTenderPrice: _parseMoney(_quoted.text),
              emdAmount: _parseMoney(_emd.text),
              tenderFee: _parseMoney(_tenderFee.text),
              documentFee: _parseMoney(_documentFee.text),
              processingCost: _parseMoney(_processingCost.text),
              otherApplicationCost: _parseMoney(_otherCost.text),
              status: _status,
              selectedDate: _status == TenderStatus.selected
                  ? DateTime.now().millisecondsSinceEpoch
                  : null,
              notes: _notes.text,
            ),
            ref.read(localWriteContextProvider),
          );
      _clearTenderForm();
      _refreshTenderProviders(ref);
      if (mounted) {
        _showMessage(context, 'Tender saved locally.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(context, error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _clearTenderForm() {
    _title.clear();
    _number.clear();
    _client.clear();
    _department.clear();
    _location.clear();
    _estimated.clear();
    _quoted.clear();
    _emd.clear();
    _tenderFee.clear();
    _documentFee.clear();
    _processingCost.clear();
    _otherCost.clear();
    _notes.clear();
    setState(() {
      _bidderProfileId = null;
      _status = TenderStatus.draft;
    });
  }
}

class _TenderList extends StatelessWidget {
  const _TenderList({required this.tenders});

  final List<TenderListItem> tenders;

  @override
  Widget build(BuildContext context) {
    if (tenders.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(22),
          child: Text(
              'No tenders yet. Add bidder profile and first tender above.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text('Tender list',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
        ),
        for (final tender in tenders) _TenderCard(tender: tender),
      ],
    );
  }
}

class _TenderCard extends ConsumerWidget {
  const _TenderCard({required this.tender});

  final TenderListItem tender;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(label: Text(tender.status.value)),
                if (tender.bidderProfileName != null)
                  Chip(label: Text(tender.bidderProfileName!)),
                if (tender.tenderNumber != null)
                  Chip(label: Text(tender.tenderNumber!)),
              ],
            ),
            const SizedBox(height: 8),
            Text(tender.title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text([tender.clientName, tender.location]
                .whereType<String>()
                .join(' • ')),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _MetricPill(
                    label: 'Quoted', value: tender.quotedPrice.format()),
                _MetricPill(
                    label: 'Estimated', value: tender.estimatedValue.format()),
                _MetricPill(
                    label: 'Application cost',
                    value: tender.totalApplicationCost.format()),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _markSelected(context, ref),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Mark selected'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showExpenseDialog(context),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Add expense'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showDocumentDialog(context),
                  icon: const Icon(Icons.attach_file_outlined),
                  label: const Text('Add document'),
                ),
                FilledButton.icon(
                  onPressed: tender.status.canConvertToProject
                      ? () => _showConvertDialog(context)
                      : null,
                  icon: const Icon(Icons.account_tree_outlined),
                  label: const Text('Convert to project'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markSelected(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(tenderRepositoryProvider).updateTenderStatus(
            tenderId: tender.id,
            status: TenderStatus.selected,
            context: ref.read(localWriteContextProvider),
          );
      _refreshTenderProviders(ref);
      if (context.mounted) {
        _showMessage(context, 'Tender marked selected.');
      }
    } catch (error) {
      if (context.mounted) {
        _showMessage(context, error.toString());
      }
    }
  }

  Future<void> _showExpenseDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _TenderExpenseDialog(tenderId: tender.id),
    );
  }

  Future<void> _showDocumentDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _TenderDocumentDialog(tenderId: tender.id),
    );
  }

  Future<void> _showConvertDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _TenderConvertDialog(tender: tender),
    );
  }
}

class _TenderExpenseDialog extends ConsumerStatefulWidget {
  const _TenderExpenseDialog({required this.tenderId});

  final String tenderId;

  @override
  ConsumerState<_TenderExpenseDialog> createState() =>
      _TenderExpenseDialogState();
}

class _TenderExpenseDialogState extends ConsumerState<_TenderExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _paidTo = TextEditingController();
  final _paymentMode = TextEditingController();
  TenderExpenseType _type = TenderExpenseType.misc;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _paidTo.dispose();
    _paymentMode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add tender expense'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<TenderExpenseType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Expense type'),
                items: [
                  for (final type in TenderExpenseType.values)
                    DropdownMenuItem(value: type, child: Text(type.value))
                ],
                onChanged: (value) =>
                    setState(() => _type = value ?? TenderExpenseType.misc),
              ),
              TextFormField(
                  controller: _amount,
                  decoration: const InputDecoration(labelText: 'Amount ₹ *'),
                  validator: _required,
                  keyboardType: TextInputType.number),
              TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Description')),
              TextFormField(
                  controller: _paidTo,
                  decoration: const InputDecoration(labelText: 'Paid to')),
              TextFormField(
                  controller: _paymentMode,
                  decoration: const InputDecoration(labelText: 'Payment mode')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save expense'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(tenderRepositoryProvider).addTenderExpense(
            TenderExpenseDraft(
              tenderId: widget.tenderId,
              expenseDate: DateTime.now().millisecondsSinceEpoch,
              expenseType: _type,
              amount: _parseMoney(_amount.text),
              description: _description.text,
              paidTo: _paidTo.text,
              paymentMode: _paymentMode.text,
            ),
            ref.read(localWriteContextProvider),
          );
      _refreshTenderProviders(ref);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        _showMessage(context, error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _TenderDocumentDialog extends ConsumerStatefulWidget {
  const _TenderDocumentDialog({required this.tenderId});

  final String tenderId;

  @override
  ConsumerState<_TenderDocumentDialog> createState() =>
      _TenderDocumentDialogState();
}

class _TenderDocumentDialogState extends ConsumerState<_TenderDocumentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fileName = TextEditingController();
  final _documentType = TextEditingController();
  final _localPath = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _fileName.dispose();
    _documentType.dispose();
    _localPath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add tender document'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                  controller: _fileName,
                  decoration: const InputDecoration(labelText: 'File name *'),
                  validator: _required),
              TextFormField(
                  controller: _documentType,
                  decoration:
                      const InputDecoration(labelText: 'Document type')),
              TextFormField(
                  controller: _localPath,
                  decoration:
                      const InputDecoration(labelText: 'Local file path')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save document')),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(tenderRepositoryProvider).addTenderDocument(
            TenderDocumentDraft(
              tenderId: widget.tenderId,
              fileName: _fileName.text,
              documentType: _documentType.text,
              localPath: _localPath.text,
            ),
            ref.read(localWriteContextProvider),
          );
      _refreshTenderProviders(ref);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        _showMessage(context, error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _TenderConvertDialog extends ConsumerStatefulWidget {
  const _TenderConvertDialog({required this.tender});

  final TenderListItem tender;

  @override
  ConsumerState<_TenderConvertDialog> createState() =>
      _TenderConvertDialogState();
}

class _TenderConvertDialogState extends ConsumerState<_TenderConvertDialog> {
  final _formKey = GlobalKey<FormState>();
  final _projectCode = TextEditingController();
  final _projectName = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _projectCode.text = 'PRJ-${DateTime.now().millisecondsSinceEpoch}';
    _projectName.text = widget.tender.title;
  }

  @override
  void dispose() {
    _projectCode.dispose();
    _projectName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Convert tender to project'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Quoted amount will become the initial agreement value: ${widget.tender.quotedPrice.format()}'),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _projectCode,
                  decoration:
                      const InputDecoration(labelText: 'Project code *'),
                  validator: _required),
              TextFormField(
                  controller: _projectName,
                  decoration:
                      const InputDecoration(labelText: 'Project name *'),
                  validator: _required),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('Create project')),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(tenderRepositoryProvider).convertSelectedTenderToProject(
            TenderProjectConversionDraft(
              tenderId: widget.tender.id,
              projectCode: _projectCode.text,
              projectName: _projectName.text,
            ),
            ref.read(localWriteContextProvider),
          );
      _refreshTenderProviders(ref);
      ref.invalidate(moduleSummaryRepositoryProvider);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        _showMessage(context, error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _ResponsiveFormGrid extends StatelessWidget {
  const _ResponsiveFormGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final child in children)
              SizedBox(
                width: isWide
                    ? (constraints.maxWidth - 14) / 2
                    : constraints.maxWidth,
                child: child,
              ),
          ],
        );
      },
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text('$label: $value'),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(message),
      ),
    );
  }
}

String? _required(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Required';
  }
  return null;
}

Money _parseMoney(String value) {
  if (value.trim().isEmpty) {
    return Money.zero;
  }
  return Money.parseRupees(value);
}

void _refreshTenderProviders(WidgetRef ref) {
  ref.invalidate(tenderStatsProvider);
  ref.invalidate(bidderProfilesProvider);
  ref.invalidate(tenderListProvider);
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
