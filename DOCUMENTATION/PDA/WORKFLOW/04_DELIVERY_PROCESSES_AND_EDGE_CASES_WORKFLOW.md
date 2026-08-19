# 🚚 Workflow 04: Delivery Execution, Payment Scenarios & Edge Cases

This document provides a comprehensive step-by-step operational guide for field delivery execution, covering Cash on Delivery (COD), Monnify Direct Bank Transfers, Upsells, Rescheduling/Callbacks, and Delivery Failures.

---

## 🎯 Overview & Objectives

* **Primary Goal**: Guide delivery agents through end-to-end customer order fulfillment, instant payment collection, proof-of-delivery (POD) capture, upsell handling, and failed delivery classification.
* **Primary Actors**: Delivery Agent (*Emeka Rider*), Customer (*Chief Aliyu Mohammed*), NoveXPS PDA App, Edge Functions (`confirm-delivery-pod`, `monnify-webhook`, `log-delivery-failure`), Supabase DB.

---

## 📊 Master Delivery Lifecycle Diagram

```mermaid
stateDiagram-v2
    [*] --> InTransit: Rider accepts order assignment
    InTransit --> COD_Success: Customer pays cash -> POD captured
    InTransit --> Monnify_Transfer: Customer transfers via Virtual Account
    InTransit --> Upsell_Added: Customer requests extra items
    InTransit --> Callback: Customer requests rescheduled time
    InTransit --> Delivery_Failed: Customer rejects / Unreachable

    COD_Success --> Inventory_Decremented: Decrement stock, Increment COD Cash Balance (+₦55,000)
    Monnify_Transfer --> Monnify_Webhook: Monnify Webhook verifies -> Order Delivered
    Upsell_Added --> COD_Success: Recalculate total & collect payment
    Callback --> InTransit: Re-scheduled for callback time
    Delivery_Failed --> Awaiting_Return: Tag item for DC Return

    Inventory_Decremented --> [*]
    Monnify_Webhook --> [*]
    Awaiting_Return --> [*]
```

---

## 📑 Detailed Delivery Sub-Workflows

### Case 4.1: Cash on Delivery (COD) Successful Delivery

```mermaid
sequenceDiagram
    autonumber
    actor Rider as 🛵 Emeka Rider
    participant App as NoveXPS PDA App
    participant Edge as Edge Function (confirm-delivery-pod)
    participant DB as Supabase PostgreSQL

    Rider->>App: Opens Order TRK-8924 -> Tap "[ Complete Delivery ]"
    Rider->>App: Selects Payment Method: "Cash on Delivery"
    Rider->>App: Collects ₦55,000 cash from customer
    Rider->>App: Captures Customer Signature & POD Photo
    
    App->>Edge: POST /confirm-delivery-pod
    Edge->>DB: CALL confirm_delivery_pod(order_id, agent_id, 'cash', 55000)
    
    DB->>DB: UPDATE orders SET status = 'delivered', payment_status = 'collected'
    DB->>DB: UPDATE delivery_agents SET current_cod_balance += 55000
    DB->>DB: UPDATE agent_inventory (total_in_custody -= 3, delivered_count_today += 3)
    DB->>DB: INSERT INTO rider_transactions (category = 'earnings', amount = 2500)
    
    DB-->>Edge: 200 OK (COD Processed Successfully)
    Edge-->>App: Success Response
    App-->>Rider: Displays Green Success Card & Updates COD Balance Hero Widget
```

#### Step-by-Step Execution:
1. Rider arrives at customer address (e.g. *Plot 402 Aminu Kano Crescent, Wuse 2, Abuja*).
2. Rider opens active order card `TRK-8924` (Customer: *Chief Aliyu Mohammed*, Item: *Respira Detox Tea*, Quantity: `3`, Total Amount: `₦55,000.00`).
3. Customer inspects package and hands over physical cash (`₦55,000.00`).
4. Rider taps **[ Complete Delivery ]** on PDA screen.
5. Selects **Payment Method: Cash on Delivery**.
6. Takes a photo of signed delivery receipt or package handover (uploaded to Supabase Storage `pod-proofs` bucket).
7. PDA calls Edge Function `confirm-delivery-pod`.
8. Edge Function atomically updates database:
   * `orders.status` set to `'delivered'`.
   * `orders.payment_status` set to `'collected'`.
   * `delivery_agents.current_cod_balance` incremented by `+₦55,000.00`.
   * `agent_inventory.total_in_custody` decremented by `3` units.
   * `agent_inventory.delivered_count_today` incremented by `3` units.
   * Rider entitlement created in `rider_transactions`: `+₦2,500.00` (₦1,000 commission + ₦1,500 transport allowance).

---

### Case 4.2: Monnify Direct Bank Transfer / Virtual Account Payment

```mermaid
sequenceDiagram
    autonumber
    actor Customer as 👤 Customer (Dr. Aisha)
    actor Rider as 🛵 Emeka Rider
    participant App as NoveXPS PDA App
    participant Monnify as Monnify Payment Gateway
    participant Webhook as Edge Function (monnify-webhook)
    participant DB as Supabase PostgreSQL

    Rider->>App: Selects Payment Method: "Direct Bank Transfer"
    App->>DB: SELECT account_number FROM monnify_virtual_accounts WHERE order_id = TRK-8925
    DB-->>App: Returns Dynamic Account (Wema Bank • 7890892501 • ₦35,000)
    App-->>Rider: Displays Account Details & QR Code on PDA Screen
    Rider-->>Customer: Shows Bank Account Number for Mobile App Transfer
    
    Customer->>Monnify: Executes Bank Transfer (₦35,000)
    Monnify->>Webhook: POST /monnify-webhook (payload: transactionReference, amountPaid)
    Webhook->>DB: Verify amount & UPDATE orders SET status = 'delivered', payment_status = 'transferred'
    Webhook->>DB: Credit rider_transactions (+₦2,500 entitlement to direct_transfer_balance)
    
    DB-->>App: Real-time WebSocket Event: "Payment Verified via Monnify!"
    App-->>Rider: Plays Success Chime & Updates Order Status to Delivered
```

#### Step-by-Step Execution:
1. Customer requests to pay via Instant Bank Transfer.
2. Rider selects **Payment Method: Direct Transfer**.
3. PDA displays dynamic virtual account generated specifically for order `TRK-8925`:
   * **Bank Name**: Wema Bank / Monnify
   * **Account Number**: `7890892501`
   * **Account Name**: `NovaExpress / Novacare`
   * **Amount Expected**: `₦35,000.00`
4. Customer transfers `₦35,000.00` using their bank app.
5. Monnify sends real-time webhook notification to `monnify-webhook` Edge Function.
6. Edge Function validates payment match and updates order `payment_status = 'transferred'` and `status = 'delivered'`.
7. Rider does **NOT** collect physical cash; instead, rider entitlement (`₦2,500.00`) is credited directly to rider’s **My Balance** (`direct_transfer_balance`).

---

### Case 4.3: On-Site Upsell / Additional Product Purchase

```mermaid
sequenceDiagram
    autonumber
    actor Rider as 🛵 Emeka Rider
    participant App as NoveXPS PDA App
    participant DB as Supabase PostgreSQL

    Customer-->>Rider: "Can I add 1 extra pack of Grazer Herbal Tea?"
    Rider->>App: Opens Order TRK-8924 -> Tap "[ + Add Upsell Item ]"
    App->>App: Checks Vehicle Stock Grazer (Grazer Tea available = 10)
    Rider->>App: Selects Grazer Tea (Qty: 1, Price: ₦15,000)
    
    App->>App: Recalculates Total Amount (₦45,000 + ₦15,000 = ₦60,000)
    App->>DB: UPDATE orders SET quantity = 4, upsell_amount = 15000, total_amount = 60000
    App-->>Rider: Displays Updated Total (₦60,000) & Collects Payment
```

#### Step-by-Step Execution:
1. During delivery, customer expresses interest in purchasing an additional product item.
2. Rider taps **[ + Add Upsell Item ]** on the order screen.
3. App queries local stock grazer to verify available item in rider vehicle custody (`agent_inventory.available_count >= requested_qty`).
4. Rider adds item (e.g. +1 *Grazer Herbal Tea* @ `₦15,000.00`).
5. Order total is updated dynamically from `₦45,000.00` to `₦60,000.00`.
6. Additional rider upsell commission is logged.

---

### Case 4.4: Reschedule / Customer Requested Callback

1. If customer is in a meeting or unavailable, rider taps **[ Reschedule / Call Back ]**.
2. Selects scheduled callback date and time (e.g. *Today @ 4:30 PM*).
3. Adds reschedule note (e.g. *"Customer requested callback at 4:30 PM after office meeting"*).
4. App updates order status to `call_back`.
5. Order moves to **Scheduled Callbacks** tab; item remains in vehicle custody.

---

### Case 4.5: Delivery Failure & Customer Rejection

```mermaid
sequenceDiagram
    autonumber
    actor Rider as 🛵 Emeka Rider
    participant App as NoveXPS PDA App
    participant Edge as Edge Function (log-delivery-failure)
    participant DB as Supabase PostgreSQL

    Rider->>App: Customer Refuses Order -> Tap "[ Log Delivery Failure ]"
    App->>App: Selects Reason: "Customer Rejected - Price Dispute"
    Rider->>App: Adds Failure Notes & Submits
    
    App->>Edge: POST /log-delivery-failure
    Edge->>DB: CALL log_delivery_failure(order_id, agent_id, reason, notes)
    
    DB->>DB: UPDATE orders SET status = 'failed'
    DB->>DB: UPDATE agent_inventory (reserved_count -= 1, awaiting_return_count += 1)
    DB->>DB: INSERT INTO stock_returns (status = 'submitted', reason = 'customer_rejected')
    
    DB-->>Edge: 200 OK (Failure Logged & Return Ticket Created)
    Edge-->>App: Success Response
    App-->>Rider: Removes Order from Active List & Tags Item as "Awaiting Return"
```

#### Step-by-Step Execution:
1. Customer refuses delivery or address is invalid after multiple calls.
2. Rider taps **[ Log Delivery Failure ]**.
3. Selects Failure Reason:
   * `customer_rejected` (Price dispute / Changed mind)
   * `unreachable` (Phone switched off after 3 attempts)
   * `wrong_address` (Address non-existent)
   * `damaged_on_arrival`
4. Adds detailed notes and submits.
5. Edge Function `log-delivery-failure` updates order status to `failed`.
6. Item custody is moved in `agent_inventory`:
   * `reserved_count` decremented by `1`.
   * `awaiting_return_count` incremented by `1`.
7. Auto-generates a pending return record in `stock_returns` (`RET-XXXXX`) for handover back to DC.

### Case 4.6: Client Pre-Packaged Delivery Fulfillment (`client_package`)

```mermaid
sequenceDiagram
    autonumber
    actor Rider as 🛵 Emeka Rider
    participant App as NoveXPS PDA App
    participant DB as Supabase PostgreSQL

    Note over Rider,App: Pre-Packaged Order with Tracking No (PKG-NOV-8821)
    Rider->>App: Scans Barcode on Physical Client Parcel (PKG-NOV-8821)
    App->>DB: SELECT * FROM client_packages WHERE tracking_number = 'PKG-NOV-8821'
    DB-->>App: Returns Package Details (Client: Novacare, Declared Value: ₦25,000, Fee: ₦3,500)
    
    Rider->>App: Hands over package to customer & collects POD signature
    Rider->>App: Submits Delivery Confirmation
    
    App->>DB: UPDATE client_packages SET status = 'delivered'
    App->>DB: UPDATE orders SET status = 'delivered'
    App->>DB: INSERT INTO rider_transactions (category = 'earnings', amount = 2500)
    
    DB-->>App: 200 OK (Client Package Delivery Completed)
    App-->>Rider: Displays Package Delivered Checkmark
```

#### Step-by-Step Execution:
1. For merchant-specific pre-packaged parcels (`fulfillment_type = 'client_package'`), items are not deducted from vehicle bulk product stock.
2. Rider scans or inputs the unique package tracking number `PKG-NOV-8821`.
3. Collects customer signature / proof of delivery photo.
4. Database updates `client_packages.status = 'delivered'` and logs rider entitlement.

---

## 🛑 Summary Matrix of Delivery Scenarios

| Scenario | Fulfillment Type | Payment Collected | Order Status | COD Balance | Rider My Balance | Inventory / Package Action |
|---|:---:|:---:|:---:|:---:|:---:|---|
| **COD Delivery** | `distributed_inventory` | ₦55,000 Cash | `delivered` | **+₦55,000** | +₦2,500 | `agent_inventory.total_in_custody` decremented |
| **Monnify Transfer** | `distributed_inventory` | ₦35,000 Bank | `delivered` | ₦0 | **+₦35,000** | `agent_inventory.total_in_custody` decremented |
| **Client Pre-Package** | `client_package` | ₦0 (Prepaid) / Cash | `delivered` | +Cash (if COD) | +₦2,500 | `client_packages.status = 'delivered'` |
| **Upsell Delivery** | `distributed_inventory` | ₦60,000 Cash | `delivered` | **+₦60,000** | +₦3,000 | Total items decremented |
| **Call Back / Reschedule** | Either | ₦0 | `call_back` | ₦0 | ₦0 | Retained in custody |
| **Delivery Failure** | `distributed_inventory` | ₦0 | `failed` | ₦0 | ₦0 | Tagged `awaiting_return_count` |

