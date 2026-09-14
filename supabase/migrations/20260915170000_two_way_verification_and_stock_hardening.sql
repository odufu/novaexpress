-- Migration: 20260915170000_two_way_verification_and_stock_hardening.sql
-- Description: Hardens client supply receiving, prevents phantom negative rider handovers, restores rejected DC stock, and adds cancel function.

-- ============================================================================
-- 1. Helper function for safe JSONB dc_stocks adjustments (idempotent ensure)
-- ============================================================================

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
BEGIN
    IF p_product_id IS NULL OR p_dc_id IS NULL OR p_delta = 0 THEN
        RETURN;
    END IF;

    SELECT COALESCE(dc_stocks, '{}'::JSONB) INTO v_curr_stocks
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
END;
$$;

-- ============================================================================
-- 2. Client Supply: Hardened Receive & Verify Stored Procedure
-- ============================================================================

DROP FUNCTION IF EXISTS public.fn_receive_client_supply(UUID, UUID, TEXT, TEXT, JSONB, TEXT);

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
DECLARE
    v_trf RECORD;
    v_item JSONB;
    v_item_id UUID;
    v_prod_id UUID;
    v_qty_rec INT;
    v_qty_dam INT;
    v_qty_mis INT;
    v_item_row RECORD;
    v_has_disc BOOLEAN := FALSE;
    v_status TEXT := 'completed';
BEGIN
    SELECT * INTO v_trf FROM public.stock_transfers WHERE id = p_transfer_id;
    IF v_trf IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Stock transfer not found');
    END IF;

    -- Process verified items if explicitly provided
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

            -- Match by item_id or product_id
            SELECT * INTO v_item_row FROM public.stock_transfer_items
            WHERE ((v_item_id IS NOT NULL AND id = v_item_id)
                OR (v_item_id IS NOT NULL AND product_id = v_item_id)
                OR (v_prod_id IS NOT NULL AND product_id = v_prod_id))
              AND transfer_id = p_transfer_id
            LIMIT 1;

            IF v_item_row IS NOT NULL THEN
                -- If received quantity was not explicitly set or is 0 while no damage/missing reported,
                -- fallback safely to quantity_shipped so stock intake is never lost.
                IF v_qty_rec = 0 AND v_qty_dam = 0 AND v_qty_mis = 0 AND v_item_row.quantity_shipped > 0 THEN
                    v_qty_rec := v_item_row.quantity_shipped;
                END IF;

                IF v_qty_dam > 0 OR v_qty_mis > 0 OR v_qty_rec != v_item_row.quantity_shipped THEN
                    v_has_disc := TRUE;
                END IF;

                UPDATE public.stock_transfer_items
                SET quantity_received = v_qty_rec,
                    quantity_damaged = v_qty_dam,
                    quantity_missing = v_qty_mis,
                    item_notes = COALESCE(v_item->>'notes', item_notes)
                WHERE id = v_item_row.id;

                -- Balance product overall stock & DC scoped stock
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
        -- Fallback: accept all shipped quantities as received
        FOR v_item_row IN SELECT * FROM public.stock_transfer_items WHERE transfer_id = p_transfer_id
        LOOP
            v_qty_rec := v_item_row.quantity_shipped;

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
    END IF;

    UPDATE public.stock_transfers
    SET status = v_status,
        receiver_id = p_receiver_id,
        receiver_name = p_receiver_name,
        receiver_role = 'dc_supervisor',
        receiver_signature_url = COALESCE(p_receiver_signature_url, ''),
        received_at = NOW(),
        has_discrepancy = v_has_disc,
        discrepancy_notes = p_notes,
        updated_at = NOW()
    WHERE id = p_transfer_id;

    -- Notify Client that consignment has been accepted and stock balanced
    IF v_trf.client_id IS NOT NULL THEN
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
            v_trf.client_id,
            'Consignment Verified & Stock Balanced! ✓',
            'Waybill ' || COALESCE(v_trf.waybill_number, '') || ' received and verified by DC supervisor ' || p_receiver_name || '. Inventory is now balanced into station shelves.',
            'inventory',
            '/products',
            false
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'status', v_status,
        'has_discrepancy', v_has_disc,
        'message', 'Inbound supply intake completed and stock balanced successfully.'
    );
END;
$$;

-- ============================================================================
-- 3. DC to Rider: Stock Handover with Availability Guard
-- ============================================================================

DROP FUNCTION IF EXISTS public.fn_issue_dc_stock_to_rider(UUID, UUID, JSONB, UUID, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.fn_issue_dc_stock_to_rider(
    p_dc_id UUID,
    p_rider_id UUID,
    p_items JSONB,
    p_sender_id UUID,
    p_sender_name TEXT,
    p_sender_signature_url TEXT DEFAULT '',
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
    v_avail INT;
    v_wh_id UUID;
    v_rider RECORD;
BEGIN
    SELECT * INTO v_rider FROM public.delivery_agents WHERE id = p_rider_id OR user_id = p_rider_id LIMIT 1;
    IF v_rider IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Delivery agent not found');
    END IF;

    SELECT company_id INTO v_company_id FROM public.distribution_centers WHERE id = p_dc_id;
    IF v_company_id IS NULL THEN
        v_company_id := '11111111-1111-4111-8111-111111111111'::UUID;
    END IF;

    -- Pre-flight validation: Check that DC has sufficient stock for ALL requested items
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_prod_id := (v_item->>'product_id')::UUID;
        v_qty := COALESCE((v_item->>'quantity')::INT, 0);

        IF v_qty > 0 THEN
            SELECT COALESCE((dc_stocks->>p_dc_id::TEXT)::INT, 0) INTO v_avail
            FROM public.products WHERE id = v_prod_id;

            IF v_avail < v_qty THEN
                RETURN jsonb_build_object(
                    'success', false,
                    'message', 'Insufficient stock in DC possession (' || v_avail || ' units available, cannot issue ' || v_qty || ' units)'
                );
            END IF;
        END IF;
    END LOOP;

    -- Find or create rider vehicle warehouse
    SELECT id INTO v_wh_id FROM public.warehouses WHERE rider_id = v_rider.id LIMIT 1;
    IF v_wh_id IS NULL THEN
        INSERT INTO public.warehouses (
            company_id,
            rider_id,
            name,
            type,
            location_state,
            address,
            is_active
        ) VALUES (
            v_company_id,
            v_rider.id,
            COALESCE(v_rider.full_name, 'Rider') || ' (' || COALESCE(v_rider.agent_code, 'PDA') || ') Vehicle Stock',
            'rider_mini_hub',
            COALESCE(v_rider.operating_state, 'Federal Capital Territory'),
            'Vehicle Mobile Custody',
            true
        ) RETURNING id INTO v_wh_id;
    END IF;

    v_waybill := 'WB-RIDER-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');

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
        receiver_id,
        receiver_name,
        receiver_role,
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
        COALESCE(p_sender_signature_url, ''),
        COALESCE(v_rider.id, p_rider_id),
        COALESCE(v_rider.full_name, 'Rider'),
        'delivery_agent',
        NOW(),
        p_notes
    ) RETURNING id INTO v_transfer_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_prod_id := (v_item->>'product_id')::UUID;
        v_qty := COALESCE((v_item->>'quantity')::INT, 0);

        IF v_qty > 0 THEN
            UPDATE public.products
            SET stock_quantity = GREATEST(0, COALESCE(stock_quantity, 0) - v_qty),
                updated_at = NOW()
            WHERE id = v_prod_id;

            -- Debit DC shelf stock
            PERFORM public.fn_adjust_dc_stock(v_prod_id, p_dc_id, -v_qty);

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

    RETURN jsonb_build_object(
        'success', true,
        'transfer_id', v_transfer_id,
        'waybill_number', v_waybill,
        'status', 'pending_rider_acceptance'
    );
END;
$$;

-- ============================================================================
-- 4. Rider Rejects Handover: Full DC Stock Restitution
-- ============================================================================

DROP FUNCTION IF EXISTS public.fn_rider_reject_stock_handover(UUID, UUID, TEXT);

CREATE OR REPLACE FUNCTION public.fn_rider_reject_stock_handover(
    p_transfer_id UUID,
    p_rider_id UUID,
    p_reason TEXT DEFAULT ''
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_trf RECORD;
    v_item RECORD;
BEGIN
    SELECT * INTO v_trf FROM public.stock_transfers WHERE id = p_transfer_id;
    IF v_trf IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Stock transfer not found');
    END IF;

    -- Restore DC shelf stock for all items
    FOR v_item IN SELECT * FROM public.stock_transfer_items WHERE transfer_id = p_transfer_id
    LOOP
        UPDATE public.products
        SET stock_quantity = COALESCE(stock_quantity, 0) + v_item.quantity_shipped,
            updated_at = NOW()
        WHERE id = v_item.product_id;

        IF v_trf.source_dc_id IS NOT NULL THEN
            PERFORM public.fn_adjust_dc_stock(v_item.product_id, v_trf.source_dc_id, v_item.quantity_shipped);
        END IF;
    END LOOP;

    UPDATE public.stock_transfers
    SET status = 'rejected',
        discrepancy_notes = 'Rejected by rider: ' || p_reason,
        updated_at = NOW()
    WHERE id = p_transfer_id;

    RETURN jsonb_build_object(
        'success', true,
        'status', 'rejected',
        'message', 'Stock handover rejected. Units returned to DC shelf.'
    );
END;
$$;

-- ============================================================================
-- 5. DC Supervisor Cancels Pending Handover: Full DC Stock Restitution
-- ============================================================================

DROP FUNCTION IF EXISTS public.fn_cancel_dc_stock_handover(UUID, UUID, TEXT);

CREATE OR REPLACE FUNCTION public.fn_cancel_dc_stock_handover(
    p_transfer_id UUID,
    p_cancelled_by UUID,
    p_reason TEXT DEFAULT ''
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_trf RECORD;
    v_item RECORD;
BEGIN
    SELECT * INTO v_trf FROM public.stock_transfers WHERE id = p_transfer_id;
    IF v_trf IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Stock transfer not found');
    END IF;
    IF v_trf.status != 'pending_rider_acceptance' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Only pending handovers can be cancelled');
    END IF;

    -- Restore DC shelf stock for all items
    FOR v_item IN SELECT * FROM public.stock_transfer_items WHERE transfer_id = p_transfer_id
    LOOP
        UPDATE public.products
        SET stock_quantity = COALESCE(stock_quantity, 0) + v_item.quantity_shipped,
            updated_at = NOW()
        WHERE id = v_item.product_id;

        IF v_trf.source_dc_id IS NOT NULL THEN
            PERFORM public.fn_adjust_dc_stock(v_item.product_id, v_trf.source_dc_id, v_item.quantity_shipped);
        END IF;
    END LOOP;

    UPDATE public.stock_transfers
    SET status = 'cancelled',
        discrepancy_notes = 'Cancelled by DC supervisor: ' || p_reason,
        updated_at = NOW()
    WHERE id = p_transfer_id;

    RETURN jsonb_build_object(
        'success', true,
        'status', 'cancelled',
        'message', 'Stock handover cancelled. Units returned to DC shelf.'
    );
END;
$$;

-- Reload schema cache so PostgREST immediately discovers updated signatures
NOTIFY pgrst, 'reload schema';
