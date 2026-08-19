# NovaExpress PDA App — Remittance Screen

The **Remittance** module is one of the most financially sensitive parts of the PDA app.

Its purpose is to let the agent clearly understand:

> **How much money have I collected? How much am I entitled to deduct? How much must I remit? How much have I already remitted? And what is still outstanding?**

For NovaExpress, this should **not** be treated simply as a "send money" screen. It is a **cash-accountability and settlement module**.

---

# 1. Remittance Module Structure

```text
REMITTANCE
│
├── Remittance Dashboard
│   ├── Total Collected
│   ├── Agent Earnings
│   ├── Transport Allowance
│   ├── Other Approved Deductions
│   ├── Expected Remittance
│   ├── Already Remitted
│   └── Outstanding
│
├── Current Remittance
│   ├── Delivery Collections
│   ├── Earnings / Deductions
│   ├── Expected Amount
│   ├── Payment Method
│   ├── POS / Transfer Charges
│   └── Submit Remittance
│
├── Remittance History
│   ├── Completed
│   ├── Pending Verification
│   ├── Rejected
│   └── Disputed
│
└── Remittance Details
    ├── Collection Breakdown
    ├── Deduction Breakdown
    ├── Payment Evidence
    ├── Verification
    └── Audit Trail
```

---

# 2. MAIN REMITTANCE SCREEN

The main screen should open with the **current financial position**.

### Header

**Remittance**

Under it:

**PDA-0042 • John**

Optional:

**Today — 18 Aug 2026**

---

# 3. REMITTANCE SUMMARY

This should be the most important section.

For example:

### Collected

**₦75,000**

Total POD cash/payment collections currently attributed to the PDA.

---

### Your Earnings

**₦5,000**

Based on the agent's current compensation arrangement.

---

### Transport Allowance

**₦7,500**

---

### Expected Remittance

# **₦62,500**

---

### Already Remitted

**₦40,000**

---

### Outstanding

# **₦22,500**

This gives the PDA an immediate understanding of their financial obligation.

---

# 4. VERY IMPORTANT — DON'T MIX COLLECTION AND EARNINGS

The system should distinguish:

**Customer money collected**

from:

**Money belonging to the PDA**

and:

**Money belonging to NovaExpress / client.**

For example:

```text
Customer Collections             ₦75,000

Less:
PDA Commission                    ₦5,000
Transport Allowance               ₦7,500

Expected Remittance              ₦62,500
```

The PDA shouldn't have to manually calculate this.

---

# 5. TODAY'S COLLECTIONS

Below the summary:

### Today's Collections

**15 deliveries**

**₦75,000 collected**

Tap:

**View Collections**

This opens the list of individual deliveries contributing to the remittance.

---

# 6. COLLECTION LIST

Example:

### NX-00482

**Respira × 2**

Customer:

Chinedu Okafor

Collected:

**₦15,000**

Status:

**Collected**

---

### NX-00483

**Grazer Herbal Tea × 6**

Collected:

**₦20,000**

---

### NX-00484

**Alpha Man × 2**

Collected:

**₦10,000**

Every collection should link back to the original delivery.

---

# 7. WHY THIS IS IMPORTANT

The PDA must be able to answer:

> "Why does the system say I owe ₦62,500?"

The answer should be traceable down to individual deliveries.

For example:

```text
15 successful POD deliveries
        ↓
₦75,000 collected
        ↓
Agent deductions calculated
        ↓
₦62,500 expected remittance
```

Nothing should appear as an unexplained balance.

---

# 8. EARNINGS BREAKDOWN

The PDA should have a dedicated section:

### Your Earnings

For the current period:

**Successful Delivery Commission**

15 × ₦1,000

= **₦15,000**

But the exact calculation should come from the configured compensation rules.

If some deliveries have different commission rates, show them individually.

---

# 9. TRANSPORT ALLOWANCE

Show separately:

### Transport Allowance

Successful deliveries:

15 × ₦1,500

= **₦22,500**

Failed delivery transport:

2 × ₦500

= **₦1,000**

Total transport allowance:

**₦23,500**

Again, these are examples—the actual rates should come from the admin configuration.

---

# 10. FAILED DELIVERY PAYMENTS

Failed deliveries need special handling.

For the current Novacare arrangement:

### Failed Deliveries

**2 failed deliveries**

Client failed-delivery charge:

2 × ₦1,500

= **₦3,000**

This should be recorded as a **client/service charge**, not as customer POD money collected by the PDA.

Likewise, the PDA's failed-delivery allowance can be calculated separately.

---

# 11. DO NOT PUT FAILED-DELIVERY MONEY INTO CUSTOMER COLLECTIONS

This distinction is critical.

A successful POD delivery might be:

> Customer pays ₦15,000.

A failed delivery might generate:

> Client owes NovaExpress ₦1,500.

Those are **different financial events**.

The PDA's remittance screen should therefore distinguish:

### Customer Collections

from

### Service Charges / Failed Delivery Charges

The latter may be accounted for centrally rather than being part of the PDA's physical cash remittance.

---

# 12. CURRENT REMITTANCE

When the PDA is ready to remit:

CTA:

**Start Remittance**

Open:

# Current Remittance

Show:

### Total Collected

**₦75,000**

### Less Your Approved Deductions

Commission:

**₦15,000**

Transport:

**₦22,500**

Other approved deductions:

**₦0**

### Amount to Remit

# **₦37,500**

The exact formula depends on the configured compensation model.

---

# 13. COMMISSION-BASED PDA

For a commission-based PDA:

```text
Total POD Collections
        ↓
- Delivery Commission
- Approved Transport Allowance
- Other Approved Deductions
        ↓
EXPECTED REMITTANCE
```

This amount is automatically calculated.

The PDA shouldn't type:

> "I am remitting ₦37,500."

Instead, the system should say:

> **Your expected remittance is ₦37,500.**

The PDA confirms it.

---

# 14. SALARY-BASED PDA

This is important because NovaExpress can configure agents differently.

If the PDA is **salary-based**, don't show:

> Commission: ₦15,000

Instead:

### Compensation

**Salary Based**

### Delivery Earnings

**Handled through monthly payroll**

The remittance calculation should therefore not deduct commission unless a configured rule says otherwise.

---

# 15. IN-HOUSE RIDER

The same Remittance module can support an in-house rider, but their calculation is different.

Current arrangement:

### Successful Delivery

**₦500 commission**

### Fuel

**₦800 per trip**

### Failed Delivery

**₦500 stipend**

However:

> **The rider remits the full amount collected.**

Therefore the screen should show:

### Collected

₦75,000

### Amount to Remit

# ₦75,000

And separately:

### Earnings Accrued

Commission:

₦7,500

Fuel:

₦12,000

These earnings are **not deducted from the current remittance**.

They accumulate for monthly payment.

This distinction is extremely important.

---

# 16. PDA VS RIDER LOGIC

The system should therefore have a configurable **settlement rule**.

### PDA — Current Arrangement

```text
Collections
   ↓
Less commission
Less transport
   ↓
PDA remits balance
```

### In-house Rider — Current Arrangement

```text
Collections
   ↓
Rider remits full amount
   ↓
Commission + fuel accumulate
   ↓
Paid at month-end
```

But these are **configurable business rules**, not hard-coded behavior.

---

# 17. PAYMENT METHOD

When submitting remittance:

### How are you remitting?

Options:

* Bank Transfer
* Cash to DC
* POS / Agent Transfer
* Other approved method

The available options should be controlled by NovaExpress.

---

# 18. BANK TRANSFER

If selected:

### Transfer Details

Amount:

**₦37,500**

Bank:

**[Select/Configured NovaExpress Account]**

Account:

**XXXXXXXXXX**

Reference:

**Enter transaction reference**

The PDA submits the reference.

---

# 19. POS REMITTANCE

For the Nigerian operational scenario, POS must be supported.

Example:

### POS Transfer

Amount:

**₦37,500**

POS/service charge:

**₦100**

Transfer amount:

**₦37,500**

The POS charge should be recorded separately.

Do **not** automatically reduce the remittance because of the POS fee.

Instead:

### POS Charge

**₦100**

**Pending Approval**

The admin can determine whether it is an allowable operational expense.

---

# 20. POS EVIDENCE

Allow the PDA to provide:

* POS receipt/photo
* Transaction reference
* POS agent name
* POS agent phone number, where appropriate
* Date/time
* Amount
* Fee

Example:

### POS Transaction

Amount:

₦37,500

Fee:

₦100

Reference:

POS-839201

Evidence:

**Receipt attached ✓**

---

# 21. CASH REMITTANCE

If the PDA hands cash to the DC:

### Cash Remittance

Amount:

**₦37,500**

Handed to:

**Wuse Distribution Center**

The DC staff should verify the physical cash.

The PDA submits:

**Request Verification**

The DC confirms:

**Cash Received**

Then the remittance becomes:

**Verified**

---

# 22. REMITTANCE STATUS

Every remittance should have a status.

Recommended:

### Draft

Not yet submitted.

### Submitted

Agent has submitted the remittance.

### Pending Verification

Operations/DC has not yet confirmed it.

### Verified

Amount and evidence confirmed.

### Partially Verified

Some component requires investigation.

### Rejected

Submission was rejected.

### Disputed

There is a financial discrepancy.

---

# 23. REMITTANCE CONFIRMATION

Before submitting:

```text
Confirm Remittance

Collections                 ₦75,000

Commission                 -₦15,000
Transport                  -₦22,500

Expected Remittance         ₦37,500

Payment Method
Bank Transfer

Reference
TRX-829102

[Submit Remittance]
```

Then require confirmation.

---

# 24. SUCCESSFUL SUBMISSION

Show:

# Remittance Submitted

**₦37,500**

Reference:

**REM-00482**

Status:

**Pending Verification**

Submitted:

**18 Aug 2026 • 6:04 PM**

CTA:

**View Remittance**

---

# 25. REMITTANCE HISTORY

The main Remittance screen should have:

### History

Example:

**REM-00481**

₦45,000

**Verified ✓**

17 Aug 2026

---

**REM-00472**

₦32,500

**Verified ✓**

16 Aug 2026

---

**REM-00463**

₦28,000

**Pending Verification**

15 Aug 2026

Tap any record → **Remittance Details**

---

# 26. REMITTANCE DETAILS

A completed remittance should show the full audit trail.

### Remittance

**REM-00482**

### Amount

**₦37,500**

### Collections

₦75,000

### Deductions

Commission: ₦15,000

Transport: ₦22,500

### Payment Method

Bank Transfer

### Reference

TRX-829102

### Submitted

18 Aug • 6:04 PM

### Verified

18 Aug • 6:15 PM

### Verified By

Wuse DC — Operations

---

# 27. DISCREPANCY FLOW

This is essential.

Suppose:

Expected:

**₦37,500**

PDA says they are remitting:

**₦35,000**

The system should **not simply allow this**.

Show:

### Remittance Difference

Expected:

**₦37,500**

Entered:

**₦35,000**

Difference:

**₦2,500**

### Why is there a difference?

* Cash shortage
* Customer payment discrepancy
* Approved expense
* Previous adjustment
* POS/transaction issue
* Other

The discrepancy is then sent for review.

---

# 28. OVER-REMITTANCE

Likewise:

Expected:

**₦37,500**

Actual:

**₦40,000**

Show:

### Excess Remittance

**₦2,500**

The system records the excess rather than silently changing the expected amount.

Operations can later reconcile it.

---

# 29. REMITTANCE DASHBOARD

The main screen could ultimately look like:

```text id="r3j5yb"
┌──────────────────────────────────┐
│ Remittance                   ⋮   │
│ PDA-0042 • John                 │
├──────────────────────────────────┤
│                                  │
│ CURRENT BALANCE                  │
│                                  │
│ Collected                        │
│ ₦75,000                          │
│                                  │
│ Your Earnings                    │
│ ₦15,000                          │
│                                  │
│ Transport                        │
│ ₦22,500                          │
│                                  │
│ ───────────────────────────────  │
│                                  │
│ EXPECTED REMITTANCE              │
│                                  │
│ ₦37,500                          │
│                                  │
│ Outstanding: ₦37,500             │
│                                  │
├──────────────────────────────────┤
│ TODAY'S COLLECTIONS              │
│ 15 deliveries                    │
│ ₦75,000 collected         >      │
├──────────────────────────────────┤
│ PENDING REMITTANCE               │
│ ₦37,500                          │
│                                  │
│ [ Start Remittance ]             │
├──────────────────────────────────┤
│ RECENT REMITTANCES         See All│
│                                  │
│ REM-00481                        │
│ ₦45,000                          │
│ ✓ Verified                       │
│                                  │
│ REM-00472                        │
│ ₦32,500                          │
│ Pending Verification             │
└──────────────────────────────────┘
```

---

# 30. The Critical Architecture Behind This Screen

I would make one important distinction in the system:

### Collection Ledger

Tracks:

> **Money the PDA collected from customers.**

### Earnings Ledger

Tracks:

> **Money the PDA has earned.**

### Remittance Ledger

Tracks:

> **Money the PDA owes NovaExpress/client and has actually remitted.**

### Expense/Deduction Ledger

Tracks:

> **Transport, POS charges, approved expenses, etc.**

These should **not be one single balance field**.

That separation will make the NovaExpress accounting much easier to audit and will allow the business to change compensation arrangements later without redesigning the entire financial system.

---

# 31. Final Remittance Screen Set for the Designer

I would design these major states:

1. **Remittance Dashboard**
2. **Today's Collections**
3. **Collection Details**
4. **Current Remittance**
5. **Earnings Breakdown**
6. **Deduction / Transport Breakdown**
7. **Select Remittance Method**
8. **Bank Transfer Remittance**
9. **POS Remittance**
10. **Cash Remittance**
11. **Remittance Review**
12. **Remittance Submitted**
13. **Remittance Details**
14. **Remittance History**
15. **Remittance Discrepancy**
16. **Pending Verification**

Again, several of these can be **states of the same screen or bottom sheets**, rather than 16 completely separate screens.

The most important UX principle is:

> **The PDA should never have to calculate what they owe NovaExpress. The system calculates it from completed deliveries, collected payments, the agent's compensation arrangement, approved transport allowances, and other configured financial rules.**

---

# 32. Direct Company Transfers (Monnify) vs. Physical Cash POD

An essential operational distinction in the NovaExpress financial flow:

### Scenario A: Physical Cash POD
1. Customer pays physical cash in hand to the rider.
2. The rider holds the physical funds in their personal custody.
3. **Remittance is REQUIRED**: The rider must remit the net amount (`Gross Cash Collected - Commission Earned - Transport Allowance`) to NovaExpress via bank transfer or DC cash handover before 6:00 PM.

### Scenario B: Direct Company Transfer (Monnify Virtual Account)
1. At the completion of delivery, the customer chooses to pay via instant bank transfer.
2. The PDA generates and displays a **dynamic virtual bank account number (powered by Monnify)** generated uniquely for that specific delivery order.
3. The customer transfers funds directly into NovaExpress’s Monnify account.
4. Once verified via Monnify webhook:
   - **Rider Holds ₦0.00 physical cash**.
   - **NO Cash Remittance is required from the rider** for this order.
   - **Company Owes the Rider**: The rider is still entitled to their delivery commission and transport allowance for executing the delivery.
   - The earnings from direct-transfer orders are credited directly into the **Rider Balance ("My Balance")** ledger.

---

# 33. Rider Balance ("My Balance") & Payout Request Workflow

### The 5th Financial Ledger: Rider Payable Ledger ("My Balance")
Accumulates all earnings owed by the company to the commissioned rider, specifically:
- Commission and transport allowances from Monnify direct-transfer deliveries.
- Excess remittances or approved operational reimbursements.

### Payout Request Workflow:
1. **Balance Visibility**: The rider views their accrued **My Balance** in the Remittance module KPIs.
2. **Request Payout**: The rider taps **"Request Payout"**, enters/confirms their payout amount, and provides or confirms their personal bank account details (Bank Name, Account Number, Account Name).
3. **DC / Finance Approval**: The Distribution Center (DC) Finance Manager reviews the payout request against reconciled deliveries.
4. **Disbursement**: Upon DC approval, funds are disbursed to the rider's personal account, and the "My Balance" ledger is debited accordingly.
5. **Audit Trail**: Every payout request has a lifecycle status: `Pending Approval`, `Approved / Paid`, or `Rejected`.
