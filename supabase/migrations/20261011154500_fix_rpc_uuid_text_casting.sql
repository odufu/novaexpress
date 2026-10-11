-- ============================================================================
-- MIGRATION: 20261011154500_fix_rpc_uuid_text_casting.sql
-- DESCRIPTION: Ensure robust type casting (UUID to TEXT) in financial RPC
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_get_merchant_financial_dashboard(
    p_client_id UUID,
    p_product_id UUID DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_start DATE;
    v_end DATE;
    v_sales_revenue NUMERIC(14, 2) := 0.00;
    v_total_expenditures NUMERIC(14, 2) := 0.00;
    v_quantity_sold INT := 0;
    v_net_profit NUMERIC(14, 2) := 0.00;
    v_available_stock INT := 0;
    v_advertisement_exp NUMERIC(14, 2) := 0.00;
    v_procurement_exp NUMERIC(14, 2) := 0.00;
    v_revenue_till_date NUMERIC(14, 2) := 0.00;
    v_daily_trends JSONB := '[]'::jsonb;
    v_state_distribution JSONB := '[]'::jsonb;
    v_product_info JSONB := NULL;
BEGIN
    -- Fallback to default date window (last 30 days if null)
    v_end := COALESCE(p_end_date, CURRENT_DATE);
    v_start := COALESCE(p_start_date, v_end - INTERVAL '30 days');

    -- 1. SALES REVENUE & QUANTITY SOLD (Delivered orders in date window)
    SELECT
        COALESCE(SUM(o.total_amount), 0.00),
        COALESCE(SUM(o.quantity), 0)
    INTO
        v_sales_revenue,
        v_quantity_sold
    FROM public.orders o
    WHERE o.client_id = p_client_id
      AND o.status = 'delivered'
      AND o.created_at::DATE BETWEEN v_start AND v_end
      AND (p_product_id IS NULL OR o.product_id = p_product_id);

    -- 2. TOTAL EXPENDITURES (Category Breakdowns)
    SELECT
        COALESCE(SUM(be.amount), 0.00),
        COALESCE(SUM(CASE WHEN be.category = 'advertisement' THEN be.amount ELSE 0.00 END), 0.00),
        COALESCE(SUM(CASE WHEN be.category = 'procurement' THEN be.amount ELSE 0.00 END), 0.00)
    INTO
        v_total_expenditures,
        v_advertisement_exp,
        v_procurement_exp
    FROM public.business_expenditures be
    WHERE be.client_id = p_client_id
      AND be.entity_type = 'merchant'
      AND be.expenditure_date BETWEEN v_start AND v_end
      AND (
          p_product_id IS NULL 
          OR be.product_id = p_product_id 
          OR be.product_id IS NULL
      );

    -- 3. NET PROFIT (Sales Revenue - Total Expenditures)
    v_net_profit := v_sales_revenue - v_total_expenditures;

    -- 4. AVAILABLE STOCK (Casting to text to match client_stock_balances column types)
    SELECT
        COALESCE(SUM(csb.balance_qty), 0)
    INTO
        v_available_stock
    FROM public.client_stock_balances csb
    WHERE csb.client_id::text = p_client_id::text
      AND (p_product_id IS NULL OR csb.product_id::text = p_product_id::text);

    -- 5. REVENUE TILL DATE (All delivered revenue since inception)
    SELECT
        COALESCE(SUM(o.total_amount), 0.00)
    INTO
        v_revenue_till_date
    FROM public.orders o
    WHERE o.client_id = p_client_id
      AND o.status = 'delivered'
      AND (p_product_id IS NULL OR o.product_id = p_product_id);

    -- 6. DAILY TRENDS (Grouped Bar Chart data: Sales vs Expenditures)
    WITH date_series AS (
        SELECT generate_series(v_start, v_end, '1 day'::interval)::DATE AS dt
    ),
    daily_sales AS (
        SELECT
            o.created_at::DATE AS dt,
            COALESCE(SUM(o.total_amount), 0.00) AS sales,
            COALESCE(SUM(o.quantity), 0) AS units
        FROM public.orders o
        WHERE o.client_id = p_client_id
          AND o.status = 'delivered'
          AND o.created_at::DATE BETWEEN v_start AND v_end
          AND (p_product_id IS NULL OR o.product_id = p_product_id)
        GROUP BY o.created_at::DATE
    ),
    daily_expenses AS (
        SELECT
            be.expenditure_date AS dt,
            COALESCE(SUM(be.amount), 0.00) AS expenses
        FROM public.business_expenditures be
        WHERE be.client_id = p_client_id
          AND be.entity_type = 'merchant'
          AND be.expenditure_date BETWEEN v_start AND v_end
          AND (p_product_id IS NULL OR be.product_id = p_product_id OR be.product_id IS NULL)
        GROUP BY be.expenditure_date
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'date', ds.dt,
            'sales', COALESCE(s.sales, 0.00),
            'expenditure', COALESCE(e.expenses, 0.00),
            'units_sold', COALESCE(s.units, 0),
            'net_margin', COALESCE(s.sales, 0.00) - COALESCE(e.expenses, 0.00)
        ) ORDER BY ds.dt ASC
    )
    INTO v_daily_trends
    FROM date_series ds
    LEFT JOIN daily_sales s ON ds.dt = s.dt
    LEFT JOIN daily_expenses e ON ds.dt = e.dt;

    -- 7. REVENUE BY STATE DISTRIBUTION (Donut Chart)
    SELECT jsonb_agg(
        jsonb_build_object(
            'state', state_data.state,
            'order_count', state_data.order_count,
            'revenue', state_data.revenue
        ) ORDER BY state_data.revenue DESC
    )
    INTO v_state_distribution
    FROM (
        SELECT
            COALESCE(NULLIF(o.customer_state, ''), 'Federal Capital Territory') AS state,
            COUNT(o.id) AS order_count,
            COALESCE(SUM(o.total_amount), 0.00) AS revenue
        FROM public.orders o
        WHERE o.client_id = p_client_id
          AND o.status = 'delivered'
          AND o.created_at::DATE BETWEEN v_start AND v_end
          AND (p_product_id IS NULL OR o.product_id = p_product_id)
        GROUP BY COALESCE(NULLIF(o.customer_state, ''), 'Federal Capital Territory')
    ) state_data;

    -- 8. PRODUCT UNIT ECONOMICS (if specific product selected)
    IF p_product_id IS NOT NULL THEN
        SELECT jsonb_build_object(
            'product_id', p.id,
            'product_name', p.name,
            'sku', p.sku,
            'base_price', p.base_price,
            'cost_price', p.cost_price,
            'units_sold', v_quantity_sold,
            'direct_revenue', v_sales_revenue,
            'direct_advertising', v_advertisement_exp,
            'direct_procurement', v_procurement_exp
        )
        INTO v_product_info
        FROM public.products p
        WHERE p.id = p_product_id;
    END IF;

    -- BUILD CONSOLIDATED JSON RESPONSE
    RETURN jsonb_build_object(
        'client_id', p_client_id,
        'product_id', p_product_id,
        'start_date', v_start,
        'end_date', v_end,
        'sales_revenue', v_sales_revenue,
        'total_expenditures', v_total_expenditures,
        'quantity_sold', v_quantity_sold,
        'net_profit', v_net_profit,
        'available_stock', v_available_stock,
        'advertisement_expenditure', v_advertisement_exp,
        'procurement_expenditure', v_procurement_exp,
        'revenue_till_date', v_revenue_till_date,
        'daily_trends', COALESCE(v_daily_trends, '[]'::jsonb),
        'state_distribution', COALESCE(v_state_distribution, '[]'::jsonb),
        'product_economics', v_product_info
    );
END;
$$;

SELECT pg_notify('pgrst', 'reload schema');
