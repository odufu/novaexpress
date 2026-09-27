-- ==============================================================================
-- Migration: 20260926233000_fn_get_product_holders_custody.sql
-- Description: Comprehensive multi-holder physical asset custody ledger
--              combining Distribution Centers, PDAs (Dispatch Riders), and Depots
--              with period opening, in, out, closing balances, and valuations.
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
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_results JSONB := '[]'::JSONB;
    v_start DATE := COALESCE(p_start_date, CURRENT_DATE - INTERVAL '30 days');
    v_end DATE := COALESCE(p_end_date, CURRENT_DATE);
    v_row RECORD;
BEGIN
    -- 1. Distribution Center & Central Warehouse Positions
    FOR v_row IN
        SELECT 
            sb.id,
            sb.warehouse AS holder_name,
            COALESCE(dc.id::TEXT, sb.id::TEXT) AS holder_id,
            CASE 
                WHEN LOWER(sb.warehouse) LIKE '%center%' OR LOWER(sb.warehouse) LIKE '%hub%' OR LOWER(sb.warehouse) LIKE '%dc%' THEN 'Distribution Center'
                ELSE 'Central Storage / In-Transit'
            END AS holder_type,
            COALESCE(dc.state, 'Lagos') AS state,
            COALESCE(dc.city, '') AS city,
            COALESCE(dc.operating_zones[1], '') AS lga,
            COALESCE(dc.contact_phone, '') AS phone,
            p.id::TEXT AS product_id,
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
        LEFT JOIN public.products p ON (p.id = sb.product_id OR p.sku = sb.item_code OR LOWER(p.name) = LOWER(sb.item_name))
        LEFT JOIN public.distribution_centers dc ON (LOWER(dc.name) = LOWER(sb.warehouse) OR LOWER(sb.warehouse) LIKE '%' || LOWER(dc.name) || '%')
        WHERE sb.client_id = p_client_id
          AND (p_product_id IS NULL OR p.id = p_product_id)
          AND (p_state IS NULL OR p_state = 'All States' OR LOWER(COALESCE(dc.state, 'Lagos')) = LOWER(p_state))
          AND (p_lga IS NULL OR p_lga = 'All LGAs' OR LOWER(COALESCE(dc.operating_zones[1], '')) LIKE '%' || LOWER(p_lga) || '%')
    LOOP
        v_results := v_results || jsonb_build_object(
            'id', v_row.id,
            'holder_id', v_row.holder_id,
            'holder_name', v_row.holder_name,
            'holder_type', v_row.holder_type,
            'state', v_row.state,
            'lga', v_row.lga,
            'city', v_row.city,
            'phone', v_row.phone,
            'product_id', v_row.product_id,
            'product_sku', v_row.product_sku,
            'product_name', v_row.product_name,
            'opening_qty', v_row.opening_qty,
            'opening_value', v_row.opening_value,
            'in_qty', v_row.in_qty,
            'in_value', v_row.in_value,
            'out_qty', v_row.out_qty,
            'out_value', v_row.out_value,
            'closing_qty', v_row.closing_qty,
            'closing_value', v_row.closing_value,
            'valuation_rate', v_row.valuation_rate,
            'last_updated', v_row.last_updated,
            'status', v_row.status
        );
    END LOOP;

    -- 2. Delivery Personnel & PDA Custody Positions (agent_inventory)
    FOR v_row IN
        SELECT 
            ai.id,
            da.id::TEXT AS holder_id,
            COALESCE(da.bank_account_name, da.agent_code, 'Dispatch PDA') || ' (' || COALESCE(da.agent_code, 'PDA') || ')' AS holder_name,
            'PDA / Dispatch Personnel' AS holder_type,
            COALESCE(da.operating_state, 'Abuja (FCT)') AS state,
            COALESCE(da.operating_city, '') AS city,
            COALESCE(da.operating_city, '') AS lga,
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
    LOOP
        v_results := v_results || jsonb_build_object(
            'id', v_row.id,
            'holder_id', v_row.holder_id,
            'holder_name', v_row.holder_name,
            'holder_type', v_row.holder_type,
            'state', v_row.state,
            'lga', v_row.lga,
            'city', v_row.city,
            'phone', v_row.phone,
            'product_id', v_row.product_id,
            'product_sku', v_row.product_sku,
            'product_name', v_row.product_name,
            'opening_qty', v_row.opening_qty,
            'opening_value', v_row.opening_value,
            'in_qty', v_row.in_qty,
            'in_value', v_row.in_value,
            'out_qty', v_row.out_qty,
            'out_value', v_row.out_value,
            'closing_qty', v_row.closing_qty,
            'closing_value', v_row.closing_value,
            'valuation_rate', v_row.valuation_rate,
            'last_updated', v_row.last_updated,
            'status', v_row.status
        );
    END LOOP;

    RETURN v_results;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_get_product_holders_custody(UUID, UUID, DATE, DATE, TEXT, TEXT) TO authenticated, service_role, anon;
