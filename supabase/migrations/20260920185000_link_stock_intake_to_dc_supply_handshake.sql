-- ============================================================================
-- NOVAXPRESS LOGISTICS PLATFORM
-- Migration: 20260920185000_link_stock_intake_to_dc_supply_handshake.sql
-- Description:
--   1. Connects stock intake invoices with physical DC consignment handshakes.
--   2. Automatically registers an incoming supply transfer in stock_transfers when an intake invoice is raised.
--   3. Synchronizes DC consignment acceptance with stock intake invoice verification.
-- ============================================================================

-- Add invoice_id column to stock_transfers if not present
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'stock_transfers' AND column_name = 'invoice_id'
    ) THEN
        ALTER TABLE public.stock_transfers 
        ADD COLUMN invoice_id UUID REFERENCES public.client_stock_invoices(id) ON DELETE SET NULL;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_stock_transfers_invoice_id ON public.stock_transfers(invoice_id);

-- Function to create DC consignment handshake when stock intake invoice is raised
CREATE OR REPLACE FUNCTION public.fn_create_dc_consignment_for_intake_invoice(
    p_invoice_id UUID,
    p_sender_id UUID DEFAULT NULL,
    p_sender_name TEXT DEFAULT '',
    p_sender_signature_url TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_inv RECORD;
    v_item RECORD;
    v_dc_id UUID;
    v_company_id UUID;
    v_transfer_id UUID;
    v_waybill TEXT;
BEGIN
    SELECT * INTO v_inv FROM public.client_stock_invoices WHERE id = p_invoice_id;
    IF v_inv IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invoice not found');
    END IF;

    -- Resolve destination DC by warehouse name matching
    SELECT id INTO v_dc_id FROM public.distribution_centers 
    WHERE name ILIKE '%' || SPLIT_PART(v_inv.destination_warehouse, ' - ', 1) || '%'
       OR v_inv.destination_warehouse ILIKE '%' || name || '%'
       OR v_inv.destination_warehouse ILIKE '%' || state || '%'
    LIMIT 1;

    -- Fallback to first active DC if not matched
    IF v_dc_id IS NULL THEN
        SELECT id INTO v_dc_id FROM public.distribution_centers LIMIT 1;
    END IF;

    -- Resolve company_id
    SELECT company_id INTO v_company_id FROM public.clients WHERE id = v_inv.client_id::UUID;
    IF v_company_id IS NULL THEN
        SELECT id INTO v_company_id FROM public.companies LIMIT 1;
    END IF;

    v_waybill := COALESCE(NULLIF(v_inv.waybill_number, ''), 'WB-INTAKE-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0'));

    -- Create pending stock transfer for DC custody acceptance
    INSERT INTO public.stock_transfers (
        company_id,
        client_id,
        invoice_id,
        transfer_type,
        transfer_number,
        waybill_number,
        destination_dc_id,
        status,
        sender_id,
        sender_name,
        sender_role,
        sender_signature_url,
        dispatched_at,
        notes
    ) VALUES (
        v_company_id,
        v_inv.client_id::UUID,
        p_invoice_id,
        'client_supply',
        v_waybill,
        v_waybill,
        v_dc_id,
        'in_transit',
        p_sender_id,
        COALESCE(NULLIF(p_sender_name, ''), v_inv.company_name, 'Merchant Procurement'),
        'client',
        p_sender_signature_url,
        NOW(),
        'Procurement Intake from ' || v_inv.supplier_name || ' (Bill: ' || v_inv.invoice_number || ')'
    ) RETURNING id INTO v_transfer_id;

    -- Copy line items into stock_transfer_items
    FOR v_item IN SELECT * FROM public.client_stock_invoice_items WHERE invoice_id = p_invoice_id
    LOOP
        INSERT INTO public.stock_transfer_items (
            transfer_id,
            product_id,
            quantity_dispatched,
            quantity_received,
            notes
        ) VALUES (
            v_transfer_id,
            v_item.product_id,
            v_item.quantity,
            0,
            v_item.product_name || ' (SKU: ' || v_item.product_sku || ')'
        );
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'invoice_id', p_invoice_id,
        'transfer_id', v_transfer_id,
        'destination_dc_id', v_dc_id,
        'waybill_number', v_waybill
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_create_dc_consignment_for_intake_invoice TO authenticated, service_role, anon;
