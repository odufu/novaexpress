-- ==============================================================================
-- Migration: 20260927013000_fn_get_product_holders_custody_pure_sql.sql
-- Description: Declarative, high-performance pure SQL implementation of fn_get_product_holders_custody
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.fn_get_product_holders_custody(
    p_client_id UUID,
    p_product_id UUID DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_state TEXT DEFAULT NULL,
    p_lga TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    WITH dc_positions AS (
        SELECT 
            sb.id::TEXT AS id,
            COALESCE(dc.id::TEXT, sb.id::TEXT) AS holder_id,
            COALESCE(dc.name, sb.warehouse) AS holder_name,
            CASE 
                WHEN dc.is_grand_dc OR LOWER(sb.warehouse) LIKE '%grand%' THEN 'Grand DC'
                WHEN dc.is_hub OR LOWER(sb.warehouse) LIKE '%hub%' THEN 'Hub Distribution Center'
                WHEN dc.id IS NOT NULL OR LOWER(sb.warehouse) LIKE '%center%' OR LOWER(sb.warehouse) LIKE '%dc%' OR LOWER(sb.warehouse) LIKE '%distribution%' THEN 'Distribution Center'
                ELSE 'Central Storage / In-Transit'
            END AS holder_type,
            COALESCE(dc.state, 'Federal Capital Territory') AS state,
            COALESCE(dc.operating_zones->>0, '') AS lga,
            COALESCE(dc.city, '') AS city,
            COALESCE(dc.contact_phone, '') AS phone,
            COALESCE(p.id::TEXT, sb.product_id, '') AS product_id,
            sb.item_code AS product_sku,
            sb.item_name AS product_name,
            COALESCE(sb.opening_qty, sb.balance_qty)::INT AS opening_qty,
            COALESCE(sb.opening_value, sb.balance_value)::NUMERIC(14,2) AS opening_value,
            COALESCE(sb.in_qty, 0)::INT AS in_qty,
            COALESCE(sb.in_value, 0)::NUMERIC(14,2) AS in_value,
            COALESCE(sb.out_qty, 0)::INT AS out_qty,
            COALESCE(sb.out_value, 0)::NUMERIC(14,2) AS out_value,
            COALESCE(sb.balance_qty, 0)::INT AS closing_qty,
            COALESCE(sb.balance_value, 0)::NUMERIC(14,2) AS closing_value,
            COALESCE(sb.valuation_rate, p.base_price, 0.00)::NUMERIC(14,2) AS valuation_rate,
            sb.updated_at AS last_updated,
            CASE 
                WHEN sb.balance_qty <= 0 THEN 'Out of Stock'
                WHEN sb.balance_qty <= COALESCE(sb.low_stock_threshold, 10) THEN 'Low Stock'
                ELSE 'Active Custody'
            END AS status
        FROM public.client_stock_balances sb
        LEFT JOIN public.products p ON (p.id::TEXT = sb.product_id OR p.sku = sb.item_code OR LOWER(p.name) = LOWER(sb.item_name))
        LEFT JOIN public.distribution_centers dc ON (
            LOWER(dc.name) = LOWER(sb.warehouse)
            OR LOWER(dc.code) = LOWER(sb.warehouse)
            OR LOWER(sb.warehouse) LIKE '%' || LOWER(dc.name) || '%'
            OR LOWER(dc.name) LIKE '%' || LOWER(sb.warehouse) || '%'
        )
        WHERE sb.client_id = p_client_id::TEXT
          AND (p_product_id IS NULL OR p.id = p_product_id OR sb.product_id = p_product_id::TEXT)
          AND (p_state IS NULL OR p_state = 'All States' OR LOWER(COALESCE(dc.state, 'Federal Capital Territory')) = LOWER(p_state))
          AND (p_lga IS NULL OR p_lga = 'All LGAs' OR LOWER(COALESCE(dc.operating_zones->>0, '')) LIKE '%' || LOWER(p_lga) || '%')
    ),
    pda_positions AS (
        SELECT 
            ai.id::TEXT AS id,
            da.id::TEXT AS holder_id,
            COALESCE(da.bank_account_name, da.agent_code, 'Dispatch PDA') || ' (' || COALESCE(da.agent_code, 'PDA') || ')' AS holder_name,
            'PDA / Dispatch Personnel' AS holder_type,
            COALESCE(da.operating_state, 'Abuja (FCT)') AS state,
            COALESCE(da.operating_city, '') AS lga,
            COALESCE(da.operating_city, '') AS city,
            '' AS phone,
            p.id::TEXT AS product_id,
            p.sku AS product_sku,
            p.name AS product_name,
            COALESCE(ai.total_in_custody, 0)::INT AS opening_qty,
            (COALESCE(ai.total_in_custody, 0) * COALESCE(p.base_price, 0.00))::NUMERIC(14,2) AS opening_value,
            0::INT AS in_qty,
            0.00::NUMERIC(14,2) AS in_value,
            COALESCE(ai.delivered_count_today, 0)::INT AS out_qty,
            (COALESCE(ai.delivered_count_today, 0) * COALESCE(p.base_price, 0.00))::NUMERIC(14,2) AS out_value,
            COALESCE(ai.available_count, ai.total_in_custody, 0)::INT AS closing_qty,
            (COALESCE(ai.available_count, ai.total_in_custody, 0) * COALESCE(p.base_price, 0.00))::NUMERIC(14,2) AS closing_value,
            COALESCE(p.base_price, 0.00)::NUMERIC(14,2) AS valuation_rate,
            ai.updated_at AS last_updated,
            CASE 
                WHEN COALESCE(ai.available_count, 0) <= 0 THEN 'Out of Stock'
                WHEN COALESCE(ai.available_count, 0) <= 5 THEN 'Low Stock'
                ELSE 'Active Custody'
            END AS status
        FROM public.agent_inventory ai
        JOIN public.products p ON p.id = ai.product_id
        JOIN public.delivery_agents da ON da.id = ai.delivery_agent_id
        WHERE (p.client_id = p_client_id OR p.client_name IN (SELECT company_name FROM public.clients WHERE id = p_client_id))
          AND (p_product_id IS NULL OR p.id = p_product_id)
          AND (p_state IS NULL OR p_state = 'All States' OR LOWER(COALESCE(da.operating_state, '')) = LOWER(p_state))
          AND (p_lga IS NULL OR p_lga = 'All LGAs' OR LOWER(COALESCE(da.operating_city, '')) LIKE '%' || LOWER(p_lga) || '%')
    ),
    combined AS (
        SELECT * FROM dc_positions
        UNION ALL
        SELECT * FROM pda_positions
    )
    SELECT COALESCE(jsonb_agg(to_jsonb(c)), '[]'::jsonb) FROM combined c;
$$;

GRANT EXECUTE ON FUNCTION public.fn_get_product_holders_custody(UUID, UUID, DATE, DATE, TEXT, TEXT) TO authenticated, service_role, anon;
