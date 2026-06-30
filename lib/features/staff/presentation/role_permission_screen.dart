import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/permission_key.dart';
import '../../../core/permissions/role_type.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/default_role_permissions.dart';
import '../domain/staff_access_policy.dart';

class RolePermissionScreen extends ConsumerWidget {
  const RolePermissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(permissionServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Roles and permissions')),
      body: access.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Cannot load access: $error')),
        data: (service) {
          final policy = service?.policy;
          if (policy == null || !policy.can(PermissionKey.staffManagement)) {
            return const _LockedMessage();
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Changes are saved locally first and then written to Firebase role metadata. They apply to staff after permission refresh or next login.',
              ),
              const SizedBox(height: 16),
              for (final role in DefaultRolePermissions.orderedRoles)
                _EditableRoleCard(role: role, actorPolicy: policy),
            ],
          );
        },
      ),
    );
  }
}

class _EditableRoleCard extends ConsumerStatefulWidget {
  const _EditableRoleCard({required this.role, required this.actorPolicy});

  final RoleType role;
  final StaffAccessPolicy actorPolicy;

  @override
  ConsumerState<_EditableRoleCard> createState() => _EditableRoleCardState();
}

class _EditableRoleCardState extends ConsumerState<_EditableRoleCard> {
  Set<PermissionKey>? _permissions;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values =
          await ref.read(staffRepositoryProvider).readLocalRolePermissions(
                companyId: widget.actorPolicy.staff.companyId,
                role: widget.role,
              );
      if (mounted) {
        setState(() => _permissions = {
              for (final entry in values.entries)
                if (entry.value) entry.key,
            });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = _permissions;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(DefaultRolePermissions.roleName(widget.role)),
        subtitle: Text(DefaultRolePermissions.roleDescription(widget.role)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (permissions == null && _error == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else if (_error != null)
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error))
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final permission in PermissionKey.values)
                  FilterChip(
                    selected: permissions!.contains(permission),
                    onSelected: widget.role == RoleType.owner
                        ? null
                        : (selected) => setState(() {
                              if (selected) {
                                permissions.add(permission);
                              } else {
                                permissions.remove(permission);
                              }
                            }),
                    label: Text(permission.simpleLabel),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed:
                    _saving || widget.role == RoleType.owner ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Save permissions'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(staffRepositoryProvider).updateRolePermissions(
            actorPolicy: widget.actorPolicy,
            role: widget.role,
            permissions: Set<PermissionKey>.from(_permissions!),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Role permissions updated')),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _LockedMessage extends StatelessWidget {
  const _LockedMessage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('staff.manage permission is required.'),
      ),
    );
  }
}
