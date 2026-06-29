class SchemaMigrationPlan {
  const SchemaMigrationPlan._();

  static const int currentVersion = 1;

  static const List<String> phase1Rules = <String>[
    'Version 1 creates the full foundation schema for company, staff, tender, project, work, billing, reports, and sync.',
    'Future versions must be additive first, migrate data in transactions, and keep local data as source of truth.',
    'Money must stay in integer paise columns; decimal quantities must stay as strings to avoid binary floating point drift.',
    'Every migration must include a test before the app can be treated as release-ready.',
  ];
}
