import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/presentation/app_feedback.dart';
import '../data/auth_providers.dart';
import '../domain/company_membership.dart';

class CompanySwitcherScreen extends ConsumerWidget {
  const CompanySwitcherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    if (user == null) return const SizedBox.shrink();
    final membershipsState = ref.watch(userCompanyMembershipsProvider(user));
    final workspaceState = ref.watch(activeWorkspaceProvider(user));
    return Scaffold(
      appBar: AppBar(title: const Text('Switch company')),
      body: membershipsState.when(
        data: (memberships) {
          final activeCompanyId = workspaceState.valueOrNull?.activeCompanyId;
          if (memberships.isEmpty) {
            return const Center(
              child: Text('You are not added to a company.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemBuilder: (context, index) {
              final membership = memberships[index];
              final selected = membership.companyId == activeCompanyId;
              return _CompanyTile(
                membership: membership,
                isActive: selected,
                onSwitch: () => _switchCompany(context, ref, membership),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemCount: memberships.length,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(friendlyErrorMessage(error))),
      ),
    );
  }

  Future<void> _switchCompany(
    BuildContext context,
    WidgetRef ref,
    CompanyMembership membership,
  ) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    try {
      await ref.read(companyRepositoryProvider).switchActiveCompany(
            user: user,
            companyId: membership.companyId,
          );
      ref.invalidate(userCompanyMembershipsProvider(user));
      ref.invalidate(activeWorkspaceProvider(user));
      ref.invalidate(userAccessPolicyProvider(user));
      ref.invalidate(permissionServiceProvider);
      if (context.mounted) context.go('/');
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(error))),
        );
      }
    }
  }
}

class _CompanyTile extends StatelessWidget {
  const _CompanyTile({
    required this.membership,
    required this.isActive,
    required this.onSwitch,
  });

  final CompanyMembership membership;
  final bool isActive;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(isActive ? Icons.check : Icons.apartment_outlined),
        ),
        title: Text(membership.companyName),
        subtitle: Text(
          '${membership.roleName ?? membership.roleId ?? 'Staff'} • '
          '${membership.isOwner ? 'Owner' : 'Member'} • '
          '${_statusLabel(membership.status)}'
          '${membership.lastAccessAt == null ? '' : '\nLast opened: ${_date(membership.lastAccessAt!)}'}',
        ),
        isThreeLine: membership.lastAccessAt != null,
        trailing: FilledButton(
          onPressed: isActive || !membership.isActive ? null : onSwitch,
          child: Text(
            isActive
                ? 'Active'
                : membership.isActive
                    ? 'Switch'
                    : 'Unavailable',
          ),
        ),
      ),
    );
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'active':
        return 'Active';
      case 'suspended':
      case 'inactive':
        return 'Temporarily unavailable';
      case 'revoked':
        return 'Access removed';
      default:
        return value;
    }
  }

  String _date(int milliseconds) {
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
