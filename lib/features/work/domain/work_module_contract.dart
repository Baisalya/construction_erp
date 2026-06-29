import '../../../core/domain/write_context.dart';
import 'work_records.dart';

abstract interface class WorkModuleContract {
  String get moduleName;
  String get phaseResponsibility;

  Future<List<WorkDayRecord>> listWorkDays(String companyId,
      {String? projectId});
  Future<String> createWorkDay(WorkDayDraft draft, WriteContext context);
  Future<void> updateWorkDay(
      String id, WorkDayDraft draft, WriteContext context);
  Future<void> deleteWorkDay(String id, WriteContext context);

  Future<List<ProjectExpenseRecord>> listExpenses(String companyId,
      {String? projectId});
  Future<String> createExpense(ProjectExpenseDraft draft, WriteContext context);
  Future<void> updateExpense(
      String id, ProjectExpenseDraft draft, WriteContext context);
  Future<void> deleteExpense(String id, WriteContext context);
}
