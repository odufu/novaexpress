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
