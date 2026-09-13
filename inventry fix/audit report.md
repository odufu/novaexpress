# Comprehensive Inventory System & Product Accounting Audit Report

**Date:** September 2026  
**Target Environment:** Supabase Cloud (`qpcafevjsrbauweuiiyq`), PostgreSQL 15, Deno Edge Functions, Flutter Multi-Platform (Web, Mobile, Desktop).  
**Status:** Audit Complete — Remediation Required.

---

## Executive Summary

An exhaustive, end-to-end audit of the inventory system and product financial accounting was conducted across all system tiers:
1. **Supabase PostgreSQL Schema, Stored Procedures, & Triggers**
2. **Supabase Deno Edge Functions**
3. **Flutter Domain & Data Layer (Datasources, Repositories, Use Cases)**
4. **State Management & Providers (`StockProvider`, `ClientPortalProvider`, `DCConsoleProvider`, `ProductCatalogProvider`)**
5. **Presentation Faces: Distribution Center Console (`DCStockPage`), Client Portal (`ClientProductsPage`, `ClientFinancePage`), and Mobile Rider App (`StockPage`, `InventoryAuditPage`, `ReturnStockModal`)**

The audit revealed that while high-level UI workflows appear visually polished, the backend inventory lifecycle suffers from **critical double-deductions, orphaned database tables, hardcoded dummy fallbacks (₦25,000 prices and static PINs), disconnected in-memory states, and missing return/reconciliation loops**.

```
                             CRITICAL INVENTORY LIFECYCLE VULNERABILITY MAP
┌───────────────────────────┬───────────────────────────────┬──────────────────────────────────────────┐
│ Operational Event         │ Current System Behavior       │ Real-World Flaw & Financial Hazard       │
├───────────────────────────┼───────────────────────────────┼──────────────────────────────────────────┤
│ 1. DC Issues to Rider     │ Decrements products.stock_qty │ DC Shelf stock decremented once.         │
│ 2. Order Delivered (POD)  │ confirm-delivery-pod ALSO     │ ⚠️ DOUBLE DEDUCTION: products.stock_qty  │
│                           │ decrements products.stock_qty │ is decremented a SECOND time!            │
├───────────────────────────┼───────────────────────────────┼──────────────────────────────────────────┤
│ 3. Rider Custody on POD   │ Inserts row into stock_returns│ ⚠️ agent_inventory table in PostgreSQL   │
│                           │ with dummy reason!            │ is NEVER decremented on delivery!        │
├───────────────────────────┼───────────────────────────────┼──────────────────────────────────────────┤
│ 4. Rider Returns to DC    │ Inserts into stock_returns    │ ⚠️ UNRECEIVED RETURNS: DC Console has no │
│                           │ with status = 'submitted'     │ screen to accept returns; stock vanishes!│
├───────────────────────────┼───────────────────────────────┼──────────────────────────────────────────┤
│ 5. Inter-DC Transfer      │ Encodes JSON tag inside       │ ⚠️ DB DIVERGENCE: products.dc_stocks     │
│                           │ products.description string!  │ JSONB column is bypassed!                │
├───────────────────────────┼───────────────────────────────┼──────────────────────────────────────────┤
│ 6. Physical Stock Audit   │ Mutates local device memory   │ ⚠️ ZERO DB SYNC: inventory_audits table  │
│                           │ and SharedPreferences only    │ in PostgreSQL is NEVER written to!       │
└───────────────────────────┴───────────────────────────────┴──────────────────────────────────────────┘
```

---

## 1. Database Schema & Stored Procedures (PostgreSQL / Supabase)

### 1.1 The Double Stock Deduction Bug on Order Delivery
* **Locations**: 
  - [`fn_issue_dc_stock_to_rider`](file:///C:/PROJECT/NoveXPS/supabase/migrations/20260914100000_two_way_stock_handshake_and_signatures.sql#L350)
  - [`supabase/functions/confirm-delivery-pod/index.ts:80-100`](file:///C:/PROJECT/NoveXPS/supabase/functions/confirm-delivery-pod/index.ts#L80-L100)
* **Finding**:
  1. When a DC supervisor allocates stock to a rider via `fn_issue_dc_stock_to_rider`, the stored procedure deducts warehouse shelf stock:
     ```sql
     UPDATE public.products
     SET stock_quantity = GREATEST(0, COALESCE(stock_quantity, 0) - v_qty)
     WHERE id = v_prod_id;
     ```
  2. When the rider delivers the customer's order and captures POD, the edge function `confirm-delivery-pod` executes:
     ```typescript
     const newStock = Math.max(0, currentStock - qty);
     await supabaseClient.from("products").update({ stock_quantity: newStock }).eq("id", order.product_id);
     ```
* **Impact**: The system deducts stock **twice** for the exact same physical unit. If a DC issues 50 units and 50 units are delivered, `products.stock_quantity` is decremented by 100 units, driving inventory balances into false shortages or negative numbers.

### 1.2 Orphaned `agent_inventory` Table
* **Location**: `public.agent_inventory` table ([`20260819180000_full_schema_pda_system.sql:182-196`](file:///C:/PROJECT/NoveXPS/supabase/migrations/20260819180000_full_schema_pda_system.sql#L182-L196)).
* **Finding**:
  - The database defines an `agent_inventory` table with columns: `delivery_agent_id`, `product_id`, `total_in_custody`, `reserved_count`, `available_count`, `delivered_count_today`, `returned_count`.
  - Stored procedure `fn_rider_accept_stock_handover` upserts `agent_inventory` when a rider accepts a transfer.
  - However, **no query in the entire Flutter application (`lib/`) selects from or listens to `agent_inventory`**.
  - Instead, [`stock_remote_datasource.dart:1000-1095`](file:///C:/PROJECT/NoveXPS/lib/features/stock/data/datasources/stock_remote_datasource.dart#L1000-L1095) dynamically reconstructs rider custody in-memory on the client by iterating historical `stock_transfers` and subtracting delivered `orders`.
  - On delivery, `agent_inventory` is never decremented in PostgreSQL.

### 1.3 `products.dc_stocks` Divergence vs `products.description`
* **Location**: Migration [`20260913130000_audit_and_chat_and_ownership_transfer.sql:22`](file:///C:/PROJECT/NoveXPS/supabase/migrations/20260913130000_audit_and_chat_and_ownership_transfer.sql#L22).
* **Finding**:
  - The database has a dedicated `dc_stocks JSONB DEFAULT '{}'::jsonb` column on `products`.
  - In [`stock_remote_datasource.dart:1435-1440`](file:///C:/PROJECT/NoveXPS/lib/features/stock/data/datasources/stock_remote_datasource.dart#L1435-L1440), inter-DC transfers serialize DC balances as a string tag inside `products.description`: `[DC_STOCKS: {"dc_id": 20}]`.
  - In `fn_receive_client_supply`, only the global `stock_quantity` is incremented; `products.dc_stocks` is **never updated**.
  - Result: DC-scoped views in `dc_stock_page.dart` that filter by `dcStocks[selectedDcId]` miss incoming client consignments.

### 1.4 Coexistence of Dual Transfer Tables
* **Finding**: The database contains two parallel transfer architectures:
  1. Legacy PDA: `stock_requests`, `stock_request_items`, and `stock_handovers` ([`20260819180000_full_schema_pda_system.sql:201-235`](file:///C:/PROJECT/NoveXPS/supabase/migrations/20260819180000_full_schema_pda_system.sql#L201-L235)).
  2. Modern Waybill: `stock_transfers` and `stock_transfer_items` ([`20260914100000_two_way_stock_handshake_and_signatures.sql`](file:///C:/PROJECT/NoveXPS/supabase/migrations/20260914100000_two_way_stock_handshake_and_signatures.sql)).
  - DC Console Tab 3 and Tab 4 still reference the legacy table architecture (`REQ-00482`), while the rest of the application uses `stock_transfers`.

---

## 2. Supabase Edge Functions Gaps

### 2.1 Package Bundles Undercount in `confirm-delivery-pod`
* **Location**: [`supabase/functions/confirm-delivery-pod/index.ts:80-100`](file:///C:/PROJECT/NoveXPS/supabase/functions/confirm-delivery-pod/index.ts#L80-L100).
* **Finding**:
  - The edge function checks only `order.product_id` and deducts `order.quantity || 1`.
  - For commercial package bundles (e.g. "Buy 3 Get 1 Free Mega Deal" containing 4 physical units), `order.quantity` in PostgreSQL is `1` (1 bundle), but `order.totalPhysicalQuantity` is `4`.
  - The edge function deducts only **1 unit**, leaving physical inventory 3 units over-reported in the database on every delivered bundle.

### 2.2 Unmanaged Stock on Order Failure / Cancellation
* **Location**: [`supabase/functions/log-delivery-failure/index.ts`](file:///C:/PROJECT/NoveXPS/supabase/functions/log-delivery-failure/index.ts).
* **Finding**:
  - When an order fails or is cancelled, `log-delivery-failure` updates `orders.status = 'cancelled'` and credits the rider transport allowance.
  - It does **not** adjust rider vehicle custody, does **not** create a return request, and does **not** release reserved stock.

### 2.3 Missing Edge Functions
1. `auto-stock-alert`: No background job or trigger alerts merchants or DC supervisors when stock drops below `low_stock_threshold`.
2. `daily-stock-reconciliation`: No automated daily ledger snapshot comparing physical DC shelf counts + rider vehicle custody against supplier dispatch waybills.

---

## 3. Hardcoded Data, Fallbacks & Mock Numbers

| File & Line | Code Snippet | Issue & Risk |
| :--- | :--- | :--- |
| **`stock_remote_datasource.dart:483`** | `double unitPrice = ... ?? 25000.0;` | Hardcoded fallback price of ₦25,000 if order amount is missing. |
| **`stock_remote_datasource.dart:1013`** | `final price = ... ?? 25000.0;` | Hardcoded fallback price of ₦25,000 if product base price is missing. |
| **`product_catalog_provider.dart:184`** | `final basePrice = ... ?? 25000.0;` | Hardcoded fallback price of ₦25,000 in catalog provider. |
| **`fn_calculate_merchant_asset_custody:396`** | `COALESCE(v_prod.base_price, 25000.00)` | Hardcoded fallback ₦25,000 in PostgreSQL stored procedure! |
| **`dc_stock_page.dart:3431-3432`** | `REQ-00482 • Replenishment Handover`<br>`20x Respira Detox Tea, 10x Grazer Tea` | Hardcoded mock request card in DC Console Tab 3. |
| **`dc_stock_page.dart:3453`** | `Handover PIN (HND-9921) generated` | Fake SnackBar displaying static PIN `HND-9921`. |
| **`dc_stock_page.dart:3502-3505`** | `completeStockHandover('REQ-00482')`<br>`+30 units transferred to vehicle custody` | Hardcoded PIN completion in Tab 4 ignoring text input. |
| **`stock_details_grazer_page.dart:22-48`** | `productName = 'Respira Detox Tea'`<br>`displaySku = 'RDT-001'` | Hardcoded fallback product details and copy. |

---

## 4. Half-Implemented & Dead Features

### 4.1 DC Console Tab 3: "Rider Picking Queue" (Mock / Dead UI)
* **Location**: [`dc_stock_page.dart:3400-3467`](file:///C:/PROJECT/NoveXPS/lib/features/dc_console/presentation/pages/dc_stock_page.dart#L3400-L3467).
* **Status**: Purely mock UI. Displays hardcoded `REQ-00482`.
  - `OutlinedButton(onPressed: () {}, child: Text('Print Picking Ticket'))` has an **empty callback** (`onPressed: () {}`).
  - `Approve & Generate Handover PIN` button displays a SnackBar with `HND-9921` without writing to Supabase.

### 4.2 DC Console Tab 4: "Dispatch Handover Counter" (Disconnected UI)
* **Location**: [`dc_stock_page.dart:3470-3524`](file:///C:/PROJECT/NoveXPS/lib/features/dc_console/presentation/pages/dc_stock_page.dart#L3470-L3524).
* **Status**: Contains a `TextField` for entering a Handover PIN, but clicking `Confirm Physical Handover` ignores the input and invokes `completeStockHandover('REQ-00482')` on local in-memory state.

### 4.3 DC Console Tab 1: "DC Warehouse Stock Batches" (Local Cache Only)
* **Location**: [`dc_stock_page.dart:3075-3176`](file:///C:/PROJECT/NoveXPS/lib/features/dc_console/presentation/pages/dc_stock_page.dart#L3075-L3176).
* **Status**: Displays warehouse storage bins and lot batches (`DCWarehouseBatch`), but they are stored **only in SharedPreferences** (`getCachedWarehouseBatches()`). The PostgreSQL table `product_batches` is never queried.

### 4.4 Rider Stock Returns to DC (One-Way Black Hole)
* **Location**: [`return_stock_modal.dart`](file:///C:/PROJECT/NoveXPS/lib/features/stock/presentation/widgets/return_stock_modal.dart) and [`stock_remote_datasource.dart:1287-1352`](file:///C:/PROJECT/NoveXPS/lib/features/stock/data/datasources/stock_remote_datasource.dart#L1287-L1352).
* **Status**: When a rider returns stock to a DC, a record is inserted into `stock_returns` with status `'submitted'`. **DC Console has no interface to view or accept `stock_returns`**, so returned goods never get credited back to warehouse inventory.

### 4.5 Rider Inventory Physical Audit (Local-Only State)
* **Location**: [`inventory_audit_page.dart`](file:///C:/PROJECT/NoveXPS/lib/features/stock/presentation/pages/inventory_audit_page.dart) and [`stock_provider.dart:1361-1395`](file:///C:/PROJECT/NoveXPS/lib/features/stock/presentation/providers/stock_provider.dart#L1361-L1395).
* **Status**: `InventoryAuditPage` captures unit counts and variance reasons, but `submitRiderStockAudit` only mutates local state and SharedPreferences. It **never writes to `public.inventory_audits` in Supabase**, leaving supervisors without audit logs.

### 4.6 Inter-DC Transfer Arrival Receipt (Unfinishable Transfer)
* **Location**: [`stock_remote_datasource.dart:1380-1445`](file:///C:/PROJECT/NoveXPS/lib/features/stock/data/datasources/stock_remote_datasource.dart#L1380-L1445).
* **Status**: Creates transfer records with status `'in_transit'`. The destination DC has no screen to inspect received items and mark the transfer `'completed'`.

### 4.7 Barcode Button in Rider Stock Page
* **Location**: [`stock_page.dart:355-365`](file:///C:/PROJECT/NoveXPS/lib/features/stock/presentation/pages/stock_page.dart#L355-L365).
* **Status**: The barcode search icon navigates to `/orders/scan` (`ScanToCollectPage`), which is designed for order tracking numbers, not product barcodes or SKUs.

### 4.8 Order Assignment Bundle Units Gap
* **Location**: [`dc_assign_order_modal.dart:482`](file:///C:/PROJECT/NoveXPS/lib/features/dc_console/presentation/widgets/dc_assign_order_modal.dart#L482).
* **Status**: Checks `availableCustodyUnits >= widget.order.quantity`. For package bundles, `quantity` is `1` while `totalPhysicalQuantity` is `5`. A rider holding only 1 unit can be dispatched on a 5-unit order.

---

## 5. Product Accounting & Financial Custody Gaps

### 5.1 Missing `cost_price` (COGS) in Product Schema
* **Current State**:
  - `products` table has `base_price` (retail price), but lacks `cost_price` / `wholesale_price` (procurement cost).
  - In [`client_finance_page.dart`](file:///C:/PROJECT/NoveXPS/lib/features/client_portal/presentation/pages/client_finance_page.dart), the KPI titled **"Net Realized Profit"** actually computes **Net Revenue after logistics deductions**:
    $$\text{Net Revenue} = \text{Gross Collections} - \text{Logistics Fees} - \text{Platform Fees} - \text{Gateway Fees}$$
  - Without `cost_price`, true Cost of Goods Sold (COGS) and commercial net profit cannot be determined.

### 5.2 Damaged & Missing Stock Financial Loss is Unaccounted
* **Current State**:
  - In `stock_transfers` and `stock_transfer_items`, we record `quantity_damaged` and `quantity_missing`.
  - However, there are no financial ledger entries created for damaged or missing units.
  - These losses are not reflected in merchant settlement vouchers or carrier liability deductions.

### 5.3 Single-Sided Product Creation (Client Portal Only)
* **Current State**:
  - Merchants can create products in `ClientAddProductModal`, but DC Console has no interface for warehouse staff to register inbound products or add new SKUs.
  - `ClientAddProductModal` also lacks fields for `cost_price`, `low_stock_threshold`, package weight (for shipping fee calculations), and barcode numbers.
