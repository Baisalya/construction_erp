class AppUser {
  const AppUser({
    required this.uid,
    this.email,
    this.phoneNumber,
    this.displayName,
    this.photoUrl,
    this.isEmailVerified = false,
    this.linkedProviders = const <String>[],
  });

  final String uid;
  final String? email;
  final String? phoneNumber;
  final String? displayName;
  final String? photoUrl;
  final bool isEmailVerified;
  final List<String> linkedProviders;

  String get normalizedEmail => (email ?? '').trim().toLowerCase();

  /// Firebase UID is the stable global identity. Firebase Auth can return a
  /// freshly mapped [AppUser] on every read, so value equality prevents
  /// Riverpod family providers from being recreated for the same account.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AppUser && other.uid == uid;

  @override
  int get hashCode => uid.hashCode;
}
