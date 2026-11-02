-- =========================================================================
-- NovaExpress Dynamic Website & Portfolio Tables Migration
-- =========================================================================

-- 1. Website Settings (Global config, Hero section, Contact, Announcements)
CREATE TABLE IF NOT EXISTS public.website_settings (
    key TEXT PRIMARY KEY,
    brand_name TEXT NOT NULL DEFAULT 'NovaXpress Logistics',
    tagline TEXT DEFAULT 'Fast, Secure & Scalable Last-Mile Delivery Across Nigeria',
    hero_badge TEXT DEFAULT 'Next-Gen Express Logistics & Cold-Chain Network',
    hero_title TEXT DEFAULT 'Powering Nigeria’s Fastest Deliveries & Cash-on-Delivery Remittance',
    hero_subtitle TEXT DEFAULT 'From intra-city express dispatch to nationwide cold-chain pharma distribution, NovaXpress delivers unmatched reliability, speed, and real-time electronic proof of delivery.',
    hero_cta_primary_text TEXT DEFAULT 'Request a Delivery Quote',
    hero_cta_primary_link TEXT DEFAULT '/contact',
    hero_cta_secondary_text TEXT DEFAULT 'Track Shipment',
    hero_cta_secondary_link TEXT DEFAULT '/track',
    contact_phone TEXT DEFAULT '+234 812 345 6789',
    contact_email TEXT DEFAULT 'operations@novaxpress.ng',
    whatsapp_number TEXT DEFAULT '+2348123456789',
    headquarters_address TEXT DEFAULT 'NovaXpress Grand Central Hub, Ikeja Logistics Corridor, Lagos, Nigeria',
    operating_hours TEXT DEFAULT 'Mon - Sat: 7:00 AM - 9:00 PM | 24/7 Operations Support',
    announcement_text TEXT DEFAULT '✨ Expanded coverage: Same-day express dispatch now live in Lagos, Abuja, Port Harcourt, and Kano!',
    announcement_active BOOLEAN DEFAULT true,
    social_links JSONB DEFAULT '{"linkedin": "https://linkedin.com", "twitter": "https://x.com", "instagram": "https://instagram.com", "facebook": "https://facebook.com"}'::jsonb,
    meta_title TEXT DEFAULT 'NovaXpress | Fast, Reliable Logistics & Express Courier in Nigeria',
    meta_description TEXT DEFAULT 'NovaXpress provides high-speed last-mile delivery, refrigerated pharmaceutical cold chain, B2B inventory warehousing, and rapid COD remittance.',
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Website Services
CREATE TABLE IF NOT EXISTS public.website_services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    short_description TEXT NOT NULL,
    full_description TEXT,
    icon_name TEXT DEFAULT 'Truck',
    features JSONB DEFAULT '[]'::jsonb,
    sla_delivery_time TEXT DEFAULT 'Same Day Delivery',
    is_featured BOOLEAN DEFAULT true,
    is_active BOOLEAN DEFAULT true,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Website Portfolio / Case Studies
CREATE TABLE IF NOT EXISTS public.website_portfolio (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    client_name TEXT NOT NULL,
    category TEXT NOT NULL,
    summary TEXT NOT NULL,
    challenge TEXT,
    solution TEXT,
    results TEXT,
    metrics JSONB DEFAULT '[]'::jsonb,
    image_url TEXT,
    is_featured BOOLEAN DEFAULT true,
    is_active BOOLEAN DEFAULT true,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Website Testimonials
CREATE TABLE IF NOT EXISTS public.website_testimonials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_name TEXT NOT NULL,
    author_title TEXT DEFAULT 'Operations Director',
    company TEXT NOT NULL,
    quote TEXT NOT NULL,
    rating INTEGER DEFAULT 5,
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT true,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Website Stats / Impact Metrics
CREATE TABLE IF NOT EXISTS public.website_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    label TEXT NOT NULL,
    value TEXT NOT NULL,
    suffix TEXT DEFAULT '',
    description TEXT,
    icon_name TEXT DEFAULT 'Activity',
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Website Inquiries & Quote Requests
CREATE TABLE IF NOT EXISTS public.website_inquiries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT,
    company TEXT,
    service_type TEXT DEFAULT 'Express Delivery',
    destination_hub TEXT,
    estimated_volume TEXT,
    message TEXT NOT NULL,
    status TEXT DEFAULT 'NEW',
    admin_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on all tables
ALTER TABLE public.website_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.website_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.website_portfolio ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.website_testimonials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.website_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.website_inquiries ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Public can view website settings" ON public.website_settings;
DROP POLICY IF EXISTS "Public can view active services" ON public.website_services;
DROP POLICY IF EXISTS "Public can view active portfolio" ON public.website_portfolio;
DROP POLICY IF EXISTS "Public can view active testimonials" ON public.website_testimonials;
DROP POLICY IF EXISTS "Public can view website stats" ON public.website_stats;
DROP POLICY IF EXISTS "Public can submit inquiries" ON public.website_inquiries;

DROP POLICY IF EXISTS "Admin full access website settings" ON public.website_settings;
DROP POLICY IF EXISTS "Admin full access website services" ON public.website_services;
DROP POLICY IF EXISTS "Admin full access website portfolio" ON public.website_portfolio;
DROP POLICY IF EXISTS "Admin full access website testimonials" ON public.website_testimonials;
DROP POLICY IF EXISTS "Admin full access website stats" ON public.website_stats;
DROP POLICY IF EXISTS "Admin full access website inquiries" ON public.website_inquiries;

-- Public read policies
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

-- Public inquiry submission policy
CREATE POLICY "Public can submit inquiries" ON public.website_inquiries
    FOR INSERT TO anon, authenticated WITH CHECK (true);

-- Authenticated full access (or service_role)
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

-- =========================================================================
-- INITIAL SEED DATA
-- =========================================================================

-- Seed Website Settings
INSERT INTO public.website_settings (key, brand_name, tagline, hero_badge, hero_title, hero_subtitle, hero_cta_primary_text, hero_cta_primary_link, hero_cta_secondary_text, hero_cta_secondary_link, contact_phone, contact_email, whatsapp_number, headquarters_address, operating_hours, announcement_text, announcement_active)
VALUES (
    'general',
    'NovaXpress Logistics',
    'Next-Gen Delivery & Distribution Architecture',
    '🚀 Enterprise Courier, Cold Chain & COD Solutions',
    'The Modern Logistics Backbone for High-Growth African Commerce',
    'Eliminate delayed shipments and lost revenue. NovaXpress powers same-day intra-city delivery, secure multi-hub warehousing, certified cold chain, and instant cash-on-delivery remittance across Nigeria.',
    'Request a Delivery Quote',
    '/contact',
    'Track Your Package',
    '/track',
    '+234 812 345 6789',
    'operations@novaxpress.ng',
    '+2348123456789',
    'NovaXpress Grand DC, Ikeja Logistics Gateway, Lagos State, Nigeria',
    'Mon - Sat: 7:00 AM - 9:00 PM | 24/7 Operations Dispatch',
    '⚡ New Hubs Online: Express dispatch and next-day inter-state haulage now active in Lagos, Abuja, Port Harcourt, and Kano!',
    true
)
ON CONFLICT (key) DO UPDATE SET
    brand_name = EXCLUDED.brand_name,
    hero_title = EXCLUDED.hero_title,
    hero_subtitle = EXCLUDED.hero_subtitle,
    updated_at = NOW();

-- Seed Services
INSERT INTO public.website_services (slug, title, short_description, full_description, icon_name, features, sla_delivery_time, is_featured, is_active, display_order)
VALUES 
(
    'express-intra-city',
    'Intra-City Express Dispatch',
    'Fast, dedicated doorstep delivery across major metropolitan centers within hours.',
    'Our algorithmically routed rider fleet and distributed DC network guarantee speed, item security, and real-time electronic signature capture upon delivery.',
    'Zap',
    '["Under 4-hour intra-city dispatch", "Real-time rider GPS tracking", "Digital Proof of Delivery (POD) with photo & signature", "Reverse logistics & exchange handling"]'::jsonb,
    'Same-Day (2 - 4 Hours)',
    true,
    true,
    1
),
(
    'pharma-cold-chain',
    'Pharma & Cold-Chain Logistics',
    'Temperature-monitored refrigerated transport for pharmaceuticals, vaccines, and biologics.',
    'Certified temperature-controlled supply chain keeping critical medications, lab samples, and sensitive goods within optimal temperature ranges (2°C - 8°C & ambient controlled).',
    'ThermometerSnowflake',
    '["Continuous IoT temperature telemetry", "Insulated pharma-grade coolers & dry-ice packaging", "Regulatory compliance documentation", "Priority airport & inter-city corridors"]'::jsonb,
    '24 - 48 Hours Guaranteed',
    true,
    true,
    2
),
(
    'cod-remittance',
    'Cash on Delivery & Instant Remittance',
    'Secure cash & POS collection at doorstep with 24-hour bank account remittance.',
    'Boost customer trust and checkout conversion rates by offering Cash/POS on Delivery while enjoying automated reconciliation and direct deposit payouts to your business account.',
    'Banknote',
    '["T+1 fast automated bank remittance", "POS and Instant Mobile Transfer collection", "Automated daily settlement reporting", "Zero discrepancy cash reconciliation portal"]'::jsonb,
    'Daily 24h Payouts',
    true,
    true,
    3
),
(
    'b2b-warehousing',
    'Micro-Hub Warehousing & Fulfillment',
    'Strategic micro-fulfillment centers in prime consumption zones to minimize last-mile transit times.',
    'Store your fast-moving SKUs across our modern distribution centers. When orders land, we pick, pack, label, and dispatch immediately to your end consumers.',
    'Warehouse',
    '["Real-time cloud inventory visibility", "Pick, pack, and custom kitting services", "Batch and expiry date tracking", "Direct integration with Shopify, WooCommerce, & custom ERPs"]'::jsonb,
    'Instant Auto-Fulfillment',
    true,
    true,
    4
),
(
    'interstate-cargo',
    'Interstate Linehaul & Haulage',
    'Scheduled line-haul trunk routes connecting North, South, East, and Western distribution zones.',
    'Reliable interstate linehaul cargo services connecting key industrial corridors across all 36 states with end-to-end milestone tracking and dedicated insurance coverage.',
    'Truck',
    '["Daily scheduled trunk dispatches", "Full Truckload (FTL) and Less than Truckload (LTL)", "GPS tracking with geo-fence alarms", "Comprehensive transit cargo protection"]'::jsonb,
    '24 - 72 Hours Nationwide',
    true,
    true,
    5
),
(
    'reverse-logistics',
    'Smart Returns & Reverse Logistics',
    'Hassle-free return pickups, condition inspection, and restocking back to your warehouse.',
    'Turn returns into retained customers with frictionless return collection, quick inspection reports, and automated restock workflows.',
    'RotateCcw',
    '["Fast customer return pickup", "Quality & condition inspection checklist", "Automated restock synchronization", "Customer exchange deliveries"]'::jsonb,
    '24 - 48 Hours',
    false,
    true,
    6
)
ON CONFLICT (slug) DO NOTHING;

-- Seed Portfolio / Case Studies
INSERT INTO public.website_portfolio (slug, title, client_name, category, summary, challenge, solution, results, metrics, image_url, is_featured, is_active, display_order)
VALUES
(
    'novacare-nationwide-pharma',
    'Scaling Temperature-Controlled Pharma Distribution to 12 States',
    'Novacare Health & Pharmaceuticals',
    'Healthcare & Cold Chain',
    'How Novacare transformed patient access to temperature-sensitive injectables and medications with NovaXpress cold-chain logistics.',
    'Novacare was experiencing a 14% spoilage rate and high customer churn due to unpredictable inter-state transit times and temperature spikes during transit.',
    'NovaXpress implemented IoT-enabled temperature logging containers, established dedicated cold-storage zones at Lagos and Abuja distribution centers, and deployed specialized pharma riders.',
    'Reduced spoilage to 0.02%, reduced delivery turnaround from 72 hours to under 24 hours, and enabled Novacare to onboard over 150 new partner clinics.',
    '[{"label": "Spoilage Reduction", "value": "99.8%"}, {"label": "Delivery SLA", "value": "Under 24h"}, {"label": "Clinic Partners", "value": "150+"}, {"label": "Monthly Volume", "value": "18,500 units"}]'::jsonb,
    'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?auto=format&fit=crop&w=1200&q=80',
    true,
    true,
    1
),
(
    'comfortcare-d2c-fulfillment',
    'Achieving 99.2% Delivery Success with 24-Hour Cash on Delivery Remittance',
    'ComfortCare Wellness Brands',
    'D2C & Omnichannel E-commerce',
    'Scaling a high-volume direct-to-consumer health and beauty brand with automated COD reconciliation and local micro-warehousing.',
    'High order return rates (RTO exceeding 26%) due to delayed dispatch, manual cash reconciliation errors, and cash remittance lag taking up to 10 days.',
    'Integrated ComfortCare orders into NovaXpress automated micro-warehouses in Lagos and Port Harcourt with same-day dispatch and 24-hour automated bank remittance.',
    'Return rate dropped from 26% to under 5.4%, customer satisfaction surged to 4.9 stars, and ComfortCare scaled daily volume 4x without cash flow bottleneck.',
    '[{"label": "RTO Reduction", "value": "79%"}, {"label": "Remittance Cycle", "value": "24 Hours"}, {"label": "Delivery Rate", "value": "99.2%"}, {"label": "Daily Parcels", "value": "1,200+"}]'::jsonb,
    'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?auto=format&fit=crop&w=1200&q=80',
    true,
    true,
    2
),
(
    'pangea-b2b-supply-chain',
    'Cross-Docking and B2B Wholesale Distribution for Modern Retail Chains',
    'Pangea Retail Distribution Group',
    'B2B Wholesale & Linehaul',
    'Unifying inventory management and scheduled weekly replenishment for 45 supermarkets and retail outlets.',
    'Stockouts at store locations while regional warehouses were overstocked; high transport costs due to fragmented logistics vendors and lack of centralized proof of delivery.',
    'NovaXpress deployed centralized cross-docking, weekly scheduled delivery routes, digital bill of lading with instant signature capture, and digital invoicing.',
    'Zero stockouts over 9 consecutive months, 28% reduction in total freight logistics spend, and instant real-time auditability for finance.',
    '[{"label": "Logistics Cost Saved", "value": "28%"}, {"label": "Retail Outlets", "value": "45 Stores"}, {"label": "Stockout Rate", "value": "0.0%"}, {"label": "Audit Speed", "value": "100% Digital"}]'::jsonb,
    'https://images.unsplash.com/photo-1553413077-190dd305871c?auto=format&fit=crop&w=1200&q=80',
    true,
    true,
    3
)
ON CONFLICT (slug) DO NOTHING;

-- Seed Testimonials
INSERT INTO public.website_testimonials (author_name, author_title, company, quote, rating, avatar_url, is_active, display_order)
VALUES
(
    'Dr. Kemi Adeleke',
    'Supply Chain Lead',
    'Novacare Pharmaceuticals',
    'NovaXpress solved our biggest headache: cold-chain compliance. With real-time temperature logs and reliable riders, our sensitive vaccines and pharmaceuticals arrive intact every single time.',
    5,
    'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=200&q=80',
    true,
    1
),
(
    'Tunde Babalola',
    'Co-Founder & COO',
    'ComfortCare Lifestyle',
    'Before NovaXpress, COD money took 10-14 days to reach our bank account. With NovaXpress, our cash is remitted within 24 hours like clockwork. That alone allowed us to grow 300% this year.',
    5,
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=80',
    true,
    2
),
(
    'Emeka Nwosu',
    'Head of Retail Logistics',
    'Apex Superstores Nigeria',
    'Their micro-hub warehousing and electronic proof of delivery make tracking effortless. We never have disputes over missing cartons or unclear delivery times anymore.',
    5,
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=200&q=80',
    true,
    3
)
ON CONFLICT DO NOTHING;

-- Seed Stats
INSERT INTO public.website_stats (label, value, suffix, description, icon_name, display_order)
VALUES
('Successful Deliveries', '250,000', '+', 'Doorstep parcels completed with electronic POD', 'PackageCheck', 1),
('On-Time Delivery Rate', '99.4', '%', 'Consistently meeting strict customer SLAs', 'Clock', 2),
('Cash Remitted (COD)', '₦4.8B', '+', 'Fast, fully reconciled merchant payouts', 'Banknote', 3),
('Distribution Hubs', '18', '+', 'Micro-fulfillment centers nationwide', 'MapPin', 4)
ON CONFLICT DO NOTHING;
