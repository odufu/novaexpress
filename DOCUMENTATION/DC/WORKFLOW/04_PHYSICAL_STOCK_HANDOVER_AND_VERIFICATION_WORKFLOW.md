# 🤝 DC Workflow 04: Physical Stock Handover & Verification

This document details the dual-verification physical stock handover procedure at DC dispatch counters, QR/PIN validation, atomic custody transfer, and inventory database updates.

---

## 🎯 Overview & Objectives

* **Primary Goal**: Execute physical handover of picked inventory from DC warehouse custody to field delivery agent custody, ensuring 100% agreement on item counts and zero unrecorded inventory movement.
* **Primary Actors**: DC Supervisor (*Adekunle Supervisor*), Delivery Agent (*Emeka Rider*), NoveXPS DC Portal, PostgreSQL Stored Procedure (`confirm_stock_handover`).
* **Database Tables**: `agent_inventory`, `stock_handovers`, `stock_requests`, `product_batches`.

---

## 📊 Detailed Workflow Diagram

```mermaid
sequenceDiagram
    autonumber
    actor Rider as 🛵 Emeka Rider (PDA-7000)
    actor Supervisor as 🏢 Adekunle Supervisor (DC Counter #2)
    participant Portal as NoveXPS DC Portal
    participant DB as Supabase PostgreSQL

    Rider->>Supervisor: Arrives at Counter #2 & displays Handover Code (HND-9921)
    Supervisor->>Supervisor: Presents physical boxes (Respira Tea: 20, Grazer Tea: 10)
    Rider->>Supervisor: Counts items & verifies package seals
    
    Supervisor->>Portal: Opens "Confirm Handover" Screen -> Inputs HND-9921
    Portal->>DB: CALL confirm_stock_handover('req-uuid-00482', 'HND-9921', 'agent-uuid-7000')
    
    DB->>DB: UPDATE stock_handovers SET supervisor_confirmed = true, agent_confirmed = true
    DB->>DB: UPDATE stock_requests SET status = 'handed_over'
    DB->>DB: UPSERT agent_inventory (total_in_custody += 20, available_count += 20)
    DB->>DB: DECREMENT product_batches.current_quantity at DC
    
    DB-->>Portal: Handover Execution Successful
    Portal-->>Supervisor: Displays Green Success Screen & Prints Receipt
    DB-->>Rider: Real-Time PDA Update: "Stock Custody Transferred (+30 items)"
    Supervisor-->>Rider: Hands over boxes for vehicle loading
```

---

## 📑 Step-by-Step Execution Sequence

### Step 1: Counter Verification & Item Inspection
1. Rider presents Handover Security Code `HND-9921` on PDA screen at **Dispatch Counter #2**.
2. Supervisor locates staged boxes:
   * **Box 1**: 20 units of *Respira Detox Tea* (Batch `BATCH-RSP-2026`).
   * **Box 2**: 10 units of *Grazer Herbal Tea* (Batch `BATCH-GRZ-2026`).
3. Rider and Supervisor perform a joint physical count and inspect box tamper seals.

### Step 2: Handover Confirmation Input
1. Supervisor enters `HND-9921` into the **Handover Verification Screen** on the DC Portal (or scans rider’s PDA screen QR code).
2. Taps **[ Confirm Physical Handover ]**.

### Step 3: Atomic Stored Procedure Execution
1. System executes stored procedure `confirm_stock_handover`:
   ```sql
   SELECT confirm_stock_handover(
       p_request_id := 'req-uuid-00482',
       p_handover_code := 'HND-9921',
       p_agent_id := 'agent-uuid-7000'
   );
   ```
2. Database atomic changes:
   * `stock_handovers`: `supervisor_confirmed = true`, `agent_confirmed = true`, `confirmed_at = NOW()`.
   * `stock_requests.status` updated to `'handed_over'`.
   * `agent_inventory`: `total_in_custody` and `available_count` incremented for rider.
   * `product_batches.current_quantity`: decremented at DC warehouse.

### Step 4: Loading & Dispatch
1. Portal displays green checkmark confirmation.
2. Rider’s PDA vehicle stock grazer updates immediately via WebSocket CDC.
3. Rider loads boxes into motorcycle cargo box and departs for delivery route.

---

## 🛑 Discrepancy Protocol

| Scenario | Action Required |
|---|---|
| **Damaged Pack Found at Counter** | Supervisor removes damaged pack, edits handover quantity on portal from 20 to 19 before code validation. Database updates custody for 19 units. |
| **Code Mismatch / Invalid PIN** | Portal displays red error banner. Supervisor re-checks active request queue to ensure correct code entry. |
