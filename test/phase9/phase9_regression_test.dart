import 'package:construction_erp/core/domain/write_context.dart';
import 'package:construction_erp/core/value_objects/money.dart';
import 'package:construction_erp/core/value_objects/quantity.dart';
import 'package:construction_erp/database/local_database.dart';
import 'package:construction_erp/features/billing/domain/billing_records.dart';
import 'package:construction_erp/features/labor/domain/labor_records.dart';
import 'package:construction_erp/features/machinery/domain/machinery_records.dart';
import 'package:construction_erp/features/material/data/material_repository.dart';
import 'package:construction_erp/features/material/domain/material_records.dart';
import 'package:construction_erp/features/project/data/project_repository.dart';
import 'package:construction_erp/features/project/domain/project_record.dart';
import 'package:construction_erp/features/tender/data/tender_repository.dart';
import 'package:construction_erp/features/tender/domain/bidder_profile.dart';
import 'package:construction_erp/features/tender/domain/tender_application.dart';
import 'package:construction_erp/features/tender/domain/tender_status.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ConstructionDatabase database;

  const companyA = WriteContext(
    companyId: 'company-a',
    userId: 'owner-a',
    deviceId: 'device-a',
    nowMillis: 1700000000000,
  );
  const companyB = WriteContext(
    companyId: 'company-b',
    userId: 'owner-b',
    deviceId: 'device-b',
    nowMillis: 1700000001000,
  );

  setUp(() => database = ConstructionDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  test('company isolation and project filtering protect local records',
      () async {
    final projects = ProjectRepository(database: database);
    final materials = MaterialRepository(database: database);
    final projectA1 = await _project(projects, companyA, 'A One');
    final projectA2 = await _project(projects, companyA, 'A Two');
    final projectB = await _project(projects, companyB, 'B One');

    final supplierA = await materials.createSupplier(
      const SupplierDraft(supplierName: 'Supplier A'),
      companyA,
    );
    final supplierB = await materials.createSupplier(
      const SupplierDraft(supplierName: 'Supplier B'),
      companyB,
    );
    await _purchase(materials, companyA, projectA1, supplierA, 'Cement');
    await _purchase(materials, companyA, projectA2, supplierA, 'Steel');
    await _purchase(materials, companyB, projectB, supplierB, 'Sand');

    expect(await projects.listProjects(companyA.companyId), hasLength(2));
    expect(await projects.listProjects(companyB.companyId), hasLength(1));
    expect(
      (await materials.listPurchases(companyA.companyId, projectId: projectA1))
          .single
          .items
          .single
          .materialName,
      'Cement',
    );
    expect(
      await materials.listPurchases(companyA.companyId, projectId: projectB),
      isEmpty,
    );
    expect(
      await materials.listPurchases(companyB.companyId, projectId: projectA1),
      isEmpty,
    );
  });

  test('multiple bidder profiles remain linked to their tenders', () async {
    final tenders = TenderRepository(database: database);
    final statePortal = await tenders.createBidderProfile(
      const BidderProfileDraft(profileName: 'State Portal'),
      companyA,
    );
    final centralPortal = await tenders.createBidderProfile(
      const BidderProfileDraft(profileName: 'Central Portal'),
      companyA,
    );
    await tenders.createTender(
      TenderDraft(
        bidderProfileId: statePortal,
        tenderTitle: 'Road work',
        status: TenderStatus.applied,
      ),
      companyA,
    );
    await tenders.createTender(
      TenderDraft(
        bidderProfileId: centralPortal,
        tenderTitle: 'Bridge work',
        status: TenderStatus.selected,
      ),
      companyA,
    );

    final profiles = await tenders.listBidderProfiles(companyA.companyId);
    final records = await tenders.listTenders(companyA.companyId);
    expect(profiles.map((item) => item.profileName),
        containsAll(<String>['State Portal', 'Central Portal']));
    expect(records.map((item) => item.bidderProfileName),
        containsAll(<String>['State Portal', 'Central Portal']));
  });

  test('labor advances and own machine charge types calculate exact balances',
      () {
    final laborBalance = const LaborCalculator().calculateAdvanceBalance(
      const LaborAdvanceDraft(
        laborId: 'labor-1',
        advanceDate: 1700000000000,
        amount: Money.fromPaise(1000000),
        recoveredAmount: Money.fromPaise(350000),
      ),
    );
    expect(laborBalance, const Money.fromPaise(650000));

    const calculator = MachineryCalculator();
    final daily = calculator.calculateUsage(
      MachineUsageDraft(
        projectId: 'project-1',
        machineId: 'own-machine',
        usageDate: 1700000000000,
        chargeType: MachineChargeType.daily,
        daysUsed: DecimalQuantity.parse('2.5'),
        rate: Money.rupees(2000),
      ),
    );
    final weekly = calculator.calculateUsage(
      MachineUsageDraft(
        projectId: 'project-1',
        machineId: 'own-machine',
        usageDate: 1700000000000,
        chargeType: MachineChargeType.weekly,
        quantity: DecimalQuantity.parse('2'),
        rate: Money.rupees(10000),
        paidAmount: Money.rupees(5000),
      ),
    );
    expect(daily.totalAmount, Money.rupees(5000));
    expect(weekly.totalAmount, Money.rupees(20000));
    expect(weekly.pendingAmount, Money.rupees(15000));
    expect(weekly.paymentStatus, MachinePaymentStatus.partial);
  });

  test('running and final bills apply GST, TDS and retention consistently', () {
    const calculator = BillingCalculator();
    final running = calculator.calculateBill(
      ProjectBillDraft(
        projectId: 'project-1',
        billNumber: 'RB-01',
        billDate: 1700000000000,
        billType: BillType.runningBill,
        grossBillAmount: Money.rupees(100000),
        gstRateBasisPoints: 1800,
        tdsAmount: Money.rupees(1000),
        retentionAmount: Money.rupees(5000),
      ),
    );
    final finalBill = calculator.calculateBill(
      ProjectBillDraft(
        projectId: 'project-1',
        billNumber: 'FB-01',
        billDate: 1700000000000,
        billType: BillType.finalBill,
        grossBillAmount: Money.rupees(50000),
        gstRateBasisPoints: 1800,
        tdsAmount: Money.rupees(500),
        retentionAmount: Money.rupees(2500),
        initialReceivedAmount: Money.rupees(30000),
      ),
    );
    expect(running.gstAmount, Money.rupees(18000));
    expect(running.netReceivableAmount, Money.rupees(112000));
    expect(finalBill.netReceivableAmount, Money.rupees(56000));
    expect(finalBill.receivedAmount, Money.rupees(30000));
    expect(finalBill.pendingAmount, Money.rupees(26000));
    expect(finalBill.status, BillStatus.partial);
  });
}

Future<String> _project(
  ProjectRepository repository,
  WriteContext context,
  String name,
) {
  return repository.createProject(
    ProjectDraft(projectName: name, agreementGrossValue: Money.rupees(100000)),
    context,
  );
}

Future<void> _purchase(
  MaterialRepository repository,
  WriteContext context,
  String projectId,
  String supplierId,
  String material,
) async {
  await repository.createPurchase(
    MaterialPurchaseDraft(
      projectId: projectId,
      supplierId: supplierId,
      purchaseDate: context.timestamp,
      items: [
        MaterialPurchaseItemDraft(
          materialName: material,
          quantity: DecimalQuantity.parse('1'),
          rate: Money.rupees(100),
        ),
      ],
    ),
    context,
  );
}
