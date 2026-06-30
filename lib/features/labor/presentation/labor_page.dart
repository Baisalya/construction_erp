import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/value_objects/money.dart';
import '../../../core/value_objects/quantity.dart';
import '../../../shared/formatters/positive_decimal_input_formatter.dart';
import '../../../shared/presentation/app_feedback.dart';
import '../../project/domain/project_record.dart';
import '../../work/presentation/work_project_provider.dart';
import '../domain/labor_records.dart';

final laborWorkEntriesViewProvider = FutureProvider.autoDispose
    .family<List<LaborWorkEntryRecord>, String?>((ref, projectId) async {
  final repository = ref.watch(laborRepositoryProvider);
  final writeContext = ref.watch(localWriteContextProvider);
  return repository.listWorkEntries(writeContext.companyId,
      projectId: projectId);
});

class LaborPage extends ConsumerStatefulWidget {
  const LaborPage({super.key});

  @override
  ConsumerState<LaborPage> createState() => _LaborPageState();
}

class _LaborPageState extends ConsumerState<LaborPage> {
  String? _projectId;
  final _nameController = TextEditingController(text: 'Site Labor');
  final _quantityController = TextEditingController(text: '1');
  final _rateController = TextEditingController(text: '650');
  final _paidController = TextEditingController(text: '300');
  final _descriptionController = TextEditingController();
  LaborWorkType _workType = LaborWorkType.daywise;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _rateController.dispose();
    _paidController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(workProjectsProvider);
    return SafeArea(
      child: projects.when(
        data: (projectList) {
          final selectedProjectId =
              projectList.any((project) => project.id == _projectId)
                  ? _projectId!
                  : projectList.isEmpty
                      ? null
                      : projectList.first.id;
          final entries =
              ref.watch(laborWorkEntriesViewProvider(selectedProjectId));
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const _HeaderCard(
                title: 'Labor',
                subtitle:
                    'Daywise, thika, hourly, piecework, paid, pending, and advances are local-first.',
                icon: Icons.engineering_outlined,
              ),
              const SizedBox(height: 16),
              if (selectedProjectId == null)
                const _MessageCard(
                    message: 'Create a project before adding labor work.')
              else
                _LaborQuickEntry(
                  projects: projectList,
                  projectId: selectedProjectId,
                  onProjectChanged: (value) =>
                      setState(() => _projectId = value),
                  nameController: _nameController,
                  quantityController: _quantityController,
                  rateController: _rateController,
                  paidController: _paidController,
                  descriptionController: _descriptionController,
                  workType: _workType,
                  onWorkTypeChanged: (value) =>
                      setState(() => _workType = value ?? _workType),
                  onSave: () => _saveLaborEntry(selectedProjectId),
                ),
              const SizedBox(height: 16),
              entries.when(
                data: (data) => _LaborEntryList(
                  entries: data,
                  onDelete: (id) => _deleteEntry(id, selectedProjectId!),
                ),
                loading: () => const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator())),
                error: (error, stackTrace) =>
                    _MessageCard(message: friendlyErrorMessage(error)),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _MessageCard(message: friendlyErrorMessage(error)),
      ),
    );
  }

  Future<void> _saveLaborEntry(String projectId) async {
    try {
      final repository = ref.read(laborRepositoryProvider);
      final writeContext = ref.read(localWriteContextProvider);
      final laborId = await repository.createLaborer(
        LaborerDraft(
            name: _nameController.text,
            defaultRate: Money.parseRupees(_rateController.text)),
        writeContext,
      );
      await repository.createWorkEntry(
        LaborWorkEntryDraft(
          projectId: projectId,
          laborId: laborId,
          workDate: writeContext.timestamp,
          workDescription: _descriptionController.text,
          workType: _workType,
          quantity: DecimalQuantity.parse(_quantityController.text),
          unit: switch (_workType) {
            LaborWorkType.daywise => 'day',
            LaborWorkType.hourly => 'hour',
            LaborWorkType.piecework => 'piece',
            LaborWorkType.thika => 'job',
            LaborWorkType.custom => 'custom',
          },
          rate: Money.parseRupees(_rateController.text),
          paidAmount: Money.parseRupees(_paidController.text),
        ),
        writeContext,
      );
      ref.invalidate(laborWorkEntriesViewProvider(projectId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Labor work saved successfully.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyErrorMessage(error))));
      }
    }
  }

  Future<void> _deleteEntry(String id, String projectId) async {
    if (!await confirmDestructiveAction(
      context,
      title: 'Delete labor entry?',
      message: 'This labor cost will be removed from project totals.',
    )) {
      return;
    }
    await ref.read(localRecordMaintenanceProvider).softDelete(
        'labor_work_entries', id, ref.read(localWriteContextProvider));
    ref.invalidate(laborWorkEntriesViewProvider(projectId));
  }
}

class _LaborQuickEntry extends StatelessWidget {
  const _LaborQuickEntry(
      {required this.projects,
      required this.projectId,
      required this.onProjectChanged,
      required this.nameController,
      required this.quantityController,
      required this.rateController,
      required this.paidController,
      required this.descriptionController,
      required this.workType,
      required this.onWorkTypeChanged,
      required this.onSave});

  final List<ProjectRecord> projects;
  final String projectId;
  final ValueChanged<String?> onProjectChanged;
  final TextEditingController nameController;
  final TextEditingController quantityController;
  final TextEditingController rateController;
  final TextEditingController paidController;
  final TextEditingController descriptionController;
  final LaborWorkType workType;
  final ValueChanged<LaborWorkType?> onWorkTypeChanged;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick labor entry',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 280,
                  child: DropdownButtonFormField<String>(
                    initialValue: projectId,
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(), labelText: 'Project'),
                    items: [
                      for (final project in projects)
                        DropdownMenuItem(
                            value: project.id,
                            child: Text(project.projectName,
                                overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: onProjectChanged,
                  ),
                ),
                _Input(controller: nameController, label: 'Labor name'),
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<LaborWorkType>(
                    initialValue: workType,
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(), labelText: 'Work type'),
                    items: [
                      for (final item in LaborWorkType.values)
                        DropdownMenuItem(value: item, child: Text(item.value)),
                    ],
                    onChanged: onWorkTypeChanged,
                  ),
                ),
                _Input(
                    controller: descriptionController,
                    label: 'Work description'),
                _Input(controller: quantityController, label: 'Days / qty'),
                _Input(controller: rateController, label: 'Rate ₹'),
                _Input(controller: paidController, label: 'Paid ₹'),
              ],
            ),
            const SizedBox(height: 16),
            ListenableBuilder(
              listenable: Listenable.merge([
                nameController,
                quantityController,
                rateController,
                paidController,
              ]),
              builder: (context, _) => FilledButton.icon(
                onPressed: _validLaborEntry(nameController, quantityController,
                        rateController, paidController)
                    ? onSave
                    : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save labor work'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LaborEntryList extends StatelessWidget {
  const _LaborEntryList({required this.entries, required this.onDelete});

  final List<LaborWorkEntryRecord> entries;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const _MessageCard(message: 'No labor work entry yet.');
    }
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 800) {
        return Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Work type')),
                DataColumn(label: Text('Quantity')),
                DataColumn(label: Text('Total')),
                DataColumn(label: Text('Paid')),
                DataColumn(label: Text('Pending')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: [
                for (final entry in entries)
                  DataRow(cells: [
                    DataCell(Text(entry.workType.value)),
                    DataCell(Text('${entry.quantity} ${entry.unit}')),
                    DataCell(Text(entry.totalAmount.format())),
                    DataCell(Text(entry.paidAmount.format())),
                    DataCell(Text(entry.pendingAmount.format())),
                    DataCell(Text(paymentStatusLabel(
                        paid: entry.paidAmount, pending: entry.pendingAmount))),
                    DataCell(IconButton(
                      tooltip: 'Delete work entry',
                      onPressed: () => onDelete(entry.id),
                      icon: const Icon(Icons.delete_outline),
                    )),
                  ]),
              ],
            ),
          ),
        );
      }
      return Column(children: [
        for (final entry in entries)
          Card(
            child: ListTile(
              leading: const Icon(Icons.engineering_outlined),
              title: Text(
                  '${entry.workType.value} • ${entry.quantity} ${entry.unit}'),
              subtitle: Text(
                  'Total ${entry.totalAmount.format()} • Paid ${entry.paidAmount.format()} • Pending ${entry.pendingAmount.format()}\n${paymentStatusLabel(paid: entry.paidAmount, pending: entry.pendingAmount)}'),
              isThreeLine: true,
              trailing: IconButton(
                  tooltip: 'Delete work entry',
                  onPressed: () => onDelete(entry.id),
                  icon: const Icon(Icons.delete_outline)),
            ),
          ),
      ]);
    });
  }
}

class _Input extends StatelessWidget {
  const _Input({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    final numeric = label.contains('₹') || label.contains('qty');
    return SizedBox(
        width: 190,
        child: TextField(
            controller: controller,
            keyboardType: numeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            inputFormatters:
                numeric ? const [PositiveDecimalInputFormatter()] : null,
            decoration: const InputDecoration(border: OutlineInputBorder())
                .copyWith(labelText: label)));
  }
}

bool _validLaborEntry(
  TextEditingController name,
  TextEditingController quantity,
  TextEditingController rate,
  TextEditingController paid,
) {
  if (name.text.trim().isEmpty) return false;
  try {
    final parsedQuantity = DecimalQuantity.parse(quantity.text);
    final parsedRate = Money.parseRupees(rate.text);
    final parsedPaid = Money.parseRupees(paid.text);
    final total = parsedQuantity.multiplyMoney(parsedRate);
    return !parsedQuantity.isZero &&
        !parsedQuantity.isNegative &&
        !parsedRate.isNegative &&
        !parsedPaid.isNegative &&
        parsedPaid.paise <= total.paise;
  } catch (_) {
    return false;
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard(
      {required this.title, required this.subtitle, required this.icon});

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(padding: const EdgeInsets.all(20), child: Text(message)));
}
