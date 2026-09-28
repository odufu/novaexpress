-- Migration: 20260928060000_marketer_supervision_phone_normalization_and_dedup.sql
-- Description:
-- 1. Digital Marketer Supervision Hierarchy: is_supervisor flag and supervisor_id foreign key.
-- 2. Commission Model configuration: per_form_submission vs per_delivered_order.
-- 3. Robust Phone Number Normalization Function (handles +234, 00234, 234, leading 0, no leading 0, spaces, dashes, parentheses).
-- 4. Duplicate Form Submission Prevention: checks active orders by normalized phone and prevents double deliveries and duplicate commission claims.
-- 5. Updated RLS policies for order_conversations to scope regular marketers strictly to their assets and allow supervisors to view supervisees' orders.

-- 1. Extend client_marketers with supervisory and commission configuration
ALTER TABLE public.client_marketers
  ADD COLUMN IF NOT EXISTS is_supervisor BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS supervisor_id UUID REFERENCES public.client_marketers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS commission_model TEXT DEFAULT 'per_form_submission',
  ADD COLUMN IF NOT EXISTS commission_per_form_submission NUMERIC(12,2) DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS commission_per_delivered_order NUMERIC(12,2) DEFAULT 0.00;

CREATE INDEX IF NOT EXISTS idx_client_marketers_supervisor_id ON public.client_marketers(supervisor_id);
CREATE INDEX IF NOT EXISTS idx_client_marketers_is_supervisor ON public.client_marketers(is_supervisor);

-- 2. Extend users with marketer fields if not present
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS marketer_id UUID,
  ADD COLUMN IF NOT EXISTS marketer_code TEXT,
  ADD COLUMN IF NOT EXISTS is_supervisor BOOLEAN DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_users_marketer_id ON public.users(marketer_id);

-- 3. Extend orders and customer_leads with customer_phone_normalized column
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS customer_phone_normalized TEXT;

CREATE INDEX IF NOT EXISTS idx_orders_customer_phone_normalized ON public.orders(customer_phone_normalized);
CREATE INDEX IF NOT EXISTS idx_orders_client_phone_norm_status ON public.orders(client_id, customer_phone_normalized, status);

ALTER TABLE public.customer_leads
  ADD COLUMN IF NOT EXISTS customer_phone_normalized TEXT;

CREATE INDEX IF NOT EXISTS idx_customer_leads_phone_normalized ON public.customer_leads(customer_phone_normalized);

-- 4. Canonical Phone Number Normalization Function
CREATE OR REPLACE FUNCTION public.fn_normalize_nigerian_phone(p_phone TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_clean TEXT;
BEGIN
    IF p_phone IS NULL OR TRIM(p_phone) = '' THEN
        RETURN '';
    END IF;

    -- Strip all non-digit characters
    v_clean := REGEXP_REPLACE(p_phone, '\D', '', 'g');

    -- Strip international prefix 00234
    IF v_clean LIKE '00234%' THEN
        v_clean := SUBSTRING(v_clean FROM 6);
    -- Strip country code 234
    ELSIF v_clean LIKE '234%' THEN
        v_clean := SUBSTRING(v_clean FROM 4);
    END IF;

    -- Strip leading 0 if present (e.g. from +234(0)801... or 0801...)
    IF v_clean LIKE '0%' THEN
        v_clean := SUBSTRING(v_clean FROM 2);
    END IF;

    -- Standard Nigerian mobile numbers are 10 national digits (starting with 7, 8, or 9)
    -- If string length >= 10, take the rightmost 10 digits and prefix standard '0'
    IF LENGTH(v_clean) >= 10 THEN
        v_clean := RIGHT(v_clean, 10);
        RETURN '0' || v_clean; -- Canonical 11-digit local format: e.g. 08012345678
    END IF;

    -- Fallback for short local inputs
    IF LENGTH(v_clean) > 0 THEN
        RETURN '0' || v_clean;
    END IF;

    RETURN '';
END;
$$;

-- Populate existing orders' customer_phone_normalized for existing records
UPDATE public.orders
SET customer_phone_normalized = public.fn_normalize_nigerian_phone(customer_phone)
WHERE customer_phone_normalized IS NULL AND customer_phone IS NOT NULL;

-- 5. Upgraded Lead Form Submission RPC with Duplicate Prevention & Normalization
CREATE OR REPLACE FUNCTION public.fn_submit_marketing_lead_order(p_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_form_id UUID;
    v_client_id UUID;
    v_marketer_id UUID;
    v_marketer_name TEXT;
    v_product_id UUID;
    v_product_name TEXT;
    v_product_sku TEXT;
    v_product_price NUMERIC;
    v_customer_name TEXT;
    v_raw_customer_phone TEXT;
    v_customer_phone TEXT;
    v_customer_alt_phone TEXT;
    v_customer_email TEXT;
    v_delivery_address TEXT;
    v_delivery_state TEXT;
    v_delivery_lga TEXT;
    v_notes TEXT;
    v_package_id TEXT;
    v_package_name TEXT;
    v_paid_qty INT;
    v_free_qty INT;
    v_buy_qty INT;
    v_total_amount NUMERIC;
    v_redirect_url TEXT;
    v_utm_source TEXT;
    v_utm_medium TEXT;
    v_utm_campaign TEXT;
    v_utm_content TEXT;
    v_ad_id TEXT;
    v_order_id UUID;
    v_lead_id UUID;
    v_order_number TEXT;
    v_assigned_closer_id UUID;
    v_assigned_closer_name TEXT;
    v_final_redirect TEXT;

    -- Duplicate detection variables
    v_existing_order_id UUID;
    v_existing_order_number TEXT;
    v_existing_status TEXT;
    v_existing_amount NUMERIC;
    v_existing_package TEXT;
    v_existing_state TEXT;
    v_existing_lga TEXT;
    v_existing_created_at TIMESTAMPTZ;
BEGIN
    -- Parse & Sanitize Inputs
    v_form_id := (p_payload->>'form_id')::UUID;
    v_customer_name := TRIM(COALESCE(p_payload->>'customer_name', 'Valued Customer'));
    v_raw_customer_phone := TRIM(COALESCE(p_payload->>'customer_phone', ''));
    v_customer_phone := public.fn_normalize_nigerian_phone(v_raw_customer_phone);
    v_customer_alt_phone := TRIM(COALESCE(p_payload->>'customer_alt_phone', ''));
    v_customer_email := TRIM(COALESCE(p_payload->>'customer_email', ''));
    v_delivery_address := TRIM(COALESCE(p_payload->>'delivery_address', ''));
    v_delivery_state := TRIM(COALESCE(p_payload->>'delivery_state', 'Lagos'));
    v_delivery_lga := TRIM(COALESCE(p_payload->>'delivery_lga', p_payload->>'lga', p_payload->>'delivery_city', 'Ikeja'));
    v_notes := TRIM(COALESCE(p_payload->>'notes', ''));
    v_package_id := COALESCE(p_payload->>'package_deal_id', p_payload->>'package_id', 'pkg-1');
    v_package_name := COALESCE(p_payload->>'package_selected', p_payload->>'package_name', 'Standard Package');
    
    v_paid_qty := COALESCE((p_payload->>'paid_quantity')::INT, (p_payload->>'buy_qty')::INT, 1);
    v_free_qty := COALESCE((p_payload->>'free_quantity')::INT, 0);
    v_buy_qty := COALESCE((p_payload->>'package_quantity')::INT, (p_payload->>'buy_qty')::INT, (v_paid_qty + v_free_qty));
    v_total_amount := COALESCE((p_payload->>'order_amount')::NUMERIC, (p_payload->>'total_amount')::NUMERIC, 0.00);

    -- UTM attributes
    v_utm_source := p_payload->>'utm_source';
    v_utm_medium := p_payload->>'utm_medium';
    v_utm_campaign := p_payload->>'utm_campaign';
    v_utm_content := p_payload->>'utm_content';
    v_ad_id := p_payload->>'ad_id';

    -- Validation
    IF v_form_id IS NULL THEN
        RAISE EXCEPTION 'form_id is required';
    END IF;
    IF LENGTH(v_customer_phone) < 10 THEN
        RAISE EXCEPTION 'Valid phone number is required';
    END IF;

    -- Lookup Form Details
    SELECT f.client_id, f.marketer_id, f.product_id, f.product_name, f.redirect_url, m.full_name
    INTO v_client_id, v_marketer_id, v_product_id, v_product_name, v_redirect_url, v_marketer_name
    FROM public.lead_forms f
    LEFT JOIN public.client_marketers m ON m.id = f.marketer_id
    WHERE f.id = v_form_id;

    IF v_client_id IS NULL THEN
        RAISE EXCEPTION 'Lead form not found or inactive';
    END IF;

    -- DUPLICATE PREVENTION CHECK
    -- Detect if an active non-terminal order exists for this client with the same normalized phone within 48 hours
    SELECT id, order_number, status, total_amount, package_deal_name, delivery_state, delivery_lga, created_at
    INTO v_existing_order_id, v_existing_order_number, v_existing_status, v_existing_amount, v_existing_package, v_existing_state, v_existing_lga, v_existing_created_at
    FROM public.orders
    WHERE client_id = v_client_id
      AND (
          customer_phone_normalized = v_customer_phone
          OR customer_phone = v_customer_phone
          OR RIGHT(REGEXP_REPLACE(customer_phone, '\D', '', 'g'), 10) = RIGHT(v_customer_phone, 10)
      )
      AND status IN ('new', 'contacting', 'pending', 'confirmed', 'in_transit', 'rescheduled')
      AND created_at > (NOW() - INTERVAL '48 hours')
    ORDER BY created_at DESC
    LIMIT 1;

    -- If duplicate found, handle idempotently without creating a second fulfillment order
    IF v_existing_order_id IS NOT NULL THEN
        -- Record in customer_leads as duplicate for ad analytics tracking
        INSERT INTO public.customer_leads (
            client_id,
            marketer_id,
            form_id,
            customer_name,
            customer_phone,
            customer_phone_normalized,
            customer_address,
            delivery_state,
            delivery_lga,
            product_interest,
            package_interest,
            status,
            call_notes,
            utm_source,
            utm_medium,
            utm_campaign,
            ad_id,
            created_at,
            updated_at
        ) VALUES (
            v_client_id,
            v_marketer_id,
            v_form_id,
            v_customer_name,
            v_raw_customer_phone,
            v_customer_phone,
            v_delivery_address,
            v_delivery_state,
            v_delivery_lga,
            v_product_name,
            v_package_name,
            'duplicate_submission',
            'Duplicate form submission. Re-used existing active order #' || v_existing_order_number,
            v_utm_source,
            v_utm_medium,
            v_utm_campaign,
            v_ad_id,
            NOW(),
            NOW()
        );

        -- Append system note to existing order
        UPDATE public.orders
        SET delivery_notes = COALESCE(delivery_notes, '') || E'\n[SYSTEM] Repeat ad form submission from ' || COALESCE(v_utm_source, 'ad') || ' on ' || TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI') || '. Kept single order to avoid double delivery.',
            updated_at = NOW()
        WHERE id = v_existing_order_id;

        -- Prepare redirect URL
        v_final_redirect := v_redirect_url;
        IF v_final_redirect IS NOT NULL AND v_final_redirect != '' THEN
            IF POSITION('?' IN v_final_redirect) > 0 THEN
                v_final_redirect := v_final_redirect || '&order_id=' || v_existing_order_id::TEXT || '&order_number=' || v_existing_order_number || '&is_duplicate=true';
            ELSE
                v_final_redirect := v_final_redirect || '?order_id=' || v_existing_order_id::TEXT || '&order_number=' || v_existing_order_number || '&is_duplicate=true';
            END IF;
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'is_duplicate', true,
            'order_id', v_existing_order_id,
            'order_number', v_existing_order_number,
            'status', v_existing_status,
            'message', 'We have already received your order (#' || v_existing_order_number || ')! Our confirmation agent will contact you shortly.',
            'package_deal_name', COALESCE(v_existing_package, v_package_name),
            'total_amount', v_existing_amount,
            'delivery_state', v_existing_state,
            'delivery_lga', v_existing_lga,
            'redirect_url', v_final_redirect
        );
    END IF;

    -- Lookup Product SKU and base price if not supplied
    IF v_product_id IS NOT NULL THEN
        SELECT sku, price INTO v_product_sku, v_product_price
        FROM public.products
        WHERE id = v_product_id;
    END IF;

    IF v_total_amount <= 0 AND v_product_price IS NOT NULL THEN
        v_total_amount := v_product_price * v_buy_qty;
    END IF;

    -- Generate unique human-readable order number
    v_order_number := 'ORD-MK-' || TO_CHAR(NOW(), 'YYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');

    -- 1. Create Lead in customer_leads table
    INSERT INTO public.customer_leads (
        client_id,
        marketer_id,
        form_id,
        customer_name,
        customer_phone,
        customer_phone_normalized,
        customer_address,
        delivery_state,
        delivery_lga,
        product_interest,
        package_interest,
        status,
        call_notes,
        utm_source,
        utm_medium,
        utm_campaign,
        ad_id,
        created_at,
        updated_at
    ) VALUES (
        v_client_id,
        v_marketer_id,
        v_form_id,
        v_customer_name,
        v_raw_customer_phone,
        v_customer_phone,
        v_delivery_address,
        v_delivery_state,
        v_delivery_lga,
        v_product_name,
        v_package_name,
        'new_lead',
        CASE WHEN v_notes != '' THEN 'Customer Note: ' || v_notes ELSE 'Marketing Landing Page Lead' END,
        v_utm_source,
        v_utm_medium,
        v_utm_campaign,
        v_ad_id,
        NOW(),
        NOW()
    ) RETURNING id INTO v_lead_id;

    -- 2. Create Order in orders table with package deal details, LGA, normalized phone, and pending closer confirmation
    INSERT INTO public.orders (
        order_number,
        client_id,
        product_id,
        product_name,
        product_sku,
        package_deal_name,
        package_deal_id,
        marketer_id,
        marketer_name,
        form_id,
        lead_id,
        customer_name,
        customer_phone,
        customer_phone_normalized,
        customer_alt_phone,
        customer_email,
        delivery_address,
        delivery_state,
        delivery_lga,
        lga,
        delivery_city,
        quantity,
        paid_quantity,
        free_quantity,
        total_amount,
        status,
        assignment_status,
        offer_package_id,
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        ad_id,
        delivery_notes,
        payment_method,
        is_pod,
        created_at,
        updated_at
    ) VALUES (
        v_order_number,
        v_client_id,
        v_product_id,
        v_product_name,
        v_product_sku,
        v_package_name,
        v_package_id,
        v_marketer_id,
        v_marketer_name,
        v_form_id,
        v_lead_id,
        v_customer_name,
        v_customer_phone,
        v_customer_phone,
        v_customer_alt_phone,
        v_customer_email,
        v_delivery_address,
        v_delivery_state,
        v_delivery_lga,
        v_delivery_lga,
        v_delivery_lga,
        v_buy_qty,
        v_paid_qty,
        v_free_qty,
        v_total_amount,
        'new',
        'pending_closer_confirmation',
        v_package_id,
        v_utm_source,
        v_utm_medium,
        v_utm_campaign,
        v_utm_content,
        v_ad_id,
        v_notes,
        'pay_on_delivery',
        true,
        NOW(),
        NOW()
    ) RETURNING id INTO v_order_id;

    -- 3. Execute Automatic Round-Robin Closer Assignment
    BEGIN
        SELECT closer_id, closer_name
        INTO v_assigned_closer_id, v_assigned_closer_name
        FROM public.fn_assign_order_to_product_closer(v_order_id);
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    -- 4. Update Form Statistics
    UPDATE public.lead_forms
    SET total_submissions = total_submissions + 1,
        total_orders_booked = total_orders_booked + 1,
        updated_at = NOW()
    WHERE id = v_form_id;

    -- 5. Update Marketer Aggregate Statistics
    IF v_marketer_id IS NOT NULL THEN
        UPDATE public.client_marketers
        SET total_leads_generated = total_leads_generated + 1,
            total_orders_generated = total_orders_generated + 1,
            updated_at = NOW()
        WHERE id = v_marketer_id;
    END IF;

    -- 6. Build Redirect URL with conversion parameters
    v_final_redirect := v_redirect_url;
    IF v_final_redirect IS NOT NULL AND v_final_redirect != '' THEN
        IF POSITION('?' IN v_final_redirect) > 0 THEN
            v_final_redirect := v_final_redirect || '&order_id=' || v_order_id::TEXT || '&order_number=' || v_order_number || '&amount=' || v_total_amount::TEXT;
        ELSE
            v_final_redirect := v_final_redirect || '?order_id=' || v_order_id::TEXT || '&order_number=' || v_order_number || '&amount=' || v_total_amount::TEXT;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'is_duplicate', false,
        'order_id', v_order_id,
        'order_number', v_order_number,
        'lead_id', v_lead_id,
        'status', 'new',
        'assignment_status', 'pending_closer_confirmation',
        'assigned_closer_id', v_assigned_closer_id,
        'assigned_closer_name', v_assigned_closer_name,
        'package_deal_name', v_package_name,
        'quantity', v_buy_qty,
        'paid_quantity', v_paid_qty,
        'free_quantity', v_free_qty,
        'total_amount', v_total_amount,
        'delivery_state', v_delivery_state,
        'delivery_lga', v_delivery_lga,
        'redirect_url', v_final_redirect
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_normalize_nigerian_phone(TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_submit_marketing_lead_order(JSONB) TO authenticated, service_role, anon;

-- 6. Security & Scoping RLS for order_conversations
-- Marketers can strictly see their own conversations; Supervisors see their own + their supervisees'
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
            LEFT JOIN public.client_marketers cm ON cm.user_id = u.id OR cm.id = u.marketer_id
            WHERE u.id = auth.uid() AND (
                (u.role IN ('client', 'merchant') AND u.client_id::text = order_conversations.client_id::text) OR
                (u.role IN ('dc_manager', 'dc_staff', 'operations') AND u.distribution_center_id::text = order_conversations.distribution_center_id::text) OR
                (da.id::text = order_conversations.delivery_agent_id::text) OR
                (cc.id::text = order_conversations.closer_id::text) OR
                -- Regular Marketer: strictly their own conversations
                (cm.id IS NOT NULL AND cm.is_supervisor = false AND order_conversations.marketer_id = cm.id) OR
                -- Supervisory Marketer: their own conversations + their supervisees' conversations
                (cm.id IS NOT NULL AND cm.is_supervisor = true AND (
                    order_conversations.marketer_id = cm.id OR
                    order_conversations.marketer_id IN (SELECT id FROM public.client_marketers WHERE supervisor_id = cm.id)
                )) OR
                (u.role IN ('super_admin', 'admin'))
            )
        )
    )
);
