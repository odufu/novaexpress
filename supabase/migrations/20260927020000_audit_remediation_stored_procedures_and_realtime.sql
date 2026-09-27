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
