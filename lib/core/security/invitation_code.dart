import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Normalizes the code users type or paste from an invitation.
String normalizeInvitationCode(String value) =>
    value.trim().replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

/// Firestore stores only this digest. The readable invitation code is shown
/// once to the owner and kept in the local invitation record.
String hashInvitationCode(String value) {
  final normalized = normalizeInvitationCode(value);
  return sha256.convert(utf8.encode(normalized)).toString();
}
