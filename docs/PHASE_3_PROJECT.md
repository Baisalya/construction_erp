# Phase 3 - Project Agreement Calculator

This phase adds only the Project module foundation on top of Phase 2.

## Completed in Phase 3

- Project repository/service architecture.
- Project domain models and enums.
- Manual project creation foundation.
- Agreement value calculator.
- Agreement gross value, security deposit, deductions, advance received.
- Recoverable vs non-recoverable deduction handling.
- Project milestone foundation.
- Project dashboard stats.
- Responsive Project UI page.
- Windows table layout and Android card/form layout.
- Sync delta rows for project inserts, agreement updates, deductions, and milestones.
- Unit tests for project agreement calculations and project stats.

## Agreement calculation rule

Current Phase 3 default:

```text
agreementFinalValue = agreementGrossValue - nonRecoverableDeductions - securityDepositAmount
```

Recoverable deductions are shown in the summary but do not reduce agreement final value.

A later Settings phase can add a company-level switch for whether security deposit should be deducted or only tracked.

## Not included yet

- Phase 4 material/labor/machinery/fuel/repair logic is now added in `docs/PHASE_4_WORK.md`.
- Phase 5 billing, GST and final profit/loss reports.
- Live Firebase authentication or Firestore sync.
- Conflict resolution UI.
- PDF/Excel export.
