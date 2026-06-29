import '../../../core/domain/write_context.dart';
import 'material_records.dart';

abstract interface class MaterialModuleContract {
  String get moduleName;
  String get phaseResponsibility;

  Future<String> createSupplier(SupplierDraft draft, WriteContext context);
  Future<List<SupplierRecord>> listSuppliers(String companyId);
  Future<String> createPurchase(
      MaterialPurchaseDraft draft, WriteContext context);
  Future<List<MaterialPurchaseRecord>> listPurchases(String companyId,
      {String? projectId});
  Future<String> recordSupplierPayment(
      SupplierPaymentDraft draft, WriteContext context);
}
