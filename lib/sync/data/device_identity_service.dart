import 'dart:io' show Platform;

import 'package:uuid/uuid.dart';

import 'local_sync_queue_repository.dart';

class DeviceIdentityService {
  DeviceIdentityService(
      {required LocalSyncQueueRepository localQueue, Uuid? uuid})
      : _localQueue = localQueue,
        _uuid = uuid ?? const Uuid();
  final LocalSyncQueueRepository _localQueue;
  final Uuid _uuid;

  Future<String> ensureDevice(
      {required String companyId,
      required String firebaseUid,
      String? existingDeviceId}) async {
    final saved = await _localQueue.existingDeviceId(companyId, firebaseUid);
    final candidate = existingDeviceId == null ||
            existingDeviceId.isEmpty ||
            existingDeviceId.startsWith('local-')
        ? null
        : existingDeviceId;
    final deviceId = saved ?? candidate ?? _uuid.v4();
    final platform = Platform.operatingSystem;
    await _localQueue.upsertDevice(
        companyId: companyId,
        deviceId: deviceId,
        firebaseUid: firebaseUid,
        deviceName: '$platform device',
        platform: platform);
    return deviceId;
  }
}
