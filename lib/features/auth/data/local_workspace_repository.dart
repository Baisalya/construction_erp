import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../database/local_database.dart';
import '../domain/app_user.dart';
import '../domain/app_user_profile.dart';
import '../domain/company_membership.dart';

class LocalWorkspaceRepository {
  LocalWorkspaceRepository({required ConstructionDatabase database})
      : _database = database;

  final ConstructionDatabase _database;

  Future<void> upsertUserProfile(
    AppUser user, {
    String? defaultCompanyId,
  }) async {
    await _database.ensureSchema();
    final now = DateTime.now().millisecondsSinceEpoch;
    final email = normalizeEmail(user.email);
    await _database.customStatement(
      '''
      INSERT INTO app_user_profiles (
        uid, normalized_email, display_name, photo_url, phone,
        last_login_at, default_company_id, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(uid) DO UPDATE SET
        normalized_email = excluded.normalized_email,
        display_name = excluded.display_name,
        photo_url = excluded.photo_url,
        phone = excluded.phone,
        last_login_at = excluded.last_login_at,
        default_company_id = COALESCE(excluded.default_company_id, app_user_profiles.default_company_id),
        updated_at = excluded.updated_at;
      ''',
      [
        Variable<String>(user.uid),
        Variable<String>(email),
        user.displayName,
        user.photoUrl,
        user.phoneNumber,
        Variable<int>(now),
        defaultCompanyId,
        Variable<int>(now),
        Variable<int>(now),
      ],
    );
  }

  Future<void> upsertMembership(CompanyMembership membership) async {
    await _database.ensureSchema();
    await _database.customStatement(
      '''
      INSERT OR REPLACE INTO company_memberships (
        id, uid, company_id, company_name, role_id, role_name, status,
        is_owner, can_access_all_projects, assigned_project_ids_json,
        last_access_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      ''',
      [
        Variable<String>(membership.id),
        Variable<String>(membership.uid),
        Variable<String>(membership.companyId),
        Variable<String>(membership.companyName),
        membership.roleId,
        membership.roleName,
        Variable<String>(membership.status),
        Variable<int>(membership.isOwner ? 1 : 0),
        Variable<int>(membership.canAccessAllProjects ? 1 : 0),
        Variable<String>(membership.assignedProjectIdsJson),
        membership.lastAccessAt,
        Variable<int>(membership.updatedAt),
      ],
    );
  }

  Future<void> replaceMemberships({
    required String uid,
    required Iterable<CompanyMembership> memberships,
  }) async {
    await _database.ensureSchema();
    await _database.transaction(() async {
      await _database.customStatement(
        'DELETE FROM company_memberships WHERE uid = ?;',
        [Variable<String>(uid)],
      );
      for (final membership in memberships) {
        await upsertMembership(membership);
      }
    });
  }

  Future<List<CompanyMembership>> listMemberships(String uid) async {
    await _database.ensureSchema();
    final rows = await _database.customSelect(
      '''
      SELECT * FROM company_memberships
      WHERE uid = ?
      ORDER BY last_access_at DESC, company_name COLLATE NOCASE ASC;
      ''',
      variables: [Variable<String>(uid)],
    ).get();
    return rows.map(_membershipFromRow).toList(growable: false);
  }

  Future<CompanyMembership?> readMembership({
    required String uid,
    required String companyId,
  }) async {
    await _database.ensureSchema();
    final row = await _database.customSelect(
      '''
      SELECT * FROM company_memberships
      WHERE uid = ? AND company_id = ?
      LIMIT 1;
      ''',
      variables: [Variable<String>(uid), Variable<String>(companyId)],
    ).getSingleOrNull();
    return row == null ? null : _membershipFromRow(row);
  }

  Future<ActiveWorkspace?> readActiveWorkspace(String uid) async {
    await _database.ensureSchema();
    final row = await _database.customSelect(
      '''
      SELECT * FROM active_workspace
      WHERE uid = ?
      LIMIT 1;
      ''',
      variables: [Variable<String>(uid)],
    ).getSingleOrNull();
    if (row == null) return null;
    return ActiveWorkspace(
      uid: row.read<String>('uid'),
      activeCompanyId: row.readNullable<String>('active_company_id'),
      activeProjectId: row.readNullable<String>('active_project_id'),
      updatedAt: row.read<int>('updated_at'),
    );
  }

  Future<void> setActiveCompany({
    required String uid,
    required String companyId,
    String? projectId,
  }) async {
    await _database.ensureSchema();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.customStatement(
      '''
      INSERT OR REPLACE INTO active_workspace (
        id, uid, active_company_id, active_project_id, updated_at
      ) VALUES (?, ?, ?, ?, ?);
      ''',
      [
        Variable<String>('workspace_$uid'),
        Variable<String>(uid),
        Variable<String>(companyId),
        projectId,
        Variable<int>(now),
      ],
    );
    await _database.customUpdate(
      '''
      UPDATE company_memberships
      SET last_access_at = ?, updated_at = ?
      WHERE uid = ? AND company_id = ?;
      ''',
      variables: [
        Variable<int>(now),
        Variable<int>(now),
        Variable<String>(uid),
        Variable<String>(companyId),
      ],
    );
  }

  Future<void> setActiveProject({
    required String uid,
    required String companyId,
    String? projectId,
  }) async {
    await _database.ensureSchema();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.customStatement(
      '''
      INSERT OR REPLACE INTO active_workspace (
        id, uid, active_company_id, active_project_id, updated_at
      ) VALUES (?, ?, ?, ?, ?);
      ''',
      [
        Variable<String>('workspace_$uid'),
        Variable<String>(uid),
        Variable<String>(companyId),
        projectId,
        Variable<int>(now),
      ],
    );
  }

  CompanyMembership _membershipFromRow(QueryRow row) {
    final assignedRaw = row.readNullable<String>('assigned_project_ids_json');
    final assigned = assignedRaw == null || assignedRaw.isEmpty
        ? const <String>[]
        : (jsonDecode(assignedRaw) as List<dynamic>)
            .map((item) => '$item')
            .toList(growable: false);
    return CompanyMembership(
      id: row.read<String>('id'),
      uid: row.read<String>('uid'),
      companyId: row.read<String>('company_id'),
      companyName: row.read<String>('company_name'),
      roleId: row.readNullable<String>('role_id'),
      roleName: row.readNullable<String>('role_name'),
      status: row.read<String>('status'),
      isOwner: row.read<int>('is_owner') == 1,
      canAccessAllProjects: row.read<int>('can_access_all_projects') == 1,
      assignedProjectIds: assigned,
      lastAccessAt: row.readNullable<int>('last_access_at'),
      updatedAt: row.read<int>('updated_at'),
    );
  }
}
