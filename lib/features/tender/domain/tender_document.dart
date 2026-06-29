import 'package:flutter/foundation.dart';

@immutable
class TenderDocumentDraft {
  const TenderDocumentDraft({
    required this.tenderId,
    required this.fileName,
    this.documentType,
    this.localPath,
    this.firebaseStoragePath,
    this.contentHash,
    this.uploadedAt,
  });

  final String tenderId;
  final String fileName;
  final String? documentType;
  final String? localPath;
  final String? firebaseStoragePath;
  final String? contentHash;
  final int? uploadedAt;

  Map<String, Object?> toPayload() {
    return {
      'tenderId': tenderId,
      'documentType': documentType,
      'fileName': fileName,
      'localPath': localPath,
      'firebaseStoragePath': firebaseStoragePath,
      'contentHash': contentHash,
      'uploadedAt': uploadedAt,
    };
  }
}

@immutable
class TenderDocument {
  const TenderDocument({
    required this.id,
    required this.companyId,
    required this.tenderId,
    required this.fileName,
    this.documentType,
    this.localPath,
    this.firebaseStoragePath,
    this.contentHash,
    this.uploadedAt,
  });

  final String id;
  final String companyId;
  final String tenderId;
  final String fileName;
  final String? documentType;
  final String? localPath;
  final String? firebaseStoragePath;
  final String? contentHash;
  final int? uploadedAt;
}
