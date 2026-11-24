-- Migration: 20261119153000_standardize_two_dcs_abuja_lagos.sql
-- Description: Standardize the distribution network strictly to the 2 official autonomous DCs:
--              1. Abuja Central DC (Central Command / DC-ABJ-01)
--              2. Lagos Central DC (DC-LAG-01)
--              Deactivates legacy dummy test entries (Benue DC, Lokoja DC, etc.)

DO $$
BEGIN
    RAISE NOTICE '⚡ Standardizing NovaXpress Logistics Distribution Centers to Abuja & Lagos...';

    -- 1. Ensure Abuja Central DC is active and standardized
    UPDATE public.distribution_centers
    SET 
        name = 'Abuja Central DC',
        code = 'DC-ABJ-01',
        state = 'Federal Capital Territory',
        city = 'Abuja Municipal (AMAC)',
        address = 'Plot 402 Aminu Kano Crescent, Wuse 2, Abuja',
        manager_name = 'Ahmed Bello',
        is_grand_dc = true,
        is_hub = true,
        is_active = true,
        dc_type = 'grand_dc',
        updated_at = NOW()
    WHERE id = '22222222-2222-4222-8222-222222222222'
       OR code IN ('DC-CMD-01', 'DC-WUSE-01', 'DC-ABJ-01');

    -- If Abuja DC record does not exist under that UUID, insert it
    IF NOT EXISTS (
        SELECT 1 FROM public.distribution_centers 
        WHERE id = '22222222-2222-4222-8222-222222222222' OR code = 'DC-ABJ-01'
    ) THEN
        INSERT INTO public.distribution_centers (
            id,
            company_id,
            name,
            code,
            state,
            city,
            address,
            contact_phone,
            contact_email,
            manager_name,
            is_active,
            is_grand_dc,
            is_hub,
            dc_type,
            operating_zones,
            created_at,
            updated_at
        ) VALUES (
            '22222222-2222-4222-8222-222222222222',
            '11111111-1111-4111-8111-111111111111',
            'Abuja Central DC',
            'DC-ABJ-01',
            'Federal Capital Territory',
            'Abuja Municipal (AMAC)',
            'Plot 402 Aminu Kano Crescent, Wuse 2, Abuja',
            '+2348023456789',
            'abuja.dc@novaxpress.ng',
            'Ahmed Bello',
            true,
            true,
            true,
            'grand_dc',
            '["Central Business District", "Abuja Municipal (AMAC)", "Wuse I", "Wuse II", "Maitama", "Garki", "Jabi", "Utako"]'::jsonb,
            NOW(),
            NOW()
        );
    END IF;

    -- 2. Ensure Lagos Central DC is active and standardized
    UPDATE public.distribution_centers
    SET 
        name = 'Lagos Central DC',
        code = 'DC-LAG-01',
        state = 'Lagos',
        city = 'Ikeja',
        address = 'Plot 14, Commercial Avenue, Ikeja Logistics Corridor, Lagos',
        manager_name = 'Babatunde Adeleke',
        is_grand_dc = false,
        is_hub = true,
        is_active = true,
        dc_type = 'hub',
        updated_at = NOW()
    WHERE id = '33333333-3333-4333-8333-333333333333'
       OR code IN ('DC-LAG-01', 'DC-IKEJA-01', 'DC-LOS-HQ', 'DC-0039')
       OR name ILIKE '%NOVA XPRESS LAGOS%'
       OR name ILIKE '%Ikeja Central%';

    -- If Lagos DC record does not exist under that UUID, insert it
    IF NOT EXISTS (
        SELECT 1 FROM public.distribution_centers 
        WHERE id = '33333333-3333-4333-8333-333333333333' OR code = 'DC-LAG-01'
    ) THEN
        INSERT INTO public.distribution_centers (
            id,
            company_id,
            name,
            code,
            state,
            city,
            address,
            contact_phone,
            contact_email,
            manager_name,
            is_active,
            is_grand_dc,
            is_hub,
            dc_type,
            operating_zones,
            created_at,
            updated_at
        ) VALUES (
            '33333333-3333-4333-8333-333333333333',
            '11111111-1111-4111-8111-111111111111',
            'Lagos Central DC',
            'DC-LAG-01',
            'Lagos',
            'Ikeja',
            'Plot 14, Commercial Avenue, Ikeja Logistics Corridor, Lagos',
            '+2348052223344',
            'lagos.dc@novaxpress.ng',
            'Babatunde Adeleke',
            true,
            false,
            true,
            'hub',
            '["Ikeja", "Oshodi-Isolo", "Alimosho", "Surulere", "Lagos Mainland", "Lagos Island", "Eti-Osa", "Kosofe"]'::jsonb,
            NOW(),
            NOW()
        );
    END IF;

    -- 3. Deactivate any legacy dummy/test distribution centers
    UPDATE public.distribution_centers
    SET is_active = false, updated_at = NOW()
    WHERE code IN ('DC-BNU001', 'DC-LKJ-001')
       OR name ILIKE '%Benue%'
       OR name ILIKE '%Lokoja%';

    -- 4. Update warehouse references if warehouses table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'warehouses') THEN
        UPDATE public.warehouses
        SET is_active = false
        WHERE name ILIKE '%Benue%' OR name ILIKE '%Lokoja%';
    END IF;

    RAISE NOTICE '✅ Distribution centers standardized to 2 active DCs: Abuja Central DC and Lagos Central DC.';
END $$;
