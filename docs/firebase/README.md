# Phase 6 Firebase setup

Firebase is limited to authentication and company access metadata. Construction business ledgers remain in Drift/SQLite.

## Console setup

1. Enable Email/Password and Google in Firebase Authentication.
2. Create the Cloud Firestore database.
3. Review and deploy the Phase 6 rules:

   ```powershell
   firebase deploy --only firestore:rules
   ```

4. Keep the generated `lib/firebase_options.dart` and `android/app/google-services.json` aligned with the same Firebase project.

## Google login

- Android uses the official `google_sign_in` plugin and exchanges its ID token for a Firebase credential.
- Windows uses Firebase Auth's native Google provider flow.
- Register the SHA-1 and SHA-256 fingerprints for every Android signing certificate used to build the app.
- The Android `google-services.json` must include both the Android OAuth client and a web OAuth client (`client_type: 3`).
- On the first Android Google login, users choose either **Link existing password account** or **Continue with Google**. Linking signs into the existing password UID first and then attaches the Google credential, preserving company/staff access across devices.
- Keep Firebase Authentication configured as **One account per email address**.
- Windows Google login additionally requires a Google Cloud OAuth client of type **Desktop app**. Until that client is supplied, Windows continues to support email/password and password reset without invoking an unsupported mobile API.

## Password reset

The login page includes **Forgot password?** and calls Firebase Authentication's password-reset email flow. Customize the sender name and message in Firebase Console → Authentication → Templates → Password reset.

## Allowed metadata paths

- `companies/{companyId}`
- `companies/{companyId}/staff/{staffId}`
- `companies/{companyId}/roles/{roleId}`
- `companies/{companyId}/role_permissions/{roleId}`
- `companies/{companyId}/invitations/{inviteCode}`
- `companies/{companyId}/devices/{deviceId}`

All other paths are denied by default. `sync_deltas` is explicitly denied until Phase 7.

## Invitation flow

The owner creates an invitation and shares the displayed Company ID and invite code privately. Staff registers or logs in using the invited email, chooses **Join company with invite code**, then enters both values. The accepted user's canonical Firestore staff document uses their Firebase UID so security rules can check active/revoked access without trusting client-provided company data.
