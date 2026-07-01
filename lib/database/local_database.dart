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
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (_) async {
          await transaction(() => _applySchemaChanges(0));
        },
        onUpgrade: (_, from, to) async {
          if (from > to) {
            throw StateError(
              'Database downgrade from version $from to $to is not supported. '
              'Install a newer app version to keep the local ERP data safe.',
            );
          }
          await transaction(() => _applySchemaChanges(from));
        },
        beforeOpen: (_) async {
          for (final pragma in AppSchemaSql.pragmas) {
            await customStatement(pragma);
          }
          _schemaReady = true;
        },
      );

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

    // The first statement opens the connection. Drift then runs [migration]
    // before this query is executed, including upgrades of existing installs.
    await customSelect('SELECT 1 AS schema_ready;').getSingle();
  }

  Future<void> _applySchemaChanges(int storedVersion) async {
    for (final statement in AppSchemaSql.createTables) {
      await customStatement(statement);
    }
    if (storedVersion < 2) {
      await _addColumnIfMissing(
        'sync_queue',
        'base_version',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        'sync_queue',
        'new_version',
        'INTEGER NOT NULL DEFAULT 1',
      );
    }
    if (storedVersion < 3) {
      await _addColumnIfMissing(
        'sync_conflicts',
        'remote_delta_id',
        'TEXT',
      );
      await _addColumnIfMissing(
        'sync_conflicts',
        'remote_operation',
        'TEXT',
      );
    }

    if (storedVersion < 4) {
      await _addColumnIfMissing(
        'project_staff_assignments',
        'firebase_uid',
        'TEXT',
      );
      await _addColumnIfMissing(
        'project_staff_assignments',
        'role_id',
        'TEXT',
      );
      await _addColumnIfMissing(
        'project_staff_assignments',
        'can_create_entries',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        'project_staff_assignments',
        'status',
        "TEXT NOT NULL DEFAULT 'active'",
      );
      await _addColumnIfMissing(
        'staff_access_cache',
        'can_access_all_projects',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        'sync_queue',
        'project_id',
        'TEXT',
      );
    }
    if (storedVersion < 5) {
      await _addColumnIfMissing(
        'sync_conflicts',
        'project_id',
        'TEXT',
      );
    }
    for (final statement in AppSchemaSql.createIndexes) {
      await customStatement(statement);
    }
  }

  Future<void> _addColumnIfMissing(
    String table,
    String column,
    String declaration,
  ) async {
    final columns = await customSelect('PRAGMA table_info($table);').get();
    final exists = columns.any((row) => row.data['name'] == column);
    if (!exists) {
      await customStatement(
          'ALTER TABLE $table ADD COLUMN $column $declaration;');
    }
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
