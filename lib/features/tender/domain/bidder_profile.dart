import 'package:flutter/foundation.dart';

@immutable
class BidderProfileDraft {
  const BidderProfileDraft({
    required this.profileName,
    this.portalName,
    this.username,
    this.registeredMobile,
    this.registeredEmail,
    this.notes,
  });

  final String profileName;
  final String? portalName;
  final String? username;
  final String? registeredMobile;
  final String? registeredEmail;
  final String? notes;

  Map<String, Object?> toPayload() {
    return {
      'profileName': profileName,
      'portalName': portalName,
      'username': username,
      'registeredMobile': registeredMobile,
      'registeredEmail': registeredEmail,
      'notes': notes,
    };
  }
}

@immutable
class BidderProfile {
  const BidderProfile({
    required this.id,
    required this.companyId,
    required this.profileName,
    this.portalName,
    this.username,
    this.registeredMobile,
    this.registeredEmail,
    this.notes,
  });

  final String id;
  final String companyId;
  final String profileName;
  final String? portalName;
  final String? username;
  final String? registeredMobile;
  final String? registeredEmail;
  final String? notes;
}
