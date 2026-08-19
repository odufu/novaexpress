# NovaExpress PDA App — Inventory Screen

The **Inventory module** is the PDA's stock-custody center.

It should answer five questions:

> **What stock do I currently have?**
> **Who owns it?**
> **What is available for delivery?**
> **What stock is coming to me?**
> **What stock have I received, delivered, returned, damaged, or lost?**

For NovaExpress, this is especially important because a PDA may hold **client-owned distributed inventory** such as **Respira, Grazer Herbal Tea and Alpha Man** and can request additional stock from **any authorized Distribution Center**.

---

# 1. Inventory Module Structure

```text
INVENTORY
│
├── My Inventory
│   ├── Inventory Summary
│   ├── Product List
│   └── Product Details
│
├── Request Stock
│   ├── Select Distribution Center
│   ├── Select Products
│   ├── Enter Quantities
│   ├── Review Request
│   └── Request Status
│
├── Stock Handover
│   ├── Pending Handover
│   ├── Verify Items
│   ├── Scan / Manual Verification
│   └── Handover Confirmation
│
├── Inventory Reconciliation
│   ├── Audit Summary
│   ├── Count Items
│   ├── Record Variance
│   └── Submit Audit
│
└── Inventory History
    ├── Received
    ├── Delivered
    ├── Returned
    ├── Damaged
    ├── Adjusted
    └── Transferred
```

---

# 2. MY INVENTORY — MAIN SCREEN

This should be the **default screen** when the PDA taps Inventory.

The screen should not feel like a warehouse-management dashboard.

It is specifically:

> **My current stock in custody.**

---

# 3. Header

Display:

### My Inventory

Under it:

**PDA-0042 • John**

Optionally:

**Current location / assigned zone**

On the right:

* Inventory audit icon
* More/filter icon

---

# 4. INVENTORY SUMMARY

At the top, show the most important numbers.

For example:

```text
TOTAL STOCK
87 units

RESERVED
12 units

AVAILABLE
75 units
```

The distinction is very important.

### Total

Everything physically recorded as being in the PDA's custody.

### Reserved

Units already allocated to pending deliveries.

### Available

Units the PDA can still use for new deliveries.

Conceptually:

**Available = Total − Reserved − Other restricted stock**

---

# 5. LOW STOCK ALERT

If an item falls below its configured threshold:

### ⚠️ Low Stock

**Respira**

Only **3 units available**

**Reorder level: 5**

CTA:

**Request Stock**

This should take the PDA directly into the stock-request flow.

---

# 6. ACTIVE CUSTODY

This is the main inventory list.

Each product card should show:

### Respira

**Novacare Limited**

Total:

**42 units**

Reserved:

**8**

Available:

**34**

The PDA should immediately know:

> "I physically have 42 units, but only 34 are currently free to allocate."

---

# 7. PRODUCT CARD

Recommended information:

```text
RESPIRA
Novacare Limited

Total          42
Reserved        8
Available      34

SKU-RSP01
```

Optional:

* Low-stock indicator
* Batch
* Expiry, if applicable
* Last received date

Tap the card to open **Product Inventory Details**.

---

# 8. CLIENT OWNERSHIP MUST BE VISIBLE

This is particularly important for NovaExpress.

Instead of simply:

> Respira — 42

show:

> **Respira**
> **Owner: Novacare Limited**

Because the PDA is not necessarily the owner of the stock.

The system is recording:

> **Stock physically in PDA custody**

not:

> **PDA-owned stock**

---

# 9. INVENTORY TYPES

The PDA may have different kinds of stock.

The system should identify them.

For example:

### Distributed Inventory

**Respira — Novacare Limited**

or:

### NovaExpress Inventory

**Packaging Materials**

This prevents different ownership models from becoming mixed together.

---

# 10. STOCK POSITION

A useful summary section can show:

| Position            | Quantity |
| ------------------- | -------: |
| Total in Custody    |       87 |
| Reserved            |       12 |
| Available           |       75 |
| Awaiting Return     |        3 |
| Under Investigation |        1 |

The exact categories should depend on the system's inventory state model.

---

# 11. INBOUND STOCK

The main Inventory screen should show if stock is coming to the PDA.

Example:

### Incoming Stock

**Stock Request #REQ-00482**

From:

**Wuse Distribution Center**

Status:

**Ready for Collection**

Items:

* Respira × 10
* Grazer Herbal Tea × 20

CTA:

**View Request**

This is much more useful than forcing the PDA to constantly open Request Stock to see whether their request has been fulfilled.

---

# 12. RETURNS

The inventory screen should also surface outstanding returns.

Example:

### Returns

**3 items awaiting return**

**Respira × 2**

**Grazer Herbal Tea × 1**

Return to:

**Wuse Distribution Center**

CTA:

**Process Returns**

This prevents returned stock from simply sitting in the PDA's inventory indefinitely.

---

# 13. INVENTORY AUDIT STATUS

The system should show whether the PDA's inventory needs reconciliation.

Example:

### Inventory Audit

**Last audited: Today, 08:30 AM**

Status:

**Audit Required**

CTA:

**Start Inventory Audit**

Or:

**Inventory Reconciled ✓**

This is important because inventory custody needs to be periodically verified.

---

# 14. MAIN INVENTORY SCREEN — RECOMMENDED STRUCTURE

I would structure the screen roughly as:

```text
┌──────────────────────────────┐
│ ← My Inventory          ⋮    │
│ PDA-0042 • John              │
├──────────────────────────────┤
│ INVENTORY SUMMARY             │
│                              │
│ Total       Reserved Available│
│ 87          12       75       │
├──────────────────────────────┤
│ ⚠ LOW STOCK                  │
│ Respira — 3 available        │
│ [Request Stock]              │
├──────────────────────────────┤
│ ACTIVE CUSTODY         See All│
│                              │
│ Respira                      │
│ Novacare Limited             │
│ Total 42 | Reserved 8        │
│ Available 34                 │
│                              │
│ Grazer Herbal Tea             │
│ Novacare Limited             │
│ Total 18 | Reserved 4        │
│ Available 14                 │
│                              │
│ Alpha Man                    │
│ Novacare Limited             │
│ Total 3 | Reserved 0         │
│ Available 3                  │
├──────────────────────────────┤
│ INBOUND                      │
│ REQ-00482                    │
│ From Wuse DC                 │
│ Ready for Collection         │
├──────────────────────────────┤
│ RETURNS                      │
│ 3 items awaiting return      │
│ [Process Returns]            │
├──────────────────────────────┤
│ INVENTORY AUDIT              │
│ Last audit: 08:30 AM         │
│ [Start Inventory Audit]      │
└──────────────────────────────┘
```

---

# 15. PRODUCT INVENTORY DETAILS

When the PDA taps **Respira**, open:

### Respira

**Owner: Novacare Limited**

**SKU: SKU-RSP01**

Then show:

### Stock Position

**Total:** 42

**Reserved:** 8

**Available:** 34

---

# 16. PRODUCT MOVEMENT

Show how the quantity got to its current state.

Example:

```text
Received from Wuse DC       +20
Delivered                    -5
Returned                     +2
Reserved                     -8
Adjustment                   -1
--------------------------------
Current                     42
```

This is extremely useful when there is an inventory dispute.

---

# 17. PRODUCT HISTORY

The PDA should be able to see:

### Received

+20

**From Wuse DC**

### Delivered

-2

**Order NX-00482**

### Returned

+1

**Order NX-00471**

### Damaged

-1

**Reported 17 Aug**

Each movement should have a reference ID.

---

# 18. REQUEST STOCK

This should be a prominent action from Inventory.

CTA:

**Request Stock**

But the first thing the PDA must select is:

# Distribution Center

Because a registered PDA can restock from **any authorized DC**.

Example:

### Select Distribution Center

* Wuse Distribution Center
* Garki Distribution Center
* Kubwa Distribution Center
* Ikeja Distribution Center

The system should only show DCs from which the PDA is permitted to request stock.

---

# 19. WHY SELECTING THE DC IS IMPORTANT

The stock request should explicitly record:

> **PDA → Requested DC → Product → Quantity**

For example:

```text
Request #REQ-00482

Requester:
PDA-0042 — John

Fulfillment DC:
Wuse Distribution Center

Products:
Respira × 10
Grazer Herbal Tea × 20
Alpha Man × 5
```

The selected DC then receives the request in its own system.

---

# 20. REQUEST STOCK — PRODUCT SELECTION

After selecting the DC:

### Request Inventory

**Respira**

Current available: 3

Request:

**10**

---

**Grazer Herbal Tea**

Current available: 14

Request:

**20**

---

**Alpha Man**

Current available: 3

Request:

**10**

CTA:

**Review Request**

---

# 21. REQUEST REVIEW

Before submission:

### Stock Request

**From:** PDA-0042 John

**To:** Wuse Distribution Center

| Product           | Requested |
| ----------------- | --------: |
| Respira           |        10 |
| Grazer Herbal Tea |        20 |
| Alpha Man         |        10 |

CTA:

**Submit Request**

---

# 22. REQUEST STATUS

After submission:

### Pending DC Approval

**REQ-00482**

Wuse Distribution Center

Requested:

* Respira × 10
* Grazer × 20
* Alpha Man × 10

Status:

**Awaiting DC Review**

---

# 23. PARTIAL APPROVAL

The system must support partial fulfillment.

Example:

Requested:

**Respira × 10**

DC only has:

**6**

DC approves:

**6**

The PDA sees:

```text
Requested: 10
Approved: 6
Shortfall: 4
```

Status:

**Partially Approved**

This is much better than forcing the DC to either approve everything or reject everything.

---

# 24. STOCK HANDOVER

When the request is ready:

### Stock Handover

**REQ-00482**

From:

**Wuse Distribution Center**

To:

**PDA-0042 — John**

Then:

### Expected Items

Respira × 10

Grazer Herbal Tea × 20

Alpha Man × 5

The PDA verifies what they physically receive.

---

# 25. SCANNING / MANUAL VERIFICATION

The handover should support:

### Scan Items

The PDA can scan the product/package barcode.

The system verifies:

> Expected: 10
> Scanned: 10 ✓

If:

Expected: 10

Scanned: 9

show:

> **Quantity discrepancy: 1 unit**

The PDA should not be able to silently accept the wrong quantity.

---

# 26. HANDOVER CONFIRMATION

After verification:

### Confirm Stock Received

**10 Respira**

**20 Grazer Herbal Tea**

**5 Alpha Man**

Received by:

**John — PDA-0042**

Issued by:

**DC Staff**

CTA:

**Confirm Handover**

Once confirmed, the PDA's inventory increases.

---

# 27. INVENTORY RECONCILIATION

This is the PDA's physical stock audit.

The system compares:

> **Expected System Quantity**

against:

> **Physical Quantity**

Example:

### Respira

System expects:

**42**

Physical count:

**42**

✓ Reconciled

---

### Grazer Herbal Tea

System expects:

**30**

Physical:

**28**

⚠ Variance: **-2**

---

# 28. VARIANCE REASON

If there is a discrepancy, the PDA must provide a reason.

Options:

* Damaged
* Missing
* Delivery not recorded
* Return not recorded
* Incorrect handover
* System error
* Other

For "Other":

**Reason required**

---

# 29. INVENTORY AUDIT SUBMISSION

At the end:

### Audit Summary

```text
15 SKUs
12 Reconciled
2 Variances
1 Pending
```

CTA:

**Submit Inventory Audit**

The system records:

* Agent
* Date/time
* Expected quantity
* Physical quantity
* Variance
* Reasons
* Evidence where required

---

# 30. INVENTORY HISTORY

This is the audit trail for the PDA.

Filters:

### All

### Received

Stock received from DC.

### Delivered

Stock consumed by successful deliveries.

### Returned

Stock returned from failed deliveries.

### Damaged

Stock marked damaged.

### Adjusted

Authorized inventory adjustments.

---

# 31. INVENTORY HISTORY CARD

Example:

### Respira

**+10 units**

Received from:

**Wuse Distribution Center**

**Today • 10:42 AM**

Reference:

**STK-00482**

---

Another:

### Respira

**-2 units**

Delivered:

**NX-00482**

**Today • 2:14 PM**

---

Another:

### Respira

**+2 units**

Returned:

**NX-00471**

**Today • 4:02 PM**

---

# 32. IMPORTANT INVENTORY RULE

The PDA should never simply see:

> Respira: 42

and have the number magically change.

Every change should come from a recognized inventory event:

```text
Received
+
Delivered
-
Returned
+
Damaged
-
Adjustment
+/-
Transfer/Handover
```

This creates a reliable inventory ledger.

---

# 33. INVENTORY STATES

For each unit/product, the system should conceptually support:

```text
IN PDA CUSTODY
│
├── Available
├── Reserved
├── Out for Delivery
├── Delivered
├── Awaiting Return
├── Returned
├── Damaged
└── Under Investigation
```

This is more powerful than just storing one quantity.

---

# 34. WHAT THE PDA SHOULD NOT DO

The PDA should **not** be able to manually:

* Increase inventory
* Reduce inventory
* Change product ownership
* Change stock value
* Transfer stock to another PDA
* Delete inventory history
* Modify a completed handover

Instead, inventory changes must happen through controlled events.

For example:

**Receive Stock**

**Deliver Product**

**Return Product**

**Report Damage**

**Authorized Adjustment**

---

# 35. IMPORTANT RELATIONSHIP WITH DELIVERIES

The Inventory module and Delivery module must be tightly connected.

When a PDA successfully delivers:

**Respira × 2**

Inventory automatically changes:

**42 → 40**

and the inventory history gets:

> **-2 — Delivery NX-00482**

When a failed delivery is returned:

**40 → 42**

and history gets:

> **+2 — Return NX-00482**

The PDA should never have to manually adjust those quantities.

---

# 36. IMPORTANT RELATIONSHIP WITH REMITTANCE

For POD distributed inventory:

```text
Inventory
   ↓
Product delivered
   ↓
Customer pays
   ↓
Cash collected
   ↓
Remittance liability created
```

So a single delivery can affect **both inventory and finance**.

For example:

**Respira × 2 delivered**

causes:

* Inventory decreases by 2
* Delivery becomes successful
* Customer payment recorded
* PDA commission calculated
* Transport allowance calculated
* Expected remittance generated

This is why the Inventory module must not be designed as an isolated warehouse feature.

---

# 37. FINAL INVENTORY SCREEN SET FOR DESIGN

For the PDA, I recommend these major screens:

### Core Inventory

1. **My Inventory**
2. **Product Inventory Details**
3. **Inventory History**

### Stock Request

4. **Select Distribution Center**
5. **Request Stock**
6. **Review Stock Request**
7. **Stock Request Details / Status**

### Stock Collection

8. **Stock Handover**
9. **Scan / Verify Items**
10. **Handover Confirmation**

### Reconciliation

11. **Inventory Audit**
12. **Inventory Variance**
13. **Audit Summary / Submission**

### Returns

14. **Returns**
15. **Return Details**
16. **Return Handover**

Again, these do **not** necessarily mean 16 completely independent visual screens. Several can be states, modals, bottom sheets, or steps within a flow.

---

# 38. THE INVENTORY MODULE'S CORE PURPOSE

For the PDA, the entire module should revolve around this lifecycle:

**REQUEST → RECEIVE → HOLD → RESERVE → DELIVER → RETURN → RECONCILE**

And the system should always be able to answer:

> **"At this exact moment, how many units of each client's product are physically in this PDA's custody, where did they come from, what are they reserved for, and what happened to every unit that left?"**

That is the standard the Inventory UI should be designed around.
