-- ==============================================================================
-- NovaXpress Academy / E-Learning Management Schema
-- Role-Based Training, Quizzes, Progress Tracking & Cryptographic Certification
-- ==============================================================================

-- 1. LMS Courses Table (Mapped to Operational Roles)
CREATE TABLE IF NOT EXISTS public.lms_courses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_key TEXT UNIQUE NOT NULL,
    role_title TEXT NOT NULL,
    certification_name TEXT NOT NULL,
    description TEXT,
    badge_color TEXT DEFAULT '#F37021',
    icon_name TEXT DEFAULT 'Award',
    estimated_duration TEXT DEFAULT '2 Hours',
    is_published BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. LMS Modules Table (Objectives, Video, Transcript, Summary, Pass Score)
CREATE TABLE IF NOT EXISTS public.lms_modules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID NOT NULL REFERENCES public.lms_courses(id) ON DELETE CASCADE,
    module_order INT NOT NULL DEFAULT 1,
    title TEXT NOT NULL,
    objectives TEXT[] DEFAULT '{}',
    video_url TEXT,
    video_duration TEXT DEFAULT '15 mins',
    transcript TEXT,
    summary_markdown TEXT,
    passing_score INT DEFAULT 80,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. LMS Questions Table (Objective Multiple-Choice Examination)
CREATE TABLE IF NOT EXISTS public.lms_questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_id UUID NOT NULL REFERENCES public.lms_modules(id) ON DELETE CASCADE,
    question_order INT NOT NULL DEFAULT 1,
    question_text TEXT NOT NULL,
    options JSONB NOT NULL DEFAULT '[]'::jsonb, -- Array of strings e.g. ["Option A", "Option B", "Option C", "Option D"]
    correct_option_index INT NOT NULL DEFAULT 0,
    explanation TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. Trainee Progress Table
CREATE TABLE IF NOT EXISTS public.lms_trainee_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    user_email TEXT NOT NULL,
    user_name TEXT,
    module_id UUID NOT NULL REFERENCES public.lms_modules(id) ON DELETE CASCADE,
    is_video_completed BOOLEAN DEFAULT false,
    quiz_score INT DEFAULT 0,
    quiz_passed BOOLEAN DEFAULT false,
    quiz_attempts INT DEFAULT 0,
    completed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT uq_trainee_module UNIQUE (user_id, module_id)
);

-- 5. Certifications Registry (Verifiable Credentials with Unique Codes)
CREATE TABLE IF NOT EXISTS public.lms_certifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    certificate_code TEXT UNIQUE NOT NULL, -- e.g. NX-CERT-2026-X8921
    user_id UUID NOT NULL,
    user_email TEXT NOT NULL,
    recipient_name TEXT NOT NULL,
    role_key TEXT NOT NULL,
    certification_name TEXT NOT NULL,
    course_id UUID REFERENCES public.lms_courses(id),
    overall_score INT NOT NULL DEFAULT 100,
    issued_at TIMESTAMPTZ DEFAULT now(),
    is_valid BOOLEAN DEFAULT true,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS on all LMS tables
ALTER TABLE public.lms_courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lms_modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lms_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lms_trainee_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lms_certifications ENABLE ROW LEVEL SECURITY;

-- Read policies: Published courses and modules are viewable by any authenticated user and anon (for syllabus review)
CREATE POLICY "Public read published courses" ON public.lms_courses FOR SELECT USING (true);
CREATE POLICY "Public read modules" ON public.lms_modules FOR SELECT USING (true);
CREATE POLICY "Public read questions" ON public.lms_questions FOR SELECT USING (true);
CREATE POLICY "Public read certifications" ON public.lms_certifications FOR SELECT USING (true);

-- Progress policies: Users can view and update their own progress
CREATE POLICY "Users read own progress" ON public.lms_trainee_progress FOR SELECT USING (auth.uid() = user_id OR auth.role() = 'service_role');
CREATE POLICY "Users insert/update own progress" ON public.lms_trainee_progress FOR ALL USING (auth.uid() = user_id OR auth.role() = 'service_role');

-- Super Admin management policies: full access for authenticated super admins or service role
CREATE POLICY "Admins full manage courses" ON public.lms_courses FOR ALL USING (auth.role() = 'service_role' OR auth.jwt() ->> 'email' = 'emeraldcodelines@gmail.com');
CREATE POLICY "Admins full manage modules" ON public.lms_modules FOR ALL USING (auth.role() = 'service_role' OR auth.jwt() ->> 'email' = 'emeraldcodelines@gmail.com');
CREATE POLICY "Admins full manage questions" ON public.lms_questions FOR ALL USING (auth.role() = 'service_role' OR auth.jwt() ->> 'email' = 'emeraldcodelines@gmail.com');
CREATE POLICY "Admins full manage certs" ON public.lms_certifications FOR ALL USING (auth.role() = 'service_role' OR auth.jwt() ->> 'email' = 'emeraldcodelines@gmail.com');

-- Public Verification Function
CREATE OR REPLACE FUNCTION public.verify_lms_certificate(p_code TEXT)
RETURNS TABLE (
    certificate_code TEXT,
    recipient_name TEXT,
    certification_name TEXT,
    role_key TEXT,
    overall_score INT,
    issued_at TIMESTAMPTZ,
    is_valid BOOLEAN
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.certificate_code,
        c.recipient_name,
        c.certification_name,
        c.role_key,
        c.overall_score,
        c.issued_at,
        c.is_valid
    FROM public.lms_certifications c
    WHERE UPPER(c.certificate_code) = UPPER(TRIM(p_code));
END;
$$;

-- Seed the 7 Official NovaXpress Certification Courses
INSERT INTO public.lms_courses (role_key, role_title, certification_name, description, badge_color, icon_name, estimated_duration)
VALUES
    ('accountant', 'National General Accountant', 'Certified Accountant', 'Master national ledger reconciliation, bank settlement verification, COD escrow governance, and corporate payout protocols.', '#7C3AED', 'Calculator', '3 Hours'),
    ('dc_finance_admin', 'DC Finance Operations Officer', 'Certified Finance Operations', 'Master daily rider cash collection reconciliation, bank deposit vouchers, cash caps, and remittance dispute clearance.', '#D97706', 'Wallet', '2.5 Hours'),
    ('dc_stock_admin', 'DC Stock & Inventory Officer', 'Certified Inventory Manager', 'Master warehouse inbounds, barcode SKU bin allocations, inter-DC stock transfer handshakes, and damaged return auditing.', '#0284C7', 'Boxes', '2 Hours'),
    ('dc_operations', 'DC Dispatch & Hub Operations', 'Certified Dispatch Operations', 'Master regional order sorting, route clustering, rider parcel manifests, failed delivery escalations, and station SLAs.', '#059669', 'Truck', '2 Hours'),
    ('rider', 'Fleet Delivery Courier', 'Certified Mobile Operations', 'Master the Rider PDA app, customer doorstep OTP protocols, digital proof of delivery signatures, and cash collection security.', '#F37021', 'Smartphone', '1.5 Hours'),
    ('closer', 'Telesales Representative / Closer', 'Certified Sales Person', 'Master order verification calls, customer address normalization, upsell bundle negotiation, and delivery rescheduling.', '#4F46E5', 'Headphones', '2.5 Hours'),
    ('dc_manager', 'Distribution Center Master Manager', 'Certified Logistics Manager', 'Master overall hub capacity planning, personnel shift scheduling, vault balance verification, and station SLA compliance.', '#1E3A8A', 'ShieldCheck', '3.5 Hours')
ON CONFLICT (role_key) DO UPDATE SET
    role_title = EXCLUDED.role_title,
    certification_name = EXCLUDED.certification_name,
    description = EXCLUDED.description,
    badge_color = EXCLUDED.badge_color,
    icon_name = EXCLUDED.icon_name;

