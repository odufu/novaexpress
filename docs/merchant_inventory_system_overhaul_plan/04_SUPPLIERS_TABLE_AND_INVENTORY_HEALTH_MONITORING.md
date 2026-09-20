# Phase 4: Suppliers Directory Table & Inventory Health Monitoring

**Module:** Suppliers Directory, Live Network Stock Aggregation & Low-Stock Alerts  
**Target Files:**  
- `lib/features/client_portal/presentation/pages/client_inventory_page.dart` (Tab 3 Upgrade)
- `lib/features/client_portal/domain/entities/client_supplier_expanded.dart` (New Entity)
- `lib/features/client_portal/presentation/widgets/client_add_supplier_modal.dart`
- `supabase/migrations/20260920180000_supplier_inventory_health_rpc.sql` (New RPC)

---

### 1. Architectural Vision

Currently, Tab 3 of `client_inventory_page.dart` renders suppliers as static visual cards (`_buildSupplierCard`). This view lacks critical operational telemetry:
- It does not show how many physical units of the supplier's products remain across the DC network.
- It does not indicate whether a product is dangerously low on stock.
- It provides no immediate trigger for the merchant to reorder or raise a stock intake invoice.

We are replacing this card grid with an **Expanded Excel-Style Supplier Operations Table (`PangeaExcelDataTable<ClientSupplierExpanded>`)** that empowers merchants to monitor vendor lead times, track remaining network inventory, and initiate reorders before stock-outs occur.

---

### 2. Data Entity: `ClientSupplierExpanded`

```dart
class ClientSupplierExpanded {
  final ClientSupplier supplier;
  final List<CatalogProduct> linkedProducts;
  final int totalUnitsRemaining;
  final int lowStockProductsCount;
  final bool hasCriticalLowStock;
  final String stockHealthStatus; // 'CRITICAL REORDER' | 'LOW STOCK' | 'HEALTHY' | 'OUT OF STOCK'

  const ClientSupplierExpanded({
    required this.supplier,
    required this.linkedProducts,
    required this.totalUnitsRemaining,
    required this.lowStockProductsCount,
    required this.hasCriticalLowStock,
    required this.stockHealthStatus,
  });
}
```

---

### 3. Database Aggregation View / RPC

#### Migration: `20260920180000_supplier_inventory_health_rpc.sql`
```sql
-- Stored procedure to fetch suppliers with aggregated network stock and health status
CREATE OR REPLACE FUNCTION public.fn_get_client_suppliers_overview(p_client_id TEXT)
RETURNS TABLE (
    supplier_id UUID,
    supplier_name TEXT,
    category TEXT,
    contact_person TEXT,
    phone TEXT,
    email TEXT,
    lead_time_days INT,
    payment_terms TEXT,
    supplied_products TEXT[],
    total_remaining_units BIGINT,
    low_stock_count INT,
    critical_reorder_needed BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id AS supplier_id,
        s.supplier_name,
        s.category,
        s.contact_person,
        s.phone,
        s.email,
        s.lead_time_days,
        s.payment_terms,
        s.supplied_products,
        COALESCE(SUM(p.stock_quantity), 0)::BIGINT AS total_remaining_units,
        COUNT(p.id) FILTER (WHERE p.stock_quantity <= COALESCE(p.low_stock_threshold, 10))::INT AS low_stock_count,
        BOOL_OR(p.stock_quantity <= COALESCE(p.low_stock_threshold, 10)) AS critical_reorder_needed
    FROM public.client_suppliers s
    LEFT JOIN public.products p 
      ON p.preferred_supplier_id = s.id 
      OR (s.supplied_products @> ARRAY[p.name] OR s.supplied_products @> ARRAY[p.sku])
    WHERE s.client_id = p_client_id
      AND s.is_active = TRUE
    GROUP BY s.id, s.supplier_name, s.category, s.contact_person, s.phone, s.email, s.lead_time_days, s.payment_terms, s.supplied_products
    ORDER BY critical_reorder_needed DESC, total_remaining_units ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_get_client_suppliers_overview(TEXT) TO authenticated, service_role;
```

---

### 4. Excel Table Column Specifications (`PangeaExcelDataTable`)

| Column # | Key | Label | Width | Alignment | Content & Interactive Behavior |
| :--- | :--- | :--- | :---: | :---: | :--- |
| **1** | `index` | `#` | 50 | Center | Sequential row numbering (1, 2, 3...). |
| **2** | `supplier_name` | `SUPPLIER / VENDOR` | 220 | Left | Supplier Name (Bold), Category badge (e.g. *Raw Materials*, *Packaging*, *Freight*), Contact Person. |
| **3** | `supplied_products` | `SUPPLIED PRODUCTS` | 240 | Left | Horizontal wrapping chips of supplied SKUs and product names (e.g. `[Grazer Herbal Tea]`, `[Hair Dye Shampoo]`). |
| **4** | `remaining_units` | `NETWORK STOCK` | 130 | Right | Total physical units remaining across all distribution centers. Bold number formatting. |
| **5** | `health_status` | `INVENTORY HEALTH` | 150 | Center | Status Badge:<br>• **HEALTHY** (Green) when all products > threshold.<br>• **LOW STOCK** (Amber) when 1+ product near threshold.<br>• **CRITICAL REORDER** (Red + Pulse) when stock <= threshold. |
| **6** | `lead_time` | `LEAD TIME & TERMS` | 140 | Left | e.g., `7d Lead Time` • `Net 15 Payment Terms`. |
| **7** | `contact` | `DIRECT CONTACT` | 160 | Left | Phone number with direct call/WhatsApp trigger icon, email. |
| **8** | `actions` | `ACTIONS` | 160 | Center | **"Raise Intake"** button (pre-selects this vendor in `ClientRaiseStockInvoiceModal`) and **"Edit"** vendor button. |

---

### 5. Timely Supplier Reorder Notification Trigger

When a product falls below `low_stock_threshold`:
1. The Supplier's row highlights in soft red/amber.
2. Clicking **"Raise Intake"** immediately opens `ClientRaiseStockInvoiceModal` with:
   - Vendor pre-selected.
   - Products supplied by that vendor pre-populated in the draft line items.
   - Suggested reorder quantity computed as `(Threshold * 3) - CurrentStock`.
3. Merchants can also click the **WhatsApp** icon on the table to launch a pre-composed replenishment message directly to the vendor's phone:
   > *"Hello [Contact Person], this is [Merchant Name]. Our stock for [Product Name] has dropped to [Remaining] units. Please prepare a replenishment consignment of [Suggested] units."*
