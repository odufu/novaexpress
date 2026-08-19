# 📊 HQ Workflow 07: National Financial Audit, POS Fee Reconciliation & Client Settlement

This document outlines enterprise financial auditing across all regional Distribution Centers, physical COD cash custody monitoring, POS fee tracking (BR-016), bank statement reconciliation, and merchant client remittance settlements.

---

## 🎯 Overview & Objectives

* **Primary Goal**: Ensure 100% financial auditing across all regional hubs, track physical cash in transit nationwide, reconcile POS transaction charges as separate financial line items (BR-016), and execute automated client COD proceeds settlements.
* **Primary Actors**: Senior Financial Auditor, Head of Internal Control, Merchant Finance Representative, Supabase Database.
* **Database Tables**: `cash_remittances`, `remittance_orders`, `orders`, `clients`, `companies`.

---

## 📊 Detailed Workflow Diagram

```mermaid
sequenceDiagram
    autonumber
    actor Auditor as 🔍 Senior Financial Auditor (HQ)
    participant Portal as NoveXPS Financial Audit Portal
    participant DB as Supabase PostgreSQL
    actor Merchant as 🏢 Merchant Client (Novacare Limited)
    actor Bank as 🏦 Corporate Bank

    Auditor->>Portal: Opens "National Cash Reconciliation Center"
    Portal->>DB: SELECT SUM(current_cod_balance) FROM delivery_agents
    DB-->>Portal: Returns National Cash in Custody (Abuja: ₦2.4M, Lagos: ₦5.8M)
    
    Auditor->>Portal: Initiates "Weekly Merchant Settlement Cycle" (Client: Novacare Limited)
    Portal->>DB: Query Verified Delivered Orders for Novacare (Week of Aug 12 - 19)
    DB-->>Portal: 500 Orders • Gross COD Collected: ₦12,500,000.00
    
    Portal->>Portal: Calculates Client Invoicing Deductions:
    Portal->>Portal: • Gross Collections: ₦12,500,000.00<br>• Less Delivery Fees (500 x ₦5,000): -₦2,500,000.00<br>• Less POS Transaction Fees (BR-016): -₦35,000.00<br>• Net Remittance Owed to Client: ₦9,965,000.00
    
    Auditor->>Portal: Approves Merchant Settlement Statement (STM-NOV-2026-0819)
    Portal->>Bank: Dispatches Bulk Transfer to Novacare GTBank (₦9,965,000.00)
    Bank-->>Portal: Settlement Disbursed (Ref: SETTLE-892102)
    
    Portal-->>Merchant: Sends Audited Settlement Statement + Tax Invoice
```

---

## 📑 Step-by-Step Execution Sequence

### Step 1: Real-Time Cash In Custody Auditing
1. Financial Auditor monitors the **National COD Heatmap** showing live physical cash balances across all field riders:
   * **Wuse DC**: 18 Riders holding `₦1,420,000.00`
   * **Ikeja Central DC**: 32 Riders holding `₦3,850,000.00`
2. Flags any individual rider holding $> ₦100,000.00$ physical cash or un-remitted funds $> 24$ hours for immediate supervisor contact.

### Step 2: POS Terminal Fee Accounting (BR-016)
1. In compliance with **BR-016**, POS payment processing charges are treated as separate financial transactions and never combined into delivery commission rates.
2. System logs exact POS charges:
   $$\text{Gross Collection} - \text{POS Processing Fee} = \text{Net Bank Inflow}$$
3. Audits monthly POS terminal invoices from merchant acquiring banks against logged transactions.

### Step 3: Merchant Client Settlement Statement Generation
1. At the end of every weekly billing cycle (Mondays at 00:00 UTC), the settlement engine aggregates all `delivered` & `verified` orders for each corporate client (*Novacare Limited*):
   * **Gross COD Collections**: `₦12,500,000.00` (500 delivered orders)
   * **Contractual Delivery Fees (BR-006)**: `500 × ₦5,000 = ₦2,500,000.00`
   * **POS Terminal Transaction Fees (BR-016)**: `₦35,000.00`
   * **Net Proceeds Payable to Merchant**: `₦9,965,000.00`

### Step 4: Electronic Disbursement & Audit Sign-Off
1. Senior Auditor verifies bank statement match and signs off.
2. Electronic wire transfer of `₦9,965,000.00` is executed from corporate treasury to Novacare’s designated bank account.
3. System issues an official PDF Settlement Report and Value-Added Tax (VAT) invoice to the client portal.

---

## 🛑 Financial Reconciliation Constraints

| Financial Rule | System Enforcement |
|---|---|
| **Zero Variance Settlement** | A client settlement statement cannot be finalized if any linked order has an un-reconciled remittance status (`status = 'pending'`). |
| **Separate POS Tracking (BR-016)** | POS fees are isolated in general ledger code `GL-5040 (Payment Gateway Charges)` for tax and operational accounting transparency. |
