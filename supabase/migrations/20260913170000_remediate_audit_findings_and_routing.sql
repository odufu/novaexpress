-- ============================================================================
-- Migration: 20260913170000_remediate_audit_findings_and_routing.sql
-- Description:
--   1. Update auto_dispatch_order_by_state_lga to honor pre-assigned DC IDs
--   2. Add latitude and longitude to distribution_centers table
--   3. Remove legacy column defaults ('Respira Detox Tea', 'Novacare', fixed fees)
--   4. Ensure stock_returns.order_id is nullable and has appropriate RLS
-- ============================================================================

-- 1. Extend distribution_centers with coordinates for proximity routing
ALTER TABLE public.distribution_centers
  ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

-- 2. Ensure stock_returns order_id is nullable
ALTER TABLE public.stock_returns
  ALTER COLUMN order_id DROP NOT NULL;

-- 3. Remove legacy default values from orders table
ALTER TABLE public.orders
  ALTER COLUMN product_name DROP DEFAULT,
  ALTER COLUMN client_delivery_fee DROP DEFAULT,
  ALTER COLUMN agent_entitlement DROP DEFAULT;

-- 4. Authoritative update to auto_dispatch_order_by_state_lga
-- Preserves existing distribution_center_id when provided by DC Console or Client Portal
CREATE OR REPLACE FUNCTION auto_dispatch_order_by_state_lga(p_order_id UUID)
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
  SELECT * INTO v_order FROM orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Order not found');
  END IF;

  v_state := COALESCE(TRIM(v_order.delivery_state), '');
  v_lga := COALESCE(TRIM(v_order.lga), '');

  -- Fetch Grand DC fallback (Wuse Central Hub)
  SELECT * INTO v_grand_dc FROM distribution_centers WHERE is_grand_dc = true AND is_active = true ORDER BY created_at ASC LIMIT 1;
  IF v_grand_dc IS NULL THEN
    SELECT * INTO v_grand_dc FROM distribution_centers WHERE is_hub = true AND is_active = true ORDER BY created_at ASC LIMIT 1;
  END IF;
  IF v_grand_dc IS NULL THEN
    SELECT * INTO v_grand_dc FROM distribution_centers WHERE is_active = true ORDER BY created_at ASC LIMIT 1;
  END IF;

  -- 1. Check if the order already has an explicitly designated distribution_center_id
  IF v_order.distribution_center_id IS NOT NULL AND TRIM(v_order.distribution_center_id::text) <> '' THEN
    BEGIN
      SELECT * INTO v_matched_dc
      FROM distribution_centers
      WHERE id = v_order.distribution_center_id::uuid AND is_active = true
      LIMIT 1;
    EXCEPTION WHEN OTHERS THEN
      v_matched_dc := NULL;
    END;
  END IF;

  -- 2. If not pre-assigned, match Distribution Center by State and LGA coverage
  IF v_matched_dc IS NULL THEN
    SELECT * INTO v_matched_dc
    FROM distribution_centers
    WHERE is_active = true
      AND (
        LOWER(state) = LOWER(v_state) 
        OR LOWER(name) ILIKE '%' || LOWER(v_state) || '%'
      )
      AND (
        operating_zones @> to_jsonb(v_lga)
        OR operating_zones::text ILIKE '%' || v_lga || '%'
        OR v_lga = ''
      )
    ORDER BY is_hub DESC, created_at ASC
    LIMIT 1;

    -- Fallback: If no LGA match, check state match
    IF v_matched_dc IS NULL AND v_state <> '' THEN
      SELECT * INTO v_matched_dc
      FROM distribution_centers
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
    UPDATE orders
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
  SELECT * INTO v_matched_driver
  FROM delivery_agents
  WHERE is_active = true
    AND LOWER(current_status) = 'active'
    AND distribution_center_id = v_matched_dc.id
    AND (
      covered_lgas @> to_jsonb(v_lga)
      OR covered_lgas::text ILIKE '%' || v_lga || '%'
      OR operating_city ILIKE '%' || v_lga || '%'
    )
  ORDER BY created_at ASC
  LIMIT 1;

  -- SUCCESS: Eligible Rider Found -> Auto-assign to Rider and create notification
  IF v_matched_driver IS NOT NULL THEN
    UPDATE orders
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
    INSERT INTO notifications (
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
  UPDATE orders
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

-- 5. Notify PostgREST to reload schema
NOTIFY pgrst, 'reload schema';
