import 'dart:convert';

class SyncEntityConfig {
  const SyncEntityConfig(
      {required this.entityType,
      required this.tableName,
      this.projectIdColumn});
  final String entityType;
  final String tableName;
  final String? projectIdColumn;
}

class SyncEntityRegistry {
  static const Set<String> projectScopedEntityTypes = {
    'project_staff_assignments',
    'projects',
    'project_agreement_deductions',
    'project_milestones',
    'work_days',
    'material_purchases',
    'material_purchase_items',
    'supplier_payments',
    'fuel_entries',
    'labor_work_entries',
    'labor_payments',
    'labor_advances',
    'machine_usage_entries',
    'machine_rental_payments',
    'machine_repair_entries',
    'project_estimates',
    'project_estimate_items',
    'project_bills',
    'project_bill_receipts',
    'gst_entries',
    'project_expenses',
  };

  static const Map<String, SyncEntityConfig> _configs = {
    'companies':
        SyncEntityConfig(entityType: 'companies', tableName: 'companies'),
    'staff_users':
        SyncEntityConfig(entityType: 'staff_users', tableName: 'staff_users'),
    'roles': SyncEntityConfig(entityType: 'roles', tableName: 'roles'),
    'permissions':
        SyncEntityConfig(entityType: 'permissions', tableName: 'permissions'),
    'project_staff_assignments': SyncEntityConfig(
        entityType: 'project_staff_assignments',
        tableName: 'project_staff_assignments',
        projectIdColumn: 'project_id'),
    'bidder_profiles': SyncEntityConfig(
        entityType: 'bidder_profiles', tableName: 'bidder_profiles'),
    'tenders': SyncEntityConfig(entityType: 'tenders', tableName: 'tenders'),
    'tender_expenses': SyncEntityConfig(
        entityType: 'tender_expenses', tableName: 'tender_expenses'),
    'tender_documents': SyncEntityConfig(
        entityType: 'tender_documents', tableName: 'tender_documents'),
    'projects': SyncEntityConfig(
        entityType: 'projects', tableName: 'projects', projectIdColumn: 'id'),
    'project_agreement_deductions': SyncEntityConfig(
        entityType: 'project_agreement_deductions',
        tableName: 'project_agreement_deductions',
        projectIdColumn: 'project_id'),
    'project_milestones': SyncEntityConfig(
        entityType: 'project_milestones',
        tableName: 'project_milestones',
        projectIdColumn: 'project_id'),
    'work_days': SyncEntityConfig(
        entityType: 'work_days',
        tableName: 'work_days',
        projectIdColumn: 'project_id'),
    'suppliers':
        SyncEntityConfig(entityType: 'suppliers', tableName: 'suppliers'),
    'material_purchases': SyncEntityConfig(
        entityType: 'material_purchases',
        tableName: 'material_purchases',
        projectIdColumn: 'project_id'),
    'material_purchase_items': SyncEntityConfig(
        entityType: 'material_purchase_items',
        tableName: 'material_purchase_items',
        projectIdColumn: 'project_id'),
    'supplier_payments': SyncEntityConfig(
        entityType: 'supplier_payments',
        tableName: 'supplier_payments',
        projectIdColumn: 'project_id'),
    'fuel_types':
        SyncEntityConfig(entityType: 'fuel_types', tableName: 'fuel_types'),
    'fuel_entries': SyncEntityConfig(
        entityType: 'fuel_entries',
        tableName: 'fuel_entries',
        projectIdColumn: 'project_id'),
    'laborers': SyncEntityConfig(entityType: 'laborers', tableName: 'laborers'),
    'labor_work_entries': SyncEntityConfig(
        entityType: 'labor_work_entries',
        tableName: 'labor_work_entries',
        projectIdColumn: 'project_id'),
    'labor_payments': SyncEntityConfig(
        entityType: 'labor_payments',
        tableName: 'labor_payments',
        projectIdColumn: 'project_id'),
    'labor_advances': SyncEntityConfig(
        entityType: 'labor_advances',
        tableName: 'labor_advances',
        projectIdColumn: 'project_id'),
    'machines': SyncEntityConfig(entityType: 'machines', tableName: 'machines'),
    'machine_usage_entries': SyncEntityConfig(
        entityType: 'machine_usage_entries',
        tableName: 'machine_usage_entries',
        projectIdColumn: 'project_id'),
    'machine_rental_payments': SyncEntityConfig(
        entityType: 'machine_rental_payments',
        tableName: 'machine_rental_payments',
        projectIdColumn: 'project_id'),
    'machine_repair_entries': SyncEntityConfig(
        entityType: 'machine_repair_entries',
        tableName: 'machine_repair_entries',
        projectIdColumn: 'project_id'),
    'project_estimates': SyncEntityConfig(
        entityType: 'project_estimates',
        tableName: 'project_estimates',
        projectIdColumn: 'project_id'),
    'project_estimate_items': SyncEntityConfig(
        entityType: 'project_estimate_items',
        tableName: 'project_estimate_items'),
    'project_bills': SyncEntityConfig(
        entityType: 'project_bills',
        tableName: 'project_bills',
        projectIdColumn: 'project_id'),
    'project_bill_receipts': SyncEntityConfig(
        entityType: 'project_bill_receipts',
        tableName: 'project_bill_receipts',
        projectIdColumn: 'project_id'),
    'gst_entries': SyncEntityConfig(
        entityType: 'gst_entries',
        tableName: 'gst_entries',
        projectIdColumn: 'project_id'),
    'project_expenses': SyncEntityConfig(
        entityType: 'project_expenses',
        tableName: 'project_expenses',
        projectIdColumn: 'project_id'),
  };

  static SyncEntityConfig requireConfig(String entityType) {
    final normalized = normalize(entityType);
    final config = _configs[normalized];
    if (config == null) {
      throw ArgumentError.value(
          entityType, 'entityType', 'Unsupported sync entity type');
    }
    return config;
  }

  static Set<String> get entityTypes => _configs.keys.toSet();

  static String normalize(String entityType) {
    final key = entityType.trim();
    if (_configs.containsKey(key)) return key;
    final snake = key
        .replaceAllMapped(
            RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]}_${m[2]}')
        .toLowerCase();
    if (_configs.containsKey(snake)) return snake;
    final plural = snake.endsWith('s') ? snake : '${snake}s';
    return _configs.containsKey(plural) ? plural : snake;
  }

  static String? projectIdFromPayload(String entityType, String payloadJson) {
    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is! Map<String, dynamic>) return null;
      return projectIdFromMap(entityType, decoded);
    } catch (_) {
      return null;
    }
  }

  static String? projectIdFromMap(
    String entityType,
    Map<String, Object?> payload,
  ) {
    final config = requireConfig(entityType);
    final column = config.projectIdColumn;
    final raw = (column == null ? null : payload[column]) ??
        payload['projectId'] ??
        payload['project_id'];
    final value = raw?.toString();
    return value == null || value.isEmpty ? null : value;
  }

  static bool isAllowedSqlIdentifier(String value) =>
      RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(value);
}
