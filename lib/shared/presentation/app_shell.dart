import 'package:flutter/material.dart';

import '../../core/constants/app_module.dart';
import '../../features/billing/presentation/billing_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/fuel/presentation/fuel_page.dart';
import '../../features/labor/presentation/labor_page.dart';
import '../../features/machinery/presentation/machinery_page.dart';
import '../../features/material/presentation/material_page.dart' as material_ui;
import '../../features/project/presentation/project_page.dart';
import '../../features/reports/presentation/reports_page.dart';
import '../../features/tender/presentation/tender_page.dart';
import '../../features/work/presentation/work_page.dart';
import '../../shared/responsive/responsive_breakpoints.dart';
import 'module_placeholder_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppModule _selectedModule = AppModule.dashboard;

  @override
  Widget build(BuildContext context) {
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
                  selectedModule: _selectedModule,
                  onSelected: _selectModule,
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
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 16),
                child: Icon(Icons.cloud_queue_outlined),
              ),
            ],
          ),
          drawer: _MobileDrawer(
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
      _ => ModulePlaceholderPage(module: module),
    };
  }

  void _selectModule(AppModule module) {
    if (_selectedModule == module) {
      return;
    }
    setState(() => _selectedModule = module);
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar(
      {required this.selectedModule, required this.onSelected});

  final AppModule selectedModule;
  final ValueChanged<AppModule> onSelected;

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
                    child: Icon(Icons.apartment,
                        color: theme.colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Construction ERP',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        Text('Local-first Phase 5',
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
                itemCount: AppModule.values.length,
                itemBuilder: (context, index) {
                  final module = AppModule.values[index];
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
          ],
        ),
      ),
    );
  }
}

class _MobileDrawer extends StatelessWidget {
  const _MobileDrawer({required this.selectedModule, required this.onSelected});

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
            for (final module in AppModule.values)
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

class NavigationItem extends StatelessWidget {
  const NavigationItem(
      {required this.module,
      required this.selected,
      required this.onTap,
      super.key});

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
              Icon(module.icon,
                  color: selected
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant),
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
