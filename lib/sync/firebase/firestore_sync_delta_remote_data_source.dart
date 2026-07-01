import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/sync_delta.dart';
import '../domain/sync_entity_registry.dart';
import '../domain/sync_models.dart';
import '../domain/sync_remote_data_source.dart';

class FirestoreSyncDeltaRemoteDataSource implements SyncDeltaRemoteDataSource {
  FirestoreSyncDeltaRemoteDataSource({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;
  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String companyId) =>
      _firestore
          .collection('companies')
          .doc(companyId)
          .collection('sync_deltas');

  /// Emits a lightweight signal when an allowed remote query changes.
  ///
  /// The existing download/apply pipeline remains responsible for validation,
  /// deduplication, conflict detection and local Drift transactions. Keeping
  /// those responsibilities in one place avoids a second sync code path.
  Stream<void> watchChangeSignals(
    String companyId, {
    required SyncDownloadScope scope,
  }) {
    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    late final StreamController<void> controller;

    Future<void> listen() async {
      for (final query in _queriesForScope(companyId, scope)) {
        final subscription = query.snapshots().listen(
          (snapshot) {
            if (snapshot.docChanges.isNotEmpty && !controller.isClosed) {
              controller.add(null);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!controller.isClosed) {
              controller.addError(error, stackTrace);
            }
          },
        );
        subscriptions.add(subscription);
      }
    }

    controller = StreamController<void>(
      onListen: () => unawaited(listen()),
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  List<Query<Map<String, dynamic>>> _queriesForScope(
    String companyId,
    SyncDownloadScope scope,
  ) {
    if (scope.allCompanyData) {
      return <Query<Map<String, dynamic>>>[_collection(companyId)];
    }

    final queries = <Query<Map<String, dynamic>>>[];
    final projectIds = scope.projectIds.toList(growable: false);
    for (final entityType in scope.entityTypes) {
      final base = _collection(companyId).where(
        'entityType',
        isEqualTo: entityType,
      );
      if (!SyncEntityRegistry.projectScopedEntityTypes.contains(entityType)) {
        queries.add(base);
        continue;
      }
      for (var offset = 0; offset < projectIds.length; offset += 30) {
        final end = (offset + 30).clamp(0, projectIds.length);
        queries.add(base.where(
          'projectId',
          whereIn: projectIds.sublist(offset, end),
        ));
      }
    }
    return queries;
  }

  @override
  Future<void> uploadDelta(SyncDelta delta) async {
    await _collection(delta.companyId)
        .doc(delta.deltaId)
        .set(delta.toFirestoreMap(), SetOptions(merge: true));
  }

  @override
  Future<List<SyncDelta>> downloadDeltas(
    String companyId, {
    int? afterCreatedAt,
    SyncDownloadScope? scope,
  }) async {
    final byId = <String, SyncDelta>{};
    if (scope == null || scope.allCompanyData) {
      Query<Map<String, dynamic>> query =
          _collection(companyId).orderBy('createdAt');
      if (afterCreatedAt != null && afterCreatedAt > 0) {
        query = query.where('createdAt', isGreaterThan: afterCreatedAt);
      }
      for (final delta in await _downloadQuery(companyId, query)) {
        byId[delta.deltaId] = delta;
      }
      return byId.values.toList(growable: false);
    }

    for (final entityType in scope.entityTypes) {
      final base = _collection(companyId).where(
        'entityType',
        isEqualTo: entityType,
      );
      if (!SyncEntityRegistry.projectScopedEntityTypes.contains(entityType)) {
        for (final delta in await _downloadQuery(companyId, base)) {
          byId[delta.deltaId] = delta;
        }
        continue;
      }
      final projectIds = scope.projectIds.toList(growable: false);
      for (var offset = 0; offset < projectIds.length; offset += 30) {
        final end = (offset + 30).clamp(0, projectIds.length);
        final chunk = projectIds.sublist(offset, end);
        final query = base.where('projectId', whereIn: chunk);
        for (final delta in await _downloadQuery(companyId, query)) {
          byId[delta.deltaId] = delta;
        }
      }
    }
    return byId.values
        .where((delta) =>
            afterCreatedAt == null || delta.createdAt > afterCreatedAt)
        .toList(growable: false);
  }

  Future<List<SyncDelta>> _downloadQuery(
    String companyId,
    Query<Map<String, dynamic>> initialQuery,
  ) async {
    var query = initialQuery.orderBy(FieldPath.documentId);
    final deltas = <SyncDelta>[];
    while (true) {
      final snapshot = await query.limit(500).get();
      deltas.addAll(snapshot.docs
          .map((doc) => SyncDelta.fromFirestoreMap(
                Map<String, Object?>.from(doc.data()),
              ))
          .where((delta) => delta.companyId == companyId));
      if (snapshot.docs.length < 500) break;
      query = query.startAfterDocument(snapshot.docs.last);
    }
    return deltas;
  }

  @override
  Future<void> updateDeviceLastSync({
    required String companyId,
    required String deviceId,
    required String userId,
    required int lastSyncAt,
  }) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('devices')
        .doc(deviceId)
        .set({
      'deviceId': deviceId,
      'companyId': companyId,
      'firebaseUid': userId,
      'lastSyncAt': lastSyncAt,
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
