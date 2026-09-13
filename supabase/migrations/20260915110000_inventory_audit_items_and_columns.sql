-- Migration: 20260915110000_inventory_audit_items_and_columns.sql
-- Description: Create inventory_audit_items table, make distribution_center_id nullable on inventory_audits for mobile rider vehicle audits, and add audit metadata columns.

-- 1. Alter inventory_audits to support rider vehicle custody audits and metadata
ALTER TABLE IF EXISTS public.inventory_audits
    ALTER COLUMN distribution_center_id DROP NOT NULL;

ALTER TABLE IF EXISTS public.inventory_audits
    ADD COLUMN IF NOT EXISTS company_id UUID REFERENCES public.companies(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS audit_type TEXT DEFAULT 'dc_warehouse';

CREATE INDEX IF NOT EXISTS idx_inventory_audits_agent ON public.inventory_audits(delivery_agent_id);
CREATE INDEX IF NOT EXISTS idx_inventory_audits_dc ON public.inventory_audits(distribution_center_id);
CREATE INDEX IF NOT EXISTS idx_inventory_audits_status ON public.inventory_audits(status);

-- 2. Create inventory_audit_items table for line-item audit counts & variance tracking
CREATE TABLE IF NOT EXISTS public.inventory_audit_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    audit_id UUID NOT NULL REFERENCES public.inventory_audits(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    expected_quantity INT NOT NULL DEFAULT 0,
    actual_quantity INT NOT NULL DEFAULT 0,
    variance INT NOT NULL DEFAULT 0,
    variance_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_inventory_audit_items_audit_id ON public.inventory_audit_items(audit_id);
CREATE INDEX IF NOT EXISTS idx_inventory_audit_items_product_id ON public.inventory_audit_items(product_id);

-- 3. Permissions & Policies
ALTER TABLE public.inventory_audit_items ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'inventory_audit_items' AND policyname = 'Allow all authenticated users access to inventory_audit_items'
    ) THEN
        CREATE POLICY "Allow all authenticated users access to inventory_audit_items"
            ON public.inventory_audit_items FOR ALL TO authenticated USING (true) WITH CHECK (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'inventory_audit_items' AND policyname = 'Allow service_role full access to inventory_audit_items'
    ) THEN
        CREATE POLICY "Allow service_role full access to inventory_audit_items"
            ON public.inventory_audit_items FOR ALL TO service_role USING (true) WITH CHECK (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'inventory_audit_items' AND policyname = 'Allow anon access to inventory_audit_items'
    ) THEN
        CREATE POLICY "Allow anon access to inventory_audit_items"
            ON public.inventory_audit_items FOR ALL TO anon USING (true) WITH CHECK (true);
    END IF;
END $$;
