-- ============================================================================
-- NOVAXPRESS LOGISTICS - ENFORCE DC SCOPING, ISOLATION & AUTO-NOTIFICATIONS
-- 1. Synchronize users.distribution_center_id with delivery_agents.distribution_center_id
-- 2. Restrict rider auto-matching strictly to the matched DC
-- 3. Synchronize both delivery_agent_id and assigned_agent_id on orders
-- 4. Emit instant push/in-app notifications to riders on order assignment
-- ============================================================================

-- 1. Backfill users with the single DC configured in delivery_agents
UPDATE public.users u
SET distribution_center_id = da.distribution_center_id::text
FROM public.delivery_agents da
WHERE da.user_id = u.id 
  AND da.distribution_center_id IS NOT NULL
  AND (u.distribution_center_id IS NULL OR u.distribution_center_id::text != da.distribution_center_id::text);

-- 2. Trigger function to keep users.distribution_center_id in sync with delivery_agents
CREATE OR REPLACE FUNCTION trg_sync_delivery_agent_dc_to_user()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.distribution_center_id IS NOT NULL AND NEW.user_id IS NOT NULL THEN
    UPDATE public.users
    SET distribution_center_id = NEW.distribution_center_id::text
    WHERE id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_delivery_agent_dc_to_user_trigger ON public.delivery_agents;
CREATE TRIGGER trg_sync_delivery_agent_dc_to_user_trigger
  AFTER INSERT OR UPDATE OF distribution_center_id, user_id ON public.delivery_agents
  FOR EACH ROW
  EXECUTE FUNCTION trg_sync_delivery_agent_dc_to_user();

-- 3. Stored function: auto_dispatch_order_by_state_lga
-- Stricly scopes rider matching to matched DC and sends notifications
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

  -- 1. Match Distribution Center by State and LGA coverage
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

  -- 2. Match Active Rider strictly belonging to matched DC covering this LGA
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

-- 4. Stored function: auto_dispatch_order (Proximity Dispatch)
-- Syncs both delivery_agent_id and assigned_agent_id
CREATE OR REPLACE FUNCTION auto_dispatch_order(
  p_order_id UUID,
  p_max_distance_km DOUBLE PRECISION DEFAULT 25.0
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_order RECORD;
  v_rider RECORD;
BEGIN
  -- 1. Fetch target order
  SELECT * INTO v_order FROM orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Order not found');
  END IF;

  IF v_order.latitude IS NULL OR v_order.longitude IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Order coordinates missing. Geocode order before dispatch.');
  END IF;

  -- 2. Find closest rider using Haversine calculation strictly in the same DC
  SELECT * INTO v_rider FROM find_closest_available_rider(
    v_order.latitude,
    v_order.longitude,
    v_order.distribution_center_id,
    p_max_distance_km
  );

  IF NOT FOUND OR v_rider.delivery_agent_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false, 
      'error', 'No active on-duty rider found within ' || p_max_distance_km || ' km with available capacity.'
    );
  END IF;

  -- 3. Assign order to rider with both ID columns synchronized
  UPDATE orders
  SET 
    delivery_agent_id = v_rider.delivery_agent_id,
    assigned_agent_id = v_rider.delivery_agent_id,
    status = 'assigned',
    assignment_status = 'proximity_assigned',
    assigned_at = NOW(),
    updated_at = NOW()
  WHERE id = p_order_id;

  -- 4. Record order activity
  INSERT INTO order_activities (
    order_id,
    user_id,
    activity_type,
    notes,
    created_at
  ) VALUES (
    p_order_id,
    v_rider.delivery_agent_id,
    'proximity_auto_dispatched',
    'Order automatically assigned to closest rider ' || v_rider.full_name || ' (' || v_rider.agent_code || ') - Distance: ' || ROUND(v_rider.distance_km::NUMERIC, 2) || ' km.',
    NOW()
  );

  -- 5. Send push/in-app notification to rider
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
    v_rider.delivery_agent_id,
    'New Order Assigned (Nearby) 📍',
    'Order #' || v_order.order_number || ' (' || v_order.customer_name || ') is ' || ROUND(v_rider.distance_km::NUMERIC, 1) || ' km from your current position.',
    'delivery',
    '/orders',
    false,
    NOW()
  );

  RETURN jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'rider_id', v_rider.delivery_agent_id,
    'rider_code', v_rider.agent_code,
    'distance_km', ROUND(v_rider.distance_km::NUMERIC, 2)
  );
END;
$$;

-- 5. Trigger to auto-dispatch on new order insert if unassigned
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

DROP TRIGGER IF EXISTS trg_orders_auto_dispatch_after_insert ON orders;
CREATE TRIGGER trg_orders_auto_dispatch_after_insert
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION trg_orders_auto_dispatch();

NOTIFY pgrst, 'reload schema';
