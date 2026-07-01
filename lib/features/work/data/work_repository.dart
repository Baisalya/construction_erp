import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/domain/write_context.dart';
import '../../../core/permissions/permission_key.dart';
import '../../../core/permissions/repository_write_guard.dart';
import '../../../core/value_objects/money.dart';
import '../../../database/local_database.dart';
import '../../../sync/data/local_delta_writer.dart';
import '../domain/work_module_contract.dart';
import '../domain/work_records.dart';

class WorkRepository implements WorkModuleContract {
  WorkRepository({
    required this.database,
    RepositoryWriteGuard writeGuard = const AllowAllRepositoryWriteGuard(),
    Uuid uuid = const Uuid(),
  })  : _writeGuard = writeGuard,
        _uuid = uuid;

  final ConstructionDatabase database;
  final RepositoryWriteGuard _writeGuard;
  final Uuid _uuid;

  @override
  String get moduleName => 'Work';

  @override
  String get phaseResponsibility =>
      'Daily site diary and project expense ledger with local-first CRUD.';

  @override
  Future<List<WorkDayRecord>> listWorkDays(String companyId,
      {String? projectId}) async {
    await database.ensureSchema();
    final scope = projectReadScope(_writeGuard, projectId: projectId);
    final rows = await database.customSelect('''
      SELECT * FROM work_days
      WHERE company_id = ? AND is_deleted = 0
        ${scope.sql}
      ORDER BY work_date DESC, updated_at DESC;
    ''', variables: [
      Variable<String>(companyId),
      ...scope.projectIds.map(Variable<String>.new),
    ]).get();
    return rows.map(_workDayFromRow).toList(growable: false);
  }

  @override
  Future<String> createWorkDay(WorkDayDraft draft, WriteContext context) async {
    _writeGuard.require(PermissionKey.projectEdit, projectId: draft.projectId);
    _validateWorkDay(draft);
    await database.ensureSchema();
    final id = _uuid.v4();
    await database.transaction(() async {
      await database.customStatement('''
        INSERT INTO work_days (
          id, company_id, created_at, updated_at, created_by_user_id,
          updated_by_user_id, is_deleted, sync_status, version, project_id,
          work_date, site_name, weather, notes
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?);
      ''', [
        Variable<String>(id),
        Variable<String>(context.companyId),
        Variable<int>(context.timestamp),
        Variable<int>(context.timestamp),
        Variable<String>(context.userId),
        Variable<String>(context.userId),
        Variable<String>(draft.projectId),
        Variable<int>(draft.workDate),
        Variable<String>(_clean(draft.siteName)),
        Variable<String>(_clean(draft.weather)),
        Variable<String>(_clean(draft.notes)),
      ]);
      await _queue(
          'work_days', id, 'insert', {'id': id, ...draft.toPayload()}, context);
    });
    return id;
  }

  @override
  Future<void> updateWorkDay(
      String id, WorkDayDraft draft, WriteContext context) async {
    _writeGuard.require(PermissionKey.projectEdit, projectId: draft.projectId);
    _validateWorkDay(draft);
    await database.ensureSchema();
    await database.transaction(() async {
      final changed = await database.customUpdate('''
        UPDATE work_days SET project_id = ?, work_date = ?, site_name = ?,
          weather = ?, notes = ?, updated_at = ?, updated_by_user_id = ?,
          sync_status = 'pendingUpload', version = version + 1
        WHERE id = ? AND company_id = ? AND is_deleted = 0;
      ''', variables: [
        Variable<String>(draft.projectId),
        Variable<int>(draft.workDate),
        Variable<String>(_clean(draft.siteName)),
        Variable<String>(_clean(draft.weather)),
        Variable<String>(_clean(draft.notes)),
        Variable<int>(context.timestamp),
        Variable<String>(context.userId),
        Variable<String>(id),
        Variable<String>(context.companyId),
      ]);
      if (changed != 1) throw StateError('Work day not found.');
      await _queue(
          'work_days', id, 'update', {'id': id, ...draft.toPayload()}, context);
    });
  }

  @override
  Future<void> deleteWorkDay(String id, WriteContext context) {
    _writeGuard.require(PermissionKey.projectEdit);
    return _softDelete('work_days', id, context);
  }

  @override
  Future<List<ProjectExpenseRecord>> listExpenses(String companyId,
      {String? projectId}) async {
    await database.ensureSchema();
    final scope = projectReadScope(_writeGuard, projectId: projectId);
    final rows = await database.customSelect('''
      SELECT * FROM project_expenses
      WHERE company_id = ? AND is_deleted = 0
        ${scope.sql}
      ORDER BY expense_date DESC, updated_at DESC;
    ''', variables: [
      Variable<String>(companyId),
      ...scope.projectIds.map(Variable<String>.new),
    ]).get();
    return rows.map(_expenseFromRow).toList(growable: false);
  }

  @override
  Future<String> createExpense(
      ProjectExpenseDraft draft, WriteContext context) async {
    _writeGuard.require(PermissionKey.projectEdit, projectId: draft.projectId);
    _validateExpense(draft);
    await database.ensureSchema();
    final id = _uuid.v4();
    await database.transaction(() async {
      await database.customStatement('''
        INSERT INTO project_expenses (
          id, company_id, created_at, updated_at, created_by_user_id,
          updated_by_user_id, is_deleted, sync_status, version, project_id,
          expense_date, expense_category, description, amount_paise,
          paid_amount_paise, pending_amount_paise, payment_mode, notes
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pendingUpload', 1, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      ''', _expenseVariables(id, draft, context));
      await _queue('project_expenses', id, 'insert',
          {'id': id, ...draft.toPayload()}, context);
    });
    return id;
  }

  @override
  Future<void> updateExpense(
      String id, ProjectExpenseDraft draft, WriteContext context) async {
    _writeGuard.require(PermissionKey.projectEdit, projectId: draft.projectId);
    _validateExpense(draft);
    await database.ensureSchema();
    await database.transaction(() async {
      final changed = await database.customUpdate('''
        UPDATE project_expenses SET project_id = ?, expense_date = ?,
          expense_category = ?, description = ?, amount_paise = ?,
          paid_amount_paise = ?, pending_amount_paise = ?, payment_mode = ?,
          notes = ?, updated_at = ?, updated_by_user_id = ?,
          sync_status = 'pendingUpload', version = version + 1
        WHERE id = ? AND company_id = ? AND is_deleted = 0;
      ''', variables: [
        Variable<String>(draft.projectId),
        Variable<int>(draft.expenseDate),
        Variable<String>(draft.category.name),
        Variable<String>(_clean(draft.description)),
        Variable<int>(draft.amount.paise),
        Variable<int>(draft.paidAmount.paise),
        Variable<int>(draft.pendingAmount.paise),
        Variable<String>(_clean(draft.paymentMode)),
        Variable<String>(_clean(draft.notes)),
        Variable<int>(context.timestamp),
        Variable<String>(context.userId),
        Variable<String>(id),
        Variable<String>(context.companyId),
      ]);
      if (changed != 1) throw StateError('Project expense not found.');
      await _queue('project_expenses', id, 'update',
          {'id': id, ...draft.toPayload()}, context);
    });
  }

  @override
  Future<void> deleteExpense(String id, WriteContext context) {
    _writeGuard.require(PermissionKey.projectEdit);
    return _softDelete('project_expenses', id, context);
  }

  List<Variable> _expenseVariables(
          String id, ProjectExpenseDraft draft, WriteContext context) =>
      [
        Variable<String>(id),
        Variable<String>(context.companyId),
        Variable<int>(context.timestamp),
        Variable<int>(context.timestamp),
        Variable<String>(context.userId),
        Variable<String>(context.userId),
        Variable<String>(draft.projectId),
        Variable<int>(draft.expenseDate),
        Variable<String>(draft.category.name),
        Variable<String>(_clean(draft.description)),
        Variable<int>(draft.amount.paise),
        Variable<int>(draft.paidAmount.paise),
        Variable<int>(draft.pendingAmount.paise),
        Variable<String>(_clean(draft.paymentMode)),
        Variable<String>(_clean(draft.notes)),
      ];

  Future<void> _softDelete(
      String table, String id, WriteContext context) async {
    await database.ensureSchema();
    await database.transaction(() async {
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
      await _queue(table, id, 'delete', {'id': id}, context);
    });
  }

  Future<void> _queue(String type, String id, String operation,
      Map<String, Object?> payload, WriteContext context) async {
    await LocalDeltaWriter.queue(
      database: database,
      context: context,
      createdAt: context.timestamp,
      entityType: type,
      entityId: id,
      operation: operation,
      fallbackPayload: payload,
    );
  }

  void _validateWorkDay(WorkDayDraft draft) {
    if (draft.projectId.trim().isEmpty) {
      throw ArgumentError('Project is required.');
    }
    if (draft.workDate <= 0) throw ArgumentError('Work date is required.');
  }

  void _validateExpense(ProjectExpenseDraft draft) {
    if (draft.projectId.trim().isEmpty) {
      throw ArgumentError('Project is required.');
    }
    if (draft.amount.paise <= 0) {
      throw ArgumentError('Expense must be greater than zero.');
    }
    if (draft.paidAmount.paise < 0 ||
        draft.paidAmount.paise > draft.amount.paise) {
      throw ArgumentError(
          'Paid amount must be between zero and expense amount.');
    }
  }

  WorkDayRecord _workDayFromRow(QueryRow row) => WorkDayRecord(
      id: row.read<String>('id'),
      companyId: row.read<String>('company_id'),
      projectId: row.read<String>('project_id'),
      workDate: row.read<int>('work_date'),
      siteName: row.readNullable<String>('site_name'),
      weather: row.readNullable<String>('weather'),
      notes: row.readNullable<String>('notes'));

  ProjectExpenseRecord _expenseFromRow(QueryRow row) => ProjectExpenseRecord(
      id: row.read<String>('id'),
      companyId: row.read<String>('company_id'),
      projectId: row.read<String>('project_id'),
      expenseDate: row.read<int>('expense_date'),
      category: ProjectExpenseCategory.fromValue(
          row.read<String>('expense_category')),
      description: row.readNullable<String>('description'),
      amount: Money.fromPaise(row.read<int>('amount_paise')),
      paidAmount: Money.fromPaise(row.read<int>('paid_amount_paise')),
      pendingAmount: Money.fromPaise(row.read<int>('pending_amount_paise')),
      paymentMode: row.readNullable<String>('payment_mode'),
      notes: row.readNullable<String>('notes'));

  String? _clean(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
