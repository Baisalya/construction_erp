import 'package:construction_erp/core/domain/write_context.dart';
import 'package:construction_erp/core/value_objects/money.dart';
import 'package:construction_erp/database/local_database.dart';
import 'package:construction_erp/features/tender/data/tender_repository.dart';
import 'package:construction_erp/features/tender/domain/bidder_profile.dart';
import 'package:construction_erp/features/tender/domain/tender_application.dart';
import 'package:construction_erp/features/tender/domain/tender_document.dart';
import 'package:construction_erp/features/tender/domain/tender_expense.dart';
import 'package:construction_erp/features/tender/domain/tender_expense_type.dart';
import 'package:construction_erp/features/tender/domain/tender_status.dart';
import 'package:construction_erp/features/tender/domain/tender_to_project_conversion.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ConstructionDatabase database;
  late TenderRepository repository;
  const context = WriteContext(
    companyId: 'company-1',
    userId: 'owner-1',
    deviceId: 'device-1',
    nowMillis: 1700000000000,
  );

  setUp(() {
    database = ConstructionDatabase(NativeDatabase.memory());
    repository = TenderRepository(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  test('creates bidder profile, tender, expenses, document and sync deltas',
      () async {
    final profileId = await repository.createBidderProfile(
      const BidderProfileDraft(
          profileName: 'State Portal Main',
          portalName: 'State Tender Portal',
          username: 'company_main'),
      context,
    );

    final tenderId = await repository.createTender(
      TenderDraft(
        bidderProfileId: profileId,
        tenderTitle: 'Village Road Improvement',
        tenderNumber: 'T-101',
        estimatedTenderValue: Money.rupees(1000000),
        quotedTenderPrice: Money.rupees(925000),
        tenderFee: Money.rupees(1000),
        documentFee: Money.rupees(500),
        processingCost: Money.rupees(250),
        otherApplicationCost: Money.rupees(125),
        status: TenderStatus.applied,
      ),
      context,
    );

    await repository.addTenderExpense(
      TenderExpenseDraft(
        tenderId: tenderId,
        expenseDate: 1700000000100,
        expenseType: TenderExpenseType.travel,
        amount: Money.rupees(2000),
        description: 'Submission travel',
      ),
      context,
    );

    await repository.addTenderDocument(
      TenderDocumentDraft(
          tenderId: tenderId,
          fileName: 'emd_receipt.pdf',
          documentType: 'EMD Receipt'),
      context,
    );

    final tenders = await repository.listTenders(context.companyId);
    expect(tenders, hasLength(1));
    expect(tenders.single.bidderProfileName, 'State Portal Main');
    expect(tenders.single.totalApplicationCost.paise, 387500);
    expect(await database.countRows('sync_queue'), 4);
  });

  test('only selected tender converts to project', () async {
    final draftTenderId = await repository.createTender(
      TenderDraft(
          tenderTitle: 'Not Selected Tender',
          quotedTenderPrice: Money.rupees(50000),
          status: TenderStatus.applied),
      context,
    );

    await expectLater(
      repository.convertSelectedTenderToProject(
        TenderProjectConversionDraft(
            tenderId: draftTenderId, projectCode: 'PRJ-FAIL'),
        context,
      ),
      throwsStateError,
    );

    final selectedTenderId = await repository.createTender(
      TenderDraft(
          tenderTitle: 'Selected Bridge Work',
          quotedTenderPrice: Money.rupees(750000),
          status: TenderStatus.selected),
      context,
    );

    final result = await repository.convertSelectedTenderToProject(
      TenderProjectConversionDraft(
          tenderId: selectedTenderId, projectCode: 'PRJ-001'),
      context,
    );

    expect(result.projectName, 'Selected Bridge Work');
    expect(await database.countRows('projects'), 1);
    expect(await database.countRows('sync_queue'), 3);
  });

  test('tender stats calculate active, selected and application cost',
      () async {
    await repository.createTender(
      TenderDraft(
        tenderTitle: 'Active Tender',
        quotedTenderPrice: Money.rupees(1000),
        tenderFee: Money.rupees(10),
        status: TenderStatus.applied,
      ),
      context,
    );
    await repository.createTender(
      TenderDraft(
        tenderTitle: 'Selected Tender',
        quotedTenderPrice: Money.rupees(2000),
        documentFee: Money.rupees(20),
        status: TenderStatus.selected,
      ),
      context,
    );

    final stats = await repository.loadStats(context.companyId);

    expect(stats.totalTenders, 2);
    expect(stats.activeTenders, 1);
    expect(stats.selectedTenders, 1);
    expect(stats.totalQuotedValue.paise, 300000);
    expect(stats.totalApplicationCost.paise, 3000);
  });
}
