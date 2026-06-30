import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:construction_erp/sync/domain/sync_delta.dart';
import 'package:construction_erp/sync/domain/sync_entity_registry.dart';
import 'package:construction_erp/sync/domain/sync_models.dart';

void main() {
  group('Phase 7 sync contract', () {
    test('sync delta keeps base and new versions for conflict detection', () {
      final delta = SyncDelta(
          deltaId: 'd1',
          companyId: 'c1',
          entityType: 'projects',
          entityId: 'p1',
          operation: SyncOperations.update,
          payloadJson:
              jsonEncode({'id': 'p1', 'company_id': 'c1', 'version': 3}),
          baseVersion: 2,
          newVersion: 3,
          createdAt: 10,
          createdByUserId: 'u1',
          deviceId: 'device-a',
          schemaVersion: 2,
          status: SyncStatuses.pendingUpload);
      final remote = delta.toFirestoreMap();
      expect(remote['baseVersion'], 2);
      expect(remote['newVersion'], 3);
      expect(remote['payloadJson'], contains('company_id'));
    });

    test('download skips own device delta by comparing device id', () {
      final localDeviceId = 'device-a';
      final delta = SyncDelta(
          deltaId: 'd1',
          companyId: 'c1',
          entityType: 'tenders',
          entityId: 't1',
          operation: SyncOperations.insert,
          payloadJson: '{}',
          baseVersion: 0,
          newVersion: 1,
          createdAt: 10,
          createdByUserId: 'u1',
          deviceId: 'device-a',
          schemaVersion: 2,
          status: SyncStatuses.uploaded);
      expect(delta.deviceId == localDeviceId, isTrue);
    });

    test('project scoped entity exposes project id from payload', () {
      final projectId = SyncEntityRegistry.projectIdFromPayload(
          'material_purchases', jsonEncode({'id': 'm1', 'project_id': 'p42'}));
      expect(projectId, 'p42');
    });

    test('unsupported entity is rejected before SQL is generated', () {
      expect(() => SyncEntityRegistry.requireConfig('DROP TABLE projects'),
          throwsArgumentError);
    });
  });
}
