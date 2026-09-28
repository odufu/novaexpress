-- ============================================================================
-- Migration: 20260928093000_marketer_payouts_and_detail_management.sql
-- Description:
--   1. Extends client_marketers with unpaid_commission_balance and total_paid_commission.
--   2. Updates fn_handle_order_delivery_marketer_lifecycle to accrue unpaid_commission_balance.
--   3. Creates public.marketer_payouts table for commission disbursements.
--   4. Creates stored procedure fn_disburse_marketer_payout.
--   5. Creates stored procedure fn_delete_marketer.
--   6. Configures Realtime sockets publication for marketer_payouts.
-- ============================================================================

-- 1. Extend client_marketers with commission balance columns
ALTER TABLE public.client_marketers
  ADD COLUMN IF NOT EXISTS unpaid_commission_balance NUMERIC(14,2) DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS total_paid_commission NUMERIC(14,2) DEFAULT 0.00;

-- Backfill existing balances
UPDATE public.client_marketers
SET unpaid_commission_balance = GREATEST(0.00, COALESCE(total_commission_earned, 0.00) - COALESCE(total_paid_commission, 0.00)),
    total_paid_commission = COALESCE(total_paid_commission, 0.00);

-- 2. Update fn_handle_order_delivery_marketer_lifecycle to update unpaid_commission_balance
CREATE OR REPLACE FUNCTION public.fn_handle_order_delivery_marketer_lifecycle()
RETURNS TRIGGER AS $$
DECLARE
    v_marketer RECORD;
    v_commission_amount NUMERIC := 0.00;
    v_form RECORD;
BEGIN
    -- Only fire when status transitions to 'delivered' or 'completed'
    IF (OLD.status IS DISTINCT FROM NEW.status) AND (LOWER(NEW.status) IN ('delivered', 'completed')) THEN
        
        -- A. If order has an attached Digital Marketer
        IF NEW.marketer_id IS NOT NULL THEN
            SELECT * INTO v_marketer FROM public.client_marketers WHERE id = NEW.marketer_id;
            
            IF v_marketer.id IS NOT NULL THEN
                -- Compute delivery commission if model is per_delivered_order
                IF COALESCE(v_marketer.commission_type, v_marketer.commission_model) = 'per_delivered_order' OR COALESCE(v_marketer.commission_per_delivered_order, 0) > 0 THEN
                    v_commission_amount := COALESCE(NULLIF(v_marketer.commission_per_delivered_order, 0), NULLIF(v_marketer.commission_rate, 0), 2000.00);
                END IF;

                -- Update marketer performance stats & earned balance
                UPDATE public.client_marketers
                SET total_orders_delivered = COALESCE(total_orders_delivered, 0) + 1,
                    total_commission_earned = COALESCE(total_commission_earned, 0) + v_commission_amount,
                    unpaid_commission_balance = COALESCE(unpaid_commission_balance, 0) + v_commission_amount,
                    updated_at = NOW()
                WHERE id = v_marketer.id;

                -- Update linked lead_form delivery count if form_id is present
                IF NEW.form_id IS NOT NULL THEN
                    UPDATE public.lead_forms
                    SET total_orders_delivered = COALESCE(total_orders_delivered, 0) + 1,
                        updated_at = NOW()
                    WHERE id = NEW.form_id;
                END IF;

                -- Send in-app push notification to the marketer
                IF v_marketer.user_id IS NOT NULL THEN
                    INSERT INTO public.notifications (
                        company_id,
                        user_id,
                        title,
                        message,
                        category,
                        action_route,
                        is_read,
                        created_at
                    ) VALUES (
                        COALESCE(NEW.client_id, '11111111-1111-4111-8111-111111111111'),
                        v_marketer.user_id,
                        'Buyer Received Delivery! 📦🎉',
                        'Ad Order #' || NEW.order_number || ' (' || NEW.customer_name || ' in ' || COALESCE(NEW.delivery_lga, NEW.delivery_city, 'LGA') || ') was delivered and confirmed by rider.' ||
                        CASE WHEN v_commission_amount > 0 THEN ' Commission of ₦' || v_commission_amount || ' credited.' ELSE '' END,
                        'marketing',
                        '/marketing',
                        false,
                        NOW()
                    );
                END IF;
            END IF;
        END IF;

        -- B. Post Lifecycle Milestone message into Pipeline Chat
        BEGIN
            PERFORM public.fn_sync_order_conversation(
                NEW.id,
                'System Notification',
                'system',
                '✅ Package Delivered & Received: Order #' || NEW.order_number || ' (' || NEW.product_name || ') has been successfully delivered to customer with verified POD.',
                NULL
            );
        EXCEPTION WHEN OTHERS THEN
            NULL; -- Non-blocking for conversation chat sync
        END;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create public.marketer_payouts Table
CREATE TABLE IF NOT EXISTS public.marketer_payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    marketer_id UUID NOT NULL REFERENCES public.client_marketers(id) ON DELETE CASCADE,
    client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    payout_number TEXT NOT NULL UNIQUE,
    amount NUMERIC(14,2) NOT NULL,
    orders_count INT NOT NULL DEFAULT 0,
    order_ids UUID[] DEFAULT '{}',
    bank_name TEXT NOT NULL,
    account_number TEXT NOT NULL,
    account_name TEXT NOT NULL,
    disbursement_ref TEXT,
    proof_of_payment_url TEXT,
    status TEXT NOT NULL DEFAULT 'remitted', -- pending, remitted, completed, rejected
    disbursed_at TIMESTAMPTZ DEFAULT NOW(),
    confirmed_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_marketer_payouts_marketer_id ON public.marketer_payouts(marketer_id);
CREATE INDEX IF NOT EXISTS idx_marketer_payouts_client_id ON public.marketer_payouts(client_id);
CREATE INDEX IF NOT EXISTS idx_marketer_payouts_status ON public.marketer_payouts(status);

-- Enable RLS
ALTER TABLE public.marketer_payouts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public access to marketer_payouts" ON public.marketer_payouts;
CREATE POLICY "Public access to marketer_payouts" ON public.marketer_payouts
    FOR ALL TO authenticated, service_role, anon
    USING (true)
    WITH CHECK (true);

-- 4. Stored Procedure: fn_disburse_marketer_payout
CREATE OR REPLACE FUNCTION public.fn_disburse_marketer_payout(
    p_marketer_id UUID,
    p_client_id UUID,
    p_amount NUMERIC,
    p_orders_count INT DEFAULT 0,
    p_order_ids UUID[] DEFAULT '{}',
    p_bank_name TEXT DEFAULT '',
    p_account_number TEXT DEFAULT '',
    p_account_name TEXT DEFAULT '',
    p_disbursement_ref TEXT DEFAULT '',
    p_proof_of_payment_url TEXT DEFAULT '',
    p_notes TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_payout_id UUID := gen_random_uuid();
    v_payout_number TEXT;
    v_marketer RECORD;
BEGIN
    SELECT * INTO v_marketer FROM public.client_marketers WHERE id = p_marketer_id;
    IF v_marketer.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Marketer not found.');
    END IF;

    -- Generate Unique Payout Number
    v_payout_number := 'MPAY-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');

    -- Insert payout record
    INSERT INTO public.marketer_payouts (
        id,
        marketer_id,
        client_id,
        payout_number,
        amount,
        orders_count,
        order_ids,
        bank_name,
        account_number,
        account_name,
        disbursement_ref,
        proof_of_payment_url,
        status,
        disbursed_at,
        notes
    ) VALUES (
        v_payout_id,
        p_marketer_id,
        p_client_id,
        v_payout_number,
        p_amount,
        p_orders_count,
        p_order_ids,
        COALESCE(NULLIF(p_bank_name, ''), v_marketer.bank_name, 'Bank Transfer'),
        COALESCE(NULLIF(p_account_number, ''), v_marketer.account_number, ''),
        COALESCE(NULLIF(p_account_name, ''), v_marketer.account_name, v_marketer.full_name),
        p_disbursement_ref,
        p_proof_of_payment_url,
        'remitted',
        NOW(),
        p_notes
    );

    -- Update marketer balances
    UPDATE public.client_marketers
    SET 
        total_paid_commission = COALESCE(total_paid_commission, 0.00) + p_amount,
        unpaid_commission_balance = GREATEST(0.00, COALESCE(unpaid_commission_balance, 0.00) - p_amount),
        updated_at = NOW()
    WHERE id = p_marketer_id;

    -- In-app notification to marketer
    IF v_marketer.user_id IS NOT NULL THEN
        INSERT INTO public.notifications (
            company_id,
            user_id,
            title,
            message,
            category,
            action_route,
            is_read,
            created_at
        ) VALUES (
            p_client_id,
            v_marketer.user_id,
            'Commission Payout Disbursed 💰',
            'Your commission disbursement #' || v_payout_number || ' of ₦' || p_amount || ' has been sent to ' || COALESCE(v_marketer.bank_name, 'your bank account') || '.',
            'finance',
            '/marketing',
            false,
            NOW()
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'payout_id', v_payout_id,
        'payout_number', v_payout_number,
        'amount', p_amount,
        'status', 'remitted',
        'message', 'Marketer payout successfully remitted with attached receipt proof.'
    );
END;
$$;

-- 5. Stored Procedure: fn_delete_marketer (Safe deletion)
CREATE OR REPLACE FUNCTION public.fn_delete_marketer(p_marketer_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_marketer RECORD;
BEGIN
    SELECT * INTO v_marketer FROM public.client_marketers WHERE id = p_marketer_id;
    IF v_marketer.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Marketer not found.');
    END IF;

    -- Unlink active forms safely so history is preserved
    UPDATE public.lead_forms
    SET marketer_id = NULL
    WHERE marketer_id = p_marketer_id;

    -- Unlink orders safely
    UPDATE public.orders
    SET marketer_id = NULL
    WHERE marketer_id = p_marketer_id;

    -- Reassign subordinate supervisees to null
    UPDATE public.client_marketers
    SET supervisor_id = NULL
    WHERE supervisor_id = p_marketer_id;

    -- Deactivate associated auth user if exists
    IF v_marketer.user_id IS NOT NULL THEN
        UPDATE public.users
        SET is_active = false
        WHERE id = v_marketer.user_id;
    END IF;

    -- Delete marketer record (cascades to marketer_payouts)
    DELETE FROM public.client_marketers WHERE id = p_marketer_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Digital marketer deleted successfully and related references preserved.'
    );
END;
$$;

-- 6. Add marketer_payouts to Realtime Publication
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'marketer_payouts'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.marketer_payouts;
    END IF;
END $$;

-- 7. Grant Permissions
GRANT EXECUTE ON FUNCTION public.fn_disburse_marketer_payout TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_delete_marketer TO authenticated, service_role, anon;
GRANT ALL ON public.marketer_payouts TO authenticated, service_role, anon;

NOTIFY pgrst, 'reload schema';
