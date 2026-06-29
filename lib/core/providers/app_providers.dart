import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/local_database.dart';
import '../../features/billing/data/billing_repository.dart';
import '../../features/fuel/data/fuel_repository.dart';
import '../../features/dashboard/data/dashboard_repository.dart';
import '../../features/labor/data/labor_repository.dart';
import '../../features/machinery/data/machinery_repository.dart';
import '../../features/material/data/material_repository.dart';
import '../../features/project/data/project_repository.dart';
import '../../features/reports/data/reports_repository.dart';
import '../../features/tender/data/tender_repository.dart';
import '../../features/work/data/work_repository.dart';
import '../../shared/data/module_summary_repository.dart';
import '../../shared/data/local_record_maintenance_repository.dart';
import '../../sync/data/local_sync_repository.dart';
import '../../sync/domain/sync_repository.dart';
import '../../sync/firebase/firebase_company_gateway.dart';
import '../domain/write_context.dart';

final localDatabaseProvider = Provider<ConstructionDatabase>((ref) {
  final database = ConstructionDatabase(openConstructionDatabaseConnection());
  ref.onDispose(() => database.close());
  return database;
});

final localWriteContextProvider = Provider<WriteContext>((ref) {
  return const WriteContext(
    companyId: 'local-company',
    userId: 'local-owner',
    deviceId: 'local-device',
  );
});

final moduleSummaryRepositoryProvider =
    Provider<ModuleSummaryRepository>((ref) {
  return ModuleSummaryRepository(database: ref.watch(localDatabaseProvider));
});

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(database: ref.watch(localDatabaseProvider));
});

final tenderRepositoryProvider = Provider<TenderRepository>((ref) {
  return TenderRepository(database: ref.watch(localDatabaseProvider));
});

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(database: ref.watch(localDatabaseProvider));
});

final materialRepositoryProvider = Provider<MaterialRepository>((ref) {
  return MaterialRepository(database: ref.watch(localDatabaseProvider));
});

final laborRepositoryProvider = Provider<LaborRepository>((ref) {
  return LaborRepository(database: ref.watch(localDatabaseProvider));
});

final machineryRepositoryProvider = Provider<MachineryRepository>((ref) {
  return MachineryRepository(database: ref.watch(localDatabaseProvider));
});

final fuelRepositoryProvider = Provider<FuelRepository>((ref) {
  return FuelRepository(database: ref.watch(localDatabaseProvider));
});

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return BillingRepository(database: ref.watch(localDatabaseProvider));
});

final workRepositoryProvider = Provider<WorkRepository>((ref) {
  return WorkRepository(database: ref.watch(localDatabaseProvider));
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(
    database: ref.watch(localDatabaseProvider),
    tenders: ref.watch(tenderRepositoryProvider),
    projects: ref.watch(projectRepositoryProvider),
    billing: ref.watch(billingRepositoryProvider),
  );
});

final localRecordMaintenanceProvider =
    Provider<LocalRecordMaintenanceRepository>((ref) {
  return LocalRecordMaintenanceRepository(
      database: ref.watch(localDatabaseProvider));
});

final firebaseCompanyGatewayProvider = Provider<FirebaseCompanyGateway>((ref) {
  return FirebaseCompanyGateway.placeholder();
});

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return LocalSyncRepository(database: ref.watch(localDatabaseProvider));
});
