-- Migration: Inspect Constraints and Fix PostgREST Schema Cache
CREATE OR REPLACE FUNCTION public.fn_debug_get_table_constraints(p_table TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_res JSONB;
BEGIN
    SELECT jsonb_agg(jsonb_build_object(
        'conname', conname,
        'contype', contype,
        'definition', pg_get_constraintdef(c.oid)
    )) INTO v_res
    FROM pg_constraint c
    JOIN pg_namespace n ON n.oid = c.connamespace
    JOIN pg_class cl ON cl.oid = c.conrelid
    WHERE n.nspname = 'public' AND cl.relname = p_table;
    RETURN COALESCE(v_res, '[]'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_debug_get_table_constraints(TEXT) TO anon, authenticated, service_role;

-- Ensure missing columns on operational tables exist
ALTER TABLE IF EXISTS public.delivery_agents
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE IF EXISTS public.stock_transfers
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE IF EXISTS public.stock_transfer_items
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Lead forms: make legacy non-null columns nullable so modern lead forms insert cleanly
DO $$
DECLARE
    col RECORD;
BEGIN
    FOR col IN 
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'lead_forms' 
          AND is_nullable = 'NO'
          AND column_name NOT IN ('id', 'product_id', 'product_name', 'form_title', 'packages', 'client_id')
    LOOP
        EXECUTE 'ALTER TABLE public.lead_forms ALTER COLUMN ' || quote_ident(col.column_name) || ' DROP NOT NULL;';
    END LOOP;
END $$;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
