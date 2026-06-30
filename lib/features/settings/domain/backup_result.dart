class BackupRestoreResult {
  const BackupRestoreResult({
    required this.inserted,
    required this.updated,
    required this.skipped,
  });

  final int inserted;
  final int updated;
  final int skipped;
}
