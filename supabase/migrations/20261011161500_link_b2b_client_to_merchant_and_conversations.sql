-- ============================================================================
-- MIGRATION: 20261011161500_link_b2b_client_to_merchant_and_conversations.sql
-- DESCRIPTION: Allow nullable client_id on order_conversations and register ComfortCare in clients
-- ============================================================================

-- 1. Make client_id nullable on order_conversations to prevent trigger failure
ALTER TABLE public.order_conversations
    ALTER COLUMN client_id DROP NOT NULL;

-- 2. Register ComfortCare Health & Pharmacy Ltd in public.clients table
INSERT INTO public.clients (
    id,
    company_id,
    name,
    code,
    company_name,
    email,
    phone,
    address,
    city,
    state,
    is_active
) VALUES (
    'c3333333-3333-4333-8333-333333333333',
    '11111111-1111-4111-8111-111111111111',
    'ComfortCare Health & Pharmacy Ltd',
    'COMFORTCARE',
    'ComfortCare Health & Pharmacy Ltd',
    'dispatch@comfortcare.ng',
    '+2348032651505',
    'Abuja Central Commercial Corridor, FCT, Nigeria',
    'Abuja',
    'Federal Capital Territory',
    true
) ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    company_name = EXCLUDED.company_name;

-- 3. Add merchant_client_id column to b2b_clients and link to ComfortCare
ALTER TABLE public.b2b_clients
    ADD COLUMN IF NOT EXISTS merchant_client_id UUID REFERENCES public.clients(id) ON DELETE SET NULL;

UPDATE public.b2b_clients
SET merchant_client_id = 'c3333333-3333-4333-8333-333333333333'
WHERE id = 'comfortcare-abuja-01';

SELECT pg_notify('pgrst', 'reload schema');
