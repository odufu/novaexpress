-- Migration: Drop legacy stock_transfers_status_check constraint to allow modern supply statuses
ALTER TABLE public.stock_transfers DROP CONSTRAINT IF EXISTS stock_transfers_status_check;
NOTIFY pgrst, 'reload schema';
