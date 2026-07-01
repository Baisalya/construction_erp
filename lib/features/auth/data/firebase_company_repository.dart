import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/permissions/permission_key.dart';
import '../../../core/permissions/role_type.dart';
import '../../../core/permissions/staff_status.dart';
import '../../../core/firebase/firestore_setup_error.dart';
import '../../../core/security/invitation_code.dart';
import '../../../database/local_database.dart';
import '../../staff/domain/default_role_permissions.dart';
import '../../staff/domain/staff_access_policy.dart';
import '../../staff/domain/staff_profile.dart';
import '../domain/app_user.dart';
import '../domain/app_user_profile.dart';
import '../domain/company_membership.dart';
import '../domain/company_profile.dart';
import 'local_staff_access_repository.dart';
import 'local_workspace_repository.dart';

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
        _accessCache = LocalStaffAccessRepository(database: database),
        _workspace = LocalWorkspaceRepository(database: database);

  final ConstructionDatabase _database;
  final FirebaseFirestore? _firestore;
  FirebaseFirestore get _firestoreInstance =>
      _firestore ?? FirebaseFirestore.instance;
  final Uuid _uuid;
  final bool _enableRemoteMetadata;
  final LocalStaffAccessRepository _accessCache;
  final LocalWorkspaceRepository _workspace;

  Future<StaffAccessPolicy?> bootstrapAccessForUser(AppUser user) async {
    await _workspace.upsertUserProfile(user);
    if (!_enableRemoteMetadata) {
      final workspace = await _workspace.readActiveWorkspace(user.uid);
      if (workspace?.activeCompanyId != null) {
        return _accessCache.readCachedPolicyForUidAndCompany(
          firebaseUid: user.uid,
          companyId: workspace!.activeCompanyId!,
        );
      }
      return _accessCache.readCachedPolicyForUid(user.uid);
    }
    var completedRemoteAccessCheck = false;
    try {
      await _upsertRemoteUserProfile(user);
      final memberships = await refreshMembershipsForUser(user);
      final workspace = await _workspace.readActiveWorkspace(user.uid);
      final activeCompanyId = workspace?.activeCompanyId;
      final selectedMembership = memberships.firstWhereOrNull(
            (membership) =>
                membership.companyId == activeCompanyId && membership.isActive,
          ) ??
          memberships.firstWhereOrNull((membership) => membership.isActive);
      if (selectedMembership != null) {
        await _workspace.setActiveCompany(
          uid: user.uid,
          companyId: selectedMembership.companyId,
          projectId: selectedMembership.canAccessAllProjects
              ? workspace?.activeProjectId
              : null,
        );
        final onlinePolicy = await _fetchPolicyFromFirestore(
          user,
          companyId: selectedMembership.companyId,
        );
        if (onlinePolicy != null) {
          await _upsertCompanyLocal(onlinePolicy.staff.companyId);
          await _upsertStaffLocal(onlinePolicy.staff);
          await _accessCache.cacheAccessPolicy(onlinePolicy);
          await registerCurrentDevice(onlinePolicy);
          return onlinePolicy;
        }
      }
      final legacyPolicy = await _fetchPolicyFromFirestore(user);
      if (legacyPolicy != null) {
        await _upsertCompanyLocal(legacyPolicy.staff.companyId);
        await _upsertStaffLocal(legacyPolicy.staff);
        await _accessCache.cacheAccessPolicy(legacyPolicy);
        await _workspace.setActiveCompany(
          uid: user.uid,
          companyId: legacyPolicy.staff.companyId,
        );
        await registerCurrentDevice(legacyPolicy);
        return legacyPolicy;
      }
      completedRemoteAccessCheck = true;
    } catch (error) {
      if (!_isOfflineError(error)) rethrow;
      // A previously validated cache is used only for genuine connectivity
      // failures. Permission errors and removed memberships never fall back.
    }
    if (completedRemoteAccessCheck) return null;
    final workspace = await _workspace.readActiveWorkspace(user.uid);
    if (workspace?.activeCompanyId != null) {
      return _accessCache.readCachedPolicyForUidAndCompany(
        firebaseUid: user.uid,
        companyId: workspace!.activeCompanyId!,
      );
    }
    return _accessCache.readCachedPolicyForUid(user.uid);
  }

  Future<List<CompanyMembership>> listMembershipsForUser(AppUser user) async {
    if (_enableRemoteMetadata) {
      try {
        return await refreshMembershipsForUser(user);
      } catch (error) {
        if (!_isOfflineError(error)) rethrow;
        // Fall back to local membership cache only while genuinely offline.
      }
    }
    return _workspace.listMemberships(user.uid);
  }

  Future<void> syncUserProfile(AppUser user) async {
    await _workspace.upsertUserProfile(user);
    if (_enableRemoteMetadata) await _upsertRemoteUserProfile(user);
  }

  bool _isOfflineError(Object error) {
    if (error is SocketException) return true;
    if (error is FirebaseException) {
      return const {
        'unavailable',
        'deadline-exceeded',
        'network-request-failed',
      }.contains(error.code);
    }
    return false;
  }

  Future<List<CompanyMembership>> refreshMembershipsForUser(
      AppUser user) async {
    final memberships = <String, CompanyMembership>{};
    final now = DateTime.now().millisecondsSinceEpoch;
    final indexSnap = await _firestoreInstance
        .collection('user_company_memberships')
        .doc(user.uid)
        .collection('companies')
        .get();
    for (final doc in indexSnap.docs) {
      final membership = _membershipFromMap(user.uid, doc.id, doc.data(), now);
      memberships[membership.companyId] = membership;
    }

    if (memberships.isEmpty) {
      await _recoverKnownLegacyMemberships(user, memberships);
    }

    if (memberships.isEmpty) {
      final staffQuery = await _legacyStaffLookup(user.uid);
      for (final doc in staffQuery.docs) {
        final companyId = doc.reference.parent.parent?.id;
        if (companyId == null) continue;
        final companyDoc = await _firestoreInstance
            .collection('companies')
            .doc(companyId)
            .get();
        final companyData = companyDoc.data() ?? const <String, dynamic>{};
        final membership = _membershipFromStaffMap(
          user.uid,
          companyId,
          companyData,
          doc.data(),
        );
        memberships[membership.companyId] = membership;
      }
    }

    final active = memberships.values.toList(growable: false);
    await _workspace.replaceMemberships(uid: user.uid, memberships: active);
    return active;
  }

  Future<void> switchActiveCompany({
    required AppUser user,
    required String companyId,
  }) async {
    final membership = await _workspace.readMembership(
      uid: user.uid,
      companyId: companyId,
    );
    if (membership == null) {
      throw StateError('You are not added to this company.');
    }
    if (!membership.isActive) {
      throw StateError('Your access to this company has been removed.');
    }
    await _workspace.setActiveCompany(uid: user.uid, companyId: companyId);
    await _workspace.upsertUserProfile(user, defaultCompanyId: companyId);
    if (_enableRemoteMetadata) {
      await _upsertRemoteUserProfile(user, defaultCompanyId: companyId);
      await _firestoreInstance
          .collection('user_company_memberships')
          .doc(user.uid)
          .collection('companies')
          .doc(companyId)
          .update({
        'lastAccessAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<ActiveWorkspace?> readActiveWorkspace(String uid) {
    return _workspace.readActiveWorkspace(uid);
  }

  Future<void> setActiveProject({
    required AppUser user,
    required String companyId,
    String? projectId,
  }) async {
    final policy = await _accessCache.readCachedPolicyForUidAndCompany(
      firebaseUid: user.uid,
      companyId: companyId,
    );
    if (projectId != null &&
        policy != null &&
        !policy.canAccessProject(projectId)) {
      throw StateError('You do not have permission for this project.');
    }
    await _workspace.setActiveProject(
      uid: user.uid,
      companyId: companyId,
      projectId: projectId,
    );
  }

  Future<StaffAccessPolicy> acceptInvitation({
    required AppUser user,
    required String companyId,
    required String inviteCode,
  }) {
    final normalizedCode = normalizeInvitationCode(inviteCode);
    if (normalizedCode.isEmpty) {
      throw ArgumentError('Invite code is required.');
    }
    return _acceptInvitationById(
      user: user,
      companyId: companyId,
      invitationId: hashInvitationCode(normalizedCode),
    );
  }

  Future<StaffAccessPolicy> acceptPendingInvitation({
    required AppUser user,
    required String companyId,
    required String invitationId,
  }) {
    return _acceptInvitationById(
      user: user,
      companyId: companyId,
      invitationId: invitationId,
    );
  }

  Future<StaffAccessPolicy> _acceptInvitationById({
    required AppUser user,
    required String companyId,
    required String invitationId,
  }) async {
    if (!_enableRemoteMetadata) {
      throw StateError('Invitation acceptance needs Firebase metadata access.');
    }
    final normalizedCompanyId = companyId.trim();
    if (normalizedCompanyId.isEmpty || invitationId.trim().isEmpty) {
      throw ArgumentError('Company ID and invite code are required.');
    }
    final companyRef =
        _firestoreInstance.collection('companies').doc(normalizedCompanyId);
    final invitationRef =
        companyRef.collection('invitations').doc(invitationId);
    final invitation = await invitationRef.get();
    if (!invitation.exists) {
      throw StateError('Invite not found. Check company ID and invite code.');
    }
    final invitationData = invitation.data()!;
    if (invitationData['status'] != 'pending') {
      throw StateError('This invite is no longer active.');
    }
    final expiresAt = _timestampMillis(invitationData['expiresAt']);
    if (expiresAt != null &&
        expiresAt < DateTime.now().millisecondsSinceEpoch) {
      throw StateError(
          'This invite has expired. Ask the owner to send a new invite.');
    }
    final invitedEmail = normalizeEmail(
      invitationData['normalizedEmail'] ?? invitationData['email'],
    );
    final userEmail = normalizeEmail(user.email);
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
      final latestExpiry = _timestampMillis(latestInvite.data()?['expiresAt']);
      if (latestExpiry != null &&
          latestExpiry < DateTime.now().millisecondsSinceEpoch) {
        throw StateError(
          'This invite has expired. Ask the owner to send a new invite.',
        );
      }
      if (!latestStaff.exists) {
        throw StateError('Invited staff record was not found.');
      }
      final staffData = latestStaff.data()!;
      final roleId = '${staffData['roleId'] ?? invitationData['roleId'] ?? ''}';
      final roleName =
          '${staffData['roleName'] ?? invitationData['roleName'] ?? roleId}';
      final assignedProjectIds = List<String>.from(
        staffData['assignedProjectIds'] ??
            invitationData['assignedProjectIds'] ??
            const <String>[],
      );
      final canAccessAllProjects =
          (staffData['canAccessAllProjects'] as bool?) ??
              (invitationData['canAccessAllProjects'] as bool?) ??
              false;
      final companyName = '${latestInvite.data()?['companyName'] ?? 'Company'}';
      transaction.update(invitationRef, {
        'status': 'accepted',
        'acceptedByUid': user.uid,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
          staffRef,
          {
            ...staffData,
            'staffId': staffId,
            'firebaseUid': user.uid,
            'email': user.email,
            'normalizedEmail': userEmail,
            'status': StaffStatus.active.storageKey,
            'invitationId': invitationId,
            'updatedAt': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
      transaction.update(invitedStaffRef, {
        'status': 'accepted',
        'acceptedByUid': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(companyRef.collection('members').doc(user.uid), {
        'uid': user.uid,
        'normalizedEmail': userEmail,
        'displayName': user.displayName ?? staffData['name'] ?? userEmail,
        'roleId': roleId,
        'roleName': roleName,
        'status': StaffStatus.active.storageKey,
        'isOwner': false,
        'joinedAt': FieldValue.serverTimestamp(),
        'invitedAt': latestInvite.data()?['createdAt'],
        'invitedByUid': latestInvite.data()?['invitedByUid'],
        'lastAccessAt': FieldValue.serverTimestamp(),
        'permissionsVersion': latestInvite.data()?['permissionsVersion'] ?? 1,
        'assignedProjectIds': assignedProjectIds,
        'canAccessAllProjects': canAccessAllProjects,
        'invitationId': invitationId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
        _firestoreInstance
            .collection('user_company_memberships')
            .doc(user.uid)
            .collection('companies')
            .doc(normalizedCompanyId),
        {
          'companyId': normalizedCompanyId,
          'companyName': companyName,
          'roleName': roleName,
          'roleId': roleId,
          'status': StaffStatus.active.storageKey,
          'isOwner': false,
          'canAccessAllProjects': canAccessAllProjects,
          'assignedProjectIds': assignedProjectIds,
          'lastAccessAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    });
    final acceptedStaff = await staffRef.get();
    final policy =
        await _policyFromStaffDocument(normalizedCompanyId, acceptedStaff);
    await _upsertCompanyLocal(normalizedCompanyId);
    await _upsertStaffLocal(policy.staff);
    await _accessCache.cacheAccessPolicy(policy);
    await _workspace.setActiveCompany(
        uid: user.uid, companyId: normalizedCompanyId);
    await registerCurrentDevice(policy);
    return policy;
  }

  Future<StaffAccessPolicy> acceptInvitationByCode({
    required AppUser user,
    required String inviteCode,
  }) async {
    final normalizedCode = normalizeInvitationCode(inviteCode);
    if (normalizedCode.isEmpty) {
      throw ArgumentError('Invite code is required.');
    }
    final QuerySnapshot<Map<String, dynamic>> matches;
    try {
      matches = await _firestoreInstance
          .collectionGroup('invitations')
          .where(
            'inviteCodeHash',
            isEqualTo: hashInvitationCode(normalizedCode),
          )
          .where('normalizedEmail', isEqualTo: normalizeEmail(user.email))
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
    } on FirebaseException catch (error, stackTrace) {
      if (isMissingInvitationLookupIndexError(error)) {
        logMissingInvitationLookupIndex(error, stackTrace: stackTrace);
      } else if (isFirestoreIndexSetupError(error)) {
        logFirestoreIndexSetupError(error, stackTrace: stackTrace);
      }
      rethrow;
    }
    if (matches.docs.isEmpty) {
      throw StateError('Invite not found. Check the invite code.');
    }
    final companyId = matches.docs.first.reference.parent.parent!.id;
    return _acceptInvitationById(
      user: user,
      companyId: companyId,
      invitationId: matches.docs.first.id,
    );
  }

  Future<List<PendingCompanyInvitation>> listPendingInvitations(
    AppUser user,
  ) async {
    if (!_enableRemoteMetadata) return const <PendingCompanyInvitation>[];
    final email = normalizeEmail(user.email);
    if (email.isEmpty) return const <PendingCompanyInvitation>[];
    final QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _firestoreInstance
          .collectionGroup('invitations')
          .where('normalizedEmail', isEqualTo: email)
          .where('status', isEqualTo: 'pending')
          .get();
    } on FirebaseException catch (error, stackTrace) {
      if (isMissingInvitationLookupIndexError(error)) {
        logMissingInvitationLookupIndex(error, stackTrace: stackTrace);
      } else if (isFirestoreIndexSetupError(error)) {
        logFirestoreIndexSetupError(error, stackTrace: stackTrace);
      }
      rethrow;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          return PendingCompanyInvitation(
            invitationId: doc.id,
            companyId: doc.reference.parent.parent?.id ?? '',
            companyName: '${data['companyName'] ?? 'Company'}',
            roleName: '${data['roleName'] ?? 'Staff'}',
            expiresAt: _timestampMillis(data['expiresAt']),
          );
        })
        .where((invite) =>
            invite.companyId.isNotEmpty &&
            (invite.expiresAt == null || invite.expiresAt! >= now))
        .toList(growable: false);
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
      canAccessAllProjects: true,
    );

    await _database.ensureSchema();
    await _database.transaction(() async {
      await _insertCompany(company);
      await _insertDefaultRolesAndPermissions(companyId, owner.uid, now);
      await _upsertStaffLocal(ownerStaff);
    });
    await _accessCache.cacheAccessPolicy(ownerPolicy);
    await _workspace.upsertUserProfile(owner, defaultCompanyId: companyId);
    await _workspace.setActiveCompany(uid: owner.uid, companyId: companyId);

    if (_enableRemoteMetadata) {
      await _upsertRemoteUserProfile(owner, defaultCompanyId: companyId);
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
    if (rows.isEmpty) return null;
    return _companyFromRow(rows.first);
  }

  Future<CompanyProfile?> readLocalCompany(String companyId) async {
    await _database.ensureSchema();
    final row = await _database.customSelect('''
      SELECT * FROM companies
      WHERE id = ? AND is_deleted = 0
      LIMIT 1;
      ''', variables: [Variable<String>(companyId)]).getSingleOrNull();
    return row == null ? null : _companyFromRow(row);
  }

  Future<void> updateCompanyProfile({
    required StaffAccessPolicy actorPolicy,
    required String companyName,
    String? gstNumber,
    String? panNumber,
    String? address,
    String? phone,
    String? email,
  }) async {
    actorPolicy.requirePermission(PermissionKey.staffManagement);
    final name = companyName.trim();
    if (name.isEmpty) {
      throw ArgumentError('Company name is required.');
    }
    final companyId = actorPolicy.staff.companyId;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.ensureSchema();
    final changed = await _database.customUpdate(
      '''
      UPDATE companies
      SET name = ?, gst_number = NULLIF(?, ''), pan_number = NULLIF(?, ''),
          address = NULLIF(?, ''), phone = NULLIF(?, ''),
          email = NULLIF(?, ''), updated_at = ?, updated_by_user_id = ?
      WHERE id = ? AND is_deleted = 0;
      ''',
      variables: [
        Variable<String>(name),
        Variable<String>(_blankToNull(gstNumber) ?? ''),
        Variable<String>(_blankToNull(panNumber) ?? ''),
        Variable<String>(_blankToNull(address) ?? ''),
        Variable<String>(_blankToNull(phone) ?? ''),
        Variable<String>(_blankToNull(email) ?? ''),
        Variable<int>(now),
        Variable<String>(actorPolicy.staff.firebaseUid ?? actorPolicy.staff.id),
        Variable<String>(companyId),
      ],
    );
    if (changed != 1) throw StateError('Company details were not found.');
    await _firestoreInstance.collection('companies').doc(companyId).update({
      'name': name,
      'companyName': name,
      'gstNumber': _blankToNull(gstNumber),
      'panNumber': _blankToNull(panNumber),
      'address': _blankToNull(address),
      'phone': _blankToNull(phone),
      'email': _blankToNull(email),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<StaffAccessPolicy?> _fetchPolicyFromFirestore(
    AppUser user, {
    String? companyId,
  }) async {
    if (companyId != null) {
      final companyRef =
          _firestoreInstance.collection('companies').doc(companyId);
      final memberDoc =
          await companyRef.collection('members').doc(user.uid).get();
      if (memberDoc.exists) {
        final staffDoc = await _staffDocumentForMember(companyId, user.uid);
        if (staffDoc != null) {
          return _policyFromStaffDocument(
            companyId,
            staffDoc,
            memberData: memberDoc.data(),
          );
        }
        return _policyFromMembershipDocument(companyId, memberDoc);
      }
      final staffSnap = await companyRef
          .collection('staff')
          .where('firebaseUid', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (staffSnap.docs.isNotEmpty) {
        return _policyFromStaffDocument(companyId, staffSnap.docs.first);
      }
      return null;
    }

    final owned = await _firestoreInstance
        .collection('companies')
        .where('ownerUid', isEqualTo: user.uid)
        .limit(1)
        .get();
    if (owned.docs.isNotEmpty) {
      final ownedCompanyId = owned.docs.first.id;
      final staffSnap = await _firestoreInstance
          .collection('companies')
          .doc(ownedCompanyId)
          .collection('staff')
          .where('firebaseUid', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (staffSnap.docs.isNotEmpty) {
        return _policyFromStaffDocument(ownedCompanyId, staffSnap.docs.first);
      }
    }

    final staffQuery = await _legacyStaffLookup(user.uid, limit: 1);
    if (staffQuery.docs.isEmpty) return null;
    final staffDoc = staffQuery.docs.first;
    final fetchedCompanyId = staffDoc.reference.parent.parent!.id;
    return _policyFromStaffDocument(fetchedCompanyId, staffDoc);
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _legacyStaffLookup(
    String uid, {
    int? limit,
  }) async {
    try {
      var query = _firestoreInstance
          .collectionGroup('staff')
          .where('firebaseUid', isEqualTo: uid);
      if (limit != null) query = query.limit(limit);
      return await query.get();
    } on FirebaseException catch (error, stackTrace) {
      if (isMissingStaffLookupIndexError(error)) {
        logMissingStaffLookupIndex(error, stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<void> _recoverKnownLegacyMemberships(
    AppUser user,
    Map<String, CompanyMembership> memberships,
  ) async {
    final workspace = await _workspace.readActiveWorkspace(user.uid);
    final knownCompanyId = workspace?.activeCompanyId;
    if (knownCompanyId != null && knownCompanyId.isNotEmpty) {
      final staff = await _firestoreInstance
          .collection('companies')
          .doc(knownCompanyId)
          .collection('staff')
          .where('firebaseUid', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (staff.docs.isNotEmpty) {
        final localCompany = await readLocalCompany(knownCompanyId);
        final companyData = <String, dynamic>{
          'name': localCompany?.name ?? 'Company',
          'companyName': localCompany?.name ?? 'Company',
        };
        final membership = _membershipFromStaffMap(
          user.uid,
          knownCompanyId,
          companyData,
          staff.docs.first.data(),
        );
        memberships[knownCompanyId] = membership;
      }
    }

    final ownedCompanies = await _firestoreInstance
        .collection('companies')
        .where('ownerUid', isEqualTo: user.uid)
        .get();
    for (final company in ownedCompanies.docs) {
      if (memberships.containsKey(company.id)) continue;
      final staff = await company.reference
          .collection('staff')
          .where('firebaseUid', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (staff.docs.isEmpty) continue;
      final membership = _membershipFromStaffMap(
        user.uid,
        company.id,
        company.data(),
        staff.docs.first.data(),
      );
      memberships[company.id] = membership;
    }
  }

  Future<StaffAccessPolicy> _policyFromStaffDocument(
    String companyId,
    DocumentSnapshot<Map<String, dynamic>> staffDoc, {
    Map<String, dynamic>? memberData,
  }) async {
    final data = staffDoc.data()!;
    final roleId = (memberData?['roleId'] ?? data['roleId']) as String?;
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
        if (permission == null) continue;
        if (entry.value == true) {
          mergedPermissions.add(permission);
        } else if (entry.value == false) {
          mergedPermissions.remove(permission);
        }
      }
    }

    final assigned =
        memberData?['assignedProjectIds'] ?? data['assignedProjectIds'];
    final assignedProjectIds = assigned is Iterable
        ? assigned.map((item) => '$item').toSet()
        : <String>{};
    final canAccessAllProjects = memberData?['canAccessAllProjects'] == true ||
        data['canAccessAllProjects'] == true ||
        roleType == RoleType.owner ||
        roleType == RoleType.admin;
    final status = memberData?['status'] ?? data['status'];
    final staff = StaffProfile(
      id: data['staffId'] as String? ?? staffDoc.id,
      companyId: companyId,
      name: (data['name'] as String?) ??
          (data['displayName'] as String?) ??
          'Staff User',
      firebaseUid: data['firebaseUid'] as String?,
      email: data['email'] as String?,
      phone: data['phone'] as String?,
      roleId: roleId,
      roleType: roleType,
      status: StaffProfile.statusFromStorage(status as String?),
      lastLoginAt: _timestampMillis(data['lastLoginAt']),
      lastSyncAt: _timestampMillis(data['lastSyncAt']),
    );
    return StaffAccessPolicy(
      staff: staff,
      allowedPermissions: mergedPermissions,
      assignedProjectIds: assignedProjectIds,
      canAccessAllProjects: canAccessAllProjects,
    );
  }

  Future<StaffAccessPolicy> _policyFromMembershipDocument(
    String companyId,
    DocumentSnapshot<Map<String, dynamic>> memberDoc,
  ) async {
    final data = memberDoc.data()!;
    final roleId = data['roleId'] as String?;
    final roleType = StaffProfile.roleTypeFromStorage(roleId);
    final permissions = roleType == null
        ? <PermissionKey>{}
        : DefaultRolePermissions.permissionsFor(roleType);
    final assigned = data['assignedProjectIds'];
    final status = StaffProfile.statusFromStorage(data['status'] as String?);
    final staff = StaffProfile(
      id: memberDoc.id,
      companyId: companyId,
      name: data['displayName'] as String? ?? 'Staff User',
      firebaseUid: memberDoc.id,
      email: data['normalizedEmail'] as String?,
      roleId: roleId,
      roleType: roleType,
      status: status,
      lastLoginAt: _timestampMillis(data['lastAccessAt']),
      lastSyncAt: _timestampMillis(data['updatedAt']),
    );
    return StaffAccessPolicy(
      staff: staff,
      allowedPermissions: permissions,
      assignedProjectIds: assigned is Iterable
          ? assigned.map((item) => '$item').toSet()
          : <String>{},
      canAccessAllProjects: data['canAccessAllProjects'] == true ||
          roleType == RoleType.owner ||
          roleType == RoleType.admin,
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _staffDocumentForMember(
    String companyId,
    String uid,
  ) async {
    final byId = await _firestoreInstance
        .collection('companies')
        .doc(companyId)
        .collection('staff')
        .doc(uid)
        .get();
    if (byId.exists) return byId;
    final query = await _firestoreInstance
        .collection('companies')
        .doc(companyId)
        .collection('staff')
        .where('firebaseUid', isEqualTo: uid)
        .limit(1)
        .get();
    return query.docs.firstOrNull;
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
      'companyName': company.name,
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

    final normalizedEmail = normalizeEmail(ownerStaff.email);
    final ownerMemberData = {
      'uid': ownerStaff.firebaseUid,
      'normalizedEmail': normalizedEmail,
      'displayName': ownerStaff.name,
      'roleId': ownerStaff.roleId,
      'roleName': 'Owner',
      'status': StaffStatus.active.storageKey,
      'isOwner': true,
      'joinedAt': FieldValue.serverTimestamp(),
      'invitedAt': FieldValue.serverTimestamp(),
      'invitedByUid': ownerStaff.firebaseUid,
      'lastAccessAt': FieldValue.serverTimestamp(),
      'permissionsVersion': 1,
      'assignedProjectIds': <String>[],
      'canAccessAllProjects': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    batch.set(companyRef.collection('staff').doc(ownerStaff.id), {
      'staffId': ownerStaff.id,
      'firebaseUid': ownerStaff.firebaseUid,
      'companyId': ownerStaff.companyId,
      'name': ownerStaff.name,
      'displayName': ownerStaff.name,
      'email': ownerStaff.email,
      'normalizedEmail': normalizedEmail,
      'phone': ownerStaff.phone,
      'roleId': ownerStaff.roleId,
      'roleName': 'Owner',
      'status': ownerStaff.status.storageKey,
      'assignedProjectIds': <String>[],
      'canAccessAllProjects': true,
      'permissionsOverride': null,
      'permissionsVersion': 1,
      'invitedByUid': ownerStaff.firebaseUid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'lastSyncAt': FieldValue.serverTimestamp(),
    });
    batch.set(
        companyRef
            .collection('members')
            .doc(ownerStaff.firebaseUid ?? ownerStaff.id),
        ownerMemberData);
    batch.set(
      _firestoreInstance
          .collection('user_company_memberships')
          .doc(ownerStaff.firebaseUid ?? ownerStaff.id)
          .collection('companies')
          .doc(company.id),
      {
        'companyId': company.id,
        'companyName': company.name,
        'roleName': 'Owner',
        'roleId': ownerStaff.roleId,
        'status': StaffStatus.active.storageKey,
        'isOwner': true,
        'canAccessAllProjects': true,
        'assignedProjectIds': <String>[],
        'lastAccessAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

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

  Future<void> _upsertRemoteUserProfile(
    AppUser user, {
    String? defaultCompanyId,
  }) async {
    final profileRef = _firestoreInstance.collection('app_users').doc(user.uid);
    await _firestoreInstance.runTransaction((transaction) async {
      final existing = await transaction.get(profileRef);
      if (existing.exists && existing.data()?['status'] == 'blocked') {
        throw StateError(
          'This account has been blocked. Please contact the company owner or support.',
        );
      }
      final mutableFields = <String, dynamic>{
        'uid': user.uid,
        'normalizedEmail': normalizeEmail(user.email),
        'displayName': user.displayName,
        'photoUrl': user.photoUrl,
        'phone': user.phoneNumber,
        'lastLoginAt': FieldValue.serverTimestamp(),
        'linkedProviders': user.linkedProviders,
        if (defaultCompanyId != null) 'defaultCompanyId': defaultCompanyId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (existing.exists) {
        transaction.update(profileRef, mutableFields);
      } else {
        transaction.set(profileRef, {
          ...mutableFields,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> _upsertCompanyLocal(String companyId) async {
    await _database.ensureSchema();
    final companyDoc =
        await _firestoreInstance.collection('companies').doc(companyId).get();
    if (!companyDoc.exists) return;
    final data = companyDoc.data()!;
    final now = DateTime.now().millisecondsSinceEpoch;
    final company = CompanyProfile(
      id: companyId,
      name: (data['name'] as String?) ??
          (data['companyName'] as String?) ??
          'Company',
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

  CompanyProfile _companyFromRow(QueryRow row) {
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
      ownerUid: row.readNullable<String>('created_by_user_id'),
      createdAt: row.read<int>('created_at'),
      updatedAt: row.read<int>('updated_at'),
    );
  }

  CompanyMembership _membershipFromMap(
    String uid,
    String companyId,
    Map<String, dynamic> data,
    int fallbackUpdatedAt,
  ) {
    final assigned = data['assignedProjectIds'];
    return CompanyMembership(
      id: '${uid}_$companyId',
      uid: uid,
      companyId: companyId,
      companyName: data['companyName'] as String? ?? 'Company',
      roleId: data['roleId'] as String?,
      roleName: data['roleName'] as String?,
      status: data['status'] as String? ?? 'active',
      isOwner: data['isOwner'] == true,
      canAccessAllProjects: data['canAccessAllProjects'] == true,
      assignedProjectIds: assigned is Iterable
          ? assigned.map((item) => '$item').toList(growable: false)
          : const <String>[],
      lastAccessAt: _timestampMillis(data['lastAccessAt']),
      updatedAt: _timestampMillis(data['updatedAt']) ?? fallbackUpdatedAt,
    );
  }

  CompanyMembership _membershipFromStaffMap(
    String uid,
    String companyId,
    Map<String, dynamic> companyData,
    Map<String, dynamic> staffData,
  ) {
    final roleId = staffData['roleId'] as String?;
    final roleType = StaffProfile.roleTypeFromStorage(roleId);
    final assigned = staffData['assignedProjectIds'];
    return CompanyMembership(
      id: '${uid}_$companyId',
      uid: uid,
      companyId: companyId,
      companyName: (companyData['name'] as String?) ??
          (companyData['companyName'] as String?) ??
          'Company',
      roleId: roleId,
      roleName: staffData['roleName'] as String? ??
          (roleType == null
              ? roleId
              : DefaultRolePermissions.roleName(roleType)),
      status: staffData['status'] as String? ?? 'active',
      isOwner: roleType == RoleType.owner,
      canAccessAllProjects: staffData['canAccessAllProjects'] == true ||
          roleType == RoleType.owner ||
          roleType == RoleType.admin,
      assignedProjectIds: assigned is Iterable
          ? assigned.map((item) => '$item').toList(growable: false)
          : const <String>[],
      lastAccessAt: _timestampMillis(staffData['lastLoginAt']),
      updatedAt: _timestampMillis(staffData['updatedAt']) ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  int? _timestampMillis(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is int) return value;
    return null;
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}

class PendingCompanyInvitation {
  const PendingCompanyInvitation({
    required this.invitationId,
    required this.companyId,
    required this.companyName,
    required this.roleName,
    required this.expiresAt,
  });

  final String invitationId;
  final String companyId;
  final String companyName;
  final String roleName;
  final int? expiresAt;
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;

  T? firstWhereOrNull(bool Function(T item) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}
