class SyncDelta {
  const SyncDelta({
    required this.deltaId,
    required this.companyId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payloadJson,
    required this.createdAt,
    required this.createdByUserId,
    required this.deviceId,
    required this.schemaVersion,
    required this.status,
  });

  final String deltaId;
  final String companyId;
  final String entityType;
  final String entityId;
  final String operation;
  final String payloadJson;
  final int createdAt;
  final String createdByUserId;
  final String deviceId;
  final int schemaVersion;
  final String status;
}
