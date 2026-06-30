import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_module.dart';
import '../../core/permissions/permission_key.dart';
import '../../features/auth/data/auth_providers.dart';
import '../../features/billing/presentation/billing_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/fuel/presentation/fuel_page.dart';
import '../../features/labor/presentation/labor_page.dart';
import '../../features/machinery/presentation/machinery_page.dart';
import '../../features/material/presentation/material_page.dart' as material_ui;
import '../../features/project/presentation/project_page.dart';
import '../../features/reports/presentation/reports_page.dart';
import '../../features/staff/presentation/staff_page.dart';
import '../../features/tender/presentation/tender_page.dart';
import '../../features/work/presentation/work_page.dart';
import '../../shared/responsive/responsive_breakpoints.dart';
import 'module_placeholder_page.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  AppModule _selectedModule = AppModule.dashboard;

  @override
  Widget build(BuildContext context) {
    final permissionState = ref.watch(permissionServiceProvider);
    final service = permissionState.valueOrNull;
    final modules = AppModule.values.where((module) {
      if (module == AppModule.staff) {
        return service?.can(PermissionKey.staffManagement) ?? false;
      }
      if (module == AppModule.settings) {
        return service?.can(PermissionKey.settingsManage) ?? false;
      }
      return true;
    }).toList(growable: false);
    if (!modules.contains(_selectedModule)) {
      _selectedModule = AppModule.dashboard;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop =
            constraints.maxWidth >= ResponsiveBreakpoints.desktopNavigationMin;
        final content = _buildContent(_selectedModule);
        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                _DesktopSidebar(
                  modules: modules,
                  selectedModule: _selectedModule,
                  onSelected: _selectModule,
                  onRefresh: _refreshAccess,
                  onSignOut: _signOut,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(_selectedModule.title),
            actions: [
              IconButton(
                tooltip: 'Refresh access',
                onPressed: _refreshAccess,
                icon: const Icon(Icons.cloud_sync_outlined),
              ),
              IconButton(
                tooltip: 'Sign out',
                onPressed: _signOut,
                icon: const Icon(Icons.logout_outlined),
              ),
            ],
          ),
          drawer: _MobileDrawer(
            modules: modules,
            selectedModule: _selectedModule,
            onSelected: (module) {
              Navigator.of(context).pop();
              _selectModule(module);
            },
          ),
          body: content,
        );
      },
    );
  }

  Widget _buildContent(AppModule module) {
    final service = ref.watch(permissionServiceProvider).valueOrNull;
    if (module == AppModule.tender &&
        !(service?.can(PermissionKey.tenderCreate) == true ||
            service?.can(PermissionKey.tenderEdit) == true ||
            service?.can(PermissionKey.tenderDelete) == true)) {
      return const _ModuleLocked(permission: PermissionKey.tenderCreate);
    }
    if (module == AppModule.project &&
        !(service?.can(PermissionKey.projectCreate) == true ||
            service?.can(PermissionKey.projectEdit) == true ||
            service?.can(PermissionKey.viewOnlyProjectAccess) == true)) {
      return const _ModuleLocked(permission: PermissionKey.projectEdit);
    }
    if (module == AppModule.work &&
        !(service?.can(PermissionKey.projectEdit) == true ||
            service?.can(PermissionKey.materialEntry) == true ||
            service?.can(PermissionKey.laborEntry) == true ||
            service?.can(PermissionKey.machineryEntry) == true)) {
      return const _ModuleLocked(permission: PermissionKey.projectEdit);
    }
    final required = switch (module) {
      AppModule.material => PermissionKey.materialEntry,
      AppModule.labor => PermissionKey.laborEntry,
      AppModule.machinery || AppModule.fuel => PermissionKey.machineryEntry,
      AppModule.billing => PermissionKey.billingEntry,
      AppModule.reports => PermissionKey.gstReports,
      AppModule.staff => PermissionKey.staffManagement,
      AppModule.settings => PermissionKey.settingsManage,
      _ => null,
    };
    if (required != null && !(service?.can(required) ?? false)) {
      return _ModuleLocked(permission: required);
    }
    return switch (module) {
      AppModule.dashboard => const DashboardPage(),
      AppModule.tender => const TenderPage(),
      AppModule.project => const ProjectPage(),
      AppModule.work => const WorkPage(),
      AppModule.material => const material_ui.MaterialPage(),
      AppModule.labor => const LaborPage(),
      AppModule.machinery => const MachineryPage(),
      AppModule.fuel => const FuelPage(),
      AppModule.billing => const BillingPage(),
      AppModule.reports => const ReportsPage(),
      AppModule.staff => const StaffPage(),
      _ => ModulePlaceholderPage(module: module),
    };
  }

  Future<void> _signOut() async {
    await ref.read(authRepositoryProvider).signOut();
  }

  Future<void> _refreshAccess() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    ref.invalidate(userAccessPolicyProvider(user));
    ref.invalidate(permissionServiceProvider);
    try {
      await ref.read(userAccessPolicyProvider(user).future);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff access refreshed')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Using saved offline access: $error')),
        );
      }
    }
  }

  void _selectModule(AppModule module) {
    if (_selectedModule == module) {
      return;
    }
    setState(() => _selectedModule = module);
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.modules,
    required this.selectedModule,
    required this.onSelected,
    required this.onRefresh,
    required this.onSignOut,
  });

  final List<AppModule> modules;
  final AppModule selectedModule;
  final ValueChanged<AppModule> onSelected;
  final VoidCallback onRefresh;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 248,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.apartment,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Construction ERP',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text('Local-first Phase 6',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
                itemCount: modules.length,
                itemBuilder: (context, index) {
                  final module = modules[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: NavigationItem(
                      module: module,
                      selected: selectedModule == module,
                      onTap: () => onSelected(module),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.cloud_sync_outlined),
              title: const Text('Refresh access'),
              onTap: onRefresh,
            ),
            ListTile(
              leading: const Icon(Icons.logout_outlined),
              title: const Text('Sign out'),
              onTap: onSignOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileDrawer extends StatelessWidget {
  const _MobileDrawer({
    required this.modules,
    required this.selectedModule,
    required this.onSelected,
  });

  final List<AppModule> modules;
  final AppModule selectedModule;
  final ValueChanged<AppModule> onSelected;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const ListTile(
              leading: CircleAvatar(child: Icon(Icons.apartment)),
              title: Text('Construction ERP'),
              subtitle: Text('Android + Windows'),
            ),
            const Divider(),
            for (final module in modules)
              ListTile(
                leading: Icon(module.icon),
                title: Text(module.title),
                selected: selectedModule == module,
                onTap: () => onSelected(module),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModuleLocked extends StatelessWidget {
  const _ModuleLocked({required this.permission});

  final PermissionKey permission;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: 12),
            Text('Access not allowed',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Your role does not include ${permission.storageKey}. Ask the owner or admin to update access.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class NavigationItem extends StatelessWidget {
  const NavigationItem({
    required this.module,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final AppModule module;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                module.icon,
                color: selected
                    ? colors.onPrimaryContainer
                    : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  module.title,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                        selected ? colors.onPrimaryContainer : colors.onSurface,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
