import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/domain/write_context.dart';
import '../../../core/permissions/permission_key.dart';
import '../../../core/permissions/repository_write_guard.dart';
import '../../../database/local_database.dart';
import '../../../database/schema/app_schema_sql.dart';
import '../../../sync/data/local_sync_queue_repository.dart';
import '../../../sync/domain/sync_delta.dart';
import '../../../sync/domain/sync_models.dart';
import '../domain/backup_result.dart';

class LocalBackupService {
  LocalBackupService({
    required ConstructionDatabase database,
    required LocalSyncQueueRepository localQueue,
    required RepositoryWriteGuard writeGuard,
    Uuid uuid = const Uuid(),
  })  : _database = database,
        _localQueue = localQueue,
        _writeGuard = writeGuard,
        _uuid = uuid;

  final ConstructionDatabase _database;
  final LocalSyncQueueRepository _localQueue;
  final RepositoryWriteGuard _writeGuard;
  final Uuid _uuid;

  static const _format = 'construction-erp-local-backup';
  static const _backupVersion = 1;
  static const businessTables = <String>[
    'companies',
    'bidder_profiles',
    'tenders',
    'tender_expenses',
    'tender_documents',
    'projects',
    'project_agreement_deductions',
    'project_milestones',
    'work_days',
    'suppliers',
    'material_purchases',
    'material_purchase_items',
    'supplier_payments',
    'fuel_types',
    'fuel_entries',
    'laborers',
    'labor_work_entries',
    'labor_payments',
    'labor_advances',
    'machines',
    'machine_usage_entries',
    'machine_rental_payments',
    'machine_repair_entries',
    'project_estimates',
    'project_estimate_items',
    'project_bills',
    'project_bill_receipts',
    'gst_entries',
    'project_expenses',
  ];

  Future<Uint8List> createBackup(WriteContext context) async {
    _writeGuard.require(PermissionKey.settingsManage);
    await _database.ensureSchema();
    final tables = <String, Object?>{};
    for (final table in businessTables) {
      final rows = table == 'companies'
          ? await _database.customSelect(
              'SELECT * FROM companies WHERE id = ? LIMIT 1',
              variables: [Variable(context.companyId)],
            ).get()
          : await _database.customSelect(
              'SELECT * FROM $table WHERE company_id = ?',
              variables: [Variable(context.companyId)],
            ).get();
      tables[table] = rows.map((row) => row.data).toList(growable: false);
    }
    final document = {
      'format': _format,
      'backupVersion': _backupVersion,
      'databaseSchemaVersion': AppSchemaSql.schemaVersion,
      'companyId': context.companyId,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'tables': tables,
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(document)));
  }

  Future<BackupRestoreResult> restoreBackup(
    Uint8List bytes,
    WriteContext context,
  ) async {
    _writeGuard.require(PermissionKey.settingsManage);
    if (bytes.length > 100 * 1024 * 1024) {
      throw const FormatException('Backup is larger than the 100 MB limit.');
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic> || decoded['format'] != _format) {
      throw const FormatException('This is not a Construction ERP backup.');
    }
    if (decoded['companyId']?.toString() != context.companyId) {
      throw const FormatException('Backup belongs to a different company.');
    }
    final schemaVersion = _int(decoded['databaseSchemaVersion']);
    if (schemaVersion > AppSchemaSql.schemaVersion) {
      throw FormatException(
        'Backup schema $schemaVersion is newer than this app supports.',
      );
    }
    final rawTables = decoded['tables'];
    if (rawTables is! Map<String, dynamic>) {
      throw const FormatException('Backup tables are missing.');
    }
    if (rawTables.keys.any((table) => !businessTables.contains(table))) {
      throw const FormatException('Backup contains an unsupported table.');
    }

    await _database.ensureSchema();
    var inserted = 0;
    var updated = 0;
    var skipped = 0;
    await _database.transaction(() async {
      for (final table in businessTables) {
        final rawRows = rawTables[table];
        if (rawRows == null) continue;
        if (rawRows is! List) {
          throw FormatException('Backup table $table is invalid.');
        }
        final columns = await _columns(table);
        for (final raw in rawRows) {
          if (raw is! Map<String, dynamic>) {
            throw FormatException('Backup row in $table is invalid.');
          }
          final row = <String, Object?>{
            for (final entry in raw.entries)
              if (columns.contains(entry.key)) entry.key: entry.value,
          };
          final id = row['id']?.toString();
          if (id == null || id.isEmpty) {
            throw FormatException('Backup row in $table has no ID.');
          }
          if (table == 'companies') {
            if (id != context.companyId) {
              throw const FormatException('Backup company ID is invalid.');
            }
          } else if (row['company_id']?.toString() != context.companyId) {
            throw FormatException('Backup row in $table has another company.');
          }
          final existing = await _database.customSelect(
            'SELECT version FROM $table WHERE id = ? LIMIT 1',
            variables: [Variable(id)],
          ).getSingleOrNull();
          final oldVersion = _int(existing?.data['version']);
          final backupVersion = max(1, _int(row['version']));
          final newVersion = existing == null
              ? backupVersion
              : max(oldVersion, backupVersion) + 1;
          row['version'] = newVersion;
          row['updated_at'] = DateTime.now().millisecondsSinceEpoch;
          row['updated_by_user_id'] = context.userId;
          row['sync_status'] = table == 'companies'
              ? SyncStatuses.localOnly
              : SyncStatuses.pendingUpload;
          if (columns.contains('created_at')) {
            row.putIfAbsent('created_at', () => context.timestamp);
          }
          if (columns.contains('is_deleted')) {
            row.putIfAbsent('is_deleted', () => 0);
          }

          await _upsert(table, row);
          if (existing == null) {
            inserted++;
          } else {
            updated++;
          }
          if (table != 'companies') {
            final isDeleted =
                row['is_deleted'] == 1 || row['is_deleted'] == true;
            await _localQueue.queueDelta(SyncDelta(
              deltaId: _uuid.v4(),
              companyId: context.companyId,
              entityType: table,
              entityId: id,
              operation: isDeleted
                  ? SyncOperations.delete
                  : existing == null
                      ? SyncOperations.insert
                      : SyncOperations.update,
              payloadJson: jsonEncode(row),
              baseVersion: existing == null ? 0 : oldVersion,
              newVersion: newVersion,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              createdByUserId: context.userId,
              deviceId: context.deviceId,
              schemaVersion: AppSchemaSql.schemaVersion,
              status: SyncStatuses.pendingUpload,
            ));
          }
        }
      }
    });
    return BackupRestoreResult(
      inserted: inserted,
      updated: updated,
      skipped: skipped,
    );
  }

  Future<Set<String>> _columns(String table) async {
    final rows =
        await _database.customSelect('PRAGMA table_info($table)').get();
    return rows.map((row) => row.data['name']?.toString() ?? '').toSet();
  }

  Future<void> _upsert(String table, Map<String, Object?> row) async {
    final columns = row.keys.toList(growable: false);
    final updates = columns
        .where((column) => column != 'id' && column != 'created_at')
        .map((column) => '$column = excluded.$column')
        .join(', ');
    await _database.customStatement('''
      INSERT INTO $table (${columns.join(', ')})
      VALUES (${List.filled(columns.length, '?').join(', ')})
      ON CONFLICT(id) DO UPDATE SET $updates
    ''', columns.map((column) => row[column]).toList(growable: false));
  }

  int _int(Object? value) => value is int
      ? value
      : value is num
          ? value.toInt()
          : int.tryParse(value?.toString() ?? '') ?? 0;
}
