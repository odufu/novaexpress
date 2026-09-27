-- Migration: 20260927021000_audit_data_remediation_linkages.sql
-- Description:
-- 1. Ensure missing catalog products exist in public.products (Hair Dye Shampoo, Grazer Herbal Balm, Clear Vision Tea).
-- 2. Link all unlinked client_stock_balances to authoritative product_ids.
-- 3. Link all client_stock_invoice_items to authoritative product_ids.
-- 4. Purge orphaned test stock balances and invoices.

-- ============================================================================
-- 1. Ensure Missing Catalog Products
-- ============================================================================
DO $$
DECLARE
    v_comp_id UUID := '11111111-1111-4111-8111-111111111111';
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.products WHERE sku = 'SKU-HDS' OR name ILIKE '%Hair Dye%') THEN
        INSERT INTO public.products (
            id, company_id, name, sku, base_price, cost_price, stock_quantity, available_count,
            client_id, client_name, category, is_active
        ) VALUES (
            '77777777-aaaa-4777-8777-777777777771', v_comp_id, 'Hair Dye Shampoo', 'SKU-HDS',
            5000.00, 2000.00, 3960, 3960,
            '00000000-0000-4000-8000-789382731303', 'Novacare Ltd', 'Hair Care', true
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.products WHERE sku = 'SKU-GHB' OR name ILIKE '%Herbal Balm%') THEN
        INSERT INTO public.products (
            id, company_id, name, sku, base_price, cost_price, stock_quantity, available_count,
            client_id, client_name, category, is_active
        ) VALUES (
            '77777777-aaaa-4777-8777-777777777772', v_comp_id, 'Grazer Herbal Balm', 'SKU-GHB',
            4500.00, 1800.00, 720, 720,
            '00000000-0000-4000-8000-789382731303', 'Novacare Ltd', 'Herbal Remedy', true
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.products WHERE sku = 'SKU-CVT' OR name ILIKE '%Clear Vision%') THEN
        INSERT INTO public.products (
            id, company_id, name, sku, base_price, cost_price, stock_quantity, available_count,
            client_id, client_name, category, is_active
        ) VALUES (
            '77777777-aaaa-4777-8777-777777777773', v_comp_id, 'Clear Vision Tea', 'SKU-CVT',
            6000.00, 2500.00, 630, 630,
            '00000000-0000-4000-8000-789382731303', 'Novacare Ltd', 'Herbal Tea', true
        );
    END IF;
END $$;

-- ============================================================================
-- 2. Link All Client Stock Balances & Normalize Client ID
-- ============================================================================
UPDATE public.client_stock_balances sb
SET product_id = p.id::TEXT,
    client_id = '00000000-0000-4000-8000-789382731303'
FROM public.products p
WHERE (sb.product_id IS NULL OR sb.product_id = '')
  AND (sb.item_code = p.sku 
    OR sb.item_name ILIKE '%' || p.name || '%' 
    OR p.name ILIKE '%' || sb.item_name || '%');

-- Delete orphaned test balance rows
DELETE FROM public.client_stock_balances
WHERE item_code = 'TEST-ITEM' 
   OR warehouse ILIKE '%Test Central%';

-- ============================================================================
-- 3. Link All Client Stock Invoice Items to Genuine Product IDs
-- ============================================================================
UPDATE public.client_stock_invoice_items ii
SET product_id = p.id::TEXT
FROM public.products p
WHERE (ii.product_id IS NULL OR ii.product_id = '')
  AND (ii.product_sku = p.sku 
    OR ii.product_name ILIKE '%' || p.name || '%' 
    OR p.name ILIKE '%' || ii.product_name || '%');

-- Handle Grazer Tea invoice items linking to Grazer Herbal Detox Tea
UPDATE public.client_stock_invoice_items
SET product_id = '3d377805-9870-4841-b452-ffb640f9825e'
WHERE (product_id IS NULL OR product_id = '')
  AND (product_name ILIKE '%Grazer%' OR product_sku ILIKE '%GRAZ%');

-- Handle Ura Clear Tea invoice items linking to Ura Clear
UPDATE public.client_stock_invoice_items
SET product_id = '5edbfcf1-3edd-4f33-a9e4-9278f6f8a9c5'
WHERE (product_id IS NULL OR product_id = '')
  AND (product_name ILIKE '%Ura Clear%' OR product_sku ILIKE '%URA%');

-- Handle Hair Dye Shampoo invoice items linking to Hair Dye Shampoo
UPDATE public.client_stock_invoice_items
SET product_id = '77777777-aaaa-4777-8777-777777777771'
WHERE (product_id IS NULL OR product_id = '')
  AND (product_name ILIKE '%Hair Dye%' OR product_sku ILIKE '%HAIR%');

-- Delete orphaned test invoices and line items
DELETE FROM public.client_stock_invoice_items
WHERE invoice_id IN (
    SELECT id FROM public.client_stock_invoices 
    WHERE client_id = '' 
       OR invoice_number ILIKE 'INV-TEST%'
);

DELETE FROM public.client_stock_invoices
WHERE client_id = '' 
   OR invoice_number ILIKE 'INV-TEST%';
