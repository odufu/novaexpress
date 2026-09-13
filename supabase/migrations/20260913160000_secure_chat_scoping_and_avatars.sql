-- ============================================================================
-- Migration: 20260913160000_secure_chat_scoping_and_avatars.sql
-- Description:
--   1. Add closer_id and closer_name to order_conversations referencing client_closers
--   2. Add sender_avatar_url to order_conversation_messages
--   3. Tighten RLS policies on order_conversations and order_conversation_messages (no public/null leaks)
--   4. Function fn_mark_conversation_read to reset unread counters cleanly
-- ============================================================================

-- 1. Table Alterations: order_conversations
ALTER TABLE public.order_conversations
ADD COLUMN IF NOT EXISTS closer_id UUID REFERENCES public.client_closers(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS closer_name TEXT;

CREATE INDEX IF NOT EXISTS idx_order_conversations_closer_id ON public.order_conversations(closer_id);

-- 2. Table Alterations: order_conversation_messages
ALTER TABLE public.order_conversation_messages
ADD COLUMN IF NOT EXISTS sender_avatar_url TEXT;

-- 3. Update fn_sync_order_conversation to also map closer
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

    -- Lookup Rider Name if set
    IF NEW.delivery_agent_id IS NOT NULL THEN
        SELECT full_name INTO v_rider_name
        FROM public.delivery_agents
        WHERE id = NEW.delivery_agent_id;
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

-- 4. Secure RLS Policies: Strictly enforce no cross-tenant visibility
DROP POLICY IF EXISTS "Users can view conversations relevant to them" ON public.order_conversations;
CREATE POLICY "Users can view conversations relevant to them" ON public.order_conversations
FOR SELECT USING (
    auth.role() = 'service_role' OR
    (
        auth.uid() IS NOT NULL AND
        EXISTS (
            SELECT 1 FROM public.users u
            LEFT JOIN public.delivery_agents da ON da.user_id = u.id
            LEFT JOIN public.client_closers cc ON cc.user_id = u.id
            WHERE u.id = auth.uid() AND (
                (u.role IN ('client', 'merchant') AND u.client_id::text = order_conversations.client_id::text) OR
                (u.role IN ('dc_manager', 'dc_staff', 'operations') AND u.distribution_center_id::text = order_conversations.distribution_center_id::text) OR
                (da.id::text = order_conversations.delivery_agent_id::text) OR
                (cc.id::text = order_conversations.closer_id::text) OR
                (u.role IN ('super_admin', 'admin'))
            )
        )
    )
);

DROP POLICY IF EXISTS "Users can view messages in their conversations" ON public.order_conversation_messages;
CREATE POLICY "Users can view messages in their conversations" ON public.order_conversation_messages
FOR SELECT USING (
    auth.role() = 'service_role' OR
    (
        auth.uid() IS NOT NULL AND
        EXISTS (
            SELECT 1 FROM public.order_conversations oc
            JOIN public.users u ON u.id = auth.uid()
            LEFT JOIN public.delivery_agents da ON da.user_id = u.id
            LEFT JOIN public.client_closers cc ON cc.user_id = u.id
            WHERE oc.id = order_conversation_messages.conversation_id AND (
                (u.role IN ('client', 'merchant') AND u.client_id::text = oc.client_id::text) OR
                (u.role IN ('dc_manager', 'dc_staff', 'operations') AND u.distribution_center_id::text = oc.distribution_center_id::text) OR
                (da.id::text = oc.delivery_agent_id::text) OR
                (cc.id::text = oc.closer_id::text) OR
                (u.role IN ('super_admin', 'admin'))
            )
        )
    )
);

DROP POLICY IF EXISTS "Users can insert messages into their conversations" ON public.order_conversation_messages;
CREATE POLICY "Users can insert messages into their conversations" ON public.order_conversation_messages
FOR INSERT WITH CHECK (
    auth.role() = 'service_role' OR
    (
        auth.uid() IS NOT NULL AND
        EXISTS (
            SELECT 1 FROM public.order_conversations oc
            JOIN public.users u ON u.id = auth.uid()
            LEFT JOIN public.delivery_agents da ON da.user_id = u.id
            LEFT JOIN public.client_closers cc ON cc.user_id = u.id
            WHERE oc.id = order_conversation_messages.conversation_id AND (
                (u.role IN ('client', 'merchant') AND u.client_id::text = oc.client_id::text) OR
                (u.role IN ('dc_manager', 'dc_staff', 'operations') AND u.distribution_center_id::text = oc.distribution_center_id::text) OR
                (da.id::text = oc.delivery_agent_id::text) OR
                (cc.id::text = oc.closer_id::text) OR
                (u.role IN ('super_admin', 'admin'))
            )
        )
    )
);

-- 5. Helper Function: fn_mark_conversation_read
CREATE OR REPLACE FUNCTION public.fn_mark_conversation_read(
    p_conversation_id UUID,
    p_role TEXT
)
RETURNS VOID AS $$
BEGIN
    IF lower(p_role) IN ('rider', 'delivery_agent', 'pda') THEN
        UPDATE public.order_conversations
        SET unread_rider_count = 0, updated_at = now()
        WHERE id = p_conversation_id;

        UPDATE public.order_conversation_messages
        SET read_by_rider = true
        WHERE conversation_id = p_conversation_id AND read_by_rider = false;

    ELSIF lower(p_role) IN ('dc_manager', 'dc_staff', 'operations') THEN
        UPDATE public.order_conversations
        SET unread_dc_count = 0, updated_at = now()
        WHERE id = p_conversation_id;

        UPDATE public.order_conversation_messages
        SET read_by_dc = true
        WHERE conversation_id = p_conversation_id AND read_by_dc = false;

    ELSIF lower(p_role) IN ('client', 'merchant', 'closer', 'sales_closer') THEN
        UPDATE public.order_conversations
        SET unread_client_count = 0, updated_at = now()
        WHERE id = p_conversation_id;

        UPDATE public.order_conversation_messages
        SET read_by_client = true
        WHERE conversation_id = p_conversation_id AND read_by_client = false;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
