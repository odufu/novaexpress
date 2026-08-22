# 🌐 NovaExpress Strategic Roadmap: Client-Facing Portals & On-Demand Dispatch

This document outlines the architectural blueprint, data schema, role hierarchy, and operational workflows for the two core client-facing expansion verticals:
1. **Distributed Inventory Merchant Portal (B2B E-Commerce & Telesales Hub)**
2. **Client Package On-Demand App (P2P / Instant Point-to-Point Rider Dispatch)**

---

## 🏗️ The 3-Pillar Ecosystem Architecture

```
                                  ┌─────────────────────────────────────────┐
                                  │      NovaExpress Core Cloud Platform     │
                                  │  (Supabase DB, GIS Radar, Remittances)  │
                                  └────┬──────────────┬──────────────┬──────┘
                                       │              │              │
        ┌──────────────────────────────┴────┐         │         ┌────┴─────────────────────────────┐
        ▼                                   ▼         ▼         ▼                                  ▼
┌───────────────────────┐       ┌───────────────────────┐       ┌──────────────────────────────────┐
│   1. MERCHANT PORTAL  │       │     2. DC CONSOLE     │       │       3. RIDER PDA TERMINAL      │
│  (Distributed Inven.) │       │  (Fulfillment Center) │       │   (Turn-by-Turn, POD, Stock)     │
│                       │       │                       │       │                                  │
│ • Client Admin BI     │       │ • Warehouse Inventory │       │ • Turn-by-Turn Google Maps GPS   │
│ • Telesales Logging   │──────▶│ • Proximity Dispatch  │──────▶│ • WhatsApp Pin Refinement        │
│ • Remittance Ledger   │       │ • Fleet Management    │       │ • Verified Gate Pin Recording    │
│ • SKU & Stock Alerts  │       │ • Returns Triage      │       │ • Digital POD Signature Canvas   │
└───────────────────────┘       └───────────────────────┘       └──────────────────────────────────┘
                                                                                 ▲
                                ┌────────────────────────────────────────────────┤
                                │ 4. CLIENT PACKAGE ON-DEMAND APP (Instant P2P)  │
                                │                                                │
                                │ • 1-Tap Nearby Rider Discovery (GIS Radar)     │
                                │ • Instant Parcel Pickup Request                │
                                │ • Live Waybill & Rider Tracking                │
                                │ • In-App Payment / Direct COD Collection       │
                                └────────────────────────────────────────────────┘
```

---

## 🏛️ VERTICAL 1: Distributed Inventory Merchant Portal

### 🎯 Objective
Enable e-commerce merchants and direct-to-consumer (D2C) brands who store physical stock across NovaExpress Distribution Centers to manage order lifecycles, run internal call centers (telesales), track delivery success velocity, and reconcile Cash-on-Delivery (COD) remittances.

### 👥 User Roles & Permissions

#### A. Client Sales Agent (Telesales / Order Confirmation Rep)
- **Leads & Intake Inbox**: Views raw incoming orders from merchant landing pages (Shopify, WooCommerce, ClickFunnels, Custom Webhooks).
- **Call-to-Confirm Workflow**:
  - 1-click dialer with customer script.
  - Address refinement (identifying Nigerian landmark hints & LGA).
  - Upsell & Cross-sell injection (adding promo items or extra units).
- **Push to Fulfillment**: Transitions order status from `lead_unconfirmed` $\rightarrow$ `confirmed_for_dispatch`, instantly placing it into the local NovaExpress Distribution Center's unassigned pool.

#### B. Client Admin / Business Owner
- **Sales Effect & Performance Dashboard**:
  - **Delivery Completion Velocity**: Conversion rate of confirmed orders vs. physically delivered PODs.
  - **Failed Order Root-Cause Matrix**: Breakdown of why orders failed (`customer_unreachable`, `customer_rescheduled`, `fake_order`, `out_of_cash`).
  - **Distribution Center Regional Heatmap**: Sales performance in Abuja vs. Lagos vs. Port Harcourt.
- **Stock & Inventory Auditing**:
  - Live units available in DC custody vs. units in-flight on rider motorcycles.
  - Expiry date & lot monitoring.
  - Stock restock requisition alerts when inventory dips below minimum threshold.
- **Financial Remittance & Settlement**:
  - Total Gross COD collected by NovaExpress riders.
  - Delivery fees and return penalty deductions.
  - Instant wallet balance payouts directly to merchant Nigerian bank accounts.

---

## 📦 VERTICAL 2: Client Package On-Demand Dispatch App

### 🎯 Objective
Empower individuals, social commerce vendors (Instagram/WhatsApp vendors), and corporate offices to summon an on-duty NovaExpress delivery rider for immediate point-to-point package pickup and same-day delivery.

### ⚙️ Core Operational Mechanics

1. **GIS Rider Discovery**:
   - Customer sets Pickup Address & Dropoff Address.
   - App queries Supabase spatial index using `find_closest_available_rider` to find the nearest PDA within $5\text{km} - 10\text{km}$.
2. **Instant Fare Estimation**:
   - Distance-based calculation using Haversine GIS algorithm + base pickup fee + declared item insurance.
3. **Dispatch & Real-Time Tracking**:
   - Order rings on the closest rider's PDA Terminal.
   - Once accepted, customer sees live rider ETA and motorcycle movement on map.
4. **Waybill & Proof of Delivery**:
   - Auto-generated digital waybill barcode.
   - Recipient signs on rider's PDA canvas upon arrival.
   - Instant SMS / WhatsApp delivery confirmation with timestamped POD photo.

---

## 🗄️ Database & Multi-Tenant Schema Blueprint

```sql
-- 1. Client Organization (Multi-Tenant Isolation)
CREATE TABLE IF NOT EXISTS public.clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_name TEXT NOT NULL,
    brand_slug TEXT UNIQUE NOT NULL,
    business_email TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    fulfillment_tier TEXT DEFAULT 'distributed_inventory' CHECK (fulfillment_tier IN ('distributed_inventory', 'ondemand_package', 'hybrid')),
    wallet_balance NUMERIC(12,2) DEFAULT 0.00,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Client Users (Admins, Telesales Agents, Finance)
CREATE TABLE IF NOT EXISTS public.client_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID REFERENCES public.clients(id) ON DELETE CASCADE,
    auth_user_id UUID UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    email TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('client_admin', 'sales_agent', 'inventory_manager', 'finance_auditor')),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Inflow Leads / Telesales Intake Pipeline
CREATE TABLE IF NOT EXISTS public.sales_leads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID REFERENCES public.clients(id) ON DELETE CASCADE,
    assigned_agent_id UUID REFERENCES public.client_users(id),
    customer_name TEXT NOT NULL,
    customer_phone TEXT NOT NULL,
    delivery_address TEXT NOT NULL,
    delivery_city TEXT,
    delivery_state TEXT,
    ordered_items JSONB NOT NULL DEFAULT '[]',
    lead_status TEXT DEFAULT 'new' CHECK (lead_status IN ('new', 'called_busy', 'called_rescheduled', 'confirmed', 'cancelled_fake')),
    call_attempts INTEGER DEFAULT 0,
    last_call_at TIMESTAMPTZ,
    converted_order_id UUID REFERENCES public.orders(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Instant On-Demand Package Dispatch Trips
CREATE TABLE IF NOT EXISTS public.ondemand_package_trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID, -- Registered individual or guest customer
    sender_name TEXT NOT NULL,
    sender_phone TEXT NOT NULL,
    pickup_address TEXT NOT NULL,
    pickup_latitude DOUBLE PRECISION,
    pickup_longitude DOUBLE PRECISION,
    recipient_name TEXT NOT NULL,
    recipient_phone TEXT NOT NULL,
    dropoff_address TEXT NOT NULL,
    dropoff_latitude DOUBLE PRECISION,
    dropoff_longitude DOUBLE PRECISION,
    package_description TEXT NOT NULL,
    package_value NUMERIC(12,2) DEFAULT 0.00,
    fare_amount NUMERIC(10,2) NOT NULL,
    payment_method TEXT DEFAULT 'wallet' CHECK (payment_method IN ('wallet', 'card', 'pod_cash', 'recipient_transfer')),
    assigned_rider_id UUID REFERENCES public.delivery_agents(id),
    trip_status TEXT DEFAULT 'searching_rider' CHECK (trip_status IN ('searching_rider', 'rider_assigned', 'rider_arrived_pickup', 'in_transit', 'delivered', 'cancelled')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 🧭 Phased Implementation Plan

| Phase | Target Module | Scope & Deliverables |
|---|---|---|
| **Phase 1 (Current - ✅ Complete)** | **PDA Terminal & DC Console Core** | Full delivery operations, turn-by-turn navigation, geocoding & proximity matching, verified gate PIN, live stock custody, COD remittances, and automated test suite. |
| **Phase 2** | **Distributed Client Portal (Telesales & Admin BI)** | Client login, telesales call confirmation workflow, conversion to live DC dispatch, merchant stock visibility, and COD remittance analytics dashboard. |
| **Phase 3** | **Client Package On-Demand App (P2P Dispatch)** | Customer mobile/web booking UI, live rider radar estimation, payment gateway integration (Monnify / Paystack), and real-time trip GPS tracking. |
