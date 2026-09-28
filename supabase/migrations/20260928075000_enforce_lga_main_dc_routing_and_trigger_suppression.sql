-- ============================================================================
-- Migration: 20260928075000_enforce_lga_main_dc_routing_and_trigger_suppression.sql
-- Description:
--   1. Ensures ONLY Wuse Grand Central is designated is_main_dc = true.
--   2. Updates trg_orders_auto_dispatch to suppress premature auto-dispatch for orders
--      awaiting closer confirmation (assignment_status = 'pending_closer_confirmation').
--   3. Upgrades auto_dispatch_order_by_state_lga:
--      - Re-evaluates DC based on latest order delivery_lga and delivery_state
--        (unless explicitly manually_assigned).
--      - If no regional DC handles the LGA, cleanly routes to Main DC (Wuse Grand Central)
--        with is_fallback_to_main = true and clear audit notes.
-- ============================================================================

-- 1. Correct is_main_dc flag: ONLY Grand DC / Wuse Central is Main DC
UPDATE public.distribution_centers
SET is_main_dc = (code = 'DC-WUSE-01' OR id = '22222222-2222-4222-8222-222222222222' OR is_grand_dc = true);

-- 2. Suppress auto-dispatch trigger for unconfirmed marketing leads
CREATE OR REPLACE FUNCTION public.trg_orders_auto_dispatch()
RETURNS TRIGGER AS $$
BEGIN
  -- If order is awaiting closer confirmation, DO NOT auto-dispatch yet!
  IF NEW.assignment_status = 'pending_closer_confirmation' 
     OR (NEW.closer_id IS NOT NULL AND NEW.status IN ('new', 'unconfirmed', 'contacting', 'pending')) THEN
    RETURN NEW;
  END IF;

  -- Auto-dispatch if no delivery agent is assigned and status is confirmed or pending dispatch
  IF COALESCE(NEW.delivery_agent_id, NEW.assigned_agent_id) IS NULL 
     AND (
       NEW.status = 'confirmed' 
       OR NEW.status = 'pending_dispatch'
       OR (NEW.closer_id IS NULL AND NEW.assignment_status != 'pending_closer_confirmation' AND NEW.status = 'pending')
     ) THEN
    PERFORM public.auto_dispatch_order_by_state_lga(NEW.id);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Upgraded auto_dispatch_order_by_state_lga
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

  -- Fetch Main DC (Grand Central Hub as designated fallback for uncovered LGAs)
  SELECT * INTO v_main_dc 
  FROM public.distribution_centers 
  WHERE is_active = true 
    AND (is_main_dc = true OR is_grand_dc = true OR code = 'DC-WUSE-01') 
  ORDER BY is_grand_dc DESC, is_main_dc DESC, created_at ASC 
  LIMIT 1;

  IF v_main_dc IS NULL THEN
    SELECT * INTO v_main_dc 
    FROM public.distribution_centers 
    WHERE is_active = true 
    ORDER BY is_hub DESC, created_at ASC 
    LIMIT 1;
  END IF;

  -- 1. Check if order was MANUALLY assigned by an admin to a specific DC
  IF v_order.assignment_status = 'manually_assigned' 
     AND v_order.distribution_center_id IS NOT NULL 
     AND TRIM(v_order.distribution_center_id::text) <> '' THEN
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

GRANT EXECUTE ON FUNCTION public.auto_dispatch_order_by_state_lga(UUID) TO authenticated, service_role, anon;

NOTIFY pgrst, 'reload schema';
