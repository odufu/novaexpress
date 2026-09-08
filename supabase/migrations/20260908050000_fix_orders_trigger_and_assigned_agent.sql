-- Fix orders table schema compatibility and trigger function
-- 1. Ensure assigned_agent_id exists on orders table as alias/column
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS assigned_agent_id UUID REFERENCES public.delivery_agents(id) ON DELETE SET NULL;

-- 2. Update trg_orders_auto_dispatch to safely check both delivery_agent_id and assigned_agent_id
CREATE OR REPLACE FUNCTION trg_orders_auto_dispatch()
RETURNS TRIGGER AS $$
BEGIN
  IF COALESCE(NEW.delivery_agent_id, NEW.assigned_agent_id) IS NULL 
     AND (NEW.status = 'pending' OR NEW.status = 'pending_dispatch' OR NEW.status IS NULL OR NEW.status = 'new') THEN
    PERFORM auto_dispatch_order_by_state_lga(NEW.id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Update auto_dispatch_order_by_state_lga to sync both delivery_agent_id and assigned_agent_id
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
  SELECT * INTO v_grand_dc FROM distribution_centers WHERE is_hub = true ORDER BY created_at ASC LIMIT 1;
  IF v_grand_dc IS NULL THEN
    SELECT * INTO v_grand_dc FROM distribution_centers ORDER BY created_at ASC LIMIT 1;
  END IF;

  -- 1. Match Distribution Center by State and LGA
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

  -- FALLBACK A: No DC matches State/LGA -> Route to Grand DC for manual triage
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

  -- 2. Match Active Rider attached to matched DC covering this LGA
  SELECT * INTO v_matched_driver
  FROM delivery_agents
  WHERE is_active = true
    AND LOWER(current_status) = 'active'
    AND (
      distribution_center_id = v_matched_dc.id
      OR distribution_center_id IS NULL
    )
    AND (
      covered_lgas @> to_jsonb(v_lga)
      OR covered_lgas::text ILIKE '%' || v_lga || '%'
      OR operating_city ILIKE '%' || v_lga || '%'
    )
  ORDER BY created_at ASC
  LIMIT 1;

  -- SUCCESS: Eligible Rider Found -> Auto-assign to Rider
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

  -- FALLBACK B: DC matched, but no rider covers this LGA -> Route to Station DC for manual rider assignment
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

-- 4. Re-bind trigger
DROP TRIGGER IF EXISTS trg_orders_auto_dispatch_after_insert ON orders;
CREATE TRIGGER trg_orders_auto_dispatch_after_insert
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION trg_orders_auto_dispatch();

NOTIFY pgrst, 'reload schema';
