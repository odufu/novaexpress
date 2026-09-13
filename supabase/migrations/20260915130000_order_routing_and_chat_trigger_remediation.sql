-- ============================================================================
-- Migration: 20260915130000_order_routing_and_chat_trigger_remediation.sql
-- Remediations for Order Pipeline, Routing & Real-time Chat Sync:
-- 1. Adds full_name column to public.delivery_agents and backfills from users.
-- 2. Fixes fn_sync_order_conversation trigger to safely resolve rider full_name
--    without crashing with 'column full_name does not exist'.
-- 3. Fixes auto_dispatch_order_by_state_lga to match riders with current_status IN ('available', 'active', 'on_duty').
-- 4. Enhances transfer_order_product_and_ownership to log order_activities audit entry
--    and establish order_conversations if missing.
-- ============================================================================

-- 1. Add full_name column to public.delivery_agents
ALTER TABLE IF EXISTS public.delivery_agents
    ADD COLUMN IF NOT EXISTS full_name VARCHAR(255);

UPDATE public.delivery_agents da
SET full_name = COALESCE(u.first_name || ' ' || u.last_name, da.bank_account_name, da.agent_code)
FROM public.users u
WHERE da.user_id = u.id AND da.full_name IS NULL;

UPDATE public.delivery_agents
SET full_name = COALESCE(bank_account_name, agent_code)
WHERE full_name IS NULL;

-- 2. Fix fn_sync_order_conversation trigger
CREATE OR REPLACE FUNCTION public.fn_sync_order_conversation()
RETURNS TRIGGER AS $$
DECLARE
    v_conv_id UUID;
    v_client_name TEXT;
    v_dc_name TEXT;
    v_rider_name TEXT;
    v_closer_name TEXT;
BEGIN
    -- Only sync if client_id is present
    IF NEW.client_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Lookup Client Name
    SELECT company_name INTO v_client_name
    FROM public.clients
    WHERE id = NEW.client_id;
    v_client_name := COALESCE(v_client_name, NEW.client_name, 'Merchant');

    -- Lookup DC Name if set
    IF NEW.distribution_center_id IS NOT NULL THEN
        SELECT name INTO v_dc_name
        FROM public.distribution_centers
        WHERE id = NEW.distribution_center_id;
    END IF;

    -- Lookup Rider Name if set (Safely joins users and checks delivery_agents)
    IF NEW.delivery_agent_id IS NOT NULL THEN
        SELECT COALESCE(da.full_name, u.first_name || ' ' || u.last_name, da.bank_account_name, da.agent_code, 'Rider')
        INTO v_rider_name
        FROM public.delivery_agents da
        LEFT JOIN public.users u ON u.id = da.user_id
        WHERE da.id = NEW.delivery_agent_id;
    END IF;

    -- Lookup Closer Name if set
    IF NEW.closer_id IS NOT NULL THEN
        SELECT full_name INTO v_closer_name
        FROM public.client_closers
        WHERE id = NEW.closer_id;
    END IF;

    -- Insert or update order_conversations
    INSERT INTO public.order_conversations (
        order_id,
        order_number,
        customer_name,
        customer_phone,
        client_id,
        client_name,
        distribution_center_id,
        distribution_center_name,
        delivery_agent_id,
        delivery_agent_name,
        closer_id,
        closer_name,
        order_status,
        current_product_name,
        current_package_name,
        current_total_amount,
        last_message_text,
        last_message_sender_name,
        last_message_at,
        updated_at
    ) VALUES (
        NEW.id,
        NEW.order_number,
        NEW.customer_name,
        NEW.customer_phone,
        NEW.client_id,
        v_client_name,
        NEW.distribution_center_id,
        v_dc_name,
        NEW.delivery_agent_id,
        v_rider_name,
        NEW.closer_id,
        v_closer_name,
        NEW.status,
        NEW.product_name,
        NEW.package_deal_name,
        COALESCE(NEW.total_amount, 0),
        'Order pipeline active.',
        'System',
        now(),
        now()
    )
    ON CONFLICT (order_id) DO UPDATE SET
        order_number = EXCLUDED.order_number,
        customer_name = EXCLUDED.customer_name,
        customer_phone = EXCLUDED.customer_phone,
        client_id = EXCLUDED.client_id,
        client_name = EXCLUDED.client_name,
        distribution_center_id = EXCLUDED.distribution_center_id,
        distribution_center_name = EXCLUDED.distribution_center_name,
        delivery_agent_id = EXCLUDED.delivery_agent_id,
        delivery_agent_name = EXCLUDED.delivery_agent_name,
        closer_id = EXCLUDED.closer_id,
        closer_name = EXCLUDED.closer_name,
        order_status = EXCLUDED.order_status,
        current_product_name = EXCLUDED.current_product_name,
        current_package_name = EXCLUDED.current_package_name,
        current_total_amount = EXCLUDED.current_total_amount,
        updated_at = now();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-attach trigger to orders table
DROP TRIGGER IF EXISTS trg_sync_order_conversation ON public.orders;
CREATE TRIGGER trg_sync_order_conversation
    AFTER INSERT OR UPDATE OF customer_name, customer_phone, client_id, distribution_center_id, delivery_agent_id, closer_id, status, product_name, package_deal_name, total_amount
    ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_sync_order_conversation();

-- 3. Fix auto_dispatch_order_by_state_lga (Honor 'available', 'active', 'on_duty' rider status)
CREATE OR REPLACE FUNCTION public.auto_dispatch_order_by_state_lga(p_order_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
  v_state TEXT;
  v_lga TEXT;
  v_matched_dc RECORD;
  v_matched_driver RECORD;
  v_grand_dc RECORD;
BEGIN
  -- 0. Fetch Order details
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Order not found');
  END IF;

  v_state := COALESCE(TRIM(v_order.delivery_state), '');
  v_lga := COALESCE(TRIM(v_order.lga), '');

  -- Fetch Grand DC fallback (Wuse Central Hub)
  SELECT * INTO v_grand_dc FROM public.distribution_centers WHERE is_grand_dc = true AND is_active = true ORDER BY created_at ASC LIMIT 1;
  IF v_grand_dc IS NULL THEN
    SELECT * INTO v_grand_dc FROM public.distribution_centers WHERE is_hub = true AND is_active = true ORDER BY created_at ASC LIMIT 1;
  END IF;
  IF v_grand_dc IS NULL THEN
    SELECT * INTO v_grand_dc FROM public.distribution_centers WHERE is_active = true ORDER BY created_at ASC LIMIT 1;
  END IF;

  -- 1. Check if the order already has an explicitly designated distribution_center_id
  IF v_order.distribution_center_id IS NOT NULL AND TRIM(v_order.distribution_center_id::text) <> '' THEN
    BEGIN
      SELECT * INTO v_matched_dc
      FROM public.distribution_centers
      WHERE id = v_order.distribution_center_id::uuid AND is_active = true
      LIMIT 1;
    EXCEPTION WHEN OTHERS THEN
      v_matched_dc := NULL;
    END;
  END IF;

  -- 2. If not pre-assigned, match Distribution Center by State and LGA coverage
  IF v_matched_dc IS NULL THEN
    SELECT * INTO v_matched_dc
    FROM public.distribution_centers
    WHERE is_active = true
      AND (
        LOWER(state) = LOWER(v_state) 
        OR LOWER(name) ILIKE '%' || LOWER(v_state) || '%'
      )
      AND (
        operating_zones @> to_jsonb(v_lga)
        OR operating_zones::text ILIKE '%' || v_lga || '%'
        OR v_lga = ''
      )
    ORDER BY is_hub DESC, created_at ASC
    LIMIT 1;

    -- Fallback: If no LGA match, check state match
    IF v_matched_dc IS NULL AND v_state <> '' THEN
      SELECT * INTO v_matched_dc
      FROM public.distribution_centers
      WHERE is_active = true
        AND (
          LOWER(state) = LOWER(v_state)
          OR LOWER(name) ILIKE '%' || LOWER(v_state) || '%'
        )
      ORDER BY is_hub DESC, created_at ASC
      LIMIT 1;
    END IF;
  END IF;

  -- FALLBACK A: No DC matches State/LGA and none pre-assigned -> Route to Grand DC for manual triage
  IF v_matched_dc IS NULL THEN
    UPDATE public.orders
    SET 
      distribution_center_id = v_grand_dc.id,
      delivery_agent_id = NULL,
      assigned_agent_id = NULL,
      status = 'pending_dispatch',
      assignment_status = 'pending_dc_assignment',
      routing_notes = '🚨 Escalated to Grand DC (' || v_grand_dc.name || '). No regional DC covers State: "' || v_state || '", LGA: "' || v_lga || '".',
      updated_at = NOW()
    WHERE id = p_order_id;

    RETURN jsonb_build_object(
      'success', true,
      'status', 'pending_dc_assignment',
      'distribution_center_id', v_grand_dc.id,
      'distribution_center_name', v_grand_dc.name,
      'assigned_agent_id', null,
      'message', 'No DC found. Escalated to Grand DC.'
    );
  END IF;

  -- 3. Match Active Rider strictly belonging to matched DC covering this LGA
  -- Supports 'available', 'active', 'on_duty' current_status
  SELECT * INTO v_matched_driver
  FROM public.delivery_agents
  WHERE is_active = true
    AND is_on_duty = true
    AND LOWER(current_status) IN ('available', 'active', 'on_duty')
    AND distribution_center_id = v_matched_dc.id
    AND (
      covered_lgas @> to_jsonb(v_lga)
      OR covered_lgas::text ILIKE '%' || v_lga || '%'
      OR operating_city ILIKE '%' || v_lga || '%'
    )
  ORDER BY created_at ASC
  LIMIT 1;

  -- SUCCESS: Eligible Rider Found -> Auto-assign to Rider and create notification
  IF v_matched_driver IS NOT NULL THEN
    UPDATE public.orders
    SET 
      distribution_center_id = v_matched_dc.id,
      delivery_agent_id = v_matched_driver.id,
      assigned_agent_id = v_matched_driver.id,
      status = 'assigned',
      assignment_status = 'auto_assigned',
      routing_notes = '✅ Auto-assigned to Rider (' || v_matched_driver.agent_code || ') at ' || v_matched_dc.name || ' covering LGA: "' || v_lga || '".',
      assigned_at = NOW(),
      updated_at = NOW()
    WHERE id = p_order_id;

    -- Insert in-app / push notification for rider
    INSERT INTO public.notifications (
      company_id,
      delivery_agent_id,
      title,
      message,
      category,
      action_route,
      is_read,
      created_at
    ) VALUES (
      COALESCE(v_order.company_id, '11111111-1111-4111-8111-111111111111'),
      v_matched_driver.id,
      'New Order Auto-Assigned! 📦',
      'Order #' || v_order.order_number || ' (' || v_order.customer_name || ' in ' || COALESCE(v_order.delivery_city, v_lga) || ') has been assigned to your route.',
      'delivery',
      '/orders',
      false,
      NOW()
    );

    RETURN jsonb_build_object(
      'success', true,
      'status', 'auto_assigned',
      'distribution_center_id', v_matched_dc.id,
      'distribution_center_name', v_matched_dc.name,
      'assigned_agent_id', v_matched_driver.id,
      'assigned_agent_code', v_matched_driver.agent_code,
      'message', 'Order auto-assigned to rider.'
    );
  END IF;

  -- FALLBACK B: DC matched / preserved, but no rider covers this LGA -> Keep DC and await rider assignment
  UPDATE public.orders
  SET 
    distribution_center_id = v_matched_dc.id,
    delivery_agent_id = NULL,
    assigned_agent_id = NULL,
    status = 'pending_dispatch',
    assignment_status = 'pending_rider_assignment',
    routing_notes = '⚠️ Routed to ' || v_matched_dc.name || '. Awaiting manual rider assignment for LGA: "' || v_lga || '".',
    updated_at = NOW()
  WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'pending_rider_assignment',
    'distribution_center_id', v_matched_dc.id,
    'distribution_center_name', v_matched_dc.name,
    'assigned_agent_id', null,
    'message', 'Routed to Station DC. Awaiting rider assignment.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Hardened transfer_order_product_and_ownership with conversation establishment & audit logging
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
    v_dc_name TEXT;
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

    -- 4. Normalize actor role
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

    -- 6. Update Order Record
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

    -- 7. Record Activity Audit Entry in order_activities
    INSERT INTO public.order_activities (
        order_id,
        activity_type,
        notes,
        created_at
    ) VALUES (
        p_order_id,
        CASE WHEN v_is_ownership_transfer THEN 'ownership_transferred' ELSE 'product_package_modified' END,
        v_msg_body || ' [Reason: ' || p_transfer_reason || '] by ' || p_actor_name,
        now()
    );

    -- 8. Find or Create Order Conversation in order_conversations
    SELECT id INTO v_conv_id FROM public.order_conversations WHERE order_id = p_order_id;
    IF v_conv_id IS NULL THEN
        SELECT name INTO v_dc_name FROM public.distribution_centers WHERE id = v_curr_order.distribution_center_id;
        INSERT INTO public.order_conversations (
            order_id,
            order_number,
            customer_name,
            customer_phone,
            client_id,
            client_name,
            distribution_center_id,
            distribution_center_name,
            delivery_agent_id,
            order_status,
            current_product_name,
            current_package_name,
            current_total_amount,
            last_message_text,
            last_message_sender_name,
            last_message_at,
            updated_at
        ) VALUES (
            p_order_id,
            v_curr_order.order_number,
            v_curr_order.customer_name,
            v_curr_order.customer_phone,
            CASE WHEN v_is_ownership_transfer THEN v_new_product.client_id ELSE v_curr_order.client_id END,
            CASE WHEN v_is_ownership_transfer THEN v_new_client_name ELSE v_old_client_name END,
            v_curr_order.distribution_center_id,
            v_dc_name,
            v_curr_order.delivery_agent_id,
            v_curr_order.status,
            v_new_product.name,
            v_final_package_name,
            v_final_price,
            v_msg_body,
            p_actor_name,
            now(),
            now()
        ) RETURNING id INTO v_conv_id;
    ELSE
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
    END IF;

    -- 9. Post Announcement Message in conversation
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

    -- 10. Return Confirmation JSON
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

-- 5. Realtime publication check for chat tables
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'order_conversations'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.order_conversations;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'order_conversation_messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.order_conversation_messages;
    END IF;
END $$;

NOTIFY pgrst, 'reload schema';
