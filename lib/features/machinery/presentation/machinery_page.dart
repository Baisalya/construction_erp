import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/value_objects/money.dart';
import '../../../core/value_objects/quantity.dart';
import '../../../features/fuel/domain/fuel_records.dart';
import '../../project/domain/project_record.dart';
import '../../work/presentation/work_project_provider.dart';
import '../domain/machinery_records.dart';

final machineUsageViewProvider = FutureProvider.autoDispose
    .family<List<MachineUsageRecord>, String?>((ref, projectId) async {
  final repository = ref.watch(machineryRepositoryProvider);
  final writeContext = ref.watch(localWriteContextProvider);
  return repository.listUsageEntries(writeContext.companyId,
      projectId: projectId);
});

class MachineryPage extends ConsumerStatefulWidget {
  const MachineryPage({super.key});

  @override
  ConsumerState<MachineryPage> createState() => _MachineryPageState();
}

class _MachineryPageState extends ConsumerState<MachineryPage> {
  String? _projectId;
  final _machineController = TextEditingController(text: 'JCB');
  final _quantityController = TextEditingController(text: '2');
  final _rateController = TextEditingController(text: '1800');
  final _paidController = TextEditingController(text: '0');
  final _ownerController = TextEditingController();
  final _fuelQuantityController = TextEditingController(text: '20');
  final _fuelRateController = TextEditingController(text: '92');
  final _repairPartsController = TextEditingController(text: '500');
  final _repairLaborController = TextEditingController(text: '300');
  MachineOwnershipType _ownership = MachineOwnershipType.own;
  MachineChargeType _chargeType = MachineChargeType.hourly;

  @override
  void dispose() {
    _machineController.dispose();
    _quantityController.dispose();
    _rateController.dispose();
    _paidController.dispose();
    _ownerController.dispose();
    _fuelQuantityController.dispose();
    _fuelRateController.dispose();
    _repairPartsController.dispose();
    _repairLaborController.dispose();
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
          final usages = ref.watch(machineUsageViewProvider(selectedProjectId));
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const _HeaderCard(
                title: 'Machinery + Fuel + Repair',
                subtitle:
                    'Own/rental machine usage, diesel/petrol/custom fuel link, repair cost, and paid/pending tracking.',
                icon: Icons.precision_manufacturing_outlined,
              ),
              const SizedBox(height: 16),
              if (selectedProjectId == null)
                const _MessageCard(
                    message: 'Create a project before adding machinery usage.')
              else
                _MachineryQuickEntry(
                  projects: projectList,
                  projectId: selectedProjectId,
                  onProjectChanged: (value) =>
                      setState(() => _projectId = value),
                  machineController: _machineController,
                  quantityController: _quantityController,
                  rateController: _rateController,
                  paidController: _paidController,
                  ownerController: _ownerController,
                  ownership: _ownership,
                  chargeType: _chargeType,
                  onOwnershipChanged: (value) =>
                      setState(() => _ownership = value ?? _ownership),
                  onChargeTypeChanged: (value) =>
                      setState(() => _chargeType = value ?? _chargeType),
                  fuelQuantityController: _fuelQuantityController,
                  fuelRateController: _fuelRateController,
                  repairPartsController: _repairPartsController,
                  repairLaborController: _repairLaborController,
                  onSave: () => _saveMachineFlow(selectedProjectId),
                ),
              const SizedBox(height: 16),
              usages.when(
                data: (data) => _MachineUsageList(
                  usages: data,
                  onDelete: (id) => _deleteUsage(id, selectedProjectId!),
                ),
                loading: () => const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator())),
                error: (error, stackTrace) =>
                    _MessageCard(message: error.toString()),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _MessageCard(message: error.toString()),
      ),
    );
  }

  Future<void> _saveMachineFlow(String projectId) async {
    final machineryRepository = ref.read(machineryRepositoryProvider);
    final fuelRepository = ref.read(fuelRepositoryProvider);
    final writeContext = ref.read(localWriteContextProvider);
    final machineId = await machineryRepository.createMachine(
      MachineDraft(
          machineName: _machineController.text,
          machineType: 'Earthwork',
          ownershipType: _ownership,
          ownerName: _ownership == MachineOwnershipType.rental
              ? _ownerController.text
              : null),
      writeContext,
    );
    await machineryRepository.createUsageEntry(
      MachineUsageDraft(
        projectId: projectId,
        machineId: machineId,
        usageDate: writeContext.timestamp,
        workDescription: 'Local machine usage',
        chargeType: _chargeType,
        hoursUsed: _chargeType == MachineChargeType.hourly
            ? DecimalQuantity.parse(_quantityController.text)
            : null,
        daysUsed: _chargeType == MachineChargeType.daily
            ? DecimalQuantity.parse(_quantityController.text)
            : null,
        quantity: _chargeType != MachineChargeType.hourly &&
                _chargeType != MachineChargeType.daily
            ? DecimalQuantity.parse(_quantityController.text)
            : null,
        rate: Money.parseRupees(_rateController.text),
        paidAmount: Money.parseRupees(_paidController.text),
      ),
      writeContext,
    );
    final fuelTypeId = await fuelRepository.createFuelType(
      FuelTypeDraft(
          name: 'Diesel',
          defaultRate: Money.parseRupees(_fuelRateController.text)),
      writeContext,
    );
    await fuelRepository.createFuelEntry(
      FuelEntryDraft(
        projectId: projectId,
        fuelDate: writeContext.timestamp,
        fuelTypeId: fuelTypeId,
        quantity: DecimalQuantity.parse(_fuelQuantityController.text),
        rate: Money.parseRupees(_fuelRateController.text),
        usedForType: FuelUsedForType.machinery,
        machineId: machineId,
      ),
      writeContext,
    );
    await machineryRepository.recordRepair(
      MachineRepairDraft(
        machineId: machineId,
        projectId: projectId,
        repairDate: writeContext.timestamp,
        repairDescription: 'Local repair entry',
        partsCost: Money.parseRupees(_repairPartsController.text),
        laborCost: Money.parseRupees(_repairLaborController.text),
      ),
      writeContext,
    );
    ref.invalidate(machineUsageViewProvider(projectId));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Machinery usage, fuel, and repair saved locally.')));
    }
  }

  Future<void> _deleteUsage(String id, String projectId) async {
    await ref.read(localRecordMaintenanceProvider).softDelete(
        'machine_usage_entries', id, ref.read(localWriteContextProvider));
    ref.invalidate(machineUsageViewProvider(projectId));
  }
}

class _MachineryQuickEntry extends StatelessWidget {
  const _MachineryQuickEntry({
    required this.projects,
    required this.projectId,
    required this.onProjectChanged,
    required this.machineController,
    required this.quantityController,
    required this.rateController,
    required this.paidController,
    required this.ownerController,
    required this.ownership,
    required this.chargeType,
    required this.onOwnershipChanged,
    required this.onChargeTypeChanged,
    required this.fuelQuantityController,
    required this.fuelRateController,
    required this.repairPartsController,
    required this.repairLaborController,
    required this.onSave,
  });

  final List<ProjectRecord> projects;
  final String projectId;
  final ValueChanged<String?> onProjectChanged;
  final TextEditingController machineController;
  final TextEditingController quantityController;
  final TextEditingController rateController;
  final TextEditingController paidController;
  final TextEditingController ownerController;
  final MachineOwnershipType ownership;
  final MachineChargeType chargeType;
  final ValueChanged<MachineOwnershipType?> onOwnershipChanged;
  final ValueChanged<MachineChargeType?> onChargeTypeChanged;
  final TextEditingController fuelQuantityController;
  final TextEditingController fuelRateController;
  final TextEditingController repairPartsController;
  final TextEditingController repairLaborController;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick machine + fuel + repair entry',
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
                _Input(controller: machineController, label: 'Machine'),
                SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<MachineOwnershipType>(
                      initialValue: ownership,
                      decoration: const InputDecoration(
                          border: OutlineInputBorder(), labelText: 'Ownership'),
                      items: [
                        for (final item in MachineOwnershipType.values)
                          DropdownMenuItem(value: item, child: Text(item.value))
                      ],
                      onChanged: onOwnershipChanged,
                    )),
                if (ownership == MachineOwnershipType.rental)
                  _Input(controller: ownerController, label: 'Owner name'),
                SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<MachineChargeType>(
                      initialValue: chargeType,
                      decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Charge type'),
                      items: [
                        for (final item in MachineChargeType.values)
                          DropdownMenuItem(value: item, child: Text(item.value))
                      ],
                      onChanged: onChargeTypeChanged,
                    )),
                _Input(controller: quantityController, label: 'Usage quantity'),
                _Input(controller: rateController, label: 'Rate ₹'),
                _Input(controller: paidController, label: 'Usage paid ₹'),
                _Input(controller: fuelQuantityController, label: 'Fuel liter'),
                _Input(controller: fuelRateController, label: 'Fuel rate ₹'),
                _Input(controller: repairPartsController, label: 'Parts ₹'),
                _Input(
                    controller: repairLaborController, label: 'Repair labor ₹'),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save machinery flow')),
          ],
        ),
      ),
    );
  }
}

class _MachineUsageList extends StatelessWidget {
  const _MachineUsageList({required this.usages, required this.onDelete});

  final List<MachineUsageRecord> usages;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    if (usages.isEmpty) {
      return const _MessageCard(message: 'No machine usage yet.');
    }
    return Column(
      children: [
        for (final usage in usages)
          Card(
            child: ListTile(
              leading: const Icon(Icons.precision_manufacturing_outlined),
              title: Text('${usage.chargeType.value} usage'),
              subtitle: Text(
                  'Total ${usage.totalAmount.format()} • Pending ${usage.pendingAmount.format()} • ${usage.paymentStatus.value}'),
              trailing: IconButton(
                  tooltip: 'Delete usage',
                  onPressed: () => onDelete(usage.id),
                  icon: const Icon(Icons.delete_outline)),
            ),
          ),
      ],
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: 190,
        child: TextField(
            controller: controller,
            decoration: const InputDecoration(border: OutlineInputBorder())
                .copyWith(labelText: label)));
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
