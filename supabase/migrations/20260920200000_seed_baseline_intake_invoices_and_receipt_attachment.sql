-- ============================================================================
-- NOVAXPRESS LOGISTICS PLATFORM
-- Migration: 20260920200000_seed_baseline_intake_invoices_and_receipt_attachment.sql
-- Description:
--   1. Add payment_receipt_url column to client_stock_invoices table.
--   2. Seed authoritative baseline historical intake invoices with line items so they persist alongside user-created bills.
-- ============================================================================

-- 1. Add payment_receipt_url column if not present
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'client_stock_invoices' 
          AND column_name = 'payment_receipt_url'
    ) THEN
        ALTER TABLE public.client_stock_invoices 
        ADD COLUMN payment_receipt_url TEXT;
    END IF;
END $$;

-- 2. Ensure supplier foreign keys resolve or exist
INSERT INTO public.client_suppliers (
    id, client_id, supplier_name, contact_person, email, phone, category, payment_terms, bank_name, account_number, account_name
) VALUES 
    ('00000000-0000-4000-8000-000000000001', '33333333-3333-4333-8333-333333333333', 'Apex Herbal Laboratories Ltd', 'Dr. Patrick Okonjo', 'procurement@apexherbal.ng', '+234 803 111 2233', 'Herbal Formulations & Pharma', 'Net 30 Days', 'Access Bank', '0123456789', 'Apex Herbal Laboratories Ltd'),
    ('00000000-0000-4000-8000-000000000002', '33333333-3333-4333-8333-333333333333', 'DermaCare Naturals & Cosmeceuticals', 'Amina Bello', 'orders@dermacare.ng', '+234 802 444 5566', 'Finished Goods Manufacturing', 'Immediate', 'Zenith Bank', '1012345678', 'DermaCare Naturals Ltd'),
    ('00000000-0000-4000-8000-000000000003', '33333333-3333-4333-8333-333333333333', 'ProFit Activewear & Medical Goods', 'Engr. Emeka Eze', 'sales@profitgoods.ng', '+234 805 777 8899', 'Finished Goods Manufacturing', 'Net 15 Days', 'GTBank', '0234567890', 'ProFit Activewear Nigeria')
ON CONFLICT (id) DO UPDATE SET
    supplier_name = EXCLUDED.supplier_name,
    email = EXCLUDED.email;

-- 3. Seed authoritative baseline historical stock intake invoices
INSERT INTO public.client_stock_invoices (
    id, client_id, invoice_number, supplier_id, supplier_name, destination_warehouse, entry_date, status, payment_status, total_units, subtotal_raw_product_cost, total_packaging_cost, total_transportation_cost, total_handling_clearing_cost, other_addons_cost, grand_total_landed_cost, notes, payment_receipt_url, created_at
) VALUES 
    (
        '11111111-0000-4000-8000-000000000001',
        '33333333-3333-4333-8333-333333333333',
        'INV-STK-NOV-2026-001',
        '00000000-0000-4000-8000-000000000001',
        'Apex Herbal Laboratories Ltd',
        'Wuse Central Distribution Hub',
        '2026-09-14',
        'verified',
        'paid',
        5000,
        6000000.00,
        1750000.00,
        1792780.00,
        0.00,
        0.00,
        9542780.00,
        'Bulk production intake batch #GH-2026-88. Verified and received at Wuse Central Distribution Hub.',
        'https://images.unsplash.com/photo-1554415707-9e4466b404c0?w=600&auto=format&fit=crop&q=80',
        '2026-09-14 10:00:00+00'
    ),
    (
        '11111111-0000-4000-8000-000000000002',
        '33333333-3333-4333-8333-333333333333',
        'INV-STK-NOV-2026-002',
        '00000000-0000-4000-8000-000000000001',
        'Apex Herbal Laboratories Ltd',
        'Wuse Central Distribution Hub',
        '2026-09-15',
        'verified',
        'paid',
        4000,
        8400000.00,
        1800000.00,
        1600000.00,
        0.00,
        0.00,
        11800000.00,
        'Ura Clear intake batch #UC-901. Received intact at central hub.',
        'https://images.unsplash.com/photo-1554415707-9e4466b404c0?w=600&auto=format&fit=crop&q=80',
        '2026-09-15 11:30:00+00'
    ),
    (
        '11111111-0000-4000-8000-000000000003',
        '33333333-3333-4333-8333-333333333333',
        'INV-STK-NOV-2026-003',
        '00000000-0000-4000-8000-000000000003',
        'ProFit Activewear & Medical Goods',
        'LAGOS MAIN DC',
        '2026-09-17',
        'verified',
        'unpaid',
        2000,
        7600000.00,
        1000000.00,
        1400000.00,
        0.00,
        0.00,
        10000000.00,
        'Import consignment cleared through Lagos port and received in depot.',
        NULL,
        '2026-09-17 14:00:00+00'
    ),
    (
        '11111111-0000-4000-8000-000000000004',
        '33333333-3333-4333-8333-333333333333',
        'INV-STK-NOV-2026-004',
        '00000000-0000-4000-8000-000000000002',
        'DermaCare Naturals & Cosmeceuticals',
        'Wuse Central Distribution Hub',
        '2026-09-19',
        'verified',
        'unpaid',
        1500,
        5250000.00,
        1200000.00,
        1050000.00,
        0.00,
        0.00,
        7500000.00,
        'Organic Hair Dye Shampoo batch #HDS-2026. Includes application glove sachets.',
        NULL,
        '2026-09-19 09:15:00+00'
    )
ON CONFLICT (id) DO UPDATE SET
    destination_warehouse = EXCLUDED.destination_warehouse,
    payment_receipt_url = COALESCE(client_stock_invoices.payment_receipt_url, EXCLUDED.payment_receipt_url);

-- 4. Seed invoice line items
INSERT INTO public.client_stock_invoice_items (
    id, invoice_id, product_name, product_sku, quantity, supplier_unit_price, packaging_cost_per_unit, transportation_cost_per_unit, effective_landed_cost_per_unit, total_landed_cost, target_retail_price, projected_margin_percent
) VALUES
    ('22222222-0000-4000-8000-000000000001', '11111111-0000-4000-8000-000000000001', 'Grazer Herbal Tea', 'SKU-GRAZ-TEA', 5000, 1200.00, 350.00, 358.56, 1908.56, 9542780.00, 12500.00, 84.73),
    ('22222222-0000-4000-8000-000000000002', '11111111-0000-4000-8000-000000000002', 'Ura Clear Tea', 'SKU-URA-TEA', 4000, 2100.00, 450.00, 400.00, 2950.00, 11800000.00, 14000.00, 78.93),
    ('22222222-0000-4000-8000-000000000003', '11111111-0000-4000-8000-000000000003', 'Compression Vest', 'SKU-COMP-VEST', 2000, 3800.00, 500.00, 700.00, 5000.00, 10000000.00, 18500.00, 72.97),
    ('22222222-0000-4000-8000-000000000004', '11111111-0000-4000-8000-000000000004', 'Hair Dye Shampoo', 'SKU-HAIR-SHMP', 1500, 3500.00, 800.00, 700.00, 5000.00, 7500000.00, 16000.00, 68.75)
ON CONFLICT (id) DO NOTHING;
