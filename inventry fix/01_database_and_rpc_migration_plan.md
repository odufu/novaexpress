# Phase 1: Database Schema & Stored Procedure Migration Plan

**Document Path:** `c:\PROJECT\NoveXPS\inventry fix\01_database_and_rpc_migration_plan.md`  
**Target Migration File:** `supabase/migrations/20260915100000_inventory_ledger_remediation.sql`  
**Execution Environment:** Supabase Cloud PostgreSQL 15  

---

## 1. Problem Statement & Root Cause Analysis

1. **Double Stock Deduction**: `products.stock_quantity` is decremented twice for every delivery: first when issued to the rider by `fn_issue_dc_stock_to_rider`, and second by `confirm-delivery-pod`.
2. **Missing `dc_stocks` Synchronization**: When `fn_receive_client_supply` is called, it increments `products.stock_quantity` globally, but leaves `products.dc_stocks` untouched. Likewise, `fn_issue_dc_stock_to_rider` does not decrement `products.dc_stocks`.
3. **Orphaned `agent_inventory`**: `agent_inventory` is populated when riders accept stock, but is never decremented when orders are delivered or returned.
4. **Missing Return Receipt Procedure**: There is no stored procedure to process a rider stock return at the DC, meaning returned stock never re-enters warehouse inventory.
5. **Hardcoded Fallbacks**: `fn_calculate_merchant_asset_custody` has a hardcoded ₦25,000 price fallback on line 396.
6. **Missing Financial Accounting Columns**: The `products` table lacks wholesale cost (`cost_price`), product weight (`weight_kg`), and barcode.

---

## 2. Proposed Schema DDL Changes

The migration script will execute the following DDL updates:

```sql
-- 1. Extend products table for financial accounting and physical specs
ALTER TABLE public.products
    ADD COLUMN IF NOT EXISTS cost_price NUMERIC(15,2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS barcode TEXT,
    ADD COLUMN IF NOT EXISTS weight_kg NUMERIC(8,3) DEFAULT 0.500,
    ADD COLUMN IF NOT EXISTS low_stock_threshold INT DEFAULT 10,
    ADD COLUMN IF NOT EXISTS damaged_count INT DEFAULT 0;

-- 2. Ensure index on products barcode and agent_inventory
CREATE INDEX IF NOT EXISTS idx_products_barcode ON public.products(barcode);
CREATE INDEX IF NOT EXISTS idx_agent_inventory_agent_prod ON public.agent_inventory(delivery_agent_id, product_id);

-- 3. Ensure stock_returns has destination_dc_id and condition fields
ALTER TABLE public.stock_returns
    ADD COLUMN IF NOT EXISTS destination_dc_id UUID REFERENCES public.distribution_centers(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS condition TEXT DEFAULT 'good' CHECK (condition IN ('good', 'damaged', 'expired', 'tampered')),
    ADD COLUMN IF NOT EXISTS received_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS received_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
```

---

## 3. Stored Procedure Remediation Specifications

### 3.1 Update `fn_receive_client_supply`
**Goal**: Atomically update both global `stock_quantity` and the specific DC's balance inside `products.dc_stocks`.

```sql
CREATE OR REPLACE FUNCTION public.fn_receive_client_supply(
    p_transfer_id UUID,
    p_receiver_id UUID,
    p_receiver_name TEXT,
    p_receiver_signature_url TEXT,
    p_verified_items JSONB, -- Array of {item_id, quantity_received, quantity_damaged, quantity_missing, notes}
    p_notes TEXT DEFAULT ''
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_trf RECORD;
    v_item JSONB;
    v_item_id UUID;
    v_qty_rec INT;
    v_qty_dam INT;
    v_qty_mis INT;
    v_item_row RECORD;
    v_has_disc BOOLEAN := FALSE;
    v_status TEXT := 'completed';
    v_dc_id TEXT;
BEGIN
    SELECT * INTO v_trf FROM public.stock_transfers WHERE id = p_transfer_id;
    IF v_trf IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Stock transfer not found');
    END IF;

    v_dc_id := COALESCE(v_trf.destination_dc_id::TEXT, '');

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_verified_items)
    LOOP
        v_item_id := (v_item->>'item_id')::UUID;
        v_qty_rec := COALESCE((v_item->>'quantity_received')::INT, 0);
        v_qty_dam := COALESCE((v_item->>'quantity_damaged')::INT, 0);
        v_qty_mis := COALESCE((v_item->>'quantity_missing')::INT, 0);

        SELECT * INTO v_item_row FROM public.stock_transfer_items WHERE id = v_item_id AND transfer_id = p_transfer_id;
        IF v_item_row IS NOT NULL THEN
            IF v_qty_dam > 0 OR v_qty_mis > 0 OR v_qty_rec != v_item_row.quantity_shipped THEN
                v_has_disc := TRUE;
            END IF;

            UPDATE public.stock_transfer_items
            SET quantity_received = v_qty_rec,
                quantity_damaged = v_qty_dam,
                quantity_missing = v_qty_mis,
                item_notes = COALESCE(v_item->>'notes', item_notes)
            WHERE id = v_item_id;

            -- Atomically increment global stock AND DC-specific JSONB stock
            IF v_qty_rec > 0 AND v_item_row.product_id IS NOT NULL THEN
                UPDATE public.products
                SET stock_quantity = COALESCE(stock_quantity, 0) + v_qty_rec,
                    dc_stocks = CASE 
                        WHEN v_dc_id <> '' THEN
                            jsonb_set(
                                COALESCE(dc_stocks, '{}'::jsonb),
                                ARRAY[v_dc_id],
                                to_jsonb(COALESCE((dc_stocks->>v_dc_id)::INT, 0) + v_qty_rec)
                            )
                        ELSE COALESCE(dc_stocks, '{}'::jsonb)
                    END,
                    updated_at = NOW()
                WHERE id = v_item_row.product_id;
            END IF;
        END IF;
    END LOOP;

    IF v_has_disc THEN
        v_status := 'discrepancy_reported';
    END IF;

    UPDATE public.stock_transfers
    SET status = v_status,
        receiver_id = p_receiver_id,
        receiver_name = p_receiver_name,
        receiver_role = 'dc_supervisor',
        receiver_signature_url = p_receiver_signature_url,
        received_at = NOW(),
        has_discrepancy = v_has_disc,
        discrepancy_notes = p_notes,
        updated_at = NOW()
    WHERE id = p_transfer_id;

    RETURN jsonb_build_object(
        'success', true,
        'transfer_id', p_transfer_id,
        'status', v_status
    );
END;
$$;
```

---

### 3.2 Update `fn_issue_dc_stock_to_rider`
**Goal**: Decrement both global `stock_quantity` and the issuing DC's balance inside `dc_stocks`.

```sql
CREATE OR REPLACE FUNCTION public.fn_issue_dc_stock_to_rider(
    p_dc_id UUID,
    p_rider_id UUID,
    p_items JSONB, -- Array of {product_id, quantity}
    p_sender_id UUID,
    p_sender_name TEXT,
    p_sender_signature_url TEXT,
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
    v_rider RECORD;
    v_wh_id UUID;
    v_dc_str TEXT;
BEGIN
    SELECT company_id INTO v_company_id FROM public.distribution_centers WHERE id = p_dc_id;
    IF v_company_id IS NULL THEN
        SELECT id INTO v_company_id FROM public.companies LIMIT 1;
    END IF;

    v_dc_str := p_dc_id::TEXT;

    SELECT * INTO v_rider FROM public.delivery_agents WHERE id = p_rider_id OR user_id = p_rider_id;
    IF v_rider IS NOT NULL THEN
        SELECT id INTO v_wh_id FROM public.warehouses WHERE rider_id = v_rider.id LIMIT 1;
    END IF;

    v_waybill := 'WB-RIDER-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');

    INSERT INTO public.stock_transfers (
        company_id,
        transfer_type,
        transfer_number,
        waybill_number,
        source_dc_id,
        destination_warehouse_id,
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
        v_wh_id,
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
            -- Decrement global stock and DC-specific balance
            UPDATE public.products
            SET stock_quantity = GREATEST(0, COALESCE(stock_quantity, 0) - v_qty),
                dc_stocks = jsonb_set(
                    COALESCE(dc_stocks, '{}'::jsonb),
                    ARRAY[v_dc_str],
                    to_jsonb(GREATEST(0, COALESCE((dc_stocks->>v_dc_str)::INT, 0) - v_qty))
                ),
                updated_at = NOW()
            WHERE id = v_prod_id;

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

    IF v_rider IS NOT NULL THEN
        INSERT INTO public.notifications (
            company_id,
            delivery_agent_id,
            title,
            message,
            category,
            action_route,
            is_read
        ) VALUES (
            v_company_id,
            v_rider.id,
            'New Stock Handover Awaiting Acceptance! 📦',
            'DC Supervisor ' || p_sender_name || ' issued stock to you (Waybill: ' || v_waybill || '). Please count and sign to accept custody.',
            'inventory',
            '/stock/handover/' || v_transfer_id,
            false
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'transfer_id', v_transfer_id,
        'waybill_number', v_waybill,
        'status', 'pending_rider_acceptance'
    );
END;
$$;
```

---

### 3.3 New Stored Procedure: `fn_confirm_order_delivery_stock`
**Goal**: Atomically update rider custody in `agent_inventory` and increment `products.delivered_count` **WITHOUT** decrementing `products.stock_quantity` again.

```sql
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
    v_agent_record RECORD;
BEGIN
    -- 1. Deduct physical units from rider custody in agent_inventory
    UPDATE public.agent_inventory
    SET available_count = GREATEST(0, COALESCE(available_count, 0) - v_qty),
        total_in_custody = GREATEST(0, COALESCE(total_in_custody, 0) - v_qty),
        delivered_count_today = COALESCE(delivered_count_today, 0) + v_qty,
        updated_at = NOW()
    WHERE delivery_agent_id = p_agent_id AND product_id = p_product_id;

    -- 2. Increment global delivered metrics on product
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
```

---

### 3.4 New Stored Procedure: `fn_receive_rider_stock_return`
**Goal**: Receive returned rider items back into DC inventory.

```sql
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
    v_dc_str TEXT;
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
    v_dc_str := p_dc_id::TEXT;

    -- 1. Deduct from rider's custody
    IF v_ret.delivery_agent_id IS NOT NULL AND v_ret.product_id IS NOT NULL THEN
        UPDATE public.agent_inventory
        SET total_in_custody = GREATEST(0, COALESCE(total_in_custody, 0) - v_qty),
            available_count = GREATEST(0, COALESCE(available_count, 0) - v_qty),
            returned_count = COALESCE(returned_count, 0) + v_qty,
            updated_at = NOW()
        WHERE delivery_agent_id = v_ret.delivery_agent_id AND product_id = v_ret.product_id;
    END IF;

    -- 2. Restock into DC shelf IF condition is 'good'
    IF p_condition = 'good' AND v_ret.product_id IS NOT NULL THEN
        UPDATE public.products
        SET stock_quantity = COALESCE(stock_quantity, 0) + v_qty,
            dc_stocks = jsonb_set(
                COALESCE(dc_stocks, '{}'::jsonb),
                ARRAY[v_dc_str],
                to_jsonb(COALESCE((dc_stocks->>v_dc_str)::INT, 0) + v_qty)
            ),
            updated_at = NOW()
        WHERE id = v_ret.product_id;
    ELSE
        -- Track as damaged
        IF v_ret.product_id IS NOT NULL THEN
            UPDATE public.products
            SET damaged_count = COALESCE(damaged_count, 0) + v_qty,
                updated_at = NOW()
            WHERE id = v_ret.product_id;
        END IF;
    END IF;

    -- 3. Update return record
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
        'restocked_quantity', CASE WHEN p_condition = 'good' THEN v_qty ELSE 0 END,
        'damaged_quantity', CASE WHEN p_condition != 'good' THEN v_qty ELSE 0 END
    );
END;
$$;
```

---

### 3.5 Clean Up Hardcoded ₦25,000 in `fn_calculate_merchant_asset_custody`
**Goal**: Remove fallback ₦25,000. Use actual `base_price` (or 0.00 if unset).

```sql
-- In fn_calculate_merchant_asset_custody:
-- Replace:
-- v_unit_val := COALESCE(v_prod.base_price, 25000.00);
-- With:
-- v_unit_val := COALESCE(v_prod.base_price, 0.00);
```

---

## 4. Verification & Testing Script

Run the following psql verification snippet to validate Phase 1:
```sql
DO $$
BEGIN
    ASSERT (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'cost_price') = 1, 'Missing cost_price';
    ASSERT (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'barcode') = 1, 'Missing barcode';
    ASSERT (SELECT COUNT(*) FROM pg_proc WHERE proname = 'fn_confirm_order_delivery_stock') = 1, 'Missing fn_confirm_order_delivery_stock';
    ASSERT (SELECT COUNT(*) FROM pg_proc WHERE proname = 'fn_receive_rider_stock_return') = 1, 'Missing fn_receive_rider_stock_return';
    RAISE NOTICE 'Phase 1 Database Verification PASSED!';
END;
$$;
```
