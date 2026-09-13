# Phase 4: Distribution Center Console Stock Page Remediation Plan

**Document Path:** `c:\PROJECT\NoveXPS\inventry fix\04_dc_console_stock_page_remediation_plan.md`  
**Target Files:**
1. `lib/features/dc_console/presentation/pages/dc_stock_page.dart`
2. `lib/features/dc_console/presentation/widgets/dc_assign_order_modal.dart`
3. `lib/features/dc_console/presentation/widgets/dc_return_receipt_modal.dart` (New)

---

## 1. Remediation for `dc_stock_page.dart`

### 1.1 Tab 1: "DC Warehouse Stock Batches"
* **Current Issue**: Lines 3075-3176 read batch lot numbers and expiration dates exclusively from local `SharedPreferences` cache via `getCachedWarehouseBatches()`. If another supervisor creates a batch, it never synchronizes.
* **Fix**:
  1. Add a direct query in `dc_console_provider` or `stock_remote_datasource` to fetch `product_batches` for `dc_id`:
     ```sql
     SELECT * FROM public.product_batches WHERE distribution_center_id = :dc_id ORDER BY expiry_date ASC;
     ```
  2. Bind the list to the Tab 1 DataTable, retaining local caching strictly as an offline fallback.

### 1.2 Tab 3: "Rider Picking Queue" (Eliminating Mock UI & Hardcoded Data)
* **Current Issue**: Lines 3400-3467 display static card `REQ-00482`, an empty callback button `OutlinedButton(onPressed: () {})`, and a fake SnackBar showing `HND-9921`.
* **Fix**:
  1. Fetch active transfers from `stock_transfers`:
     ```sql
     SELECT * FROM public.stock_transfers 
     WHERE source_dc_id = :dc_id 
       AND status IN ('requested', 'picking_in_progress', 'pending_rider_acceptance')
     ORDER BY created_at DESC;
     ```
  2. Replace static cards with dynamically generated cards showing real waybill numbers, rider names, requested SKU line items, and quantities.
  3. Wire the "Print Picking Ticket" button to invoke standard PDF/thermal ticket generation using the transfer line items.
  4. Wire "Approve & Generate Handover PIN": Generate a secure 4-digit or 6-digit one-time PIN (OTP) stored in `stock_transfers.notes` or `stock_transfers.waybill_number`, and send a real push notification to the rider.

### 1.3 Tab 4: "Dispatch Handover Counter" (Wiring Dynamic PIN Verification)
* **Current Issue**: Lines 3470-3524 render a PIN input field, but clicking `Confirm Physical Handover` ignores `_pinController.text` and executes:
  ```dart
  ref.read(stockNotifierProvider.notifier).completeStockHandover('REQ-00482');
  ```
* **Fix**:
  1. Read the PIN entered into `_pinController.text.trim()`.
  2. Look up the pending transfer matching the entered PIN or waybill number.
  3. Show error if no pending transfer matches the entered PIN.
  4. Call `completeStockHandover(matchedTransfer.id, pin)`.

### 1.4 New Inbound Stock Returns Sub-view (Closing the Return Loop)
* **Current Issue**: When riders return stock, records are inserted into `stock_returns` with status `'submitted'`. There is currently **zero UI** in `DCStockPage` to view or accept these returns.
* **Fix**:
  Add an "Inbound Rider Returns" section or tab view to `dc_stock_page.dart`:
  1. Query `stock_returns`:
     ```sql
     SELECT sr.*, da.full_name as rider_name, p.name as product_name, p.sku
     FROM public.stock_returns sr
     JOIN public.delivery_agents da ON da.id = sr.delivery_agent_id
     JOIN public.products p ON p.id = sr.product_id
     WHERE sr.status = 'submitted'
     ORDER BY sr.created_at DESC;
     ```
  2. Provide a "Receive & Inspect" button that opens `DCReturnReceiptModal`.
  3. Modal allows the supervisor to:
     - Verify actual quantity received.
     - Select condition (`'good'`, `'damaged'`, `'expired'`).
     - Enter notes.
     - Click **"Accept into Warehouse"**, which triggers `fn_receive_rider_stock_return`!

---

## 2. Remediation for `dc_assign_order_modal.dart`

### 2.1 Package Bundles Custody Verification Fix
* **Location**: `dc_assign_order_modal.dart:482`
* **Current Code**:
  ```dart
  final hasEnoughStock = availableCustodyUnits >= widget.order.quantity;
  ```
* **Vulnerability**: For package bundles, `order.quantity` is `1` (1 bundle), while `order.totalPhysicalQuantity` is `5` units. A rider carrying only 1 unit passes validation and is dispatched to deliver 5 units, leading to failed deliveries and customer disputes.
* **Fix**:
  ```dart
  // Corrected physical inventory check:
  final requiredPhysicalUnits = widget.order.totalPhysicalQuantity > 0 
      ? widget.order.totalPhysicalQuantity 
      : widget.order.quantity;
  final hasEnoughStock = availableCustodyUnits >= requiredPhysicalUnits;
  ```

---

## 3. Verification Plan

1. **Tab 3 & 4 Handover Verification**:
   - Create a live stock transfer in DC Console.
   - Verify it appears in Tab 3 Picking Queue with exact SKU breakdown.
   - Enter the generated PIN in Tab 4 Handover Counter.
   - Verify the transfer completes and rider custody increases in `agent_inventory`.
2. **Rider Returns Verification**:
   - Initiate a return from rider app.
   - Open DC Console $\rightarrow$ Inbound Returns.
   - Accept the return. Verify `agent_inventory` decreases and `products.stock_quantity` + `dc_stocks` increases.
3. **Bundle Dispatch Test**:
   - Create an order with a 3-unit bundle.
   - Attempt to assign a rider with only 1 unit in custody.
   - Verify that assignment is blocked with a clear warning: `"Rider has 1 unit in custody, but 3 units are required for this package bundle"`.
