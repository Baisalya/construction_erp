import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:construction_erp/core/firebase/firebase_bootstrap.dart';
import 'package:construction_erp/core/firebase/firestore_setup_error.dart';
import 'package:construction_erp/features/auth/data/auth_providers.dart';
import 'package:construction_erp/features/auth/domain/app_user.dart';
import 'package:construction_erp/features/auth/domain/auth_repository_contract.dart';
import 'package:construction_erp/features/auth/presentation/auth_gate.dart';
import 'package:construction_erp/shared/presentation/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final missingIndex = FirebaseException(
    plugin: 'cloud_firestore',
    code: 'failed-precondition',
    message: 'The query requires a COLLECTION_GROUP_ASC index for collection '
        'staff and field firebaseUid.',
  );

  test('missing staff collection-group index gets a friendly setup message',
      () {
    expect(isMissingStaffLookupIndexError(missingIndex), isTrue);
    expect(friendlyErrorMessage(missingIndex), missingStaffLookupIndexMessage);
    expect(
      isMissingStaffLookupIndexError(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Missing permission.',
        ),
      ),
      isFalse,
    );
  });

  test('invitation index errors do not expose Firebase console links', () {
    final invitationIndex = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'failed-precondition',
      message: 'The query requires an index. That index is currently building '
          'and cannot be used yet. See its status here: '
          'https://console.firebase.google.com/v1/r/project/demo/firestore/indexes',
    );

    expect(isFirestoreIndexSetupError(invitationIndex), isTrue);
    expect(
      friendlyErrorMessage(invitationIndex),
      firestoreIndexSetupMessage,
    );
    expect(
      friendlyErrorMessage(invitationIndex),
      isNot(contains('console.firebase.google.com')),
    );
  });

  testWidgets('auth gateway does not show Access blocked for missing index',
      (tester) async {
    const user = AppUser(uid: 'uid-1', email: 'staff@example.com');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseBootstrapProvider.overrideWithValue(
            const FirebaseBootstrapResult.ready(),
          ),
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository(user)),
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          userCompanyMembershipsProvider.overrideWith(
            (ref, user) => Future.error(missingIndex),
          ),
        ],
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Firebase setup required'), findsOneWidget);
    expect(find.text(missingStaffLookupIndexMessage), findsOneWidget);
    expect(find.text('Access blocked'), findsNothing);
  });

  test('index file declares staff firebaseUid collection-group ascending', () {
    final document = jsonDecode(
      File('docs/firebase/firestore.indexes.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final overrides = document['fieldOverrides'] as List<dynamic>;
    final staff = overrides.cast<Map<String, dynamic>>().singleWhere(
          (entry) =>
              entry['collectionGroup'] == 'staff' &&
              entry['fieldPath'] == 'firebaseUid',
        );
    final indexes =
        (staff['indexes'] as List<dynamic>).cast<Map<String, dynamic>>();
    expect(
      indexes.any(
        (index) =>
            index['order'] == 'ASCENDING' &&
            index['queryScope'] == 'COLLECTION_GROUP',
      ),
      isTrue,
    );
  });
}

class _FakeAuthRepository implements AuthRepositoryContract {
  _FakeAuthRepository(this._user);

  AppUser? _user;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> authStateChanges() => Stream.value(_user);

  @override
  Future<void> signOut() async => _user = null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
