import '../domain/staff_module_contract.dart';

class StaffRepository implements StaffModuleContract {
  const StaffRepository();

  @override
  String get moduleName => 'Staff';

  @override
  String get phase1Responsibility =>
      'Staff roles, permissions, invitations, and access cache foundation';
}
