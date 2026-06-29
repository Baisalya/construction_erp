# Phase 4 - Material, Labor, Machinery, Fuel, Repair

This phase adds work-cost business logic on top of Phase 3 without building Phase 5 billing/GST/profit-loss screens yet.

## Included

### Material

- Supplier creation.
- Material purchase creation.
- Multiple material item support in repository logic.
- Quantity × rate calculation using integer paise and decimal quantity strings.
- GST calculation using basis points.
- Paid/pending/payment status calculation.
- Supplier payment foundation.

### Labor

- Laborer master.
- Work entries for daywise, thika, hourly, piecework, and custom.
- Quantity × rate calculation without double.
- Paid/pending/payment status calculation.
- Labor payment foundation.
- Labor advance and balance calculation.

### Machinery

- Machine master for own/rental machines.
- Hourly/daily/weekly/monthly/fixed charge types.
- Machine usage calculation.
- Machine rental payment foundation.
- Machine repair entry with parts, labor, total, paid, and pending.

### Fuel

- Fuel types such as Diesel, Petrol, and Custom.
- Fuel entries with quantity, rate, total, paid, pending.
- Used-for links: machinery, labor, material transport, project general, other.
- Machine link required when used for machinery.

### Reports foundation

`ReportsRepository.loadProjectCostSummary()` now calculates:

```text
materialCost = sum(material_purchase_items.total_amount_paise)
laborCost = sum(labor_work_entries.total_amount_paise)
machineryCost = sum(machine_usage_entries.total_amount_paise)
fuelCost = sum(fuel_entries.total_amount_paise)
repairCost = sum(machine_repair_entries.total_cost_paise)
otherExpenseCost = sum(project_expenses.amount_paise)
```

## Not included yet

- Phase 5 Billing/GST/Estimate screens.
- Final profit/loss UI.
- Firebase live sync.
- Conflict resolution.
- Backup/export.
