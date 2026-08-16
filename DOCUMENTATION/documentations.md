# NOVAEXPRESS LOGISTICS

## Product Requirements Document (PRD)

**Product:** NovaExpress Logistics Management Platform
**Market:** Nigeria
**Primary Currency:** Nigerian Naira (₦ / NGN)
**Initial POD Products:** Grazer Herbal Tea, Respira, Alpha Man
**Product Catalogue:** Extensible — additional products will be added
**Primary Headquarters:** Abuja, Nigeria

---

# 1. PRODUCT OVERVIEW

NovaExpress Logistics is a Nigerian logistics and distribution management platform designed to manage the movement of customer orders and physical products across Nigeria.

NovaExpress operates through a hierarchical distribution structure consisting of:

* General Operations Unit
* Headquarters
* Distribution Centers
* Personal Distribution Agents (PDAs)
* Customers
* Corporate/major clients

The platform manages the complete lifecycle of an order, from the moment an order enters NovaExpress through allocation, stock movement, PDA collection, customer delivery, payment collection where applicable, product returns, and financial reconciliation.

The system must support both:

1. **Pay on Delivery (POD)**
2. **Non-Pay on Delivery / Prepaid orders**

The initial products handled under POD include:

* Grazer Herbal Tea
* Respira
* Alpha Man

The architecture must allow administrators to add additional products without requiring changes to the core application.

---

# 2. NIGERIAN MARKET REQUIREMENT

The system is specifically designed for operations within Nigeria.

Nigeria is not merely the geographic location of the company; Nigerian operational requirements are part of the core product specification.

The application must therefore use Nigerian conventions throughout.

---

# 3. CURRENCY REQUIREMENT

All financial values in the system must be represented in **Nigerian Naira**.

Currency code:

**NGN**

Currency symbol:

**₦**

Examples:

* ₦5,000
* ₦25,000
* ₦150,000
* ₦1,250,000

The system must not display USD, GBP, EUR or any other currency in normal NovaExpress operations.

Financial amounts stored in the backend should use NGN.

Examples of values that must be represented in Naira include:

* Product prices
* Order values
* Discounts
* POD collection amounts
* PDA cash balances
* Remittances
* Stock valuations
* Client charges
* Financial reports

---

# 4. NIGERIAN PHONE NUMBER REQUIREMENT

Customer, PDA, staff and client contact numbers should support Nigerian phone numbers.

Examples:

* 080XXXXXXXX
* 081XXXXXXXX
* 090XXXXXXXX
* 070XXXXXXXX
* +234XXXXXXXXXX

The system should normalize phone numbers internally where necessary while allowing users to enter common Nigerian formats.

---

# 5. NIGERIAN ADDRESS REQUIREMENT

The delivery address structure must be designed for Nigerian addresses.

The system should support:

* State
* LGA
* City/Town
* Area/Neighbourhood
* Street
* House/Building number
* Landmark
* Additional directions
* Customer delivery notes

Example:

**State:** FCT Abuja
**LGA:** Abuja Municipal
**Area:** Garki
**Street:** Example Street
**House:** 24
**Landmark:** Opposite XYZ Pharmacy

The system should not assume that a formal street address alone is sufficient.

Landmarks and delivery instructions are important for Nigerian last-mile delivery.

---

# 6. NIGERIAN LOCATION STRUCTURE

The system should support all Nigerian states and the Federal Capital Territory.

The location hierarchy should generally be:

**Country → State/FCT → LGA → City/Town → Area → Address**

The Federal Capital Territory must be treated appropriately as **FCT Abuja**, rather than as a normal Nigerian state.

The system should support expansion across:

* Abuja / FCT
* Lagos
* Kano
* Rivers
* Kaduna
* Oyo
* Anambra
* Enugu
* Delta
* Edo
* Ogun
* Plateau
* Nasarawa
* Niger
* and all other Nigerian states.

The location data should be configurable rather than hardcoded into individual screens.

---

# 7. CORE BUSINESS OBJECTIVE

The system must provide NovaExpress with complete operational visibility over:

**Orders**

**Products**

**Inventory**

**Distribution Centers**

**PDAs**

**Deliveries**

**POD collections**

**Cash remittances**

**Returns**

**Stock transfers**

**Restock requests**

**Client packages**

**Discounts**

**Free products**

**Reports**

---

# 8. ORGANIZATIONAL STRUCTURE

NovaExpress uses a hierarchical operational model.

The highest level is the **General Operations Unit**.

Under General Operations are one or more **Headquarters**.

Each Headquarters manages multiple **Distribution Centers**.

Each Distribution Center manages multiple **Personal Distribution Agents (PDAs)**.

Therefore:

**General Operations → Headquarters → Distribution Centers → PDAs → Customers**

The system must maintain this relationship throughout all modules.

---

# 9. GENERAL OPERATIONS UNIT

The General Operations Unit provides company-wide operational control.

It should be able to see information across all Headquarters.

Responsibilities include:

* Managing Headquarters
* Monitoring nationwide orders
* Monitoring nationwide inventory
* Monitoring Distribution Centers
* Monitoring PDAs
* Monitoring POD collections
* Monitoring outstanding cash
* Monitoring stock transfers
* Monitoring restock requests
* Managing system configuration
* Viewing company-wide reports

General Operations should have a high-level dashboard rather than manually managing every individual delivery.

---

# 10. HEADQUARTERS

NovaExpress can have multiple Headquarters.

The first major Headquarters is in Abuja.

Additional Headquarters can be created as the company expands.

Each HQ manages:

* Its Distribution Centers
* HQ inventory
* Regional stock transfers
* DC restocking
* Regional orders
* Regional PDA activity
* Regional operational performance

An HQ should not automatically have access to another HQ's operational data unless its role permits such access.

---

# 11. DISTRIBUTION CENTERS

Distribution Centers operate underneath Headquarters.

A DC is responsible for local physical inventory and PDA operations.

A DC should be able to:

* Receive stock from HQ
* Hold inventory
* Request additional stock
* Receive stock transfers
* Issue stock to PDAs
* Receive returned products
* Monitor PDA inventory
* Monitor local orders
* Monitor local deliveries
* Verify PDA remittances

---

# 12. PERSONAL DISTRIBUTION AGENTS

PDAs are field delivery personnel.

A PDA is assigned to a Distribution Center.

The PDA's primary responsibilities are:

1. Receive assigned orders/products from the DC.
2. Take the products to customers.
3. Deliver orders.
4. Collect customer payment for POD orders.
5. Record delivery outcomes.
6. Return failed/undelivered products to the DC.
7. Remit collected POD cash according to NovaExpress procedures.

The PDA application must therefore be optimized for speed and simplicity.

---

# 13. PDA MOBILE APPLICATION

The PDA should not see the complex administrative functionality available to Headquarters and General Operations.

The PDA application should focus on:

* Today's work
* Orders
* Delivery
* Stock
* Cash
* Remittance
* History
* Profile

The PDA should be able to complete most common tasks with minimal typing.

---

# 14. PDA PRIMARY NAVIGATION

The PDA application should contain the following primary areas:

1. Home
2. Orders
3. Stock
4. Cash
5. History
6. Profile

---

# 15. PDA HOME

The Home screen is the PDA's daily operational dashboard.

It should immediately show:

### Delivery Summary

* Orders assigned today
* Orders collected
* Orders out for delivery
* Orders delivered
* Failed deliveries
* Orders awaiting action

### Stock Summary

* Total products currently held
* Products awaiting delivery

### Cash Summary

* POD cash collected
* Cash already remitted
* Cash remaining to remit

### Alerts

Examples:

* Cash remittance pending
* Failed delivery requiring action
* Product return pending
* New order assigned

---

# 16. PDA ORDER MANAGEMENT

The PDA must have an Orders section containing all orders assigned to them.

Orders should be filterable by status.

Suggested statuses:

* Assigned
* Ready for Collection
* Collected
* Out for Delivery
* Delivered
* Failed
* Returned

Each order should clearly display:

* Order ID
* Customer name
* Customer location
* Product count
* Payment type
* Amount to collect if POD
* Current status

---

# 17. ORDER DETAILS

The PDA must be able to open any assigned order.

Order Details should contain:

### Customer

* Customer name
* Phone number
* Delivery address
* State
* LGA
* Area
* Landmark
* Delivery instructions

### Order

* Order ID
* Client
* Order date
* Products
* Paid quantities
* Free quantities
* Total physical quantities

### Payment

* POD or Non-POD
* Amount to collect
* Amount collected
* Outstanding amount

### Distribution

* Headquarters
* Distribution Center
* PDA
* Assignment date

---

# 18. PRODUCT QUANTITY MODEL

The system must distinguish between:

**Paid Quantity**

and

**Free Quantity**

and

**Total Physical Quantity**

Example:

A customer orders:

**5 Grazer Herbal Tea**

Client promotion:

**1 free Grazer Herbal Tea**

The system must display:

Paid Quantity: 5
Free Quantity: 1
Total Physical Quantity: 6

The customer pays according to the applicable commercial rules.

However, NovaExpress must physically deliver and account for **6 units**.

---

# 19. CURRENT POD PRODUCT CATALOGUE

The initial NovaExpress POD catalogue contains:

### Grazer Herbal Tea

### Respira

### Alpha Man

These are the current products.

The system must not be designed around only these three products.

A product management module must allow authorized administrators to add:

* New products
* Product prices
* Product codes
* Product descriptions
* Product categories
* Product status
* Product images
* Package rules
* Discount rules
* Free-product rules

without redesigning the application.

---

# 20. PRODUCT IDENTIFICATION

Each product should have a unique internal product identifier.

Example:

**GRAZER-001**

**RESPIRA-001**

**ALPHA-001**

The exact codes should be configurable.

Products may also have:

* Barcode
* QR code
* SKU
* Batch number
* Expiry date, where applicable

---

# 21. PDA ORDER COLLECTION FROM DC

When a PDA arrives at a Distribution Center, they need to collect their assigned orders.

The process should be:

1. PDA opens assigned orders.
2. PDA selects orders to collect.
3. PDA scans order/package code where applicable.
4. DC verifies the order.
5. Products are handed to the PDA.
6. PDA confirms receipt.
7. System deducts products from DC inventory.
8. System adds products to PDA inventory.
9. Order status changes to Collected.

The system must create an inventory transaction for this movement.

---

# 22. ORDER SCANNING

The PDA application should support barcode/QR scanning where applicable.

Scanning should allow the system to quickly identify:

* Order
* Product
* Package
* Collection reference

The scan should not replace validation.

The system must still verify that:

* The order belongs to the PDA.
* The order is available for collection.
* The order has not already been collected.
* The product quantities match.

---

# 23. PDA INVENTORY

Every PDA must have an individual inventory account.

Example:

PDA: John Doe

Grazer Herbal Tea: 12
Respira: 5
Alpha Man: 4

The system should know exactly how many units are currently assigned to that PDA.

---

# 24. PDA INVENTORY MOVEMENT

PDA inventory changes through transactions such as:

* Received from DC
* Delivered to customer
* Returned to DC
* Damaged
* Adjusted by authorized staff

Every movement must be recorded.

The PDA should be able to see their current stock and basic stock history.

---

# 25. DELIVERY PROCESS

The delivery process begins when the PDA has collected the order from the DC.

The PDA opens the order and sees:

* Customer name
* Customer phone
* Nigerian delivery address
* Landmark
* Delivery instructions
* Product information
* Payment status

The PDA should be able to call the customer and open navigation.

---

# 26. CUSTOMER CONTACT

The application should support quick access to the customer's Nigerian phone number.

Actions may include:

* Call customer
* Copy number
* View number

The system should not expose unnecessary customer information to the PDA.

---

# 27. DELIVERY CONFIRMATION

When the PDA reaches the customer, they must confirm the delivery.

Depending on the final business decision, confirmation may involve:

* OTP
* Customer signature
* Delivery photo
* PDA confirmation
* Timestamp
* GPS/location capture

The PRD should keep this configurable.

---

# 28. PAY ON DELIVERY

For a POD order, the PDA must collect the amount due from the customer.

The order should clearly display:

**Amount to Collect: ₦XX,XXX**

The PDA records the amount actually received.

The application must support:

* Cash
* Bank transfer

The final allowed payment methods should be configurable by NovaExpress.

---

# 29. POD PAYMENT VALIDATION

The system must compare:

**Expected Amount**

against

**Amount Collected**

Example:

Expected:

**₦45,000**

Collected:

**₦45,000**

Result:

**Matched**

If the PDA records:

Expected:

**₦45,000**

Collected:

**₦40,000**

The system must calculate:

**Variance: ₦5,000**

The PDA must provide a reason.

---

# 30. NON-POD ORDERS

For prepaid/non-POD orders, the PDA must not collect customer payment.

The order should display:

**PAID**

and:

**Amount to Collect: ₦0**

The PDA simply completes the delivery.

---

# 31. DELIVERY SUCCESS

After a successful delivery, the system records:

* Order ID
* Customer
* PDA
* Products delivered
* Delivery date
* Delivery time
* Delivery confirmation
* Payment status
* Amount collected if POD

The order becomes:

**Delivered**

The corresponding PDA inventory is reduced.

---

# 32. FAILED DELIVERY

If delivery fails, the PDA must select a reason.

Initial reasons should include:

* Customer unavailable
* Customer refused order
* Phone unreachable
* Wrong address
* Address/location issue
* Customer requested another date
* Product issue
* Other

The PDA can add notes.

---

# 33. DELIVERY REATTEMPT

A failed order may be eligible for another delivery attempt.

The system should support:

* Reattempt
* Reschedule
* Return to DC

The exact action available should depend on NovaExpress's operational rules.

---

# 34. PRODUCT RETURNS

When an order cannot be delivered and must return to the DC:

1. PDA marks order for return.
2. PDA returns physical products to DC.
3. DC receives the products.
4. DC verifies quantities.
5. DC inspects condition.
6. Inventory is updated.
7. Order becomes Returned or another applicable status.

Returned products should be classified as appropriate:

* Good condition
* Damaged
* Opened
* Missing
* Unsellable

---

# 35. PDA CASH MANAGEMENT

The PDA's cash position must be tracked separately from their physical product inventory.

The system should maintain:

**Expected POD**

**Collected POD**

**Remitted**

**Verified**

**Outstanding**

Example:

Expected:

**₦500,000**

Collected:

**₦490,000**

Remitted:

**₦400,000**

Outstanding:

**₦90,000**

---

# 36. PDA REMITTANCE

PDA remittance is the process of handing over collected POD money to NovaExpress.

The PDA should be able to see:

**Total collected**

**Total already remitted**

**Amount remaining**

The PDA can initiate a remittance.

The system records:

* Remittance ID
* PDA
* DC
* Amount
* Payment method
* Reference
* Date
* Time
* Status

---

# 37. CASH REMITTANCE STATUS

Possible statuses:

* Pending
* Submitted
* Received
* Verified
* Rejected
* Variance
* Outstanding

The PDA should clearly know whether their submitted remittance has been verified.

---

# 38. DC CASH VERIFICATION

When the PDA submits cash/remittance, the DC or authorized finance officer verifies it.

Example:

Expected:

**₦150,000**

Received:

**₦150,000**

Status:

**Verified**

If:

Expected:

**₦150,000**

Received:

**₦140,000**

Status:

**Variance**

Difference:

**₦10,000**

---

# 39. HEADQUARTERS INVENTORY

HQ maintains its own inventory.

HQ can:

* Receive stock
* Store stock
* Transfer stock to DCs
* Transfer stock between DCs
* Approve DC restock requests
* View stock levels
* View stock movement

---

# 40. DISTRIBUTION CENTER INVENTORY

DC inventory includes:

* Stock received from HQ
* Stock currently available
* Stock allocated to PDAs
* Returned stock
* Damaged stock
* Reserved stock
* Stock in transit

---

# 41. RESTOCK REQUESTS

A DC can request additional stock from its HQ.

Example:

Wuse DC requests:

Grazer Herbal Tea: 500
Respira: 200
Alpha Man: 100

The request is sent to HQ.

HQ can:

* Approve
* Partially approve
* Reject

Once approved, a stock transfer is created.

---

# 42. STOCK TRANSFERS BETWEEN DISTRIBUTION CENTERS

NovaExpress must support movement of stock from one DC to another.

Example:

Lagos DC → Abuja DC

or:

Abuja DC → Nasarawa DC

The system records:

* Source
* Destination
* Products
* Quantities
* Requesting user
* Approving user
* Dispatch date
* Receiving date
* Expected quantities
* Actual quantities
* Discrepancies

---

# 43. STOCK ACCOUNTABILITY

Every product must have a traceable inventory history.

The system must answer:

> Where did this unit come from?

> Where is it now?

> Who received it?

> Who delivered it?

> Was it returned?

> Was it damaged?

This is particularly important for free products because they have physical value even when the customer was not charged for them.

---

# 44. CLIENT MANAGEMENT

NovaExpress may work with multiple major clients.

Each client can have different:

* Products
* Prices
* Discounts
* Packages
* Free-product arrangements
* Order rules

The system must therefore associate every order with a client.

---

# 45. CLIENT BULK PACKAGES

The system must support bulk-buying arrangements.

Example:

A client may have:

**Buy 5 Grazer Herbal Tea**

**Receive 1 free**

**Additional discount applies**

The package engine calculates the commercial and physical quantities.

Example:

Paid:

5

Free:

1

Physical fulfillment:

6

---

# 46. PROMOTION ENGINE

Promotions should be configurable.

Examples:

* Buy 5, get 1 free
* Buy 10, get 2 free
* Buy X, receive percentage discount
* Buy X products and receive another product free

The system should support future promotional rules without changing the core order architecture.

---

# 47. REPORTING

The platform should provide reports for:

### Orders

* Total orders
* Orders by state
* Orders by LGA
* Orders by client
* Orders by product
* POD vs Non-POD
* Delivered
* Failed
* Returned

### Inventory

* HQ stock
* DC stock
* PDA stock
* Stock transfers
* Stock discrepancies
* Free products distributed

### Delivery

* PDA performance
* DC performance
* Delivery success rate
* Failed deliveries
* Returns

### Finance

* POD expected
* POD collected
* POD remitted
* POD verified
* Outstanding cash
* Variances

---

# 48. PDA PERFORMANCE

The system should calculate PDA performance metrics.

Examples:

* Orders assigned
* Orders collected
* Orders delivered
* Failed deliveries
* Returns
* Delivery success rate
* POD collected
* POD outstanding
* Stock currently held
* Average delivery completion time

---

# 49. NOTIFICATIONS

The PDA should receive notifications for important events.

Examples:

* New order assigned
* Order assignment changed
* Delivery reminder
* Customer delivery issue
* Cash remittance due
* Remittance verified
* Remittance variance
* Return required
* Important operational message

Notifications should be actionable where possible.

---

# 50. OFFLINE / POOR CONNECTIVITY CONSIDERATION

The application is designed for Nigerian field operations.

The PDA may operate in locations where mobile connectivity is unstable.

The system should therefore consider offline-friendly behaviour.

The PDA should be able to access already assigned orders and relevant customer information even when connectivity is temporarily unavailable.

Actions performed offline should be queued and synchronized when connectivity returns, subject to backend validation.

Financial actions and other sensitive operations must have appropriate safeguards against duplicate submissions.

---

# 51. SECURITY

The system must protect:

* Customer information
* PDA information
* Financial information
* Order information
* Inventory information

PDA users should only see information necessary for their assigned operations.

A PDA should not be able to access:

* Another PDA's orders
* HQ-wide inventory
* Company financial reports
* Other customers' unrelated orders
* Administrative configuration

---

# 52. ROLE-BASED ACCESS

Permissions should be based on organizational role.

For example:

**General Operations**

Nationwide access.

**HQ**

Access to its HQ and assigned DCs.

**DC**

Access to its DC and assigned PDAs.

**PDA**

Access to assigned orders, own inventory and own cash activity.

---

# 53. AUDIT TRAIL

Important operations must be logged.

Examples:

* Order assignment
* Product collection
* Stock transfer
* Stock adjustment
* Delivery confirmation
* POD collection
* Cash remittance
* Cash verification
* Return
* Inventory adjustment

The audit record should include:

* User
* Action
* Date
* Time
* Reference
* Previous state where relevant
* New state where relevant

---

# 54. PRODUCT CATALOGUE REQUIREMENT

The initial catalogue is:

1. Grazer Herbal Tea
2. Respira
3. Alpha Man

However, the product module must be designed for expansion.

An administrator must be able to add a new product without requiring a software release.

New products should support:

* Name
* Product code/SKU
* Description
* Category
* Selling price
* Client-specific price where applicable
* Stock quantity
* Barcode/QR code
* Product image
* Active/inactive status
* Package eligibility
* Free-product eligibility

---

# 55. DATABASE / SYSTEM DATA MODEL

The core system should conceptually contain the following entities:

### Organization

* General Operations
* Headquarters
* Distribution Centers

### Users

* Admins
* HQ staff
* DC staff
* PDAs

### Clients

* Client accounts
* Client rules

### Products

* Product catalogue
* SKUs
* Prices

### Packages

* Bulk-buy rules
* Discounts
* Free products

### Orders

* Customer
* Client
* Products
* Payment
* Distribution
* Delivery

### Inventory

* HQ stock
* DC stock
* PDA stock
* Stock movements

### Deliveries

* Assignment
* Delivery attempts
* Delivery outcome
* Returns

### Finance

* POD collections
* Remittances
* Verification
* Variances

### Audit

* System activities

---

# 56. ORDER NUMBERING

Orders should have unique NovaExpress identifiers.

Example:

**NEX-2026-000001**

The format should be configurable.

Other records should have unique references as well.

Examples:

**TRF-000001** — Stock Transfer

**RST-000001** — Restock Request

**REM-000001** — Remittance

**PDA-000001** — PDA ID

---

# 57. CORE BUSINESS RULES

The following rules are mandatory.

### Rule 1

All NovaExpress financial values are in **Nigerian Naira (₦ / NGN)**.

### Rule 2

Only authorized users can change product prices.

### Rule 3

Free products are deducted from physical inventory.

### Rule 4

Paid quantity and physical quantity must be separately tracked.

### Rule 5

Every stock movement must have a transaction record.

### Rule 6

Every POD collection must have an expected amount.

### Rule 7

PDA-reported collection must be compared against expected collection.

### Rule 8

PDA remittances must be separately recorded from customer collections.

### Rule 9

Cash is not considered reconciled until authorized staff verify it.

### Rule 10

Failed deliveries must have a reason.

### Rule 11

Returned products must be physically verified.

### Rule 12

PDAs can only access orders assigned to them.

### Rule 13

Products must be extensible.

### Rule 14

Headquarters and Distribution Centers must maintain separate inventory balances.

### Rule 15

A PDA must have an identifiable stock balance.

### Rule 16

An order must have a clearly identifiable client, customer, payment type, location and operational assignment.

---

# 58. MVP — PHASE 1

The first release should focus on the operational core.

### Required

**User Authentication**

**Organization Management**

**HQ Management**

**DC Management**

**PDA Management**

**Product Management**

**Order Management**

**Inventory Management**

**PDA Stock**

**Order Assignment**

**Order Collection**

**Delivery**

**POD Collection**

**Cash Remittance**

**Returns**

**Restock Requests**

**Stock Transfers**

**Basic Reports**

**Notifications**

**Audit Logs**

---

# 59. PDA MVP

The PDA application MVP should contain:

1. Login
2. Home
3. Orders
4. Order Details
5. Order Collection
6. QR/Barcode Scan
7. Delivery
8. POD Payment
9. Non-POD Delivery
10. Delivery Success
11. Failed Delivery
12. My Stock
13. Cash Dashboard
14. Cash Remittance
15. History
16. Profile

---

# 60. SUCCESS CRITERIA

The NovaExpress system should be considered operationally successful when management can trace an order from:

**Client → Order → HQ → DC → PDA → Customer → Delivery → Payment → Remittance → Reconciliation**

and trace the physical products from:

**HQ → DC → PDA → Customer**

while accounting for:

* Paid products
* Free products
* Discounts
* Delivered products
* Returned products
* Damaged products
* POD cash
* Remitted cash
* Cash discrepancies

---

# 61. PRIMARY DESIGN PRINCIPLE

NovaExpress should not be designed as a generic delivery app.

It is a **Nigerian distribution operations platform**.

The product design must reflect the actual operational realities of moving physical products and collecting money across Nigeria.

The interface should always make these questions easy to answer:

**Where is the order?**

**Where is the product?**

**Which HQ is responsible?**

**Which DC is responsible?**

**Which PDA has the order?**

**Has the customer received it?**

**Is it Pay on Delivery?**

**How much should the PDA collect in ₦?**

**How much did the PDA collect?**

**How much has the PDA remitted?**

**How much is still outstanding?**

**Where are the free products?**

**Has every physical unit been accounted for?**

**Is there a stock or cash discrepancy?**

That traceability is the foundation of the NovaExpress Logistics platform.
