enum PermissionKey {
  tenderCreate,
  tenderEdit,
  tenderDelete,
  projectCreate,
  projectEdit,
  projectDelete,
  materialEntry,
  laborEntry,
  machineryEntry,
  billingEntry,
  gstReports,
  staffManagement,
  exportReports,
  viewOnlyProjectAccess,
  settingsManage,
}

extension PermissionKeyX on PermissionKey {
  String get storageKey {
    return switch (this) {
      PermissionKey.tenderCreate => 'tender.create',
      PermissionKey.tenderEdit => 'tender.edit',
      PermissionKey.tenderDelete => 'tender.delete',
      PermissionKey.projectCreate => 'project.create',
      PermissionKey.projectEdit => 'project.edit',
      PermissionKey.projectDelete => 'project.delete',
      PermissionKey.materialEntry => 'material.entry',
      PermissionKey.laborEntry => 'labor.entry',
      PermissionKey.machineryEntry => 'machinery.entry',
      PermissionKey.billingEntry => 'billing.entry',
      PermissionKey.gstReports => 'reports.gst',
      PermissionKey.staffManagement => 'staff.manage',
      PermissionKey.exportReports => 'reports.export',
      PermissionKey.viewOnlyProjectAccess => 'project.view_only',
      PermissionKey.settingsManage => 'settings.manage',
    };
  }

  String get simpleLabel {
    return switch (this) {
      PermissionKey.tenderCreate => 'Can add tender',
      PermissionKey.tenderEdit => 'Can edit tender',
      PermissionKey.tenderDelete => 'Can delete tender',
      PermissionKey.projectCreate => 'Can create project',
      PermissionKey.projectEdit => 'Can edit project',
      PermissionKey.projectDelete => 'Can delete project',
      PermissionKey.materialEntry => 'Can enter material',
      PermissionKey.laborEntry => 'Can enter labor',
      PermissionKey.machineryEntry => 'Can enter machinery',
      PermissionKey.billingEntry => 'Can enter billing',
      PermissionKey.gstReports => 'Can view GST report',
      PermissionKey.staffManagement => 'Can manage staff',
      PermissionKey.exportReports => 'Can export reports',
      PermissionKey.viewOnlyProjectAccess => 'Can view assigned project only',
      PermissionKey.settingsManage => 'Can manage settings',
    };
  }
}

PermissionKey? permissionKeyFromStorageKey(String storageKey) {
  for (final permission in PermissionKey.values) {
    if (permission.storageKey == storageKey) {
      return permission;
    }
  }
  return null;
}

Set<PermissionKey> permissionSetFromJsonMap(Map<String, dynamic> json) {
  final permissions = <PermissionKey>{};
  for (final entry in json.entries) {
    if (entry.value == true) {
      final permission = permissionKeyFromStorageKey(entry.key);
      if (permission != null) {
        permissions.add(permission);
      }
    }
  }
  return permissions;
}

Map<String, bool> permissionSetToJsonMap(Set<PermissionKey> permissions) {
  return {
    for (final permission in PermissionKey.values)
      permission.storageKey: permissions.contains(permission),
  };
}
