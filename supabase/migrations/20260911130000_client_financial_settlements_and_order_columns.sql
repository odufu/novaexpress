-- ============================================================================
-- NOVAXPRESS LOGISTICS PLATFORM - CLIENT FINANCIAL SETTLEMENTS & ORDER SCHEMA
-- Migration for:
--   1. First-class financial, remittance, and product columns on `orders` table
--   2. Client Payout Bank Account details on `clients` table
--   3. `client_settlements` table (DC / Platform -> Merchant Settlement Ledger)
--   4. Backfilling historical order remittance and client tenant attribution
-- ============================================================================

-- 1. Add missing financial, remittance, and product columns to orders
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS remittance_status TEXT DEFAULT 'unremitted',
  ADD COLUMN IF NOT EXISTS financial_settlement_status TEXT DEFAULT 'pending_remittance',
  ADD COLUMN IF NOT EXISTS remittance_reference TEXT,
  ADD COLUMN IF NOT EXISTS remitted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS product_sku TEXT,
  ADD COLUMN IF NOT EXISTS package_deal_id TEXT,
  ADD COLUMN IF NOT EXISTS package_deal_name TEXT,
  ADD COLUMN IF NOT EXISTS client_name TEXT DEFAULT 'Novacale Limited',
  ADD COLUMN IF NOT EXISTS client_company TEXT DEFAULT 'Novacale Limited';

CREATE INDEX IF NOT EXISTS idx_orders_remittance_status ON public.orders(remittance_status);
CREATE INDEX IF NOT EXISTS idx_orders_financial_settlement_status ON public.orders(financial_settlement_status);
CREATE INDEX IF NOT EXISTS idx_orders_client_product ON public.orders(client_id, product_name);
CREATE INDEX IF NOT EXISTS idx_orders_delivered_at ON public.orders(delivered_at);

-- 2. Add merchant payout bank account details to clients
ALTER TABLE public.clients
  ADD COLUMN IF NOT EXISTS bank_name TEXT DEFAULT 'Zenith Bank',
  ADD COLUMN IF NOT EXISTS account_number TEXT DEFAULT '1012345678',
  ADD COLUMN IF NOT EXISTS account_name TEXT DEFAULT 'Novacale Limited',
  ADD COLUMN IF NOT EXISTS settlement_frequency TEXT DEFAULT 'weekly',
  ADD COLUMN IF NOT EXISTS settlement_day TEXT DEFAULT 'Friday';

-- Update default Novacale Limited client profile with explicit settlement bank details
UPDATE public.clients
SET
  bank_name = 'Zenith Bank',
  account_number = '1012345678',
  account_name = 'Novacale Limited',
  settlement_frequency = 'weekly',
  settlement_day = 'Friday'
WHERE id = '33333333-3333-4333-8333-333333333333'::uuid;

-- 3. Create client_settlements table (Platform / DC -> Merchant Ledger)
CREATE TABLE IF NOT EXISTS public.client_settlements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  settlement_number TEXT UNIQUE NOT NULL, -- e.g. 'SETTLE-NOV-2026-001'
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  company_id UUID REFERENCES public.companies(id),
  period_start TIMESTAMPTZ,
  period_end TIMESTAMPTZ,
  total_orders_count INT NOT NULL DEFAULT 0,
  gross_collections NUMERIC(14,2) NOT NULL DEFAULT 0.00,
  logistics_fees_deducted NUMERIC(14,2) NOT NULL DEFAULT 0.00,
  net_payout_amount NUMERIC(14,2) NOT NULL DEFAULT 0.00,
  destination_bank_name TEXT,
  destination_account_number TEXT,
  destination_account_name TEXT,
  payout_reference TEXT,
  proof_of_payment_url TEXT,
  status TEXT DEFAULT 'completed', -- 'pending', 'processing', 'completed', 'disputed'
  notes TEXT,
  settled_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_client_settlements_client_id ON public.client_settlements(client_id);
CREATE INDEX IF NOT EXISTS idx_client_settlements_settled_at ON public.client_settlements(settled_at);

-- 4. Enable Row Level Security on client_settlements
ALTER TABLE public.client_settlements ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'client_settlements' AND policyname = 'Allow public select on client_settlements'
  ) THEN
    CREATE POLICY "Allow public select on client_settlements" ON public.client_settlements FOR SELECT USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'client_settlements' AND policyname = 'Allow authenticated insert on client_settlements'
  ) THEN
    CREATE POLICY "Allow authenticated insert on client_settlements" ON public.client_settlements FOR INSERT WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'client_settlements' AND policyname = 'Allow authenticated update on client_settlements'
  ) THEN
    CREATE POLICY "Allow authenticated update on client_settlements" ON public.client_settlements FOR UPDATE USING (true);
  END IF;
END $$;

-- 5. Backfill historical orders data for consistent reporting
UPDATE public.orders
SET 
  client_id = '33333333-3333-4333-8333-333333333333'::uuid,
  client_name = 'Novacale Limited',
  client_company = 'Novacale Limited'
WHERE client_id IS NULL;

UPDATE public.orders
SET
  remittance_status = CASE 
    WHEN payment_status = 'remitted' THEN 'remitted'
    WHEN payment_status = 'paid_direct' OR payment_type ILIKE '%direct%' OR payment_type ILIKE '%prepaid%' THEN 'direct_transfer'
    WHEN status = 'delivered' THEN 'unremitted'
    ELSE 'unremitted'
  END,
  financial_settlement_status = CASE
    WHEN payment_status = 'remitted' THEN 'cash_remitted_verified'
    WHEN payment_status = 'paid_direct' OR payment_type ILIKE '%direct%' OR payment_type ILIKE '%prepaid%' THEN 'direct_transfer_settled'
    ELSE 'pending_remittance'
  END,
  delivered_at = CASE
    WHEN status = 'delivered' AND delivered_at IS NULL THEN updated_at
    ELSE delivered_at
  END,
  remitted_at = CASE
    WHEN payment_status = 'remitted' AND remitted_at IS NULL THEN updated_at
    ELSE remitted_at
  END,
  remittance_reference = CASE
    WHEN payment_status = 'remitted' AND remittance_reference IS NULL THEN 'SETTLE-NOV-2026-001'
    ELSE remittance_reference
  END;

-- 6. Seed Initial Historical Settlement Batch for Novacale Limited
INSERT INTO public.client_settlements (
  id,
  settlement_number,
  client_id,
  company_id,
  period_start,
  period_end,
  total_orders_count,
  gross_collections,
  logistics_fees_deducted,
  net_payout_amount,
  destination_bank_name,
  destination_account_number,
  destination_account_name,
  payout_reference,
  status,
  notes,
  settled_at
)
VALUES (
  '55555555-5555-4555-8555-555555555551'::uuid,
  'SETTLE-NOV-2026-001',
  '33333333-3333-4333-8333-333333333333'::uuid,
  '11111111-1111-4111-8111-111111111111'::uuid,
  NOW() - INTERVAL '7 days',
  NOW() - INTERVAL '1 day',
  6,
  320000.00,
  30000.00,
  290000.00,
  'Zenith Bank',
  '1012345678',
  'Novacale Limited',
  'NIP-TXN-984210984',
  'completed',
  'Batch 01 settlement paid out via Zenith NIP to Novacale Limited corporate account.',
  NOW() - INTERVAL '1 day'
)
ON CONFLICT (settlement_number) DO UPDATE SET
  gross_collections = EXCLUDED.gross_collections,
  net_payout_amount = EXCLUDED.net_payout_amount;

-- 7. Notify PostgREST to immediately refresh OpenAPI and schema cache
NOTIFY pgrst, 'reload schema';
