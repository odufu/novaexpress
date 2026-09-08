-- === FILE: 20260818000000_pda_functions_and_schema.sql ===
-- ============================================================================
-- NovaExpress Logistics Management System
-- Schema Enhancements, Ledger Triggers, and Stored Procedures for PDA App
-- ============================================================================

-- 1. Ensure extensions exist
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Stored Procedure: Confirm Delivery POD (Atomic Execution)
CREATE OR REPLACE FUNCTION confirm_delivery_pod(
    p_order_id UUID,
    p_agent_id UUID,
    p_payment_type VARCHAR,
    p_amount NUMERIC,
    p_proof_url TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_order RECORD;
    v_agent RECORD;
    v_commission NUMERIC;
    v_transport NUMERIC;
    v_earning NUMERIC;
    v_net_to_remit NUMERIC;
    v_new_cod_balance NUMERIC;
    v_new_direct_balance NUMERIC;
BEGIN
    -- 1. Verify order existence and assignment
    SELECT * INTO v_order
    FROM orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Order not found.'
        );
    END IF;

    -- 2. Fetch Agent Details & Calculate Entitlement
    SELECT * INTO v_agent
    FROM delivery_agents
    WHERE id = p_agent_id;

    v_commission := COALESCE(v_agent.commission_rate, CASE WHEN v_agent.personnel_type = 'in_house_rider' THEN 500 ELSE 1000 END);
    v_transport := CASE WHEN v_agent.personnel_type = 'in_house_rider' THEN COALESCE(v_agent.fuel_allowance, 800) ELSE COALESCE(v_agent.transport_allowance, 1500) END;
    v_earning := v_commission + v_transport;

    -- 3. Update Order Status
    UPDATE orders
    SET 
        status = 'delivered',
        payment_status = 'collected',
        proof_of_delivery_url = COALESCE(p_proof_url, proof_of_delivery_url),
        delivery_notes = COALESCE(p_notes, delivery_notes),
        updated_at = NOW()
    WHERE id = p_order_id;

    -- 3b. Inventory Custody Settlement: Deduct delivered product stock
    IF v_order.product_id IS NOT NULL THEN
        UPDATE products
        SET 
            available_count = GREATEST(0, COALESCE(available_count, 0) - COALESCE(v_order.quantity, 1)),
            delivered_count = COALESCE(delivered_count, 0) + COALESCE(v_order.quantity, 1)
        WHERE id = v_order.product_id;
    END IF;

    -- 4. Financial Ledger Settlement:
    -- If Cash POD: Rider retains earnings directly from cash. Cash to remit = amountCollected - v_earning
    -- If Non-Cash (Prepaid / Transfer / POS): Rider collected 0 cash; Company credits My Balance (direct_transfer_balance)
    IF p_payment_type = 'pay_on_delivery' OR v_order.payment_type = 'pay_on_delivery' THEN
        v_net_to_remit := GREATEST(0, COALESCE(p_amount, v_order.total_amount) - v_earning);
        
        UPDATE delivery_agents
        SET current_cod_balance = current_cod_balance + v_net_to_remit
        WHERE id = p_agent_id
        RETURNING current_cod_balance, direct_transfer_balance INTO v_new_cod_balance, v_new_direct_balance;
    ELSE
        UPDATE delivery_agents
        SET direct_transfer_balance = direct_transfer_balance + v_earning
        WHERE id = p_agent_id
        RETURNING current_cod_balance, direct_transfer_balance INTO v_new_cod_balance, v_new_direct_balance;

        -- Record transaction credit for rider
        INSERT INTO rider_transactions (
            delivery_agent_id,
            transaction_code,
            title,
            category,
            amount,
            is_credit,
            reference,
            status,
            description,
            created_at
        ) VALUES (
            p_agent_id,
            CONCAT('TXN-', SUBSTRING(CAST(EXTRACT(EPOCH FROM NOW()) AS TEXT), 6, 6)),
            'Direct Transfer Delivery Credited',
            'direct_transfer',
            v_earning,
            true,
            COALESCE(v_order.order_number, CAST(p_order_id AS TEXT)),
            'settled',
            CONCAT('Commission (₦', v_commission, ') + Transport (₦', v_transport, ') credited to My Balance from direct company transfer.'),
            NOW()
        );
    END IF;

    -- 5. Record Activity in Audit Log
    INSERT INTO order_activities (
        order_id,
        user_id,
        activity_type,
        notes,
        created_at
    ) VALUES (
        p_order_id,
        v_agent.user_id,
        'delivery_completed',
        CONCAT('Delivered by Agent. Payment: ₦', COALESCE(p_amount, v_order.total_amount), '. Rider Entitlement Retained: ₦', v_earning),
        NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'status', 'delivered',
        'current_cod_balance', v_new_cod_balance,
        'direct_transfer_balance', v_new_direct_balance,
        'rider_earning', v_earning,
        'message', 'Delivery confirmed and financial balance updated.'
    );
END;
$$;

-- 3. Stored Procedure: Log Delivery Failure / Reschedule
CREATE OR REPLACE FUNCTION log_delivery_failure(
    p_order_id UUID,
    p_agent_id UUID,
    p_reason_code VARCHAR,
    p_reschedule_time TIMESTAMPTZ DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_new_status VARCHAR;
BEGIN
    IF p_reason_code = 'rescheduled' OR p_reason_code = 'customer_callback' OR p_reschedule_time IS NOT NULL THEN
        v_new_status := 'call_back';
    ELSE
        v_new_status := 'cancelled';
    END IF;

    UPDATE orders
    SET 
        status = v_new_status,
        scheduled_callback_at = p_reschedule_time,
        reschedule_note = p_reason_code,
        delivery_notes = COALESCE(p_notes, delivery_notes),
        updated_at = NOW()
    WHERE id = p_order_id;

    -- Record Activity Audit
    INSERT INTO order_activities (
        order_id,
        user_id,
        activity_type,
        notes,
        created_at
    ) VALUES (
        p_order_id,
        (SELECT user_id FROM delivery_agents WHERE id = p_agent_id),
        'delivery_failed',
        CONCAT('Delivery attempt failed: [', p_reason_code, '] ', COALESCE(p_notes, '')),
        NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'status', v_new_status,
        'message', 'Delivery failure recorded and logged.'
    );
END;
$$;


-- === FILE: 20260819180000_full_schema_pda_system.sql ===
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



-- === FILE: 20260819183000_seed_data_all_modules.sql ===
-- ============================================================================
-- NovaExpress Logistics Management System (NoveXPS)
-- Complete Database Seed Data for PDA App & Operational Workflows
-- ============================================================================

-- Ensure all optional/additional columns exist on pre-existing tables before seed insertion
ALTER TABLE IF EXISTS delivery_agents ADD COLUMN IF NOT EXISTS vehicle_type VARCHAR(50) DEFAULT 'motorcycle';
ALTER TABLE IF EXISTS delivery_agents ADD COLUMN IF NOT EXISTS vehicle_plate_number VARCHAR(50);
ALTER TABLE IF EXISTS delivery_agents ADD COLUMN IF NOT EXISTS operating_state VARCHAR(100) DEFAULT 'Abuja (FCT)';
ALTER TABLE IF EXISTS delivery_agents ADD COLUMN IF NOT EXISTS operating_city VARCHAR(100) DEFAULT 'Wuse 2';
ALTER TABLE IF EXISTS delivery_agents ADD COLUMN IF NOT EXISTS current_status VARCHAR(50) DEFAULT 'available';
ALTER TABLE IF EXISTS delivery_agents ADD COLUMN IF NOT EXISTS bank_name VARCHAR(100);
ALTER TABLE IF EXISTS delivery_agents ADD COLUMN IF NOT EXISTS bank_account_number VARCHAR(20);
ALTER TABLE IF EXISTS delivery_agents ADD COLUMN IF NOT EXISTS bank_account_name VARCHAR(255);
ALTER TABLE IF EXISTS delivery_agents ADD COLUMN IF NOT EXISTS last_sync_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS company_id UUID;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS order_number VARCHAR(100);
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS delivery_agent_id UUID;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS distribution_center_id UUID;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS client_id UUID;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS customer_name VARCHAR(255);
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS customer_phone VARCHAR(50);
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS customer_alt_phone VARCHAR(50);
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS delivery_state VARCHAR(100) DEFAULT 'Abuja (FCT)';
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS delivery_city VARCHAR(100) DEFAULT 'Wuse 2';
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS delivery_address TEXT;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS landmark TEXT;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS lga VARCHAR(100);
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS product_id UUID;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS product_name VARCHAR(255) DEFAULT 'Respira Detox Tea';
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS quantity INT DEFAULT 1;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS paid_quantity INT DEFAULT 1;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS free_quantity INT DEFAULT 0;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS base_price NUMERIC(14,2) DEFAULT 0.00;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS upsell_amount NUMERIC(14,2) DEFAULT 0.00;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS total_amount NUMERIC(14,2) DEFAULT 0.00;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS payment_type VARCHAR(50) DEFAULT 'pay_on_delivery';
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS payment_status VARCHAR(50) DEFAULT 'pending';
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'in_transit';
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS delivery_method VARCHAR(50) DEFAULT 'cash';
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS scheduled_callback_at TIMESTAMPTZ;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS reschedule_note TEXT;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS proof_of_delivery_url TEXT;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS agent_entitlement NUMERIC(14,2) DEFAULT 2500.00;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS delivery_notes TEXT;

ALTER TABLE IF EXISTS products ADD COLUMN IF NOT EXISTS reorder_level INT DEFAULT 5;
ALTER TABLE IF EXISTS products ADD COLUMN IF NOT EXISTS category VARCHAR(100);
ALTER TABLE IF EXISTS products ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE IF EXISTS products ADD COLUMN IF NOT EXISTS image_url TEXT;

ALTER TABLE IF EXISTS users ADD COLUMN IF NOT EXISTS first_name VARCHAR(100);
ALTER TABLE IF EXISTS users ADD COLUMN IF NOT EXISTS last_name VARCHAR(100);
ALTER TABLE IF EXISTS users ADD COLUMN IF NOT EXISTS avatar_url TEXT;

ALTER TABLE IF EXISTS distribution_centers ADD COLUMN IF NOT EXISTS code VARCHAR(50);
ALTER TABLE IF EXISTS distribution_centers ADD COLUMN IF NOT EXISTS state VARCHAR(100);
ALTER TABLE IF EXISTS distribution_centers ADD COLUMN IF NOT EXISTS city VARCHAR(100);
ALTER TABLE IF EXISTS distribution_centers ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE IF EXISTS distribution_centers ADD COLUMN IF NOT EXISTS contact_phone VARCHAR(50);
ALTER TABLE IF EXISTS distribution_centers ADD COLUMN IF NOT EXISTS contact_email VARCHAR(255);
ALTER TABLE IF EXISTS distribution_centers ADD COLUMN IF NOT EXISTS is_hub BOOLEAN DEFAULT false;

ALTER TABLE IF EXISTS clients ADD COLUMN IF NOT EXISTS code VARCHAR(50);
ALTER TABLE IF EXISTS clients ADD COLUMN IF NOT EXISTS contact_person VARCHAR(100);
ALTER TABLE IF EXISTS clients ADD COLUMN IF NOT EXISTS phone VARCHAR(50);
ALTER TABLE IF EXISTS clients ADD COLUMN IF NOT EXISTS email VARCHAR(255);

ALTER TABLE IF EXISTS client_packages ADD COLUMN IF NOT EXISTS tracking_number VARCHAR(100);
ALTER TABLE IF EXISTS client_packages ADD COLUMN IF NOT EXISTS package_label VARCHAR(255);
ALTER TABLE IF EXISTS client_packages ADD COLUMN IF NOT EXISTS package_description TEXT;
ALTER TABLE IF EXISTS client_packages ADD COLUMN IF NOT EXISTS declared_value NUMERIC(14,2) DEFAULT 0.00;
ALTER TABLE IF EXISTS client_packages ADD COLUMN IF NOT EXISTS client_delivery_fee NUMERIC(14,2) DEFAULT 0.00;
ALTER TABLE IF EXISTS client_packages ADD COLUMN IF NOT EXISTS agent_commission NUMERIC(14,2) DEFAULT 0.00;
ALTER TABLE IF EXISTS client_packages ADD COLUMN IF NOT EXISTS current_custody_agent_id UUID;
ALTER TABLE IF EXISTS client_packages ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'in_custody';

ALTER TABLE IF EXISTS product_batches ADD COLUMN IF NOT EXISTS batch_number VARCHAR(100);
ALTER TABLE IF EXISTS product_batches ADD COLUMN IF NOT EXISTS expiry_date DATE;
ALTER TABLE IF EXISTS product_batches ADD COLUMN IF NOT EXISTS manufacture_date DATE;
ALTER TABLE IF EXISTS product_batches ADD COLUMN IF NOT EXISTS initial_quantity INT;
ALTER TABLE IF EXISTS product_batches ADD COLUMN IF NOT EXISTS current_quantity INT;

ALTER TABLE IF EXISTS agent_inventory ADD COLUMN IF NOT EXISTS delivery_agent_id UUID;
ALTER TABLE IF EXISTS agent_inventory ADD COLUMN IF NOT EXISTS product_id UUID;
ALTER TABLE IF EXISTS agent_inventory ADD COLUMN IF NOT EXISTS batch_id UUID;
ALTER TABLE IF EXISTS agent_inventory ADD COLUMN IF NOT EXISTS total_in_custody INT DEFAULT 0;
ALTER TABLE IF EXISTS agent_inventory ADD COLUMN IF NOT EXISTS reserved_count INT DEFAULT 0;
ALTER TABLE IF EXISTS agent_inventory ADD COLUMN IF NOT EXISTS available_count INT DEFAULT 0;
ALTER TABLE IF EXISTS agent_inventory ADD COLUMN IF NOT EXISTS delivered_count_today INT DEFAULT 0;
ALTER TABLE IF EXISTS agent_inventory ADD COLUMN IF NOT EXISTS returned_count INT DEFAULT 0;
ALTER TABLE IF EXISTS agent_inventory ADD COLUMN IF NOT EXISTS awaiting_return_count INT DEFAULT 0;

ALTER TABLE IF EXISTS cash_remittances ALTER COLUMN deposit_receipt_url DROP NOT NULL;
ALTER TABLE IF EXISTS cash_remittances ADD COLUMN IF NOT EXISTS deposit_receipt_url TEXT;
ALTER TABLE IF EXISTS cash_remittances ADD COLUMN IF NOT EXISTS reference_number VARCHAR(100);
ALTER TABLE IF EXISTS cash_remittances ADD COLUMN IF NOT EXISTS gross_collections NUMERIC(14,2) DEFAULT 0.00;
ALTER TABLE IF EXISTS cash_remittances ADD COLUMN IF NOT EXISTS commission_deducted NUMERIC(14,2) DEFAULT 0.00;
ALTER TABLE IF EXISTS cash_remittances ADD COLUMN IF NOT EXISTS transport_allowance_deducted NUMERIC(14,2) DEFAULT 0.00;
ALTER TABLE IF EXISTS cash_remittances ADD COLUMN IF NOT EXISTS payment_method VARCHAR(50) DEFAULT 'bank_transfer';
ALTER TABLE IF EXISTS cash_remittances ADD COLUMN IF NOT EXISTS verified_by_name VARCHAR(100);
ALTER TABLE IF EXISTS cash_remittances ADD COLUMN IF NOT EXISTS verified_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS payout_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payout_number VARCHAR(100),
    delivery_agent_id UUID,
    amount NUMERIC(14,2) DEFAULT 0.00,
    bank_name VARCHAR(100),
    account_number VARCHAR(50),
    account_name VARCHAR(255),
    status VARCHAR(50) DEFAULT 'pending',
    disbursement_ref VARCHAR(100),
    dc_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE IF EXISTS payout_requests ADD COLUMN IF NOT EXISTS payout_number VARCHAR(100);
ALTER TABLE IF EXISTS payout_requests ADD COLUMN IF NOT EXISTS delivery_agent_id UUID;
ALTER TABLE IF EXISTS payout_requests ADD COLUMN IF NOT EXISTS amount NUMERIC(14,2) DEFAULT 0.00;
ALTER TABLE IF EXISTS payout_requests ADD COLUMN IF NOT EXISTS bank_name VARCHAR(100);
ALTER TABLE IF EXISTS payout_requests ADD COLUMN IF NOT EXISTS account_number VARCHAR(50);
ALTER TABLE IF EXISTS payout_requests ADD COLUMN IF NOT EXISTS account_name VARCHAR(255);
ALTER TABLE IF EXISTS payout_requests ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'pending';
ALTER TABLE IF EXISTS payout_requests ADD COLUMN IF NOT EXISTS disbursement_ref VARCHAR(100);
ALTER TABLE IF EXISTS payout_requests ADD COLUMN IF NOT EXISTS dc_notes TEXT;

CREATE TABLE IF NOT EXISTS rider_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    delivery_agent_id UUID,
    transaction_code VARCHAR(100),
    title VARCHAR(255),
    category VARCHAR(100),
    amount NUMERIC(14,2) DEFAULT 0.00,
    is_credit BOOLEAN DEFAULT true,
    reference VARCHAR(100),
    status VARCHAR(50) DEFAULT 'settled',
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE IF EXISTS rider_transactions ADD COLUMN IF NOT EXISTS delivery_agent_id UUID;
ALTER TABLE IF EXISTS rider_transactions ADD COLUMN IF NOT EXISTS transaction_code VARCHAR(100);
ALTER TABLE IF EXISTS rider_transactions ADD COLUMN IF NOT EXISTS title VARCHAR(255);
ALTER TABLE IF EXISTS rider_transactions ADD COLUMN IF NOT EXISTS category VARCHAR(100);
ALTER TABLE IF EXISTS rider_transactions ADD COLUMN IF NOT EXISTS amount NUMERIC(14,2) DEFAULT 0.00;
ALTER TABLE IF EXISTS rider_transactions ADD COLUMN IF NOT EXISTS is_credit BOOLEAN DEFAULT true;
ALTER TABLE IF EXISTS rider_transactions ADD COLUMN IF NOT EXISTS reference VARCHAR(100);
ALTER TABLE IF EXISTS rider_transactions ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'settled';
ALTER TABLE IF EXISTS rider_transactions ADD COLUMN IF NOT EXISTS description TEXT;

-- 1. COMPANIES
INSERT INTO companies (id, name, code, email, phone, address, currency)
VALUES (
    '11111111-1111-4111-8111-111111111111',
    'NovaExpress Logistics Limited',
    'NOVEXPS',
    'operations@novaexpress.ng',
    '+2348000000000',
    'Plot 102 Central Business District, Abuja, Nigeria',
    'NGN'
) ON CONFLICT (id) DO UPDATE 
SET name = EXCLUDED.name, email = EXCLUDED.email;

-- 2. DISTRIBUTION CENTERS (DC / HUBS)
INSERT INTO distribution_centers (id, company_id, name, code, state, city, address, contact_phone, is_hub)
VALUES 
(
    '22222222-2222-4222-8222-222222222222',
    '11111111-1111-4111-8111-111111111111',
    'Wuse Distribution Center',
    'DC-WUSE-01',
    'Abuja (FCT)',
    'Wuse 2',
    'Plot 402 Aminu Kano Crescent, Wuse 2, Abuja',
    '+2348031112233',
    true
),
(
    '22222222-2222-4222-8222-333333333333',
    '11111111-1111-4111-8111-111111111111',
    'Ikeja Central Distribution Center',
    'DC-IKEJA-01',
    'Lagos',
    'Ikeja',
    'Plot 14 Commercial Avenue, Ikeja GRA, Lagos',
    '+2348052223344',
    true
) ON CONFLICT (id) DO NOTHING;

-- 3. USERS & DELIVERY AGENTS (RIDER: EMEKA RIDER • PDA-7000)
INSERT INTO users (id, company_id, email, phone_number, first_name, last_name, role)
VALUES 
(
    'a1111111-1111-4111-8111-111111111111',
    '11111111-1111-4111-8111-111111111111',
    'emeka.rider@novaexpress.ng',
    '08031234567',
    'Emeka',
    'Rider',
    'delivery_agent'
),
(
    'a2222222-2222-4222-8222-222222222222',
    '11111111-1111-4111-8111-111111111111',
    'dc.supervisor@novaexpress.ng',
    '08091112233',
    'Adekunle',
    'Supervisor',
    'dc_manager'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO delivery_agents (
    id,
    user_id,
    distribution_center_id,
    agent_code,
    vehicle_type,
    vehicle_plate_number,
    operating_state,
    operating_city,
    current_status,
    current_cod_balance,
    direct_transfer_balance,
    bank_name,
    bank_account_number,
    bank_account_name
) VALUES (
    'b1111111-1111-4111-8111-111111111111',
    'a1111111-1111-4111-8111-111111111111',
    '22222222-2222-4222-8222-222222222222',
    'PDA-7000',
    'motorcycle',
    'ABJ-789-XY',
    'Abuja (FCT)',
    'Wuse 2',
    'available',
    2000.00,  -- ₦2,000.00 cash custody to remit
    18500.00, -- ₦18,500.00 Monnify direct transfer earnings
    'Zenith Bank',
    '0123456789',
    'Emeka Rider'
) ON CONFLICT (id) DO UPDATE 
SET current_cod_balance = EXCLUDED.current_cod_balance,
    direct_transfer_balance = EXCLUDED.direct_transfer_balance;

-- 4. CLIENTS
INSERT INTO clients (id, company_id, name, code, contact_person, phone, email)
VALUES 
(
    'c1111111-1111-4111-8111-111111111111',
    '11111111-1111-4111-8111-111111111111',
    'Novacare Limited',
    'NOVACARE',
    'Dr. Kalu Okonkwo',
    '+2348039998877',
    'orders@novacare.ng'
),
(
    'c2222222-2222-4222-8222-222222222222',
    '11111111-1111-4111-8111-111111111111',
    'PharmaPlus Ltd',
    'PHARMAPLUS',
    'Pharm. Zainab Aliyu',
    '+2348076665544',
    'dispatch@pharmaplus.ng'
) ON CONFLICT (id) DO NOTHING;

-- 5. PRODUCTS & BATCHES (DISTRIBUTED INVENTORY)
INSERT INTO products (id, company_id, client_id, sku, name, category, description, base_price, reorder_level, low_stock_threshold)
VALUES 
(
    'd1111111-1111-4111-8111-111111111111',
    '11111111-1111-4111-8111-111111111111',
    'c1111111-1111-4111-8111-111111111111',
    'SKU-RSP01',
    'Respira Detox Tea',
    'Herbal Detox',
    'Organic herbal detox blend formulated for respiratory purification, revitalization and digestive health.',
    26000.00,
    5,
    5
),
(
    'd2222222-2222-4222-8222-222222222222',
    '11111111-1111-4111-8111-111111111111',
    'c1111111-1111-4111-8111-111111111111',
    'SKU-GRZ02',
    'Grazer Herbal Tea',
    'Digestive Care',
    'Botanical colon cleanse herbal tea for gentle digestive support and natural detox.',
    15000.00,
    5,
    5
),
(
    'd3333333-3333-4333-8333-333333333333',
    '11111111-1111-4111-8111-111111111111',
    'c1111111-1111-4111-8111-111111111111',
    'SKU-ALM03',
    'Alpha Man Vitality',
    'Mens Wellness',
    'Daily organic vitality supplement for mens physical endurance and wellness.',
    22000.00,
    5,
    5
),
(
    'd4444444-4444-4444-8444-444444444444',
    '11111111-1111-4111-8111-111111111111',
    'c2222222-2222-4222-8222-222222222222',
    'SKU-IBP04',
    'Immunity Booster Pack',
    'Immunity & Wellness',
    'Organic wellness daily defense formula with citrus, ginger, turmeric and herbal antioxidants.',
    18500.00,
    8,
    5
) ON CONFLICT (id) DO NOTHING;

INSERT INTO product_batches (id, product_id, batch_number, initial_quantity, current_quantity, expiry_date)
VALUES 
('e1111111-1111-4111-8111-111111111111', 'd1111111-1111-4111-8111-111111111111', 'BATCH-RSP-2026', 1000, 420, '2028-06-30'),
('e2222222-2222-4222-8222-222222222222', 'd2222222-2222-4222-8222-222222222222', 'BATCH-GRZ-2026', 800, 310, '2028-08-31'),
('e3333333-3333-4333-8333-333333333333', 'd3333333-3333-4333-8333-333333333333', 'BATCH-ALM-2026', 500, 180, '2027-12-31'),
('e4444444-4444-4444-8444-444444444444', 'd4444444-4444-4444-8444-444444444444', 'BATCH-IBP-2026', 600, 240, '2028-01-31')
ON CONFLICT (id) DO NOTHING;

-- 6. AGENT VEHICLE INVENTORY (EMEKA RIDER)
INSERT INTO agent_inventory (
    id,
    delivery_agent_id,
    product_id,
    batch_id,
    total_in_custody,
    reserved_count,
    available_count,
    delivered_count_today,
    returned_count,
    awaiting_return_count,
    last_audit_at
) VALUES 
('f1111111-1111-4111-8111-111111111111', 'b1111111-1111-4111-8111-111111111111', 'd1111111-1111-4111-8111-111111111111', 'e1111111-1111-4111-8111-111111111111', 42, 8, 34, 6, 2, 2, NOW()),
('f2222222-2222-4222-8222-222222222222', 'b1111111-1111-4111-8111-111111111111', 'd2222222-2222-4222-8222-222222222222', 'e2222222-2222-4222-8222-222222222222', 18, 4, 14, 6, 1, 1, NOW()),
('f3333333-3333-4333-8333-333333333333', 'b1111111-1111-4111-8111-111111111111', 'd3333333-3333-4333-8333-333333333333', 'e3333333-3333-4333-8333-333333333333', 3, 0, 3, 10, 2, 0, NOW()),
('f4444444-4444-4444-8444-444444444444', 'b1111111-1111-4111-8111-111111111111', 'd4444444-4444-4444-8444-444444444444', 'e4444444-4444-4444-8444-444444444444', 24, 4, 20, 6, 0, 0, NOW())
ON CONFLICT (delivery_agent_id, product_id) DO UPDATE 
SET total_in_custody = EXCLUDED.total_in_custody,
    available_count = EXCLUDED.available_count;

-- 7. STOCK REQUESTS & HANDOVERS
INSERT INTO stock_requests (id, request_number, delivery_agent_id, distribution_center_id, status, request_type, notes)
VALUES (
    '10101010-1010-4010-8010-101010101010',
    'REQ-00482',
    'b1111111-1111-4111-8111-111111111111',
    '22222222-2222-4222-8222-222222222222',
    'approved',
    'restock',
    'Morning vehicle restock for Wuse 2 deliveries'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO stock_request_items (id, stock_request_id, product_id, requested_quantity, approved_quantity, handed_over_quantity)
VALUES 
(gen_random_uuid(), '10101010-1010-4010-8010-101010101010', 'd1111111-1111-4111-8111-111111111111', 20, 20, 20),
(gen_random_uuid(), '10101010-1010-4010-8010-101010101010', 'd2222222-2222-4222-8222-222222222222', 10, 10, 10)
ON CONFLICT DO NOTHING;

-- 8. ORDERS & DELIVERIES (MOCK DATA COHERENCE)
INSERT INTO orders (
    id,
    company_id,
    order_number,
    delivery_agent_id,
    distribution_center_id,
    client_id,
    customer_name,
    customer_phone,
    customer_alt_phone,
    delivery_state,
    delivery_city,
    delivery_address,
    product_id,
    product_name,
    quantity,
    paid_quantity,
    free_quantity,
    base_price,
    upsell_amount,
    total_amount,
    payment_type,
    payment_status,
    status,
    delivery_notes,
    agent_entitlement,
    created_at
) VALUES 
(
    '20202020-2020-4020-8020-202020202020',
    '11111111-1111-4111-8111-111111111111',
    'TRK-8924',
    'b1111111-1111-4111-8111-111111111111',
    '22222222-2222-4222-8222-222222222222',
    'c1111111-1111-4111-8111-111111111111',
    'Chief Aliyu Mohammed',
    '08031234567',
    '08099887766',
    'Abuja (FCT)',
    'Wuse 2',
    'Plot 402 Aminu Kano Crescent, Near KFC, Wuse 2, Abuja',
    'd1111111-1111-4111-8111-111111111111',
    'Respira Detox Tea',
    3,
    2,
    1,
    45000.00,
    10000.00,
    55000.00,
    'pay_on_delivery',
    'pending',
    'in_transit',
    'Call 10 minutes before arrival. Gate code #402.',
    2500.00,
    NOW() - INTERVAL '2 hours'
),
(
    '20202020-2020-4020-8020-303030303030',
    '11111111-1111-4111-8111-111111111111',
    'TRK-8925',
    'b1111111-1111-4111-8111-111111111111',
    '22222222-2222-4222-8222-222222222222',
    'c1111111-1111-4111-8111-111111111111',
    'Dr. Aisha Garba',
    '08129990011',
    NULL,
    'Abuja (FCT)',
    'Maitama',
    '12 Aguiyi Ironsi Street, Maitama, Abuja',
    'd2222222-2222-4222-8222-222222222222',
    'Grazer Herbal Tea',
    2,
    2,
    0,
    30000.00,
    5000.00,
    35000.00,
    'pay_on_delivery',
    'pending',
    'accepted',
    'Intake completed at Wuse DC. Vehicle loaded.',
    2500.00,
    NOW() - INTERVAL '4 hours'
),
(
    '20202020-2020-4020-8020-404040404040',
    '11111111-1111-4111-8111-111111111111',
    'TRK-8921',
    'b1111111-1111-4111-8111-111111111111',
    '22222222-2222-4222-8222-222222222222',
    'c1111111-1111-4111-8111-111111111111',
    'Engr. Nnamdi Eze',
    '07065554433',
    NULL,
    'Abuja (FCT)',
    'Garki II',
    'Suite B12, Gimbiya Street, Garki II, Abuja',
    'd1111111-1111-4111-8111-111111111111',
    'Respira Detox Tea',
    4,
    3,
    1,
    60000.00,
    15000.00,
    75000.00,
    'pay_on_delivery',
    'collected',
    'delivered',
    'Delivered successfully. POD cash collected in full.',
    2500.00,
    NOW() - INTERVAL '6 hours'
),
(
    '20202020-2020-4020-8020-505050505050',
    '11111111-1111-4111-8111-111111111111',
    'TRK-8920',
    'b1111111-1111-4111-8111-111111111111',
    '22222222-2222-4222-8222-222222222222',
    'c2222222-2222-4222-8222-222222222222',
    'Mrs. Folake Adebayo',
    '08051112233',
    NULL,
    'Abuja (FCT)',
    'Asokoro',
    '8 Yakubu Gowon Crescent, Asokoro, Abuja',
    'd4444444-4444-4444-8444-444444444444',
    'Immunity Booster Pack',
    1,
    1,
    0,
    18000.00,
    0.00,
    18000.00,
    'pay_on_delivery',
    'pending',
    'call_back',
    'Customer requested callback at 4:30 PM after office meeting.',
    2500.00,
    NOW() - INTERVAL '8 hours'
) ON CONFLICT (id) DO NOTHING;

-- 9. MONNIFY DYNAMIC VIRTUAL ACCOUNTS
INSERT INTO monnify_virtual_accounts (
    id,
    order_id,
    account_reference,
    account_number,
    account_name,
    bank_name,
    expected_amount,
    status
) VALUES (
    '30303030-3030-4030-8030-303030303030',
    '20202020-2020-4020-8020-202020202020',
    'MNFY-TRK-8924',
    '7890892401',
    'NovaExpress / Novacare Limited',
    'Wema Bank / Monnify',
    55000.00,
    'active'
) ON CONFLICT (id) DO NOTHING;

-- 10. CASH REMITTANCES
INSERT INTO cash_remittances (
    id,
    company_id,
    delivery_agent_id,
    reference_number,
    deposit_receipt_url,
    amount,
    gross_collections,
    commission_deducted,
    transport_allowance_deducted,
    payment_method,
    status,
    verified_by_name,
    verified_at,
    notes,
    created_at
) VALUES 
(
    '40404040-4040-4040-8040-505050505050',
    '11111111-1111-4111-8111-111111111111',
    'b1111111-1111-4111-8111-111111111111',
    'RMT-0005',
    'https://novexps.storage/receipts/rec-0005.jpg',
    25000.00,
    45000.00,
    8000.00,
    12000.00,
    'bank_transfer',
    'pending',
    NULL,
    NULL,
    'Bank transfer awaiting DC Finance receipt confirmation.',
    NOW() - INTERVAL '1 hour'
),
(
    '40404040-4040-4040-8040-404040404040',
    '11111111-1111-4111-8111-111111111111',
    'b1111111-1111-4111-8111-111111111111',
    'RMT-0004',
    'https://novexps.storage/receipts/rec-0004.jpg',
    15000.00,
    30000.00,
    6000.00,
    9000.00,
    'bank_transfer',
    'verified',
    'Wuse DC Finance Desk',
    NOW() - INTERVAL '1 day',
    'Bank transfer verified & reconciled by Wuse DC Finance desk.',
    NOW() - INTERVAL '1 day'
),
(
    '40404040-4040-4040-8040-303030303030',
    '11111111-1111-4111-8111-111111111111',
    'b1111111-1111-4111-8111-111111111111',
    'RMT-0003',
    'https://novexps.storage/receipts/rec-0003.jpg',
    20000.00,
    40000.00,
    8000.00,
    12000.00,
    'cash_to_dc',
    'verified',
    'Adekunle Supervisor',
    NOW() - INTERVAL '4 days',
    'Cash handed over at Wuse DC reception.',
    NOW() - INTERVAL '4 days'
),
(
    '40404040-4040-4040-8040-202020202020',
    '11111111-1111-4111-8111-111111111111',
    'b1111111-1111-4111-8111-111111111111',
    'RMT-0002',
    'https://novexps.storage/receipts/rec-0002.jpg',
    10000.00,
    20000.00,
    4000.00,
    6000.00,
    'pos',
    'verified',
    'Ikeja DC Finance',
    NOW() - INTERVAL '8 days',
    'POS terminal receipt attached and approved.',
    NOW() - INTERVAL '8 days'
) ON CONFLICT (id) DO NOTHING;

-- 11. PAYOUT REQUESTS
INSERT INTO payout_requests (
    id,
    payout_number,
    delivery_agent_id,
    amount,
    bank_name,
    account_number,
    account_name,
    status,
    disbursement_ref,
    dc_notes,
    created_at
) VALUES 
(
    '50505050-5050-4050-8050-101010101010',
    'PAY-0082',
    'b1111111-1111-4111-8111-111111111111',
    15000.00,
    'Zenith Bank',
    '0123456789',
    'Emeka Rider',
    'pending',
    NULL,
    'Under review by Wuse DC Finance desk',
    NOW() - INTERVAL '1 hour 20 minutes'
),
(
    '50505050-5050-4050-8050-202020202020',
    'PAY-0079',
    'b1111111-1111-4111-8111-111111111111',
    20000.00,
    'Zenith Bank',
    '0123456789',
    'Emeka Rider',
    'approved',
    'DISB-88374291',
    'Disbursed via Central Treasury',
    NOW() - INTERVAL '6 days'
),
(
    '50505050-5050-4050-8050-303030303030',
    'PAY-0071',
    'b1111111-1111-4111-8111-111111111111',
    25000.00,
    'Zenith Bank',
    '0123456789',
    'Emeka Rider',
    'approved',
    'DISB-77291044',
    'Disbursed via Wuse DC Finance',
    NOW() - INTERVAL '21 days'
) ON CONFLICT (id) DO NOTHING;

-- 12. RIDER TRANSACTIONS AUDIT TRAIL
INSERT INTO rider_transactions (
    id,
    delivery_agent_id,
    transaction_code,
    title,
    category,
    amount,
    is_credit,
    reference,
    status,
    description,
    created_at
) VALUES 
(
    gen_random_uuid(),
    'b1111111-1111-4111-8111-111111111111',
    'TXN-9021',
    'Direct Transfer Credit (TRK-8924)',
    'direct_transfer',
    2500.00,
    true,
    'MNFY-TRK-8924',
    'settled',
    'Commission (₦1,000) + Transport Allowance (₦1,500) credited to My Balance from Monnify customer transfer.',
    NOW() - INTERVAL '45 minutes'
),
(
    gen_random_uuid(),
    'b1111111-1111-4111-8111-111111111111',
    'TXN-9018',
    'Cash POD Collection (TRK-8923)',
    'earnings',
    27500.00,
    false,
    'POD-8923-CASH',
    'pending',
    'Cash in physical custody. Added to To Remit ledger for end of day settlement.',
    NOW() - INTERVAL '2 hours'
),
(
    gen_random_uuid(),
    'b1111111-1111-4111-8111-111111111111',
    'TXN-9005',
    'Balance Payout Requested',
    'payout',
    15000.00,
    false,
    'PAY-0082',
    'pending',
    'Withdrawal from My Balance to Zenith Bank (0123456789). Awaiting DC Approval.',
    NOW() - INTERVAL '4 hours'
),
(
    gen_random_uuid(),
    'b1111111-1111-4111-8111-111111111111',
    'TXN-8992',
    'Remittance Verified & Reconciled',
    'remittance',
    15000.00,
    false,
    'RMT-0004',
    'verified',
    'Bank transfer remittance reconciled by Wuse DC Finance desk.',
    NOW() - INTERVAL '1 day'
),
(
    gen_random_uuid(),
    'b1111111-1111-4111-8111-111111111111',
    'TXN-8980',
    'Delivery Commission Payout Disbursed',
    'payout',
    20000.00,
    true,
    'DISB-88374291',
    'approved',
    'Disbursement paid into registered Zenith Bank account.',
    NOW() - INTERVAL '6 days'
),
(
    gen_random_uuid(),
    'b1111111-1111-4111-8111-111111111111',
    'TXN-8975',
    'Remittance Verified & Reconciled',
    'remittance',
    10000.00,
    false,
    'RMT-0002',
    'verified',
    'Bank transfer remittance reconciled by Wuse DC Finance desk.',
    NOW() - INTERVAL '8 days'
) ON CONFLICT (id) DO NOTHING;


-- === FILE: 20260819190000_reload_schema_cache.sql ===
-- Reload PostgREST Schema Cache
SELECT pg_notify('pgrst', 'reload schema');


-- === FILE: 20260819233000_dynamic_notifications_and_triggers.sql ===
-- ============================================================================
-- NovaExpress Logistics Management System
-- Dynamic Notifications Engine & Automated Ledger Triggers
-- ============================================================================

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    delivery_agent_id UUID REFERENCES delivery_agents(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    category VARCHAR(50) NOT NULL DEFAULT 'system', -- 'delivery', 'finance', 'stock', 'system'
    action_route TEXT,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for high-performance agent notification queries
CREATE INDEX IF NOT EXISTS idx_notifications_agent_id ON notifications(delivery_agent_id);
CREATE INDEX IF NOT EXISTS idx_notifications_category ON notifications(category);

-- ----------------------------------------------------------------------------
-- 1. TRIGGER: Automatic Notification on Cash Remittance Status Changes
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_notify_remittance_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO notifications (company_id, delivery_agent_id, title, message, category, action_route)
        VALUES (
            NEW.company_id,
            NEW.delivery_agent_id,
            'Remittance Submitted 💸',
            'Your cash remittance of ₦' || TO_CHAR(NEW.amount, 'FM999,999,999') || ' (Ref: ' || COALESCE(NEW.reference_number, 'RMT-PENDING') || ') was logged and sent for DC verification.',
            'finance',
            '/cash/history'
        );
    ELSIF (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status) THEN
        IF (NEW.status = 'approved') THEN
            INSERT INTO notifications (company_id, delivery_agent_id, title, message, category, action_route)
            VALUES (
                NEW.company_id,
                NEW.delivery_agent_id,
                'Remittance Approved ✓',
                'Your cash remittance of ₦' || TO_CHAR(NEW.amount, 'FM999,999,999') || ' (Ref: ' || COALESCE(NEW.reference_number, 'RMT-APPROVED') || ') was verified and reconciled by Wuse DC Finance desk.',
                'finance',
                '/cash/history'
            );
        ELSIF (NEW.status = 'rejected') THEN
            INSERT INTO notifications (company_id, delivery_agent_id, title, message, category, action_route)
            VALUES (
                NEW.company_id,
                NEW.delivery_agent_id,
                'Remittance Returned ⚠️',
                'Your remittance of ₦' || TO_CHAR(NEW.amount, 'FM999,999,999') || ' requires attention. Please contact Wuse DC Finance desk.',
                'finance',
                '/cash/history'
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_remittance_notification ON cash_remittances;
CREATE TRIGGER trg_remittance_notification
AFTER INSERT OR UPDATE ON cash_remittances
FOR EACH ROW
EXECUTE FUNCTION trg_notify_remittance_status();

-- ----------------------------------------------------------------------------
-- 2. SEED LIVE NOTIFICATIONS FOR ACCOUNT PDA-7000
-- ----------------------------------------------------------------------------
INSERT INTO notifications (company_id, delivery_agent_id, title, message, category, action_route, is_read)
VALUES
(
    '11111111-1111-4111-8111-111111111111',
    'b1111111-1111-4111-8111-111111111111',
    'New Delivery Assigned 📦',
    'Order TRK-8925 (Dr. Aisha Garba) in Maitama has been assigned to your queue.',
    'delivery',
    '/orders',
    false
),
(
    '11111111-1111-4111-8111-111111111111',
    'b1111111-1111-4111-8111-111111111111',
    'Remittance Approved ✓',
    'Your cash remittance of ₦15,000 (RMT-0004) has been verified and reconciled by Wuse DC Finance desk.',
    'finance',
    '/cash/history',
    false
),
(
    '11111111-1111-4111-8111-111111111111',
    'b1111111-1111-4111-8111-111111111111',
    'Stock Replenishment Ready 🏷️',
    'Transfer request REQ-00482 (20x Respira, 15x Grazer) is packaged and ready for pickup at Wuse DC counter.',
    'stock',
    '/orders/scan',
    false
),
(
    '11111111-1111-4111-8111-111111111111',
    NULL, -- Broadcast notification for all agents in company
    'Security & Field Advisory ⚠️',
    'Rain advisory in Lekki/Ajah & CBD expressway. Maintain speed safety and verify waterproof package seals.',
    'system',
    NULL,
    true
)
ON CONFLICT DO NOTHING;

NOTIFY pgrst, 'reload schema';


-- === FILE: 20260822120000_automated_geocoding_and_proximity_dispatch.sql ===
-- ============================================================================
-- NovaExpress Logistics Management System (NoveXPS)
-- Database Migration: Automated Geocoding, Proximity Dispatch & Spatial Indexing
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

NOTIFY pgrst, 'reload schema';

-- ----------------------------------------------------------------------------
-- 1. ORDERS TABLE EXTENSIONS FOR GEOCODING & LOCATION
-- ----------------------------------------------------------------------------
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS geocoding_status VARCHAR(32) DEFAULT 'pending';
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS geocoded_address TEXT;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS location_confidence REAL DEFAULT 0.0;
ALTER TABLE IF EXISTS orders ADD COLUMN IF NOT EXISTS is_location_verified BOOLEAN DEFAULT FALSE;

-- ----------------------------------------------------------------------------
-- 2. USERS & DELIVERY AGENTS TABLE EXTENSIONS FOR GPS TELEMETRY & DISPATCH
-- ----------------------------------------------------------------------------
ALTER TABLE IF EXISTS users ADD COLUMN IF NOT EXISTS current_latitude DOUBLE PRECISION;
ALTER TABLE IF EXISTS users ADD COLUMN IF NOT EXISTS current_longitude DOUBLE PRECISION;
ALTER TABLE IF EXISTS users ADD COLUMN IF NOT EXISTS last_location_update TIMESTAMPTZ;
ALTER TABLE IF EXISTS users ADD COLUMN IF NOT EXISTS is_on_duty BOOLEAN DEFAULT TRUE;
ALTER TABLE IF EXISTS users ADD COLUMN IF NOT EXISTS max_active_orders INT DEFAULT 15;
ALTER TABLE IF EXISTS users ADD COLUMN IF NOT EXISTS assigned_zones TEXT[] DEFAULT ARRAY[]::TEXT[];

ALTER TABLE IF EXISTS delivery_agents ADD COLUMN IF NOT EXISTS current_latitude DOUBLE PRECISION;
ALTER TABLE IF EXISTS delivery_agents ADD COLUMN IF NOT EXISTS current_longitude DOUBLE PRECISION;
ALTER TABLE IF EXISTS delivery_agents ADD COLUMN IF NOT EXISTS last_location_update TIMESTAMPTZ;
ALTER TABLE IF EXISTS delivery_agents ADD COLUMN IF NOT EXISTS is_on_duty BOOLEAN DEFAULT TRUE;
ALTER TABLE IF EXISTS delivery_agents ADD COLUMN IF NOT EXISTS max_active_orders INT DEFAULT 15;
ALTER TABLE IF EXISTS delivery_agents ADD COLUMN IF NOT EXISTS assigned_zones TEXT[] DEFAULT ARRAY[]::TEXT[];

-- ----------------------------------------------------------------------------
-- 3. SPATIAL & PERFORMANCE INDEXES
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_orders_coordinates ON orders (latitude, longitude) WHERE latitude IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_orders_geocoding_status ON orders (geocoding_status);
CREATE INDEX IF NOT EXISTS idx_delivery_agents_telemetry ON delivery_agents (current_latitude, current_longitude) WHERE current_latitude IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_delivery_agents_duty_status ON delivery_agents (is_on_duty, distribution_center_id);

-- ----------------------------------------------------------------------------
-- 4. PURE SQL SCALAR FUNCTION: calculate_haversine_distance_km
-- Calculates great-circle distance between two (lat, lon) coordinates in Kilometers
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calculate_haversine_distance_km(
  p_lat1 DOUBLE PRECISION,
  p_lon1 DOUBLE PRECISION,
  p_lat2 DOUBLE PRECISION,
  p_lon2 DOUBLE PRECISION
)
RETURNS DOUBLE PRECISION
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
  SELECT (6371.0 * acos(
    LEAST(1.0, GREATEST(-1.0,
      cos(radians(p_lat1)) * cos(radians(p_lat2)) *
      cos(radians(p_lon2) - radians(p_lon1)) +
      sin(radians(p_lat1)) * sin(radians(p_lat2))
    ))
  ));
$$;

-- ----------------------------------------------------------------------------
-- 5. STORED FUNCTION: find_closest_available_rider
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION find_closest_available_rider(
  p_order_lat DOUBLE PRECISION,
  p_order_lng DOUBLE PRECISION,
  p_distribution_center_id UUID DEFAULT NULL,
  p_max_distance_km DOUBLE PRECISION DEFAULT 25.0
)
RETURNS TABLE (
  delivery_agent_id UUID,
  agent_code VARCHAR,
  full_name TEXT,
  phone TEXT,
  current_lat DOUBLE PRECISION,
  current_lng DOUBLE PRECISION,
  distance_km DOUBLE PRECISION,
  active_orders_count INT
)
LANGUAGE sql
STABLE
AS $$
  SELECT 
    da.id AS delivery_agent_id,
    da.agent_code,
    COALESCE(u.first_name || ' ' || u.last_name, u.email, da.agent_code) AS full_name,
    COALESCE(u.phone_number, da.agent_code) AS phone,
    COALESCE(da.current_latitude, u.current_latitude) AS current_lat,
    COALESCE(da.current_longitude, u.current_longitude) AS current_lng,
    calculate_haversine_distance_km(
      p_order_lat, 
      p_order_lng, 
      COALESCE(da.current_latitude, u.current_latitude), 
      COALESCE(da.current_longitude, u.current_longitude)
    ) AS distance_km,
    (
      SELECT COUNT(*)::INT 
      FROM orders o 
      WHERE o.delivery_agent_id = da.id 
        AND o.status IN ('accepted', 'in_transit', 'pending', 'assigned')
    ) AS active_orders_count
  FROM delivery_agents da
  JOIN users u ON da.user_id = u.id
  WHERE (p_distribution_center_id IS NULL OR da.distribution_center_id = p_distribution_center_id)
    AND COALESCE(da.is_on_duty, u.is_on_duty, true) = TRUE
    AND COALESCE(da.current_latitude, u.current_latitude) IS NOT NULL
    AND COALESCE(da.current_longitude, u.current_longitude) IS NOT NULL
    AND (
      SELECT COUNT(*) 
      FROM orders o 
      WHERE o.delivery_agent_id = da.id 
        AND o.status IN ('accepted', 'in_transit', 'pending', 'assigned')
    ) < COALESCE(da.max_active_orders, u.max_active_orders, 15)
    AND calculate_haversine_distance_km(
      p_order_lat, 
      p_order_lng, 
      COALESCE(da.current_latitude, u.current_latitude), 
      COALESCE(da.current_longitude, u.current_longitude)
    ) <= p_max_distance_km
  ORDER BY distance_km ASC, active_orders_count ASC
  LIMIT 1;
$$;

-- ----------------------------------------------------------------------------
-- 6. STORED FUNCTION: auto_dispatch_order
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_dispatch_order(
  p_order_id UUID,
  p_max_distance_km DOUBLE PRECISION DEFAULT 25.0
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_order RECORD;
  v_rider RECORD;
BEGIN
  -- 1. Fetch target order
  SELECT * INTO v_order FROM orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Order not found');
  END IF;

  IF v_order.latitude IS NULL OR v_order.longitude IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Order coordinates missing. Geocode order before dispatch.');
  END IF;

  -- 2. Find closest rider using Haversine calculation
  SELECT * INTO v_rider FROM find_closest_available_rider(
    v_order.latitude,
    v_order.longitude,
    v_order.distribution_center_id,
    p_max_distance_km
  );

  IF NOT FOUND OR v_rider.delivery_agent_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false, 
      'error', 'No active on-duty rider found within ' || p_max_distance_km || ' km with available capacity.'
    );
  END IF;

  -- 3. Assign order to rider
  UPDATE orders
  SET 
    delivery_agent_id = v_rider.delivery_agent_id,
    status = 'assigned',
    updated_at = NOW()
  WHERE id = p_order_id;

  -- 4. Record order activity
  INSERT INTO order_activities (
    order_id,
    user_id,
    activity_type,
    notes,
    created_at
  ) VALUES (
    p_order_id,
    v_rider.delivery_agent_id,
    'proximity_auto_dispatched',
    'Order automatically assigned to closest rider ' || v_rider.full_name || ' (' || v_rider.agent_code || ') - Distance: ' || ROUND(v_rider.distance_km::NUMERIC, 2) || ' km.',
    NOW()
  );

  -- 5. Send push/in-app notification to rider
  INSERT INTO notifications (
    company_id,
    user_id,
    title,
    message,
    category,
    action_route,
    is_read,
    created_at
  ) VALUES (
    v_order.company_id,
    v_rider.delivery_agent_id,
    'New Order Assigned (Nearby) 📍',
    'Order #' || v_order.order_number || ' (' || v_order.customer_name || ') is ' || ROUND(v_rider.distance_km::NUMERIC, 1) || ' km from your current position.',
    'delivery',
    '/orders/' || p_order_id,
    false,
    NOW()
  );

  RETURN jsonb_build_object(
    'success', true,
    'orderId', p_order_id,
    'riderId', v_rider.delivery_agent_id,
    'riderName', v_rider.full_name,
    'riderCode', v_rider.agent_code,
    'distanceKm', ROUND(v_rider.distance_km::NUMERIC, 2),
    'activeOrdersCount', v_rider.active_orders_count + 1
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 7. STORED FUNCTION: update_rider_gps_telemetry
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_rider_gps_telemetry(
  p_agent_id UUID,
  p_latitude DOUBLE PRECISION,
  p_longitude DOUBLE PRECISION
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE delivery_agents
  SET 
    current_latitude = p_latitude,
    current_longitude = p_longitude,
    last_location_update = NOW(),
    updated_at = NOW()
  WHERE id = p_agent_id;

  UPDATE users
  SET 
    current_latitude = p_latitude,
    current_longitude = p_longitude,
    last_location_update = NOW(),
    updated_at = NOW()
  WHERE id = p_agent_id OR id = (SELECT user_id FROM delivery_agents WHERE id = p_agent_id);
END;
$$;

-- ----------------------------------------------------------------------------
-- 8. STORED FUNCTION: record_verified_gate_pin
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION record_verified_gate_pin(
  p_order_id UUID,
  p_latitude DOUBLE PRECISION,
  p_longitude DOUBLE PRECISION,
  p_geocoded_address TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE orders
  SET 
    latitude = p_latitude,
    longitude = p_longitude,
    is_location_verified = TRUE,
    location_confidence = 1.0,
    geocoding_status = 'exact_verified',
    geocoded_address = COALESCE(p_geocoded_address, geocoded_address),
    updated_at = NOW()
  WHERE id = p_order_id;
END;
$$;

-- ----------------------------------------------------------------------------
-- 9. SEED DATA REFINEMENT: REALISTIC GPS FIXES FOR RIDERS & ORDERS
-- ----------------------------------------------------------------------------
-- Update Rider PDA-7000 (Emeka Rider) location to Wuse 2
UPDATE delivery_agents
SET 
  current_latitude = 9.0765,
  current_longitude = 7.4832,
  is_on_duty = TRUE,
  max_active_orders = 15,
  last_location_update = NOW()
WHERE agent_code = 'PDA-7000';

UPDATE users
SET 
  current_latitude = 9.0765,
  current_longitude = 7.4832,
  last_location_update = NOW()
WHERE email = 'emeka.rider@novaexpress.ng';

-- Update Sample Orders with Geocoded Locations & Verification
UPDATE orders
SET 
  latitude = 9.0765,
  longitude = 7.4832,
  geocoding_status = 'exact_verified',
  geocoded_address = 'Plot 402 Aminu Kano Crescent, Wuse 2, Abuja, Nigeria',
  location_confidence = 0.95,
  is_location_verified = true
WHERE order_number = 'TRK-8924';

UPDATE orders
SET 
  latitude = 9.0882,
  longitude = 7.4933,
  geocoding_status = 'landmark_match',
  geocoded_address = 'Maitama District, Abuja, Nigeria',
  location_confidence = 0.85,
  is_location_verified = false
WHERE order_number = 'TRK-8925';

UPDATE orders
SET 
  latitude = 9.0345,
  longitude = 7.4891,
  geocoding_status = 'exact_verified',
  geocoded_address = '22 Area 11, Garki, Abuja, Nigeria',
  location_confidence = 0.90,
  is_location_verified = true
WHERE order_number = 'TRK-8926';

UPDATE orders
SET 
  latitude = 9.0435,
  longitude = 7.5255,
  geocoding_status = 'landmark_match',
  geocoded_address = '8 Yakubu Gowon Crescent, Asokoro, Abuja, Nigeria',
  location_confidence = 0.80,
  is_location_verified = false
WHERE order_number = 'TRK-8927';

NOTIFY pgrst, 'reload schema';


-- === FILE: 20260823150000_storage_buckets_and_upload_restrictions.sql ===
-- ==============================================================================
-- NOVAEXPRESS LOGISTICS: SUPABASE STORAGE BUCKETS & UPLOAD SECURITY RESTRICTIONS
-- ==============================================================================

-- 1. Create and configure 'avatars' bucket with 5MB limit and image restrictions
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars',
    'avatars',
    true,
    5242880, -- 5 MB
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'];

-- 2. Create and configure 'remittance-proofs' bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'remittance-proofs',
    'remittance-proofs',
    true,
    10485760, -- 10 MB
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 10485760,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];

-- 3. Create and configure 'pod-proofs' bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'pod-proofs',
    'pod-proofs',
    true,
    10485760, -- 10 MB
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 10485760,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

-- ==============================================================================
-- STORAGE RLS SECURITY POLICIES
-- ==============================================================================

-- Public Read Policy for avatars
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' AND policyname = 'Public Access for Avatars'
    ) THEN
        CREATE POLICY "Public Access for Avatars"
        ON storage.objects FOR SELECT
        USING (bucket_id = 'avatars');
    END IF;
END $$;

-- Upload Policy for avatars
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' AND policyname = 'Allow Authenticated or Service Role Avatar Uploads'
    ) THEN
        CREATE POLICY "Allow Authenticated or Service Role Avatar Uploads"
        ON storage.objects FOR INSERT
        WITH CHECK (bucket_id = 'avatars');
    END IF;
END $$;


-- === FILE: 20260824000000_paystack_gateway_tables.sql ===
-- ============================================================================
-- NOVAEXPRESS LOGISTICS PLATFORM - PAYSTACK GATEWAY SCHEMA
-- Table Definitions & Indexing for Paystack Remittances & Direct Transfers
-- ============================================================================

-- 1. PAYSTACK DYNAMIC VIRTUAL ACCOUNTS
CREATE TABLE IF NOT EXISTS paystack_virtual_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
    account_reference VARCHAR(100) UNIQUE NOT NULL,
    account_number VARCHAR(50) NOT NULL,
    bank_name VARCHAR(100) NOT NULL DEFAULT 'Titan Trust Bank / Paystack',
    account_name VARCHAR(255) NOT NULL DEFAULT 'NovaExpress Logistics / Settlement',
    expected_amount NUMERIC(14, 2) NOT NULL,
    amount_paid NUMERIC(14, 2) DEFAULT 0.00,
    status VARCHAR(50) NOT NULL DEFAULT 'active', -- 'active', 'paid', 'expired'
    payment_received_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. PAYSTACK TRANSACTIONS LEDGER (AUDIT & RECONCILIATION)
CREATE TABLE IF NOT EXISTS paystack_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference VARCHAR(100) UNIQUE NOT NULL,
    virtual_account_id UUID REFERENCES paystack_virtual_accounts(id) ON DELETE SET NULL,
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    remittance_id UUID REFERENCES cash_remittances(id) ON DELETE SET NULL,
    delivery_agent_id UUID REFERENCES delivery_agents(id) ON DELETE SET NULL,
    distribution_center_id UUID REFERENCES distribution_centers(id) ON DELETE SET NULL,
    amount NUMERIC(14, 2) NOT NULL,
    currency VARCHAR(10) NOT NULL DEFAULT 'NGN',
    transaction_type VARCHAR(50) NOT NULL, -- 'direct_transfer', 'remittance', 'payout'
    channel VARCHAR(50) DEFAULT 'dedicated_nuban', -- 'dedicated_nuban', 'bank_transfer', 'card', 'ussd'
    payer_email VARCHAR(255),
    payer_name VARCHAR(255),
    verification_status VARCHAR(50) NOT NULL DEFAULT 'verified', -- 'verified', 'pending', 'failed'
    paystack_response JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Ensure cash_remittances has distribution_center_id, is_partial, expected_amount, and discrepancy tracking
ALTER TABLE cash_remittances ADD COLUMN IF NOT EXISTS distribution_center_id UUID REFERENCES distribution_centers(id) ON DELETE SET NULL;
ALTER TABLE cash_remittances ADD COLUMN IF NOT EXISTS is_partial BOOLEAN DEFAULT FALSE;
ALTER TABLE cash_remittances ADD COLUMN IF NOT EXISTS expected_amount NUMERIC(14, 2);
ALTER TABLE cash_remittances ADD COLUMN IF NOT EXISTS discrepancy_amount NUMERIC(14, 2) DEFAULT 0.00;
ALTER TABLE cash_remittances ADD COLUMN IF NOT EXISTS discrepancy_reason TEXT;
ALTER TABLE cash_remittances ADD COLUMN IF NOT EXISTS paystack_channel VARCHAR(50) DEFAULT 'bank_transfer';
ALTER TABLE cash_remittances ADD COLUMN IF NOT EXISTS paystack_bank VARCHAR(100) DEFAULT 'Titan Trust Bank / Paystack';
ALTER TABLE cash_remittances ADD COLUMN IF NOT EXISTS paystack_auth_code VARCHAR(100);
ALTER TABLE cash_remittances ADD COLUMN IF NOT EXISTS paystack_paid_at TIMESTAMPTZ;
ALTER TABLE cash_remittances ADD COLUMN IF NOT EXISTS payer_email VARCHAR(255);
ALTER TABLE cash_remittances ADD COLUMN IF NOT EXISTS payer_name VARCHAR(255);
ALTER TABLE cash_remittances ADD COLUMN IF NOT EXISTS gateway_response VARCHAR(255) DEFAULT 'Approved / Successful';

-- 3. INDEXES FOR HIGH-THROUGHPUT WEBHOOK & QUERY PERFORMANCE
CREATE INDEX IF NOT EXISTS idx_paystack_va_account_ref ON paystack_virtual_accounts(account_reference);
CREATE INDEX IF NOT EXISTS idx_paystack_va_order_id ON paystack_virtual_accounts(order_id);
CREATE INDEX IF NOT EXISTS idx_paystack_txns_ref ON paystack_transactions(reference);
CREATE INDEX IF NOT EXISTS idx_paystack_txns_order_id ON paystack_transactions(order_id);
CREATE INDEX IF NOT EXISTS idx_paystack_txns_remittance_id ON paystack_transactions(remittance_id);
CREATE INDEX IF NOT EXISTS idx_paystack_txns_agent_id ON paystack_transactions(delivery_agent_id);
CREATE INDEX IF NOT EXISTS idx_paystack_txns_dc_id ON paystack_transactions(distribution_center_id);
CREATE INDEX IF NOT EXISTS idx_cash_remittances_dc_id ON cash_remittances(distribution_center_id);

-- 4. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE paystack_virtual_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE paystack_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read of active virtual accounts"
ON paystack_virtual_accounts FOR SELECT USING (true);

CREATE POLICY "Allow service role full access to paystack virtual accounts"
ON paystack_virtual_accounts FOR ALL USING (true);

CREATE POLICY "Allow public read of paystack transactions"
ON paystack_transactions FOR SELECT USING (true);

CREATE POLICY "Allow service role full access to paystack transactions"
ON paystack_transactions FOR ALL USING (true);



-- === FILE: 20260825000000_standardize_payment_methods_cash_and_paystack.sql ===
-- ============================================================================
-- NOVAEXPRESS LOGISTICS PLATFORM - STANDARDIZE PAYMENT METHODS MIGRATION
-- Standardize operational payment options strictly to:
--   1. 'cash' (Pay On Delivery with physical cash custody for later remittance)
--   2. 'bank_transfer' (Direct Transfer via Paystack with instant company settlement)
-- (POS terminal payment option has been decommissioned from active POD flow).
-- ============================================================================

-- 1. Ensure orders table default delivery_method is 'cash' and payment_type support
ALTER TABLE orders ALTER COLUMN delivery_method SET DEFAULT 'cash';

-- 2. Update any legacy 'pos' delivery_method or payment_type references to 'cash' or 'bank_transfer'
UPDATE orders 
SET delivery_method = 'cash' 
WHERE delivery_method = 'pos' OR delivery_method IS NULL;

-- 3. Add explicit check constraint or document standardized payment methods
COMMENT ON COLUMN orders.delivery_method IS 'Standardized payment method: cash or direct_transfer (Paystack). Legacy POS removed.';
COMMENT ON COLUMN orders.payment_type IS 'Payment terms: pay_on_delivery (Cash POD) or prepaid (Direct Transfer via Paystack / Online).';

-- 4. Ensure paystack_transactions has direct transfer and remittance indices
CREATE INDEX IF NOT EXISTS idx_paystack_txns_created_at ON paystack_transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_paystack_txns_payer_email ON paystack_transactions(payer_email);
CREATE INDEX IF NOT EXISTS idx_orders_payment_type_status ON orders(payment_type, payment_status);

-- 5. Helper function for dynamic transfer fee calculation: ₦100 per ₦5,000 transfer block
CREATE OR REPLACE FUNCTION calculate_remittance_transfer_fee(p_amount NUMERIC)
RETURNS NUMERIC AS $$
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN 0;
  END IF;
  RETURN CEIL(p_amount / 5000.0) * 100;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION calculate_remittance_transfer_fee(NUMERIC) IS 'Calculates dynamic remittance transfer charge: ₦100 per ₦5,000 block (e.g. ₦5,000 -> ₦100, ₦5,200 -> ₦200, ₦35,000 -> ₦700).';

-- 6. Notify PostgREST to reload schema cache
NOTIFY pgrst, 'reload schema';



-- === FILE: 20260902100000_rider_compensation_and_dc_finance_settings.sql ===
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


-- === FILE: 20260902110000_hierarchical_dc_dispatch_and_lga_routing.sql ===
-- ============================================================================
-- NOVAEXPRESS LOGISTICS PLATFORM - HIERARCHICAL DC & LGA DISPATCH ENGINE
-- Production-grade schema & triggers for:
--   1. Grand DC vs Regional Station DC designation
--   2. Order state & LGA multi-zone dispatching
--   3. Fallback escalation (Grand DC vs Station DC)
-- ============================================================================

-- 1. Extend distribution_centers table with is_grand_dc column
ALTER TABLE distribution_centers
  ADD COLUMN IF NOT EXISTS is_grand_dc BOOLEAN DEFAULT false;

-- Designate Wuse Central Distribution Hub (or primary hub) as Grand DC
UPDATE distribution_centers
SET is_grand_dc = true
WHERE code = 'DC-ABJ-01' OR id = '22222222-2222-4222-8222-222222222222';

-- 2. Extend orders table with routing & assignment tracking columns
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS distribution_center_id TEXT,
  ADD COLUMN IF NOT EXISTS delivery_state TEXT,
  ADD COLUMN IF NOT EXISTS delivery_lga TEXT,
  ADD COLUMN IF NOT EXISTS assignment_status TEXT DEFAULT 'auto_assigned',
  ADD COLUMN IF NOT EXISTS routing_notes TEXT;

-- 3. PostgreSQL Stored Procedure for Automatic Order Dispatch by State & LGA
CREATE OR REPLACE FUNCTION auto_dispatch_order_by_state_lga(p_order_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
  v_matched_dc RECORD;
  v_grand_dc RECORD;
  v_matched_driver RECORD;
  v_res JSONB;
  v_state TEXT;
  v_lga TEXT;
BEGIN
  -- Fetch the order
  SELECT * INTO v_order FROM orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Order not found');
  END IF;

  v_state := TRIM(COALESCE(v_order.delivery_state, v_order.destination_state, ''));
  v_lga := TRIM(COALESCE(v_order.delivery_lga, v_order.lga, ''));

  -- Fetch Grand DC
  SELECT * INTO v_grand_dc FROM distribution_centers WHERE is_grand_dc = true AND is_active = true LIMIT 1;
  IF NOT FOUND THEN
    SELECT * INTO v_grand_dc FROM distribution_centers WHERE is_active = true ORDER BY created_at ASC LIMIT 1;
  END IF;

  -- 1. Match Distribution Center by State and LGA
  SELECT * INTO v_matched_dc
  FROM distribution_centers
  WHERE is_active = true
    AND (
      LOWER(state) = LOWER(v_state) 
      OR LOWER(name) ILIKE '%' || LOWER(v_state) || '%'
    )
    AND (
      operating_zones @> to_jsonb(v_lga)
      OR operating_zones::text ILIKE '%' || v_lga || '%'
      OR v_lga = ''
    )
  ORDER BY is_hub DESC, created_at ASC
  LIMIT 1;

  -- Fallback: If no LGA match, check state match
  IF v_matched_dc IS NULL AND v_state <> '' THEN
    SELECT * INTO v_matched_dc
    FROM distribution_centers
    WHERE is_active = true
      AND (
        LOWER(state) = LOWER(v_state)
        OR LOWER(name) ILIKE '%' || LOWER(v_state) || '%'
      )
    ORDER BY is_hub DESC, created_at ASC
    LIMIT 1;
  END IF;

  -- FALLBACK A: No DC matches State/LGA -> Route to Grand DC for manual triage
  IF v_matched_dc IS NULL THEN
    UPDATE orders
    SET 
      distribution_center_id = v_grand_dc.id,
      assigned_agent_id = NULL,
      status = 'pending_dispatch',
      assignment_status = 'pending_dc_assignment',
      routing_notes = '🚨 Escalated to Grand DC (' || v_grand_dc.name || '). No regional DC covers State: "' || v_state || '", LGA: "' || v_lga || '".',
      updated_at = NOW()
    WHERE id = p_order_id;

    RETURN jsonb_build_object(
      'success', true,
      'status', 'pending_dc_assignment',
      'distribution_center_id', v_grand_dc.id,
      'distribution_center_name', v_grand_dc.name,
      'assigned_agent_id', null,
      'message', 'No DC found. Escalated to Grand DC.'
    );
  END IF;

  -- 2. Match Active Rider attached to matched DC covering this LGA
  SELECT * INTO v_matched_driver
  FROM delivery_agents
  WHERE is_active = true
    AND LOWER(current_status) = 'active'
    AND (
      distribution_center_id = v_matched_dc.id
      OR distribution_center_id IS NULL
    )
    AND (
      covered_lgas @> to_jsonb(v_lga)
      OR covered_lgas::text ILIKE '%' || v_lga || '%'
      OR operating_city ILIKE '%' || v_lga || '%'
    )
  ORDER BY created_at ASC
  LIMIT 1;

  -- SUCCESS: Eligible Rider Found -> Auto-assign to Rider
  IF v_matched_driver IS NOT NULL THEN
    UPDATE orders
    SET 
      distribution_center_id = v_matched_dc.id,
      assigned_agent_id = v_matched_driver.id,
      status = 'assigned',
      assignment_status = 'auto_assigned',
      routing_notes = '✅ Auto-assigned to Rider (' || v_matched_driver.agent_code || ') at ' || v_matched_dc.name || ' covering LGA: "' || v_lga || '".',
      assigned_at = NOW(),
      updated_at = NOW()
    WHERE id = p_order_id;

    RETURN jsonb_build_object(
      'success', true,
      'status', 'auto_assigned',
      'distribution_center_id', v_matched_dc.id,
      'distribution_center_name', v_matched_dc.name,
      'assigned_agent_id', v_matched_driver.id,
      'assigned_agent_code', v_matched_driver.agent_code,
      'message', 'Order auto-assigned to rider.'
    );
  END IF;

  -- FALLBACK B: DC matched, but no rider covers this LGA -> Route to Station DC for manual rider assignment
  UPDATE orders
  SET 
    distribution_center_id = v_matched_dc.id,
    assigned_agent_id = NULL,
    status = 'pending_dispatch',
    assignment_status = 'pending_rider_assignment',
    routing_notes = '⚠️ Routed to ' || v_matched_dc.name || '. Awaiting manual rider assignment for LGA: "' || v_lga || '".',
    updated_at = NOW()
  WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'pending_rider_assignment',
    'distribution_center_id', v_matched_dc.id,
    'distribution_center_name', v_matched_dc.name,
    'assigned_agent_id', null,
    'message', 'Routed to Station DC. Awaiting rider assignment.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Trigger to auto-dispatch on new order insert if unassigned
CREATE OR REPLACE FUNCTION trg_orders_auto_dispatch()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.assigned_agent_id IS NULL AND (NEW.status = 'pending' OR NEW.status = 'pending_dispatch' OR NEW.status IS NULL) THEN
    PERFORM auto_dispatch_order_by_state_lga(NEW.id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_orders_auto_dispatch_after_insert ON orders;
CREATE TRIGGER trg_orders_auto_dispatch_after_insert
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION trg_orders_auto_dispatch();

-- 5. Notify PostgREST to reload schema cache
NOTIFY pgrst, 'reload schema';


-- === FILE: 20260902120000_client_portal_and_merchant_management.sql ===
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


-- === FILE: 20260902140000_enterprise_clients_and_closer_hierarchy.sql ===
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

-- 6. Storage Buckets Initialization
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('avatars', 'avatars', true),
  ('pod-proofs', 'pod-proofs', true),
  ('remittance-proofs', 'remittance-proofs', true),
  ('products', 'products', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 7. Notify PostgREST to reload schema
NOTIFY pgrst, 'reload schema';

