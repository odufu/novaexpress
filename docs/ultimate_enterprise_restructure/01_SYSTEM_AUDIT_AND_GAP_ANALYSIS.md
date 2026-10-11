# NovaXpress Enterprise Architecture: Master System Audit & Gap Analysis
**Document Reference:** `01_SYSTEM_AUDIT_AND_GAP_ANALYSIS.md`  
**Target Environment:** NovaXpress Enterprise Clearinghouse & Logistics Platform  
**Audit Scope:** Database Schemas, Live Tables, Stored Procedures, Triggers, Edge Functions, Flutter Providers, Presentation Layer, and Third-Party Interfaces  
**Date:** October 2026

---

## 1. Executive Context & The Ultimate Objective

NovaXpress is evolving from a localized internal courier system into a **Dual-Engine Enterprise Platform**:
1. **Engine A: E-Commerce Merchant Clearinghouse & Financial Command Center**  
   Empowering brand merchants (Novacare, Leafora, Emerald, etc.) with real-time operational logistics, COD collection custody, and **unit-level financial profitability analytics** (Sales, Ad Spend, Procurement, Gross/Net Margins, Stock, and Product-level drilldown).
2. **Engine B: High-Throughput Inbound B2B Logistics Clearinghouse & Decentralized Pickup Protocol**  
   Empowering external supermarket chains, general stores, and decentralized community pharmacy networks (ComfortCare model) to plug into NovaExpress via an authenticated REST API for multi-stop automated pickup, package consolidation, flat-rate pricing with stop surcharges, and verified e-POD last-mile delivery.

To achieve this **Ultimate Objective**, this audit identifies:
- **What to KEEP** (Rock-solid, audited components that must not be disrupted).
- **What to OPTIMIZE & POLISH** (High-value modules requiring hardening, performance tuning, or responsive UI polish).
- **What to DROP / REMOVE** (Deprecated mock relics, artificial order generators, dead fallback paths).
- **What to ADD** (The missing architectural pillars: Business Expenditures, Multi-Stop B2B Ingestion, Tri-Portal Financial Dashboards, and Document Attachments).

---

## 2. Comprehensive System Audit by Layer

### Layer 1: PostgreSQL & Supabase Database Layer

#### A. Active Tables Audit
| Table Name | Current Role & Status | Audit Verdict | Recommended Action |
| :--- | :--- | :---: | :--- |
| `clients` | Stores registered merchant profiles, corporate details, bank accounts, custom tariffs. | **KEEP** | Enhance with B2B API access flags, webhook URLs, and client category (`e_commerce_merchant` vs `b2b_logistics_partner`). |
| `users` | Role-based user authentication (`client`, `dc_manager`, `delivery_agent`, `closer`, `marketer`). | **KEEP** | Retain as authoritative identity table. |
| `products` | Merchant catalog products, SKUs, pricing, `dc_stocks` JSONB cache. | **KEEP** | 100% reconciled with `client_stock_balances`. Retain as core SKU registry. |
| `product_packages` | Commercial multi-packs (e.g. "Buy 2 Get 1 Free") linked to products. | **KEEP** | Core e-commerce pricing engine. Fully functional. |
| `client_stock_balances` | Date-tiered physical inventory balances per hub (`warehouse`, `balance_qty`, `valuation_rate`). | **KEEP** | Synced in real time with `products.dc_stocks` via `fn_adjust_dc_stock`. |
| `distribution_centers` | Physical hub locations (Wuse Grand Central, Lagos Main DC, Kaduna DC, Otukpo DC). | **KEEP** | Retain hierarchy (`is_grand_dc` flag distinguishes Grand DC from Sub-DCs). |
| `delivery_agents` | Registered dispatch riders, vehicle types, phone numbers, assigned DC. | **KEEP** | Active fleet registry. |
| `agent_inventory` | Live custody of product units held on rider motorcycles. | **KEEP** | Live custody verified via `fn_get_product_holders_custody`. |
| `orders` | Core transaction table for all customer deliveries. | **POLISH** | Add columns for B2B API ingestion: `fulfillment_type` (`nova_inventory` vs `client_package`), `b2b_client_id`, `client_order_reference`, `pickup_stops_count`, `additional_pickup_fee`. |
| `stock_transfers` & `stock_transfer_items` | Two-way consignment handshakes between merchants, DCs, and riders. | **KEEP** | 100% verified with signature-free physical checks. |
| `suppliers` & `invoices` | Merchant supplier records and incoming stock intake invoices. | **KEEP** | Fully functional. |
| `customer_leads` & `lead_forms` | Digital marketing suite and sales closer CRM integration. | **KEEP** | Fully operational. |

#### B. Tables to be ADDED (The Missing Pillars)
1. **`business_expenditures` (NEW)**:
   - Universal multi-tier expense ledger for **Merchants**, **Grand DC**, and **Sub-DCs**.
   - Foreign keys: `client_id` (optional), `distribution_center_id` (optional), `product_id` (optional for SKU unit economics).
   - Tracks: `expense_name`, `category` (Ads, Procurement, Generator Diesel, Repairs, Leases, Staff), `amount`, `expense_date`, `receipt_url`, `receipt_file_name`.
2. **`b2b_clients` (NEW)**:
   - Registry of external B2B partners (e.g. `comfortcare-abuja-01`, general supermarket chains).
   - Stores: `client_name`, `api_key_hash`, `webhook_url`, `webhook_secret`, `base_flat_rate` (default ₦3,500), `additional_pickup_fee` (default ₦1,500), `is_active`.
3. **`client_package_pickups` (NEW)**:
   - Multi-stop pickup itinerary table linked to `orders(id)`.
   - Stores: `stop_sequence` (1, 2, ...), `pharmacy_name` / `pickup_location_name`, `pickup_address`, `contact_phone`, `contact_whatsapp`, `drugs_to_collect` JSONB, `sealed_bag_ref`, `status` (`pending`, `collected`, `failed`).

#### C. Stored Procedures & Triggers Audit
- **`fn_adjust_dc_stock`**: Synchronizes `products.dc_stocks` and `client_stock_balances` in real time. (**KEEP & PRESERVE**).
- **`fn_get_product_holders_custody`**: Aggregates physical inventory across DCs and riders. (**KEEP & PRESERVE**).
- **`fn_generate_merchant_daily_settlement`**: Reconciles daily COD cash collections. (**KEEP & PRESERVE**).
- **`fn_get_financial_dashboard` (NEW - TO BE ADDED)**: High-performance pure PostgreSQL analytics procedure that calculates the 8 core metrics, date-bucketed timelines, and geographic state distributions for Merchants, Grand DC, and Sub-DCs.

---

### Layer 2: Supabase Edge Functions Layer

#### Current Inventory of Edge Functions:
1. `auto-stock-alert` (Stock threshold monitoring) - **KEEP**
2. `confirm-delivery-pod` (Electronic POD recording) - **KEEP**
3. `dispatch-order` (Rider order dispatch) - **KEEP**
4. `generate-daily-settlements` (Daily 10:00 PM settlement closeout) - **KEEP**
5. `geocode-and-dispatch` (LGA & coordinates matching) - **KEEP**
6. `log-delivery-failure` (Failed attempt logging) - **KEEP**
7. `monnify-webhook` & `paystack-webhook` (Payment gateways) - **KEEP**
8. `process-stock-intake-invoice` (Invoice parsing) - **KEEP**
9. `request-balance-payout` (Rider / closer commission payouts) - **KEEP**
10. `request-stock-transfer` (Consignment transfers) - **KEEP**
11. `submit-cash-remittance` (Rider Paystack bank transfers) - **KEEP**
12. `submit-order` (Standard merchant order creation) - **KEEP**
13. `update-rider-telemetry` (GPS tracking) - **KEEP**

#### Edge Functions to be ADDED:
1. **`ingest-client-package` (NEW - CRITICAL)**:
   - Authenticated HTTP POST ingestion endpoint for external B2B APIs (ComfortCare, supermarkets, general stores).
   - Validates Bearer API Key against `b2b_clients`.
   - Validates JSON payload (`order_reference`, `receiver`, `pickup_stops`, `package_contents`, `payment_receipt`).
   - Server-side fee calculation: $\text{Total Fee} = ₦3,500 + (\text{Stops} - 1) \times ₦1,500$.
   - Creates `orders` record with `fulfillment_type = 'client_package'` and populates `client_package_pickups` child rows.
   - Automatically routes the order to the closest active DC hub based on the first pickup stop coordinates.
2. **`b2b-status-webhook-dispatcher` (NEW)**:
   - Dispatches real-time outbound webhooks back to external B2B clients when riders arrive at pickups, collect bags, or complete doorstep deliveries.

---

### Layer 3: Flutter Application & Provider Architecture

#### A. Client Portal (`lib/features/client_portal/`)
- **Current State**: Contains robust layouts for inventory, orders, marketing suite, and closers.
- **Deficiencies Identified**:
  - `client_dashboard_page.dart` has low-stock alerts and daily cash accumulator, but **lacks the 8 core business profitability metrics** (Sales, Total Expenditure, Net Profit, Procurement, Qty Sold, Available Stock, Advertisement, Revenue Till Date).
  - Lacks the **Product Filter Dropdown** right beside the Date Range Picker (the #1 request from the merchant demo).
  - Lacks the **Revenue vs Expenditure grouped bar chart** and **Revenue by States donut chart**.
  - Lacks an **Expenditure Management modal** with receipt/invoice PDF/image attachment.

#### B. DC Console (`lib/features/dc_console/`)
- **Current State**: Strong warehouse consignment intake, transfer management, and fleet tables.
- **Deficiencies Identified**:
  - Grand DC Dashboard does not provide logistics business intelligence (Fleet Fuel, Leases, Staff OpEx, Delivery Fee Income, Net Logistics Margin).
  - Sub-DC Dashboard does not provide station operating metrics (Local Generator Diesel, Bike Maintenance, Local Handover Fees, Station Net Balance).
  - Supervisors cannot currently record hub operating expenditures directly in the app.

#### C. Rider PDA (`lib/features/stock/`, `lib/features/orders/`)
- **Current State**: Displays standard doorstep deliveries and vehicle stock custody.
- **Deficiencies Identified**:
  - Rider manifest treats all orders as originating from a warehouse. It **cannot currently render a multi-stop dispensary pickup route** (Stop 1: MedPlus -> Stop 2: H-Medix -> Stop 3: Patient).
  - Lacks a **Sealed Bag QR / Barcode Scanner** to verify clinical bags before leaving dispensaries.
  - Lacks recipient **WhatsApp OTP verification** before releasing controlled pharmaceutical consignments.

---

## 3. What Needs to be Re-Implemented, Polished, Dropped, or Added

### Summary Table

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                               MASTER ARCHITECTURAL ACTION MATRIX                                │
├─────────────────────┬───────────────────────────────────────────────────────────────────────────┤
│ ACTION              │ COMPONENTS & MODULES                                                      │
├─────────────────────┼───────────────────────────────────────────────────────────────────────────┤
│ KEEP (Preserve)     │ • Multi-tenant Client scoping and RLS                                     │
│                     │ • Physical stock balancing engine (client_stock_balances)                 │
│                     │ • Two-way signature-free consignment handshake engine                     │
│                     │ • Stored procedures: fn_adjust_dc_stock, fn_get_product_holders_custody   │
│                     │ • Paystack instant remittance & virtual NUBAN settlement pipeline        │
│                     │ • Closers, Marketers, and Digital Marketing Suite                         │
├─────────────────────┼───────────────────────────────────────────────────────────────────────────┤
│ POLISH & REFACTOR   │ • orders table: Add fulfillment_type and B2B pricing columns              │
│                     │ • client_dashboard_page.dart: Overhaul into 8-Metric Profitability Center │
│                     │ • dc_supervisor_dashboard_page.dart: Add Logistics OpEx & Earnings View   │
│                     │ • Date Range Picker: Standardize across all dashboards with custom modal   │
│                     │ • Mobile responsiveness: Ensure all metric cards & charts never overflow  │
├─────────────────────┼───────────────────────────────────────────────────────────────────────────┤
│ DROP / PURGE        │ • Legacy MockOrdersRemoteDataSource fallback in production paths          │
│                     │ • Hardcoded developer names and fallback credentials                      │
│                     │ • Artificial order synthesizers in remittance screens                     │
├─────────────────────┼───────────────────────────────────────────────────────────────────────────┤
│ ADD (New Modules)   │ • Database Table: business_expenditures (with PDF/image upload support)   │
│                     │ • Database Table: b2b_clients (with API Key & Webhook management)         │
│                     │ • Database Table: client_package_pickups (Multi-stop pickup routes)       │
│                     │ • Edge Function: ingest-client-package (B2B REST Ingestion Gateway)       │
│                     │ • Stored Procedure: fn_get_merchant_financial_dashboard                  │
│                     │ • Stored Procedure: fn_get_dc_logistics_dashboard                        │
│                     │ • Flutter UI: Product Selector Dropdown for SKU-level Unit Economics      │
│                     │ • Flutter UI: Revenue vs Expenditure Dual-Bar Chart                       │
│                     │ • Flutter UI: Revenue by States Donut Chart                               │
│                     │ • Flutter UI: Record Business Expenditure Modal with Document Attachment  │
│                     │ • Flutter UI: Rider PDA Multi-Stop Pickup Manifest & Bag Scanner         │
└─────────────────────┴───────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Next Step in Audit Documentation

Proceed to `02_FINANCIAL_INTELLIGENCE_AND_EXPENDITURE_ENGINE.md` for the exact data structures, formulas, and UI specifications of the Tri-Portal Financial Command Center.
