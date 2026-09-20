# Phase 2: DC Merchant 360° Representation, Editing & Brand Theming Specification

**Module:** DC Console & Multi-Tenant Merchant Management  
**Target Files:**  
- `lib/features/dc_console/presentation/pages/dc_clients_page.dart`
- `lib/features/dc_console/presentation/widgets/dc_edit_client_modal.dart` (New)
- `lib/features/dc_console/presentation/widgets/dc_client_asset_portfolio_modal.dart` (Upgraded)
- `lib/features/dc_console/presentation/providers/dc_console_provider.dart`
- `supabase/migrations/20260920160000_dc_merchant_management_and_brand_theming.sql` (New)

---

### 1. Architectural Vision

Distribution Centers (DCs) are the regional custodians of physical merchant inventory, order dispatch, and Cash-on-Delivery (COD) vaults. To manage merchants effectively, DC operators must not merely view static rows; they need a **Merchant 360° Operations & Governance Hub** enabling:
1. **Full Lifecycle Editing**: Editing corporate credentials, contact managers, operating depot states, and assigned closer capacities.
2. **Value-Added Service Toggles**: Enabling or disabling `has_inventory_management` and assigning service modules (`fulfillment`, `delivery`, `inventory_management`, `returns_processing`).
3. **Brand Identity & White-Label Customization**: Uploading merchant logos and configuring primary, secondary, and accent colors with real-time preview presets.
4. **Negotiated Operational Tariffs**: Maintaining custom delivery fees, failed attempt compensations, platform maintenance fees, and electronic settlement bank details.
5. **Physical Custody & Unit Economics Oversight**: Viewing live stock quantities across all regional distribution centers, landed valuation, and margin health per merchant.

---

### 2. Detailed Data Model & Database Upgrades

#### Database Migration: `20260920160000_dc_merchant_management_and_brand_theming.sql`
```sql
-- Ensure all brand and service columns exist with proper defaults
ALTER TABLE public.clients
ADD COLUMN IF NOT EXISTS has_inventory_management BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS services_enabled TEXT[] DEFAULT ARRAY['fulfillment', 'delivery', 'inventory_management'],
ADD COLUMN IF NOT EXISTS logo_url TEXT,
ADD COLUMN IF NOT EXISTS primary_color TEXT DEFAULT '#0D9488',
ADD COLUMN IF NOT EXISTS secondary_color TEXT DEFAULT '#031632',
ADD COLUMN IF NOT EXISTS accent_color TEXT DEFAULT '#10B981',
ADD COLUMN IF NOT EXISTS brand_theme JSONB DEFAULT '{"font_family": "Inter", "border_radius": 8}'::jsonb,
ADD COLUMN IF NOT EXISTS operating_states TEXT[] DEFAULT ARRAY['Federal Capital Territory', 'Lagos', 'Rivers', 'Kano', 'Oyo', 'Enugu'];

-- Stored procedure for atomic DC client profile & tariff updates
CREATE OR REPLACE FUNCTION public.fn_update_client_profile_and_tariffs(
    p_client_id UUID,
    p_company_name TEXT,
    p_contact_person TEXT,
    p_email TEXT,
    p_phone TEXT,
    p_address TEXT,
    p_city TEXT,
    p_state TEXT,
    p_tier TEXT,
    p_closer_limit INT,
    p_has_inventory_management BOOLEAN,
    p_services_enabled TEXT[],
    p_operating_states TEXT[],
    p_logo_url TEXT,
    p_primary_color TEXT,
    p_secondary_color TEXT,
    p_accent_color TEXT,
    p_custom_delivery_fee NUMERIC,
    p_custom_failed_attempt_fee NUMERIC,
    p_custom_platform_fee NUMERIC,
    p_bank_name TEXT,
    p_account_number TEXT,
    p_account_name TEXT,
    p_settlement_frequency TEXT,
    p_settlement_day TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.clients
    SET
        company_name = COALESCE(p_company_name, company_name),
        contact_person = COALESCE(p_contact_person, contact_person),
        email = COALESCE(p_email, email),
        phone = COALESCE(p_phone, phone),
        address = COALESCE(p_address, address),
        city = COALESCE(p_city, city),
        state = COALESCE(p_state, state),
        tier = COALESCE(p_tier, tier),
        is_enterprise = (p_tier = 'enterprise'),
        closer_limit = COALESCE(p_closer_limit, closer_limit),
        has_inventory_management = COALESCE(p_has_inventory_management, has_inventory_management),
        services_enabled = COALESCE(p_services_enabled, services_enabled),
        operating_states = COALESCE(p_operating_states, operating_states),
        logo_url = p_logo_url,
        primary_color = COALESCE(p_primary_color, primary_color),
        secondary_color = COALESCE(p_secondary_color, secondary_color),
        accent_color = COALESCE(p_accent_color, accent_color),
        custom_delivery_fee = p_custom_delivery_fee,
        custom_failed_attempt_fee = p_custom_failed_attempt_fee,
        custom_platform_fee_value = p_custom_platform_fee,
        bank_name = COALESCE(p_bank_name, bank_name),
        account_number = COALESCE(p_account_number, account_number),
        account_name = COALESCE(p_account_name, account_name),
        settlement_frequency = COALESCE(p_settlement_frequency, settlement_frequency),
        settlement_day = COALESCE(p_settlement_day, settlement_day),
        updated_at = NOW()
    WHERE id = p_client_id;

    RETURN jsonb_build_object(
        'success', true,
        'client_id', p_client_id,
        'updated_at', NOW()
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_update_client_profile_and_tariffs TO authenticated, service_role;
```

---

### 3. Flutter DC Console Implementation Details

#### 3.1. Upgrading `DCClientsPage`
- Add an explicit **Manage & Edit** action button to every client row alongside `View Assets` and `Client Settlement`.
- Enhance the Client Card/Row to display:
  - Inventory Service Badge: `[Inventory Managed]` (Emerald) vs. `[Fulfillment Only]` (Slate).
  - Operating Regional Depots count (e.g. `6 States Covered`).
  - Brand Palette indicator (small circular preview of merchant's primary brand color).

#### 3.2. New Widget: `DCEditClientModal` (`lib/features/dc_console/presentation/widgets/dc_edit_client_modal.dart`)
A multi-tab interactive dialog with 4 distinct configuration tabs:
1. **Tab 1: Corporate Profile & Depots**:
   - Company Name, Client Code (read-only), Contact Person, Phone, Email, Physical Address.
   - Primary Depot State & Multi-Select Operating States dropdown (Nigeria locations).
   - Tier Selection (`enterprise` vs `standard_merchant`) & Telesales Closer Limit.
2. **Tab 2: Services & Stock Governance**:
   - `Inventory Management & Landed Cost Tracking` (Switch toggle).
     - *Helper text*: "When enabled, merchant tracks itemized procurement costs (freight, packaging, handling) and weighted average valuation rates."
   - Checkbox list of enabled services: `Physical Hub Warehousing`, `Rider Last-Mile Delivery`, `Intake Landed Cost Accounting`, `Returns & Refurbishment`.
3. **Tab 3: Brand Identity & Theming**:
   - Logo URL input with live image preview.
   - Brand Presets picker (Novacare Emerald, NovaXpress Blaze, Royal Sapphire, Imperial Violet, Crimson Ruby, Corporate Slate).
   - Hex code inputs for Primary, Secondary, and Accent colors with live theme preview card.
4. **Tab 4: Tariffs & Settlement Banking**:
   - Negotiated Delivery Fee (₦).
   - Failed Delivery Surcharge (₦).
   - Platform Charge / System Maintenance (₦).
   - Third-Party Switch Fee policy details.
   - Bank Name, 10-digit NUBAN, Verified Corporate Account Name, Settlement Frequency, and Settlement Day.

#### 3.3. Enhancing `DCClientAssetPortfolioModal`
- Add a new tab: **"Unit Economics & Landed Cost Overview"**:
  - Displays merchant's product portfolio with average landed cost per unit, retail price, gross margin %, and stock valuation across hubs.
  - Summarizes physical custody: total units in Central DC, regional hubs, and active in-transit rider bags.
