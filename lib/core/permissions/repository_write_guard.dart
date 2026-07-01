import 'permission_key.dart';
import '../../features/staff/domain/staff_access_policy.dart';

/// Synchronous guard used at the repository boundary. UI visibility is only a
/// convenience; every protected write must pass through this guard as well.
abstract interface class RepositoryWriteGuard {
  void require(PermissionKey permission, {String? projectId});

  bool canAccessProject(String projectId);

  bool get canAccessAllProjects;

  Set<String> get allowedProjectIds;
}

class AllowAllRepositoryWriteGuard implements RepositoryWriteGuard {
  const AllowAllRepositoryWriteGuard();

  @override
  void require(PermissionKey permission, {String? projectId}) {}

  @override
  bool canAccessProject(String projectId) => true;

  @override
  bool get canAccessAllProjects => true;

  @override
  Set<String> get allowedProjectIds => const <String>{};
}

class StaffPolicyWriteGuard implements RepositoryWriteGuard {
  const StaffPolicyWriteGuard(this.policy);

  final StaffAccessPolicy? policy;

  @override
  void require(PermissionKey permission, {String? projectId}) {
    final current = policy;
    if (current == null) {
      throw const StaffAccessBlockedException('no_active_access_cache');
    }
    current.requireActiveStaff();
    current.requirePermission(permission);
    if (projectId != null && !current.canAccessProject(projectId)) {
      throw ProjectAccessDeniedException(projectId);
    }
  }

  @override
  bool canAccessProject(String projectId) =>
      policy?.canAccessProject(projectId) ?? false;

  @override
  bool get canAccessAllProjects {
    final current = policy;
    return current != null &&
        current.isActive &&
        (current.isOwnerOrAdmin || current.canAccessAllProjects);
  }

  @override
  Set<String> get allowedProjectIds =>
      policy?.assignedProjectIds ?? const <String>{};
}

class ProjectAccessDeniedException implements Exception {
  const ProjectAccessDeniedException(this.projectId);

  final String projectId;

  @override
  String toString() => 'Project access denied: $projectId';
}

class ProjectReadScope {
  const ProjectReadScope(this.sql, this.projectIds);

  final String sql;
  final List<String> projectIds;
}

/// Builds the SQL fragment used by every project-level local read. This keeps
/// tenant data on disk while ensuring restricted staff never load rows from an
/// unassigned project into a feature repository.
ProjectReadScope projectReadScope(
  RepositoryWriteGuard guard, {
  String? projectId,
  String column = 'project_id',
}) {
  if (projectId != null) {
    return guard.canAccessProject(projectId)
        ? ProjectReadScope('AND $column = ?', <String>[projectId])
        : const ProjectReadScope('AND 1 = 0', <String>[]);
  }
  if (guard.canAccessAllProjects) {
    return const ProjectReadScope('', <String>[]);
  }
  final ids = guard.allowedProjectIds.toList(growable: false)..sort();
  if (ids.isEmpty) {
    return const ProjectReadScope('AND 1 = 0', <String>[]);
  }
  return ProjectReadScope(
    'AND $column IN (${List<String>.filled(ids.length, '?').join(', ')})',
    ids,
  );
}
