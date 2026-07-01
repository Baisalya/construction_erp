import 'package:construction_erp/core/permissions/role_type.dart';
import 'package:construction_erp/core/permissions/staff_status.dart';
import 'package:construction_erp/core/providers/app_providers.dart';
import 'package:construction_erp/core/domain/write_context.dart';
import 'package:construction_erp/core/value_objects/money.dart';
import 'package:construction_erp/database/local_database.dart';
import 'package:construction_erp/features/project/data/project_repository.dart';
import 'package:construction_erp/features/project/domain/project_record.dart';
import 'package:construction_erp/features/auth/data/auth_providers.dart';
import 'package:construction_erp/features/staff/domain/default_role_permissions.dart';
import 'package:construction_erp/features/staff/domain/permission_service.dart';
import 'package:construction_erp/features/staff/domain/staff_access_policy.dart';
import 'package:construction_erp/features/staff/domain/staff_profile.dart';
import 'package:construction_erp/shared/presentation/app_shell.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ownerService = PermissionService(
    StaffAccessPolicy(
      staff: const StaffProfile(
        id: 'local-owner',
        companyId: 'local-company',
        name: 'Test owner',
        firebaseUid: 'local-owner',
        roleId: 'owner',
        roleType: RoleType.owner,
        status: StaffStatus.active,
      ),
      allowedPermissions: DefaultRolePermissions.permissionsFor(RoleType.owner),
    ),
  );

  Widget testApp(ConstructionDatabase database) {
    return ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(database),
        permissionServiceProvider.overrideWith((ref) async => ownerService),
      ],
      child: const MaterialApp(home: AppShell()),
    );
  }

  testWidgets('release app shell opens dashboard', (tester) async {
    final database = ConstructionDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      testApp(database),
    );
    await tester.pumpAndSettle();

    expect(find.text('Construction ERP Overview'), findsOneWidget);
  });

  testWidgets('mobile drawer and work forms render without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = ConstructionDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      testApp(database),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Material').last);
    await tester.pumpAndSettle();

    expect(find.text('Create a project before adding a material purchase.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop sidebar renders at Windows width without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = ConstructionDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      testApp(database),
    );
    await tester.pumpAndSettle();

    expect(find.text('Construction ERP Overview'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Fuel'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Fuel'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Reports'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Reports'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('project work and fuel forms render on mobile', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = ConstructionDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    const write = WriteContext(
        companyId: 'local-company',
        userId: 'local-owner',
        deviceId: 'local-device',
        nowMillis: 1700000000000);
    await ProjectRepository(database: database).createProject(
        ProjectDraft(
            projectName: 'Mobile project',
            agreementGrossValue: Money.rupees(100000)),
        write);

    await tester.pumpWidget(testApp(database));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work').last);
    await tester.pumpAndSettle();
    expect(find.text('Daily Work & Expenses'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fuel').last);
    await tester.pumpAndSettle();
    expect(find.text('Add fuel entry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings and report export controls fit mobile', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = ConstructionDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(testApp(database));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Backup and Restore'), findsOneWidget);
    expect(find.text('Create backup'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reports').last);
    await tester.pumpAndSettle();
    expect(find.text('Export PDF'), findsOneWidget);
    expect(find.text('Export Excel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all primary release pages open from Windows navigation',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = ConstructionDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(testApp(database));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tenders'));
    await tester.pumpAndSettle();
    expect(find.text('Tender Module'), findsOneWidget);

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    expect(find.text('Project Agreement Calculator'), findsOneWidget);

    await tester.tap(find.text('Billing'));
    await tester.pumpAndSettle();
    expect(find.text('Billing, GST and Profit/Loss'), findsOneWidget);

    await tester.tap(find.text('Staff'));
    await tester.pumpAndSettle();
    expect(find.text('Staff management'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Backup and Restore'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
