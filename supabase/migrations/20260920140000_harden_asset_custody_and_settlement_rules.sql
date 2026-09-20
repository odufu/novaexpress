-- Migration: 20260920140000_harden_asset_custody_and_settlement_rules.sql
-- Description:
-- 1. Upgrades fn_calculate_merchant_asset_custody to dynamically read client's custom_delivery_fee and deduct failed delivery fees.
-- 2. Upgrades fn_generate_merchant_daily_settlement to include all failed delivery statuses ('failed', 'cancelled', 'rejected', 'customer_rejected').

-- 1. fn_calculate_merchant_asset_custody
CREATE OR REPLACE FUNCTION public.fn_calculate_merchant_asset_custody(
    p_client_id UUID,
    p_dc_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_cash_in_paystack NUMERIC(14, 2) := 0.00;
    v_cash_in_dc_vault NUMERIC(14, 2) := 0.00;
    v_total_liquid_cash NUMERIC(14, 2) := 0.00;
    v_total_units_in_custody INT := 0;
    v_base_inventory_valuation NUMERIC(14, 2) := 0.00;
    v_weighted_retail_valuation NUMERIC(14, 2) := 0.00;
    v_prod RECORD;
    v_client RECORD;
    v_delivery_fee NUMERIC(14, 2) := 5000.00;
    v_failed_fee NUMERIC(14, 2) := 500.00;
    v_failed_orders_count INT := 0;
    v_failed_charges NUMERIC(14, 2) := 0.00;
BEGIN
    -- Look up client settings
    SELECT custom_delivery_fee, custom_failed_attempt_fee
    INTO v_client
    FROM public.clients
    WHERE id = p_client_id;

    IF FOUND THEN
        IF v_client.custom_delivery_fee IS NOT NULL AND v_client.custom_delivery_fee > 0 THEN
            v_delivery_fee := v_client.custom_delivery_fee;
        END IF;
        IF v_client.custom_failed_attempt_fee IS NOT NULL AND v_client.custom_failed_attempt_fee > 0 THEN
            v_failed_fee := v_client.custom_failed_attempt_fee;
        END IF;
    END IF;

    -- 1. Liquid Cash in Custody (Delivered orders awaiting 10 PM Closeout)
    SELECT 
        COALESCE(SUM(CASE WHEN COALESCE(payment_method, delivery_method, 'cash') = 'paystack' OR payment_type = 'prepaid' THEN (total_amount - COALESCE(client_delivery_fee, v_delivery_fee)) ELSE 0 END), 0.00),
        COALESCE(SUM(CASE WHEN COALESCE(payment_method, delivery_method, 'cash') = 'cash' AND payment_type = 'pay_on_delivery' THEN (total_amount - COALESCE(client_delivery_fee, v_delivery_fee)) ELSE 0 END), 0.00)
    INTO v_cash_in_paystack, v_cash_in_dc_vault
    FROM public.orders
    WHERE client_id = p_client_id
      AND status = 'delivered'
      AND (financial_settlement_status IS NULL OR financial_settlement_status != 'client_settled')
      AND (p_dc_id IS NULL OR distribution_center_id = p_dc_id);

    -- Deduct pending failed delivery attempt fees from unsettled failed/cancelled orders
    SELECT COUNT(*) INTO v_failed_orders_count
    FROM public.orders
    WHERE client_id = p_client_id
      AND status IN ('failed', 'cancelled', 'rejected', 'customer_rejected')
      AND (financial_settlement_status IS NULL OR financial_settlement_status != 'client_settled')
      AND (p_dc_id IS NULL OR distribution_center_id = p_dc_id);

    v_failed_charges := v_failed_orders_count * v_failed_fee;
    v_total_liquid_cash := GREATEST(0.00, (v_cash_in_paystack + v_cash_in_dc_vault) - v_failed_charges);

    -- 2. In-Kind Inventory Custody & Dual Valuation
    FOR v_prod IN
        SELECT id, name, sku, base_price, stock_quantity, available_count
        FROM public.products
        WHERE client_id = p_client_id OR client_name IN (SELECT company_name FROM public.clients WHERE id = p_client_id)
    LOOP
        DECLARE
            v_units INT := COALESCE(v_prod.stock_quantity, v_prod.available_count, 0);
            v_avg_price NUMERIC(14, 2);
        BEGIN
            v_total_units_in_custody := v_total_units_in_custody + v_units;
            v_base_inventory_valuation := v_base_inventory_valuation + (v_units * COALESCE(v_prod.base_price, 25000.00));

            -- Calculate historical realized unit price factoring in package deals
            SELECT COALESCE(AVG(total_amount / NULLIF(quantity, 0)), v_prod.base_price, 25000.00)
            INTO v_avg_price
            FROM public.orders
            WHERE client_id = p_client_id AND product_name = v_prod.name AND status = 'delivered';

            v_weighted_retail_valuation := v_weighted_retail_valuation + (v_units * v_avg_price);
        END;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'client_id', p_client_id,
        'liquid_cash_in_custody', v_total_liquid_cash,
        'physical_cod_in_dc_vault', v_cash_in_dc_vault,
        'direct_transfer_in_paystack', v_cash_in_paystack,
        'failed_delivery_surcharges', v_failed_charges,
        'total_inventory_units_held', v_total_units_in_custody,
        'inventory_baseline_liquidation_value', v_base_inventory_valuation,
        'inventory_estimated_retail_value', v_weighted_retail_valuation,
        'grand_total_asset_value', (v_total_liquid_cash + v_weighted_retail_valuation)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_calculate_merchant_asset_custody(UUID, UUID) TO authenticated, service_role, anon;

-- 2. fn_generate_merchant_daily_settlement (with updated failed status inclusion)
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
    -- Effective period boundaries (Default: Today from 00:00:00 to 23:59:59 UTC)
    v_eff_period_start := COALESCE(p_period_start, date_trunc('day', NOW()));
    v_eff_period_end   := COALESCE(p_period_end,   date_trunc('day', NOW()) + INTERVAL '1 day' - INTERVAL '1 millisecond');

    -- Load Client Info
    SELECT id, name, company_name, custom_delivery_fee, custom_failed_attempt_fee, 
           custom_platform_fee, custom_platform_fee_value, custom_platform_fee_type,
           bank_name, account_number, account_name
    INTO v_client
    FROM public.clients
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
            WHERE o.client_id = p_client_id
              AND o.id = ANY(p_order_ids)
              AND o.status = 'delivered'
              AND (o.financial_settlement_status IS NULL OR o.financial_settlement_status != 'client_settled')
        LOOP
            v_order_ids_array := array_append(v_order_ids_array, v_order.id);
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
    ELSE
        FOR v_order IN
            SELECT o.id, o.total_amount, o.client_delivery_fee, o.payment_type,
                   COALESCE(o.payment_method, o.delivery_method, 'cash') AS eff_method
            FROM public.orders o
            WHERE o.client_id = p_client_id
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

    -- Charge 2: Failed Delivery Attempt Surcharges (incorporates failed, cancelled, rejected, customer_rejected)
    v_unit_failed_fee := COALESCE(v_client.custom_failed_attempt_fee, v_dc_settings.failed_order_charge, 1000.00);
    SELECT COUNT(*) INTO v_failed_orders_count
    FROM public.orders
    WHERE client_id = p_client_id
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
            'platform_fee_type', COALESCE(v_client.custom_platform_fee_type, v_dc_settings.platform_fee_type, 'flat'),
            'platform_fee_value', COALESCE(v_client.custom_platform_fee_value, v_client.custom_platform_fee, v_dc_settings.platform_fee_value, 500.00)
        ),
        'delivery_fees', v_delivery_fees,
        'failed_attempt_fees', v_failed_attempt_fees,
        'failed_orders_count', v_failed_orders_count,
        'platform_operations_fees', v_system_operation_fees,
        'payment_gateway_fees', v_gateway_fees,
        'other_charges', v_other_charges,
        'total_deductions', v_total_deductions
    );

    -- Sequential settlement number: SET-YYYYMMDD-XXX
    SELECT COUNT(*) + 1 INTO v_today_seq
    FROM public.client_settlements
    WHERE created_at >= date_trunc('day', NOW());

    v_settlement_number := 'SET-' || to_char(NOW(), 'YYYYMMDD') || '-' || lpad(v_today_seq::text, 3, '0');

    -- Insert Settlement
    INSERT INTO public.client_settlements (
        id,
        settlement_number,
        client_id,
        period_start,
        period_end,
        orders_count,
        gross_amount,
        delivery_fees,
        failed_attempt_fees,
        platform_charges,
        other_deductions,
        total_deductions,
        net_payout,
        bank_name,
        account_number,
        account_name,
        settlement_status,
        charges_breakdown,
        order_ids,
        distribution_center_id,
        created_at,
        settled_at
    ) VALUES (
        v_settlement_id,
        v_settlement_number,
        p_client_id,
        v_eff_period_start,
        v_eff_period_end,
        v_orders_count,
        v_gross_collections,
        v_delivery_fees,
        v_failed_attempt_fees,
        v_total_platform_charges,
        v_other_charges,
        v_total_deductions,
        v_net_payout,
        v_client.bank_name,
        v_client.account_number,
        v_client.account_name,
        'completed',
        v_charges_breakdown,
        v_order_ids_array,
        p_dc_id,
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
        'breakdown', v_charges_breakdown
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_generate_merchant_daily_settlement(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, JSONB, UUID[]) TO authenticated, service_role, anon;
