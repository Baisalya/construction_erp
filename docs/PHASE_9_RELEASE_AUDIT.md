# Phase 9 release audit

## Baseline inspected

- Flutter feature, domain, repository, provider, routing, and theme structure
- Android Gradle, manifest, Firebase configuration, launcher placeholder, and package identity
- Windows CMake, runner resources, plugin registration, title, icon, and executable identity
- Drift schema versions 1–3, idempotent setup, audit columns, soft deletion, indexes, and migrations
- Firebase Auth/company/staff metadata boundaries and Firestore rules/indexes
- Sync queue, upload/download, idempotent apply, permission guard, conflict resolution, device identity, backup/restore, PDF, and Excel export
- Existing unit, repository, migration, permission, sync, service, and widget tests

Baseline commands on Flutter 3.41.9: dependency resolution succeeded, analysis had zero issues, and all 76 existing tests passed.

## Problems found before Phase 9 changes

- Phase 5 names remained in package, Windows executable, README, and visible module labels.
- Android release manifest did not declare Internet access although Firebase is used.
- Windows runner lacked product/version metadata.
- Android used drawer-only navigation; Windows content could stretch excessively on ultra-wide displays.
- Tender, Material, Labor, and Machinery lists did not switch to desktop tables.
- Several cost quick-entry forms could submit invalid or negative input to repositories.
- Work, Material, Labor, Machinery, Fuel, and staff access changes lacked confirmation.
- Money formatting did not use Indian digit grouping.
- Cost rows did not consistently show total, paid, pending, and a clear payment status.
- Sync/conflict screens exposed record types, IDs, versions, raw JSON, and raw errors.
- Staff table exposed Firebase user identifiers.
- Authentication and several module errors could expose raw exception text.
- An unused phase-placeholder UI file remained in the source tree.
- Explicit tests were missing for tenant isolation/project filters, multiple bidder profiles, labor advance balance, own-machine daily/weekly charging, final-bill deductions, Indian money formatting, and full release navigation.

## Phase 9 result

- Unified Material 3 theme, spacing, cards, input styling, button sizing, tables, and responsive navigation.
- Android has bottom navigation for primary work plus a complete drawer; Windows keeps a stable sidebar and bounded content width.
- Desktop tables are used for Tender, Project, Material, Labor, Machinery, Billing, and Staff lists; mobile retains cards.
- Positive numeric input filtering and pre-submit validity checks were added to quick-entry cost forms.
- Destructive actions now require confirmation and remain soft deletes where the repositories already use soft deletion.
- Currency uses Indian grouping and every cost-list row shows Total, Paid, Pending, and Paid/Partial/Pending.
- Reports show agreement, estimated/actual costs by category, GST, received/pending, payable, and agreement/received profit or loss.
- Sync wording is user-facing; conflict JSON and developer merge controls are only available in debug builds.
- Release identity is `Construction ERP` version `1.0.0+9`; Android and Windows metadata are aligned.
- Android uses Flutter 3.41's AGP 8.11.1 / Gradle 8.14 toolchain with Kotlin 2.3 metadata support. Release signing is conditional on the publisher's private `android/key.properties`.
- No broad storage permission is requested. Backup/export uses the platform file picker/document flow.
- Firebase configuration contains normal public client configuration only; no private service-account credential is included.

## Known publisher-owned items

- Replace the placeholder Android/Windows icon when final brand artwork is available.
- Add the publisher's Android release keystore and private `android/key.properties`, then rebuild before installation or store upload. The verified APK/AAB produced during this audit are intentionally unsigned because no publisher key was supplied.
- Firebase service availability and Firestore deployment must be verified against the production Firebase project by the release owner.
