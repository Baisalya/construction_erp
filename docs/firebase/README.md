# Phase 7 Firebase setup

Firebase is limited to authentication, company access metadata, and the
`sync_deltas` transport log. Construction business ledgers remain in
Drift/SQLite.

## Console setup

1. Enable Email/Password and Google in Firebase Authentication.
2. Create the Cloud Firestore database.
3. Review and deploy the Phase 7 rules and sync query index:

   ```powershell
   firebase deploy --only firestore:rules,firestore:indexes
   ```

4. Keep `lib/firebase_options.dart` and
   `android/app/google-services.json` aligned with the same Firebase project.

## Google login

- Android uses the official `google_sign_in` plugin and exchanges its ID token
  for a Firebase credential.
- Windows uses Firebase Auth's native Google provider flow.
- Register the SHA-1 and SHA-256 fingerprints for every Android signing
  certificate used to build the app.
- The Android `google-services.json` must include both the Android OAuth client
  and a web OAuth client (`client_type: 3`).
- On the first Android Google login, users choose either **Link existing
  password account** or **Continue with Google**. Linking preserves the
  existing Firebase UID and company/staff access.
- Keep Firebase Authentication configured as **One account per email address**.
- Windows Google login additionally requires a Google Cloud OAuth client of
  type **Desktop app**. Email/password and password reset remain available.

## Password reset

The login page includes **Forgot password?** and calls Firebase
Authentication's password-reset email flow. Customize it in Firebase Console >
Authentication > Templates > Password reset.

## Allowed metadata and transport paths

- `companies/{companyId}`
- `companies/{companyId}/staff/{staffId}`
- `companies/{companyId}/roles/{roleId}`
- `companies/{companyId}/role_permissions/{roleId}`
- `companies/{companyId}/invitations/{inviteCode}`
- `companies/{companyId}/devices/{deviceId}`
- `companies/{companyId}/sync_deltas/{deltaId}`

All other paths are denied by default. `sync_deltas` is transport-only; normal
Firestore business collections remain denied.

## Invitation flow

The owner creates an invitation and shares the Company ID and invite code.
Staff registers or logs in using the invited email and joins with both values.
The canonical Firestore staff document uses the Firebase UID so security rules
can enforce active/revoked access without trusting client-provided company data.
