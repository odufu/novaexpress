-- ============================================================================
-- MIGRATION: 20261011140000_business_expenditures_and_financial_analytics.sql
-- DESCRIPTION: Universal Multi-Tier Expenditure Ledger & High-Performance RPCs
-- AUTHOR: NovaExpress Engineering / Architecture Council
-- ============================================================================

-- 1. STORAGE BUCKET FOR RECEIPT & INVOICE ATTACHMENTS (PDF / IMAGES)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'expenditure-receipts',
    'expenditure-receipts',
    true,
    15728640, -- 15MB limit
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Storage bucket access policies
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Public Access for Expenditure Receipts') THEN
        CREATE POLICY "Public Access for Expenditure Receipts" ON storage.objects
            FOR SELECT USING (bucket_id = 'expenditure-receipts');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Allow Uploads for Expenditure Receipts') THEN
        CREATE POLICY "Allow Uploads for Expenditure Receipts" ON storage.objects
            FOR INSERT WITH CHECK (bucket_id = 'expenditure-receipts');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Allow Updates for Expenditure Receipts') THEN
        CREATE POLICY "Allow Updates for Expenditure Receipts" ON storage.objects
            FOR UPDATE USING (bucket_id = 'expenditure-receipts');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Allow Deletes for Expenditure Receipts') THEN
        CREATE POLICY "Allow Deletes for Expenditure Receipts" ON storage.objects
            FOR DELETE USING (bucket_id = 'expenditure-receipts');
    END IF;
END $$;

-- 2. UNIVERSAL BUSINESS EXPENDITURES TABLE
CREATE TABLE IF NOT EXISTS public.business_expenditures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type TEXT NOT NULL CHECK (entity_type IN ('merchant', 'grand_dc', 'sub_dc')),
    client_id UUID REFERENCES public.clients(id) ON DELETE CASCADE,
    distribution_center_id UUID REFERENCES public.distribution_centers(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL, -- HYBRID LINK: NULL = Overhead, UUID = SKU-specific
    title TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL CHECK (category IN (
        'advertisement',
        'procurement',
        'logistics',
        'salaries',
        'rent_utilities',
        'packaging',
        'rider_allowance',
        'diesel_fuel',
        'equipment_maintenance',
        'other'
    )),
    amount NUMERIC(14, 2) NOT NULL CHECK (amount >= 0),
    expenditure_date DATE NOT NULL DEFAULT CURRENT_DATE,
    receipt_url TEXT,
    receipt_file_name TEXT,
    receipt_mime_type TEXT,
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for lightning-fast aggregation & dashboard queries
CREATE INDEX IF NOT EXISTS idx_expenditures_client_date ON public.business_expenditures(client_id, expenditure_date);
CREATE INDEX IF NOT EXISTS idx_expenditures_dc_date ON public.business_expenditures(distribution_center_id, expenditure_date);
CREATE INDEX IF NOT EXISTS idx_expenditures_product ON public.business_expenditures(product_id);
CREATE INDEX IF NOT EXISTS idx_expenditures_category ON public.business_expenditures(category);
CREATE INDEX IF NOT EXISTS idx_expenditures_entity_type ON public.business_expenditures(entity_type);

-- Enable RLS
ALTER TABLE public.business_expenditures ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'business_expenditures' AND policyname = 'Allow read for all authenticated users') THEN
        CREATE POLICY "Allow read for all authenticated users" ON public.business_expenditures
            FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'business_expenditures' AND policyname = 'Allow insert for authenticated users') THEN
        CREATE POLICY "Allow insert for authenticated users" ON public.business_expenditures
            FOR INSERT WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'business_expenditures' AND policyname = 'Allow update for authenticated users') THEN
        CREATE POLICY "Allow update for authenticated users" ON public.business_expenditures
            FOR UPDATE USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'business_expenditures' AND policyname = 'Allow delete for authenticated users') THEN
        CREATE POLICY "Allow delete for authenticated users" ON public.business_expenditures
            FOR DELETE USING (true);
    END IF;
END $$;

-- 3. STORED PROCEDURE: fn_get_merchant_financial_dashboard
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
          -- If filtering by product: include product-specific AND proportion of unlinked overhead
          p_product_id IS NULL 
          OR be.product_id = p_product_id 
          OR be.product_id IS NULL
      );

    -- 3. NET PROFIT (Sales Revenue - Total Expenditures)
    v_net_profit := v_sales_revenue - v_total_expenditures;

    -- 4. AVAILABLE STOCK (Real-time balance from client_stock_balances)
    SELECT
        COALESCE(SUM(csb.current_balance), 0)
    INTO
        v_available_stock
    FROM public.client_stock_balances csb
    WHERE csb.client_id = p_client_id
      AND (p_product_id IS NULL OR csb.product_id = p_product_id);

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

-- 4. STORED PROCEDURE: fn_get_dc_logistics_dashboard
CREATE OR REPLACE FUNCTION public.fn_get_dc_logistics_dashboard(
    p_dc_id UUID DEFAULT NULL,
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
    v_logistics_gross_revenue NUMERIC(14, 2) := 0.00;
    v_network_opex NUMERIC(14, 2) := 0.00;
    v_total_parcels_handled INT := 0;
    v_net_logistics_margin NUMERIC(14, 2) := 0.00;
    v_vault_inventory INT := 0;
    v_rider_allowances NUMERIC(14, 2) := 0.00;
    v_facility_capex NUMERIC(14, 2) := 0.00;
    v_cumulative_revenue NUMERIC(14, 2) := 0.00;
    v_daily_trends JSONB := '[]'::jsonb;
    v_dc_breakdown JSONB := '[]'::jsonb;
BEGIN
    v_end := COALESCE(p_end_date, CURRENT_DATE);
    v_start := COALESCE(p_start_date, v_end - INTERVAL '30 days');

    -- 1. LOGISTICS REVENUE & PARCEL VOLUMES
    SELECT
        COALESCE(SUM(o.client_delivery_fee), 0.00),
        COUNT(o.id)
    INTO
        v_logistics_gross_revenue,
        v_total_parcels_handled
    FROM public.orders o
    WHERE o.status = 'delivered'
      AND o.created_at::DATE BETWEEN v_start AND v_end
      AND (p_dc_id IS NULL OR o.assigned_dc_id = p_dc_id);

    -- 2. OPERATIONAL EXPENDITURES
    SELECT
        COALESCE(SUM(be.amount), 0.00),
        COALESCE(SUM(CASE WHEN be.category = 'rider_allowance' THEN be.amount ELSE 0.00 END), 0.00),
        COALESCE(SUM(CASE WHEN be.category IN ('rent_utilities', 'equipment_maintenance', 'diesel_fuel') THEN be.amount ELSE 0.00 END), 0.00)
    INTO
        v_network_opex,
        v_rider_allowances,
        v_facility_capex
    FROM public.business_expenditures be
    WHERE be.entity_type IN ('grand_dc', 'sub_dc')
      AND be.expenditure_date BETWEEN v_start AND v_end
      AND (p_dc_id IS NULL OR be.distribution_center_id = p_dc_id);

    -- 3. NET LOGISTICS PLATFORM PROFIT
    v_net_logistics_margin := v_logistics_gross_revenue - v_network_opex;

    -- 4. VAULT INVENTORY COUNT
    SELECT COALESCE(SUM(csb.current_balance), 0)
    INTO v_vault_inventory
    FROM public.client_stock_balances csb
    WHERE (p_dc_id IS NULL OR csb.distribution_center_id = p_dc_id);

    -- 5. CUMULATIVE REVENUE TO DATE
    SELECT COALESCE(SUM(o.client_delivery_fee), 0.00)
    INTO v_cumulative_revenue
    FROM public.orders o
    WHERE o.status = 'delivered'
      AND (p_dc_id IS NULL OR o.assigned_dc_id = p_dc_id);

    -- 6. DC BREAKDOWN
    IF p_dc_id IS NULL THEN
        SELECT jsonb_agg(
            jsonb_build_object(
                'dc_id', dc_data.id,
                'dc_name', dc_data.name,
                'city', dc_data.city,
                'parcels', dc_data.parcels,
                'revenue', dc_data.revenue
            ) ORDER BY dc_data.revenue DESC
        )
        INTO v_dc_breakdown
        FROM (
            SELECT
                dc.id,
                dc.name,
                dc.city,
                COUNT(o.id) AS parcels,
                COALESCE(SUM(o.client_delivery_fee), 0.00) AS revenue
            FROM public.distribution_centers dc
            LEFT JOIN public.orders o ON o.assigned_dc_id = dc.id 
                AND o.status = 'delivered' 
                AND o.created_at::DATE BETWEEN v_start AND v_end
            GROUP BY dc.id, dc.name, dc.city
        ) dc_data;
    END IF;

    RETURN jsonb_build_object(
        'dc_id', p_dc_id,
        'start_date', v_start,
        'end_date', v_end,
        'logistics_gross_revenue', v_logistics_gross_revenue,
        'network_opex', v_network_opex,
        'total_parcels_handled', v_total_parcels_handled,
        'net_logistics_margin', v_net_logistics_margin,
        'vault_inventory', v_vault_inventory,
        'rider_allowances', v_rider_allowances,
        'facility_capex', v_facility_capex,
        'cumulative_revenue', v_cumulative_revenue,
        'dc_breakdown', COALESCE(v_dc_breakdown, '[]'::jsonb)
    );
END;
$$;

-- Notify PostgREST to refresh schema cache
SELECT pg_notify('pgrst', 'reload schema');
