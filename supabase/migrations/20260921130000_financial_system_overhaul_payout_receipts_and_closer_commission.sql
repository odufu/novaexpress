-- Migration: 20260921130000_financial_system_overhaul_payout_receipts_and_closer_commission.sql
-- Description: 
-- 1. Adds proof_of_payment_url to payout_requests for Rider Payout parity.
-- 2. Adds is_commission_enabled, bank details, and balance tracking to client_closers.
-- 3. Creates closer_payouts table for Telesales Closer Commission Disbursements.
-- 4. Stored procedures for Closer Payouts and Rider COD earnings parity.

-- 1. Rider Payout Proof Parity
ALTER TABLE IF EXISTS public.payout_requests 
ADD COLUMN IF NOT EXISTS proof_of_payment_url TEXT,
ADD COLUMN IF NOT EXISTS disbursed_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- 2. Optional Closer Commission & Bank Details on client_closers
ALTER TABLE IF EXISTS public.client_closers 
ADD COLUMN IF NOT EXISTS is_commission_enabled BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS bank_name TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS account_number TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS account_name TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS unpaid_commission_balance NUMERIC(14,2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS total_paid_commission NUMERIC(14,2) DEFAULT 0.00;

-- 3. Closer Payouts Table
CREATE TABLE IF NOT EXISTS public.closer_payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    closer_id UUID NOT NULL REFERENCES public.client_closers(id) ON DELETE CASCADE,
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

-- Indexes for fast closer payout querying
CREATE INDEX IF NOT EXISTS idx_closer_payouts_closer_id ON public.closer_payouts(closer_id);
CREATE INDEX IF NOT EXISTS idx_closer_payouts_client_id ON public.closer_payouts(client_id);
CREATE INDEX IF NOT EXISTS idx_closer_payouts_status ON public.closer_payouts(status);

-- Enable RLS
ALTER TABLE public.closer_payouts ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Public access to closer_payouts" ON public.closer_payouts;
CREATE POLICY "Public access to closer_payouts" ON public.closer_payouts
    FOR ALL TO authenticated, service_role, anon
    USING (true)
    WITH CHECK (true);

-- 4. Stored Procedure: fn_disburse_closer_payout
CREATE OR REPLACE FUNCTION public.fn_disburse_closer_payout(
    p_closer_id UUID,
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
    v_closer RECORD;
BEGIN
    SELECT * INTO v_closer FROM public.client_closers WHERE id = p_closer_id;
    IF v_closer.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Closer not found.');
    END IF;

    -- Generate Unique Payout Number
    v_payout_number := 'CPAY-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');

    -- Insert payout record
    INSERT INTO public.closer_payouts (
        id,
        closer_id,
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
        p_closer_id,
        p_client_id,
        v_payout_number,
        p_amount,
        p_orders_count,
        p_order_ids,
        COALESCE(NULLIF(p_bank_name, ''), v_closer.bank_name, 'Bank Transfer'),
        COALESCE(NULLIF(p_account_number, ''), v_closer.account_number, ''),
        COALESCE(NULLIF(p_account_name, ''), v_closer.account_name, v_closer.full_name),
        p_disbursement_ref,
        p_proof_of_payment_url,
        'remitted',
        NOW(),
        p_notes
    );

    -- Update closer balances
    UPDATE public.client_closers
    SET 
        total_paid_commission = COALESCE(total_paid_commission, 0.00) + p_amount,
        unpaid_commission_balance = GREATEST(0.00, COALESCE(unpaid_commission_balance, 0.00) - p_amount),
        updated_at = NOW()
    WHERE id = p_closer_id;

    RETURN jsonb_build_object(
        'success', true,
        'payout_id', v_payout_id,
        'payout_number', v_payout_number,
        'amount', p_amount,
        'status', 'remitted',
        'message', 'Closer payout successfully remitted with attached receipt proof.'
    );
END;
$$;

-- 5. Stored Procedure: fn_closer_confirm_payout
CREATE OR REPLACE FUNCTION public.fn_closer_confirm_payout(
    p_payout_id UUID,
    p_closer_id UUID,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_payout RECORD;
BEGIN
    SELECT * INTO v_payout FROM public.closer_payouts WHERE id = p_payout_id AND closer_id = p_closer_id;
    IF v_payout.id IS NULL THEN
        SELECT * INTO v_payout FROM public.closer_payouts WHERE id = p_payout_id;
        IF v_payout.id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'Closer payout not found.');
        END IF;
    END IF;

    UPDATE public.closer_payouts
    SET 
        status = 'completed',
        confirmed_at = NOW(),
        notes = COALESCE(p_notes, notes),
        updated_at = NOW()
    WHERE id = p_payout_id;

    RETURN jsonb_build_object(
        'success', true,
        'payout_id', p_payout_id,
        'payout_number', v_payout.payout_number,
        'status', 'completed',
        'message', 'Payout confirmation recorded successfully.'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_disburse_closer_payout TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_closer_confirm_payout TO authenticated, service_role, anon;
GRANT ALL ON public.closer_payouts TO authenticated, service_role, anon;

NOTIFY pgrst, 'reload schema';
