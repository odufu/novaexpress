-- ============================================================================
-- Migration: 20260915150000_chat_tagging_and_notifications_remediation.sql
-- Description:
--   1. Expands public.notifications with user_id and client_id so DC Managers,
--      Clients, and Closers receive targeted notifications alongside Riders.
--   2. Enhances fn_on_order_message_inserted trigger:
--      - Detects @Operations, @Rider, and @Client mentions in message bodies.
--      - Automatically inserts real-time notifications into public.notifications
--        with action routes linking directly to the specific order chat.
--   3. Enhances fn_sync_order_conversation trigger:
--      - Adds automatic milestone chat broadcasting for 'in_transit' / 'dispatched'
--        and 'confirmed' order status transitions.
-- ============================================================================

-- 1. Add user_id and client_id to public.notifications
ALTER TABLE IF EXISTS public.notifications
    ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS client_id UUID REFERENCES public.clients(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_client_id ON public.notifications(client_id);


-- 2. Enhanced fn_on_order_message_inserted with @Tagging & Notifications
CREATE OR REPLACE FUNCTION public.fn_on_order_message_inserted()
RETURNS TRIGGER AS $$
DECLARE
    v_conv RECORD;
    v_dc_manager_id UUID;
    v_client_user_id UUID;
    v_order_num TEXT;
BEGIN
    -- 1. Fetch parent conversation details
    SELECT * INTO v_conv
    FROM public.order_conversations
    WHERE id = NEW.conversation_id;

    v_order_num := COALESCE(v_conv.order_number, 'Order');

    -- 2. Update order_conversations preview and role unread counters
    IF NEW.sender_role = 'delivery_agent' THEN
        UPDATE public.order_conversations
        SET last_message_text = NEW.message_body,
            last_message_sender_name = NEW.sender_name,
            last_message_at = NEW.created_at,
            unread_rider_count = 0,
            unread_dc_count = unread_dc_count + 1,
            unread_client_count = unread_client_count + 1,
            updated_at = now()
        WHERE id = NEW.conversation_id;

    ELSIF NEW.sender_role = 'dc_manager' THEN
        UPDATE public.order_conversations
        SET last_message_text = NEW.message_body,
            last_message_sender_name = NEW.sender_name,
            last_message_at = NEW.created_at,
            unread_dc_count = 0,
            unread_rider_count = unread_rider_count + 1,
            unread_client_count = unread_client_count + 1,
            updated_at = now()
        WHERE id = NEW.conversation_id;

    ELSIF NEW.sender_role = 'client' THEN
        UPDATE public.order_conversations
        SET last_message_text = NEW.message_body,
            last_message_sender_name = NEW.sender_name,
            last_message_at = NEW.created_at,
            unread_client_count = 0,
            unread_rider_count = unread_rider_count + 1,
            unread_dc_count = unread_dc_count + 1,
            updated_at = now()
        WHERE id = NEW.conversation_id;

    ELSE
        -- System or milestone notification
        UPDATE public.order_conversations
        SET last_message_text = NEW.message_body,
            last_message_sender_name = NEW.sender_name,
            last_message_at = NEW.created_at,
            unread_rider_count = unread_rider_count + 1,
            unread_dc_count = unread_dc_count + 1,
            unread_client_count = unread_client_count + 1,
            updated_at = now()
        WHERE id = NEW.conversation_id;
    END IF;

    -- 3. Automatic Tagging & Real-Time Push / In-App Notification Dispatch
    -- Only dispatch notifications for human chat messages (not automated system bot)
    IF NEW.sender_role <> 'system' AND v_conv.id IS NOT NULL THEN

        -- Scenario A: Tagged @Operations / @DC / @Manager, OR Rider sent a message to DC
        IF NEW.message_body ILIKE '%@Operations%' OR NEW.message_body ILIKE '%@DC%' OR NEW.message_body ILIKE '%@Manager%' OR NEW.sender_role = 'delivery_agent' THEN
            -- Lookup manager user for this DC
            SELECT u.id INTO v_dc_manager_id
            FROM public.users u
            WHERE (u.distribution_center_id::text = v_conv.distribution_center_id::text OR u.role = 'dc_manager')
              AND u.is_active = true
            ORDER BY (u.distribution_center_id::text = v_conv.distribution_center_id::text) DESC, u.created_at ASC
            LIMIT 1;

            IF v_dc_manager_id IS NOT NULL THEN
                INSERT INTO public.notifications (
                    company_id,
                    user_id,
                    title,
                    message,
                    category,
                    action_route,
                    is_read,
                    created_at
                ) VALUES (
                    '11111111-1111-4111-8111-111111111111',
                    v_dc_manager_id,
                    CASE 
                        WHEN NEW.message_body ILIKE '%@Operations%' THEN '🚨 Tagged by ' || NEW.sender_name || ' (#' || v_order_num || ')'
                        ELSE '💬 Order Message from ' || NEW.sender_name || ' (#' || v_order_num || ')'
                    END,
                    SUBSTRING(NEW.message_body FROM 1 FOR 140),
                    'chat',
                    '/orders/' || v_conv.order_id,
                    false,
                    now()
                );
            END IF;
        END IF;

        -- Scenario B: Tagged @Rider, OR DC Manager / Client sent a message to Rider
        IF (NEW.message_body ILIKE '%@Rider%' OR NEW.sender_role IN ('dc_manager', 'client')) AND v_conv.delivery_agent_id IS NOT NULL THEN
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
                '11111111-1111-4111-8111-111111111111',
                v_conv.delivery_agent_id,
                CASE 
                    WHEN NEW.message_body ILIKE '%@Rider%' THEN '🚨 Mentioned by ' || NEW.sender_name || ' (#' || v_order_num || ')'
                    ELSE '💬 Update on Order #' || v_order_num
                END,
                SUBSTRING(NEW.message_body FROM 1 FOR 140),
                'chat',
                '/orders/' || v_conv.order_id,
                false,
                now()
            );
        END IF;

        -- Scenario C: Tagged @Client / @Merchant
        IF (NEW.message_body ILIKE '%@Client%' OR NEW.message_body ILIKE '%@Merchant%') AND v_conv.client_id IS NOT NULL THEN
            -- Lookup user attached to this client
            SELECT u.id INTO v_client_user_id
            FROM public.users u
            WHERE u.client_id::text = v_conv.client_id::text AND u.is_active = true
            ORDER BY u.created_at ASC
            LIMIT 1;

            INSERT INTO public.notifications (
                company_id,
                client_id,
                user_id,
                title,
                message,
                category,
                action_route,
                is_read,
                created_at
            ) VALUES (
                '11111111-1111-4111-8111-111111111111',
                v_conv.client_id,
                v_client_user_id,
                '🚨 Operations Tagged Merchant (Order #' || v_order_num || ')',
                SUBSTRING(NEW.message_body FROM 1 FOR 140),
                'chat',
                '/orders/' || v_conv.order_id,
                false,
                now()
            );
        END IF;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. Enhanced fn_sync_order_conversation with full lifecycle milestone broadcasts
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
    SELECT name INTO v_client_name
    FROM public.clients
    WHERE id = NEW.client_id;

    -- Lookup DC Name
    IF NEW.distribution_center_id IS NOT NULL THEN
        SELECT name INTO v_dc_name
        FROM public.distribution_centers
        WHERE id = NEW.distribution_center_id;
    END IF;

    -- Lookup Rider Full Name
    IF NEW.delivery_agent_id IS NOT NULL THEN
        SELECT COALESCE(da.full_name, u.first_name || ' ' || u.last_name, da.bank_account_name, da.agent_code)
        INTO v_rider_name
        FROM public.delivery_agents da
        LEFT JOIN public.users u ON da.user_id = u.id
        WHERE da.id = NEW.delivery_agent_id;
    END IF;

    -- Lookup Closer Name
    IF NEW.closer_id IS NOT NULL THEN
        SELECT closer_name INTO v_closer_name
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
        updated_at = now()
    RETURNING id INTO v_conv_id;

    -- If TG_OP is UPDATE, emit milestone messages into the chat for Client, DC, and Rider
    IF TG_OP = 'UPDATE' AND v_conv_id IS NOT NULL THEN
        -- Case A: Rider Assigned
        IF (OLD.delivery_agent_id IS DISTINCT FROM NEW.delivery_agent_id) AND NEW.delivery_agent_id IS NOT NULL THEN
            INSERT INTO public.order_conversation_messages (
                conversation_id,
                order_id,
                sender_name,
                sender_role,
                message_body,
                message_type,
                metadata,
                read_by_client,
                read_by_dc,
                read_by_rider,
                created_at
            ) VALUES (
                v_conv_id,
                NEW.id,
                'System Dispatcher',
                'system',
                '🚴 Rider Assigned: ' || COALESCE(v_rider_name, 'Fleet Rider') || ' has been assigned to deliver order #' || NEW.order_number || '.',
                'rider_assigned',
                jsonb_build_object('delivery_agent_id', NEW.delivery_agent_id, 'delivery_agent_name', v_rider_name),
                false,
                false,
                false,
                now()
            );
        END IF;

        -- Case B: Status Changed (In-Transit, Delivered, Failed, Rescheduled, Confirmed)
        IF OLD.status IS DISTINCT FROM NEW.status THEN
            IF NEW.status = 'delivered' THEN
                INSERT INTO public.order_conversation_messages (
                    conversation_id,
                    order_id,
                    sender_name,
                    sender_role,
                    message_body,
                    message_type,
                    metadata,
                    read_by_client,
                    read_by_dc,
                    read_by_rider,
                    created_at
                ) VALUES (
                    v_conv_id,
                    NEW.id,
                    'Delivery Operations',
                    'system',
                    '🎉 Order Delivered! Order #' || NEW.order_number || ' completed successfully. Payment: ' || UPPER(COALESCE(NEW.payment_method, 'COD')) || ' (₦' || TO_CHAR(COALESCE(NEW.total_amount, 0), 'FM999,999,999') || ').',
                    'delivery_completed',
                    jsonb_build_object(
                        'delivered_at', NEW.delivered_at,
                        'total_amount', NEW.total_amount,
                        'payment_method', NEW.payment_method,
                        'proof_of_delivery_url', NEW.proof_of_delivery_url
                    ),
                    false,
                    false,
                    false,
                    now()
                );
            ELSIF NEW.status IN ('delivery_failed', 'failed') THEN
                INSERT INTO public.order_conversation_messages (
                    conversation_id,
                    order_id,
                    sender_name,
                    sender_role,
                    message_body,
                    message_type,
                    metadata,
                    read_by_client,
                    read_by_dc,
                    read_by_rider,
                    created_at
                ) VALUES (
                    v_conv_id,
                    NEW.id,
                    'Delivery Operations',
                    'system',
                    '⚠️ Delivery Attempt Failed for Order #' || NEW.order_number || '. Reason: ' || COALESCE(NEW.reschedule_note, NEW.delivery_notes, 'Customer unreachable') || '.',
                    'delivery_failed',
                    jsonb_build_object('failure_note', COALESCE(NEW.reschedule_note, NEW.delivery_notes)),
                    false,
                    false,
                    false,
                    now()
                );
            ELSIF NEW.status = 'rescheduled' THEN
                INSERT INTO public.order_conversation_messages (
                    conversation_id,
                    order_id,
                    sender_name,
                    sender_role,
                    message_body,
                    message_type,
                    metadata,
                    read_by_client,
                    read_by_dc,
                    read_by_rider,
                    created_at
                ) VALUES (
                    v_conv_id,
                    NEW.id,
                    'Delivery Operations',
                    'system',
                    '📅 Order Rescheduled: Callback set for Order #' || NEW.order_number || '. Note: ' || COALESCE(NEW.reschedule_note, 'Pending customer consultation') || '.',
                    'rescheduled',
                    jsonb_build_object('rescheduled_at', NEW.scheduled_callback_at, 'reschedule_note', NEW.reschedule_note),
                    false,
                    false,
                    false,
                    now()
                );
            ELSIF NEW.status IN ('in_transit', 'dispatched') THEN
                INSERT INTO public.order_conversation_messages (
                    conversation_id,
                    order_id,
                    sender_name,
                    sender_role,
                    message_body,
                    message_type,
                    metadata,
                    read_by_client,
                    read_by_dc,
                    read_by_rider,
                    created_at
                ) VALUES (
                    v_conv_id,
                    NEW.id,
                    'Fleet Dispatch',
                    'system',
                    '🚚 Out for Delivery: Order #' || NEW.order_number || ' is now in transit with rider ' || COALESCE(v_rider_name, 'Assigned Rider') || '.',
                    'status_change',
                    jsonb_build_object('status', NEW.status, 'rider_name', v_rider_name),
                    false,
                    false,
                    false,
                    now()
                );
            ELSIF NEW.status IN ('confirmed', 'ready_for_dispatch') THEN
                INSERT INTO public.order_conversation_messages (
                    conversation_id,
                    order_id,
                    sender_name,
                    sender_role,
                    message_body,
                    message_type,
                    metadata,
                    read_by_client,
                    read_by_dc,
                    read_by_rider,
                    created_at
                ) VALUES (
                    v_conv_id,
                    NEW.id,
                    'DC Operations',
                    'system',
                    '📋 Order Confirmed: Order #' || NEW.order_number || ' verified and queued for dispatch at ' || COALESCE(v_dc_name, 'Distribution Center') || '.',
                    'status_change',
                    jsonb_build_object('status', NEW.status, 'dc_name', v_dc_name),
                    false,
                    false,
                    false,
                    now()
                );
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
