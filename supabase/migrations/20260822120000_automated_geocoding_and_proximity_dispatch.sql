-- ============================================================================
-- NovaExpress Logistics Management System (NoveXPS)
-- Database Migration: Automated Geocoding, Proximity Dispatch & Spatial Indexing
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

NOTIFY pgrst, 'reload schema';

-- ----------------------------------------------------------------------------
-- 1. ORDERS TABLE EXTENSIONS FOR GEOCODING & LOCATION
-- ----------------------------------------------------------------------------
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS geocoding_status VARCHAR(32) DEFAULT 'pending';
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS geocoded_address TEXT;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS location_confidence REAL DEFAULT 0.0;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS is_location_verified BOOLEAN DEFAULT FALSE;

-- ----------------------------------------------------------------------------
-- 2. USERS & DELIVERY AGENTS TABLE EXTENSIONS FOR GPS TELEMETRY & DISPATCH
-- ----------------------------------------------------------------------------
ALTER TABLE IF EXISTS users ADD COLUMN IF NOT EXISTS current_latitude DOUBLE PRECISION;
ALTER TABLE IF EXISTS users ADD COLUMN IF NOT EXISTS current_longitude DOUBLE PRECISION;
ALTER TABLE IF EXISTS users ADD COLUMN IF NOT EXISTS last_location_update TIMESTAMPTZ;
ALTER TABLE IF EXISTS users ADD COLUMN IF NOT EXISTS is_on_duty BOOLEAN DEFAULT TRUE;
ALTER TABLE IF EXISTS users ADD COLUMN IF NOT EXISTS max_active_orders INT DEFAULT 15;
ALTER TABLE IF EXISTS users ADD COLUMN IF NOT EXISTS assigned_zones TEXT[] DEFAULT ARRAY[]::TEXT[];

ALTER TABLE IF EXISTS delivery_agents ADD COLUMN IF NOT EXISTS current_latitude DOUBLE PRECISION;
ALTER TABLE IF EXISTS delivery_agents ADD COLUMN IF NOT EXISTS current_longitude DOUBLE PRECISION;
ALTER TABLE IF EXISTS delivery_agents ADD COLUMN IF NOT EXISTS last_location_update TIMESTAMPTZ;
ALTER TABLE IF EXISTS delivery_agents ADD COLUMN IF NOT EXISTS is_on_duty BOOLEAN DEFAULT TRUE;
ALTER TABLE IF EXISTS delivery_agents ADD COLUMN IF NOT EXISTS max_active_orders INT DEFAULT 15;
ALTER TABLE IF EXISTS delivery_agents ADD COLUMN IF NOT EXISTS assigned_zones TEXT[] DEFAULT ARRAY[]::TEXT[];

-- ----------------------------------------------------------------------------
-- 3. SPATIAL & PERFORMANCE INDEXES
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_orders_coordinates ON orders (latitude, longitude) WHERE latitude IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_orders_geocoding_status ON orders (geocoding_status);
CREATE INDEX IF NOT EXISTS idx_delivery_agents_telemetry ON delivery_agents (current_latitude, current_longitude) WHERE current_latitude IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_delivery_agents_duty_status ON delivery_agents (is_on_duty, distribution_center_id);

-- ----------------------------------------------------------------------------
-- 4. PURE SQL SCALAR FUNCTION: calculate_haversine_distance_km
-- Calculates great-circle distance between two (lat, lon) coordinates in Kilometers
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calculate_haversine_distance_km(
  p_lat1 DOUBLE PRECISION,
  p_lon1 DOUBLE PRECISION,
  p_lat2 DOUBLE PRECISION,
  p_lon2 DOUBLE PRECISION
)
RETURNS DOUBLE PRECISION
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
  SELECT (6371.0 * acos(
    LEAST(1.0, GREATEST(-1.0,
      cos(radians(p_lat1)) * cos(radians(p_lat2)) *
      cos(radians(p_lon2) - radians(p_lon1)) +
      sin(radians(p_lat1)) * sin(radians(p_lat2))
    ))
  ));
$$;

-- ----------------------------------------------------------------------------
-- 5. STORED FUNCTION: find_closest_available_rider
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION find_closest_available_rider(
  p_order_lat DOUBLE PRECISION,
  p_order_lng DOUBLE PRECISION,
  p_distribution_center_id UUID DEFAULT NULL,
  p_max_distance_km DOUBLE PRECISION DEFAULT 25.0
)
RETURNS TABLE (
  delivery_agent_id UUID,
  agent_code VARCHAR,
  full_name TEXT,
  phone TEXT,
  current_lat DOUBLE PRECISION,
  current_lng DOUBLE PRECISION,
  distance_km DOUBLE PRECISION,
  active_orders_count INT
)
LANGUAGE sql
STABLE
AS $$
  SELECT 
    da.id AS delivery_agent_id,
    da.agent_code,
    COALESCE(u.first_name || ' ' || u.last_name, u.email, da.agent_code) AS full_name,
    COALESCE(u.phone_number, da.agent_code) AS phone,
    COALESCE(da.current_latitude, u.current_latitude) AS current_lat,
    COALESCE(da.current_longitude, u.current_longitude) AS current_lng,
    calculate_haversine_distance_km(
      p_order_lat, 
      p_order_lng, 
      COALESCE(da.current_latitude, u.current_latitude), 
      COALESCE(da.current_longitude, u.current_longitude)
    ) AS distance_km,
    (
      SELECT COUNT(*)::INT 
      FROM orders o 
      WHERE o.delivery_agent_id = da.id 
        AND o.status IN ('accepted', 'in_transit', 'pending', 'assigned')
    ) AS active_orders_count
  FROM delivery_agents da
  JOIN users u ON da.user_id = u.id
  WHERE (p_distribution_center_id IS NULL OR da.distribution_center_id = p_distribution_center_id)
    AND COALESCE(da.is_on_duty, u.is_on_duty, true) = TRUE
    AND COALESCE(da.current_latitude, u.current_latitude) IS NOT NULL
    AND COALESCE(da.current_longitude, u.current_longitude) IS NOT NULL
    AND (
      SELECT COUNT(*) 
      FROM orders o 
      WHERE o.delivery_agent_id = da.id 
        AND o.status IN ('accepted', 'in_transit', 'pending', 'assigned')
    ) < COALESCE(da.max_active_orders, u.max_active_orders, 15)
    AND calculate_haversine_distance_km(
      p_order_lat, 
      p_order_lng, 
      COALESCE(da.current_latitude, u.current_latitude), 
      COALESCE(da.current_longitude, u.current_longitude)
    ) <= p_max_distance_km
  ORDER BY distance_km ASC, active_orders_count ASC
  LIMIT 1;
$$;

-- ----------------------------------------------------------------------------
-- 6. STORED FUNCTION: auto_dispatch_order
-- ----------------------------------------------------------------------------
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

  -- 2. Find closest rider using Haversine calculation
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

  -- 3. Assign order to rider
  UPDATE orders
  SET 
    delivery_agent_id = v_rider.delivery_agent_id,
    status = 'assigned',
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
    user_id,
    title,
    message,
    category,
    action_route,
    is_read,
    created_at
  ) VALUES (
    v_order.company_id,
    v_rider.delivery_agent_id,
    'New Order Assigned (Nearby) 📍',
    'Order #' || v_order.order_number || ' (' || v_order.customer_name || ') is ' || ROUND(v_rider.distance_km::NUMERIC, 1) || ' km from your current position.',
    'delivery',
    '/orders/' || p_order_id,
    false,
    NOW()
  );

  RETURN jsonb_build_object(
    'success', true,
    'orderId', p_order_id,
    'riderId', v_rider.delivery_agent_id,
    'riderName', v_rider.full_name,
    'riderCode', v_rider.agent_code,
    'distanceKm', ROUND(v_rider.distance_km::NUMERIC, 2),
    'activeOrdersCount', v_rider.active_orders_count + 1
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 7. STORED FUNCTION: update_rider_gps_telemetry
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_rider_gps_telemetry(
  p_agent_id UUID,
  p_latitude DOUBLE PRECISION,
  p_longitude DOUBLE PRECISION
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE delivery_agents
  SET 
    current_latitude = p_latitude,
    current_longitude = p_longitude,
    last_location_update = NOW(),
    updated_at = NOW()
  WHERE id = p_agent_id;

  UPDATE users
  SET 
    current_latitude = p_latitude,
    current_longitude = p_longitude,
    last_location_update = NOW(),
    updated_at = NOW()
  WHERE id = p_agent_id OR id = (SELECT user_id FROM delivery_agents WHERE id = p_agent_id);
END;
$$;

-- ----------------------------------------------------------------------------
-- 8. STORED FUNCTION: record_verified_gate_pin
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION record_verified_gate_pin(
  p_order_id UUID,
  p_latitude DOUBLE PRECISION,
  p_longitude DOUBLE PRECISION,
  p_geocoded_address TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE orders
  SET 
    latitude = p_latitude,
    longitude = p_longitude,
    is_location_verified = TRUE,
    location_confidence = 1.0,
    geocoding_status = 'exact_verified',
    geocoded_address = COALESCE(p_geocoded_address, geocoded_address),
    updated_at = NOW()
  WHERE id = p_order_id;
END;
$$;

-- ----------------------------------------------------------------------------
-- 9. SEED DATA REFINEMENT: REALISTIC GPS FIXES FOR RIDERS & ORDERS
-- ----------------------------------------------------------------------------
-- Update Rider PDA-7000 (Emeka Rider) location to Wuse 2
UPDATE delivery_agents
SET 
  current_latitude = 9.0765,
  current_longitude = 7.4832,
  is_on_duty = TRUE,
  max_active_orders = 15,
  last_location_update = NOW()
WHERE agent_code = 'PDA-7000';

UPDATE users
SET 
  current_latitude = 9.0765,
  current_longitude = 7.4832,
  last_location_update = NOW()
WHERE email = 'emeka.rider@novaexpress.ng';

-- Update Sample Orders with Geocoded Locations & Verification
UPDATE orders
SET 
  latitude = 9.0765,
  longitude = 7.4832,
  geocoding_status = 'exact_verified',
  geocoded_address = 'Plot 402 Aminu Kano Crescent, Wuse 2, Abuja, Nigeria',
  location_confidence = 0.95,
  is_location_verified = true
WHERE order_number = 'TRK-8924';

UPDATE orders
SET 
  latitude = 9.0882,
  longitude = 7.4933,
  geocoding_status = 'landmark_match',
  geocoded_address = 'Maitama District, Abuja, Nigeria',
  location_confidence = 0.85,
  is_location_verified = false
WHERE order_number = 'TRK-8925';

UPDATE orders
SET 
  latitude = 9.0345,
  longitude = 7.4891,
  geocoding_status = 'exact_verified',
  geocoded_address = '22 Area 11, Garki, Abuja, Nigeria',
  location_confidence = 0.90,
  is_location_verified = true
WHERE order_number = 'TRK-8926';

UPDATE orders
SET 
  latitude = 9.0435,
  longitude = 7.5255,
  geocoding_status = 'landmark_match',
  geocoded_address = '8 Yakubu Gowon Crescent, Asokoro, Abuja, Nigeria',
  location_confidence = 0.80,
  is_location_verified = false
WHERE order_number = 'TRK-8927';

NOTIFY pgrst, 'reload schema';
