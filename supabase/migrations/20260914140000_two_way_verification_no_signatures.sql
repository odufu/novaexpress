-- Migration: 20260914140000_two_way_verification_no_signatures.sql
-- Description: Two-way stock verification handshake across Client->DC, DC->DC, and DC->Rider without mandatory signatures.

-- ============================================================================
-- 1. Helper function for safe JSONB dc_stocks adjustments
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
-- 2. Client Supply: Dispatch (Party A Logs Supply Request)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_dispatch_client_supply(
    p_client_id UUID,
    p_dc_id UUID,
    p_items JSONB, -- Array of {product_id, quantity, notes}
    p_sender_id UUID DEFAULT NULL,
    p_sender_name TEXT DEFAULT '',
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
    v_item_notes TEXT;
    v_total_items INT := 0;
    v_total_qty INT := 0;
BEGIN
    SELECT company_id INTO v_company_id FROM public.clients WHERE id = p_client_id;
    IF v_company_id IS NULL THEN
        SELECT id INTO v_company_id FROM public.companies LIMIT 1;
    END IF;

    v_waybill := 'WB-SUPPLY-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');

    INSERT INTO public.stock_transfers (
        company_id,
        client_id,
        transfer_type,
        transfer_number,
        waybill_number,
        destination_dc_id,
        status,
        sender_id,
        sender_name,
        sender_role,
        sender_signature_url,
        dispatched_at,
        notes
    ) VALUES (
        v_company_id,
        p_client_id,
        'client_to_dc',
        v_waybill,
        v_waybill,
        p_dc_id,
        'pending_dc_acceptance',
        p_sender_id,
        p_sender_name,
        'client_admin',
        COALESCE(p_sender_signature_url, ''),
        NOW(),
        p_notes
    ) RETURNING id INTO v_transfer_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_prod_id := (v_item->>'product_id')::UUID;
        v_qty := COALESCE((v_item->>'quantity')::INT, 0);
        v_item_notes := v_item->>'notes';

        IF v_qty > 0 THEN
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
                v_qty,
                0,
                0,
                0,
                v_item_notes
            );
            v_total_items := v_total_items + 1;
            v_total_qty := v_total_qty + v_qty;
        END IF;
    END LOOP;

    -- Notify DC Supervisors
    INSERT INTO public.notifications (
        company_id,
        distribution_center_id,
        title,
        message,
        category,
        action_route,
        is_read
    ) VALUES (
        v_company_id,
        p_dc_id,
        'Inbound Client Supply Dispatched! 📦',
        'Consignment ' || v_waybill || ' (' || v_total_qty || ' total units) dispatched by ' || p_sender_name || '. Awaiting DC physical count and intake approval.',
        'inventory',
        '/stock',
        false
    );

    RETURN jsonb_build_object(
        'success', true,
        'transfer_id', v_transfer_id,
        'waybill_number', v_waybill,
        'status', 'pending_dc_acceptance',
        'items_count', v_total_items,
        'total_quantity', v_total_qty
    );
END;
$$;

-- ============================================================================
-- 3. Client Supply: Receive & Verify (Party B Accepts & Balances Stock)
-- ============================================================================

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
-- 4. Inter-DC Transfer: Dispatch (Party A Reserves & Dispatches)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_dispatch_inter_dc_transfer(
    p_source_dc_id UUID,
    p_destination_dc_id UUID,
    p_product_id UUID,
    p_quantity INT,
    p_sender_id UUID DEFAULT NULL,
    p_sender_name TEXT DEFAULT '',
    p_notes TEXT DEFAULT ''
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_company_id UUID;
    v_transfer_id UUID;
    v_waybill TEXT;
    v_src_name TEXT := 'Source DC';
    v_prod_name TEXT := 'Product';
BEGIN
    IF p_quantity <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Transfer quantity must be greater than 0');
    END IF;

    SELECT company_id, name INTO v_company_id, v_src_name
    FROM public.distribution_centers
    WHERE id = p_source_dc_id;

    IF v_company_id IS NULL THEN
        SELECT id INTO v_company_id FROM public.companies LIMIT 1;
    END IF;

    SELECT name INTO v_prod_name FROM public.products WHERE id = p_product_id;

    v_waybill := 'WB-INTERDC-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');

    -- 1. Create Transfer Record in 'pending_destination_acceptance'
    INSERT INTO public.stock_transfers (
        company_id,
        transfer_type,
        transfer_number,
        waybill_number,
        source_dc_id,
        destination_dc_id,
        status,
        sender_id,
        sender_name,
        sender_role,
        dispatched_at,
        notes
    ) VALUES (
        v_company_id,
        'inter_dc',
        v_waybill,
        v_waybill,
        p_source_dc_id,
        p_destination_dc_id,
        'pending_destination_acceptance',
        p_sender_id,
        p_sender_name,
        'dc_supervisor',
        NOW(),
        p_notes
    ) RETURNING id INTO v_transfer_id;

    -- 2. Insert Item
    INSERT INTO public.stock_transfer_items (
        transfer_id,
        product_id,
        quantity_shipped,
        quantity_received
    ) VALUES (
        v_transfer_id,
        p_product_id,
        p_quantity,
        0
    );

    -- 3. Atomically debit source DC stock (reserve it in-transit)
    PERFORM public.fn_adjust_dc_stock(p_product_id, p_source_dc_id, -p_quantity);

    -- 4. Notify Destination DC Supervisors
    INSERT INTO public.notifications (
        company_id,
        distribution_center_id,
        title,
        message,
        category,
        action_route,
        is_read
    ) VALUES (
        v_company_id,
        p_destination_dc_id,
        'Incoming Inter-DC Stock Transfer! 🚚',
        v_src_name || ' dispatched ' || p_quantity || ' units of ' || COALESCE(v_prod_name, 'product') || ' (Waybill: ' || v_waybill || '). Awaiting receipt acceptance.',
        'inventory',
        '/stock',
        false
    );

    RETURN jsonb_build_object(
        'success', true,
        'transfer_id', v_transfer_id,
        'waybill_number', v_waybill,
        'status', 'pending_destination_acceptance',
        'quantity', p_quantity,
        'message', 'Inter-DC transfer dispatched successfully. Awaiting destination DC acceptance.'
    );
END;
$$;

-- ============================================================================
-- 5. Inter-DC Transfer: Receive & Accept (Party B Verifies & Balances Stock)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_receive_inter_dc_transfer(
    p_transfer_id UUID,
    p_receiver_id UUID DEFAULT NULL,
    p_receiver_name TEXT DEFAULT '',
    p_quantity_received INT DEFAULT NULL,
    p_notes TEXT DEFAULT ''
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_trf RECORD;
    v_item RECORD;
    v_qty_rec INT;
    v_has_disc BOOLEAN := FALSE;
    v_status TEXT := 'completed';
BEGIN
    SELECT * INTO v_trf FROM public.stock_transfers WHERE id = p_transfer_id;
    IF v_trf IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Stock transfer not found');
    END IF;

    SELECT * INTO v_item FROM public.stock_transfer_items WHERE transfer_id = p_transfer_id LIMIT 1;
    IF v_item IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Transfer has no items');
    END IF;

    v_qty_rec := COALESCE(p_quantity_received, v_item.quantity_shipped);

    IF v_qty_rec != v_item.quantity_shipped THEN
        v_has_disc := TRUE;
        v_status := 'discrepancy_reported';

        -- If received LESS than shipped, refund remaining back to source DC
        IF v_qty_rec < v_item.quantity_shipped AND v_trf.source_dc_id IS NOT NULL THEN
            PERFORM public.fn_adjust_dc_stock(v_item.product_id, v_trf.source_dc_id, (v_item.quantity_shipped - v_qty_rec));
        END IF;
    END IF;

    -- Update Item
    UPDATE public.stock_transfer_items
    SET quantity_received = v_qty_rec
    WHERE id = v_item.id;

    -- Atomically credit Destination DC
    IF v_qty_rec > 0 AND v_trf.destination_dc_id IS NOT NULL THEN
        PERFORM public.fn_adjust_dc_stock(v_item.product_id, v_trf.destination_dc_id, v_qty_rec);
    END IF;

    -- Update Transfer Header
    UPDATE public.stock_transfers
    SET status = v_status,
        receiver_id = p_receiver_id,
        receiver_name = p_receiver_name,
        receiver_role = 'dc_supervisor',
        received_at = NOW(),
        has_discrepancy = v_has_disc,
        discrepancy_notes = p_notes,
        updated_at = NOW()
    WHERE id = p_transfer_id;

    -- Notify Source DC that destination DC has accepted
    IF v_trf.source_dc_id IS NOT NULL THEN
        INSERT INTO public.notifications (
            company_id,
            distribution_center_id,
            title,
            message,
            category,
            action_route,
            is_read
        ) VALUES (
            v_trf.company_id,
            v_trf.source_dc_id,
            'Inter-DC Stock Receipt Confirmed! ✓',
            'Waybill ' || COALESCE(v_trf.waybill_number, '') || ' received & accepted by ' || p_receiver_name || '. Transferred stock is now balanced.',
            'inventory',
            '/stock',
            false
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'status', v_status,
        'has_discrepancy', v_has_disc,
        'quantity_received', v_qty_rec,
        'message', 'Inter-DC stock transfer accepted and balanced successfully.'
    );
END;
$$;

-- ============================================================================
-- 6. DC to Rider Handover: Dispatch (No Signature Requirement)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_issue_dc_stock_to_rider(
    p_dc_id UUID,
    p_rider_id UUID,
    p_items JSONB, -- Array of {product_id, quantity}
    p_sender_id UUID DEFAULT NULL,
    p_sender_name TEXT DEFAULT '',
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
    v_rider RECORD;
    v_wh_id UUID;
BEGIN
    SELECT company_id INTO v_company_id FROM public.distribution_centers WHERE id = p_dc_id;
    IF v_company_id IS NULL THEN
        SELECT id INTO v_company_id FROM public.companies LIMIT 1;
    END IF;

    SELECT * INTO v_rider FROM public.delivery_agents WHERE id = p_rider_id OR user_id = p_rider_id;
    IF v_rider IS NOT NULL THEN
        SELECT id INTO v_wh_id FROM public.warehouses WHERE rider_id = v_rider.id LIMIT 1;
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

            -- Also debit DC shelf stock
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
            'DC Supervisor ' || p_sender_name || ' issued stock to you (Waybill: ' || v_waybill || '). Please count and accept custody.',
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

-- ============================================================================
-- 7. Rider Accepts Handover: Accept Custody (No Signature Requirement)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_rider_accept_stock_handover(
    p_transfer_id UUID,
    p_rider_id UUID,
    p_rider_name TEXT,
    p_rider_signature_url TEXT DEFAULT '',
    p_verified_items JSONB DEFAULT NULL,
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
BEGIN
    SELECT * INTO v_trf FROM public.stock_transfers WHERE id = p_transfer_id;
    IF v_trf IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Stock transfer not found');
    END IF;

    SELECT * INTO v_rider FROM public.delivery_agents WHERE id = p_rider_id OR user_id = p_rider_id;

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
            IF v_qty_rec < v_item.quantity_shipped THEN
                UPDATE public.products
                SET stock_quantity = COALESCE(stock_quantity, 0) + (v_item.quantity_shipped - v_qty_rec)
                WHERE id = v_item.product_id;

                IF v_trf.source_dc_id IS NOT NULL THEN
                    PERFORM public.fn_adjust_dc_stock(v_item.product_id, v_trf.source_dc_id, (v_item.quantity_shipped - v_qty_rec));
                END IF;
            END IF;
        END IF;

        UPDATE public.stock_transfer_items
        SET quantity_received = v_qty_rec
        WHERE id = v_item.id;

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

    UPDATE public.stock_transfers
    SET status = CASE WHEN v_has_disc THEN 'discrepancy_reported' ELSE 'completed' END,
        receiver_id = p_rider_id,
        receiver_name = p_rider_name,
        receiver_role = 'delivery_agent',
        receiver_signature_url = COALESCE(p_rider_signature_url, ''),
        received_at = NOW(),
        has_discrepancy = v_has_disc,
        discrepancy_notes = p_notes,
        updated_at = NOW()
    WHERE id = p_transfer_id;

    RETURN jsonb_build_object(
        'success', true,
        'status', CASE WHEN v_has_disc THEN 'discrepancy_reported' ELSE 'completed' END,
        'has_discrepancy', v_has_disc,
        'message', 'Stock custody accepted and balanced successfully.'
    );
END;
$$;
