import 'package:flutter/foundation.dart';

@immutable
class AuditFields {
  const AuditFields({
    required this.id,
    required this.companyId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.createdByUserId,
    this.updatedByUserId,
    this.isDeleted = false,
    this.syncStatus = 'localOnly',
  });

  final String id;
  final String companyId;
  final int createdAt;
  final int updatedAt;
  final String? createdByUserId;
  final String? updatedByUserId;
  final bool isDeleted;
  final String syncStatus;
  final int version;
}
