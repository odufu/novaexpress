# 01. Database Schema & Stored Procedures Specification

## 1. Migration Overview

The database layer serves as the single source of truth for all monetary transactions, fee deductions, and asset custody. All financial actions must be atomic, guarded by transactional integrity (`BEGIN ... COMMIT`), and enforce foreign key relations.

Migration File: `supabase/migrations/20260913190000_finance_settlement_and_payout_remediation.sql`

---

## 2. Table Enhancements & Column Definitions

### 2.1 Cash Remittances Table (`cash_remittances`)
Add missing column for failed delivery stipends deducted during remittance reconciliation:
```sql
ALTER TABLE IF EXISTS public.cash_remittances
    ADD COLUMN IF NOT EXISTS failed_stipends_deducted NUMERIC(14, 2) DEFAULT 0.00;
```

### 2.2 DC Finance Settings Table (`dc_finance_settings`)
Expand settings table with configurable client order charges and daily closeout rules:
```sql
ALTER TABLE IF EXISTS public.dc_finance_settings
    ADD COLUMN IF NOT EXISTS default_client_delivery_fee NUMERIC(14, 2) DEFAULT 3500.00,
    ADD COLUMN IF NOT EXISTS platform_fee_type TEXT DEFAULT 'flat', -- 'flat' or 'percent'
    ADD COLUMN IF NOT EXISTS platform_fee_value NUMERIC(14, 2) DEFAULT 500.00,
    ADD COLUMN IF NOT EXISTS paystack_fee_absorbed_by TEXT DEFAULT 'merchant', -- 'merchant', 'company', 'shared'
    ADD COLUMN IF NOT EXISTS failed_order_charge NUMERIC(14, 2) DEFAULT 500.00,
    ADD COLUMN IF NOT EXISTS daily_settlement_cutoff_time TEXT DEFAULT '22:00';
```

### 2.3 Clients / Merchants Table (`clients`)
Add merchant-specific fee overrides:
```sql
ALTER TABLE IF EXISTS public.clients
    ADD COLUMN IF NOT EXISTS custom_delivery_fee NUMERIC(14, 2),
    ADD COLUMN IF NOT EXISTS custom_platform_fee NUMERIC(14, 2),
    ADD COLUMN IF NOT EXISTS custom_failed_attempt_fee NUMERIC(14, 2);
```

### 2.4 Client Settlements Table (`client_settlements`)
Expand settlement ledger with itemized fee deductions and granular JSONB breakdown:
```sql
ALTER TABLE IF EXISTS public.client_settlements
    ADD COLUMN IF NOT EXISTS distribution_center_id UUID REFERENCES public.distribution_centers(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS platform_fees_deducted NUMERIC(14, 2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS gateway_fees_deducted NUMERIC(14, 2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS failed_attempt_fees_deducted NUMERIC(14, 2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS other_charges_deducted NUMERIC(14, 2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS charges_breakdown JSONB DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS idx_client_settlements_dc_id ON public.client_settlements(distribution_center_id);
```

---

## 3. Authoritative Stored Procedures

### 3.1 `decrement_driver_entitlement`
Safely decrements a rider's `direct_transfer_balance` upon DC approval of a payout claim.
```sql
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
    SET direct_transfer_balance = GREATEST(0.00, COALESCE(direct_transfer_balance, 0.00) - p_amount)
    WHERE id = p_driver_id;
END;
$$;
```

### 3.2 `fn_approve_cash_remittance`
Atomically clears rider COD debt, verifies remittance record, updates linked orders, and generates audit entries.
```sql
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
    v_new_cod_balance NUMERIC;
BEGIN
    -- 1. Fetch remittance
    SELECT * INTO v_rem
    FROM public.cash_remittances
    WHERE id = p_remittance_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Remittance record not found');
    END IF;

    -- 2. Mark verified
    UPDATE public.cash_remittances
    SET 
        status = 'verified',
        is_verified = true,
        verified_by_user_id = p_supervisor_id,
        verified_at = NOW(),
        updated_at = NOW()
    WHERE id = p_remittance_id;

    -- 3. Atomically decrement rider COD balance by the remitted amount
    UPDATE public.delivery_agents
    SET current_cod_balance = GREATEST(0.00, COALESCE(current_cod_balance, 0.00) - v_rem.amount)
    WHERE id = v_rem.delivery_agent_id
    RETURNING current_cod_balance INTO v_new_cod_balance;

    -- 4. Mark all associated orders as 'remitted'
    UPDATE public.orders
    SET 
        payment_status = 'collected',
        remittance_status = 'remitted',
        updated_at = NOW()
    WHERE id IN (
        SELECT order_id FROM public.remittance_orders WHERE cash_remittance_id = p_remittance_id
    );

    RETURN jsonb_build_object(
        'success', true,
        'remittance_id', p_remittance_id,
        'new_cod_balance', v_new_cod_balance,
        'message', 'Remittance approved and rider COD balance liquidated successfully.'
    );
END;
$$;
```

### 3.3 `fn_generate_merchant_daily_settlement`
Executes the **Daily 10:00 PM Merchant Settlement Closeout**:
1. Identifies all orders delivered for the client where `financial_settlement_status != 'client_settled'`.
2. Computes total gross collections.
3. Retrieves active billing configuration (client overrides if set, otherwise DC finance settings).
4. Calculates itemized deductions (Delivery Fees, Platform Fees, Paystack Gateway Fees, Failed Attempt Charges, and Other Charges).
5. Generates a unique settlement number `SETTLE-YYYY-MM-DD-XXXX`.
6. Inserts the `client_settlements` record.
7. Locks all settled orders by updating `remittance_status = 'remitted'`, `financial_settlement_status = 'client_settled'`, `remittance_reference = settlement_number`.
8. Returns a comprehensive JSON summary.

```sql
CREATE OR REPLACE FUNCTION public.fn_generate_merchant_daily_settlement(
    p_client_id UUID,
    p_dc_id UUID,
    p_period_start TIMESTAMPTZ,
    p_period_end TIMESTAMPTZ,
    p_custom_deductions JSONB DEFAULT '{}'::jsonb
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
    v_orders_count INT := 0;
    v_gross_collections NUMERIC(14, 2) := 0.00;
    v_delivery_fees NUMERIC(14, 2) := 0.00;
    v_platform_fees NUMERIC(14, 2) := 0.00;
    v_gateway_fees NUMERIC(14, 2) := 0.00;
    v_failed_attempt_fees NUMERIC(14, 2) := 0.00;
    v_other_charges NUMERIC(14, 2) := 0.00;
    v_total_deductions NUMERIC(14, 2) := 0.00;
    v_net_payout NUMERIC(14, 2) := 0.00;
    v_order RECORD;
    v_order_delivery_fee NUMERIC(14, 2);
    v_order_platform_fee NUMERIC(14, 2);
    v_order_gateway_fee NUMERIC(14, 2);
    v_charges_breakdown JSONB;
BEGIN
    -- 1. Fetch Client Profile & Bank Account
    SELECT * INTO v_client FROM public.clients WHERE id = p_client_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Client not found');
    END IF;

    -- 2. Fetch Active DC Finance Settings
    SELECT * INTO v_dc_settings FROM public.dc_finance_settings 
    WHERE id = 'global_finance_config' OR distribution_center_id = p_dc_id::text
    ORDER BY created_at DESC LIMIT 1;

    -- Generate Unique Settlement Reference
    v_settlement_number := 'SETTLE-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || SUBSTRING(v_settlement_id::text, 1, 6);

    -- 3. Aggregate delivered eligible orders
    FOR v_order IN 
        SELECT id, order_number, total_amount, payment_type, payment_method, client_delivery_fee
        FROM public.orders
        WHERE client_id = p_client_id
          AND status = 'delivered'
          AND (financial_settlement_status IS NULL OR financial_settlement_status != 'client_settled')
          AND delivered_at >= p_period_start
          AND delivered_at <= p_period_end
    LOOP
        v_orders_count := v_orders_count + 1;
        v_gross_collections := v_gross_collections + COALESCE(v_order.total_amount, 0.00);

        -- A. Determine Delivery Fee (Client override > Order specific fee > DC setting default)
        v_order_delivery_fee := COALESCE(v_client.custom_delivery_fee, v_order.client_delivery_fee, v_dc_settings.default_client_delivery_fee, 3500.00);
        v_delivery_fees := v_delivery_fees + v_order_delivery_fee;

        -- B. Determine Platform Fee
        IF COALESCE(v_client.custom_platform_fee, 0) > 0 THEN
            v_order_platform_fee := v_client.custom_platform_fee;
        ELSIF v_dc_settings.platform_fee_type = 'percent' THEN
            v_order_platform_fee := (COALESCE(v_order.total_amount, 0.00) * (COALESCE(v_dc_settings.platform_fee_value, 2.5) / 100.0));
        ELSE
            v_order_platform_fee := COALESCE(v_dc_settings.platform_fee_value, 500.00);
        END IF;
        v_platform_fees := v_platform_fees + v_order_platform_fee;

        -- C. Determine Gateway Processing Fee for Direct Transfer / Paystack
        IF v_order.payment_method = 'paystack' OR v_order.payment_type = 'prepaid' THEN
            IF COALESCE(v_dc_settings.paystack_fee_absorbed_by, 'merchant') = 'merchant' THEN
                -- 1.5% + NGN 100 capped at NGN 2000
                v_order_gateway_fee := LEAST(2000.00, (COALESCE(v_order.total_amount, 0.00) * 0.015) + 100.00);
                v_gateway_fees := v_gateway_fees + v_order_gateway_fee;
            END IF;
        END IF;
    END LOOP;

    -- 4. Check for Failed Order Charges (if client covers attempts)
    IF COALESCE(v_client.custom_failed_attempt_fee, v_dc_settings.failed_order_charge, 0) > 0 THEN
        SELECT COALESCE(COUNT(*), 0) * COALESCE(v_client.custom_failed_attempt_fee, v_dc_settings.failed_order_charge, 500.00)
        INTO v_failed_attempt_fees
        FROM public.orders
        WHERE client_id = p_client_id
          AND status IN ('cancelled', 'failed')
          AND updated_at >= p_period_start
          AND updated_at <= p_period_end;
    END IF;

    -- 5. Process Custom Extra Deductions
    IF p_custom_deductions ? 'other_charges' THEN
        v_other_charges := (p_custom_deductions->>'other_charges')::numeric;
    END IF;

    v_total_deductions := v_delivery_fees + v_platform_fees + v_gateway_fees + v_failed_attempt_fees + v_other_charges;
    v_net_payout := GREATEST(0.00, v_gross_collections - v_total_deductions);

    -- 6. Construct JSONB breakdown
    v_charges_breakdown := jsonb_build_object(
        'delivery_fees', v_delivery_fees,
        'platform_fees', v_platform_fees,
        'gateway_fees', v_gateway_fees,
        'failed_attempt_fees', v_failed_attempt_fees,
        'other_charges', v_other_charges,
        'total_deductions', v_total_deductions,
        'rate_basis', jsonb_build_object(
            'delivery_fee_per_order', COALESCE(v_client.custom_delivery_fee, v_dc_settings.default_client_delivery_fee, 3500.00),
            'platform_fee_rule', COALESCE(v_dc_settings.platform_fee_type, 'flat')
        )
    );

    -- 7. Insert into client_settlements
    INSERT INTO public.client_settlements (
        id,
        settlement_number,
        client_id,
        distribution_center_id,
        period_start,
        period_end,
        total_orders_count,
        gross_collections,
        logistics_fees_deducted,
        platform_fees_deducted,
        gateway_fees_deducted,
        failed_attempt_fees_deducted,
        other_charges_deducted,
        charges_breakdown,
        net_payout_amount,
        destination_bank_name,
        destination_account_number,
        destination_account_name,
        status,
        notes,
        settled_at,
        created_at
    ) VALUES (
        v_settlement_id,
        v_settlement_number,
        p_client_id,
        p_dc_id,
        p_period_start,
        p_period_end,
        v_orders_count,
        v_gross_collections,
        v_delivery_fees,
        v_platform_fees,
        v_gateway_fees,
        v_failed_attempt_fees,
        v_other_charges,
        v_charges_breakdown,
        v_net_payout,
        COALESCE(v_client.bank_name, 'Zenith Bank'),
        COALESCE(v_client.account_number, '1012345678'),
        COALESCE(v_client.account_name, v_client.company_name),
        'completed',
        'Daily 10:00 PM Merchant Settlement Closeout executed by Grand DC Clearinghouse',
        NOW(),
        NOW()
    );

    -- 8. Lock settled orders
    UPDATE public.orders
    SET 
        remittance_status = 'remitted',
        financial_settlement_status = 'client_settled',
        remittance_reference = v_settlement_number,
        updated_at = NOW()
    WHERE client_id = p_client_id
      AND status = 'delivered'
      AND (financial_settlement_status IS NULL OR financial_settlement_status != 'client_settled')
      AND delivered_at >= p_period_start
      AND delivered_at <= p_period_end;

    RETURN jsonb_build_object(
        'success', true,
        'settlement_id', v_settlement_id,
        'settlement_number', v_settlement_number,
        'orders_settled', v_orders_count,
        'gross_collections', v_gross_collections,
        'total_deductions', v_total_deductions,
        'net_payout', v_net_payout,
        'charges_breakdown', v_charges_breakdown
    );
END;
$$;
```

### 3.4 `fn_calculate_merchant_asset_custody`
Calculates total client holdings held in liquid cash vs in-kind inventory:
```sql
CREATE OR REPLACE FUNCTION public.fn_calculate_merchant_asset_custody(
    p_client_id UUID
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
    -- 1. Liquid Cash in Custody (Awaiting 10 PM Closeout)
    SELECT 
        COALESCE(SUM(CASE WHEN payment_method = 'paystack' OR payment_type = 'prepaid' THEN (total_amount - COALESCE(client_delivery_fee, 3500.00)) ELSE 0 END), 0.00),
        COALESCE(SUM(CASE WHEN payment_method = 'cash' AND payment_type = 'pay_on_delivery' THEN (total_amount - COALESCE(client_delivery_fee, 3500.00)) ELSE 0 END), 0.00)
    INTO v_cash_in_paystack, v_cash_in_dc_vault
    FROM public.orders
    WHERE client_id = p_client_id
      AND status = 'delivered'
      AND (financial_settlement_status IS NULL OR financial_settlement_status != 'client_settled');

    v_total_liquid_cash := v_cash_in_paystack + v_cash_in_dc_vault;

    -- 2. In-Kind Inventory Custody & Dual Valuation
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

            -- Calculate historical realized unit price factoring in package deals
            SELECT COALESCE(AVG(total_amount / NULLIF(quantity, 0)), v_prod.base_price, 25000.00)
            INTO v_avg_price
            FROM public.orders
            WHERE client_id = p_client_id AND product_name = v_prod.name AND status = 'delivered';

            v_weighted_retail_valuation := v_weighted_retail_valuation + (v_units * v_avg_price);
        END;
    END LOOP;

    RETURN jsonb_build_object(
        'client_id', p_client_id,
        'liquid_cash_in_escrow', v_total_liquid_cash,
        'cash_breakdown', jsonb_build_object(
            'paystack_direct_escrow', v_cash_in_paystack,
            'dc_vault_collections', v_cash_in_dc_vault
        ),
        'in_kind_inventory', jsonb_build_object(
            'total_units', v_total_units_in_custody,
            'base_liquidation_value', v_base_inventory_valuation,
            'estimated_retail_valuation_range', jsonb_build_object(
                'min_value', v_base_inventory_valuation,
                'expected_package_value', v_weighted_retail_valuation
            )
        )
    );
END;
$$;
```
