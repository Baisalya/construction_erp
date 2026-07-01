import 'app_user.dart';

abstract interface class AuthRepositoryContract {
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  Future<AppUser> signInWithEmailPassword({
    required String email,
    required String password,
  });

  Future<AppUser> registerWithEmailPassword({
    required String email,
    required String password,
    String? displayName,
  });

  Future<AppUser> signInWithGoogle();

  Future<AppUser> linkGoogleToCurrentUser();

  Future<AppUser> linkPasswordToCurrentUser({
    required String email,
    required String password,
  });

  Future<void> unlinkProvider(String providerId);

  Future<List<String>> getLinkedProviders();

  Future<AppUser> updateProfile({
    required String displayName,
    String? photoUrl,
  });

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

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

  Future<AppUser?> reloadCurrentUser();

  Future<void> signOut();
}
