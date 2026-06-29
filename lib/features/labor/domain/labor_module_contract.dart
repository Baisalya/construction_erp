import '../../../core/domain/write_context.dart';
import 'labor_records.dart';

abstract interface class LaborModuleContract {
  String get moduleName;
  String get phaseResponsibility;

  Future<String> createLaborer(LaborerDraft draft, WriteContext context);
  Future<List<LaborerRecord>> listLaborers(String companyId);
  Future<String> createWorkEntry(
      LaborWorkEntryDraft draft, WriteContext context);
  Future<List<LaborWorkEntryRecord>> listWorkEntries(String companyId,
      {String? projectId});
  Future<String> recordLaborPayment(
      LaborPaymentDraft draft, WriteContext context);
  Future<String> recordLaborAdvance(
      LaborAdvanceDraft draft, WriteContext context);
}
