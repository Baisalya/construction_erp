import '../../../core/domain/write_context.dart';
import 'bidder_profile.dart';
import 'tender_application.dart';
import 'tender_document.dart';
import 'tender_expense.dart';
import 'tender_status.dart';
import 'tender_summary.dart';
import 'tender_to_project_conversion.dart';

abstract interface class TenderModuleContract {
  String get moduleName;
  String get phaseResponsibility;

  Future<List<BidderProfile>> listBidderProfiles(String companyId);
  Future<String> createBidderProfile(
      BidderProfileDraft draft, WriteContext context);

  Future<List<TenderListItem>> listTenders(String companyId);
  Future<TenderDashboardStats> loadStats(String companyId);
  Future<TenderApplication?> findTender(String companyId, String tenderId);
  Future<String> createTender(TenderDraft draft, WriteContext context);
  Future<void> updateTenderStatus({
    required String tenderId,
    required TenderStatus status,
    required WriteContext context,
    int? selectedDate,
    String? rejectionReason,
  });

  Future<String> addTenderExpense(
      TenderExpenseDraft draft, WriteContext context);
  Future<List<TenderExpense>> listTenderExpenses(
      String companyId, String tenderId);

  Future<String> addTenderDocument(
      TenderDocumentDraft draft, WriteContext context);
  Future<List<TenderDocument>> listTenderDocuments(
      String companyId, String tenderId);

  Future<TenderProjectConversionResult> convertSelectedTenderToProject(
    TenderProjectConversionDraft draft,
    WriteContext context,
  );
}
