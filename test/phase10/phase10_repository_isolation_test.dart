import 'package:construction_erp/core/domain/write_context.dart';
import 'package:construction_erp/core/permissions/permission_key.dart';
import 'package:construction_erp/core/permissions/repository_write_guard.dart';
import 'package:construction_erp/core/permissions/role_type.dart';
import 'package:construction_erp/core/permissions/staff_status.dart';
import 'package:construction_erp/core/security/invitation_code.dart';
import 'package:construction_erp/core/value_objects/money.dart';
import 'package:construction_erp/core/value_objects/quantity.dart';
import 'package:construction_erp/database/local_database.dart';
import 'package:construction_erp/features/auth/data/local_workspace_repository.dart';
import 'package:construction_erp/features/auth/domain/company_membership.dart';
import 'package:construction_erp/features/billing/data/billing_repository.dart';
import 'package:construction_erp/features/billing/domain/billing_records.dart';
import 'package:construction_erp/features/material/data/material_repository.dart';
import 'package:construction_erp/features/material/domain/material_records.dart';
import 'package:construction_erp/features/project/data/project_repository.dart';
import 'package:construction_erp/features/project/domain/project_record.dart';
import 'package:construction_erp/features/staff/domain/staff_access_policy.dart';
import 'package:construction_erp/features/staff/domain/staff_profile.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ConstructionDatabase database;

  const write = WriteContext(
    companyId: 'company-a',
    userId: 'owner-uid',
    deviceId: 'device-a',
    nowMillis: 1700000000000,
  );

  setUp(() => database = ConstructionDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  test('restricted repositories never load unassigned project rows', () async {
    final ownerProjects = ProjectRepository(database: database);
    final ownerMaterial = MaterialRepository(database: database);
    final ownerBilling = BillingRepository(database: database);

    final projectOne = await ownerProjects.createProject(
      ProjectDraft(
        projectName: 'Allowed project',
        agreementGrossValue: Money.rupees(100000),
      ),
      write,
    );
    final projectTwo = await ownerProjects.createProject(
      ProjectDraft(
        projectName: 'Hidden project',
        agreementGrossValue: Money.rupees(200000),
      ),
      write,
    );
    final supplier = await ownerMaterial.createSupplier(
      const SupplierDraft(supplierName: 'Supplier'),
      write,
    );
    for (final entry in [
      (projectOne, 'Allowed cement', 100),
      (projectTwo, 'Hidden steel', 500),
    ]) {
      await ownerMaterial.createPurchase(
        MaterialPurchaseDraft(
          projectId: entry.$1,
          supplierId: supplier,
          purchaseDate: write.timestamp,
          items: [
            MaterialPurchaseItemDraft(
              materialName: entry.$2,
              quantity: DecimalQuantity.parse('1'),
              rate: Money.rupees(entry.$3),
            ),
          ],
        ),
        write,
      );
    }
    await ownerBilling.createBill(
      ProjectBillDraft(
        projectId: projectOne,
        billNumber: 'A-1',
        billDate: write.timestamp,
        billType: BillType.runningBill,
        grossBillAmount: Money.rupees(1000),
      ),
      write,
    );
    await ownerBilling.createBill(
      ProjectBillDraft(
        projectId: projectTwo,
        billNumber: 'H-1',
        billDate: write.timestamp,
        billType: BillType.runningBill,
        grossBillAmount: Money.rupees(9000),
      ),
      write,
    );

    final guard = StaffPolicyWriteGuard(
      const StaffAccessPolicy(
        staff: StaffProfile(
          id: 'staff-uid',
          companyId: 'company-a',
          name: 'Restricted accountant',
          firebaseUid: 'staff-uid',
          roleId: 'accountant',
          roleType: RoleType.accountant,
          status: StaffStatus.active,
        ),
        allowedPermissions: {
          PermissionKey.materialEntry,
          PermissionKey.billingEntry,
        },
        assignedProjectIds: {'project-placeholder'},
      ),
    );
    final scopedPolicy = StaffAccessPolicy(
      staff: guard.policy!.staff,
      allowedPermissions: guard.policy!.allowedPermissions,
      assignedProjectIds: {projectOne},
    );
    final scopedGuard = StaffPolicyWriteGuard(scopedPolicy);
    final projects = ProjectRepository(
      database: database,
      writeGuard: scopedGuard,
    );
    final material = MaterialRepository(
      database: database,
      writeGuard: scopedGuard,
    );
    final billing = BillingRepository(
      database: database,
      writeGuard: scopedGuard,
    );

    expect((await projects.listProjects('company-a')).single.id, projectOne);
    expect(
      (await material.listPurchases('company-a')).single.projectId,
      projectOne,
    );
    expect(
      await material.listPurchases('company-a', projectId: projectTwo),
      isEmpty,
    );
    expect((await billing.listBills('company-a')).single.projectId, projectOne);
    expect(
      await billing.listBills('company-a', projectId: projectTwo),
      isEmpty,
    );
    final summary = await billing.loadBillingSummary('company-a');
    expect(summary.agreementValue, Money.rupees(100000));
    expect(summary.materialCost, Money.rupees(100));
    expect(summary.totalBilled, Money.rupees(1000));
  });

  test('switching workspace changes company without deleting other data',
      () async {
    final workspace = LocalWorkspaceRepository(database: database);
    const first = CompanyMembership(
      id: 'uid-company-a',
      uid: 'uid',
      companyId: 'company-a',
      companyName: 'Company A',
      status: 'active',
      isOwner: true,
      canAccessAllProjects: true,
      updatedAt: 1,
    );
    const second = CompanyMembership(
      id: 'uid-company-b',
      uid: 'uid',
      companyId: 'company-b',
      companyName: 'Company B',
      status: 'active',
      isOwner: false,
      canAccessAllProjects: false,
      assignedProjectIds: ['project-b'],
      updatedAt: 1,
    );
    await workspace.replaceMemberships(
      uid: 'uid',
      memberships: const [first, second],
    );
    await workspace.setActiveCompany(uid: 'uid', companyId: 'company-a');
    expect(
      (await workspace.readActiveWorkspace('uid'))!.activeCompanyId,
      'company-a',
    );
    await workspace.setActiveCompany(uid: 'uid', companyId: 'company-b');
    final active = await workspace.readActiveWorkspace('uid');
    expect(active!.activeCompanyId, 'company-b');
    expect(active.activeProjectId, isNull);
    expect(await workspace.listMemberships('uid'), hasLength(2));
  });

  test('invitation digest never stores the readable invite code', () {
    const code = 'ABCD1234EFGH5678';
    final digest = hashInvitationCode(code);
    expect(digest, hasLength(64));
    expect(digest, isNot(contains(code)));
    expect(hashInvitationCode(' abcd-1234-efgh-5678 '), digest);
  });
}
