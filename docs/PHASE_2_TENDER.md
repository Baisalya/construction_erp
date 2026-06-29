# Phase 2 Tender Module

## Business flow covered

Tender Applied → Tender Selected → Project Created

Phase 2 adds the first real business module while keeping the app local-first.

## Included

1. Bidder profiles
   - Company can store multiple tender portal usernames/accounts.
   - Each tender can link to one bidder profile.

2. Tenders
   - Tender title, number, client, department, location.
   - Estimated tender value and quoted price stored in integer paise.
   - EMD, tender fee, document fee, processing cost, and other application cost.
   - Status: draft, applied, submitted, selected, rejected, cancelled.

3. Tender expenses
   - Additional tender application expenses like travel, staff, document, EMD, misc.
   - Amount stored in integer paise.

4. Tender documents
   - Local path and optional future Firebase Storage path metadata.
   - Content hash field prepared for future backup/sync verification.

5. Tender to project conversion
   - Only selected tenders can be converted.
   - Conversion creates a local project record.
   - Initial agreement values are copied from quoted tender price.
   - Phase 3 will add final agreement deduction calculation.

6. Sync deltas
   - Every bidder/tender/expense/document/project insert creates a row in `sync_queue`.
   - Firestore upload is intentionally not enabled yet.

## Architecture rule

The UI calls Riverpod providers and repositories. It does not directly access SQLite or Firebase.

## Tests added

- Bidder profile + tender + expense + document creation.
- Tender application cost calculation.
- Sync queue creation for local writes.
- Selected tender conversion to project.
- Non-selected tender conversion blocked.
- Tender dashboard stats.
