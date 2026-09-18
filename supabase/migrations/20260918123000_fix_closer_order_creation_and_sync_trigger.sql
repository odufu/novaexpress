-- Fix closer order creation and fn_sync_order_conversation trigger
-- 1. Ensure client_closers has closer_name column/alias so any queries referencing closer_name will never fail
ALTER TABLE public.client_closers ADD COLUMN IF NOT EXISTS closer_name TEXT;
UPDATE public.client_closers SET closer_name = full_name WHERE closer_name IS NULL;

-- 2. Ensure orders and order_conversations have closer_avatar_url
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS closer_avatar_url TEXT;
ALTER TABLE public.order_conversations ADD COLUMN IF NOT EXISTS closer_avatar_url TEXT;

-- 3. Fix fn_sync_order_conversation to safely reference full_name and avoid referencing non-existent columns on orders
CREATE OR REPLACE FUNCTION public.fn_sync_order_conversation()
RETURNS TRIGGER AS $$
DECLARE
    v_client_name TEXT := 'Merchant';
    v_dc_name TEXT := 'Distribution Hub';
    v_rider_name TEXT := 'Unassigned Rider';
    v_closer_name TEXT := 'Sales Closer';
    v_closer_avatar_url TEXT := NULL;
BEGIN
    -- Lookup Client Company Name
    IF NEW.client_id IS NOT NULL THEN
        SELECT COALESCE(name, company_name, 'Merchant') INTO v_client_name
        FROM public.clients
        WHERE id = NEW.client_id;
    END IF;

    -- Lookup Distribution Center Name
    IF NEW.distribution_center_id IS NOT NULL THEN
        SELECT name INTO v_dc_name
        FROM public.distribution_centers
        WHERE id = NEW.distribution_center_id;
    END IF;

    -- Lookup Rider Full Name
    IF NEW.delivery_agent_id IS NOT NULL THEN
        SELECT COALESCE(da.full_name, u.first_name || ' ' || u.last_name, da.bank_account_name, da.agent_code, 'Rider')
        INTO v_rider_name
        FROM public.delivery_agents da
        LEFT JOIN public.users u ON da.user_id = u.id
        WHERE da.id = NEW.delivery_agent_id;
    END IF;

    -- Lookup Closer Full Name & Avatar URL (Safe lookup using full_name)
    IF NEW.closer_id IS NOT NULL THEN
        SELECT COALESCE(full_name, closer_name, closer_code, 'Sales Closer'), avatar_url 
        INTO v_closer_name, v_closer_avatar_url
        FROM public.client_closers
        WHERE id = NEW.closer_id;
    END IF;

    -- Fallback to order fields if closer not in client_closers
    IF v_closer_name IS NULL OR v_closer_name = 'Sales Closer' THEN
        IF NEW.closer_name IS NOT NULL AND TRIM(NEW.closer_name) <> '' THEN
            v_closer_name := NEW.closer_name;
        END IF;
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
        COALESCE(NEW.client_name, v_client_name),
        NEW.distribution_center_id,
        v_dc_name,
        NEW.delivery_agent_id,
        v_rider_name,
        NEW.closer_id,
        COALESCE(NEW.closer_name, v_closer_name),
        v_closer_avatar_url,
        COALESCE(NEW.status, 'pending_dispatch'),
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
        distribution_center_name = v_dc_name,
        delivery_agent_id = EXCLUDED.delivery_agent_id,
        delivery_agent_name = v_rider_name,
        closer_id = EXCLUDED.closer_id,
        closer_name = EXCLUDED.closer_name,
        closer_avatar_url = EXCLUDED.closer_avatar_url,
        order_status = EXCLUDED.order_status,
        current_product_name = EXCLUDED.current_product_name,
        current_package_name = EXCLUDED.current_package_name,
        current_total_amount = EXCLUDED.current_total_amount,
        updated_at = now();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-attach trigger to orders table to ensure it triggers on insert/update
DROP TRIGGER IF EXISTS trg_sync_order_conversation ON public.orders;
CREATE TRIGGER trg_sync_order_conversation
    AFTER INSERT OR UPDATE OF customer_name, customer_phone, client_id, distribution_center_id, delivery_agent_id, closer_id, status, product_name, package_deal_name, total_amount
    ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_sync_order_conversation();
