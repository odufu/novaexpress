-- =========================================================================
-- MIGRATION: 20260917180000_novacare_closer_and_chat_avatar.sql
-- Description:
--   1. Expands `orders` and `order_conversations` tables with `closer_avatar_url`.
--   2. Updates `fn_sync_order_conversation` to sync closer full_name and avatar_url.
--   3. Updates `fn_on_order_message_inserted` to handle `closer` sender_role.
--   4. Seeds Novacare Closer (Amaka Chioma, closer@novacare.com) in `client_closers` and `users`.
-- =========================================================================

-- 1. Add closer_avatar_url to orders and order_conversations
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS closer_avatar_url TEXT;

ALTER TABLE public.order_conversations 
ADD COLUMN IF NOT EXISTS closer_avatar_url TEXT;

-- 2. Enhanced fn_sync_order_conversation
CREATE OR REPLACE FUNCTION public.fn_sync_order_conversation()
RETURNS TRIGGER AS $$
DECLARE
    v_conv_id UUID;
    v_client_name TEXT;
    v_dc_name TEXT;
    v_rider_name TEXT;
    v_closer_name TEXT;
    v_closer_avatar_url TEXT;
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

    -- Lookup Closer Full Name & Avatar URL
    IF NEW.closer_id IS NOT NULL THEN
        SELECT full_name, avatar_url INTO v_closer_name, v_closer_avatar_url
        FROM public.client_closers
        WHERE id = NEW.closer_id;
    END IF;

    -- Fallback to order fields if closer not in client_closers
    IF v_closer_name IS NULL THEN
        v_closer_name := NEW.closer_name;
    END IF;
    IF v_closer_avatar_url IS NULL THEN
        v_closer_avatar_url := NEW.closer_avatar_url;
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
        closer_avatar_url,
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
        v_closer_avatar_url,
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
        closer_avatar_url = EXCLUDED.closer_avatar_url,
        order_status = EXCLUDED.order_status,
        current_product_name = EXCLUDED.current_product_name,
        current_package_name = EXCLUDED.current_package_name,
        current_total_amount = EXCLUDED.current_total_amount,
        updated_at = now()
    RETURNING id INTO v_conv_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Enhanced fn_on_order_message_inserted to handle 'closer' sender_role
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

    ELSIF NEW.sender_role IN ('client', 'closer') THEN
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

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Seed Novacare Closer into client_closers and users
INSERT INTO public.client_closers (
    id,
    client_id,
    user_id,
    closer_code,
    full_name,
    email,
    phone,
    avatar_url,
    is_active,
    daily_call_target,
    commission_rate,
    created_at,
    updated_at
) VALUES (
    '44444444-4444-4444-8444-444444444444',
    '00000000-0000-4000-8000-789382731303',
    '44444444-4444-4444-8444-444444444444',
    'CLS-NOVA-001',
    'Amaka Chioma',
    'closer@novacare.com',
    '08021122334',
    'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=150&auto=format&fit=crop&q=80',
    true,
    50,
    500.00,
    now(),
    now()
)
ON CONFLICT (id) DO UPDATE SET
    client_id = EXCLUDED.client_id,
    closer_code = EXCLUDED.closer_code,
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email,
    phone = EXCLUDED.phone,
    avatar_url = EXCLUDED.avatar_url,
    is_active = EXCLUDED.is_active,
    commission_rate = EXCLUDED.commission_rate,
    updated_at = now();

-- Also ensure user record in public.users
INSERT INTO public.users (
    id,
    email,
    role,
    first_name,
    last_name,
    phone_number,
    client_id,
    avatar_url,
    is_active,
    created_at,
    updated_at
) VALUES (
    '44444444-4444-4444-8444-444444444444',
    'closer@novacare.com',
    'closer',
    'Amaka',
    'Chioma',
    '08021122334',
    '00000000-0000-4000-8000-789382731303',
    'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=150&auto=format&fit=crop&q=80',
    true,
    now(),
    now()
)
ON CONFLICT (id) DO UPDATE SET
    role = EXCLUDED.role,
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    phone_number = EXCLUDED.phone_number,
    client_id = EXCLUDED.client_id,
    avatar_url = EXCLUDED.avatar_url,
    is_active = EXCLUDED.is_active,
    updated_at = now();
