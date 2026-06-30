import '../../../core/permissions/role_type.dart';
import '../../../core/permissions/staff_status.dart';

class StaffProfile {
  const StaffProfile({
    required this.id,
    required this.companyId,
    required this.name,
    required this.status,
    this.firebaseUid,
    this.phone,
    this.email,
    this.roleId,
    this.roleType,
    this.lastLoginAt,
    this.lastSyncAt,
  });

  final String id;
  final String companyId;
  final String name;
  final String? firebaseUid;
  final String? phone;
  final String? email;
  final String? roleId;
  final RoleType? roleType;
  final StaffStatus status;
  final int? lastLoginAt;
  final int? lastSyncAt;

  bool get canUseCompanyData => status == StaffStatus.active;

  bool get isOwner =>
      roleType == RoleType.owner || roleId == RoleType.owner.storageKey;

  bool get isAdmin =>
      roleType == RoleType.admin || roleId == RoleType.admin.storageKey;

  StaffProfile copyWith({
    String? id,
    String? companyId,
    String? name,
    String? firebaseUid,
    String? phone,
    String? email,
    String? roleId,
    RoleType? roleType,
    StaffStatus? status,
    int? lastLoginAt,
    int? lastSyncAt,
  }) {
    return StaffProfile(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      roleId: roleId ?? this.roleId,
      roleType: roleType ?? this.roleType,
      status: status ?? this.status,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }

  static StaffStatus statusFromStorage(String? value) {
    return switch (value) {
      'active' => StaffStatus.active,
      'inactive' => StaffStatus.inactive,
      'revoked' => StaffStatus.revoked,
      'invited' => StaffStatus.invited,
      _ => StaffStatus.invited,
    };
  }

  static RoleType? roleTypeFromStorage(String? value) {
    return switch (value) {
      'owner' => RoleType.owner,
      'admin' => RoleType.admin,
      'accountant' => RoleType.accountant,
      'projectManager' => RoleType.projectManager,
      'siteSupervisor' => RoleType.siteSupervisor,
      'dataEntryStaff' => RoleType.dataEntryStaff,
      'viewer' => RoleType.viewer,
      _ => null,
    };
  }
}
