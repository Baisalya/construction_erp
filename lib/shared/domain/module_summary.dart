import '../../core/constants/app_module.dart';

class ModuleSummary {
  const ModuleSummary({
    required this.module,
    required this.count,
    required this.label,
    required this.description,
  });

  factory ModuleSummary.empty(AppModule module) {
    return ModuleSummary(
      module: module,
      count: 0,
      label: 'Ready',
      description: module.simpleDescription,
    );
  }

  final AppModule module;
  final int count;
  final String label;
  final String description;
}
