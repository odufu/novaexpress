# NovaExpress Logistics Clearinghouse
## Enterprise Specification: Decentralized Pharmacy Network & Multi-Stop B2B Inbound Logistics Protocol
**Document Version:** 2.0.0 (Decentralized Community Pharmacy Network Model)  
**Target Audience:** NovaExpress Executive Board, Operations Directors, Dispatch Management, and Engineering Team  
**Subject:** Implementation of Decentralized Community Pharmacy Pickups, Flat-Rate Logistics, Multi-Pharmacy Surcharges, and Last-Mile Delivery for ComfortCare & E-Commerce  

---

## 1. Executive Summary & Strategic Model

Unlike traditional e-commerce models where products are held in centralized warehouses, **ComfortCare operates a Decentralized Community Pharmacy Network across Nigeria**. 

ComfortCare does **not** hold physical inventory in warehouses. Instead, licensed community pharmacies across Abuja and all 36 states register their physical premises on ComfortCare. 

When a patient places an order:
1. **Intelligent Local Sourcing:** ComfortCare's routing algorithm queries nearby registered pharmacies stocking the patient's prescribed drugs.
2. **Single vs. Multi-Pharmacy Sourcing:**
   * **Single-Pharmacy Fulfillment (Optimal):** If one nearby pharmacy stocks all items, NovaExpress executes a single pickup and doorstep delivery for a standard flat rate (**₦3,500**).
   * **Multi-Pharmacy Split Sourcing:** If items are split across two or more pharmacies (e.g., Pharmacy A has Malaria tabs, Pharmacy B has an inhaler), NovaExpress executes a **Multi-Stop Pickup** route. ComfortCare charges the customer an **additional pickup surcharge** (**+₦1,500** per extra pharmacy stop).
3. **Automated B2B Dispatch:** ComfortCare automatically fires an HTTP POST payload to NovaExpress containing the complete itinerary of pharmacy pickup stops, sealed bag reference IDs, patient delivery destination, and payment receipt.

```
┌────────────────────────────────────────────────────────────────────────┐
│                      PATIENT PLACES RX ORDER                           │
│                      Destination: Wuse 2, Abuja                        │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│             COMFORTCARE LOCAL PHARMACY SOURCING ALGORITHM              │
│       Queries Registered Pharmacies Stocking Prescribed Meds           │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
         ┌──────────────────────────┴──────────────────────────┐
         │                                                     │
         ▼                                                     ▼
┌─────────────────────────────────┐   ┌──────────────────────────────────┐
│   CASE 1: SINGLE-PHARMACY MATCH │   │  CASE 2: MULTI-PHARMACY SPLIT    │
│   MedPlus Pharmacy (Life Camp)  │   │  MedPlus (Life Camp) + H-Medix   │
│   • 1 Pickup Stop               │   │  • 2 Pickup Stops                │
│   • Logistics Fee: Flat ₦3,500  │   │  • Flat Rate: ₦3,500             │
│   • Extra Surcharge: ₦0.00      │   │  • Extra Pickup Surcharge: ₦1,500│
│   • Total Logistics: ₦3,500     │   │  • Total Logistics: ₦5,000       │
└────────────────┬────────────────┘   └────────────────┬─────────────────┘
                 │                                     │
                 └──────────────────┬──────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│           AUTOMATED HTTP POST INGESTION TO NOVAEXPRESS                 │
│         POST /functions/v1/ingest-client-package (Bearer Token)        │
│    Payload: pickup_stops, bag_refs, patient_whatsapp, payment_receipt  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│          NOVAEXPRESS FIELD RIDER MULTI-STOP EXECUTION QUEUE            │
│  [Task 1] Collect Bag A from MedPlus (Life Camp)                       │
│  [Task 2] (If Multi-Stop) Collect Bag B from H-Medix (Wuse 2)          │
│  [Task 3] Deliver Consolidated Consignment to Patient Doorstep (e-POD) │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Pharmacy Premise Registration & Location Capture (ComfortCare)

When a retail pharmacy registers on ComfortCare, their exact physical location and licensing are verified and indexed:

### Captured Pharmacy Metadata:
1. **Legal & Trade Name:** (e.g., *MedPlus Pharmacy Ltd - Life Camp Branch*)
2. **Physical Street Address:** (e.g., *Suite 4, Life Camp Commercial Complex*)
3. **Geographical Granularity:** State (*FCT*), City (*Abuja*), LGA (*AMAC*), Landmark (*Near Life Camp Roundabout*).
4. **Geo-Coordinates:** Latitude & Longitude for radius calculations.
5. **Premise Regulatory License:** PCN (Pharmacists Council of Nigeria) Premise Registration Number.
6. **Direct Dispatch Lines:** Pharmacist-in-Charge Phone and active **WhatsApp line** for rider dispatch updates.

---

## 3. The Multi-Pickup Sourcing Engine & Pricing Rules

### 3.1. Sourcing Logic
When a cart containing $N$ items is submitted:
* **Step 1 (Proximity Search):** The system searches for active registered pharmacies within a 10km radius of the patient's delivery address.
* **Step 2 (Item Match):**
  * If Pharmacy $A$ has 100% of the cart items $\rightarrow$ **1 Pickup Stop**.
  * If Pharmacy $A$ has Item 1, and Pharmacy $B$ has Item 2 $\rightarrow$ **2 Pickup Stops**.
  * The algorithm always selects the minimum number of pharmacies to minimize extra pickup fees for the patient.

### 3.2. Sourcing Pricing Matrix
```
┌─────────────────────────────────┬─────────────────┬──────────────────┬─────────────────┐
│ SOURCING SCENARIO               │ PICKUP STOPS    │ EXTRA PICKUP FEE │ TOTAL LOGISTICS │
├─────────────────────────────────┼─────────────────┼──────────────────┼─────────────────┤
│ Single Pharmacy (100% in stock) │ 1 Pharmacy Stop │ ₦0.00            │ ₦3,500.00       │
│ Dual Pharmacy Split             │ 2 Pharmacy Stops│ +₦1,500.00       │ ₦5,000.00       │
│ Triple Pharmacy Split           │ 3 Pharmacy Stops│ +₦3,000.00       │ ₦6,500.00       │
└─────────────────────────────────┴─────────────────┴──────────────────┴─────────────────┘
```

* **Formula:** $\text{Total Logistics Fee} = \text{Base Flat Rate (₦3,500)} + \left[(\text{Pickup Stops} - 1) \times ₦1,500\right]$

---

## 4. Inbound B2B REST API Specification for NovaExpress

NovaExpress receives this order via an authenticated HTTP POST request. The payload provides the complete multi-stop pickup itinerary:

### Request Headers
```http
POST /functions/v1/ingest-client-package HTTP/1.1
Host: api.novaexpress.ng
Authorization: Bearer nx_live_comfortcare_sec_994821049
X-Client-Id: comfortcare-abuja-01
Content-Type: application/json
```

### Complete Multi-Stop JSON Request Payload Schema
```json
{
  "client_id": "comfortcare-abuja-01",
  "client_name": "ComfortCare Health & Pharmacy Ltd",
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
      "pharmacy_id": "ph-medplus-lifecamp",
      "pharmacy_name": "MedPlus Pharmacy (Life Camp Branch)",
      "pickup_address": "Suite 4, Life Camp Commercial Complex, Life Camp, Abuja",
      "city": "Abuja",
      "state": "Federal Capital Territory",
      "lga": "Abuja Municipal (AMAC)",
      "landmark": "Near Life Camp Roundabout",
      "contact_person": "Pharm. Kenneth Okafor",
      "contact_phone": "+234 803 111 2233",
      "contact_whatsapp": "+234 803 111 2233",
      "drugs_to_collect": [
        "Coartem 80/480mg (x2)"
      ],
      "sealed_bag_ref": "BAG-CC-99014-A"
    },
    {
      "stop_number": 2,
      "pharmacy_id": "ph-hmedix-wuse",
      "pharmacy_name": "H-Medix Pharmacy (Wuse 2 Branch)",
      "pickup_address": "Plot 42, Aminu Kano Crescent, Wuse 2, Abuja",
      "city": "Abuja",
      "state": "Federal Capital Territory",
      "lga": "Abuja Municipal (AMAC)",
      "landmark": "Opposite Banex Plaza Corridor",
      "contact_person": "Pharm. Fatima Bello",
      "contact_phone": "+234 802 444 5566",
      "contact_whatsapp": "+234 802 444 5566",
      "drugs_to_collect": [
        "Augmentin 625mg (x1)"
      ],
      "sealed_bag_ref": "BAG-CC-99014-B"
    }
  ],
  "receiver": {
    "name": "Dr. Farouk Al-Mansur",
    "phone_number": "+234 803 265 1505",
    "whatsapp_number": "+234 803 265 1505",
    "location": {
      "full_address": "Plot 1044, Adetokunbo Ademola Crescent, Wuse 2, Abuja",
      "city": "Abuja",
      "state": "Federal Capital Territory",
      "lga": "Abuja Municipal (AMAC)",
      "landmark": "Near Life Camp Roundabout / Wuse 2 Corridor"
    }
  },
  "package_contents": [
    {
      "drug_id": "prod-coartem-80-480",
      "drug_name": "Coartem 80/480mg",
      "quantity": 2,
      "unit_price": 3850.0,
      "total_line_amount": 7700.0,
      "requires_cold_chain": false,
      "assigned_pharmacy_id": "ph-medplus-lifecamp",
      "assigned_pharmacy_name": "MedPlus Pharmacy (Life Camp Branch)",
      "sealed_bag_ref": "BAG-CC-99014-A"
    },
    {
      "drug_id": "prod-augmentin-625",
      "drug_name": "Augmentin 625mg",
      "quantity": 1,
      "unit_price": 6500.0,
      "total_line_amount": 6500.0,
      "requires_cold_chain": false,
      "assigned_pharmacy_id": "ph-hmedix-wuse",
      "assigned_pharmacy_name": "H-Medix Pharmacy (Wuse 2 Branch)",
      "sealed_bag_ref": "BAG-CC-99014-B"
    }
  ],
  "payment_receipt": {
    "gateway": "Paystack Instant Settlement",
    "receipt_number": "CC-PAYSTACK-99014",
    "transaction_reference": "CC-TXN-8492048",
    "amount_paid": 19200.0,
    "medication_subtotal": 14200.0,
    "base_logistics_fee": 3500.0,
    "additional_pickup_fee": 1500.0,
    "total_logistics_fee": 5000.0,
    "pickup_stops_count": 2,
    "currency": "NGN",
    "payment_status": "prepaid",
    "verified_at": "2026-10-10T17:50:00.000Z"
  },
  "other_details": {
    "fulfillment_mode": "client_package",
    "sourcing_model": "decentralized_community_pharmacy_network",
    "delivery_notes": "Deliver to Clinic Front Desk, Gate 2. Clinical parcel seal."
  }
}
```

### Response from NovaExpress (HTTP 201 Created)
```json
{
  "success": true,
  "order_reference": "CC-99014",
  "tracking_number": "NOV-2026-9901",
  "assigned_dc": "Wuse Central Distribution Hub",
  "assigned_rider": "Rider Ibrahim",
  "rider_phone": "+234 812 345 6789",
  "pickup_stops_count": 2,
  "additional_pickup_fee": 1500.0,
  "total_logistics_fee": 5000.0,
  "status": "pending_dispatch",
  "eta": "35 - 45 mins",
  "live_tracking_url": "https://novaexpress.ng/track/NOV-2026-9901"
}
```

---

## 5. Execution in NovaExpress: The Multi-Stop Chain of Custody

When NovaExpress receives a multi-pickup order:

1. **Rider Route Manifest:**
   The NovaExpress Rider App displays a sequential **3-Stop Task Queue**:
   * **Task 1 (Pickup 1):** Ride to *MedPlus Life Camp* $\rightarrow$ Tap WhatsApp to alert pharmacist $\rightarrow$ Collect sealed bag `BAG-CC-99014-A` $\rightarrow$ Mark Stop 1 Picked Up.
   * **Task 2 (Pickup 2):** Ride to *H-Medix Wuse* $\rightarrow$ Collect sealed bag `BAG-CC-99014-B` $\rightarrow$ Mark Stop 2 Picked Up.
   * **Task 3 (Final Delivery):** Ride to *Dr. Farouk, Wuse 2* $\rightarrow$ Hand over both sealed clinical bags $\rightarrow$ Collect recipient signature & OTP e-POD $\rightarrow$ Order Complete!

2. **Rider Financial Compensation:**
   * Standard single-stop rider entitlement: **₦1,800.00**.
   * Additional pickup allowance credited to rider: **+₦1,000.00**.
   * **Total Rider Payout:** **₦2,800.00**.
   * **NovaExpress Net Platform Margin:** ₦5,000.00 - ₦2,800.00 = **₦2,200.00 (44% Net Margin)**.

---

## 6. Mutual Benefits for All Stakeholders

| Stakeholder | How it Works | Direct Business Advantage |
| :--- | :--- | :--- |
| **NovaExpress** | • Receives pre-paid multi-stop delivery jobs via automated API.<br/>• Higher earnings per trip (₦5,000 vs ₦3,500). | • **Massive revenue uplift** without operating warehouses.<br/>• **Higher rider satisfaction** with extra multi-pickup bonuses.<br/>• **Zero cash collection risk** (prepaid on gateway). |
| **ComfortCare** | • Zero capital expenditure on warehouses or dead stock.<br/>• Every registered pharmacy acts as a micro-fulfillment center. | • **100% product availability:** If one pharmacy is out of stock, the order is fulfilled across two pharmacies seamlessly.<br/>• **Guaranteed pharmaceutical SLAs.** |
| **Community Pharmacies** | • Receive order alerts on their console: `Pack Bag BAG-CC-99014-A`.<br/>• NovaExpress rider arrives and picks up the pre-packaged bag. | • **High incremental retail footfall & revenue** without spending a Naira on customer acquisition.<br/>• No need to hire their own delivery riders. |
| **End Patients / Buyers** | • Transparent pricing at checkout.<br/>• Fast same-day doorstep delivery. | • **Never hear "Out of Stock":** Even rare multi-drug regimens are consolidated and delivered directly to their doorstep. |

---

## 7. Implementation Checklist for NovaExpress

1. **Deploy Inbound Webhook:** Deploy `ingest-client-package` Supabase Edge Function to parse `pickup_stops` array and `logistics_pricing`.
2. **Support Multi-Stop Routing in Rider App:** Display sequential stops (Pickup 1 $\rightarrow$ Pickup 2 $\rightarrow$ Final Delivery) with 1-tap WhatsApp buttons for both the pharmacists and the final recipient.
3. **Credit Rider Multi-Pickup Allowance:** Automatically add ₦1,000 to rider wallet for every extra pickup stop completed.

This documentation serves as the blueprint for connecting the decentralized pharmacy network with NovaExpress's last-mile fleet.
