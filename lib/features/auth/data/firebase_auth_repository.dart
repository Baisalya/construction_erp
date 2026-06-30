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
  Stream<AppUser?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map(_mapUser);
  }

  @override
  AppUser? get currentUser => _mapUser(_firebaseAuth.currentUser);

  @override
  Future<AppUser> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = _mapUser(credential.user);
      if (user == null) {
        throw const AuthFailure(
          AuthFailureCode.unknown,
          'Login failed. Please try again.',
        );
      }
      return user;
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    }
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        _googleInitialization ??= GoogleSignIn.instance.initialize();
        await _googleInitialization;
        final googleUser = await GoogleSignIn.instance.authenticate();
        final googleAuthentication = googleUser.authentication;
        final idToken = googleAuthentication.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw const AuthFailure(
            AuthFailureCode.providerConfiguration,
            'Google did not return a valid sign-in token.',
          );
        }
        _pendingGoogleCredential =
            GoogleAuthProvider.credential(idToken: idToken);
        _pendingGoogleEmail = googleUser.email;
        throw AuthFailure(
          AuthFailureCode.googleAccountChoiceRequired,
          'Choose whether to link an existing password account or continue with Google.',
          email: googleUser.email,
        );
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        throw const AuthFailure(
          AuthFailureCode.providerConfiguration,
          'Windows Google login needs a Google Desktop OAuth client. Email/password login remains available.',
        );
      } else {
        throw const AuthFailure(
          AuthFailureCode.providerConfiguration,
          'Google login is configured only for Android and Windows.',
        );
      }
    } on GoogleSignInException catch (error) {
      throw mapGoogleSignInException(error);
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    }
  }

  @override
  Future<AppUser> continueWithPendingGoogleCredential() async {
    final googleCredential = _pendingGoogleCredential;
    if (googleCredential == null) {
      throw const AuthFailure(
        AuthFailureCode.unknown,
        'Google login session expired. Start Google login again.',
      );
    }
    try {
      final credential =
          await _firebaseAuth.signInWithCredential(googleCredential);
      final user = _mapUser(credential.user);
      if (user == null) {
        throw const AuthFailure(
          AuthFailureCode.unknown,
          'Google login did not return a user account.',
        );
      }
      _clearPendingGoogleLink();
      return user;
    } on FirebaseAuthException catch (error) {
      if (error.code == 'account-exists-with-different-credential') {
        _pendingGoogleEmail = error.email ?? _pendingGoogleEmail;
        throw AuthFailure(
          AuthFailureCode.accountLinkRequired,
          'This email already uses another login method. Enter the existing password to link Google.',
          email: _pendingGoogleEmail,
        );
      }
      throw mapFirebaseAuthException(error);
    }
  }

  @override
  Future<AppUser> linkPendingGoogleCredentialWithPassword({
    required String password,
  }) async {
    final email = _pendingGoogleEmail;
    final googleCredential = _pendingGoogleCredential;
    if (email == null || googleCredential == null) {
      throw const AuthFailure(
        AuthFailureCode.unknown,
        'Google linking session expired. Start Google login again.',
      );
    }
    try {
      final existing = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final existingUser = existing.user;
      if (existingUser == null) {
        throw const AuthFailure(
          AuthFailureCode.unknown,
          'Could not open the existing password account.',
        );
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
        throw const AuthFailure(
          AuthFailureCode.unknown,
          'Google was linked, but the account could not be loaded.',
        );
      }
      _clearPendingGoogleLink();
      return user;
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw const AuthFailure(
        AuthFailureCode.invalidEmail,
        'Enter a valid email address.',
      );
    }
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: normalizedEmail);
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    }
  }

  @override
  Future<AppUser> registerOwnerWithEmailPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (displayName != null && displayName.trim().isNotEmpty) {
        await credential.user?.updateDisplayName(displayName.trim());
      }
      final user = _mapUser(_firebaseAuth.currentUser ?? credential.user);
      if (user == null) {
        throw const AuthFailure(
          AuthFailureCode.unknown,
          'Owner registration failed. Please try again.',
        );
      }
      return user;
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    }
  }

  @override
  Future<void> reloadSession() async {
    try {
      await _firebaseAuth.currentUser?.reload();
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
        // Firebase is already signed out. A Google SDK cleanup failure must
        // not prevent the local auth gate from closing the company session.
      }
    }
  }

  void _clearPendingGoogleLink() {
    _pendingGoogleCredential = null;
    _pendingGoogleEmail = null;
  }

  AppUser? _mapUser(User? user) {
    if (user == null) {
      return null;
    }
    return AppUser(
      uid: user.uid,
      email: user.email,
      phoneNumber: user.phoneNumber,
      displayName: user.displayName,
      isEmailVerified: user.emailVerified,
    );
  }
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
        AuthFailureCode.invalidEmail,
        'Enter a valid email address.',
      ),
    'wrong-password' || 'invalid-credential' => const AuthFailure(
        AuthFailureCode.wrongPassword,
        'Password is incorrect.',
      ),
    'user-not-found' => const AuthFailure(
        AuthFailureCode.userNotFound,
        'No account found for this email.',
      ),
    'email-already-in-use' => const AuthFailure(
        AuthFailureCode.emailAlreadyInUse,
        'This email is already registered.',
      ),
    'weak-password' => const AuthFailure(
        AuthFailureCode.weakPassword,
        'Use a stronger password.',
      ),
    'network-request-failed' => const AuthFailure(
        AuthFailureCode.networkUnavailable,
        'Network unavailable. Check internet and try again.',
      ),
    'permission-denied' => const AuthFailure(
        AuthFailureCode.permissionDenied,
        'You do not have permission for this company.',
      ),
    'account-exists-with-different-credential' => AuthFailure(
        AuthFailureCode.accountLinkRequired,
        'An account already exists for this email. Sign in with its current method, then link Google.',
        email: error.email,
      ),
    'too-many-requests' => const AuthFailure(
        AuthFailureCode.tooManyRequests,
        'Too many attempts. Wait a little and try again.',
      ),
    'credential-already-in-use' => const AuthFailure(
        AuthFailureCode.accountLinkRequired,
        'This Google account is already linked to another user. Sign in to that account or contact the owner.',
      ),
    _ => AuthFailure(
        AuthFailureCode.unknown,
        error.message ?? 'Authentication failed. Please try again.',
      ),
  };
}
