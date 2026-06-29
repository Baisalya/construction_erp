enum RoleType {
  owner,
  admin,
  accountant,
  projectManager,
  siteSupervisor,
  dataEntryStaff,
  viewer,
}

extension RoleTypeX on RoleType {
  String get storageKey {
    return switch (this) {
      RoleType.owner => 'owner',
      RoleType.admin => 'admin',
      RoleType.accountant => 'accountant',
      RoleType.projectManager => 'projectManager',
      RoleType.siteSupervisor => 'siteSupervisor',
      RoleType.dataEntryStaff => 'dataEntryStaff',
      RoleType.viewer => 'viewer',
    };
  }
}
