-- ============================================================================
-- Migration: 20260915120000_financial_system_schema_and_rpc_remediation.sql
-- Financial & Remittance System Deep Remediation:
-- 1. Adds missing is_verified column and indexes to public.cash_remittances
-- 2. Adds payment_method column to public.orders for full compatibility
-- 3. Adds default_failed_stipend column to dc_finance_settings for edge function compatibility
-- 4. Fixes and hardens fn_approve_cash_remittance, fn_generate_merchant_daily_settlement,
--    and fn_calculate_merchant_asset_custody stored procedures
-- ============================================================================

-- 1. Add missing is_verified column to cash_remittances
ALTER TABLE IF EXISTS public.cash_remittances
    ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_cash_remittances_is_verified ON public.cash_remittances(is_verified);

-- Backfill is_verified for all previously verified rows
UPDATE public.cash_remittances
SET is_verified = TRUE
WHERE status = 'verified';

-- 2. Add payment_method column to orders table
ALTER TABLE IF EXISTS public.orders
    ADD COLUMN IF NOT EXISTS payment_method VARCHAR(50) DEFAULT 'cash';

UPDATE public.orders
SET payment_method = COALESCE(delivery_method, 'cash')
WHERE payment_method IS NULL;

CREATE INDEX IF NOT EXISTS idx_orders_payment_method ON public.orders(payment_method);

-- 3. Add default_failed_stipend column to dc_finance_settings
ALTER TABLE IF EXISTS public.dc_finance_settings
    ADD COLUMN IF NOT EXISTS default_failed_stipend NUMERIC(14,2) DEFAULT 500.00;

UPDATE public.dc_finance_settings
SET default_failed_stipend = COALESCE(default_failed_delivery_allowance, 500.00)
WHERE default_failed_stipend IS NULL;

-- 4. Hardened Stored Procedure: fn_approve_cash_remittance
CREATE OR REPLACE FUNCTION public.fn_approve_cash_remittance(
    p_remittance_id UUID,
    p_supervisor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_rem RECORD;
    v_new_cod_balance NUMERIC;
BEGIN
    -- A. Fetch remittance
    SELECT * INTO v_rem
    FROM public.cash_remittances
    WHERE id = p_remittance_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Remittance record not found');
    END IF;

    -- B. Mark verified with timestamp and supervisor
    UPDATE public.cash_remittances
    SET 
        status = 'verified',
        is_verified = TRUE,
        verified_by_user_id = COALESCE(p_supervisor_id, verified_by_user_id),
        verified_at = COALESCE(verified_at, NOW()),
        updated_at = NOW()
    WHERE id = p_remittance_id;

    -- C. Atomically decrement rider COD balance by the remitted amount
    UPDATE public.delivery_agents
    SET 
        current_cod_balance = GREATEST(0.00, COALESCE(current_cod_balance, 0.00) - v_rem.amount),
        updated_at = NOW()
    WHERE id = v_rem.delivery_agent_id
    RETURNING current_cod_balance INTO v_new_cod_balance;

    -- D. Mark all associated orders as 'remitted' and 'cash_remitted_verified'
    UPDATE public.orders
    SET 
        payment_status = 'collected',
        remittance_status = 'remitted',
        financial_settlement_status = 'cash_remitted_verified',
        remittance_reference = COALESCE(remittance_reference, v_rem.reference_number),
        remitted_at = COALESCE(remitted_at, NOW()),
        updated_at = NOW()
    WHERE id IN (
        SELECT order_id FROM public.remittance_orders WHERE cash_remittance_id = p_remittance_id
    )
    OR remittance_reference = v_rem.reference_number
    OR (v_rem.reference_number IS NOT NULL AND delivery_notes LIKE '%' || v_rem.reference_number || '%');

    RETURN jsonb_build_object(
        'success', true,
        'remittance_id', p_remittance_id,
        'new_cod_balance', v_new_cod_balance,
        'message', 'Remittance approved and rider COD balance liquidated successfully.'
    );
END;
$$;

-- 5. Hardened Stored Procedure: fn_generate_merchant_daily_settlement
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
    v_orders_count INT := 0;
    v_gross_collections NUMERIC(14, 2) := 0.00;
    v_delivery_fees NUMERIC(14, 2) := 0.00;
    v_platform_fees NUMERIC(14, 2) := 0.00;
    v_gateway_fees NUMERIC(14, 2) := 0.00;
    v_failed_attempt_fees NUMERIC(14, 2) := 0.00;
    v_other_charges NUMERIC(14, 2) := 0.00;
    v_total_deductions NUMERIC(14, 2) := 0.00;
    v_net_payout NUMERIC(14, 2) := 0.00;
    v_order RECORD;
    v_order_delivery_fee NUMERIC(14, 2);
    v_order_platform_fee NUMERIC(14, 2);
    v_order_gateway_fee NUMERIC(14, 2);
    v_charges_breakdown JSONB;
    v_effective_method TEXT;
BEGIN
    -- 1. Fetch Client Profile & Bank Account
    SELECT * INTO v_client FROM public.clients WHERE id = p_client_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Client not found');
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

        -- A. Determine Delivery Fee (Client override > Order specific fee > DC setting default)
        v_order_delivery_fee := COALESCE(v_client.custom_delivery_fee, v_order.client_delivery_fee, v_dc_settings.default_client_delivery_fee, 3500.00);
        v_delivery_fees := v_delivery_fees + v_order_delivery_fee;

        -- B. Determine Platform Fee
        IF COALESCE(v_client.custom_platform_fee, 0) > 0 THEN
            v_order_platform_fee := v_client.custom_platform_fee;
        ELSIF v_dc_settings.platform_fee_type = 'percent' THEN
            v_order_platform_fee := (COALESCE(v_order.total_amount, 0.00) * (COALESCE(v_dc_settings.platform_fee_value, 2.5) / 100.0));
        ELSE
            v_order_platform_fee := COALESCE(v_dc_settings.platform_fee_value, 500.00);
        END IF;
        v_platform_fees := v_platform_fees + v_order_platform_fee;

        -- C. Determine Gateway Processing Fee for Direct Transfer / Paystack
        IF v_order.eff_method = 'paystack' OR v_order.payment_type = 'prepaid' THEN
            IF COALESCE(v_dc_settings.paystack_fee_absorbed_by, 'merchant') = 'merchant' THEN
                -- 1.5% + NGN 100 capped at NGN 2000
                v_order_gateway_fee := LEAST(2000.00, (COALESCE(v_order.total_amount, 0.00) * 0.015) + 100.00);
                v_gateway_fees := v_gateway_fees + v_order_gateway_fee;
            END IF;
        END IF;
    END LOOP;

    -- 4. Check for Failed Order Charges (if client covers attempts)
    IF COALESCE(v_client.custom_failed_attempt_fee, v_dc_settings.failed_order_charge, 0) > 0 THEN
        SELECT COALESCE(COUNT(*), 0) * COALESCE(v_client.custom_failed_attempt_fee, v_dc_settings.failed_order_charge, 500.00)
        INTO v_failed_attempt_fees
        FROM public.orders
        WHERE client_id = p_client_id
          AND status IN ('cancelled', 'failed')
          AND updated_at >= p_period_start
          AND updated_at <= p_period_end;
    END IF;

    -- 5. Process Custom Extra Deductions
    IF p_custom_deductions ? 'other_charges' THEN
        v_other_charges := (p_custom_deductions->>'other_charges')::numeric;
    END IF;

    v_total_deductions := v_delivery_fees + v_platform_fees + v_gateway_fees + v_failed_attempt_fees + v_other_charges;
    v_net_payout := GREATEST(0.00, v_gross_collections - v_total_deductions);

    -- 6. Construct JSONB breakdown
    v_charges_breakdown := jsonb_build_object(
        'delivery_fees', v_delivery_fees,
        'platform_fees', v_platform_fees,
        'gateway_fees', v_gateway_fees,
        'failed_attempt_fees', v_failed_attempt_fees,
        'other_charges', v_other_charges,
        'total_deductions', v_total_deductions,
        'rate_basis', jsonb_build_object(
            'delivery_fee_per_order', COALESCE(v_client.custom_delivery_fee, v_dc_settings.default_client_delivery_fee, 3500.00),
            'platform_fee_rule', COALESCE(v_dc_settings.platform_fee_type, 'flat')
        )
    );

    -- 7. Insert into client_settlements
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
        v_platform_fees,
        v_gateway_fees,
        v_failed_attempt_fees,
        v_other_charges,
        v_charges_breakdown,
        v_net_payout,
        COALESCE(v_client.bank_name, 'Zenith Bank'),
        COALESCE(v_client.account_number, '1012345678'),
        COALESCE(v_client.account_name, v_client.company_name, v_client.name),
        'completed',
        'Daily 10:00 PM Merchant Settlement Closeout executed by Grand DC Clearinghouse',
        NOW(),
        NOW()
    );

    -- 8. Lock settled orders
    UPDATE public.orders
    SET 
        remittance_status = 'remitted',
        financial_settlement_status = 'client_settled',
        remittance_reference = v_settlement_number,
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
        'orders_settled', v_orders_count,
        'gross_collections', v_gross_collections,
        'total_deductions', v_total_deductions,
        'net_payout', v_net_payout,
        'charges_breakdown', v_charges_breakdown
    );
END;
$$;

-- 6. Hardened Stored Procedure: fn_calculate_merchant_asset_custody
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
BEGIN
    -- 1. Liquid Cash in Custody (Delivered orders awaiting 10 PM Closeout)
    SELECT 
        COALESCE(SUM(CASE WHEN COALESCE(payment_method, delivery_method, 'cash') = 'paystack' OR payment_type = 'prepaid' THEN (total_amount - COALESCE(client_delivery_fee, 3500.00)) ELSE 0 END), 0.00),
        COALESCE(SUM(CASE WHEN COALESCE(payment_method, delivery_method, 'cash') = 'cash' AND payment_type = 'pay_on_delivery' THEN (total_amount - COALESCE(client_delivery_fee, 3500.00)) ELSE 0 END), 0.00)
    INTO v_cash_in_paystack, v_cash_in_dc_vault
    FROM public.orders
    WHERE client_id = p_client_id
      AND status = 'delivered'
      AND (financial_settlement_status IS NULL OR financial_settlement_status != 'client_settled')
      AND (p_dc_id IS NULL OR distribution_center_id = p_dc_id);

    v_total_liquid_cash := v_cash_in_paystack + v_cash_in_dc_vault;

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
        'total_inventory_units_held', v_total_units_in_custody,
        'inventory_baseline_liquidation_value', v_base_inventory_valuation,
        'inventory_estimated_retail_value', v_weighted_retail_valuation,
        'grand_total_asset_value', (v_total_liquid_cash + v_weighted_retail_valuation)
    );
END;
$$;

-- 7. Hardened Stored Procedure: confirm_delivery_pod (incorporates transfer fee deduction for cash POD)
CREATE OR REPLACE FUNCTION public.confirm_delivery_pod(
    p_order_id UUID,
    p_agent_id UUID,
    p_payment_type VARCHAR,
    p_amount NUMERIC,
    p_proof_url TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_order RECORD;
    v_agent RECORD;
    v_commission NUMERIC;
    v_transport NUMERIC;
    v_earning NUMERIC;
    v_transfer_fee NUMERIC := 0.00;
    v_net_to_remit NUMERIC;
    v_new_cod_balance NUMERIC;
    v_new_direct_balance NUMERIC;
    v_amount_collected NUMERIC;
BEGIN
    SELECT * INTO v_order
    FROM public.orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Order not found.');
    END IF;

    SELECT * INTO v_agent
    FROM public.delivery_agents
    WHERE id = p_agent_id;

    v_commission := COALESCE(v_agent.commission_rate, CASE WHEN v_agent.personnel_type = 'in_house_rider' THEN 500.00 ELSE 1000.00 END);
    v_transport := CASE WHEN v_agent.personnel_type = 'in_house_rider' THEN COALESCE(v_agent.fuel_allowance, 800.00) ELSE COALESCE(v_agent.transport_allowance, 1500.00) END;
    v_earning := v_commission + v_transport;
    v_amount_collected := COALESCE(p_amount, v_order.total_amount, 0.00);

    -- Update Order Status
    UPDATE public.orders
    SET 
        status = 'delivered',
        payment_status = CASE WHEN p_payment_type = 'pay_on_delivery' THEN 'collected' ELSE 'paid' END,
        remittance_status = CASE WHEN p_payment_type = 'pay_on_delivery' THEN 'unremitted' ELSE 'direct_transfer' END,
        financial_settlement_status = CASE WHEN p_payment_type = 'pay_on_delivery' THEN 'in_dc_custody' ELSE 'direct_transfer_settled' END,
        proof_of_delivery_url = COALESCE(p_proof_url, proof_of_delivery_url),
        delivery_notes = COALESCE(p_notes, delivery_notes),
        payment_method = CASE WHEN p_payment_type = 'pay_on_delivery' THEN 'cash' ELSE 'paystack' END,
        delivered_at = NOW(),
        updated_at = NOW()
    WHERE id = p_order_id;

    -- Financial Balance Allocation
    IF p_payment_type = 'pay_on_delivery' OR v_order.payment_type = 'pay_on_delivery' THEN
        -- Dynamic transfer charge: ₦100 per ₦5,000 block
        v_transfer_fee := CEIL(v_amount_collected / 5000.0) * 100.00;
        v_net_to_remit := GREATEST(0.00, v_amount_collected - v_earning - v_transfer_fee);
        
        UPDATE public.delivery_agents
        SET 
            current_cod_balance = COALESCE(current_cod_balance, 0.00) + v_net_to_remit,
            updated_at = NOW()
        WHERE id = p_agent_id
        RETURNING current_cod_balance, direct_transfer_balance INTO v_new_cod_balance, v_new_direct_balance;
    ELSE
        UPDATE public.delivery_agents
        SET 
            direct_transfer_balance = COALESCE(direct_transfer_balance, 0.00) + v_earning,
            updated_at = NOW()
        WHERE id = p_agent_id
        RETURNING current_cod_balance, direct_transfer_balance INTO v_new_cod_balance, v_new_direct_balance;

        INSERT INTO public.rider_transactions (
            delivery_agent_id,
            transaction_code,
            title,
            category,
            amount,
            is_credit,
            reference,
            status,
            description,
            created_at
        ) VALUES (
            p_agent_id,
            CONCAT('TXN-', SUBSTRING(CAST(EXTRACT(EPOCH FROM NOW()) AS TEXT), 6, 6)),
            'Direct Transfer Delivery Credited',
            'direct_transfer',
            v_earning,
            true,
            COALESCE(v_order.order_number, CAST(p_order_id AS TEXT)),
            'settled',
            CONCAT('Commission (₦', v_commission, ') + Transport (₦', v_transport, ') credited to My Balance from direct company transfer.'),
            NOW()
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'status', 'delivered',
        'current_cod_balance', v_new_cod_balance,
        'direct_transfer_balance', v_new_direct_balance,
        'rider_earning', v_earning,
        'transfer_fee_retained', v_transfer_fee,
        'message', 'Delivery confirmed and financial balance updated.'
    );
END;
$$;

-- 8. Grants and Permissions
GRANT EXECUTE ON FUNCTION public.fn_approve_cash_remittance(UUID, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_generate_merchant_daily_settlement(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, JSONB) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_calculate_merchant_asset_custody(UUID, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.confirm_delivery_pod(UUID, UUID, VARCHAR, NUMERIC, TEXT, TEXT) TO authenticated, service_role;

GRANT SELECT, INSERT, UPDATE ON public.cash_remittances TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE ON public.remittance_orders TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE ON public.client_settlements TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE ON public.payout_requests TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE ON public.dc_finance_settings TO authenticated, service_role;
