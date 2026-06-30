import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/permissions/permission_key.dart';
import '../../../core/permissions/role_type.dart';
import '../../../core/permissions/staff_status.dart';
import '../../../core/providers/app_providers.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/default_role_permissions.dart';
import '../domain/staff_access_policy.dart';
import '../domain/staff_profile.dart';

final _staffListProvider = FutureProvider.family<List<StaffProfile>, String>(
  (ref, companyId) {
    return ref
        .watch(staffRepositoryProvider)
        .listLocalStaff(companyId: companyId);
  },
);

class StaffPage extends ConsumerWidget {
  const StaffPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessState = ref.watch(permissionServiceProvider);
    return accessState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _StaffMessage(
        icon: Icons.error_outline,
        title: 'Staff access error',
        message: '$error',
      ),
      data: (service) {
        final policy = service?.policy;
        if (policy == null) {
          return const _StaffMessage(
            icon: Icons.person_off_outlined,
            title: 'Login required',
            message: 'Login with owner/admin account to manage staff.',
          );
        }
        if (!policy.can(PermissionKey.staffManagement)) {
          return const _StaffMessage(
            icon: Icons.lock_outline,
            title: 'Staff management locked',
            message:
                'Only Owner/Admin or users with staff.manage permission can open this page.',
          );
        }
        final staffList = ref.watch(_staffListProvider(policy.staff.companyId));
        return staffList.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _StaffMessage(
            icon: Icons.error_outline,
            title: 'Cannot load staff',
            message: '$error',
          ),
          data: (items) => _StaffContent(policy: policy, staff: items),
        );
      },
    );
  }
}

class _StaffContent extends ConsumerWidget {
  const _StaffContent({required this.policy, required this.staff});

  final StaffAccessPolicy policy;
  final List<StaffProfile> staff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Staff management',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Invite staff, assign roles and keep local access safe.',
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: () => _showInviteDialog(context, ref),
                      icon: const Icon(Icons.person_add_alt_outlined),
                      label: const Text('Add staff'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/roles'),
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text('Roles & permissions'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 780) {
                    return _StaffTable(policy: policy, staff: staff);
                  }
                  return _StaffCardList(policy: policy, staff: staff);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showInviteDialog(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _InviteStaffDialog(policy: policy),
    );
    ref.invalidate(_staffListProvider(policy.staff.companyId));
  }
}

class _StaffTable extends StatelessWidget {
  const _StaffTable({required this.policy, required this.staff});

  final StaffAccessPolicy policy;
  final List<StaffProfile> staff;

  @override
  Widget build(BuildContext context) {
    if (staff.isEmpty) {
      return const _StaffMessage(
        icon: Icons.groups_2_outlined,
        title: 'No staff yet',
        message:
            'Use Add staff to invite accountants, supervisors and data entry users.',
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Email')),
          DataColumn(label: Text('Role')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Firebase UID')),
          DataColumn(label: Text('Actions')),
        ],
        rows: [
          for (final item in staff)
            DataRow(
              cells: [
                DataCell(Text(item.name)),
                DataCell(Text(item.email ?? '-')),
                DataCell(Text(item.roleId ?? '-')),
                DataCell(_StatusChip(status: item.status)),
                DataCell(Text(item.firebaseUid ?? 'Pending invite')),
                DataCell(_StaffActions(policy: policy, staff: item)),
              ],
            ),
        ],
      ),
    );
  }
}

class _StaffCardList extends StatelessWidget {
  const _StaffCardList({required this.policy, required this.staff});

  final StaffAccessPolicy policy;
  final List<StaffProfile> staff;

  @override
  Widget build(BuildContext context) {
    if (staff.isEmpty) {
      return const _StaffMessage(
        icon: Icons.groups_2_outlined,
        title: 'No staff yet',
        message:
            'Use Add staff to invite accountants, supervisors and data entry users.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: staff.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = staff[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(item.name),
            subtitle: Text(
                '${item.email ?? 'No email'} • ${item.roleId ?? 'No role'}'),
            trailing: SizedBox(
              width: 110,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(child: _StatusChip(status: item.status)),
                  _StaffActions(policy: policy, staff: item),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _StaffAction {
  editDetails,
  changeRole,
  assignProjects,
  activate,
  deactivate,
  revoke,
}

class _StaffActions extends ConsumerWidget {
  const _StaffActions({required this.policy, required this.staff});

  final StaffAccessPolicy policy;
  final StaffProfile staff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_StaffAction>(
      tooltip: 'Edit staff',
      onSelected: (action) => _run(context, ref, action),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _StaffAction.editDetails,
          child: Text('Edit details'),
        ),
        const PopupMenuItem(
          value: _StaffAction.changeRole,
          child: Text('Change role'),
        ),
        const PopupMenuItem(
          value: _StaffAction.assignProjects,
          child: Text('Assign projects'),
        ),
        if (staff.status != StaffStatus.active)
          const PopupMenuItem(
            value: _StaffAction.activate,
            child: Text('Activate'),
          ),
        if (staff.status != StaffStatus.inactive)
          const PopupMenuItem(
            value: _StaffAction.deactivate,
            child: Text('Set inactive'),
          ),
        if (staff.status != StaffStatus.revoked)
          const PopupMenuItem(
            value: _StaffAction.revoke,
            child: Text('Revoke access'),
          ),
      ],
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    _StaffAction action,
  ) async {
    try {
      switch (action) {
        case _StaffAction.editDetails:
          await _editDetails(context, ref);
        case _StaffAction.changeRole:
          await _changeRole(context, ref);
        case _StaffAction.assignProjects:
          await _assignProjects(context, ref);
        case _StaffAction.activate:
          await _changeStatus(ref, StaffStatus.active);
        case _StaffAction.deactivate:
          await _changeStatus(ref, StaffStatus.inactive);
        case _StaffAction.revoke:
          await _changeStatus(ref, StaffStatus.revoked);
      }
      ref.invalidate(_staffListProvider(policy.staff.companyId));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    }
  }

  Future<void> _changeStatus(WidgetRef ref, StaffStatus status) {
    return ref.read(staffRepositoryProvider).changeStaffStatus(
          actorPolicy: policy,
          staffId: staff.id,
          status: status,
        );
  }

  Future<void> _editDetails(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController(text: staff.name);
    final email = TextEditingController(text: staff.email);
    final phone = TextEditingController(text: staff.phone);
    final formKey = GlobalKey<FormState>();
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit staff details'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Name required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) => value != null && value.contains('@')
                      ? null
                      : 'Valid email required',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (save == true) {
      await ref.read(staffRepositoryProvider).updateStaffDetails(
            actorPolicy: policy,
            staffId: staff.id,
            name: name.text,
            email: email.text,
            phone: phone.text,
          );
    }
    name.dispose();
    email.dispose();
    phone.dispose();
  }

  Future<void> _changeRole(BuildContext context, WidgetRef ref) async {
    var selected = staff.roleType ?? RoleType.viewer;
    final role = await showDialog<RoleType>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Change role for ${staff.name}'),
          content: DropdownButtonFormField<RoleType>(
            initialValue: selected,
            items: [
              for (final role in DefaultRolePermissions.orderedRoles
                  .where((role) => role != RoleType.owner))
                DropdownMenuItem(
                  value: role,
                  child: Text(DefaultRolePermissions.roleName(role)),
                ),
            ],
            onChanged: (value) => setState(() => selected = value ?? selected),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (role != null) {
      await ref.read(staffRepositoryProvider).updateStaffRole(
            actorPolicy: policy,
            staffId: staff.id,
            role: role,
          );
    }
  }

  Future<void> _assignProjects(BuildContext context, WidgetRef ref) async {
    final projects = await ref
        .read(projectRepositoryProvider)
        .listProjects(policy.staff.companyId);
    final selected =
        await ref.read(staffRepositoryProvider).listAssignedProjectIds(
              companyId: policy.staff.companyId,
              staffId: staff.id,
            );
    if (!context.mounted) return;
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Projects for ${staff.name}'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 460),
            child: projects.isEmpty
                ? const Text('Create a project before assigning staff.')
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final project in projects)
                        CheckboxListTile(
                          value: selected.contains(project.id),
                          title: Text(project.projectName),
                          onChanged: (checked) => setState(() {
                            if (checked == true) {
                              selected.add(project.id);
                            } else {
                              selected.remove(project.id);
                            }
                          }),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, Set<String>.from(selected)),
              child: const Text('Save assignments'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      await ref.read(staffRepositoryProvider).assignProjects(
            actorPolicy: policy,
            staffId: staff.id,
            projectIds: result.toList(growable: false),
          );
    }
  }
}

class _InviteStaffDialog extends ConsumerStatefulWidget {
  const _InviteStaffDialog({required this.policy});

  final StaffAccessPolicy policy;

  @override
  ConsumerState<_InviteStaffDialog> createState() => _InviteStaffDialogState();
}

class _InviteStaffDialogState extends ConsumerState<_InviteStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  RoleType _role = RoleType.siteSupervisor;
  bool _isLoading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add staff invite'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Staff name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Name required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) => value != null && value.contains('@')
                      ? null
                      : 'Valid email required',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'Phone optional'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RoleType>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: [
                    for (final role in DefaultRolePermissions.orderedRoles
                        .where((role) => role != RoleType.owner))
                      DropdownMenuItem(
                        value: role,
                        child: Text(DefaultRolePermissions.roleName(role)),
                      ),
                  ],
                  onChanged: (value) => setState(() => _role = value ?? _role),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                if (_success != null) ...[
                  const SizedBox(height: 12),
                  SelectableText(
                    _success!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(_success == null ? 'Cancel' : 'Close'),
        ),
        FilledButton(
          onPressed: _isLoading || _success != null ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send invite'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final invitation = await ref.read(staffRepositoryProvider).inviteStaff(
            actorPolicy: widget.policy,
            name: _nameController.text,
            email: _emailController.text,
            phone: _phoneController.text,
            role: _role,
          );
      if (mounted) {
        setState(() {
          _success = 'Invite created. Company ID: ${invitation.companyId}\n'
              'Invite code: ${invitation.inviteCode}';
        });
      }
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final StaffStatus status;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(status.storageKey));
  }
}

class _StaffMessage extends StatelessWidget {
  const _StaffMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
