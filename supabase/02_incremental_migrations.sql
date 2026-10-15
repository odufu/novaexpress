
-- =================== 20260920100000_client_inventory_and_landed_cost_management.sql ===================
-- ============================================================================
-- NOVAXPRESS LOGISTICS PLATFORM
-- Migration: 20260920100000_client_inventory_and_landed_cost_management.sql
-- Description:
--   1. Add has_inventory_management and services_enabled to clients table
--   2. Create client_suppliers table (vendor management)
--   3. Create client_stock_invoices & client_stock_invoice_items (goods intake / landed costs)
--   4. Create client_stock_balances (Pangea Suite mirror & multi-hub inventory ledger)
--   5. Intake verification RPC & sales order deduction triggers
--   6. Backfill Novacare Ltd & initial commercial suppliers
-- ============================================================================

-- 1. Alter clients table with inventory capability flag
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'clients' 
          AND column_name = 'has_inventory_management'
    ) THEN
        ALTER TABLE public.clients ADD COLUMN has_inventory_management BOOLEAN DEFAULT false;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'clients' 
          AND column_name = 'services_enabled'
    ) THEN
        ALTER TABLE public.clients ADD COLUMN services_enabled JSONB DEFAULT '["fulfillment", "delivery"]'::jsonb;
    END IF;
END $$;

-- Backfill Novacare / Novacale clients with inventory management enabled
UPDATE public.clients
SET has_inventory_management = true,
    services_enabled = '["fulfillment", "delivery", "inventory_management", "closer_desk"]'::jsonb
WHERE id IN (
    '33333333-3333-4333-8333-333333333333'::uuid,
    'c1111111-1111-4111-8111-111111111111'::uuid
) OR name ILIKE '%novacare%' OR company_name ILIKE '%novacare%' OR name ILIKE '%novacale%';

-- 2. Create client_suppliers table
CREATE TABLE IF NOT EXISTS public.client_suppliers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id TEXT NOT NULL,
    company_id UUID DEFAULT '11111111-1111-4111-8111-111111111111',
    supplier_name TEXT NOT NULL,
    contact_person TEXT,
    email TEXT,
    phone TEXT,
    address TEXT,
    city TEXT DEFAULT 'Abuja',
    country TEXT DEFAULT 'Nigeria',
    supplied_products JSONB DEFAULT '[]'::jsonb,
    payment_terms TEXT DEFAULT 'Immediate' CHECK (payment_terms IN ('Immediate', 'Net 15', 'Net 30', '50% Advance', 'Custom')),
    bank_name TEXT,
    account_number TEXT,
    account_name TEXT,
    notes TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_client_suppliers_client_id ON public.client_suppliers(client_id);

-- 3. Create client_stock_invoices table (Stock Intake / Purchase Entry)
CREATE TABLE IF NOT EXISTS public.client_stock_invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id TEXT NOT NULL,
    invoice_number TEXT NOT NULL,
    supplier_id UUID REFERENCES public.client_suppliers(id) ON DELETE SET NULL,
    supplier_name TEXT NOT NULL,
    destination_warehouse TEXT NOT NULL DEFAULT 'Stores - NL',
    entry_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT NOT NULL DEFAULT 'received' CHECK (status IN ('draft', 'pending_inspection', 'received', 'verified', 'cancelled')),
    payment_status TEXT NOT NULL DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'partially_paid', 'paid')),
    total_units INT NOT NULL DEFAULT 0,
    subtotal_raw_product_cost NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    total_packaging_cost NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    total_transportation_cost NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    total_handling_clearing_cost NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    other_addons_cost NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    grand_total_landed_cost NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    notes TEXT,
    created_by TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_client_stock_invoices_client ON public.client_stock_invoices(client_id);
CREATE INDEX IF NOT EXISTS idx_client_stock_invoices_num ON public.client_stock_invoices(invoice_number);

-- 4. Create client_stock_invoice_items table
CREATE TABLE IF NOT EXISTS public.client_stock_invoice_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID NOT NULL REFERENCES public.client_stock_invoices(id) ON DELETE CASCADE,
    product_id TEXT,
    product_name TEXT NOT NULL,
    product_sku TEXT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    supplier_unit_price NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    packaging_cost_per_unit NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    transportation_cost_per_unit NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    handling_cost_per_unit NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    other_addons_per_unit NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    effective_landed_cost_per_unit NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    total_landed_cost NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    target_retail_price NUMERIC(14, 2) DEFAULT 0.00,
    projected_margin_percent NUMERIC(6, 2) DEFAULT 0.00,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_stock_inv_items_invoice ON public.client_stock_invoice_items(invoice_id);
CREATE INDEX IF NOT EXISTS idx_stock_inv_items_product ON public.client_stock_invoice_items(product_name);

-- 5. Create client_stock_balances table (Pangea Suite Mirror & Multi-Hub Ledger)
CREATE TABLE IF NOT EXISTS public.client_stock_balances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id TEXT NOT NULL,
    product_id TEXT,
    item_code TEXT NOT NULL,
    item_name TEXT NOT NULL,
    item_group TEXT DEFAULT 'Novacare',
    warehouse TEXT NOT NULL,
    stock_uom TEXT DEFAULT 'Nos',
    opening_qty NUMERIC(14, 2) DEFAULT 0.00,
    opening_value NUMERIC(14, 2) DEFAULT 0.00,
    in_qty NUMERIC(14, 2) DEFAULT 0.00,
    in_value NUMERIC(14, 2) DEFAULT 0.00,
    out_qty NUMERIC(14, 2) DEFAULT 0.00,
    out_value NUMERIC(14, 2) DEFAULT 0.00,
    balance_qty NUMERIC(14, 2) DEFAULT 0.00,
    balance_value NUMERIC(14, 2) DEFAULT 0.00,
    valuation_rate NUMERIC(14, 4) DEFAULT 0.0000,
    reserved_stock NUMERIC(14, 2) DEFAULT 0.00,
    low_stock_threshold INT DEFAULT 20,
    company TEXT DEFAULT 'Novacare Ltd',
    last_entry_invoice_id UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_client_stock_balance UNIQUE (client_id, item_code, warehouse)
);

CREATE INDEX IF NOT EXISTS idx_client_stock_bal_client ON public.client_stock_balances(client_id);
CREATE INDEX IF NOT EXISTS idx_client_stock_bal_item ON public.client_stock_balances(item_name);
CREATE INDEX IF NOT EXISTS idx_client_stock_bal_warehouse ON public.client_stock_balances(warehouse);

-- 6. RPC Function: Process & Finalize Stock Intake Invoice
CREATE OR REPLACE FUNCTION public.fn_process_client_stock_intake_invoice(p_invoice_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_inv RECORD;
    v_item RECORD;
    v_cur_bal RECORD;
    v_new_bal_qty NUMERIC;
    v_new_valuation NUMERIC;
BEGIN
    SELECT * INTO v_inv FROM public.client_stock_invoices WHERE id = p_invoice_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Invoice not found');
    END IF;

    -- Iterate through each item in the invoice
    FOR v_item IN SELECT * FROM public.client_stock_invoice_items WHERE invoice_id = p_invoice_id LOOP
        -- Check if a stock balance record already exists for this client, item, and warehouse
        SELECT * INTO v_cur_bal 
        FROM public.client_stock_balances
        WHERE client_id = v_inv.client_id
          AND (item_code = v_item.product_sku OR item_name = v_item.product_name)
          AND warehouse = v_inv.destination_warehouse;

        IF FOUND THEN
            -- Calculate weighted average valuation rate
            v_new_bal_qty := v_cur_bal.balance_qty + v_item.quantity;
            IF v_new_bal_qty > 0 THEN
                v_new_valuation := ((v_cur_bal.balance_qty * v_cur_bal.valuation_rate) + (v_item.quantity * v_item.effective_landed_cost_per_unit)) / v_new_bal_qty;
            ELSE
                v_new_valuation := v_item.effective_landed_cost_per_unit;
            END IF;

            UPDATE public.client_stock_balances
            SET in_qty = in_qty + v_item.quantity,
                in_value = in_value + v_item.total_landed_cost,
                balance_qty = balance_qty + v_item.quantity,
                balance_value = (balance_qty + v_item.quantity) * v_new_valuation,
                valuation_rate = v_new_valuation,
                last_entry_invoice_id = p_invoice_id,
                updated_at = NOW()
            WHERE id = v_cur_bal.id;
        ELSE
            -- Insert new stock balance record
            INSERT INTO public.client_stock_balances (
                client_id,
                product_id,
                item_code,
                item_name,
                warehouse,
                stock_uom,
                opening_qty,
                opening_value,
                in_qty,
                in_value,
                out_qty,
                out_value,
                balance_qty,
                balance_value,
                valuation_rate,
                reserved_stock,
                last_entry_invoice_id
            ) VALUES (
                v_inv.client_id,
                v_item.product_id,
                v_item.product_sku,
                v_item.product_name,
                v_inv.destination_warehouse,
                'Nos',
                0,
                0,
                v_item.quantity,
                v_item.total_landed_cost,
                0,
                0,
                v_item.quantity,
                v_item.total_landed_cost,
                v_item.effective_landed_cost_per_unit,
                0,
                p_invoice_id
            );
        END IF;

        -- Also synchronize products table available stock and cost price
        UPDATE public.products
        SET stock_quantity = COALESCE(stock_quantity, 0) + v_item.quantity,
            available_count = COALESCE(available_count, 0) + v_item.quantity,
            base_price = CASE WHEN base_price <= 0 THEN v_item.target_retail_price ELSE base_price END,
            updated_at = NOW()
        WHERE name = v_item.product_name OR sku = v_item.product_sku;
    END LOOP;

    -- Update invoice status to verified
    UPDATE public.client_stock_invoices
    SET status = 'verified',
        updated_at = NOW()
    WHERE id = p_invoice_id;

    RETURN jsonb_build_object('success', true, 'invoice_id', p_invoice_id);
END;
$$;

-- 7. Seed Initial Verified Suppliers for Novacare Ltd
INSERT INTO public.client_suppliers (
    id, client_id, supplier_name, contact_person, email, phone, address, city, payment_terms, bank_name, account_number, account_name, notes
) VALUES (
    'a1111111-2222-3333-4444-555555555551'::uuid,
    '33333333-3333-4333-8333-333333333333',
    'Apex Herbal Laboratories Ltd',
    'Alhaji Musa Danjuma',
    'supplies@apexherbal.ng',
    '08023456781',
    'Plot 45, Industrial Estate, Kano',
    'Kano',
    'Net 15',
    'Zenith Bank',
    '1019283746',
    'Apex Herbal Laboratories Ltd',
    'Primary raw herbal formulations manufacturer for Grazer and Ura Clear series.'
), (
    'a1111111-2222-3333-4444-555555555552'::uuid,
    '33333333-3333-4333-8333-333333333333',
    'PolyPack & Foil Print Works',
    'Mrs. Folashade Adeyemi',
    'orders@polypackng.com',
    '08139876543',
    '14 Oshodi Expressway, Ilupeju, Lagos',
    'Lagos',
    'Immediate',
    'Access Bank',
    '0029384756',
    'PolyPack Solutions Nigeria',
    'Customized anti-tamper foil pouches, carton packaging, and tea box printing.'
), (
    'a1111111-2222-3333-4444-555555555553'::uuid,
    '33333333-3333-4333-8333-333333333333',
    'Trans-Sahara Inter-State Haulage',
    'Captain Godwin Effiong',
    'dispatch@transsaharalogistics.com',
    '09056781234',
    'Central Heavy Truck Terminal, Idu, Abuja',
    'Abuja',
    '50% Advance',
    'First Bank of Nigeria',
    '3049586712',
    'Trans Sahara Freight Ltd',
    'Bulk freight haulage from manufacturing laboratories to central storage and regional distribution centers.'
)
ON CONFLICT (id) DO NOTHING;

-- Grant permissions for public / authenticated
GRANT SELECT, INSERT, UPDATE, DELETE ON public.client_suppliers TO authenticated, service_role, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.client_stock_invoices TO authenticated, service_role, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.client_stock_invoice_items TO authenticated, service_role, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.client_stock_balances TO authenticated, service_role, anon;


-- =================== 20260920110000_seed_pangea_stock_balances.sql ===================
-- ============================================================================
-- PANGEA SUITE STOCK BALANCES SEED (NOVACARE LTD)
-- Export Date: 2026-09-13 | Total Balance Positions: 917
-- ============================================================================

-- 1. Synchronize master products catalog with Pangea Suite valuation rates
UPDATE public.products SET stock_quantity = 58595, available_count = 58595, base_price = 1908.556, client_id = '33333333-3333-4333-8333-333333333333' WHERE name = 'Grazer Herbal Tea';
UPDATE public.products SET stock_quantity = 6112, available_count = 6112, base_price = 5000.0, client_id = '33333333-3333-4333-8333-333333333333' WHERE name = 'Hair Dye Shampoo';
UPDATE public.products SET stock_quantity = 2496, available_count = 2496, base_price = 2500.0, client_id = '33333333-3333-4333-8333-333333333333' WHERE name = 'Grazer Herbal Balm';
UPDATE public.products SET stock_quantity = 448, available_count = 448, base_price = 1248.99, client_id = '33333333-3333-4333-8333-333333333333' WHERE name = 'Nail Repair';
UPDATE public.products SET stock_quantity = 2460, available_count = 2460, base_price = 2256.41, client_id = '33333333-3333-4333-8333-333333333333' WHERE name = 'Clear Vision Tea';
UPDATE public.products SET stock_quantity = 39816, available_count = 39816, base_price = 2950.0, client_id = '33333333-3333-4333-8333-333333333333' WHERE name = 'Ura Clear Tea';
UPDATE public.products SET stock_quantity = 12228, available_count = 12228, base_price = 5000.0, client_id = '33333333-3333-4333-8333-333333333333' WHERE name = 'Compression Vest';
UPDATE public.products SET stock_quantity = 1515, available_count = 1515, base_price = 1800.0, client_id = '33333333-3333-4333-8333-333333333333' WHERE name = 'Hair Growth Oil';
UPDATE public.products SET stock_quantity = 4818, available_count = 4818, base_price = 1950.0, client_id = '33333333-3333-4333-8333-333333333333' WHERE name = 'ORAVITA CAPSULE';
UPDATE public.products SET stock_quantity = 1396, available_count = 1396, base_price = 2300.0, client_id = '33333333-3333-4333-8333-333333333333' WHERE name = 'VELORA HERBAL TEA';
UPDATE public.products SET stock_quantity = 2931, available_count = 2931, base_price = 2000.0, client_id = '33333333-3333-4333-8333-333333333333' WHERE name = 'ALPHA MAN HERBAL TEA';
UPDATE public.products SET stock_quantity = 2973, available_count = 2973, base_price = 1800.0, client_id = '33333333-3333-4333-8333-333333333333' WHERE name = 'RESPIRA LUNG TEA';
UPDATE public.products SET stock_quantity = 10, available_count = 10, base_price = 2000.0, client_id = '33333333-3333-4333-8333-333333333333' WHERE name = 'Push Board Pro';

-- 2. Insert Stock Balance records across all 108 warehouses

INSERT INTO public.client_stock_balances (
    client_id, item_code, item_name, item_group, warehouse, stock_uom,
    opening_qty, opening_value, in_qty, in_value, out_qty, out_value,
    balance_qty, balance_value, valuation_rate, reserved_stock, company
) VALUES
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Stores - NL', 'Nos', 24177.0, 46131425.51, 34.0, 66752.39, 3040.0, 5792142.4, 21171.0, 40406035.5, 1908.556, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Adeyemo Adeola LOGISTICS - Novacare Ltd - NL', 'Nos', 101.0, 194424.8, 0.0, 0.0, 0.0, 0.0, 101.0, 194424.8, 1924.998, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'PELICAN DELIVERY AND LOGISTICS SERVICES LOGISTICS - Novacare Ltd - NL', 'Nos', 63.0, 315000.0, 0.0, 0.0, 0.0, 0.0, 63.0, 315000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'KENNEDY OROWO EDEYE Logistics - Novacare Ltd - NL', 'Nos', 367.0, 699248.77, 0.0, 0.0, 115.0, 219110.65, 252.0, 480138.12, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Efe Brendon Avwia Logistics - Novacare Ltd - NL', 'Nos', 436.0, 632715.16, 0.0, 0.0, 115.0, 219110.65, 321.0, 413604.51, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Ibylogistics Limited LOGISTICS - Novacare Ltd - NL', 'Nos', 680.0, 1309814.3, 0.0, 0.0, 69.0, 131466.39, 611.0, 1178347.91, 1928.556, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Chidimma maryjane Iloegbunam Logistics - Novacare Ltd - NL', 'Nos', 604.0, 1150863.04, 0.0, 0.0, 0.0, 0.0, 604.0, 1150863.04, 1905.402, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Hambolu babatunde philips Logistics - Novacare Ltd - NL', 'Nos', 597.0, 1135470.07, 0.0, 0.0, 132.0, 251500.92, 465.0, 883969.15, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'BLUE AMAZON LOGISTICS LTD LOGISTICS - Novacare Ltd - NL', 'Nos', 439.0, 845496.44, 0.0, 0.0, 18.0, 34667.28, 421.0, 810829.16, 1925.96, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Changfa Jesse David - Novacare Ltd - NL', 'Nos', 4.0, 7621.24, 0.0, 0.0, 0.0, 0.0, 4.0, 7621.24, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Olufunke Babalola Logistics - Novacare Ltd - NL', 'Nos', 17.0, 80000.0, 0.0, 0.0, 0.0, 0.0, 17.0, 80000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Teekina kuroakegha Gbeneteh Logistics - Novacare Ltd - NL', 'Nos', -152.0, -285360.08, 320.0, 609699.2, 44.0, 84945.96, 124.0, 239393.16, 1930.59, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Olufunke Babalola Logistics - Novacare Ltd - NL', 'Nos', 410.0, 782203.1, 0.0, 0.0, 49.0, 93918.79, 361.0, 688284.31, 1906.605, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Emmanuel Nnamdi Ugwu Logistics - Novacare Ltd - NL', 'Nos', 173.0, 339375.83, 0.0, 0.0, 21.0, 41195.91, 152.0, 298179.92, 1961.71, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Omoga Victor Ohe-obe Logistics - Novacare Ltd - NL', 'Nos', 443.0, 844052.33, 0.0, 0.0, 112.0, 213394.72, 331.0, 630657.61, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Oluwadamilare Emmanuel Logistics - Novacare Ltd - NL', 'Nos', 468.0, 893692.8, 0.0, 0.0, 95.0, 181412.0, 373.0, 712280.8, 1909.6, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Etimbuk Gregory Logistics - Novacare Ltd - NL', 'Nos', 414.0, 788798.34, 320.0, 609699.2, 80.0, 152424.8, 654.0, 1246072.74, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'YAYA JOB - Novacare Ltd - NL', 'Nos', 19.0, 47500.0, 0.0, 0.0, 0.0, 0.0, 19.0, 47500.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Victor Ogbenyi Logistics - Novacare Ltd - NL', 'Nos', 3.0, 146.97, 0.0, 0.0, 0.0, 0.0, 3.0, 146.97, 1248.99, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Victor Ogbenyi Logistics - Novacare Ltd - NL', 'Nos', 502.0, 824465.62, 320.0, 609699.2, 257.0, 489664.67, 565.0, 944500.15, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Enny logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 440.0, 94684.8, 160.0, 304849.6, 74.0, 142481.08, 526.0, 257053.32, 1919.303, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'RAPH XPRESS LOGISTICS - Novacare Ltd - NL', 'Nos', 25.0, 56410.25, 0.0, 0.0, 0.0, 0.0, 25.0, 56410.25, 2256.41, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Chidi Godstime Egege Logistics - Novacare Ltd - NL', 'Nos', 357.0, 680195.67, 0.0, 0.0, 105.0, 200057.55, 252.0, 480138.12, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'YAYA JOB - Novacare Ltd - NL', 'Nos', 410.0, 802542.2, 0.0, 0.0, 0.0, 0.0, 410.0, 802542.2, 1957.42, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'John Hamza shuaibu Logistics - Novacare Ltd - NL', 'Nos', -1.0, -5000.0, 0.0, 0.0, 1.0, 5000.0, -2.0, -10000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'John Hamza shuaibu Logistics - Novacare Ltd - NL', 'Nos', 185.0, 352482.35, 0.0, 0.0, 155.0, 295323.05, 30.0, 57159.3, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'RAPH XPRESS LOGISTICS - Novacare Ltd - NL', 'Nos', 857.0, 1632850.67, 320.0, 609699.2, 150.0, 285796.5, 1027.0, 1956753.37, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'smart logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 335.0, 654849.6, 0.0, 0.0, 41.0, 82000.0, 294.0, 572849.6, 1948.468, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Emmanuel Nnamdi Ugwu Logistics - Novacare Ltd - NL', 'Nos', 17.0, 42500.0, 0.0, 0.0, 0.0, 0.0, 17.0, 42500.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Durojaiye Ilashe Joseph Logistics - Novacare Ltd - NL', 'Nos', 34.0, 170000.0, 0.0, 0.0, 0.0, 0.0, 34.0, 170000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Durojaiye Ilashe Joseph Logistics - Novacare Ltd - NL', 'Nos', 303.0, 580763.13, 160.0, 304849.6, 26.0, 49834.46, 437.0, 835778.27, 1912.536, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Abdulsalam Abubakar Logistics - Novacare Ltd - NL', 'Nos', 421.0, 802135.51, 0.0, 0.0, 89.0, 169572.59, 332.0, 632562.92, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Olupona oluwaseyi Logistics - Novacare Ltd - NL', 'Nos', 758.0, 1447029.58, 0.0, 0.0, 0.0, 0.0, 758.0, 1447029.58, 1909.01, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Olupona oluwaseyi Logistics - Novacare Ltd - NL', 'Nos', 134.0, 395300.0, 0.0, 0.0, 0.0, 0.0, 134.0, 395300.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Adeyinka Ekundayo Isreal Logistics - Novacare Ltd - NL', 'Nos', 780.0, 1495033.8, 0.0, 0.0, 0.0, 0.0, 780.0, 1495033.8, 1916.71, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Olawale Olusola Logistics - Novacare Ltd - NL', 'Nos', 863.0, 1695699.2, 0.0, 0.0, 65.0, 130000.0, 798.0, 1565699.2, 1962.029, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'ADICHA LOGISTICS - Novacare Ltd - NL', 'Nos', 364.0, 693532.84, 0.0, 0.0, 22.0, 41916.82, 342.0, 651616.02, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'ZIBRA & CO LTD LOGISTICS - Novacare Ltd - NL', 'Nos', 503.0, 958370.93, 0.0, 0.0, 80.0, 152424.8, 423.0, 805946.13, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'ZIBRA & CO LTD LOGISTICS - Novacare Ltd - NL', 'Nos', 463.0, 1381850.0, 0.0, 0.0, 51.0, 150450.0, 412.0, 1231400.0, 2988.835, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Smart move Logistics Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 203.0, 386869.28, 0.0, 0.0, 53.0, 101005.28, 150.0, 285864.0, 1905.76, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Efe Brendon Avwia Logistics - Novacare Ltd - NL', 'Nos', 28.0, 50499.88, 0.0, 0.0, 0.0, 0.0, 28.0, 50499.88, 2785.71, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'PELICAN DELIVERY AND LOGISTICS SERVICES LOGISTICS - Novacare Ltd - NL', 'Nos', 326.0, 621199.46, 0.0, 0.0, 71.0, 135345.41, 255.0, 485854.05, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Chidimma maryjane Iloegbunam Logistics - Novacare Ltd - NL', 'Nos', 75.0, 375000.0, 0.0, 0.0, 0.0, 0.0, 75.0, 375000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Sheriff Adesola Raifu Logistics - Novacare Ltd - NL', 'Nos', 298.0, 567782.38, 0.0, 0.0, 113.0, 215300.03, 185.0, 352482.35, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Shittu Adebamke Yusuff Logistics - Novacare Ltd - NL', 'Nos', 401.0, 802000.0, 0.0, 0.0, 58.0, 116000.0, 343.0, 686000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Enny logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 21.0, 33600.0, 0.0, 0.0, 0.0, 0.0, 21.0, 33600.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Tajudeen A Ayetigbo LOGISTICS - Novacare Ltd - NL', 'Nos', 19.0, 47500.0, 0.0, 0.0, 0.0, 0.0, 19.0, 47500.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'HOG logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 371.0, 706870.01, 0.0, 0.0, 174.0, 331523.94, 197.0, 375346.07, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Olufunke Babalola Logistics - Novacare Ltd - NL', 'Nos', 440.0, 1312000.0, 0.0, 0.0, 18.0, 53100.0, 422.0, 1258900.0, 2987.915, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'ADICHA LOGISTICS - Novacare Ltd - NL', 'Nos', 5.0, 25000.0, 0.0, 0.0, 0.0, 0.0, 5.0, 25000.0, 5000.0, 0.0, 'Novacare Ltd')
ON CONFLICT (client_id, item_code, warehouse) DO UPDATE SET
    opening_qty = EXCLUDED.opening_qty,
    opening_value = EXCLUDED.opening_value,
    in_qty = EXCLUDED.in_qty,
    in_value = EXCLUDED.in_value,
    out_qty = EXCLUDED.out_qty,
    out_value = EXCLUDED.out_value,
    balance_qty = EXCLUDED.balance_qty,
    balance_value = EXCLUDED.balance_value,
    valuation_rate = EXCLUDED.valuation_rate,
    reserved_stock = EXCLUDED.reserved_stock,
    updated_at = NOW();


INSERT INTO public.client_stock_balances (
    client_id, item_code, item_name, item_group, warehouse, stock_uom,
    opening_qty, opening_value, in_qty, in_value, out_qty, out_value,
    balance_qty, balance_value, valuation_rate, reserved_stock, company
) VALUES
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'smart logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 30.0, 75000.0, 0.0, 0.0, 0.0, 0.0, 30.0, 75000.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Olupona oluwaseyi Logistics - Novacare Ltd - NL', 'Nos', 84.0, 420000.0, 0.0, 0.0, 0.0, 0.0, 84.0, 420000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Ibrahim Abdulrashid Logistics - Novacare Ltd - NL', 'Nos', 456.0, 885347.2, 0.0, 0.0, 7.0, 14000.0, 449.0, 871347.2, 1940.64, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Abu Momoh Logistics - Novacare Ltd - NL', 'Nos', 418.0, 836000.0, 0.0, 0.0, 0.0, 0.0, 418.0, 836000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Chidimma maryjane Iloegbunam Logistics - Novacare Ltd - NL', 'Nos', 13.0, 34728.59, 0.0, 0.0, 0.0, 0.0, 13.0, 34728.59, 2671.43, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Yohanna Vanduna Logistics - Novacare Ltd - NL', 'Nos', 481.0, 919392.36, 0.0, 0.0, 26.0, 50012.56, 455.0, 869379.8, 1910.725, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'RAPH XPRESS LOGISTICS - Novacare Ltd - NL', 'Nos', 67.0, 187600.0, 0.0, 0.0, 1.0, 2800.0, 66.0, 184800.0, 2800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Adetola Sam Adewuyi LOGISTICS - Novacare Ltd - NL', 'Nos', 209.0, 398768.39, 0.0, 0.0, 45.0, 86251.95, 164.0, 312516.44, 1905.588, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Akanimo Edet Akpan Logistics - Novacare Ltd - NL', 'Nos', 396.0, 759213.32, 0.0, 0.0, 45.0, 86637.15, 351.0, 672576.17, 1916.171, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Okoli Nnaemeka Augustine Logistics - Novacare Ltd - NL', 'Nos', 317.0, 603983.27, 0.0, 0.0, 189.0, 360103.59, 128.0, 243879.68, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Chidi Godstime Egege Logistics - Novacare Ltd - NL', 'Nos', 25.0, 62500.0, 0.0, 0.0, 0.0, 0.0, 25.0, 62500.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Etimbuk Gregory Logistics - Novacare Ltd - NL', 'Nos', 113.0, 565000.0, 0.0, 0.0, 0.0, 0.0, 113.0, 565000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Msuega Terlanga Japhet Logistics - Novacare Ltd - NL', 'Nos', 408.0, 778369.68, 0.0, 0.0, 56.0, 107335.76, 352.0, 671033.92, 1906.346, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Raphael Michael Logistics - Novacare Ltd - NL', 'Nos', 629.0, 1198439.99, 320.0, 609699.2, 87.0, 165761.97, 862.0, 1642377.22, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Hezekiah Victor Adesanmi Logistics - Novacare Ltd - NL', 'Nos', 182.0, 347017.22, 0.0, 0.0, 0.0, 0.0, 182.0, 347017.22, 1906.688, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Akanimo Edet Akpan Logistics - Novacare Ltd - NL', 'Nos', 36.0, 90000.0, 0.0, 0.0, 0.0, 0.0, 36.0, 90000.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Ibitoye adewale Logistics - Novacare Ltd - NL', 'Nos', 242.0, 466235.44, 0.0, 0.0, 85.0, 167101.77, 157.0, 299133.67, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Ibitoye adewale Logistics - Novacare Ltd - NL', 'Nos', 68.0, 184232.4, 0.0, 0.0, 0.0, 0.0, 68.0, 184232.4, 2709.3, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Anthony Ezekiel Logistics - Novacare Ltd - NL', 'Nos', 21.0, 37800.0, 0.0, 0.0, 0.0, 0.0, 21.0, 37800.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Anthony Ezekiel Logistics - Novacare Ltd - NL', 'Nos', 40.0, 120000.0, 0.0, 0.0, 0.0, 0.0, 40.0, 120000.0, 3000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'TEMIBASH LOGISTICS LOGISTICS - Novacare Ltd - NL', 'Nos', 225.0, 436673.6, 0.0, 0.0, 46.0, 92000.0, 179.0, 344673.6, 1925.551, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Adeyemo Adeola LOGISTICS - Novacare Ltd - NL', 'Nos', 3.0, 3746.97, 0.0, 0.0, 0.0, 0.0, 3.0, 3746.97, 1248.99, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'KENNEDY OROWO EDEYE Logistics - Novacare Ltd - NL', 'Nos', 518.0, 1544100.0, 0.0, 0.0, 72.0, 212400.0, 446.0, 1331700.0, 2985.874, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'ZIBRA & CO LTD LOGISTICS - Novacare Ltd - NL', 'Nos', 8.0, 22400.0, 0.0, 0.0, 0.0, 0.0, 8.0, 22400.0, 2800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'ZIBRA & CO LTD LOGISTICS - Novacare Ltd - NL', 'Nos', 18.0, 36000.0, 0.0, 0.0, 0.0, 0.0, 18.0, 36000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Adekunle Logistic - Novacare Ltd - NL', 'Nos', 226.0, 402000.0, 0.0, 0.0, 34.0, 68000.0, 192.0, 334000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Raphael Michael Logistics - Novacare Ltd - NL', 'Nos', 60.0, 300000.0, 0.0, 0.0, 0.0, 0.0, 60.0, 300000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Oluwadamilare Emmanuel Logistics - Novacare Ltd - NL', 'Nos', 8.0, 40000.0, 0.0, 0.0, 0.0, 0.0, 8.0, 40000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'ATP Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 726.0, 1383255.06, 320.0, 609699.2, 154.0, 293417.74, 892.0, 1699536.52, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'HOG logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 49.0, 122500.0, 0.0, 0.0, 0.0, 0.0, 49.0, 122500.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Hambolu babatunde philips Logistics - Novacare Ltd - NL', 'Nos', 510.0, 1512500.0, 0.0, 0.0, 81.0, 238950.0, 429.0, 1273550.0, 2968.648, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Olaseni Adewumi James Logistics - Novacare Ltd - NL', 'Nos', 239.0, 478000.0, 0.0, 0.0, 66.0, 132000.0, 173.0, 346000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Usiju Ladu Logistics - Novacare Ltd - NL', 'Nos', 36.0, 44963.64, 0.0, 0.0, 0.0, 0.0, 36.0, 44963.64, 1248.99, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Toheeb Biola Popoola Logistics - Novacare Ltd - NL', 'Nos', 121.0, 230542.51, 320.0, 609699.2, 74.0, 140992.94, 367.0, 699248.77, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'ATP Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 43.0, 120400.0, 0.0, 0.0, 0.0, 0.0, 43.0, 120400.0, 2800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Victor Ogbenyi Logistics - Novacare Ltd - NL', 'Nos', 5.0, 1500.0, 0.0, 0.0, 0.0, 0.0, 5.0, 1500.0, 2800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'GINIKA ANAMBRA - Novacare Ltd - NL', 'Nos', 280.0, 533486.8, 0.0, 0.0, 77.0, 146708.87, 203.0, 386777.93, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'ATP Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 99.0, 495000.0, 0.0, 0.0, 1.0, 5000.0, 98.0, 490000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Tajudeen A Ayetigbo LOGISTICS - Novacare Ltd - NL', 'Nos', 532.0, 1037920.24, 0.0, 0.0, 11.0, 21676.82, 521.0, 1016243.42, 1950.563, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Alatiya Absalom Emmanuel Logistics - Novacare Ltd - NL', 'Nos', 37.0, 92500.0, 0.0, 0.0, 0.0, 0.0, 37.0, 92500.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Alatiya Absalom Emmanuel Logistics - Novacare Ltd - NL', 'Nos', 413.0, 795699.2, 0.0, 0.0, 49.0, 98000.0, 364.0, 697699.2, 1916.756, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'John Hamza shuaibu Logistics - Novacare Ltd - NL', 'Nos', 98.0, 257599.86, 0.0, 0.0, 0.0, 0.0, 98.0, 257599.86, 2628.57, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Arinze Esther Logistics - Novacare Ltd - NL', 'Nos', 372.0, 708985.92, 0.0, 0.0, 64.0, 122150.44, 308.0, 586835.48, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Olufunke Babalola Logistics - Novacare Ltd - NL', 'Nos', 20.0, 24500.0, 0.0, 0.0, 0.0, 0.0, 20.0, 24500.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Teekina kuroakegha Gbeneteh Logistics - Novacare Ltd - NL', 'Nos', 19.0, 47500.0, 0.0, 0.0, 0.0, 0.0, 19.0, 47500.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Ezekiel Ameh Logistics - Novacare Ltd - NL', 'Nos', 242.0, 461085.02, 0.0, 0.0, 38.0, 72401.78, 204.0, 388683.24, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'George O.O LOGISTICS - Novacare Ltd - NL', 'Nos', 540.0, 1028867.4, 0.0, 0.0, 103.0, 196246.93, 437.0, 832620.47, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Ezekiel Ameh Logistics - Novacare Ltd - NL', 'Nos', 52.0, 260000.0, 0.0, 0.0, 0.0, 0.0, 52.0, 260000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'RAPH XPRESS LOGISTICS - Novacare Ltd - NL', 'Nos', 85.0, 425000.0, 0.0, 0.0, 2.0, 10000.0, 83.0, 415000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Chidimma maryjane Iloegbunam Logistics - Novacare Ltd - NL', 'Nos', 343.0, 1011850.0, 0.0, 0.0, 0.0, 0.0, 343.0, 1011850.0, 2950.0, 0.0, 'Novacare Ltd')
ON CONFLICT (client_id, item_code, warehouse) DO UPDATE SET
    opening_qty = EXCLUDED.opening_qty,
    opening_value = EXCLUDED.opening_value,
    in_qty = EXCLUDED.in_qty,
    in_value = EXCLUDED.in_value,
    out_qty = EXCLUDED.out_qty,
    out_value = EXCLUDED.out_value,
    balance_qty = EXCLUDED.balance_qty,
    balance_value = EXCLUDED.balance_value,
    valuation_rate = EXCLUDED.valuation_rate,
    reserved_stock = EXCLUDED.reserved_stock,
    updated_at = NOW();


INSERT INTO public.client_stock_balances (
    client_id, item_code, item_name, item_group, warehouse, stock_uom,
    opening_qty, opening_value, in_qty, in_value, out_qty, out_value,
    balance_qty, balance_value, valuation_rate, reserved_stock, company
) VALUES
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Adetola Sam Adewuyi LOGISTICS - Novacare Ltd - NL', 'Nos', 32.0, 54400.0, 0.0, 0.0, 3.0, 5100.0, 29.0, 49300.0, 1700.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Victor Ogbenyi Logistics - Novacare Ltd - NL', 'Nos', 35.0, 120000.0, 0.0, 0.0, 0.0, 0.0, 35.0, 120000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Changfa Jesse David - Novacare Ltd - NL', 'Nos', 65.0, 191750.0, 0.0, 0.0, 9.0, 26550.0, 56.0, 165200.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Ibylogistics Limited LOGISTICS - Novacare Ltd - NL', 'Nos', 33.0, 165000.0, 0.0, 0.0, 1.0, 5000.0, 32.0, 160000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Emmanuel Olapeju Awoyemi Logistics - Novacare Ltd - NL', 'Nos', 454.0, 892849.6, 0.0, 0.0, 0.0, 0.0, 454.0, 892849.6, 1966.629, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Ola Cash - Novacare Ltd - NL', 'Nos', 34.0, 170000.0, 0.0, 0.0, 2.0, 10000.0, 32.0, 160000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Ola Cash - Novacare Ltd - NL', 'Nos', 241.0, 459709.91, 0.0, 0.0, 79.0, 150693.29, 162.0, 309016.62, 1907.51, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Ola Cash - Novacare Ltd - NL', 'Nos', 11.0, 22000.0, 0.0, 0.0, 0.0, 0.0, 11.0, 22000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Ola Cash - Novacare Ltd - NL', 'Nos', 32.0, 64000.0, 0.0, 0.0, 0.0, 0.0, 32.0, 64000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Ola Cash - Novacare Ltd - NL', 'Nos', 279.0, 823050.0, 0.0, 0.0, 15.0, 44250.0, 264.0, 778800.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Emmanuel Olapeju Awoyemi Logistics - Novacare Ltd - NL', 'Nos', 20.0, 50000.0, 0.0, 0.0, 0.0, 0.0, 20.0, 50000.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Hambolu babatunde philips Logistics - Novacare Ltd - NL', 'Nos', 46.0, 92000.0, 0.0, 0.0, 0.0, 0.0, 46.0, 92000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'John Hamza shuaibu Logistics - Novacare Ltd - NL', 'Nos', 397.0, 1187150.0, 0.0, 0.0, 106.0, 314150.0, 291.0, 873000.0, 3000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Tajudeen A Ayetigbo LOGISTICS - Novacare Ltd - NL', 'Nos', 57.0, 285000.0, 0.0, 0.0, 1.0, 5000.0, 56.0, 280000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Adekunle Logistic - Novacare Ltd - NL', 'Nos', 244.0, 603900.0, 0.0, 0.0, 26.0, 64350.0, 218.0, 539550.0, 2475.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'George O.O LOGISTICS - Novacare Ltd - NL', 'Nos', 23.0, 115000.0, 0.0, 0.0, 5.0, 25000.0, 18.0, 90000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Adeyemo Adeola LOGISTICS - Novacare Ltd - NL', 'Nos', 14.0, 28000.0, 0.0, 0.0, 0.0, 0.0, 14.0, 28000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Adeyemo Adeola LOGISTICS - Novacare Ltd - NL', 'Nos', 8.0, 40000.0, 0.0, 0.0, 0.0, 0.0, 8.0, 40000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Adeyemo Adeola LOGISTICS - Novacare Ltd - NL', 'Nos', 60.0, 150000.0, 0.0, 0.0, 0.0, 0.0, 60.0, 150000.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Etimbuk Gregory Logistics - Novacare Ltd - NL', 'Nos', 202.0, 595900.0, 160.0, 480000.0, 39.0, 115050.0, 323.0, 960850.0, 2974.768, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Velocitŕ logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 593.0, 1134071.64, 0.0, 0.0, 50.0, 97134.0, 543.0, 1036937.64, 1909.646, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Velocitŕ logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 13.0, 24700.0, 0.0, 0.0, 0.0, 0.0, 13.0, 24700.0, 1900.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Victor Ogbenyi Logistics - Novacare Ltd - NL', 'Nos', 256.0, 764000.0, 320.0, 960000.0, 110.0, 330000.0, 466.0, 1394000.0, 3000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Olawale Olusola Logistics - Novacare Ltd - NL', 'Nos', 31.0, 155000.0, 0.0, 0.0, 0.0, 0.0, 31.0, 155000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Fomax logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 778.0, 1525699.2, 0.0, 0.0, 136.0, 272000.0, 642.0, 1253699.2, 1952.802, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'ATP Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 323.0, 968850.0, 160.0, 480000.0, 132.0, 395850.0, 351.0, 1053000.0, 3000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Adetola Sam Adewuyi LOGISTICS - Novacare Ltd - NL', 'Nos', 38.0, 190000.0, 0.0, 0.0, 1.0, 5000.0, 37.0, 185000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Shittu Adebamke Yusuff Logistics - Novacare Ltd - NL', 'Nos', 26.0, 130000.0, 0.0, 0.0, 0.0, 0.0, 26.0, 130000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Abdulsalam Abubakar Logistics - Novacare Ltd - NL', 'Nos', 44.0, 220000.0, 0.0, 0.0, 0.0, 0.0, 44.0, 220000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Anthony Ezekiel Logistics - Novacare Ltd - NL', 'Nos', 356.0, 691957.44, 0.0, 0.0, 28.0, 55301.12, 328.0, 636656.32, 1941.025, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Express Logistics, Ebonyi LOGISTICS - Novacare Ltd - NL', 'Nos', 277.0, 527770.87, 0.0, 0.0, 61.0, 116223.91, 216.0, 411546.96, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Toheeb Biola Popoola Logistics - Novacare Ltd - NL', 'Nos', 55.0, 145750.0, 0.0, 0.0, 0.0, 0.0, 55.0, 145750.0, 2650.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Enny logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 25.0, 39000.0, 0.0, 0.0, 0.0, 0.0, 25.0, 39000.0, 3360.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'AHUAKAGHA CHIZURUOKE COSMOS Logistics - Novacare Ltd - NL', 'Nos', -2.0, -4000.0, 0.0, 0.0, 0.0, 0.0, -2.0, -4000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Omoga Victor Ohe-obe Logistics - Novacare Ltd - NL', 'Nos', 343.0, 1027850.0, 0.0, 0.0, 33.0, 97850.0, 310.0, 930000.0, 3000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'KENNEDY OROWO EDEYE Logistics - Novacare Ltd - NL', 'Nos', 44.0, 220000.0, 0.0, 0.0, 0.0, 0.0, 44.0, 220000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'KENNEDY OROWO EDEYE Logistics - Novacare Ltd - NL', 'Nos', 38.0, 102600.0, 0.0, 0.0, 0.0, 0.0, 38.0, 102600.0, 2700.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'PELICAN DELIVERY AND LOGISTICS SERVICES LOGISTICS - Novacare Ltd - NL', 'Nos', 238.0, 702100.0, 0.0, 0.0, 44.0, 129800.0, 194.0, 572300.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Express Logistics, Ebonyi LOGISTICS - Novacare Ltd - NL', 'Nos', 18.0, 45000.0, 0.0, 0.0, 0.0, 0.0, 18.0, 45000.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Teekina kuroakegha Gbeneteh Logistics - Novacare Ltd - NL', 'Nos', 20.0, 100000.0, 0.0, 0.0, 0.0, 0.0, 20.0, 100000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Smart move Logistics Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 29.0, 81200.0, 0.0, 0.0, 0.0, 0.0, 29.0, 81200.0, 2800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Adekunle Logistic - Novacare Ltd - NL', 'Nos', 25.0, 65000.0, 0.0, 0.0, 0.0, 0.0, 25.0, 65000.0, 2800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Usiju Ladu Logistics - Novacare Ltd - NL', 'Nos', 331.0, 635347.2, 0.0, 0.0, 31.0, 60334.2, 300.0, 575013.0, 1916.71, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'FOMAX PH. LOGISTICS - Novacare Ltd - NL', 'Nos', 293.0, 561596.03, 0.0, 0.0, 43.0, 82418.53, 250.0, 479177.5, 1916.71, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'YAYA JOB - Novacare Ltd - NL', 'Nos', 267.0, 787650.0, 0.0, 0.0, 0.0, 0.0, 267.0, 787650.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Okoli Nnaemeka Augustine Logistics - Novacare Ltd - NL', 'Nos', 9.0, 18000.0, 0.0, 0.0, 0.0, 0.0, 9.0, 18000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Omoga Victor Ohe-obe Logistics - Novacare Ltd - NL', 'Nos', 5.0, 14000.0, 0.0, 0.0, 0.0, 0.0, 5.0, 14000.0, 2800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Abdulsalam Abubakar Logistics - Novacare Ltd - NL', 'Nos', 20.0, 50000.0, 0.0, 0.0, 0.0, 0.0, 20.0, 50000.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'RAPH XPRESS LOGISTICS - Novacare Ltd - NL', 'Nos', 375.0, 1122250.0, 320.0, 960000.0, 138.0, 411250.0, 557.0, 1671000.0, 3000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Changfa Jesse David - Novacare Ltd - NL', 'Nos', 3.0, 15000.0, 0.0, 0.0, 0.0, 0.0, 3.0, 15000.0, 5000.0, 0.0, 'Novacare Ltd')
ON CONFLICT (client_id, item_code, warehouse) DO UPDATE SET
    opening_qty = EXCLUDED.opening_qty,
    opening_value = EXCLUDED.opening_value,
    in_qty = EXCLUDED.in_qty,
    in_value = EXCLUDED.in_value,
    out_qty = EXCLUDED.out_qty,
    out_value = EXCLUDED.out_value,
    balance_qty = EXCLUDED.balance_qty,
    balance_value = EXCLUDED.balance_value,
    valuation_rate = EXCLUDED.valuation_rate,
    reserved_stock = EXCLUDED.reserved_stock,
    updated_at = NOW();


INSERT INTO public.client_stock_balances (
    client_id, item_code, item_name, item_group, warehouse, stock_uom,
    opening_qty, opening_value, in_qty, in_value, out_qty, out_value,
    balance_qty, balance_value, valuation_rate, reserved_stock, company
) VALUES
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Teekina kuroakegha Gbeneteh Logistics - Novacare Ltd - NL', 'Nos', 119.0, 343050.0, 160.0, 480000.0, 37.0, 109150.0, 242.0, 713900.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'PELICAN DELIVERY AND LOGISTICS SERVICES LOGISTICS - Novacare Ltd - NL', 'Nos', 22.0, 55000.0, 0.0, 0.0, 0.0, 0.0, 22.0, 55000.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Hambolu babatunde philips Logistics - Novacare Ltd - NL', 'Nos', 61.0, 305000.0, 0.0, 0.0, 1.0, 5000.0, 60.0, 300000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'RAFH EXPRESS LOGISTICS ABUJA - Novacare Ltd - NL', 'Nos', 12.0, 60000.0, 0.0, 0.0, 0.0, 0.0, 12.0, 60000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Hambolu babatunde philips Logistics - Novacare Ltd - NL', 'Nos', 51.0, 81600.0, 0.0, 0.0, 0.0, 0.0, 51.0, 81600.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'FOMAX ASABA (DELTA) LOGISTICS - Novacare Ltd - NL', 'Nos', 363.0, 726000.0, 0.0, 0.0, 10.0, 20000.0, 353.0, 706000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'FOMAX ASABA (DELTA) LOGISTICS - Novacare Ltd - NL', 'Nos', 40.0, 100000.0, 0.0, 0.0, 0.0, 0.0, 40.0, 100000.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'RAPH XPRESS LOGISTICS - Novacare Ltd - NL', 'Nos', 18.0, 90000.0, 0.0, 0.0, 0.0, 0.0, 18.0, 90000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Ezekiel Ameh Logistics - Novacare Ltd - NL', 'Nos', 21.0, 58800.0, 0.0, 0.0, 0.0, 0.0, 21.0, 58800.0, 2800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Akanimo Edet Akpan Logistics - Novacare Ltd - NL', 'Nos', 13.0, 26000.0, 0.0, 0.0, 0.0, 0.0, 13.0, 26000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Chidimma maryjane Iloegbunam Logistics - Novacare Ltd - NL', 'Nos', 46.0, 230000.0, 0.0, 0.0, 0.0, 0.0, 46.0, 230000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Anthony Ezekiel Logistics - Novacare Ltd - NL', 'Nos', 408.0, 1220939.36, 0.0, 0.0, 8.0, 23721.76, 400.0, 1197217.6, 2993.044, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Fomax logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 60.0, 300000.0, 0.0, 0.0, 0.0, 0.0, 60.0, 300000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Velocitŕ logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 18.0, 90000.0, 0.0, 0.0, 0.0, 0.0, 18.0, 90000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'APPLE ABIA TAZE LOGISTICS SERVICES - Novacare Ltd - NL', 'Nos', 263.0, 397096.53, 0.0, 0.0, 44.0, 83833.64, 219.0, 313262.89, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Stores - NL', 'Nos', 4.0, 11200.0, 0.0, 0.0, 0.0, 0.0, 4.0, 11200.0, 2800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Stores - NL', 'Nos', 1556.0, 7780000.0, 0.0, 0.0, 105.0, 525000.0, 1451.0, 7255000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Stores - NL', 'Nos', 15597.0, 46791000.0, 26.0, 96500.0, 4320.0, 12960000.0, 11303.0, 33927500.0, 3001.637, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Stores - NL', 'Nos', 930.0, 1860000.0, 0.0, 0.0, 0.0, 0.0, 930.0, 1860000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Stores - NL', 'Nos', 6375.0, 22312500.0, 0.0, 0.0, 40.0, 140000.0, 6335.0, 22172500.0, 3500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Hezekiah Victor Adesanmi Logistics - Novacare Ltd - NL', 'Nos', 60.0, 300000.0, 0.0, 0.0, 0.0, 0.0, 60.0, 300000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Ezekiel Ameh Logistics - Novacare Ltd - NL', 'Nos', 13.0, 26000.0, 0.0, 0.0, 0.0, 0.0, 13.0, 26000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Olagunju Damilola Logistics - Novacare Ltd - NL', 'Nos', 23.0, 115000.0, 0.0, 0.0, 2.0, 10000.0, 21.0, 105000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Olagunju Damilola Logistics - Novacare Ltd - NL', 'Nos', 328.0, 630868.72, 0.0, 0.0, 176.0, 341261.6, 152.0, 289607.12, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Olagunju Damilola Logistics - Novacare Ltd - NL', 'Nos', 34.0, 91580.7, 0.0, 0.0, 0.0, 0.0, 34.0, 91580.7, 2693.55, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'TEMIBASH LOGISTICS LOGISTICS - Novacare Ltd - NL', 'Nos', 28.0, 70000.0, 0.0, 0.0, 0.0, 0.0, 28.0, 70000.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Emmanuel Olapeju Awoyemi Logistics - Novacare Ltd - NL', 'Nos', 20.0, 40000.0, 0.0, 0.0, 0.0, 0.0, 20.0, 40000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'APPLE ANAMBRA DELIVERY SERVICES - Novacare Ltd - NL', 'Nos', 271.0, 526849.6, 0.0, 0.0, 0.0, 0.0, 271.0, 526849.6, 1944.094, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'George O.O LOGISTICS - Novacare Ltd - NL', 'Nos', 22.0, 61600.0, 0.0, 0.0, 0.0, 0.0, 22.0, 61600.0, 2800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'RAFH EXPRESS LOGISTICS ABUJA - Novacare Ltd - NL', 'Nos', 468.0, 909347.2, 0.0, 0.0, 0.0, 0.0, 468.0, 909347.2, 1943.05, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Raphael Michael Logistics - Novacare Ltd - NL', 'Nos', 479.0, 1413050.0, 320.0, 960000.0, 47.0, 138650.0, 752.0, 2234400.0, 2971.277, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'APPLE ANAMBRA DELIVERY SERVICES - Novacare Ltd - NL', 'Nos', 14.0, 28000.0, 0.0, 0.0, 0.0, 0.0, 14.0, 28000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Akanimo Edet Akpan Logistics - Novacare Ltd - NL', 'Nos', 76.0, 380000.0, 0.0, 0.0, 0.0, 0.0, 76.0, 380000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Hambolu babatunde philips Logistics - Novacare Ltd - NL', 'Nos', 112.0, 440000.0, 0.0, 0.0, 6.0, 30000.0, 106.0, 410000.0, 3867.925, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Olaseni Adewumi James Logistics - Novacare Ltd - NL', 'Nos', 70.0, 189000.0, 0.0, 0.0, 0.0, 0.0, 70.0, 189000.0, 2700.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Chidi Godstime Egege Logistics - Novacare Ltd - NL', 'Nos', 51.0, 255000.0, 0.0, 0.0, 3.0, 15000.0, 48.0, 240000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'smart logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 12.0, 60000.0, 0.0, 0.0, 0.0, 0.0, 12.0, 60000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Raphael Michael Logistics - Novacare Ltd - NL', 'Nos', 122.0, 550000.0, 0.0, 0.0, 0.0, 0.0, 122.0, 550000.0, 4508.197, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Raphael Michael Logistics - Novacare Ltd - NL', 'Nos', 19.0, 38000.0, 0.0, 0.0, 0.0, 0.0, 19.0, 38000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Tajudeen A Ayetigbo LOGISTICS - Novacare Ltd - NL', 'Nos', 8.0, 16000.0, 0.0, 0.0, 0.0, 0.0, 8.0, 16000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Sheriff Adesola Raifu Logistics - Novacare Ltd - NL', 'Nos', 28.0, 101232.88, 0.0, 0.0, 0.0, 0.0, 28.0, 101232.88, 3615.46, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Velocitŕ logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 349.0, 1045550.0, 0.0, 0.0, 49.0, 145550.0, 300.0, 900000.0, 3000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Smart move Logistics Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 13.0, 23400.0, 0.0, 0.0, 0.0, 0.0, 13.0, 23400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Toheeb Biola Popoola Logistics - Novacare Ltd - NL', 'Nos', 27.0, 135000.0, 0.0, 0.0, 0.0, 0.0, 27.0, 135000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Alatiya Absalom Emmanuel Logistics - Novacare Ltd - NL', 'Nos', 43.0, 215000.0, 0.0, 0.0, 1.0, 5000.0, 42.0, 210000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'GINIKA ANAMBRA - Novacare Ltd - NL', 'Nos', 17.0, 34000.0, 0.0, 0.0, 0.0, 0.0, 17.0, 34000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Olawale Olusola Logistics - Novacare Ltd - NL', 'Nos', 183.0, 547850.0, 0.0, 0.0, 34.0, 100850.0, 149.0, 447000.0, 3000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Arinze Esther Logistics - Novacare Ltd - NL', 'Nos', 37.0, 185000.0, 0.0, 0.0, 0.0, 0.0, 37.0, 185000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'HOG logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 24.0, 120000.0, 0.0, 0.0, 2.0, 10000.0, 22.0, 110000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Victor Ogbenyi Logistics - Novacare Ltd - NL', 'Nos', 19.0, 38000.0, 0.0, 0.0, 0.0, 0.0, 19.0, 38000.0, 2000.0, 0.0, 'Novacare Ltd')
ON CONFLICT (client_id, item_code, warehouse) DO UPDATE SET
    opening_qty = EXCLUDED.opening_qty,
    opening_value = EXCLUDED.opening_value,
    in_qty = EXCLUDED.in_qty,
    in_value = EXCLUDED.in_value,
    out_qty = EXCLUDED.out_qty,
    out_value = EXCLUDED.out_value,
    balance_qty = EXCLUDED.balance_qty,
    balance_value = EXCLUDED.balance_value,
    valuation_rate = EXCLUDED.valuation_rate,
    reserved_stock = EXCLUDED.reserved_stock,
    updated_at = NOW();


INSERT INTO public.client_stock_balances (
    client_id, item_code, item_name, item_group, warehouse, stock_uom,
    opening_qty, opening_value, in_qty, in_value, out_qty, out_value,
    balance_qty, balance_value, valuation_rate, reserved_stock, company
) VALUES
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Victor Ogbenyi Logistics - Novacare Ltd - NL', 'Nos', 26.0, 100588.25, 0.0, 0.0, 1.0, 5000.0, 25.0, 95588.25, 3823.53, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'APPLE ABIA TAZE LOGISTICS SERVICES - Novacare Ltd - NL', 'Nos', 26.0, 65000.0, 0.0, 0.0, 0.0, 0.0, 26.0, 65000.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'APPLE ABIA TAZE LOGISTICS SERVICES - Novacare Ltd - NL', 'Nos', 65.0, 325000.0, 0.0, 0.0, 0.0, 0.0, 65.0, 325000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'APPLE ABIA TAZE LOGISTICS SERVICES - Novacare Ltd - NL', 'Nos', 151.0, 302000.0, 0.0, 0.0, 13.0, 26000.0, 138.0, 276000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'APPLE ABIA TAZE LOGISTICS SERVICES - Novacare Ltd - NL', 'Nos', 17.0, 34000.0, 0.0, 0.0, 0.0, 0.0, 17.0, 34000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'APPLE ABIA TAZE LOGISTICS SERVICES - Novacare Ltd - NL', 'Nos', 11.0, 19800.0, 0.0, 0.0, 0.0, 0.0, 11.0, 19800.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'APPLE ABIA TAZE LOGISTICS SERVICES - Novacare Ltd - NL', 'Nos', 110.0, 550000.0, 0.0, 0.0, 0.0, 0.0, 110.0, 550000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Adekunle Logistic - Novacare Ltd - NL', 'Nos', 50.0, 250000.0, 0.0, 0.0, 1.0, 5000.0, 49.0, 245000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Adekunle Logistic - Novacare Ltd - NL', 'Nos', 93.0, 405000.0, 0.0, 0.0, 0.0, 0.0, 93.0, 405000.0, 4354.839, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'FLYMARK LOGISTICS KD - Novacare Ltd - NL', 'Nos', 307.0, 614000.0, 0.0, 0.0, 7.0, 14000.0, 300.0, 600000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Ibylogistics Limited LOGISTICS - Novacare Ltd - NL', 'Nos', 103.0, 257500.0, 0.0, 0.0, 0.0, 0.0, 103.0, 257500.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Efe Brendon Avwia Logistics - Novacare Ltd - NL', 'Nos', 10.0, 15000.0, 0.0, 0.0, 0.0, 0.0, 10.0, 15000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Ibylogistics Limited LOGISTICS - Novacare Ltd - NL', 'Nos', 309.0, 927000.0, 0.0, 0.0, 46.0, 138000.0, 263.0, 789000.0, 3000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'FOMAX PH. LOGISTICS - Novacare Ltd - NL', 'Nos', 50.0, 140000.0, 0.0, 0.0, 0.0, 0.0, 50.0, 140000.0, 2800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Hambolu babatunde philips Logistics - Novacare Ltd - NL', 'Nos', 1.0, 1800.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1800.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Okoli Nnaemeka Augustine Logistics - Novacare Ltd - NL', 'Nos', 69.0, 345000.0, 0.0, 0.0, 1.0, 5000.0, 68.0, 340000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Chidimma maryjane Iloegbunam Logistics - Novacare Ltd - NL', 'Nos', 4.0, 8000.0, 0.0, 0.0, 0.0, 0.0, 4.0, 8000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Omoga Victor Ohe-obe Logistics - Novacare Ltd - NL', 'Nos', 45.0, 225000.0, 0.0, 0.0, 0.0, 0.0, 45.0, 225000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Msuega Terlanga Japhet Logistics - Novacare Ltd - NL', 'Nos', 22.0, 110000.0, 0.0, 0.0, 0.0, 0.0, 22.0, 110000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'FOMAX PH. LOGISTICS - Novacare Ltd - NL', 'Nos', 448.0, 1048000.0, 0.0, 0.0, 15.0, 30000.0, 433.0, 1018000.0, 2351.039, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Anthony Ezekiel Logistics - Novacare Ltd - NL', 'Nos', 45.0, 225000.0, 0.0, 0.0, 0.0, 0.0, 45.0, 225000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Olagunju Damilola Logistics - Novacare Ltd - NL', 'Nos', 204.0, 609800.0, 0.0, 0.0, 124.0, 369800.0, 80.0, 240000.0, 3000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Olawale Olusola Logistics - Novacare Ltd - NL', 'Nos', 45.0, 81000.0, 0.0, 0.0, 0.0, 0.0, 45.0, 81000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'BLUE AMAZON LOGISTICS LTD LOGISTICS - Novacare Ltd - NL', 'Nos', 22.0, 55000.0, 0.0, 0.0, 0.0, 0.0, 22.0, 55000.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Okora Samaro Matthew LOGISTICS - Novacare Ltd - NL', 'Nos', 159.0, 318000.0, 0.0, 0.0, 0.0, 0.0, 159.0, 318000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'De Wealthz Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 40.0, 64000.0, 0.0, 0.0, 0.0, 0.0, 40.0, 64000.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Emmanuel Olapeju Awoyemi Logistics - Novacare Ltd - NL', 'Nos', 210.0, 619500.0, 0.0, 0.0, 0.0, 0.0, 210.0, 619500.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'APPLE ANAMBRA DELIVERY SERVICES - Novacare Ltd - NL', 'Nos', 23.0, 57500.0, 0.0, 0.0, 0.0, 0.0, 23.0, 57500.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Okora Samaro Matthew LOGISTICS - Novacare Ltd - NL', 'Nos', 43.0, 215000.0, 0.0, 0.0, 0.0, 0.0, 43.0, 215000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Akanimo Edet Akpan Logistics - Novacare Ltd - NL', 'Nos', 330.0, 989500.0, 0.0, 0.0, 45.0, 134500.0, 285.0, 855000.0, 3000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Olaseni Adewumi James Logistics - Novacare Ltd - NL', 'Nos', 178.0, 508000.0, 0.0, 0.0, 23.0, 50750.0, 155.0, 457250.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Olagunju Damilola Logistics - Novacare Ltd - NL', 'Nos', 47.0, 94000.0, 0.0, 0.0, 0.0, 0.0, 47.0, 94000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'KENNEDY OROWO EDEYE Logistics - Novacare Ltd - NL', 'Nos', 66.0, 132000.0, 0.0, 0.0, 0.0, 0.0, 66.0, 132000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Adeyemo Adeola LOGISTICS - Novacare Ltd - NL', 'Nos', 312.0, 624000.0, 0.0, 0.0, 0.0, 0.0, 312.0, 624000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'BLUE AMAZON LOGISTICS LTD LOGISTICS - Novacare Ltd - NL', 'Nos', 35.0, 175000.0, 0.0, 0.0, 0.0, 0.0, 35.0, 175000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Fomax logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 15.0, 37500.0, 0.0, 0.0, 0.0, 0.0, 15.0, 37500.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Express Logistics, Ebonyi LOGISTICS - Novacare Ltd - NL', 'Nos', 40.0, 200000.0, 0.0, 0.0, 0.0, 0.0, 40.0, 200000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Toheeb Biola Popoola Logistics - Novacare Ltd - NL', 'Nos', 210.0, 584975.0, 320.0, 960000.0, 67.0, 193981.73, 463.0, 1350993.27, 2917.912, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Hezekiah Victor Adesanmi Logistics - Novacare Ltd - NL', 'Nos', 28.0, 70000.0, 0.0, 0.0, 0.0, 0.0, 28.0, 70000.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'John Hamza shuaibu Logistics - Novacare Ltd - NL', 'Nos', 185.0, 805000.0, 40.0, 140000.0, 7.0, 35000.0, 218.0, 910000.0, 4174.312, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Anthony Ezekiel Logistics - Novacare Ltd - NL', 'Nos', 18.0, 45000.0, 0.0, 0.0, 0.0, 0.0, 18.0, 45000.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'George O.O LOGISTICS - Novacare Ltd - NL', 'Nos', 334.0, 980000.0, 0.0, 0.0, 21.0, 48650.0, 313.0, 931350.0, 2975.559, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Olufunke Babalola Logistics - Novacare Ltd - NL', 'Nos', 6.0, 12000.0, 0.0, 0.0, 0.0, 0.0, 6.0, 12000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Olufunke Babalola Logistics - Novacare Ltd - NL', 'Nos', 101.0, 505000.0, 0.0, 0.0, 0.0, 0.0, 101.0, 505000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Olagunju Damilola Logistics - Novacare Ltd - NL', 'Nos', 26.0, 130000.0, 0.0, 0.0, 0.0, 0.0, 26.0, 130000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'John Hamza shuaibu Logistics - Novacare Ltd - NL', 'Nos', 40.0, 80000.0, 0.0, 0.0, 0.0, 0.0, 40.0, 80000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Smart move Logistics Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 686.0, 2023700.0, 0.0, 0.0, 21.0, 61950.0, 665.0, 1961750.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Changfa Jesse David - Novacare Ltd - NL', 'Nos', 17.0, 42500.0, 0.0, 0.0, 0.0, 0.0, 17.0, 42500.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Olupona oluwaseyi Logistics - Novacare Ltd - NL', 'Nos', 1.0, 1248.99, 0.0, 0.0, 0.0, 0.0, 1.0, 1248.99, 1248.99, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Usiju Ladu Logistics - Novacare Ltd - NL', 'Nos', 21.0, 52500.0, 0.0, 0.0, 0.0, 0.0, 21.0, 52500.0, 2500.0, 0.0, 'Novacare Ltd')
ON CONFLICT (client_id, item_code, warehouse) DO UPDATE SET
    opening_qty = EXCLUDED.opening_qty,
    opening_value = EXCLUDED.opening_value,
    in_qty = EXCLUDED.in_qty,
    in_value = EXCLUDED.in_value,
    out_qty = EXCLUDED.out_qty,
    out_value = EXCLUDED.out_value,
    balance_qty = EXCLUDED.balance_qty,
    balance_value = EXCLUDED.balance_value,
    valuation_rate = EXCLUDED.valuation_rate,
    reserved_stock = EXCLUDED.reserved_stock,
    updated_at = NOW();


INSERT INTO public.client_stock_balances (
    client_id, item_code, item_name, item_group, warehouse, stock_uom,
    opening_qty, opening_value, in_qty, in_value, out_qty, out_value,
    balance_qty, balance_value, valuation_rate, reserved_stock, company
) VALUES
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'ADICHA LOGISTICS - Novacare Ltd - NL', 'Nos', 74.0, 207200.0, 0.0, 0.0, 0.0, 0.0, 74.0, 207200.0, 2800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'TEMIBASH LOGISTICS LOGISTICS - Novacare Ltd - NL', 'Nos', 77.0, 385000.0, 0.0, 0.0, 0.0, 0.0, 77.0, 385000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Adeyinka Ekundayo Isreal Logistics - Novacare Ltd - NL', 'Nos', 35.0, 175000.0, 0.0, 0.0, 0.0, 0.0, 35.0, 175000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Oluwadamilare Emmanuel Logistics - Novacare Ltd - NL', 'Nos', 23.0, 46000.0, 0.0, 0.0, 0.0, 0.0, 23.0, 46000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Usiju Ladu Logistics - Novacare Ltd - NL', 'Nos', 31.0, 155000.0, 0.0, 0.0, 0.0, 0.0, 31.0, 155000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Oluwadamilare Emmanuel Logistics - Novacare Ltd - NL', 'Nos', 41.0, 114800.0, 0.0, 0.0, 0.0, 0.0, 41.0, 114800.0, 2800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Yohanna Vanduna Logistics - Novacare Ltd - NL', 'Nos', 60.0, 120000.0, 0.0, 0.0, 0.0, 0.0, 60.0, 120000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Yohanna Vanduna Logistics - Novacare Ltd - NL', 'Nos', 6.0, 30000.0, 70.0, 350000.0, 0.0, 0.0, 76.0, 380000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Teekina kuroakegha Gbeneteh Logistics - Novacare Ltd - NL', 'Nos', 15.0, 30000.0, 0.0, 0.0, 0.0, 0.0, 15.0, 30000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'GINIKA ANAMBRA - Novacare Ltd - NL', 'Nos', 11.0, 22000.0, 0.0, 0.0, 0.0, 0.0, 11.0, 22000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Shittu Adebamke Yusuff Logistics - Novacare Ltd - NL', 'Nos', 33.0, 82500.0, 0.0, 0.0, 0.0, 0.0, 33.0, 82500.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Adeyemo Adeola LOGISTICS - Novacare Ltd - NL', 'Nos', 76.0, 224200.0, 0.0, 0.0, 0.0, 0.0, 76.0, 224200.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Usiju Ladu Logistics - Novacare Ltd - NL', 'Nos', 204.0, 601800.0, 0.0, 0.0, 10.0, 29500.0, 194.0, 572300.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Durojaiye Ilashe Joseph Logistics - Novacare Ltd - NL', 'Nos', 174.0, 513300.0, 160.0, 480000.0, 18.0, 53100.0, 316.0, 940200.0, 2975.316, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Yohanna Vanduna Logistics - Novacare Ltd - NL', 'Nos', 13.0, 26000.0, 0.0, 0.0, 0.0, 0.0, 13.0, 26000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Arinze Esther Logistics - Novacare Ltd - NL', 'Nos', 347.0, 1039650.0, 0.0, 0.0, 67.0, 199650.0, 280.0, 840000.0, 3000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Ibrahim Abdulrashid Logistics - Novacare Ltd - NL', 'Nos', 377.0, 914000.0, 0.0, 0.0, 6.0, 12000.0, 371.0, 902000.0, 2431.267, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Ibrahim Abdulrashid Logistics - Novacare Ltd - NL', 'Nos', 14.0, 42000.0, 0.0, 0.0, 0.0, 0.0, 14.0, 42000.0, 3000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Smart move Logistics Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 61.0, 305000.0, 0.0, 0.0, 0.0, 0.0, 61.0, 305000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Yohanna Vanduna Logistics - Novacare Ltd - NL', 'Nos', 25.0, 32500.0, 0.0, 0.0, 0.0, 0.0, 25.0, 32500.0, 1300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Emmanuel Nnamdi Ugwu Logistics - Novacare Ltd - NL', 'Nos', 151.0, 755000.0, 0.0, 0.0, 0.0, 0.0, 151.0, 755000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Ezekiel Ameh Logistics - Novacare Ltd - NL', 'Nos', 407.0, 1208650.0, 0.0, 0.0, 16.0, 47200.0, 391.0, 1161450.0, 2970.46, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Velocitŕ logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 16.0, 32000.0, 0.0, 0.0, 0.0, 0.0, 16.0, 32000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Abdulsalam Abubakar Logistics - Novacare Ltd - NL', 'Nos', 393.0, 1159350.0, 0.0, 0.0, 13.0, 38350.0, 380.0, 1121000.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Chidi Godstime Egege Logistics - Novacare Ltd - NL', 'Nos', 496.0, 2947200.0, 0.0, 0.0, 53.0, 156350.0, 443.0, 2790850.0, 6299.887, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Tajudeen A Ayetigbo LOGISTICS - Novacare Ltd - NL', 'Nos', 307.0, 913650.0, 0.0, 0.0, 9.0, 26550.0, 298.0, 887100.0, 2976.846, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Yohanna Vanduna Logistics - Novacare Ltd - NL', 'Nos', 359.0, 1037600.0, 0.0, 0.0, 9.0, 21600.0, 350.0, 1016000.0, 2902.857, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Efe Brendon Avwia Logistics - Novacare Ltd - NL', 'Nos', 487.0, 1448650.0, 0.0, 0.0, 81.0, 238950.0, 406.0, 1209700.0, 2989.409, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Durojaiye Ilashe Joseph Logistics - Novacare Ltd - NL', 'Nos', 32.0, 64000.0, 0.0, 0.0, 0.0, 0.0, 32.0, 64000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Olawale Olusola Logistics - Novacare Ltd - NL', 'Nos', 47.0, 114000.0, 0.0, 0.0, 0.0, 0.0, 47.0, 114000.0, 2425.532, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'HOG logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 266.0, 792700.0, 0.0, 0.0, 84.0, 247800.0, 182.0, 544900.0, 2993.956, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Durojaiye Ilashe Joseph Logistics - Novacare Ltd - NL', 'Nos', 8.0, 9991.92, 0.0, 0.0, 0.0, 0.0, 8.0, 9991.92, 1248.99, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Fomax logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 10.0, 20000.0, 0.0, 0.0, 0.0, 0.0, 10.0, 20000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Express Logistics, Ebonyi LOGISTICS - Novacare Ltd - NL', 'Nos', 13.0, 16236.87, 0.0, 0.0, 0.0, 0.0, 13.0, 16236.87, 1248.99, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Oluwadamilare Emmanuel Logistics - Novacare Ltd - NL', 'Nos', 165.0, 458084.55, 160.0, 480000.0, 43.0, 119379.61, 282.0, 818704.94, 2903.209, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Okolie Anthony ogorchukwu Logistics - Novacare Ltd - NL', 'Nos', 558.0, 1084054.5, 0.0, 0.0, 22.0, 42740.5, 536.0, 1041314.0, 1942.75, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Olaseni Adewumi James Logistics - Novacare Ltd - NL', 'Nos', 12.0, 14987.88, 0.0, 0.0, 0.0, 0.0, 12.0, 14987.88, 1248.99, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'De Wealthz Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 496.0, 946548.8, 0.0, 0.0, 26.0, 51053.1, 470.0, 895495.7, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'ATP Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 19.0, 38000.0, 0.0, 0.0, 0.0, 0.0, 19.0, 38000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Abu Momoh Logistics - Novacare Ltd - NL', 'Nos', 370.0, 892000.0, 0.0, 0.0, 0.0, 0.0, 370.0, 892000.0, 2410.811, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'TEMIBASH LOGISTICS LOGISTICS - Novacare Ltd - NL', 'Nos', 12.0, 15600.0, 0.0, 0.0, 0.0, 0.0, 12.0, 15600.0, 1300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Ibitoye adewale Logistics - Novacare Ltd - NL', 'Nos', 25.0, 125000.0, 0.0, 0.0, 0.0, 0.0, 25.0, 125000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Teekina kuroakegha Gbeneteh Logistics - Novacare Ltd - NL', 'Nos', 16.0, 19983.84, 0.0, 0.0, 0.0, 0.0, 16.0, 19983.84, 1248.99, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Msuega Terlanga Japhet Logistics - Novacare Ltd - NL', 'Nos', 266.0, 792700.0, 0.0, 0.0, 55.0, 162250.0, 211.0, 630450.0, 2987.915, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Raphael Michael Logistics - Novacare Ltd - NL', 'Nos', 37.0, 92500.0, 0.0, 0.0, 0.0, 0.0, 37.0, 92500.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Hezekiah Victor Adesanmi Logistics - Novacare Ltd - NL', 'Nos', 116.0, 342200.0, 0.0, 0.0, 0.0, 0.0, 116.0, 342200.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Adetola Sam Adewuyi LOGISTICS - Novacare Ltd - NL', 'Nos', 388.0, 1144600.0, 0.0, 0.0, 22.0, 64900.0, 366.0, 1079700.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Alatiya Absalom Emmanuel Logistics - Novacare Ltd - NL', 'Nos', 324.0, 3931800.0, 0.0, 0.0, 22.0, 398800.0, 302.0, 3533000.0, 11698.675, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Fomax logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 1266.0, 2684000.0, 0.0, 0.0, 112.0, 224000.0, 1154.0, 2460000.0, 2131.716, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'HOG logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 71.0, 295000.0, 0.0, 0.0, 0.0, 0.0, 71.0, 295000.0, 4154.93, 0.0, 'Novacare Ltd')
ON CONFLICT (client_id, item_code, warehouse) DO UPDATE SET
    opening_qty = EXCLUDED.opening_qty,
    opening_value = EXCLUDED.opening_value,
    in_qty = EXCLUDED.in_qty,
    in_value = EXCLUDED.in_value,
    out_qty = EXCLUDED.out_qty,
    out_value = EXCLUDED.out_value,
    balance_qty = EXCLUDED.balance_qty,
    balance_value = EXCLUDED.balance_value,
    valuation_rate = EXCLUDED.valuation_rate,
    reserved_stock = EXCLUDED.reserved_stock,
    updated_at = NOW();


INSERT INTO public.client_stock_balances (
    client_id, item_code, item_name, item_group, warehouse, stock_uom,
    opening_qty, opening_value, in_qty, in_value, out_qty, out_value,
    balance_qty, balance_value, valuation_rate, reserved_stock, company
) VALUES
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Emmanuel Nnamdi Ugwu Logistics - Novacare Ltd - NL', 'Nos', 14.0, 28000.0, 0.0, 0.0, 0.0, 0.0, 14.0, 28000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Olaseni Adewumi James Logistics - Novacare Ltd - NL', 'Nos', 64.0, 320000.0, 0.0, 0.0, 0.0, 0.0, 64.0, 320000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Okoli Nnaemeka Augustine Logistics - Novacare Ltd - NL', 'Nos', 532.0, 1569400.0, 0.0, 0.0, 122.0, 359900.0, 410.0, 1209500.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Etimbuk Gregory Logistics - Novacare Ltd - NL', 'Nos', 8.0, 24000.0, 0.0, 0.0, 0.0, 0.0, 8.0, 24000.0, 3000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'De Wealthz Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 9.0, 45000.0, 0.0, 0.0, 0.0, 0.0, 9.0, 45000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'FOMAX ASABA (DELTA) LOGISTICS - Novacare Ltd - NL', 'Nos', 209.0, 616550.0, 0.0, 0.0, 11.0, 32450.0, 198.0, 584100.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Msuega Terlanga Japhet Logistics - Novacare Ltd - NL', 'Nos', 12.0, 19200.0, 0.0, 0.0, 0.0, 0.0, 12.0, 19200.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'ADICHA LOGISTICS - Novacare Ltd - NL', 'Nos', 269.0, 801550.0, 0.0, 0.0, 41.0, 120950.0, 228.0, 680600.0, 2985.088, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'smart logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 14.0, 28000.0, 0.0, 0.0, 0.0, 0.0, 14.0, 28000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Ibylogistics Limited LOGISTICS - Novacare Ltd - NL', 'Nos', 22.0, 44000.0, 0.0, 0.0, 0.0, 0.0, 22.0, 44000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Sheriff Adesola Raifu Logistics - Novacare Ltd - NL', 'Nos', 34.0, 170000.0, 0.0, 0.0, 0.0, 0.0, 34.0, 170000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Sheriff Adesola Raifu Logistics - Novacare Ltd - NL', 'Nos', 15.0, 45000.0, 0.0, 0.0, 0.0, 0.0, 15.0, 45000.0, 3000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'PELICAN DELIVERY AND LOGISTICS SERVICES LOGISTICS - Novacare Ltd - NL', 'Nos', 24.0, 48000.0, 0.0, 0.0, 0.0, 0.0, 24.0, 48000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Chidi Godstime Egege Logistics - Novacare Ltd - NL', 'Nos', 29.0, 58000.0, 0.0, 0.0, 0.0, 0.0, 29.0, 58000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Enny logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 243.0, 716850.0, 320.0, 960000.0, 23.0, 67850.0, 540.0, 1609000.0, 2979.63, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Emmanuel Nnamdi Ugwu Logistics - Novacare Ltd - NL', 'Nos', 186.0, 548700.0, 0.0, 0.0, 5.0, 14750.0, 181.0, 533950.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Olupona oluwaseyi Logistics - Novacare Ltd - NL', 'Nos', 23.0, 57500.0, 0.0, 0.0, 0.0, 0.0, 23.0, 57500.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Smart move Logistics Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 14.0, 28000.0, 0.0, 0.0, 0.0, 0.0, 14.0, 28000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Olaseni Adewumi James Logistics - Novacare Ltd - NL', 'Nos', 12.0, 24000.0, 0.0, 0.0, 0.0, 0.0, 12.0, 24000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Efe Brendon Avwia Logistics - Novacare Ltd - NL', 'Nos', 8.0, 16000.0, 0.0, 0.0, 0.0, 0.0, 8.0, 16000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Efe Brendon Avwia Logistics - Novacare Ltd - NL', 'Nos', 22.0, 110000.0, 0.0, 0.0, 1.0, 5000.0, 21.0, 105000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Okolie Anthony ogorchukwu Logistics - Novacare Ltd - NL', 'Nos', 202.0, 595900.0, 0.0, 0.0, 10.0, 29500.0, 192.0, 566400.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Okolie Anthony ogorchukwu Logistics - Novacare Ltd - NL', 'Nos', 17.0, 34000.0, 0.0, 0.0, 0.0, 0.0, 17.0, 34000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'RAFH EXPRESS LOGISTICS ABUJA - Novacare Ltd - NL', 'Nos', 28.0, 70000.0, 0.0, 0.0, 0.0, 0.0, 28.0, 70000.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'TEMIBASH LOGISTICS LOGISTICS - Novacare Ltd - NL', 'Nos', 87.0, 435000.0, 0.0, 0.0, 0.0, 0.0, 87.0, 435000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Alatiya Absalom Emmanuel Logistics - Novacare Ltd - NL', 'Nos', 8.0, 16000.0, 0.0, 0.0, 0.0, 0.0, 8.0, 16000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Toheeb Biola Popoola Logistics - Novacare Ltd - NL', 'Nos', 8.0, 40000.0, 0.0, 0.0, 0.0, 0.0, 8.0, 40000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Sheriff Adesola Raifu Logistics - Novacare Ltd - NL', 'Nos', 252.0, 756000.0, 0.0, 0.0, 49.0, 147000.0, 203.0, 609000.0, 3000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Ibrahim Abdulrashid Logistics - Novacare Ltd - NL', 'Nos', 35.0, 87500.0, 0.0, 0.0, 0.0, 0.0, 35.0, 87500.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Enny logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 13.0, 279500.0, 0.0, 0.0, 0.0, 0.0, 13.0, 279500.0, 21500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'GINIKA ANAMBRA - Novacare Ltd - NL', 'Nos', 312.0, 936000.0, 0.0, 0.0, 20.0, 60000.0, 292.0, 876000.0, 3000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Ibrahim Abdulrashid Logistics - Novacare Ltd - NL', 'Nos', 26.0, 130000.0, 0.0, 0.0, 0.0, 0.0, 26.0, 130000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Express Logistics, Ebonyi LOGISTICS - Novacare Ltd - NL', 'Nos', 26.0, 52000.0, 0.0, 0.0, 0.0, 0.0, 26.0, 52000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Okoli Nnaemeka Augustine Logistics - Novacare Ltd - NL', 'Nos', 10.0, 20000.0, 0.0, 0.0, 0.0, 0.0, 10.0, 20000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Msuega Terlanga Japhet Logistics - Novacare Ltd - NL', 'Nos', 10.0, 20000.0, 0.0, 0.0, 0.0, 0.0, 10.0, 20000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'FOMAX PH. LOGISTICS - Novacare Ltd - NL', 'Nos', 23.0, 46000.0, 0.0, 0.0, 0.0, 0.0, 23.0, 46000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Okolie Anthony ogorchukwu Logistics - Novacare Ltd - NL', 'Nos', 42.0, 105000.0, 0.0, 0.0, 0.0, 0.0, 42.0, 105000.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Adetola Sam Adewuyi LOGISTICS - Novacare Ltd - NL', 'Nos', 14.0, 28000.0, 0.0, 0.0, 0.0, 0.0, 14.0, 28000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'TEMIBASH LOGISTICS LOGISTICS - Novacare Ltd - NL', 'Nos', 267.0, 795650.0, 0.0, 0.0, 21.0, 61950.0, 246.0, 733700.0, 2982.52, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'GINIKA ANAMBRA - Novacare Ltd - NL', 'Nos', 34.0, 170000.0, 0.0, 0.0, 1.0, 5000.0, 33.0, 165000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'HOG logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 14.0, 28000.0, 0.0, 0.0, 0.0, 0.0, 14.0, 28000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'RAFH EXPRESS LOGISTICS ABUJA - Novacare Ltd - NL', 'Nos', 167.0, 486000.0, 0.0, 0.0, 0.0, 0.0, 167.0, 486000.0, 2910.18, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'ATP Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 109.0, 545000.0, 0.0, 0.0, 0.0, 0.0, 109.0, 545000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'George O.O LOGISTICS - Novacare Ltd - NL', 'Nos', 65.0, 325000.0, 0.0, 0.0, 0.0, 0.0, 65.0, 325000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Hezekiah Victor Adesanmi Logistics - Novacare Ltd - NL', 'Nos', 47.0, 94000.0, 0.0, 0.0, 0.0, 0.0, 47.0, 94000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Anthony Ezekiel Logistics - Novacare Ltd - NL', 'Nos', 85.0, 425000.0, 0.0, 0.0, 0.0, 0.0, 85.0, 425000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Express Logistics, Ebonyi LOGISTICS - Novacare Ltd - NL', 'Nos', 197.0, 589150.0, 0.0, 0.0, 29.0, 85550.0, 168.0, 503600.0, 2997.619, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Okolie Anthony ogorchukwu Logistics - Novacare Ltd - NL', 'Nos', 10.0, 18000.0, 0.0, 0.0, 0.0, 0.0, 10.0, 18000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'ADICHA LOGISTICS - Novacare Ltd - NL', 'Nos', 37.0, 74000.0, 0.0, 0.0, 0.0, 0.0, 37.0, 74000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'ZIBRA & CO LTD LOGISTICS - Novacare Ltd - NL', 'Nos', 41.0, 205000.0, 0.0, 0.0, 0.0, 0.0, 41.0, 205000.0, 5000.0, 0.0, 'Novacare Ltd')
ON CONFLICT (client_id, item_code, warehouse) DO UPDATE SET
    opening_qty = EXCLUDED.opening_qty,
    opening_value = EXCLUDED.opening_value,
    in_qty = EXCLUDED.in_qty,
    in_value = EXCLUDED.in_value,
    out_qty = EXCLUDED.out_qty,
    out_value = EXCLUDED.out_value,
    balance_qty = EXCLUDED.balance_qty,
    balance_value = EXCLUDED.balance_value,
    valuation_rate = EXCLUDED.valuation_rate,
    reserved_stock = EXCLUDED.reserved_stock,
    updated_at = NOW();


INSERT INTO public.client_stock_balances (
    client_id, item_code, item_name, item_group, warehouse, stock_uom,
    opening_qty, opening_value, in_qty, in_value, out_qty, out_value,
    balance_qty, balance_value, valuation_rate, reserved_stock, company
) VALUES
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'George O.O LOGISTICS - Novacare Ltd - NL', 'Nos', 4.0, 8000.0, 0.0, 0.0, 0.0, 0.0, 4.0, 8000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'ZIBRA & CO LTD LOGISTICS - Novacare Ltd - NL', 'Nos', 47.0, 235000.0, 0.0, 0.0, 2.0, 10000.0, 45.0, 225000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Emmanuel Olapeju Awoyemi Logistics - Novacare Ltd - NL', 'Nos', 7.0, 9100.0, 0.0, 0.0, 0.0, 0.0, 7.0, 9100.0, 1300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Sheriff Adesola Raifu Logistics - Novacare Ltd - NL', 'Nos', 66.0, 377028.96, 0.0, 0.0, 1.0, 5712.56, 65.0, 371316.4, 5712.56, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Arinze Esther Logistics - Novacare Ltd - NL', 'Nos', 17.0, 47600.0, 0.0, 0.0, 0.0, 0.0, 17.0, 47600.0, 2800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'smart logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 289.0, 852550.0, 0.0, 0.0, 18.0, 53100.0, 271.0, 799450.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Toheeb Biola Popoola Logistics - Novacare Ltd - NL', 'Nos', 5.0, 6244.95, 0.0, 0.0, 0.0, 0.0, 5.0, 6244.95, 1248.99, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'John Hamza shuaibu Logistics - Novacare Ltd - NL', 'Nos', 1.0, 1248.99, 0.0, 0.0, 0.0, 0.0, 1.0, 1248.99, 1248.99, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Emmanuel Olapeju Awoyemi Logistics - Novacare Ltd - NL', 'Nos', 20.0, 36000.0, 0.0, 0.0, 0.0, 0.0, 20.0, 36000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Emmanuel Olapeju Awoyemi Logistics - Novacare Ltd - NL', 'Nos', 16.0, 80000.0, 0.0, 0.0, 0.0, 0.0, 16.0, 80000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Omoga Victor Ohe-obe Logistics - Novacare Ltd - NL', 'Nos', 27.0, 81000.0, 0.0, 0.0, 0.0, 0.0, 27.0, 81000.0, 3000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'FLYMARK LOGISTICS KD - Novacare Ltd - NL', 'Nos', 32.0, 160000.0, 0.0, 0.0, 0.0, 0.0, 32.0, 160000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Okolie Anthony ogorchukwu Logistics - Novacare Ltd - NL', 'Nos', 53.0, 265000.0, 0.0, 0.0, 0.0, 0.0, 53.0, 265000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Abdulsalam Abubakar Logistics - Novacare Ltd - NL', 'Nos', 9.0, 18000.0, 0.0, 0.0, 0.0, 0.0, 9.0, 18000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Ibrahim Abdulrashid Logistics - Novacare Ltd - NL', 'Nos', 38.0, 68400.0, 0.0, 0.0, 0.0, 0.0, 38.0, 68400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Ibrahim Abdulrashid Logistics - Novacare Ltd - NL', 'Nos', 123.0, 615000.0, 0.0, 0.0, 0.0, 0.0, 123.0, 615000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Akanimo Edet Akpan Logistics - Novacare Ltd - NL', 'Nos', 8.0, 12800.0, 0.0, 0.0, 0.0, 0.0, 8.0, 12800.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Akanimo Edet Akpan Logistics - Novacare Ltd - NL', 'Nos', 201.0, 1005000.0, 0.0, 0.0, 0.0, 0.0, 201.0, 1005000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Abu Momoh Logistics - Novacare Ltd - NL', 'Nos', 35.0, 93500.0, 0.0, 0.0, 0.0, 0.0, 35.0, 93500.0, 2671.429, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Abu Momoh Logistics - Novacare Ltd - NL', 'Nos', 74.0, 370000.0, 0.0, 0.0, 0.0, 0.0, 74.0, 370000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Abu Momoh Logistics - Novacare Ltd - NL', 'Nos', 39.0, 195000.0, 0.0, 0.0, 0.0, 0.0, 39.0, 195000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Yohanna Vanduna Logistics - Novacare Ltd - NL', 'Nos', 97.0, 485000.0, 0.0, 0.0, 0.0, 0.0, 97.0, 485000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'ATP Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 5.0, 6500.0, 0.0, 0.0, 0.0, 0.0, 5.0, 6500.0, 1300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Velocitŕ logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 37.0, 185000.0, 0.0, 0.0, 0.0, 0.0, 37.0, 185000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'YAYA JOB - Novacare Ltd - NL', 'Nos', 71.0, 355000.0, 0.0, 0.0, 0.0, 0.0, 71.0, 355000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'YAYA JOB - Novacare Ltd - NL', 'Nos', 56.0, 280000.0, 0.0, 0.0, 0.0, 0.0, 56.0, 280000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'YAYA JOB - Novacare Ltd - NL', 'Nos', 12.0, 24000.0, 0.0, 0.0, 0.0, 0.0, 12.0, 24000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'APPLE ANAMBRA DELIVERY SERVICES - Novacare Ltd - NL', 'Nos', 32.0, 160000.0, 0.0, 0.0, 0.0, 0.0, 32.0, 160000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'APPLE ANAMBRA DELIVERY SERVICES - Novacare Ltd - NL', 'Nos', 151.0, 445450.0, 0.0, 0.0, 1.0, 2950.0, 150.0, 442500.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'APPLE ANAMBRA DELIVERY SERVICES - Novacare Ltd - NL', 'Nos', 39.0, 195000.0, 0.0, 0.0, 0.0, 0.0, 39.0, 195000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'APPLE ANAMBRA DELIVERY SERVICES - Novacare Ltd - NL', 'Nos', 11.0, 22000.0, 0.0, 0.0, 0.0, 0.0, 11.0, 22000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'PELICAN DELIVERY AND LOGISTICS SERVICES LOGISTICS - Novacare Ltd - NL', 'Nos', 2.0, 2600.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2600.0, 1300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'PELICAN DELIVERY AND LOGISTICS SERVICES LOGISTICS - Novacare Ltd - NL', 'Nos', 89.0, 311500.0, 0.0, 0.0, 0.0, 0.0, 89.0, 311500.0, 3500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'GINIKA ANAMBRA - Novacare Ltd - NL', 'Nos', 33.0, 165000.0, 0.0, 0.0, 0.0, 0.0, 33.0, 165000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'BLUE AMAZON LOGISTICS LTD LOGISTICS - Novacare Ltd - NL', 'Nos', 75.0, 375000.0, 0.0, 0.0, 0.0, 0.0, 75.0, 375000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Chidi Godstime Egege Logistics - Novacare Ltd - NL', 'Nos', 127.0, 635000.0, 0.0, 0.0, 1.0, 5000.0, 126.0, 630000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Ibitoye adewale Logistics - Novacare Ltd - NL', 'Nos', 101.0, 505000.0, 0.0, 0.0, 0.0, 0.0, 101.0, 505000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Ezekiel Ameh Logistics - Novacare Ltd - NL', 'Nos', 23.0, 115000.0, 0.0, 0.0, 1.0, 5000.0, 22.0, 110000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'TRUST LOGISTICS PDA - Novacare Ltd - NL', 'Nos', 299.0, 582434.06, 0.0, 0.0, 1.0, 1947.94, 298.0, 580486.12, 1947.94, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'TRUST LOGISTICS PDA - Novacare Ltd - NL', 'Nos', 35.0, 87500.0, 0.0, 0.0, 0.0, 0.0, 35.0, 87500.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'TRUST LOGISTICS PDA - Novacare Ltd - NL', 'Nos', 13.0, 16900.0, 0.0, 0.0, 0.0, 0.0, 13.0, 16900.0, 1300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'TRUST LOGISTICS PDA - Novacare Ltd - NL', 'Nos', 24.0, 120000.0, 0.0, 0.0, 0.0, 0.0, 24.0, 120000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'TRUST LOGISTICS PDA - Novacare Ltd - NL', 'Nos', 145.0, 290000.0, 0.0, 0.0, 1.0, 2000.0, 144.0, 288000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'TRUST LOGISTICS PDA - Novacare Ltd - NL', 'Nos', 46.0, 230000.0, 0.0, 0.0, 0.0, 0.0, 46.0, 230000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'TRUST LOGISTICS PDA - Novacare Ltd - NL', 'Nos', 14.0, 28000.0, 0.0, 0.0, 0.0, 0.0, 14.0, 28000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Okolie Anthony ogorchukwu Logistics - Novacare Ltd - NL', 'Nos', 82.0, 287000.0, 0.0, 0.0, 0.0, 0.0, 82.0, 287000.0, 3500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Alatiya Absalom Emmanuel Logistics - Novacare Ltd - NL', 'Nos', 161.0, 745000.0, 0.0, 0.0, 0.0, 0.0, 161.0, 745000.0, 4627.329, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Olawale Olusola Logistics - Novacare Ltd - NL', 'Nos', 118.0, 590000.0, 0.0, 0.0, 0.0, 0.0, 118.0, 590000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Adetola Sam Adewuyi LOGISTICS - Novacare Ltd - NL', 'Nos', 102.0, 510000.0, 0.0, 0.0, 0.0, 0.0, 102.0, 510000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Abdulsalam Abubakar Logistics - Novacare Ltd - NL', 'Nos', 110.0, 550000.0, 0.0, 0.0, 0.0, 0.0, 110.0, 550000.0, 5000.0, 0.0, 'Novacare Ltd')
ON CONFLICT (client_id, item_code, warehouse) DO UPDATE SET
    opening_qty = EXCLUDED.opening_qty,
    opening_value = EXCLUDED.opening_value,
    in_qty = EXCLUDED.in_qty,
    in_value = EXCLUDED.in_value,
    out_qty = EXCLUDED.out_qty,
    out_value = EXCLUDED.out_value,
    balance_qty = EXCLUDED.balance_qty,
    balance_value = EXCLUDED.balance_value,
    valuation_rate = EXCLUDED.valuation_rate,
    reserved_stock = EXCLUDED.reserved_stock,
    updated_at = NOW();


INSERT INTO public.client_stock_balances (
    client_id, item_code, item_name, item_group, warehouse, stock_uom,
    opening_qty, opening_value, in_qty, in_value, out_qty, out_value,
    balance_qty, balance_value, valuation_rate, reserved_stock, company
) VALUES
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Fomax logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 3.0, 15000.0, 0.0, 0.0, 0.0, 0.0, 3.0, 15000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Msuega Terlanga Japhet Logistics - Novacare Ltd - NL', 'Nos', 97.0, 485000.0, 0.0, 0.0, 2.0, 10000.0, 95.0, 475000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Shittu Adebamke Yusuff Logistics - Novacare Ltd - NL', 'Nos', 10.0, 12489.9, 0.0, 0.0, 0.0, 0.0, 10.0, 12489.9, 1248.99, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Shittu Adebamke Yusuff Logistics - Novacare Ltd - NL', 'Nos', 64.0, 260000.0, 0.0, 0.0, 0.0, 0.0, 64.0, 260000.0, 4062.5, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Durojaiye Ilashe Joseph Logistics - Novacare Ltd - NL', 'Nos', 108.0, 540000.0, 0.0, 0.0, 0.0, 0.0, 108.0, 540000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Express Logistics, Ebonyi LOGISTICS - Novacare Ltd - NL', 'Nos', 85.0, 425000.0, 0.0, 0.0, 0.0, 0.0, 85.0, 425000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Usiju Ladu Logistics - Novacare Ltd - NL', 'Nos', 109.0, 545000.0, 0.0, 0.0, 0.0, 0.0, 109.0, 545000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Olupona oluwaseyi Logistics - Novacare Ltd - NL', 'Nos', 114.0, 570000.0, 0.0, 0.0, 0.0, 0.0, 114.0, 570000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Olupona oluwaseyi Logistics - Novacare Ltd - NL', 'Nos', 55.0, 110000.0, 0.0, 0.0, 0.0, 0.0, 55.0, 110000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'ADICHA LOGISTICS - Novacare Ltd - NL', 'Nos', 14.0, 70000.0, 0.0, 0.0, 0.0, 0.0, 14.0, 70000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Etimbuk Gregory Logistics - Novacare Ltd - NL', 'Nos', 66.0, 118800.0, 0.0, 0.0, 0.0, 0.0, 66.0, 118800.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Etimbuk Gregory Logistics - Novacare Ltd - NL', 'Nos', 15.0, 27000.0, 0.0, 0.0, 0.0, 0.0, 15.0, 27000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Etimbuk Gregory Logistics - Novacare Ltd - NL', 'Nos', 112.0, 560000.0, 0.0, 0.0, 0.0, 0.0, 112.0, 560000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'FOMAX PH. LOGISTICS - Novacare Ltd - NL', 'Nos', 19.0, 38000.0, 0.0, 0.0, 0.0, 0.0, 19.0, 38000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Adekunle Logistic - Novacare Ltd - NL', 'Nos', 19.0, 38000.0, 0.0, 0.0, 0.0, 0.0, 19.0, 38000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'TEMIBASH LOGISTICS LOGISTICS - Novacare Ltd - NL', 'Nos', 33.0, 66000.0, 0.0, 0.0, 0.0, 0.0, 33.0, 66000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Teekina kuroakegha Gbeneteh Logistics - Novacare Ltd - NL', 'Nos', 58.0, 290000.0, 0.0, 0.0, 0.0, 0.0, 58.0, 290000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'RAPH XPRESS LOGISTICS - Novacare Ltd - NL', 'Nos', 16.0, 20800.0, 0.0, 0.0, 0.0, 0.0, 16.0, 20800.0, 1300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Oluwadamilare Emmanuel Logistics - Novacare Ltd - NL', 'Nos', 90.0, 450000.0, 0.0, 0.0, 0.0, 0.0, 90.0, 450000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Toheeb Biola Popoola Logistics - Novacare Ltd - NL', 'Nos', 31.0, 62000.0, 0.0, 0.0, 0.0, 0.0, 31.0, 62000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Arinze Esther Logistics - Novacare Ltd - NL', 'Nos', 32.0, 160000.0, 0.0, 0.0, 0.0, 0.0, 32.0, 160000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Arinze Esther Logistics - Novacare Ltd - NL', 'Nos', 22.0, 44000.0, 0.0, 0.0, 0.0, 0.0, 22.0, 44000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Hezekiah Victor Adesanmi Logistics - Novacare Ltd - NL', 'Nos', 4.0, 4995.96, 0.0, 0.0, 0.0, 0.0, 4.0, 4995.96, 1248.99, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Hezekiah Victor Adesanmi Logistics - Novacare Ltd - NL', 'Nos', 55.0, 275000.0, 0.0, 0.0, 0.0, 0.0, 55.0, 275000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'FOMAX ASABA (DELTA) LOGISTICS - Novacare Ltd - NL', 'Nos', 13.0, 26000.0, 0.0, 0.0, 0.0, 0.0, 13.0, 26000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Okora Samaro Matthew LOGISTICS - Novacare Ltd - NL', 'Nos', 22.0, 55000.0, 0.0, 0.0, 0.0, 0.0, 22.0, 55000.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Okora Samaro Matthew LOGISTICS - Novacare Ltd - NL', 'Nos', 5.0, 6500.0, 0.0, 0.0, 0.0, 0.0, 5.0, 6500.0, 1300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Okora Samaro Matthew LOGISTICS - Novacare Ltd - NL', 'Nos', 14.0, 28000.0, 0.0, 0.0, 0.0, 0.0, 14.0, 28000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Okora Samaro Matthew LOGISTICS - Novacare Ltd - NL', 'Nos', 65.0, 325000.0, 0.0, 0.0, 0.0, 0.0, 65.0, 325000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Okora Samaro Matthew LOGISTICS - Novacare Ltd - NL', 'Nos', 11.0, 22000.0, 0.0, 0.0, 0.0, 0.0, 11.0, 22000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Tajudeen A Ayetigbo LOGISTICS - Novacare Ltd - NL', 'Nos', 122.0, 550000.0, 0.0, 0.0, 0.0, 0.0, 122.0, 550000.0, 4508.197, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'FOMAX ASABA (DELTA) LOGISTICS - Novacare Ltd - NL', 'Nos', 96.0, 480000.0, 0.0, 0.0, 0.0, 0.0, 96.0, 480000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'FOMAX ASABA (DELTA) LOGISTICS - Novacare Ltd - NL', 'Nos', 39.0, 195000.0, 0.0, 0.0, 0.0, 0.0, 39.0, 195000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'KENNEDY OROWO EDEYE Logistics - Novacare Ltd - NL', 'Nos', 66.0, 330000.0, 0.0, 0.0, 0.0, 0.0, 66.0, 330000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'smart logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 24.0, 120000.0, 0.0, 0.0, 0.0, 0.0, 24.0, 120000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'HOG logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 4.0, 5200.0, 0.0, 0.0, 0.0, 0.0, 4.0, 5200.0, 1300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'RAFH EXPRESS LOGISTICS ABUJA - Novacare Ltd - NL', 'Nos', 4.0, 5200.0, 0.0, 0.0, 0.0, 0.0, 4.0, 5200.0, 1300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'RAFH EXPRESS LOGISTICS ABUJA - Novacare Ltd - NL', 'Nos', 70.0, 245000.0, 0.0, 0.0, 0.0, 0.0, 70.0, 245000.0, 3500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'RAFH EXPRESS LOGISTICS ABUJA - Novacare Ltd - NL', 'Nos', 15.0, 30000.0, 0.0, 0.0, 0.0, 0.0, 15.0, 30000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Ibylogistics Limited LOGISTICS - Novacare Ltd - NL', 'Nos', 94.0, 470000.0, 0.0, 0.0, 0.0, 0.0, 94.0, 470000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Olagunju Damilola Logistics - Novacare Ltd - NL', 'Nos', 32.0, 57600.0, 0.0, 0.0, 0.0, 0.0, 32.0, 57600.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'FLYMARK LOGISTICS KD - Novacare Ltd - NL', 'Nos', 13.0, 26000.0, 0.0, 0.0, 0.0, 0.0, 13.0, 26000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'De Wealthz Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 605.0, 1808750.0, 0.0, 0.0, 17.0, 50150.0, 588.0, 1758600.0, 2990.816, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Enny logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 36.0, 180000.0, 35.0, 175000.0, 0.0, 0.0, 71.0, 355000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'DINO LOGISTICS - Novacare Ltd - NL', 'Nos', 921.0, 1770108.51, 0.0, 0.0, 0.0, 0.0, 921.0, 1770108.51, 1921.942, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'DINO LOGISTICS - Novacare Ltd - NL', 'Nos', 65.0, 182000.0, 0.0, 0.0, 0.0, 0.0, 65.0, 182000.0, 2800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Changfa Jesse David - Novacare Ltd - NL', 'Nos', 41.0, 205000.0, 0.0, 0.0, 0.0, 0.0, 41.0, 205000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'NOVA XPRESS ABUJA - Novacare Ltd - NL', 'Nos', 5336.0, 10227564.56, 0.0, 0.0, 301.0, 576929.71, 5035.0, 9650634.85, 1916.71, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'NOVA XPRESS ABUJA - Novacare Ltd - NL', 'Nos', 980.0, 2891000.0, 0.0, 0.0, 156.0, 460200.0, 824.0, 2430800.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'NOVA XPRESS ABUJA - Novacare Ltd - NL', 'Nos', 616.0, 3080000.0, 0.0, 0.0, 10.0, 50000.0, 606.0, 3030000.0, 5000.0, 0.0, 'Novacare Ltd')
ON CONFLICT (client_id, item_code, warehouse) DO UPDATE SET
    opening_qty = EXCLUDED.opening_qty,
    opening_value = EXCLUDED.opening_value,
    in_qty = EXCLUDED.in_qty,
    in_value = EXCLUDED.in_value,
    out_qty = EXCLUDED.out_qty,
    out_value = EXCLUDED.out_value,
    balance_qty = EXCLUDED.balance_qty,
    balance_value = EXCLUDED.balance_value,
    valuation_rate = EXCLUDED.valuation_rate,
    reserved_stock = EXCLUDED.reserved_stock,
    updated_at = NOW();


INSERT INTO public.client_stock_balances (
    client_id, item_code, item_name, item_group, warehouse, stock_uom,
    opening_qty, opening_value, in_qty, in_value, out_qty, out_value,
    balance_qty, balance_value, valuation_rate, reserved_stock, company
) VALUES
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'NOVA XPRESS ABUJA - Novacare Ltd - NL', 'Nos', 2.0, 5000.0, 0.0, 0.0, 0.0, 0.0, 2.0, 5000.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'NOVA XPRESS ABUJA - Novacare Ltd - NL', 'Nos', 200.0, 493000.0, 0.0, 0.0, 0.0, 0.0, 200.0, 493000.0, 2465.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'NOVA XPRESS ABUJA - Novacare Ltd - NL', 'Nos', 27.0, 54000.0, 0.0, 0.0, 6.0, 12000.0, 21.0, 42000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Emmanuel Nnamdi Ugwu Logistics - Novacare Ltd - NL', 'Nos', 34.0, 119000.0, 0.0, 0.0, 0.0, 0.0, 34.0, 119000.0, 3500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'DINO LOGISTICS - Novacare Ltd - NL', 'Nos', 235.0, 702000.0, 0.0, 0.0, 0.0, 0.0, 235.0, 702000.0, 2987.234, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Shittu Adebamke Yusuff Logistics - Novacare Ltd - NL', 'Nos', 192.0, 574400.0, 0.0, 0.0, 16.0, 47200.0, 176.0, 527200.0, 2995.455, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'BLUE AMAZON LOGISTICS LTD LOGISTICS - Novacare Ltd - NL', 'Nos', 221.0, 651950.0, 0.0, 0.0, 20.0, 59000.0, 201.0, 592950.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Adeyinka Ekundayo Isreal Logistics - Novacare Ltd - NL', 'Nos', 407.0, 1177567.16, 0.0, 0.0, 0.0, 0.0, 407.0, 1177567.16, 2893.285, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Ibitoye adewale Logistics - Novacare Ltd - NL', 'Nos', 175.0, 524250.0, 0.0, 0.0, 49.0, 146250.0, 126.0, 378000.0, 3000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'Usiju Ladu Logistics - Novacare Ltd - NL', 'Nos', 12.0, 36000.0, 0.0, 0.0, 0.0, 0.0, 12.0, 36000.0, 3000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Chidi Godstime Egege Logistics - Novacare Ltd - NL', 'Nos', 1.0, 1300.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1300.0, 1300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'De Wealthz Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 10.0, 18000.0, 0.0, 0.0, 0.0, 0.0, 10.0, 18000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Okoli Nnaemeka Augustine Logistics - Novacare Ltd - NL', 'Nos', 73.0, 365000.0, 0.0, 0.0, 0.0, 0.0, 73.0, 365000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Omoga Victor Ohe-obe Logistics - Novacare Ltd - NL', 'Nos', 8.0, 12800.0, 0.0, 0.0, 0.0, 0.0, 8.0, 12800.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'DASHGO DELIVERY CALABAR - Novacare Ltd - NL', 'Nos', 532.0, 1014217.72, 0.0, 0.0, 42.0, 80501.82, 490.0, 933715.9, 1905.543, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'DASHGO DELIVERY CALABAR - Novacare Ltd - NL', 'Nos', 306.0, 910700.0, 0.0, 0.0, 24.0, 70800.0, 282.0, 839900.0, 2978.369, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'DASHGO DELIVERY CALABAR - Novacare Ltd - NL', 'Nos', 24.0, 120000.0, 0.0, 0.0, 1.0, 5000.0, 23.0, 115000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'DASHGO DELIVERY CALABAR - Novacare Ltd - NL', 'Nos', 20.0, 50000.0, 0.0, 0.0, 0.0, 0.0, 20.0, 50000.0, 2500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'DASHGO DELIVERY CALABAR - Novacare Ltd - NL', 'Nos', 36.0, 126000.0, 0.0, 0.0, 0.0, 0.0, 36.0, 126000.0, 3500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Oluwadamilare Emmanuel Logistics - Novacare Ltd - NL', 'Nos', 24.0, 43200.0, 0.0, 0.0, 0.0, 0.0, 24.0, 43200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Olufunke Babalola Logistics - Novacare Ltd - NL', 'Nos', 12.0, 21600.0, 0.0, 0.0, 0.0, 0.0, 12.0, 21600.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'George O.O LOGISTICS - Novacare Ltd - NL', 'Nos', 5.0, 9000.0, 0.0, 0.0, 0.0, 0.0, 5.0, 9000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Stores - NL', 'Nos', 21.0, 35700.0, 0.0, 0.0, 0.0, 0.0, 21.0, 35700.0, 1700.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Stores - NL', 'Nos', 100.0, 179800.0, 0.0, 0.0, 0.0, 0.0, 100.0, 179800.0, 1798.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Efe Brendon Avwia Logistics - Novacare Ltd - NL', 'Nos', 10.0, 18000.0, 0.0, 0.0, 0.0, 0.0, 10.0, 18000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Arinze Esther Logistics - Novacare Ltd - NL', 'Nos', 9.0, 14400.0, 0.0, 0.0, 0.0, 0.0, 9.0, 14400.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'De Wealthz Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 25.0, 125000.0, 0.0, 0.0, 0.0, 0.0, 25.0, 125000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Tajudeen A Ayetigbo LOGISTICS - Novacare Ltd - NL', 'Nos', 15.0, 33000.0, 0.0, 0.0, 0.0, 0.0, 15.0, 33000.0, 2200.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'NOVA XPRESS ABUJA - Novacare Ltd - NL', 'Nos', 12.0, 21600.0, 0.0, 0.0, 0.0, 0.0, 12.0, 21600.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Yohanna Vanduna Logistics - Novacare Ltd - NL', 'Nos', 18.0, 39600.0, 0.0, 0.0, 0.0, 0.0, 18.0, 39600.0, 2200.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Alatiya Absalom Emmanuel Logistics - Novacare Ltd - NL', 'Nos', 28.0, 50400.0, 0.0, 0.0, 0.0, 0.0, 28.0, 50400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Victor Ogbenyi Logistics - Novacare Ltd - NL', 'Nos', 41.0, 73800.0, 0.0, 0.0, 0.0, 0.0, 41.0, 73800.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Sheriff Adesola Raifu Logistics - Novacare Ltd - NL', 'Nos', 18.0, 32400.0, 0.0, 0.0, 0.0, 0.0, 18.0, 32400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Chidi Godstime Egege Logistics - Novacare Ltd - NL', 'Nos', 13.0, 20800.0, 0.0, 0.0, 0.0, 0.0, 13.0, 20800.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Emmanuel Olapeju Awoyemi Logistics - Novacare Ltd - NL', 'Nos', 60.0, 300000.0, 0.0, 0.0, 0.0, 0.0, 60.0, 300000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Ibitoye adewale Logistics - Novacare Ltd - NL', 'Nos', 14.0, 25200.0, 0.0, 0.0, 0.0, 0.0, 14.0, 25200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Raphael Michael Logistics - Novacare Ltd - NL', 'Nos', 16.0, 28800.0, 0.0, 0.0, 0.0, 0.0, 16.0, 28800.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Chidimma maryjane Iloegbunam Logistics - Novacare Ltd - NL', 'Nos', 11.0, 17600.0, 0.0, 0.0, 0.0, 0.0, 11.0, 17600.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'DINO LOGISTICS - Novacare Ltd - NL', 'Nos', 35.0, 175000.0, 0.0, 0.0, 0.0, 0.0, 35.0, 175000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'DINO LOGISTICS - Novacare Ltd - NL', 'Nos', 74.0, 118400.0, 0.0, 0.0, 0.0, 0.0, 74.0, 118400.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'DINO LOGISTICS - Novacare Ltd - NL', 'Nos', 45.0, 225000.0, 0.0, 0.0, 0.0, 0.0, 45.0, 225000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Anthony Ezekiel Logistics - Novacare Ltd - NL', 'Nos', 30.0, 48000.0, 0.0, 0.0, 0.0, 0.0, 30.0, 48000.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'APPLE ABIA TAZE LOGISTICS SERVICES - Novacare Ltd - NL', 'Nos', 18.0, 32400.0, 0.0, 0.0, 0.0, 0.0, 18.0, 32400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Ibrahim Abdulrashid Logistics - Novacare Ltd - NL', 'Nos', 17.0, 27200.0, 0.0, 0.0, 0.0, 0.0, 17.0, 27200.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Adekunle Logistic - Novacare Ltd - NL', 'Nos', 7.0, 11200.0, 0.0, 0.0, 0.0, 0.0, 7.0, 11200.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Olawale Olusola Logistics - Novacare Ltd - NL', 'Nos', 18.0, 28800.0, 0.0, 0.0, 0.0, 0.0, 18.0, 28800.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Okolie Anthony ogorchukwu Logistics - Novacare Ltd - NL', 'Nos', 28.0, 44800.0, 0.0, 0.0, 0.0, 0.0, 28.0, 44800.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Shittu Adebamke Yusuff Logistics - Novacare Ltd - NL', 'Nos', 20.0, 32000.0, 0.0, 0.0, 0.0, 0.0, 20.0, 32000.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Akanimo Edet Akpan Logistics - Novacare Ltd - NL', 'Nos', 36.0, 57600.0, 0.0, 0.0, 0.0, 0.0, 36.0, 57600.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Usiju Ladu Logistics - Novacare Ltd - NL', 'Nos', 15.0, 24000.0, 0.0, 0.0, 0.0, 0.0, 15.0, 24000.0, 1600.0, 0.0, 'Novacare Ltd')
ON CONFLICT (client_id, item_code, warehouse) DO UPDATE SET
    opening_qty = EXCLUDED.opening_qty,
    opening_value = EXCLUDED.opening_value,
    in_qty = EXCLUDED.in_qty,
    in_value = EXCLUDED.in_value,
    out_qty = EXCLUDED.out_qty,
    out_value = EXCLUDED.out_value,
    balance_qty = EXCLUDED.balance_qty,
    balance_value = EXCLUDED.balance_value,
    valuation_rate = EXCLUDED.valuation_rate,
    reserved_stock = EXCLUDED.reserved_stock,
    updated_at = NOW();


INSERT INTO public.client_stock_balances (
    client_id, item_code, item_name, item_group, warehouse, stock_uom,
    opening_qty, opening_value, in_qty, in_value, out_qty, out_value,
    balance_qty, balance_value, valuation_rate, reserved_stock, company
) VALUES
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'HOG logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 28.0, 44800.0, 0.0, 0.0, 0.0, 0.0, 28.0, 44800.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Adetola Sam Adewuyi LOGISTICS - Novacare Ltd - NL', 'Nos', 24.0, 31200.0, 0.0, 0.0, 0.0, 0.0, 24.0, 31200.0, 1300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Ibylogistics Limited LOGISTICS - Novacare Ltd - NL', 'Nos', 7.0, 11200.0, 0.0, 0.0, 0.0, 0.0, 7.0, 11200.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Hambolu babatunde philips Logistics - Novacare Ltd - NL', 'Nos', 29.0, 46400.0, 0.0, 0.0, 0.0, 0.0, 29.0, 46400.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'KENNEDY OROWO EDEYE Logistics - Novacare Ltd - NL', 'Nos', 22.0, 35200.0, 0.0, 0.0, 0.0, 0.0, 22.0, 35200.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Ezekiel Ameh Logistics - Novacare Ltd - NL', 'Nos', 9.0, 14400.0, 0.0, 0.0, 0.0, 0.0, 9.0, 14400.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'TEMIBASH LOGISTICS LOGISTICS - Novacare Ltd - NL', 'Nos', 20.0, 32000.0, 0.0, 0.0, 0.0, 0.0, 20.0, 32000.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'smart logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 16.0, 25600.0, 0.0, 0.0, 0.0, 0.0, 16.0, 25600.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'John Hamza shuaibu Logistics - Novacare Ltd - NL', 'Nos', 20.0, 32000.0, 0.0, 0.0, 0.0, 0.0, 20.0, 32000.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Stores - NL', 'Nos', 3543.0, 6908850.0, 0.0, 0.0, 480.0, 936000.0, 3063.0, 5972850.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Stores - NL', 'Nos', -349.0, -802700.0, 0.0, 0.0, 30.0, 69000.0, -379.0, -871700.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'NOVA XPRESS ABUJA - Novacare Ltd - NL', 'Nos', -220.0, -429000.0, 0.0, 0.0, 84.0, 163800.0, -304.0, -592800.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'NOVA XPRESS ABUJA - Novacare Ltd - NL', 'Nos', 18.0, 35100.0, 0.0, 0.0, 3.0, 5850.0, 15.0, 29250.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Smart move Logistics Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 18.0, 28800.0, 0.0, 0.0, 0.0, 0.0, 18.0, 28800.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'NOVA XPRESS ABUJA - Novacare Ltd - NL', 'Nos', 11.0, 17600.0, 0.0, 0.0, 0.0, 0.0, 11.0, 17600.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'RAPH XPRESS LOGISTICS - Novacare Ltd - NL', 'Nos', 149.0, 290550.0, 0.0, 0.0, 55.0, 107250.0, 94.0, 183300.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'RAPH XPRESS LOGISTICS - Novacare Ltd - NL', 'Nos', 49.0, 107800.0, 0.0, 0.0, 1.0, 1950.0, 48.0, 105850.0, 2205.208, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'John Hamza shuaibu Logistics - Novacare Ltd - NL', 'Nos', 109.0, 212550.0, 250.0, 487500.0, 106.0, 206700.0, 253.0, 493350.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'John Hamza shuaibu Logistics - Novacare Ltd - NL', 'Nos', 26.0, 59800.0, 30.0, 69000.0, 11.0, 25300.0, 45.0, 103500.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Oluwadamilare Emmanuel Logistics - Novacare Ltd - NL', 'Nos', 35.0, 71750.0, 0.0, 0.0, 0.0, 0.0, 35.0, 71750.0, 2050.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Oluwadamilare Emmanuel Logistics - Novacare Ltd - NL', 'Nos', 0.0, 0.0, 80.0, 156000.0, 11.0, 21450.0, 69.0, 134550.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Hambolu babatunde philips Logistics - Novacare Ltd - NL', 'Nos', 28.0, 54600.0, 0.0, 0.0, 81.0, 157950.0, -53.0, -103350.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Hambolu babatunde philips Logistics - Novacare Ltd - NL', 'Nos', 44.0, 101200.0, 0.0, 0.0, 4.0, 9200.0, 40.0, 92000.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Velocitŕ logistics LOGISTICS - Novacare Ltd - NL', 'Nos', -9.0, -17550.0, 0.0, 0.0, 45.0, 87750.0, -54.0, -105300.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Velocitŕ logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 36.0, 82800.0, 0.0, 0.0, 1.0, 2300.0, 35.0, 80500.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Victor Ogbenyi Logistics - Novacare Ltd - NL', 'Nos', 7.0, 13650.0, 0.0, 0.0, 44.0, 85800.0, -37.0, -72150.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Victor Ogbenyi Logistics - Novacare Ltd - NL', 'Nos', 33.0, 75900.0, 0.0, 0.0, 0.0, 0.0, 33.0, 75900.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'FOMAX ASABA (DELTA) LOGISTICS - Novacare Ltd - NL', 'Nos', 45.0, 87750.0, 0.0, 0.0, 21.0, 40950.0, 24.0, 46800.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'FOMAX ASABA (DELTA) LOGISTICS - Novacare Ltd - NL', 'Nos', 21.0, 48300.0, 0.0, 0.0, 1.0, 2300.0, 20.0, 46000.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'FOMAX PH. LOGISTICS - Novacare Ltd - NL', 'Nos', -35.0, -68250.0, 0.0, 0.0, 43.0, 83850.0, -78.0, -152100.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'FOMAX PH. LOGISTICS - Novacare Ltd - NL', 'Nos', 21.0, 48300.0, 0.0, 0.0, 3.0, 6900.0, 18.0, 41400.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'DINO LOGISTICS - Novacare Ltd - NL', 'Nos', 8.0, 24000.0, 0.0, 0.0, 0.0, 0.0, 8.0, 24000.0, 3000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'BLUE AMAZON LOGISTICS LTD LOGISTICS - Novacare Ltd - NL', 'Nos', 20.0, 32000.0, 0.0, 0.0, 0.0, 0.0, 20.0, 32000.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Omoga Victor Ohe-obe Logistics - Novacare Ltd - NL', 'Nos', 67.0, 234500.0, 0.0, 0.0, 0.0, 0.0, 67.0, 234500.0, 3500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Omoga Victor Ohe-obe Logistics - Novacare Ltd - NL', 'Nos', 35.0, 63000.0, 0.0, 0.0, 0.0, 0.0, 35.0, 63000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Changfa Jesse David - Novacare Ltd - NL', 'Nos', 18.0, 28800.0, 0.0, 0.0, 0.0, 0.0, 18.0, 28800.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Stores - NL', 'Nos', 105.0, 210000.0, 3.0, 6000.0, 30.0, 60000.0, 78.0, 156000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Stores - NL', 'Nos', 234.0, 421200.0, 4.0, 7200.0, 100.0, 180000.0, 138.0, 248400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Sheriff Adesola Raifu Logistics - Novacare Ltd - NL', 'Nos', 24.0, 48000.0, 0.0, 0.0, 6.0, 12000.0, 18.0, 36000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Sheriff Adesola Raifu Logistics - Novacare Ltd - NL', 'Nos', 32.0, 57600.0, 0.0, 0.0, 9.0, 16200.0, 23.0, 41400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Enny logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 42.0, 84000.0, 0.0, 0.0, 4.0, 8000.0, 38.0, 76000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Enny logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 29.0, 52200.0, 20.0, 36000.0, 22.0, 39600.0, 27.0, 48600.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Velocitŕ logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 38.0, 68400.0, 0.0, 0.0, 14.0, 25200.0, 24.0, 43200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Abdulsalam Abubakar Logistics - Novacare Ltd - NL', 'Nos', 11.0, 22000.0, 0.0, 0.0, 9.0, 18000.0, 2.0, 4000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Abdulsalam Abubakar Logistics - Novacare Ltd - NL', 'Nos', 14.0, 25200.0, 0.0, 0.0, 7.0, 12600.0, 7.0, 12600.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Fomax logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 60.0, 108000.0, 0.0, 0.0, 21.0, 37800.0, 39.0, 70200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Fomax logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 76.0, 152000.0, 0.0, 0.0, 30.0, 60000.0, 46.0, 92000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Hambolu babatunde philips Logistics - Novacare Ltd - NL', 'Nos', 13.0, 23400.0, 0.0, 0.0, 7.0, 12600.0, 6.0, 10800.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Hambolu babatunde philips Logistics - Novacare Ltd - NL', 'Nos', 15.0, 30000.0, 0.0, 0.0, 7.0, 14000.0, 8.0, 16000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Hezekiah Victor Adesanmi Logistics - Novacare Ltd - NL', 'Nos', 39.0, 78000.0, 0.0, 0.0, 0.0, 0.0, 39.0, 78000.0, 2000.0, 0.0, 'Novacare Ltd')
ON CONFLICT (client_id, item_code, warehouse) DO UPDATE SET
    opening_qty = EXCLUDED.opening_qty,
    opening_value = EXCLUDED.opening_value,
    in_qty = EXCLUDED.in_qty,
    in_value = EXCLUDED.in_value,
    out_qty = EXCLUDED.out_qty,
    out_value = EXCLUDED.out_value,
    balance_qty = EXCLUDED.balance_qty,
    balance_value = EXCLUDED.balance_value,
    valuation_rate = EXCLUDED.valuation_rate,
    reserved_stock = EXCLUDED.reserved_stock,
    updated_at = NOW();


INSERT INTO public.client_stock_balances (
    client_id, item_code, item_name, item_group, warehouse, stock_uom,
    opening_qty, opening_value, in_qty, in_value, out_qty, out_value,
    balance_qty, balance_value, valuation_rate, reserved_stock, company
) VALUES
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Hezekiah Victor Adesanmi Logistics - Novacare Ltd - NL', 'Nos', 33.0, 59400.0, 0.0, 0.0, 0.0, 0.0, 33.0, 59400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Durojaiye Ilashe Joseph Logistics - Novacare Ltd - NL', 'Nos', 63.0, 113400.0, 0.0, 0.0, 2.0, 3600.0, 61.0, 109800.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Durojaiye Ilashe Joseph Logistics - Novacare Ltd - NL', 'Nos', 59.0, 118000.0, 0.0, 0.0, 4.0, 8000.0, 55.0, 110000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Chidimma maryjane Iloegbunam Logistics - Novacare Ltd - NL', 'Nos', 64.0, 128000.0, 0.0, 0.0, 0.0, 0.0, 64.0, 128000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Chidimma maryjane Iloegbunam Logistics - Novacare Ltd - NL', 'Nos', 26.0, 46800.0, 0.0, 0.0, 0.0, 0.0, 26.0, 46800.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Ibrahim Abdulrashid Logistics - Novacare Ltd - NL', 'Nos', 16.0, 32000.0, 0.0, 0.0, 1.0, 2000.0, 15.0, 30000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Ibrahim Abdulrashid Logistics - Novacare Ltd - NL', 'Nos', 11.0, 19800.0, 0.0, 0.0, 1.0, 1800.0, 10.0, 18000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Omoga Victor Ohe-obe Logistics - Novacare Ltd - NL', 'Nos', 22.0, 44000.0, 0.0, 0.0, 10.0, 20000.0, 12.0, 24000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Omoga Victor Ohe-obe Logistics - Novacare Ltd - NL', 'Nos', 12.0, 21600.0, 0.0, 0.0, 8.0, 14400.0, 4.0, 7200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Olagunju Damilola Logistics - Novacare Ltd - NL', 'Nos', 19.0, 38000.0, 0.0, 0.0, 9.0, 18000.0, 10.0, 20000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Olagunju Damilola Logistics - Novacare Ltd - NL', 'Nos', 26.0, 46800.0, 0.0, 0.0, 12.0, 21600.0, 14.0, 25200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Abu Momoh Logistics - Novacare Ltd - NL', 'Nos', 56.0, 112000.0, 0.0, 0.0, 0.0, 0.0, 56.0, 112000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Abu Momoh Logistics - Novacare Ltd - NL', 'Nos', 53.0, 95400.0, 0.0, 0.0, 0.0, 0.0, 53.0, 95400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'John Hamza shuaibu Logistics - Novacare Ltd - NL', 'Nos', 36.0, 64800.0, 0.0, 0.0, 17.0, 30600.0, 19.0, 34200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'John Hamza shuaibu Logistics - Novacare Ltd - NL', 'Nos', 63.0, 126000.0, 0.0, 0.0, 60.0, 120000.0, 3.0, 6000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Express Logistics, Ebonyi LOGISTICS - Novacare Ltd - NL', 'Nos', 49.0, 88200.0, 0.0, 0.0, 1.0, 1800.0, 48.0, 86400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Express Logistics, Ebonyi LOGISTICS - Novacare Ltd - NL', 'Nos', 55.0, 110000.0, 0.0, 0.0, 4.0, 8000.0, 51.0, 102000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Oluwadamilare Emmanuel Logistics - Novacare Ltd - NL', 'Nos', 33.0, 59400.0, 0.0, 0.0, 4.0, 7200.0, 29.0, 52200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'ADICHA LOGISTICS - Novacare Ltd - NL', 'Nos', 11.0, 19800.0, 0.0, 0.0, 2.0, 3600.0, 9.0, 16200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'ADICHA LOGISTICS - Novacare Ltd - NL', 'Nos', 6.0, 12000.0, 0.0, 0.0, 8.0, 16000.0, -2.0, -4000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Changfa Jesse David - Novacare Ltd - NL', 'Nos', 16.0, 28800.0, 0.0, 0.0, 0.0, 0.0, 16.0, 28800.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Changfa Jesse David - Novacare Ltd - NL', 'Nos', 2.0, 4000.0, 0.0, 0.0, 0.0, 0.0, 2.0, 4000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Okoli Nnaemeka Augustine Logistics - Novacare Ltd - NL', 'Nos', 31.0, 56833.23, 0.0, 0.0, 14.0, 25666.62, 17.0, 31166.61, 1833.33, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Okoli Nnaemeka Augustine Logistics - Novacare Ltd - NL', 'Nos', 15.0, 30000.0, 0.0, 0.0, 11.0, 22000.0, 4.0, 8000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'ZIBRA & CO LTD LOGISTICS - Novacare Ltd - NL', 'Nos', 16.0, 28800.0, 0.0, 0.0, 9.0, 16200.0, 7.0, 12600.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'ZIBRA & CO LTD LOGISTICS - Novacare Ltd - NL', 'Nos', 7.0, 14000.0, 0.0, 0.0, 11.0, 22000.0, -4.0, -8000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Arinze Esther Logistics - Novacare Ltd - NL', 'Nos', 22.0, 39600.0, 0.0, 0.0, 1.0, 1800.0, 21.0, 37800.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Arinze Esther Logistics - Novacare Ltd - NL', 'Nos', 30.0, 60000.0, 0.0, 0.0, 5.0, 10000.0, 25.0, 50000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Ola Cash - Novacare Ltd - NL', 'Nos', 19.0, 34200.0, 0.0, 0.0, 10.0, 18000.0, 9.0, 16200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Ola Cash - Novacare Ltd - NL', 'Nos', 20.0, 40000.0, 0.0, 0.0, 1.0, 2000.0, 19.0, 38000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Adekunle Logistic - Novacare Ltd - NL', 'Nos', 34.0, 68000.0, 0.0, 0.0, 3.0, 6000.0, 31.0, 62000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Adekunle Logistic - Novacare Ltd - NL', 'Nos', 43.0, 77400.0, 0.0, 0.0, 3.0, 5400.0, 40.0, 72000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Ibitoye adewale Logistics - Novacare Ltd - NL', 'Nos', 42.0, 84000.0, 0.0, 0.0, 19.0, 38000.0, 23.0, 46000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Ibitoye adewale Logistics - Novacare Ltd - NL', 'Nos', 34.0, 61200.0, 0.0, 0.0, 21.0, 37800.0, 13.0, 23400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Chidi Godstime Egege Logistics - Novacare Ltd - NL', 'Nos', 22.0, 44000.0, 0.0, 0.0, 15.0, 30000.0, 7.0, 14000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Chidi Godstime Egege Logistics - Novacare Ltd - NL', 'Nos', 39.0, 70200.0, 0.0, 0.0, 6.0, 10800.0, 33.0, 59400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Olufunke Babalola Logistics - Novacare Ltd - NL', 'Nos', 40.0, 80000.0, 0.0, 0.0, 3.0, 6000.0, 37.0, 74000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Olufunke Babalola Logistics - Novacare Ltd - NL', 'Nos', 34.0, 61200.0, 0.0, 0.0, 5.0, 9000.0, 29.0, 52200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Raphael Michael Logistics - Novacare Ltd - NL', 'Nos', 51.0, 102000.0, 30.0, 60000.0, 12.0, 24000.0, 69.0, 138000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Raphael Michael Logistics - Novacare Ltd - NL', 'Nos', 36.0, 64800.0, 30.0, 54000.0, 14.0, 25200.0, 52.0, 93600.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'HOG logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 2.0, 4000.0, 0.0, 0.0, 0.0, 0.0, 2.0, 4000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'HOG logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 17.0, 31224.41, 0.0, 0.0, 7.0, 12857.11, 10.0, 18367.3, 1836.73, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Akanimo Edet Akpan Logistics - Novacare Ltd - NL', 'Nos', 50.0, 90000.0, 0.0, 0.0, 0.0, 0.0, 50.0, 90000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Akanimo Edet Akpan Logistics - Novacare Ltd - NL', 'Nos', 27.0, 54000.0, 0.0, 0.0, 1.0, 2000.0, 26.0, 52000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Olaseni Adewumi James Logistics - Novacare Ltd - NL', 'Nos', 41.0, 73800.0, 0.0, 0.0, 5.0, 9000.0, 36.0, 64800.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Olaseni Adewumi James Logistics - Novacare Ltd - NL', 'Nos', 44.0, 88000.0, 0.0, 0.0, 3.0, 6000.0, 41.0, 82000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Teekina kuroakegha Gbeneteh Logistics - Novacare Ltd - NL', 'Nos', 24.0, 48000.0, 0.0, 0.0, 7.0, 14000.0, 17.0, 34000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Teekina kuroakegha Gbeneteh Logistics - Novacare Ltd - NL', 'Nos', 39.0, 70200.0, 0.0, 0.0, 10.0, 18000.0, 29.0, 52200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'KENNEDY OROWO EDEYE Logistics - Novacare Ltd - NL', 'Nos', 20.0, 40000.0, 0.0, 0.0, 1.0, 2000.0, 19.0, 38000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'KENNEDY OROWO EDEYE Logistics - Novacare Ltd - NL', 'Nos', 24.0, 43200.0, 0.0, 0.0, 7.0, 12600.0, 17.0, 30600.0, 1800.0, 0.0, 'Novacare Ltd')
ON CONFLICT (client_id, item_code, warehouse) DO UPDATE SET
    opening_qty = EXCLUDED.opening_qty,
    opening_value = EXCLUDED.opening_value,
    in_qty = EXCLUDED.in_qty,
    in_value = EXCLUDED.in_value,
    out_qty = EXCLUDED.out_qty,
    out_value = EXCLUDED.out_value,
    balance_qty = EXCLUDED.balance_qty,
    balance_value = EXCLUDED.balance_value,
    valuation_rate = EXCLUDED.valuation_rate,
    reserved_stock = EXCLUDED.reserved_stock,
    updated_at = NOW();


INSERT INTO public.client_stock_balances (
    client_id, item_code, item_name, item_group, warehouse, stock_uom,
    opening_qty, opening_value, in_qty, in_value, out_qty, out_value,
    balance_qty, balance_value, valuation_rate, reserved_stock, company
) VALUES
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'AHUAKAGHA CHIZURUOKE COSMOS Logistics - Novacare Ltd - NL', 'Nos', 34.0, 78200.0, 0.0, 0.0, 0.0, 0.0, 34.0, 78200.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'AHUAKAGHA CHIZURUOKE COSMOS Logistics - Novacare Ltd - NL', 'Nos', 22.0, 42900.0, 0.0, 0.0, 0.0, 0.0, 22.0, 42900.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Adetola Sam Adewuyi LOGISTICS - Novacare Ltd - NL', 'Nos', 32.0, 57600.0, 0.0, 0.0, 10.0, 18000.0, 22.0, 39600.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Adetola Sam Adewuyi LOGISTICS - Novacare Ltd - NL', 'Nos', 33.0, 66000.0, 0.0, 0.0, 11.0, 22000.0, 22.0, 44000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Victor Ogbenyi Logistics - Novacare Ltd - NL', 'Nos', 20.0, 40000.0, 0.0, 0.0, 11.0, 22000.0, 9.0, 18000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Victor Ogbenyi Logistics - Novacare Ltd - NL', 'Nos', 38.0, 68400.0, 0.0, 0.0, 24.0, 43200.0, 14.0, 25200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'RAPH XPRESS LOGISTICS - Novacare Ltd - NL', 'Nos', 5.0, 10000.0, 0.0, 0.0, 4.0, 8000.0, 1.0, 2000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'RAPH XPRESS LOGISTICS - Novacare Ltd - NL', 'Nos', 31.0, 55800.0, 0.0, 0.0, 26.0, 46800.0, 5.0, 9000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Ibylogistics Limited LOGISTICS - Novacare Ltd - NL', 'Nos', 11.0, 19800.0, 0.0, 0.0, 2.0, 3600.0, 9.0, 16200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Ibylogistics Limited LOGISTICS - Novacare Ltd - NL', 'Nos', 14.0, 28000.0, 0.0, 0.0, 0.0, 0.0, 14.0, 28000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'DINO LOGISTICS - Novacare Ltd - NL', 'Nos', 9.0, 18000.0, 0.0, 0.0, 0.0, 0.0, 9.0, 18000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'DINO LOGISTICS - Novacare Ltd - NL', 'Nos', 5.0, 9000.0, 0.0, 0.0, 0.0, 0.0, 5.0, 9000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Olupona oluwaseyi Logistics - Novacare Ltd - NL', 'Nos', 62.0, 111600.0, 0.0, 0.0, 0.0, 0.0, 62.0, 111600.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Olupona oluwaseyi Logistics - Novacare Ltd - NL', 'Nos', 59.0, 118000.0, 0.0, 0.0, 0.0, 0.0, 59.0, 118000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Tajudeen A Ayetigbo LOGISTICS - Novacare Ltd - NL', 'Nos', 27.0, 54000.0, 0.0, 0.0, 3.0, 6000.0, 24.0, 48000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Tajudeen A Ayetigbo LOGISTICS - Novacare Ltd - NL', 'Nos', 19.0, 34200.0, 0.0, 0.0, 4.0, 7200.0, 15.0, 27000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Ezekiel Ameh Logistics - Novacare Ltd - NL', 'Nos', 3.0, 5400.0, 0.0, 0.0, 2.0, 3600.0, 1.0, 1800.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Ezekiel Ameh Logistics - Novacare Ltd - NL', 'Nos', 23.0, 46000.0, 0.0, 0.0, 9.0, 18000.0, 14.0, 28000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Ezekiel Ameh Logistics - Novacare Ltd - NL', 'Nos', 25.0, 48750.0, 0.0, 0.0, 10.0, 19500.0, 15.0, 29250.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Etimbuk Gregory Logistics - Novacare Ltd - NL', 'Nos', 42.0, 84000.0, 0.0, 0.0, 20.0, 40000.0, 22.0, 44000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Etimbuk Gregory Logistics - Novacare Ltd - NL', 'Nos', 39.0, 70200.0, 0.0, 0.0, 2.0, 3600.0, 37.0, 66600.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'GINIKA ANAMBRA - Novacare Ltd - NL', 'Nos', 40.0, 78000.0, 0.0, 0.0, 4.0, 7800.0, 36.0, 70200.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Tajudeen A Ayetigbo LOGISTICS - Novacare Ltd - NL', 'Nos', 11.0, 21450.0, 0.0, 0.0, 0.0, 0.0, 11.0, 21450.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Olufunke Babalola Logistics - Novacare Ltd - NL', 'Nos', 45.0, 87750.0, 0.0, 0.0, 17.0, 33150.0, 28.0, 54600.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Yohanna Vanduna Logistics - Novacare Ltd - NL', 'Nos', 27.0, 52650.0, 0.0, 0.0, 23.0, 44850.0, 4.0, 7800.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Msuega Terlanga Japhet Logistics - Novacare Ltd - NL', 'Nos', 28.0, 54600.0, 0.0, 0.0, 14.0, 27300.0, 14.0, 27300.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'DASHGO DELIVERY CALABAR - Novacare Ltd - NL', 'Nos', 46.0, 89700.0, 0.0, 0.0, 4.0, 7800.0, 42.0, 81900.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Emmanuel Nnamdi Ugwu Logistics - Novacare Ltd - NL', 'Nos', 28.0, 54600.0, 0.0, 0.0, 0.0, 0.0, 28.0, 54600.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Chidi Godstime Egege Logistics - Novacare Ltd - NL', 'Nos', 18.0, 35100.0, 0.0, 0.0, 16.0, 31200.0, 2.0, 3900.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Emmanuel Olapeju Awoyemi Logistics - Novacare Ltd - NL', 'Nos', 30.0, 58500.0, 0.0, 0.0, 0.0, 0.0, 30.0, 58500.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Omoga Victor Ohe-obe Logistics - Novacare Ltd - NL', 'Nos', 127.0, 247650.0, 0.0, 0.0, 41.0, 79950.0, 86.0, 167700.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'DINO LOGISTICS - Novacare Ltd - NL', 'Nos', 30.0, 58500.0, 0.0, 0.0, 0.0, 0.0, 30.0, 58500.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Okoli Nnaemeka Augustine Logistics - Novacare Ltd - NL', 'Nos', 177.0, 345150.0, 0.0, 0.0, 35.0, 68250.0, 142.0, 276900.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Olaseni Adewumi James Logistics - Novacare Ltd - NL', 'Nos', 49.0, 95550.0, 0.0, 0.0, 8.0, 15600.0, 41.0, 79950.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Express Logistics, Ebonyi LOGISTICS - Novacare Ltd - NL', 'Nos', 32.0, 62400.0, 0.0, 0.0, 2.0, 3900.0, 30.0, 58500.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'HOG logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 106.0, 206700.0, 0.0, 0.0, 23.0, 44850.0, 83.0, 161850.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'BLUE AMAZON LOGISTICS LTD LOGISTICS - Novacare Ltd - NL', 'Nos', 23.0, 44850.0, 0.0, 0.0, 0.0, 0.0, 23.0, 44850.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'TEMIBASH LOGISTICS LOGISTICS - Novacare Ltd - NL', 'Nos', 74.0, 144300.0, 0.0, 0.0, 0.0, 0.0, 74.0, 144300.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Ibylogistics Limited LOGISTICS - Novacare Ltd - NL', 'Nos', -16.0, -31200.0, 0.0, 0.0, 39.0, 76050.0, -55.0, -107250.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Akanimo Edet Akpan Logistics - Novacare Ltd - NL', 'Nos', 15.0, 29250.0, 0.0, 0.0, 5.0, 9750.0, 10.0, 19500.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Durojaiye Ilashe Joseph Logistics - Novacare Ltd - NL', 'Nos', 24.0, 46800.0, 0.0, 0.0, 23.0, 44850.0, 1.0, 1950.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Durojaiye Ilashe Joseph Logistics - Novacare Ltd - NL', 'Nos', 29.0, 66700.0, 0.0, 0.0, 0.0, 0.0, 29.0, 66700.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Adetola Sam Adewuyi LOGISTICS - Novacare Ltd - NL', 'Nos', 57.0, 111150.0, 0.0, 0.0, 9.0, 17550.0, 48.0, 93600.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'ATP Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', -39.0, -76050.0, 150.0, 292500.0, 63.0, 122850.0, 48.0, 93600.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Usiju Ladu Logistics - Novacare Ltd - NL', 'Nos', 4.0, 7800.0, 0.0, 0.0, 7.0, 13650.0, -3.0, -5850.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Toheeb Biola Popoola Logistics - Novacare Ltd - NL', 'Nos', 38.0, 81100.0, 0.0, 0.0, 0.0, 0.0, 38.0, 81100.0, 2134.211, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Toheeb Biola Popoola Logistics - Novacare Ltd - NL', 'Nos', 2.0, 3900.0, 0.0, 0.0, 38.0, 74100.0, -36.0, -70200.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'NOVA XPRESS ABUJA - Novacare Ltd - NL', 'Nos', 365.0, 657000.0, 0.0, 0.0, 67.0, 120600.0, 298.0, 536400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'NOVA XPRESS ABUJA - Novacare Ltd - NL', 'Nos', 578.0, 1156000.0, 0.0, 0.0, 38.0, 76000.0, 540.0, 1080000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Adetola Sam Adewuyi LOGISTICS - Novacare Ltd - NL', 'Nos', 34.0, 78200.0, 0.0, 0.0, 0.0, 0.0, 34.0, 78200.0, 2300.0, 0.0, 'Novacare Ltd')
ON CONFLICT (client_id, item_code, warehouse) DO UPDATE SET
    opening_qty = EXCLUDED.opening_qty,
    opening_value = EXCLUDED.opening_value,
    in_qty = EXCLUDED.in_qty,
    in_value = EXCLUDED.in_value,
    out_qty = EXCLUDED.out_qty,
    out_value = EXCLUDED.out_value,
    balance_qty = EXCLUDED.balance_qty,
    balance_value = EXCLUDED.balance_value,
    valuation_rate = EXCLUDED.valuation_rate,
    reserved_stock = EXCLUDED.reserved_stock,
    updated_at = NOW();


INSERT INTO public.client_stock_balances (
    client_id, item_code, item_name, item_group, warehouse, stock_uom,
    opening_qty, opening_value, in_qty, in_value, out_qty, out_value,
    balance_qty, balance_value, valuation_rate, reserved_stock, company
) VALUES
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'DINO LOGISTICS - Novacare Ltd - NL', 'Nos', 30.0, 69000.0, 0.0, 0.0, 0.0, 0.0, 30.0, 69000.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Ibylogistics Limited LOGISTICS - Novacare Ltd - NL', 'Nos', 37.0, 85100.0, 0.0, 0.0, 0.0, 0.0, 37.0, 85100.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Olaseni Adewumi James Logistics - Novacare Ltd - NL', 'Nos', 39.0, 89700.0, 0.0, 0.0, 3.0, 6900.0, 36.0, 82800.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'TEMIBASH LOGISTICS LOGISTICS - Novacare Ltd - NL', 'Nos', 32.0, 73600.0, 0.0, 0.0, 0.0, 0.0, 32.0, 73600.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'DASHGO DELIVERY CALABAR - Novacare Ltd - NL', 'Nos', 30.0, 69000.0, 0.0, 0.0, 0.0, 0.0, 30.0, 69000.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Sheriff Adesola Raifu Logistics - Novacare Ltd - NL', 'Nos', 22.0, 50600.0, 0.0, 0.0, 4.0, 9200.0, 18.0, 41400.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'GINIKA ANAMBRA - Novacare Ltd - NL', 'Nos', 29.0, 66700.0, 0.0, 0.0, 0.0, 0.0, 29.0, 66700.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Okoli Nnaemeka Augustine Logistics - Novacare Ltd - NL', 'Nos', 29.0, 66700.0, 0.0, 0.0, 3.0, 6900.0, 26.0, 59800.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Chidi Godstime Egege Logistics - Novacare Ltd - NL', 'Nos', 42.0, 96600.0, 0.0, 0.0, 0.0, 0.0, 42.0, 96600.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Usiju Ladu Logistics - Novacare Ltd - NL', 'Nos', 26.0, 59800.0, 0.0, 0.0, 0.0, 0.0, 26.0, 59800.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Yohanna Vanduna Logistics - Novacare Ltd - NL', 'Nos', 23.0, 52900.0, 0.0, 0.0, 2.0, 4600.0, 21.0, 48300.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Raphael Michael Logistics - Novacare Ltd - NL', 'Nos', 8.0, 15600.0, 0.0, 0.0, 21.0, 40950.0, -13.0, -25350.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Raphael Michael Logistics - Novacare Ltd - NL', 'Nos', 33.0, 75900.0, 0.0, 0.0, 3.0, 6900.0, 30.0, 69000.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Tajudeen A Ayetigbo LOGISTICS - Novacare Ltd - NL', 'Nos', 17.0, 39100.0, 0.0, 0.0, 0.0, 0.0, 17.0, 39100.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Akanimo Edet Akpan Logistics - Novacare Ltd - NL', 'Nos', 32.0, 73600.0, 0.0, 0.0, 0.0, 0.0, 32.0, 73600.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Express Logistics, Ebonyi LOGISTICS - Novacare Ltd - NL', 'Nos', 42.0, 96600.0, 0.0, 0.0, 2.0, 4600.0, 40.0, 92000.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Omoga Victor Ohe-obe Logistics - Novacare Ltd - NL', 'Nos', 32.0, 73600.0, 0.0, 0.0, 1.0, 2300.0, 31.0, 71300.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'ATP Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 41.0, 94300.0, 0.0, 0.0, 4.0, 9200.0, 37.0, 85100.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'HOG logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 41.0, 94300.0, 0.0, 0.0, 3.0, 6900.0, 38.0, 87400.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Olufunke Babalola Logistics - Novacare Ltd - NL', 'Nos', 23.0, 52900.0, 0.0, 0.0, 0.0, 0.0, 23.0, 52900.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Msuega Terlanga Japhet Logistics - Novacare Ltd - NL', 'Nos', 46.0, 105800.0, 0.0, 0.0, 1.0, 2300.0, 45.0, 103500.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Alatiya Absalom Emmanuel Logistics - Novacare Ltd - NL', 'Nos', 32.0, 64000.0, 0.0, 0.0, 7.0, 14000.0, 25.0, 50000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Alatiya Absalom Emmanuel Logistics - Novacare Ltd - NL', 'Nos', 47.0, 84600.0, 0.0, 0.0, 6.0, 10800.0, 41.0, 73800.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Sheriff Adesola Raifu Logistics - Novacare Ltd - NL', 'Nos', 93.0, 181350.0, 0.0, 0.0, 24.0, 46800.0, 69.0, 134550.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Emmanuel Nnamdi Ugwu Logistics - Novacare Ltd - NL', 'Nos', 30.0, 69000.0, 0.0, 0.0, 0.0, 0.0, 30.0, 69000.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'BLUE AMAZON LOGISTICS LTD LOGISTICS - Novacare Ltd - NL', 'Nos', 29.0, 66700.0, 0.0, 0.0, 0.0, 0.0, 29.0, 66700.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Olawale Olusola Logistics - Novacare Ltd - NL', 'Nos', 39.0, 76050.0, 0.0, 0.0, 12.0, 23400.0, 27.0, 52650.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Olawale Olusola Logistics - Novacare Ltd - NL', 'Nos', 28.0, 64400.0, 0.0, 0.0, 2.0, 4600.0, 26.0, 59800.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'PELICAN DELIVERY AND LOGISTICS SERVICES LOGISTICS - Novacare Ltd - NL', 'Nos', 46.0, 82800.0, 0.0, 0.0, 0.0, 0.0, 46.0, 82800.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Yohanna Vanduna Logistics - Novacare Ltd - NL', 'Nos', 36.0, 72000.0, 0.0, 0.0, 3.0, 6000.0, 33.0, 66000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Yohanna Vanduna Logistics - Novacare Ltd - NL', 'Nos', 44.0, 79200.0, 0.0, 0.0, 0.0, 0.0, 44.0, 79200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Express Logistics, Ebonyi LOGISTICS - Novacare Ltd - NL', 'Nos', 16.0, 25600.0, 0.0, 0.0, 0.0, 0.0, 16.0, 25600.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'SAGE LOGISTICS - Novacare Ltd - NL', 'Nos', 109.0, 327000.0, 0.0, 0.0, 61.0, 183000.0, 48.0, 144000.0, 3000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'SAGE LOGISTICS - Novacare Ltd - NL', 'Nos', 276.0, 525865.56, 0.0, 0.0, 42.0, 80023.02, 234.0, 445842.54, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'George O.O LOGISTICS - Novacare Ltd - NL', 'Nos', 2.0, 3400.0, 0.0, 0.0, 0.0, 0.0, 2.0, 3400.0, 1700.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'imole logistics - Novacare Ltd - NL', 'Nos', 127.0, 241974.37, 0.0, 0.0, 65.0, 123845.15, 62.0, 118129.22, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'imole logistics - Novacare Ltd - NL', 'Nos', 170.0, 501500.0, 0.0, 0.0, 9.0, 26550.0, 161.0, 474950.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'ANIEADOLF CREATIONS - Novacare Ltd - NL', 'Nos', 379.0, 731583.7, 0.0, 0.0, 29.0, 55978.7, 350.0, 675605.0, 1930.3, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'ANIEADOLF CREATIONS - Novacare Ltd - NL', 'Nos', 190.0, 559437.9, 0.0, 0.0, 25.0, 73610.25, 165.0, 485827.65, 2944.41, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'ANIEADOLF CREATIONS - Novacare Ltd - NL', 'Nos', 30.0, 60000.0, 0.0, 0.0, 23.0, 46000.0, 7.0, 14000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'ANIEADOLF CREATIONS - Novacare Ltd - NL', 'Nos', 66.0, 128000.0, 0.0, 0.0, 43.0, 86000.0, 23.0, 42000.0, 1826.087, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Shittu Adebamke Yusuff Logistics - Novacare Ltd - NL', 'Nos', 46.0, 92000.0, 0.0, 0.0, 4.0, 8000.0, 42.0, 84000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Shittu Adebamke Yusuff Logistics - Novacare Ltd - NL', 'Nos', 47.0, 84600.0, 0.0, 0.0, 3.0, 5400.0, 44.0, 79200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Toheeb Biola Popoola Logistics - Novacare Ltd - NL', 'Nos', 10.0, 13000.0, 0.0, 0.0, 0.0, 0.0, 10.0, 13000.0, 1300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Tajudeen A Ayetigbo LOGISTICS - Novacare Ltd - NL', 'Nos', 20.0, 36000.0, 0.0, 0.0, 0.0, 0.0, 20.0, 36000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Msuega Terlanga Japhet Logistics - Novacare Ltd - NL', 'Nos', 26.0, 41600.0, 0.0, 0.0, 0.0, 0.0, 26.0, 41600.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'GetIT Express Logistics - Novacare Ltd - NL', 'Nos', 320.0, 608000.0, 0.0, 0.0, 0.0, 0.0, 320.0, 608000.0, 1900.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'GetIT Express Logistics - Novacare Ltd - NL', 'Nos', 110.0, 324500.0, 0.0, 0.0, 0.0, 0.0, 110.0, 324500.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'GetIT Express Logistics - Novacare Ltd - NL', 'Nos', 20.0, 36000.0, 0.0, 0.0, 0.0, 0.0, 20.0, 36000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'YAYA JOB - Novacare Ltd - NL', 'Nos', 37.0, 66600.0, 0.0, 0.0, 0.0, 0.0, 37.0, 66600.0, 1800.0, 0.0, 'Novacare Ltd')
ON CONFLICT (client_id, item_code, warehouse) DO UPDATE SET
    opening_qty = EXCLUDED.opening_qty,
    opening_value = EXCLUDED.opening_value,
    in_qty = EXCLUDED.in_qty,
    in_value = EXCLUDED.in_value,
    out_qty = EXCLUDED.out_qty,
    out_value = EXCLUDED.out_value,
    balance_qty = EXCLUDED.balance_qty,
    balance_value = EXCLUDED.balance_value,
    valuation_rate = EXCLUDED.valuation_rate,
    reserved_stock = EXCLUDED.reserved_stock,
    updated_at = NOW();


INSERT INTO public.client_stock_balances (
    client_id, item_code, item_name, item_group, warehouse, stock_uom,
    opening_qty, opening_value, in_qty, in_value, out_qty, out_value,
    balance_qty, balance_value, valuation_rate, reserved_stock, company
) VALUES
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'YAYA JOB - Novacare Ltd - NL', 'Nos', 37.0, 74000.0, 0.0, 0.0, 0.0, 0.0, 37.0, 74000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Msuega Terlanga Japhet Logistics - Novacare Ltd - NL', 'Nos', 37.0, 74000.0, 0.0, 0.0, 13.0, 26000.0, 24.0, 48000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Msuega Terlanga Japhet Logistics - Novacare Ltd - NL', 'Nos', 46.0, 84000.0, 0.0, 0.0, 8.0, 15600.0, 38.0, 68400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'GetIT Express Logistics - Novacare Ltd - NL', 'Nos', 20.0, 40000.0, 0.0, 0.0, 0.0, 0.0, 20.0, 40000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'APPLE ANAMBRA DELIVERY SERVICES - Novacare Ltd - NL', 'Nos', 37.0, 74000.0, 0.0, 0.0, 0.0, 0.0, 37.0, 74000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'APPLE ANAMBRA DELIVERY SERVICES - Novacare Ltd - NL', 'Nos', 38.0, 69666.54, 0.0, 0.0, 1.0, 1833.33, 37.0, 67833.21, 1833.33, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'byke messengers logistic - Novacare Ltd - NL', 'Nos', 541.0, 1036548.8, 0.0, 0.0, 85.0, 167727.44, 456.0, 868821.36, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'byke messengers logistic - Novacare Ltd - NL', 'Nos', 135.0, 405000.0, 320.0, 960000.0, 43.0, 129000.0, 412.0, 1236000.0, 3000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'AB LOGISTICS KADUNA - Novacare Ltd - NL', 'Nos', 169.0, 338000.0, 0.0, 0.0, 16.0, 32000.0, 153.0, 306000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'AB LOGISTICS KADUNA - Novacare Ltd - NL', 'Nos', 336.0, 748000.0, 0.0, 0.0, 6.0, 12000.0, 330.0, 736000.0, 2230.303, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'PEAKLINK LOGISTICS LTD - Novacare Ltd - NL', 'Nos', 197.0, 377644.14, 0.0, 0.0, 34.0, 66892.28, 163.0, 310751.86, 1906.453, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'PEAKLINK LOGISTICS LTD - Novacare Ltd - NL', 'Nos', 258.0, 761369.9, 0.0, 0.0, 17.0, 42849.35, 241.0, 718520.55, 2981.413, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Solomon Uduak Ikpembe - Novacare Ltd - NL', 'Nos', 42.0, 80041.92, 160.0, 304849.6, 20.0, 38115.2, 182.0, 346776.32, 1905.364, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Solomon Uduak Ikpembe - Novacare Ltd - NL', 'Nos', 189.0, 561550.0, 320.0, 960000.0, 27.0, 79650.0, 482.0, 1441900.0, 2991.494, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'ISMAIL MUHAMMAD LIMAN - Novacare Ltd - NL', 'Nos', 217.0, 418849.6, 320.0, 609699.2, 3.0, 6000.0, 534.0, 1022548.8, 1914.885, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'ISMAIL MUHAMMAD LIMAN - Novacare Ltd - NL', 'Nos', 98.0, 272000.0, 320.0, 960000.0, 8.0, 16000.0, 410.0, 1216000.0, 2965.854, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'ATOMIC LOGISTICS EDO - Novacare Ltd - NL', 'Nos', 224.0, 426800.24, 0.0, 0.0, 53.0, 100992.23, 171.0, 325808.01, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'ATOMIC LOGISTICS EDO - Novacare Ltd - NL', 'Nos', 282.0, 839900.0, 0.0, 0.0, 19.0, 56050.0, 263.0, 783850.0, 2980.418, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Aruoriwo Adhuze - Novacare Ltd - NL', 'Nos', 276.0, 529011.96, 0.0, 0.0, 44.0, 84335.24, 232.0, 444676.72, 1916.71, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Aruoriwo Adhuze - Novacare Ltd - NL', 'Nos', 218.0, 643100.0, 0.0, 0.0, 16.0, 47200.0, 202.0, 595900.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'ug express logistics ltd - Novacare Ltd - NL', 'Nos', 342.0, 665819.28, 0.0, 0.0, 36.0, 70086.24, 306.0, 595733.04, 1946.84, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'ug express logistics ltd - Novacare Ltd - NL', 'Nos', 329.0, 734000.0, 0.0, 0.0, 35.0, 70000.0, 294.0, 664000.0, 2258.503, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Smart move Logistics Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 105.0, 525000.0, 0.0, 0.0, 1.0, 5000.0, 104.0, 520000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Connect Logistics - Novacare Ltd - NL', 'Nos', 33.0, 64350.0, 0.0, 0.0, 9.0, 17550.0, 24.0, 46800.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Connect Logistics - Novacare Ltd - NL', 'Nos', 26.0, 59800.0, 0.0, 0.0, 1.0, 2300.0, 25.0, 57500.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Teekina kuroakegha Gbeneteh Logistics - Novacare Ltd - NL', 'Nos', 28.0, 54600.0, 0.0, 0.0, 2.0, 3900.0, 26.0, 50700.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Teekina kuroakegha Gbeneteh Logistics - Novacare Ltd - NL', 'Nos', 158.0, 308100.0, 0.0, 0.0, 4.0, 7800.0, 154.0, 300300.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Shittu Adebamke Yusuff Logistics - Novacare Ltd - NL', 'Nos', 37.0, 72150.0, 0.0, 0.0, 8.0, 15600.0, 29.0, 56550.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Shittu Adebamke Yusuff Logistics - Novacare Ltd - NL', 'Nos', 37.0, 85100.0, 0.0, 0.0, 3.0, 6900.0, 34.0, 78200.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'imole logistics - Novacare Ltd - NL', 'Nos', 20.0, 40000.0, 0.0, 0.0, 0.0, 0.0, 20.0, 40000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'imole logistics - Novacare Ltd - NL', 'Nos', 12.0, 21600.0, 0.0, 0.0, 3.0, 5400.0, 9.0, 16200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Olawale Olusola Logistics - Novacare Ltd - NL', 'Nos', 10.0, 18000.0, 0.0, 0.0, 0.0, 0.0, 10.0, 18000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Olawale Olusola Logistics - Novacare Ltd - NL', 'Nos', 8.0, 16000.0, 0.0, 0.0, 5.0, 10000.0, 3.0, 6000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Etimbuk Gregory Logistics - Novacare Ltd - NL', 'Nos', 38.0, 68400.0, 0.0, 0.0, 0.0, 0.0, 38.0, 68400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Ola Cash - Novacare Ltd - NL', 'Nos', 29.0, 52200.0, 0.0, 0.0, 0.0, 0.0, 29.0, 52200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-PBP', 'Push Board Pro', 'Novacare', 'Ola Cash - Novacare Ltd - NL', 'Nos', 10.0, 20000.0, 0.0, 0.0, 0.0, 0.0, 10.0, 20000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Ola Cash - Novacare Ltd - NL', 'Nos', 69.0, 345000.0, 0.0, 0.0, 0.0, 0.0, 69.0, 345000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Velocitŕ logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 41.0, 73800.0, 0.0, 0.0, 0.0, 0.0, 41.0, 73800.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'Okoli Nnaemeka Augustine Logistics - Novacare Ltd - NL', 'Nos', 6.0, 10800.0, 0.0, 0.0, 0.0, 0.0, 6.0, 10800.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Okoli Nnaemeka Augustine Logistics - Novacare Ltd - NL', 'Nos', 23.0, 39100.0, 0.0, 0.0, 0.0, 0.0, 23.0, 39100.0, 1700.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'TRUST LOGISTICS BENUE - Novacare Ltd - NL', 'Nos', 320.0, 960000.0, 0.0, 0.0, 0.0, 0.0, 320.0, 960000.0, 3000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'John Peter Adamawa - Novacare Ltd - NL', 'Nos', 12.0, 23400.0, 0.0, 0.0, 8.0, 15600.0, 4.0, 7800.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'John Peter Adamawa - Novacare Ltd - NL', 'Nos', 25.0, 57500.0, 0.0, 0.0, 1.0, 2300.0, 24.0, 55200.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Enny logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 27.0, 48600.0, 0.0, 0.0, 0.0, 0.0, 27.0, 48600.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Enny logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 112.0, 560000.0, 0.0, 0.0, 0.0, 0.0, 112.0, 560000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'YAYA JOB - Novacare Ltd - NL', 'Nos', 23.0, 41400.0, 0.0, 0.0, 0.0, 0.0, 23.0, 41400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'GINIKA ANAMBRA - Novacare Ltd - NL', 'Nos', 10.0, 16000.0, 0.0, 0.0, 0.0, 0.0, 10.0, 16000.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'GINIKA ANAMBRA - Novacare Ltd - NL', 'Nos', 30.0, 60000.0, 0.0, 0.0, 0.0, 0.0, 30.0, 60000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'GINIKA ANAMBRA - Novacare Ltd - NL', 'Nos', 28.0, 51333.24, 0.0, 0.0, 16.0, 29333.28, 12.0, 21999.96, 1833.33, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Abdulsalam Abubakar Logistics - Novacare Ltd - NL', 'Nos', 18.0, 32400.0, 0.0, 0.0, 0.0, 0.0, 18.0, 32400.0, 1800.0, 0.0, 'Novacare Ltd')
ON CONFLICT (client_id, item_code, warehouse) DO UPDATE SET
    opening_qty = EXCLUDED.opening_qty,
    opening_value = EXCLUDED.opening_value,
    in_qty = EXCLUDED.in_qty,
    in_value = EXCLUDED.in_value,
    out_qty = EXCLUDED.out_qty,
    out_value = EXCLUDED.out_value,
    balance_qty = EXCLUDED.balance_qty,
    balance_value = EXCLUDED.balance_value,
    valuation_rate = EXCLUDED.valuation_rate,
    reserved_stock = EXCLUDED.reserved_stock,
    updated_at = NOW();


INSERT INTO public.client_stock_balances (
    client_id, item_code, item_name, item_group, warehouse, stock_uom,
    opening_qty, opening_value, in_qty, in_value, out_qty, out_value,
    balance_qty, balance_value, valuation_rate, reserved_stock, company
) VALUES
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Olaseni Adewumi James Logistics - Novacare Ltd - NL', 'Nos', 94.0, 470000.0, 0.0, 0.0, 0.0, 0.0, 94.0, 470000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Olaseni Adewumi James Logistics - Novacare Ltd - NL', 'Nos', 24.0, 43200.0, 0.0, 0.0, 0.0, 0.0, 24.0, 43200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'FLYMARK LOGISTICS KD - Novacare Ltd - NL', 'Nos', 32.0, 94400.0, 0.0, 0.0, 7.0, 20650.0, 25.0, 73750.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Hezekiah Victor Adesanmi Logistics - Novacare Ltd - NL', 'Nos', 29.0, 46400.0, 0.0, 0.0, 0.0, 0.0, 29.0, 46400.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Anthony Ezekiel Logistics - Novacare Ltd - NL', 'Nos', 31.0, 62000.0, 0.0, 0.0, 0.0, 0.0, 31.0, 62000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Anthony Ezekiel Logistics - Novacare Ltd - NL', 'Nos', 23.0, 42392.22, 0.0, 0.0, 15.0, 27647.1, 8.0, 14745.12, 1843.14, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'Adeyinka Ekundayo Isreal Logistics - Novacare Ltd - NL', 'Nos', 35.0, 56000.0, 0.0, 0.0, 0.0, 0.0, 35.0, 56000.0, 1600.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Ezekiel Ameh Logistics - Novacare Ltd - NL', 'Nos', 26.0, 59800.0, 0.0, 0.0, 0.0, 0.0, 26.0, 59800.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'De Wealthz Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 9.0, 16200.0, 0.0, 0.0, 0.0, 0.0, 9.0, 16200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Teekina kuroakegha Gbeneteh Logistics - Novacare Ltd - NL', 'Nos', 9.0, 16200.0, 0.0, 0.0, 0.0, 0.0, 9.0, 16200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'TRUST LOGISTICS PDA - Novacare Ltd - NL', 'Nos', 18.0, 32400.0, 0.0, 0.0, 0.0, 0.0, 18.0, 32400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Olupona oluwaseyi Logistics - Novacare Ltd - NL', 'Nos', 32.0, 57600.0, 0.0, 0.0, 0.0, 0.0, 32.0, 57600.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'FOMAX ASABA (DELTA) LOGISTICS - Novacare Ltd - NL', 'Nos', 14.0, 25200.0, 0.0, 0.0, 0.0, 0.0, 14.0, 25200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'Fomax logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 20.0, 36000.0, 0.0, 0.0, 0.0, 0.0, 20.0, 36000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-NR', 'Nail Repair', 'Novacare', 'FLYMARK LOGISTICS KD - Novacare Ltd - NL', 'Nos', 11.0, 19800.0, 0.0, 0.0, 0.0, 0.0, 11.0, 19800.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'FLYMARK LOGISTICS KD - Novacare Ltd - NL', 'Nos', 17.0, 85000.0, 0.0, 0.0, 2.0, 10000.0, 15.0, 75000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'FLYMARK LOGISTICS KD - Novacare Ltd - NL', 'Nos', 26.0, 46800.0, 0.0, 0.0, 0.0, 0.0, 26.0, 46800.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'TEMIBASH LOGISTICS LOGISTICS - Novacare Ltd - NL', 'Nos', 34.0, 68000.0, 0.0, 0.0, 2.0, 4000.0, 32.0, 64000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'TEMIBASH LOGISTICS LOGISTICS - Novacare Ltd - NL', 'Nos', 35.0, 63000.0, 0.0, 0.0, 5.0, 9000.0, 30.0, 54000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'FOMAX PH. LOGISTICS - Novacare Ltd - NL', 'Nos', 27.0, 54000.0, 0.0, 0.0, 11.0, 22000.0, 16.0, 32000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'FOMAX PH. LOGISTICS - Novacare Ltd - NL', 'Nos', 25.0, 45000.0, 0.0, 0.0, 3.0, 5400.0, 22.0, 39600.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'DASHGO DELIVERY CALABAR - Novacare Ltd - NL', 'Nos', 20.0, 40000.0, 0.0, 0.0, 0.0, 0.0, 20.0, 40000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'DASHGO DELIVERY CALABAR - Novacare Ltd - NL', 'Nos', 23.0, 41400.0, 0.0, 0.0, 5.0, 9000.0, 18.0, 32400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'APPLE ABIA TAZE LOGISTICS SERVICES - Novacare Ltd - NL', 'Nos', 21.0, 42000.0, 0.0, 0.0, 2.0, 4000.0, 19.0, 38000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'APPLE ABIA TAZE LOGISTICS SERVICES - Novacare Ltd - NL', 'Nos', 17.0, 30600.0, 0.0, 0.0, 6.0, 10800.0, 11.0, 19800.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'PELICAN DELIVERY AND LOGISTICS SERVICES LOGISTICS - Novacare Ltd - NL', 'Nos', 34.0, 68000.0, 0.0, 0.0, 18.0, 36000.0, 16.0, 32000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'PELICAN DELIVERY AND LOGISTICS SERVICES LOGISTICS - Novacare Ltd - NL', 'Nos', 31.0, 55800.0, 0.0, 0.0, 5.0, 9000.0, 26.0, 46800.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Adeyinka Ekundayo Isreal Logistics - Novacare Ltd - NL', 'Nos', 32.0, 64000.0, 0.0, 0.0, 0.0, 0.0, 32.0, 64000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Adeyinka Ekundayo Isreal Logistics - Novacare Ltd - NL', 'Nos', 38.0, 68400.0, 0.0, 0.0, 0.0, 0.0, 38.0, 68400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Adolf Umoh Aniekeme - Novacare Ltd - NL', 'Nos', 60.0, 120000.0, 0.0, 0.0, 0.0, 0.0, 60.0, 120000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Adolf Umoh Aniekeme - Novacare Ltd - NL', 'Nos', 58.0, 104400.0, 0.0, 0.0, 0.0, 0.0, 58.0, 104400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Olawale Olusola Logistics - Novacare Ltd - NL', 'Nos', 15.0, 27000.0, 0.0, 0.0, 1.0, 1800.0, 14.0, 25200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Emmanuel Nnamdi Ugwu Logistics - Novacare Ltd - NL', 'Nos', 38.0, 68400.0, 0.0, 0.0, 0.0, 0.0, 38.0, 68400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Emmanuel Nnamdi Ugwu Logistics - Novacare Ltd - NL', 'Nos', 14.0, 28000.0, 0.0, 0.0, 4.0, 8000.0, 10.0, 20000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'BLUE AMAZON LOGISTICS LTD LOGISTICS - Novacare Ltd - NL', 'Nos', 38.0, 68400.0, 0.0, 0.0, 0.0, 0.0, 38.0, 68400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'BLUE AMAZON LOGISTICS LTD LOGISTICS - Novacare Ltd - NL', 'Nos', 34.0, 68000.0, 0.0, 0.0, 2.0, 4000.0, 32.0, 64000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'De Wealthz Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 36.0, 72000.0, 0.0, 0.0, 8.0, 16000.0, 28.0, 56000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'De Wealthz Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 35.0, 70000.0, 0.0, 0.0, 11.0, 22000.0, 24.0, 48000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Emmanuel Olapeju Awoyemi Logistics - Novacare Ltd - NL', 'Nos', 39.0, 78000.0, 0.0, 0.0, 0.0, 0.0, 39.0, 78000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Emmanuel Olapeju Awoyemi Logistics - Novacare Ltd - NL', 'Nos', 38.0, 68400.0, 0.0, 0.0, 0.0, 0.0, 38.0, 68400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'FOMAX ASABA (DELTA) LOGISTICS - Novacare Ltd - NL', 'Nos', 40.0, 80000.0, 0.0, 0.0, 0.0, 0.0, 40.0, 80000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'FOMAX ASABA (DELTA) LOGISTICS - Novacare Ltd - NL', 'Nos', 40.0, 72000.0, 0.0, 0.0, 0.0, 0.0, 40.0, 72000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'AB LOGISTICS KADUNA - Novacare Ltd - NL', 'Nos', 40.0, 80000.0, 0.0, 0.0, 0.0, 0.0, 40.0, 80000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'AB LOGISTICS KADUNA - Novacare Ltd - NL', 'Nos', 39.0, 70200.0, 0.0, 0.0, 2.0, 3600.0, 37.0, 66600.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Toheeb Biola Popoola Logistics - Novacare Ltd - NL', 'Nos', 24.0, 48000.0, 0.0, 0.0, 3.0, 6000.0, 21.0, 42000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Toheeb Biola Popoola Logistics - Novacare Ltd - NL', 'Nos', 11.0, 19800.0, 50.0, 90000.0, 1.0, 1800.0, 60.0, 108000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'PEAKLINK LOGISTICS LTD - Novacare Ltd - NL', 'Nos', 40.0, 80000.0, 0.0, 0.0, 0.0, 0.0, 40.0, 80000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'PEAKLINK LOGISTICS LTD - Novacare Ltd - NL', 'Nos', 40.0, 72000.0, 0.0, 0.0, 0.0, 0.0, 40.0, 72000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Smart move Logistics Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 19.0, 38000.0, 0.0, 0.0, 1.0, 2000.0, 18.0, 36000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Smart move Logistics Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 31.0, 62000.0, 0.0, 0.0, 1.0, 2000.0, 30.0, 60000.0, 2000.0, 0.0, 'Novacare Ltd')
ON CONFLICT (client_id, item_code, warehouse) DO UPDATE SET
    opening_qty = EXCLUDED.opening_qty,
    opening_value = EXCLUDED.opening_value,
    in_qty = EXCLUDED.in_qty,
    in_value = EXCLUDED.in_value,
    out_qty = EXCLUDED.out_qty,
    out_value = EXCLUDED.out_value,
    balance_qty = EXCLUDED.balance_qty,
    balance_value = EXCLUDED.balance_value,
    valuation_rate = EXCLUDED.valuation_rate,
    reserved_stock = EXCLUDED.reserved_stock,
    updated_at = NOW();


INSERT INTO public.client_stock_balances (
    client_id, item_code, item_name, item_group, warehouse, stock_uom,
    opening_qty, opening_value, in_qty, in_value, out_qty, out_value,
    balance_qty, balance_value, valuation_rate, reserved_stock, company
) VALUES
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'George O.O LOGISTICS - Novacare Ltd - NL', 'Nos', 3.0, 6000.0, 0.0, 0.0, 2.0, 4000.0, 1.0, 2000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'George O.O LOGISTICS - Novacare Ltd - NL', 'Nos', 9.0, 16200.0, 0.0, 0.0, 1.0, 1800.0, 8.0, 14400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Aruoriwo Adhuze - Novacare Ltd - NL', 'Nos', 54.0, 108000.0, 0.0, 0.0, 5.0, 10000.0, 49.0, 98000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Aruoriwo Adhuze - Novacare Ltd - NL', 'Nos', 56.0, 100800.0, 0.0, 0.0, 4.0, 7200.0, 52.0, 93600.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Efe Brendon Avwia Logistics - Novacare Ltd - NL', 'Nos', 31.0, 62000.0, 0.0, 0.0, 3.0, 6000.0, 28.0, 56000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Efe Brendon Avwia Logistics - Novacare Ltd - NL', 'Nos', 37.0, 66600.0, 0.0, 0.0, 8.0, 14400.0, 29.0, 52200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'byke messengers logistic - Novacare Ltd - NL', 'Nos', 39.0, 78000.0, 0.0, 0.0, 7.0, 14000.0, 32.0, 64000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'byke messengers logistic - Novacare Ltd - NL', 'Nos', 43.0, 77400.0, 0.0, 0.0, 10.0, 18000.0, 33.0, 59400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Solomon Uduak Ikpembe - Novacare Ltd - NL', 'Nos', 40.0, 80000.0, 0.0, 0.0, 9.0, 18000.0, 31.0, 62000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Solomon Uduak Ikpembe - Novacare Ltd - NL', 'Nos', 46.0, 82800.0, 0.0, 0.0, 4.0, 7200.0, 42.0, 75600.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'ug express logistics ltd - Novacare Ltd - NL', 'Nos', 25.0, 50000.0, 0.0, 0.0, 5.0, 10000.0, 20.0, 40000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'ug express logistics ltd - Novacare Ltd - NL', 'Nos', 24.0, 48000.0, 0.0, 0.0, 7.0, 14000.0, 17.0, 34000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'ISMAIL MUHAMMAD LIMAN - Novacare Ltd - NL', 'Nos', 24.0, 48000.0, 0.0, 0.0, 3.0, 6000.0, 21.0, 42000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'ISMAIL MUHAMMAD LIMAN - Novacare Ltd - NL', 'Nos', 39.0, 70200.0, 0.0, 0.0, 0.0, 0.0, 39.0, 70200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Usiju Ladu Logistics - Novacare Ltd - NL', 'Nos', 25.0, 50000.0, 0.0, 0.0, 7.0, 14000.0, 18.0, 36000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Usiju Ladu Logistics - Novacare Ltd - NL', 'Nos', 38.0, 68400.0, 0.0, 0.0, 2.0, 3600.0, 36.0, 64800.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'TRUST LOGISTICS PDA - Novacare Ltd - NL', 'Nos', 37.0, 74000.0, 0.0, 0.0, 0.0, 0.0, 37.0, 74000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'TRUST LOGISTICS PDA - Novacare Ltd - NL', 'Nos', 39.0, 70200.0, 0.0, 0.0, 0.0, 0.0, 39.0, 70200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Okolie Anthony ogorchukwu Logistics - Novacare Ltd - NL', 'Nos', 12.0, 24000.0, 0.0, 0.0, 6.0, 12000.0, 6.0, 12000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Okolie Anthony ogorchukwu Logistics - Novacare Ltd - NL', 'Nos', 34.0, 61200.0, 0.0, 0.0, 7.0, 12600.0, 27.0, 48600.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'ANIEADOLF CREATIONS - Novacare Ltd - NL', 'Nos', 30.0, 150000.0, 0.0, 0.0, 2.0, 10000.0, 28.0, 140000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'APPLE ANAMBRA DELIVERY SERVICES - Novacare Ltd - NL', 'Nos', 15.0, 27000.0, 0.0, 0.0, 0.0, 0.0, 15.0, 27000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'smart logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 17.0, 34000.0, 0.0, 0.0, 9.0, 18000.0, 8.0, 16000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'smart logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 13.0, 23400.0, 0.0, 0.0, 0.0, 0.0, 13.0, 23400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'groza logistics ltd - Novacare Ltd - NL', 'Nos', 176.0, 336849.6, 0.0, 0.0, 46.0, 89159.3, 130.0, 247690.3, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'groza logistics ltd - Novacare Ltd - NL', 'Nos', 96.0, 268000.0, 0.0, 0.0, 76.0, 209000.0, 20.0, 59000.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'groza logistics ltd - Novacare Ltd - NL', 'Nos', 28.0, 56000.0, 0.0, 0.0, 2.0, 4000.0, 26.0, 52000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'groza logistics ltd - Novacare Ltd - NL', 'Nos', 20.0, 36000.0, 0.0, 0.0, 0.0, 0.0, 20.0, 36000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'groza logistics ltd - Novacare Ltd - NL', 'Nos', 84.0, 420000.0, 0.0, 0.0, 0.0, 0.0, 84.0, 420000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'AB LOGISTICS KADUNA - Novacare Ltd - NL', 'Nos', 40.0, 200000.0, 0.0, 0.0, 0.0, 0.0, 40.0, 200000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'PEAKLINK LOGISTICS LTD - Novacare Ltd - NL', 'Nos', 43.0, 215000.0, 0.0, 0.0, 0.0, 0.0, 43.0, 215000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Adolf Umoh Aniekeme - Novacare Ltd - NL', 'Nos', 400.0, 800000.0, 0.0, 0.0, 0.0, 0.0, 400.0, 800000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Adolf Umoh Aniekeme - Novacare Ltd - NL', 'Nos', 387.0, 926000.0, 0.0, 0.0, 0.0, 0.0, 387.0, 926000.0, 2392.765, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Adolf Umoh Aniekeme - Novacare Ltd - NL', 'Nos', 35.0, 175000.0, 0.0, 0.0, 0.0, 0.0, 35.0, 175000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'ATP Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 30.0, 60000.0, 0.0, 0.0, 16.0, 32000.0, 14.0, 28000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'ATP Logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 23.0, 41400.0, 0.0, 0.0, 17.0, 30600.0, 6.0, 10800.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Steve temienor - Novacare Ltd - NL', 'Nos', 138.0, 269100.0, 0.0, 0.0, 54.0, 105300.0, 84.0, 163800.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Steve temienor - Novacare Ltd - NL', 'Nos', 26.0, 59800.0, 0.0, 0.0, 4.0, 9200.0, 22.0, 50600.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'FOMAX PH. LOGISTICS - Novacare Ltd - NL', 'Nos', 20.0, 36000.0, 0.0, 0.0, 0.0, 0.0, 20.0, 36000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Abutu Emmanuel - Novacare Ltd - NL', 'Nos', 42.0, 81900.0, 0.0, 0.0, 10.0, 19500.0, 32.0, 62400.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Abutu Emmanuel - Novacare Ltd - NL', 'Nos', 19.0, 43700.0, 0.0, 0.0, 5.0, 11500.0, 14.0, 32200.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'ATOMIC LOGISTICS EDO - Novacare Ltd - NL', 'Nos', 46.0, 92000.0, 0.0, 0.0, 20.0, 40000.0, 26.0, 52000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'ATOMIC LOGISTICS EDO - Novacare Ltd - NL', 'Nos', 49.0, 88200.0, 0.0, 0.0, 19.0, 34200.0, 30.0, 54000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Adekunle Logistic - Novacare Ltd - NL', 'Nos', 35.0, 68250.0, 0.0, 0.0, 6.0, 11700.0, 29.0, 56550.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Adekunle Logistic - Novacare Ltd - NL', 'Nos', 27.0, 62100.0, 0.0, 0.0, 0.0, 0.0, 27.0, 62100.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'SAGE LOGISTICS - Novacare Ltd - NL', 'Nos', 24.0, 48000.0, 0.0, 0.0, 21.0, 42000.0, 3.0, 6000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Eagles Frontier Logistics - Novacare Ltd - NL', 'Nos', 8.0, 15600.0, 0.0, 0.0, 4.0, 7800.0, 4.0, 7800.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Eagles Frontier Logistics - Novacare Ltd - NL', 'Nos', 22.0, 50600.0, 0.0, 0.0, 1.0, 2300.0, 21.0, 48300.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'PresteveGO Logistics - Novacare Ltd - NL', 'Nos', 33.0, 66000.0, 0.0, 0.0, 15.0, 30000.0, 18.0, 36000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'PresteveGO Logistics - Novacare Ltd - NL', 'Nos', 132.0, 389400.0, 320.0, 960000.0, 15.0, 44250.0, 437.0, 1305150.0, 2986.613, 0.0, 'Novacare Ltd')
ON CONFLICT (client_id, item_code, warehouse) DO UPDATE SET
    opening_qty = EXCLUDED.opening_qty,
    opening_value = EXCLUDED.opening_value,
    in_qty = EXCLUDED.in_qty,
    in_value = EXCLUDED.in_value,
    out_qty = EXCLUDED.out_qty,
    out_value = EXCLUDED.out_value,
    balance_qty = EXCLUDED.balance_qty,
    balance_value = EXCLUDED.balance_value,
    valuation_rate = EXCLUDED.valuation_rate,
    reserved_stock = EXCLUDED.reserved_stock,
    updated_at = NOW();


INSERT INTO public.client_stock_balances (
    client_id, item_code, item_name, item_group, warehouse, stock_uom,
    opening_qty, opening_value, in_qty, in_value, out_qty, out_value,
    balance_qty, balance_value, valuation_rate, reserved_stock, company
) VALUES
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'PresteveGO Logistics - Novacare Ltd - NL', 'Nos', 95.0, 178000.0, 0.0, 0.0, 1.0, 2000.0, 94.0, 176000.0, 1872.34, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'PresteveGO Logistics - Novacare Ltd - NL', 'Nos', 96.0, 192000.0, 0.0, 0.0, 0.0, 0.0, 96.0, 192000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'PresteveGO Logistics - Novacare Ltd - NL', 'Nos', 18.0, 90000.0, 0.0, 0.0, 0.0, 0.0, 18.0, 90000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'SAGE LOGISTICS - Novacare Ltd - NL', 'Nos', 30.0, 54000.0, 0.0, 0.0, 15.0, 27000.0, 15.0, 27000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Oluwatobi Femi-Fasan - Novacare Ltd - NL', 'Nos', -3.0, -5850.0, 0.0, 0.0, 33.0, 64350.0, -36.0, -70200.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Oluwatobi Femi-Fasan - Novacare Ltd - NL', 'Nos', 50.0, 115000.0, 0.0, 0.0, 1.0, 2300.0, 49.0, 112700.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Adeyemo Adeola LOGISTICS - Novacare Ltd - NL', 'Nos', 19.0, 38000.0, 0.0, 0.0, 0.0, 0.0, 19.0, 38000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Adeyemo Adeola LOGISTICS - Novacare Ltd - NL', 'Nos', 20.0, 36000.0, 0.0, 0.0, 0.0, 0.0, 20.0, 36000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'ISMAIL MUHAMMAD LIMAN - Novacare Ltd - NL', 'Nos', 67.0, 335000.0, 0.0, 0.0, 0.0, 0.0, 67.0, 335000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Solomon Uduak Ikpembe - Novacare Ltd - NL', 'Nos', 30.0, 150000.0, 0.0, 0.0, 0.0, 0.0, 30.0, 150000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Aruoriwo Adhuze - Novacare Ltd - NL', 'Nos', 13.0, 65000.0, 0.0, 0.0, 0.0, 0.0, 13.0, 65000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'RAPH XPRESS LOGISTICS - Novacare Ltd - NL', 'Nos', 18.0, 32400.0, 0.0, 0.0, 0.0, 0.0, 18.0, 32400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'SOLOPEE LOGISTCS - Novacare Ltd - NL', 'Nos', 306.0, 583024.86, 0.0, 0.0, 35.0, 66685.85, 271.0, 516339.01, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'SOLOPEE LOGISTCS - Novacare Ltd - NL', 'Nos', 47.0, 94000.0, 0.0, 0.0, 5.0, 10000.0, 42.0, 84000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'SOLOPEE LOGISTCS - Novacare Ltd - NL', 'Nos', 30.0, 54000.0, 0.0, 0.0, 6.0, 10800.0, 24.0, 43200.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'SOLOPEE LOGISTCS - Novacare Ltd - NL', 'Nos', 137.0, 404150.0, 320.0, 960000.0, 19.0, 56050.0, 438.0, 1308100.0, 2986.53, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'SOLOPEE LOGISTCS - Novacare Ltd - NL', 'Nos', 34.0, 170000.0, 0.0, 0.0, 0.0, 0.0, 34.0, 170000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Blessing Hezekiah - Novacare Ltd - NL', 'Nos', 17.0, 33150.0, 0.0, 0.0, 0.0, 0.0, 17.0, 33150.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Blessing Hezekiah - Novacare Ltd - NL', 'Nos', 30.0, 69000.0, 0.0, 0.0, 1.0, 2300.0, 29.0, 66700.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'ug express logistics ltd - Novacare Ltd - NL', 'Nos', 49.0, 245000.0, 0.0, 0.0, 0.0, 0.0, 49.0, 245000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'ATOMIC LOGISTICS EDO - Novacare Ltd - NL', 'Nos', 33.0, 165000.0, 0.0, 0.0, 0.0, 0.0, 33.0, 165000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'ug express logistic ebonyi - Novacare Ltd - NL', 'Nos', 232.0, 692400.0, 0.0, 0.0, 13.0, 38350.0, 219.0, 654050.0, 2986.53, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'ug express logistic ebonyi - Novacare Ltd - NL', 'Nos', 35.0, 175000.0, 0.0, 0.0, 0.0, 0.0, 35.0, 175000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'ug express logistic ebonyi - Novacare Ltd - NL', 'Nos', 60.0, 120000.0, 0.0, 0.0, 5.0, 10000.0, 55.0, 110000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'ug express logistic ebonyi - Novacare Ltd - NL', 'Nos', 60.0, 108000.0, 0.0, 0.0, 5.0, 9000.0, 55.0, 99000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Gimway Concept - Novacare Ltd - NL', 'Nos', 376.0, 716396.56, 0.0, 0.0, 175.0, 333429.25, 201.0, 382967.31, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Gimway Concept - Novacare Ltd - NL', 'Nos', 58.0, 171100.0, 0.0, 0.0, 45.0, 132750.0, 13.0, 38350.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Gimway Concept - Novacare Ltd - NL', 'Nos', 15.0, 75000.0, 0.0, 0.0, 0.0, 0.0, 15.0, 75000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'SAGE LOGISTICS - Novacare Ltd - NL', 'Nos', 45.0, 225000.0, 0.0, 0.0, 0.0, 0.0, 45.0, 225000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Steve temienor - Novacare Ltd - NL', 'Nos', -240.0, -5160000.0, 0.0, 0.0, 0.0, 0.0, -240.0, -5160000.0, 21500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Davtom Logistics - Novacare Ltd - NL', 'Nos', 70.0, 136500.0, 0.0, 0.0, 0.0, 0.0, 70.0, 136500.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Davtom Logistics - Novacare Ltd - NL', 'Nos', 30.0, 69000.0, 0.0, 0.0, 0.0, 0.0, 30.0, 69000.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Daniel Ekpo - Novacare Ltd - NL', 'Nos', 71.0, 138450.0, 0.0, 0.0, 12.0, 23400.0, 59.0, 115050.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Daniel Ekpo - Novacare Ltd - NL', 'Nos', 28.0, 64400.0, 0.0, 0.0, 2.0, 4600.0, 26.0, 59800.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'Sabi logistics - Novacare Ltd - NL', 'Nos', 122.0, 232447.82, 0.0, 0.0, 45.0, 85738.95, 77.0, 146708.87, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'Sabi logistics - Novacare Ltd - NL', 'Nos', 68.0, 204000.0, 320.0, 960000.0, 43.0, 129000.0, 345.0, 1035000.0, 3000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'Sabi logistics - Novacare Ltd - NL', 'Nos', 18.0, 90000.0, 0.0, 0.0, 0.0, 0.0, 18.0, 90000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Sabi logistics - Novacare Ltd - NL', 'Nos', 40.0, 80000.0, 0.0, 0.0, 2.0, 4000.0, 38.0, 76000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Sabi logistics - Novacare Ltd - NL', 'Nos', 35.0, 63000.0, 0.0, 0.0, 7.0, 12600.0, 28.0, 50400.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'Fomax logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 693.0, 1351350.0, 0.0, 0.0, 135.0, 263250.0, 558.0, 1088100.0, 1950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'Fomax logistics LOGISTICS - Novacare Ltd - NL', 'Nos', 295.0, 678500.0, 0.0, 0.0, 1.0, 2300.0, 294.0, 676200.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'ATOMIC LOGISTICS EDO - Novacare Ltd - NL', 'Nos', 40.0, 140000.0, 0.0, 0.0, 0.0, 0.0, 40.0, 140000.0, 3500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'SOLOPEE LOGISTCS - Novacare Ltd - NL', 'Nos', 40.0, 140000.0, 0.0, 0.0, 0.0, 0.0, 40.0, 140000.0, 3500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'imole logistics - Novacare Ltd - NL', 'Nos', 40.0, 140000.0, 0.0, 0.0, 0.0, 0.0, 40.0, 140000.0, 3500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'ug express logistic ebonyi - Novacare Ltd - NL', 'Nos', 40.0, 140000.0, 0.0, 0.0, 0.0, 0.0, 40.0, 140000.0, 3500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'groza logistics ltd - Novacare Ltd - NL', 'Nos', 40.0, 140000.0, 0.0, 0.0, 0.0, 0.0, 40.0, 140000.0, 3500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'Gimway Concept - Novacare Ltd - NL', 'Nos', 20.0, 40000.0, 0.0, 0.0, 2.0, 4000.0, 18.0, 36000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'Gimway Concept - Novacare Ltd - NL', 'Nos', 20.0, 36000.0, 0.0, 0.0, 0.0, 0.0, 20.0, 36000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'Gimway Concept - Novacare Ltd - NL', 'Nos', 40.0, 140000.0, 0.0, 0.0, 0.0, 0.0, 40.0, 140000.0, 3500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'byke messengers logistic - Novacare Ltd - NL', 'Nos', 40.0, 140000.0, 0.0, 0.0, 0.0, 0.0, 40.0, 140000.0, 3500.0, 0.0, 'Novacare Ltd')
ON CONFLICT (client_id, item_code, warehouse) DO UPDATE SET
    opening_qty = EXCLUDED.opening_qty,
    opening_value = EXCLUDED.opening_value,
    in_qty = EXCLUDED.in_qty,
    in_value = EXCLUDED.in_value,
    out_qty = EXCLUDED.out_qty,
    out_value = EXCLUDED.out_value,
    balance_qty = EXCLUDED.balance_qty,
    balance_value = EXCLUDED.balance_value,
    valuation_rate = EXCLUDED.valuation_rate,
    reserved_stock = EXCLUDED.reserved_stock,
    updated_at = NOW();


INSERT INTO public.client_stock_balances (
    client_id, item_code, item_name, item_group, warehouse, stock_uom,
    opening_qty, opening_value, in_qty, in_value, out_qty, out_value,
    balance_qty, balance_value, valuation_rate, reserved_stock, company
) VALUES
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'milly logistics - Novacare Ltd - NL', 'Nos', 237.0, 474000.0, 0.0, 0.0, 31.0, 62000.0, 206.0, 412000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'milly logistics - Novacare Ltd - NL', 'Nos', 155.0, 775000.0, 0.0, 0.0, 0.0, 0.0, 155.0, 775000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'milly logistics - Novacare Ltd - NL', 'Nos', 44.0, 220000.0, 0.0, 0.0, 0.0, 0.0, 44.0, 220000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHB', 'Grazer Herbal Balm', 'Novacare', 'milly logistics - Novacare Ltd - NL', 'Nos', 65.0, 117000.0, 0.0, 0.0, 0.0, 0.0, 65.0, 117000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CVT', 'Clear Vision Tea', 'Novacare', 'milly logistics - Novacare Ltd - NL', 'Nos', 6.0, 12000.0, 0.0, 0.0, 0.0, 0.0, 6.0, 12000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'milly logistics - Novacare Ltd - NL', 'Nos', 240.0, 708000.0, 0.0, 0.0, 29.0, 85550.0, 211.0, 622450.0, 2950.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'milly logistics - Novacare Ltd - NL', 'Nos', 32.0, 64000.0, 0.0, 0.0, 1.0, 2000.0, 31.0, 62000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'milly logistics - Novacare Ltd - NL', 'Nos', 20.0, 40000.0, 0.0, 0.0, 1.0, 2000.0, 19.0, 38000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HGO', 'Hair Growth Oil', 'Novacare', 'milly logistics - Novacare Ltd - NL', 'Nos', 74.0, 140600.0, 0.0, 0.0, 0.0, 0.0, 74.0, 140600.0, 1900.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-OC', 'ORAVITA CAPSULE', 'Leafora', 'milly logistics - Novacare Ltd - NL', 'Nos', -7.0, -16100.0, 0.0, 0.0, 17.0, 39100.0, -24.0, -55200.0, 2300.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-GHT', 'Grazer Herbal Tea', 'Novacare', 'yusuf joy - Novacare Ltd - NL', 'Nos', 160.0, 304849.6, 0.0, 0.0, 3.0, 5715.93, 157.0, 299133.67, 1905.31, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-UCT', 'Ura Clear Tea', 'Novacare', 'yusuf joy - Novacare Ltd - NL', 'Nos', 160.0, 480000.0, 0.0, 0.0, 2.0, 6000.0, 158.0, 474000.0, 3000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-AMHT', 'ALPHA MAN HERBAL TEA', 'Novacare', 'yusuf joy - Novacare Ltd - NL', 'Nos', 15.0, 30000.0, 0.0, 0.0, 0.0, 0.0, 15.0, 30000.0, 2000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-RLT', 'RESPIRA LUNG TEA', 'Novacare', 'yusuf joy - Novacare Ltd - NL', 'Nos', 15.0, 27000.0, 0.0, 0.0, 0.0, 0.0, 15.0, 27000.0, 1800.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-CV', 'Compression Vest', 'Novacare', 'yusuf joy - Novacare Ltd - NL', 'Nos', 40.0, 140000.0, 0.0, 0.0, 0.0, 0.0, 40.0, 140000.0, 3500.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-HDS', 'Hair Dye Shampoo', 'Novacare', 'yusuf joy - Novacare Ltd - NL', 'Nos', 35.0, 175000.0, 0.0, 0.0, 0.0, 0.0, 35.0, 175000.0, 5000.0, 0.0, 'Novacare Ltd'),
    ('33333333-3333-4333-8333-333333333333', 'SKU-VHT', 'VELORA HERBAL TEA', 'Leafora', 'milly logistics - Novacare Ltd - NL', 'Nos', 0.0, 0.0, 0.0, 0.0, 1.0, 1950.0, -1.0, -1950.0, 1950.0, 0.0, 'Novacare Ltd')
ON CONFLICT (client_id, item_code, warehouse) DO UPDATE SET
    opening_qty = EXCLUDED.opening_qty,
    opening_value = EXCLUDED.opening_value,
    in_qty = EXCLUDED.in_qty,
    in_value = EXCLUDED.in_value,
    out_qty = EXCLUDED.out_qty,
    out_value = EXCLUDED.out_value,
    balance_qty = EXCLUDED.balance_qty,
    balance_value = EXCLUDED.balance_value,
    valuation_rate = EXCLUDED.valuation_rate,
    reserved_stock = EXCLUDED.reserved_stock,
    updated_at = NOW();



-- =================== 20260920120000_client_brand_identity_and_theming.sql ===================
-- ============================================================================
-- Migration: 20260920120000_client_brand_identity_and_theming.sql
-- Description: Adds Merchant Brand Identity & Dynamic Theming fields to clients
--              table (logo, primary, secondary, accent colors, theme JSONB).
-- ============================================================================

ALTER TABLE public.clients
  ADD COLUMN IF NOT EXISTS logo_url TEXT,
  ADD COLUMN IF NOT EXISTS brand_color_primary TEXT DEFAULT '#0D9488',
  ADD COLUMN IF NOT EXISTS brand_color_secondary TEXT DEFAULT '#1E293B',
  ADD COLUMN IF NOT EXISTS brand_color_accent TEXT DEFAULT '#F59E0B',
  ADD COLUMN IF NOT EXISTS brand_theme JSONB DEFAULT '{"primary": "#0D9488", "secondary": "#1E293B", "accent": "#F59E0B"}'::jsonb;

-- Backfill or update Novacare Ltd with signature wellness emerald green brand theme
UPDATE public.clients
SET 
  logo_url = COALESCE(logo_url, 'https://cdn-icons-png.flaticon.com/512/2966/2966327.png'),
  brand_color_primary = COALESCE(brand_color_primary, '#0D9488'),
  brand_color_secondary = COALESCE(brand_color_secondary, '#031632'),
  brand_color_accent = COALESCE(brand_color_accent, '#10B981'),
  brand_theme = jsonb_build_object(
    'primary', COALESCE(brand_color_primary, '#0D9488'),
    'secondary', COALESCE(brand_color_secondary, '#031632'),
    'accent', COALESCE(brand_color_accent, '#10B981'),
    'preset_name', 'Novacare Emerald'
  )
WHERE company_name ILIKE '%novacare%' OR company_name ILIKE '%novacale%';


-- =================== 20260920130000_inventory_lifecycle_ledger_and_date_range_balancing.sql ===================
-- ============================================================================
-- NOVAXPRESS LOGISTICS PLATFORM
-- Migration: 20260920130000_inventory_lifecycle_ledger_and_date_range_balancing.sql
-- Description:
--   1. Create client_stock_ledger_entries table (immutable transaction audit trail)
--   2. Ensure orders table has source_warehouse, paid_quantity, and free_quantity
--   3. Seed initial baseline ledger entries from client_stock_balances
--   4. Update fn_process_client_stock_intake_invoice to log purchase receipts in ledger
--   5. Update fn_confirm_order_delivery_stock to deduct physical client stock & log delivery in ledger
--   6. Create fn_get_client_stock_balance_period RPC for dynamic opening/closing balance over date range
--   7. Update fn_generate_merchant_daily_settlement to balance COGS and gross margin
-- ============================================================================

-- 1. Ensure orders has source_warehouse, paid_quantity, free_quantity
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'source_warehouse'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN source_warehouse TEXT DEFAULT 'Stores - NL';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'paid_quantity'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN paid_quantity INT DEFAULT 1;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'free_quantity'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN free_quantity INT DEFAULT 0;
    END IF;
END $$;

-- 2. Create client_stock_ledger_entries table
CREATE TABLE IF NOT EXISTS public.client_stock_ledger_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id TEXT NOT NULL,
    warehouse TEXT NOT NULL,
    item_code TEXT NOT NULL,
    item_name TEXT NOT NULL,
    item_group TEXT DEFAULT 'Novacare',
    voucher_type TEXT NOT NULL CHECK (voucher_type IN ('baseline_seed', 'purchase_receipt', 'sales_order_delivery', 'stock_transfer', 'stock_return', 'inventory_adjustment')),
    voucher_no TEXT,
    order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL,
    invoice_id UUID REFERENCES public.client_stock_invoices(id) ON DELETE SET NULL,
    posting_date DATE NOT NULL DEFAULT CURRENT_DATE,
    posting_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    qty_change NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    incoming_qty NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    outgoing_qty NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    valuation_rate NUMERIC(14, 4) NOT NULL DEFAULT 0.0000,
    total_value NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_stock_ledger_client ON public.client_stock_ledger_entries(client_id);
CREATE INDEX IF NOT EXISTS idx_stock_ledger_item ON public.client_stock_ledger_entries(item_code);
CREATE INDEX IF NOT EXISTS idx_stock_ledger_warehouse ON public.client_stock_ledger_entries(warehouse);
CREATE INDEX IF NOT EXISTS idx_stock_ledger_posting_date ON public.client_stock_ledger_entries(posting_date);
CREATE INDEX IF NOT EXISTS idx_stock_ledger_voucher ON public.client_stock_ledger_entries(voucher_type, voucher_no);

-- 3. Seed initial baseline ledger entries from client_stock_balances
INSERT INTO public.client_stock_ledger_entries (
    client_id,
    warehouse,
    item_code,
    item_name,
    item_group,
    voucher_type,
    voucher_no,
    posting_date,
    posting_at,
    qty_change,
    incoming_qty,
    outgoing_qty,
    valuation_rate,
    total_value,
    notes
)
SELECT 
    b.client_id,
    b.warehouse,
    b.item_code,
    b.item_name,
    COALESCE(b.item_group, 'Novacare'),
    'baseline_seed',
    'SEED-PANGEA-20260901',
    DATE '2026-09-01',
    TIMESTAMPTZ '2026-09-01 00:00:00+01',
    COALESCE(b.opening_qty, b.balance_qty, 0.00),
    COALESCE(b.opening_qty, b.balance_qty, 0.00),
    0.00,
    COALESCE(b.valuation_rate, 0.0000),
    COALESCE(b.opening_value, b.balance_value, 0.00),
    'Baseline inventory migration snapshot from Pangea Suite'
FROM public.client_stock_balances b
WHERE NOT EXISTS (
    SELECT 1 FROM public.client_stock_ledger_entries l
    WHERE l.client_id = b.client_id 
      AND l.warehouse = b.warehouse 
      AND l.item_code = b.item_code 
      AND l.voucher_type = 'baseline_seed'
);

-- Seed any verified intake invoices as purchase receipts if not present
INSERT INTO public.client_stock_ledger_entries (
    client_id,
    warehouse,
    item_code,
    item_name,
    item_group,
    voucher_type,
    voucher_no,
    invoice_id,
    posting_date,
    posting_at,
    qty_change,
    incoming_qty,
    outgoing_qty,
    valuation_rate,
    total_value,
    notes
)
SELECT 
    inv.client_id,
    inv.destination_warehouse,
    item.product_sku,
    item.product_name,
    'Novacare',
    'purchase_receipt',
    inv.invoice_number,
    inv.id,
    inv.entry_date,
    inv.created_at,
    item.quantity,
    item.quantity,
    0.00,
    item.effective_landed_cost_per_unit,
    item.total_landed_cost,
    'Supplier intake verification from ' || inv.supplier_name
FROM public.client_stock_invoices inv
JOIN public.client_stock_invoice_items item ON item.invoice_id = inv.id
WHERE inv.status = 'verified'
  AND NOT EXISTS (
    SELECT 1 FROM public.client_stock_ledger_entries l
    WHERE l.invoice_id = inv.id AND l.item_code = item.product_sku
);

-- 4. Update fn_process_client_stock_intake_invoice to write to client_stock_ledger_entries
CREATE OR REPLACE FUNCTION public.fn_process_client_stock_intake_invoice(p_invoice_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_inv RECORD;
    v_item RECORD;
    v_cur_bal RECORD;
    v_new_bal_qty NUMERIC;
    v_new_valuation NUMERIC;
BEGIN
    SELECT * INTO v_inv FROM public.client_stock_invoices WHERE id = p_invoice_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Invoice not found');
    END IF;

    -- Process each item in the intake invoice
    FOR v_item IN SELECT * FROM public.client_stock_invoice_items WHERE invoice_id = p_invoice_id LOOP
        SELECT * INTO v_cur_bal 
        FROM public.client_stock_balances
        WHERE client_id = v_inv.client_id
          AND (item_code = v_item.product_sku OR item_name = v_item.product_name)
          AND warehouse = v_inv.destination_warehouse;

        IF FOUND THEN
            v_new_bal_qty := v_cur_bal.balance_qty + v_item.quantity;
            IF v_new_bal_qty > 0 THEN
                v_new_valuation := ((v_cur_bal.balance_qty * v_cur_bal.valuation_rate) + (v_item.quantity * v_item.effective_landed_cost_per_unit)) / v_new_bal_qty;
            ELSE
                v_new_valuation := v_item.effective_landed_cost_per_unit;
            END IF;

            UPDATE public.client_stock_balances
            SET in_qty = in_qty + v_item.quantity,
                in_value = in_value + v_item.total_landed_cost,
                balance_qty = balance_qty + v_item.quantity,
                balance_value = (balance_qty + v_item.quantity) * v_new_valuation,
                valuation_rate = v_new_valuation,
                last_entry_invoice_id = p_invoice_id,
                updated_at = NOW()
            WHERE id = v_cur_bal.id;
        ELSE
            v_new_valuation := v_item.effective_landed_cost_per_unit;
            INSERT INTO public.client_stock_balances (
                client_id,
                product_id,
                item_code,
                item_name,
                warehouse,
                stock_uom,
                opening_qty,
                opening_value,
                in_qty,
                in_value,
                out_qty,
                out_value,
                balance_qty,
                balance_value,
                valuation_rate,
                reserved_stock,
                last_entry_invoice_id
            ) VALUES (
                v_inv.client_id,
                v_item.product_id,
                v_item.product_sku,
                v_item.product_name,
                v_inv.destination_warehouse,
                'Nos',
                0,
                0,
                v_item.quantity,
                v_item.total_landed_cost,
                0,
                0,
                v_item.quantity,
                v_item.total_landed_cost,
                v_new_valuation,
                0,
                p_invoice_id
            );
        END IF;

        -- Write immutable record to client_stock_ledger_entries
        INSERT INTO public.client_stock_ledger_entries (
            client_id,
            warehouse,
            item_code,
            item_name,
            voucher_type,
            voucher_no,
            invoice_id,
            posting_date,
            posting_at,
            qty_change,
            incoming_qty,
            outgoing_qty,
            valuation_rate,
            total_value,
            notes
        ) VALUES (
            v_inv.client_id,
            v_inv.destination_warehouse,
            v_item.product_sku,
            v_item.product_name,
            'purchase_receipt',
            v_inv.invoice_number,
            p_invoice_id,
            v_inv.entry_date,
            NOW(),
            v_item.quantity,
            v_item.quantity,
            0,
            v_new_valuation,
            v_item.total_landed_cost,
            'Verified Stock Intake from ' || v_inv.supplier_name
        );

        -- Synchronize global catalog products count & cost price
        UPDATE public.products
        SET stock_quantity = COALESCE(stock_quantity, 0) + v_item.quantity,
            available_count = COALESCE(available_count, 0) + v_item.quantity,
            cost_price = v_new_valuation,
            base_price = CASE WHEN base_price <= 0 THEN v_item.target_retail_price ELSE base_price END,
            updated_at = NOW()
        WHERE name = v_item.product_name OR sku = v_item.product_sku;
    END LOOP;

    -- Mark invoice status as verified
    UPDATE public.client_stock_invoices
    SET status = 'verified',
        updated_at = NOW()
    WHERE id = p_invoice_id;

    RETURN jsonb_build_object('success', true, 'invoice_id', p_invoice_id);
END;
$$;

-- 5. Upgrade fn_confirm_order_delivery_stock to deduct physical stock from client_stock_balances
CREATE OR REPLACE FUNCTION public.fn_confirm_order_delivery_stock(
    p_order_id UUID,
    p_agent_id UUID,
    p_product_id UUID,
    p_physical_quantity INT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_qty INT := GREATEST(1, COALESCE(p_physical_quantity, 1));
    v_agent RECORD;
    v_order RECORD;
    v_bal RECORD;
    v_wh TEXT := 'Stores - NL';
    v_item_code TEXT;
    v_item_name TEXT;
    v_val_rate NUMERIC(14, 4) := 0.0000;
BEGIN
    SELECT * INTO v_agent FROM public.delivery_agents WHERE id = p_agent_id OR user_id = p_agent_id;
    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;

    -- 1. Deduct physical units from rider custody in agent_inventory
    IF v_agent IS NOT NULL AND p_product_id IS NOT NULL THEN
        UPDATE public.agent_inventory
        SET available_count = GREATEST(0, COALESCE(available_count, 0) - v_qty),
            total_in_custody = GREATEST(0, COALESCE(total_in_custody, 0) - v_qty),
            delivered_count_today = COALESCE(delivered_count_today, 0) + v_qty,
            updated_at = NOW()
        WHERE delivery_agent_id = v_agent.id AND product_id = p_product_id;
    END IF;

    -- 2. Increment delivered metrics on product
    IF p_product_id IS NOT NULL THEN
        UPDATE public.products
        SET delivered_count = COALESCE(delivered_count, 0) + v_qty,
            updated_at = NOW()
        WHERE id = p_product_id;
    END IF;

    -- 3. Balance Merchant Physical Inventory in client_stock_balances
    IF v_order IS NOT NULL AND v_order.client_id IS NOT NULL THEN
        v_wh := COALESCE(v_order.source_warehouse, 'Stores - NL');
        v_item_name := COALESCE(v_order.product_name, 'Standard Product');

        -- Match stock balance record
        SELECT * INTO v_bal FROM public.client_stock_balances
        WHERE client_id = v_order.client_id::TEXT
          AND (item_name = v_item_name OR product_id = p_product_id::TEXT)
        ORDER BY CASE WHEN warehouse = v_wh THEN 1 ELSE 2 END, balance_qty DESC
        LIMIT 1;

        IF v_bal IS NOT NULL THEN
            v_val_rate := COALESCE(v_bal.valuation_rate, 0.0000);
            v_item_code := v_bal.item_code;
            v_wh := v_bal.warehouse;

            UPDATE public.client_stock_balances
            SET out_qty = out_qty + v_qty,
                out_value = out_value + (v_qty * v_val_rate),
                balance_qty = GREATEST(0, balance_qty - v_qty),
                balance_value = GREATEST(0, (balance_qty - v_qty) * v_val_rate),
                updated_at = NOW()
            WHERE id = v_bal.id;

            -- Log transaction to client_stock_ledger_entries
            INSERT INTO public.client_stock_ledger_entries (
                client_id,
                warehouse,
                item_code,
                item_name,
                item_group,
                voucher_type,
                voucher_no,
                order_id,
                posting_date,
                posting_at,
                qty_change,
                incoming_qty,
                outgoing_qty,
                valuation_rate,
                total_value,
                notes
            ) VALUES (
                v_order.client_id::TEXT,
                v_wh,
                v_item_code,
                v_item_name,
                COALESCE(v_bal.item_group, 'Novacare'),
                'sales_order_delivery',
                v_order.order_number,
                p_order_id,
                CURRENT_DATE,
                NOW(),
                -v_qty,
                0,
                v_qty,
                v_val_rate,
                v_qty * v_val_rate,
                'Order fulfillment delivered by rider ' || COALESCE(v_order.delivery_agent_name, 'Rider')
            );
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'deducted_quantity', v_qty,
        'warehouse', v_wh,
        'valuation_rate', v_val_rate
    );
END;
$$;

-- 6. Create fn_get_client_stock_balance_period RPC
-- Dynamically calculates opening stock, period receipts, period issues, and closing balance
CREATE OR REPLACE FUNCTION public.fn_get_client_stock_balance_period(
    p_client_id TEXT,
    p_start_date DATE DEFAULT DATE '2026-09-01',
    p_end_date DATE DEFAULT CURRENT_DATE,
    p_warehouse TEXT DEFAULT 'All Warehouses',
    p_item_group TEXT DEFAULT 'All Item Groups'
)
RETURNS TABLE (
    id UUID,
    client_id TEXT,
    product_id TEXT,
    item_code TEXT,
    item_name TEXT,
    item_group TEXT,
    warehouse TEXT,
    stock_uom TEXT,
    opening_qty NUMERIC(14, 2),
    opening_value NUMERIC(14, 2),
    in_qty NUMERIC(14, 2),
    in_value NUMERIC(14, 2),
    out_qty NUMERIC(14, 2),
    out_value NUMERIC(14, 2),
    balance_qty NUMERIC(14, 2),
    balance_value NUMERIC(14, 2),
    valuation_rate NUMERIC(14, 4),
    reserved_stock NUMERIC(14, 2),
    company TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH base_positions AS (
        SELECT 
            b.id AS bal_id,
            b.client_id,
            b.product_id,
            b.item_code,
            b.item_name,
            COALESCE(b.item_group, 'Novacare') AS item_group,
            b.warehouse,
            COALESCE(b.stock_uom, 'Nos') AS stock_uom,
            COALESCE(b.valuation_rate, 0.0000) AS valuation_rate,
            COALESCE(b.reserved_stock, 0.00) AS reserved_stock,
            COALESCE(b.company, 'Novacare Ltd') AS company,
            b.opening_qty AS static_opening_qty,
            b.balance_qty AS static_balance_qty
        FROM public.client_stock_balances b
        WHERE (b.client_id = p_client_id OR p_client_id = 'all')
          AND (p_warehouse = 'All Warehouses' OR b.warehouse = p_warehouse)
          AND (p_item_group = 'All Item Groups' OR b.item_group = p_item_group)
    ),
    ledger_agg AS (
        SELECT 
            l.client_id,
            l.warehouse,
            l.item_code,
            -- Opening is all movement prior to start_date
            COALESCE(SUM(CASE WHEN l.posting_date < p_start_date THEN l.qty_change ELSE 0 END), 0.00) AS calc_prior_delta,
            -- Incoming during the date range
            COALESCE(SUM(CASE WHEN l.posting_date BETWEEN p_start_date AND p_end_date THEN l.incoming_qty ELSE 0 END), 0.00) AS calc_in_qty,
            -- Outgoing during the date range
            COALESCE(SUM(CASE WHEN l.posting_date BETWEEN p_start_date AND p_end_date THEN l.outgoing_qty ELSE 0 END), 0.00) AS calc_out_qty
        FROM public.client_stock_ledger_entries l
        WHERE (l.client_id = p_client_id OR p_client_id = 'all')
        GROUP BY l.client_id, l.warehouse, l.item_code
    )
    SELECT 
        bp.bal_id AS id,
        bp.client_id,
        bp.product_id,
        bp.item_code,
        bp.item_name,
        bp.item_group,
        bp.warehouse,
        bp.stock_uom,
        -- If ledger has historical entries before start date, use them; otherwise fallback to static baseline
        ROUND(COALESCE(NULLIF(la.calc_prior_delta, 0), bp.static_opening_qty, 0.00), 2) AS opening_qty,
        ROUND((COALESCE(NULLIF(la.calc_prior_delta, 0), bp.static_opening_qty, 0.00) * bp.valuation_rate), 2) AS opening_value,
        ROUND(COALESCE(la.calc_in_qty, 0.00), 2) AS in_qty,
        ROUND((COALESCE(la.calc_in_qty, 0.00) * bp.valuation_rate), 2) AS in_value,
        ROUND(COALESCE(la.calc_out_qty, 0.00), 2) AS out_qty,
        ROUND((COALESCE(la.calc_out_qty, 0.00) * bp.valuation_rate), 2) AS out_value,
        ROUND(
            (COALESCE(NULLIF(la.calc_prior_delta, 0), bp.static_opening_qty, 0.00) + COALESCE(la.calc_in_qty, 0.00) - COALESCE(la.calc_out_qty, 0.00)), 
            2
        ) AS balance_qty,
        ROUND(
            (COALESCE(NULLIF(la.calc_prior_delta, 0), bp.static_opening_qty, 0.00) + COALESCE(la.calc_in_qty, 0.00) - COALESCE(la.calc_out_qty, 0.00)) * bp.valuation_rate, 
            2
        ) AS balance_value,
        bp.valuation_rate,
        bp.reserved_stock,
        bp.company
    FROM base_positions bp
    LEFT JOIN ledger_agg la 
      ON la.client_id = bp.client_id 
     AND la.warehouse = bp.warehouse 
     AND la.item_code = bp.item_code
    ORDER BY bp.warehouse, bp.item_name;
END;
$$;

-- Grant permissions to authenticated, anon, service_role
GRANT SELECT, INSERT, UPDATE, DELETE ON public.client_stock_ledger_entries TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_process_client_stock_intake_invoice(UUID) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_confirm_order_delivery_stock(UUID, UUID, UUID, INT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_get_client_stock_balance_period(TEXT, DATE, DATE, TEXT, TEXT) TO authenticated, service_role, anon;


-- =================== 20260920140000_harden_asset_custody_and_settlement_rules.sql ===================
-- Migration: 20260920140000_harden_asset_custody_and_settlement_rules.sql
-- Description:
-- 1. Upgrades fn_calculate_merchant_asset_custody to dynamically read client's custom_delivery_fee and deduct failed delivery fees.
-- 2. Upgrades fn_generate_merchant_daily_settlement to include all failed delivery statuses ('failed', 'cancelled', 'rejected', 'customer_rejected').

-- 1. fn_calculate_merchant_asset_custody
CREATE OR REPLACE FUNCTION public.fn_calculate_merchant_asset_custody(
    p_client_id UUID,
    p_dc_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_cash_in_paystack NUMERIC(14, 2) := 0.00;
    v_cash_in_dc_vault NUMERIC(14, 2) := 0.00;
    v_total_liquid_cash NUMERIC(14, 2) := 0.00;
    v_total_units_in_custody INT := 0;
    v_base_inventory_valuation NUMERIC(14, 2) := 0.00;
    v_weighted_retail_valuation NUMERIC(14, 2) := 0.00;
    v_prod RECORD;
    v_client RECORD;
    v_delivery_fee NUMERIC(14, 2) := 5000.00;
    v_failed_fee NUMERIC(14, 2) := 500.00;
    v_failed_orders_count INT := 0;
    v_failed_charges NUMERIC(14, 2) := 0.00;
BEGIN
    -- Look up client settings
    SELECT custom_delivery_fee, custom_failed_attempt_fee
    INTO v_client
    FROM public.clients
    WHERE id = p_client_id;

    IF FOUND THEN
        IF v_client.custom_delivery_fee IS NOT NULL AND v_client.custom_delivery_fee > 0 THEN
            v_delivery_fee := v_client.custom_delivery_fee;
        END IF;
        IF v_client.custom_failed_attempt_fee IS NOT NULL AND v_client.custom_failed_attempt_fee > 0 THEN
            v_failed_fee := v_client.custom_failed_attempt_fee;
        END IF;
    END IF;

    -- 1. Liquid Cash in Custody (Delivered orders awaiting 10 PM Closeout)
    SELECT 
        COALESCE(SUM(CASE WHEN COALESCE(payment_method, delivery_method, 'cash') = 'paystack' OR payment_type = 'prepaid' THEN (total_amount - COALESCE(client_delivery_fee, v_delivery_fee)) ELSE 0 END), 0.00),
        COALESCE(SUM(CASE WHEN COALESCE(payment_method, delivery_method, 'cash') = 'cash' AND payment_type = 'pay_on_delivery' THEN (total_amount - COALESCE(client_delivery_fee, v_delivery_fee)) ELSE 0 END), 0.00)
    INTO v_cash_in_paystack, v_cash_in_dc_vault
    FROM public.orders
    WHERE client_id = p_client_id
      AND status = 'delivered'
      AND (financial_settlement_status IS NULL OR financial_settlement_status != 'client_settled')
      AND (p_dc_id IS NULL OR distribution_center_id = p_dc_id);

    -- Deduct pending failed delivery attempt fees from unsettled failed/cancelled orders
    SELECT COUNT(*) INTO v_failed_orders_count
    FROM public.orders
    WHERE client_id = p_client_id
      AND status IN ('failed', 'cancelled', 'rejected', 'customer_rejected')
      AND (financial_settlement_status IS NULL OR financial_settlement_status != 'client_settled')
      AND (p_dc_id IS NULL OR distribution_center_id = p_dc_id);

    v_failed_charges := v_failed_orders_count * v_failed_fee;
    v_total_liquid_cash := GREATEST(0.00, (v_cash_in_paystack + v_cash_in_dc_vault) - v_failed_charges);

    -- 2. In-Kind Inventory Custody & Dual Valuation
    FOR v_prod IN
        SELECT id, name, sku, base_price, stock_quantity, available_count
        FROM public.products
        WHERE client_id = p_client_id OR client_name IN (SELECT company_name FROM public.clients WHERE id = p_client_id)
    LOOP
        DECLARE
            v_units INT := COALESCE(v_prod.stock_quantity, v_prod.available_count, 0);
            v_avg_price NUMERIC(14, 2);
        BEGIN
            v_total_units_in_custody := v_total_units_in_custody + v_units;
            v_base_inventory_valuation := v_base_inventory_valuation + (v_units * COALESCE(v_prod.base_price, 25000.00));

            -- Calculate historical realized unit price factoring in package deals
            SELECT COALESCE(AVG(total_amount / NULLIF(quantity, 0)), v_prod.base_price, 25000.00)
            INTO v_avg_price
            FROM public.orders
            WHERE client_id = p_client_id AND product_name = v_prod.name AND status = 'delivered';

            v_weighted_retail_valuation := v_weighted_retail_valuation + (v_units * v_avg_price);
        END;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'client_id', p_client_id,
        'liquid_cash_in_custody', v_total_liquid_cash,
        'physical_cod_in_dc_vault', v_cash_in_dc_vault,
        'direct_transfer_in_paystack', v_cash_in_paystack,
        'failed_delivery_surcharges', v_failed_charges,
        'total_inventory_units_held', v_total_units_in_custody,
        'inventory_baseline_liquidation_value', v_base_inventory_valuation,
        'inventory_estimated_retail_value', v_weighted_retail_valuation,
        'grand_total_asset_value', (v_total_liquid_cash + v_weighted_retail_valuation)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_calculate_merchant_asset_custody(UUID, UUID) TO authenticated, service_role, anon;

-- 2. fn_generate_merchant_daily_settlement (with updated failed status inclusion)
CREATE OR REPLACE FUNCTION public.fn_generate_merchant_daily_settlement(
    p_client_id UUID,
    p_dc_id UUID DEFAULT NULL,
    p_period_start TIMESTAMPTZ DEFAULT NULL,
    p_period_end TIMESTAMPTZ DEFAULT NULL,
    p_custom_deductions JSONB DEFAULT '{}'::jsonb,
    p_order_ids UUID[] DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_settlement_id UUID := gen_random_uuid();
    v_settlement_number TEXT;
    v_today_seq INT;
    v_client RECORD;
    v_dc_settings RECORD;
    
    -- Calculated Totals
    v_orders_count INT := 0;
    v_gross_collections NUMERIC(14, 2) := 0.00;
    v_delivery_fees NUMERIC(14, 2) := 0.00;
    v_failed_attempt_fees NUMERIC(14, 2) := 0.00;
    v_system_operation_fees NUMERIC(14, 2) := 0.00;
    v_gateway_fees NUMERIC(14, 2) := 0.00;
    v_other_charges NUMERIC(14, 2) := 0.00;
    v_total_platform_charges NUMERIC(14, 2) := 0.00;
    v_total_deductions NUMERIC(14, 2) := 0.00;
    v_net_payout NUMERIC(14, 2) := 0.00;
    
    -- Rates & intermediate vars
    v_order_delivery_fee NUMERIC(14, 2);
    v_order_platform_fee NUMERIC(14, 2);
    v_order_gateway_fee NUMERIC(14, 2);
    v_unit_failed_fee NUMERIC(14, 2);
    v_failed_orders_count INT := 0;
    v_charges_breakdown JSONB;
    
    v_order RECORD;
    v_order_ids_array UUID[] := '{}';
    v_eff_period_start TIMESTAMPTZ;
    v_eff_period_end TIMESTAMPTZ;
BEGIN
    -- Effective period boundaries (Default: Today from 00:00:00 to 23:59:59 UTC)
    v_eff_period_start := COALESCE(p_period_start, date_trunc('day', NOW()));
    v_eff_period_end   := COALESCE(p_period_end,   date_trunc('day', NOW()) + INTERVAL '1 day' - INTERVAL '1 millisecond');

    -- Load Client Info
    SELECT id, name, company_name, custom_delivery_fee, custom_failed_attempt_fee, 
           custom_platform_fee, custom_platform_fee_value, custom_platform_fee_type,
           bank_name, account_number, account_name
    INTO v_client
    FROM public.clients
    WHERE id = p_client_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Client not found');
    END IF;

    -- Load DC System Level Config (fallback rates)
    SELECT default_client_delivery_fee, failed_order_charge, 
           platform_fee_type, platform_fee_value, paystack_direct_fee_percent
    INTO v_dc_settings
    FROM public.dc_settings
    ORDER BY created_at ASC
    LIMIT 1;

    -- Step 1: Iterate over Delivered Orders
    IF p_order_ids IS NOT NULL AND array_length(p_order_ids, 1) > 0 THEN
        FOR v_order IN
            SELECT o.id, o.total_amount, o.client_delivery_fee, o.payment_type,
                   COALESCE(o.payment_method, o.delivery_method, 'cash') AS eff_method
            FROM public.orders o
            WHERE o.client_id = p_client_id
              AND o.id = ANY(p_order_ids)
              AND o.status = 'delivered'
              AND (o.financial_settlement_status IS NULL OR o.financial_settlement_status != 'client_settled')
        LOOP
            v_order_ids_array := array_append(v_order_ids_array, v_order.id);
            v_orders_count := v_orders_count + 1;
            v_gross_collections := v_gross_collections + COALESCE(v_order.total_amount, 0.00);

            v_order_delivery_fee := COALESCE(v_client.custom_delivery_fee, v_order.client_delivery_fee, v_dc_settings.default_client_delivery_fee, 5000.00);
            v_delivery_fees := v_delivery_fees + v_order_delivery_fee;

            IF v_client.custom_platform_fee_type = 'percentage' THEN
                v_order_platform_fee := COALESCE(v_order.total_amount, 0.00) * (COALESCE(v_client.custom_platform_fee_value, v_client.custom_platform_fee, 2.5) / 100.0);
            ELSE
                v_order_platform_fee := COALESCE(v_client.custom_platform_fee_value, v_client.custom_platform_fee, v_dc_settings.platform_fee_value, 500.00);
            END IF;
            v_system_operation_fees := v_system_operation_fees + v_order_platform_fee;

            IF LOWER(v_order.eff_method) = 'direct_transfer' OR LOWER(v_order.payment_type) = 'direct_transfer' THEN
                v_order_gateway_fee := LEAST(2000.00, COALESCE(v_order.total_amount, 0.00) * (COALESCE(v_dc_settings.paystack_direct_fee_percent, 1.5) / 100.0));
                v_gateway_fees := v_gateway_fees + v_order_gateway_fee;
            END IF;
        END LOOP;
    ELSE
        FOR v_order IN
            SELECT o.id, o.total_amount, o.client_delivery_fee, o.payment_type,
                   COALESCE(o.payment_method, o.delivery_method, 'cash') AS eff_method
            FROM public.orders o
            WHERE o.client_id = p_client_id
              AND (p_dc_id IS NULL OR o.distribution_center_id = p_dc_id)
              AND o.status = 'delivered'
              AND (o.financial_settlement_status IS NULL OR o.financial_settlement_status != 'client_settled')
              AND (o.delivered_at >= v_eff_period_start AND o.delivered_at <= v_eff_period_end)
        LOOP
            v_order_ids_array := array_append(v_order_ids_array, v_order.id);
            v_orders_count := v_orders_count + 1;
            v_gross_collections := v_gross_collections + COALESCE(v_order.total_amount, 0.00);

            v_order_delivery_fee := COALESCE(v_client.custom_delivery_fee, v_order.client_delivery_fee, v_dc_settings.default_client_delivery_fee, 5000.00);
            v_delivery_fees := v_delivery_fees + v_order_delivery_fee;

            IF v_client.custom_platform_fee_type = 'percentage' THEN
                v_order_platform_fee := COALESCE(v_order.total_amount, 0.00) * (COALESCE(v_client.custom_platform_fee_value, v_client.custom_platform_fee, 2.5) / 100.0);
            ELSE
                v_order_platform_fee := COALESCE(v_client.custom_platform_fee_value, v_client.custom_platform_fee, v_dc_settings.platform_fee_value, 500.00);
            END IF;
            v_system_operation_fees := v_system_operation_fees + v_order_platform_fee;

            IF LOWER(v_order.eff_method) = 'direct_transfer' OR LOWER(v_order.payment_type) = 'direct_transfer' THEN
                v_order_gateway_fee := LEAST(2000.00, COALESCE(v_order.total_amount, 0.00) * (COALESCE(v_dc_settings.paystack_direct_fee_percent, 1.5) / 100.0));
                v_gateway_fees := v_gateway_fees + v_order_gateway_fee;
            END IF;
        END LOOP;
    END IF;

    -- Zero-Order Guard
    IF v_orders_count = 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'No eligible delivered orders found for settlement',
            'orders_settled', 0,
            'gross_collections', 0.00,
            'net_payout', 0.00
        );
    END IF;

    -- Charge 2: Failed Delivery Attempt Surcharges (incorporates failed, cancelled, rejected, customer_rejected)
    v_unit_failed_fee := COALESCE(v_client.custom_failed_attempt_fee, v_dc_settings.failed_order_charge, 1000.00);
    SELECT COUNT(*) INTO v_failed_orders_count
    FROM public.orders
    WHERE client_id = p_client_id
      AND status IN ('failed', 'cancelled', 'rejected', 'customer_rejected')
      AND (v_eff_period_start IS NULL OR (COALESCE(delivered_at, created_at) >= v_eff_period_start))
      AND (COALESCE(delivered_at, created_at) <= v_eff_period_end);

    v_failed_attempt_fees := v_failed_orders_count * v_unit_failed_fee;

    -- Optional custom deductions
    IF p_custom_deductions ? 'other_charges' THEN
        v_other_charges := COALESCE((p_custom_deductions->>'other_charges')::numeric, 0.00);
    END IF;

    v_total_platform_charges := v_system_operation_fees + v_gateway_fees;
    v_total_deductions := v_delivery_fees + v_failed_attempt_fees + v_total_platform_charges + v_other_charges;
    v_net_payout := GREATEST(0.00, v_gross_collections - v_total_deductions);

    -- Build itemized breakdown
    v_charges_breakdown := jsonb_build_object(
        'rate_basis', jsonb_build_object(
            'delivery_fee_per_order', COALESCE(v_client.custom_delivery_fee, v_dc_settings.default_client_delivery_fee, 5000.00),
            'failed_delivery_fee', v_unit_failed_fee,
            'platform_fee_type', COALESCE(v_client.custom_platform_fee_type, v_dc_settings.platform_fee_type, 'flat'),
            'platform_fee_value', COALESCE(v_client.custom_platform_fee_value, v_client.custom_platform_fee, v_dc_settings.platform_fee_value, 500.00)
        ),
        'delivery_fees', v_delivery_fees,
        'failed_attempt_fees', v_failed_attempt_fees,
        'failed_orders_count', v_failed_orders_count,
        'platform_operations_fees', v_system_operation_fees,
        'payment_gateway_fees', v_gateway_fees,
        'other_charges', v_other_charges,
        'total_deductions', v_total_deductions
    );

    -- Sequential settlement number: SET-YYYYMMDD-XXX
    SELECT COUNT(*) + 1 INTO v_today_seq
    FROM public.client_settlements
    WHERE created_at >= date_trunc('day', NOW());

    v_settlement_number := 'SET-' || to_char(NOW(), 'YYYYMMDD') || '-' || lpad(v_today_seq::text, 3, '0');

    -- Insert Settlement
    INSERT INTO public.client_settlements (
        id,
        settlement_number,
        client_id,
        period_start,
        period_end,
        orders_count,
        gross_amount,
        delivery_fees,
        failed_attempt_fees,
        platform_charges,
        other_deductions,
        total_deductions,
        net_payout,
        bank_name,
        account_number,
        account_name,
        settlement_status,
        charges_breakdown,
        order_ids,
        distribution_center_id,
        created_at,
        settled_at
    ) VALUES (
        v_settlement_id,
        v_settlement_number,
        p_client_id,
        v_eff_period_start,
        v_eff_period_end,
        v_orders_count,
        v_gross_collections,
        v_delivery_fees,
        v_failed_attempt_fees,
        v_total_platform_charges,
        v_other_charges,
        v_total_deductions,
        v_net_payout,
        v_client.bank_name,
        v_client.account_number,
        v_client.account_name,
        'completed',
        v_charges_breakdown,
        v_order_ids_array,
        p_dc_id,
        NOW(),
        NOW()
    );

    -- Mark orders as client_settled
    IF array_length(v_order_ids_array, 1) > 0 THEN
        UPDATE public.orders
        SET financial_settlement_status = 'client_settled',
            updated_at = NOW()
        WHERE id = ANY(v_order_ids_array);
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'settlement_id', v_settlement_id,
        'settlement_number', v_settlement_number,
        'client_id', p_client_id,
        'orders_settled', v_orders_count,
        'failed_orders_deducted', v_failed_orders_count,
        'gross_collections', v_gross_collections,
        'total_deductions', v_total_deductions,
        'net_payout', v_net_payout,
        'breakdown', v_charges_breakdown
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_generate_merchant_daily_settlement(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, JSONB, UUID[]) TO authenticated, service_role, anon;


-- =================== 20260920150000_package_deal_pricing_and_physical_depletion_rules.sql ===================
-- ============================================================================
-- Migration: 20260920150000_package_deal_pricing_and_physical_depletion_rules.sql
-- Description:
--   Authoritative package pricing governance for Respira products:
--     1 Box                = ₦21,500 (1 paid, 0 free, 1 total physical unit)
--     2 Boxes              = ₦35,000 (2 paid, 0 free, 2 total physical units)
--     3 Boxes              = ₦45,000 (3 paid, 0 free, 3 total physical units)
--     4 Boxes + 1 Box Free = ₦55,000 (4 paid, 1 free, 5 total physical units)
--   Enforces strict package-first commercial pricing, physical stock depletion
--   on delivery POD, and synchronization with product_packages table.
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE 'Applying package-first pricing and physical stock depletion governance...';
END $$;

-- 1. Ensure Table Structure & Constraints
CREATE TABLE IF NOT EXISTS public.product_packages (
    id TEXT PRIMARY KEY,
    product_id TEXT NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    product_sku VARCHAR(100),
    package_name VARCHAR(255) NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    paid_quantity INT NOT NULL DEFAULT 1,
    free_quantity INT DEFAULT 0,
    package_price NUMERIC(14,2) NOT NULL,
    client_id TEXT,
    client_name VARCHAR(255),
    description TEXT,
    is_custom BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexing for fast lookups during order creation and switching
CREATE INDEX IF NOT EXISTS idx_product_packages_product_id ON public.product_packages(product_id);
CREATE INDEX IF NOT EXISTS idx_product_packages_client_id ON public.product_packages(client_id);
CREATE INDEX IF NOT EXISTS idx_product_packages_product_name ON public.product_packages(product_name);

-- Ensure Realtime publication includes product_packages
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'product_packages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.product_packages;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END $$;

-- 2. Upsert Authoritative Respira Commercial Package Suites
-- Respira Detox Tea (Novacale Limited)
INSERT INTO public.product_packages (
    id, product_id, product_name, product_sku, package_name, quantity, paid_quantity, free_quantity, package_price, client_id, client_name, is_custom, description
) VALUES
    ('pkg-respira-nova-1', '490dc0ad-e5f7-4c72-8f85-667b6ac1072d', 'Respira Detox Tea', 'SKU-48678', '1 Box (Standard Retail)', 1, 1, 0, 21500.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false, '1 Box Starter Treatment'),
    ('pkg-respira-nova-2', '490dc0ad-e5f7-4c72-8f85-667b6ac1072d', 'Respira Detox Tea', 'SKU-48678', '2 Boxes Promo Deal', 2, 2, 0, 35000.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false, '2 Boxes Intensive Treatment'),
    ('pkg-respira-nova-3', '490dc0ad-e5f7-4c72-8f85-667b6ac1072d', 'Respira Detox Tea', 'SKU-48678', '3 Boxes Cleanse Bundle', 3, 3, 0, 45000.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false, '3 Boxes Complete Cleanse Bundle'),
    ('pkg-respira-nova-5', '490dc0ad-e5f7-4c72-8f85-667b6ac1072d', 'Respira Detox Tea', 'SKU-48678', '4 Boxes + 1 Box Free Mega Deal', 5, 4, 1, 55000.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false, '5 Boxes Mega Saver: 4 Paid + 1 Free Bonus Box')
ON CONFLICT (id) DO UPDATE SET
    product_id = EXCLUDED.product_id,
    package_name = EXCLUDED.package_name,
    package_price = EXCLUDED.package_price,
    quantity = EXCLUDED.quantity,
    paid_quantity = EXCLUDED.paid_quantity,
    free_quantity = EXCLUDED.free_quantity,
    description = EXCLUDED.description,
    updated_at = NOW();

-- Respira Detox Tea (Leafora Limited)
INSERT INTO public.product_packages (
    id, product_id, product_name, product_sku, package_name, quantity, paid_quantity, free_quantity, package_price, client_id, client_name, is_custom, description
) VALUES
    ('pkg-respira-leaf-1', 'd14f2ecf-a2b0-4e98-9fc9-4f678bae1e1f', 'Respira Detox Tea', 'SKU-PRD-6028', '1 Box (Standard Retail)', 1, 1, 0, 21500.00, '00000000-0000-4000-8000-789183072480', 'Leafora Limited', false, '1 Box Starter Treatment'),
    ('pkg-respira-leaf-2', 'd14f2ecf-a2b0-4e98-9fc9-4f678bae1e1f', 'Respira Detox Tea', 'SKU-PRD-6028', '2 Boxes Promo Deal', 2, 2, 0, 35000.00, '00000000-0000-4000-8000-789183072480', 'Leafora Limited', false, '2 Boxes Intensive Treatment'),
    ('pkg-respira-leaf-3', 'd14f2ecf-a2b0-4e98-9fc9-4f678bae1e1f', 'Respira Detox Tea', 'SKU-PRD-6028', '3 Boxes Value Bundle', 3, 3, 0, 45000.00, '00000000-0000-4000-8000-789183072480', 'Leafora Limited', false, '3 Boxes Complete Cleanse Bundle'),
    ('pkg-respira-leaf-5', 'd14f2ecf-a2b0-4e98-9fc9-4f678bae1e1f', 'Respira Detox Tea', 'SKU-PRD-6028', '4 Boxes + 1 Box Free Mega Deal', 5, 4, 1, 55000.00, '00000000-0000-4000-8000-789183072480', 'Leafora Limited', false, '5 Boxes Mega Saver: 4 Paid + 1 Free Bonus Box')
ON CONFLICT (id) DO UPDATE SET
    product_id = EXCLUDED.product_id,
    package_name = EXCLUDED.package_name,
    package_price = EXCLUDED.package_price,
    quantity = EXCLUDED.quantity,
    paid_quantity = EXCLUDED.paid_quantity,
    free_quantity = EXCLUDED.free_quantity,
    description = EXCLUDED.description,
    updated_at = NOW();

-- Respira Lungs Detox Tea (Novacale Limited)
INSERT INTO public.product_packages (
    id, product_id, product_name, product_sku, package_name, quantity, paid_quantity, free_quantity, package_price, client_id, client_name, is_custom, description
) VALUES
    ('pkg-respira-lungs-1', 'd4f0a76c-2393-476e-ac2c-c350f31a8a90', 'Respira Lungs Detox Tea', 'SKU-95708', '1 Box (Standard Retail)', 1, 1, 0, 21500.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false, '1 Box Starter Treatment'),
    ('pkg-respira-lungs-2', 'd4f0a76c-2393-476e-ac2c-c350f31a8a90', 'Respira Lungs Detox Tea', 'SKU-95708', '2 Boxes Promo Deal', 2, 2, 0, 35000.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false, '2 Boxes Intensive Treatment'),
    ('pkg-respira-lungs-3', 'd4f0a76c-2393-476e-ac2c-c350f31a8a90', 'Respira Lungs Detox Tea', 'SKU-95708', '3 Boxes Cleanse Bundle', 3, 3, 0, 45000.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false, '3 Boxes Complete Cleanse Bundle'),
    ('pkg-respira-lungs-5', 'd4f0a76c-2393-476e-ac2c-c350f31a8a90', 'Respira Lungs Detox Tea', 'SKU-95708', '4 Boxes + 1 Box Free Mega Deal', 5, 4, 1, 55000.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false, '5 Boxes Mega Saver: 4 Paid + 1 Free Bonus Box')
ON CONFLICT (id) DO UPDATE SET
    product_id = EXCLUDED.product_id,
    package_name = EXCLUDED.package_name,
    package_price = EXCLUDED.package_price,
    quantity = EXCLUDED.quantity,
    paid_quantity = EXCLUDED.paid_quantity,
    free_quantity = EXCLUDED.free_quantity,
    description = EXCLUDED.description,
    updated_at = NOW();

-- RESPIRA LUNG TEA (SKU-RLT, Novacare Ltd)
DO $$
DECLARE
    v_rlt_id TEXT;
BEGIN
    SELECT id::text INTO v_rlt_id FROM public.products WHERE sku = 'SKU-RLT' OR name ILIKE '%RESPIRA LUNG TEA%' LIMIT 1;
    IF v_rlt_id IS NOT NULL THEN
        INSERT INTO public.product_packages (
            id, product_id, product_name, product_sku, package_name, quantity, paid_quantity, free_quantity, package_price, client_id, client_name, is_custom, description
        ) VALUES
            ('pkg-rlt-1', v_rlt_id, 'RESPIRA LUNG TEA', 'SKU-RLT', '1 Box (Standard Retail)', 1, 1, 0, 21500.00, '33333333-3333-4333-8333-333333333333', 'Novacare Ltd', false, '1 Box Treatment'),
            ('pkg-rlt-2', v_rlt_id, 'RESPIRA LUNG TEA', 'SKU-RLT', '2 Boxes Promo Deal', 2, 2, 0, 35000.00, '33333333-3333-4333-8333-333333333333', 'Novacare Ltd', false, '2 Boxes Deal'),
            ('pkg-rlt-3', v_rlt_id, 'RESPIRA LUNG TEA', 'SKU-RLT', '3 Boxes Cleanse Bundle', 3, 3, 0, 45000.00, '33333333-3333-4333-8333-333333333333', 'Novacare Ltd', false, '3 Boxes Cleanse Bundle'),
            ('pkg-rlt-5', v_rlt_id, 'RESPIRA LUNG TEA', 'SKU-RLT', '4 Boxes + 1 Box Free Mega Deal', 5, 4, 1, 55000.00, '33333333-3333-4333-8333-333333333333', 'Novacare Ltd', false, '5 Boxes Mega Deal: 4 Paid + 1 Free')
        ON CONFLICT (id) DO UPDATE SET
            package_name = EXCLUDED.package_name,
            package_price = EXCLUDED.package_price,
            quantity = EXCLUDED.quantity,
            paid_quantity = EXCLUDED.paid_quantity,
            free_quantity = EXCLUDED.free_quantity,
            description = EXCLUDED.description,
            updated_at = NOW();
    END IF;
END $$;

-- 3. Stored Procedure: Authoritative Physical Delivery Confirmation
CREATE OR REPLACE FUNCTION public.fn_confirm_order_delivery_stock(
    p_order_id UUID,
    p_agent_id UUID,
    p_product_id UUID,
    p_physical_quantity INT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_qty INT := GREATEST(1, COALESCE(p_physical_quantity, 1));
    v_agent RECORD;
BEGIN
    SELECT * INTO v_agent FROM public.delivery_agents WHERE id = p_agent_id OR user_id = p_agent_id;

    IF v_agent IS NOT NULL AND p_product_id IS NOT NULL THEN
        UPDATE public.agent_inventory
        SET available_count = GREATEST(0, COALESCE(available_count, 0) - v_qty),
            total_in_custody = GREATEST(0, COALESCE(total_in_custody, 0) - v_qty),
            delivered_count_today = COALESCE(delivered_count_today, 0) + v_qty,
            updated_at = NOW()
        WHERE delivery_agent_id = v_agent.id AND product_id = p_product_id;
    END IF;

    IF p_product_id IS NOT NULL THEN
        UPDATE public.products
        SET delivered_count = COALESCE(delivered_count, 0) + v_qty,
            stock_quantity = GREATEST(0, COALESCE(stock_quantity, 0) - v_qty),
            available_count = GREATEST(0, COALESCE(available_count, 0) - v_qty),
            updated_at = NOW()
        WHERE id = p_product_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'deducted_physical_quantity', v_qty
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_confirm_order_delivery_stock(UUID, UUID, UUID, INT) TO authenticated, service_role, anon;


-- =================== 20260920160000_dc_merchant_management_and_brand_theming.sql ===================
-- ============================================================================
-- NOVAXPRESS LOGISTICS PLATFORM
-- Migration: 20260920160000_dc_merchant_management_and_brand_theming.sql
-- Description:
--   1. Ensures all brand theming, operating states, and service modules exist on clients.
--   2. Provides fn_update_client_profile_and_tariffs RPC for DC-side merchant management.
-- ============================================================================

DO $$
BEGIN
    -- has_inventory_management
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'clients' AND column_name = 'has_inventory_management'
    ) THEN
        ALTER TABLE public.clients ADD COLUMN has_inventory_management BOOLEAN DEFAULT TRUE;
    END IF;

    -- services_enabled
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'clients' AND column_name = 'services_enabled'
    ) THEN
        ALTER TABLE public.clients ADD COLUMN services_enabled TEXT[] DEFAULT ARRAY['fulfillment', 'delivery', 'inventory_management'];
    END IF;

    -- logo_url
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'clients' AND column_name = 'logo_url'
    ) THEN
        ALTER TABLE public.clients ADD COLUMN logo_url TEXT;
    END IF;

    -- primary_color
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'clients' AND column_name = 'primary_color'
    ) THEN
        ALTER TABLE public.clients ADD COLUMN primary_color TEXT DEFAULT '#0D9488';
    END IF;

    -- secondary_color
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'clients' AND column_name = 'secondary_color'
    ) THEN
        ALTER TABLE public.clients ADD COLUMN secondary_color TEXT DEFAULT '#031632';
    END IF;

    -- accent_color
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'clients' AND column_name = 'accent_color'
    ) THEN
        ALTER TABLE public.clients ADD COLUMN accent_color TEXT DEFAULT '#10B981';
    END IF;

    -- brand_theme
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'clients' AND column_name = 'brand_theme'
    ) THEN
        ALTER TABLE public.clients ADD COLUMN brand_theme JSONB DEFAULT '{"font_family": "Inter", "border_radius": 8}'::jsonb;
    END IF;

    -- operating_states
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'clients' AND column_name = 'operating_states'
    ) THEN
        ALTER TABLE public.clients ADD COLUMN operating_states TEXT[] DEFAULT ARRAY['Federal Capital Territory', 'Lagos', 'Rivers', 'Kano', 'Oyo', 'Enugu'];
    END IF;
END $$;

-- Atomic RPC for DC Console to update merchant details, tariffs, brand, and services
CREATE OR REPLACE FUNCTION public.fn_update_client_profile_and_tariffs(
    p_client_id UUID,
    p_company_name TEXT,
    p_contact_person TEXT,
    p_email TEXT,
    p_phone TEXT,
    p_address TEXT,
    p_city TEXT,
    p_state TEXT,
    p_tier TEXT,
    p_closer_limit INT,
    p_has_inventory_management BOOLEAN,
    p_services_enabled TEXT[],
    p_operating_states TEXT[],
    p_logo_url TEXT,
    p_primary_color TEXT,
    p_secondary_color TEXT,
    p_accent_color TEXT,
    p_custom_delivery_fee NUMERIC,
    p_custom_failed_attempt_fee NUMERIC,
    p_custom_platform_fee NUMERIC,
    p_bank_name TEXT,
    p_account_number TEXT,
    p_account_name TEXT,
    p_settlement_frequency TEXT,
    p_settlement_day TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.clients
    SET
        company_name = COALESCE(NULLIF(p_company_name, ''), company_name),
        contact_person = COALESCE(NULLIF(p_contact_person, ''), contact_person),
        email = COALESCE(NULLIF(p_email, ''), email),
        phone = COALESCE(NULLIF(p_phone, ''), phone),
        address = COALESCE(NULLIF(p_address, ''), address),
        city = COALESCE(NULLIF(p_city, ''), city),
        state = COALESCE(NULLIF(p_state, ''), state),
        tier = COALESCE(NULLIF(p_tier, ''), tier),
        is_enterprise = (COALESCE(p_tier, tier) = 'enterprise'),
        closer_limit = COALESCE(p_closer_limit, closer_limit),
        has_inventory_management = COALESCE(p_has_inventory_management, has_inventory_management),
        services_enabled = COALESCE(p_services_enabled, services_enabled),
        operating_states = COALESCE(p_operating_states, operating_states),
        logo_url = p_logo_url,
        primary_color = COALESCE(NULLIF(p_primary_color, ''), primary_color),
        secondary_color = COALESCE(NULLIF(p_secondary_color, ''), secondary_color),
        accent_color = COALESCE(NULLIF(p_accent_color, ''), accent_color),
        custom_delivery_fee = p_custom_delivery_fee,
        custom_failed_attempt_fee = p_custom_failed_attempt_fee,
        custom_platform_fee_value = p_custom_platform_fee,
        bank_name = COALESCE(NULLIF(p_bank_name, ''), bank_name),
        account_number = COALESCE(NULLIF(p_account_number, ''), account_number),
        account_name = COALESCE(NULLIF(p_account_name, ''), account_name),
        settlement_frequency = COALESCE(NULLIF(p_settlement_frequency, ''), settlement_frequency),
        settlement_day = COALESCE(NULLIF(p_settlement_day, ''), settlement_day),
        updated_at = NOW()
    WHERE id = p_client_id;

    RETURN jsonb_build_object(
        'success', true,
        'client_id', p_client_id,
        'updated_at', NOW()
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_update_client_profile_and_tariffs TO authenticated, service_role, anon;


-- =================== 20260920170000_link_products_to_suppliers.sql ===================
-- ============================================================================
-- NOVAXPRESS LOGISTICS PLATFORM
-- Migration: 20260920170000_link_products_to_suppliers.sql
-- Description:
--   1. Adds preferred_supplier_id foreign key column to products.
--   2. Automatically links products to existing active suppliers.
-- ============================================================================

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

-- Auto-link Novacare products to Apex Herbal Laboratories Ltd where matching
UPDATE public.products p
SET preferred_supplier_id = s.id
FROM public.client_suppliers s
WHERE (s.supplier_name ILIKE '%Apex%' 
    OR (s.supplied_products IS NOT NULL AND s.supplied_products::text ILIKE '%' || p.name || '%')
    OR (s.supplied_products IS NOT NULL AND s.supplied_products::text ILIKE '%' || p.sku || '%'))
  AND p.preferred_supplier_id IS NULL;


-- =================== 20260920180000_supplier_inventory_health_rpc.sql ===================
-- ============================================================================
-- NOVAXPRESS LOGISTICS PLATFORM
-- Migration: 20260920180000_supplier_inventory_health_rpc.sql
-- Description:
--   1. Creates fn_get_client_suppliers_overview RPC for real-time inventory aggregation per vendor.
--   2. Calculates remaining network units, low-stock alerts, and replenishment urgency.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_get_client_suppliers_overview(p_client_id TEXT)
RETURNS TABLE (
    supplier_id UUID,
    client_id TEXT,
    supplier_name TEXT,
    category TEXT,
    contact_person TEXT,
    phone TEXT,
    email TEXT,
    address TEXT,
    city TEXT,
    country TEXT,
    lead_time_days INT,
    payment_terms TEXT,
    bank_name TEXT,
    account_number TEXT,
    account_name TEXT,
    notes TEXT,
    is_active BOOLEAN,
    created_at TIMESTAMPTZ,
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
        s.client_id,
        s.supplier_name,
        s.category,
        s.contact_person,
        s.phone,
        s.email,
        s.address,
        s.city,
        s.country,
        s.lead_time_days,
        s.payment_terms,
        s.bank_name,
        s.account_number,
        s.account_name,
        s.notes,
        s.is_active,
        s.created_at,
        s.supplied_products,
        COALESCE(SUM(p.stock_quantity), 0)::BIGINT AS total_remaining_units,
        COUNT(p.id) FILTER (WHERE p.stock_quantity <= COALESCE(p.low_stock_threshold, 10))::INT AS low_stock_count,
        BOOL_OR(p.stock_quantity <= COALESCE(p.low_stock_threshold, 10)) AS critical_reorder_needed
    FROM public.client_suppliers s
    LEFT JOIN public.products p 
      ON p.preferred_supplier_id = s.id 
      OR (s.supplied_products @> ARRAY[p.name] OR s.supplied_products @> ARRAY[p.sku])
    WHERE (s.client_id = p_client_id OR p_client_id = 'all')
      AND s.is_active = TRUE
    GROUP BY 
        s.id, s.client_id, s.supplier_name, s.category, s.contact_person, s.phone, s.email, 
        s.address, s.city, s.country, s.lead_time_days, s.payment_terms, s.bank_name, 
        s.account_number, s.account_name, s.notes, s.is_active, s.created_at, s.supplied_products
    ORDER BY critical_reorder_needed DESC, total_remaining_units ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_get_client_suppliers_overview(TEXT) TO authenticated, service_role, anon;


-- =================== 20260920185000_link_stock_intake_to_dc_supply_handshake.sql ===================
-- ============================================================================
-- NOVAXPRESS LOGISTICS PLATFORM
-- Migration: 20260920185000_link_stock_intake_to_dc_supply_handshake.sql
-- Description:
--   1. Connects stock intake invoices with physical DC consignment handshakes.
--   2. Extends stock_transfers and client_stock_invoices with industrial reception fields.
--   3. Registers an incoming supply transfer when a stock intake invoice is raised.
--   4. Provides fn_receive_supply_consignment_handshake for verified reception of both
--      merchant/supplier consignments and inter-DC stock freights.
-- ============================================================================

-- 1. Extend stock_transfers schema
ALTER TABLE public.stock_transfers
    ADD COLUMN IF NOT EXISTS invoice_id UUID REFERENCES public.client_stock_invoices(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS carrier_driver_name TEXT,
    ADD COLUMN IF NOT EXISTS carrier_phone TEXT,
    ADD COLUMN IF NOT EXISTS carrier_license_plate TEXT,
    ADD COLUMN IF NOT EXISTS waybill_slip_url TEXT,
    ADD COLUMN IF NOT EXISTS destination_bin TEXT,
    ADD COLUMN IF NOT EXISTS verified_units INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS damaged_units INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS missing_units INT DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_stock_transfers_invoice_id ON public.stock_transfers(invoice_id);

-- 2. Extend client_stock_invoices schema
ALTER TABLE public.client_stock_invoices
    ADD COLUMN IF NOT EXISTS waybill_number TEXT,
    ADD COLUMN IF NOT EXISTS payment_receipt_url TEXT,
    ADD COLUMN IF NOT EXISTS verified_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS verified_by TEXT,
    ADD COLUMN IF NOT EXISTS verified_units INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS damaged_units INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS missing_units INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS handshake_notes TEXT;

CREATE INDEX IF NOT EXISTS idx_client_stock_invoices_waybill ON public.client_stock_invoices(waybill_number);

-- 3. Stored Procedure: fn_create_dc_consignment_for_intake_invoice
CREATE OR REPLACE FUNCTION public.fn_create_dc_consignment_for_intake_invoice(
    p_invoice_id UUID,
    p_sender_id UUID DEFAULT NULL,
    p_sender_name TEXT DEFAULT '',
    p_sender_signature_url TEXT DEFAULT '',
    p_carrier_driver_name TEXT DEFAULT '',
    p_carrier_phone TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_inv RECORD;
    v_item RECORD;
    v_dc_id UUID;
    v_company_id UUID;
    v_transfer_id UUID;
    v_waybill TEXT;
    v_dc_name TEXT;
    v_total_units INT := 0;
BEGIN
    SELECT * INTO v_inv FROM public.client_stock_invoices WHERE id = p_invoice_id;
    IF v_inv IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invoice not found');
    END IF;

    -- Resolve destination DC by warehouse name matching
    SELECT id, name INTO v_dc_id, v_dc_name FROM public.distribution_centers 
    WHERE name ILIKE '%' || SPLIT_PART(v_inv.destination_warehouse, ' - ', 1) || '%'
       OR v_inv.destination_warehouse ILIKE '%' || name || '%'
       OR v_inv.destination_warehouse ILIKE '%' || state || '%'
    LIMIT 1;

    -- Fallback to first active DC if not matched
    IF v_dc_id IS NULL THEN
        SELECT id, name INTO v_dc_id, v_dc_name FROM public.distribution_centers LIMIT 1;
    END IF;

    -- Resolve company_id
    SELECT company_id INTO v_company_id FROM public.clients WHERE id = v_inv.client_id::UUID;
    IF v_company_id IS NULL THEN
        SELECT id INTO v_company_id FROM public.companies LIMIT 1;
    END IF;

    v_waybill := COALESCE(NULLIF(v_inv.waybill_number, ''), 'WB-INTAKE-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0'));

    -- Ensure the invoice has the waybill number and initial status is 'in_transit'
    UPDATE public.client_stock_invoices
    SET waybill_number = v_waybill,
        status = CASE WHEN status = 'draft' THEN 'in_transit' ELSE COALESCE(status, 'in_transit') END,
        updated_at = NOW()
    WHERE id = p_invoice_id;

    -- Create pending stock transfer for DC custody acceptance
    INSERT INTO public.stock_transfers (
        company_id,
        client_id,
        invoice_id,
        transfer_type,
        transfer_number,
        waybill_number,
        destination_dc_id,
        status,
        sender_id,
        sender_name,
        sender_role,
        sender_signature_url,
        carrier_driver_name,
        carrier_phone,
        dispatched_at,
        notes
    ) VALUES (
        v_company_id,
        v_inv.client_id::UUID,
        p_invoice_id,
        'client_supply',
        v_waybill,
        v_waybill,
        v_dc_id,
        'in_transit',
        p_sender_id,
        COALESCE(NULLIF(p_sender_name, ''), 'Merchant Procurement'),
        'client',
        p_sender_signature_url,
        p_carrier_driver_name,
        p_carrier_phone,
        NOW(),
        'Procurement Inbound Intake from ' || COALESCE(v_inv.supplier_name, 'Vendor') || ' (Bill: ' || v_inv.invoice_number || ')'
    ) RETURNING id INTO v_transfer_id;

    -- Copy line items into stock_transfer_items
    FOR v_item IN SELECT * FROM public.client_stock_invoice_items WHERE invoice_id = p_invoice_id
    LOOP
        INSERT INTO public.stock_transfer_items (
            transfer_id,
            product_id,
            quantity_shipped,
            quantity_received,
            quantity_damaged,
            quantity_missing,
            item_notes
        ) VALUES (
            v_transfer_id,
            v_item.product_id,
            v_item.quantity,
            0,
            0,
            0,
            v_item.product_name || ' (SKU: ' || v_item.product_sku || ')'
        );
        v_total_units := v_total_units + v_item.quantity;
    END LOOP;

    -- Send Realtime Notification to DC Personnel
    BEGIN
        INSERT INTO public.notifications (
            company_id,
            title,
            message,
            category,
            action_route,
            is_read
        ) VALUES (
            v_company_id,
            'Inbound Consignment Dispatched: ' || v_waybill,
            'Merchant dispatched ' || v_total_units || ' units from ' || COALESCE(v_inv.supplier_name, 'Vendor') || ' to ' || COALESCE(v_dc_name, 'Hub') || '. Physical reception verification required.',
            'inventory',
            '/dc/stock',
            false
        );
    EXCEPTION WHEN OTHERS THEN
        -- Non-blocking notification failure
    END;

    RETURN jsonb_build_object(
        'success', true,
        'invoice_id', p_invoice_id,
        'transfer_id', v_transfer_id,
        'destination_dc_id', v_dc_id,
        'destination_dc_name', v_dc_name,
        'waybill_number', v_waybill,
        'total_units', v_total_units
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_create_dc_consignment_for_intake_invoice TO authenticated, service_role, anon;

-- 4. Stored Procedure: fn_receive_supply_consignment_handshake (Universal Reception for Client Supply & Inter-DC)
CREATE OR REPLACE FUNCTION public.fn_receive_supply_consignment_handshake(
    p_transfer_id UUID,
    p_receiver_id UUID,
    p_receiver_name TEXT,
    p_receiver_role TEXT DEFAULT 'dc_supervisor',
    p_receiver_signature_url TEXT DEFAULT '',
    p_carrier_driver_name TEXT DEFAULT '',
    p_carrier_phone TEXT DEFAULT '',
    p_carrier_license_plate TEXT DEFAULT '',
    p_waybill_slip_url TEXT DEFAULT '',
    p_destination_bin TEXT DEFAULT '',
    p_verified_items JSONB DEFAULT '[]'::JSONB,
    p_notes TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_trf RECORD;
    v_inv RECORD;
    v_item JSONB;
    v_item_id UUID;
    v_prod_id UUID;
    v_item_row RECORD;
    v_qty_rec INT;
    v_qty_dam INT;
    v_qty_mis INT;
    v_total_rec INT := 0;
    v_total_dam INT := 0;
    v_total_mis INT := 0;
    v_total_shipped INT := 0;
    v_has_disc BOOLEAN := FALSE;
    v_status TEXT := 'completed';
    v_inv_status TEXT := 'verified';
    v_dc_name TEXT := 'Distribution Center';
    v_cur_bal RECORD;
    v_new_bal_qty NUMERIC;
    v_new_valuation NUMERIC;
    v_target_wh TEXT;
BEGIN
    SELECT * INTO v_trf FROM public.stock_transfers WHERE id = p_transfer_id;
    IF v_trf IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Stock transfer not found');
    END IF;

    -- Resolve DC name
    IF v_trf.destination_dc_id IS NOT NULL THEN
        SELECT name INTO v_dc_name FROM public.distribution_centers WHERE id = v_trf.destination_dc_id;
    END IF;

    -- Process verified items
    IF jsonb_array_length(p_verified_items) > 0 THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(p_verified_items)
        LOOP
            BEGIN
                v_item_id := (v_item->>'item_id')::UUID;
            EXCEPTION WHEN OTHERS THEN
                v_item_id := NULL;
            END;

            BEGIN
                v_prod_id := (v_item->>'product_id')::UUID;
            EXCEPTION WHEN OTHERS THEN
                v_prod_id := NULL;
            END;

            v_qty_rec := COALESCE((v_item->>'quantity_received')::INT, 0);
            v_qty_dam := COALESCE((v_item->>'quantity_damaged')::INT, 0);
            v_qty_mis := COALESCE((v_item->>'quantity_missing')::INT, 0);

            -- Match item row in stock_transfer_items
            SELECT * INTO v_item_row FROM public.stock_transfer_items
            WHERE ((v_item_id IS NOT NULL AND id = v_item_id)
                OR (v_item_id IS NOT NULL AND product_id = v_item_id)
                OR (v_prod_id IS NOT NULL AND product_id = v_prod_id))
              AND transfer_id = p_transfer_id
            LIMIT 1;

            IF v_item_row IS NOT NULL THEN
                v_total_shipped := v_total_shipped + COALESCE(v_item_row.quantity_shipped, 0);

                -- Fallback to shipped qty if received was omitted and no damages/missing reported
                IF v_qty_rec = 0 AND v_qty_dam = 0 AND v_qty_mis = 0 AND v_item_row.quantity_shipped > 0 THEN
                    v_qty_rec := v_item_row.quantity_shipped;
                END IF;

                IF v_qty_dam > 0 OR v_qty_mis > 0 OR v_qty_rec != v_item_row.quantity_shipped THEN
                    v_has_disc := TRUE;
                END IF;

                v_total_rec := v_total_rec + v_qty_rec;
                v_total_dam := v_total_dam + v_qty_dam;
                v_total_mis := v_total_mis + v_qty_mis;

                UPDATE public.stock_transfer_items
                SET quantity_received = v_qty_rec,
                    quantity_damaged = v_qty_dam,
                    quantity_missing = v_qty_mis,
                    item_notes = COALESCE(v_item->>'notes', item_notes)
                WHERE id = v_item_row.id;

                -- Credit physical product stock & DC warehouse stock
                IF v_qty_rec > 0 AND v_item_row.product_id IS NOT NULL THEN
                    UPDATE public.products
                    SET stock_quantity = COALESCE(stock_quantity, 0) + v_qty_rec,
                        updated_at = NOW()
                    WHERE id = v_item_row.product_id;

                    IF v_trf.destination_dc_id IS NOT NULL THEN
                        PERFORM public.fn_adjust_dc_stock(v_item_row.product_id, v_trf.destination_dc_id, v_qty_rec);
                    END IF;
                END IF;
            END IF;
        END LOOP;
    ELSE
        -- Fallback: Accept full shipped quantities as received
        FOR v_item_row IN SELECT * FROM public.stock_transfer_items WHERE transfer_id = p_transfer_id
        LOOP
            v_qty_rec := v_item_row.quantity_shipped;
            v_total_shipped := v_total_shipped + v_qty_rec;
            v_total_rec := v_total_rec + v_qty_rec;

            UPDATE public.stock_transfer_items
            SET quantity_received = v_qty_rec
            WHERE id = v_item_row.id;

            IF v_qty_rec > 0 AND v_item_row.product_id IS NOT NULL THEN
                UPDATE public.products
                SET stock_quantity = COALESCE(stock_quantity, 0) + v_qty_rec,
                    updated_at = NOW()
                WHERE id = v_item_row.product_id;

                IF v_trf.destination_dc_id IS NOT NULL THEN
                    PERFORM public.fn_adjust_dc_stock(v_item_row.product_id, v_trf.destination_dc_id, v_qty_rec);
                END IF;
            END IF;
        END LOOP;
    END IF;

    IF v_has_disc THEN
        v_status := 'discrepancy_reported';
        v_inv_status := 'discrepancy';
    ELSE
        v_status := 'completed';
        v_inv_status := 'verified';
    END IF;

    -- Update stock_transfers header
    UPDATE public.stock_transfers
    SET status = v_status,
        receiver_id = p_receiver_id,
        receiver_name = p_receiver_name,
        receiver_role = COALESCE(NULLIF(p_receiver_role, ''), 'dc_supervisor'),
        receiver_signature_url = COALESCE(p_receiver_signature_url, ''),
        carrier_driver_name = COALESCE(NULLIF(p_carrier_driver_name, ''), carrier_driver_name),
        carrier_phone = COALESCE(NULLIF(p_carrier_phone, ''), carrier_phone),
        carrier_license_plate = COALESCE(NULLIF(p_carrier_license_plate, ''), carrier_license_plate),
        waybill_slip_url = COALESCE(NULLIF(p_waybill_slip_url, ''), waybill_slip_url),
        destination_bin = COALESCE(NULLIF(p_destination_bin, ''), destination_bin),
        verified_units = v_total_rec,
        damaged_units = v_total_dam,
        missing_units = v_total_mis,
        received_at = NOW(),
        has_discrepancy = v_has_disc,
        discrepancy_notes = p_notes,
        updated_at = NOW()
    WHERE id = p_transfer_id;

    -- Synchronize with linked Client Stock Invoice if present
    IF v_trf.invoice_id IS NOT NULL THEN
        SELECT * INTO v_inv FROM public.client_stock_invoices WHERE id = v_trf.invoice_id;
        IF v_inv IS NOT NULL THEN
            UPDATE public.client_stock_invoices
            SET status = v_inv_status,
                verified_at = NOW(),
                verified_by = p_receiver_name,
                verified_units = v_total_rec,
                damaged_units = v_total_dam,
                missing_units = v_total_mis,
                handshake_notes = p_notes,
                updated_at = NOW()
            WHERE id = v_trf.invoice_id;

            -- ERP Stock Ledger balancing: Update client_stock_balances
            v_target_wh := COALESCE(NULLIF(v_inv.destination_warehouse, ''), v_dc_name);
            FOR v_item_row IN SELECT * FROM public.stock_transfer_items WHERE transfer_id = p_transfer_id
            LOOP
                IF v_item_row.quantity_received > 0 AND v_item_row.product_id IS NOT NULL THEN
                    SELECT * INTO v_cur_bal FROM public.client_stock_balances
                    WHERE client_id = v_inv.client_id
                      AND (product_id = v_item_row.product_id OR item_name = v_item_row.item_notes)
                      AND warehouse = v_target_wh
                    LIMIT 1;

                    IF FOUND THEN
                        UPDATE public.client_stock_balances
                        SET in_qty = in_qty + v_item_row.quantity_received,
                            balance_qty = balance_qty + v_item_row.quantity_received,
                            balance_value = (balance_qty + v_item_row.quantity_received) * valuation_rate,
                            updated_at = NOW()
                        WHERE id = v_cur_bal.id;
                    ELSE
                        INSERT INTO public.client_stock_balances (
                            client_id, product_id, item_code, item_name, warehouse, stock_uom,
                            opening_qty, opening_value, in_qty, in_value, out_qty, out_value,
                            balance_qty, balance_value, valuation_rate, reserved_stock
                        ) VALUES (
                            v_inv.client_id, v_item_row.product_id, COALESCE(v_item_row.product_id::text, 'SKU'),
                            COALESCE(v_item_row.item_notes, 'Product Item'), v_target_wh, 'Nos',
                            0, 0, v_item_row.quantity_received, 0, 0, 0,
                            v_item_row.quantity_received, 0, 0, 0
                        );
                    END IF;

                    -- Record immutable ledger entry
                    BEGIN
                        INSERT INTO public.client_stock_ledger_entries (
                            client_id, warehouse, item_code, item_name, voucher_type, voucher_no,
                            invoice_id, posting_date, posting_at, qty_change, incoming_qty, outgoing_qty,
                            valuation_rate, total_value, notes
                        ) VALUES (
                            v_inv.client_id, v_target_wh, COALESCE(v_item_row.product_id::text, 'SKU'),
                            COALESCE(v_item_row.item_notes, 'Product Item'), 'purchase_receipt',
                            COALESCE(v_trf.waybill_number, v_trf.transfer_number), v_trf.invoice_id,
                            CURRENT_DATE, NOW(), v_item_row.quantity_received, v_item_row.quantity_received, 0,
                            0, 0, 'Verified Inbound Consignment Handshake at ' || v_dc_name
                        );
                    EXCEPTION WHEN OTHERS THEN
                        -- Non-blocking ledger insert
                    END;
                END IF;
            END LOOP;

            -- Notify Merchant of Completed Consignment Handshake
            BEGIN
                INSERT INTO public.notifications (
                    company_id,
                    client_id,
                    title,
                    message,
                    category,
                    action_route,
                    is_read
                ) VALUES (
                    v_trf.company_id,
                    v_inv.client_id,
                    CASE WHEN v_has_disc THEN '⚠️ Consignment Received with Discrepancy' ELSE '✓ Consignment Verified & Received!' END,
                    'Waybill ' || COALESCE(v_trf.waybill_number, '') || ' verified at ' || v_dc_name || ' by ' || p_receiver_name || '. ' || v_total_rec || ' units credited to station shelves.' || CASE WHEN v_has_disc THEN ' (' || v_total_dam || ' damaged, ' || v_total_mis || ' missing)' ELSE '' END,
                    'inventory',
                    '/inventory',
                    false
                );
            EXCEPTION WHEN OTHERS THEN
                -- Non-blocking notification
            END;
        END IF;
    END IF;

    -- Inter-DC specific handling
    IF v_trf.transfer_type = 'inter_dc' THEN
        -- If discrepancy reported on inter-DC transfer, log audit event
        IF v_has_disc THEN
            BEGIN
                INSERT INTO public.inventory_audits (
                    product_id,
                    action,
                    performed_by,
                    notes
                ) VALUES (
                    NULL,
                    'inter_dc_discrepancy',
                    p_receiver_name,
                    'Inter-DC transfer ' || v_trf.transfer_number || ' received with ' || v_total_dam || ' damaged and ' || v_total_mis || ' missing units.'
                );
            EXCEPTION WHEN OTHERS THEN
            END;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'status', v_status,
        'has_discrepancy', v_has_disc,
        'total_shipped', v_total_shipped,
        'total_received', v_total_rec,
        'total_damaged', v_total_dam,
        'total_missing', v_total_mis,
        'invoice_id', v_trf.invoice_id,
        'transfer_id', p_transfer_id,
        'waybill_number', v_trf.waybill_number,
        'destination_dc_name', v_dc_name,
        'message', 'Consignment reception handshake successfully processed and inventory credited.'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_receive_supply_consignment_handshake TO authenticated, service_role, anon;

-- 5. Backwards-compatible wrapper for fn_receive_client_supply
CREATE OR REPLACE FUNCTION public.fn_receive_client_supply(
    p_transfer_id UUID,
    p_receiver_id UUID,
    p_receiver_name TEXT,
    p_receiver_signature_url TEXT DEFAULT '',
    p_verified_items JSONB DEFAULT '[]'::JSONB,
    p_notes TEXT DEFAULT ''
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN public.fn_receive_supply_consignment_handshake(
        p_transfer_id := p_transfer_id,
        p_receiver_id := p_receiver_id,
        p_receiver_name := p_receiver_name,
        p_receiver_role := 'dc_supervisor',
        p_receiver_signature_url := p_receiver_signature_url,
        p_carrier_driver_name := '',
        p_carrier_phone := '',
        p_carrier_license_plate := '',
        p_waybill_slip_url := '',
        p_destination_bin := '',
        p_verified_items := p_verified_items,
        p_notes := p_notes
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_receive_client_supply TO authenticated, service_role, anon;


-- =================== 20260920190000_purge_bloated_stock_and_seed_date_tiered_balances.sql ===================
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


-- =================== 20260920200000_seed_baseline_intake_invoices_and_receipt_attachment.sql ===================
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
ALTER TABLE public.client_suppliers ADD COLUMN IF NOT EXISTS category TEXT;

INSERT INTO public.client_suppliers (
    id, client_id, supplier_name, contact_person, email, phone, category, payment_terms, bank_name, account_number, account_name
) VALUES 
    ('00000000-0000-4000-8000-000000000001', '33333333-3333-4333-8333-333333333333', 'Apex Herbal Laboratories Ltd', 'Dr. Patrick Okonjo', 'procurement@apexherbal.ng', '+234 803 111 2233', 'Herbal Formulations & Pharma', 'Net 30', 'Access Bank', '0123456789', 'Apex Herbal Laboratories Ltd'),
    ('00000000-0000-4000-8000-000000000002', '33333333-3333-4333-8333-333333333333', 'DermaCare Naturals & Cosmeceuticals', 'Amina Bello', 'orders@dermacare.ng', '+234 802 444 5566', 'Finished Goods Manufacturing', 'Immediate', 'Zenith Bank', '1012345678', 'DermaCare Naturals Ltd'),
    ('00000000-0000-4000-8000-000000000003', '33333333-3333-4333-8333-333333333333', 'ProFit Activewear & Medical Goods', 'Engr. Emeka Eze', 'sales@profitgoods.ng', '+234 805 777 8899', 'Finished Goods Manufacturing', 'Net 15', 'GTBank', '0234567890', 'ProFit Activewear Nigeria')
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


-- =================== 20260920210000_manual_client_settlement_receipt_and_approval.sql ===================
-- Migration: 20260920210000_manual_client_settlement_receipt_and_approval.sql
-- Description: Hardens manual client settlement flow, adds receipt attachment support,
-- fixes fn_generate_merchant_daily_settlement schema mapping bugs, and adds fn_merchant_approve_settlement.

-- 1. Ensure client_settlements columns exist
ALTER TABLE IF EXISTS public.client_settlements
    ADD COLUMN IF NOT EXISTS proof_of_payment_url TEXT,
    ADD COLUMN IF NOT EXISTS payout_reference TEXT,
    ADD COLUMN IF NOT EXISTS notes TEXT,
    ADD COLUMN IF NOT EXISTS distribution_center_id UUID REFERENCES public.distribution_centers(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS platform_fees_deducted NUMERIC(14, 2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS gateway_fees_deducted NUMERIC(14, 2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS failed_attempt_fees_deducted NUMERIC(14, 2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS other_charges_deducted NUMERIC(14, 2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS charges_breakdown JSONB DEFAULT '{}'::jsonb;

-- Ensure default status is 'remitted' for pending merchant verification
ALTER TABLE IF EXISTS public.client_settlements
    ALTER COLUMN status SET DEFAULT 'remitted';

-- 2. Drop legacy function signatures to prevent signature collision
DROP FUNCTION IF EXISTS public.fn_generate_merchant_daily_settlement(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, JSONB, UUID[]);
DROP FUNCTION IF EXISTS public.fn_generate_merchant_daily_settlement(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, JSONB);
DROP FUNCTION IF EXISTS public.fn_generate_merchant_daily_settlement(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, JSONB, UUID[], TEXT, TEXT, TEXT);

-- 3. Stored Procedure: fn_generate_merchant_daily_settlement (Full 9-parameter version)
CREATE OR REPLACE FUNCTION public.fn_generate_merchant_daily_settlement(
    p_client_id UUID,
    p_dc_id UUID DEFAULT NULL,
    p_period_start TIMESTAMPTZ DEFAULT NULL,
    p_period_end TIMESTAMPTZ DEFAULT NULL,
    p_custom_deductions JSONB DEFAULT '{}'::jsonb,
    p_order_ids UUID[] DEFAULT NULL,
    p_proof_of_payment_url TEXT DEFAULT NULL,
    p_payout_reference TEXT DEFAULT NULL,
    p_status TEXT DEFAULT 'remitted'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_settlement_id UUID := gen_random_uuid();
    v_settlement_number TEXT;
    v_today_seq INT;
    v_client RECORD;
    v_dc_settings RECORD;
    
    -- Calculated Totals
    v_orders_count INT := 0;
    v_gross_collections NUMERIC(14, 2) := 0.00;
    v_delivery_fees NUMERIC(14, 2) := 0.00;
    v_failed_attempt_fees NUMERIC(14, 2) := 0.00;
    v_system_operation_fees NUMERIC(14, 2) := 0.00;
    v_gateway_fees NUMERIC(14, 2) := 0.00;
    v_other_charges NUMERIC(14, 2) := 0.00;
    v_total_platform_charges NUMERIC(14, 2) := 0.00;
    v_total_deductions NUMERIC(14, 2) := 0.00;
    v_net_payout NUMERIC(14, 2) := 0.00;
    
    -- Rates & intermediate vars
    v_order_delivery_fee NUMERIC(14, 2);
    v_order_platform_fee NUMERIC(14, 2);
    v_order_gateway_fee NUMERIC(14, 2);
    v_unit_failed_fee NUMERIC(14, 2);
    v_failed_orders_count INT := 0;
    v_charges_breakdown JSONB;
    
    v_order RECORD;
    v_order_ids_array UUID[] := '{}';
    v_eff_period_start TIMESTAMPTZ;
    v_eff_period_end TIMESTAMPTZ;
BEGIN
    -- Effective period boundaries (Default: Past 60 days up to current timestamp)
    v_eff_period_start := COALESCE(p_period_start, date_trunc('day', NOW()) - INTERVAL '60 days');
    v_eff_period_end   := COALESCE(p_period_end,   NOW());

    -- Load Client Info (using to_jsonb for schema-safe access to optional columns)
    SELECT id, name, company_name, custom_delivery_fee, custom_failed_attempt_fee, 
           custom_platform_fee, bank_name, account_number, account_name,
           to_jsonb(c) AS raw_json
    INTO v_client
    FROM public.clients c
    WHERE id = p_client_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Client not found');
    END IF;

    -- Load DC System Level Config (fallback rates)
    SELECT default_client_delivery_fee, failed_order_charge, 
           platform_fee_type, platform_fee_value, paystack_direct_fee_percent
    INTO v_dc_settings
    FROM public.dc_settings
    ORDER BY created_at ASC
    LIMIT 1;

    -- Step 1: Iterate over Delivered Orders
    IF p_order_ids IS NOT NULL AND array_length(p_order_ids, 1) > 0 THEN
        FOR v_order IN
            SELECT o.id, o.total_amount, o.client_delivery_fee, o.payment_type,
                   COALESCE(o.payment_method, o.delivery_method, 'cash') AS eff_method
            FROM public.orders o
            WHERE (o.client_id = p_client_id OR o.merchant_id = p_client_id)
              AND o.id = ANY(p_order_ids)
              AND o.status = 'delivered'
              AND (o.financial_settlement_status IS NULL OR o.financial_settlement_status != 'client_settled')
        LOOP
            v_order_ids_array := array_append(v_order_ids_array, v_order.id);
            v_orders_count := v_orders_count + 1;
            v_gross_collections := v_gross_collections + COALESCE(v_order.total_amount, 0.00);

            v_order_delivery_fee := COALESCE(v_client.custom_delivery_fee, v_order.client_delivery_fee, v_dc_settings.default_client_delivery_fee, 5000.00);
            v_delivery_fees := v_delivery_fees + v_order_delivery_fee;

            IF COALESCE(v_client.raw_json->>'custom_platform_fee_type', 'flat') = 'percentage' THEN
                v_order_platform_fee := COALESCE(v_order.total_amount, 0.00) * (COALESCE((v_client.raw_json->>'custom_platform_fee_value')::numeric, v_client.custom_platform_fee, 2.5) / 100.0);
            ELSE
                v_order_platform_fee := COALESCE((v_client.raw_json->>'custom_platform_fee_value')::numeric, v_client.custom_platform_fee, v_dc_settings.platform_fee_value, 500.00);
            END IF;
            v_system_operation_fees := v_system_operation_fees + v_order_platform_fee;

            IF LOWER(v_order.eff_method) = 'direct_transfer' OR LOWER(COALESCE(v_order.payment_type, '')) = 'direct_transfer' THEN
                v_order_gateway_fee := LEAST(2000.00, COALESCE(v_order.total_amount, 0.00) * (COALESCE(v_dc_settings.paystack_direct_fee_percent, 1.5) / 100.0));
                v_gateway_fees := v_gateway_fees + v_order_gateway_fee;
            END IF;
        END LOOP;
    ELSE
        FOR v_order IN
            SELECT o.id, o.total_amount, o.client_delivery_fee, o.payment_type,
                   COALESCE(o.payment_method, o.delivery_method, 'cash') AS eff_method
            FROM public.orders o
            WHERE (o.client_id = p_client_id OR o.merchant_id = p_client_id)
              AND (p_dc_id IS NULL OR o.distribution_center_id = p_dc_id)
              AND o.status = 'delivered'
              AND (o.financial_settlement_status IS NULL OR o.financial_settlement_status != 'client_settled')
              AND (o.delivered_at >= v_eff_period_start AND o.delivered_at <= v_eff_period_end)
        LOOP
            v_order_ids_array := array_append(v_order_ids_array, v_order.id);
            v_orders_count := v_orders_count + 1;
            v_gross_collections := v_gross_collections + COALESCE(v_order.total_amount, 0.00);

            v_order_delivery_fee := COALESCE(v_client.custom_delivery_fee, v_order.client_delivery_fee, v_dc_settings.default_client_delivery_fee, 5000.00);
            v_delivery_fees := v_delivery_fees + v_order_delivery_fee;

            IF COALESCE(v_client.raw_json->>'custom_platform_fee_type', 'flat') = 'percentage' THEN
                v_order_platform_fee := COALESCE(v_order.total_amount, 0.00) * (COALESCE((v_client.raw_json->>'custom_platform_fee_value')::numeric, v_client.custom_platform_fee, 2.5) / 100.0);
            ELSE
                v_order_platform_fee := COALESCE((v_client.raw_json->>'custom_platform_fee_value')::numeric, v_client.custom_platform_fee, v_dc_settings.platform_fee_value, 500.00);
            END IF;
            v_system_operation_fees := v_system_operation_fees + v_order_platform_fee;

            IF LOWER(v_order.eff_method) = 'direct_transfer' OR LOWER(COALESCE(v_order.payment_type, '')) = 'direct_transfer' THEN
                v_order_gateway_fee := LEAST(2000.00, COALESCE(v_order.total_amount, 0.00) * (COALESCE(v_dc_settings.paystack_direct_fee_percent, 1.5) / 100.0));
                v_gateway_fees := v_gateway_fees + v_order_gateway_fee;
            END IF;
        END LOOP;
    END IF;

    -- Zero-Order Guard
    IF v_orders_count = 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'No eligible delivered orders found for settlement',
            'orders_settled', 0,
            'gross_collections', 0.00,
            'net_payout', 0.00
        );
    END IF;

    -- Charge 2: Failed Delivery Attempt Surcharges
    v_unit_failed_fee := COALESCE(v_client.custom_failed_attempt_fee, v_dc_settings.failed_order_charge, 1000.00);
    SELECT COUNT(*) INTO v_failed_orders_count
    FROM public.orders
    WHERE (client_id = p_client_id OR merchant_id = p_client_id)
      AND status IN ('failed', 'cancelled', 'rejected', 'customer_rejected')
      AND (v_eff_period_start IS NULL OR (COALESCE(delivered_at, created_at) >= v_eff_period_start))
      AND (COALESCE(delivered_at, created_at) <= v_eff_period_end);

    v_failed_attempt_fees := v_failed_orders_count * v_unit_failed_fee;

    -- Optional custom deductions
    IF p_custom_deductions ? 'other_charges' THEN
        v_other_charges := COALESCE((p_custom_deductions->>'other_charges')::numeric, 0.00);
    END IF;

    v_total_platform_charges := v_system_operation_fees + v_gateway_fees;
    v_total_deductions := v_delivery_fees + v_failed_attempt_fees + v_total_platform_charges + v_other_charges;
    v_net_payout := GREATEST(0.00, v_gross_collections - v_total_deductions);

    -- Build itemized breakdown
    v_charges_breakdown := jsonb_build_object(
        'rate_basis', jsonb_build_object(
            'delivery_fee_per_order', COALESCE(v_client.custom_delivery_fee, v_dc_settings.default_client_delivery_fee, 5000.00),
            'failed_delivery_fee', v_unit_failed_fee,
            'platform_fee_type', COALESCE(v_client.raw_json->>'custom_platform_fee_type', 'flat'),
            'platform_fee_value', COALESCE((v_client.raw_json->>'custom_platform_fee_value')::numeric, v_client.custom_platform_fee, 500.00)
        ),
        'delivery_fees', v_delivery_fees,
        'failed_attempt_fees', v_failed_attempt_fees,
        'failed_orders_count', v_failed_orders_count,
        'platform_operations_fees', v_system_operation_fees,
        'payment_gateway_fees', v_gateway_fees,
        'other_charges', v_other_charges,
        'total_deductions', v_total_deductions,
        'proof_of_payment_url', p_proof_of_payment_url,
        'payout_reference', p_payout_reference,
        'order_ids', v_order_ids_array
    );

    -- Sequential settlement number: SETTLE-YYYYMMDD-XXX
    SELECT COUNT(*) + 1 INTO v_today_seq
    FROM public.client_settlements
    WHERE created_at >= date_trunc('day', NOW());

    v_settlement_number := 'SETTLE-' || to_char(NOW(), 'YYYYMMDD') || '-' || lpad(v_today_seq::text, 3, '0');

    -- Insert into client_settlements with accurate column mappings
    INSERT INTO public.client_settlements (
        id,
        settlement_number,
        client_id,
        distribution_center_id,
        period_start,
        period_end,
        total_orders_count,
        gross_collections,
        logistics_fees_deducted,
        platform_fees_deducted,
        gateway_fees_deducted,
        failed_attempt_fees_deducted,
        other_charges_deducted,
        net_payout_amount,
        destination_bank_name,
        destination_account_number,
        destination_account_name,
        payout_reference,
        proof_of_payment_url,
        status,
        notes,
        charges_breakdown,
        created_at,
        settled_at
    ) VALUES (
        v_settlement_id,
        v_settlement_number,
        p_client_id,
        p_dc_id,
        v_eff_period_start,
        v_eff_period_end,
        v_orders_count,
        v_gross_collections,
        v_delivery_fees,
        v_system_operation_fees,
        v_gateway_fees,
        v_failed_attempt_fees,
        v_other_charges,
        v_net_payout,
        COALESCE(v_client.bank_name, 'Access Bank'),
        COALESCE(v_client.account_number, '0123456789'),
        COALESCE(v_client.account_name, v_client.company_name, 'Merchant Account'),
        p_payout_reference,
        p_proof_of_payment_url,
        COALESCE(p_status, 'remitted'),
        COALESCE(p_custom_deductions->>'notes', 'Manual Bank Transfer Settlement Fulfilled by Central DC'),
        v_charges_breakdown,
        NOW(),
        NOW()
    );

    -- Mark orders as client_settled
    IF array_length(v_order_ids_array, 1) > 0 THEN
        UPDATE public.orders
        SET financial_settlement_status = 'client_settled',
            updated_at = NOW()
        WHERE id = ANY(v_order_ids_array);
    END IF;

    -- Return full result payload
    RETURN jsonb_build_object(
        'success', true,
        'settlement_id', v_settlement_id,
        'settlement_number', v_settlement_number,
        'client_id', p_client_id,
        'orders_settled', v_orders_count,
        'failed_orders_deducted', v_failed_orders_count,
        'gross_collections', v_gross_collections,
        'total_deductions', v_total_deductions,
        'net_payout', v_net_payout,
        'status', COALESCE(p_status, 'remitted'),
        'proof_of_payment_url', p_proof_of_payment_url,
        'payout_reference', p_payout_reference,
        'breakdown', v_charges_breakdown
    );
END;
$$;

-- 4. Overloaded 6-parameter compatibility signature
CREATE OR REPLACE FUNCTION public.fn_generate_merchant_daily_settlement(
    p_client_id UUID,
    p_dc_id UUID DEFAULT NULL,
    p_period_start TIMESTAMPTZ DEFAULT NULL,
    p_period_end TIMESTAMPTZ DEFAULT NULL,
    p_custom_deductions JSONB DEFAULT '{}'::jsonb,
    p_order_ids UUID[] DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN public.fn_generate_merchant_daily_settlement(
        p_client_id := p_client_id,
        p_dc_id := p_dc_id,
        p_period_start := p_period_start,
        p_period_end := p_period_end,
        p_custom_deductions := p_custom_deductions,
        p_order_ids := p_order_ids,
        p_proof_of_payment_url := NULL,
        p_payout_reference := NULL,
        p_status := 'remitted'
    );
END;
$$;

-- 5. Stored Procedure: fn_merchant_approve_settlement
CREATE OR REPLACE FUNCTION public.fn_merchant_approve_settlement(
    p_settlement_id UUID,
    p_client_id UUID DEFAULT NULL,
    p_approval_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_settlement RECORD;
BEGIN
    SELECT * INTO v_settlement
    FROM public.client_settlements
    WHERE id = p_settlement_id
      AND (p_client_id IS NULL OR client_id = p_client_id);
      
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Settlement record not found');
    END IF;
    
    UPDATE public.client_settlements
    SET status = 'completed',
        notes = COALESCE(notes, '') || ' | Merchant Approved & Confirmed on ' || to_char(NOW(), 'YYYY-MM-DD HH24:MI:SS') || COALESCE(' - ' || p_approval_notes, ''),
        settled_at = NOW()
    WHERE id = p_settlement_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'settlement_id', p_settlement_id,
        'status', 'completed',
        'approved_at', NOW()
    );
END;
$$;

-- 6. Permissions
GRANT EXECUTE ON FUNCTION public.fn_generate_merchant_daily_settlement(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, JSONB, UUID[], TEXT, TEXT, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_generate_merchant_daily_settlement(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, JSONB, UUID[]) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_merchant_approve_settlement(UUID, UUID, TEXT) TO authenticated, service_role, anon;
GRANT SELECT, INSERT, UPDATE ON public.client_settlements TO authenticated, service_role, anon;


-- =================== 20260921130000_financial_system_overhaul_payout_receipts_and_closer_commission.sql ===================
-- Migration: 20260921130000_financial_system_overhaul_payout_receipts_and_closer_commission.sql
-- Description: 
-- 1. Adds proof_of_payment_url to payout_requests for Rider Payout parity.
-- 2. Adds is_commission_enabled, bank details, and balance tracking to client_closers.
-- 3. Creates closer_payouts table for Telesales Closer Commission Disbursements.
-- 4. Stored procedures for Closer Payouts and Rider COD earnings parity.

-- 1. Rider Payout Proof Parity
ALTER TABLE IF EXISTS public.payout_requests 
ADD COLUMN IF NOT EXISTS proof_of_payment_url TEXT,
ADD COLUMN IF NOT EXISTS disbursed_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- 2. Optional Closer Commission & Bank Details on client_closers
ALTER TABLE IF EXISTS public.client_closers 
ADD COLUMN IF NOT EXISTS is_commission_enabled BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS bank_name TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS account_number TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS account_name TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS unpaid_commission_balance NUMERIC(14,2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS total_paid_commission NUMERIC(14,2) DEFAULT 0.00;

-- 3. Closer Payouts Table
CREATE TABLE IF NOT EXISTS public.closer_payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    closer_id UUID NOT NULL REFERENCES public.client_closers(id) ON DELETE CASCADE,
    client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    payout_number TEXT NOT NULL UNIQUE,
    amount NUMERIC(14,2) NOT NULL,
    orders_count INT NOT NULL DEFAULT 0,
    order_ids UUID[] DEFAULT '{}',
    bank_name TEXT NOT NULL,
    account_number TEXT NOT NULL,
    account_name TEXT NOT NULL,
    disbursement_ref TEXT,
    proof_of_payment_url TEXT,
    status TEXT NOT NULL DEFAULT 'remitted', -- pending, remitted, completed, rejected
    disbursed_at TIMESTAMPTZ DEFAULT NOW(),
    confirmed_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for fast closer payout querying
CREATE INDEX IF NOT EXISTS idx_closer_payouts_closer_id ON public.closer_payouts(closer_id);
CREATE INDEX IF NOT EXISTS idx_closer_payouts_client_id ON public.closer_payouts(client_id);
CREATE INDEX IF NOT EXISTS idx_closer_payouts_status ON public.closer_payouts(status);

-- Enable RLS
ALTER TABLE public.closer_payouts ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Public access to closer_payouts" ON public.closer_payouts;
CREATE POLICY "Public access to closer_payouts" ON public.closer_payouts
    FOR ALL TO authenticated, service_role, anon
    USING (true)
    WITH CHECK (true);

-- 4. Stored Procedure: fn_disburse_closer_payout
CREATE OR REPLACE FUNCTION public.fn_disburse_closer_payout(
    p_closer_id UUID,
    p_client_id UUID,
    p_amount NUMERIC,
    p_orders_count INT DEFAULT 0,
    p_order_ids UUID[] DEFAULT '{}',
    p_bank_name TEXT DEFAULT '',
    p_account_number TEXT DEFAULT '',
    p_account_name TEXT DEFAULT '',
    p_disbursement_ref TEXT DEFAULT '',
    p_proof_of_payment_url TEXT DEFAULT '',
    p_notes TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_payout_id UUID := gen_random_uuid();
    v_payout_number TEXT;
    v_closer RECORD;
BEGIN
    SELECT * INTO v_closer FROM public.client_closers WHERE id = p_closer_id;
    IF v_closer.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Closer not found.');
    END IF;

    -- Generate Unique Payout Number
    v_payout_number := 'CPAY-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');

    -- Insert payout record
    INSERT INTO public.closer_payouts (
        id,
        closer_id,
        client_id,
        payout_number,
        amount,
        orders_count,
        order_ids,
        bank_name,
        account_number,
        account_name,
        disbursement_ref,
        proof_of_payment_url,
        status,
        disbursed_at,
        notes
    ) VALUES (
        v_payout_id,
        p_closer_id,
        p_client_id,
        v_payout_number,
        p_amount,
        p_orders_count,
        p_order_ids,
        COALESCE(NULLIF(p_bank_name, ''), v_closer.bank_name, 'Bank Transfer'),
        COALESCE(NULLIF(p_account_number, ''), v_closer.account_number, ''),
        COALESCE(NULLIF(p_account_name, ''), v_closer.account_name, v_closer.full_name),
        p_disbursement_ref,
        p_proof_of_payment_url,
        'remitted',
        NOW(),
        p_notes
    );

    -- Update closer balances
    UPDATE public.client_closers
    SET 
        total_paid_commission = COALESCE(total_paid_commission, 0.00) + p_amount,
        unpaid_commission_balance = GREATEST(0.00, COALESCE(unpaid_commission_balance, 0.00) - p_amount),
        updated_at = NOW()
    WHERE id = p_closer_id;

    RETURN jsonb_build_object(
        'success', true,
        'payout_id', v_payout_id,
        'payout_number', v_payout_number,
        'amount', p_amount,
        'status', 'remitted',
        'message', 'Closer payout successfully remitted with attached receipt proof.'
    );
END;
$$;

-- 5. Stored Procedure: fn_closer_confirm_payout
CREATE OR REPLACE FUNCTION public.fn_closer_confirm_payout(
    p_payout_id UUID,
    p_closer_id UUID,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_payout RECORD;
BEGIN
    SELECT * INTO v_payout FROM public.closer_payouts WHERE id = p_payout_id AND closer_id = p_closer_id;
    IF v_payout.id IS NULL THEN
        SELECT * INTO v_payout FROM public.closer_payouts WHERE id = p_payout_id;
        IF v_payout.id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'Closer payout not found.');
        END IF;
    END IF;

    UPDATE public.closer_payouts
    SET 
        status = 'completed',
        confirmed_at = NOW(),
        notes = COALESCE(p_notes, notes),
        updated_at = NOW()
    WHERE id = p_payout_id;

    RETURN jsonb_build_object(
        'success', true,
        'payout_id', p_payout_id,
        'payout_number', v_payout.payout_number,
        'status', 'completed',
        'message', 'Payout confirmation recorded successfully.'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_disburse_closer_payout TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_closer_confirm_payout TO authenticated, service_role, anon;
GRANT ALL ON public.closer_payouts TO authenticated, service_role, anon;

NOTIFY pgrst, 'reload schema';


-- =================== 20260926213500_patch_fn_create_dc_consignment_stored_procedure.sql ===================
-- Migration: 20260926213500_patch_fn_create_dc_consignment_stored_procedure.sql
-- Description: Patch fn_create_dc_consignment_for_intake_invoice with safe product_id UUID resolution

CREATE OR REPLACE FUNCTION public.fn_create_dc_consignment_for_intake_invoice(
    p_invoice_id UUID,
    p_sender_id UUID DEFAULT NULL,
    p_sender_name TEXT DEFAULT '',
    p_sender_signature_url TEXT DEFAULT '',
    p_carrier_driver_name TEXT DEFAULT '',
    p_carrier_phone TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_inv RECORD;
    v_item RECORD;
    v_dc_id UUID;
    v_company_id UUID;
    v_transfer_id UUID;
    v_prod_id UUID;
    v_waybill TEXT;
    v_dc_name TEXT;
    v_total_units INT := 0;
BEGIN
    SELECT * INTO v_inv FROM public.client_stock_invoices WHERE id = p_invoice_id;
    IF v_inv IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invoice not found');
    END IF;

    -- Resolve destination DC by warehouse name matching
    SELECT id, name INTO v_dc_id, v_dc_name FROM public.distribution_centers 
    WHERE name ILIKE '%' || SPLIT_PART(v_inv.destination_warehouse, ' - ', 1) || '%'
       OR v_inv.destination_warehouse ILIKE '%' || name || '%'
       OR v_inv.destination_warehouse ILIKE '%' || state || '%'
    LIMIT 1;

    -- Fallback to first active DC if not matched
    IF v_dc_id IS NULL THEN
        SELECT id, name INTO v_dc_id, v_dc_name FROM public.distribution_centers LIMIT 1;
    END IF;

    -- Resolve company_id
    SELECT company_id INTO v_company_id FROM public.clients WHERE id = v_inv.client_id::UUID;
    IF v_company_id IS NULL THEN
        SELECT id INTO v_company_id FROM public.companies LIMIT 1;
    END IF;

    v_waybill := COALESCE(NULLIF(v_inv.waybill_number, ''), 'WB-INTAKE-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0'));

    -- Ensure the invoice has the waybill number and initial status is 'in_transit'
    UPDATE public.client_stock_invoices
    SET waybill_number = v_waybill,
        status = CASE WHEN status = 'draft' THEN 'in_transit' ELSE COALESCE(status, 'in_transit') END,
        updated_at = NOW()
    WHERE id = p_invoice_id;

    -- Create pending stock transfer for DC custody acceptance
    INSERT INTO public.stock_transfers (
        company_id,
        client_id,
        invoice_id,
        transfer_type,
        transfer_number,
        waybill_number,
        destination_dc_id,
        status,
        sender_id,
        sender_name,
        sender_role,
        sender_signature_url,
        carrier_driver_name,
        carrier_phone,
        dispatched_at,
        notes
    ) VALUES (
        v_company_id,
        v_inv.client_id::UUID,
        p_invoice_id,
        'client_supply',
        v_waybill,
        v_waybill,
        v_dc_id,
        'in_transit',
        p_sender_id,
        COALESCE(NULLIF(p_sender_name, ''), 'Merchant Procurement'),
        'client',
        p_sender_signature_url,
        p_carrier_driver_name,
        p_carrier_phone,
        NOW(),
        'Procurement Inbound Intake from ' || COALESCE(v_inv.supplier_name, 'Vendor') || ' (Bill: ' || v_inv.invoice_number || ')'
    ) RETURNING id INTO v_transfer_id;

    -- Copy line items into stock_transfer_items with robust UUID resolution
    FOR v_item IN SELECT * FROM public.client_stock_invoice_items WHERE invoice_id = p_invoice_id
    LOOP
        v_prod_id := NULL;
        IF v_item.product_id IS NOT NULL AND v_item.product_id::TEXT ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
            v_prod_id := v_item.product_id::UUID;
        END IF;

        IF v_prod_id IS NULL THEN
            SELECT id INTO v_prod_id FROM public.products 
            WHERE sku = v_item.product_sku OR name ILIKE v_item.product_name 
            LIMIT 1;
        END IF;

        INSERT INTO public.stock_transfer_items (
            transfer_id,
            product_id,
            quantity_shipped,
            quantity_received,
            quantity_damaged,
            quantity_missing,
            item_notes
        ) VALUES (
            v_transfer_id,
            v_prod_id,
            v_item.quantity,
            0,
            0,
            0,
            v_item.product_name || ' (SKU: ' || v_item.product_sku || ')'
        );
        v_total_units := v_total_units + v_item.quantity;
    END LOOP;

    -- Send Realtime Notification to DC Personnel
    BEGIN
        INSERT INTO public.notifications (
            company_id,
            title,
            message,
            category,
            action_route,
            is_read
        ) VALUES (
            v_company_id,
            'Inbound Consignment Dispatched: ' || v_waybill,
            'Merchant dispatched ' || v_total_units || ' units from ' || COALESCE(v_inv.supplier_name, 'Vendor') || ' to ' || COALESCE(v_dc_name, 'Hub') || '. Physical reception verification required.',
            'inventory',
            '/dc/stock',
            false
        );
    EXCEPTION WHEN OTHERS THEN
        -- Non-blocking notification failure
    END;

    RETURN jsonb_build_object(
        'success', true,
        'invoice_id', p_invoice_id,
        'transfer_id', v_transfer_id,
        'destination_dc_id', v_dc_id,
        'destination_dc_name', v_dc_name,
        'waybill_number', v_waybill,
        'total_units', v_total_units
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_create_dc_consignment_for_intake_invoice TO authenticated, service_role, anon;


-- =================== 20260926214000_patch_fn_create_dc_consignment_stored_procedure_v2.sql ===================
-- Migration: 20260926214000_patch_fn_create_dc_consignment_stored_procedure_v2.sql
-- Description: Patch fn_create_dc_consignment_for_intake_invoice with safe product_id UUID resolution

CREATE OR REPLACE FUNCTION public.fn_create_dc_consignment_for_intake_invoice(
    p_invoice_id UUID,
    p_sender_id UUID DEFAULT NULL,
    p_sender_name TEXT DEFAULT '',
    p_sender_signature_url TEXT DEFAULT '',
    p_carrier_driver_name TEXT DEFAULT '',
    p_carrier_phone TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_inv RECORD;
    v_item RECORD;
    v_dc_id UUID;
    v_company_id UUID;
    v_transfer_id UUID;
    v_prod_id UUID;
    v_waybill TEXT;
    v_dc_name TEXT;
    v_total_units INT := 0;
BEGIN
    SELECT * INTO v_inv FROM public.client_stock_invoices WHERE id = p_invoice_id;
    IF v_inv IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invoice not found');
    END IF;

    -- Resolve destination DC by warehouse name matching
    SELECT id, name INTO v_dc_id, v_dc_name FROM public.distribution_centers 
    WHERE name ILIKE '%' || SPLIT_PART(v_inv.destination_warehouse, ' - ', 1) || '%'
       OR v_inv.destination_warehouse ILIKE '%' || name || '%'
       OR v_inv.destination_warehouse ILIKE '%' || state || '%'
    LIMIT 1;

    -- Fallback to first active DC if not matched
    IF v_dc_id IS NULL THEN
        SELECT id, name INTO v_dc_id, v_dc_name FROM public.distribution_centers LIMIT 1;
    END IF;

    -- Resolve company_id
    SELECT company_id INTO v_company_id FROM public.clients WHERE id = v_inv.client_id::UUID;
    IF v_company_id IS NULL THEN
        SELECT id INTO v_company_id FROM public.companies LIMIT 1;
    END IF;

    v_waybill := COALESCE(NULLIF(v_inv.waybill_number, ''), 'WB-INTAKE-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0'));

    -- Ensure the invoice has the waybill number and initial status is 'in_transit'
    UPDATE public.client_stock_invoices
    SET waybill_number = v_waybill,
        status = CASE WHEN status = 'draft' THEN 'in_transit' ELSE COALESCE(status, 'in_transit') END,
        updated_at = NOW()
    WHERE id = p_invoice_id;

    -- Create pending stock transfer for DC custody acceptance
    INSERT INTO public.stock_transfers (
        company_id,
        client_id,
        invoice_id,
        transfer_type,
        transfer_number,
        waybill_number,
        destination_dc_id,
        status,
        sender_id,
        sender_name,
        sender_role,
        sender_signature_url,
        carrier_driver_name,
        carrier_phone,
        dispatched_at,
        notes
    ) VALUES (
        v_company_id,
        v_inv.client_id::UUID,
        p_invoice_id,
        'client_supply',
        v_waybill,
        v_waybill,
        v_dc_id,
        'in_transit',
        p_sender_id,
        COALESCE(NULLIF(p_sender_name, ''), 'Merchant Procurement'),
        'client',
        p_sender_signature_url,
        p_carrier_driver_name,
        p_carrier_phone,
        NOW(),
        'Procurement Inbound Intake from ' || COALESCE(v_inv.supplier_name, 'Vendor') || ' (Bill: ' || v_inv.invoice_number || ')'
    ) RETURNING id INTO v_transfer_id;

    -- Copy line items into stock_transfer_items with robust UUID resolution
    FOR v_item IN SELECT * FROM public.client_stock_invoice_items WHERE invoice_id = p_invoice_id
    LOOP
        v_prod_id := NULL;
        IF v_item.product_id IS NOT NULL AND v_item.product_id::TEXT ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
            v_prod_id := v_item.product_id::UUID;
        END IF;

        IF v_prod_id IS NULL THEN
            SELECT id INTO v_prod_id FROM public.products 
            WHERE sku = v_item.product_sku OR name ILIKE v_item.product_name 
            LIMIT 1;
        END IF;

        INSERT INTO public.stock_transfer_items (
            transfer_id,
            product_id,
            quantity_shipped,
            quantity_received,
            quantity_damaged,
            quantity_missing,
            item_notes
        ) VALUES (
            v_transfer_id,
            v_prod_id,
            v_item.quantity,
            0,
            0,
            0,
            v_item.product_name || ' (SKU: ' || v_item.product_sku || ')'
        );
        v_total_units := v_total_units + v_item.quantity;
    END LOOP;

    -- Send Realtime Notification to DC Personnel
    BEGIN
        INSERT INTO public.notifications (
            company_id,
            title,
            message,
            category,
            action_route,
            is_read
        ) VALUES (
            v_company_id,
            'Inbound Consignment Dispatched: ' || v_waybill,
            'Merchant dispatched ' || v_total_units || ' units from ' || COALESCE(v_inv.supplier_name, 'Vendor') || ' to ' || COALESCE(v_dc_name, 'Hub') || '. Physical reception verification required.',
            'inventory',
            '/dc/stock',
            false
        );
    EXCEPTION WHEN OTHERS THEN
        -- Non-blocking notification failure
    END;

    RETURN jsonb_build_object(
        'success', true,
        'invoice_id', p_invoice_id,
        'transfer_id', v_transfer_id,
        'destination_dc_id', v_dc_id,
        'destination_dc_name', v_dc_name,
        'waybill_number', v_waybill,
        'total_units', v_total_units
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_create_dc_consignment_for_intake_invoice TO authenticated, service_role, anon;


-- =================== 20260926233000_fn_get_product_holders_custody.sql ===================
-- ==============================================================================
-- Migration: 20260926233000_fn_get_product_holders_custody.sql
-- Description: Comprehensive multi-holder physical asset custody ledger
--              combining Distribution Centers, PDAs (Dispatch Riders), and Depots
--              with period opening, in, out, closing balances, and valuations.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.fn_get_product_holders_custody(
    p_client_id UUID,
    p_product_id UUID DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_state TEXT DEFAULT NULL,
    p_lga TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_results JSONB := '[]'::JSONB;
    v_start DATE := COALESCE(p_start_date, CURRENT_DATE - INTERVAL '30 days');
    v_end DATE := COALESCE(p_end_date, CURRENT_DATE);
    v_row RECORD;
BEGIN
    -- 1. Distribution Center & Central Warehouse Positions
    FOR v_row IN
        SELECT 
            sb.id,
            sb.warehouse AS holder_name,
            COALESCE(dc.id::TEXT, sb.id::TEXT) AS holder_id,
            CASE 
                WHEN LOWER(sb.warehouse) LIKE '%center%' OR LOWER(sb.warehouse) LIKE '%hub%' OR LOWER(sb.warehouse) LIKE '%dc%' THEN 'Distribution Center'
                ELSE 'Central Storage / In-Transit'
            END AS holder_type,
            COALESCE(dc.state, 'Lagos') AS state,
            COALESCE(dc.city, '') AS city,
            COALESCE(dc.operating_zones[1], '') AS lga,
            COALESCE(dc.contact_phone, '') AS phone,
            p.id::TEXT AS product_id,
            sb.item_code AS product_sku,
            sb.item_name AS product_name,
            COALESCE(sb.opening_qty, sb.balance_qty)::INT AS opening_qty,
            COALESCE(sb.opening_value, sb.balance_value)::NUMERIC(14,2) AS opening_value,
            COALESCE(sb.in_qty, 0)::INT AS in_qty,
            COALESCE(sb.in_value, 0)::NUMERIC(14,2) AS in_value,
            COALESCE(sb.out_qty, 0)::INT AS out_qty,
            COALESCE(sb.out_value, 0)::NUMERIC(14,2) AS out_value,
            COALESCE(sb.balance_qty, 0)::INT AS closing_qty,
            COALESCE(sb.balance_value, 0)::NUMERIC(14,2) AS closing_value,
            COALESCE(sb.valuation_rate, p.base_price, 0.00)::NUMERIC(14,2) AS valuation_rate,
            sb.updated_at AS last_updated,
            CASE 
                WHEN sb.balance_qty <= 0 THEN 'Out of Stock'
                WHEN sb.balance_qty <= COALESCE(sb.low_stock_threshold, 10) THEN 'Low Stock'
                ELSE 'Active Custody'
            END AS status
        FROM public.client_stock_balances sb
        LEFT JOIN public.products p ON (p.id = sb.product_id OR p.sku = sb.item_code OR LOWER(p.name) = LOWER(sb.item_name))
        LEFT JOIN public.distribution_centers dc ON (LOWER(dc.name) = LOWER(sb.warehouse) OR LOWER(sb.warehouse) LIKE '%' || LOWER(dc.name) || '%')
        WHERE sb.client_id = p_client_id
          AND (p_product_id IS NULL OR p.id = p_product_id)
          AND (p_state IS NULL OR p_state = 'All States' OR LOWER(COALESCE(dc.state, 'Lagos')) = LOWER(p_state))
          AND (p_lga IS NULL OR p_lga = 'All LGAs' OR LOWER(COALESCE(dc.operating_zones[1], '')) LIKE '%' || LOWER(p_lga) || '%')
    LOOP
        v_results := v_results || jsonb_build_object(
            'id', v_row.id,
            'holder_id', v_row.holder_id,
            'holder_name', v_row.holder_name,
            'holder_type', v_row.holder_type,
            'state', v_row.state,
            'lga', v_row.lga,
            'city', v_row.city,
            'phone', v_row.phone,
            'product_id', v_row.product_id,
            'product_sku', v_row.product_sku,
            'product_name', v_row.product_name,
            'opening_qty', v_row.opening_qty,
            'opening_value', v_row.opening_value,
            'in_qty', v_row.in_qty,
            'in_value', v_row.in_value,
            'out_qty', v_row.out_qty,
            'out_value', v_row.out_value,
            'closing_qty', v_row.closing_qty,
            'closing_value', v_row.closing_value,
            'valuation_rate', v_row.valuation_rate,
            'last_updated', v_row.last_updated,
            'status', v_row.status
        );
    END LOOP;

    -- 2. Delivery Personnel & PDA Custody Positions (agent_inventory)
    FOR v_row IN
        SELECT 
            ai.id,
            da.id::TEXT AS holder_id,
            COALESCE(da.bank_account_name, da.agent_code, 'Dispatch PDA') || ' (' || COALESCE(da.agent_code, 'PDA') || ')' AS holder_name,
            'PDA / Dispatch Personnel' AS holder_type,
            COALESCE(da.operating_state, 'Abuja (FCT)') AS state,
            COALESCE(da.operating_city, '') AS city,
            COALESCE(da.operating_city, '') AS lga,
            '' AS phone,
            p.id::TEXT AS product_id,
            p.sku AS product_sku,
            p.name AS product_name,
            COALESCE(ai.total_in_custody, 0)::INT AS opening_qty,
            (COALESCE(ai.total_in_custody, 0) * COALESCE(p.base_price, 0.00))::NUMERIC(14,2) AS opening_value,
            0::INT AS in_qty,
            0.00::NUMERIC(14,2) AS in_value,
            COALESCE(ai.delivered_count_today, 0)::INT AS out_qty,
            (COALESCE(ai.delivered_count_today, 0) * COALESCE(p.base_price, 0.00))::NUMERIC(14,2) AS out_value,
            COALESCE(ai.available_count, ai.total_in_custody, 0)::INT AS closing_qty,
            (COALESCE(ai.available_count, ai.total_in_custody, 0) * COALESCE(p.base_price, 0.00))::NUMERIC(14,2) AS closing_value,
            COALESCE(p.base_price, 0.00)::NUMERIC(14,2) AS valuation_rate,
            ai.updated_at AS last_updated,
            CASE 
                WHEN COALESCE(ai.available_count, 0) <= 0 THEN 'Out of Stock'
                WHEN COALESCE(ai.available_count, 0) <= 5 THEN 'Low Stock'
                ELSE 'Active Custody'
            END AS status
        FROM public.agent_inventory ai
        JOIN public.products p ON p.id = ai.product_id
        JOIN public.delivery_agents da ON da.id = ai.delivery_agent_id
        WHERE (p.client_id = p_client_id OR p.client_name IN (SELECT company_name FROM public.clients WHERE id = p_client_id))
          AND (p_product_id IS NULL OR p.id = p_product_id)
          AND (p_state IS NULL OR p_state = 'All States' OR LOWER(COALESCE(da.operating_state, '')) = LOWER(p_state))
          AND (p_lga IS NULL OR p_lga = 'All LGAs' OR LOWER(COALESCE(da.operating_city, '')) LIKE '%' || LOWER(p_lga) || '%')
    LOOP
        v_results := v_results || jsonb_build_object(
            'id', v_row.id,
            'holder_id', v_row.holder_id,
            'holder_name', v_row.holder_name,
            'holder_type', v_row.holder_type,
            'state', v_row.state,
            'lga', v_row.lga,
            'city', v_row.city,
            'phone', v_row.phone,
            'product_id', v_row.product_id,
            'product_sku', v_row.product_sku,
            'product_name', v_row.product_name,
            'opening_qty', v_row.opening_qty,
            'opening_value', v_row.opening_value,
            'in_qty', v_row.in_qty,
            'in_value', v_row.in_value,
            'out_qty', v_row.out_qty,
            'out_value', v_row.out_value,
            'closing_qty', v_row.closing_qty,
            'closing_value', v_row.closing_value,
            'valuation_rate', v_row.valuation_rate,
            'last_updated', v_row.last_updated,
            'status', v_row.status
        );
    END LOOP;

    RETURN v_results;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_get_product_holders_custody(UUID, UUID, DATE, DATE, TEXT, TEXT) TO authenticated, service_role, anon;


-- =================== 20260927010000_dc_tier_hierarchy_and_reception_architecture.sql ===================
-- ============================================================================
-- NOVAXPRESS LOGISTICS PLATFORM - DC TIER HIERARCHY & RECEPTION ARCHITECTURE
-- Production-grade schema & triggers for:
--   1. Grand DC (Wuse Central branch default)
--   2. Hub Distribution Center (Regional Hubs)
--   3. General Distribution Center (Branch/Local DCs)
--   4. Reception to ANY DC with default to Grand DC
-- ============================================================================

-- 1. Add dc_type column with check constraint
ALTER TABLE public.distribution_centers
  ADD COLUMN IF NOT EXISTS dc_type VARCHAR(50) DEFAULT 'general_dc';

-- Ensure constraint exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_distribution_centers_dc_type'
  ) THEN
    ALTER TABLE public.distribution_centers
      ADD CONSTRAINT chk_distribution_centers_dc_type
      CHECK (dc_type IN ('grand_dc', 'hub_dc', 'general_dc'));
  END IF;
END $$;

-- 2. Populate and standardize existing distribution centers
-- Wuse Central Distribution Hub is the Grand DC (Central DC Default)
UPDATE public.distribution_centers
SET dc_type = 'grand_dc',
    is_grand_dc = true,
    is_hub = true,
    is_primary_dc = true,
    name = CASE 
      WHEN name NOT ILIKE '%Grand%' THEN 'Wuse Grand Central Distribution Center' 
      ELSE name 
    END
WHERE code = 'DC-WUSE-01' 
   OR id = '22222222-2222-4222-8222-222222222222'
   OR is_grand_dc = true;

-- Hub Distribution Centers (is_hub = true and not grand)
UPDATE public.distribution_centers
SET dc_type = 'hub_dc',
    is_grand_dc = false,
    is_hub = true
WHERE (is_hub = true) 
  AND (is_grand_dc = false OR is_grand_dc IS NULL)
  AND (code != 'DC-WUSE-01' AND id != '22222222-2222-4222-8222-222222222222');

-- General Distribution Centers (all other local / satellite stations)
UPDATE public.distribution_centers
SET dc_type = 'general_dc',
    is_grand_dc = false,
    is_hub = false
WHERE dc_type IS NULL OR (is_hub = false AND is_grand_dc = false);

-- 3. Automatic Synchronization Trigger for DC Tiers
CREATE OR REPLACE FUNCTION public.fn_sync_dc_tier_fields()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.dc_type = 'grand_dc' THEN
    NEW.is_grand_dc := true;
    NEW.is_hub := true;
  ELSIF NEW.dc_type = 'hub_dc' THEN
    NEW.is_grand_dc := false;
    NEW.is_hub := true;
  ELSIF NEW.dc_type = 'general_dc' THEN
    NEW.is_grand_dc := false;
    NEW.is_hub := false;
  ELSIF NEW.is_grand_dc = true THEN
    NEW.dc_type := 'grand_dc';
    NEW.is_hub := true;
  ELSIF NEW.is_hub = true THEN
    NEW.dc_type := 'hub_dc';
    NEW.is_grand_dc := false;
  ELSE
    NEW.dc_type := 'general_dc';
    NEW.is_grand_dc := false;
    NEW.is_hub := false;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_dc_tier_fields ON public.distribution_centers;
CREATE TRIGGER trg_sync_dc_tier_fields
  BEFORE INSERT OR UPDATE ON public.distribution_centers
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_sync_dc_tier_fields();

-- 4. Stored Procedure: Comprehensive Product Custody Holders
-- Aggregates balances across Grand DC, Hub DCs, General DCs, and PDA Riders
CREATE OR REPLACE FUNCTION public.fn_get_product_holders_custody(
    p_client_id UUID DEFAULT NULL,
    p_start_date TIMESTAMPTZ DEFAULT NULL,
    p_end_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
    id TEXT,
    holder_id TEXT,
    holder_name TEXT,
    holder_type TEXT,
    state TEXT,
    lga TEXT,
    city TEXT,
    phone TEXT,
    product_id TEXT,
    product_sku TEXT,
    product_name TEXT,
    opening_qty INT,
    opening_value NUMERIC,
    in_qty INT,
    out_qty INT,
    closing_qty INT,
    valuation_rate NUMERIC,
    closing_value NUMERIC,
    last_updated TIMESTAMPTZ,
    status TEXT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_start TIMESTAMPTZ := COALESCE(p_start_date, NOW() - INTERVAL '30 days');
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
BEGIN
    RETURN QUERY
    -- 1. Distribution Centers (Grand DC, Hub DC, General DC)
    SELECT
        ('dc-custody-' || COALESCE(dc.id::TEXT, sb.id::TEXT))::TEXT AS id,
        COALESCE(dc.id::TEXT, 'dc-wuse-01')::TEXT AS holder_id,
        COALESCE(dc.name, sb.warehouse)::TEXT AS holder_name,
        (CASE 
            WHEN dc.dc_type = 'grand_dc' OR dc.is_grand_dc = true THEN 'Grand DC'
            WHEN dc.dc_type = 'hub_dc' OR dc.is_hub = true THEN 'Hub Distribution Center'
            ELSE 'General Distribution Center'
        END)::TEXT AS holder_type,
        COALESCE(dc.state, 'Abuja (FCT)')::TEXT AS state,
        COALESCE((dc.operating_zones->>0), dc.city, 'Abuja Municipal')::TEXT AS lga,
        COALESCE(dc.city, 'Abuja')::TEXT AS city,
        COALESCE(dc.contact_phone, '+234 803 111 2233')::TEXT AS phone,
        COALESCE(p.id::TEXT, sb.item_code)::TEXT AS product_id,
        sb.item_code::TEXT AS product_sku,
        sb.item_name::TEXT AS product_name,
        COALESCE(sb.opening_qty, 0)::INT AS opening_qty,
        COALESCE(sb.opening_value, 0.0)::NUMERIC AS opening_value,
        COALESCE(sb.in_qty, 0)::INT AS in_qty,
        COALESCE(sb.out_qty, 0)::INT AS out_qty,
        COALESCE(sb.balance_qty, 0)::INT AS closing_qty,
        COALESCE(sb.valuation_rate, 0.0)::NUMERIC AS valuation_rate,
        COALESCE(sb.balance_value, 0.0)::NUMERIC AS closing_value,
        COALESCE(sb.updated_at, NOW())::TIMESTAMPTZ AS last_updated,
        (CASE 
            WHEN sb.balance_qty <= 0 THEN 'Out of Stock'
            WHEN sb.balance_qty <= 10 THEN 'Low Stock'
            ELSE 'Active Custody'
        END)::TEXT AS status
    FROM public.client_stock_balances sb
    LEFT JOIN public.distribution_centers dc 
      ON (LOWER(dc.name) = LOWER(sb.warehouse) OR LOWER(sb.warehouse) LIKE '%' || LOWER(dc.name) || '%')
    LEFT JOIN public.products p 
      ON (p.sku = sb.item_code AND (p_client_id IS NULL OR p.client_id = p_client_id))
    WHERE (p_client_id IS NULL OR sb.client_id = p_client_id)

    UNION ALL

    -- 2. Active PDA Riders / Delivery Agents
    SELECT
        ('pda-custody-' || ai.id::TEXT)::TEXT AS id,
        da.id::TEXT AS holder_id,
        (da.full_name || ' (' || COALESCE(da.agent_code, 'PDA') || ')')::TEXT AS holder_name,
        'PDA / Dispatch Personnel'::TEXT AS holder_type,
        COALESCE(dc.state, 'Abuja (FCT)')::TEXT AS state,
        COALESCE((dc.operating_zones->>0), 'Abuja Municipal')::TEXT AS lga,
        COALESCE(dc.city, 'Abuja')::TEXT AS city,
        COALESCE(da.phone_number, '+234 812 000 0000')::TEXT AS phone,
        p.id::TEXT AS product_id,
        p.sku::TEXT AS product_sku,
        p.name::TEXT AS product_name,
        GREATEST(0, (ai.quantity_received - ai.quantity_delivered - ai.quantity_returned))::INT AS opening_qty,
        (GREATEST(0, (ai.quantity_received - ai.quantity_delivered - ai.quantity_returned)) * COALESCE(p.cost_price, 15000.0))::NUMERIC AS opening_value,
        COALESCE(ai.quantity_received, 0)::INT AS in_qty,
        COALESCE(ai.quantity_delivered, 0)::INT AS out_qty,
        GREATEST(0, (ai.quantity_received - ai.quantity_delivered - ai.quantity_returned))::INT AS closing_qty,
        COALESCE(p.cost_price, 15000.0)::NUMERIC AS valuation_rate,
        (GREATEST(0, (ai.quantity_received - ai.quantity_delivered - ai.quantity_returned)) * COALESCE(p.cost_price, 15000.0))::NUMERIC AS closing_value,
        COALESCE(ai.updated_at, NOW())::TIMESTAMPTZ AS last_updated,
        (CASE 
            WHEN (ai.quantity_received - ai.quantity_delivered - ai.quantity_returned) <= 0 THEN 'Out of Stock'
            WHEN (ai.quantity_received - ai.quantity_delivered - ai.quantity_returned) <= 5 THEN 'Low Stock'
            ELSE 'Active Custody'
        END)::TEXT AS status
    FROM public.agent_inventory ai
    JOIN public.delivery_agents da ON da.id = ai.agent_id
    JOIN public.products p ON p.id = ai.product_id
    LEFT JOIN public.distribution_centers dc ON dc.id = da.distribution_center_id
    WHERE (p_client_id IS NULL OR p.client_id = p_client_id)
      AND (ai.quantity_received - ai.quantity_delivered - ai.quantity_returned) > 0;
END;
$$;

-- 5. Stored Procedure for Consignment Reception: Support ANY DC with Grand DC fallback
CREATE OR REPLACE FUNCTION public.fn_create_dc_consignment_for_intake_invoice(
    p_invoice_id UUID,
    p_sender_id UUID DEFAULT NULL,
    p_sender_name TEXT DEFAULT '',
    p_sender_signature_url TEXT DEFAULT '',
    p_carrier_driver_name TEXT DEFAULT '',
    p_carrier_phone TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_inv RECORD;
    v_item RECORD;
    v_dc_id UUID;
    v_company_id UUID;
    v_transfer_id UUID;
    v_prod_id UUID;
    v_waybill TEXT;
    v_dc_name TEXT;
    v_total_units INT := 0;
BEGIN
    SELECT * INTO v_inv FROM public.client_stock_invoices WHERE id = p_invoice_id;
    IF v_inv IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invoice not found');
    END IF;

    -- Match targeted receiving DC across ANY tier (Grand DC, Hub DC, or General DC)
    SELECT id, name INTO v_dc_id, v_dc_name FROM public.distribution_centers 
    WHERE name ILIKE '%' || SPLIT_PART(v_inv.destination_warehouse, ' - ', 1) || '%'
       OR v_inv.destination_warehouse ILIKE '%' || name || '%'
       OR v_inv.destination_warehouse ILIKE '%' || state || '%'
       OR v_inv.destination_warehouse ILIKE '%' || code || '%'
    LIMIT 1;

    -- If not matched, default to Grand DC (Wuse Central branch default)
    IF v_dc_id IS NULL THEN
        SELECT id, name INTO v_dc_id, v_dc_name FROM public.distribution_centers 
        WHERE dc_type = 'grand_dc' OR is_grand_dc = true OR code = 'DC-WUSE-01'
        ORDER BY created_at ASC LIMIT 1;
    END IF;

    -- Final fallback if Grand DC is not seeded yet
    IF v_dc_id IS NULL THEN
        SELECT id, name INTO v_dc_id, v_dc_name FROM public.distribution_centers LIMIT 1;
    END IF;

    -- Resolve company_id
    SELECT company_id INTO v_company_id FROM public.clients WHERE id = v_inv.client_id::UUID;
    IF v_company_id IS NULL THEN
        SELECT id INTO v_company_id FROM public.companies LIMIT 1;
    END IF;

    v_waybill := COALESCE(NULLIF(v_inv.waybill_number, ''), 'WB-INTAKE-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0'));

    -- Ensure invoice has the waybill number and initial status is 'in_transit'
    UPDATE public.client_stock_invoices
    SET waybill_number = v_waybill,
        status = CASE WHEN status = 'draft' THEN 'in_transit' ELSE COALESCE(status, 'in_transit') END,
        updated_at = NOW()
    WHERE id = p_invoice_id;

    -- Create pending stock transfer for DC custody acceptance
    INSERT INTO public.stock_transfers (
        source_dc_id,
        destination_dc_id,
        source_type,
        destination_type,
        status,
        transfer_notes,
        created_at,
        updated_at
    ) VALUES (
        NULL,
        v_dc_id,
        'supplier_intake',
        'dc_warehouse',
        'in_transit',
        'Supplier intake invoice ' || v_inv.invoice_number || ' bound for ' || v_dc_name || ' [' || v_waybill || ']',
        NOW(),
        NOW()
    ) RETURNING id INTO v_transfer_id;

    -- Create transfer items from invoice line items
    FOR v_item IN SELECT * FROM public.client_stock_invoice_items WHERE invoice_id = p_invoice_id LOOP
        SELECT id INTO v_prod_id FROM public.products 
        WHERE (sku = v_item.product_sku OR id::TEXT = v_item.product_id)
        LIMIT 1;

        INSERT INTO public.stock_transfer_items (
            transfer_id,
            product_id,
            quantity,
            notes
        ) VALUES (
            v_transfer_id,
            COALESCE(v_prod_id, '00000000-0000-0000-0000-000000000000'::UUID),
            v_item.quantity,
            'Landed cost per unit: ' || v_item.effective_landed_cost_per_unit
        );
        v_total_units := v_total_units + v_item.quantity;
    END LOOP;

    -- Create DC Supply Intake Record
    INSERT INTO public.dc_supply_intake_records (
        invoice_id,
        transfer_id,
        distribution_center_id,
        company_id,
        waybill_number,
        expected_units,
        carrier_driver_name,
        carrier_phone,
        status,
        sender_id,
        sender_name,
        sender_signature_url,
        notes
    ) VALUES (
        p_invoice_id,
        v_transfer_id,
        v_dc_id,
        v_company_id,
        v_waybill,
        v_total_units,
        p_carrier_driver_name,
        p_carrier_phone,
        'dispatched',
        p_sender_id,
        p_sender_name,
        p_sender_signature_url,
        'Consignment created for reception at ' || v_dc_name
    ) ON CONFLICT (invoice_id) DO UPDATE SET
        distribution_center_id = EXCLUDED.distribution_center_id,
        carrier_driver_name = EXCLUDED.carrier_driver_name,
        carrier_phone = EXCLUDED.carrier_phone,
        status = 'dispatched',
        updated_at = NOW();

    RETURN jsonb_build_object(
        'success', true,
        'transfer_id', v_transfer_id,
        'waybill_number', v_waybill,
        'destination_dc_id', v_dc_id,
        'destination_dc_name', v_dc_name,
        'total_units', v_total_units
    );
END;
$$;


-- =================== 20260927011000_drop_old_fn_get_product_holders_custody.sql ===================
-- Drop old conflicting 3-parameter overload of fn_get_product_holders_custody
DROP FUNCTION IF EXISTS public.fn_get_product_holders_custody(UUID, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE);
DROP FUNCTION IF EXISTS public.fn_get_product_holders_custody(UUID, TIMESTAMP, TIMESTAMP);


-- =================== 20260927012000_patch_fn_get_product_holders_custody_types.sql ===================
-- ==============================================================================
-- Migration: 20260927012000_patch_fn_get_product_holders_custody_types.sql
-- Description: Explicit type casting for sb.client_id (TEXT) and p.id (UUID)
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.fn_get_product_holders_custody(
    p_client_id UUID,
    p_product_id UUID DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_state TEXT DEFAULT NULL,
    p_lga TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_results JSONB := '[]'::JSONB;
    v_row RECORD;
BEGIN
    -- 1. Distribution Center & Central Warehouse Positions
    FOR v_row IN
        SELECT 
            sb.id,
            sb.warehouse AS holder_name,
            COALESCE(dc.id::TEXT, sb.id::TEXT) AS holder_id,
            CASE 
                WHEN LOWER(sb.warehouse) LIKE '%center%' OR LOWER(sb.warehouse) LIKE '%hub%' OR LOWER(sb.warehouse) LIKE '%dc%' THEN 'Distribution Center'
                ELSE 'Central Storage / In-Transit'
            END AS holder_type,
            COALESCE(dc.state, 'Lagos') AS state,
            COALESCE(dc.city, '') AS city,
            COALESCE(dc.operating_zones[1], '') AS lga,
            COALESCE(dc.contact_phone, '') AS phone,
            COALESCE(p.id::TEXT, sb.product_id, '') AS product_id,
            sb.item_code AS product_sku,
            sb.item_name AS product_name,
            COALESCE(sb.opening_qty, sb.balance_qty)::INT AS opening_qty,
            COALESCE(sb.opening_value, sb.balance_value)::NUMERIC(14,2) AS opening_value,
            COALESCE(sb.in_qty, 0)::INT AS in_qty,
            COALESCE(sb.in_value, 0)::NUMERIC(14,2) AS in_value,
            COALESCE(sb.out_qty, 0)::INT AS out_qty,
            COALESCE(sb.out_value, 0)::NUMERIC(14,2) AS out_value,
            COALESCE(sb.balance_qty, 0)::INT AS closing_qty,
            COALESCE(sb.balance_value, 0)::NUMERIC(14,2) AS closing_value,
            COALESCE(sb.valuation_rate, p.base_price, 0.00)::NUMERIC(14,2) AS valuation_rate,
            sb.updated_at AS last_updated,
            CASE 
                WHEN sb.balance_qty <= 0 THEN 'Out of Stock'
                WHEN sb.balance_qty <= COALESCE(sb.low_stock_threshold, 10) THEN 'Low Stock'
                ELSE 'Active Custody'
            END AS status
        FROM public.client_stock_balances sb
        LEFT JOIN public.products p ON (p.id::TEXT = sb.product_id OR p.sku = sb.item_code OR LOWER(p.name) = LOWER(sb.item_name))
        LEFT JOIN public.distribution_centers dc ON (LOWER(dc.name) = LOWER(sb.warehouse) OR LOWER(sb.warehouse) LIKE '%' || LOWER(dc.name) || '%')
        WHERE sb.client_id = p_client_id::TEXT
          AND (p_product_id IS NULL OR p.id = p_product_id OR sb.product_id = p_product_id::TEXT)
          AND (p_state IS NULL OR p_state = 'All States' OR LOWER(COALESCE(dc.state, 'Lagos')) = LOWER(p_state))
          AND (p_lga IS NULL OR p_lga = 'All LGAs' OR LOWER(COALESCE(dc.operating_zones[1], '')) LIKE '%' || LOWER(p_lga) || '%')
    LOOP
        v_results := v_results || jsonb_build_object(
            'id', v_row.id,
            'holder_id', v_row.holder_id,
            'holder_name', v_row.holder_name,
            'holder_type', v_row.holder_type,
            'state', v_row.state,
            'lga', v_row.lga,
            'city', v_row.city,
            'phone', v_row.phone,
            'product_id', v_row.product_id,
            'product_sku', v_row.product_sku,
            'product_name', v_row.product_name,
            'opening_qty', v_row.opening_qty,
            'opening_value', v_row.opening_value,
            'in_qty', v_row.in_qty,
            'in_value', v_row.in_value,
            'out_qty', v_row.out_qty,
            'out_value', v_row.out_value,
            'closing_qty', v_row.closing_qty,
            'closing_value', v_row.closing_value,
            'valuation_rate', v_row.valuation_rate,
            'last_updated', v_row.last_updated,
            'status', v_row.status
        );
    END LOOP;

    -- 2. Delivery Personnel & PDA Custody Positions (agent_inventory)
    FOR v_row IN
        SELECT 
            ai.id,
            da.id::TEXT AS holder_id,
            COALESCE(da.bank_account_name, da.agent_code, 'Dispatch PDA') || ' (' || COALESCE(da.agent_code, 'PDA') || ')' AS holder_name,
            'PDA / Dispatch Personnel' AS holder_type,
            COALESCE(da.operating_state, 'Abuja (FCT)') AS state,
            COALESCE(da.operating_city, '') AS city,
            COALESCE(da.operating_city, '') AS lga,
            '' AS phone,
            p.id::TEXT AS product_id,
            p.sku AS product_sku,
            p.name AS product_name,
            COALESCE(ai.total_in_custody, 0)::INT AS opening_qty,
            (COALESCE(ai.total_in_custody, 0) * COALESCE(p.base_price, 0.00))::NUMERIC(14,2) AS opening_value,
            0::INT AS in_qty,
            0.00::NUMERIC(14,2) AS in_value,
            COALESCE(ai.delivered_count_today, 0)::INT AS out_qty,
            (COALESCE(ai.delivered_count_today, 0) * COALESCE(p.base_price, 0.00))::NUMERIC(14,2) AS out_value,
            COALESCE(ai.available_count, ai.total_in_custody, 0)::INT AS closing_qty,
            (COALESCE(ai.available_count, ai.total_in_custody, 0) * COALESCE(p.base_price, 0.00))::NUMERIC(14,2) AS closing_value,
            COALESCE(p.base_price, 0.00)::NUMERIC(14,2) AS valuation_rate,
            ai.updated_at AS last_updated,
            CASE 
                WHEN COALESCE(ai.available_count, 0) <= 0 THEN 'Out of Stock'
                WHEN COALESCE(ai.available_count, 0) <= 5 THEN 'Low Stock'
                ELSE 'Active Custody'
            END AS status
        FROM public.agent_inventory ai
        JOIN public.products p ON p.id = ai.product_id
        JOIN public.delivery_agents da ON da.id = ai.delivery_agent_id
        WHERE (p.client_id = p_client_id OR p.client_name IN (SELECT company_name FROM public.clients WHERE id = p_client_id))
          AND (p_product_id IS NULL OR p.id = p_product_id)
          AND (p_state IS NULL OR p_state = 'All States' OR LOWER(COALESCE(da.operating_state, '')) = LOWER(p_state))
          AND (p_lga IS NULL OR p_lga = 'All LGAs' OR LOWER(COALESCE(da.operating_city, '')) LIKE '%' || LOWER(p_lga) || '%')
    LOOP
        v_results := v_results || jsonb_build_object(
            'id', v_row.id,
            'holder_id', v_row.holder_id,
            'holder_name', v_row.holder_name,
            'holder_type', v_row.holder_type,
            'state', v_row.state,
            'lga', v_row.lga,
            'city', v_row.city,
            'phone', v_row.phone,
            'product_id', v_row.product_id,
            'product_sku', v_row.product_sku,
            'product_name', v_row.product_name,
            'opening_qty', v_row.opening_qty,
            'opening_value', v_row.opening_value,
            'in_qty', v_row.in_qty,
            'in_value', v_row.in_value,
            'out_qty', v_row.out_qty,
            'out_value', v_row.out_value,
            'closing_qty', v_row.closing_qty,
            'closing_value', v_row.closing_value,
            'valuation_rate', v_row.valuation_rate,
            'last_updated', v_row.last_updated,
            'status', v_row.status
        );
    END LOOP;

    RETURN v_results;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_get_product_holders_custody(UUID, UUID, DATE, DATE, TEXT, TEXT) TO authenticated, service_role, anon;


-- =================== 20260927013000_fn_get_product_holders_custody_pure_sql.sql ===================
-- ==============================================================================
-- Migration: 20260927013000_fn_get_product_holders_custody_pure_sql.sql
-- Description: Declarative, high-performance pure SQL implementation of fn_get_product_holders_custody
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.fn_get_product_holders_custody(
    p_client_id UUID,
    p_product_id UUID DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_state TEXT DEFAULT NULL,
    p_lga TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    WITH dc_positions AS (
        SELECT 
            sb.id::TEXT AS id,
            COALESCE(dc.id::TEXT, sb.id::TEXT) AS holder_id,
            COALESCE(dc.name, sb.warehouse) AS holder_name,
            CASE 
                WHEN dc.is_grand_dc OR LOWER(sb.warehouse) LIKE '%grand%' THEN 'Grand DC'
                WHEN dc.is_hub OR LOWER(sb.warehouse) LIKE '%hub%' THEN 'Hub Distribution Center'
                WHEN dc.id IS NOT NULL OR LOWER(sb.warehouse) LIKE '%center%' OR LOWER(sb.warehouse) LIKE '%dc%' OR LOWER(sb.warehouse) LIKE '%distribution%' THEN 'Distribution Center'
                ELSE 'Central Storage / In-Transit'
            END AS holder_type,
            COALESCE(dc.state, 'Federal Capital Territory') AS state,
            COALESCE(dc.operating_zones->>0, '') AS lga,
            COALESCE(dc.city, '') AS city,
            COALESCE(dc.contact_phone, '') AS phone,
            COALESCE(p.id::TEXT, sb.product_id, '') AS product_id,
            sb.item_code AS product_sku,
            sb.item_name AS product_name,
            COALESCE(sb.opening_qty, sb.balance_qty)::INT AS opening_qty,
            COALESCE(sb.opening_value, sb.balance_value)::NUMERIC(14,2) AS opening_value,
            COALESCE(sb.in_qty, 0)::INT AS in_qty,
            COALESCE(sb.in_value, 0)::NUMERIC(14,2) AS in_value,
            COALESCE(sb.out_qty, 0)::INT AS out_qty,
            COALESCE(sb.out_value, 0)::NUMERIC(14,2) AS out_value,
            COALESCE(sb.balance_qty, 0)::INT AS closing_qty,
            COALESCE(sb.balance_value, 0)::NUMERIC(14,2) AS closing_value,
            COALESCE(sb.valuation_rate, p.base_price, 0.00)::NUMERIC(14,2) AS valuation_rate,
            sb.updated_at AS last_updated,
            CASE 
                WHEN sb.balance_qty <= 0 THEN 'Out of Stock'
                WHEN sb.balance_qty <= COALESCE(sb.low_stock_threshold, 10) THEN 'Low Stock'
                ELSE 'Active Custody'
            END AS status
        FROM public.client_stock_balances sb
        LEFT JOIN public.products p ON (p.id::TEXT = sb.product_id OR p.sku = sb.item_code OR LOWER(p.name) = LOWER(sb.item_name))
        LEFT JOIN public.distribution_centers dc ON (
            LOWER(dc.name) = LOWER(sb.warehouse)
            OR LOWER(dc.code) = LOWER(sb.warehouse)
            OR LOWER(sb.warehouse) LIKE '%' || LOWER(dc.name) || '%'
            OR LOWER(dc.name) LIKE '%' || LOWER(sb.warehouse) || '%'
        )
        WHERE sb.client_id = p_client_id::TEXT
          AND (p_product_id IS NULL OR p.id = p_product_id OR sb.product_id = p_product_id::TEXT)
          AND (p_state IS NULL OR p_state = 'All States' OR LOWER(COALESCE(dc.state, 'Federal Capital Territory')) = LOWER(p_state))
          AND (p_lga IS NULL OR p_lga = 'All LGAs' OR LOWER(COALESCE(dc.operating_zones->>0, '')) LIKE '%' || LOWER(p_lga) || '%')
    ),
    pda_positions AS (
        SELECT 
            ai.id::TEXT AS id,
            da.id::TEXT AS holder_id,
            COALESCE(da.bank_account_name, da.agent_code, 'Dispatch PDA') || ' (' || COALESCE(da.agent_code, 'PDA') || ')' AS holder_name,
            'PDA / Dispatch Personnel' AS holder_type,
            COALESCE(da.operating_state, 'Abuja (FCT)') AS state,
            COALESCE(da.operating_city, '') AS lga,
            COALESCE(da.operating_city, '') AS city,
            '' AS phone,
            p.id::TEXT AS product_id,
            p.sku AS product_sku,
            p.name AS product_name,
            COALESCE(ai.total_in_custody, 0)::INT AS opening_qty,
            (COALESCE(ai.total_in_custody, 0) * COALESCE(p.base_price, 0.00))::NUMERIC(14,2) AS opening_value,
            0::INT AS in_qty,
            0.00::NUMERIC(14,2) AS in_value,
            COALESCE(ai.delivered_count_today, 0)::INT AS out_qty,
            (COALESCE(ai.delivered_count_today, 0) * COALESCE(p.base_price, 0.00))::NUMERIC(14,2) AS out_value,
            COALESCE(ai.available_count, ai.total_in_custody, 0)::INT AS closing_qty,
            (COALESCE(ai.available_count, ai.total_in_custody, 0) * COALESCE(p.base_price, 0.00))::NUMERIC(14,2) AS closing_value,
            COALESCE(p.base_price, 0.00)::NUMERIC(14,2) AS valuation_rate,
            ai.updated_at AS last_updated,
            CASE 
                WHEN COALESCE(ai.available_count, 0) <= 0 THEN 'Out of Stock'
                WHEN COALESCE(ai.available_count, 0) <= 5 THEN 'Low Stock'
                ELSE 'Active Custody'
            END AS status
        FROM public.agent_inventory ai
        JOIN public.products p ON p.id = ai.product_id
        JOIN public.delivery_agents da ON da.id = ai.delivery_agent_id
        WHERE (p.client_id = p_client_id OR p.client_name IN (SELECT company_name FROM public.clients WHERE id = p_client_id))
          AND (p_product_id IS NULL OR p.id = p_product_id)
          AND (p_state IS NULL OR p_state = 'All States' OR LOWER(COALESCE(da.operating_state, '')) = LOWER(p_state))
          AND (p_lga IS NULL OR p_lga = 'All LGAs' OR LOWER(COALESCE(da.operating_city, '')) LIKE '%' || LOWER(p_lga) || '%')
    ),
    combined AS (
        SELECT * FROM dc_positions
        UNION ALL
        SELECT * FROM pda_positions
    )
    SELECT COALESCE(jsonb_agg(to_jsonb(c)), '[]'::jsonb) FROM combined c;
$$;

GRANT EXECUTE ON FUNCTION public.fn_get_product_holders_custody(UUID, UUID, DATE, DATE, TEXT, TEXT) TO authenticated, service_role, anon;


-- =================== 20260927020000_audit_remediation_stored_procedures_and_realtime.sql ===================
-- Migration: 20260927020000_audit_remediation_stored_procedures_and_realtime.sql
-- Description:
-- 1. Ensure all active realtime tables are added to supabase_realtime publication.
-- 2. Upgrade fn_confirm_order_delivery_stock with safe product_id resolution.
-- 3. Upgrade fn_create_dc_consignment_for_intake_invoice with robust product matching.
-- 4. Upgrade fn_calculate_merchant_asset_custody with product_id and robust order matching.
-- 5. Upgrade fn_process_client_stock_intake_invoice with product_id backfill on balances.

-- ============================================================================
-- 1. Realtime Publication: Ensure all tables have realtime websocket replication
-- ============================================================================
DO $$
DECLARE
    tbl text;
    tables text[] := ARRAY[
        'orders',
        'products',
        'stock_transfers',
        'stock_transfer_items',
        'client_stock_invoices',
        'client_stock_invoice_items',
        'client_stock_balances',
        'client_stock_ledger_entries',
        'product_packages',
        'notifications',
        'order_conversations',
        'order_conversation_messages',
        'delivery_agents',
        'cash_remittances',
        'client_settlements',
        'distribution_centers'
    ];
BEGIN
    FOREACH tbl IN ARRAY tables LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' AND tablename = tbl
        ) THEN
            BEGIN
                EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I;', tbl);
            EXCEPTION WHEN OTHERS THEN
                -- If table does not exist or already added, continue
                NULL;
            END;
        END IF;
    END LOOP;
END $$;

-- ============================================================================
-- 2. Stored Procedure: fn_confirm_order_delivery_stock with Order Lookup Fallback
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_confirm_order_delivery_stock(
    p_order_id UUID,
    p_agent_id UUID,
    p_product_id UUID,
    p_physical_quantity INT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_qty INT := GREATEST(1, COALESCE(p_physical_quantity, 1));
    v_agent RECORD;
    v_resolved_product_id UUID := p_product_id;
BEGIN
    -- Fallback: resolve product_id directly from orders table if not supplied
    IF v_resolved_product_id IS NULL AND p_order_id IS NOT NULL THEN
        SELECT product_id INTO v_resolved_product_id FROM public.orders WHERE id = p_order_id;
    END IF;

    SELECT * INTO v_agent FROM public.delivery_agents WHERE id = p_agent_id OR user_id = p_agent_id;

    IF v_agent IS NOT NULL AND v_resolved_product_id IS NOT NULL THEN
        UPDATE public.agent_inventory
        SET available_count = GREATEST(0, COALESCE(available_count, 0) - v_qty),
            total_in_custody = GREATEST(0, COALESCE(total_in_custody, 0) - v_qty),
            delivered_count_today = COALESCE(delivered_count_today, 0) + v_qty,
            updated_at = NOW()
        WHERE delivery_agent_id = v_agent.id AND product_id = v_resolved_product_id;
    END IF;

    IF v_resolved_product_id IS NOT NULL THEN
        UPDATE public.products
        SET delivered_count = COALESCE(delivered_count, 0) + v_qty,
            stock_quantity = GREATEST(0, COALESCE(stock_quantity, 0) - v_qty),
            available_count = GREATEST(0, COALESCE(available_count, 0) - v_qty),
            updated_at = NOW()
        WHERE id = v_resolved_product_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'product_id', v_resolved_product_id,
        'deducted_physical_quantity', v_qty
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_confirm_order_delivery_stock(UUID, UUID, UUID, INT) TO authenticated, service_role, anon;

-- ============================================================================
-- 3. Stored Procedure: fn_create_dc_consignment_for_intake_invoice (Robust Product Matching)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_create_dc_consignment_for_intake_invoice(
    p_invoice_id UUID,
    p_sender_id UUID DEFAULT NULL,
    p_sender_name TEXT DEFAULT '',
    p_sender_signature_url TEXT DEFAULT '',
    p_carrier_driver_name TEXT DEFAULT '',
    p_carrier_phone TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_inv RECORD;
    v_item RECORD;
    v_dc_id UUID;
    v_company_id UUID;
    v_transfer_id UUID;
    v_prod_id UUID;
    v_waybill TEXT;
    v_dc_name TEXT;
    v_total_units INT := 0;
BEGIN
    SELECT * INTO v_inv FROM public.client_stock_invoices WHERE id = p_invoice_id;
    IF v_inv IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invoice not found');
    END IF;

    -- Match targeted receiving DC across ANY tier (Grand DC, Hub DC, or General DC)
    SELECT id, name INTO v_dc_id, v_dc_name FROM public.distribution_centers 
    WHERE name ILIKE '%' || SPLIT_PART(v_inv.destination_warehouse, ' - ', 1) || '%'
       OR v_inv.destination_warehouse ILIKE '%' || name || '%'
       OR v_inv.destination_warehouse ILIKE '%' || state || '%'
       OR v_inv.destination_warehouse ILIKE '%' || code || '%'
    LIMIT 1;

    -- If not matched, default to Grand DC
    IF v_dc_id IS NULL THEN
        SELECT id, name INTO v_dc_id, v_dc_name FROM public.distribution_centers 
        WHERE dc_type = 'grand_dc' OR is_grand_dc = true OR code = 'DC-WUSE-01'
        ORDER BY created_at ASC LIMIT 1;
    END IF;

    -- Final fallback
    IF v_dc_id IS NULL THEN
        SELECT id, name INTO v_dc_id, v_dc_name FROM public.distribution_centers LIMIT 1;
    END IF;

    -- Resolve company_id
    BEGIN
        SELECT company_id INTO v_company_id FROM public.clients WHERE id = v_inv.client_id::UUID;
    EXCEPTION WHEN OTHERS THEN
        v_company_id := NULL;
    END;
    IF v_company_id IS NULL THEN
        SELECT id INTO v_company_id FROM public.companies LIMIT 1;
    END IF;

    v_waybill := COALESCE(NULLIF(v_inv.waybill_number, ''), 'WB-INTAKE-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0'));

    -- Ensure invoice has the waybill number and status is in_transit
    UPDATE public.client_stock_invoices
    SET waybill_number = v_waybill,
        status = CASE WHEN status = 'draft' THEN 'in_transit' ELSE COALESCE(status, 'in_transit') END,
        updated_at = NOW()
    WHERE id = p_invoice_id;

    -- Check if transfer already exists for this invoice
    SELECT id INTO v_transfer_id FROM public.stock_transfers WHERE invoice_id = p_invoice_id LIMIT 1;

    IF v_transfer_id IS NULL THEN
        -- Create pending stock transfer for DC custody acceptance
        INSERT INTO public.stock_transfers (
            company_id,
            source_dc_id,
            destination_dc_id,
            transfer_type,
            status,
            transfer_number,
            waybill_number,
            notes,
            invoice_id,
            sender_id,
            sender_name,
            sender_signature_url,
            carrier_driver_name,
            carrier_phone,
            created_at,
            updated_at
        ) VALUES (
            v_company_id,
            NULL,
            v_dc_id,
            'supplier_intake',
            'in_transit',
            v_waybill,
            v_waybill,
            'Supplier intake invoice ' || v_inv.invoice_number || ' bound for ' || v_dc_name || ' [' || v_waybill || ']',
            p_invoice_id,
            p_sender_id,
            p_sender_name,
            p_sender_signature_url,
            p_carrier_driver_name,
            p_carrier_phone,
            NOW(),
            NOW()
        ) RETURNING id INTO v_transfer_id;

        -- Create transfer items from invoice line items
        FOR v_item IN SELECT * FROM public.client_stock_invoice_items WHERE invoice_id = p_invoice_id LOOP
            SELECT id INTO v_prod_id FROM public.products 
            WHERE (id::TEXT = v_item.product_id 
                OR sku = v_item.product_sku 
                OR name ILIKE '%' || v_item.product_name || '%'
                OR v_item.product_name ILIKE '%' || name || '%')
            ORDER BY (CASE WHEN id::TEXT = v_item.product_id THEN 1 WHEN sku = v_item.product_sku THEN 2 ELSE 3 END) ASC
            LIMIT 1;

            INSERT INTO public.stock_transfer_items (
                transfer_id,
                product_id,
                quantity_shipped,
                quantity_received,
                notes
            ) VALUES (
                v_transfer_id,
                v_prod_id,
                v_item.quantity,
                0,
                'Line item: ' || v_item.product_name
            );

            v_total_units := v_total_units + v_item.quantity;
        END LOOP;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'transfer_id', v_transfer_id,
        'invoice_id', p_invoice_id,
        'waybill_number', v_waybill,
        'destination_dc_id', v_dc_id,
        'destination_dc_name', v_dc_name,
        'total_units', v_total_units,
        'status', 'in_transit'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_create_dc_consignment_for_intake_invoice(UUID, UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role, anon;

-- ============================================================================
-- 4. Stored Procedure: fn_calculate_merchant_asset_custody (Hardened Order Matching)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_calculate_merchant_asset_custody(
    p_client_id UUID,
    p_dc_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_cash_in_paystack NUMERIC(14, 2) := 0.00;
    v_cash_in_dc_vault NUMERIC(14, 2) := 0.00;
    v_total_liquid_cash NUMERIC(14, 2) := 0.00;
    v_total_units_in_custody INT := 0;
    v_base_inventory_valuation NUMERIC(14, 2) := 0.00;
    v_weighted_retail_valuation NUMERIC(14, 2) := 0.00;
    v_prod RECORD;
    v_client RECORD;
    v_delivery_fee NUMERIC(14, 2) := 5000.00;
    v_failed_fee NUMERIC(14, 2) := 500.00;
    v_failed_orders_count INT := 0;
    v_failed_charges NUMERIC(14, 2) := 0.00;
BEGIN
    -- Look up client settings
    SELECT custom_delivery_fee, custom_failed_attempt_fee
    INTO v_client
    FROM public.clients
    WHERE id = p_client_id;

    IF FOUND THEN
        IF v_client.custom_delivery_fee IS NOT NULL AND v_client.custom_delivery_fee > 0 THEN
            v_delivery_fee := v_client.custom_delivery_fee;
        END IF;
        IF v_client.custom_failed_attempt_fee IS NOT NULL AND v_client.custom_failed_attempt_fee > 0 THEN
            v_failed_fee := v_client.custom_failed_attempt_fee;
        END IF;
    END IF;

    -- 1. Liquid Cash in Custody (Delivered orders awaiting settlement)
    SELECT 
        COALESCE(SUM(CASE WHEN COALESCE(payment_method, delivery_method, 'cash') = 'paystack' OR payment_type = 'prepaid' THEN (total_amount - COALESCE(client_delivery_fee, v_delivery_fee)) ELSE 0 END), 0.00),
        COALESCE(SUM(CASE WHEN COALESCE(payment_method, delivery_method, 'cash') = 'cash' AND payment_type = 'pay_on_delivery' THEN (total_amount - COALESCE(client_delivery_fee, v_delivery_fee)) ELSE 0 END), 0.00)
    INTO v_cash_in_paystack, v_cash_in_dc_vault
    FROM public.orders
    WHERE client_id = p_client_id
      AND status = 'delivered'
      AND (financial_settlement_status IS NULL OR financial_settlement_status != 'client_settled')
      AND (p_dc_id IS NULL OR distribution_center_id = p_dc_id);

    -- Deduct pending failed delivery attempt fees from unsettled failed/cancelled orders
    SELECT COUNT(*) INTO v_failed_orders_count
    FROM public.orders
    WHERE client_id = p_client_id
      AND status IN ('failed', 'cancelled', 'rejected', 'customer_rejected')
      AND (financial_settlement_status IS NULL OR financial_settlement_status != 'client_settled')
      AND (p_dc_id IS NULL OR distribution_center_id = p_dc_id);

    v_failed_charges := v_failed_orders_count * v_failed_fee;
    v_total_liquid_cash := GREATEST(0.00, (v_cash_in_paystack + v_cash_in_dc_vault) - v_failed_charges);

    -- 2. In-Kind Inventory Custody & Dual Valuation
    FOR v_prod IN
        SELECT id, name, sku, base_price, stock_quantity, available_count
        FROM public.products
        WHERE client_id = p_client_id OR client_name IN (SELECT company_name FROM public.clients WHERE id = p_client_id)
    LOOP
        DECLARE
            v_units INT := COALESCE(v_prod.stock_quantity, v_prod.available_count, 0);
            v_avg_price NUMERIC(14, 2);
        BEGIN
            v_total_units_in_custody := v_total_units_in_custody + v_units;
            v_base_inventory_valuation := v_base_inventory_valuation + (v_units * COALESCE(v_prod.base_price, 25000.00));

            -- Calculate historical realized unit price factoring in package deals with robust product matching
            SELECT COALESCE(AVG(total_amount / NULLIF(quantity, 0)), v_prod.base_price, 25000.00)
            INTO v_avg_price
            FROM public.orders
            WHERE client_id = p_client_id 
              AND (product_id = v_prod.id 
                OR product_name = v_prod.name 
                OR product_sku = v_prod.sku
                OR product_name ILIKE '%' || v_prod.name || '%'
                OR v_prod.name ILIKE '%' || product_name || '%')
              AND status = 'delivered';

            v_weighted_retail_valuation := v_weighted_retail_valuation + (v_units * v_avg_price);
        END;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'client_id', p_client_id,
        'liquid_cash_in_custody', v_total_liquid_cash,
        'physical_cod_in_dc_vault', v_cash_in_dc_vault,
        'direct_transfer_in_paystack', v_cash_in_paystack,
        'failed_delivery_surcharges', v_failed_charges,
        'total_inventory_units_held', v_total_units_in_custody,
        'inventory_baseline_liquidation_value', v_base_inventory_valuation,
        'inventory_estimated_retail_value', v_weighted_retail_valuation,
        'grand_total_asset_value', (v_total_liquid_cash + v_weighted_retail_valuation)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_calculate_merchant_asset_custody(UUID, UUID) TO authenticated, service_role, anon;

-- ============================================================================
-- 5. Stored Procedure: fn_process_client_stock_intake_invoice (Backfill product_id)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_process_client_stock_intake_invoice(p_invoice_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_inv RECORD;
    v_item RECORD;
    v_cur_bal RECORD;
    v_new_bal_qty NUMERIC;
    v_new_valuation NUMERIC;
    v_resolved_prod_id TEXT;
BEGIN
    SELECT * INTO v_inv FROM public.client_stock_invoices WHERE id = p_invoice_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Invoice not found');
    END IF;

    -- Process each item in the intake invoice
    FOR v_item IN SELECT * FROM public.client_stock_invoice_items WHERE invoice_id = p_invoice_id LOOP
        v_resolved_prod_id := v_item.product_id;
        IF v_resolved_prod_id IS NULL OR v_resolved_prod_id = '' THEN
            SELECT id::TEXT INTO v_resolved_prod_id FROM public.products
            WHERE sku = v_item.product_sku 
               OR name ILIKE '%' || v_item.product_name || '%'
               OR v_item.product_name ILIKE '%' || name || '%'
            LIMIT 1;
        END IF;

        SELECT * INTO v_cur_bal 
        FROM public.client_stock_balances
        WHERE client_id = v_inv.client_id
          AND (item_code = v_item.product_sku 
            OR item_name = v_item.product_name 
            OR (v_resolved_prod_id IS NOT NULL AND product_id = v_resolved_prod_id))
          AND warehouse = v_inv.destination_warehouse;

        IF FOUND THEN
            v_new_bal_qty := v_cur_bal.balance_qty + v_item.quantity;
            IF v_new_bal_qty > 0 THEN
                v_new_valuation := ((v_cur_bal.balance_qty * v_cur_bal.valuation_rate) + (v_item.quantity * v_item.effective_landed_cost_per_unit)) / v_new_bal_qty;
            ELSE
                v_new_valuation := v_item.effective_landed_cost_per_unit;
            END IF;

            UPDATE public.client_stock_balances
            SET in_qty = in_qty + v_item.quantity,
                in_value = in_value + v_item.total_landed_cost,
                balance_qty = v_new_bal_qty,
                balance_value = v_new_bal_qty * v_new_valuation,
                valuation_rate = v_new_valuation,
                product_id = COALESCE(NULLIF(client_stock_balances.product_id, ''), v_resolved_prod_id),
                last_entry_invoice_id = p_invoice_id,
                updated_at = NOW()
            WHERE id = v_cur_bal.id;
        ELSE
            v_new_valuation := v_item.effective_landed_cost_per_unit;
            INSERT INTO public.client_stock_balances (
                client_id,
                product_id,
                item_code,
                item_name,
                warehouse,
                stock_uom,
                opening_qty,
                opening_value,
                in_qty,
                in_value,
                out_qty,
                out_value,
                balance_qty,
                balance_value,
                valuation_rate,
                reserved_stock,
                last_entry_invoice_id,
                updated_at
            ) VALUES (
                v_inv.client_id,
                v_resolved_prod_id,
                v_item.product_sku,
                v_item.product_name,
                v_inv.destination_warehouse,
                'Nos',
                0,
                0,
                v_item.quantity,
                v_item.total_landed_cost,
                0,
                0,
                v_item.quantity,
                v_item.total_landed_cost,
                v_new_valuation,
                0,
                p_invoice_id,
                NOW()
            );
        END IF;

        -- Write immutable record to client_stock_ledger_entries
        INSERT INTO public.client_stock_ledger_entries (
            client_id,
            warehouse,
            item_code,
            item_name,
            voucher_type,
            voucher_no,
            invoice_id,
            posting_date,
            posting_at,
            qty_change,
            valuation_rate,
            value_change,
            running_balance_qty,
            running_balance_value,
            notes
        ) VALUES (
            v_inv.client_id,
            v_inv.destination_warehouse,
            v_item.product_sku,
            v_item.product_name,
            'Purchase Receipt',
            v_inv.invoice_number,
            p_invoice_id,
            COALESCE(v_inv.entry_date, CURRENT_DATE),
            NOW(),
            v_item.quantity,
            v_item.effective_landed_cost_per_unit,
            v_item.total_landed_cost,
            COALESCE(v_new_bal_qty, v_item.quantity),
            COALESCE(v_new_bal_qty * v_new_valuation, v_item.total_landed_cost),
            'Stock Intake Invoice: ' || v_inv.invoice_number
        );
    END LOOP;

    -- Update invoice status
    UPDATE public.client_stock_invoices
    SET status = 'verified',
        updated_at = NOW()
    WHERE id = p_invoice_id;

    RETURN jsonb_build_object(
        'success', true,
        'invoice_id', p_invoice_id,
        'message', 'Stock intake invoice processed, balances updated, and immutable ledger entries written.'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_process_client_stock_intake_invoice(UUID) TO authenticated, service_role, anon;


-- =================== 20260927021000_audit_data_remediation_linkages.sql ===================
-- Migration: 20260927021000_audit_data_remediation_linkages.sql
-- Description:
-- 1. Ensure missing catalog products exist in public.products (Hair Dye Shampoo, Grazer Herbal Balm, Clear Vision Tea).
-- 2. Link all unlinked client_stock_balances to authoritative product_ids.
-- 3. Link all client_stock_invoice_items to authoritative product_ids.
-- 4. Purge orphaned test stock balances and invoices.

-- ============================================================================
-- 1. Ensure Missing Catalog Products
-- ============================================================================
DO $$
DECLARE
    v_comp_id UUID := '11111111-1111-4111-8111-111111111111';
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.products WHERE sku = 'SKU-HDS' OR name ILIKE '%Hair Dye%') THEN
        INSERT INTO public.products (
            id, company_id, name, sku, base_price, cost_price, stock_quantity, available_count,
            client_id, client_name, category, is_active
        ) VALUES (
            '77777777-aaaa-4777-8777-777777777771', v_comp_id, 'Hair Dye Shampoo', 'SKU-HDS',
            5000.00, 2000.00, 3960, 3960,
            '00000000-0000-4000-8000-789382731303', 'Novacare Ltd', 'Hair Care', true
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.products WHERE sku = 'SKU-GHB' OR name ILIKE '%Herbal Balm%') THEN
        INSERT INTO public.products (
            id, company_id, name, sku, base_price, cost_price, stock_quantity, available_count,
            client_id, client_name, category, is_active
        ) VALUES (
            '77777777-aaaa-4777-8777-777777777772', v_comp_id, 'Grazer Herbal Balm', 'SKU-GHB',
            4500.00, 1800.00, 720, 720,
            '00000000-0000-4000-8000-789382731303', 'Novacare Ltd', 'Herbal Remedy', true
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.products WHERE sku = 'SKU-CVT' OR name ILIKE '%Clear Vision%') THEN
        INSERT INTO public.products (
            id, company_id, name, sku, base_price, cost_price, stock_quantity, available_count,
            client_id, client_name, category, is_active
        ) VALUES (
            '77777777-aaaa-4777-8777-777777777773', v_comp_id, 'Clear Vision Tea', 'SKU-CVT',
            6000.00, 2500.00, 630, 630,
            '00000000-0000-4000-8000-789382731303', 'Novacare Ltd', 'Herbal Tea', true
        );
    END IF;
END $$;

-- ============================================================================
-- 2. Link All Client Stock Balances & Normalize Client ID
-- ============================================================================
UPDATE public.client_stock_balances sb
SET product_id = p.id::TEXT,
    client_id = '00000000-0000-4000-8000-789382731303'
FROM public.products p
WHERE (sb.product_id IS NULL OR sb.product_id = '')
  AND (sb.item_code = p.sku 
    OR sb.item_name ILIKE '%' || p.name || '%' 
    OR p.name ILIKE '%' || sb.item_name || '%');

-- Delete orphaned test balance rows
DELETE FROM public.client_stock_balances
WHERE item_code = 'TEST-ITEM' 
   OR warehouse ILIKE '%Test Central%';

-- ============================================================================
-- 3. Link All Client Stock Invoice Items to Genuine Product IDs
-- ============================================================================
UPDATE public.client_stock_invoice_items ii
SET product_id = p.id::TEXT
FROM public.products p
WHERE (ii.product_id IS NULL OR ii.product_id = '')
  AND (ii.product_sku = p.sku 
    OR ii.product_name ILIKE '%' || p.name || '%' 
    OR p.name ILIKE '%' || ii.product_name || '%');

-- Handle Grazer Tea invoice items linking to Grazer Herbal Detox Tea
UPDATE public.client_stock_invoice_items
SET product_id = '3d377805-9870-4841-b452-ffb640f9825e'
WHERE (product_id IS NULL OR product_id = '')
  AND (product_name ILIKE '%Grazer%' OR product_sku ILIKE '%GRAZ%');

-- Handle Ura Clear Tea invoice items linking to Ura Clear
UPDATE public.client_stock_invoice_items
SET product_id = '5edbfcf1-3edd-4f33-a9e4-9278f6f8a9c5'
WHERE (product_id IS NULL OR product_id = '')
  AND (product_name ILIKE '%Ura Clear%' OR product_sku ILIKE '%URA%');

-- Handle Hair Dye Shampoo invoice items linking to Hair Dye Shampoo
UPDATE public.client_stock_invoice_items
SET product_id = '77777777-aaaa-4777-8777-777777777771'
WHERE (product_id IS NULL OR product_id = '')
  AND (product_name ILIKE '%Hair Dye%' OR product_sku ILIKE '%HAIR%');

-- Delete orphaned test invoices and line items
DELETE FROM public.client_stock_invoice_items
WHERE invoice_id IN (
    SELECT id FROM public.client_stock_invoices 
    WHERE client_id = '' 
       OR invoice_number ILIKE 'INV-TEST%'
);

DELETE FROM public.client_stock_invoices
WHERE client_id = '' 
   OR invoice_number ILIKE 'INV-TEST%';


-- =================== 20260927030000_fn_adjust_dc_stock_sync_balances.sql ===================
-- ==============================================================================
-- Migration: 20260927020000_fn_adjust_dc_stock_sync_balances.sql
-- Description: Ensures fn_adjust_dc_stock updates both products.dc_stocks and
--              client_stock_balances in lockstep whenever stock is adjusted.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.fn_adjust_dc_stock(
    p_product_id UUID,
    p_dc_id UUID,
    p_delta INT
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_dc_key TEXT := p_dc_id::TEXT;
    v_curr_val INT := 0;
    v_new_val INT := 0;
    v_curr_stocks JSONB;
    v_dc_name TEXT;
    v_dc_code TEXT;
    v_client_id TEXT;
    v_sku TEXT;
    v_name TEXT;
    v_updated_rows INT := 0;
BEGIN
    IF p_product_id IS NULL OR p_dc_id IS NULL OR p_delta = 0 THEN
        RETURN;
    END IF;

    -- 1. Update products.dc_stocks JSONB
    SELECT COALESCE(dc_stocks, '{}'::JSONB), client_id::TEXT, sku, name 
    INTO v_curr_stocks, v_client_id, v_sku, v_name
    FROM public.products
    WHERE id = p_product_id;

    IF v_curr_stocks ? v_dc_key THEN
        v_curr_val := COALESCE((v_curr_stocks->>v_dc_key)::INT, 0);
    END IF;

    v_new_val := GREATEST(0, v_curr_val + p_delta);
    v_curr_stocks := jsonb_set(v_curr_stocks, ARRAY[v_dc_key], to_jsonb(v_new_val), true);

    UPDATE public.products
    SET dc_stocks = v_curr_stocks,
        updated_at = NOW()
    WHERE id = p_product_id;

    -- 2. Keep client_stock_balances in lockstep
    SELECT name, code INTO v_dc_name, v_dc_code FROM public.distribution_centers WHERE id = p_dc_id;
    IF v_dc_name IS NOT NULL THEN
        UPDATE public.client_stock_balances
        SET balance_qty = GREATEST(0, balance_qty + p_delta),
            in_qty = in_qty + CASE WHEN p_delta > 0 THEN p_delta ELSE 0 END,
            out_qty = out_qty + CASE WHEN p_delta < 0 THEN ABS(p_delta) ELSE 0 END,
            updated_at = NOW()
        WHERE (product_id = p_product_id::TEXT OR item_code = v_sku OR LOWER(item_name) = LOWER(v_name))
          AND (
              warehouse = v_dc_name 
              OR LOWER(warehouse) = LOWER(v_dc_name)
              OR (v_dc_code IS NOT NULL AND LOWER(warehouse) LIKE '%' || LOWER(v_dc_code) || '%')
          );
        GET DIAGNOSTICS v_updated_rows = ROW_COUNT;

        -- If no matching warehouse record exists yet and delta is positive, insert initial balance record
        IF v_updated_rows = 0 AND v_client_id IS NOT NULL AND p_delta > 0 THEN
            INSERT INTO public.client_stock_balances (
                client_id,
                product_id,
                item_code,
                item_name,
                warehouse,
                balance_qty,
                in_qty,
                out_qty,
                opening_qty,
                company,
                updated_at
            ) VALUES (
                v_client_id,
                p_product_id::TEXT,
                v_sku,
                v_name,
                v_dc_name,
                p_delta,
                p_delta,
                0,
                0,
                COALESCE((SELECT company_name FROM public.clients WHERE id::TEXT = v_client_id LIMIT 1), 'Merchant'),
                NOW()
            );
        END IF;
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_adjust_dc_stock(UUID, UUID, INT) TO authenticated, service_role, anon;


-- =================== 20260927083000_digital_marketing_suite_and_closer_product_assignment.sql ===================
-- ============================================================================
-- Migration: 20260927083000_digital_marketing_suite_and_closer_product_assignment.sql
-- Description: Digital Marketer Accounts, Lead Forms, Landing Page Order Ingestion,
--              Closer Product Attachment, and Balanced Split Round-Robin Assignment.
-- ============================================================================

-- 1. Extend client_closers with assigned products array
ALTER TABLE public.client_closers
  ADD COLUMN IF NOT EXISTS assigned_product_ids UUID[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS assigned_product_names TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS last_assigned_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_client_closers_assigned_products 
  ON public.client_closers USING GIN (assigned_product_ids);

-- 2. Create client_marketers table
CREATE TABLE IF NOT EXISTS public.client_marketers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  marketer_code TEXT NOT NULL UNIQUE,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  is_active BOOLEAN DEFAULT true,
  daily_ad_spend_budget NUMERIC(14,2) DEFAULT 0.00,
  commission_rate NUMERIC(12,2) DEFAULT 0.00,
  is_commission_enabled BOOLEAN DEFAULT false,
  bank_name TEXT DEFAULT '',
  account_number TEXT DEFAULT '',
  account_name TEXT DEFAULT '',
  avatar_url TEXT,
  total_leads_generated INT DEFAULT 0,
  total_orders_generated INT DEFAULT 0,
  total_orders_delivered INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_client_marketers_client_id ON public.client_marketers(client_id);
CREATE INDEX IF NOT EXISTS idx_client_marketers_user_id ON public.client_marketers(user_id);
CREATE INDEX IF NOT EXISTS idx_client_marketers_marketer_code ON public.client_marketers(marketer_code);

-- 3. Create lead_forms table
CREATE TABLE IF NOT EXISTS public.lead_forms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  marketer_id UUID REFERENCES public.client_marketers(id) ON DELETE SET NULL,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  product_name TEXT NOT NULL,
  form_title TEXT NOT NULL,
  form_slug TEXT UNIQUE,
  description TEXT DEFAULT '',
  packages JSONB NOT NULL DEFAULT '[]'::jsonb,
  redirect_url TEXT NOT NULL DEFAULT '',
  pixel_id TEXT DEFAULT '',
  capi_token TEXT DEFAULT '',
  test_event_code TEXT DEFAULT '',
  field_options JSONB NOT NULL DEFAULT '{"require_email": false, "require_alt_phone": false, "require_city": false, "require_notes": false}'::jsonb,
  appearance JSONB NOT NULL DEFAULT '{"primary_color": "#F37021", "button_text": "Complete Order Now", "badge_text": "Pay On Delivery + Fast Delivery"}'::jsonb,
  is_active BOOLEAN DEFAULT true,
  total_views INT DEFAULT 0,
  total_submissions INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure all required columns exist in case lead_forms pre-existed
ALTER TABLE public.lead_forms
  ADD COLUMN IF NOT EXISTS client_id UUID REFERENCES public.clients(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS marketer_id UUID REFERENCES public.client_marketers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS product_name TEXT,
  ADD COLUMN IF NOT EXISTS form_title TEXT,
  ADD COLUMN IF NOT EXISTS form_slug TEXT,
  ADD COLUMN IF NOT EXISTS description TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS packages JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS redirect_url TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS pixel_id TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS capi_token TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS test_event_code TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS field_options JSONB DEFAULT '{"require_email": false, "require_alt_phone": false, "require_city": false, "require_notes": false}'::jsonb,
  ADD COLUMN IF NOT EXISTS appearance JSONB DEFAULT '{"primary_color": "#F37021", "button_text": "Complete Order Now", "badge_text": "Pay On Delivery + Fast Delivery"}'::jsonb,
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS total_views INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_submissions INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_lead_forms_client_id ON public.lead_forms(client_id);
CREATE INDEX IF NOT EXISTS idx_lead_forms_marketer_id ON public.lead_forms(marketer_id);
CREATE INDEX IF NOT EXISTS idx_lead_forms_product_id ON public.lead_forms(product_id);
CREATE INDEX IF NOT EXISTS idx_lead_forms_form_slug ON public.lead_forms(form_slug);

-- 4. Extend orders and customer_leads with marketing attribution columns
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS marketer_id UUID REFERENCES public.client_marketers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS marketer_name TEXT,
  ADD COLUMN IF NOT EXISTS form_id UUID REFERENCES public.lead_forms(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS offer_package_id TEXT,
  ADD COLUMN IF NOT EXISTS utm_source TEXT,
  ADD COLUMN IF NOT EXISTS utm_medium TEXT,
  ADD COLUMN IF NOT EXISTS utm_campaign TEXT,
  ADD COLUMN IF NOT EXISTS utm_content TEXT,
  ADD COLUMN IF NOT EXISTS ad_id TEXT;

CREATE INDEX IF NOT EXISTS idx_orders_marketer_id ON public.orders(marketer_id);
CREATE INDEX IF NOT EXISTS idx_orders_form_id ON public.orders(form_id);

ALTER TABLE public.customer_leads
  ADD COLUMN IF NOT EXISTS marketer_id UUID REFERENCES public.client_marketers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS form_id UUID REFERENCES public.lead_forms(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS utm_source TEXT,
  ADD COLUMN IF NOT EXISTS utm_campaign TEXT,
  ADD COLUMN IF NOT EXISTS utm_medium TEXT,
  ADD COLUMN IF NOT EXISTS ad_id TEXT;

CREATE INDEX IF NOT EXISTS idx_customer_leads_marketer_id ON public.customer_leads(marketer_id);
CREATE INDEX IF NOT EXISTS idx_customer_leads_form_id ON public.customer_leads(form_id);

-- 5. Stored Procedure: Balanced Split Round-Robin Assignment to Closers Attached to Product
CREATE OR REPLACE FUNCTION public.fn_assign_order_round_robin(
    p_order_id UUID,
    p_product_id UUID,
    p_client_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_closer_id UUID;
    v_closer_name TEXT;
    v_closer_code TEXT;
BEGIN
    -- 1. Try finding an active closer explicitly assigned to this product for this client
    -- Balanced Split logic: pick active closer with lowest pending/active orders, tie-breaking by last_assigned_at ASC
    SELECT c.id, c.full_name, c.closer_code
    INTO v_closer_id, v_closer_name, v_closer_code
    FROM public.client_closers c
    LEFT JOIN public.orders o ON o.closer_id = c.id AND o.status IN ('new', 'contacting', 'pending', 'confirmed')
    WHERE c.client_id = p_client_id
      AND c.is_active = true
      AND (p_product_id = ANY(c.assigned_product_ids) OR array_length(c.assigned_product_ids, 1) IS NULL OR array_length(c.assigned_product_ids, 1) = 0)
    GROUP BY c.id, c.full_name, c.closer_code, c.last_assigned_at
    ORDER BY COUNT(o.id) ASC, c.last_assigned_at ASC NULLS FIRST, c.created_at ASC
    LIMIT 1
    FOR UPDATE OF c SKIP LOCKED;

    -- 2. Fallback: If no closer is attached to this product, assign to ANY active closer under this client
    IF v_closer_id IS NULL THEN
        SELECT c.id, c.full_name, c.closer_code
        INTO v_closer_id, v_closer_name, v_closer_code
        FROM public.client_closers c
        LEFT JOIN public.orders o ON o.closer_id = c.id AND o.status IN ('new', 'contacting', 'pending', 'confirmed')
        WHERE c.client_id = p_client_id
          AND c.is_active = true
        GROUP BY c.id, c.full_name, c.closer_code, c.last_assigned_at
        ORDER BY COUNT(o.id) ASC, c.last_assigned_at ASC NULLS FIRST, c.created_at ASC
        LIMIT 1
        FOR UPDATE OF c SKIP LOCKED;
    END IF;

    -- 3. If an eligible closer was resolved, assign them to the order & update stats
    IF v_closer_id IS NOT NULL THEN
        UPDATE public.orders
        SET closer_id = v_closer_id,
            closer_name = v_closer_name,
            closer_code = v_closer_code,
            updated_at = NOW()
        WHERE id = p_order_id;

        -- Also link closer to corresponding customer_leads if exists
        UPDATE public.customer_leads
        SET assigned_closer_id = v_closer_id,
            updated_at = NOW()
        WHERE converted_order_id = p_order_id::text
           OR id = (SELECT lead_id FROM public.orders WHERE id = p_order_id);

        -- Update closer's assigned counter & rotation timestamp
        UPDATE public.client_closers
        SET total_leads_assigned = COALESCE(total_leads_assigned, 0) + 1,
            last_assigned_at = NOW(),
            updated_at = NOW()
        WHERE id = v_closer_id;
    END IF;

    RETURN v_closer_id;
END;
$$;

-- 6. Stored Procedure: Public Marketing Lead Order Ingestion
CREATE OR REPLACE FUNCTION public.fn_submit_marketing_lead_order(
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_form_id UUID;
    v_client_id UUID;
    v_marketer_id UUID;
    v_marketer_name TEXT;
    v_product_id UUID;
    v_product_name TEXT;
    v_product_sku TEXT;
    v_product_price NUMERIC;
    v_customer_name TEXT;
    v_customer_phone TEXT;
    v_customer_alt_phone TEXT;
    v_customer_email TEXT;
    v_delivery_address TEXT;
    v_delivery_state TEXT;
    v_delivery_city TEXT;
    v_notes TEXT;
    v_package_id TEXT;
    v_package_name TEXT;
    v_buy_qty INT;
    v_total_amount NUMERIC;
    v_redirect_url TEXT;
    v_utm_source TEXT;
    v_utm_medium TEXT;
    v_utm_campaign TEXT;
    v_utm_content TEXT;
    v_ad_id TEXT;
    v_order_id UUID;
    v_lead_id UUID;
    v_order_number TEXT;
    v_assigned_closer_id UUID;
    v_assigned_closer_name TEXT;
    v_clean_phone TEXT;
    v_final_redirect TEXT;
BEGIN
    -- Parse & Sanitize Inputs
    v_form_id := (p_payload->>'form_id')::UUID;
    v_customer_name := TRIM(COALESCE(p_payload->>'customer_name', 'Valued Customer'));
    v_customer_phone := TRIM(COALESCE(p_payload->>'customer_phone', ''));
    v_customer_alt_phone := TRIM(COALESCE(p_payload->>'customer_alt_phone', ''));
    v_customer_email := TRIM(COALESCE(p_payload->>'customer_email', ''));
    v_delivery_address := TRIM(COALESCE(p_payload->>'delivery_address', ''));
    v_delivery_state := TRIM(COALESCE(p_payload->>'delivery_state', 'Lagos'));
    v_delivery_city := TRIM(COALESCE(p_payload->>'delivery_city', ''));
    v_notes := TRIM(COALESCE(p_payload->>'notes', ''));
    v_package_id := COALESCE(p_payload->>'package_id', 'pkg-1');
    v_package_name := COALESCE(p_payload->>'package_name', 'Standard Package');
    v_buy_qty := COALESCE((p_payload->>'buy_qty')::INT, 1);
    v_total_amount := COALESCE((p_payload->>'total_amount')::NUMERIC, 0.00);

    -- UTM attributes
    v_utm_source := p_payload->>'utm_source';
    v_utm_medium := p_payload->>'utm_medium';
    v_utm_campaign := p_payload->>'utm_campaign';
    v_utm_content := p_payload->>'utm_content';
    v_ad_id := p_payload->>'ad_id';

    -- Validation
    IF v_form_id IS NULL THEN
        RAISE EXCEPTION 'form_id is required';
    END IF;
    IF LENGTH(v_customer_phone) < 10 THEN
        RAISE EXCEPTION 'Valid phone number is required';
    END IF;

    -- Lookup Form Details
    SELECT f.client_id, f.marketer_id, f.product_id, f.product_name, f.redirect_url, m.full_name
    INTO v_client_id, v_marketer_id, v_product_id, v_product_name, v_redirect_url, v_marketer_name
    FROM public.lead_forms f
    LEFT JOIN public.client_marketers m ON m.id = f.marketer_id
    WHERE f.id = v_form_id;

    IF v_client_id IS NULL THEN
        RAISE EXCEPTION 'Lead form not found or inactive';
    END IF;

    -- Lookup Product SKU and base price if not supplied
    SELECT sku, price
    INTO v_product_sku, v_product_price
    FROM public.products
    WHERE id = v_product_id;

    IF v_total_amount <= 0 THEN
        v_total_amount := COALESCE(v_product_price, 25000.00) * v_buy_qty;
    END IF;

    -- Generate Clean Order Number: ORD-MK-YYMMDD-XXXX
    v_order_number := 'ORD-MK-' || TO_CHAR(NOW(), 'YYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');

    -- 1. Create Lead in customer_leads
    INSERT INTO public.customer_leads (
        client_id,
        marketer_id,
        form_id,
        customer_name,
        customer_phone,
        customer_address,
        delivery_state,
        delivery_lga,
        product_interest,
        package_interest,
        status,
        call_notes,
        utm_source,
        utm_medium,
        utm_campaign,
        ad_id,
        created_at,
        updated_at
    ) VALUES (
        v_client_id,
        v_marketer_id,
        v_form_id,
        v_customer_name,
        v_customer_phone,
        v_delivery_address,
        v_delivery_state,
        COALESCE(v_delivery_city, 'AMAC'),
        v_product_name,
        v_package_name,
        'new_lead',
        CASE WHEN v_notes != '' THEN 'Customer Note: ' || v_notes ELSE 'Marketing Landing Page Lead' END,
        v_utm_source,
        v_utm_medium,
        v_utm_campaign,
        v_ad_id,
        NOW(),
        NOW()
    ) RETURNING id INTO v_lead_id;

    -- 2. Create Order in orders table
    INSERT INTO public.orders (
        order_number,
        client_id,
        product_id,
        product_name,
        product_sku,
        marketer_id,
        marketer_name,
        form_id,
        lead_id,
        customer_name,
        customer_phone,
        customer_alt_phone,
        customer_email,
        delivery_address,
        delivery_state,
        delivery_city,
        quantity,
        total_amount,
        status,
        offer_package_id,
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        ad_id,
        delivery_notes,
        payment_method,
        is_pod,
        created_at,
        updated_at
    ) VALUES (
        v_order_number,
        v_client_id,
        v_product_id,
        v_product_name,
        v_product_sku,
        v_marketer_id,
        v_marketer_name,
        v_form_id,
        v_lead_id,
        v_customer_name,
        v_customer_phone,
        v_customer_alt_phone,
        v_customer_email,
        v_delivery_address,
        v_delivery_state,
        v_delivery_city,
        v_buy_qty,
        v_total_amount,
        'new',
        v_package_id,
        v_utm_source,
        v_utm_medium,
        v_utm_campaign,
        v_utm_content,
        v_ad_id,
        CASE WHEN v_notes != '' THEN 'Marketing Lead: ' || v_notes ELSE 'Marketing Landing Page Order' END,
        'cash_on_delivery',
        true,
        NOW(),
        NOW()
    ) RETURNING id INTO v_order_id;

    -- Link converted order to lead
    UPDATE public.customer_leads
    SET converted_order_id = v_order_id::text
    WHERE id = v_lead_id;

    -- 3. Execute Balanced Split Round-Robin Assignment to Closer
    v_assigned_closer_id := public.fn_assign_order_round_robin(v_order_id, v_product_id, v_client_id);
    
    IF v_assigned_closer_id IS NOT NULL THEN
        SELECT full_name INTO v_assigned_closer_name FROM public.client_closers WHERE id = v_assigned_closer_id;
    END IF;

    -- 4. Increment Form and Marketer submission counters
    UPDATE public.lead_forms
    SET total_submissions = COALESCE(total_submissions, 0) + 1,
        updated_at = NOW()
    WHERE id = v_form_id;

    IF v_marketer_id IS NOT NULL THEN
        UPDATE public.client_marketers
        SET total_orders_generated = COALESCE(total_orders_generated, 0) + 1,
            total_leads_generated = COALESCE(total_leads_generated, 0) + 1,
            updated_at = NOW()
        WHERE id = v_marketer_id;
    END IF;

    -- 5. Format Thank You Redirect URL
    IF v_redirect_url IS NOT NULL AND v_redirect_url != '' THEN
        v_final_redirect := v_redirect_url || (CASE WHEN v_redirect_url LIKE '%?%' THEN '&' ELSE '?' END) ||
            'order_id=' || v_order_id::text ||
            '&order_number=' || v_order_number ||
            '&amount=' || v_total_amount::text ||
            '&event_id=CAPI_ORD_' || REPLACE(v_order_number, '-', '_');
    ELSE
        v_final_redirect := '';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'order_id', v_order_id,
        'order_number', v_order_number,
        'lead_id', v_lead_id,
        'assigned_closer_id', v_assigned_closer_id,
        'assigned_closer_name', v_assigned_closer_name,
        'redirect_url', v_final_redirect,
        'total_amount', v_total_amount,
        'event_id', 'CAPI_ORD_' || REPLACE(v_order_number, '-', '_')
    );
END;
$$;

-- 7. Add client_marketers and lead_forms to Realtime Publication
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.client_marketers;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.lead_forms;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- 8. Enable Row Level Security (RLS) & Grant Access
ALTER TABLE public.client_marketers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lead_forms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read on active lead_forms"
    ON public.lead_forms FOR SELECT
    USING (is_active = true);

CREATE POLICY "Allow full access for service_role and authenticated users on lead_forms"
    ON public.lead_forms FOR ALL
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Allow full access on client_marketers"
    ON public.client_marketers FOR ALL
    USING (true)
    WITH CHECK (true);

-- Grant execute on stored procedures
GRANT EXECUTE ON FUNCTION public.fn_assign_order_round_robin(UUID, UUID, UUID) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_submit_marketing_lead_order(JSONB) TO anon, authenticated, service_role;


-- =================== 20260927091500_closer_confirmation_and_lga_dispatch.sql ===================
-- ============================================================================
-- Migration: 20260927091500_closer_confirmation_and_lga_dispatch.sql
-- Description: 
--   1. Ensures delivery_lga and lga columns are explicitly populated on order creation.
--   2. Prevents premature auto-dispatch for orders awaiting closer confirmation.
--   3. Adds fn_confirm_closer_order stored procedure to confirm order, update State/LGA,
--      and trigger automatic DC & Rider matching via auto_dispatch_order_by_state_lga.
--   4. Adds update trigger on orders.status to auto-dispatch on confirmation.
-- ============================================================================

-- 1. Ensure columns exist on orders table
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS delivery_lga TEXT,
  ADD COLUMN IF NOT EXISTS lga TEXT;

-- 2. Enhanced fn_submit_marketing_lead_order with explicit State & LGA storage
CREATE OR REPLACE FUNCTION public.fn_submit_marketing_lead_order(
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_form_id UUID;
    v_client_id UUID;
    v_marketer_id UUID;
    v_marketer_name TEXT;
    v_product_id UUID;
    v_product_name TEXT;
    v_product_sku TEXT;
    v_product_price NUMERIC;
    v_customer_name TEXT;
    v_customer_phone TEXT;
    v_customer_alt_phone TEXT;
    v_customer_email TEXT;
    v_delivery_address TEXT;
    v_delivery_state TEXT;
    v_delivery_lga TEXT;
    v_notes TEXT;
    v_package_id TEXT;
    v_package_name TEXT;
    v_buy_qty INT;
    v_total_amount NUMERIC;
    v_redirect_url TEXT;
    v_utm_source TEXT;
    v_utm_medium TEXT;
    v_utm_campaign TEXT;
    v_utm_content TEXT;
    v_ad_id TEXT;
    v_order_id UUID;
    v_lead_id UUID;
    v_order_number TEXT;
    v_assigned_closer_id UUID;
    v_assigned_closer_name TEXT;
    v_final_redirect TEXT;
BEGIN
    -- Parse & Sanitize Inputs
    v_form_id := (p_payload->>'form_id')::UUID;
    v_customer_name := TRIM(COALESCE(p_payload->>'customer_name', 'Valued Customer'));
    v_customer_phone := TRIM(COALESCE(p_payload->>'customer_phone', ''));
    v_customer_alt_phone := TRIM(COALESCE(p_payload->>'customer_alt_phone', ''));
    v_customer_email := TRIM(COALESCE(p_payload->>'customer_email', ''));
    v_delivery_address := TRIM(COALESCE(p_payload->>'delivery_address', ''));
    v_delivery_state := TRIM(COALESCE(p_payload->>'delivery_state', 'Lagos'));
    -- Harmonize LGA / City to canonical LGA
    v_delivery_lga := TRIM(COALESCE(p_payload->>'delivery_lga', p_payload->>'lga', p_payload->>'delivery_city', 'Ikeja'));
    v_notes := TRIM(COALESCE(p_payload->>'notes', ''));
    v_package_id := COALESCE(p_payload->>'package_id', 'pkg-1');
    v_package_name := COALESCE(p_payload->>'package_name', 'Standard Package');
    v_buy_qty := COALESCE((p_payload->>'buy_qty')::INT, 1);
    v_total_amount := COALESCE((p_payload->>'total_amount')::NUMERIC, 0.00);

    -- UTM attributes
    v_utm_source := p_payload->>'utm_source';
    v_utm_medium := p_payload->>'utm_medium';
    v_utm_campaign := p_payload->>'utm_campaign';
    v_utm_content := p_payload->>'utm_content';
    v_ad_id := p_payload->>'ad_id';

    -- Validation
    IF v_form_id IS NULL THEN
        RAISE EXCEPTION 'form_id is required';
    END IF;
    IF LENGTH(v_customer_phone) < 10 THEN
        RAISE EXCEPTION 'Valid phone number is required';
    END IF;

    -- Lookup Form Details
    SELECT f.client_id, f.marketer_id, f.product_id, f.product_name, f.redirect_url, m.full_name
    INTO v_client_id, v_marketer_id, v_product_id, v_product_name, v_redirect_url, v_marketer_name
    FROM public.lead_forms f
    LEFT JOIN public.client_marketers m ON m.id = f.marketer_id
    WHERE f.id = v_form_id;

    IF v_client_id IS NULL THEN
        RAISE EXCEPTION 'Lead form not found or inactive';
    END IF;

    -- Lookup Product SKU and base price if not supplied
    SELECT sku, price
    INTO v_product_sku, v_product_price
    FROM public.products
    WHERE id = v_product_id;

    IF v_total_amount <= 0 THEN
        v_total_amount := COALESCE(v_product_price, 25000.00) * v_buy_qty;
    END IF;

    -- Generate Clean Order Number: ORD-MK-YYMMDD-XXXX
    v_order_number := 'ORD-MK-' || TO_CHAR(NOW(), 'YYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');

    -- 1. Create Lead in customer_leads
    INSERT INTO public.customer_leads (
        client_id,
        marketer_id,
        form_id,
        customer_name,
        customer_phone,
        customer_address,
        delivery_state,
        delivery_lga,
        product_interest,
        package_interest,
        status,
        call_notes,
        utm_source,
        utm_medium,
        utm_campaign,
        ad_id,
        created_at,
        updated_at
    ) VALUES (
        v_client_id,
        v_marketer_id,
        v_form_id,
        v_customer_name,
        v_customer_phone,
        v_delivery_address,
        v_delivery_state,
        v_delivery_lga,
        v_product_name,
        v_package_name,
        'new_lead',
        CASE WHEN v_notes != '' THEN 'Customer Note: ' || v_notes ELSE 'Marketing Landing Page Lead' END,
        v_utm_source,
        v_utm_medium,
        v_utm_campaign,
        v_ad_id,
        NOW(),
        NOW()
    ) RETURNING id INTO v_lead_id;

    -- 2. Create Order in orders table with status 'new' and explicit LGA
    INSERT INTO public.orders (
        order_number,
        client_id,
        product_id,
        product_name,
        product_sku,
        marketer_id,
        marketer_name,
        form_id,
        lead_id,
        customer_name,
        customer_phone,
        customer_alt_phone,
        customer_email,
        delivery_address,
        delivery_state,
        delivery_lga,
        lga,
        delivery_city,
        quantity,
        total_amount,
        status,
        assignment_status,
        offer_package_id,
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        ad_id,
        delivery_notes,
        payment_method,
        is_pod,
        created_at,
        updated_at
    ) VALUES (
        v_order_number,
        v_client_id,
        v_product_id,
        v_product_name,
        v_product_sku,
        v_marketer_id,
        v_marketer_name,
        v_form_id,
        v_lead_id,
        v_customer_name,
        v_customer_phone,
        v_customer_alt_phone,
        v_customer_email,
        v_delivery_address,
        v_delivery_state,
        v_delivery_lga,
        v_delivery_lga,
        v_delivery_lga,
        v_buy_qty,
        v_total_amount,
        'new',
        'pending_closer_confirmation',
        v_package_id,
        v_utm_source,
        v_utm_medium,
        v_utm_campaign,
        v_utm_content,
        v_ad_id,
        CASE WHEN v_notes != '' THEN 'Marketing Lead: ' || v_notes ELSE 'Marketing Landing Page Order' END,
        'cash_on_delivery',
        true,
        NOW(),
        NOW()
    ) RETURNING id INTO v_order_id;

    -- Link converted order to lead
    UPDATE public.customer_leads
    SET converted_order_id = v_order_id::text
    WHERE id = v_lead_id;

    -- 3. Execute Balanced Split Round-Robin Assignment to Closer
    v_assigned_closer_id := public.fn_assign_order_round_robin(v_order_id, v_product_id, v_client_id);
    
    IF v_assigned_closer_id IS NOT NULL THEN
        SELECT full_name INTO v_assigned_closer_name FROM public.client_closers WHERE id = v_assigned_closer_id;
    END IF;

    -- 4. Increment Form and Marketer submission counters
    UPDATE public.lead_forms
    SET total_submissions = COALESCE(total_submissions, 0) + 1,
        updated_at = NOW()
    WHERE id = v_form_id;

    IF v_marketer_id IS NOT NULL THEN
        UPDATE public.client_marketers
        SET total_orders_generated = COALESCE(total_orders_generated, 0) + 1,
            total_leads_generated = COALESCE(total_leads_generated, 0) + 1,
            updated_at = NOW()
        WHERE id = v_marketer_id;
    END IF;

    -- 5. Format Thank You Redirect URL
    IF v_redirect_url IS NOT NULL AND v_redirect_url != '' THEN
        v_final_redirect := v_redirect_url || (CASE WHEN v_redirect_url LIKE '%?%' THEN '&' ELSE '?' END) ||
            'order_id=' || v_order_id::text ||
            '&order_number=' || v_order_number ||
            '&amount=' || v_total_amount::text ||
            '&event_id=CAPI_ORD_' || REPLACE(v_order_number, '-', '_');
    ELSE
        v_final_redirect := '';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'order_id', v_order_id,
        'order_number', v_order_number,
        'lead_id', v_lead_id,
        'assigned_closer_id', v_assigned_closer_id,
        'assigned_closer_name', v_assigned_closer_name,
        'redirect_url', v_final_redirect,
        'total_amount', v_total_amount,
        'event_id', 'CAPI_ORD_' || REPLACE(v_order_number, '-', '_')
    );
END;
$$;

-- 3. Refine Auto-Dispatch Trigger: Do NOT auto-dispatch orders awaiting closer confirmation
CREATE OR REPLACE FUNCTION public.trg_orders_auto_dispatch()
RETURNS TRIGGER AS $$
BEGIN
  -- If order has a closer and is awaiting confirmation ('new', 'unconfirmed', 'contacting'), DO NOT dispatch yet
  IF NEW.closer_id IS NOT NULL AND (NEW.status = 'new' OR NEW.status = 'unconfirmed' OR NEW.status = 'contacting') THEN
    RETURN NEW;
  END IF;

  -- Auto-dispatch if no delivery agent is assigned and status is confirmed or pending dispatch
  IF COALESCE(NEW.delivery_agent_id, NEW.assigned_agent_id) IS NULL 
     AND (
       NEW.status = 'confirmed' 
       OR NEW.status = 'pending_dispatch'
       OR (NEW.closer_id IS NULL AND (NEW.status = 'pending' OR NEW.status = 'new' OR NEW.status IS NULL))
     ) THEN
    PERFORM public.auto_dispatch_order_by_state_lga(NEW.id);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_orders_auto_dispatch_after_insert ON orders;
CREATE TRIGGER trg_orders_auto_dispatch_after_insert
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_orders_auto_dispatch();

DROP TRIGGER IF EXISTS trg_orders_auto_dispatch_after_update ON orders;
CREATE TRIGGER trg_orders_auto_dispatch_after_update
  AFTER UPDATE OF status ON orders
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('confirmed', 'pending_dispatch'))
  EXECUTE FUNCTION public.trg_orders_auto_dispatch();

-- 4. Stored Procedure: Closer Order Confirmation & Instant DC/Rider Dispatch
CREATE OR REPLACE FUNCTION public.fn_confirm_closer_order(
    p_order_id UUID,
    p_closer_id UUID,
    p_delivery_address TEXT DEFAULT NULL,
    p_delivery_state TEXT DEFAULT NULL,
    p_delivery_lga TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_order RECORD;
    v_dispatch_result JSONB;
    v_matched_dc_id UUID;
    v_matched_dc_name TEXT;
    v_assigned_agent_id UUID;
    v_assigned_agent_name TEXT;
    v_assigned_agent_phone TEXT;
    v_assigned_agent_code TEXT;
BEGIN
    -- 1. Fetch Order and verify existence
    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Order not found');
    END IF;

    -- 2. Update order address, state, and LGA details if updated during phone confirmation
    UPDATE public.orders
    SET 
        delivery_address = COALESCE(NULLIF(TRIM(p_delivery_address), ''), delivery_address),
        delivery_state = COALESCE(NULLIF(TRIM(p_delivery_state), ''), delivery_state),
        delivery_lga = COALESCE(NULLIF(TRIM(p_delivery_lga), ''), delivery_lga),
        lga = COALESCE(NULLIF(TRIM(p_delivery_lga), ''), lga, delivery_lga),
        delivery_city = COALESCE(NULLIF(TRIM(p_delivery_lga), ''), delivery_city, delivery_lga),
        delivery_notes = CASE 
            WHEN p_notes IS NOT NULL AND TRIM(p_notes) <> '' 
            THEN COALESCE(delivery_notes || E'\n[Closer Confirmation]: ' || TRIM(p_notes), '[Closer Confirmation]: ' || TRIM(p_notes))
            ELSE delivery_notes
        END,
        status = 'confirmed',
        updated_at = NOW()
    WHERE id = p_order_id;

    -- 3. Execute automatic State/LGA DC and Rider matching
    v_dispatch_result := public.auto_dispatch_order_by_state_lga(p_order_id);

    -- Fetch refreshed order routing state
    SELECT 
        o.distribution_center_id,
        dc.name AS dc_name,
        o.delivery_agent_id,
        da.name AS agent_name,
        da.phone AS agent_phone,
        da.agent_code
    INTO 
        v_matched_dc_id,
        v_matched_dc_name,
        v_assigned_agent_id,
        v_assigned_agent_name,
        v_assigned_agent_phone,
        v_assigned_agent_code
    FROM public.orders o
    LEFT JOIN public.distribution_centers dc ON dc.id = o.distribution_center_id
    LEFT JOIN public.delivery_agents da ON da.id = o.delivery_agent_id
    WHERE o.id = p_order_id;

    -- 4. Update Closer performance stats
    IF p_closer_id IS NOT NULL THEN
        UPDATE public.client_closers
        SET total_orders_booked = COALESCE(total_orders_booked, 0) + 1,
            total_leads_confirmed = COALESCE(total_leads_confirmed, 0) + 1,
            updated_at = NOW()
        WHERE id = p_closer_id;
    END IF;

    -- 5. Update linked customer_lead if exists
    IF v_order.lead_id IS NOT NULL THEN
        UPDATE public.customer_leads
        SET status = 'order_confirmed',
            call_notes = CASE 
                WHEN p_notes IS NOT NULL AND TRIM(p_notes) <> '' 
                THEN COALESCE(call_notes || E'\n[Confirmation]: ' || TRIM(p_notes), '[Confirmation]: ' || TRIM(p_notes))
                ELSE call_notes
            END,
            last_called_at = NOW(),
            updated_at = NOW()
        WHERE id = v_order.lead_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'order_number', v_order.order_number,
        'status', 'confirmed',
        'distribution_center_id', v_matched_dc_id,
        'distribution_center_name', v_matched_dc_name,
        'delivery_agent_id', v_assigned_agent_id,
        'delivery_agent_name', v_assigned_agent_name,
        'delivery_agent_phone', v_assigned_agent_phone,
        'delivery_agent_code', v_assigned_agent_code,
        'dispatch_result', v_dispatch_result
    );
END;
$$;

-- 5. Grants
GRANT EXECUTE ON FUNCTION public.fn_confirm_closer_order(UUID, UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_submit_marketing_lead_order(JSONB) TO authenticated, service_role, anon;

NOTIFY pgrst, 'reload schema';


-- =================== 20260927094000_realtime_marketing_and_closer_channels.sql ===================
-- Migration: 20260927094000_realtime_marketing_and_closer_channels.sql
-- Description: Ensure customer_leads, client_closers, lead_forms, client_marketers, and orders
-- are all added to the supabase_realtime publication for live socket streaming.

DO $$
DECLARE
    tbl text;
    tables text[] := ARRAY[
        'orders',
        'customer_leads',
        'lead_forms',
        'client_closers',
        'client_marketers'
    ];
BEGIN
    FOREACH tbl IN ARRAY tables LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' AND tablename = tbl
        ) THEN
            BEGIN
                EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I;', tbl);
            EXCEPTION WHEN OTHERS THEN
                NULL;
            END;
        END IF;
    END LOOP;
END $$;


-- =================== 20260928043000_marketer_chat_dp_and_package_sync.sql ===================
-- Migration: 20260928043000_marketer_chat_dp_and_package_sync.sql
-- Description:
-- 1. Add marketer_id, marketer_name, marketer_avatar_url, and form_id to public.order_conversations
-- 2. Upgrade fn_sync_order_conversation to populate marketer details so conversation DP is that of the marketer who generated the order
-- 3. Create fn_update_marketer_profile RPC to atomically update marketer avatar, phone, and bank details across tables
-- 4. Upgrade fn_submit_marketing_lead_order to ensure order conversation inherits marketer DP immediately

-- 1. Add Marketer Fields to order_conversations
ALTER TABLE public.order_conversations
  ADD COLUMN IF NOT EXISTS marketer_id UUID REFERENCES public.client_marketers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS marketer_name TEXT,
  ADD COLUMN IF NOT EXISTS marketer_avatar_url TEXT,
  ADD COLUMN IF NOT EXISTS form_id UUID REFERENCES public.lead_forms(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_order_conversations_marketer_id ON public.order_conversations(marketer_id);
CREATE INDEX IF NOT EXISTS idx_order_conversations_form_id ON public.order_conversations(form_id);

-- 2. Upgrade fn_sync_order_conversation to synchronize Marketer DP & closer DP
CREATE OR REPLACE FUNCTION public.fn_sync_order_conversation()
RETURNS TRIGGER AS $$
DECLARE
    v_client_name TEXT := 'Merchant';
    v_dc_name TEXT := 'Distribution Hub';
    v_rider_name TEXT := 'Unassigned Rider';
    v_closer_name TEXT := 'Sales Closer';
    v_closer_avatar_url TEXT := NULL;
    v_marketer_name TEXT := NULL;
    v_marketer_avatar_url TEXT := NULL;
BEGIN
    -- Lookup Client Company Name
    IF NEW.client_id IS NOT NULL THEN
        SELECT COALESCE(name, company_name, 'Merchant') INTO v_client_name
        FROM public.clients
        WHERE id = NEW.client_id;
    END IF;

    -- Lookup Distribution Center Name
    IF NEW.distribution_center_id IS NOT NULL THEN
        SELECT name INTO v_dc_name
        FROM public.distribution_centers
        WHERE id = NEW.distribution_center_id;
    END IF;

    -- Lookup Rider Full Name
    IF NEW.delivery_agent_id IS NOT NULL THEN
        SELECT COALESCE(da.full_name, u.first_name || ' ' || u.last_name, da.bank_account_name, da.agent_code, 'Rider')
        INTO v_rider_name
        FROM public.delivery_agents da
        LEFT JOIN public.users u ON da.user_id = u.id
        WHERE da.id = NEW.delivery_agent_id;
    END IF;

    -- Lookup Closer Full Name & Avatar URL
    IF NEW.closer_id IS NOT NULL THEN
        SELECT COALESCE(full_name, closer_name, closer_code, 'Sales Closer'), avatar_url 
        INTO v_closer_name, v_closer_avatar_url
        FROM public.client_closers
        WHERE id = NEW.closer_id;
    END IF;

    -- Fallback closer details
    IF v_closer_name IS NULL OR v_closer_name = 'Sales Closer' THEN
        IF NEW.closer_name IS NOT NULL AND TRIM(NEW.closer_name) <> '' THEN
            v_closer_name := NEW.closer_name;
        END IF;
    END IF;
    IF v_closer_avatar_url IS NULL THEN
        v_closer_avatar_url := NEW.closer_avatar_url;
    END IF;

    -- Lookup Digital Marketer Full Name & Avatar URL (the person whose lead form generated this order)
    IF NEW.marketer_id IS NOT NULL THEN
        SELECT COALESCE(full_name, marketer_code, 'Digital Marketer'), avatar_url
        INTO v_marketer_name, v_marketer_avatar_url
        FROM public.client_marketers
        WHERE id = NEW.marketer_id;
    END IF;

    IF v_marketer_name IS NULL AND NEW.marketer_name IS NOT NULL AND TRIM(NEW.marketer_name) <> '' THEN
        v_marketer_name := NEW.marketer_name;
    END IF;

    -- Insert or update order_conversations
    INSERT INTO public.order_conversations (
        order_id,
        order_number,
        customer_name,
        customer_phone,
        client_id,
        client_name,
        distribution_center_id,
        distribution_center_name,
        delivery_agent_id,
        delivery_agent_name,
        closer_id,
        closer_name,
        closer_avatar_url,
        marketer_id,
        marketer_name,
        marketer_avatar_url,
        form_id,
        order_status,
        current_product_name,
        current_package_name,
        current_total_amount,
        last_message_text,
        last_message_sender_name,
        last_message_at,
        updated_at
    ) VALUES (
        NEW.id,
        NEW.order_number,
        NEW.customer_name,
        NEW.customer_phone,
        NEW.client_id,
        COALESCE(NEW.client_name, v_client_name),
        NEW.distribution_center_id,
        v_dc_name,
        NEW.delivery_agent_id,
        v_rider_name,
        NEW.closer_id,
        COALESCE(NEW.closer_name, v_closer_name),
        v_closer_avatar_url,
        NEW.marketer_id,
        COALESCE(v_marketer_name, NEW.marketer_name),
        v_marketer_avatar_url,
        NEW.form_id,
        COALESCE(NEW.status, 'new'),
        NEW.product_name,
        NEW.package_deal_name,
        COALESCE(NEW.total_amount, 0),
        CASE 
            WHEN NEW.marketer_id IS NOT NULL THEN 'Marketing order created via Lead Form.'
            ELSE 'Order pipeline active.'
        END,
        COALESCE(v_marketer_name, 'System'),
        now(),
        now()
    )
    ON CONFLICT (order_id) DO UPDATE SET
        order_number = EXCLUDED.order_number,
        customer_name = EXCLUDED.customer_name,
        customer_phone = EXCLUDED.customer_phone,
        client_id = EXCLUDED.client_id,
        client_name = EXCLUDED.client_name,
        distribution_center_id = EXCLUDED.distribution_center_id,
        distribution_center_name = v_dc_name,
        delivery_agent_id = EXCLUDED.delivery_agent_id,
        delivery_agent_name = v_rider_name,
        closer_id = COALESCE(EXCLUDED.closer_id, order_conversations.closer_id),
        closer_name = COALESCE(EXCLUDED.closer_name, order_conversations.closer_name),
        closer_avatar_url = COALESCE(EXCLUDED.closer_avatar_url, order_conversations.closer_avatar_url),
        marketer_id = COALESCE(EXCLUDED.marketer_id, order_conversations.marketer_id),
        marketer_name = COALESCE(EXCLUDED.marketer_name, order_conversations.marketer_name),
        marketer_avatar_url = COALESCE(EXCLUDED.marketer_avatar_url, order_conversations.marketer_avatar_url),
        form_id = COALESCE(EXCLUDED.form_id, order_conversations.form_id),
        order_status = EXCLUDED.order_status,
        current_product_name = EXCLUDED.current_product_name,
        current_package_name = EXCLUDED.current_package_name,
        current_total_amount = EXCLUDED.current_total_amount,
        updated_at = now();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-attach trigger on orders table
DROP TRIGGER IF EXISTS trg_sync_order_conversation ON public.orders;
CREATE TRIGGER trg_sync_order_conversation
    AFTER INSERT OR UPDATE OF customer_name, customer_phone, client_id, distribution_center_id, delivery_agent_id, closer_id, marketer_id, form_id, status, product_name, package_deal_name, total_amount
    ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_sync_order_conversation();

-- Backfill existing order_conversations from orders
UPDATE public.order_conversations oc
SET marketer_id = o.marketer_id,
    marketer_name = COALESCE(m.full_name, o.marketer_name),
    marketer_avatar_url = m.avatar_url,
    form_id = o.form_id
FROM public.orders o
LEFT JOIN public.client_marketers m ON m.id = o.marketer_id
WHERE oc.order_id = o.id AND o.marketer_id IS NOT NULL;

-- 3. Stored Procedure: fn_update_marketer_profile
CREATE OR REPLACE FUNCTION public.fn_update_marketer_profile(
    p_marketer_id UUID,
    p_full_name TEXT DEFAULT NULL,
    p_phone TEXT DEFAULT NULL,
    p_avatar_url TEXT DEFAULT NULL,
    p_bank_name TEXT DEFAULT NULL,
    p_account_number TEXT DEFAULT NULL,
    p_account_name TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_updated_row RECORD;
BEGIN
    -- Update client_marketers table
    UPDATE public.client_marketers
    SET full_name = COALESCE(NULLIF(TRIM(p_full_name), ''), full_name),
        phone = COALESCE(NULLIF(TRIM(p_phone), ''), phone),
        avatar_url = COALESCE(NULLIF(TRIM(p_avatar_url), ''), avatar_url),
        bank_name = COALESCE(p_bank_name, bank_name),
        account_number = COALESCE(p_account_number, account_number),
        account_name = COALESCE(p_account_name, account_name),
        updated_at = NOW()
    WHERE id = p_marketer_id
    RETURNING * INTO v_updated_row;

    IF v_updated_row IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Marketer not found');
    END IF;

    -- If linked to auth user, cascade avatar_url and phone to users table
    v_user_id := v_updated_row.user_id;
    IF v_user_id IS NOT NULL THEN
        UPDATE public.users
        SET avatar_url = COALESCE(NULLIF(TRIM(p_avatar_url), ''), avatar_url),
            phone = COALESCE(NULLIF(TRIM(p_phone), ''), phone)
        WHERE id = v_user_id;
    END IF;

    -- Also update all existing order_conversations associated with this marketer
    IF p_avatar_url IS NOT NULL AND TRIM(p_avatar_url) <> '' THEN
        UPDATE public.order_conversations
        SET marketer_avatar_url = p_avatar_url,
            marketer_name = COALESCE(v_updated_row.full_name, marketer_name),
            updated_at = NOW()
        WHERE marketer_id = p_marketer_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'marketer_id', v_updated_row.id,
        'full_name', v_updated_row.full_name,
        'avatar_url', v_updated_row.avatar_url,
        'phone', v_updated_row.phone,
        'bank_name', v_updated_row.bank_name,
        'account_number', v_updated_row.account_number,
        'account_name', v_updated_row.account_name
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =================== 20260928051500_lead_order_package_deal_enrichment.sql ===================
-- Migration: 20260928051500_lead_order_package_deal_enrichment.sql
-- Description:
-- 1. Ensure paid_quantity, free_quantity, package_deal_name, package_deal_id exist on orders
-- 2. Upgrade fn_submit_marketing_lead_order to store paid_quantity, free_quantity, package_deal_name, and package_deal_id

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS paid_quantity INT DEFAULT 1,
  ADD COLUMN IF NOT EXISTS free_quantity INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS package_deal_name VARCHAR(255),
  ADD COLUMN IF NOT EXISTS package_deal_id TEXT;

CREATE OR REPLACE FUNCTION public.fn_submit_marketing_lead_order(p_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_form_id UUID;
    v_client_id UUID;
    v_marketer_id UUID;
    v_marketer_name TEXT;
    v_product_id UUID;
    v_product_name TEXT;
    v_product_sku TEXT;
    v_product_price NUMERIC;
    v_customer_name TEXT;
    v_customer_phone TEXT;
    v_customer_alt_phone TEXT;
    v_customer_email TEXT;
    v_delivery_address TEXT;
    v_delivery_state TEXT;
    v_delivery_lga TEXT;
    v_notes TEXT;
    v_package_id TEXT;
    v_package_name TEXT;
    v_paid_qty INT;
    v_free_qty INT;
    v_buy_qty INT;
    v_total_amount NUMERIC;
    v_redirect_url TEXT;
    v_utm_source TEXT;
    v_utm_medium TEXT;
    v_utm_campaign TEXT;
    v_utm_content TEXT;
    v_ad_id TEXT;
    v_order_id UUID;
    v_lead_id UUID;
    v_order_number TEXT;
    v_assigned_closer_id UUID;
    v_assigned_closer_name TEXT;
    v_final_redirect TEXT;
BEGIN
    -- Parse & Sanitize Inputs
    v_form_id := (p_payload->>'form_id')::UUID;
    v_customer_name := TRIM(COALESCE(p_payload->>'customer_name', 'Valued Customer'));
    v_customer_phone := TRIM(COALESCE(p_payload->>'customer_phone', ''));
    v_customer_alt_phone := TRIM(COALESCE(p_payload->>'customer_alt_phone', ''));
    v_customer_email := TRIM(COALESCE(p_payload->>'customer_email', ''));
    v_delivery_address := TRIM(COALESCE(p_payload->>'delivery_address', ''));
    v_delivery_state := TRIM(COALESCE(p_payload->>'delivery_state', 'Lagos'));
    -- Harmonize LGA / City to canonical LGA
    v_delivery_lga := TRIM(COALESCE(p_payload->>'delivery_lga', p_payload->>'lga', p_payload->>'delivery_city', 'Ikeja'));
    v_notes := TRIM(COALESCE(p_payload->>'notes', ''));
    v_package_id := COALESCE(p_payload->>'package_deal_id', p_payload->>'package_id', 'pkg-1');
    v_package_name := COALESCE(p_payload->>'package_selected', p_payload->>'package_name', 'Standard Package');
    
    v_paid_qty := COALESCE((p_payload->>'paid_quantity')::INT, (p_payload->>'buy_qty')::INT, 1);
    v_free_qty := COALESCE((p_payload->>'free_quantity')::INT, 0);
    v_buy_qty := COALESCE((p_payload->>'package_quantity')::INT, (p_payload->>'buy_qty')::INT, (v_paid_qty + v_free_qty));
    v_total_amount := COALESCE((p_payload->>'order_amount')::NUMERIC, (p_payload->>'total_amount')::NUMERIC, 0.00);

    -- UTM attributes
    v_utm_source := p_payload->>'utm_source';
    v_utm_medium := p_payload->>'utm_medium';
    v_utm_campaign := p_payload->>'utm_campaign';
    v_utm_content := p_payload->>'utm_content';
    v_ad_id := p_payload->>'ad_id';

    -- Validation
    IF v_form_id IS NULL THEN
        RAISE EXCEPTION 'form_id is required';
    END IF;
    IF LENGTH(v_customer_phone) < 10 THEN
        RAISE EXCEPTION 'Valid phone number is required';
    END IF;

    -- Lookup Form Details
    SELECT f.client_id, f.marketer_id, f.product_id, f.product_name, f.redirect_url, m.full_name
    INTO v_client_id, v_marketer_id, v_product_id, v_product_name, v_redirect_url, v_marketer_name
    FROM public.lead_forms f
    LEFT JOIN public.client_marketers m ON m.id = f.marketer_id
    WHERE f.id = v_form_id;

    IF v_client_id IS NULL THEN
        RAISE EXCEPTION 'Lead form not found or inactive';
    END IF;

    -- Lookup Product SKU and base price if not supplied
    IF v_product_id IS NOT NULL THEN
        SELECT sku, price INTO v_product_sku, v_product_price
        FROM public.products
        WHERE id = v_product_id;
    END IF;

    IF v_total_amount <= 0 AND v_product_price IS NOT NULL THEN
        v_total_amount := v_product_price * v_buy_qty;
    END IF;

    -- Generate unique human-readable order number
    v_order_number := 'ORD-MK-' || TO_CHAR(NOW(), 'YYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');

    -- 1. Create Lead in marketing_leads table
    INSERT INTO public.marketing_leads (
        client_id,
        marketer_id,
        form_id,
        customer_name,
        customer_phone,
        delivery_address,
        delivery_state,
        delivery_lga,
        product_name,
        package_selected,
        lead_status,
        notes,
        utm_source,
        utm_medium,
        utm_campaign,
        ad_id,
        created_at,
        updated_at
    ) VALUES (
        v_client_id,
        v_marketer_id,
        v_form_id,
        v_customer_name,
        v_customer_phone,
        v_delivery_address,
        v_delivery_state,
        v_delivery_lga,
        v_product_name,
        v_package_name,
        'new_lead',
        CASE WHEN v_notes != '' THEN 'Customer Note: ' || v_notes ELSE 'Marketing Landing Page Lead' END,
        v_utm_source,
        v_utm_medium,
        v_utm_campaign,
        v_ad_id,
        NOW(),
        NOW()
    ) RETURNING id INTO v_lead_id;

    -- 2. Create Order in orders table with package deal details, LGA, and pending closer confirmation
    INSERT INTO public.orders (
        order_number,
        client_id,
        product_id,
        product_name,
        product_sku,
        package_deal_name,
        package_deal_id,
        marketer_id,
        marketer_name,
        form_id,
        lead_id,
        customer_name,
        customer_phone,
        customer_alt_phone,
        customer_email,
        delivery_address,
        delivery_state,
        delivery_lga,
        lga,
        delivery_city,
        quantity,
        paid_quantity,
        free_quantity,
        total_amount,
        status,
        assignment_status,
        offer_package_id,
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        ad_id,
        delivery_notes,
        payment_method,
        is_pod,
        created_at,
        updated_at
    ) VALUES (
        v_order_number,
        v_client_id,
        v_product_id,
        v_product_name,
        v_product_sku,
        v_package_name,
        v_package_id,
        v_marketer_id,
        v_marketer_name,
        v_form_id,
        v_lead_id,
        v_customer_name,
        v_customer_phone,
        v_customer_alt_phone,
        v_customer_email,
        v_delivery_address,
        v_delivery_state,
        v_delivery_lga,
        v_delivery_lga,
        v_delivery_lga,
        v_buy_qty,
        v_paid_qty,
        v_free_qty,
        v_total_amount,
        'new',
        'pending_closer_confirmation',
        v_package_id,
        v_utm_source,
        v_utm_medium,
        v_utm_campaign,
        v_utm_content,
        v_ad_id,
        v_notes,
        'pay_on_delivery',
        true,
        NOW(),
        NOW()
    ) RETURNING id INTO v_order_id;

    -- 3. Execute Automatic Round-Robin Closer Assignment
    BEGIN
        SELECT closer_id, closer_name
        INTO v_assigned_closer_id, v_assigned_closer_name
        FROM public.fn_assign_order_to_product_closer(v_order_id);
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    -- 4. Update Form Statistics
    UPDATE public.lead_forms
    SET total_submissions = total_submissions + 1,
        total_orders_booked = total_orders_booked + 1,
        updated_at = NOW()
    WHERE id = v_form_id;

    -- 5. Update Marketer Aggregate Statistics
    IF v_marketer_id IS NOT NULL THEN
        UPDATE public.client_marketers
        SET total_leads_generated = total_leads_generated + 1,
            total_orders_generated = total_orders_generated + 1,
            updated_at = NOW()
        WHERE id = v_marketer_id;
    END IF;

    -- 6. Build Redirect URL with conversion parameters
    v_final_redirect := v_redirect_url;
    IF v_final_redirect IS NOT NULL AND v_final_redirect != '' THEN
        IF POSITION('?' IN v_final_redirect) > 0 THEN
            v_final_redirect := v_final_redirect || '&order_id=' || v_order_id::TEXT || '&order_number=' || v_order_number || '&amount=' || v_total_amount::TEXT;
        ELSE
            v_final_redirect := v_final_redirect || '?order_id=' || v_order_id::TEXT || '&order_number=' || v_order_number || '&amount=' || v_total_amount::TEXT;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'order_id', v_order_id,
        'order_number', v_order_number,
        'lead_id', v_lead_id,
        'status', 'new',
        'assignment_status', 'pending_closer_confirmation',
        'assigned_closer_id', v_assigned_closer_id,
        'assigned_closer_name', v_assigned_closer_name,
        'package_deal_name', v_package_name,
        'quantity', v_buy_qty,
        'paid_quantity', v_paid_qty,
        'free_quantity', v_free_qty,
        'total_amount', v_total_amount,
        'delivery_state', v_delivery_state,
        'delivery_lga', v_delivery_lga,
        'redirect_url', v_final_redirect
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_submit_marketing_lead_order(JSONB) TO authenticated, service_role, anon;


-- =================== 20260928060000_marketer_supervision_phone_normalization_and_dedup.sql ===================
-- Migration: 20260928060000_marketer_supervision_phone_normalization_and_dedup.sql
-- Description:
-- 1. Digital Marketer Supervision Hierarchy: is_supervisor flag and supervisor_id foreign key.
-- 2. Commission Model configuration: per_form_submission vs per_delivered_order.
-- 3. Robust Phone Number Normalization Function (handles +234, 00234, 234, leading 0, no leading 0, spaces, dashes, parentheses).
-- 4. Duplicate Form Submission Prevention: checks active orders by normalized phone and prevents double deliveries and duplicate commission claims.
-- 5. Updated RLS policies for order_conversations to scope regular marketers strictly to their assets and allow supervisors to view supervisees' orders.

-- 1. Extend client_marketers with supervisory and commission configuration
ALTER TABLE public.client_marketers
  ADD COLUMN IF NOT EXISTS is_supervisor BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS supervisor_id UUID REFERENCES public.client_marketers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS commission_model TEXT DEFAULT 'per_form_submission',
  ADD COLUMN IF NOT EXISTS commission_per_form_submission NUMERIC(12,2) DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS commission_per_delivered_order NUMERIC(12,2) DEFAULT 0.00;

CREATE INDEX IF NOT EXISTS idx_client_marketers_supervisor_id ON public.client_marketers(supervisor_id);
CREATE INDEX IF NOT EXISTS idx_client_marketers_is_supervisor ON public.client_marketers(is_supervisor);

-- 2. Extend users with marketer fields if not present
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS marketer_id UUID,
  ADD COLUMN IF NOT EXISTS marketer_code TEXT,
  ADD COLUMN IF NOT EXISTS is_supervisor BOOLEAN DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_users_marketer_id ON public.users(marketer_id);

-- 3. Extend orders and customer_leads with customer_phone_normalized column
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS customer_phone_normalized TEXT;

CREATE INDEX IF NOT EXISTS idx_orders_customer_phone_normalized ON public.orders(customer_phone_normalized);
CREATE INDEX IF NOT EXISTS idx_orders_client_phone_norm_status ON public.orders(client_id, customer_phone_normalized, status);

ALTER TABLE public.customer_leads
  ADD COLUMN IF NOT EXISTS customer_phone_normalized TEXT;

CREATE INDEX IF NOT EXISTS idx_customer_leads_phone_normalized ON public.customer_leads(customer_phone_normalized);

-- 4. Canonical Phone Number Normalization Function
CREATE OR REPLACE FUNCTION public.fn_normalize_nigerian_phone(p_phone TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_clean TEXT;
BEGIN
    IF p_phone IS NULL OR TRIM(p_phone) = '' THEN
        RETURN '';
    END IF;

    -- Strip all non-digit characters
    v_clean := REGEXP_REPLACE(p_phone, '\D', '', 'g');

    -- Strip international prefix 00234
    IF v_clean LIKE '00234%' THEN
        v_clean := SUBSTRING(v_clean FROM 6);
    -- Strip country code 234
    ELSIF v_clean LIKE '234%' THEN
        v_clean := SUBSTRING(v_clean FROM 4);
    END IF;

    -- Strip leading 0 if present (e.g. from +234(0)801... or 0801...)
    IF v_clean LIKE '0%' THEN
        v_clean := SUBSTRING(v_clean FROM 2);
    END IF;

    -- Standard Nigerian mobile numbers are 10 national digits (starting with 7, 8, or 9)
    -- If string length >= 10, take the rightmost 10 digits and prefix standard '0'
    IF LENGTH(v_clean) >= 10 THEN
        v_clean := RIGHT(v_clean, 10);
        RETURN '0' || v_clean; -- Canonical 11-digit local format: e.g. 08012345678
    END IF;

    -- Fallback for short local inputs
    IF LENGTH(v_clean) > 0 THEN
        RETURN '0' || v_clean;
    END IF;

    RETURN '';
END;
$$;

-- Populate existing orders' customer_phone_normalized for existing records
UPDATE public.orders
SET customer_phone_normalized = public.fn_normalize_nigerian_phone(customer_phone)
WHERE customer_phone_normalized IS NULL AND customer_phone IS NOT NULL;

-- 5. Upgraded Lead Form Submission RPC with Duplicate Prevention & Normalization
CREATE OR REPLACE FUNCTION public.fn_submit_marketing_lead_order(p_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_form_id UUID;
    v_client_id UUID;
    v_marketer_id UUID;
    v_marketer_name TEXT;
    v_product_id UUID;
    v_product_name TEXT;
    v_product_sku TEXT;
    v_product_price NUMERIC;
    v_customer_name TEXT;
    v_raw_customer_phone TEXT;
    v_customer_phone TEXT;
    v_customer_alt_phone TEXT;
    v_customer_email TEXT;
    v_delivery_address TEXT;
    v_delivery_state TEXT;
    v_delivery_lga TEXT;
    v_notes TEXT;
    v_package_id TEXT;
    v_package_name TEXT;
    v_paid_qty INT;
    v_free_qty INT;
    v_buy_qty INT;
    v_total_amount NUMERIC;
    v_redirect_url TEXT;
    v_utm_source TEXT;
    v_utm_medium TEXT;
    v_utm_campaign TEXT;
    v_utm_content TEXT;
    v_ad_id TEXT;
    v_order_id UUID;
    v_lead_id UUID;
    v_order_number TEXT;
    v_assigned_closer_id UUID;
    v_assigned_closer_name TEXT;
    v_final_redirect TEXT;

    -- Duplicate detection variables
    v_existing_order_id UUID;
    v_existing_order_number TEXT;
    v_existing_status TEXT;
    v_existing_amount NUMERIC;
    v_existing_package TEXT;
    v_existing_state TEXT;
    v_existing_lga TEXT;
    v_existing_created_at TIMESTAMPTZ;
BEGIN
    -- Parse & Sanitize Inputs
    v_form_id := (p_payload->>'form_id')::UUID;
    v_customer_name := TRIM(COALESCE(p_payload->>'customer_name', 'Valued Customer'));
    v_raw_customer_phone := TRIM(COALESCE(p_payload->>'customer_phone', ''));
    v_customer_phone := public.fn_normalize_nigerian_phone(v_raw_customer_phone);
    v_customer_alt_phone := TRIM(COALESCE(p_payload->>'customer_alt_phone', ''));
    v_customer_email := TRIM(COALESCE(p_payload->>'customer_email', ''));
    v_delivery_address := TRIM(COALESCE(p_payload->>'delivery_address', ''));
    v_delivery_state := TRIM(COALESCE(p_payload->>'delivery_state', 'Lagos'));
    v_delivery_lga := TRIM(COALESCE(p_payload->>'delivery_lga', p_payload->>'lga', p_payload->>'delivery_city', 'Ikeja'));
    v_notes := TRIM(COALESCE(p_payload->>'notes', ''));
    v_package_id := COALESCE(p_payload->>'package_deal_id', p_payload->>'package_id', 'pkg-1');
    v_package_name := COALESCE(p_payload->>'package_selected', p_payload->>'package_name', 'Standard Package');
    
    v_paid_qty := COALESCE((p_payload->>'paid_quantity')::INT, (p_payload->>'buy_qty')::INT, 1);
    v_free_qty := COALESCE((p_payload->>'free_quantity')::INT, 0);
    v_buy_qty := COALESCE((p_payload->>'package_quantity')::INT, (p_payload->>'buy_qty')::INT, (v_paid_qty + v_free_qty));
    v_total_amount := COALESCE((p_payload->>'order_amount')::NUMERIC, (p_payload->>'total_amount')::NUMERIC, 0.00);

    -- UTM attributes
    v_utm_source := p_payload->>'utm_source';
    v_utm_medium := p_payload->>'utm_medium';
    v_utm_campaign := p_payload->>'utm_campaign';
    v_utm_content := p_payload->>'utm_content';
    v_ad_id := p_payload->>'ad_id';

    -- Validation
    IF v_form_id IS NULL THEN
        RAISE EXCEPTION 'form_id is required';
    END IF;
    IF LENGTH(v_customer_phone) < 10 THEN
        RAISE EXCEPTION 'Valid phone number is required';
    END IF;

    -- Lookup Form Details
    SELECT f.client_id, f.marketer_id, f.product_id, f.product_name, f.redirect_url, m.full_name
    INTO v_client_id, v_marketer_id, v_product_id, v_product_name, v_redirect_url, v_marketer_name
    FROM public.lead_forms f
    LEFT JOIN public.client_marketers m ON m.id = f.marketer_id
    WHERE f.id = v_form_id;

    IF v_client_id IS NULL THEN
        RAISE EXCEPTION 'Lead form not found or inactive';
    END IF;

    -- DUPLICATE PREVENTION CHECK
    -- Detect if an active non-terminal order exists for this client with the same normalized phone within 48 hours
    SELECT id, order_number, status, total_amount, package_deal_name, delivery_state, delivery_lga, created_at
    INTO v_existing_order_id, v_existing_order_number, v_existing_status, v_existing_amount, v_existing_package, v_existing_state, v_existing_lga, v_existing_created_at
    FROM public.orders
    WHERE client_id = v_client_id
      AND (
          customer_phone_normalized = v_customer_phone
          OR customer_phone = v_customer_phone
          OR RIGHT(REGEXP_REPLACE(customer_phone, '\D', '', 'g'), 10) = RIGHT(v_customer_phone, 10)
      )
      AND status IN ('new', 'contacting', 'pending', 'confirmed', 'in_transit', 'rescheduled')
      AND created_at > (NOW() - INTERVAL '48 hours')
    ORDER BY created_at DESC
    LIMIT 1;

    -- If duplicate found, handle idempotently without creating a second fulfillment order
    IF v_existing_order_id IS NOT NULL THEN
        -- Record in customer_leads as duplicate for ad analytics tracking
        INSERT INTO public.customer_leads (
            client_id,
            marketer_id,
            form_id,
            customer_name,
            customer_phone,
            customer_phone_normalized,
            customer_address,
            delivery_state,
            delivery_lga,
            product_interest,
            package_interest,
            status,
            call_notes,
            utm_source,
            utm_medium,
            utm_campaign,
            ad_id,
            created_at,
            updated_at
        ) VALUES (
            v_client_id,
            v_marketer_id,
            v_form_id,
            v_customer_name,
            v_raw_customer_phone,
            v_customer_phone,
            v_delivery_address,
            v_delivery_state,
            v_delivery_lga,
            v_product_name,
            v_package_name,
            'duplicate_submission',
            'Duplicate form submission. Re-used existing active order #' || v_existing_order_number,
            v_utm_source,
            v_utm_medium,
            v_utm_campaign,
            v_ad_id,
            NOW(),
            NOW()
        );

        -- Append system note to existing order
        UPDATE public.orders
        SET delivery_notes = COALESCE(delivery_notes, '') || E'\n[SYSTEM] Repeat ad form submission from ' || COALESCE(v_utm_source, 'ad') || ' on ' || TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI') || '. Kept single order to avoid double delivery.',
            updated_at = NOW()
        WHERE id = v_existing_order_id;

        -- Prepare redirect URL
        v_final_redirect := v_redirect_url;
        IF v_final_redirect IS NOT NULL AND v_final_redirect != '' THEN
            IF POSITION('?' IN v_final_redirect) > 0 THEN
                v_final_redirect := v_final_redirect || '&order_id=' || v_existing_order_id::TEXT || '&order_number=' || v_existing_order_number || '&is_duplicate=true';
            ELSE
                v_final_redirect := v_final_redirect || '?order_id=' || v_existing_order_id::TEXT || '&order_number=' || v_existing_order_number || '&is_duplicate=true';
            END IF;
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'is_duplicate', true,
            'order_id', v_existing_order_id,
            'order_number', v_existing_order_number,
            'status', v_existing_status,
            'message', 'We have already received your order (#' || v_existing_order_number || ')! Our confirmation agent will contact you shortly.',
            'package_deal_name', COALESCE(v_existing_package, v_package_name),
            'total_amount', v_existing_amount,
            'delivery_state', v_existing_state,
            'delivery_lga', v_existing_lga,
            'redirect_url', v_final_redirect
        );
    END IF;

    -- Lookup Product SKU and base price if not supplied
    IF v_product_id IS NOT NULL THEN
        SELECT sku, price INTO v_product_sku, v_product_price
        FROM public.products
        WHERE id = v_product_id;
    END IF;

    IF v_total_amount <= 0 AND v_product_price IS NOT NULL THEN
        v_total_amount := v_product_price * v_buy_qty;
    END IF;

    -- Generate unique human-readable order number
    v_order_number := 'ORD-MK-' || TO_CHAR(NOW(), 'YYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');

    -- 1. Create Lead in customer_leads table
    INSERT INTO public.customer_leads (
        client_id,
        marketer_id,
        form_id,
        customer_name,
        customer_phone,
        customer_phone_normalized,
        customer_address,
        delivery_state,
        delivery_lga,
        product_interest,
        package_interest,
        status,
        call_notes,
        utm_source,
        utm_medium,
        utm_campaign,
        ad_id,
        created_at,
        updated_at
    ) VALUES (
        v_client_id,
        v_marketer_id,
        v_form_id,
        v_customer_name,
        v_raw_customer_phone,
        v_customer_phone,
        v_delivery_address,
        v_delivery_state,
        v_delivery_lga,
        v_product_name,
        v_package_name,
        'new_lead',
        CASE WHEN v_notes != '' THEN 'Customer Note: ' || v_notes ELSE 'Marketing Landing Page Lead' END,
        v_utm_source,
        v_utm_medium,
        v_utm_campaign,
        v_ad_id,
        NOW(),
        NOW()
    ) RETURNING id INTO v_lead_id;

    -- 2. Create Order in orders table with package deal details, LGA, normalized phone, and pending closer confirmation
    INSERT INTO public.orders (
        order_number,
        client_id,
        product_id,
        product_name,
        product_sku,
        package_deal_name,
        package_deal_id,
        marketer_id,
        marketer_name,
        form_id,
        lead_id,
        customer_name,
        customer_phone,
        customer_phone_normalized,
        customer_alt_phone,
        customer_email,
        delivery_address,
        delivery_state,
        delivery_lga,
        lga,
        delivery_city,
        quantity,
        paid_quantity,
        free_quantity,
        total_amount,
        status,
        assignment_status,
        offer_package_id,
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        ad_id,
        delivery_notes,
        payment_method,
        is_pod,
        created_at,
        updated_at
    ) VALUES (
        v_order_number,
        v_client_id,
        v_product_id,
        v_product_name,
        v_product_sku,
        v_package_name,
        v_package_id,
        v_marketer_id,
        v_marketer_name,
        v_form_id,
        v_lead_id,
        v_customer_name,
        v_customer_phone,
        v_customer_phone,
        v_customer_alt_phone,
        v_customer_email,
        v_delivery_address,
        v_delivery_state,
        v_delivery_lga,
        v_delivery_lga,
        v_delivery_lga,
        v_buy_qty,
        v_paid_qty,
        v_free_qty,
        v_total_amount,
        'new',
        'pending_closer_confirmation',
        v_package_id,
        v_utm_source,
        v_utm_medium,
        v_utm_campaign,
        v_utm_content,
        v_ad_id,
        v_notes,
        'pay_on_delivery',
        true,
        NOW(),
        NOW()
    ) RETURNING id INTO v_order_id;

    -- 3. Execute Automatic Round-Robin Closer Assignment
    BEGIN
        SELECT closer_id, closer_name
        INTO v_assigned_closer_id, v_assigned_closer_name
        FROM public.fn_assign_order_to_product_closer(v_order_id);
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    -- 4. Update Form Statistics
    UPDATE public.lead_forms
    SET total_submissions = total_submissions + 1,
        total_orders_booked = total_orders_booked + 1,
        updated_at = NOW()
    WHERE id = v_form_id;

    -- 5. Update Marketer Aggregate Statistics
    IF v_marketer_id IS NOT NULL THEN
        UPDATE public.client_marketers
        SET total_leads_generated = total_leads_generated + 1,
            total_orders_generated = total_orders_generated + 1,
            updated_at = NOW()
        WHERE id = v_marketer_id;
    END IF;

    -- 6. Build Redirect URL with conversion parameters
    v_final_redirect := v_redirect_url;
    IF v_final_redirect IS NOT NULL AND v_final_redirect != '' THEN
        IF POSITION('?' IN v_final_redirect) > 0 THEN
            v_final_redirect := v_final_redirect || '&order_id=' || v_order_id::TEXT || '&order_number=' || v_order_number || '&amount=' || v_total_amount::TEXT;
        ELSE
            v_final_redirect := v_final_redirect || '?order_id=' || v_order_id::TEXT || '&order_number=' || v_order_number || '&amount=' || v_total_amount::TEXT;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'is_duplicate', false,
        'order_id', v_order_id,
        'order_number', v_order_number,
        'lead_id', v_lead_id,
        'status', 'new',
        'assignment_status', 'pending_closer_confirmation',
        'assigned_closer_id', v_assigned_closer_id,
        'assigned_closer_name', v_assigned_closer_name,
        'package_deal_name', v_package_name,
        'quantity', v_buy_qty,
        'paid_quantity', v_paid_qty,
        'free_quantity', v_free_qty,
        'total_amount', v_total_amount,
        'delivery_state', v_delivery_state,
        'delivery_lga', v_delivery_lga,
        'redirect_url', v_final_redirect
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_normalize_nigerian_phone(TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_submit_marketing_lead_order(JSONB) TO authenticated, service_role, anon;

-- 6. Security & Scoping RLS for order_conversations
-- Marketers can strictly see their own conversations; Supervisors see their own + their supervisees'
DROP POLICY IF EXISTS "Users can view conversations relevant to them" ON public.order_conversations;
CREATE POLICY "Users can view conversations relevant to them" ON public.order_conversations
FOR SELECT USING (
    auth.role() = 'service_role' OR
    (
        auth.uid() IS NOT NULL AND
        EXISTS (
            SELECT 1 FROM public.users u
            LEFT JOIN public.delivery_agents da ON da.user_id = u.id
            LEFT JOIN public.client_closers cc ON cc.user_id = u.id
            LEFT JOIN public.client_marketers cm ON cm.user_id = u.id OR cm.id = u.marketer_id
            WHERE u.id = auth.uid() AND (
                (u.role IN ('client', 'merchant') AND u.client_id::text = order_conversations.client_id::text) OR
                (u.role IN ('dc_manager', 'dc_staff', 'operations') AND u.distribution_center_id::text = order_conversations.distribution_center_id::text) OR
                (da.id::text = order_conversations.delivery_agent_id::text) OR
                (cc.id::text = order_conversations.closer_id::text) OR
                -- Regular Marketer: strictly their own conversations
                (cm.id IS NOT NULL AND cm.is_supervisor = false AND order_conversations.marketer_id = cm.id) OR
                -- Supervisory Marketer: their own conversations + their supervisees' conversations
                (cm.id IS NOT NULL AND cm.is_supervisor = true AND (
                    order_conversations.marketer_id = cm.id OR
                    order_conversations.marketer_id IN (SELECT id FROM public.client_marketers WHERE supervisor_id = cm.id)
                )) OR
                (u.role IN ('super_admin', 'admin'))
            )
        )
    )
);


-- =================== 20260928062000_fix_product_base_price_in_lead_order_fn.sql ===================
-- Migration: Fix products column lookup (base_price instead of price) in fn_submit_marketing_lead_order
-- Ensures live lead orders retrieve product SKU and base price seamlessly without column error

CREATE OR REPLACE FUNCTION public.fn_submit_marketing_lead_order(p_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_form_id UUID;
    v_client_id UUID;
    v_marketer_id UUID;
    v_marketer_name TEXT;
    v_product_id UUID;
    v_product_name TEXT;
    v_product_sku TEXT;
    v_product_price NUMERIC;
    v_customer_name TEXT;
    v_raw_customer_phone TEXT;
    v_customer_phone TEXT;
    v_customer_alt_phone TEXT;
    v_customer_email TEXT;
    v_delivery_address TEXT;
    v_delivery_state TEXT;
    v_delivery_lga TEXT;
    v_notes TEXT;
    v_package_id TEXT;
    v_package_name TEXT;
    v_paid_qty INT;
    v_free_qty INT;
    v_buy_qty INT;
    v_total_amount NUMERIC;
    v_redirect_url TEXT;
    v_utm_source TEXT;
    v_utm_medium TEXT;
    v_utm_campaign TEXT;
    v_utm_content TEXT;
    v_ad_id TEXT;
    v_order_id UUID;
    v_lead_id UUID;
    v_order_number TEXT;
    v_assigned_closer_id UUID;
    v_assigned_closer_name TEXT;
    v_final_redirect TEXT;

    -- Duplicate detection variables
    v_existing_order_id UUID;
    v_existing_order_number TEXT;
    v_existing_status TEXT;
    v_existing_amount NUMERIC;
    v_existing_package TEXT;
    v_existing_state TEXT;
    v_existing_lga TEXT;
    v_existing_created_at TIMESTAMPTZ;
BEGIN
    -- Parse & Sanitize Inputs
    v_form_id := (p_payload->>'form_id')::UUID;
    v_customer_name := TRIM(COALESCE(p_payload->>'customer_name', 'Valued Customer'));
    v_raw_customer_phone := TRIM(COALESCE(p_payload->>'customer_phone', ''));
    v_customer_phone := public.fn_normalize_nigerian_phone(v_raw_customer_phone);
    v_customer_alt_phone := TRIM(COALESCE(p_payload->>'customer_alt_phone', ''));
    v_customer_email := TRIM(COALESCE(p_payload->>'customer_email', ''));
    v_delivery_address := TRIM(COALESCE(p_payload->>'delivery_address', ''));
    v_delivery_state := TRIM(COALESCE(p_payload->>'delivery_state', 'Lagos'));
    v_delivery_lga := TRIM(COALESCE(p_payload->>'delivery_lga', p_payload->>'lga', p_payload->>'delivery_city', 'Ikeja'));
    v_notes := TRIM(COALESCE(p_payload->>'notes', ''));
    v_package_id := COALESCE(p_payload->>'package_deal_id', p_payload->>'package_id', 'pkg-1');
    v_package_name := COALESCE(p_payload->>'package_selected', p_payload->>'package_name', 'Standard Package');
    
    v_paid_qty := COALESCE((p_payload->>'paid_quantity')::INT, (p_payload->>'buy_qty')::INT, 1);
    v_free_qty := COALESCE((p_payload->>'free_quantity')::INT, 0);
    v_buy_qty := COALESCE((p_payload->>'package_quantity')::INT, (p_payload->>'buy_qty')::INT, (v_paid_qty + v_free_qty));
    v_total_amount := COALESCE((p_payload->>'order_amount')::NUMERIC, (p_payload->>'total_amount')::NUMERIC, 0.00);

    -- UTM attributes
    v_utm_source := p_payload->>'utm_source';
    v_utm_medium := p_payload->>'utm_medium';
    v_utm_campaign := p_payload->>'utm_campaign';
    v_utm_content := p_payload->>'utm_content';
    v_ad_id := p_payload->>'ad_id';

    -- Validation
    IF v_form_id IS NULL THEN
        RAISE EXCEPTION 'Form ID is strictly required to book lead order';
    END IF;

    IF v_customer_phone IS NULL OR LENGTH(v_customer_phone) < 10 THEN
        RAISE EXCEPTION 'A valid Nigerian phone number is required to book order';
    END IF;

    -- Lookup Lead Form attributes
    SELECT 
        client_id,
        marketer_id,
        product_id,
        product_name,
        redirect_url
    INTO 
        v_client_id,
        v_marketer_id,
        v_product_id,
        v_product_name,
        v_redirect_url
    FROM public.lead_forms
    WHERE id = v_form_id;

    IF v_client_id IS NULL THEN
        RAISE EXCEPTION 'Lead form not found or has been disabled';
    END IF;

    -- Lookup Marketer full name if assigned
    IF v_marketer_id IS NOT NULL THEN
        SELECT full_name INTO v_marketer_name
        FROM public.client_marketers
        WHERE id = v_marketer_id;
    END IF;

    -- =========================================================================
    -- CANONICAL DUPLICATE DETECTION ACROSS NORMALIZED PHONE NUMBERS
    -- =========================================================================
    SELECT 
        id, 
        order_number, 
        status, 
        total_amount, 
        package_deal_name, 
        delivery_state, 
        delivery_lga,
        created_at
    INTO 
        v_existing_order_id, 
        v_existing_order_number, 
        v_existing_status, 
        v_existing_amount, 
        v_existing_package, 
        v_existing_state, 
        v_existing_lga,
        v_existing_created_at
    FROM public.orders
    WHERE client_id = v_client_id
      AND customer_phone_normalized = v_customer_phone
      AND (
          status IN ('new', 'contacting', 'pending', 'confirmed', 'in_transit', 'rescheduled')
          OR created_at >= (NOW() - INTERVAL '48 HOURS')
      )
    ORDER BY created_at DESC
    LIMIT 1;

    -- Construct fallback thank-you redirect URL
    v_final_redirect := COALESCE(NULLIF(v_redirect_url, ''), '/thank-you?order=' || COALESCE(v_existing_order_number, ''));

    IF v_existing_order_id IS NOT NULL THEN
        -- Record audit lead entry in customer_leads noting duplicate submission
        INSERT INTO public.customer_leads (
            client_id,
            marketer_id,
            form_id,
            customer_name,
            customer_phone,
            customer_phone_normalized,
            customer_address,
            delivery_state,
            delivery_lga,
            product_interest,
            package_interest,
            status,
            call_notes,
            utm_source,
            utm_medium,
            utm_campaign,
            ad_id,
            created_at,
            updated_at
        ) VALUES (
            v_client_id,
            v_marketer_id,
            v_form_id,
            v_customer_name,
            v_raw_customer_phone,
            v_customer_phone,
            v_delivery_address,
            v_delivery_state,
            v_delivery_lga,
            v_product_name,
            v_package_name,
            'duplicate_submission',
            'Duplicate form submission prevented for active order #' || v_existing_order_number || ' (Phone: ' || v_customer_phone || ')',
            v_utm_source,
            v_utm_medium,
            v_utm_campaign,
            v_ad_id,
            NOW(),
            NOW()
        );

        -- Append duplicate note to existing order's notes
        UPDATE public.orders
        SET delivery_notes = COALESCE(delivery_notes, '') || ' [Duplicate Form Submission on ' || TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI') || ' UTC]'
        WHERE id = v_existing_order_id;

        -- Return duplicate acknowledgment referencing the original active order
        RETURN jsonb_build_object(
            'is_duplicate', true,
            'order_id', v_existing_order_id,
            'order_number', v_existing_order_number,
            'status', v_existing_status,
            'message', 'We have already received your order (#' || v_existing_order_number || ')! Our confirmation agent will contact you shortly.',
            'package_deal_name', COALESCE(v_existing_package, v_package_name),
            'total_amount', v_existing_amount,
            'delivery_state', v_existing_state,
            'delivery_lga', v_existing_lga,
            'redirect_url', v_final_redirect
        );
    END IF;

    -- Lookup Product SKU and base price if not supplied (base_price column)
    IF v_product_id IS NOT NULL THEN
        SELECT sku, base_price INTO v_product_sku, v_product_price
        FROM public.products
        WHERE id = v_product_id;
    END IF;

    IF v_total_amount <= 0 AND v_product_price IS NOT NULL THEN
        v_total_amount := v_product_price * v_buy_qty;
    END IF;

    -- Generate unique human-readable order number
    v_order_number := 'ORD-MK-' || TO_CHAR(NOW(), 'YYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');

    -- 1. Create Lead in customer_leads table
    INSERT INTO public.customer_leads (
        client_id,
        marketer_id,
        form_id,
        customer_name,
        customer_phone,
        customer_phone_normalized,
        customer_address,
        delivery_state,
        delivery_lga,
        product_interest,
        package_interest,
        status,
        call_notes,
        utm_source,
        utm_medium,
        utm_campaign,
        ad_id,
        created_at,
        updated_at
    ) VALUES (
        v_client_id,
        v_marketer_id,
        v_form_id,
        v_customer_name,
        v_raw_customer_phone,
        v_customer_phone,
        v_delivery_address,
        v_delivery_state,
        v_delivery_lga,
        v_product_name,
        v_package_name,
        'new_lead',
        CASE WHEN v_notes != '' THEN 'Customer Note: ' || v_notes ELSE 'Marketing Landing Page Lead' END,
        v_utm_source,
        v_utm_medium,
        v_utm_campaign,
        v_ad_id,
        NOW(),
        NOW()
    ) RETURNING id INTO v_lead_id;

    -- 2. Create Order in orders table with package deal details, LGA, normalized phone, and pending closer confirmation
    INSERT INTO public.orders (
        order_number,
        client_id,
        product_id,
        product_name,
        product_sku,
        package_deal_name,
        package_deal_id,
        marketer_id,
        marketer_name,
        form_id,
        lead_id,
        customer_name,
        customer_phone,
        customer_phone_normalized,
        customer_alt_phone,
        customer_email,
        delivery_address,
        delivery_state,
        delivery_lga,
        lga,
        delivery_city,
        quantity,
        paid_quantity,
        free_quantity,
        total_amount,
        status,
        assignment_status,
        offer_package_id,
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        ad_id,
        delivery_notes,
        payment_method,
        is_pod,
        created_at,
        updated_at
    ) VALUES (
        v_order_number,
        v_client_id,
        v_product_id,
        v_product_name,
        v_product_sku,
        v_package_name,
        v_package_id,
        v_marketer_id,
        v_marketer_name,
        v_form_id,
        v_lead_id,
        v_customer_name,
        v_customer_phone,
        v_customer_phone,
        v_customer_alt_phone,
        v_customer_email,
        v_delivery_address,
        v_delivery_state,
        v_delivery_lga,
        v_delivery_lga,
        v_delivery_lga,
        v_buy_qty,
        v_paid_qty,
        v_free_qty,
        v_total_amount,
        'new',
        'pending_closer_confirmation',
        v_package_id,
        v_utm_source,
        v_utm_medium,
        v_utm_campaign,
        v_utm_content,
        v_ad_id,
        v_notes,
        'pay_on_delivery',
        true,
        NOW(),
        NOW()
    ) RETURNING id INTO v_order_id;

    -- 3. Execute Automatic Round-Robin Closer Assignment
    BEGIN
        SELECT closer_id, closer_name
        INTO v_assigned_closer_id, v_assigned_closer_name
        FROM public.fn_assign_order_to_product_closer(v_order_id);
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    -- 4. Update Form Statistics
    UPDATE public.lead_forms
    SET total_submissions = total_submissions + 1,
        total_orders_booked = total_orders_booked + 1,
        updated_at = NOW()
    WHERE id = v_form_id;

    -- 5. Update Marketer Aggregate Statistics
    IF v_marketer_id IS NOT NULL THEN
        UPDATE public.client_marketers
        SET total_leads_generated = total_leads_generated + 1,
            total_orders_generated = total_orders_generated + 1,
            updated_at = NOW()
        WHERE id = v_marketer_id;
    END IF;

    -- 6. Link Customer Lead to Order
    UPDATE public.customer_leads
    SET order_id = v_order_id,
        converted_to_order = true,
        status = 'order_created',
        updated_at = NOW()
    WHERE id = v_lead_id;

    -- 7. Return Result Payload
    RETURN jsonb_build_object(
        'is_duplicate', false,
        'order_id', v_order_id,
        'lead_id', v_lead_id,
        'order_number', v_order_number,
        'status', 'new',
        'customer_name', v_customer_name,
        'customer_phone', v_customer_phone,
        'package_deal_name', v_package_name,
        'quantity', v_buy_qty,
        'paid_quantity', v_paid_qty,
        'free_quantity', v_free_qty,
        'total_amount', v_total_amount,
        'delivery_state', v_delivery_state,
        'delivery_lga', v_delivery_lga,
        'closer_assigned', v_assigned_closer_name,
        'redirect_url', v_final_redirect,
        'message', 'Order successfully booked from marketing form'
    );
END;
$$;


-- =================== 20260928063000_ensure_order_marketing_columns.sql ===================
-- Migration: Ensure customer_email and optional marketing columns exist on orders table
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_email TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_alt_phone TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS offer_package_id TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'pay_on_delivery';
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS is_pod BOOLEAN DEFAULT true;


-- =================== 20260928064000_resolve_company_id_in_lead_orders.sql ===================
-- Migration: Set default on orders.company_id and resolve company_id in fn_submit_marketing_lead_order
-- Ensures all marketing lead orders satisfy company_id not-null constraint seamlessly

ALTER TABLE public.orders ALTER COLUMN company_id SET DEFAULT '11111111-1111-4111-8111-111111111111'::UUID;

CREATE OR REPLACE FUNCTION public.fn_submit_marketing_lead_order(p_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_form_id UUID;
    v_client_id UUID;
    v_company_id UUID;
    v_marketer_id UUID;
    v_marketer_name TEXT;
    v_product_id UUID;
    v_product_name TEXT;
    v_product_sku TEXT;
    v_product_price NUMERIC;
    v_customer_name TEXT;
    v_raw_customer_phone TEXT;
    v_customer_phone TEXT;
    v_customer_alt_phone TEXT;
    v_customer_email TEXT;
    v_delivery_address TEXT;
    v_delivery_state TEXT;
    v_delivery_lga TEXT;
    v_notes TEXT;
    v_package_id TEXT;
    v_package_name TEXT;
    v_paid_qty INT;
    v_free_qty INT;
    v_buy_qty INT;
    v_total_amount NUMERIC;
    v_redirect_url TEXT;
    v_utm_source TEXT;
    v_utm_medium TEXT;
    v_utm_campaign TEXT;
    v_utm_content TEXT;
    v_ad_id TEXT;
    v_order_id UUID;
    v_lead_id UUID;
    v_order_number TEXT;
    v_assigned_closer_id UUID;
    v_assigned_closer_name TEXT;
    v_final_redirect TEXT;

    -- Duplicate detection variables
    v_existing_order_id UUID;
    v_existing_order_number TEXT;
    v_existing_status TEXT;
    v_existing_amount NUMERIC;
    v_existing_package TEXT;
    v_existing_state TEXT;
    v_existing_lga TEXT;
    v_existing_created_at TIMESTAMPTZ;
BEGIN
    -- Parse & Sanitize Inputs
    v_form_id := (p_payload->>'form_id')::UUID;
    v_customer_name := TRIM(COALESCE(p_payload->>'customer_name', 'Valued Customer'));
    v_raw_customer_phone := TRIM(COALESCE(p_payload->>'customer_phone', ''));
    v_customer_phone := public.fn_normalize_nigerian_phone(v_raw_customer_phone);
    v_customer_alt_phone := TRIM(COALESCE(p_payload->>'customer_alt_phone', ''));
    v_customer_email := TRIM(COALESCE(p_payload->>'customer_email', ''));
    v_delivery_address := TRIM(COALESCE(p_payload->>'delivery_address', ''));
    v_delivery_state := TRIM(COALESCE(p_payload->>'delivery_state', 'Lagos'));
    v_delivery_lga := TRIM(COALESCE(p_payload->>'delivery_lga', p_payload->>'lga', p_payload->>'delivery_city', 'Ikeja'));
    v_notes := TRIM(COALESCE(p_payload->>'notes', ''));
    v_package_id := COALESCE(p_payload->>'package_deal_id', p_payload->>'package_id', 'pkg-1');
    v_package_name := COALESCE(p_payload->>'package_selected', p_payload->>'package_name', 'Standard Package');
    
    v_paid_qty := COALESCE((p_payload->>'paid_quantity')::INT, (p_payload->>'buy_qty')::INT, 1);
    v_free_qty := COALESCE((p_payload->>'free_quantity')::INT, 0);
    v_buy_qty := COALESCE((p_payload->>'package_quantity')::INT, (p_payload->>'buy_qty')::INT, (v_paid_qty + v_free_qty));
    v_total_amount := COALESCE((p_payload->>'order_amount')::NUMERIC, (p_payload->>'total_amount')::NUMERIC, 0.00);

    -- UTM attributes
    v_utm_source := p_payload->>'utm_source';
    v_utm_medium := p_payload->>'utm_medium';
    v_utm_campaign := p_payload->>'utm_campaign';
    v_utm_content := p_payload->>'utm_content';
    v_ad_id := p_payload->>'ad_id';

    -- Validation
    IF v_form_id IS NULL THEN
        RAISE EXCEPTION 'Form ID is strictly required to book lead order';
    END IF;

    IF v_customer_phone IS NULL OR LENGTH(v_customer_phone) < 10 THEN
        RAISE EXCEPTION 'A valid Nigerian phone number is required to book order';
    END IF;

    -- Lookup Lead Form attributes
    SELECT 
        client_id,
        marketer_id,
        product_id,
        product_name,
        redirect_url
    INTO 
        v_client_id,
        v_marketer_id,
        v_product_id,
        v_product_name,
        v_redirect_url
    FROM public.lead_forms
    WHERE id = v_form_id;

    IF v_client_id IS NULL THEN
        RAISE EXCEPTION 'Lead form not found or has been disabled';
    END IF;

    -- Lookup Marketer full name if assigned
    IF v_marketer_id IS NOT NULL THEN
        SELECT full_name INTO v_marketer_name
        FROM public.client_marketers
        WHERE id = v_marketer_id;
    END IF;

    -- Resolve company_id for orders table
    BEGIN
        SELECT company_id INTO v_company_id FROM public.clients WHERE id = v_client_id;
    EXCEPTION WHEN OTHERS THEN
        v_company_id := NULL;
    END;
    IF v_company_id IS NULL THEN
        BEGIN
            SELECT id INTO v_company_id FROM public.companies LIMIT 1;
        EXCEPTION WHEN OTHERS THEN
            v_company_id := NULL;
        END;
    END IF;
    IF v_company_id IS NULL THEN
        v_company_id := '11111111-1111-4111-8111-111111111111'::UUID;
    END IF;

    -- =========================================================================
    -- CANONICAL DUPLICATE DETECTION ACROSS NORMALIZED PHONE NUMBERS
    -- =========================================================================
    SELECT 
        id, 
        order_number, 
        status, 
        total_amount, 
        package_deal_name, 
        delivery_state, 
        delivery_lga,
        created_at
    INTO 
        v_existing_order_id, 
        v_existing_order_number, 
        v_existing_status, 
        v_existing_amount, 
        v_existing_package, 
        v_existing_state, 
        v_existing_lga,
        v_existing_created_at
    FROM public.orders
    WHERE client_id = v_client_id
      AND customer_phone_normalized = v_customer_phone
      AND (
          status IN ('new', 'contacting', 'pending', 'confirmed', 'in_transit', 'rescheduled')
          OR created_at >= (NOW() - INTERVAL '48 HOURS')
      )
    ORDER BY created_at DESC
    LIMIT 1;

    -- Construct fallback thank-you redirect URL
    v_final_redirect := COALESCE(NULLIF(v_redirect_url, ''), '/thank-you?order=' || COALESCE(v_existing_order_number, ''));

    IF v_existing_order_id IS NOT NULL THEN
        -- Record audit lead entry in customer_leads noting duplicate submission
        INSERT INTO public.customer_leads (
            client_id,
            marketer_id,
            form_id,
            customer_name,
            customer_phone,
            customer_phone_normalized,
            customer_address,
            delivery_state,
            delivery_lga,
            product_interest,
            package_interest,
            status,
            call_notes,
            utm_source,
            utm_medium,
            utm_campaign,
            ad_id,
            created_at,
            updated_at
        ) VALUES (
            v_client_id,
            v_marketer_id,
            v_form_id,
            v_customer_name,
            v_raw_customer_phone,
            v_customer_phone,
            v_delivery_address,
            v_delivery_state,
            v_delivery_lga,
            v_product_name,
            v_package_name,
            'duplicate_submission',
            'Duplicate form submission prevented for active order #' || v_existing_order_number || ' (Phone: ' || v_customer_phone || ')',
            v_utm_source,
            v_utm_medium,
            v_utm_campaign,
            v_ad_id,
            NOW(),
            NOW()
        );

        -- Append duplicate note to existing order's notes
        UPDATE public.orders
        SET delivery_notes = COALESCE(delivery_notes, '') || ' [Duplicate Form Submission on ' || TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI') || ' UTC]'
        WHERE id = v_existing_order_id;

        -- Return duplicate acknowledgment referencing the original active order
        RETURN jsonb_build_object(
            'is_duplicate', true,
            'order_id', v_existing_order_id,
            'order_number', v_existing_order_number,
            'status', v_existing_status,
            'message', 'We have already received your order (#' || v_existing_order_number || ')! Our confirmation agent will contact you shortly.',
            'package_deal_name', COALESCE(v_existing_package, v_package_name),
            'total_amount', v_existing_amount,
            'delivery_state', v_existing_state,
            'delivery_lga', v_existing_lga,
            'redirect_url', v_final_redirect
        );
    END IF;

    -- Lookup Product SKU and base price if not supplied (base_price column)
    IF v_product_id IS NOT NULL THEN
        SELECT sku, base_price INTO v_product_sku, v_product_price
        FROM public.products
        WHERE id = v_product_id;
    END IF;

    IF v_total_amount <= 0 AND v_product_price IS NOT NULL THEN
        v_total_amount := v_product_price * v_buy_qty;
    END IF;

    -- Generate unique human-readable order number
    v_order_number := 'ORD-MK-' || TO_CHAR(NOW(), 'YYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');

    -- 1. Create Lead in customer_leads table
    INSERT INTO public.customer_leads (
        client_id,
        marketer_id,
        form_id,
        customer_name,
        customer_phone,
        customer_phone_normalized,
        customer_address,
        delivery_state,
        delivery_lga,
        product_interest,
        package_interest,
        status,
        call_notes,
        utm_source,
        utm_medium,
        utm_campaign,
        ad_id,
        created_at,
        updated_at
    ) VALUES (
        v_client_id,
        v_marketer_id,
        v_form_id,
        v_customer_name,
        v_raw_customer_phone,
        v_customer_phone,
        v_delivery_address,
        v_delivery_state,
        v_delivery_lga,
        v_product_name,
        v_package_name,
        'new_lead',
        CASE WHEN v_notes != '' THEN 'Customer Note: ' || v_notes ELSE 'Marketing Landing Page Lead' END,
        v_utm_source,
        v_utm_medium,
        v_utm_campaign,
        v_ad_id,
        NOW(),
        NOW()
    ) RETURNING id INTO v_lead_id;

    -- 2. Create Order in orders table with company_id, package deal details, LGA, normalized phone, and pending closer confirmation
    INSERT INTO public.orders (
        order_number,
        client_id,
        company_id,
        product_id,
        product_name,
        product_sku,
        package_deal_name,
        package_deal_id,
        marketer_id,
        marketer_name,
        form_id,
        lead_id,
        customer_name,
        customer_phone,
        customer_phone_normalized,
        customer_alt_phone,
        customer_email,
        delivery_address,
        delivery_state,
        delivery_lga,
        lga,
        delivery_city,
        quantity,
        paid_quantity,
        free_quantity,
        total_amount,
        status,
        assignment_status,
        offer_package_id,
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        ad_id,
        delivery_notes,
        payment_method,
        is_pod,
        created_at,
        updated_at
    ) VALUES (
        v_order_number,
        v_client_id,
        v_company_id,
        v_product_id,
        v_product_name,
        v_product_sku,
        v_package_name,
        v_package_id,
        v_marketer_id,
        v_marketer_name,
        v_form_id,
        v_lead_id,
        v_customer_name,
        v_customer_phone,
        v_customer_phone,
        v_customer_alt_phone,
        v_customer_email,
        v_delivery_address,
        v_delivery_state,
        v_delivery_lga,
        v_delivery_lga,
        v_delivery_lga,
        v_buy_qty,
        v_paid_qty,
        v_free_qty,
        v_total_amount,
        'new',
        'pending_closer_confirmation',
        v_package_id,
        v_utm_source,
        v_utm_medium,
        v_utm_campaign,
        v_utm_content,
        v_ad_id,
        v_notes,
        'pay_on_delivery',
        true,
        NOW(),
        NOW()
    ) RETURNING id INTO v_order_id;

    -- 3. Execute Automatic Round-Robin Closer Assignment
    BEGIN
        SELECT closer_id, closer_name
        INTO v_assigned_closer_id, v_assigned_closer_name
        FROM public.fn_assign_order_to_product_closer(v_order_id);
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    -- 4. Update Form Statistics
    UPDATE public.lead_forms
    SET total_submissions = total_submissions + 1,
        total_orders_booked = total_orders_booked + 1,
        updated_at = NOW()
    WHERE id = v_form_id;

    -- 5. Update Marketer Aggregate Statistics
    IF v_marketer_id IS NOT NULL THEN
        UPDATE public.client_marketers
        SET total_leads_generated = total_leads_generated + 1,
            total_orders_generated = total_orders_generated + 1,
            updated_at = NOW()
        WHERE id = v_marketer_id;
    END IF;

    -- 6. Link Customer Lead to Order
    UPDATE public.customer_leads
    SET order_id = v_order_id,
        converted_to_order = true,
        status = 'order_created',
        updated_at = NOW()
    WHERE id = v_lead_id;

    -- 7. Return Result Payload
    RETURN jsonb_build_object(
        'is_duplicate', false,
        'order_id', v_order_id,
        'lead_id', v_lead_id,
        'order_number', v_order_number,
        'status', 'new',
        'customer_name', v_customer_name,
        'customer_phone', v_customer_phone,
        'package_deal_name', v_package_name,
        'quantity', v_buy_qty,
        'paid_quantity', v_paid_qty,
        'free_quantity', v_free_qty,
        'total_amount', v_total_amount,
        'delivery_state', v_delivery_state,
        'delivery_lga', v_delivery_lga,
        'closer_assigned', v_assigned_closer_name,
        'redirect_url', v_final_redirect,
        'message', 'Order successfully booked from marketing form'
    );
END;
$$;


-- =================== 20260928065000_add_total_orders_booked_to_lead_forms.sql ===================
-- Migration: Add total_orders_booked to lead_forms and use COALESCE in counter increments
-- Ensures lead_forms properly tracks order conversion count alongside submissions

ALTER TABLE public.lead_forms ADD COLUMN IF NOT EXISTS total_orders_booked INT DEFAULT 0;

CREATE OR REPLACE FUNCTION public.fn_submit_marketing_lead_order(p_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_form_id UUID;
    v_client_id UUID;
    v_company_id UUID;
    v_marketer_id UUID;
    v_marketer_name TEXT;
    v_product_id UUID;
    v_product_name TEXT;
    v_product_sku TEXT;
    v_product_price NUMERIC;
    v_customer_name TEXT;
    v_raw_customer_phone TEXT;
    v_customer_phone TEXT;
    v_customer_alt_phone TEXT;
    v_customer_email TEXT;
    v_delivery_address TEXT;
    v_delivery_state TEXT;
    v_delivery_lga TEXT;
    v_notes TEXT;
    v_package_id TEXT;
    v_package_name TEXT;
    v_paid_qty INT;
    v_free_qty INT;
    v_buy_qty INT;
    v_total_amount NUMERIC;
    v_redirect_url TEXT;
    v_utm_source TEXT;
    v_utm_medium TEXT;
    v_utm_campaign TEXT;
    v_utm_content TEXT;
    v_ad_id TEXT;
    v_order_id UUID;
    v_lead_id UUID;
    v_order_number TEXT;
    v_assigned_closer_id UUID;
    v_assigned_closer_name TEXT;
    v_final_redirect TEXT;

    -- Duplicate detection variables
    v_existing_order_id UUID;
    v_existing_order_number TEXT;
    v_existing_status TEXT;
    v_existing_amount NUMERIC;
    v_existing_package TEXT;
    v_existing_state TEXT;
    v_existing_lga TEXT;
    v_existing_created_at TIMESTAMPTZ;
BEGIN
    -- Parse & Sanitize Inputs
    v_form_id := (p_payload->>'form_id')::UUID;
    v_customer_name := TRIM(COALESCE(p_payload->>'customer_name', 'Valued Customer'));
    v_raw_customer_phone := TRIM(COALESCE(p_payload->>'customer_phone', ''));
    v_customer_phone := public.fn_normalize_nigerian_phone(v_raw_customer_phone);
    v_customer_alt_phone := TRIM(COALESCE(p_payload->>'customer_alt_phone', ''));
    v_customer_email := TRIM(COALESCE(p_payload->>'customer_email', ''));
    v_delivery_address := TRIM(COALESCE(p_payload->>'delivery_address', ''));
    v_delivery_state := TRIM(COALESCE(p_payload->>'delivery_state', 'Lagos'));
    v_delivery_lga := TRIM(COALESCE(p_payload->>'delivery_lga', p_payload->>'lga', p_payload->>'delivery_city', 'Ikeja'));
    v_notes := TRIM(COALESCE(p_payload->>'notes', ''));
    v_package_id := COALESCE(p_payload->>'package_deal_id', p_payload->>'package_id', 'pkg-1');
    v_package_name := COALESCE(p_payload->>'package_selected', p_payload->>'package_name', 'Standard Package');
    
    v_paid_qty := COALESCE((p_payload->>'paid_quantity')::INT, (p_payload->>'buy_qty')::INT, 1);
    v_free_qty := COALESCE((p_payload->>'free_quantity')::INT, 0);
    v_buy_qty := COALESCE((p_payload->>'package_quantity')::INT, (p_payload->>'buy_qty')::INT, (v_paid_qty + v_free_qty));
    v_total_amount := COALESCE((p_payload->>'order_amount')::NUMERIC, (p_payload->>'total_amount')::NUMERIC, 0.00);

    -- UTM attributes
    v_utm_source := p_payload->>'utm_source';
    v_utm_medium := p_payload->>'utm_medium';
    v_utm_campaign := p_payload->>'utm_campaign';
    v_utm_content := p_payload->>'utm_content';
    v_ad_id := p_payload->>'ad_id';

    -- Validation
    IF v_form_id IS NULL THEN
        RAISE EXCEPTION 'Form ID is strictly required to book lead order';
    END IF;

    IF v_customer_phone IS NULL OR LENGTH(v_customer_phone) < 10 THEN
        RAISE EXCEPTION 'A valid Nigerian phone number is required to book order';
    END IF;

    -- Lookup Lead Form attributes
    SELECT 
        client_id,
        marketer_id,
        product_id,
        product_name,
        redirect_url
    INTO 
        v_client_id,
        v_marketer_id,
        v_product_id,
        v_product_name,
        v_redirect_url
    FROM public.lead_forms
    WHERE id = v_form_id;

    IF v_client_id IS NULL THEN
        RAISE EXCEPTION 'Lead form with id % not found', v_form_id;
    END IF;

    -- Resolve company_id with safe fallback to client/company default
    SELECT COALESCE(c.company_id, '11111111-1111-4111-8111-111111111111'::UUID)
    INTO v_company_id
    FROM public.clients c
    WHERE c.id = v_client_id;

    IF v_company_id IS NULL THEN
        v_company_id := '11111111-1111-4111-8111-111111111111'::UUID;
    END IF;

    -- Lookup Marketer full name if assigned
    IF v_marketer_id IS NOT NULL THEN
        SELECT full_name INTO v_marketer_name
        FROM public.client_marketers
        WHERE id = v_marketer_id;
    END IF;

    -- Lookup Product details
    IF v_product_id IS NOT NULL THEN
        SELECT sku, base_price
        INTO v_product_sku, v_product_price
        FROM public.products
        WHERE id = v_product_id;
    END IF;

    -- Fallback calculations for total amount if not explicitly provided
    IF v_total_amount <= 0 AND v_product_price IS NOT NULL THEN
        v_total_amount := v_product_price * v_paid_qty;
    END IF;

    -- =========================================================================
    -- ANTI-DUPLICATE CHECK: Avoid duplicate orders and submissions from ads
    -- Check if an active order exists for this client & canonical normalized phone
    -- created within the last 48 hours.
    -- =========================================================================
    SELECT 
        id, 
        order_number, 
        status, 
        total_amount, 
        package_deal_name, 
        delivery_state, 
        delivery_lga,
        created_at
    INTO 
        v_existing_order_id, 
        v_existing_order_number, 
        v_existing_status, 
        v_existing_amount,
        v_existing_package,
        v_existing_state,
        v_existing_lga,
        v_existing_created_at
    FROM public.orders
    WHERE client_id = v_client_id
      AND customer_phone_normalized = v_customer_phone
      AND created_at >= NOW() - INTERVAL '48 hours'
      AND status NOT IN ('cancelled', 'failed')
    ORDER BY created_at DESC
    LIMIT 1;

    -- If duplicate is detected, log note and return existing order without creating new order
    IF v_existing_order_id IS NOT NULL THEN
        -- Also check or create a record in customer_leads noting duplicate submission
        INSERT INTO public.customer_leads (
            client_id,
            marketer_id,
            form_id,
            customer_name,
            customer_phone,
            customer_phone_normalized,
            customer_address,
            delivery_state,
            delivery_lga,
            product_interest,
            package_interest,
            status,
            call_notes,
            order_id,
            converted_to_order,
            utm_source,
            utm_medium,
            utm_campaign,
            ad_id,
            created_at,
            updated_at
        ) VALUES (
            v_client_id,
            v_marketer_id,
            v_form_id,
            v_customer_name,
            v_raw_customer_phone,
            v_customer_phone,
            v_delivery_address,
            v_delivery_state,
            v_delivery_lga,
            v_product_name,
            v_package_name,
            'duplicate_submission',
            'DUPLICATE ADS SUBMISSION PREVENTED: An active order already exists (' || v_existing_order_number || ') within 48h for this customer phone.',
            v_existing_order_id,
            false,
            v_utm_source,
            v_utm_medium,
            v_utm_campaign,
            v_ad_id,
            NOW(),
            NOW()
        );

        -- Build redirect URL with existing order number
        v_final_redirect := v_redirect_url;
        IF v_final_redirect != '' THEN
            IF v_final_redirect LIKE '%?%' THEN
                v_final_redirect := v_final_redirect || '&order_number=' || v_existing_order_number || '&is_duplicate=true';
            ELSE
                v_final_redirect := v_final_redirect || '?order_number=' || v_existing_order_number || '&is_duplicate=true';
            END IF;
        END IF;

        RETURN jsonb_build_object(
            'is_duplicate', true,
            'existing_order_id', v_existing_order_id,
            'order_number', v_existing_order_number,
            'status', v_existing_status,
            'customer_name', v_customer_name,
            'customer_phone', v_customer_phone,
            'package_deal_name', v_existing_package,
            'total_amount', v_existing_amount,
            'delivery_state', v_existing_state,
            'delivery_lga', v_existing_lga,
            'created_at', v_existing_created_at,
            'redirect_url', v_final_redirect,
            'message', 'An active order already exists for this phone number within 48 hours. Duplicate order creation prevented.'
        );
    END IF;

    -- =========================================================================
    -- CREATE NEW ORDER & LEAD: No duplicate detected
    -- =========================================================================
    
    -- Generate Human-Readable Order Number
    v_order_number := 'ORD-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 100000)::TEXT, 5, '0');

    -- Build Redirect URL if provided
    v_final_redirect := v_redirect_url;
    IF v_final_redirect != '' THEN
        IF v_final_redirect LIKE '%?%' THEN
            v_final_redirect := v_final_redirect || '&order_number=' || v_order_number;
        ELSE
            v_final_redirect := v_final_redirect || '?order_number=' || v_order_number;
        END IF;
    END IF;

    -- 1. Create Lead in customer_leads table
    INSERT INTO public.customer_leads (
        client_id,
        marketer_id,
        form_id,
        customer_name,
        customer_phone,
        customer_phone_normalized,
        customer_address,
        delivery_state,
        delivery_lga,
        product_interest,
        package_interest,
        status,
        call_notes,
        utm_source,
        utm_medium,
        utm_campaign,
        ad_id,
        created_at,
        updated_at
    ) VALUES (
        v_client_id,
        v_marketer_id,
        v_form_id,
        v_customer_name,
        v_raw_customer_phone,
        v_customer_phone,
        v_delivery_address,
        v_delivery_state,
        v_delivery_lga,
        v_product_name,
        v_package_name,
        'new_lead',
        CASE WHEN v_notes != '' THEN 'Customer Note: ' || v_notes ELSE 'Marketing Landing Page Lead' END,
        v_utm_source,
        v_utm_medium,
        v_utm_campaign,
        v_ad_id,
        NOW(),
        NOW()
    ) RETURNING id INTO v_lead_id;

    -- 2. Create Order in orders table with company_id, package deal details, LGA, normalized phone, and pending closer confirmation
    INSERT INTO public.orders (
        order_number,
        client_id,
        company_id,
        product_id,
        product_name,
        product_sku,
        package_deal_name,
        package_deal_id,
        marketer_id,
        marketer_name,
        form_id,
        lead_id,
        customer_name,
        customer_phone,
        customer_phone_normalized,
        customer_alt_phone,
        customer_email,
        delivery_address,
        delivery_state,
        delivery_lga,
        lga,
        delivery_city,
        quantity,
        paid_quantity,
        free_quantity,
        total_amount,
        status,
        assignment_status,
        offer_package_id,
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        ad_id,
        delivery_notes,
        payment_method,
        is_pod,
        created_at,
        updated_at
    ) VALUES (
        v_order_number,
        v_client_id,
        v_company_id,
        v_product_id,
        v_product_name,
        v_product_sku,
        v_package_name,
        v_package_id,
        v_marketer_id,
        v_marketer_name,
        v_form_id,
        v_lead_id,
        v_customer_name,
        v_customer_phone,
        v_customer_phone,
        v_customer_alt_phone,
        v_customer_email,
        v_delivery_address,
        v_delivery_state,
        v_delivery_lga,
        v_delivery_lga,
        v_delivery_lga,
        v_buy_qty,
        v_paid_qty,
        v_free_qty,
        v_total_amount,
        'new',
        'pending_closer_confirmation',
        v_package_id,
        v_utm_source,
        v_utm_medium,
        v_utm_campaign,
        v_utm_content,
        v_ad_id,
        v_notes,
        'pay_on_delivery',
        true,
        NOW(),
        NOW()
    ) RETURNING id INTO v_order_id;

    -- 3. Execute Automatic Round-Robin Closer Assignment
    BEGIN
        SELECT closer_id, closer_name
        INTO v_assigned_closer_id, v_assigned_closer_name
        FROM public.fn_assign_order_to_product_closer(v_order_id);
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    -- 4. Update Form Statistics
    UPDATE public.lead_forms
    SET total_submissions = COALESCE(total_submissions, 0) + 1,
        total_orders_booked = COALESCE(total_orders_booked, 0) + 1,
        updated_at = NOW()
    WHERE id = v_form_id;

    -- 5. Update Marketer Aggregate Statistics
    IF v_marketer_id IS NOT NULL THEN
        UPDATE public.client_marketers
        SET total_leads_generated = COALESCE(total_leads_generated, 0) + 1,
            total_orders_generated = COALESCE(total_orders_generated, 0) + 1,
            updated_at = NOW()
        WHERE id = v_marketer_id;
    END IF;

    -- 6. Link Customer Lead to Order
    UPDATE public.customer_leads
    SET order_id = v_order_id,
        converted_to_order = true,
        status = 'order_created',
        updated_at = NOW()
    WHERE id = v_lead_id;

    -- 7. Return Result Payload
    RETURN jsonb_build_object(
        'is_duplicate', false,
        'order_id', v_order_id,
        'lead_id', v_lead_id,
        'order_number', v_order_number,
        'status', 'new',
        'customer_name', v_customer_name,
        'customer_phone', v_customer_phone,
        'package_deal_name', v_package_name,
        'quantity', v_buy_qty,
        'paid_quantity', v_paid_qty,
        'free_quantity', v_free_qty,
        'total_amount', v_total_amount,
        'delivery_state', v_delivery_state,
        'delivery_lga', v_delivery_lga,
        'closer_assigned', v_assigned_closer_name,
        'redirect_url', v_final_redirect,
        'message', 'Order successfully booked from marketing form'
    );
END;
$$;


-- =================== 20260928070000_add_order_linkage_to_customer_leads.sql ===================
-- Migration: Add order_id and converted_to_order columns to customer_leads
-- Ensures complete bi-directional link between customer leads and generated orders

ALTER TABLE public.customer_leads 
  ADD COLUMN IF NOT EXISTS order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS converted_to_order BOOLEAN DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_customer_leads_order_id ON public.customer_leads(order_id);

CREATE OR REPLACE FUNCTION public.fn_submit_marketing_lead_order(p_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_form_id UUID;
    v_client_id UUID;
    v_company_id UUID;
    v_marketer_id UUID;
    v_marketer_name TEXT;
    v_product_id UUID;
    v_product_name TEXT;
    v_product_sku TEXT;
    v_product_price NUMERIC;
    v_customer_name TEXT;
    v_raw_customer_phone TEXT;
    v_customer_phone TEXT;
    v_customer_alt_phone TEXT;
    v_customer_email TEXT;
    v_delivery_address TEXT;
    v_delivery_state TEXT;
    v_delivery_lga TEXT;
    v_notes TEXT;
    v_package_id TEXT;
    v_package_name TEXT;
    v_paid_qty INT;
    v_free_qty INT;
    v_buy_qty INT;
    v_total_amount NUMERIC;
    v_redirect_url TEXT;
    v_utm_source TEXT;
    v_utm_medium TEXT;
    v_utm_campaign TEXT;
    v_utm_content TEXT;
    v_ad_id TEXT;
    v_order_id UUID;
    v_lead_id UUID;
    v_order_number TEXT;
    v_assigned_closer_id UUID;
    v_assigned_closer_name TEXT;
    v_final_redirect TEXT;

    -- Duplicate detection variables
    v_existing_order_id UUID;
    v_existing_order_number TEXT;
    v_existing_status TEXT;
    v_existing_amount NUMERIC;
    v_existing_package TEXT;
    v_existing_state TEXT;
    v_existing_lga TEXT;
    v_existing_created_at TIMESTAMPTZ;
BEGIN
    -- Parse & Sanitize Inputs
    v_form_id := (p_payload->>'form_id')::UUID;
    v_customer_name := TRIM(COALESCE(p_payload->>'customer_name', 'Valued Customer'));
    v_raw_customer_phone := TRIM(COALESCE(p_payload->>'customer_phone', ''));
    v_customer_phone := public.fn_normalize_nigerian_phone(v_raw_customer_phone);
    v_customer_alt_phone := TRIM(COALESCE(p_payload->>'customer_alt_phone', ''));
    v_customer_email := TRIM(COALESCE(p_payload->>'customer_email', ''));
    v_delivery_address := TRIM(COALESCE(p_payload->>'delivery_address', ''));
    v_delivery_state := TRIM(COALESCE(p_payload->>'delivery_state', 'Lagos'));
    v_delivery_lga := TRIM(COALESCE(p_payload->>'delivery_lga', p_payload->>'lga', p_payload->>'delivery_city', 'Ikeja'));
    v_notes := TRIM(COALESCE(p_payload->>'notes', ''));
    v_package_id := COALESCE(p_payload->>'package_deal_id', p_payload->>'package_id', 'pkg-1');
    v_package_name := COALESCE(p_payload->>'package_selected', p_payload->>'package_name', 'Standard Package');
    
    v_paid_qty := COALESCE((p_payload->>'paid_quantity')::INT, (p_payload->>'buy_qty')::INT, 1);
    v_free_qty := COALESCE((p_payload->>'free_quantity')::INT, 0);
    v_buy_qty := COALESCE((p_payload->>'package_quantity')::INT, (p_payload->>'buy_qty')::INT, (v_paid_qty + v_free_qty));
    v_total_amount := COALESCE((p_payload->>'order_amount')::NUMERIC, (p_payload->>'total_amount')::NUMERIC, 0.00);

    -- UTM attributes
    v_utm_source := p_payload->>'utm_source';
    v_utm_medium := p_payload->>'utm_medium';
    v_utm_campaign := p_payload->>'utm_campaign';
    v_utm_content := p_payload->>'utm_content';
    v_ad_id := p_payload->>'ad_id';

    -- Validation
    IF v_form_id IS NULL THEN
        RAISE EXCEPTION 'Form ID is strictly required to book lead order';
    END IF;

    IF v_customer_phone IS NULL OR LENGTH(v_customer_phone) < 10 THEN
        RAISE EXCEPTION 'A valid Nigerian phone number is required to book order';
    END IF;

    -- Lookup Lead Form attributes
    SELECT 
        client_id,
        marketer_id,
        product_id,
        product_name,
        redirect_url
    INTO 
        v_client_id,
        v_marketer_id,
        v_product_id,
        v_product_name,
        v_redirect_url
    FROM public.lead_forms
    WHERE id = v_form_id;

    IF v_client_id IS NULL THEN
        RAISE EXCEPTION 'Lead form with id % not found', v_form_id;
    END IF;

    -- Resolve company_id with safe fallback to client/company default
    SELECT COALESCE(c.company_id, '11111111-1111-4111-8111-111111111111'::UUID)
    INTO v_company_id
    FROM public.clients c
    WHERE c.id = v_client_id;

    IF v_company_id IS NULL THEN
        v_company_id := '11111111-1111-4111-8111-111111111111'::UUID;
    END IF;

    -- Lookup Marketer full name if assigned
    IF v_marketer_id IS NOT NULL THEN
        SELECT full_name INTO v_marketer_name
        FROM public.client_marketers
        WHERE id = v_marketer_id;
    END IF;

    -- Lookup Product details
    IF v_product_id IS NOT NULL THEN
        SELECT sku, base_price
        INTO v_product_sku, v_product_price
        FROM public.products
        WHERE id = v_product_id;
    END IF;

    -- Fallback calculations for total amount if not explicitly provided
    IF v_total_amount <= 0 AND v_product_price IS NOT NULL THEN
        v_total_amount := v_product_price * v_paid_qty;
    END IF;

    -- =========================================================================
    -- ANTI-DUPLICATE CHECK: Avoid duplicate orders and submissions from ads
    -- Check if an active order exists for this client & canonical normalized phone
    -- created within the last 48 hours.
    -- =========================================================================
    SELECT 
        id, 
        order_number, 
        status, 
        total_amount, 
        package_deal_name, 
        delivery_state, 
        delivery_lga,
        created_at
    INTO 
        v_existing_order_id, 
        v_existing_order_number, 
        v_existing_status, 
        v_existing_amount,
        v_existing_package,
        v_existing_state,
        v_existing_lga,
        v_existing_created_at
    FROM public.orders
    WHERE client_id = v_client_id
      AND customer_phone_normalized = v_customer_phone
      AND created_at >= NOW() - INTERVAL '48 hours'
      AND status NOT IN ('cancelled', 'failed')
    ORDER BY created_at DESC
    LIMIT 1;

    -- If duplicate is detected, log note and return existing order without creating new order
    IF v_existing_order_id IS NOT NULL THEN
        -- Also check or create a record in customer_leads noting duplicate submission
        INSERT INTO public.customer_leads (
            client_id,
            marketer_id,
            form_id,
            customer_name,
            customer_phone,
            customer_phone_normalized,
            customer_address,
            delivery_state,
            delivery_lga,
            product_interest,
            package_interest,
            status,
            call_notes,
            order_id,
            converted_order_id,
            converted_to_order,
            utm_source,
            utm_medium,
            utm_campaign,
            ad_id,
            created_at,
            updated_at
        ) VALUES (
            v_client_id,
            v_marketer_id,
            v_form_id,
            v_customer_name,
            v_raw_customer_phone,
            v_customer_phone,
            v_delivery_address,
            v_delivery_state,
            v_delivery_lga,
            v_product_name,
            v_package_name,
            'duplicate_submission',
            'DUPLICATE ADS SUBMISSION PREVENTED: An active order already exists (' || v_existing_order_number || ') within 48h for this customer phone.',
            v_existing_order_id,
            v_existing_order_id::TEXT,
            false,
            v_utm_source,
            v_utm_medium,
            v_utm_campaign,
            v_ad_id,
            NOW(),
            NOW()
        );

        -- Build redirect URL with existing order number
        v_final_redirect := v_redirect_url;
        IF v_final_redirect != '' THEN
            IF v_final_redirect LIKE '%?%' THEN
                v_final_redirect := v_final_redirect || '&order_number=' || v_existing_order_number || '&is_duplicate=true';
            ELSE
                v_final_redirect := v_final_redirect || '?order_number=' || v_existing_order_number || '&is_duplicate=true';
            END IF;
        END IF;

        RETURN jsonb_build_object(
            'is_duplicate', true,
            'existing_order_id', v_existing_order_id,
            'order_number', v_existing_order_number,
            'status', v_existing_status,
            'customer_name', v_customer_name,
            'customer_phone', v_customer_phone,
            'package_deal_name', v_existing_package,
            'total_amount', v_existing_amount,
            'delivery_state', v_existing_state,
            'delivery_lga', v_existing_lga,
            'created_at', v_existing_created_at,
            'redirect_url', v_final_redirect,
            'message', 'An active order already exists for this phone number within 48 hours. Duplicate order creation prevented.'
        );
    END IF;

    -- =========================================================================
    -- CREATE NEW ORDER & LEAD: No duplicate detected
    -- =========================================================================
    
    -- Generate Human-Readable Order Number
    v_order_number := 'ORD-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 100000)::TEXT, 5, '0');

    -- Build Redirect URL if provided
    v_final_redirect := v_redirect_url;
    IF v_final_redirect != '' THEN
        IF v_final_redirect LIKE '%?%' THEN
            v_final_redirect := v_final_redirect || '&order_number=' || v_order_number;
        ELSE
            v_final_redirect := v_final_redirect || '?order_number=' || v_order_number;
        END IF;
    END IF;

    -- 1. Create Lead in customer_leads table
    INSERT INTO public.customer_leads (
        client_id,
        marketer_id,
        form_id,
        customer_name,
        customer_phone,
        customer_phone_normalized,
        customer_address,
        delivery_state,
        delivery_lga,
        product_interest,
        package_interest,
        status,
        call_notes,
        utm_source,
        utm_medium,
        utm_campaign,
        ad_id,
        created_at,
        updated_at
    ) VALUES (
        v_client_id,
        v_marketer_id,
        v_form_id,
        v_customer_name,
        v_raw_customer_phone,
        v_customer_phone,
        v_delivery_address,
        v_delivery_state,
        v_delivery_lga,
        v_product_name,
        v_package_name,
        'new_lead',
        CASE WHEN v_notes != '' THEN 'Customer Note: ' || v_notes ELSE 'Marketing Landing Page Lead' END,
        v_utm_source,
        v_utm_medium,
        v_utm_campaign,
        v_ad_id,
        NOW(),
        NOW()
    ) RETURNING id INTO v_lead_id;

    -- 2. Create Order in orders table with company_id, package deal details, LGA, normalized phone, and pending closer confirmation
    INSERT INTO public.orders (
        order_number,
        client_id,
        company_id,
        product_id,
        product_name,
        product_sku,
        package_deal_name,
        package_deal_id,
        marketer_id,
        marketer_name,
        form_id,
        lead_id,
        customer_name,
        customer_phone,
        customer_phone_normalized,
        customer_alt_phone,
        customer_email,
        delivery_address,
        delivery_state,
        delivery_lga,
        lga,
        delivery_city,
        quantity,
        paid_quantity,
        free_quantity,
        total_amount,
        status,
        assignment_status,
        offer_package_id,
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        ad_id,
        delivery_notes,
        payment_method,
        is_pod,
        created_at,
        updated_at
    ) VALUES (
        v_order_number,
        v_client_id,
        v_company_id,
        v_product_id,
        v_product_name,
        v_product_sku,
        v_package_name,
        v_package_id,
        v_marketer_id,
        v_marketer_name,
        v_form_id,
        v_lead_id,
        v_customer_name,
        v_customer_phone,
        v_customer_phone,
        v_customer_alt_phone,
        v_customer_email,
        v_delivery_address,
        v_delivery_state,
        v_delivery_lga,
        v_delivery_lga,
        v_delivery_lga,
        v_buy_qty,
        v_paid_qty,
        v_free_qty,
        v_total_amount,
        'new',
        'pending_closer_confirmation',
        v_package_id,
        v_utm_source,
        v_utm_medium,
        v_utm_campaign,
        v_utm_content,
        v_ad_id,
        v_notes,
        'pay_on_delivery',
        true,
        NOW(),
        NOW()
    ) RETURNING id INTO v_order_id;

    -- 3. Execute Automatic Round-Robin Closer Assignment
    BEGIN
        SELECT closer_id, closer_name
        INTO v_assigned_closer_id, v_assigned_closer_name
        FROM public.fn_assign_order_to_product_closer(v_order_id);
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    -- 4. Update Form Statistics
    UPDATE public.lead_forms
    SET total_submissions = COALESCE(total_submissions, 0) + 1,
        total_orders_booked = COALESCE(total_orders_booked, 0) + 1,
        updated_at = NOW()
    WHERE id = v_form_id;

    -- 5. Update Marketer Aggregate Statistics
    IF v_marketer_id IS NOT NULL THEN
        UPDATE public.client_marketers
        SET total_leads_generated = COALESCE(total_leads_generated, 0) + 1,
            total_orders_generated = COALESCE(total_orders_generated, 0) + 1,
            updated_at = NOW()
        WHERE id = v_marketer_id;
    END IF;

    -- 6. Link Customer Lead to Order
    UPDATE public.customer_leads
    SET order_id = v_order_id,
        converted_order_id = v_order_id::TEXT,
        converted_to_order = true,
        status = 'order_created',
        updated_at = NOW()
    WHERE id = v_lead_id;

    -- 7. Return Result Payload
    RETURN jsonb_build_object(
        'is_duplicate', false,
        'order_id', v_order_id,
        'lead_id', v_lead_id,
        'order_number', v_order_number,
        'status', 'new',
        'customer_name', v_customer_name,
        'customer_phone', v_customer_phone,
        'package_deal_name', v_package_name,
        'quantity', v_buy_qty,
        'paid_quantity', v_paid_qty,
        'free_quantity', v_free_qty,
        'total_amount', v_total_amount,
        'delivery_state', v_delivery_state,
        'delivery_lga', v_delivery_lga,
        'closer_assigned', v_assigned_closer_name,
        'redirect_url', v_final_redirect,
        'message', 'Order successfully booked from marketing form'
    );
END;
$$;


-- =================== 20260928073000_closer_confirmation_and_lga_dc_routing.sql ===================
-- ============================================================================
-- Migration: 20260928073000_closer_confirmation_and_lga_dc_routing.sql
-- Description:
--   1. Ensures is_main_dc column exists on distribution_centers with Main DC designation.
--   2. Ensures confirmed_at, scheduled_delivery_date, cancellation_reason exist on orders.
--   3. Upgrades auto_dispatch_order_by_state_lga:
--      - Matches DC strictly by LGA in operating_zones.
--      - If no regional DC handles the LGA, automatically sends to Main DC.
--   4. Upgrades fn_confirm_closer_order:
--      - Supports editing address, LGA, state, customer contact, and package deal details.
--      - Supports deciding the next stage: 'confirm' (with auto DC routing),
--        'reschedule' (call back), or 'cancel' (reject with reason).
-- ============================================================================

-- 1. Extend distribution_centers with is_main_dc
ALTER TABLE public.distribution_centers
  ADD COLUMN IF NOT EXISTS is_main_dc BOOLEAN DEFAULT false;

-- Designate Grand DC / Hub as Main DC
UPDATE public.distribution_centers
SET is_main_dc = true
WHERE is_grand_dc = true OR is_hub = true OR code = 'DC-WUSE-01';

-- 2. Extend orders with closer decision columns
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS scheduled_delivery_date TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;

-- 3. Stored Procedure: auto_dispatch_order_by_state_lga
CREATE OR REPLACE FUNCTION public.auto_dispatch_order_by_state_lga(p_order_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order RECORD;
  v_state TEXT;
  v_lga TEXT;
  v_matched_dc RECORD;
  v_main_dc RECORD;
  v_matched_driver RECORD;
  v_is_fallback_to_main BOOLEAN := false;
BEGIN
  -- Fetch Order details
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Order not found');
  END IF;

  v_state := COALESCE(NULLIF(TRIM(v_order.delivery_state), ''), '');
  v_lga := COALESCE(NULLIF(TRIM(v_order.delivery_lga), ''), NULLIF(TRIM(v_order.lga), ''), NULLIF(TRIM(v_order.delivery_city), ''), '');

  -- Fetch Main DC (Fallback Hub for any LGA not covered by regional DCs)
  SELECT * INTO v_main_dc 
  FROM public.distribution_centers 
  WHERE is_active = true 
    AND (is_main_dc = true OR is_grand_dc = true OR is_primary_dc = true) 
  ORDER BY is_main_dc DESC, is_grand_dc DESC, is_primary_dc DESC, created_at ASC 
  LIMIT 1;

  IF v_main_dc IS NULL THEN
    SELECT * INTO v_main_dc 
    FROM public.distribution_centers 
    WHERE is_active = true AND is_hub = true 
    ORDER BY created_at ASC 
    LIMIT 1;
  END IF;

  IF v_main_dc IS NULL THEN
    SELECT * INTO v_main_dc 
    FROM public.distribution_centers 
    WHERE is_active = true 
    ORDER BY created_at ASC 
    LIMIT 1;
  END IF;

  -- 1. Check if the order already has an explicitly designated distribution_center_id
  IF v_order.distribution_center_id IS NOT NULL AND TRIM(v_order.distribution_center_id::text) <> '' THEN
    BEGIN
      SELECT * INTO v_matched_dc
      FROM public.distribution_centers
      WHERE id = v_order.distribution_center_id::uuid AND is_active = true
      LIMIT 1;
    EXCEPTION WHEN OTHERS THEN
      v_matched_dc := NULL;
    END;
  END IF;

  -- 2. Match Distribution Center strictly by LGA handling in operating_zones
  IF v_matched_dc IS NULL AND v_lga <> '' THEN
    SELECT * INTO v_matched_dc
    FROM public.distribution_centers
    WHERE is_active = true
      AND (
        operating_zones @> jsonb_build_array(v_lga)
        OR operating_zones ? v_lga
        OR EXISTS (
          SELECT 1 FROM jsonb_array_elements_text(operating_zones) z
          WHERE LOWER(TRIM(z)) = LOWER(TRIM(v_lga))
        )
      )
    ORDER BY 
      CASE WHEN LOWER(state) = LOWER(v_state) THEN 1 ELSE 2 END,
      is_hub DESC, 
      created_at ASC
    LIMIT 1;
  END IF;

  -- 3. If NO regional DC handles this LGA, automatically send to the Main DC!
  IF v_matched_dc IS NULL THEN
    v_matched_dc := v_main_dc;
    v_is_fallback_to_main := true;
  END IF;

  -- 4. Check for active on-duty rider covering this LGA attached to the matched DC
  SELECT * INTO v_matched_driver
  FROM public.delivery_agents
  WHERE is_active = true
    AND is_on_duty = true
    AND LOWER(current_status) IN ('available', 'active', 'on_duty')
    AND (distribution_center_id::text = v_matched_dc.id::text)
    AND (
      covered_lgas @> jsonb_build_array(v_lga)
      OR covered_lgas ? v_lga
      OR EXISTS (
        SELECT 1 FROM jsonb_array_elements_text(covered_lgas) z
        WHERE LOWER(TRIM(z)) = LOWER(TRIM(v_lga))
      )
      OR v_lga = ''
      OR jsonb_array_length(COALESCE(covered_lgas, '[]'::jsonb)) = 0
    )
  ORDER BY 
    CASE 
      WHEN (covered_lgas @> jsonb_build_array(v_lga) OR covered_lgas ? v_lga) THEN 1
      ELSE 2
    END,
    created_at ASC
  LIMIT 1;

  -- 5. Update Order with Matched DC and Rider Assignment
  IF v_matched_driver.id IS NOT NULL THEN
    UPDATE public.orders
    SET 
      distribution_center_id = v_matched_dc.id,
      delivery_agent_id = v_matched_driver.id,
      assigned_agent_id = v_matched_driver.id,
      status = 'assigned',
      assignment_status = 'auto_assigned',
      routing_notes = CASE 
        WHEN v_is_fallback_to_main THEN
          '🚨 Auto-routed to Main DC (' || v_matched_dc.name || ') as no regional DC covers LGA: "' || v_lga || '" (' || v_state || '). Assigned to Rider (' || v_matched_driver.agent_code || ').'
        ELSE
          '✅ Auto-assigned to Rider (' || v_matched_driver.agent_code || ') at DC [' || v_matched_dc.name || '] covering LGA: "' || v_lga || '".'
      END,
      assigned_at = NOW(),
      updated_at = NOW()
    WHERE id = p_order_id;

    -- Create in-app notification for the driver
    INSERT INTO public.notifications (
      company_id,
      delivery_agent_id,
      title,
      message,
      category,
      action_route,
      is_read,
      created_at
    ) VALUES (
      COALESCE(v_order.company_id, '11111111-1111-4111-8111-111111111111'),
      v_matched_driver.id,
      'New Order Auto-Assigned! 📦',
      'Order #' || v_order.order_number || ' (' || v_order.customer_name || ' in ' || COALESCE(v_order.delivery_city, v_lga) || ') assigned to your route.',
      'delivery',
      '/orders',
      false,
      NOW()
    );

    RETURN jsonb_build_object(
      'success', true,
      'status', 'auto_assigned',
      'is_fallback_to_main', v_is_fallback_to_main,
      'distribution_center_id', v_matched_dc.id,
      'distribution_center_name', v_matched_dc.name,
      'assigned_agent_id', v_matched_driver.id,
      'assigned_agent_code', v_matched_driver.agent_code,
      'message', 'Order auto-assigned to rider at covering DC.'
    );
  END IF;

  -- Fallback: DC matched / assigned, awaiting rider pickup
  UPDATE public.orders
  SET 
    distribution_center_id = v_matched_dc.id,
    delivery_agent_id = NULL,
    assigned_agent_id = NULL,
    status = 'confirmed',
    assignment_status = CASE WHEN v_is_fallback_to_main THEN 'assigned_to_main_dc' ELSE 'assigned_to_dc' END,
    routing_notes = CASE 
      WHEN v_is_fallback_to_main THEN
        '🚨 Auto-routed to Main DC (' || v_matched_dc.name || '): LGA [' || v_lga || '] (' || v_state || ') is not handled by any regional DC. Main DC will handle dispatch.'
      ELSE
        '✅ Routed to Regional DC [' || v_matched_dc.name || '] handling LGA: "' || v_lga || '". Awaiting rider assignment.'
    END,
    updated_at = NOW()
  WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'confirmed',
    'is_fallback_to_main', v_is_fallback_to_main,
    'distribution_center_id', v_matched_dc.id,
    'distribution_center_name', v_matched_dc.name,
    'assigned_agent_id', null,
    'message', CASE 
      WHEN v_is_fallback_to_main THEN 'LGA not covered by regional DC. Auto-routed to Main DC.' 
      ELSE 'Order routed to Regional DC handling LGA.' 
    END
  );
END;
$$;

-- 4. Stored Procedure: fn_confirm_closer_order with full edit & decision support
CREATE OR REPLACE FUNCTION public.fn_confirm_closer_order(
    p_order_id UUID,
    p_closer_id UUID,
    p_delivery_address TEXT DEFAULT NULL,
    p_delivery_state TEXT DEFAULT NULL,
    p_delivery_lga TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_action TEXT DEFAULT 'confirm',
    p_customer_name TEXT DEFAULT NULL,
    p_customer_phone TEXT DEFAULT NULL,
    p_customer_alt_phone TEXT DEFAULT NULL,
    p_package_deal_name TEXT DEFAULT NULL,
    p_package_deal_id TEXT DEFAULT NULL,
    p_quantity INT DEFAULT NULL,
    p_paid_quantity INT DEFAULT NULL,
    p_free_quantity INT DEFAULT NULL,
    p_total_amount NUMERIC DEFAULT NULL,
    p_scheduled_delivery_date TIMESTAMPTZ DEFAULT NULL,
    p_cancellation_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_order RECORD;
    v_dispatch_result JSONB;
    v_matched_dc_id UUID;
    v_matched_dc_name TEXT;
    v_assigned_agent_id UUID;
    v_assigned_agent_name TEXT;
    v_assigned_agent_phone TEXT;
    v_assigned_agent_code TEXT;
    v_is_main_dc BOOLEAN := false;
BEGIN
    -- 1. Fetch Order and verify existence
    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Order not found');
    END IF;

    -- =========================================================================
    -- ACTION: RESCHEDULE / CALL BACK
    -- =========================================================================
    IF LOWER(p_action) IN ('reschedule', 'call_back', 'rescheduled') THEN
        UPDATE public.orders
        SET 
            status = 'rescheduled',
            assignment_status = 'call_back_requested',
            scheduled_delivery_date = p_scheduled_delivery_date,
            delivery_notes = CASE 
                WHEN p_notes IS NOT NULL AND TRIM(p_notes) <> '' 
                THEN COALESCE(delivery_notes || E'\n[Closer Call Back]: ' || TRIM(p_notes), '[Closer Call Back]: ' || TRIM(p_notes))
                ELSE delivery_notes
            END,
            closer_id = COALESCE(p_closer_id, closer_id),
            updated_at = NOW()
        WHERE id = p_order_id;

        IF v_order.lead_id IS NOT NULL THEN
            UPDATE public.customer_leads
            SET status = 'call_back',
                call_notes = CASE 
                    WHEN p_notes IS NOT NULL AND TRIM(p_notes) <> '' 
                    THEN COALESCE(call_notes || E'\n[Call Back]: ' || TRIM(p_notes), '[Call Back]: ' || TRIM(p_notes))
                    ELSE call_notes
                END,
                last_called_at = NOW(),
                updated_at = NOW()
            WHERE id = v_order.lead_id;
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'action', 'reschedule',
            'order_id', p_order_id,
            'order_number', v_order.order_number,
            'status', 'rescheduled',
            'scheduled_delivery_date', p_scheduled_delivery_date,
            'message', 'Order marked for call back / rescheduled.'
        );
    END IF;

    -- =========================================================================
    -- ACTION: CANCEL / REJECT
    -- =========================================================================
    IF LOWER(p_action) IN ('cancel', 'reject', 'cancelled', 'rejected') THEN
        UPDATE public.orders
        SET 
            status = 'cancelled',
            assignment_status = 'cancelled_by_closer',
            cancellation_reason = COALESCE(p_cancellation_reason, p_notes, 'Customer declined on confirmation call'),
            delivery_notes = CASE 
                WHEN p_notes IS NOT NULL AND TRIM(p_notes) <> '' 
                THEN COALESCE(delivery_notes || E'\n[Closer Cancelled]: ' || TRIM(p_notes), '[Closer Cancelled]: ' || TRIM(p_notes))
                ELSE delivery_notes
            END,
            closer_id = COALESCE(p_closer_id, closer_id),
            updated_at = NOW()
        WHERE id = p_order_id;

        IF v_order.lead_id IS NOT NULL THEN
            UPDATE public.customer_leads
            SET status = 'rejected',
                call_notes = CASE 
                    WHEN p_notes IS NOT NULL AND TRIM(p_notes) <> '' 
                    THEN COALESCE(call_notes || E'\n[Rejected]: ' || TRIM(p_notes), '[Rejected]: ' || TRIM(p_notes))
                    ELSE call_notes
                END,
                last_called_at = NOW(),
                updated_at = NOW()
            WHERE id = v_order.lead_id;
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'action', 'cancel',
            'order_id', p_order_id,
            'order_number', v_order.order_number,
            'status', 'cancelled',
            'message', 'Order cancelled by sales closer.'
        );
    END IF;

    -- =========================================================================
    -- ACTION: CONFIRM & APPROVE (Auto-Route to DC Handling LGA / Main DC Fallback)
    -- =========================================================================
    UPDATE public.orders
    SET 
        customer_name = COALESCE(NULLIF(TRIM(p_customer_name), ''), customer_name),
        customer_phone = COALESCE(NULLIF(TRIM(p_customer_phone), ''), customer_phone),
        customer_phone_normalized = CASE 
            WHEN p_customer_phone IS NOT NULL AND TRIM(p_customer_phone) <> '' 
            THEN public.fn_normalize_nigerian_phone(p_customer_phone) 
            ELSE customer_phone_normalized 
        END,
        customer_alt_phone = COALESCE(NULLIF(TRIM(p_customer_alt_phone), ''), customer_alt_phone),
        delivery_address = COALESCE(NULLIF(TRIM(p_delivery_address), ''), delivery_address),
        delivery_state = COALESCE(NULLIF(TRIM(p_delivery_state), ''), delivery_state),
        delivery_lga = COALESCE(NULLIF(TRIM(p_delivery_lga), ''), delivery_lga),
        lga = COALESCE(NULLIF(TRIM(p_delivery_lga), ''), lga, delivery_lga),
        delivery_city = COALESCE(NULLIF(TRIM(p_delivery_lga), ''), delivery_city, delivery_lga),
        package_deal_name = COALESCE(NULLIF(TRIM(p_package_deal_name), ''), package_deal_name),
        package_deal_id = COALESCE(NULLIF(TRIM(p_package_deal_id), ''), package_deal_id),
        quantity = COALESCE(p_quantity, quantity),
        paid_quantity = COALESCE(p_paid_quantity, paid_quantity),
        free_quantity = COALESCE(p_free_quantity, free_quantity),
        total_amount = COALESCE(p_total_amount, total_amount),
        delivery_notes = CASE 
            WHEN p_notes IS NOT NULL AND TRIM(p_notes) <> '' 
            THEN COALESCE(delivery_notes || E'\n[Closer Confirmation]: ' || TRIM(p_notes), '[Closer Confirmation]: ' || TRIM(p_notes))
            ELSE delivery_notes
        END,
        closer_id = COALESCE(p_closer_id, closer_id),
        status = 'confirmed',
        confirmed_at = NOW(),
        updated_at = NOW()
    WHERE id = p_order_id;

    -- Execute LGA-based automatic DC and Rider dispatch
    v_dispatch_result := public.auto_dispatch_order_by_state_lga(p_order_id);

    -- Fetch refreshed routing state
    SELECT 
        o.distribution_center_id,
        dc.name AS dc_name,
        COALESCE(dc.is_main_dc, dc.is_grand_dc, false) AS is_main,
        o.delivery_agent_id,
        COALESCE(da.full_name, u.first_name || ' ' || u.last_name, da.agent_code, 'Rider') AS agent_name,
        COALESCE(u.phone_number, da.guarantor_phone, '') AS agent_phone,
        da.agent_code
    INTO 
        v_matched_dc_id,
        v_matched_dc_name,
        v_is_main_dc,
        v_assigned_agent_id,
        v_assigned_agent_name,
        v_assigned_agent_phone,
        v_assigned_agent_code
    FROM public.orders o
    LEFT JOIN public.distribution_centers dc ON dc.id = o.distribution_center_id
    LEFT JOIN public.delivery_agents da ON da.id = o.delivery_agent_id
    LEFT JOIN public.users u ON u.id = da.user_id
    WHERE o.id = p_order_id;

    -- Update Closer performance stats
    IF p_closer_id IS NOT NULL THEN
        UPDATE public.client_closers
        SET total_orders_booked = COALESCE(total_orders_booked, 0) + 1,
            total_leads_confirmed = COALESCE(total_leads_confirmed, 0) + 1,
            updated_at = NOW()
        WHERE id = p_closer_id;
    END IF;

    -- Update linked customer_lead
    IF v_order.lead_id IS NOT NULL THEN
        UPDATE public.customer_leads
        SET status = 'order_confirmed',
            call_notes = CASE 
                WHEN p_notes IS NOT NULL AND TRIM(p_notes) <> '' 
                THEN COALESCE(call_notes || E'\n[Confirmation]: ' || TRIM(p_notes), '[Confirmation]: ' || TRIM(p_notes))
                ELSE call_notes
            END,
            last_called_at = NOW(),
            updated_at = NOW()
        WHERE id = v_order.lead_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'action', 'confirm',
        'order_id', p_order_id,
        'order_number', v_order.order_number,
        'status', 'confirmed',
        'distribution_center_id', v_matched_dc_id,
        'distribution_center_name', v_matched_dc_name,
        'is_main_dc', COALESCE(v_is_main_dc, false),
        'delivery_agent_id', v_assigned_agent_id,
        'delivery_agent_name', v_assigned_agent_name,
        'delivery_agent_phone', v_assigned_agent_phone,
        'delivery_agent_code', v_assigned_agent_code,
        'dispatch_result', v_dispatch_result
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.auto_dispatch_order_by_state_lga(UUID) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_confirm_closer_order(UUID, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INT, INT, INT, NUMERIC, TIMESTAMPTZ, TEXT) TO authenticated, service_role, anon;

NOTIFY pgrst, 'reload schema';


-- =================== 20260928074000_patch_fn_confirm_closer_order_agent_columns.sql ===================
-- ============================================================================
-- Migration: 20260928074000_patch_fn_confirm_closer_order_agent_columns.sql
-- Description:
--   Fixes delivery_agents column resolution in fn_confirm_closer_order.
--   delivery_agents has full_name (not name) and phone via users table (phone_number).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_confirm_closer_order(
    p_order_id UUID,
    p_closer_id UUID,
    p_delivery_address TEXT DEFAULT NULL,
    p_delivery_state TEXT DEFAULT NULL,
    p_delivery_lga TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_action TEXT DEFAULT 'confirm',
    p_customer_name TEXT DEFAULT NULL,
    p_customer_phone TEXT DEFAULT NULL,
    p_customer_alt_phone TEXT DEFAULT NULL,
    p_package_deal_name TEXT DEFAULT NULL,
    p_package_deal_id TEXT DEFAULT NULL,
    p_quantity INT DEFAULT NULL,
    p_paid_quantity INT DEFAULT NULL,
    p_free_quantity INT DEFAULT NULL,
    p_total_amount NUMERIC DEFAULT NULL,
    p_scheduled_delivery_date TIMESTAMPTZ DEFAULT NULL,
    p_cancellation_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_order RECORD;
    v_closer RECORD;
    v_dispatch_result JSONB;
    v_matched_dc_id UUID;
    v_matched_dc_name TEXT;
    v_is_main_dc BOOLEAN;
    v_assigned_agent_id UUID;
    v_assigned_agent_name TEXT;
    v_assigned_agent_phone TEXT;
    v_assigned_agent_code TEXT;
    v_norm_phone TEXT;
    v_norm_alt_phone TEXT;
BEGIN
    -- 1. Fetch current order
    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Order not found: ' || p_order_id);
    END IF;

    -- Normalize phones if provided
    IF p_customer_phone IS NOT NULL AND TRIM(p_customer_phone) <> '' THEN
        v_norm_phone := public.fn_normalize_nigerian_phone(p_customer_phone);
    END IF;
    IF p_customer_alt_phone IS NOT NULL AND TRIM(p_customer_alt_phone) <> '' THEN
        v_norm_alt_phone := public.fn_normalize_nigerian_phone(p_customer_alt_phone);
    END IF;

    -- 2. BRANCH: Decision = 'reschedule' (Call Back requested by customer)
    IF LOWER(p_action) IN ('reschedule', 'call_back', 'callback') THEN
        UPDATE public.orders
        SET 
            customer_name = COALESCE(NULLIF(TRIM(p_customer_name), ''), customer_name),
            customer_phone = COALESCE(v_norm_phone, customer_phone),
            customer_alt_phone = COALESCE(v_norm_alt_phone, customer_alt_phone),
            delivery_address = COALESCE(NULLIF(TRIM(p_delivery_address), ''), delivery_address),
            delivery_state = COALESCE(NULLIF(TRIM(p_delivery_state), ''), delivery_state),
            delivery_city = COALESCE(NULLIF(TRIM(p_delivery_lga), ''), delivery_city),
            delivery_lga = COALESCE(NULLIF(TRIM(p_delivery_lga), ''), delivery_lga),
            lga = COALESCE(NULLIF(TRIM(p_delivery_lga), ''), lga),
            delivery_notes = CASE 
                WHEN p_notes IS NOT NULL AND TRIM(p_notes) <> '' 
                THEN COALESCE(delivery_notes || E'\n[Closer Reschedule]: ' || TRIM(p_notes), '[Closer Reschedule]: ' || TRIM(p_notes))
                ELSE delivery_notes 
            END,
            scheduled_delivery_date = COALESCE(p_scheduled_delivery_date, scheduled_delivery_date),
            status = 'rescheduled',
            assignment_status = 'pending_closer_callback',
            closer_id = COALESCE(p_closer_id, closer_id),
            updated_at = NOW()
        WHERE id = p_order_id;

        -- Update customer_leads state if linked
        IF v_order.lead_id IS NOT NULL THEN
            UPDATE public.customer_leads
            SET status = 'call_back',
                call_notes = CASE 
                    WHEN p_notes IS NOT NULL AND TRIM(p_notes) <> '' 
                    THEN COALESCE(call_notes || E'\n[Closer]: ' || TRIM(p_notes), '[Closer]: ' || TRIM(p_notes))
                    ELSE call_notes
                END,
                follow_up_date = COALESCE(p_scheduled_delivery_date, follow_up_date),
                last_called_at = NOW(),
                updated_at = NOW()
            WHERE id = v_order.lead_id;
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'action', 'reschedule',
            'order_id', p_order_id,
            'order_number', v_order.order_number,
            'status', 'rescheduled',
            'scheduled_delivery_date', p_scheduled_delivery_date,
            'message', 'Order scheduled for follow-up callback. Held from DC dispatch.'
        );
    END IF;

    -- 3. BRANCH: Decision = 'cancel' (Customer rejected / invalid order)
    IF LOWER(p_action) IN ('cancel', 'reject', 'rejected', 'cancelled') THEN
        UPDATE public.orders
        SET 
            status = 'cancelled',
            assignment_status = 'cancelled_by_closer',
            cancellation_reason = COALESCE(p_cancellation_reason, p_notes, 'Cancelled by Sales Closer'),
            delivery_notes = CASE 
                WHEN p_notes IS NOT NULL AND TRIM(p_notes) <> '' 
                THEN COALESCE(delivery_notes || E'\n[Closer Cancellation]: ' || TRIM(p_notes), '[Closer Cancellation]: ' || TRIM(p_notes))
                ELSE delivery_notes 
            END,
            closer_id = COALESCE(p_closer_id, closer_id),
            updated_at = NOW()
        WHERE id = p_order_id;

        -- Update customer_leads state if linked
        IF v_order.lead_id IS NOT NULL THEN
            UPDATE public.customer_leads
            SET status = 'rejected',
                call_notes = CASE 
                    WHEN p_notes IS NOT NULL AND TRIM(p_notes) <> '' 
                    THEN COALESCE(call_notes || E'\n[Rejected]: ' || TRIM(p_notes), '[Rejected]: ' || TRIM(p_notes))
                    ELSE call_notes
                END,
                last_called_at = NOW(),
                updated_at = NOW()
            WHERE id = v_order.lead_id;
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'action', 'cancel',
            'order_id', p_order_id,
            'order_number', v_order.order_number,
            'status', 'cancelled',
            'cancellation_reason', COALESCE(p_cancellation_reason, p_notes),
            'message', 'Order cancelled and closed. No DC dispatch.'
        );
    END IF;

    -- 4. BRANCH: Decision = 'confirm' (Approve & Dispatch to DC)
    -- Update order with customer contact, refined address/LGA, deal packages & closer confirmation
    UPDATE public.orders
    SET 
        customer_name = COALESCE(NULLIF(TRIM(p_customer_name), ''), customer_name),
        customer_phone = COALESCE(v_norm_phone, customer_phone),
        customer_phone_normalized = COALESCE(v_norm_phone, customer_phone_normalized, customer_phone),
        customer_alt_phone = COALESCE(v_norm_alt_phone, customer_alt_phone),
        delivery_address = COALESCE(NULLIF(TRIM(p_delivery_address), ''), delivery_address),
        delivery_state = COALESCE(NULLIF(TRIM(p_delivery_state), ''), delivery_state),
        delivery_city = COALESCE(NULLIF(TRIM(p_delivery_lga), ''), delivery_city),
        delivery_lga = COALESCE(NULLIF(TRIM(p_delivery_lga), ''), delivery_lga),
        lga = COALESCE(NULLIF(TRIM(p_delivery_lga), ''), lga),
        package_deal_name = COALESCE(NULLIF(TRIM(p_package_deal_name), ''), package_deal_name),
        package_deal_id = COALESCE(NULLIF(TRIM(p_package_deal_id), ''), package_deal_id),
        quantity = COALESCE(p_quantity, quantity),
        paid_quantity = COALESCE(p_paid_quantity, paid_quantity),
        free_quantity = COALESCE(p_free_quantity, free_quantity),
        total_amount = COALESCE(p_total_amount, total_amount),
        delivery_notes = CASE 
            WHEN p_notes IS NOT NULL AND TRIM(p_notes) <> '' 
            THEN COALESCE(delivery_notes || E'\n[Closer Confirmed]: ' || TRIM(p_notes), '[Closer Confirmed]: ' || TRIM(p_notes))
            ELSE delivery_notes 
        END,
        closer_id = COALESCE(p_closer_id, closer_id),
        status = 'confirmed',
        confirmed_at = NOW(),
        updated_at = NOW()
    WHERE id = p_order_id;

    -- Execute LGA-based automatic DC and Rider dispatch
    v_dispatch_result := public.auto_dispatch_order_by_state_lga(p_order_id);

    -- Fetch refreshed routing state
    SELECT 
        o.distribution_center_id,
        dc.name AS dc_name,
        COALESCE(dc.is_main_dc, dc.is_grand_dc, false) AS is_main,
        o.delivery_agent_id,
        COALESCE(da.full_name, u.first_name || ' ' || u.last_name, da.agent_code, 'Rider') AS agent_name,
        COALESCE(u.phone_number, da.guarantor_phone, '') AS agent_phone,
        da.agent_code
    INTO 
        v_matched_dc_id,
        v_matched_dc_name,
        v_is_main_dc,
        v_assigned_agent_id,
        v_assigned_agent_name,
        v_assigned_agent_phone,
        v_assigned_agent_code
    FROM public.orders o
    LEFT JOIN public.distribution_centers dc ON dc.id = o.distribution_center_id
    LEFT JOIN public.delivery_agents da ON da.id = o.delivery_agent_id
    LEFT JOIN public.users u ON u.id = da.user_id
    WHERE o.id = p_order_id;

    -- Update Closer performance stats
    IF p_closer_id IS NOT NULL THEN
        UPDATE public.client_closers
        SET total_orders_booked = COALESCE(total_orders_booked, 0) + 1,
            total_leads_confirmed = COALESCE(total_leads_confirmed, 0) + 1,
            updated_at = NOW()
        WHERE id = p_closer_id;
    END IF;

    -- Update linked customer_lead
    IF v_order.lead_id IS NOT NULL THEN
        UPDATE public.customer_leads
        SET status = 'order_confirmed',
            call_notes = CASE 
                WHEN p_notes IS NOT NULL AND TRIM(p_notes) <> '' 
                THEN COALESCE(call_notes || E'\n[Confirmation]: ' || TRIM(p_notes), '[Confirmation]: ' || TRIM(p_notes))
                ELSE call_notes
            END,
            last_called_at = NOW(),
            updated_at = NOW()
        WHERE id = v_order.lead_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'action', 'confirm',
        'order_id', p_order_id,
        'order_number', v_order.order_number,
        'status', 'confirmed',
        'distribution_center_id', v_matched_dc_id,
        'distribution_center_name', v_matched_dc_name,
        'is_main_dc', COALESCE(v_is_main_dc, false),
        'delivery_agent_id', v_assigned_agent_id,
        'delivery_agent_name', v_assigned_agent_name,
        'delivery_agent_phone', v_assigned_agent_phone,
        'delivery_agent_code', v_assigned_agent_code,
        'dispatch_result', v_dispatch_result
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_confirm_closer_order(UUID, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INT, INT, INT, NUMERIC, TIMESTAMPTZ, TEXT) TO authenticated, service_role, anon;

NOTIFY pgrst, 'reload schema';


-- =================== 20260928075000_enforce_lga_main_dc_routing_and_trigger_suppression.sql ===================
-- ============================================================================
-- Migration: 20260928075000_enforce_lga_main_dc_routing_and_trigger_suppression.sql
-- Description:
--   1. Ensures ONLY Wuse Grand Central is designated is_main_dc = true.
--   2. Updates trg_orders_auto_dispatch to suppress premature auto-dispatch for orders
--      awaiting closer confirmation (assignment_status = 'pending_closer_confirmation').
--   3. Upgrades auto_dispatch_order_by_state_lga:
--      - Re-evaluates DC based on latest order delivery_lga and delivery_state
--        (unless explicitly manually_assigned).
--      - If no regional DC handles the LGA, cleanly routes to Main DC (Wuse Grand Central)
--        with is_fallback_to_main = true and clear audit notes.
-- ============================================================================

-- 1. Correct is_main_dc flag: ONLY Grand DC / Wuse Central is Main DC
UPDATE public.distribution_centers
SET is_main_dc = (code = 'DC-WUSE-01' OR id = '22222222-2222-4222-8222-222222222222' OR is_grand_dc = true);

-- 2. Suppress auto-dispatch trigger for unconfirmed marketing leads
CREATE OR REPLACE FUNCTION public.trg_orders_auto_dispatch()
RETURNS TRIGGER AS $$
BEGIN
  -- If order is awaiting closer confirmation, DO NOT auto-dispatch yet!
  IF NEW.assignment_status = 'pending_closer_confirmation' 
     OR (NEW.closer_id IS NOT NULL AND NEW.status IN ('new', 'unconfirmed', 'contacting', 'pending')) THEN
    RETURN NEW;
  END IF;

  -- Auto-dispatch if no delivery agent is assigned and status is confirmed or pending dispatch
  IF COALESCE(NEW.delivery_agent_id, NEW.assigned_agent_id) IS NULL 
     AND (
       NEW.status = 'confirmed' 
       OR NEW.status = 'pending_dispatch'
       OR (NEW.closer_id IS NULL AND NEW.assignment_status != 'pending_closer_confirmation' AND NEW.status = 'pending')
     ) THEN
    PERFORM public.auto_dispatch_order_by_state_lga(NEW.id);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Upgraded auto_dispatch_order_by_state_lga
CREATE OR REPLACE FUNCTION public.auto_dispatch_order_by_state_lga(p_order_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order RECORD;
  v_state TEXT;
  v_lga TEXT;
  v_matched_dc RECORD;
  v_main_dc RECORD;
  v_matched_driver RECORD;
  v_is_fallback_to_main BOOLEAN := false;
BEGIN
  -- Fetch Order details
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Order not found');
  END IF;

  v_state := COALESCE(NULLIF(TRIM(v_order.delivery_state), ''), '');
  v_lga := COALESCE(NULLIF(TRIM(v_order.delivery_lga), ''), NULLIF(TRIM(v_order.lga), ''), NULLIF(TRIM(v_order.delivery_city), ''), '');

  -- Fetch Main DC (Grand Central Hub as designated fallback for uncovered LGAs)
  SELECT * INTO v_main_dc 
  FROM public.distribution_centers 
  WHERE is_active = true 
    AND (is_main_dc = true OR is_grand_dc = true OR code = 'DC-WUSE-01') 
  ORDER BY is_grand_dc DESC, is_main_dc DESC, created_at ASC 
  LIMIT 1;

  IF v_main_dc IS NULL THEN
    SELECT * INTO v_main_dc 
    FROM public.distribution_centers 
    WHERE is_active = true 
    ORDER BY is_hub DESC, created_at ASC 
    LIMIT 1;
  END IF;

  -- 1. Check if order was MANUALLY assigned by an admin to a specific DC
  IF v_order.assignment_status = 'manually_assigned' 
     AND v_order.distribution_center_id IS NOT NULL 
     AND TRIM(v_order.distribution_center_id::text) <> '' THEN
    BEGIN
      SELECT * INTO v_matched_dc
      FROM public.distribution_centers
      WHERE id = v_order.distribution_center_id::uuid AND is_active = true
      LIMIT 1;
    EXCEPTION WHEN OTHERS THEN
      v_matched_dc := NULL;
    END;
  END IF;

  -- 2. Match Distribution Center strictly by LGA handling in operating_zones
  IF v_matched_dc IS NULL AND v_lga <> '' THEN
    SELECT * INTO v_matched_dc
    FROM public.distribution_centers
    WHERE is_active = true
      AND (
        operating_zones @> jsonb_build_array(v_lga)
        OR operating_zones ? v_lga
        OR EXISTS (
          SELECT 1 FROM jsonb_array_elements_text(operating_zones) z
          WHERE LOWER(TRIM(z)) = LOWER(TRIM(v_lga))
        )
      )
    ORDER BY 
      CASE WHEN LOWER(state) = LOWER(v_state) THEN 1 ELSE 2 END,
      is_hub DESC, 
      created_at ASC
    LIMIT 1;
  END IF;

  -- 3. If NO regional DC handles this LGA, automatically send to the Main DC!
  IF v_matched_dc IS NULL THEN
    v_matched_dc := v_main_dc;
    v_is_fallback_to_main := true;
  END IF;

  -- 4. Check for active on-duty rider covering this LGA attached to the matched DC
  SELECT * INTO v_matched_driver
  FROM public.delivery_agents
  WHERE is_active = true
    AND is_on_duty = true
    AND LOWER(current_status) IN ('available', 'active', 'on_duty')
    AND (distribution_center_id::text = v_matched_dc.id::text)
    AND (
      covered_lgas @> jsonb_build_array(v_lga)
      OR covered_lgas ? v_lga
      OR EXISTS (
        SELECT 1 FROM jsonb_array_elements_text(covered_lgas) z
        WHERE LOWER(TRIM(z)) = LOWER(TRIM(v_lga))
      )
      OR v_lga = ''
      OR jsonb_array_length(COALESCE(covered_lgas, '[]'::jsonb)) = 0
    )
  ORDER BY 
    CASE 
      WHEN (covered_lgas @> jsonb_build_array(v_lga) OR covered_lgas ? v_lga) THEN 1
      ELSE 2
    END,
    created_at ASC
  LIMIT 1;

  -- 5. Update Order with Matched DC and Rider Assignment
  IF v_matched_driver.id IS NOT NULL THEN
    UPDATE public.orders
    SET 
      distribution_center_id = v_matched_dc.id,
      delivery_agent_id = v_matched_driver.id,
      assigned_agent_id = v_matched_driver.id,
      status = 'assigned',
      assignment_status = 'auto_assigned',
      routing_notes = CASE 
        WHEN v_is_fallback_to_main THEN
          '🚨 Auto-routed to Main DC (' || v_matched_dc.name || ') as no regional DC covers LGA: "' || v_lga || '" (' || v_state || '). Assigned to Rider (' || v_matched_driver.agent_code || ').'
        ELSE
          '✅ Auto-assigned to Rider (' || v_matched_driver.agent_code || ') at DC [' || v_matched_dc.name || '] covering LGA: "' || v_lga || '".'
      END,
      assigned_at = NOW(),
      updated_at = NOW()
    WHERE id = p_order_id;

    -- Create in-app notification for the driver
    INSERT INTO public.notifications (
      company_id,
      delivery_agent_id,
      title,
      message,
      category,
      action_route,
      is_read,
      created_at
    ) VALUES (
      COALESCE(v_order.company_id, '11111111-1111-4111-8111-111111111111'),
      v_matched_driver.id,
      'New Order Auto-Assigned! 📦',
      'Order #' || v_order.order_number || ' (' || v_order.customer_name || ' in ' || COALESCE(v_order.delivery_city, v_lga) || ') assigned to your route.',
      'delivery',
      '/orders',
      false,
      NOW()
    );

    RETURN jsonb_build_object(
      'success', true,
      'status', 'auto_assigned',
      'is_fallback_to_main', v_is_fallback_to_main,
      'distribution_center_id', v_matched_dc.id,
      'distribution_center_name', v_matched_dc.name,
      'assigned_agent_id', v_matched_driver.id,
      'assigned_agent_code', v_matched_driver.agent_code,
      'message', 'Order auto-assigned to rider at covering DC.'
    );
  END IF;

  -- Fallback: DC matched / assigned, awaiting rider pickup
  UPDATE public.orders
  SET 
    distribution_center_id = v_matched_dc.id,
    delivery_agent_id = NULL,
    assigned_agent_id = NULL,
    status = 'confirmed',
    assignment_status = CASE WHEN v_is_fallback_to_main THEN 'assigned_to_main_dc' ELSE 'assigned_to_dc' END,
    routing_notes = CASE 
      WHEN v_is_fallback_to_main THEN
        '🚨 Auto-routed to Main DC (' || v_matched_dc.name || '): LGA [' || v_lga || '] (' || v_state || ') is not handled by any regional DC. Main DC will handle dispatch.'
      ELSE
        '✅ Routed to Regional DC [' || v_matched_dc.name || '] handling LGA: "' || v_lga || '". Awaiting rider assignment.'
    END,
    updated_at = NOW()
  WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'confirmed',
    'is_fallback_to_main', v_is_fallback_to_main,
    'distribution_center_id', v_matched_dc.id,
    'distribution_center_name', v_matched_dc.name,
    'assigned_agent_id', null,
    'message', CASE 
      WHEN v_is_fallback_to_main THEN 'LGA not covered by regional DC. Auto-routed to Main DC.' 
      ELSE 'Order routed to Regional DC handling LGA.' 
    END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.auto_dispatch_order_by_state_lga(UUID) TO authenticated, service_role, anon;

NOTIFY pgrst, 'reload schema';


-- =================== 20260928080000_performance_optimization_gin_and_btree_indexes.sql ===================
-- ============================================================================
-- Migration: 20260928080000_performance_optimization_gin_and_btree_indexes.sql
-- Description:
--   Full System Audit Performance Optimizations:
--   1. GIN indexes on jsonb columns (operating_zones, covered_lgas) for ultra-fast
--      O(log N) LGA and zone matching in auto-dispatch.
--   2. B-Tree indexes on orders(assignment_status, lead_id, scheduled_delivery_date)
--      and customer_leads(converted_order_id).
--   3. Partial index on distribution_centers(is_main_dc, is_grand_dc) for instant hub resolution.
-- ============================================================================

-- 1. GIN Index on Distribution Centers operating_zones
CREATE INDEX IF NOT EXISTS idx_dc_operating_zones_gin 
  ON public.distribution_centers USING gin (operating_zones);

-- 2. GIN Index on Delivery Agents covered_lgas
CREATE INDEX IF NOT EXISTS idx_delivery_agents_covered_lgas_gin 
  ON public.delivery_agents USING gin (covered_lgas);

-- 3. B-Tree Index on Orders assignment_status for fast closer & DC query filters
CREATE INDEX IF NOT EXISTS idx_orders_assignment_status 
  ON public.orders (assignment_status);

-- 4. B-Tree Index on Orders lead_id for instant lead-order bidirectional resolution
CREATE INDEX IF NOT EXISTS idx_orders_lead_id 
  ON public.orders (lead_id);

-- 5. Partial B-Tree Index on Orders scheduled_delivery_date for closer reschedule calendars
CREATE INDEX IF NOT EXISTS idx_orders_scheduled_delivery_date 
  ON public.orders (scheduled_delivery_date) 
  WHERE scheduled_delivery_date IS NOT NULL;

-- 6. Partial B-Tree Index on Distribution Centers Main DC / Grand DC
CREATE INDEX IF NOT EXISTS idx_dc_is_main_dc 
  ON public.distribution_centers (is_main_dc) 
  WHERE is_main_dc = true;

-- 7. B-Tree Index on customer_leads converted_order_id
CREATE INDEX IF NOT EXISTS idx_customer_leads_converted_order_id 
  ON public.customer_leads (converted_order_id) 
  WHERE converted_order_id IS NOT NULL;

NOTIFY pgrst, 'reload schema';


-- =================== 20260928081500_harmonize_customer_leads_and_fn_confirm_closer_order.sql ===================
-- ============================================================================
-- Migration: 20260928081500_harmonize_customer_leads_and_fn_confirm_closer_order.sql
-- Description:
--   1. Ensures customer_leads has status, lead_status, follow_up_date, next_callback_at,
--      call_notes, notes, last_called_at, last_call_at synchronized.
--   2. Updates fn_confirm_closer_order to update both legacy and modern column names.
-- ============================================================================

-- 1. Harmonize customer_leads columns
ALTER TABLE public.customer_leads
  ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'new_lead',
  ADD COLUMN IF NOT EXISTS lead_status VARCHAR(50) DEFAULT 'new_lead',
  ADD COLUMN IF NOT EXISTS follow_up_date TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS next_callback_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS call_notes TEXT,
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS last_called_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_call_at TIMESTAMPTZ;

-- Sync any nulls
UPDATE public.customer_leads
SET status = COALESCE(status, lead_status, 'new_lead'),
    lead_status = COALESCE(lead_status, status, 'new_lead'),
    follow_up_date = COALESCE(follow_up_date, next_callback_at),
    next_callback_at = COALESCE(next_callback_at, follow_up_date),
    call_notes = COALESCE(call_notes, notes),
    notes = COALESCE(notes, call_notes);

-- 2. Update fn_confirm_closer_order with dual column synchronization
CREATE OR REPLACE FUNCTION public.fn_confirm_closer_order(
    p_order_id UUID,
    p_closer_id UUID,
    p_delivery_address TEXT DEFAULT NULL,
    p_delivery_state TEXT DEFAULT NULL,
    p_delivery_lga TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_action TEXT DEFAULT 'confirm',
    p_customer_name TEXT DEFAULT NULL,
    p_customer_phone TEXT DEFAULT NULL,
    p_customer_alt_phone TEXT DEFAULT NULL,
    p_package_deal_name TEXT DEFAULT NULL,
    p_package_deal_id TEXT DEFAULT NULL,
    p_quantity INT DEFAULT NULL,
    p_paid_quantity INT DEFAULT NULL,
    p_free_quantity INT DEFAULT NULL,
    p_total_amount NUMERIC DEFAULT NULL,
    p_scheduled_delivery_date TIMESTAMPTZ DEFAULT NULL,
    p_cancellation_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_order RECORD;
    v_dispatch_result JSONB;
    v_matched_dc_id UUID;
    v_matched_dc_name TEXT;
    v_is_main_dc BOOLEAN;
    v_assigned_agent_id UUID;
    v_assigned_agent_name TEXT;
    v_assigned_agent_phone TEXT;
    v_assigned_agent_code TEXT;
    v_norm_phone TEXT;
    v_norm_alt_phone TEXT;
BEGIN
    -- 1. Fetch current order
    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Order not found: ' || p_order_id);
    END IF;

    -- Normalize phones if provided
    IF p_customer_phone IS NOT NULL AND TRIM(p_customer_phone) <> '' THEN
        v_norm_phone := public.fn_normalize_nigerian_phone(p_customer_phone);
    END IF;
    IF p_customer_alt_phone IS NOT NULL AND TRIM(p_customer_alt_phone) <> '' THEN
        v_norm_alt_phone := public.fn_normalize_nigerian_phone(p_customer_alt_phone);
    END IF;

    -- 2. BRANCH: Decision = 'reschedule' (Call Back requested by customer)
    IF LOWER(p_action) IN ('reschedule', 'call_back', 'callback') THEN
        UPDATE public.orders
        SET 
            customer_name = COALESCE(NULLIF(TRIM(p_customer_name), ''), customer_name),
            customer_phone = COALESCE(v_norm_phone, customer_phone),
            customer_alt_phone = COALESCE(v_norm_alt_phone, customer_alt_phone),
            delivery_address = COALESCE(NULLIF(TRIM(p_delivery_address), ''), delivery_address),
            delivery_state = COALESCE(NULLIF(TRIM(p_delivery_state), ''), delivery_state),
            delivery_city = COALESCE(NULLIF(TRIM(p_delivery_lga), ''), delivery_city),
            delivery_lga = COALESCE(NULLIF(TRIM(p_delivery_lga), ''), delivery_lga),
            lga = COALESCE(NULLIF(TRIM(p_delivery_lga), ''), lga),
            delivery_notes = CASE 
                WHEN p_notes IS NOT NULL AND TRIM(p_notes) <> '' 
                THEN COALESCE(delivery_notes || E'\n[Closer Reschedule]: ' || TRIM(p_notes), '[Closer Reschedule]: ' || TRIM(p_notes))
                ELSE delivery_notes 
            END,
            scheduled_delivery_date = COALESCE(p_scheduled_delivery_date, scheduled_delivery_date),
            status = 'rescheduled',
            assignment_status = 'pending_closer_callback',
            closer_id = COALESCE(p_closer_id, closer_id),
            updated_at = NOW()
        WHERE id = p_order_id;

        -- Update customer_leads state if linked
        IF v_order.lead_id IS NOT NULL THEN
            UPDATE public.customer_leads
            SET status = 'call_back',
                lead_status = 'call_back',
                call_notes = CASE 
                    WHEN p_notes IS NOT NULL AND TRIM(p_notes) <> '' 
                    THEN COALESCE(call_notes || E'\n[Closer]: ' || TRIM(p_notes), '[Closer]: ' || TRIM(p_notes))
                    ELSE call_notes
                END,
                notes = CASE 
                    WHEN p_notes IS NOT NULL AND TRIM(p_notes) <> '' 
                    THEN COALESCE(notes || E'\n[Closer]: ' || TRIM(p_notes), '[Closer]: ' || TRIM(p_notes))
                    ELSE notes
                END,
                follow_up_date = COALESCE(p_scheduled_delivery_date, follow_up_date),
                next_callback_at = COALESCE(p_scheduled_delivery_date, next_callback_at),
                last_called_at = NOW(),
                last_call_at = NOW(),
                updated_at = NOW()
            WHERE id = v_order.lead_id;
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'action', 'reschedule',
            'order_id', p_order_id,
            'order_number', v_order.order_number,
            'status', 'rescheduled',
            'scheduled_delivery_date', p_scheduled_delivery_date,
            'message', 'Order scheduled for follow-up callback. Held from DC dispatch.'
        );
    END IF;

    -- 3. BRANCH: Decision = 'cancel' (Customer rejected / invalid order)
    IF LOWER(p_action) IN ('cancel', 'reject', 'rejected', 'cancelled') THEN
        UPDATE public.orders
        SET 
            status = 'cancelled',
            assignment_status = 'cancelled_by_closer',
            cancellation_reason = COALESCE(p_cancellation_reason, p_notes, 'Cancelled by Sales Closer'),
            delivery_notes = CASE 
                WHEN p_notes IS NOT NULL AND TRIM(p_notes) <> '' 
                THEN COALESCE(delivery_notes || E'\n[Closer Cancellation]: ' || TRIM(p_notes), '[Closer Cancellation]: ' || TRIM(p_notes))
                ELSE delivery_notes 
            END,
            closer_id = COALESCE(p_closer_id, closer_id),
            updated_at = NOW()
        WHERE id = p_order_id;

        -- Update customer_leads state if linked
        IF v_order.lead_id IS NOT NULL THEN
            UPDATE public.customer_leads
            SET status = 'rejected',
                lead_status = 'rejected',
                call_notes = CASE 
                    WHEN p_notes IS NOT NULL AND TRIM(p_notes) <> '' 
                    THEN COALESCE(call_notes || E'\n[Rejected]: ' || TRIM(p_notes), '[Rejected]: ' || TRIM(p_notes))
                    ELSE call_notes
                END,
                notes = CASE 
                    WHEN p_notes IS NOT NULL AND TRIM(p_notes) <> '' 
                    THEN COALESCE(notes || E'\n[Rejected]: ' || TRIM(p_notes), '[Rejected]: ' || TRIM(p_notes))
                    ELSE notes
                END,
                last_called_at = NOW(),
                last_call_at = NOW(),
                updated_at = NOW()
            WHERE id = v_order.lead_id;
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'action', 'cancel',
            'order_id', p_order_id,
            'order_number', v_order.order_number,
            'status', 'cancelled',
            'cancellation_reason', COALESCE(p_cancellation_reason, p_notes),
            'message', 'Order cancelled and closed. No DC dispatch.'
        );
    END IF;

    -- 4. BRANCH: Decision = 'confirm' (Approve & Dispatch to DC)
    -- Update order with customer contact, refined address/LGA, deal packages & closer confirmation
    UPDATE public.orders
    SET 
        customer_name = COALESCE(NULLIF(TRIM(p_customer_name), ''), customer_name),
        customer_phone = COALESCE(v_norm_phone, customer_phone),
        customer_phone_normalized = COALESCE(v_norm_phone, customer_phone_normalized, customer_phone),
        customer_alt_phone = COALESCE(v_norm_alt_phone, customer_alt_phone),
        delivery_address = COALESCE(NULLIF(TRIM(p_delivery_address), ''), delivery_address),
        delivery_state = COALESCE(NULLIF(TRIM(p_delivery_state), ''), delivery_state),
        delivery_city = COALESCE(NULLIF(TRIM(p_delivery_lga), ''), delivery_city),
        delivery_lga = COALESCE(NULLIF(TRIM(p_delivery_lga), ''), delivery_lga),
        lga = COALESCE(NULLIF(TRIM(p_delivery_lga), ''), lga),
        package_deal_name = COALESCE(NULLIF(TRIM(p_package_deal_name), ''), package_deal_name),
        package_deal_id = COALESCE(NULLIF(TRIM(p_package_deal_id), ''), package_deal_id),
        quantity = COALESCE(p_quantity, quantity),
        paid_quantity = COALESCE(p_paid_quantity, paid_quantity),
        free_quantity = COALESCE(p_free_quantity, free_quantity),
        total_amount = COALESCE(p_total_amount, total_amount),
        delivery_notes = CASE 
            WHEN p_notes IS NOT NULL AND TRIM(p_notes) <> '' 
            THEN COALESCE(delivery_notes || E'\n[Closer Confirmed]: ' || TRIM(p_notes), '[Closer Confirmed]: ' || TRIM(p_notes))
            ELSE delivery_notes 
        END,
        closer_id = COALESCE(p_closer_id, closer_id),
        status = 'confirmed',
        confirmed_at = NOW(),
        updated_at = NOW()
    WHERE id = p_order_id;

    -- Execute LGA-based automatic DC and Rider dispatch
    v_dispatch_result := public.auto_dispatch_order_by_state_lga(p_order_id);

    -- Fetch refreshed routing state
    SELECT 
        o.distribution_center_id,
        dc.name AS dc_name,
        COALESCE(dc.is_main_dc, dc.is_grand_dc, false) AS is_main,
        o.delivery_agent_id,
        COALESCE(da.full_name, u.first_name || ' ' || u.last_name, da.agent_code, 'Rider') AS agent_name,
        COALESCE(u.phone_number, da.guarantor_phone, '') AS agent_phone,
        da.agent_code
    INTO 
        v_matched_dc_id,
        v_matched_dc_name,
        v_is_main_dc,
        v_assigned_agent_id,
        v_assigned_agent_name,
        v_assigned_agent_phone,
        v_assigned_agent_code
    FROM public.orders o
    LEFT JOIN public.distribution_centers dc ON dc.id = o.distribution_center_id
    LEFT JOIN public.delivery_agents da ON da.id = o.delivery_agent_id
    LEFT JOIN public.users u ON u.id = da.user_id
    WHERE o.id = p_order_id;

    -- Update Closer performance stats
    IF p_closer_id IS NOT NULL THEN
        UPDATE public.client_closers
        SET total_orders_booked = COALESCE(total_orders_booked, 0) + 1,
            total_leads_confirmed = COALESCE(total_leads_confirmed, 0) + 1,
            updated_at = NOW()
        WHERE id = p_closer_id;
    END IF;

    -- Update linked customer_lead
    IF v_order.lead_id IS NOT NULL THEN
        UPDATE public.customer_leads
        SET status = 'order_confirmed',
            lead_status = 'order_confirmed',
            call_notes = CASE 
                WHEN p_notes IS NOT NULL AND TRIM(p_notes) <> '' 
                THEN COALESCE(call_notes || E'\n[Confirmation]: ' || TRIM(p_notes), '[Confirmation]: ' || TRIM(p_notes))
                ELSE call_notes
            END,
            notes = CASE 
                WHEN p_notes IS NOT NULL AND TRIM(p_notes) <> '' 
                THEN COALESCE(notes || E'\n[Confirmation]: ' || TRIM(p_notes), '[Confirmation]: ' || TRIM(p_notes))
                ELSE notes
            END,
            last_called_at = NOW(),
            last_call_at = NOW(),
            updated_at = NOW()
        WHERE id = v_order.lead_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'action', 'confirm',
        'order_id', p_order_id,
        'order_number', v_order.order_number,
        'status', 'confirmed',
        'distribution_center_id', v_matched_dc_id,
        'distribution_center_name', v_matched_dc_name,
        'is_main_dc', COALESCE(v_is_main_dc, false),
        'delivery_agent_id', v_assigned_agent_id,
        'delivery_agent_name', v_assigned_agent_name,
        'delivery_agent_phone', v_assigned_agent_phone,
        'delivery_agent_code', v_assigned_agent_code,
        'dispatch_result', v_dispatch_result
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_confirm_closer_order(UUID, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INT, INT, INT, NUMERIC, TIMESTAMPTZ, TEXT) TO authenticated, service_role, anon;

NOTIFY pgrst, 'reload schema';


-- =================== 20260928090000_marketer_delivery_lifecycle_and_commission_trigger.sql ===================
-- ============================================================================
-- Migration: 20260928090000_marketer_delivery_lifecycle_and_commission_trigger.sql
-- Description:
--   Digital Marketer End-to-End Lifecycle Automation:
--   1. Ensures lead_forms has total_orders_delivered tracking column.
--   2. Automates Marketer Delivery Commission & Stats when orders reach 'delivered':
--      - Increments client_marketers.total_orders_delivered.
--      - Automatically credits total_commission_earned when commission_type = 'per_delivered_order'.
--      - Increments lead_forms.total_orders_delivered.
--      - Dispatches realtime in-app notification to the Digital Marketer.
--      - Broadcasts verified POD delivery milestone into order_conversations pipeline chat.
-- ============================================================================

-- 1. Extend lead_forms with total_orders_delivered column
ALTER TABLE public.lead_forms
  ADD COLUMN IF NOT EXISTS total_orders_delivered INT DEFAULT 0;

-- 2. Stored Procedure for Order Delivery Marketer Lifecycle
CREATE OR REPLACE FUNCTION public.fn_handle_order_delivery_marketer_lifecycle()
RETURNS TRIGGER AS $$
DECLARE
    v_marketer RECORD;
    v_commission_amount NUMERIC := 0.00;
    v_form RECORD;
BEGIN
    -- Only fire when status transitions to 'delivered' or 'completed'
    IF (OLD.status IS DISTINCT FROM NEW.status) AND (LOWER(NEW.status) IN ('delivered', 'completed')) THEN
        
        -- A. If order has an attached Digital Marketer
        IF NEW.marketer_id IS NOT NULL THEN
            SELECT * INTO v_marketer FROM public.client_marketers WHERE id = NEW.marketer_id;
            
            IF v_marketer.id IS NOT NULL THEN
                -- Compute delivery commission if model is per_delivered_order
                IF v_marketer.commission_type = 'per_delivered_order' OR COALESCE(v_marketer.commission_per_delivered_order, 0) > 0 THEN
                    v_commission_amount := COALESCE(NULLIF(v_marketer.commission_per_delivered_order, 0), NULLIF(v_marketer.commission_rate, 0), 2000.00);
                END IF;

                -- Update marketer performance stats & earned balance
                UPDATE public.client_marketers
                SET total_orders_delivered = COALESCE(total_orders_delivered, 0) + 1,
                    total_commission_earned = COALESCE(total_commission_earned, 0) + v_commission_amount,
                    updated_at = NOW()
                WHERE id = v_marketer.id;

                -- Update linked lead_form delivery count if form_id is present
                IF NEW.form_id IS NOT NULL THEN
                    UPDATE public.lead_forms
                    SET total_orders_delivered = COALESCE(total_orders_delivered, 0) + 1,
                        updated_at = NOW()
                    WHERE id = NEW.form_id;
                END IF;

                -- Send in-app push notification to the marketer
                IF v_marketer.user_id IS NOT NULL THEN
                    INSERT INTO public.notifications (
                        company_id,
                        user_id,
                        title,
                        message,
                        category,
                        action_route,
                        is_read,
                        created_at
                    ) VALUES (
                        COALESCE(NEW.client_id, '11111111-1111-4111-8111-111111111111'),
                        v_marketer.user_id,
                        'Buyer Received Delivery! 📦🎉',
                        'Ad Order #' || NEW.order_number || ' (' || NEW.customer_name || ' in ' || COALESCE(NEW.delivery_lga, NEW.delivery_city, 'LGA') || ') was delivered and confirmed by rider.' ||
                        CASE WHEN v_commission_amount > 0 THEN ' Commission of ₦' || v_commission_amount || ' credited.' ELSE '' END,
                        'marketing',
                        '/marketing',
                        false,
                        NOW()
                    );
                END IF;
            END IF;
        END IF;

        -- B. Post Lifecycle Milestone message into Pipeline Chat
        BEGIN
            PERFORM public.fn_sync_order_conversation(
                NEW.id,
                'System Notification',
                'system',
                '✅ Package Delivered & Received: Order #' || NEW.order_number || ' (' || NEW.product_name || ') has been successfully delivered to customer with verified POD.',
                NULL
            );
        EXCEPTION WHEN OTHERS THEN
            NULL; -- Non-blocking for conversation chat sync
        END;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Bind Trigger to public.orders
DROP TRIGGER IF EXISTS trg_orders_marketer_delivery_lifecycle ON public.orders;
CREATE TRIGGER trg_orders_marketer_delivery_lifecycle
    AFTER UPDATE OF status ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_handle_order_delivery_marketer_lifecycle();

NOTIFY pgrst, 'reload schema';


-- =================== 20260928091500_harmonize_marketer_commission_and_stats.sql ===================
-- ============================================================================
-- Migration: 20260928091500_harmonize_marketer_commission_and_stats.sql
-- Description:
--   1. Ensures client_marketers has both commission_type and commission_model
--      fully synchronized and accessible to client SDKs.
--   2. Ensures total_commission_earned column exists on client_marketers.
--   3. Synchronizes commission_type and commission_model via trigger.
-- ============================================================================

-- 1. Ensure columns exist on client_marketers
ALTER TABLE public.client_marketers
  ADD COLUMN IF NOT EXISTS commission_type VARCHAR(50) DEFAULT 'per_form_submission',
  ADD COLUMN IF NOT EXISTS commission_model VARCHAR(50) DEFAULT 'per_form_submission',
  ADD COLUMN IF NOT EXISTS total_commission_earned NUMERIC(14,2) DEFAULT 0.00;

-- 2. Populate and cross-fill existing records
UPDATE public.client_marketers
SET commission_type = COALESCE(commission_type, commission_model, 'per_form_submission'),
    commission_model = COALESCE(commission_model, commission_type, 'per_form_submission'),
    total_commission_earned = COALESCE(total_commission_earned, 0.00);

-- 3. Trigger to keep commission_type and commission_model automatically in sync
CREATE OR REPLACE FUNCTION public.fn_sync_client_marketer_commission_columns()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.commission_type IS NOT NULL AND NEW.commission_model IS NULL THEN
        NEW.commission_model := NEW.commission_type;
    ELSIF NEW.commission_model IS NOT NULL AND NEW.commission_type IS NULL THEN
        NEW.commission_type := NEW.commission_model;
    ELSIF NEW.commission_type IS NOT NULL AND NEW.commission_type IS DISTINCT FROM OLD.commission_type THEN
        NEW.commission_model := NEW.commission_type;
    ELSIF NEW.commission_model IS NOT NULL AND NEW.commission_model IS DISTINCT FROM OLD.commission_model THEN
        NEW.commission_type := NEW.commission_model;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_client_marketer_commission ON public.client_marketers;
CREATE TRIGGER trg_sync_client_marketer_commission
    BEFORE INSERT OR UPDATE ON public.client_marketers
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_sync_client_marketer_commission_columns();

-- 4. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';


-- =================== 20260928093000_marketer_payouts_and_detail_management.sql ===================
-- ============================================================================
-- Migration: 20260928093000_marketer_payouts_and_detail_management.sql
-- Description:
--   1. Extends client_marketers with unpaid_commission_balance and total_paid_commission.
--   2. Updates fn_handle_order_delivery_marketer_lifecycle to accrue unpaid_commission_balance.
--   3. Creates public.marketer_payouts table for commission disbursements.
--   4. Creates stored procedure fn_disburse_marketer_payout.
--   5. Creates stored procedure fn_delete_marketer.
--   6. Configures Realtime sockets publication for marketer_payouts.
-- ============================================================================

-- 1. Extend client_marketers with commission balance columns
ALTER TABLE public.client_marketers
  ADD COLUMN IF NOT EXISTS unpaid_commission_balance NUMERIC(14,2) DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS total_paid_commission NUMERIC(14,2) DEFAULT 0.00;

-- Backfill existing balances
UPDATE public.client_marketers
SET unpaid_commission_balance = GREATEST(0.00, COALESCE(total_commission_earned, 0.00) - COALESCE(total_paid_commission, 0.00)),
    total_paid_commission = COALESCE(total_paid_commission, 0.00);

-- 2. Update fn_handle_order_delivery_marketer_lifecycle to update unpaid_commission_balance
CREATE OR REPLACE FUNCTION public.fn_handle_order_delivery_marketer_lifecycle()
RETURNS TRIGGER AS $$
DECLARE
    v_marketer RECORD;
    v_commission_amount NUMERIC := 0.00;
    v_form RECORD;
BEGIN
    -- Only fire when status transitions to 'delivered' or 'completed'
    IF (OLD.status IS DISTINCT FROM NEW.status) AND (LOWER(NEW.status) IN ('delivered', 'completed')) THEN
        
        -- A. If order has an attached Digital Marketer
        IF NEW.marketer_id IS NOT NULL THEN
            SELECT * INTO v_marketer FROM public.client_marketers WHERE id = NEW.marketer_id;
            
            IF v_marketer.id IS NOT NULL THEN
                -- Compute delivery commission if model is per_delivered_order
                IF COALESCE(v_marketer.commission_type, v_marketer.commission_model) = 'per_delivered_order' OR COALESCE(v_marketer.commission_per_delivered_order, 0) > 0 THEN
                    v_commission_amount := COALESCE(NULLIF(v_marketer.commission_per_delivered_order, 0), NULLIF(v_marketer.commission_rate, 0), 2000.00);
                END IF;

                -- Update marketer performance stats & earned balance
                UPDATE public.client_marketers
                SET total_orders_delivered = COALESCE(total_orders_delivered, 0) + 1,
                    total_commission_earned = COALESCE(total_commission_earned, 0) + v_commission_amount,
                    unpaid_commission_balance = COALESCE(unpaid_commission_balance, 0) + v_commission_amount,
                    updated_at = NOW()
                WHERE id = v_marketer.id;

                -- Update linked lead_form delivery count if form_id is present
                IF NEW.form_id IS NOT NULL THEN
                    UPDATE public.lead_forms
                    SET total_orders_delivered = COALESCE(total_orders_delivered, 0) + 1,
                        updated_at = NOW()
                    WHERE id = NEW.form_id;
                END IF;

                -- Send in-app push notification to the marketer
                IF v_marketer.user_id IS NOT NULL THEN
                    INSERT INTO public.notifications (
                        company_id,
                        user_id,
                        title,
                        message,
                        category,
                        action_route,
                        is_read,
                        created_at
                    ) VALUES (
                        COALESCE(NEW.client_id, '11111111-1111-4111-8111-111111111111'),
                        v_marketer.user_id,
                        'Buyer Received Delivery! 📦🎉',
                        'Ad Order #' || NEW.order_number || ' (' || NEW.customer_name || ' in ' || COALESCE(NEW.delivery_lga, NEW.delivery_city, 'LGA') || ') was delivered and confirmed by rider.' ||
                        CASE WHEN v_commission_amount > 0 THEN ' Commission of ₦' || v_commission_amount || ' credited.' ELSE '' END,
                        'marketing',
                        '/marketing',
                        false,
                        NOW()
                    );
                END IF;
            END IF;
        END IF;

        -- B. Post Lifecycle Milestone message into Pipeline Chat
        BEGIN
            PERFORM public.fn_sync_order_conversation(
                NEW.id,
                'System Notification',
                'system',
                '✅ Package Delivered & Received: Order #' || NEW.order_number || ' (' || NEW.product_name || ') has been successfully delivered to customer with verified POD.',
                NULL
            );
        EXCEPTION WHEN OTHERS THEN
            NULL; -- Non-blocking for conversation chat sync
        END;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create public.marketer_payouts Table
CREATE TABLE IF NOT EXISTS public.marketer_payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    marketer_id UUID NOT NULL REFERENCES public.client_marketers(id) ON DELETE CASCADE,
    client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    payout_number TEXT NOT NULL UNIQUE,
    amount NUMERIC(14,2) NOT NULL,
    orders_count INT NOT NULL DEFAULT 0,
    order_ids UUID[] DEFAULT '{}',
    bank_name TEXT NOT NULL,
    account_number TEXT NOT NULL,
    account_name TEXT NOT NULL,
    disbursement_ref TEXT,
    proof_of_payment_url TEXT,
    status TEXT NOT NULL DEFAULT 'remitted', -- pending, remitted, completed, rejected
    disbursed_at TIMESTAMPTZ DEFAULT NOW(),
    confirmed_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_marketer_payouts_marketer_id ON public.marketer_payouts(marketer_id);
CREATE INDEX IF NOT EXISTS idx_marketer_payouts_client_id ON public.marketer_payouts(client_id);
CREATE INDEX IF NOT EXISTS idx_marketer_payouts_status ON public.marketer_payouts(status);

-- Enable RLS
ALTER TABLE public.marketer_payouts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public access to marketer_payouts" ON public.marketer_payouts;
CREATE POLICY "Public access to marketer_payouts" ON public.marketer_payouts
    FOR ALL TO authenticated, service_role, anon
    USING (true)
    WITH CHECK (true);

-- 4. Stored Procedure: fn_disburse_marketer_payout
CREATE OR REPLACE FUNCTION public.fn_disburse_marketer_payout(
    p_marketer_id UUID,
    p_client_id UUID,
    p_amount NUMERIC,
    p_orders_count INT DEFAULT 0,
    p_order_ids UUID[] DEFAULT '{}',
    p_bank_name TEXT DEFAULT '',
    p_account_number TEXT DEFAULT '',
    p_account_name TEXT DEFAULT '',
    p_disbursement_ref TEXT DEFAULT '',
    p_proof_of_payment_url TEXT DEFAULT '',
    p_notes TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_payout_id UUID := gen_random_uuid();
    v_payout_number TEXT;
    v_marketer RECORD;
BEGIN
    SELECT * INTO v_marketer FROM public.client_marketers WHERE id = p_marketer_id;
    IF v_marketer.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Marketer not found.');
    END IF;

    -- Generate Unique Payout Number
    v_payout_number := 'MPAY-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');

    -- Insert payout record
    INSERT INTO public.marketer_payouts (
        id,
        marketer_id,
        client_id,
        payout_number,
        amount,
        orders_count,
        order_ids,
        bank_name,
        account_number,
        account_name,
        disbursement_ref,
        proof_of_payment_url,
        status,
        disbursed_at,
        notes
    ) VALUES (
        v_payout_id,
        p_marketer_id,
        p_client_id,
        v_payout_number,
        p_amount,
        p_orders_count,
        p_order_ids,
        COALESCE(NULLIF(p_bank_name, ''), v_marketer.bank_name, 'Bank Transfer'),
        COALESCE(NULLIF(p_account_number, ''), v_marketer.account_number, ''),
        COALESCE(NULLIF(p_account_name, ''), v_marketer.account_name, v_marketer.full_name),
        p_disbursement_ref,
        p_proof_of_payment_url,
        'remitted',
        NOW(),
        p_notes
    );

    -- Update marketer balances
    UPDATE public.client_marketers
    SET 
        total_paid_commission = COALESCE(total_paid_commission, 0.00) + p_amount,
        unpaid_commission_balance = GREATEST(0.00, COALESCE(unpaid_commission_balance, 0.00) - p_amount),
        updated_at = NOW()
    WHERE id = p_marketer_id;

    -- In-app notification to marketer
    IF v_marketer.user_id IS NOT NULL THEN
        INSERT INTO public.notifications (
            company_id,
            user_id,
            title,
            message,
            category,
            action_route,
            is_read,
            created_at
        ) VALUES (
            p_client_id,
            v_marketer.user_id,
            'Commission Payout Disbursed 💰',
            'Your commission disbursement #' || v_payout_number || ' of ₦' || p_amount || ' has been sent to ' || COALESCE(v_marketer.bank_name, 'your bank account') || '.',
            'finance',
            '/marketing',
            false,
            NOW()
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'payout_id', v_payout_id,
        'payout_number', v_payout_number,
        'amount', p_amount,
        'status', 'remitted',
        'message', 'Marketer payout successfully remitted with attached receipt proof.'
    );
END;
$$;

-- 5. Stored Procedure: fn_delete_marketer (Safe deletion)
CREATE OR REPLACE FUNCTION public.fn_delete_marketer(p_marketer_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_marketer RECORD;
BEGIN
    SELECT * INTO v_marketer FROM public.client_marketers WHERE id = p_marketer_id;
    IF v_marketer.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Marketer not found.');
    END IF;

    -- Unlink active forms safely so history is preserved
    UPDATE public.lead_forms
    SET marketer_id = NULL
    WHERE marketer_id = p_marketer_id;

    -- Unlink orders safely
    UPDATE public.orders
    SET marketer_id = NULL
    WHERE marketer_id = p_marketer_id;

    -- Reassign subordinate supervisees to null
    UPDATE public.client_marketers
    SET supervisor_id = NULL
    WHERE supervisor_id = p_marketer_id;

    -- Deactivate associated auth user if exists
    IF v_marketer.user_id IS NOT NULL THEN
        UPDATE public.users
        SET is_active = false
        WHERE id = v_marketer.user_id;
    END IF;

    -- Delete marketer record (cascades to marketer_payouts)
    DELETE FROM public.client_marketers WHERE id = p_marketer_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Digital marketer deleted successfully and related references preserved.'
    );
END;
$$;

-- 6. Add marketer_payouts to Realtime Publication
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'marketer_payouts'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.marketer_payouts;
    END IF;
END $$;

-- 7. Grant Permissions
GRANT EXECUTE ON FUNCTION public.fn_disburse_marketer_payout TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_delete_marketer TO authenticated, service_role, anon;
GRANT ALL ON public.marketer_payouts TO authenticated, service_role, anon;

NOTIFY pgrst, 'reload schema';


-- =================== 20260928100000_supervisory_marketer_hierarchy_and_delivery_audit.sql ===================
-- ============================================================================
-- Migration: 20260928100000_supervisory_marketer_hierarchy_and_delivery_audit.sql
-- Description:
--   Supervisory Digital Marketer Realtime Delivery Notification & Hierarchy Aggregation:
--   1. Enhances fn_handle_order_delivery_marketer_lifecycle to automatically notify
--      the Supervisory Marketer when a supervisee's attributed order is delivered to buyer.
--   2. Adds fn_get_marketer_supervisees RPC to aggregate supervisee performance,
--      daily budget, conversion rates, and financial commission balances in a single indexed query.
-- ============================================================================

-- 1. Enhanced Delivery Lifecycle Trigger with Supervisory Alert
CREATE OR REPLACE FUNCTION public.fn_handle_order_delivery_marketer_lifecycle()
RETURNS TRIGGER AS $$
DECLARE
    v_marketer RECORD;
    v_supervisor RECORD;
    v_commission_amount NUMERIC := 0.00;
    v_company_id UUID;
BEGIN
    -- Only fire when status transitions to 'delivered' or 'completed'
    IF (OLD.status IS DISTINCT FROM NEW.status) AND (LOWER(NEW.status) IN ('delivered', 'completed')) THEN
        
        -- A. If order has an attached Digital Marketer
        IF NEW.marketer_id IS NOT NULL THEN
            SELECT * INTO v_marketer FROM public.client_marketers WHERE id = NEW.marketer_id;
            
            IF v_marketer.id IS NOT NULL THEN
                -- Compute delivery commission if model is per_delivered_order
                IF v_marketer.commission_type = 'per_delivered_order' OR COALESCE(v_marketer.commission_per_delivered_order, 0) > 0 THEN
                    v_commission_amount := COALESCE(NULLIF(v_marketer.commission_per_delivered_order, 0), NULLIF(v_marketer.commission_rate, 0), 2000.00);
                END IF;

                -- Update marketer performance stats & earned balance
                UPDATE public.client_marketers
                SET total_orders_delivered = COALESCE(total_orders_delivered, 0) + 1,
                    total_commission_earned = COALESCE(total_commission_earned, 0) + v_commission_amount,
                    unpaid_commission_balance = COALESCE(unpaid_commission_balance, 0.00) + v_commission_amount,
                    updated_at = NOW()
                WHERE id = v_marketer.id;

                -- Update linked lead_form delivery count if form_id is present
                IF NEW.form_id IS NOT NULL THEN
                    UPDATE public.lead_forms
                    SET total_orders_delivered = COALESCE(total_orders_delivered, 0) + 1,
                        updated_at = NOW()
                    WHERE id = NEW.form_id;
                END IF;

                -- Resolve company_id for notifications
                BEGIN
                    SELECT company_id INTO v_company_id FROM public.clients WHERE id = NEW.client_id;
                EXCEPTION WHEN OTHERS THEN
                    v_company_id := NULL;
                END;
                IF v_company_id IS NULL THEN
                    BEGIN
                        SELECT id INTO v_company_id FROM public.companies LIMIT 1;
                    EXCEPTION WHEN OTHERS THEN
                        v_company_id := NULL;
                    END;
                END IF;
                IF v_company_id IS NULL THEN
                    v_company_id := '11111111-1111-4111-8111-111111111111'::UUID;
                END IF;

                -- In-app notification to the primary marketer
                IF v_marketer.user_id IS NOT NULL THEN
                    BEGIN
                        INSERT INTO public.notifications (
                            company_id,
                            user_id,
                            title,
                            message,
                            category,
                            action_route,
                            is_read,
                            created_at
                        ) VALUES (
                            v_company_id,
                            v_marketer.user_id,
                            'Buyer Received Delivery! 📦🎉',
                            'Ad Order #' || NEW.order_number || ' (' || NEW.customer_name || ' in ' || COALESCE(NEW.delivery_lga, NEW.delivery_city, 'LGA') || ') was delivered and confirmed by rider.' ||
                            CASE WHEN v_commission_amount > 0 THEN ' Commission of ₦' || v_commission_amount || ' credited.' ELSE '' END,
                            'marketing',
                            '/marketing',
                            false,
                            NOW()
                        );
                    EXCEPTION WHEN OTHERS THEN
                        NULL;
                    END;
                END IF;

                -- B. If marketer is subordinate to a Supervisor, notify the Supervisor as well
                IF v_marketer.supervisor_id IS NOT NULL THEN
                    SELECT * INTO v_supervisor FROM public.client_marketers WHERE id = v_marketer.supervisor_id;
                    IF v_supervisor.id IS NOT NULL AND v_supervisor.user_id IS NOT NULL THEN
                        BEGIN
                            INSERT INTO public.notifications (
                                company_id,
                                user_id,
                                title,
                                message,
                                category,
                                action_route,
                                is_read,
                                created_at
                            ) VALUES (
                                v_company_id,
                                v_supervisor.user_id,
                                'Team Order Delivered! 📦🎉',
                                'Supervised media buyer ' || v_marketer.full_name || ' achieved verified delivery for Order #' || NEW.order_number || ' (' || NEW.product_name || ' in ' || COALESCE(NEW.delivery_lga, NEW.delivery_city, 'LGA') || ').',
                                'marketing',
                                '/marketing',
                                false,
                                NOW()
                            );
                        EXCEPTION WHEN OTHERS THEN
                            NULL;
                        END;
                    END IF;
                END IF;

            END IF;
        END IF;

        -- C. Post Lifecycle Milestone message into Pipeline Chat
        BEGIN
            PERFORM public.fn_sync_order_conversation(
                NEW.id,
                'System Notification',
                'system',
                '✅ Package Delivered & Received: Order #' || NEW.order_number || ' (' || NEW.product_name || ') has been successfully delivered to customer with verified POD.',
                NULL
            );
        EXCEPTION WHEN OTHERS THEN
            NULL; -- Non-blocking for conversation chat sync
        END;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Stored Procedure: fn_get_marketer_supervisees
CREATE OR REPLACE FUNCTION public.fn_get_marketer_supervisees(p_supervisor_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', m.id,
                'client_id', m.client_id,
                'user_id', m.user_id,
                'marketer_code', m.marketer_code,
                'full_name', m.full_name,
                'email', m.email,
                'phone', m.phone,
                'is_active', m.is_active,
                'daily_ad_spend_budget', m.daily_ad_spend_budget,
                'commission_rate', m.commission_rate,
                'is_commission_enabled', m.is_commission_enabled,
                'is_supervisor', m.is_supervisor,
                'supervisor_id', m.supervisor_id,
                'commission_type', m.commission_type,
                'commission_per_form_submission', m.commission_per_form_submission,
                'commission_per_delivered_order', m.commission_per_delivered_order,
                'bank_name', m.bank_name,
                'account_number', m.account_number,
                'account_name', m.account_name,
                'avatar_url', m.avatar_url,
                'total_leads_generated', m.total_leads_generated,
                'total_orders_generated', m.total_orders_generated,
                'total_orders_delivered', m.total_orders_delivered,
                'total_commission_earned', m.total_commission_earned,
                'unpaid_commission_balance', m.unpaid_commission_balance,
                'total_paid_commission', m.total_paid_commission,
                'active_forms_count', (SELECT COUNT(*) FROM public.lead_forms lf WHERE lf.marketer_id = m.id AND lf.is_active = true),
                'total_forms_count', (SELECT COUNT(*) FROM public.lead_forms lf WHERE lf.marketer_id = m.id),
                'created_at', m.created_at,
                'updated_at', m.updated_at
            ) ORDER BY m.total_orders_delivered DESC, m.full_name ASC
        ),
        '[]'::jsonb
    ) INTO v_result
    FROM public.client_marketers m
    WHERE m.supervisor_id = p_supervisor_id AND m.id != p_supervisor_id;

    RETURN v_result;
END;
$$;

-- Grant permissions to authenticated, anon and service_role
GRANT EXECUTE ON FUNCTION public.fn_get_marketer_supervisees(UUID) TO authenticated, service_role, anon;


-- =================== 20260928101500_fix_company_id_in_delivery_notification.sql ===================
-- ============================================================================
-- Migration: 20260928101500_fix_company_id_in_delivery_notification.sql
-- Description:
--   Ensures company_id is dynamically resolved and notifications never block delivery.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_handle_order_delivery_marketer_lifecycle()
RETURNS TRIGGER AS $$
DECLARE
    v_marketer RECORD;
    v_supervisor RECORD;
    v_commission_amount NUMERIC := 0.00;
    v_company_id UUID;
BEGIN
    -- Only fire when status transitions to 'delivered' or 'completed'
    IF (OLD.status IS DISTINCT FROM NEW.status) AND (LOWER(NEW.status) IN ('delivered', 'completed')) THEN
        
        -- A. If order has an attached Digital Marketer
        IF NEW.marketer_id IS NOT NULL THEN
            SELECT * INTO v_marketer FROM public.client_marketers WHERE id = NEW.marketer_id;
            
            IF v_marketer.id IS NOT NULL THEN
                -- Compute delivery commission if model is per_delivered_order
                IF v_marketer.commission_type = 'per_delivered_order' OR COALESCE(v_marketer.commission_per_delivered_order, 0) > 0 THEN
                    v_commission_amount := COALESCE(NULLIF(v_marketer.commission_per_delivered_order, 0), NULLIF(v_marketer.commission_rate, 0), 2000.00);
                END IF;

                -- Update marketer performance stats & earned balance
                UPDATE public.client_marketers
                SET total_orders_delivered = COALESCE(total_orders_delivered, 0) + 1,
                    total_commission_earned = COALESCE(total_commission_earned, 0) + v_commission_amount,
                    unpaid_commission_balance = COALESCE(unpaid_commission_balance, 0.00) + v_commission_amount,
                    updated_at = NOW()
                WHERE id = v_marketer.id;

                -- Update linked lead_form delivery count if form_id is present
                IF NEW.form_id IS NOT NULL THEN
                    UPDATE public.lead_forms
                    SET total_orders_delivered = COALESCE(total_orders_delivered, 0) + 1,
                        updated_at = NOW()
                    WHERE id = NEW.form_id;
                END IF;

                -- Resolve company_id for notifications
                BEGIN
                    SELECT company_id INTO v_company_id FROM public.clients WHERE id = NEW.client_id;
                EXCEPTION WHEN OTHERS THEN
                    v_company_id := NULL;
                END;
                IF v_company_id IS NULL THEN
                    BEGIN
                        SELECT id INTO v_company_id FROM public.companies LIMIT 1;
                    EXCEPTION WHEN OTHERS THEN
                        v_company_id := NULL;
                    END;
                END IF;
                IF v_company_id IS NULL THEN
                    v_company_id := '11111111-1111-4111-8111-111111111111'::UUID;
                END IF;

                -- In-app notification to the primary marketer
                IF v_marketer.user_id IS NOT NULL THEN
                    BEGIN
                        INSERT INTO public.notifications (
                            company_id,
                            user_id,
                            title,
                            message,
                            category,
                            action_route,
                            is_read,
                            created_at
                        ) VALUES (
                            v_company_id,
                            v_marketer.user_id,
                            'Buyer Received Delivery! 📦🎉',
                            'Ad Order #' || NEW.order_number || ' (' || NEW.customer_name || ' in ' || COALESCE(NEW.delivery_lga, NEW.delivery_city, 'LGA') || ') was delivered and confirmed by rider.' ||
                            CASE WHEN v_commission_amount > 0 THEN ' Commission of ₦' || v_commission_amount || ' credited.' ELSE '' END,
                            'marketing',
                            '/marketing',
                            false,
                            NOW()
                        );
                    EXCEPTION WHEN OTHERS THEN
                        NULL;
                    END;
                END IF;

                -- B. If marketer is subordinate to a Supervisor, notify the Supervisor as well
                IF v_marketer.supervisor_id IS NOT NULL THEN
                    SELECT * INTO v_supervisor FROM public.client_marketers WHERE id = v_marketer.supervisor_id;
                    IF v_supervisor.id IS NOT NULL AND v_supervisor.user_id IS NOT NULL THEN
                        BEGIN
                            INSERT INTO public.notifications (
                                company_id,
                                user_id,
                                title,
                                message,
                                category,
                                action_route,
                                is_read,
                                created_at
                            ) VALUES (
                                v_company_id,
                                v_supervisor.user_id,
                                'Team Order Delivered! 📦🎉',
                                'Supervised media buyer ' || v_marketer.full_name || ' achieved verified delivery for Order #' || NEW.order_number || ' (' || NEW.product_name || ' in ' || COALESCE(NEW.delivery_lga, NEW.delivery_city, 'LGA') || ').',
                                'marketing',
                                '/marketing',
                                false,
                                NOW()
                            );
                        EXCEPTION WHEN OTHERS THEN
                            NULL;
                        END;
                    END IF;
                END IF;

            END IF;
        END IF;

        -- C. Post Lifecycle Milestone message into Pipeline Chat
        BEGIN
            PERFORM public.fn_sync_order_conversation(
                NEW.id,
                'System Notification',
                'system',
                '✅ Package Delivered & Received: Order #' || NEW.order_number || ' (' || NEW.product_name || ') has been successfully delivered to customer with verified POD.',
                NULL
            );
        EXCEPTION WHEN OTHERS THEN
            NULL; -- Non-blocking for conversation chat sync
        END;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =================== 20260929160000_get_db_constraints_and_fix_cache.sql ===================
-- Migration: Inspect Constraints and Fix PostgREST Schema Cache
CREATE OR REPLACE FUNCTION public.fn_debug_get_table_constraints(p_table TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_res JSONB;
BEGIN
    SELECT jsonb_agg(jsonb_build_object(
        'conname', conname,
        'contype', contype,
        'definition', pg_get_constraintdef(c.oid)
    )) INTO v_res
    FROM pg_constraint c
    JOIN pg_namespace n ON n.oid = c.connamespace
    JOIN pg_class cl ON cl.oid = c.conrelid
    WHERE n.nspname = 'public' AND cl.relname = p_table;
    RETURN COALESCE(v_res, '[]'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_debug_get_table_constraints(TEXT) TO anon, authenticated, service_role;

-- Ensure missing columns on operational tables exist
ALTER TABLE IF EXISTS public.delivery_agents
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE IF EXISTS public.stock_transfers
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE IF EXISTS public.stock_transfer_items
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Lead forms: make legacy non-null columns nullable so modern lead forms insert cleanly
DO $$
DECLARE
    col RECORD;
BEGIN
    FOR col IN 
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'lead_forms' 
          AND is_nullable = 'NO'
          AND column_name NOT IN ('id', 'product_id', 'product_name', 'form_title', 'packages', 'client_id')
    LOOP
        EXECUTE 'ALTER TABLE public.lead_forms ALTER COLUMN ' || quote_ident(col.column_name) || ' DROP NOT NULL;';
    END LOOP;
END $$;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';


-- =================== 20260929161000_harmonize_orders_and_forms_legacy_constraints.sql ===================
-- ============================================================================
-- Migration: 20260929161000_harmonize_orders_and_forms_legacy_constraints.sql
-- Description: Drop legacy restricted CHECK and FK constraints on orders and lead_forms
--              that conflicted with modern marketing suite, closer confirmation status,
--              and client_marketers linkage.
-- ============================================================================

-- 1. Remove outdated constraints on orders
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_status_check;
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_payment_status_check;
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_marketer_id_fkey;

-- Re-link orders.marketer_id to client_marketers
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'orders_client_marketer_id_fkey'
    ) THEN
        ALTER TABLE public.orders 
            ADD CONSTRAINT orders_client_marketer_id_fkey 
            FOREIGN KEY (marketer_id) REFERENCES public.client_marketers(id) ON DELETE SET NULL;
    END IF;
END $$;

-- 2. Ensure customer_leads.marketer_id references client_marketers
ALTER TABLE public.customer_leads DROP CONSTRAINT IF EXISTS customer_leads_marketer_id_fkey;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'customer_leads_client_marketer_id_fkey'
    ) THEN
        ALTER TABLE public.customer_leads 
            ADD CONSTRAINT customer_leads_client_marketer_id_fkey 
            FOREIGN KEY (marketer_id) REFERENCES public.client_marketers(id) ON DELETE SET NULL;
    END IF;
END $$;

-- 3. Lead forms: Drop NOT NULL on legacy columns to allow modern forms insertion
DO $$
DECLARE
    legacy_cols TEXT[] := ARRAY[
        'title', 'company_id', 'status', 'digital_marketer_email', 
        'success_message', 'submit_button_text', 'product_category',
        'resolved_brand', 'resolved_cost_center', 'quantity_display_mode',
        'preset_country'
    ];
    c TEXT;
BEGIN
    FOREACH c IN ARRAY legacy_cols
    LOOP
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
              AND table_name = 'lead_forms' 
              AND column_name = c
        ) THEN
            EXECUTE 'ALTER TABLE public.lead_forms ALTER COLUMN ' || quote_ident(c) || ' DROP NOT NULL;';
        END IF;
    END LOOP;
END $$;

-- 4. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';


-- =================== 20260929162000_finalize_production_schema_parity.sql ===================
-- Migration: Finalize Production Schema Parity for Transfers, Remittances, and PostgREST Cache
ALTER TABLE IF EXISTS public.cash_remittances
    ADD COLUMN IF NOT EXISTS destination_account_name TEXT,
    ADD COLUMN IF NOT EXISTS destination_account_number TEXT,
    ADD COLUMN IF NOT EXISTS destination_bank_name TEXT;

ALTER TABLE IF EXISTS public.stock_transfers
    ALTER COLUMN source_warehouse_id DROP NOT NULL,
    ALTER COLUMN destination_warehouse_id DROP NOT NULL;

ALTER TABLE IF EXISTS public.stock_transfer_items
    ALTER COLUMN product_id DROP NOT NULL;

NOTIFY pgrst, 'reload schema';


-- =================== 20260929163000_patch_remittance_and_transfers.sql ===================
-- Migration: Add missing remittance columns and relax legacy transfer not-null constraints
ALTER TABLE IF EXISTS public.cash_remittances
    ADD COLUMN IF NOT EXISTS pos_fee NUMERIC(14,2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS verified_by_user_id UUID REFERENCES public.users(id);

ALTER TABLE IF EXISTS public.stock_transfers
    ALTER COLUMN initiated_by_user_id DROP NOT NULL;

NOTIFY pgrst, 'reload schema';


-- =================== 20260929164000_drop_stock_transfers_status_check.sql ===================
-- Migration: Drop legacy stock_transfers_status_check constraint to allow modern supply statuses
ALTER TABLE public.stock_transfers DROP CONSTRAINT IF EXISTS stock_transfers_status_check;
NOTIFY pgrst, 'reload schema';


-- =================== 20261011140000_business_expenditures_and_financial_analytics.sql ===================
-- ============================================================================
-- MIGRATION: 20261011140000_business_expenditures_and_financial_analytics.sql
-- DESCRIPTION: Universal Multi-Tier Expenditure Ledger & High-Performance RPCs
-- AUTHOR: NovaExpress Engineering / Architecture Council
-- ============================================================================

-- 1. STORAGE BUCKET FOR RECEIPT & INVOICE ATTACHMENTS (PDF / IMAGES)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'expenditure-receipts',
    'expenditure-receipts',
    true,
    15728640, -- 15MB limit
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Storage bucket access policies
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Public Access for Expenditure Receipts') THEN
        CREATE POLICY "Public Access for Expenditure Receipts" ON storage.objects
            FOR SELECT USING (bucket_id = 'expenditure-receipts');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Allow Uploads for Expenditure Receipts') THEN
        CREATE POLICY "Allow Uploads for Expenditure Receipts" ON storage.objects
            FOR INSERT WITH CHECK (bucket_id = 'expenditure-receipts');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Allow Updates for Expenditure Receipts') THEN
        CREATE POLICY "Allow Updates for Expenditure Receipts" ON storage.objects
            FOR UPDATE USING (bucket_id = 'expenditure-receipts');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Allow Deletes for Expenditure Receipts') THEN
        CREATE POLICY "Allow Deletes for Expenditure Receipts" ON storage.objects
            FOR DELETE USING (bucket_id = 'expenditure-receipts');
    END IF;
END $$;

-- 2. UNIVERSAL BUSINESS EXPENDITURES TABLE
CREATE TABLE IF NOT EXISTS public.business_expenditures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type TEXT NOT NULL CHECK (entity_type IN ('merchant', 'grand_dc', 'sub_dc')),
    client_id UUID REFERENCES public.clients(id) ON DELETE CASCADE,
    distribution_center_id UUID REFERENCES public.distribution_centers(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL, -- HYBRID LINK: NULL = Overhead, UUID = SKU-specific
    title TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL CHECK (category IN (
        'advertisement',
        'procurement',
        'logistics',
        'salaries',
        'rent_utilities',
        'packaging',
        'rider_allowance',
        'diesel_fuel',
        'equipment_maintenance',
        'other'
    )),
    amount NUMERIC(14, 2) NOT NULL CHECK (amount >= 0),
    expenditure_date DATE NOT NULL DEFAULT CURRENT_DATE,
    receipt_url TEXT,
    receipt_file_name TEXT,
    receipt_mime_type TEXT,
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for lightning-fast aggregation & dashboard queries
CREATE INDEX IF NOT EXISTS idx_expenditures_client_date ON public.business_expenditures(client_id, expenditure_date);
CREATE INDEX IF NOT EXISTS idx_expenditures_dc_date ON public.business_expenditures(distribution_center_id, expenditure_date);
CREATE INDEX IF NOT EXISTS idx_expenditures_product ON public.business_expenditures(product_id);
CREATE INDEX IF NOT EXISTS idx_expenditures_category ON public.business_expenditures(category);
CREATE INDEX IF NOT EXISTS idx_expenditures_entity_type ON public.business_expenditures(entity_type);

-- Enable RLS
ALTER TABLE public.business_expenditures ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'business_expenditures' AND policyname = 'Allow read for all authenticated users') THEN
        CREATE POLICY "Allow read for all authenticated users" ON public.business_expenditures
            FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'business_expenditures' AND policyname = 'Allow insert for authenticated users') THEN
        CREATE POLICY "Allow insert for authenticated users" ON public.business_expenditures
            FOR INSERT WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'business_expenditures' AND policyname = 'Allow update for authenticated users') THEN
        CREATE POLICY "Allow update for authenticated users" ON public.business_expenditures
            FOR UPDATE USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'business_expenditures' AND policyname = 'Allow delete for authenticated users') THEN
        CREATE POLICY "Allow delete for authenticated users" ON public.business_expenditures
            FOR DELETE USING (true);
    END IF;
END $$;

-- 3. STORED PROCEDURE: fn_get_merchant_financial_dashboard
CREATE OR REPLACE FUNCTION public.fn_get_merchant_financial_dashboard(
    p_client_id UUID,
    p_product_id UUID DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_start DATE;
    v_end DATE;
    v_sales_revenue NUMERIC(14, 2) := 0.00;
    v_total_expenditures NUMERIC(14, 2) := 0.00;
    v_quantity_sold INT := 0;
    v_net_profit NUMERIC(14, 2) := 0.00;
    v_available_stock INT := 0;
    v_advertisement_exp NUMERIC(14, 2) := 0.00;
    v_procurement_exp NUMERIC(14, 2) := 0.00;
    v_revenue_till_date NUMERIC(14, 2) := 0.00;
    v_daily_trends JSONB := '[]'::jsonb;
    v_state_distribution JSONB := '[]'::jsonb;
    v_product_info JSONB := NULL;
BEGIN
    -- Fallback to default date window (last 30 days if null)
    v_end := COALESCE(p_end_date, CURRENT_DATE);
    v_start := COALESCE(p_start_date, v_end - INTERVAL '30 days');

    -- 1. SALES REVENUE & QUANTITY SOLD (Delivered orders in date window)
    SELECT
        COALESCE(SUM(o.total_amount), 0.00),
        COALESCE(SUM(o.quantity), 0)
    INTO
        v_sales_revenue,
        v_quantity_sold
    FROM public.orders o
    WHERE o.client_id = p_client_id
      AND o.status = 'delivered'
      AND o.created_at::DATE BETWEEN v_start AND v_end
      AND (p_product_id IS NULL OR o.product_id = p_product_id);

    -- 2. TOTAL EXPENDITURES (Category Breakdowns)
    SELECT
        COALESCE(SUM(be.amount), 0.00),
        COALESCE(SUM(CASE WHEN be.category = 'advertisement' THEN be.amount ELSE 0.00 END), 0.00),
        COALESCE(SUM(CASE WHEN be.category = 'procurement' THEN be.amount ELSE 0.00 END), 0.00)
    INTO
        v_total_expenditures,
        v_advertisement_exp,
        v_procurement_exp
    FROM public.business_expenditures be
    WHERE be.client_id = p_client_id
      AND be.entity_type = 'merchant'
      AND be.expenditure_date BETWEEN v_start AND v_end
      AND (
          -- If filtering by product: include product-specific AND proportion of unlinked overhead
          p_product_id IS NULL 
          OR be.product_id = p_product_id 
          OR be.product_id IS NULL
      );

    -- 3. NET PROFIT (Sales Revenue - Total Expenditures)
    v_net_profit := v_sales_revenue - v_total_expenditures;

    -- 4. AVAILABLE STOCK (Real-time balance from client_stock_balances)
    SELECT
        COALESCE(SUM(csb.current_balance), 0)
    INTO
        v_available_stock
    FROM public.client_stock_balances csb
    WHERE csb.client_id = p_client_id
      AND (p_product_id IS NULL OR csb.product_id = p_product_id);

    -- 5. REVENUE TILL DATE (All delivered revenue since inception)
    SELECT
        COALESCE(SUM(o.total_amount), 0.00)
    INTO
        v_revenue_till_date
    FROM public.orders o
    WHERE o.client_id = p_client_id
      AND o.status = 'delivered'
      AND (p_product_id IS NULL OR o.product_id = p_product_id);

    -- 6. DAILY TRENDS (Grouped Bar Chart data: Sales vs Expenditures)
    WITH date_series AS (
        SELECT generate_series(v_start, v_end, '1 day'::interval)::DATE AS dt
    ),
    daily_sales AS (
        SELECT
            o.created_at::DATE AS dt,
            COALESCE(SUM(o.total_amount), 0.00) AS sales,
            COALESCE(SUM(o.quantity), 0) AS units
        FROM public.orders o
        WHERE o.client_id = p_client_id
          AND o.status = 'delivered'
          AND o.created_at::DATE BETWEEN v_start AND v_end
          AND (p_product_id IS NULL OR o.product_id = p_product_id)
        GROUP BY o.created_at::DATE
    ),
    daily_expenses AS (
        SELECT
            be.expenditure_date AS dt,
            COALESCE(SUM(be.amount), 0.00) AS expenses
        FROM public.business_expenditures be
        WHERE be.client_id = p_client_id
          AND be.entity_type = 'merchant'
          AND be.expenditure_date BETWEEN v_start AND v_end
          AND (p_product_id IS NULL OR be.product_id = p_product_id OR be.product_id IS NULL)
        GROUP BY be.expenditure_date
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'date', ds.dt,
            'sales', COALESCE(s.sales, 0.00),
            'expenditure', COALESCE(e.expenses, 0.00),
            'units_sold', COALESCE(s.units, 0),
            'net_margin', COALESCE(s.sales, 0.00) - COALESCE(e.expenses, 0.00)
        ) ORDER BY ds.dt ASC
    )
    INTO v_daily_trends
    FROM date_series ds
    LEFT JOIN daily_sales s ON ds.dt = s.dt
    LEFT JOIN daily_expenses e ON ds.dt = e.dt;

    -- 7. REVENUE BY STATE DISTRIBUTION (Donut Chart)
    SELECT jsonb_agg(
        jsonb_build_object(
            'state', state_data.state,
            'order_count', state_data.order_count,
            'revenue', state_data.revenue
        ) ORDER BY state_data.revenue DESC
    )
    INTO v_state_distribution
    FROM (
        SELECT
            COALESCE(NULLIF(o.customer_state, ''), 'Federal Capital Territory') AS state,
            COUNT(o.id) AS order_count,
            COALESCE(SUM(o.total_amount), 0.00) AS revenue
        FROM public.orders o
        WHERE o.client_id = p_client_id
          AND o.status = 'delivered'
          AND o.created_at::DATE BETWEEN v_start AND v_end
          AND (p_product_id IS NULL OR o.product_id = p_product_id)
        GROUP BY COALESCE(NULLIF(o.customer_state, ''), 'Federal Capital Territory')
    ) state_data;

    -- 8. PRODUCT UNIT ECONOMICS (if specific product selected)
    IF p_product_id IS NOT NULL THEN
        SELECT jsonb_build_object(
            'product_id', p.id,
            'product_name', p.name,
            'sku', p.sku,
            'base_price', p.base_price,
            'cost_price', p.cost_price,
            'units_sold', v_quantity_sold,
            'direct_revenue', v_sales_revenue,
            'direct_advertising', v_advertisement_exp,
            'direct_procurement', v_procurement_exp
        )
        INTO v_product_info
        FROM public.products p
        WHERE p.id = p_product_id;
    END IF;

    -- BUILD CONSOLIDATED JSON RESPONSE
    RETURN jsonb_build_object(
        'client_id', p_client_id,
        'product_id', p_product_id,
        'start_date', v_start,
        'end_date', v_end,
        'sales_revenue', v_sales_revenue,
        'total_expenditures', v_total_expenditures,
        'quantity_sold', v_quantity_sold,
        'net_profit', v_net_profit,
        'available_stock', v_available_stock,
        'advertisement_expenditure', v_advertisement_exp,
        'procurement_expenditure', v_procurement_exp,
        'revenue_till_date', v_revenue_till_date,
        'daily_trends', COALESCE(v_daily_trends, '[]'::jsonb),
        'state_distribution', COALESCE(v_state_distribution, '[]'::jsonb),
        'product_economics', v_product_info
    );
END;
$$;

-- 4. STORED PROCEDURE: fn_get_dc_logistics_dashboard
CREATE OR REPLACE FUNCTION public.fn_get_dc_logistics_dashboard(
    p_dc_id UUID DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_start DATE;
    v_end DATE;
    v_logistics_gross_revenue NUMERIC(14, 2) := 0.00;
    v_network_opex NUMERIC(14, 2) := 0.00;
    v_total_parcels_handled INT := 0;
    v_net_logistics_margin NUMERIC(14, 2) := 0.00;
    v_vault_inventory INT := 0;
    v_rider_allowances NUMERIC(14, 2) := 0.00;
    v_facility_capex NUMERIC(14, 2) := 0.00;
    v_cumulative_revenue NUMERIC(14, 2) := 0.00;
    v_daily_trends JSONB := '[]'::jsonb;
    v_dc_breakdown JSONB := '[]'::jsonb;
BEGIN
    v_end := COALESCE(p_end_date, CURRENT_DATE);
    v_start := COALESCE(p_start_date, v_end - INTERVAL '30 days');

    -- 1. LOGISTICS REVENUE & PARCEL VOLUMES
    SELECT
        COALESCE(SUM(o.client_delivery_fee), 0.00),
        COUNT(o.id)
    INTO
        v_logistics_gross_revenue,
        v_total_parcels_handled
    FROM public.orders o
    WHERE o.status = 'delivered'
      AND o.created_at::DATE BETWEEN v_start AND v_end
      AND (p_dc_id IS NULL OR o.assigned_dc_id = p_dc_id);

    -- 2. OPERATIONAL EXPENDITURES
    SELECT
        COALESCE(SUM(be.amount), 0.00),
        COALESCE(SUM(CASE WHEN be.category = 'rider_allowance' THEN be.amount ELSE 0.00 END), 0.00),
        COALESCE(SUM(CASE WHEN be.category IN ('rent_utilities', 'equipment_maintenance', 'diesel_fuel') THEN be.amount ELSE 0.00 END), 0.00)
    INTO
        v_network_opex,
        v_rider_allowances,
        v_facility_capex
    FROM public.business_expenditures be
    WHERE be.entity_type IN ('grand_dc', 'sub_dc')
      AND be.expenditure_date BETWEEN v_start AND v_end
      AND (p_dc_id IS NULL OR be.distribution_center_id = p_dc_id);

    -- 3. NET LOGISTICS PLATFORM PROFIT
    v_net_logistics_margin := v_logistics_gross_revenue - v_network_opex;

    -- 4. VAULT INVENTORY COUNT
    SELECT COALESCE(SUM(csb.current_balance), 0)
    INTO v_vault_inventory
    FROM public.client_stock_balances csb
    WHERE (p_dc_id IS NULL OR csb.distribution_center_id = p_dc_id);

    -- 5. CUMULATIVE REVENUE TO DATE
    SELECT COALESCE(SUM(o.client_delivery_fee), 0.00)
    INTO v_cumulative_revenue
    FROM public.orders o
    WHERE o.status = 'delivered'
      AND (p_dc_id IS NULL OR o.assigned_dc_id = p_dc_id);

    -- 6. DC BREAKDOWN
    IF p_dc_id IS NULL THEN
        SELECT jsonb_agg(
            jsonb_build_object(
                'dc_id', dc_data.id,
                'dc_name', dc_data.name,
                'city', dc_data.city,
                'parcels', dc_data.parcels,
                'revenue', dc_data.revenue
            ) ORDER BY dc_data.revenue DESC
        )
        INTO v_dc_breakdown
        FROM (
            SELECT
                dc.id,
                dc.name,
                dc.city,
                COUNT(o.id) AS parcels,
                COALESCE(SUM(o.client_delivery_fee), 0.00) AS revenue
            FROM public.distribution_centers dc
            LEFT JOIN public.orders o ON o.assigned_dc_id = dc.id 
                AND o.status = 'delivered' 
                AND o.created_at::DATE BETWEEN v_start AND v_end
            GROUP BY dc.id, dc.name, dc.city
        ) dc_data;
    END IF;

    RETURN jsonb_build_object(
        'dc_id', p_dc_id,
        'start_date', v_start,
        'end_date', v_end,
        'logistics_gross_revenue', v_logistics_gross_revenue,
        'network_opex', v_network_opex,
        'total_parcels_handled', v_total_parcels_handled,
        'net_logistics_margin', v_net_logistics_margin,
        'vault_inventory', v_vault_inventory,
        'rider_allowances', v_rider_allowances,
        'facility_capex', v_facility_capex,
        'cumulative_revenue', v_cumulative_revenue,
        'dc_breakdown', COALESCE(v_dc_breakdown, '[]'::jsonb)
    );
END;
$$;

-- Notify PostgREST to refresh schema cache
SELECT pg_notify('pgrst', 'reload schema');


-- =================== 20261011150000_b2b_client_package_logistics_protocol.sql ===================
-- ============================================================================
-- MIGRATION: 20261011150000_b2b_client_package_logistics_protocol.sql
-- DESCRIPTION: B2B Inbound Client Package Protocol & Decentralized Sourcing
-- AUTHOR: NovaExpress Engineering / Architecture Council
-- ============================================================================

-- 1. B2B CLIENTS REGISTRY (API Access Keys & Rate Configurations)
CREATE TABLE IF NOT EXISTS public.b2b_clients (
    id TEXT PRIMARY KEY,                           -- Unique client identifier (e.g., 'comfortcare-abuja-01')
    client_name TEXT NOT NULL,                     -- Display name (e.g., 'ComfortCare Health & Pharmacy Ltd')
    company_registration_no TEXT,                  -- RC / CAC Corporate Registration Number
    industry_category TEXT NOT NULL DEFAULT 'pharmacy' 
        CHECK (industry_category IN ('pharmacy', 'supermarket', 'electronics', 'fashion', 'general_retail')),
    api_key_hash TEXT NOT NULL,                    -- Bcrypt / Argon2 hash of secret bearer token
    api_key_prefix TEXT NOT NULL,                  -- Display prefix (e.g., 'nx_live_comfortcare_...')
    webhook_url TEXT,                              -- Webhook endpoint for live delivery status events
    webhook_secret TEXT,                           -- Shared secret for HMAC-SHA256 signature verification
    base_flat_rate NUMERIC(12, 2) NOT NULL DEFAULT 3500.00,
    additional_pickup_fee NUMERIC(12, 2) NOT NULL DEFAULT 1500.00,
    rider_base_allowance NUMERIC(12, 2) NOT NULL DEFAULT 1800.00,
    rider_extra_stop_allowance NUMERIC(12, 2) NOT NULL DEFAULT 1000.00,
    allowed_cities JSONB NOT NULL DEFAULT '["Abuja", "Lagos"]'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    contact_email TEXT,
    contact_phone TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_b2b_clients_active ON public.b2b_clients(is_active);

-- Seed Initial B2B Anchor Partner: ComfortCare Health & Pharmacy Ltd
INSERT INTO public.b2b_clients (
    id,
    client_name,
    company_registration_no,
    industry_category,
    api_key_hash,
    api_key_prefix,
    webhook_url,
    webhook_secret,
    base_flat_rate,
    additional_pickup_fee,
    rider_base_allowance,
    rider_extra_stop_allowance,
    allowed_cities,
    contact_email,
    contact_phone
) VALUES (
    'comfortcare-abuja-01',
    'ComfortCare Health & Pharmacy Ltd',
    'RC-1849204',
    'pharmacy',
    encode(sha256('nx_live_comfortcare_sec_994821049'::bytea), 'hex'),
    'nx_live_comfortcare_sec_9948...',
    'https://comfortcare.ng/api/v1/logistics-webhook',
    'whsec_comfortcare_prod_88294710',
    3500.00,
    1500.00,
    1800.00,
    1000.00,
    '["Abuja", "Lagos", "Kano", "Port Harcourt", "Ibadan"]'::jsonb,
    'dispatch@comfortcare.ng',
    '+2348032651505'
) ON CONFLICT (id) DO UPDATE SET
    client_name = EXCLUDED.client_name,
    base_flat_rate = EXCLUDED.base_flat_rate,
    additional_pickup_fee = EXCLUDED.additional_pickup_fee;

-- 2. ORDERS TABLE EXTENSIONS FOR B2B FULFILLMENT
ALTER TABLE public.orders
    ADD COLUMN IF NOT EXISTS fulfillment_type TEXT NOT NULL DEFAULT 'nova_inventory'
        CHECK (fulfillment_type IN ('nova_inventory', 'client_package')),
    ADD COLUMN IF NOT EXISTS b2b_client_id TEXT REFERENCES public.b2b_clients(id),
    ADD COLUMN IF NOT EXISTS client_order_reference TEXT,
    ADD COLUMN IF NOT EXISTS recipient_whatsapp TEXT,
    ADD COLUMN IF NOT EXISTS delivery_otp TEXT,
    ADD COLUMN IF NOT EXISTS otp_verified_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS pickup_stops_count INT NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS additional_pickup_fee NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS rider_pickup_allowance NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS payment_receipt_ref TEXT,
    ADD COLUMN IF NOT EXISTS payment_gateway TEXT;

CREATE INDEX IF NOT EXISTS idx_orders_fulfillment_type ON public.orders(fulfillment_type);
CREATE INDEX IF NOT EXISTS idx_orders_b2b_client ON public.orders(b2b_client_id);
CREATE INDEX IF NOT EXISTS idx_orders_client_ref ON public.orders(client_order_reference);

-- 3. CLIENT PACKAGE PICKUPS TABLE (Multi-Stop Dispensary & Supermarket Collection Itinerary)
CREATE TABLE IF NOT EXISTS public.client_package_pickups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    stop_sequence INT NOT NULL,                     -- 1, 2, 3...
    stop_label TEXT NOT NULL,                       -- e.g. 'Pickup Stop 1 (Life Camp)'
    location_id TEXT NOT NULL,                      -- e.g. 'ph-medplus-lifecamp'
    location_name TEXT NOT NULL,                    -- e.g. 'MedPlus Pharmacy (Life Camp)'
    pickup_address TEXT NOT NULL,                   -- Street address
    city TEXT NOT NULL DEFAULT 'Abuja',
    state TEXT NOT NULL DEFAULT 'Federal Capital Territory',
    lga TEXT,
    landmark TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    contact_person TEXT NOT NULL,
    contact_phone TEXT NOT NULL,
    contact_whatsapp TEXT,
    items_to_collect JSONB NOT NULL DEFAULT '[]'::jsonb, -- Array of items/drugs
    sealed_bag_ref TEXT NOT NULL,                   -- Tamper-evident barcode / QR (e.g., 'BAG-CC-99014-A')
    scanned_bag_ref TEXT,                           -- Scanned code confirmed by rider
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'rider_assigned', 'rider_arrived', 'bag_verified_collected', 'exception_failed')),
    failure_reason TEXT,
    collected_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pickups_order_id ON public.client_package_pickups(order_id);
CREATE INDEX IF NOT EXISTS idx_pickups_sealed_bag ON public.client_package_pickups(sealed_bag_ref);

-- Enable RLS
ALTER TABLE public.b2b_clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_package_pickups ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'b2b_clients' AND policyname = 'Allow read for authenticated') THEN
        CREATE POLICY "Allow read for authenticated" ON public.b2b_clients FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'client_package_pickups' AND policyname = 'Allow all for authenticated') THEN
        CREATE POLICY "Allow all for authenticated" ON public.client_package_pickups FOR ALL USING (true);
    END IF;
END $$;

-- 4. ATOMIC FUNCTION: fn_verify_pickup_bag_scan
CREATE OR REPLACE FUNCTION public.fn_verify_pickup_bag_scan(
    p_pickup_id UUID,
    p_scanned_bag_ref TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_expected_bag_ref TEXT;
    v_order_id UUID;
    v_remaining_stops INT;
BEGIN
    SELECT sealed_bag_ref, order_id
    INTO v_expected_bag_ref, v_order_id
    FROM public.client_package_pickups
    WHERE id = p_pickup_id;

    IF v_expected_bag_ref IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Pickup stop not found.');
    END IF;

    IF trim(upper(v_expected_bag_ref)) != trim(upper(p_scanned_bag_ref)) THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Bag barcode mismatch! Expected: ' || v_expected_bag_ref || ' but scanned: ' || p_scanned_bag_ref
        );
    END IF;

    -- Update stop status
    UPDATE public.client_package_pickups
    SET status = 'bag_verified_collected',
        scanned_bag_ref = p_scanned_bag_ref,
        collected_at = NOW()
    WHERE id = p_pickup_id;

    -- Check if all stops for this order are completed
    SELECT COUNT(*)
    INTO v_remaining_stops
    FROM public.client_package_pickups
    WHERE order_id = v_order_id
      AND status != 'bag_verified_collected';

    IF v_remaining_stops = 0 THEN
        UPDATE public.orders
        SET status = 'in_transit'
        WHERE id = v_order_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Bag verified and collected successfully!',
        'all_pickups_completed', (v_remaining_stops = 0),
        'remaining_stops_count', v_remaining_stops
    );
END;
$$;

-- 5. ATOMIC FUNCTION: fn_verify_delivery_otp_and_complete
CREATE OR REPLACE FUNCTION public.fn_verify_delivery_otp_and_complete(
    p_order_id UUID,
    p_entered_otp TEXT,
    p_agent_id UUID,
    p_recipient_signature_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_expected_otp TEXT;
    v_rider_allowance NUMERIC(12, 2);
    v_fulfillment_type TEXT;
BEGIN
    SELECT delivery_otp, rider_pickup_allowance, fulfillment_type
    INTO v_expected_otp, v_rider_allowance, v_fulfillment_type
    FROM public.orders
    WHERE id = p_order_id;

    IF v_expected_otp IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Order not found.');
    END IF;

    IF trim(v_expected_otp) != trim(p_entered_otp) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Invalid OTP! Recipient verification failed.');
    END IF;

    -- Update order to delivered
    UPDATE public.orders
    SET status = 'delivered',
        delivered_at = NOW(),
        otp_verified_at = NOW(),
        proof_of_delivery_signature_url = COALESCE(p_recipient_signature_url, proof_of_delivery_signature_url)
    WHERE id = p_order_id;

    -- If this was a client package with extra rider allowance, credit the rider
    IF v_fulfillment_type = 'client_package' AND v_rider_allowance > 0 THEN
        UPDATE public.delivery_agents
        SET current_balance = COALESCE(current_balance, 0.00) + v_rider_allowance
        WHERE id = p_agent_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Delivery completed and verified via OTP.',
        'order_id', p_order_id,
        'rider_credited_amount', v_rider_allowance
    );
END;
$$;

-- Notify PostgREST to refresh schema cache
SELECT pg_notify('pgrst', 'reload schema');


-- =================== 20261011153000_fix_financial_analytics_column_names.sql ===================
-- ============================================================================
-- MIGRATION: 20261011153000_fix_financial_analytics_column_names.sql
-- DESCRIPTION: Fix column names in financial analytics stored procedures
-- ============================================================================

-- 1. FIX fn_get_merchant_financial_dashboard
CREATE OR REPLACE FUNCTION public.fn_get_merchant_financial_dashboard(
    p_client_id UUID,
    p_product_id UUID DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_start DATE;
    v_end DATE;
    v_sales_revenue NUMERIC(14, 2) := 0.00;
    v_total_expenditures NUMERIC(14, 2) := 0.00;
    v_quantity_sold INT := 0;
    v_net_profit NUMERIC(14, 2) := 0.00;
    v_available_stock INT := 0;
    v_advertisement_exp NUMERIC(14, 2) := 0.00;
    v_procurement_exp NUMERIC(14, 2) := 0.00;
    v_revenue_till_date NUMERIC(14, 2) := 0.00;
    v_daily_trends JSONB := '[]'::jsonb;
    v_state_distribution JSONB := '[]'::jsonb;
    v_product_info JSONB := NULL;
BEGIN
    -- Fallback to default date window (last 30 days if null)
    v_end := COALESCE(p_end_date, CURRENT_DATE);
    v_start := COALESCE(p_start_date, v_end - INTERVAL '30 days');

    -- 1. SALES REVENUE & QUANTITY SOLD (Delivered orders in date window)
    SELECT
        COALESCE(SUM(o.total_amount), 0.00),
        COALESCE(SUM(o.quantity), 0)
    INTO
        v_sales_revenue,
        v_quantity_sold
    FROM public.orders o
    WHERE o.client_id = p_client_id
      AND o.status = 'delivered'
      AND o.created_at::DATE BETWEEN v_start AND v_end
      AND (p_product_id IS NULL OR o.product_id = p_product_id);

    -- 2. TOTAL EXPENDITURES (Category Breakdowns)
    SELECT
        COALESCE(SUM(be.amount), 0.00),
        COALESCE(SUM(CASE WHEN be.category = 'advertisement' THEN be.amount ELSE 0.00 END), 0.00),
        COALESCE(SUM(CASE WHEN be.category = 'procurement' THEN be.amount ELSE 0.00 END), 0.00)
    INTO
        v_total_expenditures,
        v_advertisement_exp,
        v_procurement_exp
    FROM public.business_expenditures be
    WHERE be.client_id = p_client_id
      AND be.entity_type = 'merchant'
      AND be.expenditure_date BETWEEN v_start AND v_end
      AND (
          p_product_id IS NULL 
          OR be.product_id = p_product_id 
          OR be.product_id IS NULL
      );

    -- 3. NET PROFIT (Sales Revenue - Total Expenditures)
    v_net_profit := v_sales_revenue - v_total_expenditures;

    -- 4. AVAILABLE STOCK (Using balance_qty from client_stock_balances)
    SELECT
        COALESCE(SUM(csb.balance_qty), 0)
    INTO
        v_available_stock
    FROM public.client_stock_balances csb
    WHERE csb.client_id = p_client_id
      AND (p_product_id IS NULL OR csb.product_id = p_product_id);

    -- 5. REVENUE TILL DATE (All delivered revenue since inception)
    SELECT
        COALESCE(SUM(o.total_amount), 0.00)
    INTO
        v_revenue_till_date
    FROM public.orders o
    WHERE o.client_id = p_client_id
      AND o.status = 'delivered'
      AND (p_product_id IS NULL OR o.product_id = p_product_id);

    -- 6. DAILY TRENDS (Grouped Bar Chart data: Sales vs Expenditures)
    WITH date_series AS (
        SELECT generate_series(v_start, v_end, '1 day'::interval)::DATE AS dt
    ),
    daily_sales AS (
        SELECT
            o.created_at::DATE AS dt,
            COALESCE(SUM(o.total_amount), 0.00) AS sales,
            COALESCE(SUM(o.quantity), 0) AS units
        FROM public.orders o
        WHERE o.client_id = p_client_id
          AND o.status = 'delivered'
          AND o.created_at::DATE BETWEEN v_start AND v_end
          AND (p_product_id IS NULL OR o.product_id = p_product_id)
        GROUP BY o.created_at::DATE
    ),
    daily_expenses AS (
        SELECT
            be.expenditure_date AS dt,
            COALESCE(SUM(be.amount), 0.00) AS expenses
        FROM public.business_expenditures be
        WHERE be.client_id = p_client_id
          AND be.entity_type = 'merchant'
          AND be.expenditure_date BETWEEN v_start AND v_end
          AND (p_product_id IS NULL OR be.product_id = p_product_id OR be.product_id IS NULL)
        GROUP BY be.expenditure_date
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'date', ds.dt,
            'sales', COALESCE(s.sales, 0.00),
            'expenditure', COALESCE(e.expenses, 0.00),
            'units_sold', COALESCE(s.units, 0),
            'net_margin', COALESCE(s.sales, 0.00) - COALESCE(e.expenses, 0.00)
        ) ORDER BY ds.dt ASC
    )
    INTO v_daily_trends
    FROM date_series ds
    LEFT JOIN daily_sales s ON ds.dt = s.dt
    LEFT JOIN daily_expenses e ON ds.dt = e.dt;

    -- 7. REVENUE BY STATE DISTRIBUTION (Donut Chart)
    SELECT jsonb_agg(
        jsonb_build_object(
            'state', state_data.state,
            'order_count', state_data.order_count,
            'revenue', state_data.revenue
        ) ORDER BY state_data.revenue DESC
    )
    INTO v_state_distribution
    FROM (
        SELECT
            COALESCE(NULLIF(o.customer_state, ''), 'Federal Capital Territory') AS state,
            COUNT(o.id) AS order_count,
            COALESCE(SUM(o.total_amount), 0.00) AS revenue
        FROM public.orders o
        WHERE o.client_id = p_client_id
          AND o.status = 'delivered'
          AND o.created_at::DATE BETWEEN v_start AND v_end
          AND (p_product_id IS NULL OR o.product_id = p_product_id)
        GROUP BY COALESCE(NULLIF(o.customer_state, ''), 'Federal Capital Territory')
    ) state_data;

    -- 8. PRODUCT UNIT ECONOMICS (if specific product selected)
    IF p_product_id IS NOT NULL THEN
        SELECT jsonb_build_object(
            'product_id', p.id,
            'product_name', p.name,
            'sku', p.sku,
            'base_price', p.base_price,
            'cost_price', p.cost_price,
            'units_sold', v_quantity_sold,
            'direct_revenue', v_sales_revenue,
            'direct_advertising', v_advertisement_exp,
            'direct_procurement', v_procurement_exp
        )
        INTO v_product_info
        FROM public.products p
        WHERE p.id = p_product_id;
    END IF;

    -- BUILD CONSOLIDATED JSON RESPONSE
    RETURN jsonb_build_object(
        'client_id', p_client_id,
        'product_id', p_product_id,
        'start_date', v_start,
        'end_date', v_end,
        'sales_revenue', v_sales_revenue,
        'total_expenditures', v_total_expenditures,
        'quantity_sold', v_quantity_sold,
        'net_profit', v_net_profit,
        'available_stock', v_available_stock,
        'advertisement_expenditure', v_advertisement_exp,
        'procurement_expenditure', v_procurement_exp,
        'revenue_till_date', v_revenue_till_date,
        'daily_trends', COALESCE(v_daily_trends, '[]'::jsonb),
        'state_distribution', COALESCE(v_state_distribution, '[]'::jsonb),
        'product_economics', v_product_info
    );
END;
$$;

-- 2. FIX fn_get_dc_logistics_dashboard
CREATE OR REPLACE FUNCTION public.fn_get_dc_logistics_dashboard(
    p_dc_id UUID DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_start DATE;
    v_end DATE;
    v_logistics_gross_revenue NUMERIC(14, 2) := 0.00;
    v_network_opex NUMERIC(14, 2) := 0.00;
    v_total_parcels_handled INT := 0;
    v_net_logistics_margin NUMERIC(14, 2) := 0.00;
    v_vault_inventory INT := 0;
    v_rider_allowances NUMERIC(14, 2) := 0.00;
    v_facility_capex NUMERIC(14, 2) := 0.00;
    v_cumulative_revenue NUMERIC(14, 2) := 0.00;
    v_dc_breakdown JSONB := '[]'::jsonb;
BEGIN
    v_end := COALESCE(p_end_date, CURRENT_DATE);
    v_start := COALESCE(p_start_date, v_end - INTERVAL '30 days');

    -- 1. LOGISTICS REVENUE & PARCEL VOLUMES (using distribution_center_id)
    SELECT
        COALESCE(SUM(o.client_delivery_fee), 0.00),
        COUNT(o.id)
    INTO
        v_logistics_gross_revenue,
        v_total_parcels_handled
    FROM public.orders o
    WHERE o.status = 'delivered'
      AND o.created_at::DATE BETWEEN v_start AND v_end
      AND (p_dc_id IS NULL OR o.distribution_center_id = p_dc_id);

    -- 2. OPERATIONAL EXPENDITURES
    SELECT
        COALESCE(SUM(be.amount), 0.00),
        COALESCE(SUM(CASE WHEN be.category = 'rider_allowance' THEN be.amount ELSE 0.00 END), 0.00),
        COALESCE(SUM(CASE WHEN be.category IN ('rent_utilities', 'equipment_maintenance', 'diesel_fuel') THEN be.amount ELSE 0.00 END), 0.00)
    INTO
        v_network_opex,
        v_rider_allowances,
        v_facility_capex
    FROM public.business_expenditures be
    WHERE be.entity_type IN ('grand_dc', 'sub_dc')
      AND be.expenditure_date BETWEEN v_start AND v_end
      AND (p_dc_id IS NULL OR be.distribution_center_id = p_dc_id);

    -- 3. NET LOGISTICS PLATFORM PROFIT
    v_net_logistics_margin := v_logistics_gross_revenue - v_network_opex;

    -- 4. VAULT INVENTORY COUNT (using balance_qty)
    SELECT COALESCE(SUM(csb.balance_qty), 0)
    INTO v_vault_inventory
    FROM public.client_stock_balances csb;

    -- 5. CUMULATIVE REVENUE TO DATE
    SELECT COALESCE(SUM(o.client_delivery_fee), 0.00)
    INTO v_cumulative_revenue
    FROM public.orders o
    WHERE o.status = 'delivered'
      AND (p_dc_id IS NULL OR o.distribution_center_id = p_dc_id);

    -- 6. DC BREAKDOWN
    IF p_dc_id IS NULL THEN
        SELECT jsonb_agg(
            jsonb_build_object(
                'dc_id', dc_data.id,
                'dc_name', dc_data.name,
                'city', dc_data.city,
                'parcels', dc_data.parcels,
                'revenue', dc_data.revenue
            ) ORDER BY dc_data.revenue DESC
        )
        INTO v_dc_breakdown
        FROM (
            SELECT
                dc.id,
                dc.name,
                dc.city,
                COUNT(o.id) AS parcels,
                COALESCE(SUM(o.client_delivery_fee), 0.00) AS revenue
            FROM public.distribution_centers dc
            LEFT JOIN public.orders o ON o.distribution_center_id = dc.id 
                AND o.status = 'delivered' 
                AND o.created_at::DATE BETWEEN v_start AND v_end
            GROUP BY dc.id, dc.name, dc.city
        ) dc_data;
    END IF;

    RETURN jsonb_build_object(
        'dc_id', p_dc_id,
        'start_date', v_start,
        'end_date', v_end,
        'logistics_gross_revenue', v_logistics_gross_revenue,
        'network_opex', v_network_opex,
        'total_parcels_handled', v_total_parcels_handled,
        'net_logistics_margin', v_net_logistics_margin,
        'vault_inventory', v_vault_inventory,
        'rider_allowances', v_rider_allowances,
        'facility_capex', v_facility_capex,
        'cumulative_revenue', v_cumulative_revenue,
        'dc_breakdown', COALESCE(v_dc_breakdown, '[]'::jsonb)
    );
END;
$$;

SELECT pg_notify('pgrst', 'reload schema');


-- =================== 20261011154500_fix_rpc_uuid_text_casting.sql ===================
-- ============================================================================
-- MIGRATION: 20261011154500_fix_rpc_uuid_text_casting.sql
-- DESCRIPTION: Ensure robust type casting (UUID to TEXT) in financial RPC
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_get_merchant_financial_dashboard(
    p_client_id UUID,
    p_product_id UUID DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_start DATE;
    v_end DATE;
    v_sales_revenue NUMERIC(14, 2) := 0.00;
    v_total_expenditures NUMERIC(14, 2) := 0.00;
    v_quantity_sold INT := 0;
    v_net_profit NUMERIC(14, 2) := 0.00;
    v_available_stock INT := 0;
    v_advertisement_exp NUMERIC(14, 2) := 0.00;
    v_procurement_exp NUMERIC(14, 2) := 0.00;
    v_revenue_till_date NUMERIC(14, 2) := 0.00;
    v_daily_trends JSONB := '[]'::jsonb;
    v_state_distribution JSONB := '[]'::jsonb;
    v_product_info JSONB := NULL;
BEGIN
    -- Fallback to default date window (last 30 days if null)
    v_end := COALESCE(p_end_date, CURRENT_DATE);
    v_start := COALESCE(p_start_date, v_end - INTERVAL '30 days');

    -- 1. SALES REVENUE & QUANTITY SOLD (Delivered orders in date window)
    SELECT
        COALESCE(SUM(o.total_amount), 0.00),
        COALESCE(SUM(o.quantity), 0)
    INTO
        v_sales_revenue,
        v_quantity_sold
    FROM public.orders o
    WHERE o.client_id = p_client_id
      AND o.status = 'delivered'
      AND o.created_at::DATE BETWEEN v_start AND v_end
      AND (p_product_id IS NULL OR o.product_id = p_product_id);

    -- 2. TOTAL EXPENDITURES (Category Breakdowns)
    SELECT
        COALESCE(SUM(be.amount), 0.00),
        COALESCE(SUM(CASE WHEN be.category = 'advertisement' THEN be.amount ELSE 0.00 END), 0.00),
        COALESCE(SUM(CASE WHEN be.category = 'procurement' THEN be.amount ELSE 0.00 END), 0.00)
    INTO
        v_total_expenditures,
        v_advertisement_exp,
        v_procurement_exp
    FROM public.business_expenditures be
    WHERE be.client_id = p_client_id
      AND be.entity_type = 'merchant'
      AND be.expenditure_date BETWEEN v_start AND v_end
      AND (
          p_product_id IS NULL 
          OR be.product_id = p_product_id 
          OR be.product_id IS NULL
      );

    -- 3. NET PROFIT (Sales Revenue - Total Expenditures)
    v_net_profit := v_sales_revenue - v_total_expenditures;

    -- 4. AVAILABLE STOCK (Casting to text to match client_stock_balances column types)
    SELECT
        COALESCE(SUM(csb.balance_qty), 0)
    INTO
        v_available_stock
    FROM public.client_stock_balances csb
    WHERE csb.client_id::text = p_client_id::text
      AND (p_product_id IS NULL OR csb.product_id::text = p_product_id::text);

    -- 5. REVENUE TILL DATE (All delivered revenue since inception)
    SELECT
        COALESCE(SUM(o.total_amount), 0.00)
    INTO
        v_revenue_till_date
    FROM public.orders o
    WHERE o.client_id = p_client_id
      AND o.status = 'delivered'
      AND (p_product_id IS NULL OR o.product_id = p_product_id);

    -- 6. DAILY TRENDS (Grouped Bar Chart data: Sales vs Expenditures)
    WITH date_series AS (
        SELECT generate_series(v_start, v_end, '1 day'::interval)::DATE AS dt
    ),
    daily_sales AS (
        SELECT
            o.created_at::DATE AS dt,
            COALESCE(SUM(o.total_amount), 0.00) AS sales,
            COALESCE(SUM(o.quantity), 0) AS units
        FROM public.orders o
        WHERE o.client_id = p_client_id
          AND o.status = 'delivered'
          AND o.created_at::DATE BETWEEN v_start AND v_end
          AND (p_product_id IS NULL OR o.product_id = p_product_id)
        GROUP BY o.created_at::DATE
    ),
    daily_expenses AS (
        SELECT
            be.expenditure_date AS dt,
            COALESCE(SUM(be.amount), 0.00) AS expenses
        FROM public.business_expenditures be
        WHERE be.client_id = p_client_id
          AND be.entity_type = 'merchant'
          AND be.expenditure_date BETWEEN v_start AND v_end
          AND (p_product_id IS NULL OR be.product_id = p_product_id OR be.product_id IS NULL)
        GROUP BY be.expenditure_date
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'date', ds.dt,
            'sales', COALESCE(s.sales, 0.00),
            'expenditure', COALESCE(e.expenses, 0.00),
            'units_sold', COALESCE(s.units, 0),
            'net_margin', COALESCE(s.sales, 0.00) - COALESCE(e.expenses, 0.00)
        ) ORDER BY ds.dt ASC
    )
    INTO v_daily_trends
    FROM date_series ds
    LEFT JOIN daily_sales s ON ds.dt = s.dt
    LEFT JOIN daily_expenses e ON ds.dt = e.dt;

    -- 7. REVENUE BY STATE DISTRIBUTION (Donut Chart)
    SELECT jsonb_agg(
        jsonb_build_object(
            'state', state_data.state,
            'order_count', state_data.order_count,
            'revenue', state_data.revenue
        ) ORDER BY state_data.revenue DESC
    )
    INTO v_state_distribution
    FROM (
        SELECT
            COALESCE(NULLIF(o.customer_state, ''), 'Federal Capital Territory') AS state,
            COUNT(o.id) AS order_count,
            COALESCE(SUM(o.total_amount), 0.00) AS revenue
        FROM public.orders o
        WHERE o.client_id = p_client_id
          AND o.status = 'delivered'
          AND o.created_at::DATE BETWEEN v_start AND v_end
          AND (p_product_id IS NULL OR o.product_id = p_product_id)
        GROUP BY COALESCE(NULLIF(o.customer_state, ''), 'Federal Capital Territory')
    ) state_data;

    -- 8. PRODUCT UNIT ECONOMICS (if specific product selected)
    IF p_product_id IS NOT NULL THEN
        SELECT jsonb_build_object(
            'product_id', p.id,
            'product_name', p.name,
            'sku', p.sku,
            'base_price', p.base_price,
            'cost_price', p.cost_price,
            'units_sold', v_quantity_sold,
            'direct_revenue', v_sales_revenue,
            'direct_advertising', v_advertisement_exp,
            'direct_procurement', v_procurement_exp
        )
        INTO v_product_info
        FROM public.products p
        WHERE p.id = p_product_id;
    END IF;

    -- BUILD CONSOLIDATED JSON RESPONSE
    RETURN jsonb_build_object(
        'client_id', p_client_id,
        'product_id', p_product_id,
        'start_date', v_start,
        'end_date', v_end,
        'sales_revenue', v_sales_revenue,
        'total_expenditures', v_total_expenditures,
        'quantity_sold', v_quantity_sold,
        'net_profit', v_net_profit,
        'available_stock', v_available_stock,
        'advertisement_expenditure', v_advertisement_exp,
        'procurement_expenditure', v_procurement_exp,
        'revenue_till_date', v_revenue_till_date,
        'daily_trends', COALESCE(v_daily_trends, '[]'::jsonb),
        'state_distribution', COALESCE(v_state_distribution, '[]'::jsonb),
        'product_economics', v_product_info
    );
END;
$$;

SELECT pg_notify('pgrst', 'reload schema');


-- =================== 20261011155000_fix_delivery_state_column.sql ===================
-- ============================================================================
-- MIGRATION: 20261011155000_fix_delivery_state_column.sql
-- DESCRIPTION: Use o.delivery_state in fn_get_merchant_financial_dashboard
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_get_merchant_financial_dashboard(
    p_client_id UUID,
    p_product_id UUID DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_start DATE;
    v_end DATE;
    v_sales_revenue NUMERIC(14, 2) := 0.00;
    v_total_expenditures NUMERIC(14, 2) := 0.00;
    v_quantity_sold INT := 0;
    v_net_profit NUMERIC(14, 2) := 0.00;
    v_available_stock INT := 0;
    v_advertisement_exp NUMERIC(14, 2) := 0.00;
    v_procurement_exp NUMERIC(14, 2) := 0.00;
    v_revenue_till_date NUMERIC(14, 2) := 0.00;
    v_daily_trends JSONB := '[]'::jsonb;
    v_state_distribution JSONB := '[]'::jsonb;
    v_product_info JSONB := NULL;
BEGIN
    -- Fallback to default date window (last 30 days if null)
    v_end := COALESCE(p_end_date, CURRENT_DATE);
    v_start := COALESCE(p_start_date, v_end - INTERVAL '30 days');

    -- 1. SALES REVENUE & QUANTITY SOLD (Delivered orders in date window)
    SELECT
        COALESCE(SUM(o.total_amount), 0.00),
        COALESCE(SUM(o.quantity), 0)
    INTO
        v_sales_revenue,
        v_quantity_sold
    FROM public.orders o
    WHERE o.client_id = p_client_id
      AND o.status = 'delivered'
      AND o.created_at::DATE BETWEEN v_start AND v_end
      AND (p_product_id IS NULL OR o.product_id = p_product_id);

    -- 2. TOTAL EXPENDITURES (Category Breakdowns)
    SELECT
        COALESCE(SUM(be.amount), 0.00),
        COALESCE(SUM(CASE WHEN be.category = 'advertisement' THEN be.amount ELSE 0.00 END), 0.00),
        COALESCE(SUM(CASE WHEN be.category = 'procurement' THEN be.amount ELSE 0.00 END), 0.00)
    INTO
        v_total_expenditures,
        v_advertisement_exp,
        v_procurement_exp
    FROM public.business_expenditures be
    WHERE be.client_id = p_client_id
      AND be.entity_type = 'merchant'
      AND be.expenditure_date BETWEEN v_start AND v_end
      AND (
          p_product_id IS NULL 
          OR be.product_id = p_product_id 
          OR be.product_id IS NULL
      );

    -- 3. NET PROFIT (Sales Revenue - Total Expenditures)
    v_net_profit := v_sales_revenue - v_total_expenditures;

    -- 4. AVAILABLE STOCK (Casting to text to match client_stock_balances column types)
    SELECT
        COALESCE(SUM(csb.balance_qty), 0)
    INTO
        v_available_stock
    FROM public.client_stock_balances csb
    WHERE csb.client_id::text = p_client_id::text
      AND (p_product_id IS NULL OR csb.product_id::text = p_product_id::text);

    -- 5. REVENUE TILL DATE (All delivered revenue since inception)
    SELECT
        COALESCE(SUM(o.total_amount), 0.00)
    INTO
        v_revenue_till_date
    FROM public.orders o
    WHERE o.client_id = p_client_id
      AND o.status = 'delivered'
      AND (p_product_id IS NULL OR o.product_id = p_product_id);

    -- 6. DAILY TRENDS (Grouped Bar Chart data: Sales vs Expenditures)
    WITH date_series AS (
        SELECT generate_series(v_start, v_end, '1 day'::interval)::DATE AS dt
    ),
    daily_sales AS (
        SELECT
            o.created_at::DATE AS dt,
            COALESCE(SUM(o.total_amount), 0.00) AS sales,
            COALESCE(SUM(o.quantity), 0) AS units
        FROM public.orders o
        WHERE o.client_id = p_client_id
          AND o.status = 'delivered'
          AND o.created_at::DATE BETWEEN v_start AND v_end
          AND (p_product_id IS NULL OR o.product_id = p_product_id)
        GROUP BY o.created_at::DATE
    ),
    daily_expenses AS (
        SELECT
            be.expenditure_date AS dt,
            COALESCE(SUM(be.amount), 0.00) AS expenses
        FROM public.business_expenditures be
        WHERE be.client_id = p_client_id
          AND be.entity_type = 'merchant'
          AND be.expenditure_date BETWEEN v_start AND v_end
          AND (p_product_id IS NULL OR be.product_id = p_product_id OR be.product_id IS NULL)
        GROUP BY be.expenditure_date
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'date', ds.dt,
            'sales', COALESCE(s.sales, 0.00),
            'expenditure', COALESCE(e.expenses, 0.00),
            'units_sold', COALESCE(s.units, 0),
            'net_margin', COALESCE(s.sales, 0.00) - COALESCE(e.expenses, 0.00)
        ) ORDER BY ds.dt ASC
    )
    INTO v_daily_trends
    FROM date_series ds
    LEFT JOIN daily_sales s ON ds.dt = s.dt
    LEFT JOIN daily_expenses e ON ds.dt = e.dt;

    -- 7. REVENUE BY STATE DISTRIBUTION (Using delivery_state)
    SELECT jsonb_agg(
        jsonb_build_object(
            'state', state_data.state,
            'order_count', state_data.order_count,
            'revenue', state_data.revenue
        ) ORDER BY state_data.revenue DESC
    )
    INTO v_state_distribution
    FROM (
        SELECT
            COALESCE(NULLIF(o.delivery_state, ''), 'Federal Capital Territory') AS state,
            COUNT(o.id) AS order_count,
            COALESCE(SUM(o.total_amount), 0.00) AS revenue
        FROM public.orders o
        WHERE o.client_id = p_client_id
          AND o.status = 'delivered'
          AND o.created_at::DATE BETWEEN v_start AND v_end
          AND (p_product_id IS NULL OR o.product_id = p_product_id)
        GROUP BY COALESCE(NULLIF(o.delivery_state, ''), 'Federal Capital Territory')
    ) state_data;

    -- 8. PRODUCT UNIT ECONOMICS (if specific product selected)
    IF p_product_id IS NOT NULL THEN
        SELECT jsonb_build_object(
            'product_id', p.id,
            'product_name', p.name,
            'sku', p.sku,
            'base_price', p.base_price,
            'cost_price', p.cost_price,
            'units_sold', v_quantity_sold,
            'direct_revenue', v_sales_revenue,
            'direct_advertising', v_advertisement_exp,
            'direct_procurement', v_procurement_exp
        )
        INTO v_product_info
        FROM public.products p
        WHERE p.id = p_product_id;
    END IF;

    -- BUILD CONSOLIDATED JSON RESPONSE
    RETURN jsonb_build_object(
        'client_id', p_client_id,
        'product_id', p_product_id,
        'start_date', v_start,
        'end_date', v_end,
        'sales_revenue', v_sales_revenue,
        'total_expenditures', v_total_expenditures,
        'quantity_sold', v_quantity_sold,
        'net_profit', v_net_profit,
        'available_stock', v_available_stock,
        'advertisement_expenditure', v_advertisement_exp,
        'procurement_expenditure', v_procurement_exp,
        'revenue_till_date', v_revenue_till_date,
        'daily_trends', COALESCE(v_daily_trends, '[]'::jsonb),
        'state_distribution', COALESCE(v_state_distribution, '[]'::jsonb),
        'product_economics', v_product_info
    );
END;
$$;

SELECT pg_notify('pgrst', 'reload schema');


-- =================== 20261011160000_allow_nullable_product_for_b2b_orders.sql ===================
-- ============================================================================
-- MIGRATION: 20261011160000_allow_nullable_product_for_b2b_orders.sql
-- DESCRIPTION: Allow product_id and base_price to be nullable for client_package orders
-- ============================================================================

ALTER TABLE public.orders
    ALTER COLUMN product_id DROP NOT NULL,
    ALTER COLUMN base_price DROP NOT NULL;

SELECT pg_notify('pgrst', 'reload schema');


-- =================== 20261011161500_link_b2b_client_to_merchant_and_conversations.sql ===================
-- ============================================================================
-- MIGRATION: 20261011161500_link_b2b_client_to_merchant_and_conversations.sql
-- DESCRIPTION: Allow nullable client_id on order_conversations and register ComfortCare in clients
-- ============================================================================

-- 1. Make client_id nullable on order_conversations to prevent trigger failure
ALTER TABLE public.order_conversations
    ALTER COLUMN client_id DROP NOT NULL;

-- 2. Register ComfortCare Health & Pharmacy Ltd in public.clients table
INSERT INTO public.clients (
    id,
    company_id,
    name,
    code,
    company_name,
    email,
    phone,
    address,
    city,
    state,
    is_active
) VALUES (
    'c3333333-3333-4333-8333-333333333333',
    '11111111-1111-4111-8111-111111111111',
    'ComfortCare Health & Pharmacy Ltd',
    'COMFORTCARE',
    'ComfortCare Health & Pharmacy Ltd',
    'dispatch@comfortcare.ng',
    '+2348032651505',
    'Abuja Central Commercial Corridor, FCT, Nigeria',
    'Abuja',
    'Federal Capital Territory',
    true
) ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    company_name = EXCLUDED.company_name;

-- 3. Add merchant_client_id column to b2b_clients and link to ComfortCare
ALTER TABLE public.b2b_clients
    ADD COLUMN IF NOT EXISTS merchant_client_id UUID REFERENCES public.clients(id) ON DELETE SET NULL;

UPDATE public.b2b_clients
SET merchant_client_id = 'c3333333-3333-4333-8333-333333333333'
WHERE id = 'comfortcare-abuja-01';

SELECT pg_notify('pgrst', 'reload schema');


-- =================== 20261011163000_fix_pod_signature_column_in_otp_rpc.sql ===================
-- ============================================================================
-- MIGRATION: 20261011163000_fix_pod_signature_column_in_otp_rpc.sql
-- DESCRIPTION: Use proof_of_delivery_url in fn_verify_delivery_otp_and_complete
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_verify_delivery_otp_and_complete(
    p_order_id UUID,
    p_entered_otp TEXT,
    p_agent_id UUID,
    p_recipient_signature_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_expected_otp TEXT;
    v_rider_allowance NUMERIC(12, 2);
    v_fulfillment_type TEXT;
BEGIN
    SELECT delivery_otp, rider_pickup_allowance, fulfillment_type
    INTO v_expected_otp, v_rider_allowance, v_fulfillment_type
    FROM public.orders
    WHERE id = p_order_id;

    IF v_expected_otp IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Order not found.');
    END IF;

    IF trim(v_expected_otp) != trim(p_entered_otp) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Invalid OTP! Recipient verification failed.');
    END IF;

    -- Update order to delivered using proof_of_delivery_url
    UPDATE public.orders
    SET status = 'delivered',
        delivered_at = NOW(),
        otp_verified_at = NOW(),
        proof_of_delivery_url = COALESCE(p_recipient_signature_url, proof_of_delivery_url)
    WHERE id = p_order_id;

    -- If this was a client package with extra rider allowance, credit the rider
    IF v_fulfillment_type = 'client_package' AND v_rider_allowance > 0 THEN
        UPDATE public.delivery_agents
        SET current_balance = COALESCE(current_balance, 0.00) + v_rider_allowance
        WHERE id = p_agent_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Delivery completed and verified via OTP.',
        'order_id', p_order_id,
        'rider_credited_amount', v_rider_allowance
    );
END;
$$;

SELECT pg_notify('pgrst', 'reload schema');


-- =================== 20261011164500_fix_rider_payout_in_otp_rpc.sql ===================
-- ============================================================================
-- MIGRATION: 20261011164500_fix_rider_payout_in_otp_rpc.sql
-- DESCRIPTION: Credit rider direct_transfer_balance and record rider_transactions
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_verify_delivery_otp_and_complete(
    p_order_id UUID,
    p_entered_otp TEXT,
    p_agent_id UUID,
    p_recipient_signature_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_expected_otp TEXT;
    v_rider_allowance NUMERIC(12, 2);
    v_fulfillment_type TEXT;
    v_order_num TEXT;
BEGIN
    SELECT delivery_otp, rider_pickup_allowance, fulfillment_type, order_number
    INTO v_expected_otp, v_rider_allowance, v_fulfillment_type, v_order_num
    FROM public.orders
    WHERE id = p_order_id;

    IF v_expected_otp IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Order not found.');
    END IF;

    IF trim(v_expected_otp) != trim(p_entered_otp) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Invalid OTP! Recipient verification failed.');
    END IF;

    -- Update order to delivered using proof_of_delivery_url
    UPDATE public.orders
    SET status = 'delivered',
        delivered_at = NOW(),
        otp_verified_at = NOW(),
        proof_of_delivery_url = COALESCE(p_recipient_signature_url, proof_of_delivery_url)
    WHERE id = p_order_id;

    -- If this was a client package with extra rider allowance, credit the rider
    IF v_fulfillment_type = 'client_package' AND v_rider_allowance > 0 AND p_agent_id IS NOT NULL THEN
        UPDATE public.delivery_agents
        SET direct_transfer_balance = COALESCE(direct_transfer_balance, 0.00) + v_rider_allowance
        WHERE id = p_agent_id;

        INSERT INTO public.rider_transactions (
            delivery_agent_id,
            transaction_code,
            title,
            category,
            amount,
            is_credit,
            reference,
            status,
            description
        ) VALUES (
            p_agent_id,
            'TXN-B2B-' || substring(p_order_id::text, 1, 8),
            'B2B Multi-Stop Delivery Payout (' || COALESCE(v_order_num, '') || ')',
            'delivery_payout',
            v_rider_allowance,
            true,
            p_order_id::text,
            'completed',
            'Completed multi-stop client package delivery and collected recipient OTP'
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Delivery completed and verified via OTP.',
        'order_id', p_order_id,
        'rider_credited_amount', v_rider_allowance
    );
END;
$$;

SELECT pg_notify('pgrst', 'reload schema');


-- =================== 20261011170000_fix_client_stock_invoice_and_consignment_handshake.sql ===================
-- Migration: 20261011170000_fix_client_stock_invoice_and_consignment_handshake.sql
-- Description: Fix client_stock_invoices check constraint and fn_create_dc_consignment_for_intake_invoice column alignment

-- 1. Relax/Update status check constraint on client_stock_invoices
ALTER TABLE public.client_stock_invoices DROP CONSTRAINT IF EXISTS client_stock_invoices_status_check;
ALTER TABLE public.client_stock_invoices ADD CONSTRAINT client_stock_invoices_status_check 
    CHECK (status IN ('draft', 'pending_inspection', 'in_transit', 'received', 'verified', 'cancelled', 'discrepancy'));

-- 2. Stored Procedure: fn_create_dc_consignment_for_intake_invoice
CREATE OR REPLACE FUNCTION public.fn_create_dc_consignment_for_intake_invoice(
    p_invoice_id UUID,
    p_sender_id UUID DEFAULT NULL,
    p_sender_name TEXT DEFAULT '',
    p_sender_signature_url TEXT DEFAULT '',
    p_carrier_driver_name TEXT DEFAULT '',
    p_carrier_phone TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_inv RECORD;
    v_item RECORD;
    v_dc_id UUID;
    v_company_id UUID;
    v_transfer_id UUID;
    v_prod_id UUID;
    v_waybill TEXT;
    v_dc_name TEXT;
    v_total_units INT := 0;
BEGIN
    SELECT * INTO v_inv FROM public.client_stock_invoices WHERE id = p_invoice_id;
    IF v_inv IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invoice not found');
    END IF;

    -- Match targeted receiving DC across ANY tier (Grand DC, Hub DC, or General DC)
    SELECT id, name INTO v_dc_id, v_dc_name FROM public.distribution_centers 
    WHERE name ILIKE '%' || SPLIT_PART(v_inv.destination_warehouse, ' - ', 1) || '%'
       OR v_inv.destination_warehouse ILIKE '%' || name || '%'
       OR v_inv.destination_warehouse ILIKE '%' || state || '%'
       OR v_inv.destination_warehouse ILIKE '%' || code || '%'
    LIMIT 1;

    -- If not matched, default to Grand DC (Wuse Central branch default)
    IF v_dc_id IS NULL THEN
        SELECT id, name INTO v_dc_id, v_dc_name FROM public.distribution_centers 
        WHERE dc_type = 'grand_dc' OR is_grand_dc = true OR code = 'DC-WUSE-01'
        ORDER BY created_at ASC LIMIT 1;
    END IF;

    -- Final fallback
    IF v_dc_id IS NULL THEN
        SELECT id, name INTO v_dc_id, v_dc_name FROM public.distribution_centers LIMIT 1;
    END IF;

    -- Resolve company_id
    SELECT company_id INTO v_company_id FROM public.clients WHERE id = v_inv.client_id::UUID;
    IF v_company_id IS NULL THEN
        SELECT id INTO v_company_id FROM public.companies LIMIT 1;
    END IF;

    v_waybill := COALESCE(NULLIF(v_inv.waybill_number, ''), 'WB-INTAKE-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0'));

    -- Ensure invoice has the waybill number and initial status is 'in_transit'
    UPDATE public.client_stock_invoices
    SET waybill_number = v_waybill,
        status = 'in_transit',
        updated_at = NOW()
    WHERE id = p_invoice_id;

    -- Create pending stock transfer for DC custody acceptance
    INSERT INTO public.stock_transfers (
        company_id,
        client_id,
        invoice_id,
        transfer_type,
        transfer_number,
        waybill_number,
        destination_dc_id,
        status,
        sender_id,
        sender_name,
        sender_role,
        sender_signature_url,
        carrier_driver_name,
        carrier_phone,
        dispatched_at,
        notes
    ) VALUES (
        v_company_id,
        v_inv.client_id::UUID,
        p_invoice_id,
        'client_supply',
        v_waybill,
        v_waybill,
        v_dc_id,
        'in_transit',
        p_sender_id,
        COALESCE(NULLIF(p_sender_name, ''), 'Merchant Procurement'),
        'client',
        p_sender_signature_url,
        p_carrier_driver_name,
        p_carrier_phone,
        NOW(),
        'Procurement Inbound Intake from ' || COALESCE(v_inv.supplier_name, 'Vendor') || ' (Bill: ' || v_inv.invoice_number || ')'
    ) RETURNING id INTO v_transfer_id;

    -- Copy line items into stock_transfer_items with robust UUID resolution and valid columns
    FOR v_item IN SELECT * FROM public.client_stock_invoice_items WHERE invoice_id = p_invoice_id
    LOOP
        v_prod_id := NULL;
        IF v_item.product_id IS NOT NULL AND v_item.product_id::TEXT ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
            v_prod_id := v_item.product_id::UUID;
        END IF;

        IF v_prod_id IS NULL THEN
            SELECT id INTO v_prod_id FROM public.products 
            WHERE sku = v_item.product_sku OR name ILIKE v_item.product_name 
            LIMIT 1;
        END IF;

        INSERT INTO public.stock_transfer_items (
            transfer_id,
            product_id,
            quantity_shipped,
            quantity_received,
            quantity_damaged,
            quantity_missing,
            item_notes
        ) VALUES (
            v_transfer_id,
            v_prod_id,
            v_item.quantity,
            0,
            0,
            0,
            v_item.product_name || ' (SKU: ' || v_item.product_sku || ')'
        );
        v_total_units := v_total_units + v_item.quantity;
    END LOOP;

    -- Create/Sync DC Supply Intake Record if table exists
    BEGIN
        INSERT INTO public.dc_supply_intake_records (
            invoice_id,
            transfer_id,
            distribution_center_id,
            company_id,
            waybill_number,
            expected_units,
            carrier_driver_name,
            carrier_phone,
            status,
            sender_id,
            sender_name,
            sender_signature_url,
            notes
        ) VALUES (
            p_invoice_id,
            v_transfer_id,
            v_dc_id,
            v_company_id,
            v_waybill,
            v_total_units,
            p_carrier_driver_name,
            p_carrier_phone,
            'pending_dock_arrival',
            p_sender_id,
            COALESCE(NULLIF(p_sender_name, ''), 'Merchant Procurement'),
            p_sender_signature_url,
            'Awaiting physical dock check-in at ' || COALESCE(v_dc_name, 'Hub')
        )
        ON CONFLICT (invoice_id) DO UPDATE
        SET transfer_id = EXCLUDED.transfer_id,
            distribution_center_id = EXCLUDED.distribution_center_id,
            expected_units = EXCLUDED.expected_units,
            updated_at = NOW();
    EXCEPTION WHEN OTHERS THEN
        -- Non-blocking if table is absent or schema mismatch
    END;

    -- Realtime Notification to DC Personnel
    BEGIN
        INSERT INTO public.notifications (
            company_id,
            title,
            message,
            category,
            action_route,
            is_read
        ) VALUES (
            v_company_id,
            'Inbound Consignment Dispatched: ' || v_waybill,
            'Merchant dispatched ' || v_total_units || ' units from ' || COALESCE(v_inv.supplier_name, 'Vendor') || ' to ' || COALESCE(v_dc_name, 'Hub') || '. Physical reception verification required.',
            'inventory',
            '/dc/stock',
            false
        );
    EXCEPTION WHEN OTHERS THEN
        -- Non-blocking
    END;

    RETURN jsonb_build_object(
        'success', true,
        'invoice_id', p_invoice_id,
        'transfer_id', v_transfer_id,
        'destination_dc_id', v_dc_id,
        'destination_dc_name', v_dc_name,
        'waybill_number', v_waybill,
        'total_units', v_total_units,
        'status', 'in_transit'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_create_dc_consignment_for_intake_invoice TO authenticated, service_role, anon;

