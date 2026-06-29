import 'package:flutter/foundation.dart';

@immutable
class WriteContext {
  const WriteContext({
    required this.companyId,
    required this.userId,
    required this.deviceId,
    this.nowMillis,
  });

  final String companyId;
  final String userId;
  final String deviceId;
  final int? nowMillis;

  int get timestamp => nowMillis ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, Object?> toAuditJson() {
    return {
      'companyId': companyId,
      'userId': userId,
      'deviceId': deviceId,
      'timestamp': timestamp,
    };
  }
}
