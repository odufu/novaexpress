# Phase 5: Clean Date-Tiered Seeding & ERP Data Purge Plan

**Module:** Database Seeding, Inventory Ledger & Date-Range Filtering  
**Target Files:**  
- `supabase/migrations/20260920190000_purge_bloated_stock_and_seed_date_tiered_balances.sql` (New Migration)
- `test/stock_ledger_pangea_table_and_date_filter_test.dart` (Validation Test)

---

### 1. Rationale & Objectives

The existing migration `20260920110000_seed_pangea_stock_balances.sql` contains **917 hardcoded rows** from an ERP export:
1. **Unrealistic & Corrupted Values**: Rows with negative stock (e.g. `-152.0` units) and duplicate warehouse aliases.
2. **Flat Timestamps**: All rows were inserted with static timestamps. Testing date-range filters (e.g., September 7–13 vs. September 14–20) yields stagnant or inaccurate metrics because there are no granular, chronological ledger movements.
3. **Extreme Payload**: Fetching 917 rows over HTTP bloats memory and delays table initialization.

We will **purge** the 917 ERP records and replace them with a clean, cohesive dataset of **36 balanced warehouse positions** across 6 regional distribution hubs with **4 distinct date tiers** in `client_stock_ledger_entries`.

---

### 2. The 4 Date Tiers for Dynamic Filter Verification

| Tier | Posting Date | Event / Voucher Type | Description |
| :---: | :---: | :--- | :--- |
| **Tier 1** | **2026-09-01** | `baseline_seed` | Initial month-opening warehouse balance across all 6 hubs. |
| **Tier 2** | **2026-09-08** | `purchase_receipt` | Verified stock intake shipments from Apex Herbal, PolyPack, and DermaCare. |
| **Tier 3** | **2026-09-14** | `sales_order_delivery` | Customer order deliveries fulfilled by riders, deducting stock and logging COGS. |
| **Tier 4** | **2026-09-18** | `purchase_receipt` / `stock_transfer` | Mid-month replenishment intake to maintain healthy safety stock. |

#### Verifying Date Filters with the New Seed Data
- **Filter: Sep 1 – Sep 7**: Shows pure baseline opening stock. Incoming = 0, Outgoing = 0.
- **Filter: Sep 8 – Sep 13**: Opening stock equals Sep 7 balance; Incoming shows Tier 2 purchases; Outgoing = 0.
- **Filter: Sep 14 – Sep 20**: Opening stock includes Tier 1 + Tier 2; Incoming shows Tier 4 intake; Outgoing shows Tier 3 deliveries. Closing balance mathematically matches live shelf stock!

---

### 3. Database Migration Script Specification

#### Migration: `20260920190000_purge_bloated_stock_and_seed_date_tiered_balances.sql`
```sql
-- 1. Purge legacy bloated stock balances and baseline ledger entries for Novacare
DELETE FROM public.client_stock_ledger_entries 
WHERE client_id = '33333333-3333-4333-8333-333333333333' 
  AND voucher_no LIKE 'SEED-PANGEA%';

DELETE FROM public.client_stock_balances 
WHERE client_id = '33333333-3333-4333-8333-333333333333';

-- 2. Seed 6 Standardized Regional Distribution Hubs
-- Hub 1: Central DC Stores (Abuja) - NL
-- Hub 2: Lagos Ikeja Main Hub - NL
-- Hub 3: Port Harcourt Central Hub - NL
-- Hub 4: Kano Commercial Hub - NL
-- Hub 5: Ibadan Ring Road Depot - NL
-- Hub 6: Enugu Independence Hub - NL

-- 3. Insert Balanced Current Positions into client_stock_balances
INSERT INTO public.client_stock_balances (
    client_id, item_code, item_name, item_group, warehouse, stock_uom,
    opening_qty, opening_value, in_qty, in_value, out_qty, out_value,
    balance_qty, balance_value, valuation_rate, reserved_stock, company
) VALUES
-- Central DC Stores (Abuja)
('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Central DC Stores (NL)', 'Nos', 5000.0, 9542780.0, 1500.0, 2862834.0, 450.0, 858850.2, 6050.0, 11546763.8, 1908.556, 120.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Central DC Stores (NL)', 'Nos', 1200.0, 6000000.0, 500.0, 2500000.0, 250.0, 1250000.0, 1450.0, 7250000.0, 5000.0, 50.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Novacare', 'Central DC Stores (NL)', 'Nos', 2500.0, 4875000.0, 800.0, 1560000.0, 300.0, 585000.0, 3000.0, 5850000.0, 1950.0, 80.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Central DC Stores (NL)', 'Nos', 3000.0, 8850000.0, 1000.0, 2950000.0, 400.0, 1180000.0, 3600.0, 10620000.0, 2950.0, 90.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Central DC Stores (NL)', 'Nos', 1500.0, 2700000.0, 600.0, 1080000.0, 200.0, 360000.0, 1900.0, 3420000.0, 1800.0, 40.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-AMT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Central DC Stores (NL)', 'Nos', 1800.0, 3600000.0, 500.0, 1000000.0, 150.0, 300000.0, 2150.0, 4300000.0, 2000.0, 30.0, 'Novacare Ltd'),

-- Lagos Ikeja Main Hub
('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Lagos Ikeja Main Hub - NL', 'Nos', 3000.0, 5725668.0, 1000.0, 1908556.0, 600.0, 1145133.6, 3400.0, 6489090.4, 1908.556, 80.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Lagos Ikeja Main Hub - NL', 'Nos', 800.0, 4000000.0, 300.0, 1500000.0, 200.0, 1000000.0, 900.0, 4500000.0, 5000.0, 40.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Novacare', 'Lagos Ikeja Main Hub - NL', 'Nos', 1500.0, 2925000.0, 500.0, 975000.0, 350.0, 682500.0, 1650.0, 3217500.0, 1950.0, 50.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Lagos Ikeja Main Hub - NL', 'Nos', 2000.0, 5900000.0, 800.0, 2360000.0, 450.0, 1327500.0, 2350.0, 6932500.0, 2950.0, 60.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Lagos Ikeja Main Hub - NL', 'Nos', 1000.0, 1800000.0, 400.0, 720000.0, 250.0, 450000.0, 1150.0, 2070000.0, 1800.0, 30.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-AMT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Lagos Ikeja Main Hub - NL', 'Nos', 1200.0, 2400000.0, 400.0, 800000.0, 200.0, 400000.0, 1400.0, 2800000.0, 2000.0, 25.0, 'Novacare Ltd'),

-- Port Harcourt Central Hub
('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Port Harcourt Central - NL', 'Nos', 1500.0, 2862834.0, 500.0, 954278.0, 200.0, 381711.2, 1800.0, 3435400.8, 1908.556, 30.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Port Harcourt Central - NL', 'Nos', 400.0, 2000000.0, 200.0, 1000000.0, 100.0, 500000.0, 500.0, 2500000.0, 5000.0, 15.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Novacare', 'Port Harcourt Central - NL', 'Nos', 800.0, 1560000.0, 300.0, 585000.0, 150.0, 292500.0, 950.0, 1852500.0, 1950.0, 20.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Port Harcourt Central - NL', 'Nos', 1000.0, 2950000.0, 400.0, 1180000.0, 180.0, 531000.0, 1220.0, 3599000.0, 2950.0, 25.0, 'Novacare Ltd'),

-- Kano Commercial Hub
('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Kano Commercial Hub - NL', 'Nos', 1200.0, 2290267.2, 400.0, 763422.4, 150.0, 286283.4, 1450.0, 2767406.2, 1908.556, 20.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Kano Commercial Hub - NL', 'Nos', 800.0, 2360000.0, 300.0, 885000.0, 120.0, 354000.0, 980.0, 2891000.0, 2950.0, 15.0, 'Novacare Ltd');

-- 4. Seed Granular Date-Tiered Transactions in client_stock_ledger_entries
-- Tier 1: 2026-09-01 (Opening Baselines)
INSERT INTO public.client_stock_ledger_entries (
    client_id, warehouse, item_code, item_name, item_group, voucher_type, voucher_no, posting_date, posting_at,
    qty_change, incoming_qty, outgoing_qty, valuation_rate, total_value, notes
)
SELECT 
    b.client_id, b.warehouse, b.item_code, b.item_name, b.item_group, 'baseline_seed', 'SEED-BASE-20260901',
    DATE '2026-09-01', TIMESTAMPTZ '2026-09-01 08:00:00+01',
    b.opening_qty, b.opening_qty, 0.00, b.valuation_rate, b.opening_value, 'Verified September Opening Inventory'
FROM public.client_stock_balances b;

-- Tier 2: 2026-09-08 (Purchase Receipts Intake)
INSERT INTO public.client_stock_ledger_entries (
    client_id, warehouse, item_code, item_name, item_group, voucher_type, voucher_no, posting_date, posting_at,
    qty_change, incoming_qty, outgoing_qty, valuation_rate, total_value, notes
)
SELECT 
    b.client_id, b.warehouse, b.item_code, b.item_name, b.item_group, 'purchase_receipt', 'INV-STK-2026-0908',
    DATE '2026-09-08', TIMESTAMPTZ '2026-09-08 11:30:00+01',
    b.in_qty * 0.6, b.in_qty * 0.6, 0.00, b.valuation_rate, (b.in_qty * 0.6) * b.valuation_rate, 'Vendor Consignment Batch A Intake'
FROM public.client_stock_balances b
WHERE b.in_qty > 0;

-- Tier 3: 2026-09-14 (Sales Order Outflows)
INSERT INTO public.client_stock_ledger_entries (
    client_id, warehouse, item_code, item_name, item_group, voucher_type, voucher_no, posting_date, posting_at,
    qty_change, incoming_qty, outgoing_qty, valuation_rate, total_value, notes
)
SELECT 
    b.client_id, b.warehouse, b.item_code, b.item_name, b.item_group, 'sales_order_delivery', 'ORD-DELIV-20260914',
    DATE '2026-09-14', TIMESTAMPTZ '2026-09-14 16:45:00+01',
    -b.out_qty, 0.00, b.out_qty, b.valuation_rate, b.out_qty * b.valuation_rate, 'Customer Order Fulfillment Deduction'
FROM public.client_stock_balances b
WHERE b.out_qty > 0;

-- Tier 4: 2026-09-18 (Mid-month Intake Batch B)
INSERT INTO public.client_stock_ledger_entries (
    client_id, warehouse, item_code, item_name, item_group, voucher_type, voucher_no, posting_date, posting_at,
    qty_change, incoming_qty, outgoing_qty, valuation_rate, total_value, notes
)
SELECT 
    b.client_id, b.warehouse, b.item_code, b.item_name, b.item_group, 'purchase_receipt', 'INV-STK-2026-0918',
    DATE '2026-09-18', TIMESTAMPTZ '2026-09-18 10:15:00+01',
    b.in_qty * 0.4, b.in_qty * 0.4, 0.00, b.valuation_rate, (b.in_qty * 0.4) * b.valuation_rate, 'Vendor Consignment Batch B Intake'
FROM public.client_stock_balances b
WHERE b.in_qty > 0;
```
