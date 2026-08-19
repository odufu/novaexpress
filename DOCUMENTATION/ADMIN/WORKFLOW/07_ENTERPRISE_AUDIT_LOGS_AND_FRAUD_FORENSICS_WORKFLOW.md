# 🔍 Admin Workflow 07: Enterprise Audit Trails, Security Telemetry & Fraud Forensics

This document details master append-only audit trail inspection, fraud forensic investigation procedures, suspicious activity anomaly detection, account freezing, and regulatory compliance reporting.

---

## 🎯 Overview & Objectives

* **Primary Goal**: Maintain complete, tamper-evident audit trails for every physical and financial action in the system (BR-020), detect fraud or inventory leakage in real-time, and execute rapid forensic investigations.
* **Primary Actors**: Super Administrator, Head of Internal Control, Forensic Auditor, Supabase Database.
* **Database Tables**: `order_activities`, `inventory_audits`, `rider_transactions`, `cash_remittances`, `payout_requests`.

---

## 📊 Detailed Workflow Diagram

```mermaid
sequenceDiagram
    autonumber
    actor Admin as 👑 Super Admin
    participant Portal as NoveXPS Forensic Audit Portal
    participant DB as Supabase PostgreSQL
    actor Security as 🛡️ Internal Control / Police

    Admin->>Portal: Opens "Master System Audit & Fraud Detection Center"
    Portal->>DB: Query High-Risk Anomalies (e.g. Rider with 3 Discrepancies in 24 hrs)
    DB-->>Portal: Flagged Profile: "Rider ID PDA-7042 (Altered POS Slip Ref: POS-9912)"
    
    Admin->>Portal: Opens Forensic Investigation Timeline for PDA-7042
    Portal->>DB: SELECT * FROM order_activities WHERE user_id = 'agent-7042'
    Portal->>DB: SELECT * FROM rider_transactions WHERE delivery_agent_id = 'agent-7042'
    DB-->>Portal: Chronological Immutable Audit Trail Loaded
    
    Admin->>Portal: Executes "[ ❄️ Freeze Agent Wallet & Suspend Device ]"
    Portal->>DB: UPDATE delivery_agents SET current_status = 'suspended' WHERE id = 'agent-7042'
    Portal->>DB: UPDATE users SET is_active = false WHERE id = 'user-7042'
    DB-->>Portal: Agent Frozen Instantly Across Network
    
    Portal->>Portal: Generates Forensic Evidence PDF Report (EVID-2026-0819)
    Admin->>Security: Hands over Evidence Package for Disciplinary / Legal Action
```

---

## 📑 Step-by-Step Execution Sequence

### Step 1: Immutable Audit Trail Architecture (BR-020)
1. Every critical operational and financial event generates an append-only row in `order_activities`:
   * **Order Assigned**: `activity_type = 'assigned'`
   * **Status Changed**: `activity_type = 'status_changed'`
   * **POD Captured**: `activity_type = 'delivery_completed'`, including GPS coordinates and photo URL.
   * **Failure Logged**: `activity_type = 'delivery_failed'`, including failure category and notes.
   * **Monnify Paid**: `activity_type = 'monnify_paid'`, including Monnify session ID and webhook payload hash.

### Step 2: Automated Fraud Detection Heuristics
1. The forensic engine continuously scans for red-flag patterns:
   * **Heuristic A (Rapid POD Submissions)**: Multiple orders marked delivered within seconds (indicates fake/ghost PODs).
   * **Heuristic B (Altered Deposit Tellers)**: Duplicate bank reference numbers submitted across multiple remittance tickets.
   * **Heuristic C (Off-Route GPS Anomalies)**: Deliveries completed $> 10\text{ km}$ away from customer delivery address.

### Step 3: Forensic Account Freeze & Asset Lock
1. When fraud is detected, Super Admin clicks **[ ❄️ Freeze Agent Wallet & Suspend Device ]**.
2. System executes atomic security lock:
   * Sets `delivery_agents.current_status = 'suspended'`.
   * Sets `users.is_active = false`.
   * Freezes all pending withdrawal payouts in `payout_requests`.
   * Revokes mobile JWT tokens to lock out the device immediately.

### Step 4: Forensic Report Export
1. System compiles a certified, timestamped PDF Evidence Package containing:
   * Device IMEI, IP address, and GPS trail.
   * Uploaded deposit slip images and Monnify transaction logs.
   * Chronological order activity timeline.

---

## 🛑 Audit Data Retention Policies

| Data Category | Retention Period | Storage Standard |
|---|:---:|---|
| **Order Activity Logs (`order_activities`)** | 7 Years | Append-only PostgreSQL Partition |
| **Financial Ledger (`rider_transactions`)** | 10 Years | Cryptographically signed, immutable |
| **POD & Remittance Photo Proofs** | 3 Years | Supabase Encrypted Storage S3 Buckets |
