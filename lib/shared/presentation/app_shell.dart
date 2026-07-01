import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_module.dart';
import '../../core/permissions/permission_key.dart';
import '../../core/providers/app_providers.dart';
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
import '../../features/settings/presentation/settings_page.dart';
import '../../features/tender/presentation/tender_page.dart';
import '../../features/work/presentation/work_page.dart';
import '../../shared/responsive/responsive_breakpoints.dart';
import '../../sync/data/sync_providers.dart';
import '../../sync/domain/sync_models.dart';
import '../../sync/services/auto_sync_controller.dart';
import 'app_feedback.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  AppModule _selectedModule = AppModule.dashboard;
  String? _configuredSyncKey;
  AutoSyncController? _autoSyncController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_autoSyncController?.stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _autoSyncController;
    if (controller == null) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(controller.resume());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(controller.pause());
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissionState = ref.watch(permissionServiceProvider);
    final service = permissionState.valueOrNull;
    final firebaseReady = ref.watch(firebaseBootstrapProvider).isReady;
    final user =
        firebaseReady ? ref.watch(authRepositoryProvider).currentUser : null;
    final writeContext = ref.watch(localWriteContextProvider);
    final autoSync = ref.watch(autoSyncControllerProvider);
    _autoSyncController = autoSync;
    final syncContext = firebaseReady && user != null && service != null
        ? SyncContext(
            companyId: writeContext.companyId,
            userId: writeContext.userId,
            staffId: service.policy.staff.id,
            deviceId: writeContext.deviceId,
          )
        : null;
    _scheduleAutoSync(syncContext);
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
                  autoSync: autoSync,
                  onSelected: _selectModule,
                  onRefresh: _refreshAccess,
                  onSync: () => context.push('/sync'),
                  onSwitchCompany: () => context.push('/company/switcher'),
                  onSwitchProject: () => context.push('/project/switcher'),
                  onCompanySettings: () => context.push('/company/settings'),
                  onAccountSettings: () => context.push('/account/settings'),
                  onSignOut: _signOut,
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: content,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            title: Text(_selectedModule.title),
            actions: [
              IconButton(
                tooltip: autoSync.message,
                onPressed: () => context.push('/sync'),
                icon: autoSync.phase == AutoSyncPhase.checking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_autoSyncIcon(autoSync.phase)),
              ),
            ],
          ),
          drawer: _MobileDrawer(
            modules: modules,
            selectedModule: _selectedModule,
            autoSync: autoSync,
            onSelected: (module) {
              Navigator.of(context).pop();
              _selectModule(module);
            },
            onSync: () {
              Navigator.of(context).pop();
              context.push('/sync');
            },
            onSwitchCompany: () {
              Navigator.of(context).pop();
              context.push('/company/switcher');
            },
            onSwitchProject: () {
              Navigator.of(context).pop();
              context.push('/project/switcher');
            },
            onCompanySettings: () {
              Navigator.of(context).pop();
              context.push('/company/settings');
            },
            onAccountSettings: () {
              Navigator.of(context).pop();
              context.push('/account/settings');
            },
            onRefresh: () {
              Navigator.of(context).pop();
              _refreshAccess();
            },
            onSignOut: () {
              Navigator.of(context).pop();
              _signOut();
            },
          ),
          body: content,
          bottomNavigationBar: _MobileNavigationBar(
            modules: modules,
            selectedModule: _selectedModule,
            onSelected: _selectModule,
            onMore: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        );
      },
    );
  }

  void _scheduleAutoSync(SyncContext? context) {
    final key = context == null
        ? null
        : '${context.companyId}|${context.userId}|${context.staffId}|${context.deviceId}';
    if (_configuredSyncKey == key) return;
    _configuredSyncKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(autoSyncControllerProvider);
      if (context == null) {
        unawaited(controller.stop());
      } else {
        unawaited(controller.start(context));
      }
    });
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
      AppModule.settings => const SettingsPage(),
    };
  }

  Future<void> _signOut() async {
    await ref.read(authRepositoryProvider).signOut();
  }

  Future<void> _refreshAccess() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    ref.invalidate(userCompanyMembershipsProvider(user));
    ref.invalidate(activeWorkspaceProvider(user));
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
          SnackBar(
              content: Text(friendlyErrorMessage(error,
                  fallback: 'Using your last saved access while offline.'))),
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
    required this.autoSync,
    required this.onSelected,
    required this.onRefresh,
    required this.onSync,
    required this.onSwitchCompany,
    required this.onSwitchProject,
    required this.onCompanySettings,
    required this.onAccountSettings,
    required this.onSignOut,
  });

  final List<AppModule> modules;
  final AppModule selectedModule;
  final AutoSyncController autoSync;
  final ValueChanged<AppModule> onSelected;
  final VoidCallback onRefresh;
  final VoidCallback onSync;
  final VoidCallback onSwitchCompany;
  final VoidCallback onSwitchProject;
  final VoidCallback onCompanySettings;
  final VoidCallback onAccountSettings;
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
                        Text('Projects, costs and billing',
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
            _AutoSyncMenuItem(controller: autoSync, onTap: onSync),
            _ShellMenuItem(
                icon: Icons.swap_horiz_outlined,
                title: 'Switch company',
                onTap: onSwitchCompany),
            _ShellMenuItem(
                icon: Icons.filter_alt_outlined,
                title: 'Select project',
                onTap: onSwitchProject),
            _ShellMenuItem(
                icon: Icons.business_outlined,
                title: 'Company settings',
                onTap: onCompanySettings),
            _ShellMenuItem(
                icon: Icons.account_circle_outlined,
                title: 'Account settings',
                onTap: onAccountSettings),
            _ShellMenuItem(
                icon: Icons.cloud_sync_outlined,
                title: 'Refresh access',
                onTap: onRefresh),
            _ShellMenuItem(
                icon: Icons.logout_outlined,
                title: 'Sign out',
                onTap: onSignOut),
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
    required this.autoSync,
    required this.onSelected,
    required this.onSync,
    required this.onSwitchCompany,
    required this.onSwitchProject,
    required this.onCompanySettings,
    required this.onAccountSettings,
    required this.onRefresh,
    required this.onSignOut,
  });

  final List<AppModule> modules;
  final AppModule selectedModule;
  final AutoSyncController autoSync;
  final ValueChanged<AppModule> onSelected;
  final VoidCallback onSync;
  final VoidCallback onSwitchCompany;
  final VoidCallback onSwitchProject;
  final VoidCallback onCompanySettings;
  final VoidCallback onAccountSettings;
  final VoidCallback onRefresh;
  final VoidCallback onSignOut;

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
            const Divider(),
            _AutoSyncMenuItem(controller: autoSync, onTap: onSync),
            _ShellMenuItem(
                icon: Icons.swap_horiz_outlined,
                title: 'Switch company',
                onTap: onSwitchCompany),
            _ShellMenuItem(
                icon: Icons.filter_alt_outlined,
                title: 'Select project',
                onTap: onSwitchProject),
            _ShellMenuItem(
                icon: Icons.business_outlined,
                title: 'Company settings',
                onTap: onCompanySettings),
            _ShellMenuItem(
                icon: Icons.account_circle_outlined,
                title: 'Account settings',
                onTap: onAccountSettings),
            _ShellMenuItem(
                icon: Icons.cloud_sync_outlined,
                title: 'Refresh access',
                onTap: onRefresh),
            _ShellMenuItem(
                icon: Icons.logout_outlined,
                title: 'Sign out',
                onTap: onSignOut),
          ],
        ),
      ),
    );
  }
}

class _ShellMenuItem extends StatelessWidget {
  const _ShellMenuItem(
      {required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }
}

class _AutoSyncMenuItem extends StatelessWidget {
  const _AutoSyncMenuItem({required this.controller, required this.onTap});

  final AutoSyncController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: controller.phase == AutoSyncPhase.checking
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(_autoSyncIcon(controller.phase)),
      title: Text(_autoSyncLabel(controller.phase)),
      onTap: onTap,
    );
  }
}

IconData _autoSyncIcon(AutoSyncPhase phase) => switch (phase) {
      AutoSyncPhase.checking => Icons.sync,
      AutoSyncPhase.upToDate => Icons.cloud_done_outlined,
      AutoSyncPhase.offline => Icons.cloud_off_outlined,
      AutoSyncPhase.attention => Icons.sync_problem_outlined,
      AutoSyncPhase.stopped => Icons.sync_disabled_outlined,
    };

String _autoSyncLabel(AutoSyncPhase phase) => switch (phase) {
      AutoSyncPhase.checking => 'Updating company data',
      AutoSyncPhase.upToDate => 'Company data up to date',
      AutoSyncPhase.offline => 'Offline — retrying',
      AutoSyncPhase.attention => 'Update needs attention',
      AutoSyncPhase.stopped => 'Automatic update paused',
    };

class _MobileNavigationBar extends StatelessWidget {
  const _MobileNavigationBar({
    required this.modules,
    required this.selectedModule,
    required this.onSelected,
    required this.onMore,
  });

  final List<AppModule> modules;
  final AppModule selectedModule;
  final ValueChanged<AppModule> onSelected;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    const preferred = <AppModule>[
      AppModule.dashboard,
      AppModule.tender,
      AppModule.project,
      AppModule.work,
    ];
    final primary = preferred.where(modules.contains).toList(growable: false);
    final selected = primary.indexOf(selectedModule);
    return NavigationBar(
      selectedIndex: selected < 0 ? primary.length : selected,
      onDestinationSelected: (index) {
        if (index == primary.length) {
          onMore();
        } else {
          onSelected(primary[index]);
        }
      },
      destinations: [
        for (final module in primary)
          NavigationDestination(
            icon: Icon(module.icon),
            selectedIcon: Icon(module.icon),
            label: module.title,
          ),
        const NavigationDestination(
          icon: Icon(Icons.menu),
          selectedIcon: Icon(Icons.menu_open),
          label: 'More',
        ),
      ],
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
              'Your role does not include access to this area. Ask the owner or admin to update it.',
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
