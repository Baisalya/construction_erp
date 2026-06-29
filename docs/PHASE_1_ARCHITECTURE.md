# Phase 1 Architecture

## 1. Understood business flow

The ERP follows this construction-company flow:

1. Company applies for many tenders.
2. Each tender can be applied through a bidder profile / portal username.
3. Tender stores estimated value, quoted price, EMD, tender fee, document fee, processing cost, other application cost, status, and result.
4. Selected tender becomes a project.
5. Project stores agreement gross value, deductions, security deposit, retention, GST rate, advance, and agreement final value.
6. Actual work cost is tracked from Material, Labor, Machinery, Fuel, Repairs, and Other Expenses.
7. Billing, GST, received amount, pending receivable, payable, and profit/loss reports are generated from ledger records.

The local database is the source of truth. Firebase is not the business database.

## 2. Complete module list

- Auth / Company Setup
- Staff / Roles / Permissions
- Tender
- Project
- Work
- Material
- Fuel
- Labor
- Machinery
- Billing / Estimate / GST
- Other Expenses
- Reports
- Settings
- Sync / Conflict / Device Registry

## 3. Database schema plan

The Phase 1 SQLite schema is implemented in `lib/database/schema/app_schema_sql.dart`.

Rules used by the schema:

- Every business table has `id`, `company_id`, `created_at`, `updated_at`, `created_by_user_id`, `updated_by_user_id`, `is_deleted`, `sync_status`, and `version` unless the table is the root company table.
- Money columns use integer paise with `_paise` suffix.
- GST and percent values use basis points with `_basis_points` suffix.
- Decimal quantities use text columns with `_decimal` suffix to avoid binary floating point errors.
- Deletes are soft deletes through `is_deleted`.
- Sync state is stored with `sync_status`.
- The schema version is `1`.

Table groups:

### Company and staff

- `companies`
- `staff_users`
- `roles`
- `permissions`
- `project_staff_assignments`

### Tender

- `bidder_profiles`
- `tenders`
- `tender_expenses`
- `tender_documents`

### Project

- `projects`
- `project_agreement_deductions`
- `project_milestones`

### Work

- `work_days`

### Material

- `suppliers`
- `material_purchases`
- `material_purchase_items`
- `supplier_payments`

### Fuel

- `fuel_types`
- `fuel_entries`

### Labor

- `laborers`
- `labor_work_entries`
- `labor_payments`
- `labor_advances`

### Machinery

- `machines`
- `machine_usage_entries`
- `machine_rental_payments`
- `machine_repair_entries`

### Billing / GST

- `project_estimates`
- `project_estimate_items`
- `project_bills`
- `project_bill_receipts`
- `gst_entries`

### Other expenses

- `project_expenses`

### Sync

- `sync_queue`
- `sync_deltas_applied`
- `sync_conflicts`
- `device_registry`
- `staff_access_cache`

## 4. Sync / Firebase plan

Firebase collections planned from Phase 1:

```text
companies/{companyId}
companies/{companyId}/staff/{staffId}
companies/{companyId}/invitations/{inviteId}
companies/{companyId}/role_permissions/{roleId}
companies/{companyId}/sync_deltas/{deltaId}
companies/{companyId}/devices/{deviceId}
```

Firebase responsibilities:

- Firebase Auth: owner/staff login.
- Firestore: company metadata, staff profiles, role permissions, devices, sync deltas.
- Firebase Storage: optional attachments / document backup.

Local sync tables:

- `sync_queue`: every local insert/update/delete creates a pending delta.
- `sync_deltas_applied`: prevents duplicate remote delta application.
- `sync_conflicts`: stores version mismatch conflicts.
- `device_registry`: stores local and remote device identity.
- `staff_access_cache`: stores the latest permission snapshot locally.

Conflict design:

- Every synced record has `version`.
- If remote version conflicts with local changed version, do not overwrite.
- Create `sync_conflicts` record.
- Owner/admin will later choose local, remote, or manual merge.

## 5. Implementation phase plan

### Phase 1 — current ZIP

Architecture, database schema, repository/service boundaries, sync-ready tables, Firebase-ready gateway, responsive shell, dashboard, and empty module pages.

### Phase 4

Tender module with bidder profiles, tender expenses, documents, and tender-to-project conversion.

### Phase 4

Project module with agreement value calculator, deductions, milestones, and project dashboard.

### Phase 4

Work module: material, labor, machinery, fuel, repair, and payments.

### Phase 5

Billing, GST, estimate, profit/loss reports.

### Phase 6

Firebase Auth, company setup, staff management, roles, permissions.

### Phase 7

Sync delta upload/download between local DB and Firestore.

### Phase 8

Conflict handling, backup/restore, export PDF/Excel.

### Phase 9

Android and Windows UI polish, migration tests, full unit tests, release preparation.
