-- ============================================================================
-- NOVAXPRESS LOGISTICS PLATFORM
-- Migration: 20260920170000_link_products_to_suppliers.sql
-- Description:
--   1. Adds preferred_supplier_id foreign key column to products.
--   2. Automatically links products to existing active suppliers.
-- ============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'products' AND column_name = 'preferred_supplier_id'
    ) THEN
        ALTER TABLE public.products 
        ADD COLUMN preferred_supplier_id UUID REFERENCES public.client_suppliers(id) ON DELETE SET NULL;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_products_preferred_supplier ON public.products(preferred_supplier_id);

-- Auto-link Novacare products to Apex Herbal Laboratories Ltd where matching
UPDATE public.products p
SET preferred_supplier_id = s.id
FROM public.client_suppliers s
WHERE (s.supplier_name ILIKE '%Apex%' OR s.supplied_products @> ARRAY[p.name] OR s.supplied_products @> ARRAY[p.sku])
  AND p.preferred_supplier_id IS NULL;
