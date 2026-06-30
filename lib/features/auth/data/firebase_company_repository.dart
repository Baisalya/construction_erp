import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/permissions/permission_key.dart';
import '../../../core/permissions/role_type.dart';
import '../../../core/permissions/staff_status.dart';
import '../../../database/local_database.dart';
import '../../staff/domain/default_role_permissions.dart';
import '../../staff/domain/staff_access_policy.dart';
import '../../staff/domain/staff_profile.dart';
import '../domain/app_user.dart';
import '../domain/company_profile.dart';
import 'local_staff_access_repository.dart';

class FirebaseCompanyRepository {
  FirebaseCompanyRepository({
    required ConstructionDatabase database,
    FirebaseFirestore? firestore,
    Uuid? uuid,
    bool enableRemoteMetadata = true,
  })  : _database = database,
        _firestore = firestore,
        _uuid = uuid ?? const Uuid(),
        _enableRemoteMetadata = enableRemoteMetadata,
        _accessCache = LocalStaffAccessRepository(database: database);

  final ConstructionDatabase _database;
  final FirebaseFirestore? _firestore;
  FirebaseFirestore get _firestoreInstance =>
      _firestore ?? FirebaseFirestore.instance;
  final Uuid _uuid;
  final bool _enableRemoteMetadata;
  final LocalStaffAccessRepository _accessCache;

  Future<StaffAccessPolicy?> bootstrapAccessForUser(AppUser user) async {
    if (!_enableRemoteMetadata) {
      return _accessCache.readCachedPolicyForUid(user.uid);
    }
    try {
      final onlinePolicy = await _fetchPolicyFromFirestore(user);
      if (onlinePolicy != null) {
        await _upsertCompanyLocal(onlinePolicy.staff.companyId);
        await _upsertStaffLocal(onlinePolicy.staff);
        await _accessCache.cacheAccessPolicy(onlinePolicy);
        await registerCurrentDevice(onlinePolicy);
        return onlinePolicy;
      }
    } catch (_) {
      // Offline login is allowed from the local cache only when a prior active
      // staff cache exists. Revoked/inactive cache still blocks access.
    }
    return _accessCache.readCachedPolicyForUid(user.uid);
  }

  Future<StaffAccessPolicy> acceptInvitation({
    required AppUser user,
    required String companyId,
    required String inviteCode,
  }) async {
    if (!_enableRemoteMetadata) {
      throw StateError('Invitation acceptance needs Firebase metadata access.');
    }
    final normalizedCompanyId = companyId.trim();
    final normalizedCode = inviteCode.trim().toUpperCase();
    if (normalizedCompanyId.isEmpty || normalizedCode.isEmpty) {
      throw ArgumentError('Company ID and invite code are required.');
    }
    final companyRef =
        _firestoreInstance.collection('companies').doc(normalizedCompanyId);
    final invitationRef =
        companyRef.collection('invitations').doc(normalizedCode);
    final invitation = await invitationRef.get();
    if (!invitation.exists) {
      throw StateError('Invite not found. Check company ID and invite code.');
    }
    final invitationData = invitation.data()!;
    if (invitationData['status'] != 'pending') {
      throw StateError('This invite is no longer active.');
    }
    final invitedEmail =
        '${invitationData['email'] ?? ''}'.trim().toLowerCase();
    final userEmail = user.email?.trim().toLowerCase();
    if (invitedEmail.isNotEmpty && invitedEmail != userEmail) {
      throw StateError(
          'Login using the email address that received this invite.');
    }
    final staffId = '${invitationData['staffId'] ?? ''}';
    if (staffId.isEmpty) {
      throw StateError(
          'Invite metadata is incomplete. Ask the owner to re-invite you.');
    }
    final invitedStaffRef = companyRef.collection('staff').doc(staffId);
    final staffRef = companyRef.collection('staff').doc(user.uid);
    await _firestoreInstance.runTransaction((transaction) async {
      final latestInvite = await transaction.get(invitationRef);
      final latestStaff = await transaction.get(invitedStaffRef);
      if (!latestInvite.exists || latestInvite.data()?['status'] != 'pending') {
        throw StateError('This invite was already used or cancelled.');
      }
      if (!latestStaff.exists) {
        throw StateError('Invited staff record was not found.');
      }
      transaction.update(invitationRef, {
        'status': 'accepted',
        'acceptedByUid': user.uid,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(staffRef, {
        ...latestStaff.data()!,
        'staffId': staffId,
        'firebaseUid': user.uid,
        'status': StaffStatus.active.storageKey,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
      transaction.update(invitedStaffRef, {
        'status': 'accepted',
        'acceptedByUid': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    final acceptedStaff = await staffRef.get();
    final policy =
        await _policyFromStaffDocument(normalizedCompanyId, acceptedStaff);
    await _upsertCompanyLocal(normalizedCompanyId);
    await _upsertStaffLocal(policy.staff);
    await _accessCache.cacheAccessPolicy(policy);
    await registerCurrentDevice(policy);
    return policy;
  }

  Future<CompanyProfile> createOwnerCompany({
    required AppUser owner,
    required String companyName,
    String? gstNumber,
    String? panNumber,
    String? address,
    String? phone,
    String? email,
    int? financialYearStart,
    int? financialYearEnd,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final companyId = _uuid.v4();
    final ownerStaffId = owner.uid;
    final company = CompanyProfile(
      id: companyId,
      name: companyName.trim(),
      gstNumber: _blankToNull(gstNumber),
      panNumber: _blankToNull(panNumber),
      address: _blankToNull(address),
      phone: _blankToNull(phone),
      email: _blankToNull(email ?? owner.email),
      financialYearStart: financialYearStart,
      financialYearEnd: financialYearEnd,
      ownerUid: owner.uid,
      createdAt: now,
      updatedAt: now,
    );

    final ownerStaff = StaffProfile(
      id: ownerStaffId,
      companyId: companyId,
      name: owner.displayName?.trim().isNotEmpty == true
          ? owner.displayName!.trim()
          : (owner.email ?? 'Owner'),
      firebaseUid: owner.uid,
      email: owner.email,
      phone: owner.phoneNumber,
      roleId: RoleType.owner.storageKey,
      roleType: RoleType.owner,
      status: StaffStatus.active,
      lastLoginAt: now,
      lastSyncAt: now,
    );

    final ownerPolicy = StaffAccessPolicy(
      staff: ownerStaff,
      allowedPermissions: DefaultRolePermissions.permissionsFor(RoleType.owner),
    );

    await _database.ensureSchema();
    await _database.transaction(() async {
      await _insertCompany(company);
      await _insertDefaultRolesAndPermissions(companyId, owner.uid, now);
      await _upsertStaffLocal(ownerStaff);
    });
    await _accessCache.cacheAccessPolicy(ownerPolicy);

    if (_enableRemoteMetadata) {
      await _writeCompanyMetadataToFirestore(company, ownerStaff, now);
    }
    await registerCurrentDevice(ownerPolicy);
    return company;
  }

  Future<void> registerCurrentDevice(StaffAccessPolicy policy) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.ensureSchema();
    final existing = await _database.customSelect(
      '''
      SELECT device_id FROM device_registry
      WHERE company_id = ? AND firebase_uid = ? AND is_deleted = 0
      ORDER BY created_at ASC LIMIT 1;
      ''',
      variables: [
        Variable<String>(policy.staff.companyId),
        Variable<String>(policy.staff.firebaseUid ?? policy.staff.id),
      ],
    ).getSingleOrNull();
    final deviceId = existing?.read<String>('device_id') ?? _uuid.v4();
    final platform = Platform.operatingSystem;
    await _database.customStatement(
      '''
      INSERT OR REPLACE INTO device_registry (
        id, company_id, created_at, updated_at, created_by_user_id,
        updated_by_user_id, is_deleted, sync_status, version, device_id,
        firebase_uid, device_name, platform, last_sync_at, status
      ) VALUES (?, ?, ?, ?, ?, ?, 0, 'localOnly', 1, ?, ?, ?, ?, ?, 'active');
      ''',
      [
        Variable<String>(deviceId),
        Variable<String>(policy.staff.companyId),
        Variable<int>(now),
        Variable<int>(now),
        policy.staff.firebaseUid,
        policy.staff.firebaseUid,
        Variable<String>(deviceId),
        policy.staff.firebaseUid,
        Variable<String>('This $platform device'),
        Variable<String>(platform),
        Variable<int>(now),
      ],
    );

    if (_enableRemoteMetadata && policy.staff.firebaseUid != null) {
      await _firestoreInstance
          .collection('companies')
          .doc(policy.staff.companyId)
          .collection('devices')
          .doc(deviceId)
          .set({
        'deviceId': deviceId,
        'firebaseUid': policy.staff.firebaseUid,
        'staffId': policy.staff.id,
        'platform': platform,
        'deviceName': 'This $platform device',
        'status': 'active',
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<CompanyProfile?> readLatestLocalCompany() async {
    await _database.ensureSchema();
    final rows = await _database.customSelect('''
      SELECT * FROM companies
      WHERE is_deleted = 0
      ORDER BY updated_at DESC
      LIMIT 1;
      ''').get();
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    return CompanyProfile(
      id: row.read<String>('id'),
      name: row.read<String>('name'),
      gstNumber: row.readNullable<String>('gst_number'),
      panNumber: row.readNullable<String>('pan_number'),
      address: row.readNullable<String>('address'),
      phone: row.readNullable<String>('phone'),
      email: row.readNullable<String>('email'),
      logoPath: row.readNullable<String>('logo_path'),
      financialYearStart: row.readNullable<int>('financial_year_start'),
      financialYearEnd: row.readNullable<int>('financial_year_end'),
      createdAt: row.read<int>('created_at'),
      updatedAt: row.read<int>('updated_at'),
    );
  }

  Future<StaffAccessPolicy?> _fetchPolicyFromFirestore(AppUser user) async {
    final owned = await _firestoreInstance
        .collection('companies')
        .where('ownerUid', isEqualTo: user.uid)
        .limit(1)
        .get();
    if (owned.docs.isNotEmpty) {
      final companyId = owned.docs.first.id;
      final staffSnap = await _firestoreInstance
          .collection('companies')
          .doc(companyId)
          .collection('staff')
          .where('firebaseUid', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (staffSnap.docs.isNotEmpty) {
        return _policyFromStaffDocument(companyId, staffSnap.docs.first);
      }
    }

    final staffQuery = await _firestoreInstance
        .collectionGroup('staff')
        .where('firebaseUid', isEqualTo: user.uid)
        .limit(1)
        .get();
    if (staffQuery.docs.isEmpty) {
      return null;
    }
    final staffDoc = staffQuery.docs.first;
    final companyId = staffDoc.reference.parent.parent!.id;
    return _policyFromStaffDocument(companyId, staffDoc);
  }

  Future<StaffAccessPolicy> _policyFromStaffDocument(
    String companyId,
    DocumentSnapshot<Map<String, dynamic>> staffDoc,
  ) async {
    final data = staffDoc.data()!;
    final roleId = data['roleId'] as String?;
    final roleType = StaffProfile.roleTypeFromStorage(roleId);
    var rolePermissions = roleType == null
        ? <PermissionKey>{}
        : DefaultRolePermissions.permissionsFor(roleType);
    if (roleId != null) {
      final permissionDoc = await _firestoreInstance
          .collection('companies')
          .doc(companyId)
          .collection('role_permissions')
          .doc(roleId)
          .get();
      final remotePermissions = permissionDoc.data()?['permissions'];
      if (remotePermissions is Map<String, dynamic>) {
        rolePermissions = permissionSetFromJsonMap(remotePermissions);
      }
    }
    final overrides = data['permissionsOverride'];
    final mergedPermissions = <PermissionKey>{...rolePermissions};
    if (overrides is Map<String, dynamic>) {
      for (final entry in overrides.entries) {
        final permission = permissionKeyFromStorageKey(entry.key);
        if (permission == null) {
          continue;
        }
        if (entry.value == true) {
          mergedPermissions.add(permission);
        } else if (entry.value == false) {
          mergedPermissions.remove(permission);
        }
      }
    }

    final assigned = data['assignedProjectIds'];
    final assignedProjectIds = assigned is Iterable
        ? assigned.map((item) => '$item').toSet()
        : <String>{};
    final staff = StaffProfile(
      id: data['staffId'] as String? ?? staffDoc.id,
      companyId: companyId,
      name: data['name'] as String? ?? 'Staff User',
      firebaseUid: data['firebaseUid'] as String?,
      email: data['email'] as String?,
      phone: data['phone'] as String?,
      roleId: roleId,
      roleType: roleType,
      status: StaffProfile.statusFromStorage(data['status'] as String?),
      lastLoginAt: _timestampMillis(data['lastLoginAt']),
      lastSyncAt: _timestampMillis(data['lastSyncAt']),
    );
    return StaffAccessPolicy(
      staff: staff,
      allowedPermissions: mergedPermissions,
      assignedProjectIds: assignedProjectIds,
    );
  }

  Future<void> _writeCompanyMetadataToFirestore(
    CompanyProfile company,
    StaffProfile ownerStaff,
    int now,
  ) async {
    final batch = _firestoreInstance.batch();
    final companyRef =
        _firestoreInstance.collection('companies').doc(company.id);
    batch.set(companyRef, {
      'companyId': company.id,
      'name': company.name,
      'gstNumber': company.gstNumber,
      'panNumber': company.panNumber,
      'address': company.address,
      'phone': company.phone,
      'email': company.email,
      'ownerUid': company.ownerUid,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(companyRef.collection('staff').doc(ownerStaff.id), {
      'staffId': ownerStaff.id,
      'firebaseUid': ownerStaff.firebaseUid,
      'companyId': ownerStaff.companyId,
      'name': ownerStaff.name,
      'email': ownerStaff.email,
      'phone': ownerStaff.phone,
      'roleId': ownerStaff.roleId,
      'status': ownerStaff.status.storageKey,
      'assignedProjectIds': <String>[],
      'permissionsOverride': null,
      'invitedByUid': ownerStaff.firebaseUid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'lastSyncAt': FieldValue.serverTimestamp(),
    });

    for (final role in DefaultRolePermissions.orderedRoles) {
      final roleId = role.storageKey;
      batch.set(companyRef.collection('roles').doc(roleId), {
        'roleId': roleId,
        'name': DefaultRolePermissions.roleName(role),
        'description': DefaultRolePermissions.roleDescription(role),
        'isSystemRole': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(companyRef.collection('role_permissions').doc(roleId), {
        'roleId': roleId,
        'permissions': permissionSetToJsonMap(
          DefaultRolePermissions.permissionsFor(role),
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> _upsertCompanyLocal(String companyId) async {
    await _database.ensureSchema();
    final companyDoc =
        await _firestoreInstance.collection('companies').doc(companyId).get();
    if (!companyDoc.exists) {
      return;
    }
    final data = companyDoc.data()!;
    final now = DateTime.now().millisecondsSinceEpoch;
    final company = CompanyProfile(
      id: companyId,
      name: data['name'] as String? ?? 'Company',
      gstNumber: data['gstNumber'] as String?,
      panNumber: data['panNumber'] as String?,
      address: data['address'] as String?,
      phone: data['phone'] as String?,
      email: data['email'] as String?,
      ownerUid: data['ownerUid'] as String?,
      createdAt: _timestampMillis(data['createdAt']) ?? now,
      updatedAt: _timestampMillis(data['updatedAt']) ?? now,
    );
    await _insertCompany(company);
  }

  Future<void> _insertCompany(CompanyProfile company) async {
    await _database.customStatement(
      '''
      INSERT OR REPLACE INTO companies (
        id, created_at, updated_at, created_by_user_id, updated_by_user_id,
        is_deleted, sync_status, version, name, gst_number, pan_number,
        address, phone, email, logo_path, financial_year_start, financial_year_end
      ) VALUES (?, ?, ?, ?, ?, 0, 'localOnly', 1, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      ''',
      [
        Variable<String>(company.id),
        Variable<int>(company.createdAt),
        Variable<int>(company.updatedAt),
        company.ownerUid,
        company.ownerUid,
        Variable<String>(company.name),
        company.gstNumber,
        company.panNumber,
        company.address,
        company.phone,
        company.email,
        company.logoPath,
        company.financialYearStart,
        company.financialYearEnd,
      ],
    );
  }

  Future<void> _insertDefaultRolesAndPermissions(
    String companyId,
    String ownerUid,
    int now,
  ) async {
    for (final role in DefaultRolePermissions.orderedRoles) {
      final roleId = role.storageKey;
      final localRoleId = '${companyId}_$roleId';
      await _database.customStatement(
        '''
        INSERT OR REPLACE INTO roles (
          id, company_id, created_at, updated_at, created_by_user_id,
          updated_by_user_id, is_deleted, sync_status, version, name, description
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'localOnly', 1, ?, ?);
        ''',
        [
          Variable<String>(localRoleId),
          Variable<String>(companyId),
          Variable<int>(now),
          Variable<int>(now),
          Variable<String>(ownerUid),
          Variable<String>(ownerUid),
          Variable<String>(DefaultRolePermissions.roleName(role)),
          Variable<String>(DefaultRolePermissions.roleDescription(role)),
        ],
      );

      final permissions = DefaultRolePermissions.permissionsFor(role);
      for (final permission in PermissionKey.values) {
        await _database.customStatement(
          '''
          INSERT OR REPLACE INTO permissions (
            id, company_id, created_at, updated_at, created_by_user_id,
            updated_by_user_id, is_deleted, sync_status, version, role_id,
            permission_key, is_allowed
          ) VALUES (?, ?, ?, ?, ?, ?, 0, 'localOnly', 1, ?, ?, ?);
          ''',
          [
            Variable<String>('${companyId}_${roleId}_${permission.storageKey}'),
            Variable<String>(companyId),
            Variable<int>(now),
            Variable<int>(now),
            Variable<String>(ownerUid),
            Variable<String>(ownerUid),
            Variable<String>(roleId),
            Variable<String>(permission.storageKey),
            Variable<int>(permissions.contains(permission) ? 1 : 0),
          ],
        );
      }
    }
  }

  Future<void> _upsertStaffLocal(StaffProfile staff) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.customStatement(
      '''
      INSERT OR REPLACE INTO staff_users (
        id, company_id, created_at, updated_at, created_by_user_id,
        updated_by_user_id, is_deleted, sync_status, version, firebase_uid,
        name, phone, email, role_id, status, last_login_at, last_sync_at
      ) VALUES (?, ?, ?, ?, ?, ?, 0, 'localOnly', 1, ?, ?, ?, ?, ?, ?, ?, ?);
      ''',
      [
        Variable<String>(staff.id),
        Variable<String>(staff.companyId),
        Variable<int>(now),
        Variable<int>(now),
        staff.firebaseUid,
        staff.firebaseUid,
        staff.firebaseUid,
        Variable<String>(staff.name),
        staff.phone,
        staff.email,
        staff.roleId,
        Variable<String>(staff.status.storageKey),
        staff.lastLoginAt,
        staff.lastSyncAt,
      ],
    );
  }

  int? _timestampMillis(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }
    if (value is int) {
      return value;
    }
    return null;
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
