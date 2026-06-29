enum StaffStatus {
  active,
  inactive,
  revoked,
  invited,
}

extension StaffStatusX on StaffStatus {
  String get storageKey {
    return switch (this) {
      StaffStatus.active => 'active',
      StaffStatus.inactive => 'inactive',
      StaffStatus.revoked => 'revoked',
      StaffStatus.invited => 'invited',
    };
  }
}
