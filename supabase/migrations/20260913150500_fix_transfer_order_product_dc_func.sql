-- ============================================================================
-- Migration: Restrict transfer_order_product_and_ownership to Handling DC
-- ============================================================================

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
    p_actor_role TEXT DEFAULT 'dc_manager',
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
    -- 0. Operational Security Guard: Riders must not directly modify products/packages
    IF lower(COALESCE(p_actor_role, '')) IN ('rider', 'delivery_agent', 'pda') THEN
        RAISE EXCEPTION 'Unauthorized: Riders are restricted from directly modifying order products or package deals. Please request the change from Handling DC Operations via the order pipeline chat.';
    END IF;

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
        WHEN lower(p_actor_role) IN ('client', 'merchant', 'closer') THEN 'client'
        WHEN lower(p_actor_role) IN ('dc_manager', 'manager', 'admin', 'supervisor', 'operations') THEN 'dc_manager'
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
