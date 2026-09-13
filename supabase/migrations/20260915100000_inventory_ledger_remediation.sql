-- ============================================================================
-- Migration: 20260915100000_inventory_ledger_remediation.sql
-- Description: Inventory System & Product Accounting Overhaul:
--              1. Products schema extension (cost_price, barcode, weight_kg, low_stock_threshold)
--              2. Stock returns schema extension (destination_dc_id, condition, received_by/at)
--              3. Atomic dc_stocks synchronization in fn_receive_client_supply and fn_issue_dc_stock_to_rider
--              4. fn_confirm_order_delivery_stock (eliminates double stock deduction on POD delivery)
--              5. fn_receive_rider_stock_return (enables DC warehouse restock from rider returns)
--              6. Elimination of hardcoded ₦25,000 in fn_calculate_merchant_asset_custody
-- ============================================================================

-- 1. Extend products table
ALTER TABLE public.products
    ADD COLUMN IF NOT EXISTS cost_price NUMERIC(15,2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS barcode TEXT,
    ADD COLUMN IF NOT EXISTS weight_kg NUMERIC(8,3) DEFAULT 0.500,
    ADD COLUMN IF NOT EXISTS low_stock_threshold INT DEFAULT 10,
    ADD COLUMN IF NOT EXISTS damaged_count INT DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_products_barcode ON public.products(barcode);
CREATE INDEX IF NOT EXISTS idx_agent_inventory_agent_prod ON public.agent_inventory(delivery_agent_id, product_id);

-- 2. Extend stock_returns table
ALTER TABLE public.stock_returns
    ADD COLUMN IF NOT EXISTS destination_dc_id UUID REFERENCES public.distribution_centers(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS condition TEXT DEFAULT 'good',
    ADD COLUMN IF NOT EXISTS received_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS received_by UUID;

-- 3. Stored Procedure: fn_receive_client_supply (Synchronize dc_stocks JSONB)
CREATE OR REPLACE FUNCTION public.fn_receive_client_supply(
    p_transfer_id UUID,
    p_receiver_id UUID,
    p_receiver_name TEXT,
    p_receiver_signature_url TEXT,
    p_verified_items JSONB, -- Array of {item_id, quantity_received, quantity_damaged, quantity_missing, notes}
    p_notes TEXT DEFAULT ''
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_trf RECORD;
    v_item JSONB;
    v_item_id UUID;
    v_qty_rec INT;
    v_qty_dam INT;
    v_qty_mis INT;
    v_item_row RECORD;
    v_has_disc BOOLEAN := FALSE;
    v_status TEXT := 'completed';
    v_dc_id TEXT;
BEGIN
    SELECT * INTO v_trf FROM public.stock_transfers WHERE id = p_transfer_id;
    IF v_trf IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Stock transfer not found');
    END IF;

    v_dc_id := COALESCE(v_trf.destination_dc_id::TEXT, '');

    -- Process each verified item
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_verified_items)
    LOOP
        v_item_id := (v_item->>'item_id')::UUID;
        v_qty_rec := COALESCE((v_item->>'quantity_received')::INT, 0);
        v_qty_dam := COALESCE((v_item->>'quantity_damaged')::INT, 0);
        v_qty_mis := COALESCE((v_item->>'quantity_missing')::INT, 0);

        SELECT * INTO v_item_row FROM public.stock_transfer_items WHERE id = v_item_id AND transfer_id = p_transfer_id;
        IF v_item_row IS NOT NULL THEN
            IF v_qty_dam > 0 OR v_qty_mis > 0 OR v_qty_rec != v_item_row.quantity_shipped THEN
                v_has_disc := TRUE;
            END IF;

            UPDATE public.stock_transfer_items
            SET quantity_received = v_qty_rec,
                quantity_damaged = v_qty_dam,
                quantity_missing = v_qty_mis,
                item_notes = COALESCE(v_item->>'notes', item_notes)
            WHERE id = v_item_id;

            -- Atomically increment DC product inventory both globally and per-DC
            IF v_qty_rec > 0 AND v_item_row.product_id IS NOT NULL THEN
                UPDATE public.products
                SET stock_quantity = COALESCE(stock_quantity, 0) + v_qty_rec,
                    dc_stocks = CASE 
                        WHEN v_dc_id <> '' THEN
                            jsonb_set(
                                COALESCE(dc_stocks, '{}'::jsonb),
                                ARRAY[v_dc_id],
                                to_jsonb(COALESCE((dc_stocks->>v_dc_id)::INT, 0) + v_qty_rec)
                            )
                        ELSE COALESCE(dc_stocks, '{}'::jsonb)
                    END,
                    updated_at = NOW()
                WHERE id = v_item_row.product_id;
            END IF;

            -- Record damaged count if any
            IF v_qty_dam > 0 AND v_item_row.product_id IS NOT NULL THEN
                UPDATE public.products
                SET damaged_count = COALESCE(damaged_count, 0) + v_qty_dam,
                    updated_at = NOW()
                WHERE id = v_item_row.product_id;
            END IF;
        END IF;
    END LOOP;

    IF v_has_disc THEN
        v_status := 'discrepancy_reported';
    END IF;

    -- Update Transfer Header
    UPDATE public.stock_transfers
    SET status = v_status,
        receiver_id = p_receiver_id,
        receiver_name = p_receiver_name,
        receiver_role = 'dc_supervisor',
        receiver_signature_url = p_receiver_signature_url,
        received_at = NOW(),
        has_discrepancy = v_has_disc,
        discrepancy_notes = p_notes,
        updated_at = NOW()
    WHERE id = p_transfer_id;

    RETURN jsonb_build_object(
        'success', true,
        'transfer_id', p_transfer_id,
        'status', v_status
    );
END;
$$;

-- 4. Stored Procedure: fn_issue_dc_stock_to_rider (Synchronize dc_stocks JSONB)
CREATE OR REPLACE FUNCTION public.fn_issue_dc_stock_to_rider(
    p_dc_id UUID,
    p_rider_id UUID,
    p_items JSONB, -- Array of {product_id, quantity}
    p_sender_id UUID,
    p_sender_name TEXT,
    p_sender_signature_url TEXT,
    p_notes TEXT DEFAULT ''
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_company_id UUID;
    v_transfer_id UUID;
    v_waybill TEXT;
    v_item JSONB;
    v_prod_id UUID;
    v_qty INT;
    v_rider RECORD;
    v_wh_id UUID;
    v_dc_str TEXT;
BEGIN
    SELECT company_id INTO v_company_id FROM public.distribution_centers WHERE id = p_dc_id;
    IF v_company_id IS NULL THEN
        SELECT id INTO v_company_id FROM public.companies LIMIT 1;
    END IF;

    v_dc_str := p_dc_id::TEXT;

    -- Resolve Rider details & mobile warehouse
    SELECT * INTO v_rider FROM public.delivery_agents WHERE id = p_rider_id OR user_id = p_rider_id;
    IF v_rider IS NOT NULL THEN
        SELECT id INTO v_wh_id FROM public.warehouses WHERE rider_id = v_rider.id LIMIT 1;
    END IF;

    v_waybill := 'WB-RIDER-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');

    -- Create Stock Transfer in 'pending_rider_acceptance'
    INSERT INTO public.stock_transfers (
        company_id,
        transfer_type,
        transfer_number,
        waybill_number,
        source_dc_id,
        destination_warehouse_id,
        status,
        sender_id,
        sender_name,
        sender_role,
        sender_signature_url,
        dispatched_at,
        notes
    ) VALUES (
        v_company_id,
        'dc_to_rider',
        v_waybill,
        v_waybill,
        p_dc_id,
        v_wh_id,
        'pending_rider_acceptance',
        p_sender_id,
        p_sender_name,
        'dc_supervisor',
        p_sender_signature_url,
        NOW(),
        p_notes
    ) RETURNING id INTO v_transfer_id;

    -- Deduct from DC shelf stock (both globally and from the issuing DC's dc_stocks)
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_prod_id := (v_item->>'product_id')::UUID;
        v_qty := COALESCE((v_item->>'quantity')::INT, 0);

        IF v_qty > 0 THEN
            UPDATE public.products
            SET stock_quantity = GREATEST(0, COALESCE(stock_quantity, 0) - v_qty),
                dc_stocks = jsonb_set(
                    COALESCE(dc_stocks, '{}'::jsonb),
                    ARRAY[v_dc_str],
                    to_jsonb(GREATEST(0, COALESCE((dc_stocks->>v_dc_str)::INT, 0) - v_qty))
                ),
                updated_at = NOW()
            WHERE id = v_prod_id;

            INSERT INTO public.stock_transfer_items (
                transfer_id,
                product_id,
                quantity_shipped,
                quantity_received
            ) VALUES (
                v_transfer_id,
                v_prod_id,
                v_qty,
                0
            );
        END IF;
    END LOOP;

    -- Send Notification to Rider
    IF v_rider IS NOT NULL THEN
        INSERT INTO public.notifications (
            company_id,
            delivery_agent_id,
            title,
            message,
            category,
            action_route,
            is_read
        ) VALUES (
            v_company_id,
            v_rider.id,
            'New Stock Handover Awaiting Acceptance! 📦',
            'DC Supervisor ' || p_sender_name || ' issued stock to you (Waybill: ' || v_waybill || '). Please count and sign to accept custody.',
            'inventory',
            '/stock/handover/' || v_transfer_id,
            false
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'transfer_id', v_transfer_id,
        'waybill_number', v_waybill,
        'status', 'pending_rider_acceptance'
    );
END;
$$;

-- 5. Stored Procedure: fn_rider_accept_stock_handover (Restore DC stock on discrepancy)
CREATE OR REPLACE FUNCTION public.fn_rider_accept_stock_handover(
    p_transfer_id UUID,
    p_rider_id UUID,
    p_rider_name TEXT,
    p_rider_signature_url TEXT,
    p_verified_items JSONB DEFAULT NULL, -- Optional array of {item_id, quantity_received}
    p_notes TEXT DEFAULT ''
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_trf RECORD;
    v_item RECORD;
    v_rider RECORD;
    v_qty_rec INT;
    v_has_disc BOOLEAN := FALSE;
    v_dc_str TEXT;
BEGIN
    SELECT * INTO v_trf FROM public.stock_transfers WHERE id = p_transfer_id;
    IF v_trf IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Stock transfer not found');
    END IF;

    v_dc_str := COALESCE(v_trf.source_dc_id::TEXT, '');
    SELECT * INTO v_rider FROM public.delivery_agents WHERE id = p_rider_id OR user_id = p_rider_id;

    -- Update transfer items and commit stock to agent_inventory
    FOR v_item IN SELECT * FROM public.stock_transfer_items WHERE transfer_id = p_transfer_id
    LOOP
        v_qty_rec := v_item.quantity_shipped;

        IF p_verified_items IS NOT NULL THEN
            SELECT COALESCE((elem->>'quantity_received')::INT, v_item.quantity_shipped)
            INTO v_qty_rec
            FROM jsonb_array_elements(p_verified_items) elem
            WHERE (elem->>'item_id')::UUID = v_item.id;
        END IF;

        IF v_qty_rec != v_item.quantity_shipped THEN
            v_has_disc := TRUE;
            -- If rider received LESS, return difference back to DC shelf stock & dc_stocks
            IF v_qty_rec < v_item.quantity_shipped THEN
                UPDATE public.products
                SET stock_quantity = COALESCE(stock_quantity, 0) + (v_item.quantity_shipped - v_qty_rec),
                    dc_stocks = CASE 
                        WHEN v_dc_str <> '' THEN
                            jsonb_set(
                                COALESCE(dc_stocks, '{}'::jsonb),
                                ARRAY[v_dc_str],
                                to_jsonb(COALESCE((dc_stocks->>v_dc_str)::INT, 0) + (v_item.quantity_shipped - v_qty_rec))
                            )
                        ELSE COALESCE(dc_stocks, '{}'::jsonb)
                    END,
                    updated_at = NOW()
                WHERE id = v_item.product_id;
            END IF;
        END IF;

        UPDATE public.stock_transfer_items
        SET quantity_received = v_qty_rec
        WHERE id = v_item.id;

        -- Upsert agent_inventory
        IF v_rider IS NOT NULL AND v_item.product_id IS NOT NULL THEN
            INSERT INTO public.agent_inventory (
                delivery_agent_id,
                product_id,
                total_in_custody,
                available_count
            ) VALUES (
                v_rider.id,
                v_item.product_id,
                v_qty_rec,
                v_qty_rec
            )
            ON CONFLICT (delivery_agent_id, product_id)
            DO UPDATE SET
                total_in_custody = public.agent_inventory.total_in_custody + v_qty_rec,
                available_count = public.agent_inventory.available_count + v_qty_rec,
                updated_at = NOW();
        END IF;
    END LOOP;

    -- Mark transfer completed with rider signature
    UPDATE public.stock_transfers
    SET status = CASE WHEN v_has_disc THEN 'discrepancy_reported' ELSE 'completed' END,
        receiver_id = p_rider_id,
        receiver_name = p_rider_name,
        receiver_role = 'delivery_agent',
        receiver_signature_url = p_rider_signature_url,
        received_at = NOW(),
        has_discrepancy = v_has_disc,
        discrepancy_notes = p_notes,
        updated_at = NOW()
    WHERE id = p_transfer_id;

    RETURN jsonb_build_object(
        'success', true,
        'status', CASE WHEN v_has_disc THEN 'discrepancy_reported' ELSE 'completed' END,
        'transfer_id', p_transfer_id
    );
END;
$$;

-- 6. Stored Procedure: fn_confirm_order_delivery_stock
-- Eliminates double stock deduction on POD delivery!
-- Decrements agent_inventory and increments products.delivered_count WITHOUT touching products.stock_quantity.
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

    -- 1. Deduct physical units from rider custody in agent_inventory
    IF v_agent IS NOT NULL AND p_product_id IS NOT NULL THEN
        UPDATE public.agent_inventory
        SET available_count = GREATEST(0, COALESCE(available_count, 0) - v_qty),
            total_in_custody = GREATEST(0, COALESCE(total_in_custody, 0) - v_qty),
            delivered_count_today = COALESCE(delivered_count_today, 0) + v_qty,
            updated_at = NOW()
        WHERE delivery_agent_id = v_agent.id AND product_id = p_product_id;
    END IF;

    -- 2. Increment global delivered metrics on product
    IF p_product_id IS NOT NULL THEN
        UPDATE public.products
        SET delivered_count = COALESCE(delivered_count, 0) + v_qty,
            updated_at = NOW()
        WHERE id = p_product_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'deducted_quantity', v_qty
    );
END;
$$;

-- 7. Stored Procedure: fn_receive_rider_stock_return
-- Enables DC supervisor to receive returned items, credit warehouse inventory, and deduct rider custody.
CREATE OR REPLACE FUNCTION public.fn_receive_rider_stock_return(
    p_return_id UUID,
    p_dc_id UUID,
    p_receiver_id UUID,
    p_verified_quantity INT,
    p_condition TEXT DEFAULT 'good',
    p_notes TEXT DEFAULT ''
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_ret RECORD;
    v_dc_str TEXT;
    v_qty INT;
BEGIN
    SELECT * INTO v_ret FROM public.stock_returns WHERE id = p_return_id;
    IF v_ret IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Stock return not found');
    END IF;

    IF v_ret.status = 'approved' OR v_ret.status = 'completed' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Stock return already received');
    END IF;

    v_qty := GREATEST(0, COALESCE(p_verified_quantity, v_ret.quantity));
    v_dc_str := p_dc_id::TEXT;

    -- 1. Deduct from rider's custody in agent_inventory
    IF v_ret.delivery_agent_id IS NOT NULL AND v_ret.product_id IS NOT NULL THEN
        UPDATE public.agent_inventory
        SET total_in_custody = GREATEST(0, COALESCE(total_in_custody, 0) - v_qty),
            available_count = GREATEST(0, COALESCE(available_count, 0) - v_qty),
            returned_count = COALESCE(returned_count, 0) + v_qty,
            updated_at = NOW()
        WHERE delivery_agent_id = v_ret.delivery_agent_id AND product_id = v_ret.product_id;
    END IF;

    -- 2. Restock into DC shelf IF condition is 'good'
    IF p_condition = 'good' AND v_ret.product_id IS NOT NULL THEN
        UPDATE public.products
        SET stock_quantity = COALESCE(stock_quantity, 0) + v_qty,
            dc_stocks = jsonb_set(
                COALESCE(dc_stocks, '{}'::jsonb),
                ARRAY[v_dc_str],
                to_jsonb(COALESCE((dc_stocks->>v_dc_str)::INT, 0) + v_qty)
            ),
            updated_at = NOW()
        WHERE id = v_ret.product_id;
    ELSE
        -- Track as damaged
        IF v_ret.product_id IS NOT NULL THEN
            UPDATE public.products
            SET damaged_count = COALESCE(damaged_count, 0) + v_qty,
                updated_at = NOW()
            WHERE id = v_ret.product_id;
        END IF;
    END IF;

    -- 3. Update return record
    UPDATE public.stock_returns
    SET status = 'approved',
        destination_dc_id = p_dc_id,
        condition = p_condition,
        received_by = p_receiver_id,
        received_at = NOW(),
        quantity = v_qty,
        admin_notes = p_notes,
        updated_at = NOW()
    WHERE id = p_return_id;

    RETURN jsonb_build_object(
        'success', true,
        'return_id', p_return_id,
        'restocked_quantity', CASE WHEN p_condition = 'good' THEN v_qty ELSE 0 END,
        'damaged_quantity', CASE WHEN p_condition != 'good' THEN v_qty ELSE 0 END
    );
END;
$$;

-- 8. Stored Procedure: fn_calculate_merchant_asset_custody (Remove hardcoded 25000)
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
BEGIN
    -- 1. Liquid Cash in Custody (Delivered orders awaiting settlement)
    SELECT 
        COALESCE(SUM(CASE WHEN payment_method = 'paystack' OR payment_type = 'prepaid' THEN (total_amount - COALESCE(client_delivery_fee, 3500.00)) ELSE 0 END), 0.00),
        COALESCE(SUM(CASE WHEN payment_method = 'cash' AND payment_type = 'pay_on_delivery' THEN (total_amount - COALESCE(client_delivery_fee, 3500.00)) ELSE 0 END), 0.00)
    INTO v_cash_in_paystack, v_cash_in_dc_vault
    FROM public.orders
    WHERE client_id = p_client_id
      AND status = 'delivered'
      AND (financial_settlement_status IS NULL OR financial_settlement_status != 'client_settled')
      AND (p_dc_id IS NULL OR distribution_center_id = p_dc_id);

    v_total_liquid_cash := v_cash_in_paystack + v_cash_in_dc_vault;

    -- 2. In-Kind Inventory Custody & Dual Valuation
    FOR v_prod IN
        SELECT id, name, sku, base_price, cost_price, stock_quantity, available_count
        FROM public.products
        WHERE client_id = p_client_id OR client_name IN (SELECT company_name FROM public.clients WHERE id = p_client_id)
    LOOP
        DECLARE
            v_units INT := COALESCE(v_prod.stock_quantity, v_prod.available_count, 0);
            v_avg_price NUMERIC(14, 2);
            v_unit_val NUMERIC(14, 2);
        BEGIN
            v_total_units_in_custody := v_total_units_in_custody + v_units;
            v_unit_val := COALESCE(v_prod.base_price, 0.00);
            v_base_inventory_valuation := v_base_inventory_valuation + (v_units * v_unit_val);

            -- Calculate historical realized unit price factoring in package deals
            SELECT COALESCE(AVG(total_amount / NULLIF(quantity, 0)), v_unit_val)
            INTO v_avg_price
            FROM public.orders
            WHERE client_id = p_client_id AND product_name = v_prod.name AND status = 'delivered';

            v_weighted_retail_valuation := v_weighted_retail_valuation + (v_units * COALESCE(v_avg_price, v_unit_val));
        END;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'client_id', p_client_id,
        'liquid_cash_in_custody', v_total_liquid_cash,
        'physical_cod_in_dc_vault', v_cash_in_dc_vault,
        'direct_transfer_in_paystack', v_cash_in_paystack,
        'total_inventory_units_held', v_total_units_in_custody,
        'inventory_baseline_liquidation_value', v_base_inventory_valuation,
        'inventory_estimated_retail_value', v_weighted_retail_valuation,
        'grand_total_asset_value', (v_total_liquid_cash + v_weighted_retail_valuation)
    );
END;
$$;

-- 9. Permissions & Execution Grants
GRANT EXECUTE ON FUNCTION public.fn_receive_client_supply(UUID, UUID, TEXT, TEXT, JSONB, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_issue_dc_stock_to_rider(UUID, UUID, JSONB, UUID, TEXT, TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_rider_accept_stock_handover(UUID, UUID, TEXT, TEXT, JSONB, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_confirm_order_delivery_stock(UUID, UUID, UUID, INT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_receive_rider_stock_return(UUID, UUID, UUID, INT, TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_calculate_merchant_asset_custody(UUID, UUID) TO authenticated, service_role;
