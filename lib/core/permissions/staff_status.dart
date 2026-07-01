enum StaffStatus {
  active,
  inactive,
  suspended,
  revoked,
  invited,
}

extension StaffStatusX on StaffStatus {
  String get storageKey {
    return switch (this) {
      StaffStatus.active => 'active',
      StaffStatus.inactive => 'inactive',
      StaffStatus.suspended => 'suspended',
      StaffStatus.revoked => 'revoked',
      StaffStatus.invited => 'invited',
    };
  }
}
