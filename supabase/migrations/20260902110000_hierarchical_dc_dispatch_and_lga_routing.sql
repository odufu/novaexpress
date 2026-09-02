-- ============================================================================
-- NOVAEXPRESS LOGISTICS PLATFORM - HIERARCHICAL DC & LGA DISPATCH ENGINE
-- Production-grade schema & triggers for:
--   1. Grand DC vs Regional Station DC designation
--   2. Order state & LGA multi-zone dispatching
--   3. Fallback escalation (Grand DC vs Station DC)
-- ============================================================================

-- 1. Extend distribution_centers table with is_grand_dc column
ALTER TABLE distribution_centers
  ADD COLUMN IF NOT EXISTS is_grand_dc BOOLEAN DEFAULT false;

-- Designate Wuse Central Distribution Hub (or primary hub) as Grand DC
UPDATE distribution_centers
SET is_grand_dc = true
WHERE code = 'DC-ABJ-01' OR id = '22222222-2222-4222-8222-222222222222';

-- 2. Extend orders table with routing & assignment tracking columns
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS distribution_center_id TEXT,
  ADD COLUMN IF NOT EXISTS delivery_state TEXT,
  ADD COLUMN IF NOT EXISTS delivery_lga TEXT,
  ADD COLUMN IF NOT EXISTS assignment_status TEXT DEFAULT 'auto_assigned',
  ADD COLUMN IF NOT EXISTS routing_notes TEXT;

-- 3. PostgreSQL Stored Procedure for Automatic Order Dispatch by State & LGA
CREATE OR REPLACE FUNCTION auto_dispatch_order_by_state_lga(p_order_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
  v_matched_dc RECORD;
  v_grand_dc RECORD;
  v_matched_driver RECORD;
  v_res JSONB;
  v_state TEXT;
  v_lga TEXT;
BEGIN
  -- Fetch the order
  SELECT * INTO v_order FROM orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Order not found');
  END IF;

  v_state := TRIM(COALESCE(v_order.delivery_state, v_order.destination_state, ''));
  v_lga := TRIM(COALESCE(v_order.delivery_lga, v_order.lga, ''));

  -- Fetch Grand DC
  SELECT * INTO v_grand_dc FROM distribution_centers WHERE is_grand_dc = true AND is_active = true LIMIT 1;
  IF NOT FOUND THEN
    SELECT * INTO v_grand_dc FROM distribution_centers WHERE is_active = true ORDER BY created_at ASC LIMIT 1;
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

-- 4. Trigger to auto-dispatch on new order insert if unassigned
CREATE OR REPLACE FUNCTION trg_orders_auto_dispatch()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.assigned_agent_id IS NULL AND (NEW.status = 'pending' OR NEW.status = 'pending_dispatch' OR NEW.status IS NULL) THEN
    PERFORM auto_dispatch_order_by_state_lga(NEW.id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_orders_auto_dispatch_after_insert ON orders;
CREATE TRIGGER trg_orders_auto_dispatch_after_insert
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION trg_orders_auto_dispatch();

-- 5. Notify PostgREST to reload schema cache
NOTIFY pgrst, 'reload schema';
