import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_bootstrap.dart';
import '../../../database/database_providers.dart';
import '../../staff/data/staff_repository.dart';
import '../../staff/domain/permission_service.dart';
import '../../staff/domain/staff_access_policy.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository_contract.dart';
import 'firebase_auth_repository.dart';
import 'firebase_company_repository.dart';
import 'local_staff_access_repository.dart';

final firebaseBootstrapProvider = Provider<FirebaseBootstrapResult>((ref) {
  return FirebaseBootstrapResult.failed(
    'Firebase bootstrap was not provided by main.dart.',
    StackTrace.current,
  );
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authRepositoryProvider = Provider<AuthRepositoryContract>((ref) {
  return FirebaseAuthRepository(firebaseAuth: ref.watch(firebaseAuthProvider));
});

final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final localStaffAccessRepositoryProvider =
    Provider<LocalStaffAccessRepository>((ref) {
  return LocalStaffAccessRepository(database: ref.watch(localDatabaseProvider));
});

final companyRepositoryProvider = Provider<FirebaseCompanyRepository>((ref) {
  return FirebaseCompanyRepository(database: ref.watch(localDatabaseProvider));
});

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  return StaffRepository(database: ref.watch(localDatabaseProvider));
});

final userAccessPolicyProvider =
    FutureProvider.family<StaffAccessPolicy?, AppUser>(
  (ref, user) async {
    return ref.watch(companyRepositoryProvider).bootstrapAccessForUser(user);
  },
);

final latestOfflineAccessPolicyProvider =
    FutureProvider<StaffAccessPolicy?>((ref) {
  return ref.watch(localStaffAccessRepositoryProvider).readLatestCachedPolicy();
});

final permissionServiceProvider =
    FutureProvider<PermissionService?>((ref) async {
  final firebaseState = ref.watch(firebaseBootstrapProvider);
  if (!firebaseState.isReady) {
    final offlinePolicy = await ref
        .watch(localStaffAccessRepositoryProvider)
        .readLatestCachedPolicy();
    return offlinePolicy == null ? null : PermissionService(offlinePolicy);
  }

  final user = ref.watch(authRepositoryProvider).currentUser;
  if (user == null) {
    final offlinePolicy = await ref
        .watch(localStaffAccessRepositoryProvider)
        .readLatestCachedPolicy();
    return offlinePolicy == null ? null : PermissionService(offlinePolicy);
  }
  final policy = await ref.watch(userAccessPolicyProvider(user).future);
  return policy == null ? null : PermissionService(policy);
});
