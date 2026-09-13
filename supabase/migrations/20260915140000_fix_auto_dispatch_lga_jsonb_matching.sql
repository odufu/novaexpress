-- ============================================================================
-- Migration: 20260915140000_fix_auto_dispatch_lga_jsonb_matching.sql
-- Description:
--   1. Fixes LGA and State routing in auto_dispatch_order_by_state_lga:
--      - Uses jsonb_build_array(v_lga) and JSON existence (?) for robust array containment.
--      - Supports hierarchical rider prioritization (direct LGA coverage -> partial match -> DC general rider).
--      - Corrects PL/pgSQL record existence check (v_matched_driver.id IS NOT NULL).
--   2. Enhances fn_sync_order_conversation to auto-generate delivery reports &
--      lifecycle milestone messages in order_conversation_messages for Client, DC, and Rider.
-- ============================================================================

-- 1. Corrected auto_dispatch_order_by_state_lga
CREATE OR REPLACE FUNCTION public.auto_dispatch_order_by_state_lga(p_order_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
  v_state TEXT;
  v_lga TEXT;
  v_matched_dc RECORD;
  v_matched_driver RECORD;
  v_grand_dc RECORD;
BEGIN
  -- 0. Fetch Order details
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Order not found');
  END IF;

  v_state := COALESCE(NULLIF(TRIM(v_order.delivery_state), ''), NULLIF(TRIM(v_order.state), ''), '');
  v_lga := COALESCE(NULLIF(TRIM(v_order.delivery_lga), ''), NULLIF(TRIM(v_order.lga), ''), NULLIF(TRIM(v_order.delivery_city), ''), NULLIF(TRIM(v_order.city), ''), '');

  -- Fetch Grand DC fallback (Wuse Central Hub)
  SELECT * INTO v_grand_dc FROM public.distribution_centers WHERE is_grand_dc = true AND is_active = true ORDER BY created_at ASC LIMIT 1;
  IF v_grand_dc IS NULL THEN
    SELECT * INTO v_grand_dc FROM public.distribution_centers WHERE is_hub = true AND is_active = true ORDER BY created_at ASC LIMIT 1;
  END IF;
  IF v_grand_dc IS NULL THEN
    SELECT * INTO v_grand_dc FROM public.distribution_centers WHERE is_active = true ORDER BY created_at ASC LIMIT 1;
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

  -- 2. If not pre-assigned, match Distribution Center by State and LGA coverage
  IF v_matched_dc IS NULL THEN
    SELECT * INTO v_matched_dc
    FROM public.distribution_centers
    WHERE is_active = true
      AND (
        LOWER(state) = LOWER(v_state) 
        OR LOWER(name) ILIKE '%' || LOWER(v_state) || '%'
      )
      AND (
        operating_zones @> jsonb_build_array(v_lga)
        OR operating_zones ? v_lga
        OR operating_zones::text ILIKE '%' || v_lga || '%'
        OR v_lga = ''
      )
    ORDER BY is_hub DESC, created_at ASC
    LIMIT 1;

    -- Fallback: If no LGA match, check state match
    IF v_matched_dc IS NULL AND v_state <> '' THEN
      SELECT * INTO v_matched_dc
      FROM public.distribution_centers
      WHERE is_active = true
        AND (
          LOWER(state) = LOWER(v_state)
          OR LOWER(name) ILIKE '%' || LOWER(v_state) || '%'
        )
      ORDER BY is_hub DESC, created_at ASC
      LIMIT 1;
    END IF;
  END IF;

  -- FALLBACK A: No DC matches State/LGA and none pre-assigned -> Route to Grand DC for manual triage
  IF v_matched_dc IS NULL THEN
    UPDATE public.orders
    SET 
      distribution_center_id = v_grand_dc.id,
      delivery_agent_id = NULL,
      assigned_agent_id = NULL,
      status = 'pending_dispatch',
      assignment_status = 'pending_dc_assignment',
      routing_notes = '🚨 Escalated to Grand DC (' || v_grand_dc.name || '). No regional DC covers State: "' || v_state || '", LGA: "' || v_lga || '".',
      updated_at = NOW()
    WHERE id = p_order_id;

    RETURN jsonb_build_object(
      'success', true,
      'status', 'pending_dc_assignment',
      'distribution_center_id', v_grand_dc.id,
      'distribution_center_name', v_grand_dc.name,
      'assigned_agent_id', null,
      'message', 'No DC found. Escalated to Grand DC.'
    );
  END IF;

  -- 3. Match Active Rider strictly belonging to matched DC covering this LGA
  -- Supports 'available', 'active', 'on_duty' current_status
  -- Prioritizes: 1) explicit LGA match, 2) text match, 3) city match, 4) general DC rider
  SELECT * INTO v_matched_driver
  FROM public.delivery_agents
  WHERE is_active = true
    AND is_on_duty = true
    AND LOWER(current_status) IN ('available', 'active', 'on_duty')
    AND (distribution_center_id::text = v_matched_dc.id::text)
    AND (
      covered_lgas @> jsonb_build_array(v_lga)
      OR covered_lgas ? v_lga
      OR covered_lgas::text ILIKE '%' || v_lga || '%'
      OR operating_city ILIKE '%' || v_lga || '%'
      OR v_lga = ''
      OR jsonb_array_length(COALESCE(covered_lgas, '[]'::jsonb)) = 0
    )
  ORDER BY 
    CASE 
      WHEN (covered_lgas @> jsonb_build_array(v_lga) OR covered_lgas ? v_lga) THEN 1
      WHEN covered_lgas::text ILIKE '%' || v_lga || '%' THEN 2
      WHEN operating_city ILIKE '%' || v_lga || '%' THEN 3
      ELSE 4
    END,
    created_at ASC
  LIMIT 1;

  -- SUCCESS: Eligible Rider Found -> Auto-assign to Rider and create notification
  IF v_matched_driver.id IS NOT NULL THEN
    UPDATE public.orders
    SET 
      distribution_center_id = v_matched_dc.id,
      delivery_agent_id = v_matched_driver.id,
      assigned_agent_id = v_matched_driver.id,
      status = 'assigned',
      assignment_status = 'auto_assigned',
      routing_notes = '✅ Auto-assigned to Rider (' || v_matched_driver.agent_code || ') at ' || v_matched_dc.name || ' covering LGA: "' || v_lga || '".',
      assigned_at = NOW(),
      updated_at = NOW()
    WHERE id = p_order_id;

    -- Insert in-app / push notification for rider
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
      'Order #' || v_order.order_number || ' (' || v_order.customer_name || ' in ' || COALESCE(v_order.delivery_city, v_lga) || ') has been assigned to your route.',
      'delivery',
      '/orders',
      false,
      NOW()
    );

    RETURN jsonb_build_object(
      'success', true,
      'status', 'auto_assigned',
      'distribution_center_id', v_matched_dc.id,
      'distribution_center_name', v_matched_dc.name,
      'assigned_agent_id', v_matched_driver.id,
      'assigned_agent_code', v_matched_driver.agent_code,
      'message', 'Order auto-assigned to rider.'
    );
  END IF;

  -- FALLBACK B: DC matched / preserved, but no rider covers this LGA -> Keep DC and await rider assignment
  UPDATE public.orders
  SET 
    distribution_center_id = v_matched_dc.id,
    delivery_agent_id = NULL,
    assigned_agent_id = NULL,
    status = 'pending_dispatch',
    assignment_status = 'pending_rider_assignment',
    routing_notes = '⚠️ Routed to ' || v_matched_dc.name || '. Awaiting manual rider assignment for LGA: "' || v_lga || '".',
    updated_at = NOW()
  WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'pending_rider_assignment',
    'distribution_center_id', v_matched_dc.id,
    'distribution_center_name', v_matched_dc.name,
    'assigned_agent_id', null,
    'message', 'Routed to Station DC. Awaiting rider assignment.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. Enhanced fn_sync_order_conversation with delivery reports & lifecycle messages
CREATE OR REPLACE FUNCTION public.fn_sync_order_conversation()
RETURNS TRIGGER AS $$
DECLARE
    v_conv_id UUID;
    v_client_name TEXT;
    v_dc_name TEXT;
    v_rider_name TEXT;
    v_closer_name TEXT;
BEGIN
    -- Only sync if client_id is present
    IF NEW.client_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Lookup Client Name
    SELECT name INTO v_client_name
    FROM public.clients
    WHERE id = NEW.client_id;

    -- Lookup DC Name
    IF NEW.distribution_center_id IS NOT NULL THEN
        SELECT name INTO v_dc_name
        FROM public.distribution_centers
        WHERE id = NEW.distribution_center_id;
    END IF;

    -- Lookup Rider Full Name
    IF NEW.delivery_agent_id IS NOT NULL THEN
        SELECT COALESCE(da.full_name, u.first_name || ' ' || u.last_name, da.bank_account_name, da.agent_code)
        INTO v_rider_name
        FROM public.delivery_agents da
        LEFT JOIN public.users u ON da.user_id = u.id
        WHERE da.id = NEW.delivery_agent_id;
    END IF;

    -- Lookup Closer Name
    IF NEW.closer_id IS NOT NULL THEN
        SELECT closer_name INTO v_closer_name
        FROM public.client_closers
        WHERE id = NEW.closer_id;
    END IF;

    -- Insert or update order_conversations
    INSERT INTO public.order_conversations (
        order_id,
        order_number,
        customer_name,
        customer_phone,
        client_id,
        client_name,
        distribution_center_id,
        distribution_center_name,
        delivery_agent_id,
        delivery_agent_name,
        closer_id,
        closer_name,
        order_status,
        current_product_name,
        current_package_name,
        current_total_amount,
        last_message_text,
        last_message_sender_name,
        last_message_at,
        updated_at
    ) VALUES (
        NEW.id,
        NEW.order_number,
        NEW.customer_name,
        NEW.customer_phone,
        NEW.client_id,
        v_client_name,
        NEW.distribution_center_id,
        v_dc_name,
        NEW.delivery_agent_id,
        v_rider_name,
        NEW.closer_id,
        v_closer_name,
        NEW.status,
        NEW.product_name,
        NEW.package_deal_name,
        COALESCE(NEW.total_amount, 0),
        'Order pipeline active.',
        'System',
        now(),
        now()
    )
    ON CONFLICT (order_id) DO UPDATE SET
        order_number = EXCLUDED.order_number,
        customer_name = EXCLUDED.customer_name,
        customer_phone = EXCLUDED.customer_phone,
        client_id = EXCLUDED.client_id,
        client_name = EXCLUDED.client_name,
        distribution_center_id = EXCLUDED.distribution_center_id,
        distribution_center_name = EXCLUDED.distribution_center_name,
        delivery_agent_id = EXCLUDED.delivery_agent_id,
        delivery_agent_name = EXCLUDED.delivery_agent_name,
        closer_id = EXCLUDED.closer_id,
        closer_name = EXCLUDED.closer_name,
        order_status = EXCLUDED.order_status,
        current_product_name = EXCLUDED.current_product_name,
        current_package_name = EXCLUDED.current_package_name,
        current_total_amount = EXCLUDED.current_total_amount,
        updated_at = now()
    RETURNING id INTO v_conv_id;

    -- If TG_OP is UPDATE, emit milestone messages into the chat for Client, DC, and Rider
    IF TG_OP = 'UPDATE' AND v_conv_id IS NOT NULL THEN
        -- Case A: Rider Assigned
        IF (OLD.delivery_agent_id IS DISTINCT FROM NEW.delivery_agent_id) AND NEW.delivery_agent_id IS NOT NULL THEN
            INSERT INTO public.order_conversation_messages (
                conversation_id,
                order_id,
                sender_name,
                sender_role,
                message_body,
                message_type,
                metadata,
                is_read,
                created_at
            ) VALUES (
                v_conv_id,
                NEW.id,
                'System Dispatcher',
                'system',
                '🚴 Rider Assigned: ' || COALESCE(v_rider_name, 'Fleet Rider') || ' has been assigned to deliver order #' || NEW.order_number || '.',
                'rider_assigned',
                jsonb_build_object('delivery_agent_id', NEW.delivery_agent_id, 'delivery_agent_name', v_rider_name),
                false,
                now()
            );
        END IF;

        -- Case B: Status Changed (Delivered, Failed, Rescheduled)
        IF OLD.status IS DISTINCT FROM NEW.status THEN
            IF NEW.status = 'delivered' THEN
                INSERT INTO public.order_conversation_messages (
                    conversation_id,
                    order_id,
                    sender_name,
                    sender_role,
                    message_body,
                    message_type,
                    metadata,
                    is_read,
                    created_at
                ) VALUES (
                    v_conv_id,
                    NEW.id,
                    'Delivery Operations',
                    'system',
                    '🎉 Order Delivered! Order #' || NEW.order_number || ' completed successfully. Payment: ' || UPPER(COALESCE(NEW.payment_method, 'COD')) || ' (₦' || TO_CHAR(COALESCE(NEW.total_amount, 0), 'FM999,999,999') || ').',
                    'delivery_completed',
                    jsonb_build_object(
                        'delivered_at', NEW.delivered_at,
                        'total_amount', NEW.total_amount,
                        'payment_method', NEW.payment_method,
                        'proof_of_delivery_url', NEW.proof_of_delivery_url
                    ),
                    false,
                    now()
                );
            ELSIF NEW.status IN ('delivery_failed', 'failed') THEN
                INSERT INTO public.order_conversation_messages (
                    conversation_id,
                    order_id,
                    sender_name,
                    sender_role,
                    message_body,
                    message_type,
                    metadata,
                    is_read,
                    created_at
                ) VALUES (
                    v_conv_id,
                    NEW.id,
                    'Delivery Operations',
                    'system',
                    '⚠️ Delivery Attempt Failed for Order #' || NEW.order_number || '. Reason: ' || COALESCE(NEW.reschedule_note, NEW.delivery_notes, 'Customer unreachable') || '.',
                    'delivery_failed',
                    jsonb_build_object('failure_note', COALESCE(NEW.reschedule_note, NEW.delivery_notes)),
                    false,
                    now()
                );
            ELSIF NEW.status = 'rescheduled' THEN
                INSERT INTO public.order_conversation_messages (
                    conversation_id,
                    order_id,
                    sender_name,
                    sender_role,
                    message_body,
                    message_type,
                    metadata,
                    is_read,
                    created_at
                ) VALUES (
                    v_conv_id,
                    NEW.id,
                    'Delivery Operations',
                    'system',
                    '📅 Order Rescheduled: Callback set for Order #' || NEW.order_number || '. Note: ' || COALESCE(NEW.reschedule_note, 'Pending customer consultation') || '.',
                    'rescheduled',
                    jsonb_build_object('rescheduled_at', NEW.scheduled_callback_at, 'reschedule_note', NEW.reschedule_note),
                    false,
                    now()
                );
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
