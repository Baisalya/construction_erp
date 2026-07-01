class AppUserProfile {
  const AppUserProfile({
    required this.uid,
    required this.normalizedEmail,
    this.displayName,
    this.photoUrl,
    this.phone,
    this.lastLoginAt,
    this.defaultCompanyId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;
  final String normalizedEmail;
  final String? displayName;
  final String? photoUrl;
  final String? phone;
  final int? lastLoginAt;
  final String? defaultCompanyId;
  final int createdAt;
  final int updatedAt;
}

String normalizeEmail(Object? email) =>
    (email ?? '').toString().trim().toLowerCase();
