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
