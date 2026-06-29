import 'package:flutter/material.dart';

enum AppModule {
  dashboard,
  tender,
  project,
  work,
  material,
  labor,
  machinery,
  fuel,
  billing,
  reports,
  staff,
  settings,
}

extension AppModuleX on AppModule {
  String get title {
    return switch (this) {
      AppModule.dashboard => 'Dashboard',
      AppModule.tender => 'Tenders',
      AppModule.project => 'Projects',
      AppModule.work => 'Work',
      AppModule.material => 'Material',
      AppModule.labor => 'Labor',
      AppModule.machinery => 'Machinery',
      AppModule.fuel => 'Fuel',
      AppModule.billing => 'Billing',
      AppModule.reports => 'Reports',
      AppModule.staff => 'Staff',
      AppModule.settings => 'Settings',
    };
  }

  String get simpleDescription {
    return switch (this) {
      AppModule.dashboard => 'Company overview and important pending items.',
      AppModule.tender =>
        'Tender accounts, applications, expenses, and results.',
      AppModule.project =>
        'Selected tender projects, agreement value, and milestones.',
      AppModule.work => 'Material, labor, and machinery work sections.',
      AppModule.material => 'Suppliers, bills, material items, and payments.',
      AppModule.labor =>
        'Labor work, thika/daywise entries, payments, and advances.',
      AppModule.machinery =>
        'Own/rental machines, fuel, repair, usage, and payments.',
      AppModule.fuel => 'Diesel, petrol, and custom fuel usage by project.',
      AppModule.billing =>
        'Estimate, running bill, final bill, GST, TDS, and receipts.',
      AppModule.reports =>
        'Project cost, profit/loss, GST, payable, and receivable reports.',
      AppModule.staff =>
        'Company staff, roles, permissions, devices, and access status.',
      AppModule.settings =>
        'Company profile, financial year, backup, and app preferences.',
    };
  }

  IconData get icon {
    return switch (this) {
      AppModule.dashboard => Icons.dashboard_outlined,
      AppModule.tender => Icons.description_outlined,
      AppModule.project => Icons.account_tree_outlined,
      AppModule.work => Icons.construction_outlined,
      AppModule.material => Icons.inventory_2_outlined,
      AppModule.labor => Icons.engineering_outlined,
      AppModule.machinery => Icons.precision_manufacturing_outlined,
      AppModule.fuel => Icons.local_gas_station_outlined,
      AppModule.billing => Icons.receipt_long_outlined,
      AppModule.reports => Icons.query_stats_outlined,
      AppModule.staff => Icons.groups_2_outlined,
      AppModule.settings => Icons.settings_outlined,
    };
  }

  String get primaryTableName {
    return switch (this) {
      AppModule.dashboard => 'projects',
      AppModule.tender => 'tenders',
      AppModule.project => 'projects',
      AppModule.work => 'work_days',
      AppModule.material => 'material_purchases',
      AppModule.labor => 'labor_work_entries',
      AppModule.machinery => 'machine_usage_entries',
      AppModule.fuel => 'fuel_entries',
      AppModule.billing => 'project_bills',
      AppModule.reports => 'projects',
      AppModule.staff => 'staff_users',
      AppModule.settings => 'companies',
    };
  }
}
