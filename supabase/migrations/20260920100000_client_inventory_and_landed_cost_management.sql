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
