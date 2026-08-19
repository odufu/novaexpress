# NovaExpress Logistics — Master Product Requirements Document (PRD)

**Document Type:** Master System PRD
**Product:** NovaExpress Logistics Management System
**Market:** Nigeria
**Currency:** Nigerian Naira (₦)
**Current Products:** Grazer Herbal Tea, Respira, Alpha Man
**Status:** Foundational / Pre-Development
**Purpose:** Establish the complete business, operational, inventory, delivery, commission, cash, and settlement logic before UI and module-specific PRDs are finalized.

---

# 1. Product Overview

NovaExpress is a Nigerian logistics and distribution company that operates a network of:

* Headquarters
* Distribution Centers (DCs)
* Personal Distribution Agents (PDAs)
* In-house Riders
* Clients
* Customers

The system will manage both:

1. **Traditional package delivery**, where a client gives NovaExpress a physical package to deliver.
2. **Distributed inventory fulfillment**, where a client supplies products in bulk and NovaExpress stores and distributes those products through its logistics network.

Both models may operate as:

* **Non-Pay on Delivery**
* **Pay on Delivery (POD)**

The system must also manage:

* Inventory
* Package custody
* Orders
* Deliveries
* Delivery personnel
* POD collections
* Remittances
* Agent commissions
* Transport/fuel allowances
* Salaries
* Failed deliveries
* Returns
* Client charges
* Client settlements
* Performance
* Financial reconciliation
* Multi-HQ operations

---

# 2. Core Business Principle

The system must **not** treat POD as an order type.

Instead, every order has two independent dimensions:

### Fulfillment Type

* Client Package
* Distributed Inventory

### Payment Type

* Non-POD
* POD

This produces four valid operational combinations:

| Fulfillment           | Payment |
| --------------------- | ------- |
| Client Package        | Non-POD |
| Client Package        | POD     |
| Distributed Inventory | Non-POD |
| Distributed Inventory | POD     |

This structure must be used throughout the system.

---

# 3. Business Scenario 1 — Client Package, Non-POD

A client gives NovaExpress a package that has already been prepared.

Example:

> Client gives NovaExpress a package to deliver to John in Lagos.

The customer does not need to pay anything.

### Workflow

Client → NovaExpress → DC → Delivery Personnel → Customer

The system tracks:

* Package
* Client
* Customer
* Delivery
* Custody
* Delivery personnel
* Delivery status
* Proof of delivery

No product inventory transaction is required.

No POD collection is required.

---

# 4. Business Scenario 2 — Client Package, POD

A client gives NovaExpress a package to deliver.

The customer must pay upon delivery.

Example:

> Package value/collection amount = ₦50,000.

The delivery personnel collects the money.

### Workflow

Client → NovaExpress → DC → Delivery Personnel → Customer

Financial workflow:

Customer → Delivery Personnel → NovaExpress → Client

The system must separately track:

* Expected collection
* Actual collection
* Delivery fee
* Delivery personnel earnings
* Remittance
* Client settlement

The package itself is tracked through **custody**, not product inventory.

---

# 5. Business Scenario 3 — Distributed Inventory, Non-POD

A client supplies products in bulk to NovaExpress.

Example:

NovaCare supplies:

> 10,000 units of Respira.

NovaExpress distributes the products through its network.

A customer orders:

> 2 Respira

and payment has already been made.

NovaExpress fulfills the order using its managed inventory.

### Physical flow

Client → HQ → DC → PDA/Rider → Customer

Inventory must be deducted as the product moves through the system.

---

# 6. Business Scenario 4 — Distributed Inventory, POD

This is one of NovaExpress's major operating models.

Example:

NovaCare supplies:

> 10,000 Respira

Customer orders:

> 2 Respira

Customer pays upon delivery.

NovaExpress delivers the product and collects the customer's money.

Under the current NovaCare commercial arrangement:

* Successful delivery generates a **₦5,000 NovaExpress delivery charge**
* NovaExpress retains its agreed delivery charge
* The remaining customer collection is payable to NovaCare
* NovaCare does not pay NovaExpress upfront for successful POD fulfillment
* Failed delivery generates a **₦1,500 charge to NovaCare**
* The product is returned to stock after a failed delivery

All these amounts must be configurable.

---

# 7. Critical Rule — No Financial Rate Is Hardcoded

The current figures are **business defaults**, not permanent system constants.

For example:

### Current successful delivery charge

₦5,000

### Current failed delivery charge

₦1,500

These may later become:

₦4,000

₦6,000

₦7,500

etc.

The system must allow authorized administrators to change rates.

---

# 8. Client-Specific Commercial Agreements

Different clients may have different agreements.

Therefore the system must support **Client Commercial Agreements**.

Example:

### NovaCare

Successful delivery:

₦5,000

Failed delivery:

₦1,500

Another client could have:

Successful:

₦4,000

Failed:

₦1,000

Therefore:

> **Delivery pricing must be configurable globally and overrideable per client.**

---

# 9. Rate Hierarchy

The system should support a hierarchy of pricing rules:

### Level 1 — System Default

General NovaExpress rate.

### Level 2 — Client Rate

Specific rate negotiated with a client.

### Level 3 — Special Arrangement

Specific temporary/custom arrangement.

The system must retain which rate was actually applied to each transaction.

Changing a rate in the future must **not alter historical transactions**.

---

# 10. Delivery Personnel

NovaExpress has two types of delivery personnel.

## Type 1 — PDA

Personal Distribution Agent.

The PDA uses **their own means of transportation**.

They may use:

* Motorcycle
* Car
* Other approved means

NovaExpress does not provide their primary delivery vehicle.

---

## Type 2 — In-House Rider

An employee/contracted rider who uses a **NovaExpress-owned motorcycle/bike**.

The company is responsible for providing the operational vehicle.

The system must therefore distinguish between:

**PDA**

and:

**In-House Rider**

throughout reporting and compensation.

---

# 11. Compensation Type

Both PDAs and In-house Riders may have different payment arrangements.

The system must support:

### Commission-Based

Compensation is calculated based on completed delivery activities.

### Salary-Based

The person receives a fixed salary.

### Hybrid

Fixed salary plus commissions/allowances.

Although the current operation may primarily use commission or salary arrangements, the architecture should support hybrid arrangements.

---

# 12. Compensation Must Be Individually Configurable

The system must never assume:

> Every PDA earns ₦1,000.

or:

> Every rider earns ₦500.

Instead, each delivery personnel has a:

# Compensation Profile

Containing:

* Payment model
* Successful delivery commission
* Failed delivery allowance
* Transport allowance
* Fuel allowance
* Other allowances
* Salary
* Settlement frequency
* Effective date
* Expiry date where applicable

---

# 13. Current PDA Compensation Example

Current default arrangement:

### Successful delivery

Commission:

**₦1,000**

Transport:

**₦1,500**

Total entitlement:

**₦2,500**

### Failed delivery

Transport/failed-delivery allowance:

**₦500**

These are configurable.

---

# 14. PDA Remittance

PDAs may deduct their approved earnings from the cash they collected before remitting.

Example:

Customer pays:

**₦20,000**

PDA entitlement:

Commission:

₦1,000

Transport:

₦1,500

Total:

₦2,500

PDA remits:

**₦17,500**

The system records:

| Transaction           |  Amount |
| --------------------- | ------: |
| Customer Collection   | ₦20,000 |
| PDA Commission        |  ₦1,000 |
| PDA Transport         |  ₦1,500 |
| PDA Total Entitlement |  ₦2,500 |
| Actual Remittance     | ₦17,500 |

The deduction must be transparent.

---

# 15. In-House Rider Compensation

Current default arrangement:

### Successful delivery

Commission:

**₦500**

### Fuel per trip

**₦800**

### Failed delivery

Stipend:

**₦500**

However, these are also configurable.

---

# 16. In-House Rider Remittance

Unlike the PDA arrangement, the rider normally **remits the full amount collected**.

Example:

Customer pays:

**₦20,000**

Rider remits:

**₦20,000**

The rider's:

* ₦500 commission
* ₦800 fuel allowance

are recorded as **earnings/accruals**.

They are not automatically deducted from the remittance.

---

# 17. Rider Monthly Earnings

For commission-based riders, the system accumulates earnings throughout the month.

Example:

100 successful deliveries:

Commission:

100 × ₦500 = **₦50,000**

Fuel:

100 × ₦800 = **₦80,000**

Total accrued:

**₦130,000**

The system shows:

**Accrued: ₦130,000**

**Paid: ₦0**

**Outstanding: ₦130,000**

At month-end, the company pays the rider.

---

# 18. Salary-Based Personnel

A delivery person can instead be salary-based.

Example:

Monthly salary:

**₦150,000**

The system must record:

* Salary amount
* Salary frequency
* Effective date
* Payment status
* Outstanding salary
* Payment history

The system should still track delivery performance even when the person is salary-based.

---

# 19. Hybrid Compensation

The system should support:

> Salary + Commission

Example:

Monthly salary:

₦100,000

Successful delivery commission:

₦300

Fuel allowance:

₦500

This allows future operational arrangements without architectural changes.

---

# 20. Delivery Pricing vs Personnel Compensation

These must remain completely separate.

For example:

### Client pays NovaExpress

₦5,000 delivery charge.

### PDA receives

₦1,000 commission.

### PDA receives

₦1,500 transport allowance.

These are three different financial records.

The system must never treat:

> ₦5,000 = PDA earnings.

---

# 21. Successful Delivery Financial Event

For every successful delivery, the system should calculate:

### Client Delivery Charge

Example:

₦5,000

### Delivery Personnel Compensation

Example PDA:

₦1,000 commission

₦1,500 transport

### Customer Collection

Whatever the order requires.

### Client Settlement

Amount payable to the client.

---

# 22. Failed Delivery Financial Event

A failed delivery is also a billable operational event where applicable.

Current NovaCare arrangement:

### Client charge

₦1,500

### PDA failed-delivery allowance

₦500

### Product

Returned to inventory.

Again, all values must be configurable.

---

# 23. Failed Delivery Is Not Automatically Cancellation

A failed delivery should create a structured event.

The system records:

* Attempt number
* Date/time
* Agent
* Failure reason
* Customer contact attempt
* Client charge
* Agent allowance
* Return requirement
* Return status

---

# 24. Failed Delivery Reasons

The system should provide predefined Nigerian operational reasons such as:

* Customer unavailable
* Customer refused package
* Customer refused payment
* Wrong phone number
* Phone switched off
* Wrong address
* Incomplete address
* Customer requested reschedule
* Customer travelled
* Location inaccessible
* Security/access issue
* Customer cannot afford POD amount
* Other

Admin should be able to add/edit reasons.

---

# 25. Product Return After Failed Delivery

For distributed inventory:

Successful:

**DC → Agent → Customer**

Failed:

**DC → Agent → Customer attempt → Agent → DC**

The returned stock must be verified.

Possible return conditions:

* Good
* Damaged
* Opened
* Missing
* Partially returned

Only verified good units should automatically return to available inventory.

---

# 26. Package Return

For client packages, a failed delivery creates a **package return/custody event**.

It does not automatically create an inventory transaction.

Example:

Customer unavailable.

Package:

Customer → PDA → DC

Status:

**Returned to DC**

---

# 27. Inventory Ownership

For distributed inventory:

The product belongs commercially to the client.

NovaExpress holds it as a logistics custodian.

Example:

**Respira**

Owner:

NovaCare

Location:

Wuse DC

Quantity:

500

The system must know:

> Who owns the inventory?

> Where is the inventory?

> Who currently has custody?

---

# 28. Inventory Locations

Inventory can exist at:

* HQ
* Distribution Center
* PDA
* Transit
* Returns
* Damaged/Quarantine

Every movement must be recorded.

---

# 29. Inventory Movement

Examples:

### Receipt

Client → HQ

### Transfer

HQ → DC

### PDA Issue

DC → PDA

### Fulfillment

PDA → Customer

### Return

PDA → DC

### Damage

Available → Damaged

Every movement must have:

* Source
* Destination
* Product
* Quantity
* Date/time
* User
* Reason
* Reference

---

# 30. Client Package Custody

Packages have a different movement model.

Example:

Client → HQ → DC → PDA → Customer

The system records **custody**, not inventory.

This distinction must remain throughout the application.

---

# 31. Orders

Every order should contain:

### Order Information

* Order ID
* Client
* External reference
* Creation date
* Source
* Fulfillment type
* Payment type

### Customer

* Name
* Phone
* Address
* State
* LGA
* Landmark

### Items

* Product/package
* Quantity
* Paid quantity
* Free quantity
* Physical quantity

### Financial

* Expected collection
* Delivery charge
* Client charge
* Discounts
* Adjustments

---

# 32. Promotions and Free Products

The system must support promotions such as:

> Buy 5 Grazer Herbal Tea, get 1 free.

The order must record:

**Paid Quantity:** 5

**Free Quantity:** 1

**Physical Quantity:** 6

Inventory must deduct:

**6**

not 5.

This is mandatory for accurate stock accountability.

---

# 33. Current Products

The current distributed/POD product catalog includes:

* Grazer Herbal Tea
* Respira
* Alpha Man

The architecture must support adding more products later.

All Nigerian monetary values must be represented in:

# Nigerian Naira (₦)

---

# 34. Delivery

Every order creates or is associated with a delivery operation.

Delivery contains:

* Order
* DC
* Delivery personnel
* Assignment
* Pickup
* Delivery destination
* Delivery attempts
* Status
* Proof of delivery
* Collection
* Return

---

# 35. Delivery Lifecycle

Recommended lifecycle:

**Created**

→ **Assigned to HQ/DC**

→ **Assigned to Delivery Personnel**

→ **Ready for Pickup**

→ **Picked Up**

→ **Out for Delivery**

→ **Delivered**

or:

**Delivery Failed**

→ **Reattempt**

or:

**Returned**

---

# 36. Proof of Delivery

Successful deliveries should support:

* Customer name
* Signature where applicable
* OTP
* Photo where required
* Timestamp
* GPS/location evidence where available
* Delivery personnel identity

The exact proof method can be configured by operation/client.

---

# 37. POD

POD means:

> Pay on Delivery.

For POD orders, the system must store:

### Expected Amount

What the agent should collect.

### Collected Amount

What was actually collected.

### Remitted Amount

What was handed back to NovaExpress.

### Variance

Expected vs actual/remitted.

---

# 38. POD Reconciliation

Example:

Expected:

₦20,000

Collected:

₦20,000

Agent entitlement:

₦2,500

Remitted:

₦17,500

System must be able to reconcile the transaction and show why the remittance is lower than collection.

---

# 39. In-House Rider POD

Expected:

₦20,000

Collected:

₦20,000

Remitted:

₦20,000

Rider earnings:

₦1,300

Earnings remain payable to the rider according to their compensation schedule.

---

# 40. Remittance

Remittance is a formal financial transaction.

Statuses:

* Pending
* Submitted
* Under Review
* Approved
* Partially Approved
* Rejected
* Disputed

A remittance must contain:

* Agent
* Delivery/order references
* Expected amount
* Collected amount
* Approved deductions
* POS/bank charges
* Actual remitted amount
* Payment method
* Transaction reference
* Reviewer
* Date
* Notes

---

# 41. POS Fees

Agents may use a POS agent to transfer/remit cash.

Example:

Remittance:

₦5,000

POS fee:

₦100

The POS fee must be recorded separately.

It must not be mixed with:

* Agent commission
* Transport
* Delivery charge

The system should allow administrators to define who bears the POS fee.

---

# 42. POS Fee Approval

POS fees may require verification.

Status:

**Pending Approval**

→ **Approved**

or:

→ **Rejected**

Only approved fees should affect the final financial reconciliation.

---

# 43. Agent Earnings Ledger

Every delivery can create one or more earnings entries.

Example:

### PDA

Successful delivery:

Commission ₦1,000

Transport ₦1,500

### Rider

Successful:

Commission ₦500

Fuel ₦800

The system maintains cumulative earnings.

---

# 44. Earnings Status

Each earning should have:

* Accrued
* Approved
* Deducted from Remittance
* Payable
* Paid
* Reversed/Adjusted

This makes salary/commission accounting auditable.

---

# 45. Delivery Personnel Performance

The system must calculate performance independently of compensation type.

For each PDA/Rider:

### Total Assigned

### Total Attempted

### Successful

### Failed

### Success Rate

### First-Attempt Success Rate

### Average Delivery Attempts

### POD Collection Accuracy

### Outstanding Remittance

This allows management to judge performance fairly.

---

# 46. Delivery Success Rate

Formula:

**Successful Deliveries ÷ Total Delivery Attempts × 100**

Example:

90 successful

10 failed

Total:

100

Success rate:

**90%**

The system should clearly distinguish this from:

> Orders assigned but never attempted.

---

# 47. Personnel Dashboard

Each delivery person should see:

### Today's Work

Assigned

Picked up

Out for delivery

Delivered

Failed

Returned

### Money

Collected

Remitted

Outstanding

### Earnings

Commission

Transport/Fuel

Total accrued

Total paid

Outstanding

### Performance

Success rate

First-attempt success

---

# 48. Admin Personnel Dashboard

Management should see:

### PDA/Rider

* Deliveries
* Success rate
* Failed deliveries
* Collections
* Remittances
* Outstanding cash
* Earnings
* Salary
* Performance

Filters:

* HQ
* DC
* Personnel type
* Compensation type
* Date
* Client

---

# 49. Headquarters

NovaExpress can have multiple HQs.

The system must therefore support:

**HQ 1 — Abuja**

**HQ 2 — Lagos**

etc.

Each HQ manages its own operational network.

---

# 50. Distribution Centers

Each DC belongs to an HQ.

DC manages:

* Inventory
* Packages
* Orders
* Delivery assignments
* PDAs
* Riders
* Returns
* Remittances
* Local reconciliation

---

# 51. General Operations Unit

The General Operations Unit has cross-HQ visibility.

It can:

* Create/manage HQs
* Monitor all HQs
* Monitor all DCs
* Monitor inventory
* Monitor deliveries
* Monitor agents
* Monitor riders
* Configure rates
* Monitor client settlements
* Review performance
* Manage system-wide policies

---

# 52. Financial Architecture

The system should conceptually maintain separate ledgers.

## Order Ledger

What was ordered.

## Physical Ledger

Where products/packages are.

## Delivery Ledger

What happened during delivery.

## Cash Ledger

What money was collected/remitted.

## Earnings Ledger

What agents/riders earned.

## Settlement Ledger

What clients and personnel are owed/paid.

---

# 53. Financial Transaction Categories

The system should support at least:

### Revenue

* Successful delivery charge
* Failed delivery charge
* Other client charges

### Customer Cash

* POD collection

### Agent Costs

* PDA commission
* PDA transport
* PDA failed allowance
* Rider commission
* Rider fuel
* Rider failed stipend

### Payroll

* Salary
* Salary adjustments

### Other Expenses

* POS fees
* Approved operational expenses

### Client Settlement

* Amount payable
* Amount settled
* Adjustments

---

# 54. Historical Rate Protection

This is a critical requirement.

Suppose:

August rate:

**₦5,000**

September:

**₦6,000**

An August order must continue showing:

**₦5,000**

even after the rate changes.

Therefore every transaction must store the **actual rate applied at transaction time**.

---

# 55. Effective Dates

Rates must support:

* Effective from
* Effective until
* Status
* Created by
* Approved by

This gives the business control over future rate changes.

---

# 56. Approval Controls

Sensitive changes should require authorization.

Examples:

* Delivery rates
* Client agreements
* Personnel compensation
* Salary
* Manual financial adjustments
* Remittance approval
* POS fee approval
* Inventory adjustments

The system should record:

**Who changed it**

**What changed**

**When**

**Previous value**

**New value**

---

# 57. Audit Trail

Every important financial/operational action must be auditable.

Example:

> Admin John changed PDA commission from ₦1,000 to ₦1,200.

The system records:

* User
* Date/time
* Previous rate
* New rate
* Effective date
* Reason
* Approval

---

# 58. Client Settlement

For distributed POD:

Customer pays:

**₦20,000**

Client agreement:

Delivery charge:

**₦5,000**

Client payable:

**₦15,000**

The settlement system should show:

### Gross Customer Collection

₦20,000

### NovaExpress Delivery Revenue

₦5,000

### Adjustments

₦0

### Client Payable

₦15,000

### Settled

₦15,000

### Outstanding

₦0

---

# 59. Client Settlement Must Support Adjustments

Possible adjustments:

* Failed delivery charge
* Approved refund
* Dispute
* Damaged item
* Missing product
* Pricing correction
* Other approved adjustment

Every adjustment must have a reason and audit trail.

---

# 60. NovaExpress Profitability

Eventually management should be able to calculate:

### Delivery Revenue

minus:

### Agent Commission

### Transport/Fuel

### Failed Delivery Costs

### POS/Transaction Costs

### Other Operational Costs

=

### Gross Operational Contribution

This allows NovaExpress to determine which clients/routes/personnel are actually profitable.

---

# 61. Client-Level Profitability

Management should eventually see:

### NovaCare

Revenue:

₦X

Agent costs:

₦X

Transport:

₦X

Failed delivery costs:

₦X

Other costs:

₦X

Contribution:

₦X

This will become extremely useful as the company adds more clients.

---

# 62. Route/Location Profitability

The system should eventually allow:

* State
* LGA
* Area
* DC
* Route

analysis.

This can reveal:

> "This route has a high failure rate and high transport cost."

This can inform future pricing.

---

# 63. Nigerian Operational Requirements

The system should be designed specifically for Nigerian operations.

It must support:

* Nigerian phone numbers
* Nigerian states
* Nigerian LGAs
* Nigerian addresses
* Nigerian Naira
* Pay on Delivery
* POS-based cash transfers
* Bank transfers
* Cash remittance
* Motorbike delivery
* Local transport/fuel allowances
* Nigerian delivery geography

---

# 64. Nigerian Location Structure

Customer addresses should support:

**State**

→ **LGA**

→ **Area**

→ **Street**

→ **House/Building**

→ **Landmark**

→ **Additional instructions**

This is more practical than relying only on formal street addresses.

---

# 65. Core User Roles

The system should eventually support:

### General Operations Admin

Global operational control.

### HQ Admin/Manager

Manages an HQ.

### DC Manager

Manages a Distribution Center.

### Inventory Officer

Manages stock.

### PDA

External/personal delivery agent.

### In-House Rider

NovaExpress rider.

### Finance Officer

Handles reconciliation/settlement.

### Client

Views/submits client operations.

### Super Admin

System-level administration.

Permissions should be role-based and potentially location-based.

---

# 66. Core Modules

The complete system should eventually contain:

### 1. Dashboard

### 2. Clients

### 3. Orders

### 4. Packages

### 5. Products

### 6. Inventory

### 7. Stock Transfers

### 8. Deliveries

### 9. PDAs

### 10. In-House Riders

### 11. Remittances

### 12. POD Collections

### 13. Earnings & Commissions

### 14. Salaries

### 15. Client Settlements

### 16. Rate Cards

### 17. Promotions

### 18. Returns

### 19. Performance

### 20. Reports

### 21. Finance

### 22. Settings

### 23. Audit Logs

---

# 67. Important System Rule

**The UI must not expose unnecessary accounting complexity to delivery personnel.**

A PDA should primarily see:

> Deliveries
> Packages
> Stock
> Collections
> Remittance
> Earnings
> Performance

The DC sees more.

HQ sees more.

Finance sees more.

General Operations sees everything they are authorized to access.

---

# 68. PDA vs Rider Operational Difference

| Area           | PDA                             | In-House Rider           |
| -------------- | ------------------------------- | ------------------------ |
| Vehicle        | Own means                       | NovaExpress bike         |
| Commission     | Configurable                    | Configurable             |
| Salary         | Possible                        | Possible                 |
| Transport      | Configurable                    | Fuel-based               |
| POD Remittance | May deduct approved entitlement | Normally full remittance |
| Settlement     | Per arrangement                 | Often monthly            |
| Inventory      | May carry stock                 | May carry stock          |
| Packages       | Yes                             | Yes                      |
| Performance    | Yes                             | Yes                      |

---

# 69. Compensation Flexibility Requirement

Admin must be able to configure an individual as:

> PDA + Commission

or:

> PDA + Salary

or:

> PDA + Hybrid

and:

> Rider + Commission

or:

> Rider + Salary

or:

> Rider + Hybrid.

Changing the compensation arrangement must not destroy historical earnings.

---

# 70. No Retroactive Recalculation

If a PDA earned:

**₦1,000**

per successful delivery in August,

and Admin changes the rate to:

**₦1,500**

in September,

August deliveries must remain:

**₦1,000**

The September rate applies only to transactions under the new effective arrangement.

---

# 71. Core Business Entities

At the database/domain level, the system will eventually revolve around entities such as:

* Client
* Client Agreement
* Product
* Promotion
* Order
* Order Item
* Package
* Delivery
* Delivery Attempt
* Customer
* HQ
* Distribution Center
* Delivery Personnel
* Compensation Profile
* Rate Card
* Inventory
* Inventory Location
* Stock Movement
* Package Custody Movement
* POD Collection
* Remittance
* Remittance Adjustment
* Agent Earning
* Salary
* Client Settlement
* Financial Transaction
* Return
* Audit Log

---

# 72. Non-Functional Requirements

The system should be:

### Secure

Role-based access and financial permissions.

### Auditable

Financial and stock changes must be traceable.

### Scalable

Support multiple HQs, DCs, clients and thousands of deliveries.

### Mobile-first

PDA and rider operations must work effectively on smartphones.

### Nigerian-network friendly

The mobile experience should remain usable under inconsistent internet connectivity.

### Offline-aware

Critical delivery workflows should have an appropriate offline strategy where technically feasible.

### Fast

Delivery personnel should not need to wait unnecessarily to perform field operations.

---

# 73. Reporting Requirements

Management reports should include:

### Delivery

* Total deliveries
* Successful
* Failed
* Success rate
* First-attempt success
* Reattempts

### POD

* Expected collections
* Actual collections
* Remitted
* Outstanding
* Variances

### Inventory

* Opening
* Received
* Transferred
* Issued
* Delivered
* Returned
* Damaged
* Closing

### Personnel

* Deliveries
* Success rate
* Commission
* Transport
* Salary
* Outstanding earnings

### Clients

* Orders
* Successful
* Failed
* POD collections
* Delivery charges
* Client payable
* Settled
* Outstanding

---

# 74. Dashboard KPI Examples

General Operations dashboard:

**Total Deliveries**

**Success Rate**

**POD Collected**

**POD Outstanding**

**Client Payables**

**Agent Earnings**

**Inventory Value/Quantity**

**Failed Deliveries**

**Returns**

**Active PDAs**

**Active Riders**

**Top Performing DCs**

**Top Performing Agents**

---

# 75. Critical Reconciliation Rules

The system should constantly be able to reconcile:

### Inventory

Opening + Incoming − Outgoing = Closing

### POD Cash

Expected Collection − Approved Deductions = Expected Remittance

### Remittance

Expected Remittance − Actual Remittance = Variance

### Agent Earnings

Accrued − Paid/Deducted = Outstanding

### Client Settlement

Gross Collection − NovaExpress Charges ± Adjustments = Client Payable

These should be system-calculated.

---

# 76. What the System Should Never Allow Silently

The system should flag:

* Missing inventory
* Unexplained stock adjustments
* Cash shortages
* Excess cash
* Unapproved deductions
* Unapproved POS fees
* Negative stock
* Unverified returns
* Duplicate remittance
* Duplicate delivery
* Rate changes without authorization
* Settlement discrepancies

---

# 77. Recommended Development Phases

Now that the master model is defined, I would structure development by **operational domains**, not simply by user roles.

## Phase 1 — PDA & Rider Mobile Operations

* Login
* Assigned deliveries
* Delivery execution
* Package custody
* Inventory received
* POD collection
* Remittance
* Earnings
* Performance
* Returns

---

## Phase 2 — DC Operations

* DC dashboard
* Orders
* Package receiving
* Inventory
* PDA/Rider management
* Stock issuing
* Returns
* Remittance verification
* Delivery monitoring
* Local reporting

---

## Phase 3 — HQ Operations

* HQ dashboard
* DC management
* Inventory oversight
* Transfers
* Restock approvals
* Client operations
* Delivery monitoring
* Financial overview

---

## Phase 4 — General Operations

* Multi-HQ management
* Global dashboards
* Rate configuration
* Compensation configuration
* Client agreements
* Performance
* Global reports
* Operational controls

---

## Phase 5 — Finance & Settlement

* POD reconciliation
* Client settlements
* Agent earnings
* Salaries
* POS charges
* Financial adjustments
* Financial reports

---

## Phase 6 — Client Portal

* Order submission
* Package tracking
* Distributed inventory
* Stock visibility
* POD tracking
* Settlement
* Reports

---

# 78. Final Architectural Principle

The most important thing for the development team is this:

> **NovaExpress is not simply a delivery app.**

It is a **logistics network + inventory management + delivery execution + cash collection + agent compensation + client settlement platform.**

And the financial model must be flexible enough to accommodate changing business arrangements.

The system should therefore **never hardcode the current ₦5,000, ₦1,500, ₦1,000, ₦500, ₦1,500 or ₦800 rates as permanent business logic.**

Instead:

**Client Agreement**

→ defines what NovaExpress charges the client

**Rate Card**

→ defines operational defaults

**Compensation Profile**

→ defines what an individual PDA/Rider earns

**Effective Dates**

→ determine which rate applies

**Financial Transaction**

→ records what actually happened

**Ledger**

→ maintains the historical truth.

That architecture will allow NovaExpress to change its pricing, negotiate different client agreements, change a PDA's commission, move someone from commission to salary, introduce new products, add new HQs/DCs, and add new delivery personnel **without rebuilding the system.**
