import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/app_user.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_repository_contract.dart';

class FirebaseAuthRepository implements AuthRepositoryContract {
  FirebaseAuthRepository({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;
  Future<void>? _googleInitialization;
  OAuthCredential? _pendingGoogleCredential;
  String? _pendingGoogleEmail;

  @override
  Stream<AppUser?> authStateChanges() =>
      _firebaseAuth.authStateChanges().map(_mapUser);

  @override
  AppUser? get currentUser => _mapUser(_firebaseAuth.currentUser);

  @override
  Future<AppUser> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final user = _mapUser(credential.user);
      if (user == null) {
        throw const AuthFailure(
            AuthFailureCode.unknown, 'Login failed. Please try again.');
      }
      return user;
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    }
  }

  @override
  Future<AppUser> registerWithEmailPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      if (displayName != null && displayName.trim().isNotEmpty) {
        await credential.user?.updateDisplayName(displayName.trim());
      }
      final user = _mapUser(_firebaseAuth.currentUser ?? credential.user);
      if (user == null) {
        throw const AuthFailure(AuthFailureCode.unknown,
            'Account could not be created. Please try again.');
      }
      return user;
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    }
  }

  @override
  Future<AppUser> registerOwnerWithEmailPassword({
    required String email,
    required String password,
    String? displayName,
  }) {
    return registerWithEmailPassword(
      email: email,
      password: password,
      displayName: displayName,
    );
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    try {
      final google = await _createGoogleCredential();
      _pendingGoogleCredential = google.credential;
      _pendingGoogleEmail = google.email;
      final credential =
          await _firebaseAuth.signInWithCredential(google.credential);
      final user = _mapUser(credential.user);
      if (user == null) {
        throw const AuthFailure(AuthFailureCode.unknown,
            'Google login did not return a user account.');
      }
      _clearPendingGoogleLink();
      return user;
    } on FirebaseAuthException catch (error) {
      if (error.code == 'account-exists-with-different-credential') {
        _pendingGoogleEmail = error.email ?? _pendingGoogleEmail;
        throw AuthFailure(
          AuthFailureCode.accountLinkRequired,
          'This email is already registered. Please sign in with password once to link Google.',
          email: _pendingGoogleEmail,
        );
      }
      throw mapFirebaseAuthException(error);
    } on GoogleSignInException catch (error) {
      throw mapGoogleSignInException(error);
    }
  }

  @override
  Future<AppUser> linkGoogleToCurrentUser() async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw const AuthFailure(AuthFailureCode.userNotFound,
          'Please sign in before connecting Google.');
    }
    try {
      final google = await _createGoogleCredential();
      final linked = await currentUser.linkWithCredential(google.credential);
      final user = _mapUser(linked.user ?? _firebaseAuth.currentUser);
      if (user == null) {
        throw const AuthFailure(AuthFailureCode.unknown,
            'Google was connected, but the account could not be loaded.');
      }
      return user;
    } on FirebaseAuthException catch (error) {
      if (error.code == 'provider-already-linked') {
        final user = _mapUser(_firebaseAuth.currentUser);
        if (user != null) return user;
      }
      throw mapFirebaseAuthException(error);
    } on GoogleSignInException catch (error) {
      throw mapGoogleSignInException(error);
    }
  }

  @override
  Future<AppUser> linkPasswordToCurrentUser({
    required String email,
    required String password,
  }) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw const AuthFailure(AuthFailureCode.userNotFound,
          'Please sign in before adding a password.');
    }
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw const AuthFailure(
          AuthFailureCode.invalidEmail, 'Enter a valid email address.');
    }
    try {
      final providers =
          currentUser.providerData.map((profile) => profile.providerId).toSet();
      if (!providers.contains(EmailAuthProvider.PROVIDER_ID) &&
          providers.contains(GoogleAuthProvider.PROVIDER_ID)) {
        final google = await _createGoogleCredential();
        await currentUser.reauthenticateWithCredential(google.credential);
      }
      final linked = await currentUser.linkWithCredential(
        EmailAuthProvider.credential(
            email: normalizedEmail, password: password),
      );
      final user = _mapUser(linked.user ?? _firebaseAuth.currentUser);
      if (user == null) {
        throw const AuthFailure(AuthFailureCode.unknown,
            'Password was added, but the account could not be loaded.');
      }
      return user;
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    }
  }

  @override
  Future<void> unlinkProvider(String providerId) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw const AuthFailure(AuthFailureCode.userNotFound,
          'Please sign in before changing sign-in methods.');
    }
    final providers = await getLinkedProviders();
    if (providers.length <= 1) {
      throw const AuthFailure(AuthFailureCode.permissionDenied,
          'Keep at least one sign-in method connected.');
    }
    if (!providers.contains(providerId)) {
      throw const AuthFailure(
          AuthFailureCode.unknown, 'This sign-in method is not connected.');
    }
    try {
      await currentUser.unlink(providerId);
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    }
  }

  @override
  Future<List<String>> getLinkedProviders() async {
    await _firebaseAuth.currentUser?.reload();
    final user = _firebaseAuth.currentUser;
    if (user == null) return const <String>[];
    final providers = user.providerData
        .map((profile) => profile.providerId)
        .where((providerId) => providerId.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return providers;
  }

  @override
  Future<AppUser> updateProfile({
    required String displayName,
    String? photoUrl,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AuthFailure(
        AuthFailureCode.userNotFound,
        'Please sign in before editing your account.',
      );
    }
    final name = displayName.trim();
    if (name.isEmpty) {
      throw const AuthFailure(
        AuthFailureCode.unknown,
        'Name is required.',
      );
    }
    try {
      await user.updateDisplayName(name);
      await user.updatePhotoURL(
        photoUrl?.trim().isEmpty == true ? null : photoUrl?.trim(),
      );
      await user.reload();
      final updated = _mapUser(_firebaseAuth.currentUser);
      if (updated == null) {
        throw const AuthFailure(
          AuthFailureCode.unknown,
          'Account details were saved but could not be reloaded.',
        );
      }
      return updated;
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _firebaseAuth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthFailure(
        AuthFailureCode.userNotFound,
        'Please sign in before changing your password.',
      );
    }
    if (newPassword.length < 6) {
      throw const AuthFailure(
        AuthFailureCode.weakPassword,
        'Use at least 6 characters for the new password.',
      );
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: email.trim().toLowerCase(),
          password: currentPassword,
        ),
      );
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    }
  }

  @override
  Future<AppUser> continueWithPendingGoogleCredential() async {
    final googleCredential = _pendingGoogleCredential;
    if (googleCredential == null) {
      throw const AuthFailure(AuthFailureCode.unknown,
          'Google login session expired. Start Google login again.');
    }
    try {
      final credential =
          await _firebaseAuth.signInWithCredential(googleCredential);
      final user = _mapUser(credential.user);
      if (user == null) {
        throw const AuthFailure(AuthFailureCode.unknown,
            'Google login did not return a user account.');
      }
      _clearPendingGoogleLink();
      return user;
    } on FirebaseAuthException catch (error) {
      if (error.code == 'account-exists-with-different-credential') {
        _pendingGoogleEmail = error.email ?? _pendingGoogleEmail;
        throw AuthFailure(
          AuthFailureCode.accountLinkRequired,
          'This email is already registered. Please sign in with password once to link Google.',
          email: _pendingGoogleEmail,
        );
      }
      throw mapFirebaseAuthException(error);
    }
  }

  @override
  Future<AppUser> linkPendingGoogleCredentialWithPassword(
      {required String password}) async {
    final email = _pendingGoogleEmail;
    final googleCredential = _pendingGoogleCredential;
    if (email == null || googleCredential == null) {
      throw const AuthFailure(AuthFailureCode.unknown,
          'Google linking session expired. Start Google login again.');
    }
    try {
      final existing = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final existingUser = existing.user;
      if (existingUser == null) {
        throw const AuthFailure(AuthFailureCode.unknown,
            'Could not open the existing password account.');
      }
      User? linkedUser;
      try {
        final linked = await existingUser.linkWithCredential(googleCredential);
        linkedUser = linked.user;
      } on FirebaseAuthException catch (error) {
        if (error.code == 'provider-already-linked') {
          linkedUser = existingUser;
        } else {
          await _firebaseAuth.signOut();
          throw mapFirebaseAuthException(error);
        }
      }
      final user = _mapUser(linkedUser ?? existingUser);
      if (user == null) {
        throw const AuthFailure(AuthFailureCode.unknown,
            'Google was linked, but the account could not be loaded.');
      }
      _clearPendingGoogleLink();
      return user;
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw const AuthFailure(
          AuthFailureCode.invalidEmail, 'Enter a valid email address.');
    }
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: normalizedEmail);
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    }
  }

  @override
  Future<void> reloadSession() async {
    await reloadCurrentUser();
  }

  @override
  Future<AppUser?> reloadCurrentUser() async {
    try {
      await _firebaseAuth.currentUser?.reload();
      return _mapUser(_firebaseAuth.currentUser);
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    }
  }

  @override
  Future<void> signOut() async {
    _clearPendingGoogleLink();
    await _firebaseAuth.signOut();
    if (defaultTargetPlatform == TargetPlatform.android &&
        _googleInitialization != null) {
      try {
        await _googleInitialization;
        await GoogleSignIn.instance.signOut();
      } on GoogleSignInException {
        // Firebase is already signed out.
      }
    }
  }

  Future<_GoogleCredential> _createGoogleCredential() async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      throw const AuthFailure(
        AuthFailureCode.providerConfiguration,
        'Windows Google login needs a Google Desktop OAuth client. Email/password login works on Windows.',
      );
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw const AuthFailure(
        AuthFailureCode.providerConfiguration,
        'Google login is currently configured for Android. Use email/password on this device.',
      );
    }
    _googleInitialization ??= GoogleSignIn.instance.initialize();
    await _googleInitialization;
    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuthentication = googleUser.authentication;
    final idToken = googleAuthentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthFailure(AuthFailureCode.providerConfiguration,
          'Google did not return a valid sign-in token.');
    }
    return _GoogleCredential(
      email: googleUser.email.trim().toLowerCase(),
      credential: GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  void _clearPendingGoogleLink() {
    _pendingGoogleCredential = null;
    _pendingGoogleEmail = null;
  }

  AppUser? _mapUser(User? user) {
    if (user == null) return null;
    final providers = user.providerData
        .map((profile) => profile.providerId)
        .where((providerId) => providerId.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return AppUser(
      uid: user.uid,
      email: user.email,
      phoneNumber: user.phoneNumber,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      isEmailVerified: user.emailVerified,
      linkedProviders: providers,
    );
  }
}

class _GoogleCredential {
  const _GoogleCredential({required this.email, required this.credential});
  final String email;
  final OAuthCredential credential;
}

AuthFailure mapGoogleSignInException(GoogleSignInException error) {
  return switch (error.code) {
    GoogleSignInExceptionCode.canceled => const AuthFailure(
        AuthFailureCode.signInCancelled,
        'Google sign-in was cancelled.',
      ),
    GoogleSignInExceptionCode.clientConfigurationError ||
    GoogleSignInExceptionCode.providerConfigurationError =>
      AuthFailure(
        AuthFailureCode.providerConfiguration,
        error.description ??
            'Google login configuration is incomplete. Check Firebase OAuth settings.',
      ),
    GoogleSignInExceptionCode.interrupted => const AuthFailure(
        AuthFailureCode.unknown,
        'Google sign-in was interrupted. Please try again.',
      ),
    _ => AuthFailure(
        AuthFailureCode.unknown,
        error.description ?? 'Google sign-in failed. Please try again.',
      ),
  };
}

AuthFailure mapFirebaseAuthException(FirebaseAuthException error) {
  return switch (error.code) {
    'invalid-email' => const AuthFailure(
        AuthFailureCode.invalidEmail, 'Enter a valid email address.'),
    'wrong-password' || 'invalid-credential' => const AuthFailure(
        AuthFailureCode.wrongPassword, 'Password is incorrect.'),
    'user-not-found' => const AuthFailure(
        AuthFailureCode.userNotFound, 'No account found for this email.'),
    'email-already-in-use' => const AuthFailure(
        AuthFailureCode.emailAlreadyInUse,
        'This email is already used with Google. Please continue with Google, then add password from Account Settings if needed.',
      ),
    'weak-password' => const AuthFailure(
        AuthFailureCode.weakPassword, 'Use a stronger password.'),
    'network-request-failed' => const AuthFailure(
        AuthFailureCode.networkUnavailable,
        'Network unavailable. Check internet and try again.'),
    'permission-denied' => const AuthFailure(AuthFailureCode.permissionDenied,
        'You do not have permission for this action.'),
    'provider-already-linked' => const AuthFailure(
        AuthFailureCode.accountLinkRequired,
        'This sign-in method is already connected.'),
    'account-exists-with-different-credential' => AuthFailure(
        AuthFailureCode.accountLinkRequired,
        'This email is already used with another sign-in method. Please sign in once to connect both methods.',
        email: error.email,
      ),
    'too-many-requests' => const AuthFailure(AuthFailureCode.tooManyRequests,
        'Too many attempts. Wait a little and try again.'),
    'credential-already-in-use' => const AuthFailure(
        AuthFailureCode.accountLinkRequired,
        'This Google account is already linked to another user. Sign in to that account or ask the owner for help.',
      ),
    'requires-recent-login' => const AuthFailure(
        AuthFailureCode.accountLinkRequired,
        'Please sign in again before changing sign-in methods.'),
    _ => AuthFailure(AuthFailureCode.unknown,
        error.message ?? 'Authentication failed. Please try again.'),
  };
}
