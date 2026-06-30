import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/sync_delta.dart';
import '../domain/sync_entity_registry.dart';
import '../domain/sync_models.dart';
import '../domain/sync_remote_data_source.dart';

class FirestoreSyncDeltaRemoteDataSource implements SyncDeltaRemoteDataSource {
  FirestoreSyncDeltaRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String companyId) =>
      _firestore
          .collection('companies')
          .doc(companyId)
          .collection('sync_deltas');

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
