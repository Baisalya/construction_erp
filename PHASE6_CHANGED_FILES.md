# Phase 6 Changed/Added Files

## Added/replaced core and startup
- lib/main.dart
- lib/firebase_options.dart
- lib/core/firebase/firebase_bootstrap.dart
- lib/core/permissions/permission_key.dart
- lib/app/routing/app_router.dart
- lib/shared/presentation/app_shell.dart

## Added/replaced auth
- lib/features/auth/domain/app_user.dart
- lib/features/auth/domain/auth_failure.dart
- lib/features/auth/domain/auth_session.dart
- lib/features/auth/domain/auth_repository_contract.dart
- lib/features/auth/domain/company_profile.dart
- lib/features/auth/data/auth_providers.dart
- lib/features/auth/data/firebase_auth_repository.dart
- lib/features/auth/data/firebase_company_repository.dart
- lib/features/auth/data/local_staff_access_repository.dart
- lib/features/auth/presentation/auth_gate.dart
- lib/features/auth/presentation/login_screen.dart
- lib/features/auth/presentation/register_owner_screen.dart
- lib/features/auth/presentation/company_setup_screen.dart
- lib/features/auth/presentation/blocked_access_screen.dart
- lib/features/auth/presentation/firebase_setup_error_screen.dart

## Added/replaced staff and permissions
- lib/features/staff/domain/staff_profile.dart
- lib/features/staff/domain/staff_access_policy.dart
- lib/features/staff/domain/default_role_permissions.dart
- lib/features/staff/domain/permission_service.dart
- lib/features/staff/domain/staff_role.dart
- lib/features/staff/domain/staff_invitation.dart
- lib/features/staff/data/staff_repository.dart
- lib/features/staff/presentation/staff_page.dart
- lib/features/staff/presentation/role_permission_screen.dart

## Tests and Firebase rules
- test/features/staff/phase6_permission_service_test.dart
- docs/firebase/firestore.rules
