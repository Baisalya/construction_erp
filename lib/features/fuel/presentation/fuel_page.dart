import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/value_objects/money.dart';
import '../../../core/value_objects/quantity.dart';
import '../../machinery/domain/machinery_records.dart';
import '../../project/domain/project_record.dart';
import '../../work/presentation/work_project_provider.dart';
import '../domain/fuel_records.dart';

final fuelTypesViewProvider =
    FutureProvider.autoDispose<List<FuelTypeRecord>>((ref) {
  final context = ref.watch(localWriteContextProvider);
  return ref.watch(fuelRepositoryProvider).listFuelTypes(context.companyId);
});

final fuelMachinesViewProvider =
    FutureProvider.autoDispose<List<MachineRecord>>((ref) {
  final context = ref.watch(localWriteContextProvider);
  return ref.watch(machineryRepositoryProvider).listMachines(context.companyId);
});

final fuelEntriesViewProvider = FutureProvider.autoDispose
    .family<List<FuelEntryRecord>, String>((ref, projectId) {
  final context = ref.watch(localWriteContextProvider);
  return ref
      .watch(fuelRepositoryProvider)
      .listFuelEntries(context.companyId, projectId: projectId);
});

class FuelPage extends ConsumerStatefulWidget {
  const FuelPage({super.key});
  @override
  ConsumerState<FuelPage> createState() => _FuelPageState();
}

class _FuelPageState extends ConsumerState<FuelPage> {
  String? _projectId;
  String? _fuelTypeId;
  String? _machineId;
  String? _editingId;
  FuelUsedForType _usedFor = FuelUsedForType.projectGeneral;
  final _typeName = TextEditingController(text: 'Diesel');
  final _typeRate = TextEditingController();
  final _quantity = TextEditingController();
  final _rate = TextEditingController();
  final _paid = TextEditingController(text: '0');
  final _vehicle = TextEditingController();
  final _description = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final item in [
      _typeName,
      _typeRate,
      _quantity,
      _rate,
      _paid,
      _vehicle,
      _description,
      _notes
    ]) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(workProjectsProvider);
    final types = ref.watch(fuelTypesViewProvider);
    final machines = ref.watch(fuelMachinesViewProvider);
    return SafeArea(
        child: projects.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text(error.toString())),
      data: (projectItems) {
        if (projectItems.isEmpty) {
          return const Center(
              child: Text('Create a project before recording fuel.'));
        }
        final projectId = projectItems.any((item) => item.id == _projectId)
            ? _projectId!
            : projectItems.first.id;
        final entries = ref.watch(fuelEntriesViewProvider(projectId));
        return ListView(padding: const EdgeInsets.all(20), children: [
          _header(projectItems, projectId),
          const SizedBox(height: 14),
          types.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stack) => Text(error.toString()),
            data: (typeItems) => machines.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => Text(error.toString()),
              data: (machineItems) =>
                  _forms(projectId, typeItems, machineItems),
            ),
          ),
          const SizedBox(height: 14),
          entries.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stack) => Text(error.toString()),
            data: (items) => Card(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text('Fuel ledger',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800))),
                  if (items.isEmpty)
                    const Padding(
                        padding: EdgeInsets.fromLTRB(18, 0, 18, 18),
                        child: Text('No fuel entry for this project.')),
                  for (final item in items)
                    ListTile(
                      leading: const Icon(Icons.local_gas_station_outlined),
                      title: Text(
                          '${item.quantity} × ${item.rate.format()} = ${item.totalAmount.format()}'),
                      subtitle: Text(
                          '${_usedForLabel(item.usedForType)} • Paid ${item.paidAmount.format()} • Pending ${item.pendingAmount.format()}${item.description == null ? '' : '\n${item.description}'}'),
                      isThreeLine: item.description != null,
                      trailing: Wrap(children: [
                        IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _edit(item)),
                        IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(item.id, projectId)),
                      ]),
                    ),
                ])),
          ),
        ]);
      },
    ));
  }

  Widget _header(List<ProjectRecord> projects, String projectId) => Card(
          child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
            spacing: 20,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                  width: 270,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Fuel',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900)),
                        const Text(
                            'Diesel, petrol and custom fuel linked to project work.')
                      ])),
              SizedBox(
                  width: 270,
                  child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: projectId,
                      decoration: const InputDecoration(
                          labelText: 'Project', border: OutlineInputBorder()),
                      items: [
                        for (final item in projects)
                          DropdownMenuItem(
                              value: item.id, child: Text(item.projectName))
                      ],
                      onChanged: (value) => setState(() {
                            _projectId = value;
                            _editingId = null;
                          }))),
            ]),
      ));

  Widget _forms(String projectId, List<FuelTypeRecord> types,
      List<MachineRecord> machines) {
    final selectedType = types.any((item) => item.id == _fuelTypeId)
        ? _fuelTypeId
        : (types.isEmpty ? null : types.first.id);
    final selectedMachine = machines.any((item) => item.id == _machineId)
        ? _machineId
        : (machines.isEmpty ? null : machines.first.id);
    return LayoutBuilder(builder: (context, constraints) {
      final typeCard = Card(
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add fuel type',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    _Field(_typeName, 'Name'),
                    _Field(_typeRate, 'Default rate ₹', number: true),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                        onPressed: _saving ? null : _saveType,
                        icon: const Icon(Icons.add),
                        label: const Text('Add type')),
                  ])));
      final entryCard = Card(
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _editingId == null
                            ? 'Add fuel entry'
                            : 'Edit fuel entry',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selectedType,
                        decoration: const InputDecoration(
                            labelText: 'Fuel type',
                            border: OutlineInputBorder()),
                        items: [
                          for (final item in types)
                            DropdownMenuItem(
                                value: item.id, child: Text(item.name))
                        ],
                        onChanged: (value) =>
                            setState(() => _fuelTypeId = value)),
                    Wrap(spacing: 10, children: [
                      SizedBox(
                          width: 170,
                          child: _Field(_quantity, 'Quantity', number: true)),
                      SizedBox(
                          width: 170,
                          child: _Field(_rate, 'Rate ₹', number: true)),
                      SizedBox(
                          width: 170,
                          child: _Field(_paid, 'Paid ₹', number: true)),
                    ]),
                    Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: DropdownButtonFormField<FuelUsedForType>(
                            isExpanded: true,
                            initialValue: _usedFor,
                            decoration: const InputDecoration(
                                labelText: 'Used for',
                                border: OutlineInputBorder()),
                            items: [
                              for (final item in FuelUsedForType.values)
                                DropdownMenuItem(
                                    value: item,
                                    child: Text(_usedForLabel(item)))
                            ],
                            onChanged: (value) =>
                                setState(() => _usedFor = value ?? _usedFor))),
                    if (_usedFor == FuelUsedForType.machinery)
                      Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: selectedMachine,
                              decoration: const InputDecoration(
                                  labelText: 'Machine',
                                  border: OutlineInputBorder()),
                              items: [
                                for (final item in machines)
                                  DropdownMenuItem(
                                      value: item.id,
                                      child: Text(item.machineName))
                              ],
                              onChanged: (value) =>
                                  setState(() => _machineId = value))),
                    _Field(_vehicle, 'Vehicle name / number'),
                    _Field(_description, 'Description'),
                    _Field(_notes, 'Notes'),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: FilledButton.icon(
                              onPressed: _saving ||
                                      selectedType == null ||
                                      (_usedFor == FuelUsedForType.machinery &&
                                          selectedMachine == null)
                                  ? null
                                  : () => _saveEntry(
                                      projectId, selectedType, selectedMachine),
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Save fuel'))),
                      if (_editingId != null)
                        IconButton(
                            onPressed: _clear, icon: const Icon(Icons.close))
                    ]),
                  ])));
      return constraints.maxWidth >= 900
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 300, child: typeCard),
              const SizedBox(width: 14),
              Expanded(child: entryCard)
            ])
          : Column(children: [typeCard, const SizedBox(height: 14), entryCard]);
    });
  }

  Future<void> _saveType() async {
    setState(() => _saving = true);
    try {
      await ref.read(fuelRepositoryProvider).createFuelType(
          FuelTypeDraft(
              name: _typeName.text,
              defaultRate: Money.parseRupees(_typeRate.text)),
          ref.read(localWriteContextProvider));
      ref.invalidate(fuelTypesViewProvider);
      _typeName.clear();
      _typeRate.clear();
    } catch (error) {
      _message(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveEntry(
      String projectId, String typeId, String? machineId) async {
    setState(() => _saving = true);
    try {
      final draft = FuelEntryDraft(
          projectId: projectId,
          fuelDate: DateTime.now().millisecondsSinceEpoch,
          fuelTypeId: typeId,
          quantity: DecimalQuantity.parse(_quantity.text),
          rate: Money.parseRupees(_rate.text),
          usedForType: _usedFor,
          machineId: _usedFor == FuelUsedForType.machinery ? machineId : null,
          vehicleName: _vehicle.text,
          description: _description.text,
          paidAmount: Money.parseRupees(_paid.text),
          notes: _notes.text);
      final repository = ref.read(fuelRepositoryProvider);
      final write = ref.read(localWriteContextProvider);
      if (_editingId == null) {
        await repository.createFuelEntry(draft, write);
      } else {
        await repository.updateFuelEntry(_editingId!, draft, write);
      }
      ref.invalidate(fuelEntriesViewProvider(projectId));
      _clear();
    } catch (error) {
      _message(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(String id, String projectId) async {
    await ref
        .read(fuelRepositoryProvider)
        .deleteFuelEntry(id, ref.read(localWriteContextProvider));
    ref.invalidate(fuelEntriesViewProvider(projectId));
  }

  void _edit(FuelEntryRecord item) => setState(() {
        _editingId = item.id;
        _fuelTypeId = item.fuelTypeId;
        _machineId = item.machineId;
        _usedFor = item.usedForType;
        _quantity.text = item.quantity.toStorageString();
        _rate.text = item.rate.inputText;
        _paid.text = item.paidAmount.inputText;
        _vehicle.text = item.vehicleName ?? '';
        _description.text = item.description ?? '';
        _notes.text = item.notes ?? '';
      });
  void _clear() => setState(() {
        _editingId = null;
        _quantity.clear();
        _rate.clear();
        _paid.text = '0';
        _vehicle.clear();
        _description.clear();
        _notes.clear();
      });
  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }
}

class _Field extends StatelessWidget {
  const _Field(this.controller, this.label, {this.number = false});
  final TextEditingController controller;
  final String label;
  final bool number;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextField(
          controller: controller,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder())));
}

String _usedForLabel(FuelUsedForType value) => switch (value) {
      FuelUsedForType.machinery => 'Machinery',
      FuelUsedForType.labor => 'Labor transport',
      FuelUsedForType.materialTransport => 'Material transport',
      FuelUsedForType.projectGeneral => 'Project general',
      FuelUsedForType.other => 'Other'
    };
