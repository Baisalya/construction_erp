import 'package:drift/drift.dart';

import '../../core/domain/write_context.dart';
import '../../core/permissions/permission_key.dart';
import '../../core/permissions/repository_write_guard.dart';
import '../../database/local_database.dart';
import '../../sync/data/local_delta_writer.dart';

class LocalRecordMaintenanceRepository {
  LocalRecordMaintenanceRepository(
      {required this.database,
      RepositoryWriteGuard writeGuard = const AllowAllRepositoryWriteGuard()})
      : _writeGuard = writeGuard;

  final ConstructionDatabase database;
  final RepositoryWriteGuard _writeGuard;

  static const _deletable = {
    'material_purchases',
    'labor_work_entries',
    'machine_usage_entries',
    'machine_repair_entries',
  };

  Future<void> softDelete(String table, String id, WriteContext context) async {
    _writeGuard.require(_permissionForTable(table));
    if (!_deletable.contains(table)) {
      throw ArgumentError.value(table, 'table', 'Deletion is not supported.');
    }
    await database.ensureSchema();
    await database.transaction(() async {
      final childItemIds = table == 'material_purchases'
          ? (await database.customSelect('''
              SELECT id FROM material_purchase_items
              WHERE purchase_id = ? AND company_id = ? AND is_deleted = 0
            ''', variables: [
              Variable<String>(id),
              Variable<String>(context.companyId),
            ]).get())
              .map((row) => row.read<String>('id'))
              .toList(growable: false)
          : const <String>[];
      final changed = await database.customUpdate('''
        UPDATE $table SET is_deleted = 1, updated_at = ?,
          updated_by_user_id = ?, sync_status = 'pendingUpload',
          version = version + 1
        WHERE id = ? AND company_id = ? AND is_deleted = 0;
      ''', variables: [
        Variable<int>(context.timestamp),
        Variable<String>(context.userId),
        Variable<String>(id),
        Variable<String>(context.companyId),
      ]);
      if (changed != 1) throw StateError('Record not found.');
      if (table == 'material_purchases') {
        await database.customUpdate('''
          UPDATE material_purchase_items SET is_deleted = 1, updated_at = ?,
            updated_by_user_id = ?, sync_status = 'pendingUpload',
            version = version + 1
          WHERE purchase_id = ? AND company_id = ? AND is_deleted = 0;
        ''', variables: [
          Variable<int>(context.timestamp),
          Variable<String>(context.userId),
          Variable<String>(id),
          Variable<String>(context.companyId),
        ]);
        for (final childId in childItemIds) {
          await LocalDeltaWriter.queue(
            database: database,
            context: context,
            createdAt: context.timestamp,
            entityType: 'material_purchase_items',
            entityId: childId,
            operation: 'delete',
          );
        }
      }
      await LocalDeltaWriter.queue(
        database: database,
        context: context,
        createdAt: context.timestamp,
        entityType: table,
        entityId: id,
        operation: 'delete',
      );
    });
  }

  PermissionKey _permissionForTable(String table) {
    return switch (table) {
      'material_purchases' => PermissionKey.materialEntry,
      'labor_work_entries' => PermissionKey.laborEntry,
      'machine_usage_entries' ||
      'machine_repair_entries' =>
        PermissionKey.machineryEntry,
      _ =>
        throw ArgumentError.value(table, 'table', 'Deletion is not supported.'),
    };
  }
}
