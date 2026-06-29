import '../../../core/domain/write_context.dart';
import 'fuel_records.dart';

abstract interface class FuelModuleContract {
  String get moduleName;
  String get phaseResponsibility;

  Future<String> createFuelType(FuelTypeDraft draft, WriteContext context);
  Future<List<FuelTypeRecord>> listFuelTypes(String companyId);
  Future<String> createFuelEntry(FuelEntryDraft draft, WriteContext context);
  Future<void> updateFuelEntry(
      String id, FuelEntryDraft draft, WriteContext context);
  Future<void> deleteFuelEntry(String id, WriteContext context);
  Future<List<FuelEntryRecord>> listFuelEntries(String companyId,
      {String? projectId});
}
