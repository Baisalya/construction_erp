import 'package:construction_erp_phase5/core/domain/write_context.dart';
import 'package:construction_erp_phase5/core/value_objects/money.dart';
import 'package:construction_erp_phase5/core/value_objects/quantity.dart';
import 'package:construction_erp_phase5/database/local_database.dart';
import 'package:construction_erp_phase5/features/billing/data/billing_repository.dart';
import 'package:construction_erp_phase5/features/billing/domain/billing_records.dart';
import 'package:construction_erp_phase5/features/material/data/material_repository.dart';
import 'package:construction_erp_phase5/features/material/domain/material_records.dart';
import 'package:construction_erp_phase5/features/project/data/project_repository.dart';
import 'package:construction_erp_phase5/features/project/domain/project_record.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ConstructionDatabase database;
  late ProjectRepository projectRepository;
  late BillingRepository billingRepository;
  late MaterialRepository materialRepository;

  const context = WriteContext(
    companyId: 'company-1',
    userId: 'owner-1',
    deviceId: 'device-1',
    nowMillis: 1700000000000,
  );

  setUp(() {
    database = ConstructionDatabase(NativeDatabase.memory());
    projectRepository = ProjectRepository(database: database);
    billingRepository = BillingRepository(database: database);
    materialRepository = MaterialRepository(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
      'estimate calculates item total and estimated profit using integer paise',
      () async {
    final projectId = await _createProject(projectRepository, context);

    await billingRepository.createEstimate(
      ProjectEstimateDraft(
        projectId: projectId,
        estimateNumber: 'EST-001',
        estimateDate: context.timestamp,
        title: 'Road work estimate',
        items: [
          EstimateItemDraft(
              itemName: 'Concrete',
              quantity: DecimalQuantity.parse('10.5'),
              rate: Money.rupees(1000)),
        ],
        estimatedLaborCost: Money.rupees(2000),
        estimatedMachineryCost: Money.rupees(3000),
      ),
      context,
    );

    final estimate = (await billingRepository.listEstimates(context.companyId,
            projectId: projectId))
        .single;

    expect(estimate.totalEstimatedMaterialCost.paise, 1050000);
    expect(estimate.totalEstimatedLaborCost.paise, 200000);
    expect(estimate.totalEstimatedMachineryCost.paise, 300000);
    expect(estimate.totalEstimatedCost.paise, 1550000);
    expect(estimate.estimatedProfit.paise, 98450000);
    expect(estimate.items.single.amount.paise, 1050000);
  });

  test(
      'bill calculates GST, net receivable, pending amount and auto output GST entry',
      () async {
    final projectId = await _createProject(projectRepository, context);

    final billId = await billingRepository.createBill(
      ProjectBillDraft(
        projectId: projectId,
        billNumber: 'RB-001',
        billDate: context.timestamp,
        grossBillAmount: Money.rupees(100000),
        gstRateBasisPoints: 1800,
        tdsAmount: Money.rupees(1000),
        retentionAmount: Money.rupees(5000),
        initialReceivedAmount: Money.rupees(50000),
        status: BillStatus.approved,
      ),
      context,
    );

    final bill = await billingRepository.findBill(context.companyId, billId);
    final gstEntries = await billingRepository.listGstEntries(context.companyId,
        projectId: projectId);

    expect(bill, isNotNull);
    expect(bill!.gstAmount.paise, 1800000);
    expect(bill.totalBillAmount.paise, 11800000);
    expect(bill.netReceivableAmount.paise, 11200000);
    expect(bill.receivedAmount.paise, 5000000);
    expect(bill.pendingAmount.paise, 6200000);
    expect(bill.status, BillStatus.partial);
    expect(gstEntries.single.gstType, GstType.output);
    expect(gstEntries.single.gstAmount.paise, 1800000);
  });

  test('receipt updates bill received and pending values safely', () async {
    final projectId = await _createProject(projectRepository, context);
    final billId = await billingRepository.createBill(
      ProjectBillDraft(
          projectId: projectId,
          billNumber: 'RB-002',
          billDate: context.timestamp,
          grossBillAmount: Money.rupees(10000)),
      context,
    );

    await billingRepository.addBillReceipt(
      ProjectBillReceiptDraft(
          projectId: projectId,
          billId: billId,
          receiptDate: context.timestamp,
          amount: Money.rupees(4000)),
      context,
    );

    final bill = await billingRepository.findBill(context.companyId, billId);
    final summary = await billingRepository
        .loadBillingSummary(context.companyId, projectId: projectId);

    expect(bill!.receivedAmount.paise, 400000);
    expect(bill.pendingAmount.paise, 600000);
    expect(bill.status, BillStatus.partial);
    expect(summary.totalReceived.paise, 400000);
    expect(summary.pendingReceivable.paise, 600000);
  });

  test(
      'profit loss summary combines actual cost, received amount, GST and payable',
      () async {
    final projectId = await _createProject(projectRepository, context);
    final supplierId = await materialRepository.createSupplier(
        const SupplierDraft(supplierName: 'Cement Supplier'), context);
    await materialRepository.createPurchase(
      MaterialPurchaseDraft(
        projectId: projectId,
        supplierId: supplierId,
        purchaseDate: context.timestamp,
        items: [
          MaterialPurchaseItemDraft(
              materialName: 'Cement',
              quantity: DecimalQuantity.parse('10'),
              rate: Money.rupees(500),
              gstRateBasisPoints: 1800)
        ],
        paidAmount: Money.rupees(1000),
      ),
      context,
    );
    final billId = await billingRepository.createBill(
      ProjectBillDraft(
          projectId: projectId,
          billNumber: 'RB-003',
          billDate: context.timestamp,
          grossBillAmount: Money.rupees(20000),
          gstRateBasisPoints: 1800),
      context,
    );
    await billingRepository.addBillReceipt(
        ProjectBillReceiptDraft(
            projectId: projectId,
            billId: billId,
            receiptDate: context.timestamp,
            amount: Money.rupees(10000)),
        context);
    await billingRepository.createGstEntry(
      GstEntryDraft(
          projectId: projectId,
          sourceId: 'manual-input',
          gstType: GstType.input,
          gstRateBasisPoints: 1800,
          taxableAmount: Money.rupees(5000),
          gstAmount: Money.rupees(900),
          entryDate: context.timestamp),
      context,
    );

    final summary = await billingRepository
        .loadBillingSummary(context.companyId, projectId: projectId);

    expect(summary.materialCost.paise, 590000);
    expect(summary.totalActualCost.paise, 590000);
    expect(summary.gstOutput.paise, 360000);
    expect(summary.gstInput.paise, 90000);
    expect(summary.totalReceived.paise, 1000000);
    expect(summary.totalPayable.paise, 490000);
    expect(summary.actualProfitByAgreement.paise, 99410000);
    expect(summary.actualProfitByReceived.paise, 410000);
  });
}

Future<String> _createProject(
    ProjectRepository repository, WriteContext context) {
  return repository.createProject(
    ProjectDraft(
        projectName: 'Phase 5 Billing Project',
        agreementGrossValue: Money.rupees(1000000)),
    context,
  );
}
