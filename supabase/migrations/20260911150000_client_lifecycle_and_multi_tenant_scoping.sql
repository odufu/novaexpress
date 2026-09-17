-- Migration: 20260911150000_client_lifecycle_and_multi_tenant_scoping.sql
-- Description: Enforce client authoritative linkage, multi-tenant isolation, product/package ownership, and live stock tracking.

-- 1. Add client_id column to public.users table (TEXT for maximum compatibility)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'users' 
          AND column_name = 'client_id'
    ) THEN
        ALTER TABLE public.users ADD COLUMN client_id TEXT;
        CREATE INDEX IF NOT EXISTS idx_users_client_id ON public.users(client_id);
    END IF;
END $$;

-- 2. Backfill client_id for known client users
UPDATE public.users 
SET client_id = '33333333-3333-4333-8333-333333333333' 
WHERE email = 'client.novacale@novaxpress.ng' 
   OR (role = 'client' AND email ILIKE '%novacale%');

UPDATE public.users 
SET client_id = 'c1111111-1111-4111-8111-111111111111' 
WHERE email = 'orders@novacare.ng' 
   OR (role = 'client' AND email ILIKE '%novacare%');

-- 3. Add live stock accounting columns to public.products if missing
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'products' 
          AND column_name = 'available_count'
    ) THEN
        ALTER TABLE public.products ADD COLUMN available_count INT DEFAULT 0;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'products' 
          AND column_name = 'delivered_count'
    ) THEN
        ALTER TABLE public.products ADD COLUMN delivered_count INT DEFAULT 0;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'products' 
          AND column_name = 'in_transit_count'
    ) THEN
        ALTER TABLE public.products ADD COLUMN in_transit_count INT DEFAULT 0;
    END IF;
END $$;

-- 4. Synchronize live stock quantity on products
UPDATE public.products 
SET available_count = COALESCE(stock_quantity, 0)
WHERE available_count IS NULL OR available_count = 0;

-- 5. Backfill client_id on public.products for strict multi-tenant isolation
UPDATE public.products 
SET client_id = '33333333-3333-4333-8333-333333333333',
    client_name = 'Novacale Limited'
WHERE client_name ILIKE '%novacale%' 
   OR name IN ('Respira Detox Tea', 'Respira Lungs Detox Tea', 'Alpha Man')
   OR client_id IS NULL AND name ILIKE '%respira%';

UPDATE public.products 
SET client_id = 'c1111111-1111-4111-8111-111111111111',
    client_name = 'Novacare Limited'
WHERE client_name ILIKE '%novacare%' 
   OR name IN ('Ura Clear', 'Grazer Herbal Detox Tea')
   OR client_id IS NULL AND (name ILIKE '%ura%' OR name ILIKE '%grazer%');

-- 6. Backfill client_id on public.product_packages
UPDATE public.product_packages
SET client_id = '33333333-3333-4333-8333-333333333333',
    client_name = 'Novacale Limited'
WHERE client_name ILIKE '%novacale%' 
   OR product_name ILIKE '%grazer%'
   OR client_id IS NULL;

-- 7. Ensure client_closers and customer_leads have client_id populated
UPDATE public.client_closers
SET client_id = '33333333-3333-4333-8333-333333333333'
WHERE client_id IS NULL;

UPDATE public.customer_leads
SET client_id = '33333333-3333-4333-8333-333333333333'
WHERE client_id IS NULL;
