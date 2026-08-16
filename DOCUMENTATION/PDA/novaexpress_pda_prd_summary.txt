# NovaExpress Logistics

## Product Requirements Document — Phase 1: PDA Mobile Application

**Product:** NovaExpress Logistics PDA App
**Phase:** Phase 1 — Personal Distribution Agent (PDA)
**Market:** Nigeria
**Currency:** Nigerian Naira (₦ / NGN)
**Primary HQ:** Abuja, Nigeria
**Initial POD Products:** Grazer Herbal Tea, Respira, Alpha Man
**Product Catalogue:** Extensible; additional products will be added later

---

# 1. Phase Overview

Phase 1 focuses exclusively on the **Personal Distribution Agent (PDA)** mobile application.

The PDA is the field agent responsible for taking customer orders from a NovaExpress Distribution Center (DC) and delivering them to customers across Nigeria.

For Pay on Delivery (POD) orders, the PDA is also responsible for collecting the customer's payment and subsequently remitting the collected money to NovaExpress according to the company's operating procedure.

The PDA application must therefore provide a simple, fast, field-oriented workflow for:

* Receiving assigned orders
* Collecting orders from a Distribution Center
* Verifying physical products
* Managing PDA-held inventory
* Delivering orders
* Collecting POD payments
* Recording delivery outcomes
* Handling failed deliveries
* Returning products to the DC
* Tracking cash collected
* Submitting remittances
* Viewing operational history

The PDA should **not** have access to complex headquarters, Distribution Center, company-wide financial, or administrative functionality.

---

# 2. Product Goal

The primary goal of the PDA application is:

> **Enable a NovaExpress PDA to receive, carry, deliver, account for, and return physical customer orders while maintaining accurate records of products and POD cash.**

The application should allow a PDA to complete their daily work with as little friction as possible.

The most important workflow is:

**DC → PDA → Customer**

For POD:

**Customer → PDA → NovaExpress**

The system must maintain an accurate digital record of both flows.

---

# 3. Nigerian-First Requirement

The PDA application is strictly designed for NovaExpress operations in Nigeria.

All interface, data, financial and delivery assumptions must reflect Nigerian operations.

### Currency

All monetary values must use:

**₦ / NGN**

Examples:

* ₦5,000
* ₦25,500
* ₦150,000

No USD, GBP, EUR or other currencies should appear in the PDA application.

### Phone Numbers

The app must support Nigerian phone numbers, including:

* 080XXXXXXXX
* 081XXXXXXXX
* 090XXXXXXXX
* 070XXXXXXXX
* +234XXXXXXXXXX

### Locations

Customer addresses must support Nigerian location structures, including:

* State
* LGA
* City/Town
* Area
* Street
* House/Building number
* Landmark
* Delivery instructions

The PDA should be able to handle addresses where landmarks and additional directions are important.

### Nigerian States

The system must support all Nigerian states and the Federal Capital Territory.

FCT Abuja must be represented as **FCT Abuja**, not as a conventional state.

---

# 4. PDA Role

A PDA is a field-level NovaExpress logistics agent assigned to a specific Distribution Center.

The PDA's responsibilities are:

1. Receive assigned customer orders.
2. Collect products from the assigned DC.
3. Confirm physical quantities received.
4. Keep accurate custody of assigned products.
5. Deliver orders to customers.
6. Collect payment for POD orders.
7. Record successful and failed deliveries.
8. Return undelivered products to the DC.
9. Track POD cash collected.
10. Submit collected money for remittance.
11. Maintain accurate operational records.

---

# 5. PDA Access Restrictions

The PDA must only have access to information relevant to their work.

The PDA must **not** be able to:

* View another PDA's orders
* View another PDA's cash balance
* Modify product prices
* Create products
* Modify client promotions
* Modify discounts
* Modify inventory independently
* Transfer stock between DCs
* Approve restock requests
* Manage Distribution Centers
* Manage Headquarters
* View company-wide financial reports
* Modify users or permissions

The PDA operates within the boundaries assigned by NovaExpress.

---

# 6. PDA App Navigation

The primary navigation should contain:

1. **Home**
2. **Orders**
3. **Stock**
4. **Cash**
5. **History**
6. **Profile**

The navigation should be optimized for one-handed mobile use.

The most frequently used area should be **Orders**.

---

# 7. PDA Screen Inventory

The initial PDA design should contain the following screens.

### Authentication

1. Login
2. Forgot Password

### Home

3. PDA Dashboard

### Orders

4. My Orders
5. Order Details
6. Collect Order
7. Scan / Verify Order
8. Delivery
9. POD Payment
10. Non-POD Confirmation
11. Delivery Success
12. Failed Delivery
13. Reattempt / Return

### Stock

14. My Stock
15. Stock Details
16. Stock Movement

### Cash

17. Cash Dashboard
18. Remittance
19. Remittance Details

### History

20. Delivery History
21. Remittance History
22. Stock History

### Profile

23. Profile
24. Settings

Some of these can be implemented as states, bottom sheets, or confirmation dialogs rather than completely independent pages.

---

# 8. Authentication

## 8.1 Login

The PDA should authenticate using credentials supplied by NovaExpress.

Possible fields:

* Phone number / username
* Password

Actions:

* Login
* Forgot Password

Optional future functionality:

* Biometric authentication
* Device verification

---

# 9. Home / PDA Dashboard

The dashboard should answer one question:

> **"What do I need to do today?"**

The screen should prioritize actionable information.

### Today's Delivery Summary

Display:

* Orders assigned
* Orders awaiting collection
* Orders collected
* Orders out for delivery
* Delivered orders
* Failed orders
* Orders requiring attention

Example:

**Today's Orders: 15**

**Delivered: 8**

**Pending: 4**

**Failed: 1**

**Awaiting Collection: 2**

---

# 10. Dashboard Stock Summary

The dashboard should show the PDA's current physical inventory.

Example:

**My Stock**

Grazer Herbal Tea — 10 units
Respira — 5 units
Alpha Man — 3 units

The PDA should be able to tap this section to open the full Stock screen.

---

# 11. Dashboard Cash Summary

The dashboard should show the PDA's current POD position.

Example:

**POD Collected Today**

₦520,000

**Already Remitted**

₦350,000

**To Remit**

₦170,000

This information should update as delivery and remittance transactions are recorded.

---

# 12. Dashboard Alerts

The dashboard should display operational alerts.

Examples:

* New order assigned
* Order awaiting collection
* Failed delivery requires action
* Product return pending
* Remittance pending
* Remittance discrepancy
* Important operational message

---

# 13. My Orders

The Orders screen is the primary PDA workspace.

The PDA should see only orders assigned to them.

Orders should be organized by status.

Suggested filters:

* All
* To Collect
* Collected
* Out for Delivery
* Delivered
* Failed
* Returned

Each order card should display:

* Order ID
* Customer name
* Location
* Product quantity
* Payment type
* Amount to collect if POD
* Order status

---

# 14. Order Status Lifecycle

An order assigned to a PDA may move through the following operational states:

**Assigned**

→ **Ready for Collection**

→ **Collected**

→ **Out for Delivery**

→ **Delivered**

or:

**Out for Delivery**

→ **Failed**

→ **Reattempt**

or:

**Failed**

→ **Returned to DC**

The exact status transition must be controlled by the backend rather than freely editable by the PDA.

---

# 15. Order Details

The Order Details screen must provide everything the PDA needs to complete the delivery.

### Customer Information

* Customer name
* Phone number
* State
* LGA
* City/Town
* Area
* Street
* House/building number
* Landmark
* Delivery instructions

### Order Information

* Order ID
* Client
* Order date
* Product(s)
* Paid quantity
* Free quantity
* Total physical quantity

### Payment Information

* POD / Non-POD
* Expected amount
* Amount collected
* Payment status

### Assignment

* Assigned DC
* PDA
* Assignment date
* Current status

---

# 16. Product Quantity Display

The PDA must clearly distinguish between:

**Paid Quantity**

**Free Quantity**

**Total Physical Quantity**

Example:

**Grazer Herbal Tea**

Paid: 5
Free: 1
Total to Deliver: 6

The PDA must understand that the customer receives **6 physical units**, even though only 5 may be paid units.

This is critical for inventory accountability.

---

# 17. Current POD Products

The PDA application must initially support these POD products:

### Grazer Herbal Tea

### Respira

### Alpha Man

The application must not hardcode these products into the interface architecture.

More products will be added later through the product management system.

The PDA UI should automatically display newly authorized products assigned to the PDA.

---

# 18. Collect Order From DC

Before delivery, the PDA must physically collect the order from the Distribution Center.

The PDA opens the order and selects:

**Collect Order**

The application should display:

* Order ID
* Customer
* Products
* Paid quantities
* Free quantities
* Total physical quantities
* Payment type
* Amount to collect

---

# 19. Order Verification

The PDA should be able to scan an order/package QR code or barcode where implemented.

Scanning should verify:

* Correct order
* Correct PDA
* Correct DC
* Order availability
* Order status
* Package identity

The system should prevent a PDA from collecting an order assigned to another PDA unless an authorized reassignment has occurred.

---

# 20. Collection Confirmation

After physical verification, the PDA confirms:

**I have received this order.**

Once confirmed:

* DC inventory decreases
* PDA inventory increases
* Order becomes Collected
* Collection timestamp is recorded
* PDA becomes responsible for the physical products

The system must create a stock movement record.

---

# 21. PDA Stock

Every PDA must have an individual inventory balance.

Example:

**PDA: John Doe**

Grazer Herbal Tea — 12
Respira — 5
Alpha Man — 4

The PDA should be able to see their current stock at any time.

---

# 22. PDA Stock Transactions

PDA stock may change through:

### Stock Received

Product received from DC.

### Delivery

Product delivered to customer.

### Return

Product returned to DC.

### Adjustment

Authorized stock adjustment.

### Damage

Product identified as damaged.

Every transaction must be recorded.

---

# 23. Stock Details

Selecting a product should show:

* Product name
* Current quantity
* Today's received quantity
* Today's delivered quantity
* Today's returned quantity
* Adjustment history
* Current balance

Example:

**Grazer Herbal Tea**

Opening: 10
Received: +20
Delivered: -15
Returned: -2
Current: 13

---

# 24. Delivery Screen

Once an order has been collected, the PDA can begin delivery.

The screen should prioritize the customer's location and contact information.

Display:

* Customer name
* Phone
* Nigerian delivery address
* Landmark
* Delivery notes

Actions:

**Call Customer**

**Open Navigation**

**Confirm Delivery**

---

# 25. Customer Contact

The PDA should be able to call the customer directly from the application.

The phone number should be displayed using a Nigerian-compatible format.

The application should not require the PDA to manually copy the number into the phone application.

---

# 26. Navigation

The application should provide a way to open the customer's location in the PDA's available navigation application.

The NovaExpress application does not necessarily need to provide its own full navigation system.

It should provide the customer location/address information required for navigation.

---

# 27. Successful Delivery

Before completing delivery, the PDA must verify that:

* Correct order is being delivered.
* Customer information is correct.
* Physical quantities match the order.
* Payment status is correctly identified.

The PDA then proceeds to either:

**POD Payment**

or:

**Non-POD Confirmation**

---

# 28. POD Order Workflow

For a POD order, the PDA must collect the customer's payment.

The order should clearly show:

**PAY ON DELIVERY**

**Amount to Collect: ₦XX,XXX**

The PDA must not have to calculate the amount manually.

The backend should provide the amount due.

---

# 29. POD Payment Screen

The POD payment screen should display:

**Expected Amount**

Example:

**₦45,000**

The PDA enters:

**Amount Collected**

Example:

**₦45,000**

The PDA selects the payment method.

Initial methods:

* Cash
* Bank Transfer

The exact allowed methods should be configurable by NovaExpress.

---

# 30. POD Payment Validation

The system must compare:

**Expected Amount**

with:

**Amount Collected**

### Matching Example

Expected:

₦45,000

Collected:

₦45,000

Result:

**Payment Matched**

### Variance Example

Expected:

₦45,000

Collected:

₦40,000

Variance:

₦5,000

The system must require the PDA to provide a reason for the variance.

The PDA should not be able to silently complete a transaction with a discrepancy.

---

# 31. Non-POD Order Workflow

For prepaid orders:

The application should clearly show:

**PAID**

**Amount to Collect: ₦0**

The PDA should not be asked to enter payment information.

The PDA only confirms delivery.

This prevents accidental cash collection from prepaid customers.

---

# 32. Delivery Confirmation

Depending on NovaExpress's final operational policy, successful delivery may require one or more of:

* PDA confirmation
* Customer OTP
* Customer signature
* Delivery photograph
* Timestamp
* GPS/location information

The architecture should support these verification mechanisms without making the PDA workflow unnecessarily complicated.

---

# 33. Delivery Success

After completion, display a clear confirmation.

Example:

**Delivery Completed**

Order:

NEX-2026-000245

Customer:

John Doe

Products:

6 units

Payment:

₦45,000 collected

The system records:

* Delivery timestamp
* PDA
* Order
* Products delivered
* Payment status
* Amount collected
* Delivery confirmation

---

# 34. Inventory Update After Delivery

When a delivery is successfully completed:

The delivered physical quantity must be deducted from PDA stock.

Example:

PDA has:

6 Grazer Herbal Tea

Customer receives:

6

New PDA balance:

0

The system must not deduct only the paid quantity when free units are included.

---

# 35. Failed Delivery

The PDA must be able to report a failed delivery.

The PDA should select a reason.

Initial reasons:

* Customer unavailable
* Customer refused
* Phone unreachable
* Wrong address
* Unable to locate customer
* Customer requested another date
* Product issue
* Other

The PDA may provide additional notes.

---

# 36. Failed Delivery Evidence

Depending on NovaExpress policy, the system may capture:

* Timestamp
* GPS location
* Customer call attempt
* PDA note
* Photograph
* Other evidence

This should be configurable.

---

# 37. Reattempt

Some failed deliveries should be eligible for reattempt.

The PDA may see:

**Reattempt Required**

The system should display:

* Previous attempt
* Failure reason
* Notes
* Next delivery date/time if scheduled

The PDA should not arbitrarily change delivery schedules if NovaExpress requires DC authorization.

---

# 38. Return to DC

If an order cannot be delivered and must return:

The PDA selects:

**Return to DC**

The order becomes:

**Return Pending**

The PDA must physically return the products.

The DC later verifies the returned products.

---

# 39. Return Inventory Process

When a return is completed at the DC:

PDA inventory:

**- Returned quantity**

DC inventory:

**+ Accepted quantity**

The system must record:

* Returned product
* Quantity
* Condition
* PDA
* DC
* Date/time
* Return reason

---

# 40. Cash Dashboard

The Cash section provides the PDA with a financial summary of their POD activity.

It should display:

### Today's POD

Expected:

₦XXX

Collected:

₦XXX

Remitted:

₦XXX

Outstanding:

₦XXX

### Lifetime / Current Outstanding

Where appropriate, the PDA can view their outstanding remittance balance.

---

# 41. Cash Must Be Separate From Product Inventory

The system must maintain two separate accountability systems:

### Physical Inventory

Products held by the PDA.

### Financial Accountability

Money collected by the PDA.

They must not be combined into a single balance.

A PDA can have:

**₦200,000 cash outstanding**

while holding:

**30 physical products**

These are separate operational liabilities.

---

# 42. Remittance

The PDA should be able to submit a remittance.

The remittance screen displays:

**Amount Available to Remit**

Example:

**₦165,000**

The PDA enters the amount being remitted.

The PDA selects the remittance method.

The system records:

* PDA
* DC
* Amount
* Method
* Date
* Time
* Reference
* Status

---

# 43. Remittance Status

Possible statuses:

* Pending
* Submitted
* Received
* Verified
* Rejected
* Variance
* Outstanding

The PDA should clearly see the current status of each remittance.

---

# 44. Remittance Reference

Where money is transferred electronically, the PDA should be able to provide the applicable transaction/reference number.

Example:

**Bank Transfer Reference**

The reference should be stored with the remittance record.

---

# 45. Remittance Verification

The PDA should not be considered financially cleared simply because they clicked Submit.

The DC or authorized finance staff must verify the remittance.

Example:

Expected:

₦100,000

Submitted:

₦100,000

Verified:

₦100,000

Status:

**Verified**

If there is a difference, the system should show the variance.

---

# 46. Delivery History

The PDA should be able to view completed deliveries.

Each record should show:

* Order ID
* Customer
* Date
* Delivery status
* Product quantity
* Payment status
* Amount collected if applicable

---

# 47. Remittance History

The PDA should be able to view previous remittances.

Each record should show:

* Remittance ID
* Amount
* Payment method
* Date
* Status
* Reference

---

# 48. Stock History

The PDA should be able to see basic stock movements.

Examples:

**Received from Wuse DC**

+20 Grazer Herbal Tea

**Delivered**

-5 Grazer Herbal Tea

**Returned**

-2 Grazer Herbal Tea

This gives the PDA transparency into their stock balance.

---

# 49. Profile

The PDA profile should display:

* Name
* PDA ID
* Phone number
* Assigned Distribution Center
* Assigned Headquarters
* Account status

Example:

**John Doe**

**PDA-00124**

**Wuse Distribution Center**

**Abuja HQ**

---

# 50. PDA Settings

Settings may include:

* Change password
* Notification preferences
* Biometric login
* App information
* Help/support
* Logout

---

# 51. Notifications

The PDA should receive operational notifications for:

* New order assignment
* Order reassignment
* Collection availability
* Delivery reminders
* Failed delivery actions
* Return instructions
* Remittance reminders
* Remittance verification
* Remittance discrepancies
* Important operational announcements

---

# 52. Offline Capability

Because PDAs operate in the field across Nigeria, the application must be designed with unreliable connectivity in mind.

The PDA should be able to access previously synchronized information such as:

* Assigned orders
* Customer information
* Delivery addresses
* Product quantities
* Relevant order status

Where appropriate, actions performed during temporary connectivity loss should be queued for synchronization.

However, sensitive financial transactions must include safeguards against:

* Duplicate submission
* Duplicate delivery confirmation
* Duplicate remittance
* Conflicting updates

The backend remains the final authority.

---

# 53. Duplicate Prevention

The system must prevent a PDA from accidentally performing the same operation twice.

Examples:

A delivered order cannot be delivered again.

A collected order cannot be collected again.

A remittance cannot be submitted twice using the same transaction.

A returned order cannot be returned repeatedly without an authorized new workflow.

---

# 54. PDA Daily Workflow

The ideal daily PDA journey should be:

### Start of Day

PDA logs in.

↓

Reviews Home dashboard.

↓

Views assigned orders.

↓

Travels to DC.

↓

Collects assigned products.

↓

Scans/verifies orders.

↓

PDA inventory updates.

### Delivery

PDA selects next order.

↓

Views customer information.

↓

Calls customer if necessary.

↓

Navigates to customer.

↓

Delivers physical products.

↓

If POD, collects ₦ payment.

↓

If prepaid, confirms delivery.

↓

Delivery completed.

↓

PDA stock updates.

### End of Day

PDA reviews POD collections.

↓

Submits remittance.

↓

DC verifies remittance.

↓

PDA reviews outstanding balance.

---

# 55. Free Product Accountability

This is a critical requirement.

If an order contains:

**5 Grazer Herbal Tea paid**

and:

**1 Grazer Herbal Tea free**

the PDA must receive and deliver:

**6 physical units**

The system must record:

Paid quantity: 5

Free quantity: 1

Physical quantity: 6

The PDA must not be able to mark only 5 units as delivered if the order requires 6 physical units.

Free products must be included in inventory movement and delivery accountability.

---

# 56. Product Extensibility

The PDA application must not be designed specifically around:

* Grazer Herbal Tea
* Respira
* Alpha Man

These are simply the current products.

The interface must dynamically support future products.

For example, if NovaExpress adds another product, the PDA should automatically be able to see it when that product is assigned to an order.

---

# 57. Important PDA Business Rules

### Rule 1

The PDA can only see orders assigned to them.

### Rule 2

A PDA cannot collect an order that has not been authorized for collection.

### Rule 3

Collection must update DC and PDA inventory.

### Rule 4

Every physical product delivered must reduce PDA inventory.

### Rule 5

Free products count toward physical inventory.

### Rule 6

POD orders must display the exact amount expected in ₦.

### Rule 7

The PDA must record the actual amount collected.

### Rule 8

Any collection variance must be recorded and explained.

### Rule 9

Prepaid orders must show ₦0 to collect.

### Rule 10

Failed deliveries require a reason.

### Rule 11

Returned products must be physically reconciled by the DC.

### Rule 12

PDA cash and PDA stock are tracked separately.

### Rule 13

PDA remittances require verification.

### Rule 14

The PDA cannot modify product prices or commercial rules.

### Rule 15

The PDA cannot independently alter inventory balances.

### Rule 16

Every important PDA operation must create an audit record.

---

# 58. PDA Dashboard KPIs

The designer should prioritize the following information:

### Delivery

**Assigned**

**Collected**

**Out for Delivery**

**Delivered**

**Failed**

### Stock

**Total Units**

**Products by Type**

### Cash

**POD Collected**

**Remitted**

**Outstanding**

The dashboard should not become an analytics-heavy screen. It is primarily a **daily action center**.

---

# 59. UX Design Principles

The PDA application should be:

### Fast

A PDA may perform many deliveries in one day.

### Simple

The PDA should not need extensive training.

### Action-oriented

The next required action should always be obvious.

### Mobile-first

The interface must be optimized for Android smartphones commonly used by Nigerian field agents.

### Low-data conscious

Avoid unnecessary large media and network requests.

### Offline-aware

The app should continue to provide useful functionality during poor connectivity.

### Error-resistant

Financial and inventory operations must have strong confirmations.

### Nigerian

Addresses, phone numbers, currency, locations and operational language must feel natural to Nigerian users.

---

# 60. Design Priority

The designer should **not design all PDA screens simultaneously**.

The first design priority should be the core delivery workflow:

**Login**

→ **Home**

→ **Orders**

→ **Order Details**

→ **Collect Order**

→ **Scan**

→ **Delivery**

→ **POD / Non-POD**

→ **Delivery Success**

→ **Cash**

→ **Remittance**

After this workflow is approved, the designer should complete:

**Stock**

→ **History**

→ **Profile**

→ **Settings**

---

# 61. Phase 1 Completion Criteria

Phase 1 PDA design is considered complete when the designer has produced a complete, clickable prototype that demonstrates:

### Order Flow

A PDA can:

* Receive an order
* View the order
* Collect it from a DC
* Verify it
* Deliver it
* Complete a POD delivery
* Complete a prepaid delivery
* Report failed delivery
* Initiate return

### Inventory Flow

A PDA can:

* View stock
* Receive stock
* Deliver stock
* Return stock
* View stock history

### Financial Flow

A PDA can:

* View POD collections
* Record customer payment
* Identify payment variance
* View outstanding cash
* Submit remittance
* View remittance status

### Accountability

The system can trace:

**Order → Product → PDA → Customer → Delivery → Payment → Remittance**

and, where applicable:

**Order → Product → PDA → Failed Delivery → Return → DC**

---

# 62. Phase 1 Design Deliverable

The final Figma deliverable for Phase 1 should contain:

**1. Complete PDA Design System**

**2. Authentication Screens**

**3. PDA Dashboard**

**4. Complete Order Workflow**

**5. Collection Workflow**

**6. QR/Barcode Verification**

**7. POD Workflow**

**8. Non-POD Workflow**

**9. Failed Delivery Workflow**

**10. Return Workflow**

**11. PDA Inventory**

**12. Cash & Remittance**

**13. History**

**14. Profile & Settings**

**15. Empty States**

**16. Loading States**

**17. Error States**

**18. Confirmation States**

**19. Offline/Sync States**

**20. Success States**

The designer should treat **POD payment, physical stock accountability, free-product quantities, and delivery status** as the highest-priority interaction areas because these are where NovaExpress has the greatest operational and financial risk.
