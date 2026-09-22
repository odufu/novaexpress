-- Migration: 20260920210000_manual_client_settlement_receipt_and_approval.sql
-- Description: Hardens manual client settlement flow, adds receipt attachment support,
-- fixes fn_generate_merchant_daily_settlement schema mapping bugs, and adds fn_merchant_approve_settlement.

-- 1. Ensure client_settlements columns exist
ALTER TABLE IF EXISTS public.client_settlements
    ADD COLUMN IF NOT EXISTS proof_of_payment_url TEXT,
    ADD COLUMN IF NOT EXISTS payout_reference TEXT,
    ADD COLUMN IF NOT EXISTS notes TEXT,
    ADD COLUMN IF NOT EXISTS distribution_center_id UUID REFERENCES public.distribution_centers(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS platform_fees_deducted NUMERIC(14, 2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS gateway_fees_deducted NUMERIC(14, 2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS failed_attempt_fees_deducted NUMERIC(14, 2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS other_charges_deducted NUMERIC(14, 2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS charges_breakdown JSONB DEFAULT '{}'::jsonb;

-- Ensure default status is 'remitted' for pending merchant verification
ALTER TABLE IF EXISTS public.client_settlements
    ALTER COLUMN status SET DEFAULT 'remitted';

-- 2. Drop legacy function signatures to prevent signature collision
DROP FUNCTION IF EXISTS public.fn_generate_merchant_daily_settlement(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, JSONB, UUID[]);
DROP FUNCTION IF EXISTS public.fn_generate_merchant_daily_settlement(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, JSONB);
DROP FUNCTION IF EXISTS public.fn_generate_merchant_daily_settlement(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, JSONB, UUID[], TEXT, TEXT, TEXT);

-- 3. Stored Procedure: fn_generate_merchant_daily_settlement (Full 9-parameter version)
CREATE OR REPLACE FUNCTION public.fn_generate_merchant_daily_settlement(
    p_client_id UUID,
    p_dc_id UUID DEFAULT NULL,
    p_period_start TIMESTAMPTZ DEFAULT NULL,
    p_period_end TIMESTAMPTZ DEFAULT NULL,
    p_custom_deductions JSONB DEFAULT '{}'::jsonb,
    p_order_ids UUID[] DEFAULT NULL,
    p_proof_of_payment_url TEXT DEFAULT NULL,
    p_payout_reference TEXT DEFAULT NULL,
    p_status TEXT DEFAULT 'remitted'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_settlement_id UUID := gen_random_uuid();
    v_settlement_number TEXT;
    v_today_seq INT;
    v_client RECORD;
    v_dc_settings RECORD;
    
    -- Calculated Totals
    v_orders_count INT := 0;
    v_gross_collections NUMERIC(14, 2) := 0.00;
    v_delivery_fees NUMERIC(14, 2) := 0.00;
    v_failed_attempt_fees NUMERIC(14, 2) := 0.00;
    v_system_operation_fees NUMERIC(14, 2) := 0.00;
    v_gateway_fees NUMERIC(14, 2) := 0.00;
    v_other_charges NUMERIC(14, 2) := 0.00;
    v_total_platform_charges NUMERIC(14, 2) := 0.00;
    v_total_deductions NUMERIC(14, 2) := 0.00;
    v_net_payout NUMERIC(14, 2) := 0.00;
    
    -- Rates & intermediate vars
    v_order_delivery_fee NUMERIC(14, 2);
    v_order_platform_fee NUMERIC(14, 2);
    v_order_gateway_fee NUMERIC(14, 2);
    v_unit_failed_fee NUMERIC(14, 2);
    v_failed_orders_count INT := 0;
    v_charges_breakdown JSONB;
    
    v_order RECORD;
    v_order_ids_array UUID[] := '{}';
    v_eff_period_start TIMESTAMPTZ;
    v_eff_period_end TIMESTAMPTZ;
BEGIN
    -- Effective period boundaries (Default: Past 60 days up to current timestamp)
    v_eff_period_start := COALESCE(p_period_start, date_trunc('day', NOW()) - INTERVAL '60 days');
    v_eff_period_end   := COALESCE(p_period_end,   NOW());

    -- Load Client Info (using to_jsonb for schema-safe access to optional columns)
    SELECT id, name, company_name, custom_delivery_fee, custom_failed_attempt_fee, 
           custom_platform_fee, bank_name, account_number, account_name,
           to_jsonb(c) AS raw_json
    INTO v_client
    FROM public.clients c
    WHERE id = p_client_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Client not found');
    END IF;

    -- Load DC System Level Config (fallback rates)
    SELECT default_client_delivery_fee, failed_order_charge, 
           platform_fee_type, platform_fee_value, paystack_direct_fee_percent
    INTO v_dc_settings
    FROM public.dc_settings
    ORDER BY created_at ASC
    LIMIT 1;

    -- Step 1: Iterate over Delivered Orders
    IF p_order_ids IS NOT NULL AND array_length(p_order_ids, 1) > 0 THEN
        FOR v_order IN
            SELECT o.id, o.total_amount, o.client_delivery_fee, o.payment_type,
                   COALESCE(o.payment_method, o.delivery_method, 'cash') AS eff_method
            FROM public.orders o
            WHERE (o.client_id = p_client_id OR o.merchant_id = p_client_id)
              AND o.id = ANY(p_order_ids)
              AND o.status = 'delivered'
              AND (o.financial_settlement_status IS NULL OR o.financial_settlement_status != 'client_settled')
        LOOP
            v_order_ids_array := array_append(v_order_ids_array, v_order.id);
            v_orders_count := v_orders_count + 1;
            v_gross_collections := v_gross_collections + COALESCE(v_order.total_amount, 0.00);

            v_order_delivery_fee := COALESCE(v_client.custom_delivery_fee, v_order.client_delivery_fee, v_dc_settings.default_client_delivery_fee, 5000.00);
            v_delivery_fees := v_delivery_fees + v_order_delivery_fee;

            IF COALESCE(v_client.raw_json->>'custom_platform_fee_type', 'flat') = 'percentage' THEN
                v_order_platform_fee := COALESCE(v_order.total_amount, 0.00) * (COALESCE((v_client.raw_json->>'custom_platform_fee_value')::numeric, v_client.custom_platform_fee, 2.5) / 100.0);
            ELSE
                v_order_platform_fee := COALESCE((v_client.raw_json->>'custom_platform_fee_value')::numeric, v_client.custom_platform_fee, v_dc_settings.platform_fee_value, 500.00);
            END IF;
            v_system_operation_fees := v_system_operation_fees + v_order_platform_fee;

            IF LOWER(v_order.eff_method) = 'direct_transfer' OR LOWER(COALESCE(v_order.payment_type, '')) = 'direct_transfer' THEN
                v_order_gateway_fee := LEAST(2000.00, COALESCE(v_order.total_amount, 0.00) * (COALESCE(v_dc_settings.paystack_direct_fee_percent, 1.5) / 100.0));
                v_gateway_fees := v_gateway_fees + v_order_gateway_fee;
            END IF;
        END LOOP;
    ELSE
        FOR v_order IN
            SELECT o.id, o.total_amount, o.client_delivery_fee, o.payment_type,
                   COALESCE(o.payment_method, o.delivery_method, 'cash') AS eff_method
            FROM public.orders o
            WHERE (o.client_id = p_client_id OR o.merchant_id = p_client_id)
              AND (p_dc_id IS NULL OR o.distribution_center_id = p_dc_id)
              AND o.status = 'delivered'
              AND (o.financial_settlement_status IS NULL OR o.financial_settlement_status != 'client_settled')
              AND (o.delivered_at >= v_eff_period_start AND o.delivered_at <= v_eff_period_end)
        LOOP
            v_order_ids_array := array_append(v_order_ids_array, v_order.id);
            v_orders_count := v_orders_count + 1;
            v_gross_collections := v_gross_collections + COALESCE(v_order.total_amount, 0.00);

            v_order_delivery_fee := COALESCE(v_client.custom_delivery_fee, v_order.client_delivery_fee, v_dc_settings.default_client_delivery_fee, 5000.00);
            v_delivery_fees := v_delivery_fees + v_order_delivery_fee;

            IF COALESCE(v_client.raw_json->>'custom_platform_fee_type', 'flat') = 'percentage' THEN
                v_order_platform_fee := COALESCE(v_order.total_amount, 0.00) * (COALESCE((v_client.raw_json->>'custom_platform_fee_value')::numeric, v_client.custom_platform_fee, 2.5) / 100.0);
            ELSE
                v_order_platform_fee := COALESCE((v_client.raw_json->>'custom_platform_fee_value')::numeric, v_client.custom_platform_fee, v_dc_settings.platform_fee_value, 500.00);
            END IF;
            v_system_operation_fees := v_system_operation_fees + v_order_platform_fee;

            IF LOWER(v_order.eff_method) = 'direct_transfer' OR LOWER(COALESCE(v_order.payment_type, '')) = 'direct_transfer' THEN
                v_order_gateway_fee := LEAST(2000.00, COALESCE(v_order.total_amount, 0.00) * (COALESCE(v_dc_settings.paystack_direct_fee_percent, 1.5) / 100.0));
                v_gateway_fees := v_gateway_fees + v_order_gateway_fee;
            END IF;
        END LOOP;
    END IF;

    -- Zero-Order Guard
    IF v_orders_count = 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'No eligible delivered orders found for settlement',
            'orders_settled', 0,
            'gross_collections', 0.00,
            'net_payout', 0.00
        );
    END IF;

    -- Charge 2: Failed Delivery Attempt Surcharges
    v_unit_failed_fee := COALESCE(v_client.custom_failed_attempt_fee, v_dc_settings.failed_order_charge, 1000.00);
    SELECT COUNT(*) INTO v_failed_orders_count
    FROM public.orders
    WHERE (client_id = p_client_id OR merchant_id = p_client_id)
      AND status IN ('failed', 'cancelled', 'rejected', 'customer_rejected')
      AND (v_eff_period_start IS NULL OR (COALESCE(delivered_at, created_at) >= v_eff_period_start))
      AND (COALESCE(delivered_at, created_at) <= v_eff_period_end);

    v_failed_attempt_fees := v_failed_orders_count * v_unit_failed_fee;

    -- Optional custom deductions
    IF p_custom_deductions ? 'other_charges' THEN
        v_other_charges := COALESCE((p_custom_deductions->>'other_charges')::numeric, 0.00);
    END IF;

    v_total_platform_charges := v_system_operation_fees + v_gateway_fees;
    v_total_deductions := v_delivery_fees + v_failed_attempt_fees + v_total_platform_charges + v_other_charges;
    v_net_payout := GREATEST(0.00, v_gross_collections - v_total_deductions);

    -- Build itemized breakdown
    v_charges_breakdown := jsonb_build_object(
        'rate_basis', jsonb_build_object(
            'delivery_fee_per_order', COALESCE(v_client.custom_delivery_fee, v_dc_settings.default_client_delivery_fee, 5000.00),
            'failed_delivery_fee', v_unit_failed_fee,
            'platform_fee_type', COALESCE(v_client.raw_json->>'custom_platform_fee_type', 'flat'),
            'platform_fee_value', COALESCE((v_client.raw_json->>'custom_platform_fee_value')::numeric, v_client.custom_platform_fee, 500.00)
        ),
        'delivery_fees', v_delivery_fees,
        'failed_attempt_fees', v_failed_attempt_fees,
        'failed_orders_count', v_failed_orders_count,
        'platform_operations_fees', v_system_operation_fees,
        'payment_gateway_fees', v_gateway_fees,
        'other_charges', v_other_charges,
        'total_deductions', v_total_deductions,
        'proof_of_payment_url', p_proof_of_payment_url,
        'payout_reference', p_payout_reference,
        'order_ids', v_order_ids_array
    );

    -- Sequential settlement number: SETTLE-YYYYMMDD-XXX
    SELECT COUNT(*) + 1 INTO v_today_seq
    FROM public.client_settlements
    WHERE created_at >= date_trunc('day', NOW());

    v_settlement_number := 'SETTLE-' || to_char(NOW(), 'YYYYMMDD') || '-' || lpad(v_today_seq::text, 3, '0');

    -- Insert into client_settlements with accurate column mappings
    INSERT INTO public.client_settlements (
        id,
        settlement_number,
        client_id,
        distribution_center_id,
        period_start,
        period_end,
        total_orders_count,
        gross_collections,
        logistics_fees_deducted,
        platform_fees_deducted,
        gateway_fees_deducted,
        failed_attempt_fees_deducted,
        other_charges_deducted,
        net_payout_amount,
        destination_bank_name,
        destination_account_number,
        destination_account_name,
        payout_reference,
        proof_of_payment_url,
        status,
        notes,
        charges_breakdown,
        created_at,
        settled_at
    ) VALUES (
        v_settlement_id,
        v_settlement_number,
        p_client_id,
        p_dc_id,
        v_eff_period_start,
        v_eff_period_end,
        v_orders_count,
        v_gross_collections,
        v_delivery_fees,
        v_system_operation_fees,
        v_gateway_fees,
        v_failed_attempt_fees,
        v_other_charges,
        v_net_payout,
        COALESCE(v_client.bank_name, 'Access Bank'),
        COALESCE(v_client.account_number, '0123456789'),
        COALESCE(v_client.account_name, v_client.company_name, 'Merchant Account'),
        p_payout_reference,
        p_proof_of_payment_url,
        COALESCE(p_status, 'remitted'),
        COALESCE(p_custom_deductions->>'notes', 'Manual Bank Transfer Settlement Fulfilled by Central DC'),
        v_charges_breakdown,
        NOW(),
        NOW()
    );

    -- Mark orders as client_settled
    IF array_length(v_order_ids_array, 1) > 0 THEN
        UPDATE public.orders
        SET financial_settlement_status = 'client_settled',
            updated_at = NOW()
        WHERE id = ANY(v_order_ids_array);
    END IF;

    -- Return full result payload
    RETURN jsonb_build_object(
        'success', true,
        'settlement_id', v_settlement_id,
        'settlement_number', v_settlement_number,
        'client_id', p_client_id,
        'orders_settled', v_orders_count,
        'failed_orders_deducted', v_failed_orders_count,
        'gross_collections', v_gross_collections,
        'total_deductions', v_total_deductions,
        'net_payout', v_net_payout,
        'status', COALESCE(p_status, 'remitted'),
        'proof_of_payment_url', p_proof_of_payment_url,
        'payout_reference', p_payout_reference,
        'breakdown', v_charges_breakdown
    );
END;
$$;

-- 4. Overloaded 6-parameter compatibility signature
CREATE OR REPLACE FUNCTION public.fn_generate_merchant_daily_settlement(
    p_client_id UUID,
    p_dc_id UUID DEFAULT NULL,
    p_period_start TIMESTAMPTZ DEFAULT NULL,
    p_period_end TIMESTAMPTZ DEFAULT NULL,
    p_custom_deductions JSONB DEFAULT '{}'::jsonb,
    p_order_ids UUID[] DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN public.fn_generate_merchant_daily_settlement(
        p_client_id := p_client_id,
        p_dc_id := p_dc_id,
        p_period_start := p_period_start,
        p_period_end := p_period_end,
        p_custom_deductions := p_custom_deductions,
        p_order_ids := p_order_ids,
        p_proof_of_payment_url := NULL,
        p_payout_reference := NULL,
        p_status := 'remitted'
    );
END;
$$;

-- 5. Stored Procedure: fn_merchant_approve_settlement
CREATE OR REPLACE FUNCTION public.fn_merchant_approve_settlement(
    p_settlement_id UUID,
    p_client_id UUID DEFAULT NULL,
    p_approval_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_settlement RECORD;
BEGIN
    SELECT * INTO v_settlement
    FROM public.client_settlements
    WHERE id = p_settlement_id
      AND (p_client_id IS NULL OR client_id = p_client_id);
      
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Settlement record not found');
    END IF;
    
    UPDATE public.client_settlements
    SET status = 'completed',
        notes = COALESCE(notes, '') || ' | Merchant Approved & Confirmed on ' || to_char(NOW(), 'YYYY-MM-DD HH24:MI:SS') || COALESCE(' - ' || p_approval_notes, ''),
        settled_at = NOW()
    WHERE id = p_settlement_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'settlement_id', p_settlement_id,
        'status', 'completed',
        'approved_at', NOW()
    );
END;
$$;

-- 6. Permissions
GRANT EXECUTE ON FUNCTION public.fn_generate_merchant_daily_settlement(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, JSONB, UUID[], TEXT, TEXT, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_generate_merchant_daily_settlement(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, JSONB, UUID[]) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_merchant_approve_settlement(UUID, UUID, TEXT) TO authenticated, service_role, anon;
GRANT SELECT, INSERT, UPDATE ON public.client_settlements TO authenticated, service_role, anon;
