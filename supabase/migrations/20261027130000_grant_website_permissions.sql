-- Grant permissions to anon and authenticated roles for website tables
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

GRANT ALL ON public.website_settings TO anon, authenticated, service_role;
GRANT ALL ON public.website_services TO anon, authenticated, service_role;
GRANT ALL ON public.website_portfolio TO anon, authenticated, service_role;
GRANT ALL ON public.website_testimonials TO anon, authenticated, service_role;
GRANT ALL ON public.website_stats TO anon, authenticated, service_role;
GRANT ALL ON public.website_inquiries TO anon, authenticated, service_role;

-- Ensure RLS policies allow anon insert
DROP POLICY IF EXISTS "Public can submit inquiries" ON public.website_inquiries;
CREATE POLICY "Public can submit inquiries" ON public.website_inquiries
    FOR INSERT TO anon, authenticated, service_role WITH CHECK (true);

DROP POLICY IF EXISTS "Public can view website settings" ON public.website_settings;
CREATE POLICY "Public can view website settings" ON public.website_settings
    FOR SELECT TO anon, authenticated, service_role USING (true);

DROP POLICY IF EXISTS "Public can view active services" ON public.website_services;
CREATE POLICY "Public can view active services" ON public.website_services
    FOR SELECT TO anon, authenticated, service_role USING (true);

DROP POLICY IF EXISTS "Public can view active portfolio" ON public.website_portfolio;
CREATE POLICY "Public can view active portfolio" ON public.website_portfolio
    FOR SELECT TO anon, authenticated, service_role USING (true);

DROP POLICY IF EXISTS "Public can view active testimonials" ON public.website_testimonials;
CREATE POLICY "Public can view active testimonials" ON public.website_testimonials
    FOR SELECT TO anon, authenticated, service_role USING (true);

DROP POLICY IF EXISTS "Public can view website stats" ON public.website_stats;
CREATE POLICY "Public can view website stats" ON public.website_stats
    FOR SELECT TO anon, authenticated, service_role USING (true);
