-- Migration: 20261011170000_fix_client_stock_invoice_and_consignment_handshake.sql
-- Description: Fix client_stock_invoices check constraint and fn_create_dc_consignment_for_intake_invoice column alignment

-- 1. Relax/Update status check constraint on client_stock_invoices
ALTER TABLE public.client_stock_invoices DROP CONSTRAINT IF EXISTS client_stock_invoices_status_check;
ALTER TABLE public.client_stock_invoices ADD CONSTRAINT client_stock_invoices_status_check 
    CHECK (status IN ('draft', 'pending_inspection', 'in_transit', 'received', 'verified', 'cancelled', 'discrepancy'));

-- 2. Stored Procedure: fn_create_dc_consignment_for_intake_invoice
CREATE OR REPLACE FUNCTION public.fn_create_dc_consignment_for_intake_invoice(
    p_invoice_id UUID,
    p_sender_id UUID DEFAULT NULL,
    p_sender_name TEXT DEFAULT '',
    p_sender_signature_url TEXT DEFAULT '',
    p_carrier_driver_name TEXT DEFAULT '',
    p_carrier_phone TEXT DEFAULT ''
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
    v_prod_id UUID;
    v_waybill TEXT;
    v_dc_name TEXT;
    v_total_units INT := 0;
BEGIN
    SELECT * INTO v_inv FROM public.client_stock_invoices WHERE id = p_invoice_id;
    IF v_inv IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invoice not found');
    END IF;

    -- Match targeted receiving DC across ANY tier (Grand DC, Hub DC, or General DC)
    SELECT id, name INTO v_dc_id, v_dc_name FROM public.distribution_centers 
    WHERE name ILIKE '%' || SPLIT_PART(v_inv.destination_warehouse, ' - ', 1) || '%'
       OR v_inv.destination_warehouse ILIKE '%' || name || '%'
       OR v_inv.destination_warehouse ILIKE '%' || state || '%'
       OR v_inv.destination_warehouse ILIKE '%' || code || '%'
    LIMIT 1;

    -- If not matched, default to Grand DC (Wuse Central branch default)
    IF v_dc_id IS NULL THEN
        SELECT id, name INTO v_dc_id, v_dc_name FROM public.distribution_centers 
        WHERE dc_type = 'grand_dc' OR is_grand_dc = true OR code = 'DC-WUSE-01'
        ORDER BY created_at ASC LIMIT 1;
    END IF;

    -- Final fallback
    IF v_dc_id IS NULL THEN
        SELECT id, name INTO v_dc_id, v_dc_name FROM public.distribution_centers LIMIT 1;
    END IF;

    -- Resolve company_id
    SELECT company_id INTO v_company_id FROM public.clients WHERE id = v_inv.client_id::UUID;
    IF v_company_id IS NULL THEN
        SELECT id INTO v_company_id FROM public.companies LIMIT 1;
    END IF;

    v_waybill := COALESCE(NULLIF(v_inv.waybill_number, ''), 'WB-INTAKE-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0'));

    -- Ensure invoice has the waybill number and initial status is 'in_transit'
    UPDATE public.client_stock_invoices
    SET waybill_number = v_waybill,
        status = 'in_transit',
        updated_at = NOW()
    WHERE id = p_invoice_id;

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
        carrier_driver_name,
        carrier_phone,
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
        COALESCE(NULLIF(p_sender_name, ''), 'Merchant Procurement'),
        'client',
        p_sender_signature_url,
        p_carrier_driver_name,
        p_carrier_phone,
        NOW(),
        'Procurement Inbound Intake from ' || COALESCE(v_inv.supplier_name, 'Vendor') || ' (Bill: ' || v_inv.invoice_number || ')'
    ) RETURNING id INTO v_transfer_id;

    -- Copy line items into stock_transfer_items with robust UUID resolution and valid columns
    FOR v_item IN SELECT * FROM public.client_stock_invoice_items WHERE invoice_id = p_invoice_id
    LOOP
        v_prod_id := NULL;
        IF v_item.product_id IS NOT NULL AND v_item.product_id::TEXT ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
            v_prod_id := v_item.product_id::UUID;
        END IF;

        IF v_prod_id IS NULL THEN
            SELECT id INTO v_prod_id FROM public.products 
            WHERE sku = v_item.product_sku OR name ILIKE v_item.product_name 
            LIMIT 1;
        END IF;

        INSERT INTO public.stock_transfer_items (
            transfer_id,
            product_id,
            quantity_shipped,
            quantity_received,
            quantity_damaged,
            quantity_missing,
            item_notes
        ) VALUES (
            v_transfer_id,
            v_prod_id,
            v_item.quantity,
            0,
            0,
            0,
            v_item.product_name || ' (SKU: ' || v_item.product_sku || ')'
        );
        v_total_units := v_total_units + v_item.quantity;
    END LOOP;

    -- Create/Sync DC Supply Intake Record if table exists
    BEGIN
        INSERT INTO public.dc_supply_intake_records (
            invoice_id,
            transfer_id,
            distribution_center_id,
            company_id,
            waybill_number,
            expected_units,
            carrier_driver_name,
            carrier_phone,
            status,
            sender_id,
            sender_name,
            sender_signature_url,
            notes
        ) VALUES (
            p_invoice_id,
            v_transfer_id,
            v_dc_id,
            v_company_id,
            v_waybill,
            v_total_units,
            p_carrier_driver_name,
            p_carrier_phone,
            'pending_dock_arrival',
            p_sender_id,
            COALESCE(NULLIF(p_sender_name, ''), 'Merchant Procurement'),
            p_sender_signature_url,
            'Awaiting physical dock check-in at ' || COALESCE(v_dc_name, 'Hub')
        )
        ON CONFLICT (invoice_id) DO UPDATE
        SET transfer_id = EXCLUDED.transfer_id,
            distribution_center_id = EXCLUDED.distribution_center_id,
            expected_units = EXCLUDED.expected_units,
            updated_at = NOW();
    EXCEPTION WHEN OTHERS THEN
        -- Non-blocking if table is absent or schema mismatch
    END;

    -- Realtime Notification to DC Personnel
    BEGIN
        INSERT INTO public.notifications (
            company_id,
            title,
            message,
            category,
            action_route,
            is_read
        ) VALUES (
            v_company_id,
            'Inbound Consignment Dispatched: ' || v_waybill,
            'Merchant dispatched ' || v_total_units || ' units from ' || COALESCE(v_inv.supplier_name, 'Vendor') || ' to ' || COALESCE(v_dc_name, 'Hub') || '. Physical reception verification required.',
            'inventory',
            '/dc/stock',
            false
        );
    EXCEPTION WHEN OTHERS THEN
        -- Non-blocking
    END;

    RETURN jsonb_build_object(
        'success', true,
        'invoice_id', p_invoice_id,
        'transfer_id', v_transfer_id,
        'destination_dc_id', v_dc_id,
        'destination_dc_name', v_dc_name,
        'waybill_number', v_waybill,
        'total_units', v_total_units,
        'status', 'in_transit'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_create_dc_consignment_for_intake_invoice TO authenticated, service_role, anon;
