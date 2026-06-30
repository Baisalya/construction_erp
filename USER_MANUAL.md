# Construction ERP User Manual

This manual is for company owners, administrators, accountants, project managers, site supervisors, data-entry staff, and viewers. It explains the app in simple language and follows the same names shown on Android and Windows.

## 1. What this app does

Construction ERP keeps the complete work cycle in one place:

1. Add a tender.
2. Mark the tender selected.
3. Convert it into a project.
4. Enter the agreement value and deductions.
5. Record daily work and every project expense.
6. Create estimates and bills.
7. Record receipts and GST.
8. Check pending payments and profit or loss.
9. Sync approved company changes between signed-in devices.
10. Create backups and export reports.

The local database on the device is the main business record. Work is saved locally first. Internet is mainly required for sign-in, staff access updates, and syncing between devices.

## 2. Important rules for every user

- Select the correct project before entering any expense.
- Enter money in rupees, for example `12500` or `12500.50`.
- Do not type commas or the rupee symbol in input boxes.
- Quantity, rate, paid amount, GST, fuel, and repair amounts cannot be negative.
- Check Total, Paid, Pending, and Status after saving.
- `Paid` means nothing is pending.
- `Partial` means part of the amount is paid.
- `Pending` means no payment is recorded yet.
- Never share passwords, backup files, or company access codes with unauthorized people.
- Sync before starting work on a second device and sync again after finishing.
- Create a backup before restoring data or making large corrections.

## 3. Android and Windows navigation

### Android

The bottom menu provides quick access to Dashboard, Tenders, Projects, and Work. Tap **More** or the top-left menu button to open Material, Labor, Machinery, Fuel, Billing, Reports, Staff, Settings, and Sync Status.

### Windows

Use the fixed sidebar on the left. Lists appear as tables on wider screens. Use the mouse, Tab key, Shift+Tab, arrow keys, Enter, and Space to move through fields and buttons.

If a menu is missing, your staff role does not have permission for that area.

## 4. First-time setup

### Owner registration

1. Open the app.
2. Tap **Create account**.
3. Enter the owner's name, email, and a secure password.
4. Complete email/password or Google sign-in.
5. Create the company profile.
6. Enter the company name and available registration, GST, PAN, address, phone, and financial-year details.
7. Review the information before saving.

The first company user becomes the Owner and receives full access.

### Returning user login

1. Enter the registered email and password, or use the linked Google account.
2. If the device is offline, previously saved access may be used only when the user was already active on that device.
3. Revoked or inactive staff cannot bypass access by going offline.

## 5. Roles and staff access

### Owner

Has complete access to company data, projects, staff, reports, sync conflicts, backup, restore, and settings.

### Admin

Has full operational access and can manage staff. Give this role only to a trusted senior employee.

### Accountant

Normally handles material costs, billing, GST, reports, and exports.

### Project Manager

Normally manages assigned projects, tender updates, work entries, material, labor, machinery, and billing.

### Site Supervisor

Normally enters material, labor, machinery, fuel, and site information for assigned projects.

### Data Entry Staff

Can enter approved operational information but should not receive staff, settings, delete, or export authority unless the owner explicitly permits it.

### Viewer

Read-only access to assigned projects.

### Add a staff member

1. Open **Staff**.
2. Tap **Add staff**.
3. Enter the staff name, valid email, optional phone, and role.
4. Save or send the invitation.
5. Open the staff action menu.
6. Choose **Assign projects**.
7. Tick only the projects that person should see.
8. Save assignments.

### Change staff access

- **Edit details** changes name, email, or phone.
- **Change role** changes the permission group.
- **Assign projects** controls project visibility.
- **Activate** restores access.
- **Set inactive** temporarily blocks company access.
- **Revoke access** permanently blocks access until an authorized person changes it again.

The app asks for confirmation before making staff inactive or revoked. After changing access, ask the staff member to use **Refresh access**.

## 6. Dashboard

The Dashboard is the owner's quick company summary. It shows:

- Active and selected tenders
- Running projects
- Pending supplier, labor, and machinery amounts
- Total project value
- Total actual expense
- Profit or loss by agreement
- GST input, GST output, and net GST

Pull down on Android or refresh the page to load recent local records.

Use the Dashboard to notice unusual pending amounts, falling profit, or missing entries. Open the related module to correct the source record; do not try to edit Dashboard totals directly.

## 7. Tender management

### Create a bidder profile

A bidder profile represents a tender portal/company login used for applications.

1. Open **Tenders**.
2. Find the bidder profile section.
3. Enter a clear profile name, portal name, username, and other available details.
4. Tap **Save bidder profile**.

Use separate profiles when the company applies through different portals, joint ventures, partners, or usernames.

### Add a tender

1. Select the bidder profile.
2. Enter the tender title. This is required.
3. Enter tender number, client/department, location, important dates, and notes where available.
4. Enter estimated value and quoted price.
5. Enter EMD, tender fee, document fee, processing cost, and other application costs.
6. Select the correct tender status.
7. Tap **Save tender**.

### Tender expenses

Open the tender action and tap **Add expense**. Select the expense type and enter the amount, description, paid-to name, and payment mode. Examples include travel, document preparation, portal charges, consultancy, and submission cost.

The tender's application cost is the total of its saved application charges and additional tender expenses.

### Tender documents

Tap **Add document** to record the file name/type and available document details. Use clear names such as `EMD Receipt`, `Technical Bid`, or `BOQ Final`.

### Tender result and project conversion

1. When the result is confirmed, use **Mark selected** only for a genuinely awarded tender.
2. Check quoted value and tender information.
3. Tap **Convert to project**.
4. Enter the project code/name information requested.
5. Tap **Create project**.

Only a selected tender can be converted. Do not create a duplicate project manually if conversion already succeeded.

## 8. Projects and agreement calculation

### Create a project manually

Use manual creation only when the project did not originate from a tender.

1. Open **Projects**.
2. Tap or open **Create project**.
3. Enter the project name; this is required.
4. Enter project code, client, location, and dates when available.
5. Enter the gross agreement value.
6. Enter security deposit, retention, GST rate, performance guarantee, advance received, and notes as applicable.
7. Tap **Save project**.

### Understanding agreement values

- **Gross agreement value:** starting contract value.
- **Security deposit:** amount held as security.
- **Recoverable deduction:** temporarily held and expected to be returned; it is tracked but does not permanently reduce agreement value.
- **Non-recoverable deduction:** permanently reduces the final agreement value.
- **Final agreement value:** gross value minus applicable permanent deductions.

### Add agreement deductions

1. Select the project.
2. Choose the deduction type.
3. Enter amount or rate as required.
4. Mark whether it is recoverable.
5. Save the deduction.

Check the recalculated final agreement value immediately after saving.

### Milestones

Use milestones for important stages such as site handover, foundation completion, slab completion, running bill submission, testing, or final handover.

1. Select the project.
2. Enter milestone title and description.
3. Enter any payment-linked amount.
4. Save the milestone.

## 9. Work page

The Work page contains the site diary and other project expenses.

### Site diary

1. Select the correct project.
2. Enter site name, weather, and work notes.
3. Describe completed work, delays, manpower issues, inspections, or material shortages clearly.
4. Tap **Save diary**.

Use the edit button to correct a diary. Use delete only for a genuinely wrong duplicate; deletion requires confirmation.

### Other project expenses

Use this for costs that do not belong to Material, Labor, Machinery, Fuel, Repair, or Billing.

1. Select a category.
2. Enter a useful description.
3. Enter total amount.
4. Enter paid amount.
5. Select Cash, Bank transfer, UPI, Cheque, or Other.
6. Add notes/reference information.
7. Tap **Save expense**.

Examples: site rent, electricity, water, office expense, transport, permit fee, testing fee, safety expense, and miscellaneous approved cost.

## 10. Material purchases and supplier expense

1. Open **Material**.
2. Select the project.
3. Enter supplier name.
4. Enter bill or invoice number.
5. Enter the amount already paid against this purchase.
6. For every item, enter material name, unit, quantity, rate, and GST percent.
7. Tap **Add another material item** for multi-item invoices.
8. Remove an incorrect item before saving if necessary.
9. Tap **Save material purchase**.

The app calculates item amount, GST, invoice total, paid amount, pending amount, and payment status.

Common units include bag, kg, tonne, piece, number, meter, square meter, cubic meter, brass, liter, and load. Use one consistent unit for the same material.

The current Material screen records payment made at purchase time. If an additional supplier payment workflow is enabled in a later UI update, record it against the same supplier, project, and purchase rather than creating a duplicate purchase.

## 11. Labor cost

1. Open **Labor**.
2. Select the project.
3. Enter laborer/contractor name.
4. Select work type:
   - **Daywise:** number of labor days × daily rate.
   - **Thika:** fixed job quantity × agreed job rate.
   - **Hourly:** hours × hourly rate.
   - **Piecework:** completed pieces/units × rate.
   - **Custom:** company-defined quantity and unit.
5. Enter work description.
6. Enter days/quantity, rate, and paid amount.
7. Tap **Save labor work**.

The app calculates Total, Paid, Pending, and Paid/Partial/Pending status. Paid amount cannot exceed the calculated labor total.

The current quick-entry screen includes payment within the labor work entry. Labor payment and advance records are supported by the data layer; use only controls visible in your installed version and do not create a fake work entry merely to represent an advance.

## 12. Machinery, fuel, and repair combined entry

1. Open **Machinery**.
2. Select the project.
3. Enter machine name.
4. Select **Own** or **Rental**.
5. For rental machinery, enter owner name.
6. Select charge type: Hourly, Daily, Weekly, Monthly, or Fixed.
7. Enter usage quantity and rate.
8. Enter the amount already paid for usage.
9. Enter fuel quantity and fuel rate.
10. Enter repair parts cost and repair labor cost.
11. Tap **Save machinery flow**.

This single action records linked machinery usage, fuel consumption, and repair cost. Check values carefully before saving so fuel or repair is not entered again in another module.

Delete only the wrong usage entry. Deletion requires confirmation and removes that usage from displayed project totals according to the stored record rules.

## 13. Fuel-only entry

Use **Fuel** when fuel must be recorded separately from the combined Machinery entry.

### Add a fuel type

1. Enter fuel name, such as Diesel or Petrol.
2. Enter the default rate.
3. Tap **Add type**.

### Add fuel usage

1. Select the project and fuel type.
2. Enter quantity, rate, and paid amount.
3. Select where it was used: Machinery, Labor transport, Material transport, Project general, or Other.
4. If Machinery is selected, select the correct machine.
5. Enter vehicle name/number, description, and notes when relevant.
6. Tap **Save fuel**.

The app shows Total, Paid, Pending, and status. Use Edit to correct an entry. Use Delete only after confirming it is wrong.

## 14. Billing, receipts, GST, and estimates

### Create an estimate

1. Open **Billing**.
2. Select the project.
3. Enter estimate number and title.
4. Enter item name, quantity, unit, and rate.
5. Enter estimated material, labor, machinery, and other costs where applicable.
6. Tap **Save estimate**.

The app calculates estimated project cost and estimated profit against the agreement value.

### Create a bill

1. Select the project.
2. Select Running bill, Final bill, or Advance bill.
3. Enter bill number and gross bill amount.
4. Enter GST rate.
5. Enter TDS, retention, other deductions, and initial received amount.
6. Select the correct bill status.
7. Tap **Save bill**.

The app calculates:

- GST amount
- Total bill amount
- Net receivable after deductions
- Received amount
- Pending amount
- Paid/Partial/other bill status

### Record money received

1. Open **Add receipt**.
2. Select the pending bill.
3. Enter received amount.
4. Enter reference/UTR/cheque information.
5. Tap **Save receipt**.

The receipt reduces the bill's pending amount. Never record the same bank receipt twice.

### Manual GST entry

Use manual GST only when an input/output GST adjustment is not already generated from a purchase or bill.

1. Select Input GST or Output GST.
2. Enter taxable amount, GST rate/amount, source information, and notes.
3. Tap **Save GST**.

- **GST input:** GST paid on eligible purchases/expenses.
- **GST output:** GST charged through project bills.
- **Net GST position:** output GST minus input GST.

Ask the accountant before making manual GST adjustments.

## 15. Reports and profit/loss

Open **Reports** to see:

- Agreement value
- Estimated project cost
- Total material cost
- Total labor cost
- Total machinery cost
- Total fuel cost
- Total repair cost
- Other expenses
- Total actual cost
- GST input and output
- Total billed and received
- Pending receivable
- Total payable
- Estimated profit
- Actual profit/loss by agreement
- Actual profit/loss by money received

### Meaning of profit figures

- **Estimated profit:** agreement value minus estimated project cost.
- **Actual profit by agreement:** agreement value minus actual recorded cost.
- **Actual profit by received:** money actually received minus actual recorded cost.

A project can show profit by agreement but a temporary loss by received when client payments are still pending.

### Export reports

Authorized users can tap **Export PDF** or **Export Excel**, choose a safe location, and share the file only with approved people. Excel includes both exact stored money and formatted display values.

## 16. Sync between devices

1. Make sure the correct company account is signed in.
2. Open **Data sync** from the top sync button or menu.
3. Review Waiting to send, Sent, Received, Updated locally, Could not update, Needs review, and Last sync.
4. Tap **Sync now**.
5. Wait for the completion message before closing the app.

If internet is unavailable, local work remains saved. Retry later.

### Safe daily sync routine

- Morning: sync before entering new work.
- During the day: save entries normally.
- Evening: sync after completing entries.
- Before changing devices: sync the first device, then sync the second device.

## 17. Items needing attention

A conflict occurs when the same record was changed differently on two devices before both changes were synced.

Only the Owner or Admin can resolve it.

- **Keep this device's copy:** use the record currently stored on this device.
- **Use the other device's copy:** replace it with the other synced copy.

Before choosing, ask the people who made both entries and compare invoice, bill, date, amount, and project. Do not guess. Developer merge/technical record details appear only in debug builds.

## 18. Backup and restore

### Create a backup

1. Open **Settings**.
2. Tap **Create backup**.
3. Choose a safe folder.
4. Keep at least one copy outside the device.
5. Include the backup date in your office backup register.

The backup contains company business records. It does not contain passwords, active login credentials, staff access cache, or device credentials.

### Restore a backup

1. Confirm you selected the correct company.
2. Create a new backup of current data first.
3. Tap **Restore backup**.
4. Read the warning.
5. Select the correct JSON backup file.
6. Confirm restore.
7. Review the number of added and updated records.
8. Check Dashboard, Projects, Billing, and Reports.
9. Sync after verification.

Never restore another company's backup. Restore updates matching records and adds missing records; it does not change current authentication or staff access.

## 19. Daily operating checklist

### Site Supervisor

- Sync at the start of the day.
- Confirm project selection.
- Enter site diary.
- Enter material received with invoice details.
- Enter labor work and paid amount.
- Enter machinery/fuel/repair once only.
- Review pending values.
- Sync at the end of the day.

### Accountant

- Check supplier, labor, machinery, fuel, and other pending amounts.
- Verify bills and receipts against bank/cheque/UPI records.
- Review GST input/output.
- Review duplicate invoices and receipts.
- Export and file reports.
- Notify the owner of overdue receivables.

### Project Manager

- Review site diaries and project milestones.
- Check agreement deductions.
- Compare estimated and actual cost.
- Review all new expenses.
- Confirm billing progress and client pending amount.

### Owner/Admin

- Review Dashboard and profit/loss.
- Check staff assignments and access status.
- Resolve sync items needing attention.
- Confirm large expenses and manual GST adjustments.
- Create scheduled backups.
- Revoke staff immediately when they leave the company.

## 20. Month-end checklist

1. Sync all authorized devices.
2. Confirm every project expense is entered once.
3. Match material invoices with supplier records.
4. Match labor and machinery paid amounts with payment proof.
5. Match bill receipts with bank statements.
6. Review GST input/output with the accountant.
7. Review total pending receivable and payable.
8. Export PDF and Excel reports.
9. Create and safely store a dated backup.
10. Record any correction in company notes/audit procedure.

## 21. Common problems

### Save button is disabled

Complete every required field and check that quantity/rate/amount values are valid and non-negative. Paid amount cannot be greater than total amount.

### Project is not visible

Ask the Owner/Admin to assign that project to your staff account, then tap **Refresh access** and sync.

### Sync does not finish

Check internet, confirm the user is active, and retry. Local work remains saved. If Needs review is greater than zero, ask the Owner/Admin to resolve it.

### Pending amount looks wrong

Open the original purchase, labor, machinery, fuel, expense, or bill. Check total and paid amounts and search for duplicate records or receipts.

### Profit looks too high

Usually an expense is missing or recorded under the wrong project. Check Material, Labor, Machinery, Fuel, Repair, and Other expenses.

### Profit looks too low

Check duplicate expenses, wrong quantity/rate, incorrect GST, or an expense entered in both Machinery and Fuel.

### Deleted something by mistake

Stop entering more changes, do not restore an old backup without approval, and contact the Owner/Admin. Use the most recent verified backup only after understanding which newer records may be affected.

## 22. Data safety responsibilities

- The company owns the data; every user must follow company policy.
- Owners should keep encrypted/off-device backups.
- Never email private backup files without protection.
- Remove access immediately for departed staff.
- Use individual accounts; do not share one login among many people.
- Keep Windows and Android devices locked and updated.
- Do not uninstall the app or clear app data before confirming a current backup and completed sync.

