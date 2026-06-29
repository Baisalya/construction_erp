import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'schema/app_schema_sql.dart';

class ConstructionDatabase extends GeneratedDatabase {
  ConstructionDatabase(super.executor);

  bool _schemaReady = false;

  @override
  int get schemaVersion => AppSchemaSql.schemaVersion;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      const <TableInfo<Table, Object?>>[];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      const <DatabaseSchemaEntity>[];

  /// Accepts Drift [Variable] values used by the repository layer and unwraps
  /// them before they reach sqlite3, whose statement API expects raw values.
  /// Query bindings still use [Variable] directly through [customSelect].
  @override
  Future<void> customStatement(String statement, [List<dynamic>? args]) {
    final rawArgs = args
        ?.map((argument) => argument is Variable ? argument.value : argument)
        .toList(growable: false);
    return super.customStatement(statement, rawArgs);
  }

  Future<void> ensureSchema() async {
    if (_schemaReady) {
      return;
    }
    for (final pragma in AppSchemaSql.pragmas) {
      await customStatement(pragma);
    }
    final versionRow = await customSelect('PRAGMA user_version;').getSingle();
    final storedVersion = versionRow.read<int>('user_version');
    if (storedVersion > AppSchemaSql.schemaVersion) {
      throw StateError(
          'Database version $storedVersion is newer than supported version '
          '${AppSchemaSql.schemaVersion}.');
    }
    await transaction(() async {
      for (final statement in AppSchemaSql.createTables) {
        await customStatement(statement);
      }
      for (final statement in AppSchemaSql.createIndexes) {
        await customStatement(statement);
      }
      // Set this only after every schema statement succeeds so a failed setup
      // is never reported as a completed migration.
      await customStatement(
          'PRAGMA user_version = ${AppSchemaSql.schemaVersion};');
    });
    _schemaReady = true;
  }

  Future<int> countRows(String tableName) async {
    _assertKnownTable(tableName);
    await ensureSchema();
    final result = await customSelect(
            'SELECT COUNT(*) AS total FROM $tableName WHERE is_deleted = 0;')
        .getSingle();
    return result.read<int>('total');
  }

  Future<int> countRowsWhere(String tableName, String safeWhereClause) async {
    _assertKnownTable(tableName);
    await ensureSchema();
    final result = await customSelect(
      'SELECT COUNT(*) AS total FROM $tableName WHERE is_deleted = 0 AND ($safeWhereClause);',
    ).getSingle();
    return result.read<int>('total');
  }

  void _assertKnownTable(String tableName) {
    if (!AppSchemaSql.tableNames.contains(tableName)) {
      throw ArgumentError.value(
          tableName, 'tableName', 'Unknown local database table.');
    }
  }
}

QueryExecutor openConstructionDatabaseConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    final file = File(path.join(directory.path, 'construction_erp.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
