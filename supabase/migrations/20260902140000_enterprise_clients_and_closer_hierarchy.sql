-- ============================================================================
-- NOVAEXPRESS LOGISTICS PLATFORM - ENTERPRISE CLIENTS & CLOSER HIERARCHY
-- Migration for:
--   1. Enterprise Client Tiering & Closer Capacity Limits
--   2. Client Closers / Telesales Agents Directory
--   3. Customer Leads Pipeline & Dialer Management
--   4. Closer Order Attribution & Performance Scoring
--   5. Seeding Demo Closer & Active Sample Leads for Novacale Limited
-- ============================================================================

-- 1. Extend clients table with Enterprise tiers & closer limits
ALTER TABLE clients
  ADD COLUMN IF NOT EXISTS tier TEXT DEFAULT 'enterprise',
  ADD COLUMN IF NOT EXISTS closer_limit INT DEFAULT 250,
  ADD COLUMN IF NOT EXISTS is_enterprise BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS total_closers_count INT DEFAULT 0;

-- Update Novacale Limited to Enterprise Client with 250 closer cap
UPDATE clients
SET
  tier = 'enterprise',
  closer_limit = 250,
  is_enterprise = true
WHERE id = '33333333-3333-4333-8333-333333333333'::uuid;

-- 2. Create client_closers table for telesales agent profiles
CREATE TABLE IF NOT EXISTS client_closers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID REFERENCES clients(id) ON DELETE CASCADE,
  user_id UUID,
  closer_code TEXT UNIQUE,
  full_name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  phone TEXT,
  is_active BOOLEAN DEFAULT true,
  daily_call_target INT DEFAULT 50,
  total_leads_assigned INT DEFAULT 0,
  total_leads_confirmed INT DEFAULT 0,
  total_orders_booked INT DEFAULT 0,
  total_orders_delivered INT DEFAULT 0,
  commission_rate NUMERIC(12,2) DEFAULT 500.00,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_client_closers_client_id ON client_closers(client_id);
CREATE INDEX IF NOT EXISTS idx_client_closers_closer_code ON client_closers(closer_code);

-- 3. Create customer_leads table for closer telesales pipeline
CREATE TABLE IF NOT EXISTS customer_leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID REFERENCES clients(id) ON DELETE CASCADE,
  assigned_closer_id UUID REFERENCES client_closers(id) ON DELETE SET NULL,
  customer_name TEXT NOT NULL,
  customer_phone TEXT NOT NULL,
  customer_address TEXT,
  delivery_state TEXT DEFAULT 'Federal Capital Territory',
  delivery_lga TEXT DEFAULT 'Abuja Municipal (AMAC)',
  product_interest TEXT DEFAULT 'Grazer Tea',
  package_interest TEXT DEFAULT '2 Packs Promo Deal',
  status TEXT DEFAULT 'new_lead', -- 'new_lead', 'calling', 'call_back', 'confirmed', 'rejected', 'order_created'
  call_notes TEXT,
  converted_order_id TEXT,
  last_called_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_customer_leads_client_id ON customer_leads(client_id);
CREATE INDEX IF NOT EXISTS idx_customer_leads_closer_id ON customer_leads(assigned_closer_id);
CREATE INDEX IF NOT EXISTS idx_customer_leads_status ON customer_leads(status);

-- 4. Extend orders table with closer attribution
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS closer_id UUID,
  ADD COLUMN IF NOT EXISTS closer_name TEXT,
  ADD COLUMN IF NOT EXISTS closer_code TEXT,
  ADD COLUMN IF NOT EXISTS lead_id UUID;

CREATE INDEX IF NOT EXISTS idx_orders_closer_id ON orders(closer_id);

-- 5. Seed Demo Closer: Amaka Chioma for Novacale Limited
-- Add user account
INSERT INTO users (id, company_id, email, phone_number, first_name, last_name, role, is_active)
VALUES (
  '44444444-4444-4444-8444-444444444444'::uuid,
  '11111111-1111-4111-8111-111111111111',
  'closer.amaka@novacale.ng',
  '08021122334',
  'Amaka',
  'Chioma (Novacale Closer)',
  'closer',
  true
)
ON CONFLICT (id) DO UPDATE SET
  role = 'closer',
  first_name = 'Amaka',
  last_name = 'Chioma (Novacale Closer)',
  is_active = true;

-- Add closer profile in client_closers
INSERT INTO client_closers (
  id,
  client_id,
  user_id,
  closer_code,
  full_name,
  email,
  phone,
  is_active,
  daily_call_target,
  total_leads_assigned,
  total_leads_confirmed,
  total_orders_booked,
  total_orders_delivered,
  commission_rate
)
VALUES (
  '44444444-4444-4444-8444-444444444444'::uuid,
  '33333333-3333-4333-8333-333333333333'::uuid,
  '44444444-4444-4444-8444-444444444444'::uuid,
  'CLS-NOVA-001',
  'Amaka Chioma',
  'closer.amaka@novacale.ng',
  '08021122334',
  true,
  50,
  45,
  38,
  34,
  31,
  500.00
)
ON CONFLICT (id) DO UPDATE SET
  closer_code = EXCLUDED.closer_code,
  full_name = EXCLUDED.full_name,
  email = EXCLUDED.email,
  phone = EXCLUDED.phone;

-- Seed Sample Leads assigned to Amaka Chioma for instant testing
INSERT INTO customer_leads (
  id,
  client_id,
  assigned_closer_id,
  customer_name,
  customer_phone,
  customer_address,
  delivery_state,
  delivery_lga,
  product_interest,
  package_interest,
  status,
  call_notes
)
VALUES
  (
    '55555555-5555-4555-8555-000000000001'::uuid,
    '33333333-3333-4333-8333-333333333333'::uuid,
    '44444444-4444-4444-8444-444444444444'::uuid,
    'Chief Emmanuel Adeleke',
    '08033221144',
    'Plot 14, Ahmadu Bello Way, Area 11, Garki',
    'Federal Capital Territory',
    'Abuja Municipal (AMAC)',
    'Grazer Tea',
    '2 Packs Promo Deal',
    'new_lead',
    'Interested in 2-pack promo. Prefers morning delivery.'
  ),
  (
    '55555555-5555-4555-8555-000000000002'::uuid,
    '33333333-3333-4333-8333-333333333333'::uuid,
    '44444444-4444-4444-8444-444444444444'::uuid,
    'Mrs. Folashade Bakare',
    '08055667788',
    'Flat 4B, Hillview Estate, Guzape',
    'Federal Capital Territory',
    'Abuja Municipal (AMAC)',
    'Grazer Tea',
    '3 Packs Family Bundle',
    'calling',
    'Requested call back around 2 PM to confirm delivery address.'
  ),
  (
    '55555555-5555-4555-8555-000000000003'::uuid,
    '33333333-3333-4333-8333-333333333333'::uuid,
    '44444444-4444-4444-8444-444444444444'::uuid,
    'Alhaji Bello Usman',
    '08099887766',
    'No. 8, Bompai Road, Fagge',
    'Kano State',
    'Fagge',
    'Grazer Tea',
    '5 Packs Mega Saver (Buy 4 Get 1 Free)',
    'confirmed',
    'Ready for immediate dispatch to Kano depot.'
  )
ON CONFLICT (id) DO NOTHING;

-- 6. Notify PostgREST to reload schema
NOTIFY pgrst, 'reload schema';
