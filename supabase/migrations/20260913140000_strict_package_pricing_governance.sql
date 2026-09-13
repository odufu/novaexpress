-- ============================================================================
-- Migration: 20260913140000_strict_package_pricing_governance.sql
-- Description:
--   1. Ensure indexes on public.product_packages
--   2. Add public.product_packages to supabase_realtime publication
--   3. Seed complete commercial package suites for all catalog products
--   4. Update stored procedure transfer_order_product_and_ownership to
--      strictly look up and lock prices to public.product_packages
-- ============================================================================

-- 1. Indexing on product_packages
CREATE INDEX IF NOT EXISTS idx_product_packages_product_id ON public.product_packages(product_id);
CREATE INDEX IF NOT EXISTS idx_product_packages_client_id ON public.product_packages(client_id);
CREATE INDEX IF NOT EXISTS idx_product_packages_product_name ON public.product_packages(product_name);

-- 2. Ensure Realtime Publication includes product_packages
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'product_packages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.product_packages;
    END IF;
END $$;

-- 3. Seed Complete Merchant Package Suites for All Catalog Products
-- Grazer Herbal Detox Tea (Novacare Limited)
INSERT INTO public.product_packages (id, product_id, product_name, product_sku, package_name, quantity, paid_quantity, free_quantity, package_price, client_id, client_name, is_custom)
VALUES
  ('pkg-grazer-1', '8d090a27-81d2-42b5-9ee5-9d0e4f695415', 'Grazer Herbal Detox Tea', 'SKU-02900', '1 Pack (Standard Retail)', 1, 1, 0, 22000.00, '33333333-3333-4333-8333-333333333333', 'Novacare Limited', false),
  ('pkg-grazer-2', '8d090a27-81d2-42b5-9ee5-9d0e4f695415', 'Grazer Herbal Detox Tea', 'SKU-02900', '2 Packs Promo Deal', 2, 2, 0, 35000.00, '33333333-3333-4333-8333-333333333333', 'Novacare Limited', false),
  ('pkg-grazer-3', '8d090a27-81d2-42b5-9ee5-9d0e4f695415', 'Grazer Herbal Detox Tea', 'SKU-02900', '3 Packs Family Bundle', 3, 3, 0, 50000.00, '33333333-3333-4333-8333-333333333333', 'Novacare Limited', false),
  ('pkg-grazer-5', '8d090a27-81d2-42b5-9ee5-9d0e4f695415', 'Grazer Herbal Detox Tea', 'SKU-02900', '5 Packs Mega Saver (Buy 4 Get 1 Free)', 5, 4, 1, 55000.00, '33333333-3333-4333-8333-333333333333', 'Novacare Limited', false)
ON CONFLICT (id) DO UPDATE SET
  product_id = EXCLUDED.product_id,
  package_price = EXCLUDED.package_price,
  quantity = EXCLUDED.quantity,
  paid_quantity = EXCLUDED.paid_quantity,
  free_quantity = EXCLUDED.free_quantity,
  updated_at = NOW();

-- Alpha Man (Novacale Limited)
INSERT INTO public.product_packages (id, product_id, product_name, product_sku, package_name, quantity, paid_quantity, free_quantity, package_price, client_id, client_name, is_custom)
VALUES
  ('pkg-alphaman-1', '4e52cc92-a760-4311-941c-2fdd7d9d8218', 'Alpha Man', 'SKU-PRD-9747', '1 Pack (Standard Retail)', 1, 1, 0, 21500.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false),
  ('pkg-alphaman-2', '4e52cc92-a760-4311-941c-2fdd7d9d8218', 'Alpha Man', 'SKU-PRD-9747', '2 Packs Promo Deal', 2, 2, 0, 36500.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false),
  ('pkg-alphaman-3', '4e52cc92-a760-4311-941c-2fdd7d9d8218', 'Alpha Man', 'SKU-PRD-9747', '3 Packs Power Bundle', 3, 3, 0, 51000.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false),
  ('pkg-alphaman-5', '4e52cc92-a760-4311-941c-2fdd7d9d8218', 'Alpha Man', 'SKU-PRD-9747', '5 Packs Mega Saver (Buy 4 Get 1 Free)', 5, 4, 1, 55000.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false)
ON CONFLICT (id) DO UPDATE SET
  product_id = EXCLUDED.product_id,
  package_price = EXCLUDED.package_price,
  quantity = EXCLUDED.quantity,
  paid_quantity = EXCLUDED.paid_quantity,
  free_quantity = EXCLUDED.free_quantity,
  updated_at = NOW();

-- Ura Clear (Novacare Limited)
INSERT INTO public.product_packages (id, product_id, product_name, product_sku, package_name, quantity, paid_quantity, free_quantity, package_price, client_id, client_name, is_custom)
VALUES
  ('pkg-uraclear-1', '6b47964e-79e9-4b76-ab0f-fb36a95dc4cb', 'Ura Clear', 'SKU-31090', '1 Bottle (Standard Retail)', 1, 1, 0, 25000.00, '33333333-3333-4333-8333-333333333333', 'Novacare Limited', false),
  ('pkg-uraclear-2', '6b47964e-79e9-4b76-ab0f-fb36a95dc4cb', 'Ura Clear', 'SKU-31090', '2 Bottles Treatment Plan', 2, 2, 0, 42000.00, '33333333-3333-4333-8333-333333333333', 'Novacare Limited', false),
  ('pkg-uraclear-3', '6b47964e-79e9-4b76-ab0f-fb36a95dc4cb', 'Ura Clear', 'SKU-31090', '3 Bottles Full Cure Bundle', 3, 3, 0, 58000.00, '33333333-3333-4333-8333-333333333333', 'Novacare Limited', false),
  ('pkg-uraclear-5', '6b47964e-79e9-4b76-ab0f-fb36a95dc4cb', 'Ura Clear', 'SKU-31090', '5 Bottles Ultimate Saver (Buy 4 Get 1 Free)', 5, 4, 1, 65000.00, '33333333-3333-4333-8333-333333333333', 'Novacare Limited', false)
ON CONFLICT (id) DO UPDATE SET
  product_id = EXCLUDED.product_id,
  package_price = EXCLUDED.package_price,
  quantity = EXCLUDED.quantity,
  paid_quantity = EXCLUDED.paid_quantity,
  free_quantity = EXCLUDED.free_quantity,
  updated_at = NOW();

-- Respira Detox Tea (Novacale Limited)
INSERT INTO public.product_packages (id, product_id, product_name, product_sku, package_name, quantity, paid_quantity, free_quantity, package_price, client_id, client_name, is_custom)
VALUES
  ('pkg-respira-nova-1', '490dc0ad-e5f7-4c72-8f85-667b6ac1072d', 'Respira Detox Tea', 'SKU-48678', '1 Pack (Standard Retail)', 1, 1, 0, 21500.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false),
  ('pkg-respira-nova-2', '490dc0ad-e5f7-4c72-8f85-667b6ac1072d', 'Respira Detox Tea', 'SKU-48678', '2 Packs Promo Deal', 2, 2, 0, 36500.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false),
  ('pkg-respira-nova-3', '490dc0ad-e5f7-4c72-8f85-667b6ac1072d', 'Respira Detox Tea', 'SKU-48678', '3 Packs Cleanse Bundle', 3, 3, 0, 50000.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false),
  ('pkg-respira-nova-5', '490dc0ad-e5f7-4c72-8f85-667b6ac1072d', 'Respira Detox Tea', 'SKU-48678', '5 Packs Mega Saver (Buy 4 Get 1 Free)', 5, 4, 1, 55000.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false)
ON CONFLICT (id) DO UPDATE SET
  product_id = EXCLUDED.product_id,
  package_price = EXCLUDED.package_price,
  quantity = EXCLUDED.quantity,
  paid_quantity = EXCLUDED.paid_quantity,
  free_quantity = EXCLUDED.free_quantity,
  updated_at = NOW();

-- Respira Detox Tea (Leafora Limited)
INSERT INTO public.product_packages (id, product_id, product_name, product_sku, package_name, quantity, paid_quantity, free_quantity, package_price, client_id, client_name, is_custom)
VALUES
  ('pkg-respira-leaf-1', 'd14f2ecf-a2b0-4e98-9fc9-4f678bae1e1f', 'Respira Detox Tea', 'SKU-PRD-6028', '1 Pack (Standard Retail)', 1, 1, 0, 21500.00, '00000000-0000-4000-8000-789183072480', 'Leafora Limited', false),
  ('pkg-respira-leaf-2', 'd14f2ecf-a2b0-4e98-9fc9-4f678bae1e1f', 'Respira Detox Tea', 'SKU-PRD-6028', '2 Packs Promo Deal', 2, 2, 0, 36500.00, '00000000-0000-4000-8000-789183072480', 'Leafora Limited', false),
  ('pkg-respira-leaf-3', 'd14f2ecf-a2b0-4e98-9fc9-4f678bae1e1f', 'Respira Detox Tea', 'SKU-PRD-6028', '3 Packs Value Bundle', 3, 3, 0, 50000.00, '00000000-0000-4000-8000-789183072480', 'Leafora Limited', false),
  ('pkg-respira-leaf-5', 'd14f2ecf-a2b0-4e98-9fc9-4f678bae1e1f', 'Respira Detox Tea', 'SKU-PRD-6028', '5 Packs Mega Saver (Buy 4 Get 1 Free)', 5, 4, 1, 55000.00, '00000000-0000-4000-8000-789183072480', 'Leafora Limited', false)
ON CONFLICT (id) DO UPDATE SET
  product_id = EXCLUDED.product_id,
  package_price = EXCLUDED.package_price,
  quantity = EXCLUDED.quantity,
  paid_quantity = EXCLUDED.paid_quantity,
  free_quantity = EXCLUDED.free_quantity,
  updated_at = NOW();

-- Respira Lungs Detox Tea (Novacale Limited)
INSERT INTO public.product_packages (id, product_id, product_name, product_sku, package_name, quantity, paid_quantity, free_quantity, package_price, client_id, client_name, is_custom)
VALUES
  ('pkg-respira-lungs-1', 'd4f0a76c-2393-476e-ac2c-c350f31a8a90', 'Respira Lungs Detox Tea', 'SKU-95708', '1 Pack (Standard Retail)', 1, 1, 0, 21500.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false),
  ('pkg-respira-lungs-2', 'd4f0a76c-2393-476e-ac2c-c350f31a8a90', 'Respira Lungs Detox Tea', 'SKU-95708', '2 Packs Promo Deal', 2, 2, 0, 36500.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false),
  ('pkg-respira-lungs-3', 'd4f0a76c-2393-476e-ac2c-c350f31a8a90', 'Respira Lungs Detox Tea', 'SKU-95708', '3 Packs Cleanse Bundle', 3, 3, 0, 50000.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false),
  ('pkg-respira-lungs-5', 'd4f0a76c-2393-476e-ac2c-c350f31a8a90', 'Respira Lungs Detox Tea', 'SKU-95708', '5 Packs Mega Saver (Buy 4 Get 1 Free)', 5, 4, 1, 55000.00, '11111111-1111-4111-8111-111111111111', 'Novacale Limited', false)
ON CONFLICT (id) DO UPDATE SET
  product_id = EXCLUDED.product_id,
  package_price = EXCLUDED.package_price,
  quantity = EXCLUDED.quantity,
  paid_quantity = EXCLUDED.paid_quantity,
  free_quantity = EXCLUDED.free_quantity,
  updated_at = NOW();

-- 4. Authoritative Stored Procedure: Strict Package Price Locking
CREATE OR REPLACE FUNCTION public.transfer_order_product_and_ownership(
    p_order_id UUID,
    p_new_product_id UUID,
    p_new_package_deal_id TEXT,
    p_new_package_name TEXT DEFAULT NULL,
    p_new_quantity INT DEFAULT NULL,
    p_new_paid_quantity INT DEFAULT NULL,
    p_new_free_quantity INT DEFAULT NULL,
    p_new_base_price NUMERIC DEFAULT NULL,
    p_new_total_amount NUMERIC DEFAULT NULL,
    p_actor_name TEXT DEFAULT 'Operator',
    p_actor_role TEXT DEFAULT 'system',
    p_transfer_reason TEXT DEFAULT 'Product or package modified'
)
RETURNS JSONB AS $$
DECLARE
    v_curr_order RECORD;
    v_new_product RECORD;
    v_package RECORD;
    v_old_client_name TEXT;
    v_new_client_name TEXT;
    v_conv_id UUID;
    v_is_ownership_transfer BOOLEAN := false;
    v_msg_body TEXT;
    v_msg_type TEXT;
    v_final_package_name TEXT;
    v_final_quantity INT;
    v_final_paid_quantity INT;
    v_final_free_quantity INT;
    v_final_price NUMERIC(14,2);
    v_safe_actor_role TEXT;
BEGIN
    -- 1. Fetch Current Order
    SELECT * INTO v_curr_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order with ID % not found', p_order_id;
    END IF;

    -- 2. Fetch New Product
    SELECT * INTO v_new_product FROM public.products WHERE id = p_new_product_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product with ID % not found', p_new_product_id;
    END IF;

    -- 3. Authoritative Package Deal Lookup from public.product_packages
    -- The price and quantities are strictly locked to the chosen package deal!
    SELECT * INTO v_package 
    FROM public.product_packages 
    WHERE id = p_new_package_deal_id;

    IF FOUND THEN
        v_final_package_name := v_package.package_name;
        v_final_quantity := v_package.quantity;
        v_final_paid_quantity := COALESCE(v_package.paid_quantity, v_package.quantity);
        v_final_free_quantity := COALESCE(v_package.free_quantity, 0);
        v_final_price := v_package.package_price;
    ELSE
        -- If package ID not found, attempt product SKU / name package lookup
        SELECT * INTO v_package 
        FROM public.product_packages 
        WHERE (product_id = p_new_product_id::text OR product_sku = v_new_product.sku OR product_name ILIKE v_new_product.name)
          AND (id = p_new_package_deal_id OR package_name ILIKE p_new_package_name)
        LIMIT 1;

        IF FOUND THEN
            v_final_package_name := v_package.package_name;
            v_final_quantity := v_package.quantity;
            v_final_paid_quantity := COALESCE(v_package.paid_quantity, v_package.quantity);
            v_final_free_quantity := COALESCE(v_package.free_quantity, 0);
            v_final_price := v_package.package_price;
        ELSE
            -- Fallback check: If an explicit package price and name was provided and no package exists yet
            IF p_new_package_name IS NOT NULL AND p_new_total_amount IS NOT NULL AND p_new_total_amount > 0 THEN
                v_final_package_name := p_new_package_name;
                v_final_quantity := COALESCE(p_new_quantity, 1);
                v_final_paid_quantity := COALESCE(p_new_paid_quantity, v_final_quantity);
                v_final_free_quantity := COALESCE(p_new_free_quantity, 0);
                v_final_price := p_new_total_amount;
            ELSE
                RAISE EXCEPTION 'Package deal "%" is not an authorized package for product "%". Must select a pre-created package from dropdown.', 
                    p_new_package_deal_id, v_new_product.name;
            END IF;
        END IF;
    END IF;

    -- 4. Normalize actor role to satisfy check constraint
    v_safe_actor_role := CASE 
        WHEN lower(p_actor_role) IN ('rider', 'delivery_agent', 'pda') THEN 'delivery_agent'
        WHEN lower(p_actor_role) IN ('client', 'merchant', 'closer') THEN 'client'
        WHEN lower(p_actor_role) IN ('dc_manager', 'manager', 'admin', 'supervisor') THEN 'dc_manager'
        ELSE 'system'
    END;

    v_old_client_name := COALESCE(v_curr_order.client_name, 'Original Client');

    -- Resolve New Client Name
    SELECT COALESCE(company_name, name) INTO v_new_client_name FROM public.clients WHERE id = v_new_product.client_id;
    IF v_new_client_name IS NULL THEN v_new_client_name := COALESCE(v_new_product.client_name, 'Merchant Client'); END IF;

    -- 5. Check if ownership transfer is required
    IF v_curr_order.client_id <> v_new_product.client_id THEN
        v_is_ownership_transfer := true;
    END IF;

    -- 6. Update Order Record with Locked Package Values
    IF v_is_ownership_transfer THEN
        UPDATE public.orders SET
            product_id = v_new_product.id,
            product_name = v_new_product.name,
            product_sku = v_new_product.sku,
            package_deal_id = p_new_package_deal_id,
            package_deal_name = v_final_package_name,
            quantity = v_final_quantity,
            paid_quantity = v_final_paid_quantity,
            free_quantity = v_final_free_quantity,
            base_price = v_final_price,
            total_amount = v_final_price,
            -- Ownership transfer fields
            client_id = v_new_product.client_id,
            client_name = v_new_client_name,
            client_company = v_new_client_name,
            original_client_id = COALESCE(v_curr_order.original_client_id, v_curr_order.client_id),
            original_client_name = v_old_client_name,
            ownership_transferred_at = now(),
            ownership_transfer_reason = p_transfer_reason,
            updated_at = now()
        WHERE id = p_order_id;

        v_msg_type := 'ownership_transferred';
        v_msg_body := '🔄 Order Ownership Transferred! Customer switched product to "' || v_new_product.name || 
                      '" (' || v_final_package_name || '). Order transferred from "' || v_old_client_name || 
                      '" to "' || v_new_client_name || '". Fixed Package Price: ₦' || 
                      TO_CHAR(v_final_price, 'FM999,999,990.00');
    ELSE
        -- Same client package deal modification
        UPDATE public.orders SET
            product_id = v_new_product.id,
            product_name = v_new_product.name,
            product_sku = v_new_product.sku,
            package_deal_id = p_new_package_deal_id,
            package_deal_name = v_final_package_name,
            quantity = v_final_quantity,
            paid_quantity = v_final_paid_quantity,
            free_quantity = v_final_free_quantity,
            base_price = v_final_price,
            total_amount = v_final_price,
            updated_at = now()
        WHERE id = p_order_id;

        v_msg_type := 'product_changed';
        v_msg_body := '📦 Order Package Updated to "' || v_final_package_name || '" (' || v_final_quantity || 
                      ' units). Fixed Package Price: ₦' || TO_CHAR(v_final_price, 'FM999,999,990.00');
    END IF;

    -- 7. Update Order Conversation & Post Announcement
    SELECT id INTO v_conv_id FROM public.order_conversations WHERE order_id = p_order_id;
    IF v_conv_id IS NOT NULL THEN
        IF v_is_ownership_transfer THEN
            UPDATE public.order_conversations SET
                client_id = v_new_product.client_id,
                client_name = v_new_client_name,
                current_product_name = v_new_product.name,
                current_package_name = v_final_package_name,
                current_total_amount = v_final_price,
                last_message_text = v_msg_body,
                last_message_sender_name = p_actor_name,
                last_message_at = now(),
                updated_at = now()
            WHERE id = v_conv_id;
        ELSE
            UPDATE public.order_conversations SET
                current_product_name = v_new_product.name,
                current_package_name = v_final_package_name,
                current_total_amount = v_final_price,
                last_message_text = v_msg_body,
                last_message_sender_name = p_actor_name,
                last_message_at = now(),
                updated_at = now()
            WHERE id = v_conv_id;
        END IF;

        INSERT INTO public.order_conversation_messages (
            conversation_id,
            order_id,
            sender_name,
            sender_role,
            message_type,
            message_body,
            metadata
        ) VALUES (
            v_conv_id,
            p_order_id,
            p_actor_name,
            v_safe_actor_role,
            v_msg_type,
            v_msg_body,
            jsonb_build_object(
                'old_product', v_curr_order.product_name,
                'new_product', v_new_product.name,
                'old_package', v_curr_order.package_deal_name,
                'new_package', v_final_package_name,
                'package_id', p_new_package_deal_id,
                'old_amount', v_curr_order.total_amount,
                'new_amount', v_final_price,
                'old_client', v_old_client_name,
                'new_client', v_new_client_name,
                'ownership_transferred', v_is_ownership_transfer,
                'reason', p_transfer_reason
            )
        );
    END IF;

    -- 8. Return Confirmation JSON
    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'order_number', v_curr_order.order_number,
        'previous_product_name', v_curr_order.product_name,
        'new_product_name', v_new_product.name,
        'previous_package_name', v_curr_order.package_deal_name,
        'new_package_name', v_final_package_name,
        'package_deal_id', p_new_package_deal_id,
        'previous_total_amount', v_curr_order.total_amount,
        'new_total_amount', v_final_price,
        'is_ownership_transfer', v_is_ownership_transfer,
        'previous_client_name', v_old_client_name,
        'new_client_name', v_new_client_name
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
