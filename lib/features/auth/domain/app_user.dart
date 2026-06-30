class AppUser {
  const AppUser({
    required this.uid,
    this.email,
    this.phoneNumber,
    this.displayName,
    this.isEmailVerified = false,
  });

  final String uid;
  final String? email;
  final String? phoneNumber;
  final String? displayName;
  final bool isEmailVerified;
}
