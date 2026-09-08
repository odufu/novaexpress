CREATE TABLE IF NOT EXISTS public.warehouses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE,
    rider_id UUID REFERENCES public.delivery_agents(id) ON DELETE SET NULL,
    distribution_center_id UUID REFERENCES public.distribution_centers(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    type TEXT DEFAULT 'rider_mini_hub',
    location_state TEXT,
    location_city TEXT,
    address TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.stock_transfers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE,
    source_warehouse_id UUID REFERENCES public.warehouses(id) ON DELETE SET NULL,
    destination_warehouse_id UUID REFERENCES public.warehouses(id) ON DELETE SET NULL,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.stock_transfer_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transfer_id UUID REFERENCES public.stock_transfers(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    quantity_shipped INT DEFAULT 0,
    quantity_received INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_transfer_items ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'warehouses' AND policyname = 'Public full access for warehouses') THEN
        CREATE POLICY "Public full access for warehouses" ON public.warehouses FOR ALL USING (true) WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'stock_transfers' AND policyname = 'Public full access for stock_transfers') THEN
        CREATE POLICY "Public full access for stock_transfers" ON public.stock_transfers FOR ALL USING (true) WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'stock_transfer_items' AND policyname = 'Public full access for stock_transfer_items') THEN
        CREATE POLICY "Public full access for stock_transfer_items" ON public.stock_transfer_items FOR ALL USING (true) WITH CHECK (true);
    END IF;
END $$;
