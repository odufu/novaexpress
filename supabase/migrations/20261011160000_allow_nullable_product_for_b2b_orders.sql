-- ============================================================================
-- MIGRATION: 20261011160000_allow_nullable_product_for_b2b_orders.sql
-- DESCRIPTION: Allow product_id and base_price to be nullable for client_package orders
-- ============================================================================

ALTER TABLE public.orders
    ALTER COLUMN product_id DROP NOT NULL,
    ALTER COLUMN base_price DROP NOT NULL;

SELECT pg_notify('pgrst', 'reload schema');
