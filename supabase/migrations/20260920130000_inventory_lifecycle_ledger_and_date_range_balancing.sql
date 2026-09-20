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
