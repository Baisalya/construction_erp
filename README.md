# Construction ERP — Phase 5

Local-first Flutter Construction ERP scaffold for Android and Windows.

This ZIP contains Phase 1 + Phase 2 + Phase 3 + Phase 4 + Phase 5 foundation.

## Phase 5 focus

Billing, GST, estimate and profit/loss UI.

## Included

- Clean Flutter structure.
- Android + Windows folders.
- Drift/SQLite local schema foundation.
- Firebase-ready company/staff/sync metadata structure.
- Riverpod providers.
- GoRouter app entry.
- Responsive shell for Android and Windows.
- Tender module foundation and tender-to-project conversion from Phase 2.
- Project agreement calculator from Phase 3.
- Material/Labor/Machinery/Fuel/Repair logic from Phase 4.
- Billing module activated in Phase 5.
- Reports module activated in Phase 5.
- Estimate records and estimate item totals.
- Running/final/advance bill records.
- GST input/output entries.
- Bill receipts and pending receivable update.
- Project profit/loss summary from ledger records.
- Local sync queue delta creation for Phase 5 writes.
- Unit tests for Phase 5 calculations.

## Important architecture rules kept

- SQLite/Drift local database remains the source of truth.
- Firebase is still only prepared for auth/company/staff/sync metadata.
- No direct Firebase query inside UI.
- No direct database business logic inside widgets.
- Billing calculations live in repository/domain service classes.
- Money is stored as integer paise.
- Decimal quantities are stored safely as text.

## Verify locally

This sandbox does not include Flutter/Dart, so run these locally:

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d windows
flutter run -d android
```

## Next phase

Phase 6 should add Firebase Auth, company setup, staff management, roles and permissions.
