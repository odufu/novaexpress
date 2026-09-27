-- Migration: 20260926213500_patch_fn_create_dc_consignment_stored_procedure.sql
-- Description: Patch fn_create_dc_consignment_for_intake_invoice with safe product_id UUID resolution

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

    -- Resolve destination DC by warehouse name matching
    SELECT id, name INTO v_dc_id, v_dc_name FROM public.distribution_centers 
    WHERE name ILIKE '%' || SPLIT_PART(v_inv.destination_warehouse, ' - ', 1) || '%'
       OR v_inv.destination_warehouse ILIKE '%' || name || '%'
       OR v_inv.destination_warehouse ILIKE '%' || state || '%'
    LIMIT 1;

    -- Fallback to first active DC if not matched
    IF v_dc_id IS NULL THEN
        SELECT id, name INTO v_dc_id, v_dc_name FROM public.distribution_centers LIMIT 1;
    END IF;

    -- Resolve company_id
    SELECT company_id INTO v_company_id FROM public.clients WHERE id = v_inv.client_id::UUID;
    IF v_company_id IS NULL THEN
        SELECT id INTO v_company_id FROM public.companies LIMIT 1;
    END IF;

    v_waybill := COALESCE(NULLIF(v_inv.waybill_number, ''), 'WB-INTAKE-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0'));

    -- Ensure the invoice has the waybill number and initial status is 'in_transit'
    UPDATE public.client_stock_invoices
    SET waybill_number = v_waybill,
        status = CASE WHEN status = 'draft' THEN 'in_transit' ELSE COALESCE(status, 'in_transit') END,
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

    -- Copy line items into stock_transfer_items with robust UUID resolution
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

    -- Send Realtime Notification to DC Personnel
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
        -- Non-blocking notification failure
    END;

    RETURN jsonb_build_object(
        'success', true,
        'invoice_id', p_invoice_id,
        'transfer_id', v_transfer_id,
        'destination_dc_id', v_dc_id,
        'destination_dc_name', v_dc_name,
        'waybill_number', v_waybill,
        'total_units', v_total_units
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_create_dc_consignment_for_intake_invoice TO authenticated, service_role, anon;
