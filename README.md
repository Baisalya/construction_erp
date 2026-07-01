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
- Foreground automatic sync after startup, resume, local saves, and allowed remote changes
- Single-flight sync, automatic retry, duplicate protection, conflict review, local backup/restore, PDF, and Excel export

SQLite/Drift is the source of truth for business records. Firebase is limited to authentication, company/staff metadata, permissions, device metadata, and sync changes.

Automatic sharing improves day-to-day collaboration but does not replace backup. Until the Phase 11 server-validated financial ledger is installed, use one nominated operator/device for company payments and client receipts. The operating procedure and status meanings are documented in [USER_MANUAL.md](USER_MANUAL.md).

## Release identity

- App name: `Construction ERP`
- Dart package: `construction_erp`
- Version: `1.0.0+10`
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


## Phase 10 production auth/company access

Phase 10 adds production-level Firebase Auth provider linking, app user profiles, multi-company memberships, active company switching, project filtering, staff invitation hardening, revoked/suspended staff blocking, and Firestore rules for membership-scoped sync access. Local SQLite/Drift remains the source of truth for ERP business records.

Before publishing Android builds, create and securely back up the private Play upload keystore, then copy `android/key.properties.example` to `android/key.properties` and replace every placeholder. Release compilation works without the private credential, but an unsigned APK/AAB must never be distributed.

## Firebase production setup checklist

This project is currently configured for the Firebase project `construction-erp-1ca05`. Before using it for a real company, review the checklist below. Firebase is used for login, company/staff access, invitations, device metadata and sync deltas only; ERP business records still live first in local SQLite/Drift.

### 1. Firebase CLI login and project check

```bash
firebase login
firebase projects:list
firebase use construction-erp-1ca05
```

If this repo is moved to a new Firebase project, run FlutterFire configuration again and replace the project IDs safely:

```bash
flutterfire configure
```

Expected Firebase files:

- `firebase.json` points to Firestore rules and indexes.
- `docs/firebase/firestore.rules` contains production security rules.
- `docs/firebase/firestore.indexes.json` contains required Firestore indexes.
- `android/app/google-services.json` contains Android Firebase config.
- `lib/firebase_options.dart` contains FlutterFire config for Android and Windows.

### 2. Enable Firebase Authentication providers

In Firebase Console -> Authentication -> Sign-in method, enable:

- Email/password
- Google

For Android Google sign-in, add the correct SHA fingerprints in Firebase Console:

- Debug SHA-1/SHA-256 for developer testing
- Release SHA-1/SHA-256 from the Play/upload keystore before production

After changing SHA fingerprints, download a fresh `google-services.json` and place it in `android/app/google-services.json`.

Windows email/password login works through Firebase Auth. Google login on Windows must remain platform-safe; if browser/provider flow is not configured, Windows should show a clear supported sign-in option instead of crashing.

### 3. Deploy Firestore rules and indexes

Always deploy rules and indexes before testing login, staff lookup, company switching or sync:

```bash
firebase deploy --only firestore:rules,firestore:indexes --project construction-erp-1ca05
```

If only the missing staff lookup index needs to be fixed, this is enough:

```bash
firebase deploy --only firestore:indexes --project construction-erp-1ca05
```

Important required index for older Phase 6-9 staff records:

| Setting | Value |
| --- | --- |
| Collection group | `staff` |
| Field | `firebaseUid` |
| Order | Ascending |
| Scope | Collection group |

This index is declared in `docs/firebase/firestore.indexes.json`. Firestore can take a few minutes to build it after deployment. During that time the app may show:

`Firebase setup required: staff lookup index is missing.`

That message means Firebase setup is incomplete or still building; it is not a staff permission problem.

Invitation pages also need the collection-group indexes declared for `invitations` in the same file. If Firebase says an invitation index is `Building`, wait until it becomes `Enabled`, then reopen the app. Do not loosen Firestore rules to bypass this.

### 4. Required Firestore collections

Production data is organized around these collections:

| Path | Purpose |
| --- | --- |
| `app_users/{uid}` | Global user profile keyed by Firebase UID |
| `companies/{companyId}` | Company profile and owner metadata |
| `companies/{companyId}/members/{uid}` | Company-specific role, status and project access |
| `companies/{companyId}/staff/{staffId}` | Existing staff records kept for compatibility |
| `companies/{companyId}/invitations/{inviteId}` | Staff invitations and invite status |
| `user_company_memberships/{uid}/companies/{companyId}` | Fast company switcher/login membership index |
| `companies/{companyId}/sync_deltas/{deltaId}` | Sync upload/download records |

The preferred production login lookup is `user_company_memberships/{uid}/companies`. The legacy `companies/{companyId}/staff` lookup remains only to support older data.

### 5. Staff and company access rules

Before production, verify:

- Owner account has an active company membership.
- Staff accounts are invited through Staff Management, not manually created in Firebase Auth.
- Revoked/suspended staff cannot open the company or sync.
- Restricted staff only see assigned projects.
- Company switcher does not show another company's data.
- Dashboard, reports, payments and sync are filtered by active company and allowed projects.

### 6. Temporary automatic sync note

The app now performs temporary automatic sync:

- On app start/resume
- After local save
- On allowed remote Firestore changes
- Every few seconds while open
- With retry after connection returns

Manual Sync remains available as a backup.

Until the Phase 11 server-validated financial ledger is implemented, use one nominated operator/device for serious payment and receipt entry. Multiple devices can work on different records, but two devices entering payments against the same pending balance at the same time can still create a business conflict.

### 7. Firebase safety rules for release

Before final production release:

- Do not commit private keystore files or `android/key.properties`.
- Firebase public config files are allowed, but never store private service account JSON in the app.
- Do not loosen Firestore rules to solve login issues.
- Fix missing indexes by deploying `docs/firebase/firestore.indexes.json`.
- Keep local backup/restore enabled because Firebase sync is not a replacement for backups.
- Test with one owner and at least two staff accounts before handing the app to a company.
