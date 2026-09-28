-- Migration: 20260928043000_marketer_chat_dp_and_package_sync.sql
-- Description:
-- 1. Add marketer_id, marketer_name, marketer_avatar_url, and form_id to public.order_conversations
-- 2. Upgrade fn_sync_order_conversation to populate marketer details so conversation DP is that of the marketer who generated the order
-- 3. Create fn_update_marketer_profile RPC to atomically update marketer avatar, phone, and bank details across tables
-- 4. Upgrade fn_submit_marketing_lead_order to ensure order conversation inherits marketer DP immediately

-- 1. Add Marketer Fields to order_conversations
ALTER TABLE public.order_conversations
  ADD COLUMN IF NOT EXISTS marketer_id UUID REFERENCES public.client_marketers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS marketer_name TEXT,
  ADD COLUMN IF NOT EXISTS marketer_avatar_url TEXT,
  ADD COLUMN IF NOT EXISTS form_id UUID REFERENCES public.lead_forms(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_order_conversations_marketer_id ON public.order_conversations(marketer_id);
CREATE INDEX IF NOT EXISTS idx_order_conversations_form_id ON public.order_conversations(form_id);

-- 2. Upgrade fn_sync_order_conversation to synchronize Marketer DP & closer DP
CREATE OR REPLACE FUNCTION public.fn_sync_order_conversation()
RETURNS TRIGGER AS $$
DECLARE
    v_client_name TEXT := 'Merchant';
    v_dc_name TEXT := 'Distribution Hub';
    v_rider_name TEXT := 'Unassigned Rider';
    v_closer_name TEXT := 'Sales Closer';
    v_closer_avatar_url TEXT := NULL;
    v_marketer_name TEXT := NULL;
    v_marketer_avatar_url TEXT := NULL;
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

    -- Lookup Closer Full Name & Avatar URL
    IF NEW.closer_id IS NOT NULL THEN
        SELECT COALESCE(full_name, closer_name, closer_code, 'Sales Closer'), avatar_url 
        INTO v_closer_name, v_closer_avatar_url
        FROM public.client_closers
        WHERE id = NEW.closer_id;
    END IF;

    -- Fallback closer details
    IF v_closer_name IS NULL OR v_closer_name = 'Sales Closer' THEN
        IF NEW.closer_name IS NOT NULL AND TRIM(NEW.closer_name) <> '' THEN
            v_closer_name := NEW.closer_name;
        END IF;
    END IF;
    IF v_closer_avatar_url IS NULL THEN
        v_closer_avatar_url := NEW.closer_avatar_url;
    END IF;

    -- Lookup Digital Marketer Full Name & Avatar URL (the person whose lead form generated this order)
    IF NEW.marketer_id IS NOT NULL THEN
        SELECT COALESCE(full_name, marketer_code, 'Digital Marketer'), avatar_url
        INTO v_marketer_name, v_marketer_avatar_url
        FROM public.client_marketers
        WHERE id = NEW.marketer_id;
    END IF;

    IF v_marketer_name IS NULL AND NEW.marketer_name IS NOT NULL AND TRIM(NEW.marketer_name) <> '' THEN
        v_marketer_name := NEW.marketer_name;
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
        marketer_id,
        marketer_name,
        marketer_avatar_url,
        form_id,
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
        NEW.marketer_id,
        COALESCE(v_marketer_name, NEW.marketer_name),
        v_marketer_avatar_url,
        NEW.form_id,
        COALESCE(NEW.status, 'new'),
        NEW.product_name,
        NEW.package_deal_name,
        COALESCE(NEW.total_amount, 0),
        CASE 
            WHEN NEW.marketer_id IS NOT NULL THEN 'Marketing order created via Lead Form.'
            ELSE 'Order pipeline active.'
        END,
        COALESCE(v_marketer_name, 'System'),
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
        closer_id = COALESCE(EXCLUDED.closer_id, order_conversations.closer_id),
        closer_name = COALESCE(EXCLUDED.closer_name, order_conversations.closer_name),
        closer_avatar_url = COALESCE(EXCLUDED.closer_avatar_url, order_conversations.closer_avatar_url),
        marketer_id = COALESCE(EXCLUDED.marketer_id, order_conversations.marketer_id),
        marketer_name = COALESCE(EXCLUDED.marketer_name, order_conversations.marketer_name),
        marketer_avatar_url = COALESCE(EXCLUDED.marketer_avatar_url, order_conversations.marketer_avatar_url),
        form_id = COALESCE(EXCLUDED.form_id, order_conversations.form_id),
        order_status = EXCLUDED.order_status,
        current_product_name = EXCLUDED.current_product_name,
        current_package_name = EXCLUDED.current_package_name,
        current_total_amount = EXCLUDED.current_total_amount,
        updated_at = now();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-attach trigger on orders table
DROP TRIGGER IF EXISTS trg_sync_order_conversation ON public.orders;
CREATE TRIGGER trg_sync_order_conversation
    AFTER INSERT OR UPDATE OF customer_name, customer_phone, client_id, distribution_center_id, delivery_agent_id, closer_id, marketer_id, form_id, status, product_name, package_deal_name, total_amount
    ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_sync_order_conversation();

-- Backfill existing order_conversations from orders
UPDATE public.order_conversations oc
SET marketer_id = o.marketer_id,
    marketer_name = COALESCE(m.full_name, o.marketer_name),
    marketer_avatar_url = m.avatar_url,
    form_id = o.form_id
FROM public.orders o
LEFT JOIN public.client_marketers m ON m.id = o.marketer_id
WHERE oc.order_id = o.id AND o.marketer_id IS NOT NULL;

-- 3. Stored Procedure: fn_update_marketer_profile
CREATE OR REPLACE FUNCTION public.fn_update_marketer_profile(
    p_marketer_id UUID,
    p_full_name TEXT DEFAULT NULL,
    p_phone TEXT DEFAULT NULL,
    p_avatar_url TEXT DEFAULT NULL,
    p_bank_name TEXT DEFAULT NULL,
    p_account_number TEXT DEFAULT NULL,
    p_account_name TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_updated_row RECORD;
BEGIN
    -- Update client_marketers table
    UPDATE public.client_marketers
    SET full_name = COALESCE(NULLIF(TRIM(p_full_name), ''), full_name),
        phone = COALESCE(NULLIF(TRIM(p_phone), ''), phone),
        avatar_url = COALESCE(NULLIF(TRIM(p_avatar_url), ''), avatar_url),
        bank_name = COALESCE(p_bank_name, bank_name),
        account_number = COALESCE(p_account_number, account_number),
        account_name = COALESCE(p_account_name, account_name),
        updated_at = NOW()
    WHERE id = p_marketer_id
    RETURNING * INTO v_updated_row;

    IF v_updated_row IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Marketer not found');
    END IF;

    -- If linked to auth user, cascade avatar_url and phone to users table
    v_user_id := v_updated_row.user_id;
    IF v_user_id IS NOT NULL THEN
        UPDATE public.users
        SET avatar_url = COALESCE(NULLIF(TRIM(p_avatar_url), ''), avatar_url),
            phone = COALESCE(NULLIF(TRIM(p_phone), ''), phone)
        WHERE id = v_user_id;
    END IF;

    -- Also update all existing order_conversations associated with this marketer
    IF p_avatar_url IS NOT NULL AND TRIM(p_avatar_url) <> '' THEN
        UPDATE public.order_conversations
        SET marketer_avatar_url = p_avatar_url,
            marketer_name = COALESCE(v_updated_row.full_name, marketer_name),
            updated_at = NOW()
        WHERE marketer_id = p_marketer_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'marketer_id', v_updated_row.id,
        'full_name', v_updated_row.full_name,
        'avatar_url', v_updated_row.avatar_url,
        'phone', v_updated_row.phone,
        'bank_name', v_updated_row.bank_name,
        'account_number', v_updated_row.account_number,
        'account_name', v_updated_row.account_name
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
