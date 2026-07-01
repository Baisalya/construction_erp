import '../../core/permissions/permission_key.dart';
import '../../core/permissions/staff_status.dart';
import '../../features/auth/data/local_staff_access_repository.dart';
import '../../features/staff/domain/staff_access_policy.dart';
import 'sync_delta.dart';
import 'sync_entity_registry.dart';
import 'sync_models.dart';

class SyncPermissionGuard {
  SyncPermissionGuard({required LocalStaffAccessRepository accessRepository})
      : _accessRepository = accessRepository;

  final LocalStaffAccessRepository _accessRepository;

  Future<SyncPermissionDecision> canRunCompanySync(SyncContext context) async {
    final policy = await _policy(context);
    if (policy == null) {
      return const SyncPermissionDecision.deny(
        'No saved staff access exists for this signed-in user.',
      );
    }
    if (policy.staff.companyId != context.companyId) {
      return const SyncPermissionDecision.deny(
        'The signed-in staff user does not belong to this company.',
      );
    }
    if (!policy.isActive) {
      return SyncPermissionDecision.deny(
        'This staff account is ${policy.staff.status.storageKey} and cannot sync.',
      );
    }
    return const SyncPermissionDecision.allow();
  }

  Future<SyncPermissionDecision> canSyncDelta(
    SyncContext context,
    SyncDelta delta, {
    SyncDirection direction = SyncDirection.upload,
  }) async {
    final companyDecision = await canRunCompanySync(context);
    if (!companyDecision.allowed) return companyDecision;
    if (delta.companyId != context.companyId) {
      return const SyncPermissionDecision.deny(
        'A delta from another company cannot be synced.',
      );
    }
    final policy = await _policy(context);
    if (policy == null) return companyDecision;
    if (policy.isOwnerOrAdmin) return const SyncPermissionDecision.allow();

    if (direction == SyncDirection.upload && _isViewer(policy)) {
      return const SyncPermissionDecision.deny(
        'Viewer accounts cannot upload changes.',
      );
    }

    PermissionKey required;
    try {
      required = _requiredPermission(delta);
    } on ArgumentError catch (error) {
      return SyncPermissionDecision.deny(error.message?.toString());
    }
    final mayReadAssignedProject = direction == SyncDirection.download &&
        policy.can(PermissionKey.viewOnlyProjectAccess);
    if (!policy.can(required) && !mayReadAssignedProject) {
      return SyncPermissionDecision.deny(
        'Permission ${required.storageKey} is required to sync ${delta.entityType}.',
      );
    }

    String? projectId;
    try {
      projectId = delta.projectId ??
          SyncEntityRegistry.projectIdFromPayload(
            delta.entityType,
            delta.payloadJson,
          );
    } on ArgumentError catch (error) {
      return SyncPermissionDecision.deny(error.message?.toString());
    }
    if (projectId != null && !policy.canAccessProject(projectId)) {
      return SyncPermissionDecision.deny(
        'This staff user is not assigned to project $projectId.',
      );
    }
    if (mayReadAssignedProject && projectId == null) {
      return const SyncPermissionDecision.deny(
        'Viewer access is limited to assigned project records.',
      );
    }
    return const SyncPermissionDecision.allow();
  }

  Future<SyncDownloadScope> downloadScope(SyncContext context) async {
    final decision = await canRunCompanySync(context);
    if (!decision.allowed) {
      throw StateError(decision.reason ?? 'Sync is not allowed.');
    }
    final policy = await _policy(context);
    if (policy == null) {
      throw StateError('No saved staff access exists for this user.');
    }
    if (policy.isOwnerOrAdmin || policy.canAccessAllProjects) {
      return const SyncDownloadScope(allCompanyData: true);
    }
    final entities = <String>{};
    for (final entity in SyncEntityRegistry.entityTypes) {
      final mayReadByEntityPermission =
          _readPermissions(entity).any((permission) => policy.can(permission));
      final mayReadAssigned = policy.can(PermissionKey.viewOnlyProjectAccess) &&
          SyncEntityRegistry.projectScopedEntityTypes.contains(entity);
      if (mayReadByEntityPermission || mayReadAssigned) entities.add(entity);
    }
    return SyncDownloadScope(
      allCompanyData: false,
      entityTypes: entities,
      projectIds: policy.assignedProjectIds,
    );
  }

  Future<StaffAccessPolicy?> _policy(SyncContext context) async {
    final policy = await _accessRepository.readCachedPolicyForUidAndCompany(
      firebaseUid: context.userId,
      companyId: context.companyId,
    );
    if (policy == null) return null;
    if (context.staffId != null && policy.staff.id != context.staffId) {
      return null;
    }
    return policy;
  }

  bool _isViewer(StaffAccessPolicy policy) =>
      policy.staff.roleId == 'viewer' ||
      (policy.allowedPermissions.length == 1 &&
          policy.can(PermissionKey.viewOnlyProjectAccess));

  PermissionKey _requiredPermission(SyncDelta delta) {
    final entity = SyncEntityRegistry.normalize(delta.entityType);
    if ({'bidder_profiles', 'tenders', 'tender_expenses', 'tender_documents'}
        .contains(entity)) {
      return switch (delta.operation) {
        SyncOperations.insert => PermissionKey.tenderCreate,
        SyncOperations.delete => PermissionKey.tenderDelete,
        _ => PermissionKey.tenderEdit,
      };
    }
    if (entity == 'projects') {
      return switch (delta.operation) {
        SyncOperations.insert => PermissionKey.projectCreate,
        SyncOperations.delete => PermissionKey.projectDelete,
        _ => PermissionKey.projectEdit,
      };
    }
    if ({
      'project_agreement_deductions',
      'project_milestones',
      'work_days',
      'project_expenses',
    }.contains(entity)) {
      return PermissionKey.projectEdit;
    }
    if ({
      'suppliers',
      'material_purchases',
      'material_purchase_items',
      'supplier_payments',
    }.contains(entity)) {
      return PermissionKey.materialEntry;
    }
    if ({
      'laborers',
      'labor_work_entries',
      'labor_payments',
      'labor_advances',
    }.contains(entity)) {
      return PermissionKey.laborEntry;
    }
    if ({
      'machines',
      'machine_usage_entries',
      'machine_rental_payments',
      'machine_repair_entries',
      'fuel_types',
      'fuel_entries',
    }.contains(entity)) {
      return PermissionKey.machineryEntry;
    }
    if ({
      'project_estimates',
      'project_estimate_items',
      'project_bills',
      'project_bill_receipts',
    }.contains(entity)) {
      return PermissionKey.billingEntry;
    }
    if (entity == 'gst_entries') return PermissionKey.gstReports;
    if ({'staff_users', 'roles', 'permissions', 'project_staff_assignments'}
        .contains(entity)) {
      return PermissionKey.staffManagement;
    }
    if (entity == 'companies') return PermissionKey.settingsManage;
    throw ArgumentError.value(
        entity, 'entityType', 'Unsupported sync entity type');
  }

  Set<PermissionKey> _readPermissions(String entity) {
    if ({'bidder_profiles', 'tenders', 'tender_expenses', 'tender_documents'}
        .contains(entity)) {
      return const {
        PermissionKey.tenderCreate,
        PermissionKey.tenderEdit,
        PermissionKey.tenderDelete,
      };
    }
    if (entity == 'projects') {
      return const {
        PermissionKey.projectCreate,
        PermissionKey.projectEdit,
        PermissionKey.projectDelete,
      };
    }
    final updateDelta = SyncDelta(
      deltaId: '',
      companyId: '',
      entityType: entity,
      entityId: '',
      operation: SyncOperations.update,
      payloadJson: '{}',
      createdAt: 0,
      createdByUserId: '',
      deviceId: '',
      schemaVersion: 2,
      status: SyncStatuses.downloaded,
    );
    return {_requiredPermission(updateDelta)};
  }
}
