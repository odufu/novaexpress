-- Migration: Finalize Production Schema Parity for Transfers, Remittances, and PostgREST Cache
ALTER TABLE IF EXISTS public.cash_remittances
    ADD COLUMN IF NOT EXISTS destination_account_name TEXT,
    ADD COLUMN IF NOT EXISTS destination_account_number TEXT,
    ADD COLUMN IF NOT EXISTS destination_bank_name TEXT;

ALTER TABLE IF EXISTS public.stock_transfers
    ALTER COLUMN source_warehouse_id DROP NOT NULL,
    ALTER COLUMN destination_warehouse_id DROP NOT NULL;

ALTER TABLE IF EXISTS public.stock_transfer_items
    ALTER COLUMN product_id DROP NOT NULL;

NOTIFY pgrst, 'reload schema';
