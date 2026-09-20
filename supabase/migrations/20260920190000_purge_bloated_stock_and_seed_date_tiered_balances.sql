-- ============================================================================
-- NOVAXPRESS LOGISTICS PLATFORM
-- Migration: 20260920190000_purge_bloated_stock_and_seed_date_tiered_balances.sql
-- Description:
--   1. Purges bloated 917 legacy raw ERP records for Novacare.
--   2. Seeds clean, balanced 36 multi-hub warehouse positions.
--   3. Seeds 4 distinct chronological date tiers in client_stock_ledger_entries.
-- ============================================================================

-- 1. Purge legacy bloated stock balances and baseline ledger entries for Novacare
DELETE FROM public.client_stock_ledger_entries 
WHERE client_id = '33333333-3333-4333-8333-333333333333' 
  AND voucher_no LIKE 'SEED-PANGEA%';

DELETE FROM public.client_stock_balances 
WHERE client_id = '33333333-3333-4333-8333-333333333333';

-- 2. Insert Balanced Current Positions into client_stock_balances (36 positions across 6 hubs)
INSERT INTO public.client_stock_balances (
    client_id, item_code, item_name, item_group, warehouse, stock_uom,
    opening_qty, opening_value, in_qty, in_value, out_qty, out_value,
    balance_qty, balance_value, valuation_rate, reserved_stock, company
) VALUES
-- Hub 1: Central DC Stores (NL) - Abuja
('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Central DC Stores (NL)', 'Nos', 5000.0, 9542780.0, 1500.0, 2862834.0, 450.0, 858850.2, 6050.0, 11546763.8, 1908.556, 120.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Central DC Stores (NL)', 'Nos', 1200.0, 6000000.0, 500.0, 2500000.0, 250.0, 1250000.0, 1450.0, 7250000.0, 5000.0, 50.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Novacare', 'Central DC Stores (NL)', 'Nos', 2500.0, 4875000.0, 800.0, 1560000.0, 300.0, 585000.0, 3000.0, 5850000.0, 1950.0, 80.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Central DC Stores (NL)', 'Nos', 3000.0, 8850000.0, 1000.0, 2950000.0, 400.0, 1180000.0, 3600.0, 10620000.0, 2950.0, 90.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Central DC Stores (NL)', 'Nos', 1500.0, 2700000.0, 600.0, 1080000.0, 200.0, 360000.0, 1900.0, 3420000.0, 1800.0, 40.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-AMT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Central DC Stores (NL)', 'Nos', 1800.0, 3600000.0, 500.0, 1000000.0, 150.0, 300000.0, 2150.0, 4300000.0, 2000.0, 30.0, 'Novacare Ltd'),

-- Hub 2: Lagos Ikeja Main Hub - NL
('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Lagos Ikeja Main Hub - NL', 'Nos', 3000.0, 5725668.0, 1000.0, 1908556.0, 600.0, 1145133.6, 3400.0, 6489090.4, 1908.556, 80.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Lagos Ikeja Main Hub - NL', 'Nos', 800.0, 4000000.0, 300.0, 1500000.0, 200.0, 1000000.0, 900.0, 4500000.0, 5000.0, 40.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Novacare', 'Lagos Ikeja Main Hub - NL', 'Nos', 1500.0, 2925000.0, 500.0, 975000.0, 350.0, 682500.0, 1650.0, 3217500.0, 1950.0, 50.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Lagos Ikeja Main Hub - NL', 'Nos', 2000.0, 5900000.0, 800.0, 2360000.0, 450.0, 1327500.0, 2350.0, 6932500.0, 2950.0, 60.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Lagos Ikeja Main Hub - NL', 'Nos', 1000.0, 1800000.0, 400.0, 720000.0, 250.0, 450000.0, 1150.0, 2070000.0, 1800.0, 30.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-AMT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Lagos Ikeja Main Hub - NL', 'Nos', 1200.0, 2400000.0, 400.0, 800000.0, 200.0, 400000.0, 1400.0, 2800000.0, 2000.0, 25.0, 'Novacare Ltd'),

-- Hub 3: Port Harcourt Central - NL
('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Port Harcourt Central - NL', 'Nos', 1500.0, 2862834.0, 500.0, 954278.0, 200.0, 381711.2, 1800.0, 3435400.8, 1908.556, 30.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Port Harcourt Central - NL', 'Nos', 400.0, 2000000.0, 200.0, 1000000.0, 100.0, 500000.0, 500.0, 2500000.0, 5000.0, 15.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Novacare', 'Port Harcourt Central - NL', 'Nos', 800.0, 1560000.0, 300.0, 585000.0, 150.0, 292500.0, 950.0, 1852500.0, 1950.0, 20.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Port Harcourt Central - NL', 'Nos', 1000.0, 2950000.0, 400.0, 1180000.0, 180.0, 531000.0, 1220.0, 3599000.0, 2950.0, 25.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Port Harcourt Central - NL', 'Nos', 600.0, 1500000.0, 200.0, 500000.0, 80.0, 200000.0, 720.0, 1800000.0, 2500.0, 10.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Port Harcourt Central - NL', 'Nos', 500.0, 1128205.0, 200.0, 451282.0, 70.0, 157948.7, 630.0, 1421538.3, 2256.41, 10.0, 'Novacare Ltd'),

-- Hub 4: Kano Commercial Hub - NL
('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Kano Commercial Hub - NL', 'Nos', 1200.0, 2290267.2, 400.0, 763422.4, 150.0, 286283.4, 1450.0, 2767406.2, 1908.556, 20.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Kano Commercial Hub - NL', 'Nos', 300.0, 1500000.0, 150.0, 750000.0, 60.0, 300000.0, 390.0, 1950000.0, 5000.0, 10.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Kano Commercial Hub - NL', 'Nos', 800.0, 2360000.0, 300.0, 885000.0, 120.0, 354000.0, 980.0, 2891000.0, 2950.0, 15.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Kano Commercial Hub - NL', 'Nos', 600.0, 1080000.0, 250.0, 450000.0, 90.0, 162000.0, 760.0, 1368000.0, 1800.0, 15.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-AMT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Kano Commercial Hub - NL', 'Nos', 700.0, 1400000.0, 250.0, 500000.0, 100.0, 200000.0, 850.0, 1700000.0, 2000.0, 15.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Novacare', 'Kano Commercial Hub - NL', 'Nos', 500.0, 975000.0, 200.0, 390000.0, 80.0, 156000.0, 620.0, 1209000.0, 1950.0, 10.0, 'Novacare Ltd'),

-- Hub 5: Ibadan Ring Road Depot - NL
('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Ibadan Ring Road Depot - NL', 'Nos', 1000.0, 1908556.0, 400.0, 763422.4, 180.0, 343540.08, 1220.0, 2328438.32, 1908.556, 15.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Ibadan Ring Road Depot - NL', 'Nos', 350.0, 1750000.0, 150.0, 750000.0, 80.0, 400000.0, 420.0, 2100000.0, 5000.0, 10.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Novacare', 'Ibadan Ring Road Depot - NL', 'Nos', 600.0, 1170000.0, 200.0, 390000.0, 90.0, 175500.0, 710.0, 1384500.0, 1950.0, 10.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Ibadan Ring Road Depot - NL', 'Nos', 700.0, 2065000.0, 250.0, 737500.0, 110.0, 324500.0, 840.0, 2478000.0, 2950.0, 15.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Ibadan Ring Road Depot - NL', 'Nos', 450.0, 810000.0, 200.0, 360000.0, 70.0, 126000.0, 580.0, 1044000.0, 1800.0, 10.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-AMT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Ibadan Ring Road Depot - NL', 'Nos', 500.0, 1000000.0, 200.0, 400000.0, 80.0, 160000.0, 620.0, 1240000.0, 2000.0, 10.0, 'Novacare Ltd'),

-- Hub 6: Enugu Independence Hub - NL
('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Enugu Independence Hub - NL', 'Nos', 900.0, 1717700.4, 300.0, 572566.8, 120.0, 229026.72, 1080.0, 2061240.48, 1908.556, 10.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Enugu Independence Hub - NL', 'Nos', 250.0, 1250000.0, 100.0, 500000.0, 50.0, 250000.0, 300.0, 1500000.0, 5000.0, 8.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Novacare', 'Enugu Independence Hub - NL', 'Nos', 450.0, 877500.0, 150.0, 292500.0, 70.0, 136500.0, 530.0, 1033500.0, 1950.0, 8.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Enugu Independence Hub - NL', 'Nos', 600.0, 1770000.0, 200.0, 590000.0, 90.0, 265500.0, 710.0, 2094500.0, 2950.0, 10.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Enugu Independence Hub - NL', 'Nos', 400.0, 720000.0, 150.0, 270000.0, 60.0, 108000.0, 490.0, 882000.0, 1800.0, 8.0, 'Novacare Ltd'),
('33333333-3333-4333-8333-333333333333', 'SKU-AMT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Enugu Independence Hub - NL', 'Nos', 450.0, 900000.0, 150.0, 300000.0, 60.0, 120000.0, 540.0, 1080000.0, 2000.0, 8.0, 'Novacare Ltd');

-- 3. Seed Granular Date-Tiered Transactions in client_stock_ledger_entries

-- Tier 1: 2026-09-01 (Verified September Opening Baselines)
INSERT INTO public.client_stock_ledger_entries (
    client_id, warehouse, item_code, item_name, item_group, voucher_type, voucher_no, posting_date, posting_at,
    qty_change, incoming_qty, outgoing_qty, valuation_rate, total_value, notes
)
SELECT 
    b.client_id, b.warehouse, b.item_code, b.item_name, b.item_group, 'baseline_seed', 'SEED-BASE-20260901',
    DATE '2026-09-01', TIMESTAMPTZ '2026-09-01 08:00:00+01',
    b.opening_qty, b.opening_qty, 0.00, b.valuation_rate, b.opening_value, 'Verified September Opening Inventory'
FROM public.client_stock_balances b;

-- Tier 2: 2026-09-08 (Vendor Purchase Receipts Intake Batch A)
INSERT INTO public.client_stock_ledger_entries (
    client_id, warehouse, item_code, item_name, item_group, voucher_type, voucher_no, posting_date, posting_at,
    qty_change, incoming_qty, outgoing_qty, valuation_rate, total_value, notes
)
SELECT 
    b.client_id, b.warehouse, b.item_code, b.item_name, b.item_group, 'purchase_receipt', 'INV-STK-2026-0908',
    DATE '2026-09-08', TIMESTAMPTZ '2026-09-08 11:30:00+01',
    ROUND(b.in_qty * 0.6, 2), ROUND(b.in_qty * 0.6, 2), 0.00, b.valuation_rate, ROUND((b.in_qty * 0.6) * b.valuation_rate, 2), 'Vendor Consignment Batch A Intake'
FROM public.client_stock_balances b
WHERE b.in_qty > 0;

-- Tier 3: 2026-09-14 (Sales Order Outflows & Rider Dispatches)
INSERT INTO public.client_stock_ledger_entries (
    client_id, warehouse, item_code, item_name, item_group, voucher_type, voucher_no, posting_date, posting_at,
    qty_change, incoming_qty, outgoing_qty, valuation_rate, total_value, notes
)
SELECT 
    b.client_id, b.warehouse, b.item_code, b.item_name, b.item_group, 'sales_order_delivery', 'ORD-DELIV-20260914',
    DATE '2026-09-14', TIMESTAMPTZ '2026-09-14 16:45:00+01',
    -b.out_qty, 0.00, b.out_qty, b.valuation_rate, ROUND(b.out_qty * b.valuation_rate, 2), 'Customer Order Fulfillment Deduction'
FROM public.client_stock_balances b
WHERE b.out_qty > 0;

-- Tier 4: 2026-09-18 (Mid-month Replenishment Intake Batch B)
INSERT INTO public.client_stock_ledger_entries (
    client_id, warehouse, item_code, item_name, item_group, voucher_type, voucher_no, posting_date, posting_at,
    qty_change, incoming_qty, outgoing_qty, valuation_rate, total_value, notes
)
SELECT 
    b.client_id, b.warehouse, b.item_code, b.item_name, b.item_group, 'purchase_receipt', 'INV-STK-2026-0918',
    DATE '2026-09-18', TIMESTAMPTZ '2026-09-18 10:15:00+01',
    ROUND(b.in_qty * 0.4, 2), ROUND(b.in_qty * 0.4, 2), 0.00, b.valuation_rate, ROUND((b.in_qty * 0.4) * b.valuation_rate, 2), 'Vendor Consignment Batch B Intake'
FROM public.client_stock_balances b
WHERE b.in_qty > 0;
