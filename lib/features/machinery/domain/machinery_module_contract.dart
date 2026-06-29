import '../../../core/domain/write_context.dart';
import 'machinery_records.dart';

abstract interface class MachineryModuleContract {
  String get moduleName;
  String get phaseResponsibility;

  Future<String> createMachine(MachineDraft draft, WriteContext context);
  Future<List<MachineRecord>> listMachines(String companyId);
  Future<String> createUsageEntry(
      MachineUsageDraft draft, WriteContext context);
  Future<List<MachineUsageRecord>> listUsageEntries(String companyId,
      {String? projectId});
  Future<String> recordRentalPayment(
      MachineRentalPaymentDraft draft, WriteContext context);
  Future<String> recordRepair(MachineRepairDraft draft, WriteContext context);
  Future<List<MachineRepairRecord>> listRepairs(String companyId,
      {String? projectId});
}
