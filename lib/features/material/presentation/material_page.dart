import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/value_objects/money.dart';
import '../../../core/value_objects/quantity.dart';
import '../../project/domain/project_record.dart';
import '../../work/presentation/work_project_provider.dart';
import '../domain/material_records.dart';

final materialPurchasesViewProvider = FutureProvider.autoDispose
    .family<List<MaterialPurchaseRecord>, String?>((ref, projectId) async {
  final repository = ref.watch(materialRepositoryProvider);
  final writeContext = ref.watch(localWriteContextProvider);
  return repository.listPurchases(writeContext.companyId, projectId: projectId);
});

class MaterialPage extends ConsumerStatefulWidget {
  const MaterialPage({super.key});

  @override
  ConsumerState<MaterialPage> createState() => _MaterialPageState();
}

class _MaterialPageState extends ConsumerState<MaterialPage> {
  String? _projectId;
  final _supplierController = TextEditingController(text: 'Local Supplier');
  final _billController = TextEditingController();
  final _paidController = TextEditingController(text: '1000');
  final List<_MaterialItemControllers> _items = [
    _MaterialItemControllers.defaults(),
  ];

  @override
  void dispose() {
    _supplierController.dispose();
    _billController.dispose();
    _paidController.dispose();
    for (final item in _items) {
      item.dispose();
    }
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
          final purchases =
              ref.watch(materialPurchasesViewProvider(selectedProjectId));
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const _HeaderCard(
                title: 'Material',
                subtitle:
                    'Supplier bills, item quantity, GST, paid and pending amounts are stored locally first.',
                icon: Icons.inventory_2_outlined,
              ),
              const SizedBox(height: 16),
              if (selectedProjectId == null)
                const _EmptyCard(
                    message:
                        'Create a project before adding a material purchase.')
              else
                _MaterialQuickEntry(
                  projects: projectList,
                  projectId: selectedProjectId,
                  onProjectChanged: (value) =>
                      setState(() => _projectId = value),
                  supplierController: _supplierController,
                  billController: _billController,
                  paidController: _paidController,
                  items: _items,
                  onAddItem: () => setState(
                      () => _items.add(_MaterialItemControllers.empty())),
                  onRemoveItem: (index) => setState(() {
                    if (_items.length > 1) {
                      _items.removeAt(index).dispose();
                    }
                  }),
                  onSave: () => _savePurchase(selectedProjectId),
                ),
              const SizedBox(height: 16),
              purchases.when(
                data: (data) => _PurchaseList(
                  purchases: data,
                  onDelete: (id) => _deletePurchase(id, selectedProjectId!),
                ),
                loading: () => const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator())),
                error: (error, stackTrace) =>
                    _ErrorCard(message: error.toString()),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorCard(message: error.toString()),
      ),
    );
  }

  Future<void> _savePurchase(String projectId) async {
    final repository = ref.read(materialRepositoryProvider);
    final writeContext = ref.read(localWriteContextProvider);
    final supplierId = await repository.createSupplier(
      SupplierDraft(supplierName: _supplierController.text),
      writeContext,
    );
    await repository.createPurchase(
      MaterialPurchaseDraft(
        projectId: projectId,
        supplierId: supplierId,
        purchaseDate: writeContext.timestamp,
        billNumber: _billController.text,
        items: [for (final item in _items) item.toDraft()],
        paidAmount: Money.parseRupees(_paidController.text),
      ),
      writeContext,
    );
    ref.invalidate(materialPurchasesViewProvider(projectId));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Material purchase saved locally.')));
    }
  }

  Future<void> _deletePurchase(String id, String projectId) async {
    await ref.read(localRecordMaintenanceProvider).softDelete(
        'material_purchases', id, ref.read(localWriteContextProvider));
    ref.invalidate(materialPurchasesViewProvider(projectId));
  }
}

class _MaterialQuickEntry extends StatelessWidget {
  const _MaterialQuickEntry({
    required this.projects,
    required this.projectId,
    required this.onProjectChanged,
    required this.supplierController,
    required this.billController,
    required this.paidController,
    required this.items,
    required this.onAddItem,
    required this.onRemoveItem,
    required this.onSave,
  });

  final List<ProjectRecord> projects;
  final String projectId;
  final ValueChanged<String?> onProjectChanged;
  final TextEditingController supplierController;
  final TextEditingController billController;
  final TextEditingController paidController;
  final List<_MaterialItemControllers> items;
  final VoidCallback onAddItem;
  final ValueChanged<int> onRemoveItem;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick material entry',
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
                _Input(controller: supplierController, label: 'Supplier'),
                _Input(controller: billController, label: 'Bill / invoice'),
                _Input(controller: paidController, label: 'Paid ₹'),
              ],
            ),
            const SizedBox(height: 14),
            for (var index = 0; index < items.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Wrap(spacing: 10, runSpacing: 10, children: [
                  _Input(
                      controller: items[index].name,
                      label: 'Material ${index + 1}'),
                  _Input(controller: items[index].unit, label: 'Unit'),
                  _Input(controller: items[index].quantity, label: 'Quantity'),
                  _Input(controller: items[index].rate, label: 'Rate ₹'),
                  _Input(controller: items[index].gst, label: 'GST %'),
                  if (items.length > 1)
                    IconButton(
                        tooltip: 'Remove item',
                        onPressed: () => onRemoveItem(index),
                        icon: const Icon(Icons.remove_circle_outline)),
                ]),
              ),
            TextButton.icon(
                onPressed: onAddItem,
                icon: const Icon(Icons.add),
                label: const Text('Add another material item')),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save material purchase')),
          ],
        ),
      ),
    );
  }
}

class _PurchaseList extends StatelessWidget {
  const _PurchaseList({required this.purchases, required this.onDelete});

  final List<MaterialPurchaseRecord> purchases;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    if (purchases.isEmpty) {
      return const _EmptyCard(
          message: 'No material purchase yet for this project.');
    }
    return Column(
      children: [
        for (final purchase in purchases)
          Card(
            child: ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(purchase.items.isEmpty
                  ? 'Material purchase'
                  : purchase.items.first.materialName),
              subtitle: Text(
                  'Total ${purchase.totalAmount.format()} • Pending ${purchase.pendingAmount.format()} • ${purchase.paymentStatus.value}'),
              trailing: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${purchase.items.length} item'),
                    IconButton(
                        tooltip: 'Delete purchase',
                        onPressed: () => onDelete(purchase.id),
                        icon: const Icon(Icons.delete_outline)),
                  ]),
            ),
          ),
      ],
    );
  }
}

class _MaterialItemControllers {
  _MaterialItemControllers(
      this.name, this.unit, this.quantity, this.rate, this.gst);
  factory _MaterialItemControllers.defaults() => _MaterialItemControllers(
      TextEditingController(text: 'Cement'),
      TextEditingController(text: 'bag'),
      TextEditingController(text: '10'),
      TextEditingController(text: '420'),
      TextEditingController(text: '18'));
  factory _MaterialItemControllers.empty() => _MaterialItemControllers(
      TextEditingController(),
      TextEditingController(text: 'piece'),
      TextEditingController(text: '1'),
      TextEditingController(),
      TextEditingController(text: '0'));
  final TextEditingController name;
  final TextEditingController unit;
  final TextEditingController quantity;
  final TextEditingController rate;
  final TextEditingController gst;
  MaterialPurchaseItemDraft toDraft() => MaterialPurchaseItemDraft(
      materialName: name.text,
      unit: unit.text,
      quantity: DecimalQuantity.parse(quantity.text),
      rate: Money.parseRupees(rate.text),
      gstRateBasisPoints: int.parse(gst.text.trim()) * 100);
  void dispose() {
    name.dispose();
    unit.dispose();
    quantity.dispose();
    rate.dispose();
    gst.dispose();
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
            .copyWith(labelText: label),
      ),
    );
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

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(padding: const EdgeInsets.all(20), child: Text(message)));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(padding: const EdgeInsets.all(20), child: Text(message)));
}
