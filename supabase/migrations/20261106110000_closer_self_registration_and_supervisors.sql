-- ============================================================================
-- NOVAXPRESS LOGISTICS PLATFORM - CLOSER SELF-REGISTRATION & SUPERVISORY HIERARCHY
-- Migration for:
--   1. Closer self-registration support with approval status ('pending', 'approved', 'rejected')
--   2. Closer supervisor designation and supervisee linkage
--   3. Default compensation: 80,000 NGN base salary & 350 NGN delivered order commission
--   4. Automatic UPG request routing to assigned supervisor
-- ============================================================================

-- 1. Extend client_closers table
ALTER TABLE client_closers
  ADD COLUMN IF NOT EXISTS is_supervisor BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS supervisor_id UUID,
  ADD COLUMN IF NOT EXISTS supervisor_name TEXT,
  ADD COLUMN IF NOT EXISTS base_salary NUMERIC(12,2) DEFAULT 80000.00,
  ADD COLUMN IF NOT EXISTS approval_status TEXT DEFAULT 'approved';

-- Set default commission_rate default constraint if needed
ALTER TABLE client_closers
  ALTER COLUMN commission_rate SET DEFAULT 350.00;

-- Indexes for supervisor hierarchy and approval queue
CREATE INDEX IF NOT EXISTS idx_client_closers_supervisor_id ON client_closers(supervisor_id);
CREATE INDEX IF NOT EXISTS idx_client_closers_approval_status ON client_closers(approval_status);
CREATE INDEX IF NOT EXISTS idx_client_closers_is_supervisor ON client_closers(is_supervisor);

-- Comment metadata
COMMENT ON COLUMN client_closers.is_supervisor IS 'Indicates if the closer is a sales supervisor authorized to approve UPG requests and oversee assigned closers';
COMMENT ON COLUMN client_closers.supervisor_id IS 'ID of the assigned supervisor closer overseeing this call representative';
COMMENT ON COLUMN client_closers.approval_status IS 'Status of closer onboarding: pending (self-registered awaiting merchant authorization), approved, or rejected';
COMMENT ON COLUMN client_closers.base_salary IS 'Monthly base starter salary in Naira (default 80k NGN, editable by merchant)';

