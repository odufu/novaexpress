# 🤝 Workflow 03: Confirming Stock Collection & Physical Handover

This document details the step-by-step physical handover verification process between the Distribution Center (DC) Supervisor and the Delivery Agent, including Security PIN / QR Code verification, batch custody transfer, and atomic inventory updates.

---

## 🎯 Overview & Objectives

* **Primary Goal**: Ensure zero inventory leakage by verifying physical stock transfer at DC through dual-confirmation (Rider Security PIN / QR Code & DC Supervisor confirmation), transferring custody atomically into the rider's vehicle inventory.
* **Primary Actors**: Delivery Agent (*Emeka Rider*), DC Supervisor (*Adekunle Supervisor*), NoveXPS PDA App, Supabase Database (`agent_inventory`, `stock_handovers`, `product_batches`).

---

## 📊 Detailed Workflow Diagram

```mermaid
sequenceDiagram
    autonumber
    actor Rider as 🛵 Emeka Rider (PDA)
    participant App as NoveXPS PDA App
    actor DC as 🏢 DC Supervisor (Wuse DC)
    participant DB as Supabase PostgreSQL

    Rider->>DC: Arrives at DC Warehouse & presents Handover Code (HND-9921)
    DC->>DC: Picks allocated stock boxes (Respira Tea: 20, Grazer Tea: 10)
    Rider->>DC: Inspects physical package seals & verifies item counts
    
    Rider->>App: Opens "Confirm Collection" Modal -> Scans QR / Enters HND-9921
    App->>DB: CALL confirm_stock_handover(p_request_id, p_handover_code, p_agent_id)
    
    alt Code Invalid / Mismatch
        DB-->>App: Return Error ("Invalid Handover Code")
        App-->>Rider: Displays Alert ("Code mismatch. Verify with DC Supervisor.")
    else Code Valid & Confirmed
        DB->>DB: UPDATE stock_handovers SET agent_confirmed = true, confirmed_at = NOW()
        DB->>DB: UPDATE stock_requests SET status = 'handed_over'
        DB->>DB: UPSERT agent_inventory (total_in_custody += 20, available_count += 20)
        DB->>DB: DECREMENT product_batches.current_quantity at DC
        DB-->>App: Success Response (Stock Custody Transferred)
        
        App-->>Rider: Plays Success Haptic/Sound & Updates Vehicle Stock Grazer
        DC-->>Rider: Hands over physical stock boxes for vehicle loading
    end
```

---

## 📑 Step-by-Step Execution Sequence

### Step 1: Arrival & Physical Counting at DC
1. The Rider arrives at the designated Distribution Center (e.g. *Wuse Distribution Center*).
2. Rider opens the **Stock Pickup Notification** in the PDA displaying approved request `REQ-00482` and Security Code `HND-9921`.
3. The DC Supervisor retrieves the pre-picked package items:
   * **Box 1**: 20 units of *Respira Detox Tea* (Batch `BATCH-RSP-2026`).
   * **Box 2**: 10 units of *Grazer Herbal Tea* (Batch `BATCH-GRZ-2026`).
4. Both parties perform a physical count and verify package seals.

### Step 2: Verification Input on Mobile PDA
1. Rider taps **[ Confirm Collection ]** on the PDA screen.
2. The PDA presents two verification methods:
   * **Option A**: Scan QR Code displayed on DC Supervisor’s terminal screen.
   * **Option B**: Enter 6-digit Handover Security Code `HND-9921`.
3. Rider submits the code.

### Step 3: Atomic Backend Execution (`confirm_stock_handover`)
1. The app invokes the atomic stored procedure:
   ```sql
   SELECT confirm_stock_handover(
       p_request_id := 'req-uuid-00482',
       p_handover_code := 'HND-9921',
       p_agent_id := 'agent-uuid-7000'
   );
   ```
2. The database executes in a single transaction block:
   * Validates `stock_requests.status == 'approved'`.
   * Verifies `handover_code == 'HND-9921'`.
   * Marks `stock_handovers`: `agent_confirmed = true`, `supervisor_confirmed = true`, `confirmed_at = NOW()`.
   * Updates `stock_requests.status = 'handed_over'`.
   * Updates `agent_inventory`:
     ```sql
     INSERT INTO agent_inventory (delivery_agent_id, product_id, batch_id, total_in_custody, available_count)
     VALUES ('agent-uuid', 'product-uuid', 'batch-uuid', 20, 20)
     ON CONFLICT (delivery_agent_id, product_id) DO UPDATE
     SET total_in_custody = agent_inventory.total_in_custody + EXCLUDED.total_in_custody,
         available_count = agent_inventory.available_count + EXCLUDED.available_count;
     ```
   * Deducts quantity from DC warehouse batch `product_batches.current_quantity`.

### Step 4: UI Hydration & Stock Grazer Update
1. The PDA screen updates with a green success checkmark animation.
2. The vehicle inventory widget on the **PDA Home Page** immediately increments:
   * *Respira Detox Tea*: 20 in custody (20 Available)
   * *Grazer Herbal Tea*: 10 in custody (10 Available)
3. Rider loads the boxes into their motorcycle/van cargo box and proceeds to delivery routes.

---

## 🛑 Edge Cases & Discrepancy Resolution

| Discrepancy / Issue | Handling Procedure |
|---|---|
| **Damaged / Expired Bins at Handover** | DC Supervisor updates `approved_quantity` on DC portal before handover confirmation. Inventory update adjusts to physical count actually accepted by rider. |
| **Network Outage at Warehouse** | Offline verification code is saved locally in SQLite action queue and synchronized automatically upon reconnecting to network. |
| **Incorrect Batch Handed Over** | Handover transaction logs exact `batch_id` to maintain lot traceability in case of manufacturer product recalls. |
