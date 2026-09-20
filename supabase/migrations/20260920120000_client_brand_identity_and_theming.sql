-- ============================================================================
-- Migration: 20260920120000_client_brand_identity_and_theming.sql
-- Description: Adds Merchant Brand Identity & Dynamic Theming fields to clients
--              table (logo, primary, secondary, accent colors, theme JSONB).
-- ============================================================================

ALTER TABLE public.clients
  ADD COLUMN IF NOT EXISTS logo_url TEXT,
  ADD COLUMN IF NOT EXISTS brand_color_primary TEXT DEFAULT '#0D9488',
  ADD COLUMN IF NOT EXISTS brand_color_secondary TEXT DEFAULT '#1E293B',
  ADD COLUMN IF NOT EXISTS brand_color_accent TEXT DEFAULT '#F59E0B',
  ADD COLUMN IF NOT EXISTS brand_theme JSONB DEFAULT '{"primary": "#0D9488", "secondary": "#1E293B", "accent": "#F59E0B"}'::jsonb;

-- Backfill or update Novacare Ltd with signature wellness emerald green brand theme
UPDATE public.clients
SET 
  logo_url = COALESCE(logo_url, 'https://cdn-icons-png.flaticon.com/512/2966/2966327.png'),
  brand_color_primary = COALESCE(brand_color_primary, '#0D9488'),
  brand_color_secondary = COALESCE(brand_color_secondary, '#031632'),
  brand_color_accent = COALESCE(brand_color_accent, '#10B981'),
  brand_theme = jsonb_build_object(
    'primary', COALESCE(brand_color_primary, '#0D9488'),
    'secondary', COALESCE(brand_color_secondary, '#031632'),
    'accent', COALESCE(brand_color_accent, '#10B981'),
    'preset_name', 'Novacare Emerald'
  )
WHERE company_name ILIKE '%novacare%' OR company_name ILIKE '%novacale%';
