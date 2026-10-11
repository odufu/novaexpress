# NovaXpress Enterprise Architecture: Financial Intelligence & Tri-Portal Expenditure Engine
**Document Reference:** `02_FINANCIAL_INTELLIGENCE_AND_EXPENDITURE_ENGINE.md`  
**Target Environment:** NovaXpress Enterprise Clearinghouse & Logistics Platform  
**Subject:** Multi-Tier Business Intelligence, Expenditure Management, Product-Level Unit Economics, and Document Attachments  
**Date:** October 2026

---

## 1. Executive Concept & Business Model

In Nigerian e-commerce and logistics:
- **E-Commerce Merchants** struggle to know which products are actually generating cash and which ones are losing money on Meta ad burn and failed delivery attempts.
- **Logistics Hub Supervisors (Sub-DCs)** struggle to account for local operational burn (generator diesel, bike repairs, packaging tape, water) against parcel drop revenues.
- **Logistics Headquarters (Grand DC)** lacks a single command center comparing total nationwide logistics revenue against trunk haulage, truck fuel, fleet depreciation, and warehouse leases.

This specification unifies all three operational tiers into a **Tri-Portal Financial Intelligence Architecture** backed by a single authoritative database table and high-performance server-side aggregation.

---

## 2. The Hybrid Expenditure Architecture (SKU Unit Economics vs. General Overhead)

A critical architectural decision was resolved:
- **Standalone Only**: Cannot calculate product ROI or unit economics.
- **Product-Attached Only**: Cannot track general overhead (rent, diesel, accountant, staff).
- **The Hybrid Solution**:
  - `business_expenditures.product_id` is **OPTIONAL (`UUID NULL REFERENCES products(id)`)**.
  - When recording an expense, the user chooses:
    - **General Business Overhead** (`product_id = NULL`): Rent, generator fuel, general marketing, administrative costs.
    - **Product-Specific Allocation** (`product_id = <Product UUID>`): Targeted ad campaign for *Alpha Man*, raw material procurement for *Respira Tea*, custom cartons for *Glucosamine*.

### The Dynamic Dashboard Aggregation Rule:
1. **When "All Products" is selected**:
   $$\text{Total Expenses} = \sum (\text{All Product-Specific Expenses}) + \sum (\text{General Overhead Expenses})$$
2. **When a Specific Product (e.g. Alpha Man) is selected**:
   $$\text{Direct SKU Expenses} = \sum (\text{Expenses directly tagged to Alpha Man})$$
   $$\text{SKU Net Profit} = \text{Product Sales Revenue} - \text{Direct SKU Expenses} - \text{Product Logistics Delivery Fees}$$
   *Result: The merchant sees the exact cash margin and ad return on investment (ROAS) for that specific SKU!*

---

## 3. Database Schema: PostgreSQL & Supabase

### 3.1. Unified `business_expenditures` Table
```sql
-- Create enum for entity scope
CREATE TYPE expenditure_entity_type AS ENUM ('merchant', 'grand_dc', 'sub_dc');

-- Universal Multi-Tier Expenditure Ledger
CREATE TABLE public.business_expenditures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type expenditure_entity_type NOT NULL,
    
    -- Owner Foreign Keys (Mutually exclusive based on entity_type)
    client_id UUID REFERENCES public.clients(id) ON DELETE CASCADE,
    distribution_center_id UUID REFERENCES public.distribution_centers(id) ON DELETE CASCADE,
    
    -- Optional Product Link (for merchants calculating SKU unit economics)
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    
    -- Expense Attributes
    expense_name TEXT NOT NULL,          -- e.g. "Meta Ad Campaign - Ramadan Promo", "50L Diesel for Generator"
    category TEXT NOT NULL,              -- Dynamic by entity_type (see category mapping below)
    amount NUMERIC(15, 2) NOT NULL CHECK (amount >= 0),
    expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Receipt / Invoice Document Attachment (PDF or Image)
    receipt_url TEXT,                    -- Supabase Storage public/signed URL
    receipt_file_name TEXT,             -- e.g. "Invoice_Diesel_Novacare_Oct2026.pdf"
    
    -- Audit & Timestamps
    recorded_by UUID REFERENCES public.users(id),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for sub-second query performance
CREATE INDEX idx_exp_entity_date ON public.business_expenditures(entity_type, expense_date);
CREATE INDEX idx_exp_client_product ON public.business_expenditures(client_id, product_id, expense_date);
CREATE INDEX idx_exp_dc_date ON public.business_expenditures(distribution_center_id, expense_date);
```

### 3.2. Dynamic Expense Categories by Entity Tier
```
┌────────────────────────────────────────────────────────────────────────┐
│ 1. MERCHANT (E-Commerce Categories)                                    │
│    • advertisement      (Meta Ads, TikTok Ads, Google, Influencers)    │
│    • procurement        (Factory stock purchases, import tariffs)      │
│    • packaging_flyers   (Custom branded boxes, flyers, bubble wrap)    │
│    • office_operations  (Staff salary, generator diesel, software)     │
│    • other              (Miscellaneous overhead)                       │
├────────────────────────────────────────────────────────────────────────┤
│ 2. GRAND DC (Logistics Headquarters Categories)                        │
│    • fleet_fuel         (Linehaul trucks, inter-state transit diesel)  │
│    • fleet_maintenance  (Truck servicing, tires, insurance, licenses) │
│    • facility_leases    (Regional warehouse leases, estate security)   │
│    • packaging_waybills (Thermal waybill rolls, packaging cartons)     │
│    • logistics_payroll  (Headquarters dispatchers, warehouse sorters)  │
│    • other              (Administrative and platform maintenance)      │
├────────────────────────────────────────────────────────────────────────┤
│ 3. SUB-DC (Local Hub Station Categories)                               │
│    • station_power      (Local generator diesel, NEPA/utility units)   │
│    • bike_repairs       (Motorcycle tires, oil change, brake pads)     │
│    • rider_subsidies    (Special transit allowances, failed drop fees) │
│    • consumables        (Packing tape, marker pens, drinking water)    │
│    • facility_upkeep    (Minor hub repairs, cleaning)                  │
│    • other              (Station miscellaneous)                        │
└────────────────────────────────────────────────────────────────────────┘
```

### 3.3. Supabase Storage Bucket: `expenditure_documents`
- **Bucket ID**: `expenditure_documents`
- **Allowed MIME Types**: `application/pdf`, `image/jpeg`, `image/png`, `image/webp`.
- **Max File Size**: 15 MB.
- **Folder Convention**:
  - Merchants: `merchants/{client_id}/{year}/{month}/{unique_file_name}`
  - DCs: `dcs/{dc_id}/{year}/{month}/{unique_file_name}`

---

## 4. Stored Procedures (RPCs) for Sub-Second Analytics

To ensure mobile and desktop clients never execute heavy client-side calculations, all metrics and timeline bucketing execute in pure PostgreSQL.

### 4.1. `fn_get_merchant_financial_dashboard`
```sql
CREATE OR REPLACE FUNCTION public.fn_get_merchant_financial_dashboard(
    p_client_id UUID,
    p_product_id UUID DEFAULT NULL,   -- If NULL, consolidates entire catalog
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_start DATE := COALESCE(p_start_date, date_trunc('month', CURRENT_DATE)::DATE);
    v_end DATE := COALESCE(p_end_date, CURRENT_DATE);
    
    v_sales_revenue NUMERIC(15, 2) := 0;
    v_qty_sold INT := 0;
    v_ad_spend NUMERIC(15, 2) := 0;
    v_procurement NUMERIC(15, 2) := 0;
    v_other_expenses NUMERIC(15, 2) := 0;
    v_total_expenses NUMERIC(15, 2) := 0;
    v_net_profit NUMERIC(15, 2) := 0;
    v_available_stock INT := 0;
    v_revenue_till_date NUMERIC(15, 2) := 0;
    
    v_chart_timeline JSONB;
    v_state_breakdown JSONB;
BEGIN
    -- 1. Sales Revenue & Quantity Sold within period
    SELECT 
        COALESCE(SUM(total_amount), 0),
        COALESCE(SUM(quantity), 0)
    INTO v_sales_revenue, v_qty_sold
    FROM public.orders
    WHERE client_id = p_client_id
      AND status = 'delivered'
      AND (p_product_id IS NULL OR product_id = p_product_id)
      AND (delivered_at::DATE BETWEEN v_start AND v_end);

    -- 2. Revenue Till Date (All-time cumulative)
    SELECT COALESCE(SUM(total_amount), 0)
    INTO v_revenue_till_date
    FROM public.orders
    WHERE client_id = p_client_id
      AND status = 'delivered'
      AND (p_product_id IS NULL OR product_id = p_product_id);

    -- 3. Expenditures Breakdown within period
    SELECT
        COALESCE(SUM(CASE WHEN category = 'advertisement' THEN amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN category = 'procurement' THEN amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN category NOT IN ('advertisement', 'procurement') THEN amount ELSE 0 END), 0),
        COALESCE(SUM(amount), 0)
    INTO v_ad_spend, v_procurement, v_other_expenses, v_total_expenses
    FROM public.business_expenditures
    WHERE client_id = p_client_id
      AND (p_product_id IS NULL OR product_id = p_product_id OR product_id IS NULL)
      AND (expense_date BETWEEN v_start AND v_end);

    -- 4. Net Profit Calculation
    v_net_profit := v_sales_revenue - v_total_expenses;

    -- 5. Available Stock
    SELECT COALESCE(SUM(stock_quantity), 0)
    INTO v_available_stock
    FROM public.products
    WHERE client_id = p_client_id
      AND is_active = true
      AND (p_product_id IS NULL OR id = p_product_id);

    -- 6. Revenue vs Expenditure Timeline (Grouped by date for Dual-Bar Chart)
    SELECT jsonb_agg(sub) INTO v_chart_timeline
    FROM (
        SELECT 
            d.series_date::TEXT AS period_date,
            COALESCE(o.rev, 0) AS revenue,
            COALESCE(e.exp, 0) AS expenditure
        FROM generate_series(v_start, v_end, interval '1 day') AS d(series_date)
        LEFT JOIN (
            SELECT delivered_at::DATE AS dt, SUM(total_amount) AS rev
            FROM public.orders
            WHERE client_id = p_client_id AND status = 'delivered'
              AND (p_product_id IS NULL OR product_id = p_product_id)
            GROUP BY delivered_at::DATE
        ) o ON o.dt = d.series_date::DATE
        LEFT JOIN (
            SELECT expense_date AS dt, SUM(amount) AS exp
            FROM public.business_expenditures
            WHERE client_id = p_client_id
              AND (p_product_id IS NULL OR product_id = p_product_id OR product_id IS NULL)
            GROUP BY expense_date
        ) e ON e.dt = d.series_date::DATE
        ORDER BY d.series_date ASC
    ) sub;

    -- 7. Geographic Distribution (Revenue by States for Donut Chart)
    SELECT jsonb_agg(sub) INTO v_state_breakdown
    FROM (
        SELECT 
            COALESCE(delivery_state, 'Unknown') AS state_name,
            SUM(total_amount) AS state_revenue,
            COUNT(id) AS orders_count
        FROM public.orders
        WHERE client_id = p_client_id
          AND status = 'delivered'
          AND (p_product_id IS NULL OR product_id = p_product_id)
          AND (delivered_at::DATE BETWEEN v_start AND v_end)
        GROUP BY COALESCE(delivery_state, 'Unknown')
        ORDER BY state_revenue DESC
    ) sub;

    RETURN jsonb_build_object(
        'sales_revenue', v_sales_revenue,
        'quantity_sold', v_qty_sold,
        'total_expenditure', v_total_expenses,
        'advertisement_spend', v_ad_spend,
        'procurement_cost', v_procurement,
        'other_expenses', v_other_expenses,
        'net_profit', v_net_profit,
        'available_stock', v_available_stock,
        'revenue_till_date', v_revenue_till_date,
        'chart_timeline', COALESCE(v_chart_timeline, '[]'::jsonb),
        'state_breakdown', COALESCE(v_state_breakdown, '[]'::jsonb)
    );
END;
$$;
```

### 4.2. `fn_get_dc_logistics_dashboard` (For Grand DC & Sub-DCs)
```sql
CREATE OR REPLACE FUNCTION public.fn_get_dc_logistics_dashboard(
    p_dc_id UUID DEFAULT NULL,        -- If NULL, aggregates nationwide Grand DC network
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_start DATE := COALESCE(p_start_date, date_trunc('month', CURRENT_DATE)::DATE);
    v_end DATE := COALESCE(p_end_date, CURRENT_DATE);
    
    v_logistics_revenue NUMERIC(15, 2) := 0;
    v_packages_delivered INT := 0;
    v_total_expenses NUMERIC(15, 2) := 0;
    v_fuel_spend NUMERIC(15, 2) := 0;
    v_maintenance_cost NUMERIC(15, 2) := 0;
    v_facility_leases NUMERIC(15, 2) := 0;
    v_other_expenses NUMERIC(15, 2) := 0;
    v_net_logistics_margin NUMERIC(15, 2) := 0;
    v_network_inventory INT := 0;
    v_revenue_till_date NUMERIC(15, 2) := 0;
    
    v_chart_timeline JSONB;
    v_dc_breakdown JSONB;
BEGIN
    -- 1. Logistics Revenue (Delivery fees) & Delivered Packages
    SELECT 
        COALESCE(SUM(client_delivery_fee), 0),
        COUNT(id)
    INTO v_logistics_revenue, v_packages_delivered
    FROM public.orders
    WHERE status = 'delivered'
      AND (p_dc_id IS NULL OR distribution_center_id = p_dc_id)
      AND (delivered_at::DATE BETWEEN v_start AND v_end);

    -- 2. Lifetime Logistics Revenue
    SELECT COALESCE(SUM(client_delivery_fee), 0)
    INTO v_revenue_till_date
    FROM public.orders
    WHERE status = 'delivered'
      AND (p_dc_id IS NULL OR distribution_center_id = p_dc_id);

    -- 3. DC Operating Expenditures
    SELECT
        COALESCE(SUM(CASE WHEN category IN ('fleet_fuel', 'station_power') THEN amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN category IN ('fleet_maintenance', 'bike_repairs') THEN amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN category IN ('facility_leases', 'facility_upkeep') THEN amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN category NOT IN ('fleet_fuel', 'station_power', 'fleet_maintenance', 'bike_repairs', 'facility_leases', 'facility_upkeep') THEN amount ELSE 0 END), 0),
        COALESCE(SUM(amount), 0)
    INTO v_fuel_spend, v_maintenance_cost, v_facility_leases, v_other_expenses, v_total_expenses
    FROM public.business_expenditures
    WHERE (p_dc_id IS NULL OR distribution_center_id = p_dc_id)
      AND (expense_date BETWEEN v_start AND v_end);

    -- 4. Net Operating Margin
    v_net_logistics_margin := v_logistics_revenue - v_total_expenses;

    -- 5. Physical Inventory in Network
    SELECT COALESCE(SUM(balance_qty), 0)
    INTO v_network_inventory
    FROM public.client_stock_balances
    WHERE (p_dc_id IS NULL OR warehouse ILIKE '%' || (SELECT code FROM public.distribution_centers WHERE id = p_dc_id) || '%');

    -- 6. Revenue vs OpEx Timeline
    SELECT jsonb_agg(sub) INTO v_chart_timeline
    FROM (
        SELECT 
            d.series_date::TEXT AS period_date,
            COALESCE(o.rev, 0) AS revenue,
            COALESCE(e.exp, 0) AS expenditure
        FROM generate_series(v_start, v_end, interval '1 day') AS d(series_date)
        LEFT JOIN (
            SELECT delivered_at::DATE AS dt, SUM(client_delivery_fee) AS rev
            FROM public.orders
            WHERE status = 'delivered'
              AND (p_dc_id IS NULL OR distribution_center_id = p_dc_id)
            GROUP BY delivered_at::DATE
        ) o ON o.dt = d.series_date::DATE
        LEFT JOIN (
            SELECT expense_date AS dt, SUM(amount) AS exp
            FROM public.business_expenditures
            WHERE (p_dc_id IS NULL OR distribution_center_id = p_dc_id)
            GROUP BY expense_date
        ) e ON e.dt = d.series_date::DATE
        ORDER BY d.series_date ASC
    ) sub;

    -- 7. Distribution Center Volume Breakdown
    SELECT jsonb_agg(sub) INTO v_dc_breakdown
    FROM (
        SELECT 
            COALESCE(dc.name, 'Unassigned DC') AS dc_name,
            SUM(o.client_delivery_fee) AS dc_revenue,
            COUNT(o.id) AS deliveries_count
        FROM public.orders o
        LEFT JOIN public.distribution_centers dc ON dc.id = o.distribution_center_id
        WHERE o.status = 'delivered'
          AND (p_dc_id IS NULL OR o.distribution_center_id = p_dc_id)
          AND (o.delivered_at::DATE BETWEEN v_start AND v_end)
        GROUP BY COALESCE(dc.name, 'Unassigned DC')
        ORDER BY dc_revenue DESC
    ) sub;

    RETURN jsonb_build_object(
        'logistics_revenue', v_logistics_revenue,
        'packages_delivered', v_packages_delivered,
        'total_expenditure', v_total_expenses,
        'fuel_spend', v_fuel_spend,
        'maintenance_cost', v_maintenance_cost,
        'facility_leases', v_facility_leases,
        'other_expenses', v_other_expenses,
        'net_logistics_margin', v_net_logistics_margin,
        'network_inventory', v_network_inventory,
        'revenue_till_date', v_revenue_till_date,
        'chart_timeline', COALESCE(v_chart_timeline, '[]'::jsonb),
        'dc_breakdown', COALESCE(v_dc_breakdown, '[]'::jsonb)
    );
END;
$$;
```

---

## 5. Flutter Presentation Layer Architecture

### 5.1. UI Components Hierarchy
```
lib/features/finance/
  ├── domain/entities/
  │   └── business_expenditure.dart
  ├── data/
  │   ├── models/business_expenditure_model.dart
  │   └── datasources/expenditures_remote_datasource.dart
  ├── presentation/
  │   ├── providers/
  │   │   ├── business_expenditure_provider.dart
  │   │   └── financial_dashboard_provider.dart
  │   └── widgets/
  │       ├── record_expenditure_modal.dart         -- Form with PDF/image file picker
  │       ├── receipt_document_viewer_modal.dart     -- In-app PDF/image full viewer
  │       ├── dual_series_revenue_expenditure_chart.dart -- Grouped Bar Chart
  │       ├── geo_revenue_by_states_donut_chart.dart -- Donut Chart with State legend
  │       └── metric_sparkline_kpi_card.dart        -- KPI Card with sparkline mini-graph
```

### 5.2. Modal Workflow: "Record Business Expenditure"
1. **Title**: Text Input (e.g., *"TikTok Influencer Campaign"*, *"100L Generator Fuel"*).
2. **Category Dropdown**: Auto-scoped based on active logged-in role (`merchant`, `grand_dc`, `sub_dc`).
3. **Amount**: Formatted Naira currency input (`₦`).
4. **Expense Date**: Reuses calendar date picker; defaults to today.
5. **Product Link (Merchants Only)**:
   - Option 1: 🌐 **General Company Overhead** (`product_id = null`)
   - Options 2..N: 📦 **[Specific Product SKU]** (e.g. *Alpha Man*, *Respira Tea*)
6. **Receipt / Invoice Attachment**:
   - Single tap to attach PDF or camera photo.
   - Live upload progress indicator.
   - Uploads to Supabase Storage `expenditure_documents` and saves public link.

---

## 6. Next Step in Audit Documentation

Proceed to `03_B2B_INBOUND_API_AND_DECENTRALIZED_PICKUP_ENGINE.md` for the complete B2B Inbound Ingestion API, multi-stop pharmacy routing, and rider execution protocol.
