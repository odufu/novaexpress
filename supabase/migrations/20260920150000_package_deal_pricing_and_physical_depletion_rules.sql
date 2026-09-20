-- ============================================================================
-- Migration: 20260920150000_package_deal_pricing_and_physical_depletion_rules.sql
-- Description:
--   Authoritative package pricing governance for Respira products:
--     1 Box                = ₦21,500 (1 paid, 0 free, 1 total physical unit)
--     2 Boxes              = ₦35,000 (2 paid, 0 free, 2 total physical units)
--     3 Boxes              = ₦45,000 (3 paid, 0 free, 3 total physical units)
--     4 Boxes + 1 Box Free = ₦55,000 (4 paid, 1 free, 5 total physical units)
--   Enforces strict package-first commercial pricing, physical stock depletion
--   on delivery POD, and synchronization with product_packages table.
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE 'Applying package-first pricing and physical stock depletion governance...';
END $$;

-- 1. Ensure Table Structure & Constraints
CREATE TABLE IF NOT EXISTS public.product_packages (
    id TEXT PRIMARY KEY,
    product_id TEXT NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    product_sku VARCHAR(100),
    package_name VARCHAR(255) NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    paid_quantity INT NOT NULL DEFAULT 1,
    free_quantity INT DEFAULT 0,
    package_price NUMERIC(14,2) NOT NULL,
    client_id TEXT,
    client_name VARCHAR(255),
    description TEXT,
    is_custom BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexing for fast lookups during order creation and switching
CREATE INDEX IF NOT EXISTS idx_product_packages_product_id ON public.product_packages(product_id);
CREATE INDEX IF NOT EXISTS idx_product_packages_client_id ON public.product_packages(client_id);
CREATE INDEX IF NOT EXISTS idx_product_packages_product_name ON public.product_packages(product_name);

-- Ensure Realtime publication includes product_packages
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'product_packages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.product_packages;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END $$;

-- 2. Upsert Authoritative Respira Commercial Package Suites
-- Respira Detox Tea (Novacale Limited)
INSERT INTO public.product_packages (
    id, product_id, product_name, product_sku, package_name, quantity, paid_quantity, free_quantity, package_price, client_id, client_name, is_custom, description
) VALUES
    ('pkg-respira-nova-1', '490dc0ad-e5f7-4c72-8f85-667b6ac1072d', 'Respira Detox Tea', 'SKU-48678', '1 Box (Standard Retail)', 1, 1, 0, 21500.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false, '1 Box Starter Treatment'),
    ('pkg-respira-nova-2', '490dc0ad-e5f7-4c72-8f85-667b6ac1072d', 'Respira Detox Tea', 'SKU-48678', '2 Boxes Promo Deal', 2, 2, 0, 35000.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false, '2 Boxes Intensive Treatment'),
    ('pkg-respira-nova-3', '490dc0ad-e5f7-4c72-8f85-667b6ac1072d', 'Respira Detox Tea', 'SKU-48678', '3 Boxes Cleanse Bundle', 3, 3, 0, 45000.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false, '3 Boxes Complete Cleanse Bundle'),
    ('pkg-respira-nova-5', '490dc0ad-e5f7-4c72-8f85-667b6ac1072d', 'Respira Detox Tea', 'SKU-48678', '4 Boxes + 1 Box Free Mega Deal', 5, 4, 1, 55000.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false, '5 Boxes Mega Saver: 4 Paid + 1 Free Bonus Box')
ON CONFLICT (id) DO UPDATE SET
    product_id = EXCLUDED.product_id,
    package_name = EXCLUDED.package_name,
    package_price = EXCLUDED.package_price,
    quantity = EXCLUDED.quantity,
    paid_quantity = EXCLUDED.paid_quantity,
    free_quantity = EXCLUDED.free_quantity,
    description = EXCLUDED.description,
    updated_at = NOW();

-- Respira Detox Tea (Leafora Limited)
INSERT INTO public.product_packages (
    id, product_id, product_name, product_sku, package_name, quantity, paid_quantity, free_quantity, package_price, client_id, client_name, is_custom, description
) VALUES
    ('pkg-respira-leaf-1', 'd14f2ecf-a2b0-4e98-9fc9-4f678bae1e1f', 'Respira Detox Tea', 'SKU-PRD-6028', '1 Box (Standard Retail)', 1, 1, 0, 21500.00, '00000000-0000-4000-8000-789183072480', 'Leafora Limited', false, '1 Box Starter Treatment'),
    ('pkg-respira-leaf-2', 'd14f2ecf-a2b0-4e98-9fc9-4f678bae1e1f', 'Respira Detox Tea', 'SKU-PRD-6028', '2 Boxes Promo Deal', 2, 2, 0, 35000.00, '00000000-0000-4000-8000-789183072480', 'Leafora Limited', false, '2 Boxes Intensive Treatment'),
    ('pkg-respira-leaf-3', 'd14f2ecf-a2b0-4e98-9fc9-4f678bae1e1f', 'Respira Detox Tea', 'SKU-PRD-6028', '3 Boxes Value Bundle', 3, 3, 0, 45000.00, '00000000-0000-4000-8000-789183072480', 'Leafora Limited', false, '3 Boxes Complete Cleanse Bundle'),
    ('pkg-respira-leaf-5', 'd14f2ecf-a2b0-4e98-9fc9-4f678bae1e1f', 'Respira Detox Tea', 'SKU-PRD-6028', '4 Boxes + 1 Box Free Mega Deal', 5, 4, 1, 55000.00, '00000000-0000-4000-8000-789183072480', 'Leafora Limited', false, '5 Boxes Mega Saver: 4 Paid + 1 Free Bonus Box')
ON CONFLICT (id) DO UPDATE SET
    product_id = EXCLUDED.product_id,
    package_name = EXCLUDED.package_name,
    package_price = EXCLUDED.package_price,
    quantity = EXCLUDED.quantity,
    paid_quantity = EXCLUDED.paid_quantity,
    free_quantity = EXCLUDED.free_quantity,
    description = EXCLUDED.description,
    updated_at = NOW();

-- Respira Lungs Detox Tea (Novacale Limited)
INSERT INTO public.product_packages (
    id, product_id, product_name, product_sku, package_name, quantity, paid_quantity, free_quantity, package_price, client_id, client_name, is_custom, description
) VALUES
    ('pkg-respira-lungs-1', 'd4f0a76c-2393-476e-ac2c-c350f31a8a90', 'Respira Lungs Detox Tea', 'SKU-95708', '1 Box (Standard Retail)', 1, 1, 0, 21500.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false, '1 Box Starter Treatment'),
    ('pkg-respira-lungs-2', 'd4f0a76c-2393-476e-ac2c-c350f31a8a90', 'Respira Lungs Detox Tea', 'SKU-95708', '2 Boxes Promo Deal', 2, 2, 0, 35000.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false, '2 Boxes Intensive Treatment'),
    ('pkg-respira-lungs-3', 'd4f0a76c-2393-476e-ac2c-c350f31a8a90', 'Respira Lungs Detox Tea', 'SKU-95708', '3 Boxes Cleanse Bundle', 3, 3, 0, 45000.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false, '3 Boxes Complete Cleanse Bundle'),
    ('pkg-respira-lungs-5', 'd4f0a76c-2393-476e-ac2c-c350f31a8a90', 'Respira Lungs Detox Tea', 'SKU-95708', '4 Boxes + 1 Box Free Mega Deal', 5, 4, 1, 55000.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false, '5 Boxes Mega Saver: 4 Paid + 1 Free Bonus Box')
ON CONFLICT (id) DO UPDATE SET
    product_id = EXCLUDED.product_id,
    package_name = EXCLUDED.package_name,
    package_price = EXCLUDED.package_price,
    quantity = EXCLUDED.quantity,
    paid_quantity = EXCLUDED.paid_quantity,
    free_quantity = EXCLUDED.free_quantity,
    description = EXCLUDED.description,
    updated_at = NOW();

-- RESPIRA LUNG TEA (SKU-RLT, Novacare Ltd)
DO $$
DECLARE
    v_rlt_id TEXT;
BEGIN
    SELECT id::text INTO v_rlt_id FROM public.products WHERE sku = 'SKU-RLT' OR name ILIKE '%RESPIRA LUNG TEA%' LIMIT 1;
    IF v_rlt_id IS NOT NULL THEN
        INSERT INTO public.product_packages (
            id, product_id, product_name, product_sku, package_name, quantity, paid_quantity, free_quantity, package_price, client_id, client_name, is_custom, description
        ) VALUES
            ('pkg-rlt-1', v_rlt_id, 'RESPIRA LUNG TEA', 'SKU-RLT', '1 Box (Standard Retail)', 1, 1, 0, 21500.00, '33333333-3333-4333-8333-333333333333', 'Novacare Ltd', false, '1 Box Treatment'),
            ('pkg-rlt-2', v_rlt_id, 'RESPIRA LUNG TEA', 'SKU-RLT', '2 Boxes Promo Deal', 2, 2, 0, 35000.00, '33333333-3333-4333-8333-333333333333', 'Novacare Ltd', false, '2 Boxes Deal'),
            ('pkg-rlt-3', v_rlt_id, 'RESPIRA LUNG TEA', 'SKU-RLT', '3 Boxes Cleanse Bundle', 3, 3, 0, 45000.00, '33333333-3333-4333-8333-333333333333', 'Novacare Ltd', false, '3 Boxes Cleanse Bundle'),
            ('pkg-rlt-5', v_rlt_id, 'RESPIRA LUNG TEA', 'SKU-RLT', '4 Boxes + 1 Box Free Mega Deal', 5, 4, 1, 55000.00, '33333333-3333-4333-8333-333333333333', 'Novacare Ltd', false, '5 Boxes Mega Deal: 4 Paid + 1 Free')
        ON CONFLICT (id) DO UPDATE SET
            package_name = EXCLUDED.package_name,
            package_price = EXCLUDED.package_price,
            quantity = EXCLUDED.quantity,
            paid_quantity = EXCLUDED.paid_quantity,
            free_quantity = EXCLUDED.free_quantity,
            description = EXCLUDED.description,
            updated_at = NOW();
    END IF;
END $$;

-- 3. Stored Procedure: Authoritative Physical Delivery Confirmation
CREATE OR REPLACE FUNCTION public.fn_confirm_order_delivery_stock(
    p_order_id UUID,
    p_agent_id UUID,
    p_product_id UUID,
    p_physical_quantity INT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_qty INT := GREATEST(1, COALESCE(p_physical_quantity, 1));
    v_agent RECORD;
BEGIN
    SELECT * INTO v_agent FROM public.delivery_agents WHERE id = p_agent_id OR user_id = p_agent_id;

    IF v_agent IS NOT NULL AND p_product_id IS NOT NULL THEN
        UPDATE public.agent_inventory
        SET available_count = GREATEST(0, COALESCE(available_count, 0) - v_qty),
            total_in_custody = GREATEST(0, COALESCE(total_in_custody, 0) - v_qty),
            delivered_count_today = COALESCE(delivered_count_today, 0) + v_qty,
            updated_at = NOW()
        WHERE delivery_agent_id = v_agent.id AND product_id = p_product_id;
    END IF;

    IF p_product_id IS NOT NULL THEN
        UPDATE public.products
        SET delivered_count = COALESCE(delivered_count, 0) + v_qty,
            stock_quantity = GREATEST(0, COALESCE(stock_quantity, 0) - v_qty),
            available_count = GREATEST(0, COALESCE(available_count, 0) - v_qty),
            updated_at = NOW()
        WHERE id = p_product_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'deducted_physical_quantity', v_qty
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_confirm_order_delivery_stock(UUID, UUID, UUID, INT) TO authenticated, service_role, anon;
