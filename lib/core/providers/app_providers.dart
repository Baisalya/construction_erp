import 'package:flutter_riverpod/flutter_riverpod.dart';

export '../../database/database_providers.dart';

import '../../database/database_providers.dart';
import '../../features/auth/data/auth_providers.dart';
import '../../features/billing/data/billing_repository.dart';
import '../../features/fuel/data/fuel_repository.dart';
import '../../features/dashboard/data/dashboard_repository.dart';
import '../../features/labor/data/labor_repository.dart';
import '../../features/machinery/data/machinery_repository.dart';
import '../../features/material/data/material_repository.dart';
import '../../features/project/data/project_repository.dart';
import '../../features/reports/data/reports_repository.dart';
import '../../features/reports/data/report_export_service.dart';
import '../../features/settings/data/local_backup_service.dart';
import '../../features/tender/data/tender_repository.dart';
import '../../features/work/data/work_repository.dart';
import '../../shared/data/module_summary_repository.dart';
import '../../shared/data/local_record_maintenance_repository.dart';
import '../../shared/services/local_file_service.dart';
import '../../sync/data/local_sync_queue_repository.dart';
import '../../sync/data/local_sync_repository.dart';
import '../../sync/domain/sync_repository.dart';
import '../../sync/firebase/firebase_company_gateway.dart';
import '../domain/write_context.dart';
import '../permissions/repository_write_guard.dart';

final repositoryWriteGuardProvider = Provider<RepositoryWriteGuard>((ref) {
  final service = ref.watch(permissionServiceProvider).valueOrNull;
  return StaffPolicyWriteGuard(service?.policy);
});

final localWriteContextProvider = Provider<WriteContext>((ref) {
  final policy = ref.watch(permissionServiceProvider).valueOrNull?.policy;
  if (policy != null) {
    return WriteContext(
      companyId: policy.staff.companyId,
      userId: policy.staff.firebaseUid ?? policy.staff.id,
      deviceId: 'local-${policy.staff.firebaseUid ?? policy.staff.id}',
    );
  }
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

final localFileServiceProvider = Provider<LocalFileService>((ref) {
  return const LocalFileService();
});

final reportExportServiceProvider = Provider<ReportExportService>((ref) {
  return ReportExportService(
    database: ref.watch(localDatabaseProvider),
    writeGuard: ref.watch(repositoryWriteGuardProvider),
  );
});

final localBackupServiceProvider = Provider<LocalBackupService>((ref) {
  return LocalBackupService(
    database: ref.watch(localDatabaseProvider),
    localQueue: LocalSyncQueueRepository(
      database: ref.watch(localDatabaseProvider),
    ),
    writeGuard: ref.watch(repositoryWriteGuardProvider),
  );
});

final tenderRepositoryProvider = Provider<TenderRepository>((ref) {
  return TenderRepository(
    database: ref.watch(localDatabaseProvider),
    writeGuard: ref.watch(repositoryWriteGuardProvider),
  );
});

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(
    database: ref.watch(localDatabaseProvider),
    writeGuard: ref.watch(repositoryWriteGuardProvider),
  );
});

final materialRepositoryProvider = Provider<MaterialRepository>((ref) {
  return MaterialRepository(
    database: ref.watch(localDatabaseProvider),
    writeGuard: ref.watch(repositoryWriteGuardProvider),
  );
});

final laborRepositoryProvider = Provider<LaborRepository>((ref) {
  return LaborRepository(
    database: ref.watch(localDatabaseProvider),
    writeGuard: ref.watch(repositoryWriteGuardProvider),
  );
});

final machineryRepositoryProvider = Provider<MachineryRepository>((ref) {
  return MachineryRepository(
    database: ref.watch(localDatabaseProvider),
    writeGuard: ref.watch(repositoryWriteGuardProvider),
  );
});

final fuelRepositoryProvider = Provider<FuelRepository>((ref) {
  return FuelRepository(
    database: ref.watch(localDatabaseProvider),
    writeGuard: ref.watch(repositoryWriteGuardProvider),
  );
});

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return BillingRepository(
    database: ref.watch(localDatabaseProvider),
    writeGuard: ref.watch(repositoryWriteGuardProvider),
  );
});

final workRepositoryProvider = Provider<WorkRepository>((ref) {
  return WorkRepository(
    database: ref.watch(localDatabaseProvider),
    writeGuard: ref.watch(repositoryWriteGuardProvider),
  );
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
    database: ref.watch(localDatabaseProvider),
    writeGuard: ref.watch(repositoryWriteGuardProvider),
  );
});

final firebaseCompanyGatewayProvider = Provider<FirebaseCompanyGateway>((ref) {
  return FirebaseCompanyGateway.placeholder();
});

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return LocalSyncRepository(database: ref.watch(localDatabaseProvider));
});
