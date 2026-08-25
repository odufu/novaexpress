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

