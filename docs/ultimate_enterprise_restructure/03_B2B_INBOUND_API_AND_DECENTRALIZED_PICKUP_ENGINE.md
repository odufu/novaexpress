# Enterprise Blueprint: B2B Inbound Ingestion API & Decentralized Sourcing Logistics Protocol

**Document Reference:** `docs/ultimate_enterprise_restructure/03_B2B_INBOUND_API_AND_DECENTRALIZED_PICKUP_ENGINE.md`  
**System Version:** 2.5.0 Enterprise Release  
**Status:** Architecture Blueprint & Implementation Specification  
**Context:** Multi-Stop Decentralized Community Pharmacy & Supermarket Logistics Ingestion (ComfortCare & B2B Retail Partners)

---

## 1. Executive Summary & Strategic Necessity

### 1.1 The Business Shift
Traditional logistics models in e-commerce assume centralized warehouses where items are picked, packed, and sorted from a single depot. However, Nigerian modern commerce is experiencing a structural revolution:
1. **Decentralized Retail Networks (e.g. ComfortCare):** Over 500+ licensed community pharmacies across Abuja and all 36 states hold the actual drug inventories. No physical inventory is held in a central warehouse. When patients order medications, orders are fulfilled directly from local dispensaries.
2. **Supermarket & General Store E-Commerce:** Supermarkets (e.g., Prince Ebeano, Next Cash & Carry, 4U Supermarket) and multi-branch retail brands want to plug into a high-reliability delivery network via REST API to power their digital order channels without maintaining an in-house fleet.

### 1.2 Core Operational Challenges Solved
- **Multi-Stop Sourcing Split:** When an order requires items from multiple branches or pharmacies (e.g., Pharmacy A has Malaria tablets, Pharmacy B has an inhaler), NovaExpress dispatches a single rider on an optimized sequential multi-stop route (`Stop A -> Stop B -> Patient Doorstep`).
- **Standardized Multi-Pickup Economics:** Base flat rate of **₦3,500** + **₦1,500** per additional stop. Rider receives **₦1,800** base + **₦1,000** extra stop bonus. Platform retains **44% net margin** (**₦2,200** on a 2-stop order).
- **Tamper-Evident Chain of Custody:** Each retail dispensary seals products in tamper-evident bags tagged with unique reference IDs (`SEAL-CC-99014-A`). The rider must scan the barcode/QR code at each stop before departure.
- **e-POD with WhatsApp OTP:** Zero-fraud doorstep handover confirmed via WhatsApp 4-digit OTP, digital signature, and geo-coordinate capture.

```
┌────────────────────────────────────────────────────────────────────────┐
│             EXTERNAL B2B CLIENT SYSTEM (e.g., ComfortCare / Supermarket)│
│                     Patient / Customer Order Checkout                  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                        HTTP POST (Bearer Token)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│           NOVAEXPRESS EDGE API GATEWAY: ingest-client-package          │
│  • Authenticate API Key via b2b_clients table                          │
│  • Validate Payload (stops, sealed bags, receiver coords)              │
│  • Compute Dynamic Pricing (₦3,500 base + ₦1,500/extra stop)           │
│  • Create Order + client_package_pickups records in DB                 │
│  • Assign Optimal Hub / Dispatch Pool & Generate Tracking No           │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                   FIELD RIDER MOBILE PDA DISPATCH                      │
│   [Stop 1] MedPlus Life Camp   ──▶ Scan Bag A ──▶ Confirm WhatsApp     │
│   [Stop 2] H-Medix Wuse 2      ──▶ Scan Bag B ──▶ Confirm WhatsApp     │
│   [Stop 3] Recipient Doorstep  ──▶ Verify WhatsApp OTP & e-POD Sign    │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                         Real-time Webhook Events
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│          B2B PARTNER WEBHOOK LISTENER (Status Synced in Real Time)     │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Database Architecture & Schema Extensions

To support B2B clients, multi-stop itineraries, and tamper-proof verification, the database requires three surgical modifications:

### 2.1 Table: `public.b2b_clients`
Registers verified external commercial clients who possess programmatic API access.

```sql
CREATE TABLE IF NOT EXISTS public.b2b_clients (
    id TEXT PRIMARY KEY,                           -- Unique client identifier (e.g., 'comfortcare-abuja-01')
    client_name TEXT NOT NULL,                     -- Display name (e.g., 'ComfortCare Health & Pharmacy Ltd')
    company_registration_no TEXT,                  -- CAC / Corporate Registration Number
    industry_category TEXT NOT NULL DEFAULT 'pharmacy' 
        CHECK (industry_category IN ('pharmacy', 'supermarket', 'electronics', 'fashion', 'general_retail')),
    api_key_hash TEXT NOT NULL,                    -- Bcrypt / Argon2 hash of secret bearer token
    api_key_prefix TEXT NOT NULL,                  -- Truncated prefix for UI display (e.g., 'nx_live_cc_...')
    webhook_url TEXT,                              -- Client endpoint for real-time status updates
    webhook_secret TEXT,                           -- Secret used for HMAC-SHA256 signature verification
    base_flat_rate NUMERIC(12, 2) NOT NULL DEFAULT 3500.00,
    additional_pickup_fee NUMERIC(12, 2) NOT NULL DEFAULT 1500.00,
    rider_base_allowance NUMERIC(12, 2) NOT NULL DEFAULT 1800.00,
    rider_extra_stop_allowance NUMERIC(12, 2) NOT NULL DEFAULT 1000.00,
    allowed_cities JSONB NOT NULL DEFAULT '["Abuja", "Lagos"]'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    contact_email TEXT NOT NULL,
    contact_phone TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_b2b_clients_active ON public.b2b_clients(is_active);
```

### 2.2 Table: `public.orders` Extensions
Adds foreign keys and operational tracking columns to existing orders table:

```sql
ALTER TABLE public.orders
    ADD COLUMN IF NOT EXISTS fulfillment_type TEXT NOT NULL DEFAULT 'nova_inventory'
        CHECK (fulfillment_type IN ('nova_inventory', 'client_package')),
    ADD COLUMN IF NOT EXISTS b2b_client_id TEXT REFERENCES public.b2b_clients(id),
    ADD COLUMN IF NOT EXISTS client_order_reference TEXT,
    ADD COLUMN IF NOT EXISTS recipient_whatsapp TEXT,
    ADD COLUMN IF NOT EXISTS delivery_otp TEXT,
    ADD COLUMN IF NOT EXISTS otp_verified_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS pickup_stops_count INT NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS additional_pickup_fee NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS rider_pickup_allowance NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS payment_receipt_ref TEXT,
    ADD COLUMN IF NOT EXISTS payment_gateway TEXT;

CREATE INDEX idx_orders_b2b_client ON public.orders(b2b_client_id);
CREATE INDEX idx_orders_client_ref ON public.orders(client_order_reference);
CREATE INDEX idx_orders_fulfillment_type ON public.orders(fulfillment_type);
```

### 2.3 Table: `public.client_package_pickups`
Detailed sequential itinerary stops for a multi-stop parcel collection.

```sql
CREATE TABLE IF NOT EXISTS public.client_package_pickups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    stop_sequence INT NOT NULL,                     -- 1 for Stop A, 2 for Stop B, etc.
    stop_label TEXT NOT NULL,                       -- 'Pickup Stop 1 (Life Camp)'
    location_id TEXT NOT NULL,                      -- Partner premises identifier (e.g. 'ph-medplus-lifecamp')
    location_name TEXT NOT NULL,                    -- 'MedPlus Pharmacy (Life Camp)'
    pickup_address TEXT NOT NULL,                   -- Street address
    city TEXT NOT NULL DEFAULT 'Abuja',
    state TEXT NOT NULL DEFAULT 'Federal Capital Territory',
    lga TEXT,
    landmark TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    contact_person TEXT NOT NULL,
    contact_phone TEXT NOT NULL,
    contact_whatsapp TEXT,
    items_to_collect JSONB NOT NULL DEFAULT '[]'::jsonb, -- Array of items/drugs
    sealed_bag_ref TEXT NOT NULL,                   -- Barcode / QR reference (e.g., 'BAG-CC-99014-A')
    scanned_bag_ref TEXT,                           -- Scanned code on collection
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'rider_assigned', 'rider_arrived', 'bag_verified_collected', 'exception_failed')),
    failure_reason TEXT,
    collected_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_pickups_order_id ON public.client_package_pickups(order_id);
CREATE INDEX idx_pickups_sealed_bag ON public.client_package_pickups(sealed_bag_ref);
```

---

## 3. Inbound REST API Gateway Specification

### 3.1 Endpoint Overview
- **URI:** `POST https://<supabase-project-id>.supabase.co/functions/v1/ingest-client-package`
- **Method:** `POST`
- **Content-Type:** `application/json`
- **Authentication:** `Authorization: Bearer <nx_live_secret_key>`
- **Custom Header:** `X-Client-Id: <client_identifier>`

### 3.2 Request Headers
```http
POST /functions/v1/ingest-client-package HTTP/1.1
Host: qpcafevjsrbauweuiiyq.supabase.co
Authorization: Bearer nx_live_comfortcare_sec_994821049
X-Client-Id: comfortcare-abuja-01
Content-Type: application/json
```

### 3.3 Full Request Payload Schema
```json
{
  "client_id": "comfortcare-abuja-01",
  "order_reference": "CC-99014",
  "fulfillment_type": "client_package",
  "logistics_pricing": {
    "base_flat_rate": 3500.0,
    "additional_pickup_fee": 1500.0,
    "pickup_count": 2,
    "total_fee": 5000.0
  },
  "pickup_stops": [
    {
      "stop_number": 1,
      "location_id": "ph-medplus-lifecamp",
      "location_name": "MedPlus Pharmacy (Life Camp Branch)",
      "pickup_address": "Suite 4, Life Camp Commercial Complex, Life Camp, Abuja",
      "city": "Abuja",
      "state": "Federal Capital Territory",
      "lga": "Abuja Municipal (AMAC)",
      "landmark": "Near Life Camp Roundabout",
      "latitude": 9.0631,
      "longitude": 7.3912,
      "contact_person": "Pharm. Kenneth Okafor",
      "contact_phone": "+2348031112233",
      "contact_whatsapp": "+2348031112233",
      "items_to_collect": [
        {
          "item_name": "Coartem 80/480mg",
          "quantity": 2,
          "requires_cold_chain": false
        }
      ],
      "sealed_bag_ref": "BAG-CC-99014-A"
    },
    {
      "stop_number": 2,
      "location_id": "ph-hmedix-wuse",
      "location_name": "H-Medix Pharmacy (Wuse 2 Branch)",
      "pickup_address": "Plot 42, Aminu Kano Crescent, Wuse 2, Abuja",
      "city": "Abuja",
      "state": "Federal Capital Territory",
      "lga": "Abuja Municipal (AMAC)",
      "landmark": "Opposite Banex Plaza Corridor",
      "latitude": 9.0792,
      "longitude": 7.4721,
      "contact_person": "Pharm. Fatima Bello",
      "contact_phone": "+2348024445566",
      "contact_whatsapp": "+2348024445566",
      "items_to_collect": [
        {
          "item_name": "Augmentin 625mg",
          "quantity": 1,
          "requires_cold_chain": false
        }
      ],
      "sealed_bag_ref": "BAG-CC-99014-B"
    }
  ],
  "receiver": {
    "name": "Dr. Farouk Al-Mansur",
    "phone_number": "+2348032651505",
    "whatsapp_number": "+2348032651505",
    "address": "Plot 1044, Adetokunbo Ademola Crescent, Wuse 2, Abuja",
    "city": "Abuja",
    "state": "Federal Capital Territory",
    "lga": "Abuja Municipal (AMAC)",
    "landmark": "Near Banex / Wuse 2 Corridor",
    "latitude": 9.0805,
    "longitude": 7.4740
  },
  "package_summary": {
    "total_packages": 2,
    "requires_cold_chain": false,
    "special_instructions": "Clinical prescription parcel. Keep upright."
  },
  "payment_receipt": {
    "gateway": "Paystack",
    "receipt_number": "CC-PAYSTACK-99014",
    "transaction_reference": "CC-TXN-8492048",
    "amount_paid": 19200.0,
    "currency": "NGN",
    "payment_status": "prepaid",
    "verified_at": "2026-10-10T17:50:00.000Z"
  }
}
```

### 3.4 Ingestion Logic & Edge Function Algorithm

When `POST /functions/v1/ingest-client-package` receives this payload:

```
Step 1: Authenticate Client API Key
  - Extract Bearer token from 'Authorization' header.
  - Query public.b2b_clients where id = payload.client_id AND is_active = true.
  - Verify token hash. If invalid -> Return HTTP 401 Unauthorized.

Step 2: Idempotency Verification
  - Query public.orders where b2b_client_id = client_id AND client_order_reference = payload.order_reference.
  - If existing order found -> Return HTTP 200 OK with existing tracking details (prevents duplicate orders).

Step 3: Server-Side Pricing Calculation
  - pickup_count = payload.pickup_stops.length.
  - If pickup_count < 1 -> Return HTTP 400 Bad Request ("At least 1 pickup stop is required").
  - base_rate = client.base_flat_rate (default ₦3,500.00).
  - extra_stop_fee = (pickup_count - 1) * client.additional_pickup_fee (default ₦1,500.00).
  - calculated_total_fee = base_rate + extra_stop_fee.
  - rider_allowance = client.rider_base_allowance + ((pickup_count - 1) * client.rider_extra_stop_allowance).

Step 4: Distribution Center (DC) Routing
  - Extract first stop coordinates (or city/LGA).
  - Match to closest active Distribution Center (e.g. "Abuja Central Hub (Wuse)").

Step 5: Transactional Order Creation
  - Generate tracking number: 'NOV-' + current_year + '-' + random_alpha_numeric(6).
  - Generate 4-digit recipient verification OTP: lpad(floor(random() * 10000)::text, 4, '0').
  - Insert row into public.orders:
      tracking_number, status = 'order_placed', fulfillment_type = 'client_package',
      b2b_client_id, client_order_reference, customer_name, customer_phone,
      recipient_whatsapp, delivery_otp, total_amount = calculated_total_fee,
      additional_pickup_fee = extra_stop_fee, rider_pickup_allowance = rider_allowance,
      assigned_dc_id.
  - Insert N rows into public.client_package_pickups:
      order_id, stop_sequence, stop_label, location_id, location_name,
      pickup_address, contact_person, contact_phone, contact_whatsapp,
      items_to_collect, sealed_bag_ref, status = 'pending'.

Step 6: Real-time Dispatch Broadcast
  - Fire Supabase Realtime broadcast to DC Dispatch Console.
  - Dispatch WhatsApp Notification to Recipient:
    "Hello Dr. Farouk! NovaExpress is picking up your ComfortCare prescription (Order CC-99014). Track live: https://novaexpress.ng/track/NOV-2026-CC104".

Step 7: HTTP 201 Response
  - Return complete order acknowledgment JSON.
```

### 3.5 Successful Response (HTTP 201 Created)
```json
{
  "success": true,
  "tracking_number": "NOV-2026-CC104",
  "order_reference": "CC-99014",
  "status": "order_placed",
  "assigned_hub": {
    "hub_id": "dc-abuja-central",
    "hub_name": "Abuja Central Distribution Hub (Wuse 2)",
    "hub_phone": "+2348006682397"
  },
  "logistics_pricing": {
    "currency": "NGN",
    "base_flat_rate": 3500.0,
    "additional_pickup_fee": 1500.0,
    "pickup_stops_count": 2,
    "total_logistics_fee": 5000.0
  },
  "estimated_delivery_time": "35 - 45 mins",
  "live_tracking_url": "https://novaexpress.ng/track/NOV-2026-CC104",
  "created_at": "2026-10-11T13:10:00.000Z"
}
```

---

## 4. Multi-Stop Physical Custody & Rider Protocol

### 4.1 Rider Route Manifest Queue
On the NovaExpress Rider Mobile PDA, a B2B multi-stop order is rendered not as a simple pickup-and-drop, but as a **Sequential 3-Phase Itinerary**:

```
┌────────────────────────────────────────────────────────────────────────┐
│  MISSION #NOV-2026-CC104: B2B Multi-Stop Prescription Delivery         │
│  Partner: ComfortCare Health • Payout: ₦2,800.00                       │
├────────────────────────────────────────────────────────────────────────┤
│  [STOP 1 - PICKUP] MedPlus Pharmacy (Life Camp)                        │
│  📍 Suite 4, Life Camp Commercial Complex                              │
│  👤 Pharm. Kenneth Okafor (+234 803 111 2233)                          │
│  📦 1 Sealed Bag: BAG-CC-99014-A (Coartem 80/480mg x2)                 │
│  🔘 [WhatsApp Pharmacist]   🔘 [Scan QR / Barcode]                     │
├────────────────────────────────────────────────────────────────────────┤
│  [STOP 2 - PICKUP] H-Medix Pharmacy (Wuse 2)                           │
│  📍 Plot 42, Aminu Kano Crescent, Wuse 2                               │
│  👤 Pharm. Fatima Bello (+234 802 444 5566)                            │
│  📦 1 Sealed Bag: BAG-CC-99014-B (Augmentin 625mg x1)                  │
│  🔘 [WhatsApp Pharmacist]   🔘 [Scan QR / Barcode]                     │
├────────────────────────────────────────────────────────────────────────┤
│  [STOP 3 - DELIVERY] Dr. Farouk Al-Mansur                              │
│  📍 Plot 1044, Adetokunbo Ademola Crescent, Wuse 2                     │
│  📱 +234 803 265 1505                                                  │
│  🔐 Required: Recipient 4-Digit OTP + Receiver Signature               │
│  🔘 [Verify OTP & Deliver]                                             │
└────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Barcode & QR Sealed Bag Scan Verification
To ensure zero mix-ups and zero tampering:
1. When the rider arrives at Stop 1 (MedPlus Life Camp), the pharmacist presents the tamper-evident sealed pouch with barcode label `BAG-CC-99014-A`.
2. The rider opens the camera barcode scanner in the NovaExpress Rider App.
3. If the scanned barcode matches `BAG-CC-99014-A`:
   - Sound confirmation beep + green checkmark.
   - Record `scanned_bag_ref = 'BAG-CC-99014-A'` and `status = 'bag_verified_collected'`.
   - Update `client_package_pickups.collected_at = NOW()`.
4. If an incorrect barcode is scanned:
   - Red flash alert: *"Invalid Bag Ref! Expected BAG-CC-99014-A. Hand pouch back to pharmacist."*
5. Rider cannot transition to Stop 2 until Stop 1 bag is successfully verified.

### 4.3 Electronic Proof-of-Delivery (e-POD) Handover
At the patient's doorstep:
1. Both sealed pouches (`BAG-CC-99014-A` and `BAG-CC-99014-B`) are inspected in the recipient's presence.
2. The rider requests the **4-digit OTP** sent to the patient's WhatsApp when dispatch started.
3. The rider enters the OTP on the PDA:
   - System validates OTP against `public.orders.delivery_otp`.
   - Upon match: e-Signature canvas unlocks.
4. Patient signs on the screen; rider captures GPS coordinates and taps **Confirm Delivery Complete**.
5. Order transitions to `status = 'delivered'`, timestamps logged, and payout of **₦2,800.00** is immediately credited to the rider's in-app wallet balance.

---

## 5. Real-Time Outbound Webhook Protocol

Whenever an order state transitions, NovaExpress dispatches an asynchronous HTTP POST webhook to the client partner's registered `webhook_url` (e.g., `https://comfortcare.ng/api/v1/logistics-webhook`).

### 5.1 Webhook Signature Header
Every webhook payload includes an HMAC-SHA256 signature in the header:
```http
X-NovaExpress-Signature: t=1790487000,v1=9e4a8b7c3d2e1f0...
```
The partner verifies this header using their shared `webhook_secret` to ensure message authenticity.

### 5.2 Supported Webhook Event Types
| Event Name | Trigger Condition |
| :--- | :--- |
| `order.dispatched` | Rider assigned to order and heading to Stop 1. |
| `pickup.stop_arrived` | Rider arrived at a pharmacy/shop location. |
| `pickup.bag_collected` | Rider scanned and verified sealed bag at Stop $N$. |
| `pickup.all_completed` | All pickup stops cleared; rider en route to patient. |
| `order.delivered` | Recipient OTP verified, signature captured, order completed. |
| `order.failed` | Pharmacy closed, stock unavailable, or patient unreachable. |

### 5.3 Webhook Payload Example: `pickup.bag_collected`
```json
{
  "event": "pickup.bag_collected",
  "timestamp": "2026-10-11T13:22:15.000Z",
  "client_id": "comfortcare-abuja-01",
  "order_reference": "CC-99014",
  "tracking_number": "NOV-2026-CC104",
  "stop_details": {
    "stop_number": 1,
    "location_id": "ph-medplus-lifecamp",
    "location_name": "MedPlus Pharmacy (Life Camp)",
    "sealed_bag_ref": "BAG-CC-99014-A",
    "collected_at": "2026-10-11T13:22:10.000Z"
  },
  "progress": {
    "completed_stops": 1,
    "total_stops": 2,
    "next_stop": "H-Medix Pharmacy (Wuse 2 Branch)"
  }
}
```

---

## 6. Financial Architecture & Stakeholder Economics

| Transaction Component | Single Stop Route | Dual Stop Route (Multi-Pickup) | Triple Stop Route |
| :--- | :--- | :--- | :--- |
| **B2B Client Invoice** | ₦3,500.00 | ₦5,000.00 | ₦6,500.00 |
| **Rider Flat Compensation** | ₦1,800.00 | ₦1,800.00 | ₦1,800.00 |
| **Rider Multi-Stop Bonus** | ₦0.00 | ₦1,000.00 | ₦2,000.00 |
| **Total Rider Payout** | **₦1,800.00** | **₦2,800.00** | **₦3,800.00** |
| **NovaExpress Net Platform Margin** | **₦1,700.00 (48.6%)** | **₦2,200.00 (44.0%)** | **₦2,700.00 (41.5%)** |
| **Cash Collection Risk** | Zero (Prepaid) | Zero (Prepaid) | Zero (Prepaid) |

**Conclusion:** Multi-stop client package deliveries yield higher absolute Naira margins (₦2,200 vs ₦1,700) for NovaExpress while keeping rider motivation exceptionally high (+₦1,000 extra per 10-minute counter stop).
