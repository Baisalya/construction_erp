import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/value_objects/money.dart';
import '../domain/agreement_deduction.dart';
import '../domain/agreement_deduction_type.dart';
import '../domain/project_agreement_summary.dart';
import '../domain/project_agreement_update.dart';
import '../domain/project_milestone.dart';
import '../domain/project_milestone_status.dart';
import '../domain/project_record.dart';
import '../domain/project_status.dart';

final projectStatsProvider = FutureProvider<ProjectDashboardStats>((ref) async {
  final context = ref.watch(localWriteContextProvider);
  final repository = ref.watch(projectRepositoryProvider);
  return repository.loadStats(context.companyId);
});

final projectListProvider = FutureProvider<List<ProjectRecord>>((ref) async {
  final context = ref.watch(localWriteContextProvider);
  final repository = ref.watch(projectRepositoryProvider);
  return repository.listProjects(context.companyId);
});

class ProjectPage extends ConsumerWidget {
  const ProjectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(projectStatsProvider);
    final projects = ref.watch(projectListProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _ProjectHeader(),
          const SizedBox(height: 14),
          stats.when(
            data: (data) => _ProjectStatsCards(stats: data),
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) =>
                _InlineError(message: error.toString()),
          ),
          const SizedBox(height: 14),
          projects.when(
            data: (data) => _ProjectForms(projects: data),
            loading: () => const Card(
                child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('Loading projects...'))),
            error: (error, stackTrace) =>
                _InlineError(message: error.toString()),
          ),
          const SizedBox(height: 14),
          projects.when(
            data: (data) => _ProjectList(projects: data),
            loading: () => const Card(
                child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('Loading project list...'))),
            error: (error, stackTrace) =>
                _InlineError(message: error.toString()),
          ),
        ],
      ),
    );
  }
}

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader();

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
                  Text('Project Agreement Calculator',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text(
                      'Create projects, set agreement value, subtract security deposit and non-recoverable deductions, and track milestones before work cost modules begin.'),
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

class _ProjectStatsCards extends StatelessWidget {
  const _ProjectStatsCards({required this.stats});

  final ProjectDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _SmallStat(
          label: 'Total projects', value: stats.totalProjects.toString()),
      _SmallStat(label: 'Running', value: stats.runningProjects.toString()),
      _SmallStat(label: 'Planned', value: stats.plannedProjects.toString()),
      _SmallStat(label: 'Completed', value: stats.completedProjects.toString()),
      _SmallStat(
          label: 'Gross agreement',
          value: stats.totalAgreementGrossValue.format()),
      _SmallStat(
          label: 'Final agreement',
          value: stats.totalAgreementFinalValue.format()),
      _SmallStat(
          label: 'Security deposit',
          value: stats.totalSecurityDeposit.format()),
      _SmallStat(
          label: 'Advance received',
          value: stats.totalAdvanceReceived.format()),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1100
            ? 4
            : width >= 760
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
          childAspectRatio: crossAxisCount == 1 ? 4.2 : 1.8,
          children: cards,
        );
      },
    );
  }
}

class _ProjectForms extends StatelessWidget {
  const _ProjectForms({required this.projects});

  final List<ProjectRecord> projects;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            _AddProjectTile(),
            const Divider(height: 1),
            _AgreementCalculatorTile(projects: projects),
            const Divider(height: 1),
            _AddMilestoneTile(projects: projects),
          ],
        ),
      ),
    );
  }
}

class _AddProjectTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AddProjectTile> createState() => _AddProjectTileState();
}

class _AddProjectTileState extends ConsumerState<_AddProjectTile> {
  final _formKey = GlobalKey<FormState>();
  final _projectName = TextEditingController();
  final _projectCode = TextEditingController();
  final _clientName = TextEditingController();
  final _siteLocation = TextEditingController();
  final _grossValue = TextEditingController();
  final _securityDeposit = TextEditingController();
  final _advanceReceived = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _projectName.dispose();
    _projectCode.dispose();
    _clientName.dispose();
    _siteLocation.dispose();
    _grossValue.dispose();
    _securityDeposit.dispose();
    _advanceReceived.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.add_business_outlined),
      title: const Text('Create project'),
      subtitle: const Text(
          'Manual project entry or later tender-converted project editing'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Form(
            key: _formKey,
            child: _ResponsiveFormGrid(
              children: [
                TextFormField(
                    controller: _projectName,
                    decoration:
                        const InputDecoration(labelText: 'Project name *'),
                    validator: _required),
                TextFormField(
                    controller: _projectCode,
                    decoration:
                        const InputDecoration(labelText: 'Project code')),
                TextFormField(
                    controller: _clientName,
                    decoration: const InputDecoration(
                        labelText: 'Client / department')),
                TextFormField(
                    controller: _siteLocation,
                    decoration:
                        const InputDecoration(labelText: 'Site location')),
                TextFormField(
                    controller: _grossValue,
                    decoration: const InputDecoration(
                        labelText: 'Agreement gross value ₹'),
                    keyboardType: TextInputType.number,
                    validator: _moneyRequired),
                TextFormField(
                    controller: _securityDeposit,
                    decoration:
                        const InputDecoration(labelText: 'Security deposit ₹'),
                    keyboardType: TextInputType.number),
                TextFormField(
                    controller: _advanceReceived,
                    decoration:
                        const InputDecoration(labelText: 'Advance received ₹'),
                    keyboardType: TextInputType.number),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveProject,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined),
                    label: const Text('Save project'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveProject() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    try {
      final repository = ref.read(projectRepositoryProvider);
      final writeContext = ref.read(localWriteContextProvider);
      await repository.createProject(
        ProjectDraft(
          projectName: _projectName.text,
          projectCode: _projectCode.text,
          clientName: _clientName.text,
          siteLocation: _siteLocation.text,
          agreementGrossValue: _parseMoney(_grossValue.text),
          approvedTenderAmount: _parseMoney(_grossValue.text),
          securityDepositAmount: _parseMoney(_securityDeposit.text),
          advanceReceived: _parseMoney(_advanceReceived.text),
          projectStatus: ProjectStatus.planned,
        ),
        writeContext,
      );
      _clearProjectForm();
      ref.invalidate(projectStatsProvider);
      ref.invalidate(projectListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project saved locally.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _clearProjectForm() {
    _projectName.clear();
    _projectCode.clear();
    _clientName.clear();
    _siteLocation.clear();
    _grossValue.clear();
    _securityDeposit.clear();
    _advanceReceived.clear();
  }
}

class _AgreementCalculatorTile extends ConsumerStatefulWidget {
  const _AgreementCalculatorTile({required this.projects});

  final List<ProjectRecord> projects;

  @override
  ConsumerState<_AgreementCalculatorTile> createState() =>
      _AgreementCalculatorTileState();
}

class _AgreementCalculatorTileState
    extends ConsumerState<_AgreementCalculatorTile> {
  final _grossValue = TextEditingController();
  final _securityDeposit = TextEditingController();
  final _deductionAmount = TextEditingController();
  final _deductionDescription = TextEditingController();
  AgreementDeductionType _deductionType = AgreementDeductionType.misc;
  String? _selectedProjectId;
  bool _recoverable = false;
  bool _saving = false;

  @override
  void didUpdateWidget(covariant _AgreementCalculatorTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedProjectId != null &&
        !widget.projects.any((project) => project.id == _selectedProjectId)) {
      _selectedProjectId = null;
    }
  }

  @override
  void dispose() {
    _grossValue.dispose();
    _securityDeposit.dispose();
    _deductionAmount.dispose();
    _deductionDescription.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedProject = _findProject(widget.projects, _selectedProjectId);
    return ExpansionTile(
      leading: const Icon(Icons.calculate_outlined),
      title: const Text('Agreement value calculator'),
      subtitle: const Text(
          'Gross value minus security deposit and non-recoverable deductions'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedProjectId,
                decoration: const InputDecoration(labelText: 'Select project'),
                items: [
                  for (final project in widget.projects)
                    DropdownMenuItem(
                        value: project.id,
                        child: Text(
                            '${project.displayCode} • ${project.projectName}',
                            overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (value) {
                  final project = _findProject(widget.projects, value);
                  setState(() {
                    _selectedProjectId = value;
                    _grossValue.text = project?.agreementGrossValue
                            .format(symbol: '')
                            .trim() ??
                        '';
                    _securityDeposit.text = project?.securityDepositAmount
                            .format(symbol: '')
                            .trim() ??
                        '';
                  });
                },
              ),
              const SizedBox(height: 12),
              if (selectedProject != null)
                _AgreementPreview(projectId: selectedProject.id),
              const SizedBox(height: 12),
              _ResponsiveFormGrid(
                children: [
                  TextFormField(
                      controller: _grossValue,
                      decoration: const InputDecoration(
                          labelText: 'Agreement gross value ₹'),
                      keyboardType: TextInputType.number),
                  TextFormField(
                      controller: _securityDeposit,
                      decoration: const InputDecoration(
                          labelText: 'Security deposit ₹'),
                      keyboardType: TextInputType.number),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _saving || _selectedProjectId == null
                          ? null
                          : _updateAgreement,
                      icon: const Icon(Icons.done_all_outlined),
                      label: const Text('Update agreement'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Add deduction',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              _ResponsiveFormGrid(
                children: [
                  DropdownButtonFormField<AgreementDeductionType>(
                    initialValue: _deductionType,
                    decoration:
                        const InputDecoration(labelText: 'Deduction type'),
                    items: [
                      for (final type in AgreementDeductionType.values)
                        DropdownMenuItem(value: type, child: Text(type.label)),
                    ],
                    onChanged: (value) => setState(() =>
                        _deductionType = value ?? AgreementDeductionType.misc),
                  ),
                  TextFormField(
                      controller: _deductionAmount,
                      decoration: const InputDecoration(labelText: 'Amount ₹'),
                      keyboardType: TextInputType.number),
                  TextFormField(
                      controller: _deductionDescription,
                      decoration:
                          const InputDecoration(labelText: 'Description')),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Recoverable later'),
                    subtitle: const Text(
                        'Recoverable amount will not reduce final agreement value'),
                    value: _recoverable,
                    onChanged: (value) => setState(() => _recoverable = value),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _saving || _selectedProjectId == null
                          ? null
                          : _addDeduction,
                      icon: const Icon(Icons.remove_circle_outline),
                      label: const Text('Add deduction'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _updateAgreement() async {
    final projectId = _selectedProjectId;
    if (projectId == null) return;
    setState(() => _saving = true);
    try {
      final repository = ref.read(projectRepositoryProvider);
      final writeContext = ref.read(localWriteContextProvider);
      await repository.updateAgreement(
        ProjectAgreementUpdateDraft(
          projectId: projectId,
          agreementGrossValue: _parseMoney(_grossValue.text),
          approvedTenderAmount: _parseMoney(_grossValue.text),
          securityDepositAmount: _parseMoney(_securityDeposit.text),
          projectStatus: ProjectStatus.running,
        ),
        writeContext,
      );
      ref.invalidate(projectStatsProvider);
      ref.invalidate(projectListProvider);
      ref.invalidate(_agreementSummaryProvider(projectId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agreement value recalculated.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _addDeduction() async {
    final projectId = _selectedProjectId;
    if (projectId == null) return;
    setState(() => _saving = true);
    try {
      final repository = ref.read(projectRepositoryProvider);
      final writeContext = ref.read(localWriteContextProvider);
      await repository.addAgreementDeduction(
        AgreementDeductionDraft(
          projectId: projectId,
          deductionDate: writeContext.timestamp,
          deductionType: _deductionType,
          amount: _parseMoney(_deductionAmount.text),
          isRecoverable: _recoverable,
          description: _deductionDescription.text,
        ),
        writeContext,
      );
      _deductionAmount.clear();
      _deductionDescription.clear();
      ref.invalidate(projectStatsProvider);
      ref.invalidate(projectListProvider);
      ref.invalidate(_agreementSummaryProvider(projectId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Deduction added and final value updated.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _AddMilestoneTile extends ConsumerStatefulWidget {
  const _AddMilestoneTile({required this.projects});

  final List<ProjectRecord> projects;

  @override
  ConsumerState<_AddMilestoneTile> createState() => _AddMilestoneTileState();
}

class _AddMilestoneTileState extends ConsumerState<_AddMilestoneTile> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _paymentAmount = TextEditingController();
  String? _selectedProjectId;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _paymentAmount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.flag_outlined),
      title: const Text('Add project milestone'),
      subtitle: const Text('Track planned work steps and linked payment value'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _ResponsiveFormGrid(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedProjectId,
                decoration: const InputDecoration(labelText: 'Project'),
                items: [
                  for (final project in widget.projects)
                    DropdownMenuItem(
                        value: project.id,
                        child: Text(
                            '${project.displayCode} • ${project.projectName}',
                            overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (value) =>
                    setState(() => _selectedProjectId = value),
              ),
              TextFormField(
                  controller: _title,
                  decoration:
                      const InputDecoration(labelText: 'Milestone title')),
              TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Description')),
              TextFormField(
                  controller: _paymentAmount,
                  decoration: const InputDecoration(
                      labelText: 'Linked payment amount ₹'),
                  keyboardType: TextInputType.number),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _saving || _selectedProjectId == null
                      ? null
                      : _saveMilestone,
                  icon: const Icon(Icons.save_alt_outlined),
                  label: const Text('Save milestone'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _saveMilestone() async {
    final projectId = _selectedProjectId;
    if (projectId == null || _title.text.trim().isEmpty) {
      return;
    }
    setState(() => _saving = true);
    try {
      final repository = ref.read(projectRepositoryProvider);
      final writeContext = ref.read(localWriteContextProvider);
      await repository.addMilestone(
        ProjectMilestoneDraft(
          projectId: projectId,
          title: _title.text,
          description: _description.text,
          status: ProjectMilestoneStatus.planned,
          paymentLinkedAmount: _parseMoney(_paymentAmount.text),
        ),
        writeContext,
      );
      _title.clear();
      _description.clear();
      _paymentAmount.clear();
      ref.invalidate(_agreementSummaryProvider(projectId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Milestone saved locally.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

final _agreementSummaryProvider =
    FutureProvider.family<ProjectAgreementSummary?, String>(
        (ref, projectId) async {
  final context = ref.watch(localWriteContextProvider);
  final repository = ref.watch(projectRepositoryProvider);
  return repository.loadAgreementSummary(context.companyId, projectId);
});

class _AgreementPreview extends ConsumerWidget {
  const _AgreementPreview({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(_agreementSummaryProvider(projectId));
    return summary.when(
      data: (data) => data == null
          ? const SizedBox.shrink()
          : _AgreementSummaryCard(summary: data),
      loading: () => const LinearProgressIndicator(),
      error: (error, stackTrace) => _InlineError(message: error.toString()),
    );
  }
}

class _AgreementSummaryCard extends StatelessWidget {
  const _AgreementSummaryCard({required this.summary});

  final ProjectAgreementSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(summary.project.projectName,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoChip(
                    label: 'Gross',
                    value: summary.calculation.grossValue.format()),
                _InfoChip(
                    label: 'Non-recoverable',
                    value:
                        summary.calculation.nonRecoverableDeductions.format()),
                _InfoChip(
                    label: 'Security deposit',
                    value:
                        summary.calculation.securityDepositDeduction.format()),
                _InfoChip(
                    label: 'Recoverable',
                    value: summary.calculation.recoverableDeductions.format()),
                _InfoChip(
                    label: 'Final agreement',
                    value: summary.calculation.finalValue.format()),
                _InfoChip(
                    label: 'Milestones',
                    value: summary.milestones.length.toString()),
              ],
            ),
            if (summary.deductions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Deductions',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              for (final deduction in summary.deductions.take(4))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      '${deduction.deductionType.label} • ${deduction.amount.format()}'),
                  subtitle: Text(deduction.isRecoverable
                      ? 'Recoverable later'
                      : 'Deducted from final value'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProjectList extends StatelessWidget {
  const _ProjectList({required this.projects});

  final List<ProjectRecord> projects;

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
              'No projects yet. Create one here or convert a selected tender from the Tender module.'),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        if (isWide) {
          return Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Code')),
                  DataColumn(label: Text('Project')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Gross')),
                  DataColumn(label: Text('Security')),
                  DataColumn(label: Text('Final value')),
                ],
                rows: [
                  for (final project in projects)
                    DataRow(
                      cells: [
                        DataCell(Text(project.displayCode)),
                        DataCell(Text(project.projectName)),
                        DataCell(Text(project.projectStatus.label)),
                        DataCell(Text(project.agreementGrossValue.format())),
                        DataCell(Text(project.securityDepositAmount.format())),
                        DataCell(Text(project.agreementFinalValue.format())),
                      ],
                    ),
                ],
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final project in projects)
              Card(
                child: ListTile(
                  title: Text(project.projectName),
                  subtitle: Text(
                      '${project.displayCode} • ${project.projectStatus.label}\nFinal: ${project.agreementFinalValue.format()}'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
          ],
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
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
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final child in children)
              SizedBox(
                width: isWide
                    ? (constraints.maxWidth - 24) / 3
                    : constraints.maxWidth,
                child: child,
              ),
          ],
        );
      },
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
        padding: const EdgeInsets.all(16),
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

String? _moneyRequired(String? value) {
  final required = _required(value);
  if (required != null) return required;
  try {
    _parseMoney(value ?? '');
  } catch (_) {
    return 'Enter valid amount';
  }
  return null;
}

Money _parseMoney(String value) {
  if (value.trim().isEmpty) {
    return Money.zero;
  }
  return Money.parseRupees(value);
}

ProjectRecord? _findProject(List<ProjectRecord> projects, String? projectId) {
  if (projectId == null) {
    return null;
  }
  for (final project in projects) {
    if (project.id == projectId) {
      return project;
    }
  }
  return null;
}
