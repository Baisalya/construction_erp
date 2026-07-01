import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

const missingStaffLookupIndexMessage =
    'Firebase setup required: staff lookup index is missing.';

const missingStaffLookupIndexDeveloperDetails = '''
Required Firestore index:
Collection group: staff
Field: firebaseUid
Order: Ascending
Scope: Collection group''';

const missingInvitationLookupIndexMessage =
    'Firebase setup required: invitation lookup index is missing or still building.';

const firestoreIndexSetupMessage =
    'Firebase setup required: Firestore index is missing or still building.';

const missingInvitationLookupIndexDeveloperDetails = '''
Required Firestore indexes:
Collection group: invitations
Fields:
- inviteCodeHash, normalizedEmail, status
- normalizedEmail, status
Scope: Collection group''';

bool isMissingStaffLookupIndexError(Object error) {
  if (error is! FirebaseException || error.code != 'failed-precondition') {
    return false;
  }
  final message = (error.message ?? error.toString()).toLowerCase();
  return message.contains('index') &&
      message.contains('staff') &&
      message.contains('firebaseuid') &&
      (message.contains('collection_group') ||
          message.contains('collection group'));
}

bool isMissingInvitationLookupIndexError(Object error) {
  if (error is! FirebaseException || error.code != 'failed-precondition') {
    return false;
  }
  final message = (error.message ?? error.toString()).toLowerCase();
  return message.contains('index') &&
      message.contains('invitations') &&
      (message.contains('normalizedemail') ||
          message.contains('invitecodehash')) &&
      (message.contains('collection_group') ||
          message.contains('collection group') ||
          message.contains('currently building'));
}

bool isFirestoreIndexSetupError(Object error) {
  if (isMissingStaffLookupIndexError(error) ||
      isMissingInvitationLookupIndexError(error)) {
    return true;
  }
  if (error is! FirebaseException || error.code != 'failed-precondition') {
    return false;
  }
  final message = (error.message ?? error.toString()).toLowerCase();
  return message.contains('index') &&
      (message.contains('currently building') ||
          message.contains('requires an index') ||
          message.contains('requires a collection_group') ||
          message.contains('console.firebase.google.com'));
}

void logMissingStaffLookupIndex(
  Object error, {
  StackTrace? stackTrace,
}) {
  developer.log(
    '$missingStaffLookupIndexMessage\n$missingStaffLookupIndexDeveloperDetails',
    name: 'construction_erp.firebase_setup',
    error: error,
    stackTrace: stackTrace,
    level: 1000,
  );
}

void logMissingInvitationLookupIndex(
  Object error, {
  StackTrace? stackTrace,
}) {
  developer.log(
    '$missingInvitationLookupIndexMessage\n'
    '$missingInvitationLookupIndexDeveloperDetails',
    name: 'construction_erp.firebase_setup',
    error: error,
    stackTrace: stackTrace,
    level: 1000,
  );
}

void logFirestoreIndexSetupError(
  Object error, {
  StackTrace? stackTrace,
}) {
  developer.log(
    firestoreIndexSetupMessage,
    name: 'construction_erp.firebase_setup',
    error: error,
    stackTrace: stackTrace,
    level: 1000,
  );
}
