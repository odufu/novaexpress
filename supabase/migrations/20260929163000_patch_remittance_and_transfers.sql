-- Migration: Add missing remittance columns and relax legacy transfer not-null constraints
ALTER TABLE IF EXISTS public.cash_remittances
    ADD COLUMN IF NOT EXISTS pos_fee NUMERIC(14,2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS verified_by_user_id UUID REFERENCES public.users(id);

ALTER TABLE IF EXISTS public.stock_transfers
    ALTER COLUMN initiated_by_user_id DROP NOT NULL;

NOTIFY pgrst, 'reload schema';
