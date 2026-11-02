-- ==============================================================================
-- Migration: 20261101140000_create_client_accountants_table.sql
-- Description: Create client_accountants table for merchant finance team members
-- Author: NoveXPS Autonomous Architecture
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.client_accountants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    accountant_code TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    can_approve_settlements BOOLEAN NOT NULL DEFAULT true,
    can_manage_expenses BOOLEAN NOT NULL DEFAULT true,
    can_disburse_payouts BOOLEAN NOT NULL DEFAULT true,
    total_settlements_validated INTEGER NOT NULL DEFAULT 0,
    total_amount_validated NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    avatar_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_client_accountants_client_id ON public.client_accountants(client_id);
CREATE INDEX IF NOT EXISTS idx_client_accountants_user_id ON public.client_accountants(user_id);
CREATE INDEX IF NOT EXISTS idx_client_accountants_accountant_code ON public.client_accountants(accountant_code);

ALTER TABLE public.client_accountants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all access to client_accountants" ON public.client_accountants FOR ALL USING (true) WITH CHECK (true);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'client_accountants'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.client_accountants;
    END IF;
END $$;

