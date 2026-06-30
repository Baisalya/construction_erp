enum AuthFailureCode {
  invalidEmail,
  wrongPassword,
  userNotFound,
  emailAlreadyInUse,
  weakPassword,
  networkUnavailable,
  permissionDenied,
  revokedOrInactiveStaff,
  firebaseNotConfigured,
  signInCancelled,
  providerConfiguration,
  googleAccountChoiceRequired,
  accountLinkRequired,
  tooManyRequests,
  unknown,
}

class AuthFailure implements Exception {
  const AuthFailure(this.code, this.message, {this.email});

  final AuthFailureCode code;
  final String message;
  final String? email;

  @override
  String toString() => message;
}
