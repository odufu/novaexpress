# Phase 5: Client Portal & Product Accounting Remediation Plan

**Document Path:** `c:\PROJECT\NoveXPS\inventry fix\05_client_portal_and_product_accounting_plan.md`  
**Target Files:**
1. `lib/features/client_portal/presentation/pages/client_finance_page.dart`
2. `lib/features/client_portal/presentation/pages/client_products_page.dart`
3. `lib/features/client_portal/presentation/widgets/client_add_product_modal.dart`
4. `lib/features/client_portal/presentation/widgets/client_product_detail_modal.dart`
5. `lib/features/client_portal/presentation/providers/client_portal_provider.dart`

---

## 1. Product Creation & Management Updates

### 1.1 Extend `ClientAddProductModal`
Add the following input fields to `ClientAddProductModal`:
1. **Wholesale Cost Price (COGS)**:
   - Form field: `_costPriceController` (Naira amount).
   - Help text: *"Wholesale or manufacturing cost per unit. Used to compute your true commercial gross profit."*
2. **Barcode / SKU Scanner**:
   - Form field: `_barcodeController`.
   - Action: Optional camera barcode scan button to scan the physical product packaging.
3. **Product Unit Weight (kg)**:
   - Form field: `_weightKgController` (default `0.5` kg).
4. **Low Stock Alert Threshold**:
   - Form field: `_lowStockThresholdController` (default `10` units).

### 1.2 Update `ClientProductDetailModal`
Display the complete product commercial matrix:
- **Retail Selling Price**: `₦${basePrice}`
- **Wholesale Unit Cost**: `₦${costPrice}`
- **Unit Gross Margin**: `₦${basePrice - costPrice}` (${\frac{\text{basePrice} - \text{costPrice}}{\text{basePrice}} \times 100\%}$)
- **Total In-Stock Asset Value**: `₦${totalPhysicalStock * costPrice}` (Valuation at Cost) vs `₦${totalPhysicalStock * basePrice}` (Valuation at Retail)
- **Damaged / Scrapped Units**: Red warning badge if `damaged_count > 0`, showing lost asset value (`damaged_count * costPrice`).

---

## 2. Remediation for `client_finance_page.dart`

### 2.1 Rectify Ambiguous Financial Terminology
Currently, `client_finance_page.dart` computes:
$$\text{KPI} = \text{Gross Collections} - \text{Logistics Fees} - \text{Platform Fees} - \text{Gateway Fees}$$
and labels it **"Net Realized Profit"**. This is technically incorrect: it represents **Net Cash Payout / Net Remittance**, not accounting profit, because it ignores the merchant's procurement cost (Cost of Goods Sold).

### 2.2 Dual Profitability Model
Refactor `client_finance_page.dart` to present both views clearly:

#### View A: Cash Flow & Payouts (The Remittance Ledger)
- **Gross Customer Collections**: Total cash/transfer collected by riders at delivery.
- **Logistics & Delivery Expenses**: Delivery base fees + extra kilometer charges.
- **Platform & Processing Fees**: Platform commission + payment gateway charges.
- **Net Merchant Remittance Due**: The exact amount disbursed to the merchant's bank account.

#### View B: Commercial Profit & Loss (P&L Ledger)
- **Gross Product Revenue**: Total retail value of delivered units.
- **Cost of Goods Sold (COGS)**:
  $$\text{COGS} = \sum_{\text{delivered}} (\text{delivered physical units} \times \text{product cost\_price})$$
- **Net Commercial Profit**:
  $$\text{Net Profit} = \text{Gross Product Revenue} - \text{COGS} - \text{Logistics Fees} - \text{Platform Fees}$$
- **Damaged Stock Loss (Write-Off)**:
  $$\text{Inventory Loss} = \sum_{\text{damaged}} (\text{damaged units} \times \text{product cost\_price})$$

### 2.3 Floating Asset Custody Breakdown Card
Add an asset custody summary card to `client_finance_page.dart`:
```
┌───────────────────────────────────────────────────────────┐
│ 📦 Merchant Physical Inventory Custody Value              │
├──────────────────────────┬────────────────┬───────────────┤
│ Location                 │ Physical Units │ Value at Cost │
├──────────────────────────┼────────────────┼───────────────┤
│ DC Warehouse Shelves     │ 340 units      │ ₦2,720,000    │
│ Rider Vehicle Custody    │ 48 units       │ ₦384,000      │
│ Inter-DC In-Transit      │ 25 units       │ ₦200,000      │
│ Quarantined (Damaged)    │ 3 units        │ ₦24,000 (Loss)│
├──────────────────────────┼────────────────┼───────────────┤
│ Total Working Capital    │ 416 units      │ ₦3,328,000    │
└──────────────────────────┴────────────────┴───────────────┘
```

---

## 3. Verification Plan

1. **Add Product Verification**:
   - Create a product with `base_price = 15000` and `cost_price = 8000`.
   - Verify that both prices are saved to Supabase without errors.
2. **Finance Page Verification**:
   - Deliver 5 units of this product.
   - Verify in `ClientFinancePage` that:
     - COGS shows $5 \times 8,000 = ₦40,000$.
     - Gross Margin shows $5 \times (15,000 - 8,000) = ₦35,000$ before logistics deductions.
3. **Zero Cost Fallback Safety**:
   - For legacy products where `cost_price` is 0, display a prompt: *"Set cost price to enable commercial profit tracking"*, avoiding division by zero or erroneous calculations.
