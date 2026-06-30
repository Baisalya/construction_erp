import 'dart:convert';

class SyncConflict {
  const SyncConflict({
    required this.id,
    required this.companyId,
    required this.entityType,
    required this.entityId,
    required this.remoteDeltaId,
    required this.remoteOperation,
    required this.localPayloadJson,
    required this.remotePayloadJson,
    required this.localVersion,
    required this.remoteVersion,
    required this.createdAt,
    required this.status,
    this.reason,
  });

  final String id;
  final String companyId;
  final String entityType;
  final String entityId;
  final String remoteDeltaId;
  final String remoteOperation;
  final String localPayloadJson;
  final String remotePayloadJson;
  final int localVersion;
  final int remoteVersion;
  final int createdAt;
  final String status;
  final String? reason;

  Map<String, Object?> get localPayload => _decode(localPayloadJson);
  Map<String, Object?> get remotePayload => _decode(remotePayloadJson);

  static Map<String, Object?> _decode(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Conflict payload must be a JSON object.');
    }
    return Map<String, Object?>.from(value);
  }
}

enum ConflictResolutionChoice { local, remote, manual }
