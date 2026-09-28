-- ============================================================================
-- Migration: 20260928080000_performance_optimization_gin_and_btree_indexes.sql
-- Description:
--   Full System Audit Performance Optimizations:
--   1. GIN indexes on jsonb columns (operating_zones, covered_lgas) for ultra-fast
--      O(log N) LGA and zone matching in auto-dispatch.
--   2. B-Tree indexes on orders(assignment_status, lead_id, scheduled_delivery_date)
--      and customer_leads(converted_order_id).
--   3. Partial index on distribution_centers(is_main_dc, is_grand_dc) for instant hub resolution.
-- ============================================================================

-- 1. GIN Index on Distribution Centers operating_zones
CREATE INDEX IF NOT EXISTS idx_dc_operating_zones_gin 
  ON public.distribution_centers USING gin (operating_zones);

-- 2. GIN Index on Delivery Agents covered_lgas
CREATE INDEX IF NOT EXISTS idx_delivery_agents_covered_lgas_gin 
  ON public.delivery_agents USING gin (covered_lgas);

-- 3. B-Tree Index on Orders assignment_status for fast closer & DC query filters
CREATE INDEX IF NOT EXISTS idx_orders_assignment_status 
  ON public.orders (assignment_status);

-- 4. B-Tree Index on Orders lead_id for instant lead-order bidirectional resolution
CREATE INDEX IF NOT EXISTS idx_orders_lead_id 
  ON public.orders (lead_id);

-- 5. Partial B-Tree Index on Orders scheduled_delivery_date for closer reschedule calendars
CREATE INDEX IF NOT EXISTS idx_orders_scheduled_delivery_date 
  ON public.orders (scheduled_delivery_date) 
  WHERE scheduled_delivery_date IS NOT NULL;

-- 6. Partial B-Tree Index on Distribution Centers Main DC / Grand DC
CREATE INDEX IF NOT EXISTS idx_dc_is_main_dc 
  ON public.distribution_centers (is_main_dc) 
  WHERE is_main_dc = true;

-- 7. B-Tree Index on customer_leads converted_order_id
CREATE INDEX IF NOT EXISTS idx_customer_leads_converted_order_id 
  ON public.customer_leads (converted_order_id) 
  WHERE converted_order_id IS NOT NULL;

NOTIFY pgrst, 'reload schema';
