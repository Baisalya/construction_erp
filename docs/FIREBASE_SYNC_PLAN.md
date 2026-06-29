# Firebase and Sync Plan

Phase 1 does not enable live Firebase sync. It prepares boundaries so Firebase can be added without rewriting local-first business logic.

## Firestore paths

```text
companies/{companyId}
companies/{companyId}/staff/{staffId}
companies/{companyId}/invitations/{inviteId}
companies/{companyId}/role_permissions/{roleId}
companies/{companyId}/sync_deltas/{deltaId}
companies/{companyId}/devices/{deviceId}
```

## Delta shape

```json
{
  "deltaId": "uuid",
  "companyId": "company-id",
  "entityType": "tenders",
  "entityId": "record-id",
  "operation": "insert|update|delete",
  "payloadJson": "{...}",
  "createdAt": 1710000000000,
  "createdByUserId": "staff-id",
  "deviceId": "device-id",
  "schemaVersion": 1,
  "status": "pendingUpload|uploaded|applied|conflict|failed"
}
```

## Security rule intent

- A user reads company data only if present in `companies/{companyId}/staff`.
- Revoked staff cannot read or write.
- Staff delta write permission depends on role permissions.
- Project-scoped staff can sync only assigned project data.
- Owner/admin can manage staff, roles, and conflicts.

## Local-first rule

Every business write must be local first. Firebase stores sync metadata and deltas only after local write succeeds.
