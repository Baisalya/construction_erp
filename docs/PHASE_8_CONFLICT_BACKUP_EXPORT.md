# Phase 8: Conflict resolution, backup and export

Phase 8 keeps Drift/SQLite as the business source of truth.

## Conflict resolution

- Only an active owner or admin can review and resolve conflicts.
- **Keep local** creates a new outbound delta above the remote version.
- **Use remote** applies the downloaded snapshot and records it as applied.
- **Manual merge** accepts a JSON object while protecting record ID, company ID,
  audit ownership and version fields.
- Resolutions retain the conflict row with resolver, timestamp and decision.

## Local backup and restore

- Backups are company-scoped JSON files.
- Integer-paise values and audit/version fields are preserved.
- Authentication, staff access cache, device registry and sync history are
  excluded to prevent restoring stale credentials or revoked access.
- Restore validates format, schema version and company ownership.
- Restored business records create new local sync deltas.
- Backup files include document paths but not the external attachment file
  contents themselves.

## Report export

- Profit/loss summaries can be saved as PDF or XLSX.
- XLSX stores an integer-paise column and a formatted display column.
- Export requires `reports.export` at the service boundary.
- Backup and restore require `settings.manage` at the service boundary.

