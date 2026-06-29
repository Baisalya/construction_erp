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
    };
  }
}
