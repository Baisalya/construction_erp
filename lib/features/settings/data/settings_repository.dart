import '../domain/settings_module_contract.dart';

class SettingsRepository implements SettingsModuleContract {
  const SettingsRepository();

  @override
  String get moduleName => 'Settings';

  @override
  String get phase1Responsibility =>
      'Company settings, financial year, backup, and local preferences foundation';
}
