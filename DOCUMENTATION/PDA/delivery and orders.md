Absolutely. For the **PDA / Delivery Agent app**, the **Deliveries / Orders** module should be one of the most important areas because this is where the agent actually executes the business operation.

The key is to avoid treating it as just an "order list." It needs to handle the full lifecycle:

**Assigned → Accepted → Out for Delivery → Delivered / Failed → Payment → Remittance / Return**

# NOVAEXPRESS PDA APP — DELIVERY / ORDERS MODULE

## 1. Delivery Module Structure

```text
DELIVERIES
│
├── Delivery List
│   ├── All
│   ├── Pending
│   ├── In Progress
│   ├── Delivered
│   ├── Failed
│   └── Returns
│
├── Delivery Details
│   ├── Order Information
│   ├── Customer Information
│   ├── Package / Product Information
│   ├── Payment Information
│   ├── Delivery Information
│   ├── Timeline
│   └── Financial Breakdown
│
├── Start Delivery
│   ├── Customer Confirmation
│   ├── Navigation
│   └── Delivery Checklist
│
├── Successful Delivery
│   ├── Payment Collection (if POD)
│   ├── Payment Confirmation
│   ├── Proof of Delivery
│   └── Complete Delivery
│
├── Failed Delivery
│   ├── Failure Reason
│   ├── Payment Status
│   ├── Retry / Reschedule
│   └── Return Requirement
│
└── Returns
    ├── Return Required
    ├── Return Details
    ├── Return to DC
    └── Return Confirmation
```

---

# 2. DELIVERY LIST SCREEN

This is the main screen when the PDA taps **Deliveries**.

## Header

Display:

* Page title: **Deliveries**
* Notification icon
* Search icon
* Optional filter icon

Under the header:

### Summary

For example:

**12 Assigned**

* 5 Pending
* 2 In Progress
* 4 Delivered
* 1 Failed

The exact summary should be dynamically calculated.

---

# 3. DELIVERY FILTER TABS

Recommended tabs:

### All

Every delivery assigned to the PDA.

### Pending

Assigned but not yet started.

### In Progress

Agent has started the delivery.

### Delivered

Successfully completed.

### Failed

Attempted but unsuccessful.

### Returns

Packages/products requiring return or already returned.

---

# 4. DELIVERY CARD

Each delivery should provide enough information for the PDA to understand the job without opening it.

Example:

### NX-00482

**Chinedu Okafor**

📍 Lekki Phase 1, Lagos

**Respira × 2**

**POD — ₦15,000**

**Today • 10:30 AM**

Status:

**Pending**

CTA:

**View Delivery**

For an active delivery:

**Out for Delivery**

CTA:

**Continue Delivery**

---

# 5. DELIVERY CARD INFORMATION RULE

The card should prioritize:

1. Customer
2. Location
3. Package/product
4. POD status
5. Amount to collect
6. Delivery status
7. Required action

The PDA shouldn't need to open the order just to know what they need to do.

---

# 6. SEARCH

The PDA should be able to search by:

* Order ID
* Customer name
* Customer phone number
* Product
* Delivery address

Example:

Search:

`NX-00482`

or:

`Chinedu`

---

# 7. FILTERS

Filters should include:

### Delivery Status

* Pending
* In Progress
* Delivered
* Failed
* Returned

### Payment Type

* POD
* Non-POD

### Delivery Type

* Direct Delivery
* Distributed Inventory

### Client

Example:

* Novacare Limited
* Other clients

### Date

* Today
* Yesterday
* This week
* Custom date

---

# 8. DELIVERY DETAILS SCREEN

When the PDA opens an order, the screen should provide the complete operational information.

Structure:

```text
Delivery Details
│
├── Status
├── Order Information
├── Customer
├── Package / Product
├── Payment
├── Delivery Address
├── Delivery Timeline
├── Financial Information
└── Actions
```

---

# 9. STATUS HEADER

At the top:

**NX-00482**

**Out for Delivery**

Potential status values:

* Assigned
* Accepted
* Ready
* Out for Delivery
* Delivered
* Failed
* Return Required
* Returned
* Cancelled

---

# 10. ORDER INFORMATION

Display:

* Order ID
* Delivery ID
* Client
* Order date
* Assigned date
* Delivery type
* Payment type

Example:

**Client**

Novacare Limited

**Delivery Type**

Distributed Inventory

**Payment**

POD

---

# 11. CUSTOMER INFORMATION

Display:

### Customer

**Chinedu Okafor**

Phone:

**080XXXXXXXX**

Address:

**12 Admiralty Way, Lekki Phase 1, Lagos**

Additional information where available:

* Landmark
* State
* LGA
* Delivery instructions

---

# 12. CUSTOMER ACTIONS

Provide quick actions:

### Call Customer

Opens phone call.

### WhatsApp

If supported.

### Navigate

Opens the configured navigation application.

### Copy Address

Useful when working with external navigation apps.

---

# 13. PACKAGE / PRODUCT INFORMATION

This section is extremely important because NovaExpress has distributed inventory.

Example:

### Package

**Respira**

Quantity:

**2 units**

Inventory owner:

**Novacare Limited**

Inventory type:

**Distributed Inventory**

Payment type:

**POD**

---

# 14. BUNDLE / FREE PRODUCT HANDLING

If an order contains a promotional package:

### Grazer Herbal Tea

Paid:

**5 units**

Free:

**1 unit**

Total physical units:

**6**

The agent must see:

> **Deliver all 6 units**

This prevents free products from disappearing from inventory records.

---

# 15. PACKAGE IDENTIFICATION

Where applicable, display:

* SKU
* Package ID
* Batch number
* Serial number
* Barcode
* Quantity

If the business later requires scanning, the PDA can scan the package before starting the delivery.

---

# 16. PAYMENT SECTION

For a POD order, this section should be prominent.

Example:

### Amount to Collect

# ₦15,000

Payment:

**Pay on Delivery**

Payment status:

**Not Collected**

The PDA should not manually type the expected amount.

The amount comes from the order.

---

# 17. NON-POD PAYMENT

For Non-POD:

### Payment

**Prepaid**

Amount to collect:

**₦0**

Status:

**Already Paid**

This prevents the PDA from accidentally collecting money from a customer who should not pay.

---

# 18. DELIVERY INFORMATION

Display:

* Assigned agent
* Distribution Center
* Assignment date
* Expected delivery date
* Delivery attempt count
* Priority
* Special instructions

Example:

**Assigned DC**

Wuse Distribution Center

**Attempt**

1 of 2

---

# 19. DELIVERY TIMELINE

The PDA should be able to see what has happened.

Example:

```text
10:02 AM
Delivery assigned

10:08 AM
Accepted by John

10:15 AM
Out for delivery

10:45 AM
Customer contacted

11:02 AM
Awaiting delivery confirmation
```

After successful completion:

```text
11:08 AM
Payment collected

11:09 AM
Proof of delivery submitted

11:10 AM
Delivery completed
```

---

# 20. FINANCIAL BREAKDOWN

This should be visible to the PDA but **not editable**.

For a current PDA commission arrangement:

```text
Customer Collection       ₦15,000

PDA Commission             ₦1,000
Transport Allowance        ₦1,500

Expected Remittance       ₦12,500
```

The exact values should come from the configured business rules.

---

# 21. IMPORTANT: DON'T SHOW INTERNAL CLIENT ACCOUNTING EXCESSIVELY

The PDA doesn't need to see complicated accounting such as:

* Client payable
* NovaExpress revenue
* Client settlement ledger

unless operationally necessary.

They primarily need:

> **How much did I collect?**

> **What am I entitled to?**

> **How much do I need to remit?**

---

# 22. PRIMARY DELIVERY ACTIONS

The available action should depend on the current state.

### Assigned

**Accept Delivery**

### Accepted

**Start Delivery**

### Out for Delivery

**Complete Delivery**

or:

**Report Failed Delivery**

### Delivered

No delivery action.

### Failed

**Retry Delivery**

or:

**Return Package**

---

# 23. ACCEPT DELIVERY

When the PDA receives a delivery assignment:

CTA:

**Accept Delivery**

Confirmation modal:

> Accept this delivery?

Show:

* Customer
* Location
* Package
* Amount to collect
* Expected delivery date

Actions:

**Accept**

**Cancel**

---

# 24. START DELIVERY

After acceptance:

**Start Delivery**

Before starting, the system can show a short checklist:

### Delivery Checklist

* Package/product confirmed
* Quantity confirmed
* Customer address available
* Payment requirement understood

CTA:

**Start Delivery**

---

# 25. START DELIVERY STATE

Once started:

Status changes:

**Out for Delivery**

The system records:

* Start time
* Agent
* Delivery attempt
* Location/GPS if enabled

The order becomes an active operational task.

---

# 26. SUCCESSFUL DELIVERY FLOW

When the agent reaches the customer:

```text
Delivery Details
       ↓
Complete Delivery
       ↓
Confirm Package
       ↓
Collect Payment (if POD)
       ↓
Payment Confirmation
       ↓
Proof of Delivery
       ↓
Customer Confirmation
       ↓
Delivery Complete
```

---

# 27. PACKAGE CONFIRMATION

Before completion:

### Confirm Items

**Respira × 2**

☑ Quantity correct

For bundles:

**Grazer Herbal Tea**

5 Paid

1 Free

6 Total

The agent confirms that the physical package matches the delivery.

---

# 28. POD PAYMENT COLLECTION

If POD:

Show:

# ₦15,000

**Amount to Collect**

Then:

### Payment Method

* Cash
* Bank Transfer
* POS
* Other approved method

The business can configure which methods are permitted.

---

# 29. CASH COLLECTION

If the agent selects:

**Cash**

The system records:

**₦15,000 collected**

The agent should not be allowed to modify the expected order amount without an approved exception process.

---

# 30. BANK TRANSFER

If customer transfers:

Capture:

* Amount
* Bank/payment reference
* Optional screenshot/evidence
* Time
* Payment method

Status:

**Payment Awaiting Verification**

or, depending on the business's process:

**Payment Recorded**

---

# 31. POS PAYMENT

If customer pays via POS:

Capture:

* Amount
* Transaction reference
* POS method
* Evidence where required

The customer-facing transaction fee, if any, should be handled according to the configured business rules.

Do not automatically treat the POS operator's fee as the PDA's personal commission.

---

# 32. PROOF OF DELIVERY

Successful delivery should require configured proof.

Possible proof types:

* OTP
* Customer signature
* Customer name
* Photo
* Delivery confirmation
* GPS/location
* Timestamp

The system administrator should be able to configure which is mandatory.

---

# 33. OTP FLOW

If OTP is required:

Screen:

**Enter Customer OTP**

Customer provides:

`482913`

Agent enters it.

System validates.

If correct:

**Delivery Verified**

If incorrect:

**Invalid OTP**

Allow retry according to configured rules.

---

# 34. CUSTOMER SIGNATURE

If signature is required:

Display signature area.

Customer signs.

CTA:

**Confirm Signature**

Then:

**Continue**

---

# 35. DELIVERY PHOTO

If required:

Camera opens.

Agent captures proof.

Example:

* Package/customer handover
* Delivery location
* Other configured evidence

The photo becomes attached to the delivery record.

---

# 36. FINAL DELIVERY CONFIRMATION

Before completion:

```text
Confirm Delivery

Customer:
Chinedu Okafor

Package:
Respira × 2

Payment:
₦15,000 — Collected

Proof:
OTP Verified ✓

Amount to Remit:
₦12,500
```

CTA:

**Complete Delivery**

This is the final commitment action.

---

# 37. DELIVERY SUCCESS SCREEN

After completion:

### Delivery Successful

**NX-00482**

Show:

✓ Delivery completed

✓ Payment collected

✓ Proof submitted

Then:

### Financial Summary

Collected:

**₦15,000**

Your commission:

**₦1,000**

Transport:

**₦1,500**

Expected remittance:

**₦12,500**

CTA:

**View Delivery**

Secondary:

**Back to Deliveries**

---

# 38. FAILED DELIVERY FLOW

The PDA should have a clear:

**Report Failed Delivery**

action.

Do not simply show a text field saying "Reason."

The system should structure the failure.

---

# 39. FAILED DELIVERY SCREEN

### Why was delivery unsuccessful?

Options:

* Customer unavailable
* Customer phone unreachable
* Wrong address
* Customer refused
* Customer refused payment
* Customer requested reschedule
* Package damaged
* Customer cancelled
* Other

---

# 40. FAILURE DETAILS

Depending on the selected reason, request additional information.

Example:

**Customer unavailable**

Ask:

> Did you contact the customer?

* Yes
* No

> Should this delivery be retried?

* Yes
* No

---

# 41. FAILED POD DELIVERY

If the customer refused to pay:

The system should explicitly capture:

**Payment was not collected**

This is different from:

**Customer unavailable**

because the financial implications may differ.

---

# 42. FAILED DELIVERY FINANCIAL CALCULATION

For the current Novacare arrangement:

Successful delivery:

**₦5,000**

Failed delivery:

**₦1,500**

Agent's failed-delivery transport:

**₦500**

These should be automatically calculated according to the active configuration.

The agent should not manually enter these values.

---

# 43. RETURN DECISION

After failure:

### What happens next?

Possible options based on business rules:

**Retry Delivery**

**Return to DC**

**Hold for Reschedule**

**Contact Operations**

The system should determine which options are available.

---

# 44. RETRY DELIVERY

If retry is permitted:

Display:

**Attempt 1 Failed**

CTA:

**Schedule Retry**

Capture:

* Retry date
* Optional time
* Reason
* Customer confirmation

Then status:

**Retry Scheduled**

---

# 45. RETURN REQUIRED

If the package must return:

Status:

**Return Required**

The PDA sees:

### Return To

**Wuse Distribution Center**

### Items

Respira × 2

CTA:

**Start Return**

---

# 46. RETURN HANDOVER

At the DC:

The PDA presents the package.

DC staff verifies:

* Package
* Product
* Quantity
* Condition

PDA confirms:

**Return Handed Over**

DC confirms:

**Received**

Then the system updates the inventory.

---

# 47. RETURN STATUS

Recommended states:

```text
Return Required
↓
Return Initiated
↓
In Transit to DC
↓
Received by DC
↓
Under Verification
↓
Accepted
↓
Inventory Restored
```

If there is a discrepancy:

**Return Disputed**

---

# 48. DELIVERY HISTORY

The history screen should allow the PDA to review previous deliveries.

Display:

* Order ID
* Customer
* Product/package
* Date
* Amount collected
* Delivery status
* Remittance status

Filters:

* Date
* Status
* POD/Non-POD
* Client

---

# 49. DELIVERY NOTIFICATIONS

Relevant notifications can include:

### New Assignment

> New POD delivery assigned.

### Assignment Changed

> Delivery NX-00482 has been reassigned.

### Delivery Reminder

> You have 3 pending deliveries.

### Failed Delivery

> Delivery marked as failed. Return required.

### Return Reminder

> Respira × 2 is awaiting return to Wuse DC.

### Financial

> Remittance of ₦12,500 is pending verification.

---

# 50. IMPORTANT EDGE CASES

The designer should create states for:

### Customer refuses to pay

Do not mark delivered.

### Customer pays partial amount

Requires controlled exception flow.

### Customer pays more than expected

Requires controlled exception flow.

### Customer pays less than expected

Requires controlled exception flow.

### Wrong product

Do not complete delivery.

### Missing quantity

Report discrepancy.

### Damaged product

Capture damage before delivery.

### Customer requests another location

Do not silently change address.

### Agent loses network

Preserve operational state appropriately.

### Agent cannot return package immediately

Return remains outstanding.

---

# 51. ORDER VS DELIVERY — IMPORTANT SYSTEM DISTINCTION

For the product architecture, I strongly recommend distinguishing:

**Order**

from

**Delivery Attempt**

An order may have multiple delivery attempts.

Example:

```text
ORDER NX-00482
│
├── Delivery Attempt 1
│      └── Failed — Customer unavailable
│
├── Delivery Attempt 2
│      └── Failed — Customer refused payment
│
└── Delivery Attempt 3
       └── Successful
```

This is much better than creating three unrelated orders.

---

# 52. DELIVERY DATA MODEL CONCEPT

The UI should reflect this structure:

```text
ORDER
│
├── Customer
├── Client
├── Package / Products
├── Payment Terms
│
└── DELIVERY
     │
     ├── Assigned Agent
     ├── Distribution Center
     ├── Status
     ├── Attempt History
     ├── Proof of Delivery
     ├── Payment Collection
     ├── Commission
     └── Remittance
```

---

# 53. RECOMMENDED DELIVERY SCREEN SET

For your designer, I would give them this exact screen list:

### Core

1. **Deliveries List**
2. **Delivery Details**
3. **Delivery Search**
4. **Delivery Filters**

### Assignment

5. **Accept Delivery Modal**
6. **Start Delivery Confirmation**

### Active Delivery

7. **Active Delivery**
8. **Navigation / Customer Contact**
9. **Package Verification**

### Successful Delivery

10. **Payment Collection**
11. **Payment Method**
12. **Payment Confirmation**
13. **Proof of Delivery**
14. **Final Delivery Confirmation**
15. **Delivery Success**

### Failed Delivery

16. **Report Failed Delivery**
17. **Failure Reason**
18. **Failure Details**
19. **Retry / Reschedule**
20. **Return Required**

### Returns

21. **Return Details**
22. **Return Initiated**
23. **Return Handover**
24. **Return Confirmation**

### History

25. **Delivery History**
26. **Delivery Attempt History**

---

# 54. THE MOST IMPORTANT SCREEN HIERARCHY

If you want to keep the PDA app lean, the designer **doesn't necessarily need 26 completely separate full-page designs**.

Many can be:

* Bottom sheets
* Modals
* Step flows
* States of the same screen

So the actual design workload can be consolidated into roughly:

### 8–12 major screens

with multiple states and modals.

For example:

**Delivery Details** can transition into:

> Start → Active → Complete

rather than creating three unrelated screens.

Likewise:

**Failed Delivery** can be a guided bottom-sheet/step flow.

This will make the PDA app much cleaner and faster for field use.

---

# 55. Monnify Dynamic Virtual Account Generation for Direct Transfers

When a delivery is completed and payment is due on delivery (POD), the customer may choose either **Cash** or **Direct Bank Transfer**:

### Direct Bank Transfer Flow via Monnify
1. **Dynamic Virtual Account Creation**:
   - The rider selects "Direct Transfer" as the payment method.
   - The app instantly retrieves a **dynamic virtual bank account number (powered by Monnify)** generated uniquely for that specific order (`NX-XXXXXX`).
   - The screen clearly displays:
     - **Bank Name**: e.g., Wema Bank / Moniepoint / Providus
     - **Account Name**: `NovaExpress - [Order #]`
     - **Account Number**: 10-digit virtual account
     - **Exact Amount Payable**: `₦XX,XXX.00`
     - **Payment Status**: *Listening for instant transfer webhook...*
2. **Instant Webhook Reconciliation**:
   - As soon as the customer completes the bank transfer, Monnify emits a webhook event to NovaExpress backend.
   - The rider's app automatically detects successful payment confirmation and marks the POD collection as complete.
3. **Remittance Exemption & Rider Compensation**:
   - Because the funds are received directly in NovaExpress's company bank account, the rider holds **₦0.00 cash** for this order and is exempt from remitting cash.
   - The delivery commission and transport allowance earned by the rider for this delivery are credited to the rider's **"My Balance" (Rider Balance)** ledger.
