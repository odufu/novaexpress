# Phase 6: Mobile Rider App, Physical Audit & Returns Handshake Plan

**Document Path:** `c:\PROJECT\NoveXPS\inventry fix\06_mobile_rider_and_returns_handshake_plan.md`  
**Target Files:**
1. `lib/features/stock/presentation/pages/stock_page.dart`
2. `lib/features/stock/presentation/pages/inventory_audit_page.dart`
3. `lib/features/stock/presentation/widgets/return_stock_modal.dart`
4. `lib/features/stock/presentation/pages/stock_details_grazer_page.dart`
5. `lib/features/stock/presentation/widgets/stock_barcode_search_modal.dart` (New)

---

## 1. Remediation for `return_stock_modal.dart`

### 1.1 Root Cause
When a rider initiates a return, the modal creates a record in `stock_returns`, but does not bind the return to the destination DC, does not enforce maximum custody constraints, and has no return waybill identifier for DC verification.

### 1.2 Required Remediation
1. **Dynamic Vehicle Custody Binding**:
   - Filter selectable products strictly to those where `agent_inventory.available_count > 0`.
   - Set max stepper value to the rider's active vehicle custody for that SKU.
2. **Select Destination Distribution Center**:
   - Add a DC selector dropdown defaulting to the rider's assigned home DC.
3. **Capture Return Reason & Condition**:
   - Reason options: `'End of Shift Restock'`, `'Customer Refusal'`, `'Damaged in Transit'`, `'Wrong Item Dispatched'`.
   - Condition radio: `'Good / Sellable'` vs `'Damaged / Quarantined'`.
4. **Waybill & Handshake Receipt**:
   - On submit, insert into `stock_returns` with status `'submitted'`.
   - Display a "Return Handshake Code" (e.g. `RET-8842`) and QR code so the DC receiving supervisor can quickly scan and verify upon rider arrival at the DC dock.

---

## 2. Remediation for `inventory_audit_page.dart`

### 2.1 Root Cause
Lines 1361-1395 in `stock_provider.dart` only write the audit counts to in-memory state and local SharedPreferences. The Supabase tables `public.inventory_audits` and `public.inventory_audit_items` are never written to, depriving management of audit compliance records.

### 2.2 Required Remediation
1. **Live System Comparison**:
   - For each SKU in the rider's custody, display:
     - Expected Count (from `agent_inventory.available_count`).
     - Physical Count (entered by rider).
     - Live Variance = $\text{Physical Count} - \text{Expected Count}$.
2. **Mandatory Variance Reason**:
   - If variance $\neq 0$, make the variance reason field mandatory (e.g., `'Count Mistake'`, `'Item Lost in Transit'`, `'Packaging Damaged'`, `'Sample Given'`).
3. **Supabase Persistence**:
   - Wire `_submitAudit()` to `stockNotifierProvider.notifier.submitRiderStockAudit()`, which executes `submitStockAuditToSupabase()`.
   - Show a success confirmation dialog with the generated Audit Reference number.

---

## 3. Remediation for `stock_details_grazer_page.dart`

### 3.1 Root Cause
Lines 22-48 contain hardcoded strings and fallbacks:
```dart
productName = 'Respira Detox Tea';
displaySku = 'RDT-001';
```
If a rider taps any other SKU, it falls back to hardcoded tea products.

### 3.2 Required Remediation
- Pass the full `StockItemEntity` via constructor or route arguments.
- Dynamically bind:
  - Product Name, SKU, Category, and Packaging specs.
  - Live available units, total custody, and delivered today count.
  - Interactive stock movement history for that specific product ID.

---

## 4. Remediation for Barcode Scanning in `stock_page.dart`

### 4.1 Root Cause
In `stock_page.dart:355-365`, the barcode icon button navigates to `/orders/scan` (`ScanToCollectPage`), which expects tracking numbers for orders, causing confusion when a rider attempts to scan a physical product barcode.

### 4.2 Required Remediation
- Point the barcode icon to open `StockBarcodeSearchModal` instead of `/orders/scan`.
- On barcode scan:
  1. Match scanned code against `products.barcode` or `products.sku`.
  2. If matched, highlight the product in the rider's stock custody list and display its current count.
  3. If not found in vehicle custody, display: *"SKU not in current vehicle custody. Check DC warehouse stock."*

---

## 5. Verification Plan

1. **Rider Return Flow**:
   - Select 2 units of an item in custody.
   - Submit return with code `RET-XXXX`.
   - Verify row created in `stock_returns` with status `'submitted'`.
2. **Audit Flow**:
   - Enter physical counts on `InventoryAuditPage` with a variance of -1.
   - Submit audit.
   - Verify `inventory_audits` and `inventory_audit_items` rows exist in Supabase with variance -1 and reason recorded.
3. **Barcode Flow**:
   - Scan test barcode on `StockPage`.
   - Verify the correct item is selected and displayed without route crashes.
