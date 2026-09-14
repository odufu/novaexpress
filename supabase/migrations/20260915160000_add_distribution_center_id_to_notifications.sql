-- Migration: 20260915160000_add_distribution_center_id_to_notifications.sql
-- Description: Add distribution_center_id to notifications table and harden two-way stock handshake stored procedures.

-- ============================================================================
-- 1. Add distribution_center_id to public.notifications
-- ============================================================================

ALTER TABLE IF EXISTS public.notifications
    ADD COLUMN IF NOT EXISTS distribution_center_id UUID REFERENCES public.distribution_centers(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_distribution_center_id ON public.notifications(distribution_center_id);

-- ============================================================================
-- 2. Stored Procedure: fn_dispatch_client_supply (Resilient with Notifications)
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
    v_dc_user_id UUID;
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

    -- 5. Send Notification to DC Supervisors (safeguarded against runtime exceptions)
    BEGIN
        SELECT id INTO v_dc_user_id 
        FROM public.users 
        WHERE (distribution_center_id::text = p_dc_id::text OR role IN ('dc_manager', 'dc_supervisor'))
          AND is_active = true 
        ORDER BY (distribution_center_id::text = p_dc_id::text) DESC, created_at ASC 
        LIMIT 1;

        INSERT INTO public.notifications (
            company_id,
            distribution_center_id,
            user_id,
            title,
            message,
            category,
            action_route,
            is_read
        ) VALUES (
            v_company_id,
            p_dc_id,
            v_dc_user_id,
            'Inbound Client Supply Dispatched! 📦',
            'Consignment ' || v_waybill || ' (' || v_total_items || ' product types) dispatched by ' || p_sender_name || '. Awaiting DC intake inspection.',
            'inventory',
            '/stock',
            false
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Notification insertion ignored: %', SQLERRM;
    END;

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
-- 3. Stored Procedure: fn_receive_client_supply (Harden Notification)
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

    -- 3. Notify Client (Safeguarded)
    IF v_trf.client_id IS NOT NULL THEN
        BEGIN
            INSERT INTO public.notifications (
                company_id,
                client_id,
                distribution_center_id,
                title,
                message,
                category,
                action_route,
                is_read
            ) VALUES (
                v_trf.company_id,
                v_trf.client_id,
                v_trf.destination_dc_id,
                'Consignment Received at DC! ✓',
                'Waybill ' || COALESCE(v_trf.waybill_number, '') || ' received and verified by ' || p_receiver_name || '. Status: ' || v_status,
                'inventory',
                '/products',
                false
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Client notification insertion ignored: %', SQLERRM;
        END;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'status', v_status,
        'has_discrepancy', v_has_disc,
        'message', 'Inbound supply intake completed successfully.'
    );
END;
$$;
