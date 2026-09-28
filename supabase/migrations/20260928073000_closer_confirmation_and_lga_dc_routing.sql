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
