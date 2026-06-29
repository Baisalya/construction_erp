# Phase 5 — Billing, GST, Estimate and Profit/Loss

Phase 5 activates the Billing and Reports modules on top of the Phase 4 work-cost ledger.

## Scope completed

- Project estimates with estimate items.
- Running/final/advance bill records.
- GST amount calculation from basis points.
- Automatic output GST entry when a bill has GST.
- Manual input/output GST adjustment entries.
- Bill receipts and pending receivable updates.
- Billing dashboard summary.
- Reports page for revenue, actual cost, GST and profit/loss.
- Local-first repository methods with sync queue delta creation for user writes.
- Unit tests for estimate, GST, net receivable, receipt and profit/loss calculations.

## Financial safety

- Money is stored and calculated as integer paise.
- Percent values such as GST are stored as basis points.
- Decimal quantities are stored as text and multiplied through the DecimalQuantity value object.
- No billing or profit/loss calculation uses `double`.

## Calculation rules

```text
GST amount = gross bill amount × gstRateBasisPoints / 10000

totalBillAmount = grossBillAmount + gstAmount

netReceivable = totalBillAmount - TDS - retention - other deductions

pendingReceivable = netReceivable - receivedAmount

totalActualCost = material + labor + machinery + fuel + repair + other expenses

actualProfitByAgreement = agreementFinalValue - totalActualCost
actualProfitByReceived = totalReceivedAmount - totalActualCost
```

## Not included yet

- Firebase Auth/company setup implementation.
- Staff invitation UI.
- Firestore sync upload/download worker.
- Conflict resolution UI.
- PDF/Excel export.
- Backup/restore.

Those remain for later phases.
