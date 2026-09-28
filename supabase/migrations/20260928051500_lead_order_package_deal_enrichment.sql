-- Migration: 20260928051500_lead_order_package_deal_enrichment.sql
-- Description:
-- 1. Ensure paid_quantity, free_quantity, package_deal_name, package_deal_id exist on orders
-- 2. Upgrade fn_submit_marketing_lead_order to store paid_quantity, free_quantity, package_deal_name, and package_deal_id

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS paid_quantity INT DEFAULT 1,
  ADD COLUMN IF NOT EXISTS free_quantity INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS package_deal_name VARCHAR(255),
  ADD COLUMN IF NOT EXISTS package_deal_id TEXT;

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

    -- 1. Create Lead in marketing_leads table
    INSERT INTO public.marketing_leads (
        client_id,
        marketer_id,
        form_id,
        customer_name,
        customer_phone,
        delivery_address,
        delivery_state,
        delivery_lga,
        product_name,
        package_selected,
        lead_status,
        notes,
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

    -- 2. Create Order in orders table with package deal details, LGA, and pending closer confirmation
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

GRANT EXECUTE ON FUNCTION public.fn_submit_marketing_lead_order(JSONB) TO authenticated, service_role, anon;
