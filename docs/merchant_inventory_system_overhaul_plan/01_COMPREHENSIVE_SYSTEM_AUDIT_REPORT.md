# Phase 1: Comprehensive System Audit Report
## Supabase, Edge Functions, Stored Procedures, Live Tables & Flutter Architecture

**Audit Date:** September 20, 2026  
**Auditor:** Antigravity System Architecture Team  
**Scope:** DC Merchant Management, Product Catalog, Inventory Lifecycle, Procurement Suppliers, Landed Cost Calculations, and Data Seeding.

---

### Executive Summary

An exhaustive cross-stack audit was performed across:
1. **Supabase Database & Migrations**: 55 migrations, master complete schema (`schema_master_complete.sql`), foreign key relationships, and RLS policies.
2. **Stored Procedures & Database Functions**: `fn_get_client_stock_balance_period`, `fn_process_client_stock_intake_invoice`, `fn_confirm_order_delivery_stock`, `fn_calculate_merchant_asset_custody`, `fn_generate_merchant_daily_settlement`.
3. **Supabase Edge Functions**: `process-stock-intake-invoice`, `auto-stock-alert`, `confirm-delivery-pod`, `generate-daily-settlements`, `dispatch-order`.
4. **Flutter Application**:
   - **DC Console**: `dc_clients_page.dart`, `dc_onboard_client_modal.dart`, `dc_client_asset_portfolio_modal.dart`, `dc_console_provider.dart`.
   - **Client Portal**: `client_inventory_page.dart`, `client_products_page.dart`, `client_dashboard_page.dart`, `client_add_product_modal.dart`, `client_supply_stock_modal.dart`, `client_raise_stock_invoice_modal.dart`, `client_add_supplier_modal.dart`.
   - **Data Tables**: `pangea_excel_data_table.dart`.

---

### Key Audit Findings & Architectural Gaps

#### 1. DC-Side Merchant Representation & Management (Deficiency)
- **Current State**:
  - `DCClientsPage` displays merchant summary cards with only two action buttons: `View Assets` and `Client Settlement`.
  - `DCOnboardClientModal` only creates new clients. There is **no mechanism** to edit merchant details once created.
  - DC operators cannot edit a merchant's corporate profile (contact person, phone, email, address, operating states), brand colors/logo, tariff rates, or enabled service modules.
  - DC operators have no dedicated view into the merchant's **unit economics**, **landed costs**, or **state-by-state warehouse stock custody**.
- **Impact**: DC operators are forced to either run direct SQL updates or leave merchant records static. Brand customization and negotiated tariff adjustments cannot be maintained autonomously.

#### 2. Product-to-Inventory & Product-to-Supplier Disconnect
- **Current State**:
  - In `client_add_product_modal.dart`, creating a product saves `name`, `sku`, `category`, `unit_price`, `cost_price`, `weight_kg`, `low_stock_threshold`, and `covering_states`.
  - There is **no field** linking the product to a `preferred_supplier_id` in the `products` table or in the creation UI.
  - Newly created products are initialized with 0 units awaiting supply, but without any link to who manufactures or supplies the SKU.
  - Products exist in the catalog, but procurement and landed cost entries in `client_stock_invoices` only link dynamically by string name/SKU rather than an explicit relationship.
- **Impact**: Merchants cannot see which supplier supplies which product until an invoice is manually raised, and the system cannot proactively prompt reorders to specific suppliers when stock drops.

#### 3. Redundancy: "Supply Stock" vs. "Stock Intake Invoice"
- **Current State**:
  - **Path A ("Supply Stock to NovaXpress" in Products Tab)**: Creates a consignment dispatch (`stock_transfers` table) allocating units to a DC without calculating procurement unit costs, packaging, freight, or handling fees. Valuation rate defaults to ₦0 or existing price.
  - **Path B ("Raise Stock Intake & Goods Receipt Invoice" in Inventory Tab)**: Itemizes landed costs (base supplier + packaging + freight + handling), updates the weighted average valuation rate in `client_stock_balances`, and writes a `purchase_receipt` to `client_stock_ledger_entries`.
- **Impact**: Having both active simultaneously creates confusion, double-handling, and bypasses landed cost math if a merchant uses Path A instead of Path B.

#### 4. Suppliers Directory: Under-represented in Card Format
- **Current State**:
  - `client_inventory_page.dart` Tab 3 renders suppliers as basic visual cards in a 2-column grid (`_buildSupplierCard`).
  - The cards only show: Supplier Name, Category, Contact Person, Payment Terms, Lead Time, and Bank Account.
  - The cards **do not show**:
    - Products supplied by the vendor.
    - Live remaining inventory units for those products in the network.
    - Low-stock or critical depletion warning indicators.
    - Quick actions to trigger a reorder or raise a stock intake invoice.
- **Impact**: Merchants cannot use the directory as an actionable replenishment hub; they must navigate between products, stock ledger, and suppliers to decide what to order.

#### 5. Massive Hardcoded Real Seed Data (917 Rows)
- **Current State**:
  - Migration `20260920110000_seed_pangea_stock_balances.sql` contains 917 hardcoded rows dumped from an ERP CSV.
  - Contains anomalous data (e.g., negative opening stock `-152.0`, duplicate warehouse names, zero-value entries).
  - All records were inserted with flat dates.
  - When testing date-range filtering in `fn_get_client_stock_balance_period`, historical movements are non-existent or skewed because all 917 records share the same baseline timestamp.
- **Impact**: Extreme query payload bloat (~230 KB per fetch), sluggish UI rendering, and inability to validate date-range filtering accurately.

#### 6. Layout Bug in Stock Intake Modal
- **Current State**:
  - In `client_raise_stock_invoice_modal.dart`, the bottom action row (`Row` containing note `Text`, `Spacer`, `OutlinedButton`, and `ElevatedButton.icon`) overflows by 28 pixels on screens under 820px width (visible in user screenshot 3).
- **Impact**: Unprofessional visual glitch with yellow/black debug overflow stripes in the UI.

#### 7. Merchant Executive Dashboard Needs Holistic Expansion
- **Current State**:
  - `client_dashboard_page.dart` only displays today's cash accumulator, basic shipment counts (Total, In-Transit, Delivered Today, Gross Delivered), quick action shortcuts, and live shipments.
  - It completely lacks inventory health KPIs, landed asset valuation, reorder alerts, and package sales velocity.
- **Impact**: Merchants must click into multiple sub-tabs to understand their operational health.

---

### Cross-System Component Matrix

| Component | Status | Audit Finding | Recommended Solution |
| :--- | :---: | :--- | :--- |
| **`clients` Table** | Healthy | Contains brand colors, tariffs, and service flags (`has_inventory_management`). | Expose in DC Edit Modal & validate constraints. |
| **`products` Table** | Needs Upgrade | Lacks `preferred_supplier_id` column. | Add `preferred_supplier_id UUID REFERENCES client_suppliers(id)`. |
| **`client_suppliers` Table** | Healthy | Has `supplied_products` array, lead times, payment terms. | Add supplier stock aggregation view/RPC. |
| **`client_stock_balances`** | Bloated | 917 hardcoded ERP dump rows with negative values. | Truncate and replace with 35 clean, multi-hub, date-tiered records. |
| **`client_stock_ledger_entries`**| Healthy | Immutable audit trail ready for period calculations. | Seed with tiered timestamps across Sept 1, 8, 15, and 19. |
| **`DCClientsPage`** | Incomplete | Only has "View Assets" & "Settlement". No Edit or 360° Management. | Build comprehensive Merchant 360° Console with tabs for Profile, Tariffs, Brand, and Custody. |
| **`ClientAddProductModal`** | Incomplete | No supplier attachment during creation. | Add optional "Preferred Supplier" selector with "+ Inline Add Supplier". |
| **`ClientProductsPage`** | Redundant | "Supply Stock" bypasses landed cost math. | Conditional routing: "Stock Intake" if `hasInventoryManagement`, else "Supply Stock". |
| **`ClientInventoryPage`** | Underpowered | Tab 3 uses static cards without stock quantities or alerts. | Upgrade Tab 3 to `PangeaExcelDataTable<ClientSupplierExpanded>`. |
| **`ClientRaiseStockInvoiceModal`**| Visual Bug | 28px overflow on bottom action row. | Wrap note in `Expanded`, make actions responsive. |
| **`ClientDashboardPage`** | Incomplete | No landed valuation, low stock alerts, or package velocity. | Add Landed Asset Valuation Card, Reorder Alerts, and Package Velocity. |
