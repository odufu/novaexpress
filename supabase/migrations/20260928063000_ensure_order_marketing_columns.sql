-- Migration: Ensure customer_email and optional marketing columns exist on orders table
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_email TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_alt_phone TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS offer_package_id TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'pay_on_delivery';
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS is_pod BOOLEAN DEFAULT true;
