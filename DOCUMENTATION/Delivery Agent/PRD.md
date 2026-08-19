# NovaExpress Logistics

# Product Requirements Document — PDA / Delivery Agent App

**Product:** NovaExpress Logistics
**Module:** PDA / Delivery Agent Mobile Application
**Version:** 1.0
**Market:** Nigeria
**Currency:** Nigerian Naira (₦)
**Primary Users:** PDAs and In-House Riders
**Platforms:** Android first; iOS/Web support may be considered later

---

# 1. Document Purpose

This PRD defines the complete requirements for the **NovaExpress PDA / Delivery Agent application**.

The application will be used by two categories of delivery personnel:

1. **PDA — Personal Distribution Agent**

   * Uses their own means of transportation.
   * May be commission-based, salary-based, or hybrid.
   * May carry distributed client inventory.
   * May receive commission and transport allowances according to their individual arrangement.

2. **In-House Rider**

   * Uses a NovaExpress-owned motorcycle/bike.
   * May be commission-based, salary-based, or hybrid.
   * May receive commission, fuel allowance, failed-delivery stipend, or other configured compensation.

The application must support both personnel types without requiring two separate applications.

---

# 2. Product Objective

The PDA/Delivery Agent app should allow delivery personnel to independently manage their complete field operation:

> **Receive → Pick Up → Deliver → Collect → Record Outcome → Return → Remit → Reconcile → Track Earnings**

The app must provide the agent with everything required to execute deliveries while giving NovaExpress accurate visibility into:

* Delivery status
* Package custody
* Distributed inventory
* POD collections
* Remittances
* Agent earnings
* Failed deliveries
* Returns
* Performance
* Agent accountability

---

# 3. Important Business Principle

The app must **not hardcode compensation or delivery charges**.

Current examples include:

* Successful delivery charge: **₦5,000**
* Failed delivery charge: **₦1,500**
* PDA successful commission: **₦1,000**
* PDA successful transport: **₦1,500**
* PDA failed-delivery allowance: **₦500**
* Rider successful commission: **₦500**
* Rider fuel allowance: **₦800**
* Rider failed-delivery stipend: **₦500**

These are **current business arrangements only**.

Administrators must be able to change them.

The PDA app simply displays the rates applicable to the specific agent, client, delivery, and effective date.

---

# 4. Users

## 4.1 PDA

A Personal Distribution Agent who:

* Receives delivery assignments.
* Uses their own transport.
* May carry distributed inventory.
* Delivers packages/products.
* Collects POD payments.
* Remits collected money.
* Earns commissions/allowances according to their compensation arrangement.

---

## 4.2 In-House Rider

An internal NovaExpress delivery rider who:

* Uses a NovaExpress motorcycle/bike.
* Receives delivery assignments.
* Delivers packages/products.
* Collects POD payments.
* Remits collections.
* Accumulates commissions/allowances or receives salary depending on arrangement.

---

# 5. Compensation Models

Every delivery agent must have a compensation profile.

Supported models:

### Commission-Based

Agent earns based on delivery activities.

### Salary-Based

Agent receives a fixed salary.

### Hybrid

Agent receives salary plus commissions/allowances.

The app must dynamically reflect the agent's arrangement.

For example, a salary-based agent should not see:

> "Commission ₦1,000"

if their arrangement does not include commission.

---

# 6. Compensation Settlement Frequency

Compensation may be settled:

* Per delivery
* During remittance
* Daily
* Weekly
* Monthly
* Other configured arrangement

The app must distinguish between:

### Earned

Money the agent has accrued.

### Settled

Money already paid or deducted/settled.

### Outstanding

Money still owed to the agent.

---

# 7. Delivery Models

The PDA app must support four scenarios.

### Scenario A

**Client Package + Non-POD**

Client provides a package.

Customer does not pay.

---

### Scenario B

**Client Package + POD**

Client provides a package.

Customer pays on delivery.

Agent collects the money.

---

### Scenario C

**Distributed Inventory + Non-POD**

Client provides products to NovaExpress.

NovaExpress distributes the inventory.

Customer does not pay on delivery.

---

### Scenario D

**Distributed Inventory + POD**

Client provides products.

NovaExpress stores/distributes them.

Customer pays upon delivery.

Agent collects the money.

---

# 8. Core Navigation

The recommended primary navigation is:

### Home

Operational dashboard.

### Deliveries

Assigned deliveries.

### Inventory

Agent's assigned inventory.

### Remittance

POD collection and money remittance.

### More

Earnings, performance, history, profile, support and settings.

---

# 9. Authentication

The agent must be able to securely log in.

Supported authentication may include:

* Phone number + password
* Username + password
* OTP where configured

The authentication system must identify:

* Agent
* Agent type
* Assigned HQ
* Assigned DC
* Account status
* Compensation arrangement

---

# 10. Account Status

Agent accounts may have:

* Active
* Suspended
* Pending Activation
* Deactivated

A suspended/deactivated agent must not receive new delivery assignments.

The app should clearly communicate the status.

---

# 11. HOME SCREEN

The Home screen is the agent's operational command center.

It should display:

### Greeting

Example:

> Good morning, John 👋

**PDA • Wuse DC**

---

## Today's Delivery Summary

Display:

**Assigned**

12

**Successful**

8

**Failed**

2

**Pending**

2

---

# 12. Today's Collection

For agents handling POD:

### Today's POD Collection

**₦185,000**

Collected:

₦185,000

Remitted:

₦160,000

Pending:

₦25,000

CTA:

**Remit Money**

For non-POD-only agents, this section may be hidden or replaced with a relevant operational card.

---

# 13. Today's Earnings

Display:

### Today's Earnings

**₦20,000**

Breakdown:

Commission:

₦8,000

Transport/Fuel:

₦12,000

The exact categories shown depend on the agent's compensation arrangement.

CTA:

**View Earnings**

---

# 14. Active Delivery

The Home screen should display the next active delivery.

Example:

**#NX-102938**

Emmanuel Okoro

Gwarinpa, Abuja

POD:

**₦25,000**

Status:

**Out for Delivery**

CTA:

**Continue Delivery**

---

# 15. Quick Actions

Home should provide quick actions:

* Deliveries
* Remit
* Inventory
* Earnings
* Call Support

The exact actions should be permission/context dependent.

---

# 16. DELIVERY LIST

The Deliveries screen is the primary operational screen.

Tabs:

### All

### Pending

### In Progress

### Delivered

### Failed

### Returned

---

# 17. Delivery Card

Each delivery should display:

**Order/Delivery ID**

Customer name

Phone number

Location

Fulfillment type

Payment type

Amount to collect if POD

Delivery status

Example:

> **NX-102938**
> Emmanuel Okoro
> Gwarinpa, Abuja
> Distributed Inventory • POD
> Collect ₦25,000
> **Out for Delivery**

CTA:

**View Delivery**

---

# 18. Delivery Details

The delivery details screen must contain:

### Customer Information

* Customer name
* Phone
* Alternate phone if available
* Address
* State
* LGA
* Area
* Landmark
* Delivery instructions

---

# 19. Customer Contact Actions

The agent should be able to:

* Call customer
* Send SMS
* Open available messaging option
* Copy phone number

All communication actions should be logged where appropriate.

---

# 20. Navigation

The app should provide:

### Navigate

This should open the device's available navigation application.

The system should pass the delivery location/address.

---

# 21. Order Information

The delivery details page must display:

### Fulfillment Type

One of:

* Client Package
* Distributed Inventory

### Payment Type

One of:

* Non-POD
* POD

---

# 22. Client Package Display

For client-package deliveries, show:

### Package

Package ID

Description

Quantity

Special instructions

POD amount if applicable

The PDA does not treat the package as NovaExpress-owned inventory.

---

# 23. Distributed Inventory Display

For inventory-based deliveries, show:

### Products

Product name

Quantity

Free quantity where applicable

Total physical quantity

Example:

**Grazer Herbal Tea**

Paid: 5

Free: 1

Total: **6 units**

---

# 24. Promotional Products

The agent must know exactly what physical products to deliver.

Example:

> Buy 5 Grazer Herbal Tea, get 1 free.

The PDA sees:

**Paid:** 5

**Free:** 1

**Deliver:** 6

The system must prevent the agent from incorrectly delivering only 5 units.

---

# 25. Starting a Delivery

When the PDA taps:

### Start Delivery

The system should:

1. Verify that the delivery is assigned to the agent.
2. Change status to **Out for Delivery**.
3. Record timestamp.
4. Record agent.
5. Record relevant location information if enabled.
6. Start the delivery attempt.

The system must prevent two agents from simultaneously claiming the same delivery.

---

# 26. Delivery Statuses

Recommended statuses:

* Assigned
* Accepted
* Picked Up
* Out for Delivery
* Delivered
* Failed
* Awaiting Return
* Returned
* Return Verified
* Cancelled

---

# 27. Successful Delivery

When the customer receives the order, the PDA selects:

### Complete Delivery

The system should require confirmation of the physical delivery.

For inventory:

The PDA confirms:

* Product
* Quantity
* Condition where applicable

---

# 28. POD COLLECTION

If the delivery is POD, the app must display:

# Amount to Collect

**₦25,000**

The agent enters:

### Amount Collected

The system should validate the amount.

If:

Expected = ₦25,000

Actual = ₦20,000

the system must flag a:

### Collection Variance

The agent must provide a reason where allowed.

---

# 29. Payment Methods

POD collection should support:

* Cash
* Bank Transfer
* POS
* Other approved methods

The system should capture the relevant reference where applicable.

---

# 30. Proof of Payment

Where applicable, the agent should be able to:

* Enter transaction reference
* Upload payment receipt
* Capture relevant proof

For cash, the system should identify it as cash collection.

---

# 31. Proof of Delivery

Depending on client configuration, successful delivery may require:

* OTP
* Customer signature
* Customer confirmation
* Photo
* Delivery timestamp
* GPS/location evidence

The required method must be configurable.

---

# 32. Successful Delivery Confirmation

Before completion, show a summary:

### Delivery Summary

Customer:

Emmanuel Okoro

Items:

2 Respira

Amount collected:

₦25,000

Payment:

Cash

Then:

### Confirm Delivery

After confirmation, the delivery becomes **Delivered**.

---

# 33. Earnings Generated by Delivery

After successful completion, the system calculates the agent's applicable compensation.

Example PDA:

Commission:

₦1,000

Transport:

₦1,500

Total:

# ₦2,500

This calculation comes from the agent's active compensation profile.

---

# 34. Agent Earnings Must Be Transparent

The app should explain:

> **Your earnings for this delivery**

Commission — ₦1,000

Transport — ₦1,500

Total — ₦2,500

The agent should not need to manually calculate their entitlement.

---

# 35. Failed Delivery

The agent must be able to select:

### Delivery Failed

The system then requires a failure reason.

Examples:

* Customer unavailable
* Customer phone switched off
* Wrong address
* Customer refused delivery
* Customer refused payment
* Customer requested reschedule
* Customer travelled
* Location inaccessible
* Security issue
* Other

---

# 36. Failed Delivery Evidence

Depending on business rules, the app may require:

* Note
* Photo
* Customer contact attempt
* Location
* Call attempt
* Other evidence

This protects NovaExpress and its clients from false delivery attempts.

---

# 37. Failed Delivery Charge

Where applicable, the system displays the applicable client charge.

Current NovaCare example:

**₦1,500**

But the app must obtain the actual amount from the backend.

It must never assume that every client pays ₦1,500.

---

# 38. Failed Delivery Agent Compensation

Example PDA:

Failed-delivery allowance:

**₦500**

The amount is determined by the agent's compensation profile.

The agent should see:

> **Failed delivery allowance: ₦500**

if applicable.

---

# 39. Reattempt

A failed delivery may be eligible for reattempt.

The app should show:

### Reattempt Delivery

if the operation allows it.

The new attempt must be separately recorded.

---

# 40. Return Requirement

If the delivery contains distributed inventory and the delivery fails, the app must instruct:

### Return Products to DC

The agent must see the products expected to be returned.

---

# 41. Return Inventory

Example:

### Return to DC

Respira — 2 units

Grazer Herbal Tea — 1 unit

The agent confirms the quantities physically returned.

---

# 42. Return Verification

The agent submits the return.

Status:

### Awaiting DC Verification

The stock should not automatically become available merely because the PDA tapped "Return."

The DC must physically verify it.

---

# 43. Inventory Module

The Inventory screen displays inventory currently assigned to the agent.

Example:

### Respira

42 units

### Grazer Herbal Tea

27 units

### Alpha Man

18 units

---

# 44. Inventory Summary

Show:

### Available

Products available for assignment/delivery.

### Reserved

Products allocated to pending deliveries.

### Out for Delivery

Products currently associated with active deliveries.

### Return Pending

Products awaiting DC verification.

### Damaged

Products flagged as damaged.

---

# 45. Inventory Details

For each product:

**Respira**

Available:

42

Reserved:

5

Out for delivery:

3

Return pending:

2

The PDA should be able to see the total custody position.

---

# 46. Inventory Movement History

Each PDA can see their inventory movements.

Example:

**+20 Respira**

Received from Wuse DC

17 Aug

---

**-2 Respira**

Delivered

Customer: Emmanuel

17 Aug

---

**+2 Respira**

Returned

Failed Delivery

16 Aug

---

# 47. Stock Receipt

When the DC issues stock to the PDA, the PDA should receive a notification.

Example:

> **Stock Transfer Received**

Wuse DC issued:

20 Respira

10 Grazer Herbal Tea

CTA:

**Review & Accept**

The PDA confirms the physical quantity.

---

# 48. Stock Discrepancy

If the PDA receives:

Expected:

20

Physical:

18

They should be able to report:

### Quantity Discrepancy

Expected: 20

Received: 18

Difference: -2

The stock transfer should become:

**Disputed / Pending Resolution**

rather than silently accepting the wrong quantity.

---

# 49. Remittance Module

The Remittance section is a core feature.

It must allow the PDA to:

* View collections
* View deductions
* Calculate expected remittance
* Submit remittance
* Upload proof
* Track approval
* View history
* Resolve discrepancies

---

# 50. Remittance Summary

Example:

### Today's Collection

₦185,000

### Approved Deductions

₦25,000

### Expected Remittance

# ₦160,000

This should be system-calculated.

---

# 51. Remittance Breakdown

Show each component.

### Collections

Order #001 — ₦20,000

Order #002 — ₦35,000

Order #003 — ₦30,000

---

### Approved Agent Deductions

Commission — ₦8,000

Transport — ₦17,000

---

### Total Collection

₦85,000

### Total Deductions

₦25,000

### Amount to Remit

# ₦60,000

---

# 52. Important Remittance Rule

The system must know whether the agent's compensation arrangement permits deductions from POD collections.

For example:

### PDA

May deduct approved commission/transport according to arrangement.

### In-House Rider

Normally remits the full collection.

Their earnings remain accrued and payable separately.

This behavior must be configuration-driven.

---

# 53. Remittance Payment Methods

Supported methods:

* Cash
* Bank transfer
* POS
* Other configured methods

---

# 54. POS Remittance

For a POS transaction:

Agent enters:

Amount:

₦5,000

POS fee:

₦100

Reference:

ABC123456

Uploads receipt where required.

The system records the POS fee independently.

---

# 55. POS Fee Approval

If approval is required:

Status:

**Pending Approval**

An administrator/DC finance officer can:

* Approve
* Reject
* Request clarification

Only approved POS fees should be reflected in final reconciliation.

---

# 56. Remittance Submission

Before submission, show:

### Remittance Summary

Collection:

₦185,000

Deductions:

₦25,000

POS fee:

₦100

Amount remitted:

₦160,000

Payment method:

Bank Transfer

Reference:

XXXXXX

Then:

### Submit Remittance

---

# 57. Remittance Status

The agent can track:

### Pending

Not yet submitted.

### Submitted

Agent submitted.

### Under Review

DC/finance reviewing.

### Approved

Fully accepted.

### Partially Approved

Only part accepted.

### Rejected

Rejected with reason.

### Disputed

Financial discrepancy requires investigation.

---

# 58. Remittance Variance

If:

Expected:

₦20,000

Actual:

₦18,000

Variance:

**₦2,000**

The system must clearly show:

### Outstanding Variance

₦2,000

The agent should be able to provide an explanation.

---

# 59. Earnings Screen

The Earnings module provides the agent with a transparent view of compensation.

Filters:

* Today
* This week
* This month
* Custom date

---

# 60. Earnings Summary

Example:

### August 2026

Successful deliveries:

182

Failed deliveries:

14

Commission:

₦182,000

Transport:

₦273,000

Failed allowances:

₦7,000

Total accrued:

# ₦462,000

---

# 61. Earnings Settlement

Display:

### Total Earned

₦462,000

### Already Settled

₦400,000

### Outstanding

# ₦62,000

This is especially important for monthly commission-based riders.

---

# 62. Salary-Based Agent View

For salary-based personnel, the app should show:

### Monthly Salary

₦150,000

### Current Period

August 2026

### Status

Pending / Partially Paid / Paid

Commission sections should only appear if applicable.

---

# 63. Hybrid Agent View

Example:

### Monthly Salary

₦100,000

### Commission

₦35,000

### Transport

₦50,000

### Total Earnings

₦185,000

---

# 64. Performance Screen

The agent should be able to see their operational performance.

### Delivery Success Rate

92.4%

### First-Attempt Success

87.6%

### Total Assigned

200

### Successful

182

### Failed

18

---

# 65. Performance History

A simple trend should show performance over:

* Day
* Week
* Month

The goal is to help agents understand their performance, not simply punish them.

---

# 66. Delivery History

Agents should be able to search past deliveries.

Filters:

* Date
* Status
* Client
* POD/Non-POD
* Product
* Customer
* Delivery ID

---

# 67. Remittance History

Show:

Date

Amount

Payment method

Status

Reference

Example:

> Aug 17 — ₦35,000 — Bank Transfer — Approved

---

# 68. Notifications

Notifications should include:

### Assignment

> New delivery assigned.

### Stock

> 20 units of Respira issued to you.

### Remittance

> Your ₦35,000 remittance was approved.

### Discrepancy

> Your remittance has a ₦2,000 variance.

### Return

> Your returned inventory has been verified.

### Earnings

> ₦25,000 commission payment recorded.

---

# 69. Profile

Profile should show:

### Personal Information

* Name
* Phone
* Email where applicable
* Profile photo

### Operational Information

* Agent ID
* Agent type
* HQ
* DC
* Status

### Delivery Arrangement

* Compensation type
* Settlement frequency

### Vehicle

For PDA:

Personal vehicle details.

For rider:

Assigned NovaExpress bike where applicable.

---

# 70. Support

The app should provide:

### Contact DC

Call/message assigned DC.

### Operations Support

Contact NovaExpress operations.

### Report a Problem

Submit:

* Delivery issue
* Customer issue
* Cash issue
* Inventory issue
* Vehicle issue
* App issue

---

# 71. Offline/Network Requirements

Because PDAs operate in the field, the app must be designed for Nigerian connectivity conditions.

The application should gracefully handle poor or intermittent internet.

The app should cache necessary information such as:

* Assigned deliveries
* Customer details
* Delivery addresses
* Assigned inventory
* Relevant delivery instructions

Where technically safe, field actions should queue for synchronization.

---

# 72. Offline Safety

Financial actions require particular caution.

The app must clearly indicate:

### Synced

or:

### Pending Sync

An agent must never assume that a POD collection/remittance is officially accepted simply because the action was recorded locally.

The server remains the source of truth.

---

# 73. Security

The PDA app must enforce:

* Secure authentication
* Session management
* Device/session controls
* Role-based access
* PIN/biometric unlock where appropriate
* Secure financial data
* No unauthorized access to other agents' information

---

# 74. Agent Cannot Modify Financial Rates

The PDA cannot change:

* Delivery charges
* Commission
* Transport rates
* Fuel rates
* Failed delivery charges
* Salary
* Client agreements

These values are controlled by authorized administrators.

---

# 75. Agent Cannot Modify Historical Earnings

Once an earning is generated, the PDA cannot modify it.

Corrections must happen through an authorized adjustment process.

---

# 76. Agent Cannot Silently Modify Inventory

Inventory quantities must be generated from:

* Stock receipt
* Delivery
* Return
* Adjustment
* Damage
* Approved transfer

Manual changes require authorization.

---

# 77. Agent Cannot Complete Another Agent's Delivery

A delivery assigned to Agent A cannot be completed by Agent B without an authorized reassignment.

The reassignment must be logged.

---

# 78. Agent Cannot Delete Transactions

Agents cannot delete:

* Deliveries
* Collections
* Remittances
* Inventory movements
* Earnings
* Returns

Corrections must create adjustment/reversal records.

---

# 79. Audit Requirements

The system must record:

* Who performed an action
* What action occurred
* When it happened
* Previous state
* New state
* Device/session where appropriate
* Reason for sensitive changes

---

# 80. Key Business Rules

### BR-001

Every delivery belongs to a client.

### BR-002

Every delivery has a fulfillment type.

### BR-003

Every delivery has a payment type.

### BR-004

POD deliveries require collection tracking.

### BR-005

POD collections require reconciliation.

### BR-006

Successful deliveries may generate client charges.

### BR-007

Failed deliveries may generate client charges according to the client's agreement.

### BR-008

Failed distributed-inventory deliveries require stock return.

### BR-009

Returned stock must be verified by the receiving DC.

### BR-010

Delivery personnel compensation is configuration-driven.

### BR-011

PDA and Rider compensation may differ.

### BR-012

Salary-based personnel may have no commission.

### BR-013

Commission-based personnel accumulate earnings.

### BR-014

Historical transactions retain the rate that was applied when the transaction occurred.

### BR-015

Agents cannot alter rates.

### BR-016

POS fees are separate financial transactions.

### BR-017

Remittances require verification.

### BR-018

Financial variances must be visible.

### BR-019

Inventory discrepancies require resolution.

### BR-020

Every important financial and inventory action must be auditable.

---

# 81. PDA/Rider App Screen Inventory

The first UI design phase should cover approximately **22 core screens**.

| #  | Screen               | Purpose                       |
| -- | -------------------- | ----------------------------- |
| 1  | Login                | Authenticate agent            |
| 2  | Home                 | Daily operational dashboard   |
| 3  | Deliveries           | View assignments              |
| 4  | Delivery Details     | View complete delivery        |
| 5  | Start Delivery       | Begin delivery                |
| 6  | POD Collection       | Record customer payment       |
| 7  | Successful Delivery  | Confirm completion            |
| 8  | Failed Delivery      | Report failed attempt         |
| 9  | Failure Reason       | Capture failure details       |
| 10 | Return Items         | Return inventory/package      |
| 11 | Inventory            | View assigned stock           |
| 12 | Inventory Details    | Product-level stock           |
| 13 | Inventory Movement   | Stock history                 |
| 14 | Remittance           | View money owed/remitted      |
| 15 | Remittance Breakdown | Calculate expected remittance |
| 16 | Submit Remittance    | Submit payment                |
| 17 | Remittance Details   | View transaction status       |
| 18 | Earnings             | View compensation             |
| 19 | Performance          | Delivery performance          |
| 20 | Notifications        | Operational alerts            |
| 21 | Profile              | Agent information             |
| 22 | More                 | Secondary functions/settings  |

Some of these should be implemented as **bottom sheets, dialogs, or multi-step flows rather than separate full pages**.

---

# 82. Primary PDA User Journey

The designer should use this as the main UX flow:

**Login**

↓

**Home**

↓

**New Delivery**

↓

**Delivery Details**

↓

**Start Delivery**

↓

**Navigate to Customer**

↓

**Confirm Customer**

↓

**Confirm Package/Product**

↓

### If POD

**Collect Payment**

↓

**Capture Payment Proof**

↓

### If Successful

**Proof of Delivery**

↓

**Complete Delivery**

↓

**Earnings Recorded**

↓

### If Failed

**Select Failure Reason**

↓

**Record Evidence**

↓

**Return Package/Product**

↓

**DC Verification**

↓

**Remittance**

↓

**Submit**

↓

**DC/Finance Verification**

↓

**Approved**

---

# 83. Design Principles

The PDA application should feel:

### Simple

The agent is working in the field and should not navigate through complicated ERP screens.

### Fast

Most common actions should take very few taps.

### Clear

Money and delivery status must never be ambiguous.

### Nigerian

The interface should reflect Nigerian delivery realities:

* ₦ currency
* POD
* Cash
* POS
* Nigerian addresses
* LGAs
* Landmarks
* Phone-based customer communication
* Motorcycle delivery

### Accountable

Every collection, delivery, stock movement and remittance should have a clear trail.

---

# 84. Most Important UI Principle

The app should always answer these five questions immediately:

### 1. What do I need to deliver?

**Deliveries**

### 2. Where am I taking it?

**Customer + Address + Navigation**

### 3. How much should I collect?

**POD Amount**

### 4. How much do I need to remit?

**Remittance**

### 5. How much have I earned?

**Earnings**

If the PDA can answer those five questions from the app without confusion, the core UX is working.

---

# 85. Final Product Definition

The NovaExpress PDA/Delivery Agent app is **not simply a delivery tracking application**.

It is a field-operational application that connects:

**Delivery Assignment**

→ **Package/Inventory Custody**

→ **Customer Delivery**

→ **POD Collection**

→ **Failed Delivery/Return**

→ **Remittance**

→ **Agent Compensation**

→ **Performance**

while continuously synchronizing with the NovaExpress **DC, HQ, Operations and Finance systems**.

The most important architectural rule is that **delivery pricing and agent compensation remain configurable**. A PDA's current ₦1,000 commission, ₦1,500 transport allowance, or any other amount must never be treated as permanent business logic. The same applies to the current ₦5,000 successful-delivery and ₦1,500 failed-delivery client charges.

This allows NovaExpress to change client agreements, change agent arrangements, introduce new products, add HQs/DCs, move an agent from commission to salary, or create special compensation arrangements **without redesigning the PDA application or rewriting the core system.**
