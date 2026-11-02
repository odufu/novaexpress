-- =========================================================================
-- NovaExpress Website Security Hardening & Storage RLS Policies
-- =========================================================================

-- 1. Restrict Table Grants for 'anon' Role
-- Ensure 'anon' can NEVER modify content tables or read other customers' inquiries
REVOKE ALL ON public.website_settings FROM anon;
REVOKE ALL ON public.website_services FROM anon;
REVOKE ALL ON public.website_portfolio FROM anon;
REVOKE ALL ON public.website_testimonials FROM anon;
REVOKE ALL ON public.website_stats FROM anon;
REVOKE ALL ON public.website_inquiries FROM anon;

-- Anon ONLY gets SELECT on public content
GRANT SELECT ON public.website_settings TO anon;
GRANT SELECT ON public.website_services TO anon;
GRANT SELECT ON public.website_portfolio TO anon;
GRANT SELECT ON public.website_testimonials TO anon;
GRANT SELECT ON public.website_stats TO anon;

-- Anon ONLY gets INSERT on website_inquiries (no select, no update, no delete!)
GRANT INSERT ON public.website_inquiries TO anon;

-- Authenticated and Service Role get full management rights
GRANT ALL ON public.website_settings TO authenticated, service_role;
GRANT ALL ON public.website_services TO authenticated, service_role;
GRANT ALL ON public.website_portfolio TO authenticated, service_role;
GRANT ALL ON public.website_testimonials TO authenticated, service_role;
GRANT ALL ON public.website_stats TO authenticated, service_role;
GRANT ALL ON public.website_inquiries TO authenticated, service_role;

-- 2. Clean and Reinforce Strict Row Level Security (RLS) Policies
ALTER TABLE public.website_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.website_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.website_portfolio ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.website_testimonials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.website_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.website_inquiries ENABLE ROW LEVEL SECURITY;

-- Reset policies
DROP POLICY IF EXISTS "Public can view website settings" ON public.website_settings;
DROP POLICY IF EXISTS "Public can view active services" ON public.website_services;
DROP POLICY IF EXISTS "Public can view active portfolio" ON public.website_portfolio;
DROP POLICY IF EXISTS "Public can view active testimonials" ON public.website_testimonials;
DROP POLICY IF EXISTS "Public can view website stats" ON public.website_stats;
DROP POLICY IF EXISTS "Public can submit inquiries" ON public.website_inquiries;
DROP POLICY IF EXISTS "Public read website inquiries" ON public.website_inquiries;

DROP POLICY IF EXISTS "Admin full access website settings" ON public.website_settings;
DROP POLICY IF EXISTS "Admin full access website services" ON public.website_services;
DROP POLICY IF EXISTS "Admin full access website portfolio" ON public.website_portfolio;
DROP POLICY IF EXISTS "Admin full access website testimonials" ON public.website_testimonials;
DROP POLICY IF EXISTS "Admin full access website stats" ON public.website_stats;
DROP POLICY IF EXISTS "Admin full access website inquiries" ON public.website_inquiries;

-- Public (Anon) Policies: Strictly READ-ONLY for website content
CREATE POLICY "Public can view website settings" ON public.website_settings
    FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "Public can view active services" ON public.website_services
    FOR SELECT TO anon, authenticated USING (is_active = true);

CREATE POLICY "Public can view active portfolio" ON public.website_portfolio
    FOR SELECT TO anon, authenticated USING (is_active = true);

CREATE POLICY "Public can view active testimonials" ON public.website_testimonials
    FOR SELECT TO anon, authenticated USING (is_active = true);

CREATE POLICY "Public can view website stats" ON public.website_stats
    FOR SELECT TO anon, authenticated USING (true);

-- Public (Anon) Policy on Inquiries: Blind INSERT only (Check against spam)
CREATE POLICY "Public can submit inquiries" ON public.website_inquiries
    FOR INSERT TO anon, authenticated WITH CHECK (
        length(trim(full_name)) > 0 AND 
        length(trim(email)) > 3 AND 
        length(trim(message)) > 0
    );

-- Authenticated (Admin) Policies: Full control
CREATE POLICY "Admin full access website settings" ON public.website_settings
    FOR ALL TO authenticated, service_role USING (true) WITH CHECK (true);

CREATE POLICY "Admin full access website services" ON public.website_services
    FOR ALL TO authenticated, service_role USING (true) WITH CHECK (true);

CREATE POLICY "Admin full access website portfolio" ON public.website_portfolio
    FOR ALL TO authenticated, service_role USING (true) WITH CHECK (true);

CREATE POLICY "Admin full access website testimonials" ON public.website_testimonials
    FOR ALL TO authenticated, service_role USING (true) WITH CHECK (true);

CREATE POLICY "Admin full access website stats" ON public.website_stats
    FOR ALL TO authenticated, service_role USING (true) WITH CHECK (true);

CREATE POLICY "Admin full access website inquiries" ON public.website_inquiries
    FOR ALL TO authenticated, service_role USING (true) WITH CHECK (true);

-- 3. Storage Policies for 'website-assets'
-- Enable public reading of images, but only authenticated users can upload/delete
DROP POLICY IF EXISTS "Public can view website assets" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated can upload website assets" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated can update website assets" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated can delete website assets" ON storage.objects;

CREATE POLICY "Public can view website assets" ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'website-assets');

CREATE POLICY "Authenticated can upload website assets" ON storage.objects
    FOR INSERT TO authenticated, service_role
    WITH CHECK (bucket_id = 'website-assets');

CREATE POLICY "Authenticated can update website assets" ON storage.objects
    FOR UPDATE TO authenticated, service_role
    USING (bucket_id = 'website-assets');

CREATE POLICY "Authenticated can delete website assets" ON storage.objects
    FOR DELETE TO authenticated, service_role
    USING (bucket_id = 'website-assets');
