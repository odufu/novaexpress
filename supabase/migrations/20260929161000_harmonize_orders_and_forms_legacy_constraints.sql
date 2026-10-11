-- ============================================================================
-- Migration: 20260929161000_harmonize_orders_and_forms_legacy_constraints.sql
-- Description: Drop legacy restricted CHECK and FK constraints on orders and lead_forms
--              that conflicted with modern marketing suite, closer confirmation status,
--              and client_marketers linkage.
-- ============================================================================

-- 1. Remove outdated constraints on orders
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_status_check;
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_payment_status_check;
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_marketer_id_fkey;

-- Re-link orders.marketer_id to client_marketers
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'orders_client_marketer_id_fkey'
    ) THEN
        ALTER TABLE public.orders 
            ADD CONSTRAINT orders_client_marketer_id_fkey 
            FOREIGN KEY (marketer_id) REFERENCES public.client_marketers(id) ON DELETE SET NULL;
    END IF;
END $$;

-- 2. Ensure customer_leads.marketer_id references client_marketers
ALTER TABLE public.customer_leads DROP CONSTRAINT IF EXISTS customer_leads_marketer_id_fkey;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'customer_leads_client_marketer_id_fkey'
    ) THEN
        ALTER TABLE public.customer_leads 
            ADD CONSTRAINT customer_leads_client_marketer_id_fkey 
            FOREIGN KEY (marketer_id) REFERENCES public.client_marketers(id) ON DELETE SET NULL;
    END IF;
END $$;

-- 3. Lead forms: Drop NOT NULL on legacy columns to allow modern forms insertion
DO $$
DECLARE
    legacy_cols TEXT[] := ARRAY[
        'title', 'company_id', 'status', 'digital_marketer_email', 
        'success_message', 'submit_button_text', 'product_category',
        'resolved_brand', 'resolved_cost_center', 'quantity_display_mode',
        'preset_country'
    ];
    c TEXT;
BEGIN
    FOREACH c IN ARRAY legacy_cols
    LOOP
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
              AND table_name = 'lead_forms' 
              AND column_name = c
        ) THEN
            EXECUTE 'ALTER TABLE public.lead_forms ALTER COLUMN ' || quote_ident(c) || ' DROP NOT NULL;';
        END IF;
    END LOOP;
END $$;

-- 4. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
