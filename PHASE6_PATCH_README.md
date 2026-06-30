# Construction ERP Phase 6 Overlay Patch

This zip contains Phase 6 implementation files for the existing repo:

`https://github.com/Baisalya/construction_erp.git`

Because the execution sandbox could not resolve `github.com`, this is an **overlay patch**, not a fully cloned repository zip. Extract/copy the contents of this zip directly over the root of your existing `construction_erp` project.

## What this patch adds

- Firebase bootstrap with safe error screen when `firebase_options.dart` is not configured.
- Firebase Auth repository for owner/staff login and owner registration.
- Company setup flow after first owner login.
- Local-first company/staff/roles/permissions writes using the existing Drift/SQLite schema.
- Firestore company/staff/roles/role_permissions/devices metadata writes.
- Staff access cache for offline login/access checks.
- Staff management page with invite flow.
- Role/permission overview page.
- Permission service and default role permission matrix.
- Firestore rules draft in `docs/firebase/firestore.rules`.
- Phase 6 permission tests.

## What is intentionally not added

- No Phase 7 business-data sync.
- No tender/project/work/billing upload to Firestore.
- No conflict sync logic.
- Existing Phase 1–5 offline business modules are left local-first.

## Apply steps

1. Backup your current project.
2. Extract this zip into your existing repo root so paths like `lib/main.dart` replace the old files.
3. From repo root, run:

```bash
flutter pub get
flutterfire configure --project=<your-firebase-project-id>
flutter analyze
flutter test
flutter run -d windows
flutter run -d android
```

`lib/firebase_options.dart` and Android `google-services.json` are configured for the current Firebase project. Re-run `flutterfire configure` only when changing Firebase projects or app registrations.

## Manual test checklist

1. Launch app before Firebase config: app should show Firebase setup error, not crash.
2. Configure Firebase and enable Email/Password Auth.
3. Register owner account.
4. Create company profile.
5. Confirm owner reaches dashboard.
6. Open Staff page.
7. Add staff invite.
8. Check Firestore: company, owner staff, roles, role_permissions, invitation and device metadata exist.
9. Disable internet after successful login: cached active staff should still open app.
10. Set staff status revoked/inactive in local cache or Firestore refresh path: access should be blocked.
11. Verify Tender/Project/Work/Billing pages still use local DB and do not upload business data.
