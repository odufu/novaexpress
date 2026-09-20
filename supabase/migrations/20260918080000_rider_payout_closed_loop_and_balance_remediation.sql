-- ============================================================================
-- Migration: 20260918080000_rider_payout_closed_loop_and_balance_remediation.sql
-- Description:
-- 1. Adds rider_confirmed_at and rider_confirmation_notes to payout_requests.
-- 2. Enhances log_delivery_failure to credit the rider's direct_transfer_balance
--    with their failed_delivery_allowance and log an audit transaction.
-- 3. Adds fn_rider_confirm_payout_receipt stored procedure to allow riders
--    to acknowledge bank disbursement and complete the payout cycle.
-- 4. Ensures confirm_delivery_pod strictly isolates COD vs Direct Transfers.
-- ============================================================================

-- 1. Add confirmation tracking columns to payout_requests
ALTER TABLE IF EXISTS public.payout_requests 
ADD COLUMN IF NOT EXISTS rider_confirmed_at TIMESTAMPTZ;

ALTER TABLE IF EXISTS public.payout_requests 
ADD COLUMN IF NOT EXISTS rider_confirmation_notes TEXT;

-- 2. Enhanced log_delivery_failure with failed delivery allowance credit
CREATE OR REPLACE FUNCTION public.log_delivery_failure(
    p_order_id UUID,
    p_agent_id UUID,
    p_reason_code VARCHAR,
    p_reschedule_time TIMESTAMPTZ DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_new_status VARCHAR;
    v_agent RECORD;
    v_order RECORD;
    v_failed_allowance NUMERIC(14,2) := 0.00;
    v_new_balance NUMERIC(14,2) := 0.00;
BEGIN
    SELECT * INTO v_agent FROM public.delivery_agents WHERE id = p_agent_id;
    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;

    IF p_reason_code = 'rescheduled' OR p_reason_code = 'customer_callback' OR p_reschedule_time IS NOT NULL THEN
        v_new_status := 'call_back';
    ELSE
        v_new_status := 'cancelled';
    END IF;

    UPDATE public.orders
    SET 
        status = v_new_status,
        scheduled_callback_at = p_reschedule_time,
        reschedule_note = p_reason_code,
        delivery_notes = COALESCE(p_notes, delivery_notes),
        updated_at = NOW()
    WHERE id = p_order_id;

    INSERT INTO public.order_activities (
        order_id,
        user_id,
        activity_type,
        notes,
        created_at
    ) VALUES (
        p_order_id,
        v_agent.user_id,
        'delivery_failed',
        CONCAT('Delivery attempt failed: [', p_reason_code, '] ', COALESCE(p_notes, '')),
        NOW()
    );

    -- Credit Rider's direct_transfer_balance with failed delivery allowance
    v_failed_allowance := COALESCE(v_agent.failed_delivery_allowance, 500.00);
    IF v_failed_allowance > 0.00 THEN
        UPDATE public.delivery_agents
        SET 
            direct_transfer_balance = COALESCE(direct_transfer_balance, 0.00) + v_failed_allowance,
            updated_at = NOW()
        WHERE id = p_agent_id
        RETURNING direct_transfer_balance INTO v_new_balance;

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
            CONCAT('TXN-FAIL-', TO_CHAR(NOW(), 'YYYYMMDD'), '-', SUBSTRING(p_order_id::TEXT FROM 1 FOR 4)),
            'Failed Delivery Stipend',
            'failed_delivery_stipend',
            v_failed_allowance,
            TRUE,
            COALESCE(v_order.order_number, SUBSTRING(p_order_id::TEXT FROM 1 FOR 8)),
            'completed',
            CONCAT('Transport stipend for failed attempt [', p_reason_code, '] on order ', COALESCE(v_order.order_number, '')),
            NOW()
        );
    ELSE
        v_new_balance := COALESCE(v_agent.direct_transfer_balance, 0.00);
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'status', v_new_status,
        'failed_delivery_stipend', v_failed_allowance,
        'direct_transfer_balance', v_new_balance,
        'message', 'Delivery failure recorded, attempt stipend credited to My Balance.'
    );
END;
$$;

-- 3. Rider Confirm Payout Receipt RPC
CREATE OR REPLACE FUNCTION public.fn_rider_confirm_payout_receipt(
    p_payout_id UUID,
    p_agent_id UUID,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_payout RECORD;
BEGIN
    SELECT * INTO v_payout
    FROM public.payout_requests
    WHERE id = p_payout_id AND (delivery_agent_id = p_agent_id OR p_agent_id IS NULL);

    IF v_payout.id IS NULL THEN
        SELECT * INTO v_payout FROM public.payout_requests WHERE id = p_payout_id;
        IF v_payout.id IS NULL THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Payout request not found.'
            );
        END IF;
    END IF;

    UPDATE public.payout_requests
    SET 
        status = 'completed',
        rider_confirmed_at = NOW(),
        rider_confirmation_notes = COALESCE(p_notes, 'Confirmed received by rider in PDA app'),
        updated_at = NOW()
    WHERE id = p_payout_id;

    -- Update any corresponding rider_transactions audit log to settled
    UPDATE public.rider_transactions
    SET 
        status = 'settled',
        description = CONCAT(description, ' [Rider Confirmed Receipt at ', TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI'), ']')
    WHERE delivery_agent_id = v_payout.delivery_agent_id
      AND (reference = v_payout.payout_number OR reference = v_payout.disbursement_ref);

    RETURN jsonb_build_object(
        'success', true,
        'payout_id', p_payout_id,
        'payout_number', v_payout.payout_number,
        'status', 'completed',
        'confirmed_at', NOW(),
        'message', 'Payout receipt successfully confirmed by rider.'
    );
END;
$$;

-- 4. Strict confirm_delivery_pod isolating COD from direct transfer
CREATE OR REPLACE FUNCTION public.confirm_delivery_pod(
    p_order_id UUID,
    p_agent_id UUID,
    p_proof_url TEXT,
    p_notes TEXT DEFAULT NULL,
    p_amount NUMERIC DEFAULT NULL,
    p_payment_type VARCHAR DEFAULT 'pay_on_delivery'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_order RECORD;
    v_agent RECORD;
    v_commission NUMERIC := 0.00;
    v_transport NUMERIC := 0.00;
    v_earning NUMERIC := 0.00;
    v_net_to_remit NUMERIC := 0.00;
    v_new_cod_balance NUMERIC := 0.00;
    v_new_direct_balance NUMERIC := 0.00;
BEGIN
    SELECT * INTO v_order
    FROM public.orders
    WHERE id = p_order_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Order not found');
    END IF;

    SELECT * INTO v_agent
    FROM public.delivery_agents
    WHERE id = p_agent_id;

    v_commission := COALESCE(v_agent.commission_rate, CASE WHEN v_agent.personnel_type = 'in_house_rider' THEN 500 ELSE 1000 END);
    v_transport := CASE WHEN v_agent.personnel_type = 'in_house_rider' THEN COALESCE(v_agent.fuel_allowance, 800) ELSE COALESCE(v_agent.transport_allowance, 1500) END;
    v_earning := v_commission + v_transport;

    UPDATE public.orders
    SET 
        status = 'delivered',
        payment_status = 'collected',
        proof_of_delivery_url = COALESCE(p_proof_url, proof_of_delivery_url),
        delivery_notes = COALESCE(p_notes, delivery_notes),
        delivered_at = NOW(),
        updated_at = NOW()
    WHERE id = p_order_id;

    IF v_order.product_id IS NOT NULL THEN
        UPDATE public.products
        SET 
            available_count = GREATEST(0, COALESCE(available_count, 0) - COALESCE(v_order.quantity, 1)),
            delivered_count = COALESCE(delivered_count, 0) + COALESCE(v_order.quantity, 1)
        WHERE id = v_order.product_id;
    END IF;

    IF p_payment_type = 'pay_on_delivery' OR v_order.payment_type = 'pay_on_delivery' THEN
        -- COD: Net cash collected is added to current_cod_balance for DC remittance.
        -- MY BALANCE (direct_transfer_balance) is untouched because the rider already retained earnings from cash.
        v_net_to_remit := GREATEST(0, COALESCE(p_amount, v_order.total_amount) - v_earning);
        
        UPDATE public.delivery_agents
        SET current_cod_balance = current_cod_balance + v_net_to_remit
        WHERE id = p_agent_id
        RETURNING current_cod_balance, direct_transfer_balance INTO v_new_cod_balance, v_new_direct_balance;
    ELSE
        -- Non-COD (Prepaid/Transfer): Customer paid company directly.
        -- MY BALANCE (direct_transfer_balance) is credited with rider's entitlement.
        -- current_cod_balance is untouched.
        UPDATE public.delivery_agents
        SET direct_transfer_balance = direct_transfer_balance + v_earning
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
            CONCAT('TXN-EARN-', TO_CHAR(NOW(), 'YYYYMMDD'), '-', SUBSTRING(p_order_id::TEXT FROM 1 FOR 4)),
            'Delivery Earning Credit',
            'delivery_earning',
            v_earning,
            TRUE,
            v_order.order_number,
            'completed',
            CONCAT('Delivery fee earned for ', v_order.order_number),
            NOW()
        );
    END IF;

    INSERT INTO public.order_activities (
        order_id,
        user_id,
        activity_type,
        notes,
        created_at
    ) VALUES (
        p_order_id,
        v_agent.user_id,
        'delivery_completed',
        CONCAT('Delivered by Agent. Payment: ₦', COALESCE(p_amount, v_order.total_amount), '. Rider Entitlement Retained: ₦', v_earning),
        NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'status', 'delivered',
        'current_cod_balance', v_new_cod_balance,
        'direct_transfer_balance', v_new_direct_balance,
        'rider_earning', v_earning,
        'message', 'Delivery confirmed and financial balance updated.'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.log_delivery_failure(UUID, UUID, VARCHAR, TIMESTAMPTZ, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_rider_confirm_payout_receipt(UUID, UUID, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.confirm_delivery_pod(UUID, UUID, TEXT, TEXT, NUMERIC, VARCHAR) TO authenticated, service_role, anon;
GRANT SELECT, INSERT, UPDATE ON public.payout_requests TO authenticated, service_role;

-- 6. Reload Schema Cache
NOTIFY pgrst, 'reload schema';
