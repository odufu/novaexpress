# NoveXPS System Audit & Architecture Report: Client Multi-Tenancy, DC Asset Management & Zero-Hardcoding Roadmap

## Executive Summary

This report delivers an exhaustive, end-to-end architectural audit of the **NoveXPS** platform across all system layers:
1. **Supabase Database Layer** (PostgreSQL schema, tables, constraints, foreign keys, triggers, and RPC procedures).
2. **Supabase Edge Functions** (`dispatch-order`, `geocode-and-dispatch`, `confirm-delivery-pod`, webhooks).
3. **Flutter Data Sources & Repositories** (`orders`, `stock`, `client_portal`, `auth`, `dc_console`, `finance`).
4. **State Management & Presentation Layer** (Riverpod providers, models, entities, pages, modals).
5. **Multi-Tenancy & Asset Ownership Contracts** (Client products, accompanied packages, order linkage, stock & remittance tracking).
6. **DC Console Capabilities** (Client creation, individual client asset tracking: products, packages, orders, remittances, and order handling).
7. **Complete Inventory of Hardcoded Placeholders & Fallbacks** (Every remaining occurrence of mock data).

---

## 1. Supabase Database Schema, Procedures & Edge Functions

### 1.1 Live Schema State & Gaps

| Table | Current Columns & Structure | Identified Gaps / Fixes Needed |
|---|---|---|
| `products` | `id`, `name`, `sku`, `base_price`, `category`, `client_id`, `client_name`, `company_id`, `stock_quantity`, `available_count`, `delivered_count`, `in_transit_count`, `low_stock_threshold`, `image_url`, `description`, `is_active` | ⚠️ **No native columns for `covering_states` or `dc_stocks`**: The system currently serializes regex JSON strings (`[COVERING_STATES: [...]]`, `[DC_STOCKS: {...}]`) inside the `description` TEXT column. Needs dedicated `covering_states TEXT[]` and `dc_stocks JSONB DEFAULT '{}'` columns for structured SQL querying and stock integrity. |
| `product_packages` | `id`, `product_id`, `product_name`, `product_sku`, `package_name`, `quantity`, `paid_quantity`, `free_quantity`, `package_price`, `client_id`, `client_name`, `description`, `is_custom` | ⚠️ **Non-unique Package IDs**: Package IDs are generated as `pkg-${sku.toLowerCase()}-${qty}`. If two clients use a generic SKU, their packages overwrite each other. Must enforce unique IDs: `pkg_${client_id}_${sku}_${quantity}` or UUID. |
| `orders` | `id`, `order_number`, `client_id`, `client_name`, `client_company`, `product_id`, `product_name`, `product_sku`, `package_deal_id`, `package_deal_name`, `quantity`, `paid_quantity`, `free_quantity`, `base_price`, `total_amount`, `client_delivery_fee`, `distribution_center_id`, `delivery_agent_id`, `status`, `remittance_status`, `financial_settlement_status` | ⚠️ Column names are `package_deal_id` and `package_deal_name`. Ensure all order creation and query payloads consistently populate both columns. |
| `client_settlements` | `id`, `client_id`, `company_id`, `settlement_number`, `period_start`, `period_end`, `total_orders_count`, `gross_collections`, `logistics_fees_deducted`, `net_payout_amount`, `destination_bank_name`, `destination_account_number`, `destination_account_name`, `status`, `payout_reference`, `settled_at` | ⚠️ **Lacks `distribution_center_id`**: Needed to track which DC regional hub originated or approved the merchant payout. Also, table is currently only queried in `ClientPortalRemoteDataSourceImpl` and is **100% missing from the DC Console**. |
| `cash_remittances` | `id`, `delivery_agent_id`, `distribution_center_id`, `amount`, `status`, `verified_at`, `payment_method`, etc. | ℹ️ Tracks **Rider COD remittances** from riders to the DC. Does NOT track client payouts (which belong in `client_settlements`). |
| `client_packages` | `id`, `client_id`, `tracking_number`, `package_label`, `declared_value`, `status`, etc. | ⚠️ Exists in Supabase schema but is **completely unused** in the Flutter app. |

### 1.2 Triggers & Stored Procedures

- **`auto_dispatch_order_by_state_lga(p_order_id UUID)`**:
  - Triggers automatically via `trg_orders_auto_dispatch` whenever an order is inserted with `delivery_agent_id IS NULL`.
  - Matches DC by State and LGA operating zones.
  - Matches active rider under the matched DC.
  - **Identified Gap**: If an order already has a specific `distribution_center_id` explicitly selected by a client or closer, the trigger should respect that DC rather than attempting a raw LGA lookup from scratch.

### 1.3 Edge Functions

- `dispatch-order` & `geocode-and-dispatch`: Functional for Nigerian centroid proximity routing.
- **Identified Gap**: No Edge Function or RPC exists to **batch-calculate client settlements** (aggregating delivered COD orders for a specific client over a date range and deducting logistics fees).

---

## 2. Pillar 1: Client Multi-Tenancy, Products, Packages & Stock/Remittance Tracking

### 2.1 Product & Package Creation & Strict Isolation

#### Current Vulnerabilities:
1. **Global Product Catalog Loading**: In `ProductCatalogNotifier` (`product_catalog_provider.dart`), `reloadCatalog()` fetches ALL products from Supabase (`dbClient.from('products').select()`) and stores them in a single un-scoped state.
2. **Cross-Tenant Product Bleed**: In `ClientPortalNotifier` (`client_portal_provider.dart` line 575), filtering relies on `p.clientId == clientId || p.clientName == companyName`. If a newly registered client has 0 products, the app falls back to Novacale demo orders or empty catalog.
3. **Hardcoded Fallback Defaults**: If a product has fewer than 2 packages, `buildDefaultPackagesForProduct()` automatically injects 4 hardcoded package tiers (`1 Unit`, `2-Pack Special Deal`, `3-Pack Value Deal`, `5-Pack Mega Deal (4 + 1 Free)`) with calculated pricing formulas. If the client deletes them, the app forces them back (`line 607`).
4. **Package ID Collision**: Package IDs do not include `client_id`, meaning package rows in Supabase can overwrite each other across clients if SKUs match.

#### Required Fixes:
- Scope `ProductCatalogNotifier` and `ClientPortalNotifier` to query `products` where `client_id.eq.$clientId`.
- Give clients complete autonomy over their commercial packages: allow creating custom packages (quantity, paid units, free promo bonus units, package price) without forcing unwanted auto-generated defaults.
- Prefix package IDs with `client_id`: `pkg_${clientId}_${productSku}_${quantity}`.
- Ensure only packages created by this client and belonging to the selected product are displayed.

### 2.2 Order Creation with Attached Product & Package

#### Current Status & Fixes:
- `ClientCreateOrderModal` properly captures `_selectedProduct` and `_selectedPackage`.
- In `client_portal_provider.dart` (`createOrder`), `packageDealId: packageId` and `packageDealName: packageName` are properly passed to `ordersProvider.notifier.createOrder`.
- **Fix Required**: Remove all fallback product names (e.g., `'Grazer Tea'`, `'Respira Detox Tea'`) and fallback prices from `client_portal_provider.dart` and `client_create_order_modal.dart`. If no products exist, disable order creation until a product is registered.

### 2.3 Live Stock & Remittance Tracking for Clients

#### Current Status:
- **Stock Tracking**: `ClientProductsPage` displays total stock across hubs, but parses it from `products.description`.
- **Remittance Tracking**: `ClientFinancePage` computes:
  - **Gross Delivered Value** (total COD collected by riders for this client's products)
  - **Logistics Delivery Fees** (deducted platform delivery fees)
  - **Money Outside** (cash active in-transit with riders)
  - **Awaiting Remittance** (cash in DC custody ready for payout)
  - **Remitted to Bank** (settled payouts)
- **Fix Required**:
  - Store stock directly in `products.dc_stocks` (or `products.available_count`) rather than regex tags in `description`.
  - Connect `ClientFinancePage` settlement history directly to live `client_settlements` records in Supabase (currently lines 630-632 fall back to `_generateSeedSettlements(clientId)`).

---

## 3. Pillar 2: DC Console Client Creation, Individual Client Asset Tracking & Order Management

### 3.1 Proper Client Creation by DCs

#### Current Status:
- `DCOnboardClientModal` collects Company Name, Client Code, Contact Person, Phone, Email, Password, Office Address, Depot State, Service Tier (Enterprise vs Standard), Closer Limit, and Banking Details.
- `dc_console_remote_datasource.dart` (`createClient`) inserts into `clients` and provisions Supabase Auth.
- **Fix Required**:
  - In `DCOnboardClientModal`, remove hardcoded hints and defaults (`Novacale Limited`, `ClientPass2026!`, `Access Bank`).
  - In `dc_console_provider.dart`, eradicate `defaultRegisteredClients` (which hardcoded Novacare and Novacale). Always load clients authoritatively from the Supabase `clients` table.

### 3.2 Tracking Individual Clients & Client Assets (The Major Missing Feature)

#### Critical Discovery:
In `DCClientsPage` (`dc_clients_page.dart`), client rows are **completely non-interactive**. A DC manager cannot click on a client to view their assets!

#### Feature Addition: DC Client Asset Management Console
When a DC manager clicks on any client in `DCClientsPage`, open a comprehensive **DC Client Asset Detail Modal/Page** displaying:
1. **Client Profile & Governance Tab**:
   - Company Name, Client Code, Contact Person, Phone, Email, Address, Depot State.
   - Service Tier, Closer Capacity, Status.
   - Settlement Banking Details (Bank, Account Number, Account Name, Settlement Frequency).
2. **Client Products & DC Inventory Tab**:
   - Every product registered by this client.
   - Stock quantities: Units in this DC Hub, Units across other Network DCs, Units in transit with riders.
   - Action: **"Receive Inbound Stock / Waybill"** directly for this client's product at this DC.
   - Product packages attached to each product.
3. **Client Package Deals Tab**:
   - All commercial package configurations belonging to this client.
4. **Client Orders Tab**:
   - All orders placed by or belonging to this client routed to this DC.
   - Live status filter (Pending Dispatch, Assigned, In Transit, Delivered, Failed).
   - Instant action to assign/reassign to DC riders.
5. **Client Financial Remittances & Settlements Tab**:
   - Total COD collected by DC riders for this client.
   - Logistics fees deducted.
   - Net balance awaiting remittance payout.
   - Historical settlements from `client_settlements`.
   - Action: **"Process Merchant Settlement"** (generates payout record with reference, bank details, and marks associated orders as settled).

### 3.3 Handling & Managing Orders Automatically Routed to DC

#### Current Status & Fixes:
1. **DC Scoping**: In `orders_provider.dart` (`_filterOrdersForCurrentScope`), `OrderRoutingService.doesOrderBelongToDc` uses State/LGA matching.
   - **Fix**: Check `order.distributionCenterId == currentDc.id` FIRST. If the order has already been assigned to this DC ID, it belongs to this DC unconditionally.
2. **DC Order Creation Draft State**: In `dc_create_order_modal.dart` (`DCCreateOrderDraftState`), remove all hardcoded defaults (`Grazer Tea`, `22000.0`, `cli-novacale-001`, `Dr. Chuka Okafor`, `Novacale Limited`, `08034455667`). Let the DC manager select from the live list of registered clients and that client's specific products/packages!
3. **In-Memory Order Masking**: In `orders_remote_datasource.dart`, remove reliance on static `_createdOrders` so all orders are confirmed live in Supabase.

---

## 4. Complete Inventory of Hardcoded Placeholders & Fallbacks

The following table catalogs every hardcoded fallback, placeholder, or demo data currently in the codebase that must be replaced:

| File | Line(s) | Hardcoded Element | Required Dynamic Replacement |
|---|---|---|---|
| `lib/features/auth/data/datasources/auth_remote_datasource.dart` | 1378-1383 | `first_name = 'Merchant'`, `last_name = 'Admin'`, `delivery_agent_code = 'CLI-01'` | Parse actual client contact person or user's registered name. |
| `lib/features/auth/data/datasources/auth_remote_datasource.dart` | 1387-1388, 1415-1417 | `Adekunle Supervisor`, `Wuse Central Distribution Hub`, `22222222-2222-4222-8222-222222222222` | Resolve DC staff's assigned DC from `users.distribution_center_id` or `distribution_centers` table. |
| `lib/features/auth/data/datasources/auth_remote_datasource.dart` | 1421-1425 | `distribution_center_id = '22222222...'`, `Joel/Emeka Rider` | Resolve from `delivery_agents` record in Supabase. |
| `lib/features/client_portal/presentation/providers/client_portal_provider.dart` | 476-489 | `ClientPortalState` initial clientProfile defaults to Novacale Limited, Dr. Chuka Okafor, `08034455667`, `CLI-NOVACALE-01` | Initialize with neutral empty values until auth user profile loads. |
| `lib/features/client_portal/presentation/providers/client_portal_provider.dart` | 569-571 | `clientId = user?.clientId ?? '33333333-3333...'`, `companyName = ... 'Novacale Limited'` | Strictly use authenticated user's `clientId` and `clientCompanyName`. |
| `lib/features/client_portal/presentation/providers/client_portal_provider.dart` | 594-597, 624-632 | `_generateSeedOrders`, `_generateSeedClosers`, `_generateSeedLeads`, `_generateSeedSettlements` | Only use if user explicitly requests demo mode; otherwise show clean empty states. |
| `lib/features/client_portal/presentation/providers/client_portal_provider.dart` | 643-660 | `ClientProfile` fallback hardcodes `Zenith Bank`, `1012345678`, Novacale contact person | Use actual client record from `clients` table; leave empty if not set. |
| `lib/features/client_portal/presentation/providers/client_portal_provider.dart` | 1528, 1538 | `importOrdersCsv` falls back to `Grazer Tea`, `prod-grazer-01` | Require product selection from client's catalog. |
| `lib/features/dc_console/presentation/widgets/dc_create_order_modal.dart` | 40-55 | `DCCreateOrderDraftState` defaults to `Grazer Tea`, `22000.0`, `cli-novacale-001`, `Dr. Chuka Okafor`, `Novacale Limited`, `08034455667` | Default to null/empty; prompt DC user to select Client first, then Client's Product, then Package. |
| `lib/features/dc_console/presentation/widgets/dc_csv_order_import_modal.dart` | 307-313 | CSV import fallbacks to `Respira Detox Tea`, `Novacare Limited`, `Wuse 2`, `FCT - Abuja` | Fail validation or require client & product mapping if columns are empty. |
| `lib/features/dc_console/presentation/pages/dc_stock_page.dart` | 1132, 1160-1166 | `final clientCtrl = TextEditingController(text: 'Novacare Limited')`, `companyMap['Novacare Limited']` | Use dynamic client dropdown from `dcConsoleProvider.clients`. |
| `lib/features/dc_console/presentation/pages/dc_orders_page.dart` | 736 | `final client = o.clientName.isNotEmpty ? o.clientName : 'Novacare'` | Use `o.clientName.isNotEmpty ? o.clientName : 'Unassigned Client'`. |
| `lib/features/dc_console/presentation/providers/product_catalog_provider.dart` | 73, 93, 245, 534, 705 | Fallback `clientName = 'Novacare Limited'` | Use empty string or require clientName parameter. |
| `lib/features/stock/presentation/providers/stock_provider.dart` | 511, 559 | `String ownerName = 'Novacare Limited'` | Require `ownerName` and `clientId`. |
| `lib/features/stock/data/models/stock_item_model.dart` | 10, 48 | `ownerName = 'Novacare Limited'` | Use `json['owner_name'] ?? json['client_name'] ?? ''`. |
| `lib/features/stock/data/datasources/stock_remote_datasource.dart` | 465, 530, 602, 952 | Fallbacks to `'Novacare Limited'` | Use actual `client_name` from DB. |
| `lib/features/orders/data/datasources/orders_remote_datasource.dart` | 313, 317, 318 | `product_name ??= 'Respira Detox Tea'`, `delivery_state ??= 'FCT - Abuja'` | Require non-empty values from order payload. |
| `lib/features/dc_console/presentation/providers/dc_console_provider.dart` | 72-103 | `defaultRegisteredClients` (Novacare & Novacale) | Remove static list; load exclusively from Supabase `clients` table. |
| `lib/features/client_portal/domain/entities/client_settlement.dart` | 36, 67 | `destinationAccountName = 'Novacale Limited'` | Use empty string default. |

---

## 5. Architectural Implementation Roadmap

```mermaid
flowchart TD
    subgraph DB [1. Supabase Database & Migrations]
        M1[Add covering_states TEXT[] & dc_stocks JSONB to products]
        M2[Add distribution_center_id to client_settlements]
        M3[Enforce unique package_id with client_id prefix]
    end

    subgraph CP [2. Client Portal Multi-Tenancy & Isolation]
        C1[Scope ProductCatalogNotifier by client_id]
        C2[Client custom package creation without forced defaults]
        C3[Order creation attaching Client Product & Package]
        C4[Real-time Stock & Remittance tracking from Supabase]
    end

    subgraph DC [3. DC Console Asset Management & Routing]
        D1[Interactive DCClientsPage row navigation]
        D2[New DC Client Detail & Asset Management View]
        D3[DC Stock receiving & allocation for client products]
        D4[DC Client Settlement Generation & Payout ledger]
        D5[Order Routing priority: explicit DC ID first]
    end

    subgraph Clean [4. Zero-Hardcoding Cleanup]
        Z1[Remove Novacale/Novacare defaults across all datasources & models]
        Z2[Remove static seed fallbacks for real users]
        Z3[Make all order creation draft states dynamic]
    end

    DB --> CP
    DB --> DC
    CP --> Clean
    DC --> Clean
```

### Proposed Phased Execution:

1. **Phase 1: Supabase Schema Upgrade & Migration**
   - Add `covering_states TEXT[]` and `dc_stocks JSONB DEFAULT '{}'` to `products`.
   - Add `distribution_center_id UUID` to `client_settlements`.
   - Update `auto_dispatch_order_by_state_lga` to honor explicit `distribution_center_id` when present.

2. **Phase 2: Client Portal Multi-Tenant Isolation & Package Autonomy**
   - Scope product catalog queries strictly to the authenticated client.
   - Allow clients to create, edit, and delete their own packages without forced 4-tier re-injection.
   - Link orders to `package_deal_id` and `package_deal_name`.
   - Wire `ClientFinancePage` settlement history directly to `client_settlements`.

3. **Phase 3: DC Console Individual Client Asset Tracking & Client Settlements**
   - Make `DCClientsPage` rows clickable.
   - Build **DC Client Asset Detail Modal/Page** (Client Profile, Client Products & Stock, Client Packages, Client Orders, Client Remittances & Settlements).
   - Add DC capability to generate and disburse client settlement payout batches.
   - Update `OrderRoutingService.doesOrderBelongToDc` to check `order.distributionCenterId == currentDc.id` first.

4. **Phase 4: Eradication of All Hardcoded Fallbacks & Verification**
   - Clean out all 20+ cataloged hardcoded fallbacks in `auth_remote_datasource.dart`, `dc_create_order_modal.dart`, `dc_stock_page.dart`, `stock_remote_datasource.dart`, `client_portal_provider.dart`, etc.
   - Validate with full unit/integration test suite.
