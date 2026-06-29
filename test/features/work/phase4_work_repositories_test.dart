import 'package:construction_erp_phase5/core/domain/write_context.dart';
import 'package:construction_erp_phase5/core/value_objects/money.dart';
import 'package:construction_erp_phase5/core/value_objects/quantity.dart';
import 'package:construction_erp_phase5/database/local_database.dart';
import 'package:construction_erp_phase5/features/fuel/data/fuel_repository.dart';
import 'package:construction_erp_phase5/features/fuel/domain/fuel_records.dart';
import 'package:construction_erp_phase5/features/labor/data/labor_repository.dart';
import 'package:construction_erp_phase5/features/labor/domain/labor_records.dart';
import 'package:construction_erp_phase5/features/machinery/data/machinery_repository.dart';
import 'package:construction_erp_phase5/features/machinery/domain/machinery_records.dart';
import 'package:construction_erp_phase5/features/material/data/material_repository.dart';
import 'package:construction_erp_phase5/features/material/domain/material_records.dart';
import 'package:construction_erp_phase5/features/project/data/project_repository.dart';
import 'package:construction_erp_phase5/features/project/domain/project_record.dart';
import 'package:construction_erp_phase5/features/reports/data/reports_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ConstructionDatabase database;
  late ProjectRepository projectRepository;
  late MaterialRepository materialRepository;
  late LaborRepository laborRepository;
  late MachineryRepository machineryRepository;
  late FuelRepository fuelRepository;
  late ReportsRepository reportsRepository;

  const context = WriteContext(
    companyId: 'company-1',
    userId: 'owner-1',
    deviceId: 'device-1',
    nowMillis: 1700000000000,
  );

  setUp(() {
    database = ConstructionDatabase(NativeDatabase.memory());
    projectRepository = ProjectRepository(database: database);
    materialRepository = MaterialRepository(database: database);
    laborRepository = LaborRepository(database: database);
    machineryRepository = MachineryRepository(database: database);
    fuelRepository = FuelRepository(database: database);
    reportsRepository = ReportsRepository(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
      'material purchase totals and supplier pending payment use integer paise',
      () async {
    final projectId = await _createProject(projectRepository, context);
    final supplierId = await materialRepository.createSupplier(
        const SupplierDraft(supplierName: 'Steel Supplier'), context);

    final purchaseId = await materialRepository.createPurchase(
      MaterialPurchaseDraft(
        projectId: projectId,
        supplierId: supplierId,
        purchaseDate: context.timestamp,
        items: [
          MaterialPurchaseItemDraft(
            materialName: 'Cement',
            quantity: DecimalQuantity.parse('10'),
            rate: Money.rupees(400),
            gstRateBasisPoints: 1800,
          ),
          MaterialPurchaseItemDraft(
            materialName: 'Sand',
            quantity: DecimalQuantity.parse('2.5'),
            rate: Money.rupees(1000),
          ),
        ],
        paidAmount: Money.rupees(1000),
      ),
      context,
    );

    final purchases = await materialRepository.listPurchases(context.companyId,
        projectId: projectId);

    expect(purchaseId, isNotEmpty);
    expect(purchases.single.totalBeforeTax.paise, 650000);
    expect(purchases.single.gstAmount.paise, 72000);
    expect(purchases.single.totalAmount.paise, 722000);
    expect(purchases.single.pendingAmount.paise, 622000);
    expect(purchases.single.paymentStatus, MaterialPaymentStatus.partial);

    await materialRepository.recordSupplierPayment(
      SupplierPaymentDraft(
        supplierId: supplierId,
        projectId: projectId,
        purchaseId: purchaseId,
        paymentDate: context.timestamp,
        amount: Money.rupees(2000),
      ),
      context,
    );
    final paidPurchase = (await materialRepository
            .listPurchases(context.companyId, projectId: projectId))
        .single;
    expect(paidPurchase.paidAmount.paise, 300000);
    expect(paidPurchase.pendingAmount.paise, 422000);
  });

  test('labor daywise and thika calculations store paid and pending amounts',
      () async {
    final projectId = await _createProject(projectRepository, context);
    final laborId = await laborRepository.createLaborer(
      LaborerDraft(
          name: 'Ramesh',
          defaultWorkType: LaborWorkType.daywise,
          defaultRate: Money.rupees(700)),
      context,
    );

    await laborRepository.createWorkEntry(
      LaborWorkEntryDraft(
        projectId: projectId,
        laborId: laborId,
        workDate: context.timestamp,
        workType: LaborWorkType.daywise,
        quantity: DecimalQuantity.parse('2'),
        unit: 'day',
        rate: Money.rupees(700),
        paidAmount: Money.rupees(500),
      ),
      context,
    );
    await laborRepository.createWorkEntry(
      LaborWorkEntryDraft(
        projectId: projectId,
        laborId: laborId,
        workDate: context.timestamp,
        workType: LaborWorkType.thika,
        quantity: DecimalQuantity.parse('1'),
        unit: 'job',
        rate: Money.rupees(3000),
      ),
      context,
    );

    final entries = await laborRepository.listWorkEntries(context.companyId,
        projectId: projectId);

    expect(entries, hasLength(2));
    expect(entries.first.totalAmount.paise + entries.last.totalAmount.paise,
        440000);
    expect(
        entries
            .any((entry) => entry.paymentStatus == LaborPaymentStatus.partial),
        isTrue);

    await laborRepository.recordLaborPayment(
      LaborPaymentDraft(
        laborId: laborId,
        projectId: projectId,
        paymentDate: context.timestamp,
        amount: Money.rupees(2000),
      ),
      context,
    );
    final paidEntries = await laborRepository.listWorkEntries(context.companyId,
        projectId: projectId);
    expect(
        paidEntries.fold<int>(
            0, (total, entry) => total + entry.pendingAmount.paise),
        190000);
  });

  test(
      'machinery rental calculation, fuel link, and repair cost are added to project cost',
      () async {
    final projectId = await _createProject(projectRepository, context);
    final machineId = await machineryRepository.createMachine(
      MachineDraft(
        machineName: 'Excavator',
        ownershipType: MachineOwnershipType.rental,
        ownerName: 'Machine Owner',
        defaultChargeType: MachineChargeType.hourly,
        defaultChargeRate: Money.rupees(2500),
      ),
      context,
    );

    await machineryRepository.createUsageEntry(
      MachineUsageDraft(
        projectId: projectId,
        machineId: machineId,
        usageDate: context.timestamp,
        chargeType: MachineChargeType.hourly,
        hoursUsed: DecimalQuantity.parse('3.5'),
        rate: Money.rupees(2500),
      ),
      context,
    );
    final fuelTypeId = await fuelRepository.createFuelType(
        FuelTypeDraft(name: 'Diesel', defaultRate: Money.rupees(90)), context);
    await fuelRepository.createFuelEntry(
      FuelEntryDraft(
        projectId: projectId,
        fuelDate: context.timestamp,
        fuelTypeId: fuelTypeId,
        quantity: DecimalQuantity.parse('20'),
        rate: Money.rupees(90),
        usedForType: FuelUsedForType.machinery,
        machineId: machineId,
        paidAmount: Money.rupees(1000),
      ),
      context,
    );
    await machineryRepository.recordRepair(
      MachineRepairDraft(
        machineId: machineId,
        projectId: projectId,
        repairDate: context.timestamp,
        partsCost: Money.rupees(1200),
        laborCost: Money.rupees(800),
      ),
      context,
    );

    final usage = (await machineryRepository.listUsageEntries(context.companyId,
            projectId: projectId))
        .single;
    final fuel = (await fuelRepository.listFuelEntries(context.companyId,
            projectId: projectId))
        .single;
    final summary = await reportsRepository.loadProjectCostSummary(
        context.companyId, projectId);

    expect(usage.totalAmount.paise, 875000);
    expect(fuel.usedForType, FuelUsedForType.machinery);
    expect(fuel.machineId, machineId);
    expect(fuel.totalAmount.paise, 180000);
    expect(summary.machineryCost.paise, 875000);
    expect(summary.fuelCost.paise, 180000);
    expect(summary.repairCost.paise, 200000);
    expect(summary.totalActualCost.paise, 1255000);

    await machineryRepository.recordRentalPayment(
      MachineRentalPaymentDraft(
        machineId: machineId,
        projectId: projectId,
        paymentDate: context.timestamp,
        amount: Money.rupees(1000),
      ),
      context,
    );
    final paidUsage = (await machineryRepository
            .listUsageEntries(context.companyId, projectId: projectId))
        .single;
    expect(paidUsage.paidAmount.paise, 100000);
    expect(paidUsage.pendingAmount.paise, 775000);
  });
}

Future<String> _createProject(
    ProjectRepository repository, WriteContext context) {
  return repository.createProject(
    ProjectDraft(
      projectName: 'Phase 4 Test Project',
      agreementGrossValue: Money.rupees(100000),
    ),
    context,
  );
}
