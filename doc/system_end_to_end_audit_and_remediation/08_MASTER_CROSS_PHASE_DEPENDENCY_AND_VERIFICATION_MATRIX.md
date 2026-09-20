# Master Cross-Phase Dependency & Verification Matrix

## 1. Executive Dependency Architecture

This matrix documents all cross-cutting dependencies connecting the database schema, stored procedures, Edge Functions, data models, providers, UI widgets, and test suites across all 7 phases.

```mermaid
graph LR
    subgraph DB["PostgreSQL Database & Stored Procedures"]
        T1[client_stock_invoices]
        T2[client_suppliers]
        T3[client_stock_balances]
        T4[orders]
        T5[product_packages]
        T6[client_settlements]
        RPC1[fn_process_client_stock_intake_invoice]
        RPC2[fn_confirm_order_delivery_stock]
        RPC3[fn_generate_merchant_daily_settlement]
        RPC4[fn_calculate_merchant_asset_custody]
    end

    subgraph EDGE["Cloud Edge Functions"]
        EF1[process-stock-intake-invoice]
        EF2[confirm-delivery-pod]
        EF3[log-delivery-failure]
        EF4[generate-daily-settlements]
    end

    subgraph FLUTTER["Flutter Architecture"]
        E1[ClientStockInvoice]
        E2[ClientSupplier]
        E3[ClientUnitEconomics]
        E4[OrderEntity]
        P1[ClientPortalProvider]
        W1[PangeaExcelDataTable]
        W2[ClientOperationalCostCell]
        W3[ClientOperationalCostBreakdownModal]
    end

    T1 --> E1
    T2 --> E2
    T4 --> E4
    T5 --> E4
    RPC1 --> EF1
    RPC2 --> EF2
    RPC3 --> EF4
    E1 & E2 & E3 & E4 --> P1
    P1 --> W1
    W1 --> W2
    W2 --> W3
```

---

## 2. Cross-Phase Dependency Mapping Table

| Phase | Core Asset | Dependent Components | Impact if Inconsistent | Remediation |
| :--- | :--- | :--- | :--- | :--- |
| **Phase 1** | `client_stock_invoices` | `ClientStockInvoice.toJson()`, `raiseStockInvoice()`, `fn_process_client_stock_intake_invoice` | Inserting `'waybill_number'` crashes with `PGRST204` | Remove `'waybill_number'` from payload; use UUID v4 for invoice ID |
| **Phase 1** | `client_suppliers` | `ClientSupplier.toJson()`, `createSupplier()` | Inserting `'category'` crashes with `PGRST204` | Remove `'category'` from payload |
| **Phase 1** | `process-stock-intake-invoice` | `deploy_all_functions.ps1`, Supabase CLI | Function returns 404 live | Add to deploy script and deploy to Supabase |
| **Phase 2** | `fn_calculate_merchant_asset_custody` | `clients.custom_delivery_fee`, `client_finance_page.dart` | Asset valuation uses hardcoded ₦3,500 fallback | Patch stored procedure to reference `custom_delivery_fee` and deduct failed surcharges |
| **Phase 3** | `unitEconomicsList` | `orders.paid_quantity`, `orders.free_quantity`, `ClientUnitEconomics.calculate` | Ignoring `free_quantity` under-calculates Dispatched COGS | Update `qtySold` to $(paid + free)$ physical units |
| **Phase 3** | `ClientUnitEconomics` | `clients.custom_platform_fee_type` | `'percentage'` check fails if checking `'percent'` | Allow `'percentage'` and `'percent'` interchangeably |
| **Phase 5** | `fn_generate_merchant_daily_settlement` | `orders.status`, `log-delivery-failure` | Stored procedure checks `status = 'failed'`, missing `'cancelled'` | Patch SQL line 146 to check `status IN ('failed', 'cancelled', 'rejected')` |
| **Phase 6** | `client_settlements` | `generate-daily-settlements`, `fetchClientSettlements` | Empty client ID crashes with `22P02` | Guard datasource against empty UUID strings |
| **Phase 7** | `PangeaExcelDataTable` | `ClientOrdersPage`, `ClientInventoryPage`, `ClientProductsPage` | Non-unified UI layout | Upgrade all desktop tables to `PangeaExcelDataTable` |

---

## 3. Holistic Automated Test Suite Verification

Every fix implemented across any phase must be validated against the comprehensive test matrix:
1. `test/pangea_excel_and_operational_economics_test.dart` (Unit economics, promotional bundles, hover popover, modal drilldown, date filtering)
2. `test/client_excel_table_test.dart` (Excel table column resizing, search filtering, theme response)
3. `test/negotiated_operational_charges_test.dart` (Custom onboarding tariffs, 3-way operational fee deductions)
4. `test/client_inventory_and_landed_cost_test.dart` (Inbound stock invoices, ERP stock ledger)
5. `test/client_order_tracking_modal_test.dart` (Orders table click to open tracking modal)
6. `flutter analyze` (Zero errors, warnings, or lints across all project files)
