-- ============================================================================
-- NovaExpress Logistics Management System (NoveXPS)
-- Complete PostgreSQL / Supabase Schema Definition for PDA Operations
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

NOTIFY pgrst, 'reload schema';

-- Column safety migrations for pre-existing tables
ALTER TABLE IF EXISTS companies ADD COLUMN IF NOT EXISTS code VARCHAR(50);
ALTER TABLE IF EXISTS companies ADD COLUMN IF NOT EXISTS email VARCHAR(255);
ALTER TABLE IF EXISTS companies ADD COLUMN IF NOT EXISTS phone VARCHAR(50);
ALTER TABLE IF EXISTS companies ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE IF EXISTS companies ADD COLUMN IF NOT EXISTS currency VARCHAR(10) DEFAULT 'NGN';
ALTER TABLE IF EXISTS companies ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

ALTER TABLE IF EXISTS users ADD COLUMN IF NOT EXISTS company_id UUID;
ALTER TABLE IF EXISTS users ADD COLUMN IF NOT EXISTS phone_number VARCHAR(50);
ALTER TABLE IF EXISTS users ADD COLUMN IF NOT EXISTS role VARCHAR(50) DEFAULT 'delivery_agent';

ALTER TABLE IF EXISTS delivery_agents ADD COLUMN IF NOT EXISTS agent_code VARCHAR(50);
ALTER TABLE IF EXISTS delivery_agents ADD COLUMN IF NOT EXISTS distribution_center_id UUID;
ALTER TABLE IF EXISTS delivery_agents ADD COLUMN IF NOT EXISTS current_cod_balance NUMERIC(14,2) DEFAULT 0.00;
ALTER TABLE IF EXISTS delivery_agents ADD COLUMN IF NOT EXISTS direct_transfer_balance NUMERIC(14,2) DEFAULT 0.00;

ALTER TABLE IF EXISTS products ADD COLUMN IF NOT EXISTS company_id UUID;
ALTER TABLE IF EXISTS products ADD COLUMN IF NOT EXISTS client_id UUID;
ALTER TABLE IF EXISTS products ADD COLUMN IF NOT EXISTS sku VARCHAR(100);
ALTER TABLE IF EXISTS products ADD COLUMN IF NOT EXISTS base_price NUMERIC(14,2) DEFAULT 0.00;
ALTER TABLE IF EXISTS products ADD COLUMN IF NOT EXISTS low_stock_threshold INT DEFAULT 5;

ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS company_id UUID;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS order_number VARCHAR(100);
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS distribution_center_id UUID;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS client_id UUID;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS delivery_address TEXT;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS fulfillment_type VARCHAR(50) DEFAULT 'distributed_inventory';
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS client_delivery_fee NUMERIC(14,2) DEFAULT 5000.00;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS agent_entitlement NUMERIC(14,2) DEFAULT 2500.00;

ALTER TABLE IF EXISTS cash_remittances ADD COLUMN IF NOT EXISTS commission_deducted NUMERIC(14,2) DEFAULT 0.00;
ALTER TABLE IF EXISTS cash_remittances ADD COLUMN IF NOT EXISTS net_amount NUMERIC(14,2) DEFAULT 0.00;


-- ----------------------------------------------------------------------------
-- 1. COMPANIES & TENANTS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(50),
    address TEXT,
    currency VARCHAR(10) DEFAULT 'NGN',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 2. DISTRIBUTION CENTERS & WAREHOUSES
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS distribution_centers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) UNIQUE NOT NULL,
    state VARCHAR(100) NOT NULL,
    city VARCHAR(100) NOT NULL,
    address TEXT NOT NULL,
    contact_phone VARCHAR(50),
    contact_email VARCHAR(255),
    is_hub BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 3. USERS & DELIVERY AGENTS (RIDERS)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES companies(id) ON DELETE SET NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone_number VARCHAR(50) UNIQUE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'delivery_agent', -- 'admin', 'dc_manager', 'delivery_agent'
    is_active BOOLEAN DEFAULT true,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS delivery_agents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    distribution_center_id UUID REFERENCES distribution_centers(id) ON DELETE SET NULL,
    agent_code VARCHAR(50) UNIQUE NOT NULL, -- e.g. 'PDA-7000'
    vehicle_type VARCHAR(50) DEFAULT 'motorcycle', -- 'motorcycle', 'van', 'bicycle'
    vehicle_plate_number VARCHAR(50),
    operating_state VARCHAR(100) NOT NULL DEFAULT 'Abuja (FCT)',
    operating_city VARCHAR(100) NOT NULL DEFAULT 'Wuse 2',
    current_status VARCHAR(50) DEFAULT 'available', -- 'available', 'on_delivery', 'offline', 'break'
    current_cod_balance NUMERIC(14, 2) DEFAULT 0.00, -- Physical cash held in custody awaiting remittance
    direct_transfer_balance NUMERIC(14, 2) DEFAULT 0.00, -- Commission/allowances owed by company for Monnify direct transfers
    bank_name VARCHAR(100),
    bank_account_number VARCHAR(20),
    bank_account_name VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    last_sync_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 4. CLIENTS & PACKAGES
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL, -- e.g. 'Novacare Limited', 'PharmaPlus'
    code VARCHAR(50) UNIQUE NOT NULL,
    contact_person VARCHAR(100),
    phone VARCHAR(50),
    email VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS client_packages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    tracking_number VARCHAR(100) UNIQUE NOT NULL,
    package_label VARCHAR(255) NOT NULL,
    package_description TEXT,
    declared_value NUMERIC(14, 2) DEFAULT 0.00,
    client_delivery_fee NUMERIC(14, 2) DEFAULT 0.00,
    agent_commission NUMERIC(14, 2) DEFAULT 0.00,
    current_custody_agent_id UUID REFERENCES delivery_agents(id),
    status VARCHAR(50) DEFAULT 'in_custody', -- 'in_custody', 'in_transit', 'delivered', 'returned'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 5. PRODUCTS, SKUs & BATCHES (DISTRIBUTED INVENTORY)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    client_id UUID REFERENCES clients(id) ON DELETE SET NULL,
    sku VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL, -- e.g. 'Respira Detox Tea', 'Grazer Herbal Tea'
    category VARCHAR(100),
    description TEXT,
    base_price NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    image_url TEXT,
    reorder_level INT DEFAULT 5,
    low_stock_threshold INT DEFAULT 5,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS product_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    batch_number VARCHAR(100) NOT NULL,
    expiry_date DATE,
    manufacture_date DATE,
    initial_quantity INT NOT NULL,
    current_quantity INT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 6. AGENT VEHICLE INVENTORY & STOCK CUSTODY
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS agent_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    delivery_agent_id UUID NOT NULL REFERENCES delivery_agents(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    batch_id UUID REFERENCES product_batches(id),
    total_in_custody INT NOT NULL DEFAULT 0,
    reserved_count INT NOT NULL DEFAULT 0, -- Allocated to active accepted orders
    available_count INT NOT NULL DEFAULT 0, -- Available for new assignments or upsells
    delivered_count_today INT NOT NULL DEFAULT 0,
    returned_count INT NOT NULL DEFAULT 0,
    awaiting_return_count INT NOT NULL DEFAULT 0,
    last_audit_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_agent_product UNIQUE (delivery_agent_id, product_id)
);

-- ----------------------------------------------------------------------------
-- 7. STOCK REQUESTS, HANDOVERS, TRANSFERS & RETURNS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS stock_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_number VARCHAR(100) UNIQUE NOT NULL, -- e.g. 'REQ-00482'
    delivery_agent_id UUID NOT NULL REFERENCES delivery_agents(id) ON DELETE CASCADE,
    distribution_center_id UUID NOT NULL REFERENCES distribution_centers(id),
    status VARCHAR(50) NOT NULL DEFAULT 'approved', -- 'pending', 'approved', 'handed_over', 'rejected'
    request_type VARCHAR(50) NOT NULL DEFAULT 'restock', -- 'restock', 'initial_intake', 'emergency'
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS stock_request_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stock_request_id UUID NOT NULL REFERENCES stock_requests(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    batch_id UUID REFERENCES product_batches(id),
    requested_quantity INT NOT NULL,
    approved_quantity INT NOT NULL,
    handed_over_quantity INT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS stock_handovers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stock_request_id UUID NOT NULL REFERENCES stock_requests(id),
    delivery_agent_id UUID NOT NULL REFERENCES delivery_agents(id),
    dc_supervisor_id UUID REFERENCES users(id),
    handover_code VARCHAR(50) NOT NULL,
    agent_confirmed BOOLEAN DEFAULT false,
    supervisor_confirmed BOOLEAN DEFAULT false,
    confirmed_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS stock_returns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    return_number VARCHAR(100) UNIQUE NOT NULL, -- e.g. 'RET-00109'
    delivery_agent_id UUID NOT NULL REFERENCES delivery_agents(id),
    distribution_center_id UUID NOT NULL REFERENCES distribution_centers(id),
    product_id UUID REFERENCES products(id),
    order_id UUID,
    quantity INT NOT NULL DEFAULT 1,
    reason VARCHAR(100) NOT NULL, -- 'customer_rejected', 'defective', 'order_cancelled', 'overstock'
    status VARCHAR(50) DEFAULT 'submitted', -- 'submitted', 'received_at_dc', 'restocked', 'written_off'
    dc_received_by UUID REFERENCES users(id),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    received_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS inventory_audits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    audit_number VARCHAR(100) UNIQUE NOT NULL, -- e.g. 'AUD-2026-08'
    delivery_agent_id UUID NOT NULL REFERENCES delivery_agents(id),
    distribution_center_id UUID NOT NULL REFERENCES distribution_centers(id),
    audited_by UUID REFERENCES users(id),
    status VARCHAR(50) DEFAULT 'reconciled', -- 'pending', 'reconciled', 'discrepancy_flagged'
    total_physical_counted INT NOT NULL,
    total_system_expected INT NOT NULL,
    discrepancy_count INT DEFAULT 0,
    discrepancy_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 8. ORDERS & DELIVERIES
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    order_number VARCHAR(100) UNIQUE NOT NULL, -- e.g. 'TRK-8924'
    delivery_agent_id UUID REFERENCES delivery_agents(id) ON DELETE SET NULL,
    distribution_center_id UUID REFERENCES distribution_centers(id),
    client_id UUID REFERENCES clients(id),
    customer_name VARCHAR(255) NOT NULL,
    customer_phone VARCHAR(50) NOT NULL,
    customer_alt_phone VARCHAR(50),
    delivery_state VARCHAR(100) NOT NULL,
    delivery_city VARCHAR(100) NOT NULL,
    delivery_address TEXT NOT NULL,
    landmark TEXT,
    lga VARCHAR(100),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    fulfillment_type VARCHAR(50) NOT NULL DEFAULT 'distributed_inventory', -- 'distributed_inventory', 'client_package'
    product_id UUID REFERENCES products(id),
    product_name VARCHAR(255) DEFAULT 'Respira Detox Tea',
    quantity INT NOT NULL DEFAULT 1,
    paid_quantity INT NOT NULL DEFAULT 1,
    free_quantity INT NOT NULL DEFAULT 0,
    base_price NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    upsell_amount NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    total_amount NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    payment_type VARCHAR(50) NOT NULL DEFAULT 'pay_on_delivery', -- 'pay_on_delivery', 'prepaid'
    payment_status VARCHAR(50) NOT NULL DEFAULT 'pending', -- 'pending', 'collected', 'transferred', 'verified', 'failed'
    status VARCHAR(50) NOT NULL DEFAULT 'in_transit', -- 'pending', 'accepted', 'in_transit', 'delivered', 'failed', 'call_back', 'cancelled'
    delivery_method VARCHAR(50) DEFAULT 'cash', -- 'cash', 'direct_transfer'
    client_delivery_fee NUMERIC(14, 2) DEFAULT 5000.00,
    agent_entitlement NUMERIC(14, 2) DEFAULT 2500.00, -- Commission (₦1000) + Transport Allowance (₦1500)
    scheduled_callback_at TIMESTAMPTZ,
    reschedule_note TEXT,
    proof_of_delivery_url TEXT,
    delivery_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS order_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id),
    activity_type VARCHAR(100) NOT NULL, -- 'assigned', 'status_changed', 'delivery_completed', 'delivery_failed', 'monnify_paid'
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 9. MONNIFY DYNAMIC VIRTUAL ACCOUNTS & DIRECT PAYMENTS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS monnify_virtual_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    account_reference VARCHAR(100) UNIQUE NOT NULL, -- e.g. 'MNFY-TRK-8924'
    account_number VARCHAR(20) NOT NULL, -- e.g. '7890892401'
    account_name VARCHAR(255) NOT NULL DEFAULT 'NovaExpress / Novacare',
    bank_name VARCHAR(100) NOT NULL DEFAULT 'Wema Bank / Monnify',
    expected_amount NUMERIC(14, 2) NOT NULL,
    amount_paid NUMERIC(14, 2) DEFAULT 0.00,
    status VARCHAR(50) NOT NULL DEFAULT 'active', -- 'active', 'paid', 'expired'
    session_id VARCHAR(150),
    payment_received_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS monnify_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    virtual_account_id UUID REFERENCES monnify_virtual_accounts(id),
    order_id UUID NOT NULL REFERENCES orders(id),
    transaction_reference VARCHAR(100) UNIQUE NOT NULL,
    amount_paid NUMERIC(14, 2) NOT NULL,
    payer_name VARCHAR(255),
    payer_account_number VARCHAR(50),
    payer_bank VARCHAR(100),
    webhook_payload JSONB,
    verification_status VARCHAR(50) DEFAULT 'verified',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 10. CASH REMITTANCES & FINANCIAL SETTLEMENT
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cash_remittances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    delivery_agent_id UUID NOT NULL REFERENCES delivery_agents(id) ON DELETE CASCADE,
    reference_number VARCHAR(100) UNIQUE NOT NULL, -- e.g. 'RMT-0005', 'RMT-0004'
    amount NUMERIC(14, 2) NOT NULL, -- Amount remitted
    gross_collections NUMERIC(14, 2) DEFAULT 0.00,
    commission_deducted NUMERIC(14, 2) DEFAULT 0.00,
    transport_allowance_deducted NUMERIC(14, 2) DEFAULT 0.00,
    pos_fee NUMERIC(14, 2) DEFAULT 0.00,
    payment_method VARCHAR(50) NOT NULL DEFAULT 'bank_transfer', -- 'bank_transfer', 'cash_to_dc', 'pos'
    destination_bank_name VARCHAR(100) DEFAULT 'GTBank',
    destination_account_number VARCHAR(50) DEFAULT '0123456789',
    destination_account_name VARCHAR(255) DEFAULT 'NovaExpress Logistics Limited',
    status VARCHAR(50) NOT NULL DEFAULT 'submitted', -- 'pending', 'submitted', 'verified', 'approved', 'rejected'
    deposit_receipt_url TEXT,
    verified_by_user_id UUID REFERENCES users(id),
    verified_by_name VARCHAR(255),
    verified_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS remittance_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cash_remittance_id UUID NOT NULL REFERENCES cash_remittances(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    order_amount NUMERIC(14, 2) NOT NULL,
    payment_type VARCHAR(50) NOT NULL DEFAULT 'pay_on_delivery'
);

-- ----------------------------------------------------------------------------
-- 11. RIDER BALANCE & PAYOUT REQUESTS LEDGER
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS payout_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payout_number VARCHAR(100) UNIQUE NOT NULL, -- e.g. 'PAY-0082'
    delivery_agent_id UUID NOT NULL REFERENCES delivery_agents(id) ON DELETE CASCADE,
    amount NUMERIC(14, 2) NOT NULL,
    bank_name VARCHAR(100) NOT NULL,
    account_number VARCHAR(20) NOT NULL,
    account_name VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending', -- 'pending', 'approved', 'rejected', 'disbursed'
    disbursement_ref VARCHAR(100),
    dc_notes TEXT,
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS rider_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    delivery_agent_id UUID NOT NULL REFERENCES delivery_agents(id) ON DELETE CASCADE,
    transaction_code VARCHAR(100) UNIQUE NOT NULL, -- e.g. 'TXN-9021'
    title VARCHAR(255) NOT NULL,
    category VARCHAR(50) NOT NULL, -- 'direct_transfer', 'earnings', 'payout', 'remittance'
    amount NUMERIC(14, 2) NOT NULL,
    is_credit BOOLEAN NOT NULL DEFAULT true, -- true = added to rider, false = deducted / withdrawal
    reference VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'settled', -- 'settled', 'verified', 'pending', 'approved'
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 12. ROW LEVEL SECURITY (RLS) POLICIES
-- ----------------------------------------------------------------------------
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE cash_remittances ENABLE ROW LEVEL SECURITY;
ALTER TABLE payout_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE rider_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can access their own profile" ON users;
CREATE POLICY "Users can access their own profile" ON users
    FOR ALL USING (auth.uid() = id);

DROP POLICY IF EXISTS "Agents can view and manage their assignments" ON orders;
CREATE POLICY "Agents can view and manage their assignments" ON orders
    FOR ALL USING (
        delivery_agent_id IN (SELECT id FROM delivery_agents WHERE user_id = auth.uid())
        OR auth.uid() IS NULL -- Allow anon key access in dev
    );

DROP POLICY IF EXISTS "Agents can view their own inventory" ON agent_inventory;
CREATE POLICY "Agents can view their own inventory" ON agent_inventory
    FOR ALL USING (
        delivery_agent_id IN (SELECT id FROM delivery_agents WHERE user_id = auth.uid())
        OR auth.uid() IS NULL
    );

DROP POLICY IF EXISTS "Agents can view and submit cash remittances" ON cash_remittances;
CREATE POLICY "Agents can view and submit cash remittances" ON cash_remittances
    FOR ALL USING (
        delivery_agent_id IN (SELECT id FROM delivery_agents WHERE user_id = auth.uid())
        OR auth.uid() IS NULL
    );

DROP POLICY IF EXISTS "Agents can view and request payouts" ON payout_requests;
CREATE POLICY "Agents can view and request payouts" ON payout_requests
    FOR ALL USING (
        delivery_agent_id IN (SELECT id FROM delivery_agents WHERE user_id = auth.uid())
        OR auth.uid() IS NULL
    );

DROP POLICY IF EXISTS "Agents can view rider transactions" ON rider_transactions;
CREATE POLICY "Agents can view rider transactions" ON rider_transactions
    FOR ALL USING (
        delivery_agent_id IN (SELECT id FROM delivery_agents WHERE user_id = auth.uid())
        OR auth.uid() IS NULL
    );

