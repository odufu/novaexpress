-- ============================================================================
-- Migration: 20260928091500_harmonize_marketer_commission_and_stats.sql
-- Description:
--   1. Ensures client_marketers has both commission_type and commission_model
--      fully synchronized and accessible to client SDKs.
--   2. Ensures total_commission_earned column exists on client_marketers.
--   3. Synchronizes commission_type and commission_model via trigger.
-- ============================================================================

-- 1. Ensure columns exist on client_marketers
ALTER TABLE public.client_marketers
  ADD COLUMN IF NOT EXISTS commission_type VARCHAR(50) DEFAULT 'per_form_submission',
  ADD COLUMN IF NOT EXISTS commission_model VARCHAR(50) DEFAULT 'per_form_submission',
  ADD COLUMN IF NOT EXISTS total_commission_earned NUMERIC(14,2) DEFAULT 0.00;

-- 2. Populate and cross-fill existing records
UPDATE public.client_marketers
SET commission_type = COALESCE(commission_type, commission_model, 'per_form_submission'),
    commission_model = COALESCE(commission_model, commission_type, 'per_form_submission'),
    total_commission_earned = COALESCE(total_commission_earned, 0.00);

-- 3. Trigger to keep commission_type and commission_model automatically in sync
CREATE OR REPLACE FUNCTION public.fn_sync_client_marketer_commission_columns()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.commission_type IS NOT NULL AND NEW.commission_model IS NULL THEN
        NEW.commission_model := NEW.commission_type;
    ELSIF NEW.commission_model IS NOT NULL AND NEW.commission_type IS NULL THEN
        NEW.commission_type := NEW.commission_model;
    ELSIF NEW.commission_type IS NOT NULL AND NEW.commission_type IS DISTINCT FROM OLD.commission_type THEN
        NEW.commission_model := NEW.commission_type;
    ELSIF NEW.commission_model IS NOT NULL AND NEW.commission_model IS DISTINCT FROM OLD.commission_model THEN
        NEW.commission_type := NEW.commission_model;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_client_marketer_commission ON public.client_marketers;
CREATE TRIGGER trg_sync_client_marketer_commission
    BEFORE INSERT OR UPDATE ON public.client_marketers
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_sync_client_marketer_commission_columns();

-- 4. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
