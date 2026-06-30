class SyncDelta {
  const SyncDelta({
    required this.deltaId,
    required this.companyId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payloadJson,
    this.baseVersion = 0,
    this.newVersion = 1,
    required this.createdAt,
    required this.createdByUserId,
    required this.deviceId,
    required this.schemaVersion,
    required this.status,
    this.errorMessage,
    this.projectId,
  });

  final String deltaId;
  final String companyId;
  final String entityType;
  final String entityId;
  final String operation;
  final String payloadJson;
  final int baseVersion;
  final int newVersion;
  final int createdAt;
  final String createdByUserId;
  final String deviceId;
  final int schemaVersion;
  final String status;
  final String? errorMessage;
  final String? projectId;

  SyncDelta copyWith({
    String? status,
    String? errorMessage,
    String? payloadJson,
    int? baseVersion,
    int? newVersion,
    String? projectId,
  }) {
    return SyncDelta(
      deltaId: deltaId,
      companyId: companyId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payloadJson: payloadJson ?? this.payloadJson,
      baseVersion: baseVersion ?? this.baseVersion,
      newVersion: newVersion ?? this.newVersion,
      createdAt: createdAt,
      createdByUserId: createdByUserId,
      deviceId: deviceId,
      schemaVersion: schemaVersion,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      projectId: projectId ?? this.projectId,
    );
  }

  Map<String, Object?> toLocalMap({String? localStatus}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'id': deltaId,
      'company_id': companyId,
      'created_at': createdAt,
      'updated_at': now,
      'created_by_user_id': createdByUserId,
      'updated_by_user_id': createdByUserId,
      'is_deleted': 0,
      'sync_status': localStatus ?? status,
      'version': newVersion,
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'payload_json': payloadJson,
      'base_version': baseVersion,
      'new_version': newVersion,
      'device_id': deviceId,
      'schema_version': schemaVersion,
      'status': localStatus ?? status,
      'error_message': errorMessage,
    };
  }

  Map<String, Object?> toFirestoreMap() => {
        'deltaId': deltaId,
        'companyId': companyId,
        'entityType': entityType,
        'entityId': entityId,
        'operation': operation,
        'payloadJson': payloadJson,
        'baseVersion': baseVersion,
        'newVersion': newVersion,
        'createdAt': createdAt,
        'createdByUserId': createdByUserId,
        'deviceId': deviceId,
        'schemaVersion': schemaVersion,
        'status': status,
        if (projectId != null) 'projectId': projectId,
      };

  factory SyncDelta.fromLocalMap(Map<String, Object?> map) => SyncDelta(
        deltaId: _s(map['id'] ?? map['delta_id'] ?? map['deltaId']),
        companyId: _s(map['company_id'] ?? map['companyId']),
        entityType: _s(map['entity_type'] ?? map['entityType']),
        entityId: _s(map['entity_id'] ?? map['entityId']),
        operation: _s(map['operation']),
        payloadJson: _s(map['payload_json'] ?? map['payloadJson']),
        baseVersion: _i(map['base_version'] ?? map['baseVersion']),
        newVersion: _i(map['new_version'] ?? map['newVersion']),
        createdAt: _i(map['created_at'] ?? map['createdAt']),
        createdByUserId:
            _s(map['created_by_user_id'] ?? map['createdByUserId']),
        deviceId: _s(map['device_id'] ?? map['deviceId']),
        schemaVersion: _i(map['schema_version'] ?? map['schemaVersion']),
        status: _s(map['status']),
        errorMessage:
            map['error_message'] == null ? null : _s(map['error_message']),
        projectId: map['project_id'] == null ? null : _s(map['project_id']),
      );

  factory SyncDelta.fromFirestoreMap(Map<String, Object?> map) => SyncDelta(
        deltaId: _s(map['deltaId'] ?? map['id']),
        companyId: _s(map['companyId'] ?? map['company_id']),
        entityType: _s(map['entityType'] ?? map['entity_type']),
        entityId: _s(map['entityId'] ?? map['entity_id']),
        operation: _s(map['operation']),
        payloadJson: _s(map['payloadJson'] ?? map['payload_json']),
        baseVersion: _i(map['baseVersion'] ?? map['base_version']),
        newVersion: _i(map['newVersion'] ?? map['new_version']),
        createdAt: _i(map['createdAt'] ?? map['created_at']),
        createdByUserId:
            _s(map['createdByUserId'] ?? map['created_by_user_id']),
        deviceId: _s(map['deviceId'] ?? map['device_id']),
        schemaVersion: _i(map['schemaVersion'] ?? map['schema_version']),
        status: _s(map['status']),
        errorMessage:
            map['errorMessage'] == null ? null : _s(map['errorMessage']),
        projectId: map['projectId'] == null ? null : _s(map['projectId']),
      );

  static int _i(Object? value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static String _s(Object? value) => value?.toString() ?? '';
}
