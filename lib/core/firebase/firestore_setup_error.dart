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
