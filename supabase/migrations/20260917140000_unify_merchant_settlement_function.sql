-- ============================================================================
-- UNIFY MERCHANT SETTLEMENT FUNCTION (DROP AMBIGUOUS 5-PARAM OVERLOAD)
-- Eliminates PostgREST PGRST203 (HTTP 300 Multiple Choices) by retaining
-- the single unified 6-parameter function with clean default parameters.
-- ============================================================================

-- 1. Drop ambiguous 5-parameter overload that collides with 6-param function
DROP FUNCTION IF EXISTS public.fn_generate_merchant_daily_settlement(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, JSONB);

-- 2. Ensure single authoritative 6-parameter definition with full default support
CREATE OR REPLACE FUNCTION public.fn_generate_merchant_daily_settlement(
    p_client_id UUID,
    p_dc_id UUID,
    p_period_start TIMESTAMPTZ DEFAULT NULL,
    p_period_end TIMESTAMPTZ DEFAULT clock_timestamp(),
    p_custom_deductions JSONB DEFAULT '{}'::jsonb,
    p_order_ids UUID[] DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_settlement_id UUID := gen_random_uuid();
    v_settlement_number TEXT;
    v_client RECORD;
    v_dc_settings RECORD;
    v_order RECORD;
    v_has_order_ids BOOLEAN := (p_order_ids IS NOT NULL AND array_length(p_order_ids, 1) > 0);
    v_eff_period_start TIMESTAMPTZ := p_period_start;
    v_eff_period_end TIMESTAMPTZ := COALESCE(p_period_end, clock_timestamp());
    
    -- Financial Aggregations
    v_orders_count INT := 0;
    v_gross_collections NUMERIC(14, 2) := 0.00;
    v_delivery_fees NUMERIC(14, 2) := 0.00;
    v_failed_attempt_fees NUMERIC(14, 2) := 0.00;
    v_gateway_fees NUMERIC(14, 2) := 0.00;
    v_system_operation_fees NUMERIC(14, 2) := 0.00;
    v_other_charges NUMERIC(14, 2) := 0.00;
    v_total_platform_charges NUMERIC(14, 2) := 0.00;
    
    -- Tariffs
    v_order_delivery_fee NUMERIC(14, 2);
    v_order_platform_fee NUMERIC(14, 2);
    v_order_gateway_fee NUMERIC(14, 2);
    v_failed_orders_count INT := 0;
    v_unit_failed_fee NUMERIC(14, 2);
    
    -- Calculated balances
    v_total_deductions NUMERIC(14, 2) := 0.00;
    v_net_payout NUMERIC(14, 2) := 0.00;
    v_charges_breakdown JSONB;
BEGIN
    -- 1. Fetch Client Profile & Custom Tariffs
    SELECT * INTO v_client FROM public.clients WHERE id = p_client_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Client profile not found');
    END IF;

    -- 2. Fetch Active DC Finance Settings
    SELECT * INTO v_dc_settings FROM public.dc_finance_settings 
    WHERE id = 'global_finance_config' OR distribution_center_id = p_dc_id::text
    ORDER BY created_at DESC LIMIT 1;

    -- Generate Unique Settlement Reference
    v_settlement_number := 'SETTLE-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || SUBSTRING(v_settlement_id::text, 1, 6);

    -- 3. Aggregate delivered eligible orders
    IF v_has_order_ids THEN
        FOR v_order IN 
            SELECT id, order_number, total_amount, payment_type, COALESCE(payment_method, delivery_method, 'cash') AS eff_method, client_delivery_fee
            FROM public.orders
            WHERE id = ANY(p_order_ids)
              AND client_id = p_client_id
              AND status = 'delivered'
              AND (financial_settlement_status IS NULL OR financial_settlement_status != 'client_settled')
        LOOP
            v_orders_count := v_orders_count + 1;
            v_gross_collections := v_gross_collections + COALESCE(v_order.total_amount, 0.00);

            -- Charge 1: Negotiated Delivery Fee
            v_order_delivery_fee := COALESCE(v_client.custom_delivery_fee, v_order.client_delivery_fee, v_dc_settings.default_client_delivery_fee, 5000.00);
            v_delivery_fees := v_delivery_fees + v_order_delivery_fee;

            -- Charge 3A: System Operation Charge
            IF v_client.custom_platform_fee_type = 'percentage' THEN
                v_order_platform_fee := COALESCE(v_order.total_amount, 0.00) * (COALESCE(v_client.custom_platform_fee_value, v_client.custom_platform_fee, 2.5) / 100.0);
            ELSE
                v_order_platform_fee := COALESCE(v_client.custom_platform_fee_value, v_client.custom_platform_fee, v_dc_settings.platform_fee_value, 500.00);
            END IF;
            v_system_operation_fees := v_system_operation_fees + v_order_platform_fee;

            -- Charge 3B: Third-Party Provider Switch Fee
            IF LOWER(v_order.eff_method) = 'direct_transfer' OR LOWER(v_order.payment_type) = 'direct_transfer' THEN
                v_order_gateway_fee := LEAST(2000.00, COALESCE(v_order.total_amount, 0.00) * (COALESCE(v_dc_settings.paystack_direct_fee_percent, 1.5) / 100.0));
                v_gateway_fees := v_gateway_fees + v_order_gateway_fee;
            END IF;
        END LOOP;
    ELSE
        FOR v_order IN 
            SELECT id, order_number, total_amount, payment_type, COALESCE(payment_method, delivery_method, 'cash') AS eff_method, client_delivery_fee
            FROM public.orders
            WHERE client_id = p_client_id
              AND status = 'delivered'
              AND (financial_settlement_status IS NULL OR financial_settlement_status != 'client_settled')
              AND (v_eff_period_start IS NULL OR delivered_at >= v_eff_period_start)
              AND (delivered_at <= v_eff_period_end)
        LOOP
            v_orders_count := v_orders_count + 1;
            v_gross_collections := v_gross_collections + COALESCE(v_order.total_amount, 0.00);

            v_order_delivery_fee := COALESCE(v_client.custom_delivery_fee, v_order.client_delivery_fee, v_dc_settings.default_client_delivery_fee, 5000.00);
            v_delivery_fees := v_delivery_fees + v_order_delivery_fee;

            IF v_client.custom_platform_fee_type = 'percentage' THEN
                v_order_platform_fee := COALESCE(v_order.total_amount, 0.00) * (COALESCE(v_client.custom_platform_fee_value, v_client.custom_platform_fee, 2.5) / 100.0);
            ELSE
                v_order_platform_fee := COALESCE(v_client.custom_platform_fee_value, v_client.custom_platform_fee, v_dc_settings.platform_fee_value, 500.00);
            END IF;
            v_system_operation_fees := v_system_operation_fees + v_order_platform_fee;

            IF LOWER(v_order.eff_method) = 'direct_transfer' OR LOWER(v_order.payment_type) = 'direct_transfer' THEN
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
    WHERE client_id = p_client_id
      AND status = 'failed'
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
            'system_operation_charge', COALESCE(v_client.custom_platform_fee_value, v_client.custom_platform_fee, 500.00)
        ),
        'delivery_fees', v_delivery_fees,
        'failed_attempt_fees', v_failed_attempt_fees,
        'platform_fees', v_total_platform_charges,
        'system_operation_fees', v_system_operation_fees,
        'gateway_fees', v_gateway_fees,
        'other_charges', v_other_charges,
        'total_deductions', v_total_deductions,
        'accounts_separation', jsonb_build_object(
            'nova_express_operations_revenue', v_delivery_fees,
            'app_operational_finance_fund', v_system_operation_fees,
            'third_party_payment_switch', v_gateway_fees,
            'merchant_net_disbursement', v_net_payout
        )
    );

    -- Insert into client_settlements
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
        charges_breakdown,
        net_payout_amount,
        destination_bank_name,
        destination_account_number,
        destination_account_name,
        status,
        notes,
        settled_at,
        created_at
    ) VALUES (
        v_settlement_id,
        v_settlement_number,
        p_client_id,
        p_dc_id,
        COALESCE(v_eff_period_start, NOW() - INTERVAL '30 days'),
        v_eff_period_end,
        v_orders_count,
        v_gross_collections,
        v_delivery_fees,
        v_system_operation_fees,
        v_gateway_fees,
        v_failed_attempt_fees,
        v_other_charges,
        v_charges_breakdown,
        v_net_payout,
        COALESCE(v_client.bank_name, 'Access Bank'),
        COALESCE(v_client.account_number, '0123456789'),
        COALESCE(v_client.account_name, v_client.company_name, v_client.name),
        'completed',
        COALESCE(p_custom_deductions->>'notes', 'Daily Client Settlement Batch'),
        NOW(),
        NOW()
    );

    -- Mark eligible delivered orders as client_settled and remitted
    IF v_has_order_ids THEN
        UPDATE public.orders
        SET 
            financial_settlement_status = 'client_settled',
            remittance_status = 'remitted',
            remittance_reference = v_settlement_number,
            remitted_at = COALESCE(remitted_at, NOW()),
            updated_at = NOW()
        WHERE id = ANY(p_order_ids)
          AND client_id = p_client_id
          AND status = 'delivered';
    ELSE
        UPDATE public.orders
        SET 
            financial_settlement_status = 'client_settled',
            remittance_status = 'remitted',
            remittance_reference = v_settlement_number,
            remitted_at = COALESCE(remitted_at, NOW()),
            updated_at = NOW()
        WHERE client_id = p_client_id
          AND status = 'delivered'
          AND (financial_settlement_status IS NULL OR financial_settlement_status != 'client_settled')
          AND (v_eff_period_start IS NULL OR delivered_at >= v_eff_period_start)
          AND (delivered_at <= v_eff_period_end);
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'settlement_id', v_settlement_id,
        'settlement_number', v_settlement_number,
        'gross_collections', v_gross_collections,
        'orders_settled', v_orders_count,
        'delivery_fees', v_delivery_fees,
        'failed_attempt_fees', v_failed_attempt_fees,
        'platform_charges', v_total_platform_charges,
        'total_deductions', v_total_deductions,
        'net_payout', v_net_payout,
        'charges_breakdown', v_charges_breakdown
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_generate_merchant_daily_settlement(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, JSONB, UUID[]) TO authenticated, service_role, anon;

NOTIFY pgrst, 'reload schema';
