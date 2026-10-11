-- ============================================================================
-- MIGRATION: 20261011163000_fix_pod_signature_column_in_otp_rpc.sql
-- DESCRIPTION: Use proof_of_delivery_url in fn_verify_delivery_otp_and_complete
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_verify_delivery_otp_and_complete(
    p_order_id UUID,
    p_entered_otp TEXT,
    p_agent_id UUID,
    p_recipient_signature_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_expected_otp TEXT;
    v_rider_allowance NUMERIC(12, 2);
    v_fulfillment_type TEXT;
BEGIN
    SELECT delivery_otp, rider_pickup_allowance, fulfillment_type
    INTO v_expected_otp, v_rider_allowance, v_fulfillment_type
    FROM public.orders
    WHERE id = p_order_id;

    IF v_expected_otp IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Order not found.');
    END IF;

    IF trim(v_expected_otp) != trim(p_entered_otp) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Invalid OTP! Recipient verification failed.');
    END IF;

    -- Update order to delivered using proof_of_delivery_url
    UPDATE public.orders
    SET status = 'delivered',
        delivered_at = NOW(),
        otp_verified_at = NOW(),
        proof_of_delivery_url = COALESCE(p_recipient_signature_url, proof_of_delivery_url)
    WHERE id = p_order_id;

    -- If this was a client package with extra rider allowance, credit the rider
    IF v_fulfillment_type = 'client_package' AND v_rider_allowance > 0 THEN
        UPDATE public.delivery_agents
        SET current_balance = COALESCE(current_balance, 0.00) + v_rider_allowance
        WHERE id = p_agent_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Delivery completed and verified via OTP.',
        'order_id', p_order_id,
        'rider_credited_amount', v_rider_allowance
    );
END;
$$;

SELECT pg_notify('pgrst', 'reload schema');
