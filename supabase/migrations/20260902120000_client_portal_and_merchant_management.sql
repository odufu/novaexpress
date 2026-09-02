-- ============================================================================
-- NOVAEXPRESS LOGISTICS PLATFORM - CLIENT & MERCHANT PORTAL SCHEMA
-- Migration for:
--   1. Clients / Merchants Table
--   2. Commercial Product Packages Table
--   3. Default Client Demo Login Seeding & Cross-Module Scoping
-- ============================================================================

-- 1. Create clients table if not exists and add safety columns
CREATE TABLE IF NOT EXISTS clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID DEFAULT '11111111-1111-4111-8111-111111111111',
  code TEXT,
  name TEXT,
  company_name TEXT,
  contact_person TEXT,
  email TEXT UNIQUE,
  phone TEXT,
  address TEXT,
  city TEXT DEFAULT 'Abuja',
  state TEXT DEFAULT 'Federal Capital Territory',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE clients
  ADD COLUMN IF NOT EXISTS code TEXT,
  ADD COLUMN IF NOT EXISTS name TEXT,
  ADD COLUMN IF NOT EXISTS company_name TEXT,
  ADD COLUMN IF NOT EXISTS contact_person TEXT,
  ADD COLUMN IF NOT EXISTS email TEXT,
  ADD COLUMN IF NOT EXISTS phone TEXT,
  ADD COLUMN IF NOT EXISTS address TEXT,
  ADD COLUMN IF NOT EXISTS city TEXT DEFAULT 'Abuja',
  ADD COLUMN IF NOT EXISTS state TEXT DEFAULT 'Federal Capital Territory',
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

-- Seed Default Client: Novacale Limited
INSERT INTO clients (id, company_id, code, name, company_name, contact_person, email, phone, address, city, state, is_active)
VALUES (
  '33333333-3333-4333-8333-333333333333'::uuid,
  '11111111-1111-4111-8111-111111111111',
  'CLI-NOVACALE-01',
  'Novacale Limited',
  'Novacale Limited',
  'Dr. Chuka Okafor',
  'client.novacale@novaexpress.ng',
  '08034455667',
  'Plot 12, Commercial Avenue, Central Business District, Abuja',
  'Abuja',
  'Federal Capital Territory',
  true
)
ON CONFLICT (id) DO UPDATE SET
  code = EXCLUDED.code,
  name = EXCLUDED.name,
  company_name = EXCLUDED.company_name,
  email = EXCLUDED.email,
  contact_person = EXCLUDED.contact_person,
  phone = EXCLUDED.phone;

-- Ensure default client user exists in users table with role 'client'
INSERT INTO users (id, company_id, email, phone_number, first_name, last_name, role, is_active)
VALUES (
  '33333333-3333-4333-8333-333333333333'::uuid,
  '11111111-1111-4111-8111-111111111111',
  'client.novacale@novaexpress.ng',
  '08034455667',
  'Chuka',
  'Okafor (Novacale)',
  'client',
  true
)
ON CONFLICT (id) DO UPDATE SET
  role = 'client',
  first_name = 'Chuka',
  last_name = 'Okafor (Novacale)',
  is_active = true;

-- 2. Create product_packages table for commercial product deals
CREATE TABLE IF NOT EXISTS product_packages (
  id TEXT PRIMARY KEY,
  product_id TEXT NOT NULL,
  product_name TEXT NOT NULL,
  product_sku TEXT,
  package_name TEXT NOT NULL,
  quantity INT NOT NULL DEFAULT 1,
  paid_quantity INT DEFAULT 1,
  free_quantity INT DEFAULT 0,
  package_price NUMERIC(14,2) NOT NULL DEFAULT 0.00,
  client_id TEXT,
  client_name TEXT DEFAULT 'Novacale Limited',
  description TEXT,
  is_custom BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed initial default commercial packages for products
INSERT INTO product_packages (id, product_id, product_name, product_sku, package_name, quantity, paid_quantity, free_quantity, package_price, client_name, is_custom)
VALUES
  ('pkg-grazer-1', 'prod-grazer-01', 'Grazer Tea', 'GRZ-TEA-01', '1 Pack (Standard Retail)', 1, 1, 0, 22000.00, 'Novacale Limited', false),
  ('pkg-grazer-2', 'prod-grazer-01', 'Grazer Tea', 'GRZ-TEA-01', '2 Packs Promo Deal', 2, 2, 0, 35000.00, 'Novacale Limited', false),
  ('pkg-grazer-3', 'prod-grazer-01', 'Grazer Tea', 'GRZ-TEA-01', '3 Packs Family Bundle', 3, 3, 0, 50000.00, 'Novacale Limited', false),
  ('pkg-grazer-5', 'prod-grazer-01', 'Grazer Tea', 'GRZ-TEA-01', '5 Packs Mega Saver (Buy 4 Get 1 Free)', 5, 4, 1, 55000.00, 'Novacale Limited', false)
ON CONFLICT (id) DO UPDATE SET
  package_price = EXCLUDED.package_price,
  quantity = EXCLUDED.quantity;

-- 3. Extend products table with client references
ALTER TABLE products
  ADD COLUMN IF NOT EXISTS client_name TEXT DEFAULT 'Novacale Limited',
  ADD COLUMN IF NOT EXISTS image_url TEXT,
  ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'Health & Wellness';

-- 4. Notify PostgREST to reload schema
NOTIFY pgrst, 'reload schema';
