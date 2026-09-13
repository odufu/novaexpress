-- ============================================================================
-- Migration: 20260915141500_fix_chat_message_read_columns.sql
-- Description:
--   Fixes fn_sync_order_conversation trigger to insert order_conversation_messages
--   with read_by_client, read_by_dc, read_by_rider instead of non-existent is_read.
-- ============================================================================

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

        -- Case B: Status Changed (Delivered, Failed, Rescheduled)
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
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
