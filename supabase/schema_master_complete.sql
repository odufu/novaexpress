-- ============================================================================
-- NOVEXPS MASTER DATABASE REPRODUCTION SCHEMA & SEED SCRIPT
-- Single-File Deployment for Fresh Supabase Projects / Accounts
-- Target: Complete NovaXpress logistics, finance, inventory & chat backend
-- Generated: 2026-09-16
-- ============================================================================

-- Enable required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 1. STORAGE BUCKETS & STORAGE POLICIES
-- ============================================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('avatars', 'avatars', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']),
    ('products', 'products', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']),
    ('pod-proofs', 'pod-proofs', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp']),
    ('remittance-proofs', 'remittance-proofs', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']),
    ('receipts', 'receipts', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Storage access policies
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Public Access for All Buckets') THEN
        CREATE POLICY "Public Access for All Buckets" ON storage.objects FOR SELECT USING (bucket_id IN ('avatars', 'products', 'pod-proofs', 'remittance-proofs', 'receipts'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Allow Uploads for All Buckets') THEN
        CREATE POLICY "Allow Uploads for All Buckets" ON storage.objects FOR INSERT WITH CHECK (bucket_id IN ('avatars', 'products', 'pod-proofs', 'remittance-proofs', 'receipts'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Allow Updates for All Buckets') THEN
        CREATE POLICY "Allow Updates for All Buckets" ON storage.objects FOR UPDATE USING (bucket_id IN ('avatars', 'products', 'pod-proofs', 'remittance-proofs', 'receipts'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Allow Deletes for All Buckets') THEN
        CREATE POLICY "Allow Deletes for All Buckets" ON storage.objects FOR DELETE USING (bucket_id IN ('avatars', 'products', 'pod-proofs', 'remittance-proofs', 'receipts'));
    END IF;
END $$;

-- ============================================================================
-- 2. CORE MASTER TABLES
-- ============================================================================

-- 2.1 Companies (Tenants)
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

-- 2.2 Distribution Centers (Hubs & Sub-hubs)
CREATE TABLE IF NOT EXISTS distribution_centers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) UNIQUE NOT NULL,
    state VARCHAR(100) NOT NULL,
    city VARCHAR(100) NOT NULL,
    address TEXT NOT NULL,
    contact_phone VARCHAR(50),
    contact_email VARCHAR(255),
    is_hub BOOLEAN DEFAULT false,
    is_grand_dc BOOLEAN DEFAULT false,
    is_primary_dc BOOLEAN DEFAULT false,
    parent_dc_id UUID REFERENCES distribution_centers(id) ON DELETE SET NULL,
    manager_name VARCHAR(150),
    storage_capacity_units INT DEFAULT 10000,
    operating_zones JSONB DEFAULT '[]'::jsonb,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.3 Warehouses
CREATE TABLE IF NOT EXISTS warehouses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    rider_id UUID,
    distribution_center_id UUID REFERENCES distribution_centers(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) DEFAULT 'hub',
    location_state VARCHAR(100),
    location_city VARCHAR(100),
    address TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.4 Users
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES companies(id) ON DELETE SET NULL,
    distribution_center_id UUID REFERENCES distribution_centers(id) ON DELETE SET NULL,
    distribution_center_name VARCHAR(255),
    client_id UUID,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone_number VARCHAR(50) UNIQUE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'delivery_agent',
    personnel_type VARCHAR(50) DEFAULT 'pda',
    compensation_type VARCHAR(50) DEFAULT 'commission_based',
    commission_rate NUMERIC(14,2) DEFAULT 1000.00,
    transport_allowance NUMERIC(14,2) DEFAULT 1500.00,
    fuel_allowance NUMERIC(14,2) DEFAULT 800.00,
    failed_delivery_allowance NUMERIC(14,2) DEFAULT 500.00,
    base_salary NUMERIC(14,2) DEFAULT 0.00,
    operating_state VARCHAR(100),
    operating_city VARCHAR(100),
    current_latitude DOUBLE PRECISION,
    current_longitude DOUBLE PRECISION,
    last_location_update TIMESTAMPTZ,
    is_on_duty BOOLEAN DEFAULT true,
    max_active_orders INT DEFAULT 15,
    assigned_zones TEXT[] DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.5 Delivery Agents (PDA Riders)
CREATE TABLE IF NOT EXISTS delivery_agents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    distribution_center_id UUID REFERENCES distribution_centers(id) ON DELETE SET NULL,
    agent_code VARCHAR(50) UNIQUE NOT NULL,
    full_name VARCHAR(255),
    vehicle_type VARCHAR(50) DEFAULT 'Motorcycle',
    vehicle_plate_number VARCHAR(50),
    operating_state VARCHAR(100),
    operating_city VARCHAR(100),
    covered_lgas JSONB DEFAULT '[]'::jsonb,
    current_status VARCHAR(50) DEFAULT 'available',
    current_cod_balance NUMERIC(14,2) DEFAULT 0.00,
    direct_transfer_balance NUMERIC(14,2) DEFAULT 0.00,
    bank_name VARCHAR(100),
    bank_account_number VARCHAR(50),
    bank_account_name VARCHAR(150),
    personnel_type VARCHAR(50) DEFAULT 'pda',
    compensation_type VARCHAR(50) DEFAULT 'commission_based',
    commission_rate NUMERIC(14,2) DEFAULT 1000.00,
    transport_allowance NUMERIC(14,2) DEFAULT 1500.00,
    fuel_allowance NUMERIC(14,2) DEFAULT 800.00,
    failed_delivery_allowance NUMERIC(14,2) DEFAULT 500.00,
    base_salary NUMERIC(14,2) DEFAULT 0.00,
    upsell_bonus_percent NUMERIC(5,2) DEFAULT 0.00,
    guarantor_name VARCHAR(150),
    guarantor_phone VARCHAR(50),
    current_latitude DOUBLE PRECISION,
    current_longitude DOUBLE PRECISION,
    last_location_update TIMESTAMPTZ,
    last_sync_at TIMESTAMPTZ,
    is_on_duty BOOLEAN DEFAULT true,
    max_active_orders INT DEFAULT 15,
    assigned_zones TEXT[] DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.6 Clients (Merchants)
CREATE TABLE IF NOT EXISTS clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES companies(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    company_name VARCHAR(255) NOT NULL,
    contact_person VARCHAR(255),
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(50) NOT NULL,
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    code VARCHAR(50) UNIQUE NOT NULL,
    tier VARCHAR(50) DEFAULT 'standard_merchant',
    closer_limit INT DEFAULT 0,
    is_enterprise BOOLEAN DEFAULT false,
    bank_name VARCHAR(100),
    account_number VARCHAR(50),
    account_name VARCHAR(255),
    settlement_frequency VARCHAR(50) DEFAULT 'daily',
    settlement_schedule VARCHAR(50) DEFAULT 'daily_22_00',
    settlement_day VARCHAR(50) DEFAULT 'Daily',
    is_active BOOLEAN DEFAULT true,
    -- Negotiated Operational Charges overrides:
    custom_delivery_fee NUMERIC(14,2) DEFAULT 5000.00,
    custom_failed_attempt_fee NUMERIC(14,2) DEFAULT 1000.00,
    custom_platform_fee NUMERIC(14,2) DEFAULT 500.00,
    custom_platform_fee_type VARCHAR(20) DEFAULT 'flat',
    custom_platform_fee_value NUMERIC(14,2) DEFAULT 500.00,
    custom_paystack_fee_absorbed_by VARCHAR(50) DEFAULT 'merchant',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.7 Client Telesales Closers
CREATE TABLE IF NOT EXISTS client_closers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    closer_code VARCHAR(50) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(50) NOT NULL,
    commission_rate NUMERIC(14,2) DEFAULT 500.00,
    is_active BOOLEAN DEFAULT true,
    total_assigned_leads INT DEFAULT 0,
    total_confirmed_orders INT DEFAULT 0,
    total_delivered_orders INT DEFAULT 0,
    total_earned_commission NUMERIC(14,2) DEFAULT 0.00,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.8 Customer Leads
CREATE TABLE IF NOT EXISTS customer_leads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    assigned_closer_id UUID REFERENCES client_closers(id) ON DELETE SET NULL,
    lead_source VARCHAR(100) DEFAULT 'facebook_ad',
    customer_name VARCHAR(255) NOT NULL,
    customer_phone VARCHAR(50) NOT NULL,
    customer_alt_phone VARCHAR(50),
    delivery_state VARCHAR(100),
    delivery_lga VARCHAR(100),
    customer_address TEXT,
    interested_product_id UUID,
    interested_package_name VARCHAR(255),
    lead_status VARCHAR(50) DEFAULT 'new_lead',
    call_attempts_count INT DEFAULT 0,
    last_call_at TIMESTAMPTZ,
    next_callback_at TIMESTAMPTZ,
    notes TEXT,
    converted_order_id UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.9 Master Products Catalog
CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES companies(id) ON DELETE SET NULL,
    client_id UUID REFERENCES clients(id) ON DELETE SET NULL,
    client_name VARCHAR(255),
    sku VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(100),
    description TEXT,
    base_price NUMERIC(14,2) NOT NULL DEFAULT 0.00,
    cost_price NUMERIC(14,2) DEFAULT 0.00,
    reorder_level INT DEFAULT 10,
    low_stock_threshold INT DEFAULT 5,
    stock_quantity INT DEFAULT 0,
    available_count INT DEFAULT 0,
    in_transit_count INT DEFAULT 0,
    delivered_count INT DEFAULT 0,
    damaged_count INT DEFAULT 0,
    dc_stocks JSONB DEFAULT '{}'::jsonb,
    covering_states TEXT[] DEFAULT '{}',
    image_url TEXT,
    barcode VARCHAR(100),
    weight_kg NUMERIC(8,2) DEFAULT 0.5,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.10 Product Batches
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

-- 2.11 Product Packages (Deal Offers)
CREATE TABLE IF NOT EXISTS product_packages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    product_name VARCHAR(255),
    product_sku VARCHAR(100),
    package_name VARCHAR(255) NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    paid_quantity INT NOT NULL DEFAULT 1,
    free_quantity INT DEFAULT 0,
    package_price NUMERIC(14,2) NOT NULL,
    client_id UUID REFERENCES clients(id) ON DELETE CASCADE,
    client_name VARCHAR(255),
    description TEXT,
    is_custom BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS client_packages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    package_name VARCHAR(255) NOT NULL,
    package_price NUMERIC(14,2) NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.12 Orders (Master Fulfillment Table)
CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES companies(id) ON DELETE SET NULL,
    order_number VARCHAR(100) UNIQUE NOT NULL,
    distribution_center_id UUID REFERENCES distribution_centers(id) ON DELETE SET NULL,
    distribution_center_name VARCHAR(255),
    delivery_agent_id UUID REFERENCES delivery_agents(id) ON DELETE SET NULL,
    assigned_agent_id UUID REFERENCES delivery_agents(id) ON DELETE SET NULL,
    client_id UUID REFERENCES clients(id) ON DELETE SET NULL,
    client_name VARCHAR(255),
    client_company VARCHAR(255),
    original_client_id UUID REFERENCES clients(id) ON DELETE SET NULL,
    original_client_name VARCHAR(255),
    closer_id UUID REFERENCES client_closers(id) ON DELETE SET NULL,
    closer_name VARCHAR(255),
    closer_code VARCHAR(50),
    lead_id UUID REFERENCES customer_leads(id) ON DELETE SET NULL,
    customer_name VARCHAR(255) NOT NULL,
    customer_phone VARCHAR(50) NOT NULL,
    customer_alt_phone VARCHAR(50),
    delivery_state VARCHAR(100) NOT NULL,
    delivery_city VARCHAR(100) NOT NULL,
    delivery_lga VARCHAR(100),
    lga VARCHAR(100),
    delivery_address TEXT NOT NULL,
    landmark TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    geocoding_status VARCHAR(50) DEFAULT 'unverified',
    geocoded_address TEXT,
    location_confidence VARCHAR(50),
    is_location_verified BOOLEAN DEFAULT false,
    fulfillment_type VARCHAR(50) DEFAULT 'distributed_inventory',
    product_id UUID REFERENCES products(id) ON DELETE SET NULL,
    product_name VARCHAR(255) NOT NULL,
    product_sku VARCHAR(100),
    package_deal_id UUID REFERENCES product_packages(id) ON DELETE SET NULL,
    package_deal_name VARCHAR(255),
    quantity INT NOT NULL DEFAULT 1,
    paid_quantity INT DEFAULT 1,
    free_quantity INT DEFAULT 0,
    base_price NUMERIC(14,2) DEFAULT 0.00,
    upsell_amount NUMERIC(14,2) DEFAULT 0.00,
    total_amount NUMERIC(14,2) NOT NULL,
    payment_type VARCHAR(50) DEFAULT 'pay_on_delivery',
    payment_method VARCHAR(50),
    payment_status VARCHAR(50) DEFAULT 'pending',
    status VARCHAR(50) DEFAULT 'pending_dispatch',
    delivery_method VARCHAR(50) DEFAULT 'standard',
    client_delivery_fee NUMERIC(14,2) DEFAULT 5000.00,
    agent_entitlement NUMERIC(14,2) DEFAULT 2500.00,
    assignment_status VARCHAR(50) DEFAULT 'unassigned',
    routing_notes TEXT,
    delivery_notes TEXT,
    reschedule_note TEXT,
    scheduled_callback_at TIMESTAMPTZ,
    proof_of_delivery_url TEXT,
    remittance_status VARCHAR(50) DEFAULT 'unremitted',
    financial_settlement_status VARCHAR(50) DEFAULT 'pending_remittance',
    remittance_reference VARCHAR(100),
    remitted_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    assigned_at TIMESTAMPTZ,
    ownership_transferred_at TIMESTAMPTZ,
    ownership_transfer_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.13 Order Activities & Audit Log
CREATE TABLE IF NOT EXISTS order_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    activity_type VARCHAR(100) NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.14 Order Conversations (Order Pipeline Chat)
CREATE TABLE IF NOT EXISTS order_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID UNIQUE NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    order_number VARCHAR(100) NOT NULL,
    customer_name VARCHAR(255),
    customer_phone VARCHAR(50),
    client_id UUID REFERENCES clients(id) ON DELETE SET NULL,
    client_name VARCHAR(255),
    distribution_center_id UUID REFERENCES distribution_centers(id) ON DELETE SET NULL,
    distribution_center_name VARCHAR(255),
    delivery_agent_id UUID REFERENCES delivery_agents(id) ON DELETE SET NULL,
    delivery_agent_name VARCHAR(255),
    closer_id UUID REFERENCES client_closers(id) ON DELETE SET NULL,
    closer_name VARCHAR(255),
    order_status VARCHAR(50),
    current_product_name VARCHAR(255),
    current_package_name VARCHAR(255),
    current_total_amount NUMERIC(14,2),
    last_message_text TEXT,
    last_message_sender_name VARCHAR(255),
    last_message_at TIMESTAMPTZ,
    unread_client_count INT DEFAULT 0,
    unread_dc_count INT DEFAULT 0,
    unread_rider_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS order_conversation_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES order_conversations(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL,
    sender_name VARCHAR(255) NOT NULL,
    sender_role VARCHAR(50) NOT NULL,
    sender_avatar_url TEXT,
    message_type VARCHAR(50) DEFAULT 'text',
    message_body TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    read_by_client BOOLEAN DEFAULT false,
    read_by_dc BOOLEAN DEFAULT false,
    read_by_rider BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.15 System Notifications
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    distribution_center_id UUID REFERENCES distribution_centers(id) ON DELETE SET NULL,
    client_id UUID REFERENCES clients(id) ON DELETE SET NULL,
    delivery_agent_id UUID REFERENCES delivery_agents(id) ON DELETE SET NULL,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    category VARCHAR(100) DEFAULT 'general',
    action_route VARCHAR(255),
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.16 Agent Inventory (Rider Custody)
CREATE TABLE IF NOT EXISTS agent_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    delivery_agent_id UUID NOT NULL REFERENCES delivery_agents(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    quantity INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(delivery_agent_id, product_id)
);

-- 2.17 Stock Handover Requests (2-Way Handshake)
CREATE TABLE IF NOT EXISTS stock_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_number VARCHAR(100) UNIQUE NOT NULL,
    delivery_agent_id UUID REFERENCES delivery_agents(id) ON DELETE SET NULL,
    distribution_center_id UUID REFERENCES distribution_centers(id) ON DELETE SET NULL,
    status VARCHAR(50) DEFAULT 'pending',
    request_type VARCHAR(50) DEFAULT 'rider_issue',
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS stock_request_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stock_request_id UUID NOT NULL REFERENCES stock_requests(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    batch_id UUID REFERENCES product_batches(id) ON DELETE SET NULL,
    requested_quantity INT NOT NULL,
    approved_quantity INT,
    handed_over_quantity INT
);

CREATE TABLE IF NOT EXISTS stock_handovers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stock_request_id UUID REFERENCES stock_requests(id) ON DELETE SET NULL,
    delivery_agent_id UUID NOT NULL REFERENCES delivery_agents(id) ON DELETE CASCADE,
    dc_supervisor_id UUID REFERENCES users(id) ON DELETE SET NULL,
    handover_code VARCHAR(50) NOT NULL,
    agent_confirmed BOOLEAN DEFAULT false,
    supervisor_confirmed BOOLEAN DEFAULT false,
    confirmed_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.18 Inter-DC & Client Supply Stock Transfers
CREATE TABLE IF NOT EXISTS stock_transfers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    transfer_number VARCHAR(100) UNIQUE NOT NULL,
    transfer_type VARCHAR(50) DEFAULT 'inter_dc',
    source_warehouse_id UUID,
    destination_warehouse_id UUID,
    source_dc_id UUID REFERENCES distribution_centers(id) ON DELETE SET NULL,
    destination_dc_id UUID REFERENCES distribution_centers(id) ON DELETE SET NULL,
    client_id UUID REFERENCES clients(id) ON DELETE SET NULL,
    waybill_number VARCHAR(100),
    status VARCHAR(50) DEFAULT 'pending',
    has_discrepancy BOOLEAN DEFAULT false,
    discrepancy_notes TEXT,
    sender_id UUID REFERENCES users(id) ON DELETE SET NULL,
    sender_name VARCHAR(255),
    sender_role VARCHAR(50),
    sender_signature_url TEXT,
    dispatched_at TIMESTAMPTZ,
    dispatched_by UUID REFERENCES users(id) ON DELETE SET NULL,
    receiver_id UUID REFERENCES users(id) ON DELETE SET NULL,
    receiver_name VARCHAR(255),
    receiver_role VARCHAR(50),
    receiver_signature_url TEXT,
    received_at TIMESTAMPTZ,
    received_by UUID REFERENCES users(id) ON DELETE SET NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS stock_transfer_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transfer_id UUID NOT NULL REFERENCES stock_transfers(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    quantity_shipped INT NOT NULL,
    quantity_received INT DEFAULT 0,
    quantity_damaged INT DEFAULT 0,
    quantity_missing INT DEFAULT 0,
    item_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.19 Stock Returns & QC Desk
CREATE TABLE IF NOT EXISTS stock_returns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    return_number VARCHAR(100) UNIQUE NOT NULL,
    delivery_agent_id UUID REFERENCES delivery_agents(id) ON DELETE SET NULL,
    distribution_center_id UUID REFERENCES distribution_centers(id) ON DELETE SET NULL,
    destination_dc_id UUID REFERENCES distribution_centers(id) ON DELETE SET NULL,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    quantity INT NOT NULL DEFAULT 1,
    reason TEXT NOT NULL,
    condition VARCHAR(50) DEFAULT 'good',
    status VARCHAR(50) DEFAULT 'pending',
    received_by UUID REFERENCES users(id) ON DELETE SET NULL,
    dc_received_by VARCHAR(255),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    received_at TIMESTAMPTZ
);

-- 2.20 Inventory Audits
CREATE TABLE IF NOT EXISTS inventory_audits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    audit_number VARCHAR(100) UNIQUE NOT NULL,
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    distribution_center_id UUID REFERENCES distribution_centers(id) ON DELETE SET NULL,
    delivery_agent_id UUID REFERENCES delivery_agents(id) ON DELETE SET NULL,
    audited_by UUID REFERENCES users(id) ON DELETE SET NULL,
    audit_type VARCHAR(50) DEFAULT 'dc_hub',
    status VARCHAR(50) DEFAULT 'in_progress',
    total_physical_counted INT DEFAULT 0,
    total_system_expected INT DEFAULT 0,
    discrepancy_count INT DEFAULT 0,
    discrepancy_notes TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS inventory_audit_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    audit_id UUID NOT NULL REFERENCES inventory_audits(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    expected_quantity INT NOT NULL,
    actual_quantity INT NOT NULL,
    variance INT NOT NULL,
    variance_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.21 Cash Remittances & Batch Matching
CREATE TABLE IF NOT EXISTS cash_remittances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    delivery_agent_id UUID NOT NULL REFERENCES delivery_agents(id) ON DELETE CASCADE,
    distribution_center_id UUID REFERENCES distribution_centers(id) ON DELETE SET NULL,
    reference_number VARCHAR(100) UNIQUE NOT NULL,
    amount NUMERIC(14,2) NOT NULL,
    payment_method VARCHAR(50) DEFAULT 'bank_transfer',
    status VARCHAR(50) DEFAULT 'pending',
    reconciliation_status VARCHAR(50) DEFAULT 'matched',
    is_verified BOOLEAN DEFAULT false,
    verified_at TIMESTAMPTZ,
    verified_by UUID REFERENCES users(id) ON DELETE SET NULL,
    commission_deducted NUMERIC(14,2) DEFAULT 0.00,
    net_amount NUMERIC(14,2) DEFAULT 0.00,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS remittance_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cash_remittance_id UUID NOT NULL REFERENCES cash_remittances(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    order_amount NUMERIC(14,2) NOT NULL,
    payment_type VARCHAR(50) DEFAULT 'pay_on_delivery'
);

CREATE TABLE IF NOT EXISTS rider_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    delivery_agent_id UUID NOT NULL REFERENCES delivery_agents(id) ON DELETE CASCADE,
    transaction_code VARCHAR(100) UNIQUE NOT NULL,
    title VARCHAR(255) NOT NULL,
    category VARCHAR(100) DEFAULT 'delivery_commission',
    amount NUMERIC(14,2) NOT NULL,
    is_credit BOOLEAN DEFAULT true,
    reference VARCHAR(100),
    status VARCHAR(50) DEFAULT 'completed',
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.22 Rider Payout Requests & Claims
CREATE TABLE IF NOT EXISTS payout_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    distribution_center_id UUID REFERENCES distribution_centers(id) ON DELETE SET NULL,
    delivery_agent_id UUID NOT NULL REFERENCES delivery_agents(id) ON DELETE CASCADE,
    payout_number VARCHAR(100) UNIQUE NOT NULL,
    amount NUMERIC(14,2) NOT NULL,
    bank_name VARCHAR(100) NOT NULL,
    account_number VARCHAR(50) NOT NULL,
    account_name VARCHAR(255) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    disbursement_ref VARCHAR(100),
    dc_notes TEXT,
    notes TEXT,
    rejection_reason TEXT,
    approved_by UUID REFERENCES users(id) ON DELETE SET NULL,
    approved_at TIMESTAMPTZ,
    reviewed_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS payout_claims (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    distribution_center_id UUID REFERENCES distribution_centers(id) ON DELETE SET NULL,
    delivery_agent_id UUID NOT NULL REFERENCES delivery_agents(id) ON DELETE CASCADE,
    payout_number VARCHAR(100) UNIQUE NOT NULL,
    amount NUMERIC(14,2) NOT NULL,
    bank_name VARCHAR(100) NOT NULL,
    account_number VARCHAR(50) NOT NULL,
    account_name VARCHAR(255) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    rejection_reason TEXT,
    notes TEXT,
    reviewed_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.23 Distribution Center Finance Settings (Config Table)
CREATE TABLE IF NOT EXISTS dc_finance_settings (
    id VARCHAR(100) PRIMARY KEY,
    distribution_center_id VARCHAR(100),
    pos_charge_mode VARCHAR(50) DEFAULT 'dynamic',
    pos_flat_rate NUMERIC(14,2) DEFAULT 350.00,
    pos_tier_amount NUMERIC(14,2) DEFAULT 5000.00,
    pos_tier_fee NUMERIC(14,2) DEFAULT 100.00,
    pos_max_cap_fee NUMERIC(14,2) DEFAULT 1500.00,
    is_pos_fee_reimbursable BOOLEAN DEFAULT true,
    paystack_direct_fee_percent NUMERIC(5,2) DEFAULT 1.5,
    paystack_fee_cap NUMERIC(14,2) DEFAULT 2000.00,
    default_commission_rate NUMERIC(14,2) DEFAULT 1000.00,
    default_transport_allowance NUMERIC(14,2) DEFAULT 1500.00,
    default_failed_stipend NUMERIC(14,2) DEFAULT 500.00,
    default_client_delivery_fee NUMERIC(14,2) DEFAULT 5000.00,
    failed_order_charge NUMERIC(14,2) DEFAULT 1000.00,
    platform_fee_type VARCHAR(20) DEFAULT 'flat',
    platform_fee_value NUMERIC(14,2) DEFAULT 500.00,
    remittance_switch_fee NUMERIC(14,2) DEFAULT 100.00,
    paystack_fee_absorbed_by VARCHAR(50) DEFAULT 'merchant',
    daily_settlement_cutoff_time VARCHAR(20) DEFAULT '22:00',
    settlement_bank_name VARCHAR(100) DEFAULT 'Titan Trust Bank',
    settlement_account_number VARCHAR(50) DEFAULT '0098234123',
    settlement_account_name VARCHAR(255) DEFAULT 'NovaXpress Logistics Limited',
    auto_reconcile_webhooks BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.24 Client Settlements (Daily 10:00 PM Workday Closeout Batches)
CREATE TABLE IF NOT EXISTS client_settlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    settlement_number VARCHAR(100) UNIQUE NOT NULL,
    client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    company_id UUID REFERENCES companies(id) ON DELETE SET NULL,
    distribution_center_id UUID REFERENCES distribution_centers(id) ON DELETE SET NULL,
    period_start TIMESTAMPTZ NOT NULL,
    period_end TIMESTAMPTZ NOT NULL,
    total_orders_count INT NOT NULL DEFAULT 0,
    gross_collections NUMERIC(14,2) NOT NULL DEFAULT 0.00,
    logistics_fees_deducted NUMERIC(14,2) NOT NULL DEFAULT 0.00,
    platform_fees_deducted NUMERIC(14,2) NOT NULL DEFAULT 0.00,
    gateway_fees_deducted NUMERIC(14,2) NOT NULL DEFAULT 0.00,
    failed_attempt_fees_deducted NUMERIC(14,2) NOT NULL DEFAULT 0.00,
    other_charges_deducted NUMERIC(14,2) NOT NULL DEFAULT 0.00,
    net_payout_amount NUMERIC(14,2) NOT NULL DEFAULT 0.00,
    charges_breakdown JSONB DEFAULT '{}'::jsonb,
    destination_bank_name VARCHAR(100),
    destination_account_number VARCHAR(50),
    destination_account_name VARCHAR(255),
    payout_reference VARCHAR(100),
    status VARCHAR(50) DEFAULT 'pending',
    settled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.25 Payment Gateway Tables (Paystack & Monnify)
CREATE TABLE IF NOT EXISTS paystack_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference VARCHAR(100) UNIQUE NOT NULL,
    virtual_account_id UUID,
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    remittance_id UUID REFERENCES cash_remittances(id) ON DELETE SET NULL,
    delivery_agent_id UUID REFERENCES delivery_agents(id) ON DELETE SET NULL,
    distribution_center_id UUID REFERENCES distribution_centers(id) ON DELETE SET NULL,
    amount NUMERIC(14,2) NOT NULL,
    currency VARCHAR(10) DEFAULT 'NGN',
    transaction_type VARCHAR(50) DEFAULT 'charge',
    channel VARCHAR(50) DEFAULT 'card',
    payer_email VARCHAR(255),
    payer_name VARCHAR(255),
    verification_status VARCHAR(50) DEFAULT 'success',
    paystack_response JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS paystack_virtual_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
    account_reference VARCHAR(100) UNIQUE NOT NULL,
    account_number VARCHAR(50) NOT NULL,
    bank_name VARCHAR(100) NOT NULL,
    account_name VARCHAR(255) NOT NULL,
    expected_amount NUMERIC(14,2) NOT NULL,
    amount_paid NUMERIC(14,2) DEFAULT 0.00,
    status VARCHAR(50) DEFAULT 'active',
    payment_received_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS monnify_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    virtual_account_id UUID,
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    transaction_reference VARCHAR(100) UNIQUE NOT NULL,
    amount_paid NUMERIC(14,2) NOT NULL,
    payer_name VARCHAR(255),
    payer_account_number VARCHAR(50),
    payer_bank VARCHAR(100),
    webhook_payload JSONB DEFAULT '{}'::jsonb,
    verification_status VARCHAR(50) DEFAULT 'success',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS monnify_virtual_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
    account_reference VARCHAR(100) UNIQUE NOT NULL,
    account_number VARCHAR(50) NOT NULL,
    account_name VARCHAR(255) NOT NULL,
    bank_name VARCHAR(100) NOT NULL,
    expected_amount NUMERIC(14,2) NOT NULL,
    amount_paid NUMERIC(14,2) DEFAULT 0.00,
    status VARCHAR(50) DEFAULT 'active',
    session_id VARCHAR(100),
    payment_received_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 3. INDEXES FOR HIGH-THROUGHPUT SEARCH & REALTIME
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_orders_client_id ON orders(client_id);
CREATE INDEX IF NOT EXISTS idx_orders_dc_id ON orders(distribution_center_id);
CREATE INDEX IF NOT EXISTS idx_orders_delivery_agent_id ON orders(delivery_agent_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at);
CREATE INDEX IF NOT EXISTS idx_orders_financial_status ON orders(financial_settlement_status);
CREATE INDEX IF NOT EXISTS idx_orders_lga ON orders(delivery_state, delivery_lga);
CREATE INDEX IF NOT EXISTS idx_products_client_id ON products(client_id);
CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku);
CREATE INDEX IF NOT EXISTS idx_agent_inventory_agent_prod ON agent_inventory(delivery_agent_id, product_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_conv ON order_conversation_messages(conversation_id, created_at);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_dc ON notifications(distribution_center_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_client ON notifications(client_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_rider ON notifications(delivery_agent_id, is_read);

-- ============================================================================
-- 4. STORED PROCEDURES & RPC BUSINESS LOGIC
-- ============================================================================

-- 4.1 Safe JSONB DC Stock Adjustment
CREATE OR REPLACE FUNCTION public.fn_adjust_dc_stock(
    p_product_id UUID,
    p_dc_id UUID,
    p_delta INT
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_dc_key TEXT := p_dc_id::TEXT;
    v_curr_val INT := 0;
    v_new_val INT := 0;
    v_curr_stocks JSONB;
BEGIN
    IF p_product_id IS NULL OR p_dc_id IS NULL OR p_delta = 0 THEN
        RETURN;
    END IF;

    SELECT COALESCE(dc_stocks, '{}'::JSONB) INTO v_curr_stocks
    FROM public.products
    WHERE id = p_product_id;

    IF v_curr_stocks ? v_dc_key THEN
        v_curr_val := COALESCE((v_curr_stocks->>v_dc_key)::INT, 0);
    END IF;

    v_new_val := GREATEST(0, v_curr_val + p_delta);
    v_curr_stocks := jsonb_set(v_curr_stocks, ARRAY[v_dc_key], to_jsonb(v_new_val), true);

    UPDATE public.products
    SET dc_stocks = v_curr_stocks,
        updated_at = NOW()
    WHERE id = p_product_id;
END;
$$;

-- 4.2 Client Supply Dispatch (Party A Logs Inbound Supply)
CREATE OR REPLACE FUNCTION public.fn_dispatch_client_supply(
    p_client_id UUID,
    p_dc_id UUID,
    p_items JSONB,
    p_sender_id UUID DEFAULT NULL,
    p_sender_name TEXT DEFAULT '',
    p_sender_signature_url TEXT DEFAULT '',
    p_notes TEXT DEFAULT ''
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_company_id UUID;
    v_transfer_id UUID;
    v_waybill TEXT;
    v_item JSONB;
    v_prod_id UUID;
    v_qty INT;
    v_item_notes TEXT;
    v_total_items INT := 0;
    v_total_qty INT := 0;
BEGIN
    SELECT company_id INTO v_company_id FROM public.clients WHERE id = p_client_id;
    IF v_company_id IS NULL THEN
        SELECT id INTO v_company_id FROM public.companies LIMIT 1;
    END IF;

    v_waybill := 'WB-SUPPLY-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');

    INSERT INTO public.stock_transfers (
        company_id,
        client_id,
        transfer_type,
        transfer_number,
        waybill_number,
        destination_dc_id,
        status,
        sender_id,
        sender_name,
        sender_role,
        sender_signature_url,
        dispatched_at,
        notes
    ) VALUES (
        v_company_id,
        p_client_id,
        'client_supply',
        v_waybill,
        v_waybill,
        p_dc_id,
        'in_transit',
        p_sender_id,
        p_sender_name,
        'client',
        p_sender_signature_url,
        NOW(),
        p_notes
    ) RETURNING id INTO v_transfer_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_prod_id := (v_item->>'product_id')::UUID;
        v_qty := COALESCE((v_item->>'quantity')::INT, 0);
        v_item_notes := COALESCE(v_item->>'notes', '');

        IF v_qty > 0 THEN
            INSERT INTO public.stock_transfer_items (
                transfer_id,
                product_id,
                quantity_shipped,
                quantity_received,
                notes
            ) VALUES (
                v_transfer_id,
                v_prod_id,
                v_qty,
                0,
                v_item_notes
            );
            v_total_items := v_total_items + 1;
            v_total_qty := v_total_qty + v_qty;
        END IF;
    END LOOP;

    INSERT INTO public.notifications (
        company_id,
        distribution_center_id,
        title,
        message,
        category,
        action_route,
        is_read
    ) VALUES (
        v_company_id,
        p_dc_id,
        'New Inbound Client Supply Dispatched 📦',
        COALESCE(p_sender_name, 'Client') || ' dispatched ' || v_total_qty || ' units across ' || v_total_items || ' product(s) (Waybill: ' || v_waybill || '). Awaiting physical receiving & verification at your station.',
        'inventory',
        '/products',
        false
    );

    RETURN jsonb_build_object(
        'success', true,
        'transfer_id', v_transfer_id,
        'waybill_number', v_waybill,
        'status', 'in_transit',
        'total_items', v_total_items,
        'total_quantity', v_total_qty,
        'message', 'Supply dispatched successfully. Awaiting receiving station verification.'
    );
END;
$$;

-- 4.3 Client Supply Receive (Party B Verifies & Updates DC Physical Inventory)
CREATE OR REPLACE FUNCTION public.fn_receive_client_supply(
    p_transfer_id UUID,
    p_receiver_id UUID DEFAULT NULL,
    p_receiver_name TEXT DEFAULT '',
    p_receiver_signature_url TEXT DEFAULT '',
    p_verified_items JSONB DEFAULT NULL,
    p_notes TEXT DEFAULT ''
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_trf RECORD;
    v_item RECORD;
    v_qty_rec INT;
    v_item_notes TEXT;
    v_has_disc BOOLEAN := FALSE;
    v_status TEXT := 'completed';
    v_dc_key TEXT;
    v_total_units_received INT := 0;
BEGIN
    SELECT * INTO v_trf FROM public.stock_transfers WHERE id = p_transfer_id;
    IF v_trf IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Stock transfer not found');
    END IF;

    IF v_trf.destination_dc_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Transfer destination DC is not specified');
    END IF;

    v_dc_key := v_trf.destination_dc_id::TEXT;

    FOR v_item IN SELECT * FROM public.stock_transfer_items WHERE transfer_id = p_transfer_id
    LOOP
        v_qty_rec := v_item.quantity_shipped;
        v_item_notes := COALESCE(v_item.notes, '');

        IF p_verified_items IS NOT NULL THEN
            SELECT 
                COALESCE((elem->>'quantity_received')::INT, v_item.quantity_shipped),
                COALESCE(elem->>'notes', v_item_notes)
            INTO v_qty_rec, v_item_notes
            FROM jsonb_array_elements(p_verified_items) elem
            WHERE (elem->>'item_id')::UUID = v_item.id;
        END IF;

        IF v_qty_rec != v_item.quantity_shipped THEN
            v_has_disc := TRUE;
            v_status := 'discrepancy_reported';
        END IF;

        UPDATE public.stock_transfer_items
        SET quantity_received = v_qty_rec,
            notes = v_item_notes
        WHERE id = v_item.id;

        IF v_qty_rec > 0 THEN
            PERFORM public.fn_adjust_dc_stock(v_item.product_id, v_trf.destination_dc_id, v_qty_rec);

            UPDATE public.products
            SET stock_quantity = COALESCE(stock_quantity, 0) + v_qty_rec,
                updated_at = NOW()
            WHERE id = v_item.product_id;

            v_total_units_received := v_total_units_received + v_qty_rec;
        END IF;
    END LOOP;

    UPDATE public.stock_transfers
    SET status = v_status,
        receiver_id = p_receiver_id,
        receiver_name = p_receiver_name,
        receiver_role = 'dc_supervisor',
        receiver_signature_url = p_receiver_signature_url,
        received_at = NOW(),
        has_discrepancy = v_has_disc,
        discrepancy_notes = p_notes,
        notes = CASE 
            WHEN p_notes <> '' THEN COALESCE(notes, '') || ' | Supervisor Notes: ' || p_notes 
            ELSE notes 
        END,
        updated_at = NOW()
    WHERE id = p_transfer_id;

    IF v_trf.client_id IS NOT NULL THEN
        INSERT INTO public.notifications (
            company_id,
            client_id,
            title,
            message,
            category,
            action_route,
            is_read
        ) VALUES (
            v_trf.company_id,
            v_trf.client_id,
            CASE WHEN v_has_disc THEN 'Supply Verified with Discrepancy ⚠️' ELSE 'Supply Received & Verified ✅' END,
            'Waybill ' || COALESCE(v_trf.waybill_number, '') || ' received and verified by DC supervisor ' || p_receiver_name || '. ' || v_total_units_received || ' units stocked.',
            'inventory',
            '/products',
            false
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'status', v_status,
        'has_discrepancy', v_has_disc,
        'total_units_received', v_total_units_received,
        'message', 'Supply verified and inventory updated successfully.'
    );
END;
$$;

-- 4.4 Inter-DC Transfer: Dispatch (Party A Debits Source DC Stock)
CREATE OR REPLACE FUNCTION public.fn_dispatch_inter_dc_transfer(
    p_source_dc_id UUID,
    p_destination_dc_id UUID,
    p_product_id UUID,
    p_quantity INT,
    p_sender_id UUID DEFAULT NULL,
    p_sender_name TEXT DEFAULT '',
    p_notes TEXT DEFAULT ''
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_company_id UUID;
    v_transfer_id UUID;
    v_waybill TEXT;
    v_src_name TEXT := 'Source DC';
    v_prod_name TEXT := 'Product';
BEGIN
    IF p_quantity <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Transfer quantity must be greater than 0');
    END IF;

    SELECT company_id, name INTO v_company_id, v_src_name
    FROM public.distribution_centers
    WHERE id = p_source_dc_id;

    IF v_company_id IS NULL THEN
        SELECT id INTO v_company_id FROM public.companies LIMIT 1;
    END IF;

    SELECT name INTO v_prod_name FROM public.products WHERE id = p_product_id;

    v_waybill := 'WB-INTERDC-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');

    INSERT INTO public.stock_transfers (
        company_id,
        transfer_type,
        transfer_number,
        waybill_number,
        source_dc_id,
        destination_dc_id,
        status,
        sender_id,
        sender_name,
        sender_role,
        dispatched_at,
        notes
    ) VALUES (
        v_company_id,
        'inter_dc',
        v_waybill,
        v_waybill,
        p_source_dc_id,
        p_destination_dc_id,
        'pending_destination_acceptance',
        p_sender_id,
        p_sender_name,
        'dc_supervisor',
        NOW(),
        p_notes
    ) RETURNING id INTO v_transfer_id;

    INSERT INTO public.stock_transfer_items (
        transfer_id,
        product_id,
        quantity_shipped,
        quantity_received
    ) VALUES (
        v_transfer_id,
        p_product_id,
        p_quantity,
        0
    );

    PERFORM public.fn_adjust_dc_stock(p_product_id, p_source_dc_id, -p_quantity);

    INSERT INTO public.notifications (
        company_id,
        distribution_center_id,
        title,
        message,
        category,
        action_route,
        is_read
    ) VALUES (
        v_company_id,
        p_destination_dc_id,
        'Incoming Inter-DC Stock Transfer! 🚚',
        v_src_name || ' dispatched ' || p_quantity || ' units of ' || COALESCE(v_prod_name, 'product') || ' (Waybill: ' || v_waybill || '). Awaiting receipt acceptance.',
        'inventory',
        '/stock',
        false
    );

    RETURN jsonb_build_object(
        'success', true,
        'transfer_id', v_transfer_id,
        'waybill_number', v_waybill,
        'status', 'pending_destination_acceptance',
        'quantity', p_quantity,
        'message', 'Inter-DC transfer dispatched successfully. Awaiting destination DC acceptance.'
    );
END;
$$;

-- 4.5 Inter-DC Transfer: Receive & Accept (Party B Credits Destination DC Stock)
CREATE OR REPLACE FUNCTION public.fn_receive_inter_dc_transfer(
    p_transfer_id UUID,
    p_receiver_id UUID DEFAULT NULL,
    p_receiver_name TEXT DEFAULT '',
    p_quantity_received INT DEFAULT NULL,
    p_notes TEXT DEFAULT ''
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_trf RECORD;
    v_item RECORD;
    v_qty_rec INT;
    v_has_disc BOOLEAN := FALSE;
    v_status TEXT := 'completed';
BEGIN
    SELECT * INTO v_trf FROM public.stock_transfers WHERE id = p_transfer_id;
    IF v_trf IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Stock transfer not found');
    END IF;

    SELECT * INTO v_item FROM public.stock_transfer_items WHERE transfer_id = p_transfer_id LIMIT 1;
    IF v_item IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Transfer has no items');
    END IF;

    v_qty_rec := COALESCE(p_quantity_received, v_item.quantity_shipped);

    IF v_qty_rec != v_item.quantity_shipped THEN
        v_has_disc := TRUE;
        v_status := 'discrepancy_reported';

        IF v_qty_rec < v_item.quantity_shipped AND v_trf.source_dc_id IS NOT NULL THEN
            PERFORM public.fn_adjust_dc_stock(v_item.product_id, v_trf.source_dc_id, (v_item.quantity_shipped - v_qty_rec));
        END IF;
    END IF;

    UPDATE public.stock_transfer_items
    SET quantity_received = v_qty_rec
    WHERE id = v_item.id;

    IF v_qty_rec > 0 AND v_trf.destination_dc_id IS NOT NULL THEN
        PERFORM public.fn_adjust_dc_stock(v_item.product_id, v_trf.destination_dc_id, v_qty_rec);
    END IF;

    UPDATE public.stock_transfers
    SET status = v_status,
        receiver_id = p_receiver_id,
        receiver_name = p_receiver_name,
        receiver_role = 'dc_supervisor',
        received_at = NOW(),
        has_discrepancy = v_has_disc,
        discrepancy_notes = p_notes,
        updated_at = NOW()
    WHERE id = p_transfer_id;

    RETURN jsonb_build_object(
        'success', true,
        'status', v_status,
        'quantity_received', v_qty_rec,
        'message', 'Inter-DC stock receipt completed.'
    );
END;
$$;

-- 4.6 Issue DC Stock to Rider (Handshake Stage 1)
CREATE OR REPLACE FUNCTION public.fn_issue_dc_stock_to_rider(
    p_dc_id UUID,
    p_rider_id UUID,
    p_items JSONB,
    p_sender_id UUID,
    p_sender_name TEXT,
    p_sender_signature_url TEXT DEFAULT '',
    p_notes TEXT DEFAULT ''
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_company_id UUID;
    v_transfer_id UUID;
    v_waybill TEXT;
    v_item JSONB;
    v_prod_id UUID;
    v_qty INT;
    v_avail INT;
    v_wh_id UUID;
    v_rider RECORD;
BEGIN
    SELECT * INTO v_rider FROM public.delivery_agents WHERE id = p_rider_id OR user_id = p_rider_id LIMIT 1;
    IF v_rider IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Delivery agent not found');
    END IF;

    SELECT company_id INTO v_company_id FROM public.distribution_centers WHERE id = p_dc_id;
    IF v_company_id IS NULL THEN
        v_company_id := '11111111-1111-4111-8111-111111111111'::UUID;
    END IF;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_prod_id := (v_item->>'product_id')::UUID;
        v_qty := COALESCE((v_item->>'quantity')::INT, 0);

        IF v_qty > 0 THEN
            SELECT COALESCE((dc_stocks->>p_dc_id::TEXT)::INT, 0) INTO v_avail
            FROM public.products WHERE id = v_prod_id;

            IF v_avail < v_qty THEN
                RETURN jsonb_build_object(
                    'success', false,
                    'message', 'Insufficient stock in DC possession (' || v_avail || ' units available, cannot issue ' || v_qty || ' units)'
                );
            END IF;
        END IF;
    END LOOP;

    SELECT id INTO v_wh_id FROM public.warehouses WHERE rider_id = v_rider.id LIMIT 1;
    IF v_wh_id IS NULL THEN
        INSERT INTO public.warehouses (
            company_id,
            rider_id,
            name,
            type,
            location_state,
            address,
            is_active
        ) VALUES (
            v_company_id,
            v_rider.id,
            COALESCE(v_rider.full_name, 'Rider') || ' (' || COALESCE(v_rider.agent_code, 'PDA') || ') Vehicle Stock',
            'rider_mini_hub',
            COALESCE(v_rider.operating_state, 'Federal Capital Territory'),
            'Rider Mobile Warehouse',
            true
        ) RETURNING id INTO v_wh_id;
    END IF;

    v_waybill := 'WB-RIDER-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');

    INSERT INTO public.stock_transfers (
        company_id,
        transfer_type,
        transfer_number,
        waybill_number,
        source_dc_id,
        source_warehouse_id,
        destination_warehouse_id,
        receiver_id,
        status,
        sender_id,
        sender_name,
        sender_role,
        sender_signature_url,
        dispatched_at,
        notes
    ) VALUES (
        v_company_id,
        'dc_to_rider',
        v_waybill,
        v_waybill,
        p_dc_id,
        NULL,
        v_wh_id,
        v_rider.id,
        'pending_rider_acceptance',
        p_sender_id,
        p_sender_name,
        'dc_supervisor',
        p_sender_signature_url,
        NOW(),
        p_notes
    ) RETURNING id INTO v_transfer_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_prod_id := (v_item->>'product_id')::UUID;
        v_qty := COALESCE((v_item->>'quantity')::INT, 0);

        IF v_qty > 0 THEN
            UPDATE public.products
            SET stock_quantity = GREATEST(0, COALESCE(stock_quantity, 0) - v_qty),
                updated_at = NOW()
            WHERE id = v_prod_id;

            PERFORM public.fn_adjust_dc_stock(v_prod_id, p_dc_id, -v_qty);

            INSERT INTO public.stock_transfer_items (
                transfer_id,
                product_id,
                quantity_shipped,
                quantity_received
            ) VALUES (
                v_transfer_id,
                v_prod_id,
                v_qty,
                0
            );
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'transfer_id', v_transfer_id,
        'waybill_number', v_waybill,
        'status', 'pending_rider_acceptance'
    );
END;
$$;

-- 4.7 Rider Accept Stock Handover (Handshake Stage 2)
CREATE OR REPLACE FUNCTION public.fn_rider_accept_stock_handover(
    p_transfer_id UUID,
    p_rider_id UUID,
    p_rider_name TEXT,
    p_rider_signature_url TEXT,
    p_verified_items JSONB DEFAULT NULL,
    p_notes TEXT DEFAULT ''
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_trf RECORD;
    v_item RECORD;
    v_rider RECORD;
    v_qty_rec INT;
    v_has_disc BOOLEAN := FALSE;
    v_dc_str TEXT;
BEGIN
    SELECT * INTO v_trf FROM public.stock_transfers WHERE id = p_transfer_id;
    IF v_trf IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Stock transfer not found');
    END IF;

    v_dc_str := COALESCE(v_trf.source_dc_id::TEXT, '');
    SELECT * INTO v_rider FROM public.delivery_agents WHERE id = p_rider_id OR user_id = p_rider_id LIMIT 1;

    FOR v_item IN SELECT * FROM public.stock_transfer_items WHERE transfer_id = p_transfer_id
    LOOP
        v_qty_rec := v_item.quantity_shipped;

        IF p_verified_items IS NOT NULL THEN
            SELECT COALESCE((elem->>'quantity_received')::INT, v_item.quantity_shipped)
            INTO v_qty_rec
            FROM jsonb_array_elements(p_verified_items) elem
            WHERE (elem->>'item_id')::UUID = v_item.id;
        END IF;

        IF v_qty_rec != v_item.quantity_shipped THEN
            v_has_disc := TRUE;
            IF v_qty_rec < v_item.quantity_shipped THEN
                UPDATE public.products
                SET stock_quantity = COALESCE(stock_quantity, 0) + (v_item.quantity_shipped - v_qty_rec),
                    updated_at = NOW()
                WHERE id = v_item.product_id;

                IF v_trf.source_dc_id IS NOT NULL THEN
                    PERFORM public.fn_adjust_dc_stock(v_item.product_id, v_trf.source_dc_id, (v_item.quantity_shipped - v_qty_rec));
                END IF;
            END IF;
        END IF;

        UPDATE public.stock_transfer_items
        SET quantity_received = v_qty_rec
        WHERE id = v_item.id;

        IF v_rider IS NOT NULL AND v_item.product_id IS NOT NULL THEN
            INSERT INTO public.agent_inventory (
                delivery_agent_id,
                product_id,
                total_in_custody,
                available_count
            ) VALUES (
                v_rider.id,
                v_item.product_id,
                v_qty_rec,
                v_qty_rec
            )
            ON CONFLICT (delivery_agent_id, product_id)
            DO UPDATE SET
                total_in_custody = public.agent_inventory.total_in_custody + v_qty_rec,
                available_count = public.agent_inventory.available_count + v_qty_rec,
                updated_at = NOW();
        END IF;
    END LOOP;

    UPDATE public.stock_transfers
    SET status = CASE WHEN v_has_disc THEN 'discrepancy_reported' ELSE 'completed' END,
        receiver_id = p_rider_id,
        receiver_name = p_rider_name,
        receiver_role = 'delivery_agent',
        receiver_signature_url = p_rider_signature_url,
        received_at = NOW(),
        has_discrepancy = v_has_disc,
        discrepancy_notes = p_notes,
        updated_at = NOW()
    WHERE id = p_transfer_id;

    RETURN jsonb_build_object(
        'success', true,
        'status', CASE WHEN v_has_disc THEN 'discrepancy_reported' ELSE 'completed' END,
        'transfer_id', p_transfer_id
    );
END;
$$;

-- 4.8 Rider Reject Stock Handover (Restores DC Stock)
CREATE OR REPLACE FUNCTION public.fn_rider_reject_stock_handover(
    p_transfer_id UUID,
    p_rider_id UUID,
    p_reason TEXT DEFAULT ''
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_trf RECORD;
    v_item RECORD;
BEGIN
    SELECT * INTO v_trf FROM public.stock_transfers WHERE id = p_transfer_id;
    IF v_trf IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Stock transfer not found');
    END IF;

    FOR v_item IN SELECT * FROM public.stock_transfer_items WHERE transfer_id = p_transfer_id
    LOOP
        UPDATE public.products
        SET stock_quantity = COALESCE(stock_quantity, 0) + v_item.quantity_shipped,
            updated_at = NOW()
        WHERE id = v_item.product_id;

        IF v_trf.source_dc_id IS NOT NULL THEN
            PERFORM public.fn_adjust_dc_stock(v_item.product_id, v_trf.source_dc_id, v_item.quantity_shipped);
        END IF;
    END LOOP;

    UPDATE public.stock_transfers
    SET status = 'rejected',
        discrepancy_notes = 'Rejected by rider: ' || p_reason,
        updated_at = NOW()
    WHERE id = p_transfer_id;

    RETURN jsonb_build_object(
        'success', true,
        'status', 'rejected',
        'message', 'Stock handover rejected. Units returned to DC shelf.'
    );
END;
$$;

-- 4.9 DC Supervisor Cancel Pending Handover (Restores DC Stock)
CREATE OR REPLACE FUNCTION public.fn_cancel_dc_stock_handover(
    p_transfer_id UUID,
    p_cancelled_by UUID,
    p_reason TEXT DEFAULT ''
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_trf RECORD;
    v_item RECORD;
BEGIN
    SELECT * INTO v_trf FROM public.stock_transfers WHERE id = p_transfer_id;
    IF v_trf IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Stock transfer not found');
    END IF;
    IF v_trf.status != 'pending_rider_acceptance' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Only pending handovers can be cancelled');
    END IF;

    FOR v_item IN SELECT * FROM public.stock_transfer_items WHERE transfer_id = p_transfer_id
    LOOP
        UPDATE public.products
        SET stock_quantity = COALESCE(stock_quantity, 0) + v_item.quantity_shipped,
            updated_at = NOW()
        WHERE id = v_item.product_id;

        IF v_trf.source_dc_id IS NOT NULL THEN
            PERFORM public.fn_adjust_dc_stock(v_item.product_id, v_trf.source_dc_id, v_item.quantity_shipped);
        END IF;
    END LOOP;

    UPDATE public.stock_transfers
    SET status = 'cancelled',
        discrepancy_notes = 'Cancelled by supervisor: ' || p_reason,
        updated_at = NOW()
    WHERE id = p_transfer_id;

    RETURN jsonb_build_object(
        'success', true,
        'status', 'cancelled',
        'message', 'Stock handover cancelled. Units returned to DC shelf.'
    );
END;
$$;

-- 4.10 Confirm Order Delivery Stock (Prevents double deduction on POD)
CREATE OR REPLACE FUNCTION public.fn_confirm_order_delivery_stock(
    p_order_id UUID,
    p_agent_id UUID,
    p_product_id UUID,
    p_physical_quantity INT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_qty INT := GREATEST(1, COALESCE(p_physical_quantity, 1));
    v_agent RECORD;
BEGIN
    SELECT * INTO v_agent FROM public.delivery_agents WHERE id = p_agent_id OR user_id = p_agent_id;

    IF v_agent IS NOT NULL AND p_product_id IS NOT NULL THEN
        UPDATE public.agent_inventory
        SET available_count = GREATEST(0, COALESCE(available_count, 0) - v_qty),
            total_in_custody = GREATEST(0, COALESCE(total_in_custody, 0) - v_qty),
            delivered_count_today = COALESCE(delivered_count_today, 0) + v_qty,
            updated_at = NOW()
        WHERE delivery_agent_id = v_agent.id AND product_id = p_product_id;
    END IF;

    IF p_product_id IS NOT NULL THEN
        UPDATE public.products
        SET delivered_count = COALESCE(delivered_count, 0) + v_qty,
            updated_at = NOW()
        WHERE id = p_product_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'deducted_quantity', v_qty
    );
END;
$$;

-- 4.11 Receive Rider Stock Return (Restores inventory upon return)
CREATE OR REPLACE FUNCTION public.fn_receive_rider_stock_return(
    p_return_id UUID,
    p_dc_id UUID,
    p_receiver_id UUID,
    p_verified_quantity INT,
    p_condition TEXT DEFAULT 'good',
    p_notes TEXT DEFAULT ''
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_ret RECORD;
    v_qty INT;
BEGIN
    SELECT * INTO v_ret FROM public.stock_returns WHERE id = p_return_id;
    IF v_ret IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Stock return not found');
    END IF;

    IF v_ret.status = 'approved' OR v_ret.status = 'completed' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Stock return already received');
    END IF;

    v_qty := GREATEST(0, COALESCE(p_verified_quantity, v_ret.quantity));

    IF v_ret.delivery_agent_id IS NOT NULL AND v_ret.product_id IS NOT NULL THEN
        UPDATE public.agent_inventory
        SET total_in_custody = GREATEST(0, COALESCE(total_in_custody, 0) - v_qty),
            available_count = GREATEST(0, COALESCE(available_count, 0) - v_qty),
            returned_count = COALESCE(returned_count, 0) + v_qty,
            updated_at = NOW()
        WHERE delivery_agent_id = v_ret.delivery_agent_id AND product_id = v_ret.product_id;
    END IF;

    IF p_condition = 'good' AND v_ret.product_id IS NOT NULL THEN
        UPDATE public.products
        SET stock_quantity = COALESCE(stock_quantity, 0) + v_qty,
            updated_at = NOW()
        WHERE id = v_ret.product_id;

        IF p_dc_id IS NOT NULL THEN
            PERFORM public.fn_adjust_dc_stock(v_ret.product_id, p_dc_id, v_qty);
        END IF;
    ELSE
        IF v_ret.product_id IS NOT NULL THEN
            UPDATE public.products
            SET damaged_count = COALESCE(damaged_count, 0) + v_qty,
                updated_at = NOW()
            WHERE id = v_ret.product_id;
        END IF;
    END IF;

    UPDATE public.stock_returns
    SET status = 'approved',
        destination_dc_id = p_dc_id,
        condition = p_condition,
        received_by = p_receiver_id,
        received_at = NOW(),
        quantity = v_qty,
        admin_notes = p_notes,
        updated_at = NOW()
    WHERE id = p_return_id;

    RETURN jsonb_build_object(
        'success', true,
        'return_id', p_return_id,
        'quantity_received', v_qty,
        'message', 'Stock return received and processed.'
    );
END;
$$;

-- 4.12 Pure SQL Scalar: calculate_haversine_distance_km
CREATE OR REPLACE FUNCTION public.calculate_haversine_distance_km(
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

-- 4.13 Proximity Query: find_closest_available_rider
CREATE OR REPLACE FUNCTION public.find_closest_available_rider(
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
      FROM public.orders o 
      WHERE o.delivery_agent_id = da.id 
        AND o.status IN ('accepted', 'in_transit', 'pending', 'assigned')
    ) AS active_orders_count
  FROM public.delivery_agents da
  JOIN public.users u ON da.user_id = u.id
  WHERE (p_distribution_center_id IS NULL OR da.distribution_center_id = p_distribution_center_id)
    AND COALESCE(da.is_on_duty, u.is_on_duty, true) = TRUE
    AND COALESCE(da.current_latitude, u.current_latitude) IS NOT NULL
    AND COALESCE(da.current_longitude, u.current_longitude) IS NOT NULL
    AND (
      SELECT COUNT(*) 
      FROM public.orders o 
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

-- 4.14 GPS Telemetry Update: update_rider_gps_telemetry
CREATE OR REPLACE FUNCTION public.update_rider_gps_telemetry(
  p_agent_id UUID,
  p_latitude DOUBLE PRECISION,
  p_longitude DOUBLE PRECISION
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.delivery_agents
  SET 
    current_latitude = p_latitude,
    current_longitude = p_longitude,
    last_location_update = NOW(),
    updated_at = NOW()
  WHERE id = p_agent_id;

  UPDATE public.users
  SET 
    current_latitude = p_latitude,
    current_longitude = p_longitude,
    last_location_update = NOW(),
    updated_at = NOW()
  WHERE id = p_agent_id OR id = (SELECT user_id FROM public.delivery_agents WHERE id = p_agent_id);
END;
$$;

-- 4.15 Gate Pin & Exact Address Verification: record_verified_gate_pin
CREATE OR REPLACE FUNCTION public.record_verified_gate_pin(
  p_order_id UUID,
  p_latitude DOUBLE PRECISION,
  p_longitude DOUBLE PRECISION,
  p_geocoded_address TEXT DEFAULT NULL,
  p_pin_label TEXT DEFAULT 'Customer Delivery Gate'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.orders
  SET 
    latitude = p_latitude,
    longitude = p_longitude,
    is_location_verified = TRUE,
    location_confidence = 1.0,
    geocoding_status = 'exact_verified',
    geocoded_address = COALESCE(p_geocoded_address, geocoded_address),
    updated_at = NOW()
  WHERE id = p_order_id;

  RETURN jsonb_build_object('success', true, 'verified', true, 'order_id', p_order_id);
END;
$$;

-- 4.16 Automated Proximity & Scoped Dispatch: auto_dispatch_order
CREATE OR REPLACE FUNCTION public.auto_dispatch_order(
  p_order_id UUID,
  p_max_distance_km DOUBLE PRECISION DEFAULT 25.0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order RECORD;
  v_matched_driver RECORD;
  v_state TEXT;
  v_lga TEXT;
  v_matched_dc RECORD;
  v_grand_dc RECORD;
BEGIN
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Order not found');
  END IF;

  v_state := COALESCE(NULLIF(TRIM(v_order.delivery_state), ''), '');
  v_lga := COALESCE(NULLIF(TRIM(v_order.delivery_lga), ''), NULLIF(TRIM(v_order.lga), ''), NULLIF(TRIM(v_order.delivery_city), ''), '');

  SELECT * INTO v_grand_dc FROM public.distribution_centers WHERE is_grand_dc = true AND is_active = true ORDER BY created_at ASC LIMIT 1;
  IF v_grand_dc IS NULL THEN
    SELECT * INTO v_grand_dc FROM public.distribution_centers WHERE is_hub = true AND is_active = true ORDER BY created_at ASC LIMIT 1;
  END IF;
  IF v_grand_dc IS NULL THEN
    SELECT * INTO v_grand_dc FROM public.distribution_centers WHERE is_active = true ORDER BY created_at ASC LIMIT 1;
  END IF;

  IF v_order.distribution_center_id IS NOT NULL THEN
    SELECT * INTO v_matched_dc FROM public.distribution_centers WHERE id = v_order.distribution_center_id AND is_active = true LIMIT 1;
  END IF;

  IF v_matched_dc IS NULL THEN
    SELECT * INTO v_matched_dc
    FROM public.distribution_centers
    WHERE is_active = true
      AND (LOWER(state) = LOWER(v_state) OR LOWER(name) ILIKE '%' || LOWER(v_state) || '%')
      AND (operating_zones @> jsonb_build_array(v_lga) OR operating_zones::text ILIKE '%' || v_lga || '%' OR v_lga = '')
    ORDER BY is_hub DESC, created_at ASC
    LIMIT 1;

    IF v_matched_dc IS NULL AND v_state <> '' THEN
      SELECT * INTO v_matched_dc
      FROM public.distribution_centers
      WHERE is_active = true AND (LOWER(state) = LOWER(v_state) OR LOWER(name) ILIKE '%' || LOWER(v_state) || '%')
      ORDER BY is_hub DESC, created_at ASC
      LIMIT 1;
    END IF;
  END IF;

  IF v_matched_dc IS NULL THEN
    UPDATE public.orders
    SET distribution_center_id = v_grand_dc.id,
        distribution_center_name = v_grand_dc.name,
        delivery_agent_id = NULL,
        assigned_agent_id = NULL,
        status = 'pending_dispatch',
        assignment_status = 'pending_dc_assignment',
        routing_notes = 'Escalated to Grand DC (' || v_grand_dc.name || '). No local DC matches State: ' || v_state,
        updated_at = NOW()
    WHERE id = p_order_id;

    RETURN jsonb_build_object(
      'success', true,
      'status', 'pending_dc_assignment',
      'distribution_center_id', v_grand_dc.id,
      'distribution_center_name', v_grand_dc.name,
      'message', 'No DC matches area. Escalated to Grand DC.'
    );
  END IF;

  SELECT * INTO v_matched_driver
  FROM public.delivery_agents
  WHERE is_active = true
    AND LOWER(current_status) = 'active'
    AND distribution_center_id = v_matched_dc.id
    AND (
      covered_lgas @> jsonb_build_array(v_lga)
      OR covered_lgas::text ILIKE '%' || v_lga || '%'
      OR operating_city ILIKE '%' || v_lga || '%'
    )
  ORDER BY created_at ASC
  LIMIT 1;

  IF v_matched_driver IS NOT NULL THEN
    UPDATE public.orders
    SET distribution_center_id = v_matched_dc.id,
        distribution_center_name = v_matched_dc.name,
        delivery_agent_id = v_matched_driver.id,
        assigned_agent_id = v_matched_driver.id,
        status = 'assigned',
        assignment_status = 'auto_assigned',
        routing_notes = 'Auto-assigned to Rider ' || COALESCE(v_matched_driver.agent_code, 'Rider') || ' (' || v_matched_dc.name || ')',
        updated_at = NOW()
    WHERE id = p_order_id;

    RETURN jsonb_build_object(
      'success', true,
      'status', 'assigned',
      'distribution_center_id', v_matched_dc.id,
      'distribution_center_name', v_matched_dc.name,
      'assigned_agent_id', v_matched_driver.id,
      'message', 'Auto-assigned to rider ' || COALESCE(v_matched_driver.agent_code, 'Rider')
    );
  ELSE
    UPDATE public.orders
    SET distribution_center_id = v_matched_dc.id,
        distribution_center_name = v_matched_dc.name,
        delivery_agent_id = NULL,
        assigned_agent_id = NULL,
        status = 'pending_dispatch',
        assignment_status = 'pending_rider_assignment',
        routing_notes = 'Routed to ' || v_matched_dc.name || '. Awaiting DC supervisor manual dispatch.',
        updated_at = NOW()
    WHERE id = p_order_id;

    RETURN jsonb_build_object(
      'success', true,
      'status', 'pending_rider_assignment',
      'distribution_center_id', v_matched_dc.id,
      'distribution_center_name', v_matched_dc.name,
      'assigned_agent_id', NULL,
      'message', 'Routed to ' || v_matched_dc.name || '. Awaiting manual rider dispatch.'
    );
  END IF;
END;
$$;

-- Backward-compatible alias
CREATE OR REPLACE FUNCTION public.auto_dispatch_order_by_state_lga(p_order_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN public.auto_dispatch_order(p_order_id);
END;
$$;

-- 4.17 Dynamic Remittance Transfer Fee Helper
CREATE OR REPLACE FUNCTION public.calculate_remittance_transfer_fee(p_amount NUMERIC)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN 0;
  END IF;
  RETURN CEIL(p_amount / 5000.0) * 100;
END;
$$;

-- 4.18 Complete Delivery Confirmation & Entitlements: confirm_delivery_pod
CREATE OR REPLACE FUNCTION public.confirm_delivery_pod(
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
    SELECT * INTO v_order
    FROM public.orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Order not found.'
        );
    END IF;

    SELECT * INTO v_agent
    FROM public.delivery_agents
    WHERE id = p_agent_id;

    v_commission := COALESCE(v_agent.commission_rate, CASE WHEN v_agent.personnel_type = 'in_house_rider' THEN 500 ELSE 1000 END);
    v_transport := CASE WHEN v_agent.personnel_type = 'in_house_rider' THEN COALESCE(v_agent.fuel_allowance, 800) ELSE COALESCE(v_agent.transport_allowance, 1500) END;
    v_earning := v_commission + v_transport;

    UPDATE public.orders
    SET 
        status = 'delivered',
        payment_status = 'collected',
        proof_of_delivery_url = COALESCE(p_proof_url, proof_of_delivery_url),
        delivery_notes = COALESCE(p_notes, delivery_notes),
        delivered_at = NOW(),
        updated_at = NOW()
    WHERE id = p_order_id;

    IF v_order.product_id IS NOT NULL THEN
        UPDATE public.products
        SET 
            available_count = GREATEST(0, COALESCE(available_count, 0) - COALESCE(v_order.quantity, 1)),
            delivered_count = COALESCE(delivered_count, 0) + COALESCE(v_order.quantity, 1)
        WHERE id = v_order.product_id;
    END IF;

    IF p_payment_type = 'pay_on_delivery' OR v_order.payment_type = 'pay_on_delivery' THEN
        v_net_to_remit := GREATEST(0, COALESCE(p_amount, v_order.total_amount) - v_earning);
        
        UPDATE public.delivery_agents
        SET current_cod_balance = current_cod_balance + v_net_to_remit
        WHERE id = p_agent_id
        RETURNING current_cod_balance, direct_transfer_balance INTO v_new_cod_balance, v_new_direct_balance;
    ELSE
        UPDATE public.delivery_agents
        SET direct_transfer_balance = direct_transfer_balance + v_earning
        WHERE id = p_agent_id
        RETURNING current_cod_balance, direct_transfer_balance INTO v_new_cod_balance, v_new_direct_balance;

        INSERT INTO public.rider_transactions (
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
            CONCAT('TXN-EARN-', TO_CHAR(NOW(), 'YYYYMMDD'), '-', SUBSTRING(p_order_id::TEXT FROM 1 FOR 4)),
            'Delivery Earning Credit',
            'delivery_earning',
            v_earning,
            TRUE,
            v_order.order_number,
            'completed',
            CONCAT('Delivery fee earned for ', v_order.order_number),
            NOW()
        );
    END IF;

    INSERT INTO public.order_activities (
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

-- 4.19 Log Delivery Failure / Reschedule: log_delivery_failure
CREATE OR REPLACE FUNCTION public.log_delivery_failure(
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

    UPDATE public.orders
    SET 
        status = v_new_status,
        scheduled_callback_at = p_reschedule_time,
        reschedule_note = p_reason_code,
        delivery_notes = COALESCE(p_notes, delivery_notes),
        updated_at = NOW()
    WHERE id = p_order_id;

    INSERT INTO public.order_activities (
        order_id,
        user_id,
        activity_type,
        notes,
        created_at
    ) VALUES (
        p_order_id,
        (SELECT user_id FROM public.delivery_agents WHERE id = p_agent_id),
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

-- 4.20 Driver Compensation Terms Update: update_driver_compensation
CREATE OR REPLACE FUNCTION public.update_driver_compensation(
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
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_res JSONB;
BEGIN
  UPDATE public.delivery_agents
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
  WHERE id::TEXT = p_agent_id OR agent_code = p_agent_id;

  SELECT to_jsonb(d) INTO v_res FROM public.delivery_agents d WHERE id::TEXT = p_agent_id OR agent_code = p_agent_id;
  RETURN v_res;
END;
$$;

-- 4.21 Decrement Driver Entitlement (on payout approval): decrement_driver_entitlement
CREATE OR REPLACE FUNCTION public.decrement_driver_entitlement(
    p_driver_id UUID,
    p_amount NUMERIC
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.delivery_agents
    SET 
        direct_transfer_balance = GREATEST(0.00, COALESCE(direct_transfer_balance, 0.00) - p_amount),
        updated_at = NOW()
    WHERE id = p_driver_id;
END;
$$;

-- 4.22 Cash Remittance Approval & Rider COD Balance Clearance: fn_approve_cash_remittance
CREATE OR REPLACE FUNCTION public.fn_approve_cash_remittance(
    p_remittance_id UUID,
    p_supervisor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_rem RECORD;
    v_ord RECORD;
BEGIN
    SELECT * INTO v_rem
    FROM public.cash_remittances
    WHERE id = p_remittance_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Remittance record not found');
    END IF;

    UPDATE public.cash_remittances
    SET status = 'approved',
        verified_by = p_supervisor_id,
        verified_at = NOW(),
        updated_at = NOW()
    WHERE id = p_remittance_id;

    UPDATE public.delivery_agents
    SET current_cod_balance = GREATEST(0.00, COALESCE(current_cod_balance, 0.00) - v_rem.amount),
        updated_at = NOW()
    WHERE id = v_rem.delivery_agent_id;

    FOR v_ord IN 
        SELECT order_id FROM public.remittance_orders WHERE remittance_id = p_remittance_id
    LOOP
        UPDATE public.orders
        SET remittance_status = 'remitted',
            financial_settlement_status = 'in_dc_custody',
            remitted_at = NOW(),
            updated_at = NOW()
        WHERE id = v_ord.order_id;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'message', 'Cash remittance approved and cleared');
END;
$$;

-- 4.23 Merchant Asset Custody & Dual Valuation: fn_calculate_merchant_asset_custody
CREATE OR REPLACE FUNCTION public.fn_calculate_merchant_asset_custody(
    p_client_id UUID,
    p_dc_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_cash_in_paystack NUMERIC(14, 2) := 0.00;
    v_cash_in_dc_vault NUMERIC(14, 2) := 0.00;
    v_total_liquid_cash NUMERIC(14, 2) := 0.00;
    v_total_units_in_custody INT := 0;
    v_base_inventory_valuation NUMERIC(14, 2) := 0.00;
    v_weighted_retail_valuation NUMERIC(14, 2) := 0.00;
    v_prod RECORD;
BEGIN
    SELECT 
        COALESCE(SUM(CASE WHEN COALESCE(payment_method, delivery_method, 'cash') = 'paystack' OR payment_type = 'prepaid' THEN (total_amount - COALESCE(client_delivery_fee, 3500.00)) ELSE 0 END), 0.00),
        COALESCE(SUM(CASE WHEN COALESCE(payment_method, delivery_method, 'cash') = 'cash' AND payment_type = 'pay_on_delivery' THEN (total_amount - COALESCE(client_delivery_fee, 3500.00)) ELSE 0 END), 0.00)
    INTO v_cash_in_paystack, v_cash_in_dc_vault
    FROM public.orders
    WHERE client_id = p_client_id
      AND status = 'delivered'
      AND (financial_settlement_status IS NULL OR financial_settlement_status != 'client_settled')
      AND (p_dc_id IS NULL OR distribution_center_id = p_dc_id);

    v_total_liquid_cash := v_cash_in_paystack + v_cash_in_dc_vault;

    FOR v_prod IN
        SELECT id, name, sku, base_price, stock_quantity, available_count
        FROM public.products
        WHERE client_id = p_client_id OR client_name IN (SELECT company_name FROM public.clients WHERE id = p_client_id)
    LOOP
        DECLARE
            v_units INT := COALESCE(v_prod.stock_quantity, v_prod.available_count, 0);
            v_avg_price NUMERIC(14, 2);
        BEGIN
            v_total_units_in_custody := v_total_units_in_custody + v_units;
            v_base_inventory_valuation := v_base_inventory_valuation + (v_units * COALESCE(v_prod.base_price, 25000.00));

            SELECT COALESCE(AVG(total_amount / NULLIF(quantity, 0)), v_prod.base_price, 25000.00)
            INTO v_avg_price
            FROM public.orders
            WHERE client_id = p_client_id AND product_name = v_prod.name AND status = 'delivered';

            v_weighted_retail_valuation := v_weighted_retail_valuation + (v_units * v_avg_price);
        END;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'client_id', p_client_id,
        'liquid_cash_in_custody', v_total_liquid_cash,
        'physical_cod_in_dc_vault', v_cash_in_dc_vault,
        'direct_transfer_in_paystack', v_cash_in_paystack,
        'total_inventory_units_held', v_total_units_in_custody,
        'inventory_baseline_liquidation_value', v_base_inventory_valuation,
        'inventory_estimated_retail_value', v_weighted_retail_valuation,
        'grand_total_asset_value', (v_total_liquid_cash + v_weighted_retail_valuation)
    );
END;
$$;

-- 4.24 Authoritative Merchant Daily Settlement Calculation (Negotiated Charges & 3-Way Split)
CREATE OR REPLACE FUNCTION public.fn_generate_merchant_daily_settlement(
    p_client_id UUID,
    p_dc_id UUID,
    p_period_start TIMESTAMPTZ DEFAULT NULL,
    p_period_end TIMESTAMPTZ DEFAULT clock_timestamp(),
    p_custom_deductions JSONB DEFAULT '{}'::jsonb,
    p_order_ids UUID[] DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_client RECORD;
    v_dc_settings RECORD;
    v_settlement_id UUID := gen_random_uuid();
    v_settlement_number TEXT;
    v_eff_period_end TIMESTAMPTZ := COALESCE(p_period_end, clock_timestamp());
    v_eff_period_start TIMESTAMPTZ := p_period_start;
    v_has_order_ids BOOLEAN := (p_order_ids IS NOT NULL AND array_length(p_order_ids, 1) > 0);

    v_orders_count INT := 0;
    v_gross_collections NUMERIC(14, 2) := 0.00;
    v_delivery_fees NUMERIC(14, 2) := 0.00;
    v_failed_attempt_fees NUMERIC(14, 2) := 0.00;
    v_gateway_fees NUMERIC(14, 2) := 0.00;
    v_system_operation_fees NUMERIC(14, 2) := 0.00;
    v_other_charges NUMERIC(14, 2) := 0.00;
    v_total_platform_charges NUMERIC(14, 2) := 0.00;

    v_order RECORD;
    v_order_delivery_fee NUMERIC(14, 2);
    v_order_system_fee NUMERIC(14, 2);
    v_order_gateway_fee NUMERIC(14, 2);
    v_total_deductions NUMERIC(14, 2) := 0.00;
    v_net_payout NUMERIC(14, 2) := 0.00;
    v_charges_breakdown JSONB;
BEGIN
    SELECT * INTO v_client FROM public.clients WHERE id = p_client_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Client not found');
    END IF;

    SELECT * INTO v_dc_settings FROM public.dc_finance_settings WHERE distribution_center_id = p_dc_id::TEXT LIMIT 1;
    IF NOT FOUND THEN
        SELECT * INTO v_dc_settings FROM public.dc_finance_settings WHERE id = 'global_finance_config' LIMIT 1;
    END IF;

    v_settlement_number := 'SETTL-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || UPPER(SUBSTRING(gen_random_uuid()::TEXT FROM 1 FOR 6));

    IF v_has_order_ids THEN
        FOR v_order IN 
            SELECT id, order_number, total_amount, payment_type, COALESCE(payment_method, delivery_method, 'cash') AS eff_method, client_delivery_fee
            FROM public.orders
            WHERE id = ANY(p_order_ids)
              AND client_id = p_client_id
              AND status = 'delivered'
              AND (financial_settlement_status IS NULL OR financial_settlement_status != 'client_settled')
        LOOP
            v_orders_count := v_orders_count + 1;
            v_gross_collections := v_gross_collections + COALESCE(v_order.total_amount, 0.00);

            v_order_delivery_fee := COALESCE(v_client.custom_delivery_fee, v_order.client_delivery_fee, v_dc_settings.default_client_delivery_fee, 5000.00);
            v_delivery_fees := v_delivery_fees + v_order_delivery_fee;

            IF COALESCE(v_client.custom_platform_fee, 0) > 0 THEN
                v_order_system_fee := v_client.custom_platform_fee;
            ELSIF v_dc_settings.platform_fee_type = 'percent' THEN
                v_order_system_fee := (COALESCE(v_order.total_amount, 0.00) * (COALESCE(v_dc_settings.platform_fee_value, 2.5) / 100.0));
            ELSE
                v_order_system_fee := COALESCE(v_dc_settings.platform_fee_value, 500.00);
            END IF;
            v_system_operation_fees := v_system_operation_fees + v_order_system_fee;

            IF v_order.eff_method = 'paystack' OR v_order.payment_type = 'prepaid' THEN
                IF COALESCE(v_dc_settings.paystack_fee_absorbed_by, 'merchant') = 'merchant' THEN
                    v_order_gateway_fee := LEAST(2000.00, (COALESCE(v_order.total_amount, 0.00) * 0.015));
                    v_gateway_fees := v_gateway_fees + v_order_gateway_fee;
                END IF;
            ELSE
                v_gateway_fees := v_gateway_fees + COALESCE(v_dc_settings.remittance_switch_fee, 100.00);
            END IF;
        END LOOP;
    ELSE
        FOR v_order IN 
            SELECT id, order_number, total_amount, payment_type, COALESCE(payment_method, delivery_method, 'cash') AS eff_method, client_delivery_fee
            FROM public.orders
            WHERE client_id = p_client_id
              AND status = 'delivered'
              AND (financial_settlement_status IS NULL OR financial_settlement_status != 'client_settled')
              AND (v_eff_period_start IS NULL OR delivered_at >= v_eff_period_start)
              AND (delivered_at <= v_eff_period_end)
        LOOP
            v_orders_count := v_orders_count + 1;
            v_gross_collections := v_gross_collections + COALESCE(v_order.total_amount, 0.00);

            v_order_delivery_fee := COALESCE(v_client.custom_delivery_fee, v_order.client_delivery_fee, v_dc_settings.default_client_delivery_fee, 5000.00);
            v_delivery_fees := v_delivery_fees + v_order_delivery_fee;

            IF COALESCE(v_client.custom_platform_fee, 0) > 0 THEN
                v_order_system_fee := v_client.custom_platform_fee;
            ELSIF v_dc_settings.platform_fee_type = 'percent' THEN
                v_order_system_fee := (COALESCE(v_order.total_amount, 0.00) * (COALESCE(v_dc_settings.platform_fee_value, 2.5) / 100.0));
            ELSE
                v_order_system_fee := COALESCE(v_dc_settings.platform_fee_value, 500.00);
            END IF;
            v_system_operation_fees := v_system_operation_fees + v_order_system_fee;

            IF v_order.eff_method = 'paystack' OR v_order.payment_type = 'prepaid' THEN
                IF COALESCE(v_dc_settings.paystack_fee_absorbed_by, 'merchant') = 'merchant' THEN
                    v_order_gateway_fee := LEAST(2000.00, (COALESCE(v_order.total_amount, 0.00) * 0.015));
                    v_gateway_fees := v_gateway_fees + v_order_gateway_fee;
                END IF;
            ELSE
                v_gateway_fees := v_gateway_fees + COALESCE(v_dc_settings.remittance_switch_fee, 100.00);
            END IF;
        END LOOP;
    END IF;

    IF v_orders_count = 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'No eligible delivered orders found for settlement',
            'orders_settled', 0,
            'gross_collections', 0.00,
            'net_payout', 0.00
        );
    END IF;

    IF NOT v_has_order_ids AND COALESCE(v_client.custom_failed_attempt_fee, v_dc_settings.failed_order_charge, 0) > 0 THEN
        SELECT COALESCE(COUNT(*), 0) * COALESCE(v_client.custom_failed_attempt_fee, v_dc_settings.failed_order_charge, 1000.00)
        INTO v_failed_attempt_fees
        FROM public.orders
        WHERE client_id = p_client_id
          AND status IN ('cancelled', 'failed', 'rejected')
          AND (v_eff_period_start IS NULL OR updated_at >= v_eff_period_start)
          AND updated_at <= v_eff_period_end;
    END IF;

    IF p_custom_deductions ? 'packaging_fees' THEN
        v_other_charges := v_other_charges + COALESCE((p_custom_deductions->>'packaging_fees')::NUMERIC, 0.00);
    END IF;
    IF p_custom_deductions ? 'storage_fees' THEN
        v_other_charges := v_other_charges + COALESCE((p_custom_deductions->>'storage_fees')::NUMERIC, 0.00);
    END IF;
    IF p_custom_deductions ? 'dispute_deductions' THEN
        v_other_charges := v_other_charges + COALESCE((p_custom_deductions->>'dispute_deductions')::NUMERIC, 0.00);
    END IF;
    IF p_custom_deductions ? 'ad_hoc_adjustment' THEN
        v_other_charges := v_other_charges + COALESCE((p_custom_deductions->>'ad_hoc_adjustment')::NUMERIC, 0.00);
    END IF;

    v_total_platform_charges := v_system_operation_fees;
    v_total_deductions := v_delivery_fees + v_failed_attempt_fees + v_total_platform_charges + v_gateway_fees + v_other_charges;
    v_net_payout := GREATEST(0.00, v_gross_collections - v_total_deductions);

    v_charges_breakdown := jsonb_build_object(
        'delivery_charges', v_delivery_fees,
        'system_operation_charge', v_system_operation_fees,
        'third_party_gateway_fees', v_gateway_fees,
        'failed_delivery_penalties', v_failed_attempt_fees,
        'other_custom_deductions', v_other_charges,
        'split_analysis', jsonb_build_object(
            'merchant_net_credit', v_net_payout,
            'logistics_hub_revenue', v_delivery_fees + v_failed_attempt_fees,
            'app_operational_revenue', v_system_operation_fees,
            'payment_switch_provider_fees', v_gateway_fees
        )
    );

    INSERT INTO public.client_settlements (
        id,
        settlement_number,
        client_id,
        distribution_center_id,
        period_start,
        period_end,
        total_orders,
        gross_amount,
        delivery_fees,
        platform_fee,
        gateway_fee,
        failed_attempt_fee,
        other_deductions,
        net_amount,
        deductions_breakdown,
        bank_name,
        account_number,
        account_name,
        status,
        notes,
        created_at,
        settled_at
    ) VALUES (
        v_settlement_id,
        v_settlement_number,
        p_client_id,
        p_dc_id,
        COALESCE(v_eff_period_start, NOW() - INTERVAL '30 days'),
        v_eff_period_end,
        v_orders_count,
        v_gross_collections,
        v_delivery_fees,
        v_system_operation_fees,
        v_gateway_fees,
        v_failed_attempt_fees,
        v_other_charges,
        v_net_payout,
        v_charges_breakdown,
        COALESCE(v_client.bank_name, 'Access Bank'),
        COALESCE(v_client.account_number, '0123456789'),
        COALESCE(v_client.account_name, v_client.company_name, v_client.name),
        'settled',
        COALESCE(p_custom_deductions->>'notes', 'Client Settlement Batch'),
        NOW(),
        NOW()
    );

    IF v_has_order_ids THEN
        UPDATE public.orders
        SET financial_settlement_status = 'client_settled',
            remittance_status = 'remitted',
            remittance_reference = v_settlement_number,
            remitted_at = NOW(),
            updated_at = NOW()
        WHERE id = ANY(p_order_ids)
          AND client_id = p_client_id
          AND status = 'delivered'
          AND (financial_settlement_status IS NULL OR financial_settlement_status != 'client_settled');
    ELSE
        UPDATE public.orders
        SET financial_settlement_status = 'client_settled',
            remittance_status = 'remitted',
            remittance_reference = v_settlement_number,
            remitted_at = NOW(),
            updated_at = NOW()
        WHERE client_id = p_client_id
          AND status = 'delivered'
          AND (financial_settlement_status IS NULL OR financial_settlement_status != 'client_settled')
          AND (v_eff_period_start IS NULL OR delivered_at >= v_eff_period_start)
          AND (delivered_at <= v_eff_period_end);
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'settlement_id', v_settlement_id,
        'settlement_number', v_settlement_number,
        'gross_collections', v_gross_collections,
        'orders_settled', v_orders_count,
        'delivery_fees', v_delivery_fees,
        'failed_attempt_fees', v_failed_attempt_fees,
        'platform_charges', v_total_platform_charges,
        'total_deductions', v_total_deductions,
        'net_payout', v_net_payout,
        'charges_breakdown', v_charges_breakdown
    );
END;
$$;

-- 4.25 Reset Conversation Read Counters: fn_mark_conversation_read
CREATE OR REPLACE FUNCTION public.fn_mark_conversation_read(
    p_conversation_id UUID,
    p_role TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF lower(p_role) IN ('rider', 'delivery_agent', 'pda') THEN
        UPDATE public.order_conversations
        SET unread_rider_count = 0, updated_at = now()
        WHERE id = p_conversation_id;

        UPDATE public.order_conversation_messages
        SET read_by_rider = true
        WHERE conversation_id = p_conversation_id AND read_by_rider = false;

    ELSIF lower(p_role) IN ('dc_manager', 'dc_staff', 'operations') THEN
        UPDATE public.order_conversations
        SET unread_dc_count = 0, updated_at = now()
        WHERE id = p_conversation_id;

        UPDATE public.order_conversation_messages
        SET read_by_dc = true
        WHERE conversation_id = p_conversation_id AND read_by_dc = false;

    ELSIF lower(p_role) IN ('client', 'merchant', 'closer', 'sales_closer') THEN
        UPDATE public.order_conversations
        SET unread_client_count = 0, updated_at = now()
        WHERE id = p_conversation_id;

        UPDATE public.order_conversation_messages
        SET read_by_client = true
        WHERE conversation_id = p_conversation_id AND read_by_client = false;
    END IF;
END;
$$;

-- 4.26 Order Product & Package Reassignment with Audit Log: transfer_order_product_and_ownership
CREATE OR REPLACE FUNCTION public.transfer_order_product_and_ownership(
    p_order_id UUID,
    p_new_product_id UUID,
    p_new_package_deal_id TEXT,
    p_new_package_name TEXT DEFAULT NULL,
    p_new_quantity INT DEFAULT NULL,
    p_new_paid_quantity INT DEFAULT NULL,
    p_new_free_quantity INT DEFAULT NULL,
    p_new_base_price NUMERIC DEFAULT NULL,
    p_new_total_amount NUMERIC DEFAULT NULL,
    p_actor_name TEXT DEFAULT 'Operator',
    p_actor_role TEXT DEFAULT 'dc_manager',
    p_transfer_reason TEXT DEFAULT 'Product or package modified'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_curr_order RECORD;
    v_new_product RECORD;
    v_package RECORD;
    v_old_client_name TEXT;
    v_new_client_name TEXT;
    v_is_ownership_transfer BOOLEAN := false;
    v_final_package_name TEXT;
    v_final_quantity INT;
    v_final_paid_quantity INT;
    v_final_free_quantity INT;
    v_final_price NUMERIC(14,2);
BEGIN
    IF lower(COALESCE(p_actor_role, '')) IN ('rider', 'delivery_agent', 'pda') THEN
        RAISE EXCEPTION 'Unauthorized: Riders are restricted from directly modifying order products or package deals.';
    END IF;

    SELECT * INTO v_curr_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order with ID % not found', p_order_id;
    END IF;

    SELECT * INTO v_new_product FROM public.products WHERE id = p_new_product_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product with ID % not found', p_new_product_id;
    END IF;

    SELECT * INTO v_package 
    FROM public.product_packages 
    WHERE id = p_new_package_deal_id;

    IF FOUND THEN
        v_final_package_name := v_package.package_name;
        v_final_quantity := v_package.quantity;
        v_final_paid_quantity := COALESCE(v_package.paid_quantity, v_package.quantity);
        v_final_free_quantity := COALESCE(v_package.free_quantity, 0);
        v_final_price := v_package.package_price;
    ELSE
        SELECT * INTO v_package 
        FROM public.product_packages 
        WHERE (product_id = p_new_product_id::text OR product_sku = v_new_product.sku OR product_name ILIKE v_new_product.name)
          AND (id = p_new_package_deal_id OR package_name ILIKE p_new_package_name)
        LIMIT 1;

        IF FOUND THEN
            v_final_package_name := v_package.package_name;
            v_final_quantity := v_package.quantity;
            v_final_paid_quantity := COALESCE(v_package.paid_quantity, v_package.quantity);
            v_final_free_quantity := COALESCE(v_package.free_quantity, 0);
            v_final_price := v_package.package_price;
        ELSE
            IF p_new_package_name IS NOT NULL AND p_new_total_amount IS NOT NULL AND p_new_total_amount > 0 THEN
                v_final_package_name := p_new_package_name;
                v_final_quantity := COALESCE(p_new_quantity, 1);
                v_final_paid_quantity := COALESCE(p_new_paid_quantity, v_final_quantity);
                v_final_free_quantity := COALESCE(p_new_free_quantity, 0);
                v_final_price := p_new_total_amount;
            ELSE
                RAISE EXCEPTION 'Package deal "%" is not an authorized package for product "%".', 
                    p_new_package_deal_id, v_new_product.name;
            END IF;
        END IF;
    END IF;

    v_old_client_name := COALESCE(v_curr_order.client_name, 'Original Client');

    SELECT COALESCE(company_name, name) INTO v_new_client_name FROM public.clients WHERE id = v_new_product.client_id;
    IF v_new_client_name IS NULL THEN v_new_client_name := COALESCE(v_new_product.client_name, 'Merchant Client'); END IF;

    IF v_curr_order.client_id <> v_new_product.client_id THEN
        v_is_ownership_transfer := true;
    END IF;

    UPDATE public.orders
    SET
        product_id = v_new_product.id,
        product_name = v_new_product.name,
        package_deal_id = p_new_package_deal_id,
        package_deal_name = v_final_package_name,
        quantity = v_final_quantity,
        paid_quantity = v_final_paid_quantity,
        free_quantity = v_final_free_quantity,
        total_amount = v_final_price,
        client_id = v_new_product.client_id,
        client_name = v_new_client_name,
        handling_fee = COALESCE(v_new_product.handling_fee, handling_fee),
        client_delivery_fee = COALESCE(v_new_product.delivery_fee, client_delivery_fee),
        updated_at = NOW()
    WHERE id = p_order_id;

    INSERT INTO public.order_activities (
        order_id,
        user_id,
        activity_type,
        notes,
        created_at
    ) VALUES (
        p_order_id,
        NULL,
        'package_transferred',
        CONCAT('Package updated to [', v_final_package_name, '] (₦', v_final_price, ') by ', p_actor_name, ' (', p_actor_role, '). Reason: ', p_transfer_reason),
        NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'product_name', v_new_product.name,
        'package_deal_name', v_final_package_name,
        'total_amount', v_final_price,
        'client_name', v_new_client_name,
        'is_ownership_transfer', v_is_ownership_transfer
    );
END;
$$;

-- 4.27 Function & Permissions Grants (Strictly No Conflicting Overloads)
GRANT EXECUTE ON FUNCTION public.fn_adjust_dc_stock(UUID, UUID, INT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_dispatch_client_supply(UUID, UUID, JSONB, UUID, TEXT, TEXT, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_receive_client_supply(UUID, UUID, TEXT, TEXT, JSONB, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_dispatch_inter_dc_transfer(UUID, UUID, UUID, INT, UUID, TEXT, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_receive_inter_dc_transfer(UUID, UUID, TEXT, INT, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_issue_dc_stock_to_rider(UUID, UUID, JSONB, UUID, TEXT, TEXT, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_rider_accept_stock_handover(UUID, UUID, TEXT, TEXT, JSONB, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_rider_reject_stock_handover(UUID, UUID, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_cancel_dc_stock_handover(UUID, UUID, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_confirm_order_delivery_stock(UUID, UUID, UUID, INT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_receive_rider_stock_return(UUID, UUID, UUID, INT, TEXT, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.calculate_haversine_distance_km(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.find_closest_available_rider(DOUBLE PRECISION, DOUBLE PRECISION, UUID, DOUBLE PRECISION) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.update_rider_gps_telemetry(UUID, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.record_verified_gate_pin(UUID, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.auto_dispatch_order(UUID, DOUBLE PRECISION) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.auto_dispatch_order_by_state_lga(UUID) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.calculate_remittance_transfer_fee(NUMERIC) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.confirm_delivery_pod(UUID, UUID, VARCHAR, NUMERIC, TEXT, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.log_delivery_failure(UUID, UUID, VARCHAR, TIMESTAMPTZ, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.update_driver_compensation(TEXT, NUMERIC, NUMERIC, NUMERIC, NUMERIC, TEXT, TEXT, JSONB, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.decrement_driver_entitlement(UUID, NUMERIC) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_approve_cash_remittance(UUID, UUID) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_calculate_merchant_asset_custody(UUID, UUID) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_generate_merchant_daily_settlement(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, JSONB, UUID[]) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_mark_conversation_read(UUID, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.transfer_order_product_and_ownership(UUID, UUID, TEXT, TEXT, INT, INT, INT, NUMERIC, NUMERIC, TEXT, TEXT, TEXT) TO authenticated, service_role, anon;

-- 4.28 Order Pipeline Chat Triggers & Realtime Counters
CREATE OR REPLACE FUNCTION public.fn_sync_order_conversation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_client_name TEXT;
    v_dc_name TEXT;
    v_rider_name TEXT;
    v_closer_name TEXT;
BEGIN
    IF NEW.client_id IS NOT NULL THEN
        SELECT company_name INTO v_client_name FROM public.clients WHERE id = NEW.client_id;
    END IF;

    IF NEW.distribution_center_id IS NOT NULL THEN
        SELECT name INTO v_dc_name FROM public.distribution_centers WHERE id = NEW.distribution_center_id;
    END IF;

    IF NEW.delivery_agent_id IS NOT NULL THEN
        SELECT full_name INTO v_rider_name FROM public.delivery_agents WHERE id = NEW.delivery_agent_id;
    END IF;

    IF NEW.closer_id IS NOT NULL THEN
        SELECT full_name INTO v_closer_name FROM public.client_closers WHERE id = NEW.closer_id;
    END IF;

    INSERT INTO public.order_conversations (
        order_id,
        order_number,
        customer_name,
        customer_phone,
        client_id,
        client_name,
        distribution_center_id,
        distribution_center_name,
        delivery_agent_id,
        delivery_agent_name,
        closer_id,
        closer_name,
        order_status,
        current_product_name,
        current_package_name,
        current_total_amount,
        last_message_text,
        last_message_sender_name,
        last_message_at,
        updated_at
    ) VALUES (
        NEW.id,
        NEW.order_number,
        NEW.customer_name,
        NEW.customer_phone,
        NEW.client_id,
        v_client_name,
        NEW.distribution_center_id,
        v_dc_name,
        NEW.delivery_agent_id,
        v_rider_name,
        NEW.closer_id,
        v_closer_name,
        NEW.status,
        NEW.product_name,
        NEW.package_deal_name,
        COALESCE(NEW.total_amount, 0),
        'Order pipeline active.',
        'System',
        NOW(),
        NOW()
    )
    ON CONFLICT (order_id) DO UPDATE SET
        order_number = EXCLUDED.order_number,
        customer_name = EXCLUDED.customer_name,
        customer_phone = EXCLUDED.customer_phone,
        client_id = EXCLUDED.client_id,
        client_name = EXCLUDED.client_name,
        distribution_center_id = EXCLUDED.distribution_center_id,
        distribution_center_name = EXCLUDED.distribution_center_name,
        delivery_agent_id = EXCLUDED.delivery_agent_id,
        delivery_agent_name = EXCLUDED.delivery_agent_name,
        closer_id = EXCLUDED.closer_id,
        closer_name = EXCLUDED.closer_name,
        order_status = EXCLUDED.order_status,
        current_product_name = EXCLUDED.current_product_name,
        current_package_name = EXCLUDED.current_package_name,
        current_total_amount = EXCLUDED.current_total_amount,
        updated_at = NOW();

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_orders_sync_conversation ON public.orders;
CREATE TRIGGER trg_orders_sync_conversation
    AFTER INSERT OR UPDATE OF customer_name, customer_phone, client_id, distribution_center_id, delivery_agent_id, closer_id, status, product_name, package_deal_name, total_amount
    ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_sync_order_conversation();

-- 4.29 Chat Message Counter & Tagging Trigger
CREATE OR REPLACE FUNCTION public.fn_on_order_message_inserted()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.order_conversations
    SET 
        last_message_text = NEW.message,
        last_message_sender_id = NEW.sender_id,
        last_message_sender_name = NEW.sender_name,
        last_message_at = NEW.created_at,
        unread_client_count = CASE WHEN NEW.sender_role <> 'client' THEN unread_client_count + 1 ELSE unread_client_count END,
        unread_dc_count = CASE WHEN NEW.sender_role <> 'dc' THEN unread_dc_count + 1 ELSE unread_dc_count END,
        unread_rider_count = CASE WHEN NEW.sender_role <> 'rider' THEN unread_rider_count + 1 ELSE unread_rider_count END,
        updated_at = NOW()
    WHERE id = NEW.conversation_id;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_message_inserted_update_conversation ON public.order_conversation_messages;
CREATE TRIGGER trg_message_inserted_update_conversation
    AFTER INSERT ON public.order_conversation_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_on_order_message_inserted();


-- ============================================================================
-- 5. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

DO $$
DECLARE
    tbl text;
BEGIN
    FOR tbl IN 
        SELECT tablename FROM pg_tables 
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY;', tbl);
        EXECUTE format('DROP POLICY IF EXISTS "Public Full Access" ON %I;', tbl);
        EXECUTE format('CREATE POLICY "Public Full Access" ON %I FOR ALL USING (true) WITH CHECK (true);', tbl);
    END LOOP;
END $$;

-- ============================================================================
-- 6. FOUNDATIONAL SEED DATA
-- Default accounts and logistics hubs for instant operations
-- ============================================================================

-- 6.1 Default Logistics Company
INSERT INTO public.companies (id, name, code, email, phone, address, currency)
VALUES (
    '11111111-1111-4111-8111-111111111111',
    'NovaXpress Logistics Limited',
    'NOVEXPS',
    'operations@novaxpress.ng',
    '+2348000000000',
    'Plot 102 Central Business District, Abuja, Nigeria',
    'NGN'
) ON CONFLICT (code) DO NOTHING;

-- 6.2 Distribution Centers (Grand Hub & Satellite Hub)
INSERT INTO public.distribution_centers (
    id, company_id, name, code, state, city, address, contact_phone, is_hub, is_grand_dc, is_primary_dc, manager_name, operating_zones
) VALUES 
(
    '22222222-2222-4222-8222-222222222222',
    '11111111-1111-4111-8111-111111111111',
    'Wuse Central Distribution Hub',
    'DC-WUSE-01',
    'FCT',
    'Abuja',
    'Plot 124 Aminu Kano Crescent, Wuse 2, Abuja',
    '+2348011111111',
    true,
    true,
    true,
    'Aliyu Mohammed',
    '["Abuja Municipal", "Bwari", "Garki", "Wuse", "Maitama", "Utako", "Jabi"]'::jsonb
),
(
    '00000000-0000-4000-8000-789382566045',
    '11111111-1111-4111-8111-111111111111',
    'Kaduna Main DC',
    'DC-KD-001',
    'Kaduna',
    'Kaduna',
    'Ahmadu Bello Way, Kaduna',
    '+2348022222222',
    false,
    false,
    false,
    'Grace Okon',
    '["Kaduna North", "Kaduna South", "Chikun"]'::jsonb
) ON CONFLICT (code) DO UPDATE SET
    operating_zones = EXCLUDED.operating_zones,
    is_grand_dc = EXCLUDED.is_grand_dc;

-- 6.3 DC Hub Warehouses
INSERT INTO public.warehouses (id, company_id, distribution_center_id, name, type, location_state, location_city, address)
VALUES 
(
    'w1111111-1111-4111-8111-111111111111',
    '11111111-1111-4111-8111-111111111111',
    '22222222-2222-4222-8222-222222222222',
    'Wuse Central Main Vault',
    'hub',
    'FCT',
    'Abuja',
    'Plot 124 Aminu Kano Crescent, Wuse 2'
),
(
    'w2222222-2222-4222-8222-222222222222',
    '11111111-1111-4111-8111-111111111111',
    '00000000-0000-4000-8000-789382566045',
    'Kaduna Satellite Warehouse',
    'sub_hub',
    'Kaduna',
    'Kaduna',
    'Ahmadu Bello Way, Kaduna'
) ON CONFLICT (id) DO NOTHING;

-- 6.4 DC Global Finance Settings
INSERT INTO public.dc_finance_settings (
    id,
    distribution_center_id,
    pos_charge_mode,
    pos_flat_rate,
    pos_tier_amount,
    pos_tier_fee,
    pos_max_cap_fee,
    paystack_direct_fee_percent,
    paystack_fee_cap,
    default_commission_rate,
    default_transport_allowance,
    default_failed_stipend,
    default_client_delivery_fee,
    failed_order_charge,
    platform_fee_type,
    platform_fee_value,
    remittance_switch_fee,
    paystack_fee_absorbed_by,
    daily_settlement_cutoff_time,
    settlement_bank_name,
    settlement_account_number,
    settlement_account_name,
    auto_reconcile_webhooks
) VALUES (
    'global_finance_config',
    NULL,
    'dynamic',
    350.00,
    5000.00,
    100.00,
    1500.00,
    1.50,
    2000.00,
    1000.00,
    1500.00,
    500.00,
    5000.00,
    1000.00,
    'flat',
    500.00,
    100.00,
    'merchant',
    '22:00',
    'Titan Trust Bank',
    '0098234123',
    'NovaXpress Logistics Limited',
    true
) ON CONFLICT (id) DO UPDATE SET
    default_client_delivery_fee = 5000.00,
    failed_order_charge = 1000.00,
    platform_fee_value = 500.00,
    remittance_switch_fee = 100.00;

-- 6.5 Default Users (Admin, DC Manager, PDA Rider)
INSERT INTO public.users (
    id, company_id, distribution_center_id, distribution_center_name, email, phone_number, first_name, last_name, role
) VALUES 
(
    'a1111111-1111-4111-8111-111111111111',
    '11111111-1111-4111-8111-111111111111',
    '22222222-2222-4222-8222-222222222222',
    'Wuse Central Distribution Hub',
    'admin@novaxpress.ng',
    '+2348030000001',
    'Super',
    'Admin',
    'admin'
),
(
    'm1111111-1111-4111-8111-111111111111',
    '11111111-1111-4111-8111-111111111111',
    '22222222-2222-4222-8222-222222222222',
    'Wuse Central Distribution Hub',
    'manager.wuse@novaxpress.ng',
    '+2348030000002',
    'Aliyu',
    'Mohammed',
    'dc_manager'
),
(
    'u1111111-1111-4111-8111-111111111111',
    '11111111-1111-4111-8111-111111111111',
    '22222222-2222-4222-8222-222222222222',
    'Wuse Central Distribution Hub',
    'rider1@novaxpress.ng',
    '+2348030000003',
    'Ibrahim',
    'Musa',
    'delivery_agent'
) ON CONFLICT (email) DO NOTHING;

-- 6.6 Delivery Agent (Primary Rider b1111111-1111-4111-8111-111111111111)
INSERT INTO public.delivery_agents (
    id, user_id, distribution_center_id, agent_code, full_name, vehicle_type, vehicle_plate_number,
    operating_state, operating_city, covered_lgas, current_status, current_cod_balance,
    commission_rate, transport_allowance, failed_delivery_allowance, is_on_duty, is_active
) VALUES (
    'b1111111-1111-4111-8111-111111111111',
    'u1111111-1111-4111-8111-111111111111',
    '22222222-2222-4222-8222-222222222222',
    'RIDER-001',
    'Ibrahim Musa',
    'Motorcycle',
    'ABJ-123-XY',
    'FCT',
    'Abuja',
    '["Abuja Municipal", "Bwari", "Gwagwalada", "Wuse", "Garki", "Maitama"]'::jsonb,
    'available',
    0.00,
    1000.00,
    1500.00,
    500.00,
    true,
    true
) ON CONFLICT (agent_code) DO NOTHING;

-- 6.7 Default Client (Novacare)
INSERT INTO public.clients (
    id, company_id, name, company_name, contact_person, email, phone, address, city, state, code, tier,
    bank_name, account_number, account_name, settlement_frequency, is_active,
    custom_delivery_fee, custom_failed_attempt_fee, custom_platform_fee, custom_platform_fee_type, custom_paystack_fee_absorbed_by
) VALUES (
    '00000000-0000-4000-8000-789382731303',
    '11111111-1111-4111-8111-111111111111',
    'Novacare',
    'Novacare Health & Wellness',
    'Dr. Emeka Okafor',
    'operations@novacare.ng',
    '+2348012345678',
    'Plot 45 Gana Street, Maitama, Abuja',
    'Abuja',
    'FCT',
    'CLI-NOVACARE',
    'enterprise',
    'Access Bank',
    '0123456789',
    'Novacare Health Ltd Settlements',
    'daily',
    true,
    5000.00,
    1000.00,
    500.00,
    'flat',
    'merchant'
) ON CONFLICT (code) DO UPDATE SET
    custom_delivery_fee = 5000.00,
    custom_failed_attempt_fee = 1000.00,
    custom_platform_fee = 500.00;

-- 6.8 Default Client Telesales Closer
INSERT INTO public.client_closers (
    id, client_id, closer_code, full_name, email, phone, commission_rate, is_active
) VALUES (
    'cc111111-1111-4111-8111-111111111111',
    '00000000-0000-4000-8000-789382731303',
    'CLOSER-01',
    'Chioma Adebayo',
    'chioma@novacare.ng',
    '+2348099887766',
    500.00,
    true
) ON CONFLICT (closer_code) DO NOTHING;

-- 6.9 Products & Packages Catalog
INSERT INTO public.products (
    id, company_id, client_id, client_name, sku, name, category, description, base_price, stock_quantity, available_count, dc_stocks, is_active
) VALUES 
(
    'p1111111-1111-4111-8111-111111111111',
    '11111111-1111-4111-8111-111111111111',
    '00000000-0000-4000-8000-789382731303',
    'Novacare',
    'NOVA-HERB-01',
    'Novacare Organic Herbal Cleanse',
    'Wellness & Health',
    '100% natural organic body cleanse and detox elixir',
    15000.00,
    150,
    150,
    '{"22222222-2222-4222-8222-222222222222": 100, "00000000-0000-4000-8000-789382566045": 50}'::jsonb,
    true
),
(
    'p2222222-2222-4222-8222-222222222222',
    '11111111-1111-4111-8111-111111111111',
    '00000000-0000-4000-8000-789382731303',
    'Novacare',
    'NOVA-SUPP-02',
    'Novacare Vitality Capsules',
    'Dietary Supplements',
    'Daily wellness, stamina, and immune support multivitamins',
    22000.00,
    100,
    100,
    '{"22222222-2222-4222-8222-222222222222": 60, "00000000-0000-4000-8000-789382566045": 40}'::jsonb,
    true
) ON CONFLICT (sku) DO NOTHING;

INSERT INTO public.product_packages (
    id, product_id, product_name, product_sku, package_name, quantity, paid_quantity, free_quantity, package_price, client_id, client_name, description
) VALUES 
(
    'pkg11111-1111-4111-8111-111111111111',
    'p1111111-1111-4111-8111-111111111111',
    'Novacare Organic Herbal Cleanse',
    'NOVA-HERB-01',
    'Single Bottle Starter Pack',
    1, 1, 0,
    15000.00,
    '00000000-0000-4000-8000-789382731303',
    'Novacare',
    '1 bottle trial treatment'
),
(
    'pkg22222-2222-4222-8222-222222222222',
    'p1111111-1111-4111-8111-111111111111',
    'Novacare Organic Herbal Cleanse',
    'NOVA-HERB-01',
    'Promo Double Pack (Buy 2 Get 1 Free)',
    3, 2, 1,
    28000.00,
    '00000000-0000-4000-8000-789382731303',
    'Novacare',
    'Special discount pack: 2 paid bottles + 1 bonus free bottle'
) ON CONFLICT (id) DO NOTHING;

-- Initial Agent Custody Stock for Rider-001
INSERT INTO public.agent_inventory (delivery_agent_id, product_id, quantity)
VALUES 
    ('b1111111-1111-4111-8111-111111111111', 'p1111111-1111-4111-8111-111111111111', 10),
    ('b1111111-1111-4111-8111-111111111111', 'p2222222-2222-4222-8222-222222222222', 5)
ON CONFLICT (delivery_agent_id, product_id) DO NOTHING;

-- ============================================================================
-- 7. REALTIME SUBSCRIPTIONS & REPLICATION
-- ============================================================================
DO $$
BEGIN
    -- Set full replica identity for live stream change events
    ALTER TABLE IF EXISTS public.orders REPLICA IDENTITY FULL;
    ALTER TABLE IF EXISTS public.order_conversations REPLICA IDENTITY FULL;
    ALTER TABLE IF EXISTS public.order_conversation_messages REPLICA IDENTITY FULL;
    ALTER TABLE IF EXISTS public.notifications REPLICA IDENTITY FULL;
    ALTER TABLE IF EXISTS public.stock_transfers REPLICA IDENTITY FULL;
    ALTER TABLE IF EXISTS public.stock_requests REPLICA IDENTITY FULL;
    ALTER TABLE IF EXISTS public.agent_inventory REPLICA IDENTITY FULL;
    ALTER TABLE IF EXISTS public.product_packages REPLICA IDENTITY FULL;

    -- Add tables to supabase_realtime publication
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        BEGIN
            ALTER PUBLICATION supabase_realtime ADD TABLE 
                public.orders,
                public.order_conversations,
                public.order_conversation_messages,
                public.notifications,
                public.stock_transfers,
                public.stock_requests,
                public.agent_inventory,
                public.product_packages;
        EXCEPTION WHEN duplicate_object THEN
            NULL;
        END;
    END IF;
END $$;

-- ============================================================================
-- 8. REFRESH POSTGREST SCHEMA CACHE
-- Forces PostgREST to immediately recognize all tables and RPCs without delay
-- ============================================================================
NOTIFY pgrst, 'reload schema';

-- ============================================================================
-- SETUP COMPLETE: Backend is 100% operational and ready for NovaXpress clients
-- ============================================================================
