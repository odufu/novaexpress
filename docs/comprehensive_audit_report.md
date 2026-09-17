# NoveXPS Comprehensive Architectural & Operational Audit Report

**Date**: September 2026  
**Audited Subsystems**:
1. Distribution Center (DC) Creation & Management
2. Order Creation & Lifecycle Management
3. 2-Tier Order Routing Engine (Geographic, Proximity & Fleet Allocation)
4. End-to-End Stock Management (Client -> Handling DC -> Fleet Rider -> POD / Return Reversal)
**Scope**: PostgreSQL Database Schema, Triggers, Stored Procedures, Supabase Edge Functions, and Flutter Client Application Layer.

---

## Executive Summary

A deep-dive, holistic audit of the NoveXPS platform was conducted across all tiers. While recent upgrades successfully established strict multi-tenant chat isolation, authoritative package deal pricing in `public.product_packages`, and real-time audio event streaming, several critical architectural gaps, hardcoded fallbacks, schema desynchronizations, and unimplemented dummy stubs remain active in the codebase.

### Top Critical Findings:
1. **Unimplemented Stock Stubs**: Core stock operations (`requestStockTransfer`, `confirmStockHandover`, `processStockReturn`, and `submitInventoryAudit`) in `StockRemoteDataSourceImpl` are unimplemented dummy stubs returning `{'status': 'success'}` without writing to the database.
2. **Broken Edge Function Schema**: `supabase/functions/request-stock-transfer` references non-existent database columns (`stock_transfer_id`, `quantity_sent`), causing SQL errors on execution.
3. **Hardcoded Fallbacks to Wuse Central DC**: In `orders_remote_datasource.dart:183`, any order created without an explicit DC UUID silently defaults to `'22222222-2222-4222-8222-222222222222'` (Wuse Central DC), causing nationwide orders (e.g. Lagos, Kano) to be misrouted. Similarly, CSV bulk order import omits DC assignment, sending all imported orders to Wuse Central.
4. **Dual Competing Routing Engines**: A client-side routing engine in Dart (`OrderRoutingService`) and a database-side routing trigger (`auto_dispatch_order_by_state_lga`) conflict. The database trigger ignores pre-assigned DC IDs if unassigned riders are present and re-routes orders independently.
5. **Stock-Blind Order Routing**: Client order creation passes `stockAllocations: const []` to the routing engine, completely bypassing vehicle custody validation. Orders are assigned to riders who possess 0 units of the ordered product.
6. **Delivery POD Stock Disconnect**: `confirm-delivery-pod` decrements `products.stock_quantity`, but fails to deduct from the delivering rider's vehicle warehouse custody. Failed deliveries (`log-delivery-failure`) never restore or log stock returns.
7. **Swallowed PostgreSQL Exceptions**: `updateRiderStockCustody` attempts to insert non-UUID string `'SYS-CUSTODY-SYNC'` into a UUID column and omits `distribution_center_id` (a NOT NULL column), silently failing inside empty `catch (_)` blocks.
8. **Text Tag Serialization**: Products still serialize `[COVERING_STATES: ...]`, `[DC_STOCKS: ...]`, and `[ORIGIN_DC: ...]` into the text `description` column despite first-class `covering_states` and `dc_stocks` columns existing in PostgreSQL.

---

## 1. Domain 1: Distribution Center (DC) Creation & Management

### 1.1 Database & Stored Procedures Layer
- **Hierarchy Flag Redundancy**: The `distribution_centers` table contains three competing hierarchy columns across different migrations:
  - `is_hub BOOLEAN DEFAULT false` (from initial schema)
  - `is_primary_dc BOOLEAN DEFAULT false` (from `20260907180000_fix_distribution_centers_schema.sql`)
  - `is_grand_dc BOOLEAN DEFAULT false` (from `20260902110000_hierarchical_dc_dispatch_and_lga_routing.sql`)
  *Impact*: Queries in different parts of the system check different flags to identify primary hub stations.
- **Operating Zones Data Type Inconsistency**: `operating_zones` was defined as `JSONB` in earlier migrations and `TEXT[]` in later scripts. Stored procedures (`auto_dispatch_order_by_state_lga`) must perform defensive casting (`operating_zones @> to_jsonb(v_lga) OR operating_zones::text ILIKE ...`).
- **Missing Coordinates**: `distribution_centers` lacks `latitude` and `longitude` columns. Proximity dispatch calculations cannot measure the distance between an order delivery address and the handling DC.

### 1.2 Edge Functions Layer
- In `dispatch-order/index.ts:105`:
  ```typescript
  const targetDc = grandDc || (allDcs && allDcs[0]) || { id: "dc-hq-fallback", name: "Grand DC National HQ" };
  ```
  If no DC is found, it attempts to assign `{ id: "dc-hq-fallback" }`. Because `orders.distribution_center_id` is a UUID foreign key referencing `distribution_centers(id)`, this causes a fatal PostgreSQL type error (`invalid input syntax for type uuid: "dc-hq-fallback"`).

### 1.3 Flutter Application Layer
- **Hardcoded Fallbacks in `dc_console_remote_datasource.dart`**:
  - Line 186 & 247: `'company_id': '11111111-1111-4111-8111-111111111111'` is hardcoded as default company ID.
  - Line 147: `'storage_capacity_units': 25000` is hardcoded when unprovided.
- **Hardcoded DC State Map Cache in `stock_remote_datasource.dart:156-160`**:
  ```dart
  final map = <String, String>{
    '22222222-2222-4222-8222-222222222222': 'Federal Capital Territory',
    '00000000-0000-4000-8000-788825051520': 'Benue',
    '00000000-0000-4000-8000-788889180011': 'Ekiti',
  };
  ```
  Static UUID mappings act as fallbacks instead of exclusively querying `distribution_centers` table.
- **Supervisor Account Provisioning Rollback**: In `dc_console_remote_datasource.dart:238`, if supervisor Auth registration fails, the newly created DC row is deleted, but if the Auth user was created and metadata insertion fails, the user becomes an unlinked orphan in Supabase Auth.

---

## 2. Domain 2: Order Creation & Lifecycle Management

### 2.1 Database & Stored Procedures Layer
- **Hardcoded Default Values in Schema (`20260819180000_full_schema_pda_system.sql`)**:
  - Line 288: `product_name VARCHAR(255) DEFAULT 'Respira Detox Tea'`
  - Line 299: `client_delivery_fee NUMERIC(14, 2) DEFAULT 5000.00`
  - Line 300: `agent_entitlement NUMERIC(14, 2) DEFAULT 2500.00`
  - Line 326: `account_name VARCHAR(255) NOT NULL DEFAULT 'NovaXpress / Novacare'`
  - Line 327: `bank_name VARCHAR(100) NOT NULL DEFAULT 'Wema Bank / Monnify'`
  *Impact*: Any order row inserted without explicit values silently receives obsolete brand names (`Novacare`, `Respira Detox Tea`) and fixed delivery fees.

### 2.2 Flutter Application Layer
- **Hardcoded Fallback Product & DC in `orders_remote_datasource.dart`**:
  - Line 176: `validProductId = 'a1b2c3d4-0000-4000-8000-000000000001'` (hardcoded fake UUID if product resolution fails).
  - Line 183: `dcId = insertPayload['distribution_center_id'] ?? '22222222-2222-4222-8222-222222222222'` (forces unassigned orders to Wuse Central DC).
  - Line 216: `final basePrice = insertPayload['base_price'] ?? 25000.0` (hardcoded ₦25,000 fallback).
- **CSV Order Import Missing DC Scoping (`dc_csv_order_import_modal.dart`)**:
  - Lines 61-80: `ParsedCsvOrderRow.toOrderPayload()` does not supply `distribution_center_id`.
  - When a DC Manager in Kano or Port Harcourt uploads a CSV manifest, the payload hits `orders_remote_datasource.dart:183`, which defaults `distribution_center_id` to Wuse Central DC (`22222222-2222-4222-8222-222222222222`). The imported orders vanish from the importing DC's view and appear in Abuja!
  - Line 318: Total amount defaults to `qty * 25000.0` if amount is unparsed.
- **Client Name Resolution Fallback**:
  - Lines 246-285 of `orders_remote_datasource.dart`: Multi-level fallback attempts to lookup client name from `clients`, then from `products.client_name`, then defaults to empty string `''`.

---

## 3. Domain 3: Order Routing & Dispatch Engine

### 3.1 Dual Competing Routing Architecture
There are two completely separate routing engines operating simultaneously:
1. **Client-Side Engine**: `OrderRoutingService.routeOrder` (`order_routing_service.dart`) in Flutter.
2. **Database Engine**: `auto_dispatch_order_by_state_lga` triggered by `trg_orders_auto_dispatch_after_insert` on PostgreSQL `orders` table.

#### The Conflict:
- When an order is created via Client Portal or DC Console, the Flutter UI evaluates `OrderRoutingService.routeOrder` and assigns a DC (e.g. Kano Station DC) and optionally a Rider.
- If no rider was auto-assigned client-side, the inserted order row has `status = 'pending_dispatch'` and `delivery_agent_id = NULL`.
- This immediately fires PostgreSQL trigger `trg_orders_auto_dispatch_after_insert`, which executes `auto_dispatch_order_by_state_lga(NEW.id)`.
- `auto_dispatch_order_by_state_lga` does NOT check if `orders.distribution_center_id` is already populated. It recalculates the DC from scratch based on `NEW.delivery_state` and `NEW.lga`. If the state/LGA strings do not exactly match the DC's configured `operating_zones`, it overrides `distribution_center_id` with Grand DC (`v_grand_dc.id`), undoing the caller's explicit DC selection!

### 3.2 Vehicle Custody Stock-Blind Routing
- In `client_portal_provider.dart:1142`:
  ```dart
  final routingResult = OrderRoutingService.routeOrder(
    order: provisionalOrder,
    distributionCenters: allDcs,
    drivers: allDrivers,
    stockAllocations: const [], // <-- EMPTY LIST SUPPLIED!
  );
  ```
  `stockAllocations` is hardcoded as an empty list `const []`.
- Although `OrderRoutingService` contains sophisticated logic to check `currentCustody >= order.quantity`, passing `const []` causes the service to fall back to:
  ```dart
  if (stockAllocations.isEmpty) {
    bestDriver = eligibleDrivers.first;
  }
  ```
  Consequently, orders are assigned to riders who do not have physical custody of the item.
- In PostgreSQL `auto_dispatch_order_by_state_lga`: The stored procedure has zero checks for rider vehicle stock or DC stock inventory. It assigns the first active rider covering the LGA regardless of inventory availability.

### 3.3 Geocoding & Proximity Routing Fallbacks
- In `geocode-and-dispatch/index.ts:180-186`:
  ```typescript
  if (!resolvedLat || !resolvedLng) {
    resolvedLat = 6.4474;
    resolvedLng = 3.4839;
    resolvedAddress = `${targetAddress}, ${targetCity}, ${targetState}, Nigeria`;
    confidence = 0.30;
    status = "locality_fallback";
  }
  ```
  Unresolvable addresses across all 36 states receive hardcoded coordinates for Lekki Phase 1, Lagos (`6.4474, 3.4839`). An order meant for Sokoto or Maiduguri is geocoded to Lagos, causing distance calculations in `auto_dispatch_order` to fail.

---

## 4. Domain 4: End-to-End Stock Management (Client -> DC -> Rider)

### 4.1 Client Stock Supply & Serialization Inconsistencies
- **Description Column Metadata Packing**:
  In `stock_remote_datasource.dart:507-524`:
  ```dart
  var finalDesc = description ?? '$name - Distributed Inventory';
  if (imageAsset != null) finalDesc = '$finalDesc [IMAGE_URL: ${imageAsset.trim()}]';
  if (coveringStates != null) finalDesc = '$finalDesc [COVERING_STATES: ${jsonEncode(coveringStates)}]';
  if (dcStocks != null) finalDesc = '$finalDesc [DC_STOCKS: ${jsonEncode(dcStocks)}]';
  ```
  Even though migration `20260913130000` introduced `covering_states TEXT[]` and `dc_stocks JSONB` columns on `public.products`, `createProduct` still serializes these structures as regex strings into the text `description` column.
- **Silent Exception Swallowing in `receiveStock`**:
  In `stock_remote_datasource.dart:829`:
  ```dart
  } catch (_) {
    return true;
  }
  ```
  If updating `products` fails, the error is swallowed and returns `true`, causing the UI to report successful stock receipt even when database persistence failed.

### 4.2 Unimplemented Stock Stubs in Flutter (`StockRemoteDataSourceImpl`)
The following core methods in `lib/features/stock/data/datasources/stock_remote_datasource.dart` are unimplemented dummy stubs:
1. `requestStockTransfer`:
   ```dart
   @override
   Future<Map<String, dynamic>> requestStockTransfer({...}) async => {'status': 'success'};
   ```
2. `confirmStockHandover`:
   ```dart
   @override
   Future<Map<String, dynamic>> confirmStockHandover({...}) async => {'status': 'success'};
   ```
3. `processStockReturn`:
   ```dart
   @override
   Future<Map<String, dynamic>> processStockReturn({...}) async => {'status': 'success'};
   ```
4. `submitInventoryAudit`:
   ```dart
   @override
   Future<Map<String, dynamic>> submitInventoryAudit({...}) async => {'status': 'success'};
   ```
*Impact*: None of these user actions write to PostgreSQL tables (`stock_transfers`, `stock_returns`, `inventory_audits`).

### 4.3 Broken Schema in Edge Function `request-stock-transfer`
In `supabase/functions/request-stock-transfer/index.ts:66-73`:
```typescript
const transferItems = payload.items.map((item) => ({
  stock_transfer_id: transfer.id,    // <-- Column is 'transfer_id' in PostgreSQL!
  product_id: item.productId,
  quantity_sent: item.quantityRequested, // <-- Column is 'quantity_shipped' in PostgreSQL!
  quantity_received: 0,
}));
await supabaseClient.from("stock_transfer_items").insert(transferItems);
```
`stock_transfer_items` table (defined in `20260907160000_warehouses_and_transfers.sql`) has columns:
`id`, `transfer_id`, `product_id`, `quantity_shipped`, `quantity_received`.
Calling this Edge Function throws: `column "stock_transfer_id" of relation "stock_transfer_items" does not exist`.

### 4.4 Hardcoded Rider Vehicle Warehouse State
In `stock_remote_datasource.dart:721`:
```dart
final newW = await dbClient.from('warehouses').insert({
  'company_id': compId,
  'rider_id': resolvedRiderAgentId,
  'name': '$riderName ($riderCode) Vehicle Stock',
  'type': 'rider_mini_hub',
  'location_state': 'Abuja (FCT)', // <-- Hardcoded for all riders nationwide!
  'address': 'Vehicle Mobile Custody',
  'is_active': true,
}).select().single();
```
Every new rider warehouse created nationwide is tagged with `'Abuja (FCT)'`, corrupting regional warehouse reporting.

### 4.5 Delivery POD & Failure Stock Lifecycle Disconnect
1. **Delivery POD Confirmation (`confirm-delivery-pod/index.ts:79-100`)**:
   - Decrements `products.stock_quantity`.
   - **Does NOT** decrement `stock_transfer_items` or the rider's active vehicle custody in `warehouses`.
   - The rider's vehicle stock count in `getRiderStockAllocations` has to compute custody through dynamic order reconciliation rather than an authoritative ledger.
2. **Failed Delivery Logging (`log-delivery-failure/index.ts:40-58`)**:
   - Updates order status to `cancelled` or `call_back`.
   - **Does NOT** record any return in `stock_returns` or restore warehouse stock.
3. **Invalid Custody Update in `updateRiderStockCustody` (`stock_remote_datasource.dart:1049-1058`)**:
   ```dart
   await dbClient.from('stock_returns').insert({
     'return_number': 'AUDIT-${DateTime.now().millisecondsSinceEpoch}',
     'order_id': 'SYS-CUSTODY-SYNC', // <-- INVALID UUID!
     'delivery_agent_id': riderId,
     'product_id': productId,
     'quantity': deliveredDelta > 0 ? deliveredDelta : returnedDelta,
     'reason': 'Real-time lifecycle balance update',
     'status': 'reconciled',
     'created_at': DateTime.now().toIso8601String(),
   });
   ```
   - `order_id` is a `UUID` column in `stock_returns`. Inserting string `'SYS-CUSTODY-SYNC'` causes PostgreSQL error `22P02: invalid input syntax for type uuid`.
   - `distribution_center_id` is defined as `UUID NOT NULL REFERENCES distribution_centers(id)`, but is omitted here.
   - The method catches and ignores the error, meaning custody updates fail 100% of the time.

---

## 5. Summary Matrix of Findings & Remediation Plan

| ID | Subsystem | File / Component | Severity | Description | Remediation |
|---|---|---|---|---|---|
| **GAP-01** | Stock | `stock_remote_datasource.dart:1063-1194` | **CRITICAL** | 4 methods (`requestStockTransfer`, `confirmStockHandover`, `processStockReturn`, `submitInventoryAudit`) are dummy stubs returning fake maps. | Implement full Supabase persistence against `stock_transfers`, `stock_returns`, and `inventory_audits`. |
| **GAP-02** | Stock | `supabase/functions/request-stock-transfer/index.ts` | **CRITICAL** | Edge function inserts into non-existent columns (`stock_transfer_id`, `quantity_sent`). | Fix column names to `transfer_id` and `quantity_shipped`. |
| **GAP-03** | Orders | `orders_remote_datasource.dart:183` & `dc_csv_order_import_modal.dart` | **CRITICAL** | Orders without DC ID and CSV bulk imports default to Wuse Central DC (`22222222...`). | Pass active DC ID from context; allow `distribution_center_id` to remain null so auto-dispatch routes properly. |
| **GAP-04** | Routing | `20260911140000...sql:38` vs `client_portal_provider.dart` | **HIGH** | DB trigger `auto_dispatch_order_by_state_lga` overwrites caller's DC selection if order has no rider. | Update stored procedure to honor existing `distribution_center_id` when present. |
| **GAP-05** | Routing | `client_portal_provider.dart:1142` | **HIGH** | `stockAllocations: const []` is hardcoded, bypassing vehicle stock check during routing. | Pass live rider stock allocations from `stockProvider` into `OrderRoutingService.routeOrder`. |
| **GAP-06** | Stock | `stock_remote_datasource.dart:1049-1058` | **HIGH** | `updateRiderStockCustody` passes non-UUID `'SYS-CUSTODY-SYNC'` and omits NOT NULL `distribution_center_id`. | Use valid nullable UUID for `order_id` and resolve rider's DC ID before insertion. |
| **GAP-07** | Stock | `confirm-delivery-pod/index.ts` & `log-delivery-failure/index.ts` | **HIGH** | POD decrements global product stock but ignores rider vehicle warehouse; failures do not log returns. | Update rider warehouse allocation on POD; log `stock_returns` on permanent failure. |
| **GAP-08** | Stock | `stock_remote_datasource.dart:507-524` | **MEDIUM** | Products serialize `[DC_STOCKS]`, `[COVERING_STATES]` into text description instead of first-class DB columns. | Write directly to `covering_states TEXT[]` and `dc_stocks JSONB` columns on `products`. |
| **GAP-09** | DC | `distribution_centers` table | **MEDIUM** | Missing `latitude` and `longitude`; redundant hierarchy flags (`is_hub`, `is_grand_dc`, `is_primary_dc`). | Add coordinates to `distribution_centers`; consolidate hierarchy into `is_grand_dc` and `is_hub`. |
| **GAP-10** | Geocoding | `geocode-and-dispatch/index.ts:180-186` | **MEDIUM** | Hardcoded Lekki coordinates (`6.4474, 3.4839`) as fallback for all unresolvable addresses nationwide. | Use state-level centroid matching before resorting to national centroid. |
| **GAP-11** | Orders | `20260819180000...sql:288-327` | **LOW** | Schema contains obsolete defaults (`Respira Detox Tea`, `Novacare`, `5000.00` fee). | Remove default string literals on `orders.product_name`, `companies`, and `monnify_virtual_accounts`. |
