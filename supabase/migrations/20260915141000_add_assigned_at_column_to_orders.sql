-- ============================================================================
-- Migration: 20260915141000_add_assigned_at_column_to_orders.sql
-- Description:
--   Adds assigned_at TIMESTAMPTZ column to public.orders for audit and tracking
--   rider assignment timestamps.
-- ============================================================================

ALTER TABLE IF EXISTS public.orders
    ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_orders_assigned_at ON public.orders(assigned_at);
