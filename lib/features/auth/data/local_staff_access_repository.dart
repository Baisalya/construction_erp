import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/permissions/permission_key.dart';
import '../../../core/permissions/staff_status.dart';
import '../../../database/local_database.dart';
import '../../staff/domain/staff_access_policy.dart';
import '../../staff/domain/staff_profile.dart';

class LocalStaffAccessRepository {
  LocalStaffAccessRepository({required ConstructionDatabase database})
      : _database = database;

  final ConstructionDatabase _database;

  Future<void> cacheAccessPolicy(StaffAccessPolicy policy) async {
    await _database.ensureSchema();
    final now = DateTime.now().millisecondsSinceEpoch;
    final permissionJson = jsonEncode(
      permissionSetToJsonMap(policy.allowedPermissions),
    );
    final assignedProjectJson = jsonEncode(policy.assignedProjectIds.toList());
    await _database.customStatement(
      '''
      INSERT OR REPLACE INTO staff_access_cache (
        id, company_id, created_at, updated_at, created_by_user_id,
        updated_by_user_id, is_deleted, sync_status, version, staff_id,
        firebase_uid, role_id, permission_json, assigned_project_ids_json,
        can_access_all_projects, status, cached_at
      ) VALUES (?, ?, ?, ?, ?, ?, 0, 'localOnly', 1, ?, ?, ?, ?, ?, ?, ?, ?);
      ''',
      [
        Variable<String>('access_${policy.staff.companyId}_${policy.staff.id}'),
        Variable<String>(policy.staff.companyId),
        Variable<int>(now),
        Variable<int>(now),
        policy.staff.firebaseUid,
        policy.staff.firebaseUid,
        Variable<String>(policy.staff.id),
        policy.staff.firebaseUid,
        policy.staff.roleId,
        Variable<String>(permissionJson),
        Variable<String>(assignedProjectJson),
        Variable<int>(policy.canAccessAllProjects ? 1 : 0),
        Variable<String>(policy.staff.status.storageKey),
        Variable<int>(now),
      ],
    );
  }

  Future<StaffAccessPolicy?> readCachedPolicyForUid(String firebaseUid) async {
    await _database.ensureSchema();
    final rows = await _database.customSelect('''
      SELECT sac.*, su.name, su.phone, su.email, su.last_login_at, su.last_sync_at
      FROM staff_access_cache sac
      LEFT JOIN staff_users su ON su.id = sac.staff_id AND su.company_id = sac.company_id
      WHERE sac.firebase_uid = ? AND sac.is_deleted = 0
      ORDER BY sac.cached_at DESC
      LIMIT 1;
      ''', variables: [Variable<String>(firebaseUid)]).get();
    if (rows.isEmpty) {
      return null;
    }
    return _policyFromRow(rows.first, isOfflineCache: true);
  }

  Future<StaffAccessPolicy?> readCachedPolicyForUidAndCompany({
    required String firebaseUid,
    required String companyId,
  }) async {
    await _database.ensureSchema();
    final rows = await _database.customSelect('''
      SELECT sac.*, su.name, su.phone, su.email, su.last_login_at, su.last_sync_at
      FROM staff_access_cache sac
      LEFT JOIN staff_users su ON su.id = sac.staff_id AND su.company_id = sac.company_id
      WHERE sac.firebase_uid = ? AND sac.company_id = ? AND sac.is_deleted = 0
      ORDER BY sac.cached_at DESC
      LIMIT 1;
      ''', variables: [
      Variable<String>(firebaseUid),
      Variable<String>(companyId),
    ]).get();
    if (rows.isEmpty) {
      return null;
    }
    return _policyFromRow(rows.first, isOfflineCache: true);
  }

  Future<List<StaffAccessPolicy>> listCachedPoliciesForUid(
    String firebaseUid,
  ) async {
    await _database.ensureSchema();
    final rows = await _database.customSelect('''
      SELECT sac.*, su.name, su.phone, su.email, su.last_login_at, su.last_sync_at
      FROM staff_access_cache sac
      LEFT JOIN staff_users su ON su.id = sac.staff_id AND su.company_id = sac.company_id
      WHERE sac.firebase_uid = ? AND sac.is_deleted = 0
      ORDER BY sac.cached_at DESC;
      ''', variables: [Variable<String>(firebaseUid)]).get();
    return rows
        .map((row) => _policyFromRow(row, isOfflineCache: true))
        .toList(growable: false);
  }

  Future<StaffAccessPolicy?> readLatestCachedPolicy() async {
    await _database.ensureSchema();
    final rows = await _database.customSelect('''
      SELECT sac.*, su.name, su.phone, su.email, su.last_login_at, su.last_sync_at
      FROM staff_access_cache sac
      LEFT JOIN staff_users su ON su.id = sac.staff_id AND su.company_id = sac.company_id
      WHERE sac.is_deleted = 0
      ORDER BY sac.cached_at DESC
      LIMIT 1;
      ''').get();
    if (rows.isEmpty) {
      return null;
    }
    return _policyFromRow(rows.first, isOfflineCache: true);
  }

  Future<void> updateCachedStatus({
    required String companyId,
    required String staffId,
    required StaffStatus status,
  }) async {
    await _database.ensureSchema();
    await _database.customUpdate(
      '''
      UPDATE staff_access_cache
      SET status = ?, cached_at = ?, updated_at = ?
      WHERE company_id = ? AND staff_id = ? AND is_deleted = 0;
      ''',
      variables: [
        Variable<String>(status.storageKey),
        Variable<int>(DateTime.now().millisecondsSinceEpoch),
        Variable<int>(DateTime.now().millisecondsSinceEpoch),
        Variable<String>(companyId),
        Variable<String>(staffId),
      ],
    );
  }

  Future<void> updateCachedRole({
    required String companyId,
    required String staffId,
    required String roleId,
    required Set<PermissionKey> permissions,
  }) async {
    await _database.ensureSchema();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.customUpdate(
      '''
      UPDATE staff_access_cache
      SET role_id = ?, permission_json = ?, cached_at = ?, updated_at = ?
      WHERE company_id = ? AND staff_id = ? AND is_deleted = 0;
      ''',
      variables: [
        Variable<String>(roleId),
        Variable<String>(jsonEncode(permissionSetToJsonMap(permissions))),
        Variable<int>(now),
        Variable<int>(now),
        Variable<String>(companyId),
        Variable<String>(staffId),
      ],
    );
  }

  Future<void> updateCachedProjects({
    required String companyId,
    required String staffId,
    required Iterable<String> projectIds,
    bool canAccessAllProjects = false,
  }) async {
    await _database.ensureSchema();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.customUpdate(
      '''
      UPDATE staff_access_cache
      SET assigned_project_ids_json = ?, can_access_all_projects = ?,
          cached_at = ?, updated_at = ?
      WHERE company_id = ? AND staff_id = ? AND is_deleted = 0;
      ''',
      variables: [
        Variable<String>(jsonEncode(projectIds.toList(growable: false))),
        Variable<int>(canAccessAllProjects ? 1 : 0),
        Variable<int>(now),
        Variable<int>(now),
        Variable<String>(companyId),
        Variable<String>(staffId),
      ],
    );
  }

  StaffAccessPolicy _policyFromRow(QueryRow row,
      {required bool isOfflineCache}) {
    final permissionMap = jsonDecode(
      row.read<String>('permission_json'),
    ) as Map<String, dynamic>;
    final projectList = jsonDecode(
      row.read<String>('assigned_project_ids_json'),
    ) as List<dynamic>;
    final roleId = row.readNullable<String>('role_id');
    final staff = StaffProfile(
      id: row.read<String>('staff_id'),
      companyId: row.read<String>('company_id'),
      name: row.readNullable<String>('name') ?? 'Staff User',
      firebaseUid: row.readNullable<String>('firebase_uid'),
      phone: row.readNullable<String>('phone'),
      email: row.readNullable<String>('email'),
      roleId: roleId,
      roleType: StaffProfile.roleTypeFromStorage(roleId),
      status: StaffProfile.statusFromStorage(row.read<String>('status')),
      lastLoginAt: row.readNullable<int>('last_login_at'),
      lastSyncAt: row.readNullable<int>('last_sync_at'),
    );
    return StaffAccessPolicy(
      staff: staff,
      allowedPermissions: permissionSetFromJsonMap(permissionMap),
      assignedProjectIds: projectList.map((item) => '$item').toSet(),
      canAccessAllProjects:
          row.readNullable<int>('can_access_all_projects') == 1,
      cachedAt: row.read<int>('cached_at'),
      isOfflineCache: isOfflineCache,
    );
  }
}
