import '../../core/constants/app_module.dart';
import '../../database/local_database.dart';
import '../domain/module_summary.dart';

class ModuleSummaryRepository {
  const ModuleSummaryRepository({required this.database});

  final ConstructionDatabase database;

  Future<List<ModuleSummary>> loadDashboardSummaries() async {
    await database.ensureSchema();
    final summaries = <ModuleSummary>[];
    for (final module
        in AppModule.values.where((module) => module != AppModule.dashboard)) {
      summaries.add(await loadModuleSummary(module));
    }
    return summaries;
  }

  Future<ModuleSummary> loadModuleSummary(AppModule module) async {
    final count = await database.countRows(module.primaryTableName);
    return ModuleSummary(
      module: module,
      count: count,
      label: count == 0 ? 'No entries yet' : '$count records',
      description: module.simpleDescription,
    );
  }
}
