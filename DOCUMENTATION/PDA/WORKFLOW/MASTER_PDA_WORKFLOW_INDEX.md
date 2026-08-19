# 📘 NoveXPS PDA Complete Operational Workflow Guide & Sitemap

Welcome to the **NovaExpress Logistics Management System (NoveXPS) Personal Digital Assistant (PDA) Operational Workflow Guide**. This master index organizes end-to-end operational workflows for delivery riders, distribution center supervisors, treasury personnel, and backend Edge Functions.

---

## 🗺️ Master Workflow Architecture Overview

```mermaid
graph TD
    A[1. Authentication & Session Setup] --> B[2. Stock Request & Replenishment]
    B --> C[3. Confirming Stock Collection & Handover]
    C --> D[4. Delivery Processes & Edge Cases]
    D -->|Successful COD / Transfer| E[5. Inventory & Stock Management]
    D -->|COD Cash Collected| F[6. Cash & Digital Remittance]
    D -->|Direct Transfer / Commission Owed| G[7. Rider Earnings & Payouts]
    F -->|DC Verified| G
    E -->|Restock / Return| B
    subgraph Resiliency Layer
        H[8. Offline Storage, Queueing & Auto-Sync Engine]
    end
    D -. Offline Sync .-> H
    F -. Offline Sync .-> H
```

---

## 📑 Workflow Guide Index

| # | Workflow Module | Description | Primary Actors | Documentation Link |
|:---:|---|---|---|---|
| **01** | **Authentication & Session Setup** | Login, JWT authentication, role detection, profile hydration, and offline sync initialization. | Emeka Rider (PDA Agent), Supabase Auth | [01_AUTHENTICATION_AND_SESSION_WORKFLOW.md](file:///c:/PROJECT/NoveXPS/DOCUMENTATION/PDA/WORKFLOW/01_AUTHENTICATION_AND_SESSION_WORKFLOW.md) |
| **02** | **Stock Request & Replenishment** | Requesting inventory from Distribution Center (DC), restock threshold triggers, and approval queues. | Rider, DC Supervisor, Edge Function (`request-stock-transfer`) | [02_STOCK_REQUEST_AND_REPLENISHMENT_WORKFLOW.md](file:///c:/PROJECT/NoveXPS/DOCUMENTATION/PDA/WORKFLOW/02_STOCK_REQUEST_AND_REPLENISHMENT_WORKFLOW.md) |
| **03** | **Confirming Stock Collection & Handover** | Security PIN / QR physical handover verification, batch allocation, and vehicle inventory intake. | Rider, DC Manager, PostgreSQL Triggers | [03_STOCK_COLLECTION_AND_HANDOVER_WORKFLOW.md](file:///c:/PROJECT/NoveXPS/DOCUMENTATION/PDA/WORKFLOW/03_STOCK_COLLECTION_AND_HANDOVER_WORKFLOW.md) |
| **04** | **Delivery Processes & Edge Cases** | End-to-end order execution: COD, Monnify Transfer, Upsell, Callback/Reschedule, Delivery Failure, POD attachment. | Rider, Customer, Edge Functions (`confirm-delivery-pod`, `monnify-webhook`, `log-delivery-failure`) | [04_DELIVERY_PROCESSES_AND_EDGE_CASES_WORKFLOW.md](file:///c:/PROJECT/NoveXPS/DOCUMENTATION/PDA/WORKFLOW/04_DELIVERY_PROCESSES_AND_EDGE_CASES_WORKFLOW.md) |
| **05** | **Inventory & Stock Management** | Stock Grazer custody view, real-time inventory counts (Reserved, Delivered, Returned, Awaiting Return), and DC returns. | Rider, DC Stock Keeper | [05_INVENTORY_AND_STOCK_MANAGEMENT_WORKFLOW.md](file:///c:/PROJECT/NoveXPS/DOCUMENTATION/PDA/WORKFLOW/05_INVENTORY_AND_STOCK_MANAGEMENT_WORKFLOW.md) |
| **06** | **Cash & Digital Remittance** | Physical COD cash custody accumulation, POS/Bank slip uploads, DC supervisor verification, and COD balance clearance. | Rider, DC Finance Supervisor, Edge Function (`submit-cash-remittance`) | [06_CASH_AND_DIGITAL_REMITTANCE_WORKFLOW.md](file:///c:/PROJECT/NoveXPS/DOCUMENTATION/PDA/WORKFLOW/06_CASH_AND_DIGITAL_REMITTANCE_WORKFLOW.md) |
| **07** | **Rider Earnings & Payouts** | Ledger tracking (₦1000 commission + ₦1500 allowance), Monnify direct transfer credits, My Balance withdrawal requests. | Rider, Treasury Officer, Edge Function (`request-balance-payout`) | [07_RIDER_EARNINGS_AND_PAYOUT_WORKFLOW.md](file:///c:/PROJECT/NoveXPS/DOCUMENTATION/PDA/WORKFLOW/07_RIDER_EARNINGS_AND_PAYOUT_WORKFLOW.md) |
| **08** | **Offline Resiliency & Sync Engine** | Offline sqlite persistence, action queueing, connectivity detection, and background sync conflict resolution. | PDA App Engine, Hive/SQLite | [08_OFFLINE_RESILIENCY_AND_SYNC_WORKFLOW.md](file:///c:/PROJECT/NoveXPS/DOCUMENTATION/PDA/WORKFLOW/08_OFFLINE_RESILIENCY_AND_SYNC_WORKFLOW.md) |

---

## 🛠️ Key System Components & Data Flow Mapping

```mermaid
sequenceDiagram
    autonumber
    actor Rider as 🛵 Emeka Rider (PDA)
    participant Flutter as NoveXPS PDA App
    participant LocalDB as Local Hive / SQLite
    participant Edge as Supabase Edge Functions
    participant DB as Remote Supabase PostgreSQL
    actor DC as 🏢 DC Manager / Treasury

    Note over Rider,DB: 1. Stock Request & Pickup
    Rider->>Flutter: Request Restock (20x Respira Tea)
    Flutter->>Edge: POST /request-stock-transfer
    Edge->>DB: INSERT INTO stock_requests (status = 'pending')
    DC->>DB: Approves & Generates Handover Code (HND-9921)
    DC-->>Rider: Hands over stock at DC
    Rider->>Flutter: Enter Handover Code (HND-9921)
    Flutter->>DB: CALL confirm_stock_handover()
    DB-->>Flutter: Increments agent_inventory (total_in_custody = 20)

    Note over Rider,DB: 2. Delivery & Execution
    Rider->>Flutter: Complete Order (TRK-8924, COD: ₦55,000)
    Flutter->>Edge: POST /confirm-delivery-pod
    Edge->>DB: CALL confirm_delivery_pod()
    DB-->>DB: Decrement agent_inventory & Increment delivery_agents.cod_balance (+₦55,000)
    DB-->>DB: Credit rider_transactions (+₦2,500 entitlement)

    Note over Rider,DB: 3. Remittance & Payout
    Rider->>Flutter: Submit Cash Remittance (RMT-0005, ₦55,000)
    Flutter->>Edge: POST /submit-cash-remittance
    DC->>DB: Verifies Cash Deposit -> Updates status = 'verified'
    DB-->>DB: Clears delivery_agents.cod_balance (-₦55,000)
    Rider->>Flutter: Request Payout (PAY-0082, ₦18,500)
    Flutter->>Edge: POST /request-balance-payout
    DC->>DB: Treasury Disburses Bank Transfer
```
