# NovaExpress Logistics — B2B Client Package & Decentralized Pharmacy Pickup Implementation TODO

**Feature:** B2B Client Package Inbound Protocol & Multi-Dispensary Last-Mile Logistics  
**Client Partner:** ComfortCare Health & Pharmacy Ltd (and future B2B e-commerce clients)  
**Status:** 📋 TODO / Ready for Implementation  
**Created Date:** October 10, 2026  
**Primary Objective:** Enable NovaExpress to ingest external client packages, calculate flat-rate delivery with multi-pickup surcharges, coordinate rider multi-stop collection at decentralized community pharmacies, and execute verified doorstep delivery with electronic Proof-of-Delivery (e-POD).

---

## 1. Executive Context & Business Model

Unlike NovaExpress's internal distributed inventory fulfillment (where goods originate from NovaCare Central Warehouses and regional Distribution Centers), **ComfortCare runs a decentralized network of licensed community pharmacies across Nigeria**.

ComfortCare does **not** store drugs in warehouses. Instead, local pharmacies register their premises. When a patient orders:
1. ComfortCare's Sourcing Engine selects the closest pharmacy/pharmacies that stock the drugs.
   - **Time of arrival is MAXIMUM priority** (fastest delivery to the patient).
   - Higher item depth takes precedence within the arrival window to minimize stops.
2. ComfortCare fires an automated HTTP POST request to NovaExpress: `POST /api/v1/orders/client-package`
3. NovaExpress dispatches a rider to execute the multi-stop pickup route, collects the sealed clinical bags, and delivers them to the patient.

### Pricing Rules Matrix:
```
+------------------------------------+------------------+---------------------+-------------------+
| Sourcing Scenario                  | Pickup Stops     | Additional Stop Fee | Total Logistics   |
+------------------------------------+------------------+---------------------+-------------------+
| Single Pharmacy Pickup (Optimal)   | 1 Pharmacy Stop  | ₦0.00               | ₦3,500.00 Flat    |
| Dual Pharmacy Pickup Split         | 2 Pharmacy Stops | +₦1,500.00          | ₦5,000.00         |
| Triple Pharmacy Pickup Split       | 3 Pharmacy Stops | +₦3,000.00          | ₦6,500.00         |
| N-Stop Pharmacy Pickup             | N Pharmacy Stops | +(N - 1) x ₦1,500   | ₦3,500 + Surcharge|
+------------------------------------+------------------+---------------------+-------------------+
```

---

## 2. Master Implementation Checklist (TODO)

```
+----------------------------------------------------------------------------------------------------+
|                                NOVAEXPRESS IMPLEMENTATION PHASES                                   |
|                                                                                                    |
|  [ ] PHASE 1: DATABASE SCHEMA & MIGRATIONS                                                         |
|      - Add fulfillment_type to orders ('nova_inventory' vs 'client_package')                       |
|      - Create client_package_pickups table for multi-stop pharmacy itineraries                     |
|      - Create b2b_clients table with API keys and webhook secrets                                  |
|                                                                                                    |
|  [ ] PHASE 2: B2B INBOUND EDGE FUNCTION / REST ENDPOINT                                            |
|      - Implement POST /functions/v1/ingest-client-package                                          |
|      - Verify Client Bearer API Token & IP rate limits                                             |
|      - Validate multi-pickup JSON payload & calculate fee (₦3,500 + ₦1,500/extra stop)             |
|      - Generate NovaExpress Tracking Number (e.g. NOV-2026-XXXXX) & dispatch task                  |
|                                                                                                    |
|  [ ] PHASE 3: RIDER PDA MOBILE APPLICATION (FLUTTER)                                               |
|      - Update Rider Task Manifest to display multi-stop pickup itineraries (Stop A, Stop B)        |
|      - Add Barcode / QR Scanner for Sealed Bag Reference IDs (e.g. SEAL-ORD-A)                     |
|      - Implement e-POD screen with Recipient WhatsApp OTP & Digital Signature                      |
|                                                                                                    |
|  [ ] PHASE 4: DISPATCHER WEB CONSOLE & LIVE MAP TRACKING                                           |
|      - Display B2B Client Package badge & client partner name                                      |
|      - Multi-stop map polyline: Rider -> Pharmacy A -> Pharmacy B -> Customer Destination          |
|      - Real-time status sync webhook to ComfortCare                                                |
|                                                                                                    |
|  [ ] PHASE 5: END-TO-END INTEGRATION TESTING                                                       |
|      - Automated test script simulating ComfortCare HTTP POST order                                |
|      - Test single pickup (₦3,500) and dual pickup (₦5,000)                                        |
|      - Validate WhatsApp notification dispatch to receiver                                         |
+----------------------------------------------------------------------------------------------------+
```

---

## 3. Phase-by-Phase Detailed Technical Tasks

### [ ] Phase 1: Database Schema & Migrations (`supabase/migrations/`)

- [ ] **Task 1.1: Create `b2b_clients` Table**
  ```sql
  CREATE TABLE public.b2b_clients (
      id TEXT PRIMARY KEY,
      client_name TEXT NOT NULL,
      api_key_hash TEXT NOT NULL,
      webhook_url TEXT,
      webhook_secret TEXT,
      base_flat_rate NUMERIC(10, 2) DEFAULT 3500.00,
      additional_pickup_fee NUMERIC(10, 2) DEFAULT 1500.00,
      is_active BOOLEAN DEFAULT TRUE,
      created_at TIMESTAMPTZ DEFAULT NOW()
  );

  -- Seed initial B2B Partner: ComfortCare
  INSERT INTO public.b2b_clients (id, client_name, api_key_hash)
  VALUES ('comfortcare-abuja-01', 'ComfortCare Health & Pharmacy Ltd', crypt('nx_live_comfortcare_sec_994821049', gen_salt('bf')));
  ```

- [ ] **Task 1.2: Add Columns to `public.orders`**
  ```sql
  ALTER TABLE public.orders 
  ADD COLUMN IF NOT EXISTS fulfillment_type TEXT DEFAULT 'nova_inventory' 
      CHECK (fulfillment_type IN ('nova_inventory', 'client_package')),
  ADD COLUMN IF NOT EXISTS b2b_client_id TEXT REFERENCES public.b2b_clients(id),
  ADD COLUMN IF NOT EXISTS client_order_reference TEXT,
  ADD COLUMN IF NOT EXISTS recipient_whatsapp TEXT,
  ADD COLUMN IF NOT EXISTS payment_receipt_ref TEXT,
  ADD COLUMN IF NOT EXISTS payment_gateway TEXT,
  ADD COLUMN IF NOT EXISTS pickup_stops_count INT DEFAULT 1,
  ADD COLUMN IF NOT EXISTS additional_pickup_fee NUMERIC(10, 2) DEFAULT 0.00;
  ```

- [ ] **Task 1.3: Create `public.client_package_pickups` Table**
  ```sql
  CREATE TABLE public.client_package_pickups (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
      stop_sequence INT NOT NULL,
      stop_label TEXT NOT NULL, -- 'Stop A', 'Stop B'
      pharmacy_id TEXT NOT NULL,
      pharmacy_name TEXT NOT NULL,
      pickup_address TEXT NOT NULL,
      city TEXT DEFAULT 'Abuja',
      state TEXT DEFAULT 'Federal Capital Territory',
      lga TEXT,
      landmark TEXT,
      contact_person TEXT,
      contact_phone TEXT,
      contact_whatsapp TEXT,
      drugs_to_collect JSONB NOT NULL DEFAULT '[]'::jsonb,
      sealed_bag_ref TEXT NOT NULL,
      status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'rider_arrived', 'collected', 'failed')),
      collected_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ DEFAULT NOW()
  );

  CREATE INDEX idx_client_package_pickups_order ON public.client_package_pickups(order_id);
  ```

---

### [ ] Phase 2: Inbound Ingestion API / Edge Function (`supabase/functions/`)

- [ ] **Task 2.1: Implement Edge Function `ingest-client-package`**
  - **Endpoint:** `POST https://<supabase-ref>.supabase.co/functions/v1/ingest-client-package`
  - **Headers Required:**
    - `Authorization: Bearer <API_KEY>`
    - `Content-Type: application/json`

- [ ] **Task 2.2: Payload Validation & Ingestion Logic**
  1. Authenticate bearer token against `b2b_clients`.
  2. Validate mandatory JSON fields:
     - `order_reference`, `fulfillment_type == 'client_package'`
     - `receiver`: `full_name`, `delivery_address`, `phone_number`, `whatsapp_number`
     - `pickup_stops`: non-empty array of pickup locations
     - `package_contents`: list of drugs
     - `payment_receipt`: `receipt_reference`
  3. Calculate logistics fee server-side:
     `pickup_count = payload.pickup_stops.length`  
     `additional_fee = pickup_count > 1 ? (pickup_count - 1) * 1500.0 : 0.0`  
     `total_fee = 3500.0 + additional_fee`
  4. Create order row in `orders` and insert entries into `client_package_pickups`.
  5. Assign optimal delivery hub / dispatch cluster based on first pickup stop coordinates.
  6. Return standard 201 Created JSON response:
     ```json
     {
       "status": "success",
       "tracking_number": "NOV-2026-CC104",
       "order_reference": "CC-104",
       "assigned_dc": "Abuja Central Dispatch Hub (Wuse 2)",
       "assigned_rider": "Rider Ibrahim",
       "rider_phone": "+234 812 345 6789",
       "pricing": {
         "base_flat_rate": 3500.0,
         "additional_pickup_fee": 1500.0,
         "pickup_count": 2,
         "total_fee": 5000.0
       },
       "eta": "25 mins"
     }
     ```

---

### [ ] Phase 3: Rider PDA Mobile App (`C:\PROJECT\NoveXPS\lib\`)

- [ ] **Task 3.1: Multi-Stop Pickup Manifest Screen**
  - When an order has `fulfillment_type == 'client_package'`:
    Display an expandable multi-stop route card:
    - **Step 1:** Pickup Stop A — *MedPlus Life Camp* (Scan Sealed Bag `SEAL-CC-104-A`)
    - **Step 2:** Pickup Stop B — *H-Medix Wuse 2* (Scan Sealed Bag `SEAL-CC-104-B`)
    - **Step 3:** Deliver to Client — *Plot 1044 Adetokunbo Ademola, Wuse 2*
  - Add quick action: "Call Pharmacist" and "Chat WhatsApp" directly from the stop card.

- [ ] **Task 3.2: Barcode / QR Bag Scanner Verification**
  - Rider must scan each `sealed_bag_ref` at the counter before departing the dispensary.
  - Ensures rider cannot leave Stop A without verifying Bag A.

- [ ] **Task 3.3: Electronic Proof-of-Delivery (e-POD) with OTP**
  - Before handing over medication parcel:
    - Send 4-digit verification OTP to `receiver.whatsapp_number`.
    - Rider enters OTP on PDA + collects digital receiver signature.
    - Captures GPS coordinates and timestamp of handover.

---

### [ ] Phase 4: Web Dispatch Console (`C:\PROJECT\NoveXPS\lib\presentation\pages\dispatch\`)

- [ ] **Task 4.1: Dispatch Live Map Polyline**
  - Render multi-point route:
    `[Rider Current Location] -> [Dispensary Stop 1] -> [Dispensary Stop 2] -> [Delivery Address]`
- [ ] **Task 4.2: Client Package Badge & Surcharge Audit**
  - Display badge: `B2B: ComfortCare • 2 Pickup Stops (₦5,000 Total Fee)`
- [ ] **Task 4.3: Outbound Status Webhook Trigger**
  - When rider status changes (`collected_at_pharmacy`, `in_transit`, `delivered`), fire an automated webhook to `https://comfortcare.ng/api/v1/logistics-webhook`.

---

## 4. Expected Incoming JSON Payload Sample (From ComfortCare)

```json
{
  "client_id": "comfortcare-abuja-01",
  "client_name": "ComfortCare Health & Pharmacy Ltd",
  "order_reference": "CC-84920",
  "fulfillment_type": "client_package",
  "logistics_pricing": {
    "base_flat_rate": 3500.0,
    "additional_pickup_fee": 1500.0,
    "pickup_count": 2,
    "total_fee": 5000.0
  },
  "pickup_stops": [
    {
      "pharmacy_id": "ph-medplus-lifecamp",
      "pharmacy_name": "MedPlus Pharmacy (Life Camp Branch)",
      "pickup_address": "Suite 12, Comfort Mall Commercial Wing, Life Camp, Abuja",
      "city": "Abuja",
      "state": "Federal Capital Territory",
      "lga": "Abuja Municipal (AMAC)",
      "landmark": "Near Life Camp Roundabout",
      "contact_person": "Pharm. Kenneth Okafor, B.Pharm",
      "contact_phone": "+234 803 111 2233",
      "contact_whatsapp": "+234 803 111 2233",
      "drugs_to_collect": [
        "Coartem 80/480mg (x1)"
      ],
      "sealed_bag_ref": "SEAL-CC-84920-A"
    },
    {
      "pharmacy_id": "ph-hmedix-wuse2",
      "pharmacy_name": "H-Medix Pharmacy (Wuse 2 Branch)",
      "pickup_address": "Plot 1044, Adetokunbo Ademola Crescent, Wuse 2, Abuja",
      "city": "Abuja",
      "state": "Federal Capital Territory",
      "lga": "Abuja Municipal (AMAC)",
      "landmark": "Beside AP Plaza, Wuse 2",
      "contact_person": "Pharm. Fatima Bello, M.Pharm",
      "contact_phone": "+234 802 444 5566",
      "contact_whatsapp": "+234 802 444 5566",
      "drugs_to_collect": [
        "Ventolin Inhaler (x1)"
      ],
      "sealed_bag_ref": "SEAL-CC-84920-B"
    }
  ],
  "receiver": {
    "full_name": "Dr. Farouk Al-Mansur",
    "delivery_address": "Plot 1044, Adetokunbo Ademola Crescent, Wuse 2, Abuja",
    "city": "Abuja",
    "state": "Federal Capital Territory",
    "lga": "Abuja Municipal (AMAC)",
    "phone_number": "+234 803 265 1505",
    "whatsapp_number": "+234 803 265 1505",
    "landmark": "Active Clinic Reception, Gate 2"
  },
  "package_contents": [
    {
      "drug_id": "prod-coartem-80-480",
      "drug_name": "Coartem 80/480mg",
      "quantity": 1,
      "assigned_pharmacy_id": "ph-medplus-lifecamp"
    },
    {
      "drug_id": "prod-ventolin-inhaler",
      "drug_name": "Ventolin Inhaler",
      "quantity": 1,
      "assigned_pharmacy_id": "ph-hmedix-wuse2"
    }
  ],
  "payment_receipt": {
    "receipt_reference": "CC-TXN-9841203",
    "payment_gateway": "Paystack Instant Settlement",
    "settlement_status": "settled",
    "total_order_amount": 16700.0,
    "logistics_fee_paid": 5000.0
  },
  "other_details": {
    "consignment_type": "pharmaceutical_consignment",
    "requires_cold_chain": false,
    "delivery_notes": "Deliver to front desk. Clinical parcel seal.",
    "urgency": "priority_same_day",
    "dispatched_timestamp": "2026-10-10T18:25:00.000Z"
  }
}
```

---

## 5. Verification & Definition of Done

When starting the NovaExpress project, complete these tests to verify full operation:
- [ ] 1. Run Supabase migration and verify tables `b2b_clients` and `client_package_pickups` exist.
- [ ] 2. Send sample JSON via Postman / curl to `/functions/v1/ingest-client-package`.
- [ ] 3. Verify order appears on Dispatcher Console with `Client Package` badge and ₦5,000 fee.
- [ ] 4. Login to Rider PDA mobile app as Emeka Rider (`rider.emeka@novaxpress.com`).
- [ ] 5. Confirm PDA shows Stop A and Stop B sequentially.
- [ ] 6. Scan barcode `SEAL-CC-84920-A` $\rightarrow$ Stop A marks as Collected.
- [ ] 7. Scan barcode `SEAL-CC-84920-B` $\rightarrow$ Stop B marks as Collected.
- [ ] 8. Execute delivery at customer destination with OTP and signature $\rightarrow$ Status changes to `delivered`.
