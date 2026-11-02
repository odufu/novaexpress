-- Migration: 20261030140000_rename_grand_dc_to_central_command.sql
-- Description: Elevate Grand DC from location-bound "Wuse" to "Central Command Distribution Center (DC-CMD-01)"
--              Updates all distribution centers, users, orders, audit logs, and routing functions.

DO $$
BEGIN
    RAISE NOTICE '⚡ Renaming Grand DC to Central Command Distribution Center (DC-CMD-01)...';

    -- 1. Update the Apex Distribution Center in public.distribution_centers
    UPDATE public.distribution_centers
    SET 
        name = 'Central Command Distribution Center',
        code = 'DC-CMD-01',
        is_grand_dc = true,
        is_hub = true,
        dc_type = 'grand_dc',
        address = COALESCE(address, 'Plot 100 Command Boulevard, Central District'),
        updated_at = NOW()
    WHERE id = '22222222-2222-4222-8222-222222222222'
       OR code = 'DC-WUSE-01'
       OR is_grand_dc = true;

    -- If no record existed for the Grand DC UUID, insert it cleanly
    IF NOT EXISTS (SELECT 1 FROM public.distribution_centers WHERE id = '22222222-2222-4222-8222-222222222222') THEN
        INSERT INTO public.distribution_centers (
            id,
            company_id,
            name,
            code,
            state,
            city,
            address,
            phone,
            email,
            manager_name,
            manager_phone,
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
            'Central Command Distribution Center',
            'DC-CMD-01',
            'Federal Capital Territory',
            'Central Command Hub',
            'Plot 100 Command Boulevard, Central District',
            '+234 803 100 0001',
            'command.dc@novaxpress.ng',
            'Ahmed Bello & Co-Managers',
            '+234 803 100 0001',
            true,
            true,
            true,
            'grand_dc',
            '["Abuja Municipal", "Bwari", "Garki", "Wuse", "Maitama", "Utako", "Jabi", "Asokoro", "Gudu", "Central Business District"]'::jsonb,
            NOW(),
            NOW()
        );
    END IF;

    -- 2. Update user records if column exists
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'distribution_center_name'
    ) THEN
        EXECUTE 'UPDATE public.users SET distribution_center_name = ''Central Command Distribution Center'' WHERE distribution_center_id = ''22222222-2222-4222-8222-222222222222'' OR distribution_center_name ILIKE ''%Wuse Grand%'' OR distribution_center_name ILIKE ''%Wuse Central%''';
    END IF;

    -- 3. Update orders records if column exists
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'distribution_center_name'
    ) THEN
        EXECUTE 'UPDATE public.orders SET distribution_center_name = ''Central Command Distribution Center'' WHERE distribution_center_id = ''22222222-2222-4222-8222-222222222222'' OR distribution_center_name ILIKE ''%Wuse Grand%'' OR distribution_center_name ILIKE ''%Wuse Central%''';
    END IF;

    -- 4. Update audit logs referencing the Grand DC
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'audit_logs' AND column_name = 'distribution_center_name'
    ) THEN
        EXECUTE 'UPDATE public.audit_logs SET distribution_center_name = ''Central Command Distribution Center'' WHERE distribution_center_id = ''22222222-2222-4222-8222-222222222222'' OR distribution_center_name ILIKE ''%Wuse Grand%'' OR distribution_center_name ILIKE ''%Wuse Central%''';
    END IF;

    -- 5. Record elevation audit log
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'audit_logs') THEN
        INSERT INTO public.audit_logs (
            actor_name,
            actor_email,
            actor_role,
            action,
            resource,
            details,
            distribution_center_id,
            distribution_center_name,
            created_at
        ) VALUES (
            'Super Administrator',
            'super.admin@novaxpress.ng',
            'super_admin',
            'UPDATE_SYSTEM_POLICY',
            'DISTRIBUTION_NETWORK',
            'Elevated Apex Grand Distribution Center to Central Command Distribution Center (DC-CMD-01). Geographic constraint removed.',
            '22222222-2222-4222-8222-222222222222',
            'Central Command Distribution Center',
            NOW()
        );
    END IF;

    RAISE NOTICE '✅ Apex DC successfully renamed to Central Command Distribution Center (DC-CMD-01).';
END $$;
