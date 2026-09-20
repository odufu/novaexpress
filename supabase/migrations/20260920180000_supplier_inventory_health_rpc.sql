-- ============================================================================
-- NOVAXPRESS LOGISTICS PLATFORM
-- Migration: 20260920180000_supplier_inventory_health_rpc.sql
-- Description:
--   1. Creates fn_get_client_suppliers_overview RPC for real-time inventory aggregation per vendor.
--   2. Calculates remaining network units, low-stock alerts, and replenishment urgency.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_get_client_suppliers_overview(p_client_id TEXT)
RETURNS TABLE (
    supplier_id UUID,
    client_id TEXT,
    supplier_name TEXT,
    category TEXT,
    contact_person TEXT,
    phone TEXT,
    email TEXT,
    address TEXT,
    city TEXT,
    country TEXT,
    lead_time_days INT,
    payment_terms TEXT,
    bank_name TEXT,
    account_number TEXT,
    account_name TEXT,
    notes TEXT,
    is_active BOOLEAN,
    created_at TIMESTAMPTZ,
    supplied_products TEXT[],
    total_remaining_units BIGINT,
    low_stock_count INT,
    critical_reorder_needed BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id AS supplier_id,
        s.client_id,
        s.supplier_name,
        s.category,
        s.contact_person,
        s.phone,
        s.email,
        s.address,
        s.city,
        s.country,
        s.lead_time_days,
        s.payment_terms,
        s.bank_name,
        s.account_number,
        s.account_name,
        s.notes,
        s.is_active,
        s.created_at,
        s.supplied_products,
        COALESCE(SUM(p.stock_quantity), 0)::BIGINT AS total_remaining_units,
        COUNT(p.id) FILTER (WHERE p.stock_quantity <= COALESCE(p.low_stock_threshold, 10))::INT AS low_stock_count,
        BOOL_OR(p.stock_quantity <= COALESCE(p.low_stock_threshold, 10)) AS critical_reorder_needed
    FROM public.client_suppliers s
    LEFT JOIN public.products p 
      ON p.preferred_supplier_id = s.id 
      OR (s.supplied_products @> ARRAY[p.name] OR s.supplied_products @> ARRAY[p.sku])
    WHERE (s.client_id = p_client_id OR p_client_id = 'all')
      AND s.is_active = TRUE
    GROUP BY 
        s.id, s.client_id, s.supplier_name, s.category, s.contact_person, s.phone, s.email, 
        s.address, s.city, s.country, s.lead_time_days, s.payment_terms, s.bank_name, 
        s.account_number, s.account_name, s.notes, s.is_active, s.created_at, s.supplied_products
    ORDER BY critical_reorder_needed DESC, total_remaining_units ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_get_client_suppliers_overview(TEXT) TO authenticated, service_role, anon;
