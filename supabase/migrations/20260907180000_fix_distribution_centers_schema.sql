-- Fix distribution_centers schema to support enterprise supervisor, hierarchy and manager metadata
ALTER TABLE public.distribution_centers
  ADD COLUMN IF NOT EXISTS manager_name TEXT,
  ADD COLUMN IF NOT EXISTS parent_dc_id UUID REFERENCES public.distribution_centers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS is_primary_dc BOOLEAN DEFAULT false;

-- Ensure products has stock_quantity column for initial inventory on creation
ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS stock_quantity INTEGER DEFAULT 0;

-- Notify PostgREST to reload schema cache
NOTIFY pgrst, 'reload schema';
