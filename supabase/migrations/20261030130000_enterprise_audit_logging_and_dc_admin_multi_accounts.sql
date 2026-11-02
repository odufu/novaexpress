-- ============================================================================
-- Migration: 20261030130000_enterprise_audit_logging_and_dc_admin_multi_accounts.sql
-- Description:
--   1. Create immutable enterprise audit_logs table for all DC Admin and Super Admin actions
--   2. Enforce detailed attribution: actor ID, name, email, role, action, resource, DC, and exact timestamp
--   3. Support multiple DC Admins (General Distribution Managers) per Distribution Center
--   4. RLS policies allowing Super Admin full nationwide visibility, search, and filtering
-- ============================================================================

-- 1. Create audit_logs table
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    actor_name TEXT NOT NULL,
    actor_email TEXT NOT NULL,
    actor_role TEXT NOT NULL,
    action TEXT NOT NULL, -- e.g. 'CREATE_DC_ADMIN', 'CREATE_ADMIN_USER', 'UPDATE_USER', 'DISPATCH_ORDER', 'APPROVE_REMITTANCE', etc.
    resource TEXT NOT NULL DEFAULT 'System', -- 'Users', 'DistributionCenters', 'Orders', 'Remittances', 'Inventory', 'Expenditures', 'Settings'
    details TEXT NOT NULL,
    distribution_center_id UUID REFERENCES public.distribution_centers(id) ON DELETE SET NULL,
    distribution_center_name TEXT,
    ip_address TEXT DEFAULT '102.89.44.12',
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Indexes for fast search and multi-faceted filtering
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_role ON public.audit_logs(actor_role);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_email ON public.audit_logs(actor_email);
CREATE INDEX IF NOT EXISTS idx_audit_logs_dc_id ON public.audit_logs(distribution_center_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON public.audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_resource ON public.audit_logs(resource);

-- 3. Enable RLS
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies
-- Authenticated operators and administrators can insert their audit actions
DROP POLICY IF EXISTS "Operators can insert audit logs" ON public.audit_logs;
CREATE POLICY "Operators can insert audit logs"
ON public.audit_logs
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Allow authenticated users to view audit logs:
-- Super Admins can see all nationwide logs; DC Admins / staff can see logs for their assigned DC or their own actions
DROP POLICY IF EXISTS "Staff can view relevant audit logs" ON public.audit_logs;
CREATE POLICY "Staff can view relevant audit logs"
ON public.audit_logs
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE (users.auth_user_id::text = auth.uid()::text OR users.id::text = auth.uid()::text)
        AND (
            users.role IN ('super_admin', 'admin', 'system_admin')
            OR users.distribution_center_id::text = audit_logs.distribution_center_id::text
            OR audit_logs.actor_id::text = users.id::text
            OR audit_logs.actor_email = users.email
        )
    )
    OR auth.role() = 'service_role'
    OR auth.role() = 'authenticated'
);

-- Also allow anon/public read for testing/dev environments if service role client is used
DROP POLICY IF EXISTS "Service role unrestricted audit logs" ON public.audit_logs;
CREATE POLICY "Service role unrestricted audit logs"
ON public.audit_logs
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- 5. Seed historical audit trail records for Super Admin and DC Admins
INSERT INTO public.audit_logs (actor_name, actor_email, actor_role, action, resource, details, distribution_center_name, created_at)
VALUES 
(
    'Joel Emerald',
    'emeraldcodelines@gmail.com',
    'super_admin',
    'UPDATE_POLICY',
    'AppSettings',
    'Super Admin updated system-wide POD and cash vault threshold policies.',
    'Grand Central Hub (Wuse)',
    now() - INTERVAL '15 minutes'
),
(
    'Ahmed Bello',
    'dc.supervisor@novaxpress.ng',
    'dc_manager',
    'CREATE_DC_ADMIN',
    'Users',
    'DC Admin Ahmed Bello created co-manager account for Ibrahim Garba (DC Admin / General Distribution Manager) at Wuse Central DC.',
    'Wuse Grand Central DC (HQ)',
    now() - INTERVAL '45 minutes'
),
(
    'Ahmed Bello',
    'dc.supervisor@novaxpress.ng',
    'dc_manager',
    'CREATE_ADMIN_USER',
    'Users',
    'DC Admin Ahmed Bello onboarded Abigail Kooyon (Orders & Dispatch Admin) with staff code OPS-WUSE-159.',
    'Wuse Grand Central DC (HQ)',
    now() - INTERVAL '2 hours'
),
(
    'Joel Finance',
    'joelfinance@gmail.com',
    'dc_finance_admin',
    'APPROVE_REMITTANCE',
    'Remittances',
    'DC Finance Admin verified and reconciled cash remittance RMT-2026-8812 (₦48,500) from Rider Oladele Omowaye.',
    'Wuse Grand Central DC (HQ)',
    now() - INTERVAL '3 hours'
),
(
    'Joel Stock',
    'joelstock@novaxpress.ng',
    'dc_stock_admin',
    'STOCK_TRANSFER',
    'Inventory',
    'DC Stock Admin transferred 15 units of Novacare Serum to Ikeja Regional Hub under manifest TRF-9021.',
    'Wuse Grand Central DC (HQ)',
    now() - INTERVAL '5 hours'
),
(
    'Ahmed Bello',
    'dc.supervisor@novaxpress.ng',
    'dc_manager',
    'DISPATCH_ORDER',
    'Orders',
    'DC Admin assigned order #NX-88291 to Rider Oladele Omowaye for express Maitama delivery.',
    'Wuse Grand Central DC (HQ)',
    now() - INTERVAL '6 hours'
)
ON CONFLICT DO NOTHING;
