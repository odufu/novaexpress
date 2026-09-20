# Phase 3: Product, Supplier & Inventory Integration Architecture

**Module:** Product Catalog, Procurement Suppliers & Stock Intake Workflow  
**Target Files:**  
- `lib/features/client_portal/presentation/widgets/client_add_product_modal.dart`
- `lib/features/client_portal/presentation/pages/client_products_page.dart`
- `lib/features/client_portal/presentation/widgets/client_raise_stock_invoice_modal.dart`
- `lib/features/client_portal/presentation/widgets/client_supply_stock_modal.dart`
- `lib/features/client_portal/domain/entities/catalog_product.dart`
- `supabase/migrations/20260920170000_link_products_to_suppliers.sql` (New)

---

### 1. The Core Architectural Questions Answered

#### Question A: Is product connected to the inventory system already?
- **Current Reality**: Product is connected to global counts (`stock_quantity`, `available_count`) and matches `client_stock_balances` via `item_name` and `item_code`. However, there is **no foreign key** linking `products` to `client_suppliers` (`preferred_supplier_id`).
- **Target Architecture**: Add `preferred_supplier_id UUID REFERENCES public.client_suppliers(id) ON DELETE SET NULL` to the `products` table. This creates a direct relational bridge between the product catalog and the direct procurement vendor.

#### Question B: When creating a product, do we attach the supplier immediately or create supplier first?
- **Frictionless Solution**:
  1. **Suppliers are NOT a blocking prerequisite**. If a merchant has not registered any suppliers yet, they can still create products freely.
  2. In `ClientAddProductModal`, provide a **"Preferred Procurement Supplier"** selector:
     - If suppliers exist: Dropdown list showing vendor name and lead time (e.g., `Apex Herbal Laboratories (7d lead)`).
     - Inline Action: A prominent `+ Add New Vendor` button next to the dropdown that opens `ClientAddSupplierModal` as a sub-sheet. Once created, the newly created supplier is automatically selected in the form.
     - Optionality: If left blank, the product is created with `preferred_supplier_id = null`. The supplier can be linked later when raising the first stock intake invoice.
  3. When `has_inventory_management == false`, the supplier selector is cleanly hidden or marked as optional, keeping the product onboarding light for basic merchants.

#### Question C: Redundancy of "Supply Stock" vs. "Stock Intake & Goods Receipt Invoice"
- **The Conflict**:
  - `client_products_page.dart` has a "Supply Stock" button on every product row that dispatches stock directly to a DC with arbitrary batch numbers, bypassing supplier and landed cost calculations.
  - `client_inventory_page.dart` has "Raise Stock Invoice" that itemizes landed cost (base unit + packaging + freight + handling) and recalculates the weighted average valuation rate.
  - Having both confuses users and creates orphan stock in warehouses with ₦0 landed cost!
- **The Definitive Architectural Resolution**:
  - **Service-Gated Action Routing**:
    ```
    If (client.hasInventoryManagement == true) {
        Product Row Primary Action -> "Stock Intake & Landed Cost"
        Action Target: Opens ClientRaiseStockInvoiceModal (pre-populates that product)
        Result: Landed cost is strictly calculated, weighted average valuation updated.
    } else {
        Product Row Primary Action -> "Supply Consignment"
        Action Target: Opens ClientSupplyStockModal (simple waybill allocation)
        Result: Simple physical unit count tracking without landed cost accounting.
    }
    ```
  - In `ClientSupplyStockModal`, if an inventory-managed merchant opens it directly, a helpful badge and banner notify:
    > 💡 **Notice:** Your account has *Advanced Landed Cost & Inventory Tracking* enabled. Physical stock added via this shortcut will carry standard catalog cost. For itemized packaging, freight, and weighted valuation, use **Stock Intake Invoice**.

---

### 2. Database Schema Migration: `20260920170000_link_products_to_suppliers.sql`

```sql
-- 1. Add preferred_supplier_id to products table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'products' AND column_name = 'preferred_supplier_id'
    ) THEN
        ALTER TABLE public.products 
        ADD COLUMN preferred_supplier_id UUID REFERENCES public.client_suppliers(id) ON DELETE SET NULL;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_products_preferred_supplier ON public.products(preferred_supplier_id);

-- 2. Link existing products to initial suppliers where matching
UPDATE public.products p
SET preferred_supplier_id = s.id
FROM public.client_suppliers s
WHERE p.client_id = s.client_id
  AND (s.supplied_products @> ARRAY[p.name] OR s.supplied_products @> ARRAY[p.sku]);
```

---

### 3. Flutter UI Implementation Details

#### 3.1. `ClientAddProductModal` Enhancements
1. **Preferred Supplier Field**:
   - Placed below "Category" and above "Pricing & Cost Valuation".
   - Dropdown displays all active suppliers for the merchant.
   - Includes "+ New Supplier" button that opens `ClientAddSupplierModal` inline.
2. **Dynamic Cost Price Guidance**:
   - If a supplier is selected and has a standard price recorded, the cost price field pre-fills with guidance text: *"Base procurement cost per unit before packaging and freight."*

#### 3.2. `ClientProductsPage` Action Row Adaptation
1. Inspect `state.clientProfile.hasInventoryManagement`.
2. For each product in the data table:
   - If `hasInventoryManagement == true`:
     - Icon: `Icons.receipt_long_rounded` (Emerald).
     - Tooltip: `'Raise Stock Intake Invoice & Landed Cost'`.
     - On tap: Opens `ClientRaiseStockInvoiceModal` with that product pre-added to the line items.
   - If `hasInventoryManagement == false`:
     - Icon: `Icons.local_shipping_rounded` (Teal).
     - Tooltip: `'Supply Consignment to Hub'`.
     - On tap: Opens `ClientSupplyStockModal`.

#### 3.3. Fixing 28px Overflow in `ClientRaiseStockInvoiceModal`
In `lib/features/client_portal/presentation/widgets/client_raise_stock_invoice_modal.dart` (lines 755-796):
- **Root Cause**: The footer row contains `Text('Note: Posting recalculates weighted average valuation rates in live inventory ledger')`, `const Spacer()`, `OutlinedButton('Cancel')`, and `ElevatedButton.icon('Post Stock Entry & Landed Cost')`. The text is not constrained and pushes the buttons past the modal boundary by 28 pixels on screens < 820px.
- **Fix**: Wrap the note text in `Expanded(child: ...)` and change `Spacer()` to `const SizedBox(width: 12)`. This guarantees that the button group always stays pinned within the modal bounds without overflow.
