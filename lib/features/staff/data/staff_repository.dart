import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/permissions/permission_key.dart';
import '../../../core/permissions/role_type.dart';
import '../../../core/permissions/staff_status.dart';
import '../../../database/local_database.dart';
import '../../auth/data/local_staff_access_repository.dart';
import '../domain/default_role_permissions.dart';
import '../domain/staff_access_policy.dart';
import '../domain/staff_invitation.dart';
import '../domain/staff_module_contract.dart';
import '../domain/staff_profile.dart';

class StaffRepository implements StaffModuleContract {
  StaffRepository({
    ConstructionDatabase? database,
    FirebaseFirestore? firestore,
    Uuid? uuid,
  })  : _database = database,
        _firestore = firestore,
        _uuid = uuid ?? const Uuid();

  final ConstructionDatabase? _database;
  final FirebaseFirestore? _firestore;

  LocalStaffAccessRepository get _accessCache =>
      LocalStaffAccessRepository(database: _requireDatabase());

  FirebaseFirestore get _firestoreInstance =>
      _firestore ?? FirebaseFirestore.instance;
  final Uuid _uuid;

  @override
  String get moduleName => 'Staff';

  @override
  String get phase1Responsibility =>
      'Staff roles, permissions, invitations, project assignment, and access cache';

  Future<List<StaffProfile>> listLocalStaff({String? companyId}) async {
    final database = _requireDatabase();
    await database.ensureSchema();
    if (companyId != null) {
      try {
        await _refreshLocalStaff(companyId);
      } catch (_) {
        // Staff management remains available from SQLite while offline.
      }
    }
    final rows = await database.customSelect('''
      SELECT * FROM staff_users
      WHERE is_deleted = 0
      ${companyId == null ? '' : 'AND company_id = ?'}
      ORDER BY updated_at DESC, name ASC;
      ''',
        variables:
            companyId == null ? const [] : [Variable<String>(companyId)]).get();
    return rows.map(_staffFromRow).toList(growable: false);
  }

  Future<StaffInvitation> inviteStaff({
    required StaffAccessPolicy actorPolicy,
    required String name,
    required String email,
    String? phone,
    required RoleType role,
    List<String> assignedProjectIds = const <String>[],
  }) async {
    actorPolicy.requirePermission(PermissionKey.staffManagement);
    final database = _requireDatabase();
    await database.ensureSchema();

    final now = DateTime.now().millisecondsSinceEpoch;
    final staffId = _uuid.v4();
    final inviteCode = _uuid.v4().split('-').first.toUpperCase();
    final inviteId = inviteCode;
    final roleId = role.storageKey;
    final companyId = actorPolicy.staff.companyId;

    final invitation = StaffInvitation(
      id: inviteId,
      companyId: companyId,
      inviteCode: inviteCode,
      roleId: roleId,
      status: 'pending',
      createdAt: now,
      expiresAt: now + const Duration(days: 14).inMilliseconds,
      email: email.trim(),
      phone: _blankToNull(phone),
      assignedProjectIds: assignedProjectIds,
      createdByUid: actorPolicy.staff.firebaseUid,
    );

    await database.customStatement(
      '''
      INSERT OR REPLACE INTO staff_users (
        id, company_id, created_at, updated_at, created_by_user_id,
        updated_by_user_id, is_deleted, sync_status, version, firebase_uid,
        name, phone, email, role_id, status, last_login_at, last_sync_at
      ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, NULL, ?, ?, ?, ?, 'invited', NULL, NULL);
      ''',
      [
        Variable<String>(staffId),
        Variable<String>(companyId),
        Variable<int>(now),
        Variable<int>(now),
        actorPolicy.staff.firebaseUid,
        actorPolicy.staff.firebaseUid,
        Variable<String>(name.trim()),
        _blankToNull(phone),
        Variable<String>(email.trim()),
        Variable<String>(roleId),
      ],
    );

    await _firestoreInstance
        .collection('companies')
        .doc(companyId)
        .collection('invitations')
        .doc(inviteId)
        .set({
      'inviteId': inviteId,
      'staffId': staffId,
      'companyId': companyId,
      'email': email.trim(),
      'phone': _blankToNull(phone),
      'inviteCode': inviteCode,
      'roleId': roleId,
      'assignedProjectIds': assignedProjectIds,
      'status': 'pending',
      'createdByUid': actorPolicy.staff.firebaseUid,
      'acceptedByUid': null,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromMillisecondsSinceEpoch(invitation.expiresAt),
      'acceptedAt': null,
    });

    await _firestoreInstance
        .collection('companies')
        .doc(companyId)
        .collection('staff')
        .doc(staffId)
        .set({
      'staffId': staffId,
      'firebaseUid': null,
      'companyId': companyId,
      'name': name.trim(),
      'email': email.trim(),
      'phone': _blankToNull(phone),
      'roleId': roleId,
      'status': StaffStatus.invited.storageKey,
      'assignedProjectIds': assignedProjectIds,
      'permissionsOverride': null,
      'inviteCode': inviteCode,
      'invitedByUid': actorPolicy.staff.firebaseUid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': null,
      'lastSyncAt': null,
    });

    return invitation;
  }

  Future<void> changeStaffStatus({
    required StaffAccessPolicy actorPolicy,
    required String staffId,
    required StaffStatus status,
  }) async {
    actorPolicy.requirePermission(PermissionKey.staffManagement);
    final database = _requireDatabase();
    await database.ensureSchema();
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.customStatement(
      '''
      UPDATE staff_users
      SET status = ?, updated_at = ?, updated_by_user_id = ?, sync_status = 'pendingUpload'
      WHERE company_id = ? AND id = ?;
      ''',
      [
        Variable<String>(status.storageKey),
        Variable<int>(now),
        actorPolicy.staff.firebaseUid,
        Variable<String>(actorPolicy.staff.companyId),
        Variable<String>(staffId),
      ],
    );
    await _accessCache.updateCachedStatus(
      companyId: actorPolicy.staff.companyId,
      staffId: staffId,
      status: status,
    );
    final remoteStaffId = await _remoteStaffDocumentId(
      actorPolicy.staff.companyId,
      staffId,
    );
    await _firestoreInstance
        .collection('companies')
        .doc(actorPolicy.staff.companyId)
        .collection('staff')
        .doc(remoteStaffId)
        .set({
      'status': status.storageKey,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateStaffRole({
    required StaffAccessPolicy actorPolicy,
    required String staffId,
    required RoleType role,
  }) async {
    actorPolicy.requirePermission(PermissionKey.staffManagement);
    final database = _requireDatabase();
    await database.ensureSchema();
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.customStatement(
      '''
      UPDATE staff_users
      SET role_id = ?, updated_at = ?, updated_by_user_id = ?, sync_status = 'pendingUpload'
      WHERE company_id = ? AND id = ?;
      ''',
      [
        Variable<String>(role.storageKey),
        Variable<int>(now),
        actorPolicy.staff.firebaseUid,
        Variable<String>(actorPolicy.staff.companyId),
        Variable<String>(staffId),
      ],
    );
    await _accessCache.updateCachedRole(
      companyId: actorPolicy.staff.companyId,
      staffId: staffId,
      roleId: role.storageKey,
      permissions: DefaultRolePermissions.permissionsFor(role),
    );
    final remoteStaffId = await _remoteStaffDocumentId(
      actorPolicy.staff.companyId,
      staffId,
    );
    await _firestoreInstance
        .collection('companies')
        .doc(actorPolicy.staff.companyId)
        .collection('staff')
        .doc(remoteStaffId)
        .set({
      'roleId': role.storageKey,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateStaffDetails({
    required StaffAccessPolicy actorPolicy,
    required String staffId,
    required String name,
    required String email,
    String? phone,
  }) async {
    actorPolicy.requirePermission(PermissionKey.staffManagement);
    if (name.trim().isEmpty || !email.contains('@')) {
      throw ArgumentError('Staff name and valid email are required.');
    }
    final database = _requireDatabase();
    await database.ensureSchema();
    final now = DateTime.now().millisecondsSinceEpoch;
    final changed = await database.customUpdate(
      '''
      UPDATE staff_users
      SET name = ?, email = ?, phone = ?, updated_at = ?, updated_by_user_id = ?
      WHERE company_id = ? AND id = ? AND is_deleted = 0;
      ''',
      variables: [
        Variable<String>(name.trim()),
        Variable<String>(email.trim()),
        Variable<String>(_blankToNull(phone) ?? ''),
        Variable<int>(now),
        Variable<String>(actorPolicy.staff.firebaseUid ?? actorPolicy.staff.id),
        Variable<String>(actorPolicy.staff.companyId),
        Variable<String>(staffId),
      ],
    );
    if (changed != 1) throw StateError('Staff record not found.');
    final remoteStaffId = await _remoteStaffDocumentId(
      actorPolicy.staff.companyId,
      staffId,
    );
    await _firestoreInstance
        .collection('companies')
        .doc(actorPolicy.staff.companyId)
        .collection('staff')
        .doc(remoteStaffId)
        .set({
      'name': name.trim(),
      'email': email.trim(),
      'phone': _blankToNull(phone),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> assignProjects({
    required StaffAccessPolicy actorPolicy,
    required String staffId,
    required List<String> projectIds,
  }) async {
    actorPolicy.requirePermission(PermissionKey.staffManagement);
    final database = _requireDatabase();
    await database.ensureSchema();
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.transaction(() async {
      await database.customUpdate(
        '''
        UPDATE project_staff_assignments
        SET is_deleted = 1, updated_at = ?, updated_by_user_id = ?
        WHERE company_id = ? AND staff_id = ? AND is_deleted = 0;
        ''',
        variables: [
          Variable<int>(now),
          Variable<String>(
              actorPolicy.staff.firebaseUid ?? actorPolicy.staff.id),
          Variable<String>(actorPolicy.staff.companyId),
          Variable<String>(staffId),
        ],
      );
      for (final projectId in projectIds.toSet()) {
        await database.customStatement(
          '''
          INSERT OR REPLACE INTO project_staff_assignments (
            id, company_id, created_at, updated_at, created_by_user_id,
            updated_by_user_id, is_deleted, sync_status, version, project_id,
            staff_id, role, can_view, can_edit, can_approve
          ) VALUES (?, ?, ?, ?, ?, ?, 0, 'localOnly', 1, ?, ?, NULL, 1, 1, 0);
          ''',
          [
            Variable<String>('${staffId}_$projectId'),
            Variable<String>(actorPolicy.staff.companyId),
            Variable<int>(now),
            Variable<int>(now),
            Variable<String>(
                actorPolicy.staff.firebaseUid ?? actorPolicy.staff.id),
            Variable<String>(
                actorPolicy.staff.firebaseUid ?? actorPolicy.staff.id),
            Variable<String>(projectId),
            Variable<String>(staffId),
          ],
        );
      }
    });
    await _accessCache.updateCachedProjects(
      companyId: actorPolicy.staff.companyId,
      staffId: staffId,
      projectIds: projectIds,
    );
    final remoteStaffId = await _remoteStaffDocumentId(
      actorPolicy.staff.companyId,
      staffId,
    );
    await _firestoreInstance
        .collection('companies')
        .doc(actorPolicy.staff.companyId)
        .collection('staff')
        .doc(remoteStaffId)
        .set({
      'assignedProjectIds': projectIds,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Set<String>> listAssignedProjectIds({
    required String companyId,
    required String staffId,
  }) async {
    final database = _requireDatabase();
    await database.ensureSchema();
    final rows = await database.customSelect(
      '''
      SELECT project_id FROM project_staff_assignments
      WHERE company_id = ? AND staff_id = ? AND is_deleted = 0;
      ''',
      variables: [Variable<String>(companyId), Variable<String>(staffId)],
    ).get();
    return rows.map((row) => row.read<String>('project_id')).toSet();
  }

  Future<Map<PermissionKey, bool>> readLocalRolePermissions({
    required String companyId,
    required RoleType role,
  }) async {
    final database = _requireDatabase();
    await database.ensureSchema();
    final rows = await database.customSelect(
      '''
      SELECT permission_key, is_allowed FROM permissions
      WHERE company_id = ? AND role_id = ? AND is_deleted = 0;
      ''',
      variables: [
        Variable<String>(companyId),
        Variable<String>(role.storageKey),
      ],
    ).get();
    if (rows.isEmpty) {
      final defaults = DefaultRolePermissions.permissionsFor(role);
      return {
        for (final key in PermissionKey.values) key: defaults.contains(key)
      };
    }
    return {
      for (final row in rows)
        if (permissionKeyFromStorageKey(row.read<String>('permission_key'))
            case final key?)
          key: row.read<int>('is_allowed') == 1,
    };
  }

  Future<void> updateRolePermissions({
    required StaffAccessPolicy actorPolicy,
    required RoleType role,
    required Set<PermissionKey> permissions,
  }) async {
    actorPolicy.requirePermission(PermissionKey.staffManagement);
    if (role == RoleType.owner &&
        permissions.length != PermissionKey.values.length) {
      throw StateError('Owner permissions cannot be reduced.');
    }
    final database = _requireDatabase();
    await database.ensureSchema();
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.transaction(() async {
      for (final permission in PermissionKey.values) {
        await database.customStatement(
          '''
          INSERT OR REPLACE INTO permissions (
            id, company_id, created_at, updated_at, created_by_user_id,
            updated_by_user_id, is_deleted, sync_status, version, role_id,
            permission_key, is_allowed
          ) VALUES (?, ?, ?, ?, ?, ?, 0, 'localOnly', 1, ?, ?, ?);
          ''',
          [
            Variable<String>(
                '${actorPolicy.staff.companyId}_${role.storageKey}_${permission.storageKey}'),
            Variable<String>(actorPolicy.staff.companyId),
            Variable<int>(now),
            Variable<int>(now),
            Variable<String>(
                actorPolicy.staff.firebaseUid ?? actorPolicy.staff.id),
            Variable<String>(
                actorPolicy.staff.firebaseUid ?? actorPolicy.staff.id),
            Variable<String>(role.storageKey),
            Variable<String>(permission.storageKey),
            Variable<int>(permissions.contains(permission) ? 1 : 0),
          ],
        );
      }
    });
    await _firestoreInstance
        .collection('companies')
        .doc(actorPolicy.staff.companyId)
        .collection('role_permissions')
        .doc(role.storageKey)
        .set({
      'roleId': role.storageKey,
      'permissions': permissionSetToJsonMap(permissions),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Set<PermissionKey> permissionsForRole(RoleType role) {
    return DefaultRolePermissions.permissionsFor(role);
  }

  StaffProfile _staffFromRow(QueryRow row) {
    final roleId = row.readNullable<String>('role_id');
    return StaffProfile(
      id: row.read<String>('id'),
      companyId: row.read<String>('company_id'),
      name: row.read<String>('name'),
      firebaseUid: row.readNullable<String>('firebase_uid'),
      phone: row.readNullable<String>('phone'),
      email: row.readNullable<String>('email'),
      roleId: roleId,
      roleType: StaffProfile.roleTypeFromStorage(roleId),
      status: StaffProfile.statusFromStorage(row.read<String>('status')),
      lastLoginAt: row.readNullable<int>('last_login_at'),
      lastSyncAt: row.readNullable<int>('last_sync_at'),
    );
  }

  Future<void> _refreshLocalStaff(String companyId) async {
    final snapshot = await _firestoreInstance
        .collection('companies')
        .doc(companyId)
        .collection('staff')
        .get();
    final merged = <String, Map<String, dynamic>>{};
    for (final document in snapshot.docs) {
      final data = document.data();
      final staffId = '${data['staffId'] ?? document.id}';
      final current = merged[staffId];
      if (current == null ||
          (current['firebaseUid'] == null && data['firebaseUid'] != null)) {
        merged[staffId] = data;
      }
    }
    final database = _requireDatabase();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final entry in merged.entries) {
      final data = entry.value;
      await database.customStatement(
        '''
        INSERT INTO staff_users (
          id, company_id, created_at, updated_at, created_by_user_id,
          updated_by_user_id, is_deleted, sync_status, version, firebase_uid,
          name, phone, email, role_id, status, last_login_at, last_sync_at
        ) VALUES (?, ?, ?, ?, NULL, NULL, 0, 'localOnly', 1, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          firebase_uid = excluded.firebase_uid,
          name = excluded.name,
          phone = excluded.phone,
          email = excluded.email,
          role_id = excluded.role_id,
          status = excluded.status,
          last_login_at = excluded.last_login_at,
          last_sync_at = excluded.last_sync_at,
          updated_at = excluded.updated_at;
        ''',
        [
          Variable<String>(entry.key),
          Variable<String>(companyId),
          Variable<int>(now),
          Variable<int>(now),
          data['firebaseUid'],
          Variable<String>('${data['name'] ?? 'Staff User'}'),
          data['phone'],
          data['email'],
          data['roleId'],
          Variable<String>('${data['status'] ?? 'invited'}'),
          _timestampMillis(data['lastLoginAt']),
          _timestampMillis(data['lastSyncAt']),
        ],
      );
    }
  }

  Future<String> _remoteStaffDocumentId(
    String companyId,
    String staffId,
  ) async {
    final database = _requireDatabase();
    final row = await database.customSelect(
      '''
      SELECT firebase_uid FROM staff_users
      WHERE company_id = ? AND id = ? AND is_deleted = 0 LIMIT 1;
      ''',
      variables: [Variable<String>(companyId), Variable<String>(staffId)],
    ).getSingleOrNull();
    return row?.readNullable<String>('firebase_uid') ?? staffId;
  }

  int? _timestampMillis(dynamic value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is int) return value;
    return null;
  }

  ConstructionDatabase _requireDatabase() {
    final database = _database;
    if (database == null) {
      throw StateError('StaffRepository needs a local database for Phase 6.');
    }
    return database;
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
