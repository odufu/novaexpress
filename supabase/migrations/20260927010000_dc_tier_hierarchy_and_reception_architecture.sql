-- ============================================================================
-- NOVAXPRESS LOGISTICS PLATFORM - DC TIER HIERARCHY & RECEPTION ARCHITECTURE
-- Production-grade schema & triggers for:
--   1. Grand DC (Wuse Central branch default)
--   2. Hub Distribution Center (Regional Hubs)
--   3. General Distribution Center (Branch/Local DCs)
--   4. Reception to ANY DC with default to Grand DC
-- ============================================================================

-- 1. Add dc_type column with check constraint
ALTER TABLE public.distribution_centers
  ADD COLUMN IF NOT EXISTS dc_type VARCHAR(50) DEFAULT 'general_dc';

-- Ensure constraint exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_distribution_centers_dc_type'
  ) THEN
    ALTER TABLE public.distribution_centers
      ADD CONSTRAINT chk_distribution_centers_dc_type
      CHECK (dc_type IN ('grand_dc', 'hub_dc', 'general_dc'));
  END IF;
END $$;

-- 2. Populate and standardize existing distribution centers
-- Wuse Central Distribution Hub is the Grand DC (Central DC Default)
UPDATE public.distribution_centers
SET dc_type = 'grand_dc',
    is_grand_dc = true,
    is_hub = true,
    is_primary_dc = true,
    name = CASE 
      WHEN name NOT ILIKE '%Grand%' THEN 'Wuse Grand Central Distribution Center' 
      ELSE name 
    END
WHERE code = 'DC-WUSE-01' 
   OR id = '22222222-2222-4222-8222-222222222222'
   OR is_grand_dc = true;

-- Hub Distribution Centers (is_hub = true and not grand)
UPDATE public.distribution_centers
SET dc_type = 'hub_dc',
    is_grand_dc = false,
    is_hub = true
WHERE (is_hub = true) 
  AND (is_grand_dc = false OR is_grand_dc IS NULL)
  AND (code != 'DC-WUSE-01' AND id != '22222222-2222-4222-8222-222222222222');

-- General Distribution Centers (all other local / satellite stations)
UPDATE public.distribution_centers
SET dc_type = 'general_dc',
    is_grand_dc = false,
    is_hub = false
WHERE dc_type IS NULL OR (is_hub = false AND is_grand_dc = false);

-- 3. Automatic Synchronization Trigger for DC Tiers
CREATE OR REPLACE FUNCTION public.fn_sync_dc_tier_fields()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.dc_type = 'grand_dc' THEN
    NEW.is_grand_dc := true;
    NEW.is_hub := true;
  ELSIF NEW.dc_type = 'hub_dc' THEN
    NEW.is_grand_dc := false;
    NEW.is_hub := true;
  ELSIF NEW.dc_type = 'general_dc' THEN
    NEW.is_grand_dc := false;
    NEW.is_hub := false;
  ELSIF NEW.is_grand_dc = true THEN
    NEW.dc_type := 'grand_dc';
    NEW.is_hub := true;
  ELSIF NEW.is_hub = true THEN
    NEW.dc_type := 'hub_dc';
    NEW.is_grand_dc := false;
  ELSE
    NEW.dc_type := 'general_dc';
    NEW.is_grand_dc := false;
    NEW.is_hub := false;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_dc_tier_fields ON public.distribution_centers;
CREATE TRIGGER trg_sync_dc_tier_fields
  BEFORE INSERT OR UPDATE ON public.distribution_centers
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_sync_dc_tier_fields();

-- 4. Stored Procedure: Comprehensive Product Custody Holders
-- Aggregates balances across Grand DC, Hub DCs, General DCs, and PDA Riders
CREATE OR REPLACE FUNCTION public.fn_get_product_holders_custody(
    p_client_id UUID DEFAULT NULL,
    p_start_date TIMESTAMPTZ DEFAULT NULL,
    p_end_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
    id TEXT,
    holder_id TEXT,
    holder_name TEXT,
    holder_type TEXT,
    state TEXT,
    lga TEXT,
    city TEXT,
    phone TEXT,
    product_id TEXT,
    product_sku TEXT,
    product_name TEXT,
    opening_qty INT,
    opening_value NUMERIC,
    in_qty INT,
    out_qty INT,
    closing_qty INT,
    valuation_rate NUMERIC,
    closing_value NUMERIC,
    last_updated TIMESTAMPTZ,
    status TEXT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_start TIMESTAMPTZ := COALESCE(p_start_date, NOW() - INTERVAL '30 days');
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
BEGIN
    RETURN QUERY
    -- 1. Distribution Centers (Grand DC, Hub DC, General DC)
    SELECT
        ('dc-custody-' || COALESCE(dc.id::TEXT, sb.id::TEXT))::TEXT AS id,
        COALESCE(dc.id::TEXT, 'dc-wuse-01')::TEXT AS holder_id,
        COALESCE(dc.name, sb.warehouse)::TEXT AS holder_name,
        (CASE 
            WHEN dc.dc_type = 'grand_dc' OR dc.is_grand_dc = true THEN 'Grand DC'
            WHEN dc.dc_type = 'hub_dc' OR dc.is_hub = true THEN 'Hub Distribution Center'
            ELSE 'General Distribution Center'
        END)::TEXT AS holder_type,
        COALESCE(dc.state, 'Abuja (FCT)')::TEXT AS state,
        COALESCE((dc.operating_zones->>0), dc.city, 'Abuja Municipal')::TEXT AS lga,
        COALESCE(dc.city, 'Abuja')::TEXT AS city,
        COALESCE(dc.contact_phone, '+234 803 111 2233')::TEXT AS phone,
        COALESCE(p.id::TEXT, sb.item_code)::TEXT AS product_id,
        sb.item_code::TEXT AS product_sku,
        sb.item_name::TEXT AS product_name,
        COALESCE(sb.opening_qty, 0)::INT AS opening_qty,
        COALESCE(sb.opening_value, 0.0)::NUMERIC AS opening_value,
        COALESCE(sb.in_qty, 0)::INT AS in_qty,
        COALESCE(sb.out_qty, 0)::INT AS out_qty,
        COALESCE(sb.balance_qty, 0)::INT AS closing_qty,
        COALESCE(sb.valuation_rate, 0.0)::NUMERIC AS valuation_rate,
        COALESCE(sb.balance_value, 0.0)::NUMERIC AS closing_value,
        COALESCE(sb.updated_at, NOW())::TIMESTAMPTZ AS last_updated,
        (CASE 
            WHEN sb.balance_qty <= 0 THEN 'Out of Stock'
            WHEN sb.balance_qty <= 10 THEN 'Low Stock'
            ELSE 'Active Custody'
        END)::TEXT AS status
    FROM public.client_stock_balances sb
    LEFT JOIN public.distribution_centers dc 
      ON (LOWER(dc.name) = LOWER(sb.warehouse) OR LOWER(sb.warehouse) LIKE '%' || LOWER(dc.name) || '%')
    LEFT JOIN public.products p 
      ON (p.sku = sb.item_code AND (p_client_id IS NULL OR p.client_id = p_client_id))
    WHERE (p_client_id IS NULL OR sb.client_id = p_client_id)

    UNION ALL

    -- 2. Active PDA Riders / Delivery Agents
    SELECT
        ('pda-custody-' || ai.id::TEXT)::TEXT AS id,
        da.id::TEXT AS holder_id,
        (da.full_name || ' (' || COALESCE(da.agent_code, 'PDA') || ')')::TEXT AS holder_name,
        'PDA / Dispatch Personnel'::TEXT AS holder_type,
        COALESCE(dc.state, 'Abuja (FCT)')::TEXT AS state,
        COALESCE((dc.operating_zones->>0), 'Abuja Municipal')::TEXT AS lga,
        COALESCE(dc.city, 'Abuja')::TEXT AS city,
        COALESCE(da.phone_number, '+234 812 000 0000')::TEXT AS phone,
        p.id::TEXT AS product_id,
        p.sku::TEXT AS product_sku,
        p.name::TEXT AS product_name,
        GREATEST(0, (ai.quantity_received - ai.quantity_delivered - ai.quantity_returned))::INT AS opening_qty,
        (GREATEST(0, (ai.quantity_received - ai.quantity_delivered - ai.quantity_returned)) * COALESCE(p.cost_price, 15000.0))::NUMERIC AS opening_value,
        COALESCE(ai.quantity_received, 0)::INT AS in_qty,
        COALESCE(ai.quantity_delivered, 0)::INT AS out_qty,
        GREATEST(0, (ai.quantity_received - ai.quantity_delivered - ai.quantity_returned))::INT AS closing_qty,
        COALESCE(p.cost_price, 15000.0)::NUMERIC AS valuation_rate,
        (GREATEST(0, (ai.quantity_received - ai.quantity_delivered - ai.quantity_returned)) * COALESCE(p.cost_price, 15000.0))::NUMERIC AS closing_value,
        COALESCE(ai.updated_at, NOW())::TIMESTAMPTZ AS last_updated,
        (CASE 
            WHEN (ai.quantity_received - ai.quantity_delivered - ai.quantity_returned) <= 0 THEN 'Out of Stock'
            WHEN (ai.quantity_received - ai.quantity_delivered - ai.quantity_returned) <= 5 THEN 'Low Stock'
            ELSE 'Active Custody'
        END)::TEXT AS status
    FROM public.agent_inventory ai
    JOIN public.delivery_agents da ON da.id = ai.agent_id
    JOIN public.products p ON p.id = ai.product_id
    LEFT JOIN public.distribution_centers dc ON dc.id = da.distribution_center_id
    WHERE (p_client_id IS NULL OR p.client_id = p_client_id)
      AND (ai.quantity_received - ai.quantity_delivered - ai.quantity_returned) > 0;
END;
$$;

-- 5. Stored Procedure for Consignment Reception: Support ANY DC with Grand DC fallback
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

    -- Final fallback if Grand DC is not seeded yet
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
        status = CASE WHEN status = 'draft' THEN 'in_transit' ELSE COALESCE(status, 'in_transit') END,
        updated_at = NOW()
    WHERE id = p_invoice_id;

    -- Create pending stock transfer for DC custody acceptance
    INSERT INTO public.stock_transfers (
        source_dc_id,
        destination_dc_id,
        source_type,
        destination_type,
        status,
        transfer_notes,
        created_at,
        updated_at
    ) VALUES (
        NULL,
        v_dc_id,
        'supplier_intake',
        'dc_warehouse',
        'in_transit',
        'Supplier intake invoice ' || v_inv.invoice_number || ' bound for ' || v_dc_name || ' [' || v_waybill || ']',
        NOW(),
        NOW()
    ) RETURNING id INTO v_transfer_id;

    -- Create transfer items from invoice line items
    FOR v_item IN SELECT * FROM public.client_stock_invoice_items WHERE invoice_id = p_invoice_id LOOP
        SELECT id INTO v_prod_id FROM public.products 
        WHERE (sku = v_item.product_sku OR id::TEXT = v_item.product_id)
        LIMIT 1;

        INSERT INTO public.stock_transfer_items (
            transfer_id,
            product_id,
            quantity,
            notes
        ) VALUES (
            v_transfer_id,
            COALESCE(v_prod_id, '00000000-0000-0000-0000-000000000000'::UUID),
            v_item.quantity,
            'Landed cost per unit: ' || v_item.effective_landed_cost_per_unit
        );
        v_total_units := v_total_units + v_item.quantity;
    END LOOP;

    -- Create DC Supply Intake Record
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
        'dispatched',
        p_sender_id,
        p_sender_name,
        p_sender_signature_url,
        'Consignment created for reception at ' || v_dc_name
    ) ON CONFLICT (invoice_id) DO UPDATE SET
        distribution_center_id = EXCLUDED.distribution_center_id,
        carrier_driver_name = EXCLUDED.carrier_driver_name,
        carrier_phone = EXCLUDED.carrier_phone,
        status = 'dispatched',
        updated_at = NOW();

    RETURN jsonb_build_object(
        'success', true,
        'transfer_id', v_transfer_id,
        'waybill_number', v_waybill,
        'destination_dc_id', v_dc_id,
        'destination_dc_name', v_dc_name,
        'total_units', v_total_units
    );
END;
$$;
