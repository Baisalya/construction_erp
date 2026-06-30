class SyncOperations {
  static const insert = 'insert';
  static const update = 'update';
  static const delete = 'delete';
}

class SyncStatuses {
  static const localOnly = 'localOnly';
  static const pendingUpload = 'pendingUpload';
  static const uploading = 'uploading';
  static const uploaded = 'uploaded';
  static const downloaded = 'downloaded';
  static const applied = 'applied';
  static const conflict = 'conflict';
  static const failed = 'failed';
}

class SyncContext {
  const SyncContext(
      {required this.companyId,
      required this.userId,
      required this.deviceId,
      this.staffId,
      this.schemaVersion = 3});
  final String companyId;
  final String userId;
  final String deviceId;
  final String? staffId;
  final int schemaVersion;
}

class SyncCounts {
  const SyncCounts(
      {this.pendingUploads = 0,
      this.uploaded = 0,
      this.downloaded = 0,
      this.applied = 0,
      this.failed = 0,
      this.conflicts = 0,
      this.lastSyncAt,
      this.errors = const []});
  final int pendingUploads;
  final int uploaded;
  final int downloaded;
  final int applied;
  final int failed;
  final int conflicts;
  final int? lastSyncAt;
  final List<String> errors;
  String? get lastError => errors.isEmpty ? null : errors.first;
}

enum SyncDirection { upload, download }

enum SyncApplyOutcome { applied, skipped, conflict, failed }

class SyncDownloadScope {
  const SyncDownloadScope({
    required this.allCompanyData,
    this.entityTypes = const {},
    this.projectIds = const {},
  });

  final bool allCompanyData;
  final Set<String> entityTypes;
  final Set<String> projectIds;
}

class SyncRunResult {
  const SyncRunResult(
      {required this.uploaded,
      required this.downloaded,
      required this.applied,
      required this.conflicts,
      required this.failed,
      this.message});
  final int uploaded;
  final int downloaded;
  final int applied;
  final int conflicts;
  final int failed;
  final String? message;
}

class SyncPermissionDecision {
  const SyncPermissionDecision.allow()
      : allowed = true,
        reason = null;
  const SyncPermissionDecision.deny(this.reason) : allowed = false;
  final bool allowed;
  final String? reason;
}
