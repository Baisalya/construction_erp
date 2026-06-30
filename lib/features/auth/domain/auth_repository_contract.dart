import 'app_user.dart';

abstract interface class AuthRepositoryContract {
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  Future<AppUser> signInWithEmailPassword({
    required String email,
    required String password,
  });

  Future<AppUser> signInWithGoogle();

  Future<AppUser> linkPendingGoogleCredentialWithPassword({
    required String password,
  });

  Future<AppUser> continueWithPendingGoogleCredential();

  Future<void> sendPasswordResetEmail(String email);

  Future<AppUser> registerOwnerWithEmailPassword({
    required String email,
    required String password,
    String? displayName,
  });

  Future<void> reloadSession();

  Future<void> signOut();
}
