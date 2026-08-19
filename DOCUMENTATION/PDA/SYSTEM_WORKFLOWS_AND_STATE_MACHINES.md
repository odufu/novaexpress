# NovaExpress PDA — System Workflows & State Machines

This document outlines the core business workflows, transaction state machines, and sequence diagrams governing the NovaExpress PDA ecosystem.

---

## 1. End-of-Delivery Payment & POD Workflow

```mermaid
sequenceDiagram
    autonumber
    actor Customer
    actor Rider as Emeka Rider (PDA)
    participant App as NoveXPS App
    participant DB as Supabase PostgreSQL
    participant Monnify as Monnify Webhook
    participant DC as Wuse DC Finance

    Rider->>Customer: Arrives at delivery address
    Rider->>App: Opens Order Details (TRK-8924)
    Rider->>Customer: Presents product package

    alt Cash Payment (Pay on Delivery)
        Customer->>Rider: Hands physical cash (₦55,000)
        Rider->>App: Selects "Cash Collection (POD)"
        Rider->>App: Captures recipient signature / photo
        Rider->>App: Taps "Confirm & Complete Delivery"
        App->>DB: RPC confirm_delivery_pod(order_id, 'pay_on_delivery', ₦55,000)
        DB-->>DB: Update order status -> 'delivered'
        DB-->>DB: Increment rider COD balance (To Remit: +₦55,000)
        DB-->>DB: Deduct product from vehicle custody
        DB-->>App: Return success confirmation
        App-->>Rider: Displays Green POD Success confirmation
    else Direct Transfer (Monnify Dedicated Virtual Account)
        Customer->>App: Scans / Copies Monnify NUBAN (7890892401)
        Customer->>Customer: Performs Bank Mobile App Transfer (₦55,000)
        Monnify->>DB: Webhook: monnify_transactions (Payment Verified)
        DB-->>DB: Update order payment_status -> 'transferred'
        Rider->>App: Selects "Direct Transfer (Monnify)"
        App->>DB: Check Monnify status (Verified)
        App->>DB: RPC confirm_delivery_pod(order_id, 'monnify_transfer', ₦55,000)
        DB-->>DB: Update order status -> 'delivered'
        DB-->>DB: Credit rider My Balance (+₦2,500 Commission & Allowance)
        DB-->>DB: Increment rider_transactions (TXN-9021)
        DB-->>App: Return success confirmation
        App-->>Rider: Displays Green POD Success confirmation
    end
```

---

## 2. Order Lifecycle State Machine

```mermaid
stateDiagram-v2
    [*] --> pending : Order Created by Merchant
    pending --> accepted : DC Supervisor assigns to Rider (PDA-7000)
    accepted --> in_transit : Rider starts delivery route
    
    in_transit --> delivered : Recipient receives package & payment confirmed
    in_transit --> call_back : Customer unavailable / requested reschedule
    in_transit --> cancelled : Customer rejected order / address invalid

    call_back --> in_transit : Scheduled callback time reached
    cancelled --> stock_return : Stock marked for return to DC custody
    stock_return --> [*] : DC Supervisor receives returned stock
    delivered --> [*] : Remittance & Reconciliation completed
```

---

## 3. Stock Custody, Handover & Return Lifecycle

```mermaid
stateDiagram-v2
    [*] --> StockRequest : Rider requests restock (REQ-00482)
    StockRequest --> DCApproved : DC Supervisor approves request
    DCApproved --> PhysicalHandover : Dual-party barcode / code verification
    PhysicalHandover --> VehicleCustody : Stock added to agent_inventory
    
    state VehicleCustody {
        [*] --> Available : Free for assignment
        Available --> Reserved : Order assigned to vehicle
        Reserved --> Delivered : Handed to customer
        Reserved --> AwaitingReturn : Order failed / cancelled
    }

    AwaitingReturn --> ReturnSubmitted : Rider logs return (RET-00109)
    ReturnSubmitted --> DCReceived : DC warehouse staff scans & restocks
    DCReceived --> [*]
```

---

## 4. Financial Reconciliation & Remittance Workflow

```mermaid
sequenceDiagram
    autonumber
    actor Rider as Emeka Rider (PDA)
    participant App as NoveXPS App
    participant DB as Supabase PostgreSQL
    actor DCFinance as Wuse DC Finance Supervisor

    Note over Rider,App: Physical Cash is in Rider Custody (To Remit: ₦25,000)
    Rider->>App: Navigates to Remittance -> "Remit Cash"
    Rider->>App: Selects Method (Bank Transfer / Cash / POS)
    Rider->>App: Attaches payment proof / receipt photo
    Rider->>App: Submits Remittance (RMT-0005)
    App->>DB: INSERT cash_remittances (status = 'submitted')
    
    Note over DB,DCFinance: DC Finance Portal receives notification
    DCFinance->>DB: Reviews bank statement / counts cash
    DCFinance->>DB: Approves Remittance (status = 'approved')
    DB-->>DB: Deducts ₦25,000 from rider COD balance
    DB-->>DB: Logs settled transaction in rider_transactions
    DB-->>App: Real-time update: Remittance Verified
    App-->>Rider: Displays Verified Green Badge on RMT-0005
```

---

## 5. Rider Earnings & My Balance Payout Workflow

```mermaid
sequenceDiagram
    autonumber
    actor Rider as Emeka Rider (PDA)
    participant App as NoveXPS App
    participant DB as Supabase PostgreSQL
    actor Treasury as Central Treasury / DC Finance

    Note over Rider,App: Monnify Direct Transfers accumulated in My Balance (₦18,500.00)
    Rider->>App: Clicks "My Balance" Hero Card -> Payout History
    Rider->>App: Clicks "[ 💵 Request Payout ]"
    Rider->>App: Enters withdrawal amount (₦15,000.00)
    Rider->>App: Confirms Zenith Bank Account (0123456789)
    Rider->>App: Submits Payout Request (PAY-0082)
    
    App->>DB: INSERT payout_requests (status = 'pending')
    App->>DB: INSERT rider_transactions (category = 'payout', status = 'pending')
    
    Note over DB,Treasury: Treasury reviews withdrawal request
    Treasury->>Treasury: Executes bank transfer to Rider
    Treasury->>DB: Marks payout_requests (status = 'approved', ref = 'DISB-88374291')
    DB-->>DB: Deducts ₦15,000 from direct_transfer_balance
    DB-->>DB: Updates rider_transactions -> 'approved'
    DB-->>App: Push notification / Real-time update
    App-->>Rider: Displays Payout Approved & Disbursed
```
