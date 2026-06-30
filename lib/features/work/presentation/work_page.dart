import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/value_objects/money.dart';
import '../../../shared/formatters/positive_decimal_input_formatter.dart';
import '../../../shared/presentation/app_feedback.dart';
import '../../project/domain/project_record.dart';
import '../domain/work_records.dart';
import 'work_project_provider.dart';

final workDaysProvider = FutureProvider.autoDispose
    .family<List<WorkDayRecord>, String>((ref, projectId) {
  final context = ref.watch(localWriteContextProvider);
  return ref
      .watch(workRepositoryProvider)
      .listWorkDays(context.companyId, projectId: projectId);
});

final projectExpensesProvider = FutureProvider.autoDispose
    .family<List<ProjectExpenseRecord>, String>((ref, projectId) {
  final context = ref.watch(localWriteContextProvider);
  return ref
      .watch(workRepositoryProvider)
      .listExpenses(context.companyId, projectId: projectId);
});

class WorkPage extends ConsumerStatefulWidget {
  const WorkPage({super.key});

  @override
  ConsumerState<WorkPage> createState() => _WorkPageState();
}

class _WorkPageState extends ConsumerState<WorkPage> {
  String? _projectId;
  String? _editingWorkDayId;
  String? _editingExpenseId;
  final _site = TextEditingController();
  final _weather = TextEditingController();
  final _workNotes = TextEditingController();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _paid = TextEditingController(text: '0');
  final _paymentMode = TextEditingController(text: 'cash');
  final _expenseNotes = TextEditingController();
  ProjectExpenseCategory _category = ProjectExpenseCategory.site;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _site,
      _weather,
      _workNotes,
      _description,
      _amount,
      _paid,
      _paymentMode,
      _expenseNotes
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(workProjectsProvider);
    return SafeArea(
      child: projects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text(friendlyErrorMessage(error))),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
                child: Text('Create a project before recording work.'));
          }
          final projectId = items.any((item) => item.id == _projectId)
              ? _projectId!
              : items.first.id;
          final days = ref.watch(workDaysProvider(projectId));
          final expenses = ref.watch(projectExpensesProvider(projectId));
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _Header(
                  projects: items,
                  projectId: projectId,
                  onChanged: (value) => setState(() {
                        _projectId = value;
                        _clearEditors();
                      })),
              const SizedBox(height: 14),
              LayoutBuilder(builder: (context, constraints) {
                final wide = constraints.maxWidth >= 850;
                final forms = [
                  _workDayForm(projectId),
                  _expenseForm(projectId),
                ];
                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Expanded(child: forms[0]),
                            const SizedBox(width: 14),
                            Expanded(child: forms[1])
                          ])
                    : Column(children: [
                        forms[0],
                        const SizedBox(height: 14),
                        forms[1]
                      ]);
              }),
              const SizedBox(height: 14),
              days.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, stack) => Text(friendlyErrorMessage(error)),
                data: (data) => _RecordCard(
                  title: 'Site diary',
                  emptyText: 'No work day recorded for this project.',
                  children: [
                    for (final day in data)
                      ListTile(
                        leading: const Icon(Icons.calendar_today_outlined),
                        title: Text(day.siteName ?? 'Project site'),
                        subtitle: Text(
                            '${_date(day.workDate)} • ${day.weather ?? 'Weather not set'}${day.notes == null ? '' : '\n${day.notes}'}'),
                        isThreeLine: day.notes != null,
                        trailing: _Actions(
                            onEdit: () => _editWorkDay(day),
                            onDelete: () => _deleteWorkDay(day.id, projectId)),
                      )
                  ],
                ),
              ),
              const SizedBox(height: 14),
              expenses.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, stack) => Text(friendlyErrorMessage(error)),
                data: (data) => _RecordCard(
                  title: 'Other project expenses',
                  emptyText: 'No other expense recorded for this project.',
                  children: [
                    for (final item in data)
                      ListTile(
                        leading: const Icon(Icons.payments_outlined),
                        title: Text(item.description ?? item.category.label),
                        subtitle: Text(
                            '${item.category.label} • ${_date(item.expenseDate)}\nTotal ${item.amount.format()} • Paid ${item.paidAmount.format()} • Pending ${item.pendingAmount.format()}\n${paymentStatusLabel(paid: item.paidAmount, pending: item.pendingAmount)}'),
                        isThreeLine: true,
                        trailing: _Actions(
                            onEdit: () => _editExpense(item),
                            onDelete: () => _deleteExpense(item.id, projectId)),
                      )
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _workDayForm(String projectId) => Card(
        child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    _editingWorkDayId == null
                        ? 'Add site diary'
                        : 'Edit site diary',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _Field(controller: _site, label: 'Site name'),
                _Field(controller: _weather, label: 'Weather'),
                _Field(controller: _workNotes, label: 'Work notes', lines: 3),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: FilledButton.icon(
                          onPressed:
                              _saving ? null : () => _saveWorkDay(projectId),
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Save diary'))),
                  if (_editingWorkDayId != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                        onPressed: _clearEditors, icon: const Icon(Icons.close))
                  ],
                ]),
              ],
            )),
      );

  Widget _expenseForm(String projectId) => Card(
        child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    _editingExpenseId == null
                        ? 'Add other expense'
                        : 'Edit other expense',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                DropdownButtonFormField<ProjectExpenseCategory>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                        labelText: 'Category', border: OutlineInputBorder()),
                    items: [
                      for (final item in ProjectExpenseCategory.values)
                        DropdownMenuItem(value: item, child: Text(item.label))
                    ],
                    onChanged: (value) =>
                        setState(() => _category = value ?? _category)),
                _Field(controller: _description, label: 'Description'),
                Row(children: [
                  Expanded(
                      child: _Field(
                          controller: _amount,
                          label: 'Amount ₹',
                          number: true)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _Field(
                          controller: _paid, label: 'Paid ₹', number: true))
                ]),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _paymentMode.text,
                  decoration: const InputDecoration(labelText: 'Payment mode'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(
                        value: 'bank', child: Text('Bank transfer')),
                    DropdownMenuItem(value: 'upi', child: Text('UPI')),
                    DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) => _paymentMode.text = value ?? 'cash',
                ),
                _Field(controller: _expenseNotes, label: 'Notes'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: FilledButton.icon(
                          onPressed:
                              _saving ? null : () => _saveExpense(projectId),
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Save expense'))),
                  if (_editingExpenseId != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                        onPressed: _clearEditors, icon: const Icon(Icons.close))
                  ],
                ]),
              ],
            )),
      );

  Future<void> _saveWorkDay(String projectId) async {
    setState(() => _saving = true);
    try {
      final repository = ref.read(workRepositoryProvider);
      final writeContext = ref.read(localWriteContextProvider);
      final draft = WorkDayDraft(
          projectId: projectId,
          workDate: DateTime.now().millisecondsSinceEpoch,
          siteName: _site.text,
          weather: _weather.text,
          notes: _workNotes.text);
      if (_editingWorkDayId == null) {
        await repository.createWorkDay(draft, writeContext);
      } else {
        await repository.updateWorkDay(_editingWorkDayId!, draft, writeContext);
      }
      ref.invalidate(workDaysProvider(projectId));
      _clearEditors();
    } catch (error) {
      _message(friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveExpense(String projectId) async {
    setState(() => _saving = true);
    try {
      final repository = ref.read(workRepositoryProvider);
      final writeContext = ref.read(localWriteContextProvider);
      final draft = ProjectExpenseDraft(
          projectId: projectId,
          expenseDate: DateTime.now().millisecondsSinceEpoch,
          category: _category,
          description: _description.text,
          amount: Money.parseRupees(_amount.text),
          paidAmount: Money.parseRupees(_paid.text),
          paymentMode: _paymentMode.text,
          notes: _expenseNotes.text);
      if (_editingExpenseId == null) {
        await repository.createExpense(draft, writeContext);
      } else {
        await repository.updateExpense(_editingExpenseId!, draft, writeContext);
      }
      ref.invalidate(projectExpensesProvider(projectId));
      _clearEditors();
    } catch (error) {
      _message(friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteWorkDay(String id, String projectId) async {
    if (!await confirmDestructiveAction(
      context,
      title: 'Delete site diary?',
      message: 'This site diary entry will be removed.',
    )) {
      return;
    }
    await ref
        .read(workRepositoryProvider)
        .deleteWorkDay(id, ref.read(localWriteContextProvider));
    ref.invalidate(workDaysProvider(projectId));
  }

  Future<void> _deleteExpense(String id, String projectId) async {
    if (!await confirmDestructiveAction(
      context,
      title: 'Delete project expense?',
      message: 'This expense will be removed from project totals.',
    )) {
      return;
    }
    await ref
        .read(workRepositoryProvider)
        .deleteExpense(id, ref.read(localWriteContextProvider));
    ref.invalidate(projectExpensesProvider(projectId));
  }

  void _editWorkDay(WorkDayRecord item) => setState(() {
        _editingWorkDayId = item.id;
        _editingExpenseId = null;
        _site.text = item.siteName ?? '';
        _weather.text = item.weather ?? '';
        _workNotes.text = item.notes ?? '';
      });

  void _editExpense(ProjectExpenseRecord item) => setState(() {
        _editingExpenseId = item.id;
        _editingWorkDayId = null;
        _category = item.category;
        _description.text = item.description ?? '';
        _amount.text = item.amount.inputText;
        _paid.text = item.paidAmount.inputText;
        _paymentMode.text = item.paymentMode ?? 'cash';
        _expenseNotes.text = item.notes ?? '';
      });

  void _clearEditors() => setState(() {
        _editingWorkDayId = null;
        _editingExpenseId = null;
        _site.clear();
        _weather.clear();
        _workNotes.clear();
        _description.clear();
        _amount.clear();
        _paid.text = '0';
        _paymentMode.text = 'cash';
        _expenseNotes.clear();
      });

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.projects,
      required this.projectId,
      required this.onChanged});
  final List<ProjectRecord> projects;
  final String projectId;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 20,
            runSpacing: 14,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Daily Work & Expenses',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const Text(
                    'Site diary and other expenses stored in the project ledger.')
              ]),
              SizedBox(
                  width: 300,
                  child: DropdownButtonFormField<String>(
                      initialValue: projectId,
                      decoration: const InputDecoration(
                          labelText: 'Project', border: OutlineInputBorder()),
                      items: [
                        for (final item in projects)
                          DropdownMenuItem(
                              value: item.id, child: Text(item.projectName))
                      ],
                      onChanged: onChanged))
            ],
          )));
}

class _Field extends StatelessWidget {
  const _Field(
      {required this.controller,
      required this.label,
      this.number = false,
      this.lines = 1});
  final TextEditingController controller;
  final String label;
  final bool number;
  final int lines;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextField(
          controller: controller,
          maxLines: lines,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          inputFormatters:
              number ? const [PositiveDecimalInputFormatter()] : null,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder())));
}

class _RecordCard extends StatelessWidget {
  const _RecordCard(
      {required this.title, required this.emptyText, required this.children});
  final String title;
  final String emptyText;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.all(18),
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800))),
        if (children.isEmpty)
          Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Text(emptyText))
        else
          ...children
      ]));
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onEdit, required this.onDelete});
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Wrap(children: [
        IconButton(
            tooltip: 'Edit',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined)),
        IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline))
      ]);
}

String _date(int milliseconds) {
  final d = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
