import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:go_router/go_router.dart';

import '../../../database/database_providers.dart';
import '../../../shared/presentation/app_feedback.dart';
import '../data/auth_providers.dart';
import '../../staff/domain/staff_access_policy.dart';

class ProjectSwitcherScreen extends ConsumerStatefulWidget {
  const ProjectSwitcherScreen({super.key});

  @override
  ConsumerState<ProjectSwitcherScreen> createState() =>
      _ProjectSwitcherScreenState();
}

class _ProjectSwitcherScreenState extends ConsumerState<ProjectSwitcherScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    if (user == null) return const SizedBox.shrink();
    final workspace = ref.watch(activeWorkspaceProvider(user)).valueOrNull;
    final policy = ref.watch(userAccessPolicyProvider(user)).valueOrNull;
    final companyId = workspace?.activeCompanyId ?? policy?.staff.companyId;
    return Scaffold(
      appBar: AppBar(title: const Text('Select project')),
      body: companyId == null || policy == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<_ProjectOption>>(
              future: _loadProjects(companyId, policy),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text(friendlyErrorMessage(snapshot.error!)));
                }
                final projects = (snapshot.data ?? const <_ProjectOption>[])
                    .where((project) => project.matches(_query))
                    .toList(growable: false);
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search project name, code or client',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                    ),
                    const SizedBox(height: 12),
                    if (policy.canAccessAllProjects || policy.isOwnerOrAdmin)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.all_inbox_outlined),
                          title: const Text('All allowed projects'),
                          selected: workspace?.activeProjectId == null,
                          onTap: () => _selectProject(null, companyId),
                        ),
                      ),
                    for (final project in projects)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.folder_open_outlined),
                          title: Text(project.name),
                          subtitle: Text([
                            project.code,
                            project.client,
                            project.status
                          ]
                              .where((item) => item != null && item.isNotEmpty)
                              .join(' • ')),
                          selected: workspace?.activeProjectId == project.id,
                          onTap: () => _selectProject(project.id, companyId),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }

  Future<List<_ProjectOption>> _loadProjects(
      String companyId, StaffAccessPolicy policy) async {
    final db = ref.read(localDatabaseProvider);
    await db.ensureSchema();
    final allowed = policy.canAccessAllProjects || policy.isOwnerOrAdmin
        ? null
        : policy.assignedProjectIds;
    if (allowed != null && allowed.isEmpty) return const <_ProjectOption>[];
    final placeholders =
        allowed == null ? '' : List.filled(allowed.length, '?').join(', ');
    final rows = await db.customSelect(
      '''
      SELECT id, project_name, project_code, client_name, project_status
      FROM projects
      WHERE company_id = ? AND is_deleted = 0
      ${allowed == null ? '' : 'AND id IN ($placeholders)'}
      ORDER BY CASE project_status WHEN 'running' THEN 0 WHEN 'active' THEN 1 ELSE 2 END,
               project_name COLLATE NOCASE ASC;
      ''',
      variables: [
        Variable<String>(companyId),
        if (allowed != null)
          for (final id in allowed) Variable<String>(id),
      ],
    ).get();
    return rows
        .map((row) => _ProjectOption(
              id: row.read<String>('id'),
              name: row.read<String>('project_name'),
              code: row.readNullable<String>('project_code'),
              client: row.readNullable<String>('client_name'),
              status: row.readNullable<String>('project_status'),
            ))
        .toList(growable: false);
  }

  Future<void> _selectProject(String? projectId, String companyId) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    await ref.read(companyRepositoryProvider).setActiveProject(
          user: user,
          companyId: companyId,
          projectId: projectId,
        );
    ref.invalidate(activeWorkspaceProvider(user));
    ref.invalidate(permissionServiceProvider);
    if (mounted) context.go('/');
  }
}

class _ProjectOption {
  const _ProjectOption(
      {required this.id,
      required this.name,
      this.code,
      this.client,
      this.status});
  final String id;
  final String name;
  final String? code;
  final String? client;
  final String? status;

  bool matches(String query) {
    if (query.isEmpty) return true;
    return name.toLowerCase().contains(query) ||
        (code ?? '').toLowerCase().contains(query) ||
        (client ?? '').toLowerCase().contains(query);
  }
}
