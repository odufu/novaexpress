-- ============================================================================
-- NOVAXPRESS LOGISTICS PLATFORM
-- Migration: 20260920185000_link_stock_intake_to_dc_supply_handshake.sql
-- Description:
--   1. Connects stock intake invoices with physical DC consignment handshakes.
--   2. Extends stock_transfers and client_stock_invoices with industrial reception fields.
--   3. Registers an incoming supply transfer when a stock intake invoice is raised.
--   4. Provides fn_receive_supply_consignment_handshake for verified reception of both
--      merchant/supplier consignments and inter-DC stock freights.
-- ============================================================================

-- 1. Extend stock_transfers schema
ALTER TABLE public.stock_transfers
    ADD COLUMN IF NOT EXISTS invoice_id UUID REFERENCES public.client_stock_invoices(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS carrier_driver_name TEXT,
    ADD COLUMN IF NOT EXISTS carrier_phone TEXT,
    ADD COLUMN IF NOT EXISTS carrier_license_plate TEXT,
    ADD COLUMN IF NOT EXISTS waybill_slip_url TEXT,
    ADD COLUMN IF NOT EXISTS destination_bin TEXT,
    ADD COLUMN IF NOT EXISTS verified_units INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS damaged_units INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS missing_units INT DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_stock_transfers_invoice_id ON public.stock_transfers(invoice_id);

-- 2. Extend client_stock_invoices schema
ALTER TABLE public.client_stock_invoices
    ADD COLUMN IF NOT EXISTS waybill_number TEXT,
    ADD COLUMN IF NOT EXISTS payment_receipt_url TEXT,
    ADD COLUMN IF NOT EXISTS verified_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS verified_by TEXT,
    ADD COLUMN IF NOT EXISTS verified_units INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS damaged_units INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS missing_units INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS handshake_notes TEXT;

CREATE INDEX IF NOT EXISTS idx_client_stock_invoices_waybill ON public.client_stock_invoices(waybill_number);

-- 3. Stored Procedure: fn_create_dc_consignment_for_intake_invoice
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

    -- Copy line items into stock_transfer_items
    FOR v_item IN SELECT * FROM public.client_stock_invoice_items WHERE invoice_id = p_invoice_id
    LOOP
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
            v_item.product_id,
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

-- 4. Stored Procedure: fn_receive_supply_consignment_handshake (Universal Reception for Client Supply & Inter-DC)
CREATE OR REPLACE FUNCTION public.fn_receive_supply_consignment_handshake(
    p_transfer_id UUID,
    p_receiver_id UUID,
    p_receiver_name TEXT,
    p_receiver_role TEXT DEFAULT 'dc_supervisor',
    p_receiver_signature_url TEXT DEFAULT '',
    p_carrier_driver_name TEXT DEFAULT '',
    p_carrier_phone TEXT DEFAULT '',
    p_carrier_license_plate TEXT DEFAULT '',
    p_waybill_slip_url TEXT DEFAULT '',
    p_destination_bin TEXT DEFAULT '',
    p_verified_items JSONB DEFAULT '[]'::JSONB,
    p_notes TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_trf RECORD;
    v_inv RECORD;
    v_item JSONB;
    v_item_id UUID;
    v_prod_id UUID;
    v_item_row RECORD;
    v_qty_rec INT;
    v_qty_dam INT;
    v_qty_mis INT;
    v_total_rec INT := 0;
    v_total_dam INT := 0;
    v_total_mis INT := 0;
    v_total_shipped INT := 0;
    v_has_disc BOOLEAN := FALSE;
    v_status TEXT := 'completed';
    v_inv_status TEXT := 'verified';
    v_dc_name TEXT := 'Distribution Center';
    v_cur_bal RECORD;
    v_new_bal_qty NUMERIC;
    v_new_valuation NUMERIC;
    v_target_wh TEXT;
BEGIN
    SELECT * INTO v_trf FROM public.stock_transfers WHERE id = p_transfer_id;
    IF v_trf IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Stock transfer not found');
    END IF;

    -- Resolve DC name
    IF v_trf.destination_dc_id IS NOT NULL THEN
        SELECT name INTO v_dc_name FROM public.distribution_centers WHERE id = v_trf.destination_dc_id;
    END IF;

    -- Process verified items
    IF jsonb_array_length(p_verified_items) > 0 THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(p_verified_items)
        LOOP
            BEGIN
                v_item_id := (v_item->>'item_id')::UUID;
            EXCEPTION WHEN OTHERS THEN
                v_item_id := NULL;
            END;

            BEGIN
                v_prod_id := (v_item->>'product_id')::UUID;
            EXCEPTION WHEN OTHERS THEN
                v_prod_id := NULL;
            END;

            v_qty_rec := COALESCE((v_item->>'quantity_received')::INT, 0);
            v_qty_dam := COALESCE((v_item->>'quantity_damaged')::INT, 0);
            v_qty_mis := COALESCE((v_item->>'quantity_missing')::INT, 0);

            -- Match item row in stock_transfer_items
            SELECT * INTO v_item_row FROM public.stock_transfer_items
            WHERE ((v_item_id IS NOT NULL AND id = v_item_id)
                OR (v_item_id IS NOT NULL AND product_id = v_item_id)
                OR (v_prod_id IS NOT NULL AND product_id = v_prod_id))
              AND transfer_id = p_transfer_id
            LIMIT 1;

            IF v_item_row IS NOT NULL THEN
                v_total_shipped := v_total_shipped + COALESCE(v_item_row.quantity_shipped, 0);

                -- Fallback to shipped qty if received was omitted and no damages/missing reported
                IF v_qty_rec = 0 AND v_qty_dam = 0 AND v_qty_mis = 0 AND v_item_row.quantity_shipped > 0 THEN
                    v_qty_rec := v_item_row.quantity_shipped;
                END IF;

                IF v_qty_dam > 0 OR v_qty_mis > 0 OR v_qty_rec != v_item_row.quantity_shipped THEN
                    v_has_disc := TRUE;
                END IF;

                v_total_rec := v_total_rec + v_qty_rec;
                v_total_dam := v_total_dam + v_qty_dam;
                v_total_mis := v_total_mis + v_qty_mis;

                UPDATE public.stock_transfer_items
                SET quantity_received = v_qty_rec,
                    quantity_damaged = v_qty_dam,
                    quantity_missing = v_qty_mis,
                    item_notes = COALESCE(v_item->>'notes', item_notes)
                WHERE id = v_item_row.id;

                -- Credit physical product stock & DC warehouse stock
                IF v_qty_rec > 0 AND v_item_row.product_id IS NOT NULL THEN
                    UPDATE public.products
                    SET stock_quantity = COALESCE(stock_quantity, 0) + v_qty_rec,
                        updated_at = NOW()
                    WHERE id = v_item_row.product_id;

                    IF v_trf.destination_dc_id IS NOT NULL THEN
                        PERFORM public.fn_adjust_dc_stock(v_item_row.product_id, v_trf.destination_dc_id, v_qty_rec);
                    END IF;
                END IF;
            END IF;
        END LOOP;
    ELSE
        -- Fallback: Accept full shipped quantities as received
        FOR v_item_row IN SELECT * FROM public.stock_transfer_items WHERE transfer_id = p_transfer_id
        LOOP
            v_qty_rec := v_item_row.quantity_shipped;
            v_total_shipped := v_total_shipped + v_qty_rec;
            v_total_rec := v_total_rec + v_qty_rec;

            UPDATE public.stock_transfer_items
            SET quantity_received = v_qty_rec
            WHERE id = v_item_row.id;

            IF v_qty_rec > 0 AND v_item_row.product_id IS NOT NULL THEN
                UPDATE public.products
                SET stock_quantity = COALESCE(stock_quantity, 0) + v_qty_rec,
                    updated_at = NOW()
                WHERE id = v_item_row.product_id;

                IF v_trf.destination_dc_id IS NOT NULL THEN
                    PERFORM public.fn_adjust_dc_stock(v_item_row.product_id, v_trf.destination_dc_id, v_qty_rec);
                END IF;
            END IF;
        END LOOP;
    END IF;

    IF v_has_disc THEN
        v_status := 'discrepancy_reported';
        v_inv_status := 'discrepancy';
    ELSE
        v_status := 'completed';
        v_inv_status := 'verified';
    END IF;

    -- Update stock_transfers header
    UPDATE public.stock_transfers
    SET status = v_status,
        receiver_id = p_receiver_id,
        receiver_name = p_receiver_name,
        receiver_role = COALESCE(NULLIF(p_receiver_role, ''), 'dc_supervisor'),
        receiver_signature_url = COALESCE(p_receiver_signature_url, ''),
        carrier_driver_name = COALESCE(NULLIF(p_carrier_driver_name, ''), carrier_driver_name),
        carrier_phone = COALESCE(NULLIF(p_carrier_phone, ''), carrier_phone),
        carrier_license_plate = COALESCE(NULLIF(p_carrier_license_plate, ''), carrier_license_plate),
        waybill_slip_url = COALESCE(NULLIF(p_waybill_slip_url, ''), waybill_slip_url),
        destination_bin = COALESCE(NULLIF(p_destination_bin, ''), destination_bin),
        verified_units = v_total_rec,
        damaged_units = v_total_dam,
        missing_units = v_total_mis,
        received_at = NOW(),
        has_discrepancy = v_has_disc,
        discrepancy_notes = p_notes,
        updated_at = NOW()
    WHERE id = p_transfer_id;

    -- Synchronize with linked Client Stock Invoice if present
    IF v_trf.invoice_id IS NOT NULL THEN
        SELECT * INTO v_inv FROM public.client_stock_invoices WHERE id = v_trf.invoice_id;
        IF v_inv IS NOT NULL THEN
            UPDATE public.client_stock_invoices
            SET status = v_inv_status,
                verified_at = NOW(),
                verified_by = p_receiver_name,
                verified_units = v_total_rec,
                damaged_units = v_total_dam,
                missing_units = v_total_mis,
                handshake_notes = p_notes,
                updated_at = NOW()
            WHERE id = v_trf.invoice_id;

            -- ERP Stock Ledger balancing: Update client_stock_balances
            v_target_wh := COALESCE(NULLIF(v_inv.destination_warehouse, ''), v_dc_name);
            FOR v_item_row IN SELECT * FROM public.stock_transfer_items WHERE transfer_id = p_transfer_id
            LOOP
                IF v_item_row.quantity_received > 0 AND v_item_row.product_id IS NOT NULL THEN
                    SELECT * INTO v_cur_bal FROM public.client_stock_balances
                    WHERE client_id = v_inv.client_id
                      AND (product_id = v_item_row.product_id OR item_name = v_item_row.item_notes)
                      AND warehouse = v_target_wh
                    LIMIT 1;

                    IF FOUND THEN
                        UPDATE public.client_stock_balances
                        SET in_qty = in_qty + v_item_row.quantity_received,
                            balance_qty = balance_qty + v_item_row.quantity_received,
                            balance_value = (balance_qty + v_item_row.quantity_received) * valuation_rate,
                            updated_at = NOW()
                        WHERE id = v_cur_bal.id;
                    ELSE
                        INSERT INTO public.client_stock_balances (
                            client_id, product_id, item_code, item_name, warehouse, stock_uom,
                            opening_qty, opening_value, in_qty, in_value, out_qty, out_value,
                            balance_qty, balance_value, valuation_rate, reserved_stock
                        ) VALUES (
                            v_inv.client_id, v_item_row.product_id, COALESCE(v_item_row.product_id::text, 'SKU'),
                            COALESCE(v_item_row.item_notes, 'Product Item'), v_target_wh, 'Nos',
                            0, 0, v_item_row.quantity_received, 0, 0, 0,
                            v_item_row.quantity_received, 0, 0, 0
                        );
                    END IF;

                    -- Record immutable ledger entry
                    BEGIN
                        INSERT INTO public.client_stock_ledger_entries (
                            client_id, warehouse, item_code, item_name, voucher_type, voucher_no,
                            invoice_id, posting_date, posting_at, qty_change, incoming_qty, outgoing_qty,
                            valuation_rate, total_value, notes
                        ) VALUES (
                            v_inv.client_id, v_target_wh, COALESCE(v_item_row.product_id::text, 'SKU'),
                            COALESCE(v_item_row.item_notes, 'Product Item'), 'purchase_receipt',
                            COALESCE(v_trf.waybill_number, v_trf.transfer_number), v_trf.invoice_id,
                            CURRENT_DATE, NOW(), v_item_row.quantity_received, v_item_row.quantity_received, 0,
                            0, 0, 'Verified Inbound Consignment Handshake at ' || v_dc_name
                        );
                    EXCEPTION WHEN OTHERS THEN
                        -- Non-blocking ledger insert
                    END;
                END IF;
            END LOOP;

            -- Notify Merchant of Completed Consignment Handshake
            BEGIN
                INSERT INTO public.notifications (
                    company_id,
                    client_id,
                    title,
                    message,
                    category,
                    action_route,
                    is_read
                ) VALUES (
                    v_trf.company_id,
                    v_inv.client_id,
                    CASE WHEN v_has_disc THEN '⚠️ Consignment Received with Discrepancy' ELSE '✓ Consignment Verified & Received!' END,
                    'Waybill ' || COALESCE(v_trf.waybill_number, '') || ' verified at ' || v_dc_name || ' by ' || p_receiver_name || '. ' || v_total_rec || ' units credited to station shelves.' || CASE WHEN v_has_disc THEN ' (' || v_total_dam || ' damaged, ' || v_total_mis || ' missing)' ELSE '' END,
                    'inventory',
                    '/inventory',
                    false
                );
            EXCEPTION WHEN OTHERS THEN
                -- Non-blocking notification
            END;
        END IF;
    END IF;

    -- Inter-DC specific handling
    IF v_trf.transfer_type = 'inter_dc' THEN
        -- If discrepancy reported on inter-DC transfer, log audit event
        IF v_has_disc THEN
            BEGIN
                INSERT INTO public.inventory_audits (
                    product_id,
                    action,
                    performed_by,
                    notes
                ) VALUES (
                    NULL,
                    'inter_dc_discrepancy',
                    p_receiver_name,
                    'Inter-DC transfer ' || v_trf.transfer_number || ' received with ' || v_total_dam || ' damaged and ' || v_total_mis || ' missing units.'
                );
            EXCEPTION WHEN OTHERS THEN
            END;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'status', v_status,
        'has_discrepancy', v_has_disc,
        'total_shipped', v_total_shipped,
        'total_received', v_total_rec,
        'total_damaged', v_total_dam,
        'total_missing', v_total_mis,
        'invoice_id', v_trf.invoice_id,
        'transfer_id', p_transfer_id,
        'waybill_number', v_trf.waybill_number,
        'destination_dc_name', v_dc_name,
        'message', 'Consignment reception handshake successfully processed and inventory credited.'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_receive_supply_consignment_handshake TO authenticated, service_role, anon;

-- 5. Backwards-compatible wrapper for fn_receive_client_supply
CREATE OR REPLACE FUNCTION public.fn_receive_client_supply(
    p_transfer_id UUID,
    p_receiver_id UUID,
    p_receiver_name TEXT,
    p_receiver_signature_url TEXT DEFAULT '',
    p_verified_items JSONB DEFAULT '[]'::JSONB,
    p_notes TEXT DEFAULT ''
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN public.fn_receive_supply_consignment_handshake(
        p_transfer_id := p_transfer_id,
        p_receiver_id := p_receiver_id,
        p_receiver_name := p_receiver_name,
        p_receiver_role := 'dc_supervisor',
        p_receiver_signature_url := p_receiver_signature_url,
        p_carrier_driver_name := '',
        p_carrier_phone := '',
        p_carrier_license_plate := '',
        p_waybill_slip_url := '',
        p_destination_bin := '',
        p_verified_items := p_verified_items,
        p_notes := p_notes
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_receive_client_supply TO authenticated, service_role, anon;
