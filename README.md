# Construction ERP

Production-oriented, local-first Flutter application for Android and Windows.

For step-by-step instructions for owners and staff, read [USER_MANUAL.md](USER_MANUAL.md).

## Included modules

- Tender applications, bidder profiles, expenses, documents, and conversion to projects
- Projects, agreement calculation, deductions, milestones, and site diary
- Material, supplier payments, labor, machinery, fuel, repairs, and other expenses
- Estimates, running/final bills, receipts, GST, and profit/loss reports
- Owner/staff roles, project assignments, and permission enforcement
- Firebase authentication and company/staff metadata
- Delta sync, duplicate protection, conflict review, local backup/restore, PDF, and Excel export

SQLite/Drift is the source of truth for business records. Firebase is limited to authentication, company/staff metadata, permissions, device metadata, and sync changes.

## Release identity

- App name: `Construction ERP`
- Dart package: `construction_erp`
- Version: `1.0.0+9`
- Android application ID: `com.baishalya.construction_erp`
- Windows executable: `construction_erp.exe`

The bundled icons are release-safe placeholders and can be replaced with final company artwork without changing app logic.

## Verify

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
flutter build windows --release
```

Android store publishing requires the private release keystore owned by the publisher. Copy `android/key.properties.example` to `android/key.properties`, fill in the private values, and run the release builds again. The real properties and keystore files are ignored by Git and must not be placed in the ZIP.
