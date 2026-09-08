-- ==============================================================================
-- INTER-DC STOCK TRANSFERS SCHEMA EXTENSION
-- Adds source_dc_id and destination_dc_id to stock_transfers for direct DC-to-DC routing
-- ==============================================================================

ALTER TABLE public.stock_transfers
    ADD COLUMN IF NOT EXISTS source_dc_id UUID REFERENCES public.distribution_centers(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS destination_dc_id UUID REFERENCES public.distribution_centers(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS transfer_type TEXT DEFAULT 'inter_dc',
    ADD COLUMN IF NOT EXISTS transfer_number TEXT,
    ADD COLUMN IF NOT EXISTS waybill_number TEXT,
    ADD COLUMN IF NOT EXISTS notes TEXT,
    ADD COLUMN IF NOT EXISTS dispatched_by TEXT,
    ADD COLUMN IF NOT EXISTS received_by TEXT;

-- Create index for high-speed inter-DC queries
CREATE INDEX IF NOT EXISTS idx_stock_transfers_source_dc ON public.stock_transfers(source_dc_id);
CREATE INDEX IF NOT EXISTS idx_stock_transfers_dest_dc ON public.stock_transfers(destination_dc_id);
