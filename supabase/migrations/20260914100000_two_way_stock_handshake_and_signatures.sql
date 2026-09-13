-- Migration: 20260914100000_two_way_stock_handshake_and_signatures.sql
-- Description: Schema extensions and atomic stored procedures for two-way stock transfer & supply handshakes with digital signatures.

-- ============================================================================
-- 1. Table Alterations for Two-Way Handshake
-- ============================================================================

ALTER TABLE IF EXISTS public.stock_transfers
    ADD COLUMN IF NOT EXISTS client_id UUID REFERENCES public.clients(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS transfer_type TEXT DEFAULT 'dc_to_rider', -- 'client_to_dc', 'dc_to_rider', 'rider_to_dc', 'inter_dc'
    -- Party A: Sender ("I have given / dispatched")
    ADD COLUMN IF NOT EXISTS sender_id UUID,
    ADD COLUMN IF NOT EXISTS sender_name TEXT,
    ADD COLUMN IF NOT EXISTS sender_role TEXT, -- 'client_admin', 'dc_supervisor', 'delivery_agent'
    ADD COLUMN IF NOT EXISTS sender_signature_url TEXT,
    ADD COLUMN IF NOT EXISTS dispatched_at TIMESTAMPTZ,
    -- Party B: Receiver ("I have received / verified")
    ADD COLUMN IF NOT EXISTS receiver_id UUID,
    ADD COLUMN IF NOT EXISTS receiver_name TEXT,
    ADD COLUMN IF NOT EXISTS receiver_role TEXT, -- 'dc_supervisor', 'delivery_agent'
    ADD COLUMN IF NOT EXISTS receiver_signature_url TEXT,
    ADD COLUMN IF NOT EXISTS received_at TIMESTAMPTZ,
    -- Discrepancy & Verification
    ADD COLUMN IF NOT EXISTS has_discrepancy BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS discrepancy_notes TEXT;

ALTER TABLE IF EXISTS public.stock_transfer_items
    ADD COLUMN IF NOT EXISTS quantity_damaged INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS quantity_missing INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS item_notes TEXT;

CREATE INDEX IF NOT EXISTS idx_stock_transfers_client_id ON public.stock_transfers(client_id);
CREATE INDEX IF NOT EXISTS idx_stock_transfers_type ON public.stock_transfers(transfer_type);
CREATE INDEX IF NOT EXISTS idx_stock_transfers_status ON public.stock_transfers(status);

-- ============================================================================
-- 2. Stored Procedure: Client Dispatches Supply Consignment to DC
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
BEGIN
    -- 1. Validate Client
    SELECT company_id INTO v_company_id FROM public.clients WHERE id = p_client_id;
    IF v_company_id IS NULL THEN
        SELECT id INTO v_company_id FROM public.companies LIMIT 1;
    END IF;

    -- 2. Generate Unique Waybill Number
    v_waybill := 'WB-SUPPLY-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');

    -- 3. Create Transfer Record (Status: 'dispatched')
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
        'dispatched',
        p_sender_id,
        p_sender_name,
        'client_admin',
        p_sender_signature_url,
        NOW(),
        p_notes
    ) RETURNING id INTO v_transfer_id;

    -- 4. Insert Items
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
        END IF;
    END LOOP;

    -- 5. Send Notification to DC Supervisors
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
        'Consignment ' || v_waybill || ' (' || v_total_items || ' product types) dispatched by ' || p_sender_name || '. Awaiting DC intake inspection.',
        'inventory',
        '/stock',
        false
    );

    RETURN jsonb_build_object(
        'success', true,
        'transfer_id', v_transfer_id,
        'waybill_number', v_waybill,
        'status', 'dispatched',
        'items_count', v_total_items
    );
END;
$$;

-- ============================================================================
-- 3. Stored Procedure: DC Receives & Verifies Inbound Client Supply
-- ============================================================================

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

    -- 1. Process each verified item
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

            -- Atomically increment DC product inventory
            IF v_qty_rec > 0 AND v_item_row.product_id IS NOT NULL THEN
                UPDATE public.products
                SET stock_quantity = COALESCE(stock_quantity, 0) + v_qty_rec,
                    updated_at = NOW()
                WHERE id = v_item_row.product_id;
            END IF;
        END IF;
    END LOOP;

    IF v_has_disc THEN
        v_status := 'discrepancy_reported';
    END IF;

    -- 2. Update Transfer Header
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

    -- 3. Notify Client
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
            'Consignment Received at DC! ✓',
            'Waybill ' || COALESCE(v_trf.waybill_number, '') || ' received and verified by ' || p_receiver_name || '. Status: ' || v_status,
            'inventory',
            '/products',
            false
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'status', v_status,
        'has_discrepancy', v_has_disc,
        'message', 'Inbound supply intake completed successfully.'
    );
END;
$$;

-- ============================================================================
-- 4. Stored Procedure: DC Issues Stock to Rider (Party A Signs & Reserves Shelf)
-- ============================================================================

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
BEGIN
    SELECT company_id INTO v_company_id FROM public.distribution_centers WHERE id = p_dc_id;
    IF v_company_id IS NULL THEN
        SELECT id INTO v_company_id FROM public.companies LIMIT 1;
    END IF;

    -- Resolve Rider details & mobile warehouse
    SELECT * INTO v_rider FROM public.delivery_agents WHERE id = p_rider_id OR user_id = p_rider_id;
    IF v_rider IS NOT NULL THEN
        SELECT id INTO v_wh_id FROM public.warehouses WHERE rider_id = v_rider.id LIMIT 1;
    END IF;

    v_waybill := 'WB-RIDER-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');

    -- 1. Create Stock Transfer in 'pending_rider_acceptance'
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

    -- 2. Deduct from DC shelf stock (reserving it) and record items
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_prod_id := (v_item->>'product_id')::UUID;
        v_qty := COALESCE((v_item->>'quantity')::INT, 0);

        IF v_qty > 0 THEN
            UPDATE public.products
            SET stock_quantity = GREATEST(0, COALESCE(stock_quantity, 0) - v_qty),
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

    -- 3. Send Notification to Rider
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

-- ============================================================================
-- 5. Stored Procedure: Rider Accepts Stock Handover (Party B Signs & Accepts Custody)
-- ============================================================================

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
BEGIN
    SELECT * INTO v_trf FROM public.stock_transfers WHERE id = p_transfer_id;
    IF v_trf IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Stock transfer not found');
    END IF;

    SELECT * INTO v_rider FROM public.delivery_agents WHERE id = p_rider_id OR user_id = p_rider_id;

    -- 1. Update transfer items and commit stock to agent_inventory
    FOR v_item IN SELECT * FROM public.stock_transfer_items WHERE transfer_id = p_transfer_id
    LOOP
        v_qty_rec := v_item.quantity_shipped;

        -- Check if explicit count provided
        IF p_verified_items IS NOT NULL THEN
            SELECT COALESCE((elem->>'quantity_received')::INT, v_item.quantity_shipped)
            INTO v_qty_rec
            FROM jsonb_array_elements(p_verified_items) elem
            WHERE (elem->>'item_id')::UUID = v_item.id;
        END IF;

        IF v_qty_rec != v_item.quantity_shipped THEN
            v_has_disc := TRUE;
            -- If rider received LESS, return the difference back to DC shelf stock
            IF v_qty_rec < v_item.quantity_shipped THEN
                UPDATE public.products
                SET stock_quantity = COALESCE(stock_quantity, 0) + (v_item.quantity_shipped - v_qty_rec)
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

    -- 2. Mark transfer completed with rider signature
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
        'has_discrepancy', v_has_disc,
        'message', 'Stock custody accepted successfully.'
    );
END;
$$;

-- ============================================================================
-- 6. Stored Procedure: Rider Rejects Stock Handover (Restores DC Shelf)
-- ============================================================================

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
        SET stock_quantity = COALESCE(stock_quantity, 0) + v_item.quantity_shipped
        WHERE id = v_item.product_id;
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
