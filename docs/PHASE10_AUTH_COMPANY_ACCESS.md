# Phase 10 Auth, Company Membership, and Project Access

Phase 10 keeps the ERP local-first while using Firebase for identity, company/staff metadata, invitations, permissions, device metadata and sync access validation.

## Identity

- Firebase UID is the canonical user identity.
- Email is normalized to lowercase for app user lookup and invitation matching.
- Email/password and Google sign-in can be linked to the same Firebase user.
- App profile metadata is stored in `app_users/{uid}` and cached locally in `app_user_profiles`.

## Company membership

- One user can belong to many companies.
- Role is membership-specific, not global.
- Local `company_memberships` and `active_workspace` keep the selected company and selected project.

## Project access

- Owners/admins can access all projects.
- Restricted staff can access only assigned projects.
- Dashboard, project switcher and sync permission guard use active company and assigned project scope.

## Invitation hardening

- Owner/admin invites staff by normalized email.
- A 16-character code is shown to the owner; Firestore stores only its SHA-256 digest.
- Invitation is accepted only after the invited person signs in or signs up.
- Invitation acceptance writes the staff, member, membership index and accepted status atomically.
- Wrong-email acceptance is blocked.
- Revoked/suspended staff access blocks company access and sync.

## Firestore rules

Rules include `app_users`, company `members`, invitation acceptance, user membership index and project-scoped sync delta validation.

- Users cannot promote their own role, owner flag or project access through the membership index.
- Profile status and membership security fields are immutable to ordinary users.
- Deploy rules and required indexes together with `firebase deploy --only firestore:rules,firestore:indexes`.

### Legacy staff lookup index

The primary login lookup reads `user_company_memberships/{uid}/companies`. Existing Phase 6–9 installations that only have `companies/{companyId}/staff` remain supported through a legacy collection-group fallback. That fallback requires this automatic index configuration:

- Collection group: `staff`
- Field: `firebaseUid`
- Order: Ascending
- Scope: Collection group

It is declared in `docs/firebase/firestore.indexes.json`. Deploy it with:

```powershell
firebase deploy --only firestore:indexes --project construction-erp-1ca05
```

Firestore can take several minutes to finish building a newly deployed index. Until it is ready, the app shows “Firebase setup required: staff lookup index is missing.” instead of treating the user as blocked.

## Local schema

Schema version 5 adds project scope to conflict records while preserving all existing local business data.
