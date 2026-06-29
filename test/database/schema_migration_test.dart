import 'package:construction_erp_phase5/database/local_database.dart';
import 'package:construction_erp_phase5/database/schema/app_schema_sql.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('version 1 schema migration is complete and idempotent', () async {
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
