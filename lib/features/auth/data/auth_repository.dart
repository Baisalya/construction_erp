import '../domain/auth_module_contract.dart';

class AuthRepository implements AuthModuleContract {
  const AuthRepository();

  @override
  String get moduleName => 'Auth';

  @override
  String get phase1Responsibility =>
      'Authentication and company setup foundation';
}
