-- ============================================================================
-- Migration: 20260927091500_closer_confirmation_and_lga_dispatch.sql
-- Description: 
--   1. Ensures delivery_lga and lga columns are explicitly populated on order creation.
--   2. Prevents premature auto-dispatch for orders awaiting closer confirmation.
--   3. Adds fn_confirm_closer_order stored procedure to confirm order, update State/LGA,
--      and trigger automatic DC & Rider matching via auto_dispatch_order_by_state_lga.
--   4. Adds update trigger on orders.status to auto-dispatch on confirmation.
-- ============================================================================

-- 1. Ensure columns exist on orders table
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS delivery_lga TEXT,
  ADD COLUMN IF NOT EXISTS lga TEXT;

-- 2. Enhanced fn_submit_marketing_lead_order with explicit State & LGA storage
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
    v_delivery_lga TEXT;
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
    -- Harmonize LGA / City to canonical LGA
    v_delivery_lga := TRIM(COALESCE(p_payload->>'delivery_lga', p_payload->>'lga', p_payload->>'delivery_city', 'Ikeja'));
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

    -- 2. Create Order in orders table with status 'new' and explicit LGA
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
        delivery_lga,
        lga,
        delivery_city,
        quantity,
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
        v_delivery_lga,
        v_delivery_lga,
        v_delivery_lga,
        v_buy_qty,
        v_total_amount,
        'new',
        'pending_closer_confirmation',
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

-- 3. Refine Auto-Dispatch Trigger: Do NOT auto-dispatch orders awaiting closer confirmation
CREATE OR REPLACE FUNCTION public.trg_orders_auto_dispatch()
RETURNS TRIGGER AS $$
BEGIN
  -- If order has a closer and is awaiting confirmation ('new', 'unconfirmed', 'contacting'), DO NOT dispatch yet
  IF NEW.closer_id IS NOT NULL AND (NEW.status = 'new' OR NEW.status = 'unconfirmed' OR NEW.status = 'contacting') THEN
    RETURN NEW;
  END IF;

  -- Auto-dispatch if no delivery agent is assigned and status is confirmed or pending dispatch
  IF COALESCE(NEW.delivery_agent_id, NEW.assigned_agent_id) IS NULL 
     AND (
       NEW.status = 'confirmed' 
       OR NEW.status = 'pending_dispatch'
       OR (NEW.closer_id IS NULL AND (NEW.status = 'pending' OR NEW.status = 'new' OR NEW.status IS NULL))
     ) THEN
    PERFORM public.auto_dispatch_order_by_state_lga(NEW.id);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_orders_auto_dispatch_after_insert ON orders;
CREATE TRIGGER trg_orders_auto_dispatch_after_insert
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_orders_auto_dispatch();

DROP TRIGGER IF EXISTS trg_orders_auto_dispatch_after_update ON orders;
CREATE TRIGGER trg_orders_auto_dispatch_after_update
  AFTER UPDATE OF status ON orders
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('confirmed', 'pending_dispatch'))
  EXECUTE FUNCTION public.trg_orders_auto_dispatch();

-- 4. Stored Procedure: Closer Order Confirmation & Instant DC/Rider Dispatch
CREATE OR REPLACE FUNCTION public.fn_confirm_closer_order(
    p_order_id UUID,
    p_closer_id UUID,
    p_delivery_address TEXT DEFAULT NULL,
    p_delivery_state TEXT DEFAULT NULL,
    p_delivery_lga TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_order RECORD;
    v_dispatch_result JSONB;
    v_matched_dc_id UUID;
    v_matched_dc_name TEXT;
    v_assigned_agent_id UUID;
    v_assigned_agent_name TEXT;
    v_assigned_agent_phone TEXT;
    v_assigned_agent_code TEXT;
BEGIN
    -- 1. Fetch Order and verify existence
    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Order not found');
    END IF;

    -- 2. Update order address, state, and LGA details if updated during phone confirmation
    UPDATE public.orders
    SET 
        delivery_address = COALESCE(NULLIF(TRIM(p_delivery_address), ''), delivery_address),
        delivery_state = COALESCE(NULLIF(TRIM(p_delivery_state), ''), delivery_state),
        delivery_lga = COALESCE(NULLIF(TRIM(p_delivery_lga), ''), delivery_lga),
        lga = COALESCE(NULLIF(TRIM(p_delivery_lga), ''), lga, delivery_lga),
        delivery_city = COALESCE(NULLIF(TRIM(p_delivery_lga), ''), delivery_city, delivery_lga),
        delivery_notes = CASE 
            WHEN p_notes IS NOT NULL AND TRIM(p_notes) <> '' 
            THEN COALESCE(delivery_notes || E'\n[Closer Confirmation]: ' || TRIM(p_notes), '[Closer Confirmation]: ' || TRIM(p_notes))
            ELSE delivery_notes
        END,
        status = 'confirmed',
        updated_at = NOW()
    WHERE id = p_order_id;

    -- 3. Execute automatic State/LGA DC and Rider matching
    v_dispatch_result := public.auto_dispatch_order_by_state_lga(p_order_id);

    -- Fetch refreshed order routing state
    SELECT 
        o.distribution_center_id,
        dc.name AS dc_name,
        o.delivery_agent_id,
        da.name AS agent_name,
        da.phone AS agent_phone,
        da.agent_code
    INTO 
        v_matched_dc_id,
        v_matched_dc_name,
        v_assigned_agent_id,
        v_assigned_agent_name,
        v_assigned_agent_phone,
        v_assigned_agent_code
    FROM public.orders o
    LEFT JOIN public.distribution_centers dc ON dc.id = o.distribution_center_id
    LEFT JOIN public.delivery_agents da ON da.id = o.delivery_agent_id
    WHERE o.id = p_order_id;

    -- 4. Update Closer performance stats
    IF p_closer_id IS NOT NULL THEN
        UPDATE public.client_closers
        SET total_orders_booked = COALESCE(total_orders_booked, 0) + 1,
            total_leads_confirmed = COALESCE(total_leads_confirmed, 0) + 1,
            updated_at = NOW()
        WHERE id = p_closer_id;
    END IF;

    -- 5. Update linked customer_lead if exists
    IF v_order.lead_id IS NOT NULL THEN
        UPDATE public.customer_leads
        SET status = 'order_confirmed',
            call_notes = CASE 
                WHEN p_notes IS NOT NULL AND TRIM(p_notes) <> '' 
                THEN COALESCE(call_notes || E'\n[Confirmation]: ' || TRIM(p_notes), '[Confirmation]: ' || TRIM(p_notes))
                ELSE call_notes
            END,
            last_called_at = NOW(),
            updated_at = NOW()
        WHERE id = v_order.lead_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'order_number', v_order.order_number,
        'status', 'confirmed',
        'distribution_center_id', v_matched_dc_id,
        'distribution_center_name', v_matched_dc_name,
        'delivery_agent_id', v_assigned_agent_id,
        'delivery_agent_name', v_assigned_agent_name,
        'delivery_agent_phone', v_assigned_agent_phone,
        'delivery_agent_code', v_assigned_agent_code,
        'dispatch_result', v_dispatch_result
    );
END;
$$;

-- 5. Grants
GRANT EXECUTE ON FUNCTION public.fn_confirm_closer_order(UUID, UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_submit_marketing_lead_order(JSONB) TO authenticated, service_role, anon;

NOTIFY pgrst, 'reload schema';
