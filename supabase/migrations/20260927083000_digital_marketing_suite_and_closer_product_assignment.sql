-- ============================================================================
-- Migration: 20260927083000_digital_marketing_suite_and_closer_product_assignment.sql
-- Description: Digital Marketer Accounts, Lead Forms, Landing Page Order Ingestion,
--              Closer Product Attachment, and Balanced Split Round-Robin Assignment.
-- ============================================================================

-- 1. Extend client_closers with assigned products array
ALTER TABLE public.client_closers
  ADD COLUMN IF NOT EXISTS assigned_product_ids UUID[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS assigned_product_names TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS last_assigned_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_client_closers_assigned_products 
  ON public.client_closers USING GIN (assigned_product_ids);

-- 2. Create client_marketers table
CREATE TABLE IF NOT EXISTS public.client_marketers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  marketer_code TEXT NOT NULL UNIQUE,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  is_active BOOLEAN DEFAULT true,
  daily_ad_spend_budget NUMERIC(14,2) DEFAULT 0.00,
  commission_rate NUMERIC(12,2) DEFAULT 0.00,
  is_commission_enabled BOOLEAN DEFAULT false,
  bank_name TEXT DEFAULT '',
  account_number TEXT DEFAULT '',
  account_name TEXT DEFAULT '',
  avatar_url TEXT,
  total_leads_generated INT DEFAULT 0,
  total_orders_generated INT DEFAULT 0,
  total_orders_delivered INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_client_marketers_client_id ON public.client_marketers(client_id);
CREATE INDEX IF NOT EXISTS idx_client_marketers_user_id ON public.client_marketers(user_id);
CREATE INDEX IF NOT EXISTS idx_client_marketers_marketer_code ON public.client_marketers(marketer_code);

-- 3. Create lead_forms table
CREATE TABLE IF NOT EXISTS public.lead_forms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  marketer_id UUID REFERENCES public.client_marketers(id) ON DELETE SET NULL,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  product_name TEXT NOT NULL,
  form_title TEXT NOT NULL,
  form_slug TEXT UNIQUE,
  description TEXT DEFAULT '',
  packages JSONB NOT NULL DEFAULT '[]'::jsonb,
  redirect_url TEXT NOT NULL DEFAULT '',
  pixel_id TEXT DEFAULT '',
  capi_token TEXT DEFAULT '',
  test_event_code TEXT DEFAULT '',
  field_options JSONB NOT NULL DEFAULT '{"require_email": false, "require_alt_phone": false, "require_city": false, "require_notes": false}'::jsonb,
  appearance JSONB NOT NULL DEFAULT '{"primary_color": "#F37021", "button_text": "Complete Order Now", "badge_text": "Pay On Delivery + Fast Delivery"}'::jsonb,
  is_active BOOLEAN DEFAULT true,
  total_views INT DEFAULT 0,
  total_submissions INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure all required columns exist in case lead_forms pre-existed
ALTER TABLE public.lead_forms
  ADD COLUMN IF NOT EXISTS client_id UUID REFERENCES public.clients(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS marketer_id UUID REFERENCES public.client_marketers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS product_name TEXT,
  ADD COLUMN IF NOT EXISTS form_title TEXT,
  ADD COLUMN IF NOT EXISTS form_slug TEXT,
  ADD COLUMN IF NOT EXISTS description TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS packages JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS redirect_url TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS pixel_id TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS capi_token TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS test_event_code TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS field_options JSONB DEFAULT '{"require_email": false, "require_alt_phone": false, "require_city": false, "require_notes": false}'::jsonb,
  ADD COLUMN IF NOT EXISTS appearance JSONB DEFAULT '{"primary_color": "#F37021", "button_text": "Complete Order Now", "badge_text": "Pay On Delivery + Fast Delivery"}'::jsonb,
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS total_views INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_submissions INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_lead_forms_client_id ON public.lead_forms(client_id);
CREATE INDEX IF NOT EXISTS idx_lead_forms_marketer_id ON public.lead_forms(marketer_id);
CREATE INDEX IF NOT EXISTS idx_lead_forms_product_id ON public.lead_forms(product_id);
CREATE INDEX IF NOT EXISTS idx_lead_forms_form_slug ON public.lead_forms(form_slug);

-- 4. Extend orders and customer_leads with marketing attribution columns
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS marketer_id UUID REFERENCES public.client_marketers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS marketer_name TEXT,
  ADD COLUMN IF NOT EXISTS form_id UUID REFERENCES public.lead_forms(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS offer_package_id TEXT,
  ADD COLUMN IF NOT EXISTS utm_source TEXT,
  ADD COLUMN IF NOT EXISTS utm_medium TEXT,
  ADD COLUMN IF NOT EXISTS utm_campaign TEXT,
  ADD COLUMN IF NOT EXISTS utm_content TEXT,
  ADD COLUMN IF NOT EXISTS ad_id TEXT;

CREATE INDEX IF NOT EXISTS idx_orders_marketer_id ON public.orders(marketer_id);
CREATE INDEX IF NOT EXISTS idx_orders_form_id ON public.orders(form_id);

ALTER TABLE public.customer_leads
  ADD COLUMN IF NOT EXISTS marketer_id UUID REFERENCES public.client_marketers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS form_id UUID REFERENCES public.lead_forms(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS utm_source TEXT,
  ADD COLUMN IF NOT EXISTS utm_campaign TEXT,
  ADD COLUMN IF NOT EXISTS utm_medium TEXT,
  ADD COLUMN IF NOT EXISTS ad_id TEXT;

CREATE INDEX IF NOT EXISTS idx_customer_leads_marketer_id ON public.customer_leads(marketer_id);
CREATE INDEX IF NOT EXISTS idx_customer_leads_form_id ON public.customer_leads(form_id);

-- 5. Stored Procedure: Balanced Split Round-Robin Assignment to Closers Attached to Product
CREATE OR REPLACE FUNCTION public.fn_assign_order_round_robin(
    p_order_id UUID,
    p_product_id UUID,
    p_client_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_closer_id UUID;
    v_closer_name TEXT;
    v_closer_code TEXT;
BEGIN
    -- 1. Try finding an active closer explicitly assigned to this product for this client
    -- Balanced Split logic: pick active closer with lowest pending/active orders, tie-breaking by last_assigned_at ASC
    SELECT c.id, c.full_name, c.closer_code
    INTO v_closer_id, v_closer_name, v_closer_code
    FROM public.client_closers c
    LEFT JOIN public.orders o ON o.closer_id = c.id AND o.status IN ('new', 'contacting', 'pending', 'confirmed')
    WHERE c.client_id = p_client_id
      AND c.is_active = true
      AND (p_product_id = ANY(c.assigned_product_ids) OR array_length(c.assigned_product_ids, 1) IS NULL OR array_length(c.assigned_product_ids, 1) = 0)
    GROUP BY c.id, c.full_name, c.closer_code, c.last_assigned_at
    ORDER BY COUNT(o.id) ASC, c.last_assigned_at ASC NULLS FIRST, c.created_at ASC
    LIMIT 1
    FOR UPDATE OF c SKIP LOCKED;

    -- 2. Fallback: If no closer is attached to this product, assign to ANY active closer under this client
    IF v_closer_id IS NULL THEN
        SELECT c.id, c.full_name, c.closer_code
        INTO v_closer_id, v_closer_name, v_closer_code
        FROM public.client_closers c
        LEFT JOIN public.orders o ON o.closer_id = c.id AND o.status IN ('new', 'contacting', 'pending', 'confirmed')
        WHERE c.client_id = p_client_id
          AND c.is_active = true
        GROUP BY c.id, c.full_name, c.closer_code, c.last_assigned_at
        ORDER BY COUNT(o.id) ASC, c.last_assigned_at ASC NULLS FIRST, c.created_at ASC
        LIMIT 1
        FOR UPDATE OF c SKIP LOCKED;
    END IF;

    -- 3. If an eligible closer was resolved, assign them to the order & update stats
    IF v_closer_id IS NOT NULL THEN
        UPDATE public.orders
        SET closer_id = v_closer_id,
            closer_name = v_closer_name,
            closer_code = v_closer_code,
            updated_at = NOW()
        WHERE id = p_order_id;

        -- Also link closer to corresponding customer_leads if exists
        UPDATE public.customer_leads
        SET assigned_closer_id = v_closer_id,
            updated_at = NOW()
        WHERE converted_order_id = p_order_id::text
           OR id = (SELECT lead_id FROM public.orders WHERE id = p_order_id);

        -- Update closer's assigned counter & rotation timestamp
        UPDATE public.client_closers
        SET total_leads_assigned = COALESCE(total_leads_assigned, 0) + 1,
            last_assigned_at = NOW(),
            updated_at = NOW()
        WHERE id = v_closer_id;
    END IF;

    RETURN v_closer_id;
END;
$$;

-- 6. Stored Procedure: Public Marketing Lead Order Ingestion
CREATE OR REPLACE FUNCTION public.fn_submit_marketing_lead_order(
    p_payload JSONB
)
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
    v_customer_phone TEXT;
    v_customer_alt_phone TEXT;
    v_customer_email TEXT;
    v_delivery_address TEXT;
    v_delivery_state TEXT;
    v_delivery_city TEXT;
    v_notes TEXT;
    v_package_id TEXT;
    v_package_name TEXT;
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
    v_clean_phone TEXT;
    v_final_redirect TEXT;
BEGIN
    -- Parse & Sanitize Inputs
    v_form_id := (p_payload->>'form_id')::UUID;
    v_customer_name := TRIM(COALESCE(p_payload->>'customer_name', 'Valued Customer'));
    v_customer_phone := TRIM(COALESCE(p_payload->>'customer_phone', ''));
    v_customer_alt_phone := TRIM(COALESCE(p_payload->>'customer_alt_phone', ''));
    v_customer_email := TRIM(COALESCE(p_payload->>'customer_email', ''));
    v_delivery_address := TRIM(COALESCE(p_payload->>'delivery_address', ''));
    v_delivery_state := TRIM(COALESCE(p_payload->>'delivery_state', 'Lagos'));
    v_delivery_city := TRIM(COALESCE(p_payload->>'delivery_city', ''));
    v_notes := TRIM(COALESCE(p_payload->>'notes', ''));
    v_package_id := COALESCE(p_payload->>'package_id', 'pkg-1');
    v_package_name := COALESCE(p_payload->>'package_name', 'Standard Package');
    v_buy_qty := COALESCE((p_payload->>'buy_qty')::INT, 1);
    v_total_amount := COALESCE((p_payload->>'total_amount')::NUMERIC, 0.00);

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

    -- Lookup Product SKU and base price if not supplied
    SELECT sku, price
    INTO v_product_sku, v_product_price
    FROM public.products
    WHERE id = v_product_id;

    IF v_total_amount <= 0 THEN
        v_total_amount := COALESCE(v_product_price, 25000.00) * v_buy_qty;
    END IF;

    -- Generate Clean Order Number: ORD-MK-YYMMDD-XXXX
    v_order_number := 'ORD-MK-' || TO_CHAR(NOW(), 'YYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');

    -- 1. Create Lead in customer_leads
    INSERT INTO public.customer_leads (
        client_id,
        marketer_id,
        form_id,
        customer_name,
        customer_phone,
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
        v_customer_phone,
        v_delivery_address,
        v_delivery_state,
        COALESCE(v_delivery_city, 'AMAC'),
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

    -- 2. Create Order in orders table
    INSERT INTO public.orders (
        order_number,
        client_id,
        product_id,
        product_name,
        product_sku,
        marketer_id,
        marketer_name,
        form_id,
        lead_id,
        customer_name,
        customer_phone,
        customer_alt_phone,
        customer_email,
        delivery_address,
        delivery_state,
        delivery_city,
        quantity,
        total_amount,
        status,
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
        v_marketer_id,
        v_marketer_name,
        v_form_id,
        v_lead_id,
        v_customer_name,
        v_customer_phone,
        v_customer_alt_phone,
        v_customer_email,
        v_delivery_address,
        v_delivery_state,
        v_delivery_city,
        v_buy_qty,
        v_total_amount,
        'new',
        v_package_id,
        v_utm_source,
        v_utm_medium,
        v_utm_campaign,
        v_utm_content,
        v_ad_id,
        CASE WHEN v_notes != '' THEN 'Marketing Lead: ' || v_notes ELSE 'Marketing Landing Page Order' END,
        'cash_on_delivery',
        true,
        NOW(),
        NOW()
    ) RETURNING id INTO v_order_id;

    -- Link converted order to lead
    UPDATE public.customer_leads
    SET converted_order_id = v_order_id::text
    WHERE id = v_lead_id;

    -- 3. Execute Balanced Split Round-Robin Assignment to Closer
    v_assigned_closer_id := public.fn_assign_order_round_robin(v_order_id, v_product_id, v_client_id);
    
    IF v_assigned_closer_id IS NOT NULL THEN
        SELECT full_name INTO v_assigned_closer_name FROM public.client_closers WHERE id = v_assigned_closer_id;
    END IF;

    -- 4. Increment Form and Marketer submission counters
    UPDATE public.lead_forms
    SET total_submissions = COALESCE(total_submissions, 0) + 1,
        updated_at = NOW()
    WHERE id = v_form_id;

    IF v_marketer_id IS NOT NULL THEN
        UPDATE public.client_marketers
        SET total_orders_generated = COALESCE(total_orders_generated, 0) + 1,
            total_leads_generated = COALESCE(total_leads_generated, 0) + 1,
            updated_at = NOW()
        WHERE id = v_marketer_id;
    END IF;

    -- 5. Format Thank You Redirect URL
    IF v_redirect_url IS NOT NULL AND v_redirect_url != '' THEN
        v_final_redirect := v_redirect_url || (CASE WHEN v_redirect_url LIKE '%?%' THEN '&' ELSE '?' END) ||
            'order_id=' || v_order_id::text ||
            '&order_number=' || v_order_number ||
            '&amount=' || v_total_amount::text ||
            '&event_id=CAPI_ORD_' || REPLACE(v_order_number, '-', '_');
    ELSE
        v_final_redirect := '';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'order_id', v_order_id,
        'order_number', v_order_number,
        'lead_id', v_lead_id,
        'assigned_closer_id', v_assigned_closer_id,
        'assigned_closer_name', v_assigned_closer_name,
        'redirect_url', v_final_redirect,
        'total_amount', v_total_amount,
        'event_id', 'CAPI_ORD_' || REPLACE(v_order_number, '-', '_')
    );
END;
$$;

-- 7. Add client_marketers and lead_forms to Realtime Publication
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.client_marketers;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.lead_forms;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- 8. Enable Row Level Security (RLS) & Grant Access
ALTER TABLE public.client_marketers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lead_forms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read on active lead_forms"
    ON public.lead_forms FOR SELECT
    USING (is_active = true);

CREATE POLICY "Allow full access for service_role and authenticated users on lead_forms"
    ON public.lead_forms FOR ALL
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Allow full access on client_marketers"
    ON public.client_marketers FOR ALL
    USING (true)
    WITH CHECK (true);

-- Grant execute on stored procedures
GRANT EXECUTE ON FUNCTION public.fn_assign_order_round_robin(UUID, UUID, UUID) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_submit_marketing_lead_order(JSONB) TO anon, authenticated, service_role;
