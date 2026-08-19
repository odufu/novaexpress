-- ============================================================================
-- NovaExpress Logistics Management System
-- Schema Enhancements, Ledger Triggers, and Stored Procedures for PDA App
-- ============================================================================

-- 1. Ensure extensions exist
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Stored Procedure: Confirm Delivery POD (Atomic Execution)
CREATE OR REPLACE FUNCTION confirm_delivery_pod(
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
    v_net_to_remit NUMERIC;
    v_new_cod_balance NUMERIC;
    v_new_direct_balance NUMERIC;
BEGIN
    -- 1. Verify order existence and assignment
    SELECT * INTO v_order
    FROM orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Order not found.'
        );
    END IF;

    -- 2. Fetch Agent Details & Calculate Entitlement
    SELECT * INTO v_agent
    FROM delivery_agents
    WHERE id = p_agent_id;

    v_commission := COALESCE(v_agent.commission_rate, CASE WHEN v_agent.personnel_type = 'in_house_rider' THEN 500 ELSE 1000 END);
    v_transport := CASE WHEN v_agent.personnel_type = 'in_house_rider' THEN COALESCE(v_agent.fuel_allowance, 800) ELSE COALESCE(v_agent.transport_allowance, 1500) END;
    v_earning := v_commission + v_transport;

    -- 3. Update Order Status
    UPDATE orders
    SET 
        status = 'delivered',
        payment_status = 'collected',
        proof_of_delivery_url = COALESCE(p_proof_url, proof_of_delivery_url),
        delivery_notes = COALESCE(p_notes, delivery_notes),
        updated_at = NOW()
    WHERE id = p_order_id;

    -- 3b. Inventory Custody Settlement: Deduct delivered product stock
    IF v_order.product_id IS NOT NULL THEN
        UPDATE products
        SET 
            available_count = GREATEST(0, COALESCE(available_count, 0) - COALESCE(v_order.quantity, 1)),
            delivered_count = COALESCE(delivered_count, 0) + COALESCE(v_order.quantity, 1)
        WHERE id = v_order.product_id;
    END IF;

    -- 4. Financial Ledger Settlement:
    -- If Cash POD: Rider retains earnings directly from cash. Cash to remit = amountCollected - v_earning
    -- If Non-Cash (Prepaid / Transfer / POS): Rider collected 0 cash; Company credits My Balance (direct_transfer_balance)
    IF p_payment_type = 'pay_on_delivery' OR v_order.payment_type = 'pay_on_delivery' THEN
        v_net_to_remit := GREATEST(0, COALESCE(p_amount, v_order.total_amount) - v_earning);
        
        UPDATE delivery_agents
        SET current_cod_balance = current_cod_balance + v_net_to_remit
        WHERE id = p_agent_id
        RETURNING current_cod_balance, direct_transfer_balance INTO v_new_cod_balance, v_new_direct_balance;
    ELSE
        UPDATE delivery_agents
        SET direct_transfer_balance = direct_transfer_balance + v_earning
        WHERE id = p_agent_id
        RETURNING current_cod_balance, direct_transfer_balance INTO v_new_cod_balance, v_new_direct_balance;

        -- Record transaction credit for rider
        INSERT INTO rider_transactions (
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

    -- 5. Record Activity in Audit Log
    INSERT INTO order_activities (
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

-- 3. Stored Procedure: Log Delivery Failure / Reschedule
CREATE OR REPLACE FUNCTION log_delivery_failure(
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
BEGIN
    IF p_reason_code = 'rescheduled' OR p_reason_code = 'customer_callback' OR p_reschedule_time IS NOT NULL THEN
        v_new_status := 'call_back';
    ELSE
        v_new_status := 'cancelled';
    END IF;

    UPDATE orders
    SET 
        status = v_new_status,
        scheduled_callback_at = p_reschedule_time,
        reschedule_note = p_reason_code,
        delivery_notes = COALESCE(p_notes, delivery_notes),
        updated_at = NOW()
    WHERE id = p_order_id;

    -- Record Activity Audit
    INSERT INTO order_activities (
        order_id,
        user_id,
        activity_type,
        notes,
        created_at
    ) VALUES (
        p_order_id,
        (SELECT user_id FROM delivery_agents WHERE id = p_agent_id),
        'delivery_failed',
        CONCAT('Delivery attempt failed: [', p_reason_code, '] ', COALESCE(p_notes, '')),
        NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'status', v_new_status,
        'message', 'Delivery failure recorded and logged.'
    );
END;
$$;
