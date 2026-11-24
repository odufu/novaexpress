-- Migration: 20261119164000_seed_precious_etuk_super_admin.sql
-- Description: Provision Super Administrator Precious Etuk into public.users table

DO $$
BEGIN
    RAISE NOTICE '⚡ Provisioning Super Administrator Precious Etuk (psolomonetuk95@gmail.com)...';

    -- Insert or update Precious Etuk in public.users
    INSERT INTO public.users (
        id,
        email,
        first_name,
        last_name,
        phone_number,
        role,
        distribution_center_id,
        distribution_center_name,
        company_id,
        is_active,
        created_at,
        updated_at
    ) VALUES (
        'e9999999-9999-4999-8999-999999999999',
        'psolomonetuk95@gmail.com',
        'Precious',
        'Etuk',
        '07072756353',
        'super_admin',
        '22222222-2222-4222-8222-222222222222',
        'Abuja Central DC',
        '11111111-1111-4111-8111-111111111111',
        true,
        NOW(),
        NOW()
    )
    ON CONFLICT (email) DO UPDATE SET
        role = 'super_admin',
        first_name = 'Precious',
        last_name = 'Etuk',
        phone_number = '07072756353',
        is_active = true,
        updated_at = NOW();

    RAISE NOTICE '✅ Precious Etuk provisioned as Super Administrator.';
END $$;
