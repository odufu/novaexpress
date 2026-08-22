# 📦 Client Package On-Demand Dispatch App (P2P PRD)

**Document Type:** On-Demand Customer Product Requirements Document (PRD)  
**Product:** NovaExpress On-Demand Package Delivery ("NovaDrop")  
**Target Audience:** Direct Consumers, Social Commerce Vendors (Instagram/WhatsApp sellers), Corporate Offices, Boutiques  
**Market:** Nigeria (NGN ₦)

---

## 1. Executive Summary

While the **Distributed Inventory model** caters to merchants warehousing bulk stock in DCs, the **Client Package On-Demand model** caters to senders who have a physical parcel in hand and need an active, nearby NovaExpress Rider/PDA immediately dispatched for instant pickup and same-day delivery.

---

## 2. User Experience & Trip Flow

```
[Sender opens App]
       │
       ▼
[Set Pickup & Dropoff GPS Locations]
       │
       ▼
[Instant Dynamic Fare Estimation (₦ Base + ₦/KM + Insurance)]
       │
       ▼
[Tap "Request Rider Now"]
       │
       ▼
[Proximity Radar Matches Nearest Available PDA within 5km]
       │
       ▼
[Rider Accepts & Arrives for Pickup]
       │
       ▼
[Digital Waybill Barcode Scanned] ──▶ [Live Turn-by-Turn GPS Tracking]
                                                    │
                                                    ▼
                                     [Recipient Sign-off & POD Photo]
```

---

## 3. Core Features & Functional Specifications

### 3.1. 1-Tap Rider Discovery & Spatial Radar
- Uses the NovaExpress GIS Proximity engine (`find_closest_available_rider`) to discover on-duty riders within the sender's vicinity.
- Displays realistic Rider ETA (e.g., *"Emeka Rider (Bajaj Boxer) is 4 mins away"*).

### 3.2. Dynamic Fare Matrix
$$\text{Trip Fare} = \text{Base Pickup Fee (₦1,200)} + (\text{Distance in KM} \times \text{₦180/km}) + \text{Item Insurance (1\% of Declared Value)}$$

### 3.3. Payment & Escrow Options
- **Sender Prepaid**: Card payment or In-App Wallet balance.
- **Pay on Pickup**: Cash or POS to the pickup rider.
- **Recipient Pay on Delivery (COD)**: Recipient pays the delivery fee upon parcel arrival.

### 3.4. Contactless POD & Digital Waybill
- Generates a scannable **Digital Waybill (NX-P2P-XXXXX)**.
- Recipient provides signature on the rider's PDA touchscreen or confirms an SMS 4-digit security PIN.
- Instant delivery receipt sent via WhatsApp/SMS to both sender and recipient.

---

## 4. Operational Controls for Distribution Centers

- **Spillover Routing**: If all local on-demand riders are busy, the trip seamlessly cascades to the nearest Distribution Center supervisor to assign an in-house fleet driver.
- **Rider Custody Tracking**: The package is registered in the rider's custody until confirmed by recipient POD signature.
