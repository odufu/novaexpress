-- ============================================================================
-- MIGRATION: 20261011150000_b2b_client_package_logistics_protocol.sql
-- DESCRIPTION: B2B Inbound Client Package Protocol & Decentralized Sourcing
-- AUTHOR: NovaExpress Engineering / Architecture Council
-- ============================================================================

-- 1. B2B CLIENTS REGISTRY (API Access Keys & Rate Configurations)
CREATE TABLE IF NOT EXISTS public.b2b_clients (
    id TEXT PRIMARY KEY,                           -- Unique client identifier (e.g., 'comfortcare-abuja-01')
    client_name TEXT NOT NULL,                     -- Display name (e.g., 'ComfortCare Health & Pharmacy Ltd')
    company_registration_no TEXT,                  -- RC / CAC Corporate Registration Number
    industry_category TEXT NOT NULL DEFAULT 'pharmacy' 
        CHECK (industry_category IN ('pharmacy', 'supermarket', 'electronics', 'fashion', 'general_retail')),
    api_key_hash TEXT NOT NULL,                    -- Bcrypt / Argon2 hash of secret bearer token
    api_key_prefix TEXT NOT NULL,                  -- Display prefix (e.g., 'nx_live_comfortcare_...')
    webhook_url TEXT,                              -- Webhook endpoint for live delivery status events
    webhook_secret TEXT,                           -- Shared secret for HMAC-SHA256 signature verification
    base_flat_rate NUMERIC(12, 2) NOT NULL DEFAULT 3500.00,
    additional_pickup_fee NUMERIC(12, 2) NOT NULL DEFAULT 1500.00,
    rider_base_allowance NUMERIC(12, 2) NOT NULL DEFAULT 1800.00,
    rider_extra_stop_allowance NUMERIC(12, 2) NOT NULL DEFAULT 1000.00,
    allowed_cities JSONB NOT NULL DEFAULT '["Abuja", "Lagos"]'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    contact_email TEXT,
    contact_phone TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_b2b_clients_active ON public.b2b_clients(is_active);

-- Seed Initial B2B Anchor Partner: ComfortCare Health & Pharmacy Ltd
INSERT INTO public.b2b_clients (
    id,
    client_name,
    company_registration_no,
    industry_category,
    api_key_hash,
    api_key_prefix,
    webhook_url,
    webhook_secret,
    base_flat_rate,
    additional_pickup_fee,
    rider_base_allowance,
    rider_extra_stop_allowance,
    allowed_cities,
    contact_email,
    contact_phone
) VALUES (
    'comfortcare-abuja-01',
    'ComfortCare Health & Pharmacy Ltd',
    'RC-1849204',
    'pharmacy',
    encode(sha256('nx_live_comfortcare_sec_994821049'::bytea), 'hex'),
    'nx_live_comfortcare_sec_9948...',
    'https://comfortcare.ng/api/v1/logistics-webhook',
    'whsec_comfortcare_prod_88294710',
    3500.00,
    1500.00,
    1800.00,
    1000.00,
    '["Abuja", "Lagos", "Kano", "Port Harcourt", "Ibadan"]'::jsonb,
    'dispatch@comfortcare.ng',
    '+2348032651505'
) ON CONFLICT (id) DO UPDATE SET
    client_name = EXCLUDED.client_name,
    base_flat_rate = EXCLUDED.base_flat_rate,
    additional_pickup_fee = EXCLUDED.additional_pickup_fee;

-- 2. ORDERS TABLE EXTENSIONS FOR B2B FULFILLMENT
ALTER TABLE public.orders
    ADD COLUMN IF NOT EXISTS fulfillment_type TEXT NOT NULL DEFAULT 'nova_inventory'
        CHECK (fulfillment_type IN ('nova_inventory', 'client_package')),
    ADD COLUMN IF NOT EXISTS b2b_client_id TEXT REFERENCES public.b2b_clients(id),
    ADD COLUMN IF NOT EXISTS client_order_reference TEXT,
    ADD COLUMN IF NOT EXISTS recipient_whatsapp TEXT,
    ADD COLUMN IF NOT EXISTS delivery_otp TEXT,
    ADD COLUMN IF NOT EXISTS otp_verified_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS pickup_stops_count INT NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS additional_pickup_fee NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS rider_pickup_allowance NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS payment_receipt_ref TEXT,
    ADD COLUMN IF NOT EXISTS payment_gateway TEXT;

CREATE INDEX IF NOT EXISTS idx_orders_fulfillment_type ON public.orders(fulfillment_type);
CREATE INDEX IF NOT EXISTS idx_orders_b2b_client ON public.orders(b2b_client_id);
CREATE INDEX IF NOT EXISTS idx_orders_client_ref ON public.orders(client_order_reference);

-- 3. CLIENT PACKAGE PICKUPS TABLE (Multi-Stop Dispensary & Supermarket Collection Itinerary)
CREATE TABLE IF NOT EXISTS public.client_package_pickups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    stop_sequence INT NOT NULL,                     -- 1, 2, 3...
    stop_label TEXT NOT NULL,                       -- e.g. 'Pickup Stop 1 (Life Camp)'
    location_id TEXT NOT NULL,                      -- e.g. 'ph-medplus-lifecamp'
    location_name TEXT NOT NULL,                    -- e.g. 'MedPlus Pharmacy (Life Camp)'
    pickup_address TEXT NOT NULL,                   -- Street address
    city TEXT NOT NULL DEFAULT 'Abuja',
    state TEXT NOT NULL DEFAULT 'Federal Capital Territory',
    lga TEXT,
    landmark TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    contact_person TEXT NOT NULL,
    contact_phone TEXT NOT NULL,
    contact_whatsapp TEXT,
    items_to_collect JSONB NOT NULL DEFAULT '[]'::jsonb, -- Array of items/drugs
    sealed_bag_ref TEXT NOT NULL,                   -- Tamper-evident barcode / QR (e.g., 'BAG-CC-99014-A')
    scanned_bag_ref TEXT,                           -- Scanned code confirmed by rider
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'rider_assigned', 'rider_arrived', 'bag_verified_collected', 'exception_failed')),
    failure_reason TEXT,
    collected_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pickups_order_id ON public.client_package_pickups(order_id);
CREATE INDEX IF NOT EXISTS idx_pickups_sealed_bag ON public.client_package_pickups(sealed_bag_ref);

-- Enable RLS
ALTER TABLE public.b2b_clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_package_pickups ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'b2b_clients' AND policyname = 'Allow read for authenticated') THEN
        CREATE POLICY "Allow read for authenticated" ON public.b2b_clients FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'client_package_pickups' AND policyname = 'Allow all for authenticated') THEN
        CREATE POLICY "Allow all for authenticated" ON public.client_package_pickups FOR ALL USING (true);
    END IF;
END $$;

-- 4. ATOMIC FUNCTION: fn_verify_pickup_bag_scan
CREATE OR REPLACE FUNCTION public.fn_verify_pickup_bag_scan(
    p_pickup_id UUID,
    p_scanned_bag_ref TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_expected_bag_ref TEXT;
    v_order_id UUID;
    v_remaining_stops INT;
BEGIN
    SELECT sealed_bag_ref, order_id
    INTO v_expected_bag_ref, v_order_id
    FROM public.client_package_pickups
    WHERE id = p_pickup_id;

    IF v_expected_bag_ref IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Pickup stop not found.');
    END IF;

    IF trim(upper(v_expected_bag_ref)) != trim(upper(p_scanned_bag_ref)) THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Bag barcode mismatch! Expected: ' || v_expected_bag_ref || ' but scanned: ' || p_scanned_bag_ref
        );
    END IF;

    -- Update stop status
    UPDATE public.client_package_pickups
    SET status = 'bag_verified_collected',
        scanned_bag_ref = p_scanned_bag_ref,
        collected_at = NOW()
    WHERE id = p_pickup_id;

    -- Check if all stops for this order are completed
    SELECT COUNT(*)
    INTO v_remaining_stops
    FROM public.client_package_pickups
    WHERE order_id = v_order_id
      AND status != 'bag_verified_collected';

    IF v_remaining_stops = 0 THEN
        UPDATE public.orders
        SET status = 'in_transit'
        WHERE id = v_order_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Bag verified and collected successfully!',
        'all_pickups_completed', (v_remaining_stops = 0),
        'remaining_stops_count', v_remaining_stops
    );
END;
$$;

-- 5. ATOMIC FUNCTION: fn_verify_delivery_otp_and_complete
CREATE OR REPLACE FUNCTION public.fn_verify_delivery_otp_and_complete(
    p_order_id UUID,
    p_entered_otp TEXT,
    p_agent_id UUID,
    p_recipient_signature_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_expected_otp TEXT;
    v_rider_allowance NUMERIC(12, 2);
    v_fulfillment_type TEXT;
BEGIN
    SELECT delivery_otp, rider_pickup_allowance, fulfillment_type
    INTO v_expected_otp, v_rider_allowance, v_fulfillment_type
    FROM public.orders
    WHERE id = p_order_id;

    IF v_expected_otp IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Order not found.');
    END IF;

    IF trim(v_expected_otp) != trim(p_entered_otp) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Invalid OTP! Recipient verification failed.');
    END IF;

    -- Update order to delivered
    UPDATE public.orders
    SET status = 'delivered',
        delivered_at = NOW(),
        otp_verified_at = NOW(),
        proof_of_delivery_signature_url = COALESCE(p_recipient_signature_url, proof_of_delivery_signature_url)
    WHERE id = p_order_id;

    -- If this was a client package with extra rider allowance, credit the rider
    IF v_fulfillment_type = 'client_package' AND v_rider_allowance > 0 THEN
        UPDATE public.delivery_agents
        SET current_balance = COALESCE(current_balance, 0.00) + v_rider_allowance
        WHERE id = p_agent_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Delivery completed and verified via OTP.',
        'order_id', p_order_id,
        'rider_credited_amount', v_rider_allowance
    );
END;
$$;

-- Notify PostgREST to refresh schema cache
SELECT pg_notify('pgrst', 'reload schema');
