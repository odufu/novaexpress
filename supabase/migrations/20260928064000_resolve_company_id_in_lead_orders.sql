-- Migration: Set default on orders.company_id and resolve company_id in fn_submit_marketing_lead_order
-- Ensures all marketing lead orders satisfy company_id not-null constraint seamlessly

ALTER TABLE public.orders ALTER COLUMN company_id SET DEFAULT '11111111-1111-4111-8111-111111111111'::UUID;

CREATE OR REPLACE FUNCTION public.fn_submit_marketing_lead_order(p_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_form_id UUID;
    v_client_id UUID;
    v_company_id UUID;
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
        RAISE EXCEPTION 'Form ID is strictly required to book lead order';
    END IF;

    IF v_customer_phone IS NULL OR LENGTH(v_customer_phone) < 10 THEN
        RAISE EXCEPTION 'A valid Nigerian phone number is required to book order';
    END IF;

    -- Lookup Lead Form attributes
    SELECT 
        client_id,
        marketer_id,
        product_id,
        product_name,
        redirect_url
    INTO 
        v_client_id,
        v_marketer_id,
        v_product_id,
        v_product_name,
        v_redirect_url
    FROM public.lead_forms
    WHERE id = v_form_id;

    IF v_client_id IS NULL THEN
        RAISE EXCEPTION 'Lead form not found or has been disabled';
    END IF;

    -- Lookup Marketer full name if assigned
    IF v_marketer_id IS NOT NULL THEN
        SELECT full_name INTO v_marketer_name
        FROM public.client_marketers
        WHERE id = v_marketer_id;
    END IF;

    -- Resolve company_id for orders table
    BEGIN
        SELECT company_id INTO v_company_id FROM public.clients WHERE id = v_client_id;
    EXCEPTION WHEN OTHERS THEN
        v_company_id := NULL;
    END;
    IF v_company_id IS NULL THEN
        BEGIN
            SELECT id INTO v_company_id FROM public.companies LIMIT 1;
        EXCEPTION WHEN OTHERS THEN
            v_company_id := NULL;
        END;
    END IF;
    IF v_company_id IS NULL THEN
        v_company_id := '11111111-1111-4111-8111-111111111111'::UUID;
    END IF;

    -- =========================================================================
    -- CANONICAL DUPLICATE DETECTION ACROSS NORMALIZED PHONE NUMBERS
    -- =========================================================================
    SELECT 
        id, 
        order_number, 
        status, 
        total_amount, 
        package_deal_name, 
        delivery_state, 
        delivery_lga,
        created_at
    INTO 
        v_existing_order_id, 
        v_existing_order_number, 
        v_existing_status, 
        v_existing_amount, 
        v_existing_package, 
        v_existing_state, 
        v_existing_lga,
        v_existing_created_at
    FROM public.orders
    WHERE client_id = v_client_id
      AND customer_phone_normalized = v_customer_phone
      AND (
          status IN ('new', 'contacting', 'pending', 'confirmed', 'in_transit', 'rescheduled')
          OR created_at >= (NOW() - INTERVAL '48 HOURS')
      )
    ORDER BY created_at DESC
    LIMIT 1;

    -- Construct fallback thank-you redirect URL
    v_final_redirect := COALESCE(NULLIF(v_redirect_url, ''), '/thank-you?order=' || COALESCE(v_existing_order_number, ''));

    IF v_existing_order_id IS NOT NULL THEN
        -- Record audit lead entry in customer_leads noting duplicate submission
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
            'Duplicate form submission prevented for active order #' || v_existing_order_number || ' (Phone: ' || v_customer_phone || ')',
            v_utm_source,
            v_utm_medium,
            v_utm_campaign,
            v_ad_id,
            NOW(),
            NOW()
        );

        -- Append duplicate note to existing order's notes
        UPDATE public.orders
        SET delivery_notes = COALESCE(delivery_notes, '') || ' [Duplicate Form Submission on ' || TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI') || ' UTC]'
        WHERE id = v_existing_order_id;

        -- Return duplicate acknowledgment referencing the original active order
        RETURN jsonb_build_object(
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

    -- Lookup Product SKU and base price if not supplied (base_price column)
    IF v_product_id IS NOT NULL THEN
        SELECT sku, base_price INTO v_product_sku, v_product_price
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

    -- 2. Create Order in orders table with company_id, package deal details, LGA, normalized phone, and pending closer confirmation
    INSERT INTO public.orders (
        order_number,
        client_id,
        company_id,
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
        v_company_id,
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

    -- 6. Link Customer Lead to Order
    UPDATE public.customer_leads
    SET order_id = v_order_id,
        converted_to_order = true,
        status = 'order_created',
        updated_at = NOW()
    WHERE id = v_lead_id;

    -- 7. Return Result Payload
    RETURN jsonb_build_object(
        'is_duplicate', false,
        'order_id', v_order_id,
        'lead_id', v_lead_id,
        'order_number', v_order_number,
        'status', 'new',
        'customer_name', v_customer_name,
        'customer_phone', v_customer_phone,
        'package_deal_name', v_package_name,
        'quantity', v_buy_qty,
        'paid_quantity', v_paid_qty,
        'free_quantity', v_free_qty,
        'total_amount', v_total_amount,
        'delivery_state', v_delivery_state,
        'delivery_lga', v_delivery_lga,
        'closer_assigned', v_assigned_closer_name,
        'redirect_url', v_final_redirect,
        'message', 'Order successfully booked from marketing form'
    );
END;
$$;
