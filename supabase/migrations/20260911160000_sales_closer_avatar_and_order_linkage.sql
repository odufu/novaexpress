-- ==============================================================================
-- SALES CLOSER PROFILE, AVATAR, AND ORDER LINKAGE MIGRATION
-- Migration: 20260911160000_sales_closer_avatar_and_order_linkage.sql
-- ==============================================================================

-- 1. Ensure avatar_url column exists on client_closers and users
ALTER TABLE IF EXISTS public.client_closers
  ADD COLUMN IF NOT EXISTS avatar_url TEXT;

ALTER TABLE IF EXISTS public.users
  ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- 2. Ensure closer_id and closer_name exist on orders table
ALTER TABLE IF EXISTS public.orders
  ADD COLUMN IF NOT EXISTS closer_id UUID REFERENCES public.client_closers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS closer_name TEXT,
  ADD COLUMN IF NOT EXISTS closer_code TEXT;

-- 3. Create index for high-speed query filtering on orders by closer
CREATE INDEX IF NOT EXISTS idx_orders_closer_id ON public.orders(closer_id);

-- 4. Function & trigger to sync closer metrics when orders are created or updated
CREATE OR REPLACE FUNCTION public.sync_closer_order_counts()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.closer_id IS NOT NULL THEN
    UPDATE public.client_closers
    SET 
      total_orders_booked = (
        SELECT COUNT(*) FROM public.orders 
        WHERE closer_id = NEW.closer_id
      ),
      total_orders_delivered = (
        SELECT COUNT(*) FROM public.orders 
        WHERE closer_id = NEW.closer_id 
          AND LOWER(status) IN ('delivered', 'completed')
      ),
      updated_at = NOW()
    WHERE id = NEW.closer_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_closer_order_counts ON public.orders;
CREATE TRIGGER trg_sync_closer_order_counts
  AFTER INSERT OR UPDATE OF status, closer_id ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_closer_order_counts();
