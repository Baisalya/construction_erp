import 'permission_key.dart';
import '../../features/staff/domain/staff_access_policy.dart';

/// Synchronous guard used at the repository boundary. UI visibility is only a
/// convenience; every protected write must pass through this guard as well.
abstract interface class RepositoryWriteGuard {
  void require(PermissionKey permission, {String? projectId});

  bool canAccessProject(String projectId);
}

class AllowAllRepositoryWriteGuard implements RepositoryWriteGuard {
  const AllowAllRepositoryWriteGuard();

  @override
  void require(PermissionKey permission, {String? projectId}) {}

  @override
  bool canAccessProject(String projectId) => true;
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
}

class ProjectAccessDeniedException implements Exception {
  const ProjectAccessDeniedException(this.projectId);

  final String projectId;

  @override
  String toString() => 'Project access denied: $projectId';
}
