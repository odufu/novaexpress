-- ============================================================================
-- NOVAXPRESS LOGISTICS PLATFORM
-- Migration: 20260920160000_dc_merchant_management_and_brand_theming.sql
-- Description:
--   1. Ensures all brand theming, operating states, and service modules exist on clients.
--   2. Provides fn_update_client_profile_and_tariffs RPC for DC-side merchant management.
-- ============================================================================

DO $$
BEGIN
    -- has_inventory_management
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'clients' AND column_name = 'has_inventory_management'
    ) THEN
        ALTER TABLE public.clients ADD COLUMN has_inventory_management BOOLEAN DEFAULT TRUE;
    END IF;

    -- services_enabled
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'clients' AND column_name = 'services_enabled'
    ) THEN
        ALTER TABLE public.clients ADD COLUMN services_enabled TEXT[] DEFAULT ARRAY['fulfillment', 'delivery', 'inventory_management'];
    END IF;

    -- logo_url
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'clients' AND column_name = 'logo_url'
    ) THEN
        ALTER TABLE public.clients ADD COLUMN logo_url TEXT;
    END IF;

    -- primary_color
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'clients' AND column_name = 'primary_color'
    ) THEN
        ALTER TABLE public.clients ADD COLUMN primary_color TEXT DEFAULT '#0D9488';
    END IF;

    -- secondary_color
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'clients' AND column_name = 'secondary_color'
    ) THEN
        ALTER TABLE public.clients ADD COLUMN secondary_color TEXT DEFAULT '#031632';
    END IF;

    -- accent_color
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'clients' AND column_name = 'accent_color'
    ) THEN
        ALTER TABLE public.clients ADD COLUMN accent_color TEXT DEFAULT '#10B981';
    END IF;

    -- brand_theme
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'clients' AND column_name = 'brand_theme'
    ) THEN
        ALTER TABLE public.clients ADD COLUMN brand_theme JSONB DEFAULT '{"font_family": "Inter", "border_radius": 8}'::jsonb;
    END IF;

    -- operating_states
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'clients' AND column_name = 'operating_states'
    ) THEN
        ALTER TABLE public.clients ADD COLUMN operating_states TEXT[] DEFAULT ARRAY['Federal Capital Territory', 'Lagos', 'Rivers', 'Kano', 'Oyo', 'Enugu'];
    END IF;
END $$;

-- Atomic RPC for DC Console to update merchant details, tariffs, brand, and services
CREATE OR REPLACE FUNCTION public.fn_update_client_profile_and_tariffs(
    p_client_id UUID,
    p_company_name TEXT,
    p_contact_person TEXT,
    p_email TEXT,
    p_phone TEXT,
    p_address TEXT,
    p_city TEXT,
    p_state TEXT,
    p_tier TEXT,
    p_closer_limit INT,
    p_has_inventory_management BOOLEAN,
    p_services_enabled TEXT[],
    p_operating_states TEXT[],
    p_logo_url TEXT,
    p_primary_color TEXT,
    p_secondary_color TEXT,
    p_accent_color TEXT,
    p_custom_delivery_fee NUMERIC,
    p_custom_failed_attempt_fee NUMERIC,
    p_custom_platform_fee NUMERIC,
    p_bank_name TEXT,
    p_account_number TEXT,
    p_account_name TEXT,
    p_settlement_frequency TEXT,
    p_settlement_day TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.clients
    SET
        company_name = COALESCE(NULLIF(p_company_name, ''), company_name),
        contact_person = COALESCE(NULLIF(p_contact_person, ''), contact_person),
        email = COALESCE(NULLIF(p_email, ''), email),
        phone = COALESCE(NULLIF(p_phone, ''), phone),
        address = COALESCE(NULLIF(p_address, ''), address),
        city = COALESCE(NULLIF(p_city, ''), city),
        state = COALESCE(NULLIF(p_state, ''), state),
        tier = COALESCE(NULLIF(p_tier, ''), tier),
        is_enterprise = (COALESCE(p_tier, tier) = 'enterprise'),
        closer_limit = COALESCE(p_closer_limit, closer_limit),
        has_inventory_management = COALESCE(p_has_inventory_management, has_inventory_management),
        services_enabled = COALESCE(p_services_enabled, services_enabled),
        operating_states = COALESCE(p_operating_states, operating_states),
        logo_url = p_logo_url,
        primary_color = COALESCE(NULLIF(p_primary_color, ''), primary_color),
        secondary_color = COALESCE(NULLIF(p_secondary_color, ''), secondary_color),
        accent_color = COALESCE(NULLIF(p_accent_color, ''), accent_color),
        custom_delivery_fee = p_custom_delivery_fee,
        custom_failed_attempt_fee = p_custom_failed_attempt_fee,
        custom_platform_fee_value = p_custom_platform_fee,
        bank_name = COALESCE(NULLIF(p_bank_name, ''), bank_name),
        account_number = COALESCE(NULLIF(p_account_number, ''), account_number),
        account_name = COALESCE(NULLIF(p_account_name, ''), account_name),
        settlement_frequency = COALESCE(NULLIF(p_settlement_frequency, ''), settlement_frequency),
        settlement_day = COALESCE(NULLIF(p_settlement_day, ''), settlement_day),
        updated_at = NOW()
    WHERE id = p_client_id;

    RETURN jsonb_build_object(
        'success', true,
        'client_id', p_client_id,
        'updated_at', NOW()
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_update_client_profile_and_tariffs TO authenticated, service_role, anon;
