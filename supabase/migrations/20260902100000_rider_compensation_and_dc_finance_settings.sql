-- ============================================================================
-- NOVAEXPRESS LOGISTICS PLATFORM - RIDER COMPENSATION & DC FINANCE SETTINGS
-- Production-grade schema for multi-device sync of:
--   1. Rider compensation terms (commission, transport, failed delivery, salary, personnel type)
--   2. DC hub finance & POS rules (charge mode, tier fee, flat rate, caps, defaults)
--   3. Distribution center supervisor scoping & LGA coverage
-- ============================================================================

-- 1. Extend delivery_agents table with full compensation and scoping columns
ALTER TABLE delivery_agents 
  ADD COLUMN IF NOT EXISTS personnel_type TEXT DEFAULT 'pda',
  ADD COLUMN IF NOT EXISTS compensation_type TEXT DEFAULT 'commission',
  ADD COLUMN IF NOT EXISTS commission_rate NUMERIC DEFAULT 1000.0,
  ADD COLUMN IF NOT EXISTS transport_allowance NUMERIC DEFAULT 1500.0,
  ADD COLUMN IF NOT EXISTS fuel_allowance NUMERIC DEFAULT 800.0,
  ADD COLUMN IF NOT EXISTS failed_delivery_allowance NUMERIC DEFAULT 500.0,
  ADD COLUMN IF NOT EXISTS base_salary NUMERIC DEFAULT 0.0,
  ADD COLUMN IF NOT EXISTS upsell_bonus_percent NUMERIC DEFAULT 10.0,
  ADD COLUMN IF NOT EXISTS covered_lgas JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS distribution_center_id TEXT,
  ADD COLUMN IF NOT EXISTS bank_name TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS bank_account_number TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS bank_account_name TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS guarantor_name TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS guarantor_phone TEXT DEFAULT '';

-- 2. Extend users table for unified profile retrieval across all devices
ALTER TABLE users 
  ADD COLUMN IF NOT EXISTS distribution_center_id TEXT,
  ADD COLUMN IF NOT EXISTS distribution_center_name TEXT,
  ADD COLUMN IF NOT EXISTS operating_state TEXT,
  ADD COLUMN IF NOT EXISTS operating_city TEXT,
  ADD COLUMN IF NOT EXISTS personnel_type TEXT DEFAULT 'pda',
  ADD COLUMN IF NOT EXISTS compensation_type TEXT DEFAULT 'commission',
  ADD COLUMN IF NOT EXISTS commission_rate NUMERIC DEFAULT 1000.0,
  ADD COLUMN IF NOT EXISTS transport_allowance NUMERIC DEFAULT 1500.0,
  ADD COLUMN IF NOT EXISTS fuel_allowance NUMERIC DEFAULT 800.0,
  ADD COLUMN IF NOT EXISTS failed_delivery_allowance NUMERIC DEFAULT 500.0,
  ADD COLUMN IF NOT EXISTS base_salary NUMERIC DEFAULT 0.0;

-- 3. Ensure distribution_centers table exists with full enterprise fields
CREATE TABLE IF NOT EXISTS distribution_centers (
  id TEXT PRIMARY KEY,
  company_id UUID NOT NULL DEFAULT '11111111-1111-4111-8111-111111111111',
  name TEXT NOT NULL,
  code TEXT UNIQUE NOT NULL,
  state TEXT NOT NULL,
  city TEXT NOT NULL,
  address TEXT NOT NULL,
  contact_phone TEXT,
  contact_email TEXT,
  manager_name TEXT,
  is_hub BOOLEAN DEFAULT true,
  is_active BOOLEAN DEFAULT true,
  operating_zones JSONB DEFAULT '[]'::jsonb,
  storage_capacity_units INTEGER DEFAULT 25000,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure columns exist if distribution_centers was already created
ALTER TABLE distribution_centers
  ADD COLUMN IF NOT EXISTS operating_zones JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS storage_capacity_units INTEGER DEFAULT 25000,
  ADD COLUMN IF NOT EXISTS is_hub BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS company_id UUID DEFAULT '11111111-1111-4111-8111-111111111111';

-- 4. Dedicated DC Finance & POS Settings table for cloud synchronization across devices
CREATE TABLE IF NOT EXISTS dc_finance_settings (
  id TEXT PRIMARY KEY,
  distribution_center_id TEXT,
  pos_charge_mode TEXT NOT NULL DEFAULT 'tiered',
  pos_tier_amount NUMERIC NOT NULL DEFAULT 10000.0,
  pos_tier_fee NUMERIC NOT NULL DEFAULT 150.0,
  pos_flat_rate NUMERIC NOT NULL DEFAULT 100.0,
  pos_max_cap_fee NUMERIC NOT NULL DEFAULT 1000.0,
  is_pos_fee_reimbursable BOOLEAN NOT NULL DEFAULT true,
  default_commission_rate NUMERIC NOT NULL DEFAULT 1000.0,
  default_transport_allowance NUMERIC NOT NULL DEFAULT 1500.0,
  default_failed_delivery_allowance NUMERIC NOT NULL DEFAULT 500.0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert default global finance configuration if not present
INSERT INTO dc_finance_settings (
  id,
  distribution_center_id,
  pos_charge_mode,
  pos_tier_amount,
  pos_tier_fee,
  pos_flat_rate,
  pos_max_cap_fee,
  is_pos_fee_reimbursable,
  default_commission_rate,
  default_transport_allowance,
  default_failed_delivery_allowance
) VALUES (
  'global_finance_config',
  NULL,
  'tiered',
  10000.0,
  150.0,
  100.0,
  1000.0,
  true,
  1000.0,
  1500.0,
  500.0
) ON CONFLICT (id) DO NOTHING;

-- 5. Helper RPC to update driver compensation atomically
CREATE OR REPLACE FUNCTION update_driver_compensation(
  p_agent_id TEXT,
  p_commission_rate NUMERIC,
  p_transport_allowance NUMERIC,
  p_failed_allowance NUMERIC,
  p_base_salary NUMERIC,
  p_personnel_type TEXT,
  p_compensation_type TEXT,
  p_covered_lgas JSONB DEFAULT NULL,
  p_dc_id TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_res JSONB;
BEGIN
  UPDATE delivery_agents
  SET 
    commission_rate = COALESCE(p_commission_rate, commission_rate),
    transport_allowance = COALESCE(p_transport_allowance, transport_allowance),
    failed_delivery_allowance = COALESCE(p_failed_allowance, failed_delivery_allowance),
    base_salary = COALESCE(p_base_salary, base_salary),
    personnel_type = COALESCE(p_personnel_type, personnel_type),
    compensation_type = COALESCE(p_compensation_type, compensation_type),
    covered_lgas = COALESCE(p_covered_lgas, covered_lgas),
    distribution_center_id = COALESCE(p_dc_id, distribution_center_id),
    updated_at = NOW()
  WHERE id = p_agent_id OR agent_code = p_agent_id;

  SELECT to_jsonb(d) INTO v_res FROM delivery_agents d WHERE id = p_agent_id OR agent_code = p_agent_id;
  RETURN v_res;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Enable Row Level Security (RLS) and permissive access for authenticated users & service role
ALTER TABLE delivery_agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE dc_finance_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE distribution_centers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow read delivery_agents for all authenticated users"
  ON delivery_agents FOR SELECT
  TO authenticated, anon, service_role
  USING (true);

CREATE POLICY "Allow update delivery_agents for authenticated staff and service role"
  ON delivery_agents FOR ALL
  TO authenticated, service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow all on dc_finance_settings"
  ON dc_finance_settings FOR ALL
  TO authenticated, anon, service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow all on distribution_centers"
  ON distribution_centers FOR ALL
  TO authenticated, anon, service_role
  USING (true)
  WITH CHECK (true);

-- 7. Notify PostgREST to reload schema cache
NOTIFY pgrst, 'reload schema';
