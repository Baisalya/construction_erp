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
  final StaffStatus status;
  final int? lastLoginAt;
  final int? lastSyncAt;

  bool get canUseCompanyData => status == StaffStatus.active;
}
