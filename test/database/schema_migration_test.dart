import 'package:construction_erp/database/local_database.dart';
import 'package:construction_erp/database/schema/app_schema_sql.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('current schema setup is complete and idempotent', () async {
    final database = ConstructionDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database.ensureSchema();
    await database.ensureSchema();

    final version =
        await database.customSelect('PRAGMA user_version;').getSingle();
    expect(version.read<int>('user_version'), AppSchemaSql.schemaVersion);

    final rows = await database.customSelect('''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table' AND name NOT LIKE 'sqlite_%';
    ''').get();
    final actualTables = rows.map((row) => row.read<String>('name')).toSet();
    expect(actualTables, containsAll(AppSchemaSql.tableNames));
    expect(actualTables.length, AppSchemaSql.tableNames.length);
  });

  test('version 1 sync queue migrates to version 2 without data loss',
      () async {
    final database = ConstructionDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.customStatement('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        created_by_user_id TEXT,
        updated_by_user_id TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'localOnly',
        version INTEGER NOT NULL DEFAULT 1,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        device_id TEXT NOT NULL,
        schema_version INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pendingUpload',
        error_message TEXT
      )
    ''');
    await database.customStatement('''
      INSERT INTO sync_queue (
        id, company_id, created_at, updated_at, entity_type, entity_id,
        operation, payload_json, device_id, schema_version
      ) VALUES ('old-delta', 'company-1', 1, 1, 'projects', 'project-1',
        'insert', '{}', 'device-1', 1)
    ''');
    await database.customStatement('PRAGMA user_version = 1');

    await database.ensureSchema();

    final columns =
        await database.customSelect('PRAGMA table_info(sync_queue)').get();
    final names = columns.map((row) => row.read<String>('name')).toSet();
    expect(names, containsAll({'base_version', 'new_version'}));
    final row = await database
        .customSelect(
          "SELECT id, base_version, new_version FROM sync_queue WHERE id = 'old-delta'",
        )
        .getSingle();
    expect(row.read<String>('id'), 'old-delta');
    expect(row.read<int>('base_version'), 0);
    expect(row.read<int>('new_version'), 1);
  });

  test('version 2 conflicts migrate to version 3 without data loss', () async {
    final database = ConstructionDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.customStatement('''
      CREATE TABLE sync_conflicts (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        created_by_user_id TEXT,
        updated_by_user_id TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'conflict',
        version INTEGER NOT NULL DEFAULT 1,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        local_payload_json TEXT NOT NULL,
        remote_payload_json TEXT NOT NULL,
        local_version INTEGER NOT NULL,
        remote_version INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'open',
        resolved_by_user_id TEXT,
        resolved_at INTEGER,
        resolution TEXT
      )
    ''');
    await database.customStatement('''
      INSERT INTO sync_conflicts (
        id, company_id, created_at, updated_at, entity_type, entity_id,
        local_payload_json, remote_payload_json, local_version, remote_version
      ) VALUES ('d1_conflict', 'company-1', 1, 1, 'projects', 'p1',
        '{}', '{}', 1, 2)
    ''');
    await database.customStatement('PRAGMA user_version = 2');

    await database.ensureSchema();

    final columns =
        await database.customSelect('PRAGMA table_info(sync_conflicts)').get();
    final names = columns.map((row) => row.read<String>('name')).toSet();
    expect(names, containsAll({'remote_delta_id', 'remote_operation'}));
    expect(await database.countRows('sync_conflicts'), 1);
  });

  test('all tenant business tables contain company and audit columns',
      () async {
    final database = ConstructionDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.ensureSchema();

    const auditColumns = {
      'created_at',
      'updated_at',
      'created_by_user_id',
      'updated_by_user_id',
      'is_deleted',
      'sync_status',
      'version',
    };
    for (final table in AppSchemaSql.tableNames) {
      final columns =
          await database.customSelect('PRAGMA table_info($table);').get();
      final names = columns.map((row) => row.read<String>('name')).toSet();
      expect(names, containsAll(auditColumns), reason: '$table audit columns');
      if (table != 'companies') {
        expect(names, contains('company_id'), reason: '$table tenant column');
      }
    }
  });
}
