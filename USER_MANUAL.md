# Construction ERP User Manual

This manual is for the company owner, administrators, accountants, project managers, site supervisors, data-entry staff, and viewers. It uses the same simple names shown in the Android and Windows app.

## 1. Read this before using the app

Construction ERP saves work to the local Drift/SQLite database first. When the user is signed in and the internet is available, the app automatically shares allowed company changes with the other active devices.

Automatic updating now works:

- When the app starts.
- When the app returns from the background.
- Shortly after a user saves a record.
- When another allowed company device sends a change.
- Through an eight-second foreground queue check.
- Through automatic retry after a temporary internet or Firebase failure.

The **Sync status** page and **Sync now** button remain available as a backup.

> Important temporary payment rule: Until the Phase 11 financial ledger upgrade is installed, the owner must nominate one person/device to record supplier payments, labor payments, machinery payments, and client receipts. Other staff may enter approved site work and expenses, but two people must not record payments against the same bill or balance at the same time.

Create a backup every working day. Automatic sharing is not a replacement for backup.

## 2. Complete company work flow

| Step | Person normally responsible | What to do | Result |
|---|---|---|---|
| 1. Company setup | Owner | Create the company and check GST/contact details | Company workspace is ready |
| 2. Staff setup | Owner/Admin | Invite staff, select a role, and assign projects | Staff sees only allowed work |
| 3. Tender | Tender staff/Manager | Add bidder profile, tender, dates, value, and expenses | Tender cost and status are recorded |
| 4. Tender result | Owner/Manager | Mark an awarded tender as selected | Tender can become a project |
| 5. Create project | Owner/Manager | Convert selected tender or create a project manually | Project ledger is opened |
| 6. Agreement | Owner/Manager/Accountant | Enter gross value, recoverable and non-recoverable deductions | Final agreement value is calculated |
| 7. Daily work | Site Supervisor | Add site diary, work progress, and approved expenses | Daily project history is available |
| 8. Material | Store/Site/Accountant | Add purchase, item values, GST, and supplier details | Material cost and supplier pending are calculated |
| 9. Labor | Site Supervisor/Accountant | Add daywise, hourly, piece, or fixed work | Labor cost and pending are calculated |
| 10. Machinery | Site Supervisor/Manager | Add own/rental use, fuel, repair, and rental charges | Machinery cost enters the project ledger |
| 11. Billing | Accountant | Create estimate, running/final bill, deductions, and GST | Net receivable is calculated |
| 12. Payment/receipt | One nominated operator | Record supplier/labor payments and client receipts | Paid and pending values are updated |
| 13. Review | Owner/Accountant | Check Dashboard, GST, pending amounts, and profit/loss | Management sees the current position |
| 14. Share and protect | Automatic + Owner | Check update status and create a daily backup | Other devices update and recovery copy exists |

Simple flow:

`Tender → Selected → Project → Agreement → Daily Work/Costs → Bill → Receipt → GST → Profit/Loss → Backup`

## 3. Roles and responsibilities

| Role | Normal use | Should not normally do |
|---|---|---|
| Owner | Full company control, staff, projects, reports, conflicts, backup | Share password or invite code |
| Admin | Trusted daily administration and staff control | Give unnecessary access |
| Accountant | Purchases, payments, billing, GST, reports, exports | Change site work without confirmation |
| Project Manager | Assigned project planning, work, material, labor, machinery | Open unassigned projects |
| Site Supervisor | Daily work, approved site entries, measurements and notes | Record unapproved financial payments |
| Data Entry | Enter approved documents and records | Approve own work or manage staff |
| Viewer | Read allowed project information | Create, edit, delete, pay, or sync writes |

Permissions belong to the membership in the active company. A person can be Owner in one company and Staff in another company using the same login.

## 4. Android and Windows navigation

### Android

- Use the bottom navigation for Dashboard, Tenders, Projects, and Work.
- Tap **More** or the top-left menu to open Material, Labor, Machinery, Fuel, Billing, Reports, Staff, Settings, and Sync Status.
- Swipe or scroll forms before assuming a button is missing.
- Tap the cloud/update icon to open Sync Status.

### Windows

- Use the fixed sidebar on the left.
- Wider lists use table layouts.
- Use Tab and Shift+Tab to move through form fields.
- Use Enter or Space to activate the selected button.
- The sidebar update row shows whether company data is current, updating, offline, or needs attention.

If a menu is absent or locked, the active role does not have permission for it.

## 5. Login, company, and project selection

### Create the first owner account

1. Open the app and choose **Create account**.
2. Enter the owner name, normalized email, and a strong password.
3. Sign in with email/password or the connected Google account.
4. Create the company.
5. Enter company name and optional GST, PAN, address, phone, and email.
6. Check the company details before saving.

### Returning user

1. Sign in with the previously connected method.
2. If only one company is active, the app normally selects it.
3. If several companies are available, choose the correct company.
4. Use **Select project** to limit the current view to one allowed project when required.

### Switch company safely

1. Open **Switch company** from the sidebar/profile menu.
2. Read the role shown below each company name.
3. Tap **Switch** on the correct company.
4. Wait for the company update status.
5. Check the company/project name before entering data.

Data from the previous company stays on the device but must not appear in the new company view.

## 6. Staff invitation and access

### Invite staff

1. Open **Staff**.
2. Choose **Invite staff** or **Add staff**.
3. Enter the staff member's real name and email.
4. Select the correct role.
5. Choose all-project access only when genuinely needed.
6. Otherwise assign only the required projects.
7. Save/send the invitation.

### Join a company

1. Sign in using the invited email address.
2. Open **Join company**.
3. Select the pending invitation or enter the invite code.
4. Confirm the company name before accepting.

### Change or remove access

- **Change role** updates job permissions.
- **Assign projects** changes project visibility.
- **Suspend** temporarily blocks access.
- **Revoke** removes company access.
- **Activate** restores an allowed membership.

After changing permissions, the staff member should keep the app online and use **Refresh access** if the change is not yet visible.

## 7. Dashboard

The Dashboard is a summary. It is not a separate editable ledger.

It shows:

- Active and selected tenders.
- Running projects.
- Pending supplier, labor, and machinery amounts.
- Total agreement/project value.
- Total actual project expense.
- Profit or loss by agreement.
- GST input, GST output, and net GST.

If a total looks wrong, open the related Material, Labor, Machinery, Billing, or Project record and correct the source entry. Pull to refresh on Android when needed. Automatically received changes also refresh the active data providers.

## 8. Tender management

### Bidder profile

Create a separate bidder profile for each portal, company identity, joint venture, partner, or tender login.

1. Open **Tenders**.
2. Add a bidder profile.
3. Enter a clear profile and portal name.
4. Add available username/contact information.
5. Save.

### Add a tender

1. Select the bidder profile.
2. Enter tender title; this is required.
3. Enter tender number, department/client, location, and important dates.
4. Enter estimated value and quoted value.
5. Enter EMD, tender fee, document fee, processing cost, and other costs.
6. Select the correct status.
7. Save the tender.

### Tender expense and documents

- Use **Add expense** for travel, document preparation, portal fees, consultancy, and submission costs.
- Use **Add document** with names such as `EMD Receipt`, `Technical Bid`, or `Final BOQ`.

### Convert to project

1. Confirm that the tender was genuinely awarded.
2. Choose **Mark selected**.
3. Check quoted value and tender information.
4. Choose **Convert to project**.
5. Enter the requested project code/name details.
6. Save once. Do not create a second manual project for the same awarded tender.

## 9. Project and agreement

### Create a manual project

Use this only when the job did not come from a tender.

1. Open **Projects** and choose **Create project**.
2. Enter project name; this is required.
3. Add code, client, location, and dates.
4. Enter gross agreement value.
5. Add available security deposit, retention, GST, guarantee, advance, and notes.
6. Save.

### Agreement terms

| Term | Meaning |
|---|---|
| Gross agreement value | Starting contract value |
| Recoverable deduction | Temporarily held and expected back |
| Non-recoverable deduction | Permanently reduces final value |
| Security/retention | Amount held under the agreement |
| Final agreement value | Gross value after applicable permanent deductions |

### Deductions and milestones

1. Select the project.
2. Add the deduction title/type and amount/rate.
3. Mark recoverable correctly.
4. Save and verify the final agreement value.
5. Add milestones for handover, foundation, slab, bill submission, testing, completion, or other important stages.

## 10. Work page and other expenses

### Daily site diary

1. Select the correct project.
2. Enter date/site, weather, and work notes.
3. Record completed work, delays, manpower issues, inspections, shortages, and instructions.
4. Save.

Write notes that another manager can understand later. Delete only a genuine duplicate or wrong entry.

### Other project expense

Use this only when the cost does not belong to Material, Labor, Machinery, Fuel, Repair, or Billing.

1. Select category.
2. Enter a useful description.
3. Enter Total and Paid amounts.
4. Select payment mode.
5. Add reference and notes.
6. Save and check Pending and Status.

Examples: site rent, electricity, water, permits, testing, safety, transport, or office expense.

## 11. Material purchases and supplier payments

### Record a purchase

1. Open **Material** and select the project.
2. Select/add supplier.
3. Enter invoice number/date.
4. Add material name, unit, quantity, and rate.
5. Enter taxable value and GST details if applicable.
6. Check item total and invoice total.
7. Save.

### Record supplier payment

Only the nominated payment operator should do this until Phase 11.

1. Open the correct purchase/supplier.
2. Read Total, Paid, and Pending.
3. Choose **Record payment**.
4. Enter amount, date, payment mode, and bank/UPI/cheque reference.
5. Confirm the amount does not exceed Pending.
6. Save once and wait for the update status.
7. Reopen the purchase and verify Paid, Pending, and Paid/Partial/Pending status.

Never press Save repeatedly because the screen appears slow. First check the record and Sync Status.

## 12. Labor work, payment, and advance

### Add labor work

1. Select project and laborer/group.
2. Select Daywise, Hourly, Thika/Fixed, or Piece work.
3. Enter days/hours/quantity and rate.
4. Enter description and date.
5. Check calculated total.
6. Save.

### Labor payment

1. Confirm the laborer and project.
2. Read the outstanding amount.
3. Enter approved payment, date, mode, and reference.
4. Save once.
5. Check remaining pending amount.

### Labor advance

Enter advance amount and recovered amount carefully. The remaining advance balance must agree with the worker's signed/approved record.

## 13. Machinery, fuel, rental, and repair

### Add machinery

1. Select project and machine.
2. Mark Own or Rental correctly.
3. Select Hourly, Daily, or Weekly charge type.
4. Enter usage and rate.
5. Add operator/notes where useful.
6. Check total and save.

### Fuel

1. Add/select fuel type.
2. Select machine and project.
3. Enter quantity, unit rate, date, and supplier/reference.
4. Check total and save.

### Repair

1. Select machine and project.
2. Describe the fault and repair.
3. Enter parts, labor, and total repair cost as requested.
4. Add workshop/vendor and reference.
5. Save.

### Rental payment

Only the nominated payment operator records the payment. Confirm the machine, vendor, project, and pending rental before saving.

## 14. Estimate, billing, receipts, and GST

### Estimate

1. Select project.
2. Add estimate title/date.
3. Add items with quantity and rate.
4. Verify estimated total and expected profit.
5. Save.

### Running or final bill

1. Select project and bill type.
2. Enter bill number/date and gross work value.
3. Enter GST, TDS, retention, and other applicable deductions.
4. Check Net Receivable.
5. Save.

| Value | Meaning |
|---|---|
| Gross bill | Work value before taxes/deductions |
| GST output | GST charged to the client |
| TDS/retention | Amount deducted or held |
| Net receivable | Amount due after calculation |
| Received | Money recorded as received |
| Pending | Net receivable minus received |

### Record client receipt

Only the nominated payment operator should record receipts until Phase 11.

1. Open the correct bill.
2. Read Net Receivable, Received, and Pending.
3. Choose **Add receipt**.
4. Enter amount, date, mode, and reference.
5. Confirm the amount is not greater than Pending.
6. Save once and check the update status.

### GST

- GST input normally comes from eligible purchases/expenses.
- GST output normally comes from client bills.
- Enter manual GST only when an authorized accountant has supporting documents.
- Never enter the same GST twice through both an automatic bill/purchase and a manual entry.

## 15. Reports and profit/loss

Reports may include:

- Agreement value.
- Material, labor, machinery, fuel, repair, and other expense.
- GST input/output.
- Total billed, received, and pending.
- Estimated profit/loss.
- Actual profit/loss by agreement.
- Actual profit/loss by receipts.

| Figure | Meaning |
|---|---|
| Estimated profit/loss | Agreement value minus estimated cost |
| Actual by agreement | Agreement value minus actual recorded cost |
| Actual by receipts | Money received minus actual recorded cost |

Choose the correct company and project filter before reading or exporting a report. Export PDF for sharing/printing and Excel for detailed checking.

## 16. Automatic company updates

### What happens automatically

| Event | App action |
|---|---|
| App starts | Checks access, sends waiting work, and receives allowed changes |
| User saves data | Durable local queue is created, then foreground sync starts shortly afterward |
| Another device changes data | Firestore change signal starts the validated download/apply process |
| Every eight seconds | App checks whether local work is waiting |
| App returns to foreground | Listener and sync restart |
| Internet fails | Local work remains saved and retry uses backoff |
| Company changes | Old listener stops and new company scope starts |
| App is closed | Foreground automatic update stops; it catches up next time the app opens |

### Status meanings

| Status shown | Meaning | User action |
|---|---|---|
| Updating company data | Sending/receiving now | Wait; do not repeatedly save |
| Company data up to date | Last update completed | Continue work |
| Offline — retrying | Internet/Firebase unavailable | Continue local work; restore internet |
| Update needs attention | Failure or conflict needs review | Open Sync Status |
| Automatic update paused | App is hidden/offline mode/not signed in | Resume/open the app |

### Manual Sync now

Use **Sync now** when:

- The owner wants an immediate confirmation.
- Internet has just returned.
- A staff permission was changed.
- The status says attention.
- Before closing the nominated payment device at day end.

The controller allows only one sync job at a time. Automatic and manual requests are safely combined instead of running over each other.

### Items needing review

Open **Review items needing attention** when two devices changed the same editable record version. Owner/Admin should compare both descriptions and choose the correct business value. Do not guess when the item affects money.

## 17. Current financial safety procedure

Automatic updating improves speed but does not yet provide the Phase 11 server-validated immutable financial ledger.

Until Phase 11:

1. Nominate one payment operator/device.
2. Other users send payment information to that operator.
3. Operator opens the latest bill/purchase and reads Pending.
4. Operator records the payment once.
5. Wait for **Company data up to date**.
6. Verify Paid and Pending.
7. Other devices may then review the result.
8. Create the daily backup.

Do not allow two admins to record payments against the same pending balance simultaneously.

## 18. Backup, restore, and export

### Daily backup

1. Wait for automatic update or tap **Sync now**.
2. Open **Settings → Backup and Restore**.
3. Choose **Create backup**.
4. Select a safe company-controlled folder.
5. Use a name containing company and date.
6. Keep at least one separate copy.

### Restore

1. Create a backup of the current device first.
2. Confirm the restore file belongs to the correct company/date.
3. Close other active company devices where practical.
4. Choose **Restore backup**.
5. Read the confirmation carefully.
6. Reopen the app and verify company, projects, totals, and Sync Status.

Do not restore an old backup merely to correct one wrong entry. Correct the entry in the proper module where possible.

## 19. Daily role checklists

### Site Supervisor

- Confirm company and project.
- Enter daily diary.
- Enter approved material/labor/machinery/fuel usage.
- Attach or reference supporting documents.
- Check the cloud/update status before leaving.

### Accountant/payment operator

- Confirm automatic update is current before payments.
- Check invoice/bill and pending amount.
- Record each approved payment once.
- Check payment reference and status.
- Review GST and pending balances.
- Run **Sync now** at day end.

### Project Manager

- Review progress and delays.
- Check project costs and pending amounts.
- Review milestones and billing readiness.
- Resolve non-financial duplicate/conflicting records with evidence.

### Owner/Admin

- Review Dashboard and unusual amounts.
- Review staff/project assignments.
- Check Sync Status and conflicts.
- Ensure only the nominated operator records payments.
- Create/verify the daily backup.

## 20. Month-end procedure

1. Confirm all approved work entries are entered.
2. Confirm invoices, labor sheets, fuel slips, repairs, and expenses.
3. Check supplier/labor/machinery pending totals.
4. Match client receipts with bank/cash records.
5. Review GST input/output with the accountant.
6. Review estimated and actual profit/loss.
7. Resolve attention items.
8. Export PDF and Excel reports.
9. Create a month-end backup and store it separately.

## 21. Common problems

| Problem | Check first | Safe action |
|---|---|---|
| Save button disabled | Required field, negative/invalid value | Correct highlighted fields |
| Project missing | Active company, project filter, assignment | Switch/filter correctly or ask Owner |
| Updating for a long time | Internet and Firebase availability | Keep app open; open Sync Status |
| Offline — retrying | Network connection | Work locally; reconnect and wait |
| Needs attention | Failed item or version conflict | Review Sync Status with Owner/Admin |
| Pending looks wrong | Duplicate/missing payment or wrong parent | Check payment list; do not add balancing fake entry |
| Profit too high | Missing costs or wrong agreement | Check all expense modules |
| Profit too low | Duplicate expense or wrong amount | Check entries and supporting documents |
| Staff cannot see project | Assignment or permission | Owner/Admin updates access |
| Profile image error | Empty/invalid photo URL | Leave blank or use a valid HTTP/HTTPS URL |
| App was closed during update | Local queue remains saved | Reopen; automatic catch-up starts |

## 22. Non-negotiable data safety rules

- Never share login passwords.
- Never give Owner/Admin access casually.
- Never reuse public/shared invite codes.
- Never edit the local SQLite file manually.
- Never remove Firebase configuration or rules from a release build.
- Never record the same payment twice to make a screen “catch up.”
- Never use automatic sharing as the only backup.
- Keep one nominated payment operator until Phase 11.
- Keep daily and month-end backups.
- Check company, project, Total, Paid, Pending, and Status before confirming money-related work.

