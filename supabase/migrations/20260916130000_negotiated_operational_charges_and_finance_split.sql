-- Migration: 20260916130000_negotiated_operational_charges_and_finance_split.sql
-- Description: Negotiated Operational Charges (Delivery Fee ₦5,000, Failed Delivery ₦1,000, Platform Charge = Third-Party Switch + System Operation Charge),
-- and strict separation of Nova Express Logistics Revenue from App Operational Finance.

-- ============================================================================
-- 1. Schema Extensions & Defaults Alignment
-- ============================================================================

-- 1.1 Clients Table: Ensure negotiated operational charge overrides exist
ALTER TABLE IF EXISTS public.clients
    ADD COLUMN IF NOT EXISTS custom_delivery_fee NUMERIC(14, 2) DEFAULT 5000.00,
    ADD COLUMN IF NOT EXISTS custom_failed_attempt_fee NUMERIC(14, 2) DEFAULT 1000.00,
    ADD COLUMN IF NOT EXISTS custom_platform_fee NUMERIC(14, 2) DEFAULT 500.00,
    ADD COLUMN IF NOT EXISTS custom_platform_fee_type TEXT DEFAULT 'flat',
    ADD COLUMN IF NOT EXISTS custom_paystack_fee_absorbed_by TEXT DEFAULT 'merchant';

-- Update baseline defaults for clients that have NULL overrides
UPDATE public.clients
SET 
    custom_delivery_fee = COALESCE(custom_delivery_fee, 5000.00),
    custom_failed_attempt_fee = COALESCE(custom_failed_attempt_fee, 1000.00),
    custom_platform_fee = COALESCE(custom_platform_fee, 500.00)
WHERE custom_delivery_fee IS NULL OR custom_failed_attempt_fee IS NULL OR custom_platform_fee IS NULL;

-- 1.2 DC Finance Settings: Update baseline defaults
ALTER TABLE IF EXISTS public.dc_finance_settings
    ADD COLUMN IF NOT EXISTS default_client_delivery_fee NUMERIC(14, 2) DEFAULT 5000.00,
    ADD COLUMN IF NOT EXISTS failed_order_charge NUMERIC(14, 2) DEFAULT 1000.00,
    ADD COLUMN IF NOT EXISTS platform_fee_value NUMERIC(14, 2) DEFAULT 500.00,
    ADD COLUMN IF NOT EXISTS remittance_switch_fee NUMERIC(14, 2) DEFAULT 100.00;

UPDATE public.dc_finance_settings
SET 
    default_client_delivery_fee = 5000.00,
    failed_order_charge = 1000.00,
    platform_fee_value = 500.00,
    remittance_switch_fee = 100.00
WHERE id = 'global_finance_config';

-- ============================================================================
-- 2. Enhanced Stored Procedure: fn_generate_merchant_daily_settlement
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_generate_merchant_daily_settlement(
    p_client_id UUID,
    p_dc_id UUID,
    p_period_start TIMESTAMPTZ,
    p_period_end TIMESTAMPTZ,
    p_custom_deductions JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_client RECORD;
    v_dc_settings RECORD;
    v_settlement_id UUID := gen_random_uuid();
    v_settlement_number TEXT;
    
    -- Aggregation Counters & Totals
    v_orders_count INT := 0;
    v_gross_collections NUMERIC(14, 2) := 0.00;
    
    -- Operational Charge Buckets
    v_delivery_fees NUMERIC(14, 2) := 0.00;
    v_system_operation_fees NUMERIC(14, 2) := 0.00;
    v_gateway_fees NUMERIC(14, 2) := 0.00;
    v_failed_attempt_fees NUMERIC(14, 2) := 0.00;
    v_other_charges NUMERIC(14, 2) := 0.00;
    
    v_order RECORD;
    v_order_delivery_fee NUMERIC(14, 2);
    v_order_system_fee NUMERIC(14, 2);
    v_order_gateway_fee NUMERIC(14, 2);
    v_total_platform_charges NUMERIC(14, 2) := 0.00;
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
    FOR v_order IN 
        SELECT id, order_number, total_amount, payment_type, COALESCE(payment_method, delivery_method, 'cash') AS eff_method, client_delivery_fee
        FROM public.orders
        WHERE client_id = p_client_id
          AND status = 'delivered'
          AND (financial_settlement_status IS NULL OR financial_settlement_status != 'client_settled')
          AND delivered_at >= p_period_start
          AND delivered_at <= p_period_end
    LOOP
        v_orders_count := v_orders_count + 1;
        v_gross_collections := v_gross_collections + COALESCE(v_order.total_amount, 0.00);

        -- Charge 1: Negotiated Delivery Fee (Client override > Order specific fee > DC setting default)
        v_order_delivery_fee := COALESCE(v_client.custom_delivery_fee, v_order.client_delivery_fee, v_dc_settings.default_client_delivery_fee, 5000.00);
        v_delivery_fees := v_delivery_fees + v_order_delivery_fee;

        -- Charge 3A: System Operation Charge (App Operational Finance)
        IF COALESCE(v_client.custom_platform_fee, 0) > 0 THEN
            v_order_system_fee := v_client.custom_platform_fee;
        ELSIF v_dc_settings.platform_fee_type = 'percent' THEN
            v_order_system_fee := (COALESCE(v_order.total_amount, 0.00) * (COALESCE(v_dc_settings.platform_fee_value, 2.5) / 100.0));
        ELSE
            v_order_system_fee := COALESCE(v_dc_settings.platform_fee_value, 500.00);
        END IF;
        v_system_operation_fees := v_system_operation_fees + v_order_system_fee;

        -- Charge 3B: Third-Party Provider Fee (Paystack / Electronic Remittance Switch)
        IF v_order.eff_method = 'paystack' OR v_order.payment_type = 'prepaid' THEN
            IF COALESCE(v_dc_settings.paystack_fee_absorbed_by, 'merchant') = 'merchant' THEN
                -- 1.5% switch fee capped at NGN 2000
                v_order_gateway_fee := LEAST(2000.00, (COALESCE(v_order.total_amount, 0.00) * 0.015));
                v_gateway_fees := v_gateway_fees + v_order_gateway_fee;
            END IF;
        ELSE
            -- Cash on Delivery electronic bank transfer remittance switch fee
            v_gateway_fees := v_gateway_fees + COALESCE(v_dc_settings.remittance_switch_fee, 100.00);
        END IF;
    END LOOP;

    -- Charge 2: Failed Delivery Attempt Fees
    IF COALESCE(v_client.custom_failed_attempt_fee, v_dc_settings.failed_order_charge, 0) > 0 THEN
        SELECT COALESCE(COUNT(*), 0) * COALESCE(v_client.custom_failed_attempt_fee, v_dc_settings.failed_order_charge, 1000.00)
        INTO v_failed_attempt_fees
        FROM public.orders
        WHERE client_id = p_client_id
          AND status IN ('cancelled', 'failed', 'rejected')
          AND updated_at >= p_period_start
          AND updated_at <= p_period_end;
    END IF;

    -- Process Custom Extra Deductions (if provided)
    IF p_custom_deductions ? 'other_charges' THEN
        v_other_charges := (p_custom_deductions->>'other_charges')::numeric;
    END IF;

    -- Calculate Totals & Net Payout
    v_total_platform_charges := v_system_operation_fees + v_gateway_fees;
    v_total_deductions := v_delivery_fees + v_failed_attempt_fees + v_total_platform_charges + v_other_charges;
    v_net_payout := GREATEST(0.00, v_gross_collections - v_total_deductions);

    -- Construct Separated Accounting Breakdown JSONB
    v_charges_breakdown := jsonb_build_object(
        'delivery_fees', v_delivery_fees,
        'failed_attempt_fees', v_failed_attempt_fees,
        'system_operation_fees', v_system_operation_fees,
        'gateway_fees', v_gateway_fees,
        'platform_fees', v_total_platform_charges,
        'other_charges', v_other_charges,
        'total_deductions', v_total_deductions,
        'accounts_separation', jsonb_build_object(
            'nova_express_operations_revenue', v_delivery_fees + v_failed_attempt_fees,
            'app_operational_finance_fund', v_system_operation_fees,
            'third_party_payment_switch', v_gateway_fees,
            'merchant_net_disbursement', v_net_payout
        ),
        'rate_basis', jsonb_build_object(
            'delivery_fee_per_order', COALESCE(v_client.custom_delivery_fee, v_dc_settings.default_client_delivery_fee, 5000.00),
            'failed_delivery_fee', COALESCE(v_client.custom_failed_attempt_fee, v_dc_settings.failed_order_charge, 1000.00),
            'system_operation_charge', COALESCE(v_client.custom_platform_fee, v_dc_settings.platform_fee_value, 500.00)
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
        p_period_start,
        p_period_end,
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
        'settled',
        '10:00 PM Automated Merchant Daily Settlement Batch',
        NOW(),
        NOW()
    );

    -- Mark eligible delivered orders as client_settled and remitted
    UPDATE public.orders
    SET 
        financial_settlement_status = 'client_settled',
        remittance_status = 'remitted',
        remittance_reference = v_settlement_number,
        remitted_at = NOW(),
        updated_at = NOW()
    WHERE client_id = p_client_id
      AND status = 'delivered'
      AND (financial_settlement_status IS NULL OR financial_settlement_status != 'client_settled')
      AND delivered_at >= p_period_start
      AND delivered_at <= p_period_end;

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
