import '../../../core/permissions/permission_key.dart';
import '../../../core/permissions/role_type.dart';

class DefaultRolePermissions {
  const DefaultRolePermissions._();

  static const orderedRoles = <RoleType>[
    RoleType.owner,
    RoleType.admin,
    RoleType.accountant,
    RoleType.projectManager,
    RoleType.siteSupervisor,
    RoleType.dataEntryStaff,
    RoleType.viewer,
  ];

  static String roleName(RoleType role) {
    return switch (role) {
      RoleType.owner => 'Owner',
      RoleType.admin => 'Admin',
      RoleType.accountant => 'Accountant',
      RoleType.projectManager => 'Project Manager',
      RoleType.siteSupervisor => 'Site Supervisor',
      RoleType.dataEntryStaff => 'Data Entry Staff',
      RoleType.viewer => 'Viewer',
    };
  }

  static String roleDescription(RoleType role) {
    return switch (role) {
      RoleType.owner => 'Company owner with every permission.',
      RoleType.admin => 'Can manage company work and staff.',
      RoleType.accountant => 'Billing, GST, payments, and report access.',
      RoleType.projectManager => 'Can manage assigned project work.',
      RoleType.siteSupervisor => 'Can enter daily site work entries.',
      RoleType.dataEntryStaff =>
        'Can add limited entries without delete/export.',
      RoleType.viewer => 'Read-only assigned project access.',
    };
  }

  static Set<PermissionKey> permissionsFor(RoleType role) {
    return switch (role) {
      RoleType.owner => PermissionKey.values.toSet(),
      RoleType.admin => PermissionKey.values.toSet(),
      RoleType.accountant => {
          PermissionKey.materialEntry,
          PermissionKey.billingEntry,
          PermissionKey.gstReports,
          PermissionKey.exportReports,
        },
      RoleType.projectManager => {
          PermissionKey.tenderEdit,
          PermissionKey.projectEdit,
          PermissionKey.materialEntry,
          PermissionKey.laborEntry,
          PermissionKey.machineryEntry,
          PermissionKey.billingEntry,
        },
      RoleType.siteSupervisor => {
          PermissionKey.materialEntry,
          PermissionKey.laborEntry,
          PermissionKey.machineryEntry,
        },
      RoleType.dataEntryStaff => {
          PermissionKey.materialEntry,
          PermissionKey.laborEntry,
          PermissionKey.machineryEntry,
          PermissionKey.billingEntry,
        },
      RoleType.viewer => {
          PermissionKey.viewOnlyProjectAccess,
        },
    };
  }
}
