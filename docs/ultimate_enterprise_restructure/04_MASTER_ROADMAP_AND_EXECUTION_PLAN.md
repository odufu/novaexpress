# NovaExpress Enterprise Master Roadmap & Implementation Execution Plan

**Document Reference:** `docs/ultimate_enterprise_restructure/04_MASTER_ROADMAP_AND_EXECUTION_PLAN.md`  
**System Version:** 2.5.0 Enterprise Release  
**Status:** Approved Master Implementation Blueprint  
**Execution Mode:** Autonomous Enterprise Engineering Protocol

---

## 1. Executive Implementation Overview

This document defines the actionable, sequenced roadmap to execute the **Ultimate Objective** across the NovaExpress enterprise platform:
1. **Financial Intelligence & Universal Expenditure Engine**: Real-time financial analytics, hybrid product-linked OpEx accounting, PDF/image receipt attachments, and high-performance PostgreSQL RPCs.
2. **Merchant Dashboard Transformation**: Mirroring legacy enterprise metrics (`academix.com.ng`), adding the crucial **Product Filter Dropdown**, date range filtering, grouped dual-series charts, and revenue by states donut breakdown.
3. **Tri-Portal Consistency**: Adapting financial and operating metrics across the Merchant Console, NovaExpress Grand Console (Logistics HQ), and Regional DC Consoles (Local Station).
4. **B2B Inbound Ingestion & Decentralized Sourcing**: REST API gateway (`ingest-client-package`), multi-stop dispensary routing, barcode/QR bag verification, WhatsApp OTP e-POD, and outbound status webhooks.

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        MASTER IMPLEMENTATION TIMELINE & PHASES                         │
├────────────┬───────────────────────────────────────────────┬───────────────────────────┤
│ PHASE      │ FOCUS AREA                                    │ ESTIMATED SCOPE           │
├────────────┼───────────────────────────────────────────────┼───────────────────────────┤
│ PHASE 1    │ Database Schema, Storage & PostgreSQL RPCs   │ Migrations, Tables, DDL   │
│ PHASE 2    │ Supabase Edge Functions & Webhooks            │ Deno/TypeScript Functions │
│ PHASE 3    │ Flutter Domain Models, State & Repositories   │ Riverpod Providers & DTOs │
│ PHASE 4    │ Merchant Financial Dashboard & OpEx UI        │ 8 KPIs, Filter, Receipts  │
│ PHASE 5    │ Grand Console & DC Operational Consoles       │ Logistics HQ & Stations   │
│ PHASE 6    │ Rider PDA Mobile Multi-Stop & e-POD Engine    │ Bag Scanner, WhatsApp OTP │
│ PHASE 7    │ Verification, Automated QA & Live Cutover    │ End-to-End Test Suite     │
└────────────┴───────────────────────────────────────────────┴───────────────────────────┘
```

---

## 2. Phase 1: Database Schema, Storage & PostgreSQL RPCs

### 1.1 Summary of Deliverables
- Deploy migration `20261011000001_business_expenditures.sql` creating table `public.business_expenditures`.
- Deploy migration `20261011000002_b2b_logistics_engine.sql` creating tables `public.b2b_clients`, `public.client_package_pickups` and altering `public.orders`.
- Provision Supabase Storage bucket `expenditure-receipts` with authenticated RLS upload/read policies.
- Deploy RPC `fn_get_merchant_financial_dashboard` with product and date-range filtering.
- Deploy RPC `fn_get_dc_logistics_dashboard` supporting Grand DC consolidated metrics and Sub-DC station metrics.

### 1.2 Step-by-Step Task Checklist
- [ ] **Task 1.1: Run SQL Migration for `business_expenditures`**
  - Columns: `id`, `entity_type`, `client_id`, `distribution_center_id`, `product_id`, `title`, `description`, `category`, `amount`, `expenditure_date`, `receipt_url`, `receipt_file_name`, `receipt_mime_type`, `created_by`, `created_at`.
  - Indexes: `client_id`, `distribution_center_id`, `product_id`, `expenditure_date`, `category`.
  - Check constraints: `entity_type IN ('merchant', 'grand_dc', 'sub_dc')`.

- [ ] **Task 1.2: Run SQL Migration for B2B Client Package Tables**
  - Create `b2b_clients` with API key hashes, webhook secrets, rate tiers.
  - Seed initial client `comfortcare-abuja-01`.
  - Alter `orders` adding `fulfillment_type`, `b2b_client_id`, `client_order_reference`, `recipient_whatsapp`, `delivery_otp`, `pickup_stops_count`, `additional_pickup_fee`, `rider_pickup_allowance`.
  - Create `client_package_pickups` with foreign keys to `orders`.

- [ ] **Task 1.3: Deploy Financial RPC Functions**
  - Implement `public.fn_get_merchant_financial_dashboard(p_client_id, p_product_id, p_start_date, p_end_date)`:
    - Metric 1: Sales Revenue (completed/delivered orders sum)
    - Metric 2: Total Expenditures (filtered by date and optional product link)
    - Metric 3: Quantity Sold (units of items delivered)
    - Metric 4: Net Profit (`Sales Revenue - Expenditures - COGS`)
    - Metric 5: Available Stock (sum from `client_stock_balances` or inventory)
    - Metric 6: Advertisement Expenses (category = 'advertisement')
    - Metric 7: Procurement Expenses (category = 'procurement')
    - Metric 8: Lifetime Revenue (all delivered revenue since inception)
    - Chart Series: Daily/Monthly Revenue vs Expenditures grouped array
    - State Breakdown: Array of `{ state, order_count, revenue }`
  - Implement `public.fn_get_dc_logistics_dashboard(p_dc_id, p_start_date, p_end_date)`.

- [ ] **Task 1.4: Setup Supabase Storage Bucket**
  - Create bucket `expenditure-receipts` (public = false or secured with signed URLs).
  - Add Storage RLS: allow authenticated users to upload and view receipts matching their `client_id` or `dc_id`.

---

## 3. Phase 2: Supabase Edge Functions & Webhooks

### 2.1 Summary of Deliverables
- Implement `supabase/functions/ingest-client-package/index.ts`:
  - Bearer token authentication against `public.b2b_clients`.
  - Idempotency checking via `order_reference`.
  - Dynamic pricing calculation ($₦3,500$ flat base + $(N - 1) \times ₦1,500$).
  - Transactional insert of `orders` + `client_package_pickups`.
  - DC routing and random 4-digit recipient OTP generation.
- Implement `supabase/functions/webhook-notifier/index.ts`:
  - Asynchronous HTTP POST caller with HMAC-SHA256 signature verification.
  - Automatically fired on status update of B2B orders.

### 2.2 Step-by-Step Task Checklist
- [ ] **Task 2.1: Implement Edge Function `ingest-client-package`**
  - Parse and validate JSON schema: `order_reference`, `pickup_stops`, `receiver`, `payment_receipt`.
  - Reject requests lacking valid Authorization header with HTTP 401.
  - Insert order records using Supabase Service Role client.
  - Return HTTP 201 with tracking number, fee breakdown, and assigned DC.

- [ ] **Task 2.2: Implement Outbound Webhook Worker**
  - Send status updates (`pickup.stop_arrived`, `pickup.bag_collected`, `order.delivered`) to partner webhook URL.
  - Exponential backoff retry mechanism (up to 3 retries).

---

## 4. Phase 3: Flutter Domain Models, State & Repositories

### 3.1 Summary of Deliverables
- Create domain entities and DTOs in `lib/data/models/` and `lib/domain/`:
  - `ExpenditureModel`: parse and serialize expenditure records.
  - `FinancialDashboardMetrics`: encapsulate the 8 KPIs, charts, and state distributions.
  - `B2BClientModel`, `ClientPackagePickupModel`, `B2BOrderManifestModel`.
- Create data repositories in `lib/data/repositories/`:
  - `ExpenditureRepository`: fetch, create, and upload receipt files.
  - `FinancialAnalyticsRepository`: call RPC `fn_get_merchant_financial_dashboard` and `fn_get_dc_logistics_dashboard`.
  - `B2BLogisticsRepository`: fetch multi-stop routes and verify bag scans.
- Create Riverpod state providers in `lib/presentation/providers/`:
  - `merchantFinancialDashboardProvider`: reactive state based on client ID, selected product ID, and date range.
  - `expendituresListProvider`: filterable list of business expenditures.
  - `dcLogisticsFinancialProvider`: station and grand console financial state.

### 3.2 Step-by-Step Task Checklist
- [ ] **Task 3.1: Create Data Models**
  - Implement `lib/data/models/expenditure_model.dart` with JSON serialization.
  - Implement `lib/data/models/financial_dashboard_metrics_model.dart`.
  - Implement `lib/data/models/client_package_pickup_model.dart`.

- [ ] **Task 3.2: Implement Repositories**
  - Implement `lib/data/repositories/expenditure_repository.dart` with file upload method (`uploadReceipt(Uint8List bytes, String fileName, String mimeType)`).
  - Implement `lib/data/repositories/financial_analytics_repository.dart` with RPC invocation.

- [ ] **Task 3.3: Implement State Providers**
  - Implement `lib/presentation/providers/merchant_financial_provider.dart` with filter controls (`setProductFilter(String? productId)`, `setDateRange(DateTimeRange range)`).

---

## 5. Phase 4: Merchant Financial Dashboard & OpEx UI

### 4.1 Summary of Deliverables
- Build modernized Merchant Financial Dashboard in `lib/presentation/pages/merchant/`:
  - Header with **Product Filter Dropdown** and **Date Range Picker**.
  - 8 KPI cards styled in high-contrast luxury dark theme:
    1. Sales (Total Revenue)
    2. Expenditures (Total OpEx)
    3. Quantity Sold (Total Delivered Units)
    4. Net Profit (`Revenue - OpEx - COGS`)
    5. Available Stock (Total Active Units)
    6. Advertisements (Marketing Spend)
    7. Procurement (Inventory Inflow Spend)
    8. Revenue Till Date (Lifetime Historical Gross)
  - Grouped Dual-Series Bar Chart: Revenue vs Expenditures by date.
  - Donut Chart: Revenue by State distribution.
  - Recent Transactions & Expenditures table.
- Build Expenditure Management Screen & Modal:
  - Add Expense Modal:
    - Title / Description
    - Amount (₦)
    - Category (Procurement, Advertisement, Logistics, Salaries, Rent, Utilities, Other)
    - Date picker
    - Optional Product Link Dropdown (Select specific SKU or leave as "General Company Overhead")
    - Attachment Dropzone: Drag-and-drop or file picker for PDF and Images (PNG, JPG, WebP)
    - Preview / view receipt thumbnail.

### 4.2 Step-by-Step Task Checklist
- [ ] **Task 4.1: Build Product Filter & Date Range Header Widget**
  - Query merchant's active product catalogue for dropdown items.
  - Default: "All Products (Consolidated)".
  - Re-trigger RPC automatically on filter change.

- [ ] **Task 4.2: Build 8 Metric KPI Grid Widget**
  - Card with icons, values formatted in Nigerian Naira (`₦`), percentage growth indicators.
  - Responsive 4-column desktop, 2-column tablet, 1-column mobile layout.

- [ ] **Task 4.3: Build Grouped Bar Chart & State Donut Widget**
  - Use `fl_chart` with custom glassmorphic tooltips.
  - Show side-by-side bars for Revenue (Emerald Green) and Expenditures (Rose Pink).

- [ ] **Task 4.4: Build Expenditure Create Modal with File Upload**
  - Integrate `file_picker` package for web and native platform support.
  - Upload receipt file directly to Supabase Storage bucket `expenditure-receipts`.
  - Save URL and metadata to `business_expenditures`.

---

## 6. Phase 5: Grand Console & DC Operational Consoles

### 5.1 Summary of Deliverables
- Update NovaExpress Grand Console (`lib/presentation/pages/hq/`):
  - Adapt the 8 financial metrics to Logistics HQ context:
    1. Logistics Gross Revenue
    2. Network Operating Expenditures (Hub Leases, Fuel, Linehaul)
    3. Total Consignments Delivered
    4. Net Logistics Platform Profit
    5. Consolidated Regional Vault Stock
    6. Fleet Maintenance & Fuel
    7. Station Asset Procurement
    8. Cumulative System Revenue
  - Add Grand Console Expenditure recording action.
- Update Regular Sub-DC Console (`lib/presentation/pages/dc/`):
  - Adapt metrics to Local Hub context:
    1. Station Fee Revenue
    2. Local Station OpEx (Station Generator Diesel, Maintenance)
    3. Local Station Deliveries
    4. Station Net Margin
    5. Local DC Vault Stock
    6. Local Rider Allowances & Payouts
    7. Hub Facility OpEx
    8. Cumulative Station Revenue
  - Add Sub-DC Expense recording action.

### 5.2 Step-by-Step Task Checklist
- [ ] **Task 5.1: Implement Grand Console Financial Tab**
  - Wire to `fn_get_dc_logistics_dashboard(p_dc_id = NULL)`.
  - Provide national breakdown by regional hub.

- [ ] **Task 5.2: Implement Sub-DC Console Financial Tab**
  - Wire to `fn_get_dc_logistics_dashboard(p_dc_id = current_dc_id)`.
  - Local station manager can record diesel, rent, and bike repair expenditures.

---

## 7. Phase 6: Rider PDA Mobile Multi-Stop & e-POD Engine

### 7.1 Summary of Deliverables
- Rider Mobile App Multi-Stop Task Queue (`lib/presentation/pages/rider/`):
  - Render multi-stop route cards for B2B client packages (`Stop 1 -> Stop 2 -> Doorstep`).
  - Pharmacist / shop contact button (WhatsApp direct link).
  - Barcode / QR camera scanner for `sealed_bag_ref`.
- Recipient Handover & Proof of Delivery (e-POD):
  - 4-digit WhatsApp OTP verification modal.
  - Digital signature canvas.
  - Instant rider wallet credit of ₦1,800 base + ₦1,000 multi-stop bonus.

### 7.2 Step-by-Step Task Checklist
- [ ] **Task 6.1: Build Multi-Stop Manifest Queue Card**
  - Query `client_package_pickups` for active order.
  - Highlight current pending stop sequence.

- [ ] **Task 6.2: Integrate Barcode / QR Bag Scanner**
  - Match scanned code against expected `sealed_bag_ref`.
  - Update status to `bag_verified_collected`.

- [ ] **Task 6.3: Implement Recipient WhatsApp OTP & Signature e-POD**
  - Validate OTP entry against `orders.delivery_otp`.
  - Collect recipient signature and close order.

---

## 8. Phase 7: Verification, Automated QA & Live Cutover

### 8.1 Summary of Deliverables
- Comprehensive automated verification scripts in `scripts/`:
  - `verify_financial_rpcs.py`: tests RPCs across different product filters and date ranges.
  - `simulate_b2b_order_ingestion.py`: tests B2B API gateway with 1-stop, 2-stop, and 3-stop payloads.
  - `test_receipt_upload_and_expenditures.py`: verifies file upload, storage retrieval, and ledger tracking.
- Flutter automated test suite:
  - Unit tests for models and providers.
  - Widget tests for financial dashboard KPI cards.
- Static analysis & compilation check:
  - `flutter analyze lib/` with 0 warnings/errors.

---

## 9. Immediate Execution Trigger: Phase 1 Action Plan

The roadmap is fully detailed, unified, and ready for deployment. The immediate next action is executing **Phase 1: Database Schema, Storage & PostgreSQL RPCs**:
1. Create and apply the `business_expenditures` table and RLS policies.
2. Create and apply the `b2b_clients`, `client_package_pickups` tables and `orders` schema extensions.
3. Deploy the `fn_get_merchant_financial_dashboard` and `fn_get_dc_logistics_dashboard` PostgreSQL stored procedures.
4. Verify all RPCs and tables with a Python execution test script.
