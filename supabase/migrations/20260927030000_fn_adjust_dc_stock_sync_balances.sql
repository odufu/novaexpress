-- ==============================================================================
-- Migration: 20260927020000_fn_adjust_dc_stock_sync_balances.sql
-- Description: Ensures fn_adjust_dc_stock updates both products.dc_stocks and
--              client_stock_balances in lockstep whenever stock is adjusted.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.fn_adjust_dc_stock(
    p_product_id UUID,
    p_dc_id UUID,
    p_delta INT
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_dc_key TEXT := p_dc_id::TEXT;
    v_curr_val INT := 0;
    v_new_val INT := 0;
    v_curr_stocks JSONB;
    v_dc_name TEXT;
    v_dc_code TEXT;
    v_client_id TEXT;
    v_sku TEXT;
    v_name TEXT;
    v_updated_rows INT := 0;
BEGIN
    IF p_product_id IS NULL OR p_dc_id IS NULL OR p_delta = 0 THEN
        RETURN;
    END IF;

    -- 1. Update products.dc_stocks JSONB
    SELECT COALESCE(dc_stocks, '{}'::JSONB), client_id::TEXT, sku, name 
    INTO v_curr_stocks, v_client_id, v_sku, v_name
    FROM public.products
    WHERE id = p_product_id;

    IF v_curr_stocks ? v_dc_key THEN
        v_curr_val := COALESCE((v_curr_stocks->>v_dc_key)::INT, 0);
    END IF;

    v_new_val := GREATEST(0, v_curr_val + p_delta);
    v_curr_stocks := jsonb_set(v_curr_stocks, ARRAY[v_dc_key], to_jsonb(v_new_val), true);

    UPDATE public.products
    SET dc_stocks = v_curr_stocks,
        updated_at = NOW()
    WHERE id = p_product_id;

    -- 2. Keep client_stock_balances in lockstep
    SELECT name, code INTO v_dc_name, v_dc_code FROM public.distribution_centers WHERE id = p_dc_id;
    IF v_dc_name IS NOT NULL THEN
        UPDATE public.client_stock_balances
        SET balance_qty = GREATEST(0, balance_qty + p_delta),
            in_qty = in_qty + CASE WHEN p_delta > 0 THEN p_delta ELSE 0 END,
            out_qty = out_qty + CASE WHEN p_delta < 0 THEN ABS(p_delta) ELSE 0 END,
            updated_at = NOW()
        WHERE (product_id = p_product_id::TEXT OR item_code = v_sku OR LOWER(item_name) = LOWER(v_name))
          AND (
              warehouse = v_dc_name 
              OR LOWER(warehouse) = LOWER(v_dc_name)
              OR (v_dc_code IS NOT NULL AND LOWER(warehouse) LIKE '%' || LOWER(v_dc_code) || '%')
          );
        GET DIAGNOSTICS v_updated_rows = ROW_COUNT;

        -- If no matching warehouse record exists yet and delta is positive, insert initial balance record
        IF v_updated_rows = 0 AND v_client_id IS NOT NULL AND p_delta > 0 THEN
            INSERT INTO public.client_stock_balances (
                client_id,
                product_id,
                item_code,
                item_name,
                warehouse,
                balance_qty,
                in_qty,
                out_qty,
                opening_qty,
                company,
                updated_at
            ) VALUES (
                v_client_id,
                p_product_id::TEXT,
                v_sku,
                v_name,
                v_dc_name,
                p_delta,
                p_delta,
                0,
                0,
                COALESCE((SELECT company_name FROM public.clients WHERE id::TEXT = v_client_id LIMIT 1), 'Merchant'),
                NOW()
            );
        END IF;
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_adjust_dc_stock(UUID, UUID, INT) TO authenticated, service_role, anon;
