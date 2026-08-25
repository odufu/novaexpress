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

