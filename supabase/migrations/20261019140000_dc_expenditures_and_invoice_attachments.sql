-- ============================================================================
-- MIGRATION: 20261019140000_dc_expenditures_and_invoice_attachments.sql
-- DESCRIPTION: Enhance business_expenditures for Distribution Center OpEx,
--              invoice numbers, vendor tracking, and multi-DC scoping.
-- ============================================================================

-- 1. Add vendor, invoice reference, and payment columns
ALTER TABLE public.business_expenditures 
    ADD COLUMN IF NOT EXISTS invoice_number TEXT,
    ADD COLUMN IF NOT EXISTS vendor_name TEXT,
    ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'transfer',
    ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'approved';

-- 2. Relax category check constraint to support all DC operational categories
ALTER TABLE public.business_expenditures 
    DROP CONSTRAINT IF EXISTS business_expenditures_category_check;

ALTER TABLE public.business_expenditures 
    ADD CONSTRAINT business_expenditures_category_check CHECK (category IN (
        'advertisement',
        'procurement',
        'logistics',
        'salaries',
        'rent_utilities',
        'packaging',
        'rider_allowance',
        'diesel_fuel',
        'equipment_maintenance',
        'facility_supplies',
        'security',
        'stationery',
        'other'
    ));

-- 3. Storage bucket policies for receipt attachments
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'expenditure-receipts',
    'expenditure-receipts',
    true,
    15728640,
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 15728640;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Public Access for Expenditure Receipts') THEN
        CREATE POLICY "Public Access for Expenditure Receipts" ON storage.objects
            FOR SELECT USING (bucket_id = 'expenditure-receipts');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Allow Uploads for Expenditure Receipts') THEN
        CREATE POLICY "Allow Uploads for Expenditure Receipts" ON storage.objects
            FOR INSERT WITH CHECK (bucket_id = 'expenditure-receipts');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Allow Updates for Expenditure Receipts') THEN
        CREATE POLICY "Allow Updates for Expenditure Receipts" ON storage.objects
            FOR UPDATE USING (bucket_id = 'expenditure-receipts');
    END IF;
END $$;

-- 4. Seed initial realistic DC Expenditures for Abuja Main DC and Ikeja DC
INSERT INTO public.business_expenditures (
    entity_type,
    distribution_center_id,
    title,
    description,
    category,
    amount,
    expenditure_date,
    invoice_number,
    vendor_name,
    payment_method,
    status,
    receipt_url
) VALUES
-- Abuja Main DC (Wuse Grand Central - 22222222-2222-4222-8222-222222222222)
(
    'grand_dc',
    '22222222-2222-4222-8222-222222222222',
    'Station Backup Generator Diesel (350 Litres)',
    '350 Litres of diesel for hub continuous power during national grid fluctuation.',
    'diesel_fuel',
    385000.00,
    CURRENT_DATE - INTERVAL '2 days',
    'INV-ABJ-DSL-089',
    'TotalEnergies Wuse 2 Service Station',
    'transfer',
    'approved',
    'https://images.unsplash.com/photo-1554415707-9e44667eee15?w=800&auto=format&fit=crop'
),
(
    'grand_dc',
    '22222222-2222-4222-8222-222222222222',
    'Rider Dispatch Fuel Allowance (12 Riders - Week 42)',
    'Weekly fuel and bike mobility allowance for Abuja FCT distribution squad.',
    'rider_allowance',
    180000.00,
    CURRENT_DATE - INTERVAL '3 days',
    'VOU-ABJ-FL-104',
    'DC Fleet Disbursement Petty Cash',
    'transfer',
    'approved',
    null
),
(
    'grand_dc',
    '22222222-2222-4222-8222-222222222222',
    'Bulk Waybill Consumables & Security Flyer Pouches',
    'Thermal receipt rolls (50 packs) and tamper-proof security waybill bags.',
    'packaging',
    125000.00,
    CURRENT_DATE - INTERVAL '5 days',
    'INV-PACK-ABJ-312',
    'Printech Supplies Ltd Garki',
    'card',
    'approved',
    'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?w=800&auto=format&fit=crop'
),
(
    'grand_dc',
    '22222222-2222-4222-8222-222222222222',
    'Hub Facility Rent & Dedicated Fiber Internet',
    'Monthly high-speed enterprise broadband for barcode scanning and live tracking.',
    'rent_utilities',
    85000.00,
    CURRENT_DATE - INTERVAL '8 days',
    'INV-NET-OCT-2026',
    'MainOne Enterprise Fiber Service',
    'transfer',
    'approved',
    null
),
(
    'grand_dc',
    '22222222-2222-4222-8222-222222222222',
    'Fleet Bike Servicing (TVS King & Bajaj 4 Units)',
    'Brake pad replacements, engine oil changes, and chain tightening for station bikes.',
    'equipment_maintenance',
    95000.00,
    CURRENT_DATE - INTERVAL '10 days',
    'INV-MOTO-ABJ-077',
    'Alhaji Musa Auto & Bike Clinic Apo',
    'cash',
    'approved',
    null
),
-- Lagos Ikeja DC (22222222-2222-4222-8222-333333333333)
(
    'sub_dc',
    '22222222-2222-4222-8222-333333333333',
    'Ikeja Hub Generator Diesel Top-up (200 Litres)',
    'Station generator fuel for sorting conveyor and warehouse illumination.',
    'diesel_fuel',
    220000.00,
    CURRENT_DATE - INTERVAL '1 day',
    'INV-IKJ-DSL-042',
    'Oando Filling Station Ikeja Along',
    'transfer',
    'approved',
    'https://images.unsplash.com/photo-1554415707-9e44667eee15?w=800&auto=format&fit=crop'
),
(
    'sub_dc',
    '22222222-2222-4222-8222-333333333333',
    'Lagos Riders Express Fuel Subsidies (8 Riders)',
    'Daily dispatch fuel and transit bridge toll subsidies for Mainland riders.',
    'rider_allowance',
    120000.00,
    CURRENT_DATE - INTERVAL '4 days',
    'VOU-IKJ-FL-088',
    'Ikeja Station Petty Cash',
    'transfer',
    'approved',
    null
),
(
    'sub_dc',
    '22222222-2222-4222-8222-333333333333',
    'Station Barcode Scanners & Zebra Printer Repair',
    'Replacement of worn thermal printhead and 2 wireless barcode scanners.',
    'equipment_maintenance',
    68000.00,
    CURRENT_DATE - INTERVAL '7 days',
    'INV-TECH-IKJ-209',
    'Compucare Computer Village Ikeja',
    'transfer',
    'approved',
    null
);
