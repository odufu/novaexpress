# 🏢 Distributed Inventory Client-Facing Portal (Merchant PRD)

**Document Type:** Client Portal Product Requirements Document (PRD)  
**Product:** NovaExpress Merchant Admin & Telesales Platform  
**Target Audience:** E-Commerce Merchants, D2C Health/Beauty Brands, Telesales Confirmation Reps, Finance Officers  
**Market:** Nigeria (NGN ₦)

---

## 1. Executive Summary

Merchants using NovaExpress's **Distributed Inventory Fulfillment model** stock inventory in bulk across multiple regional Distribution Centers (e.g. Abuja DC, Lagos DC, Port Harcourt DC). 

This portal provides merchants with:
1. **A Telesales / Order Confirmation Call Center**: Where sales agents take unconfirmed web leads (Shopify, WooCommerce, ClickFunnels, landing page webhooks), call customers to confirm orders, refine delivery addresses and landmark hints, pitch upsells, and push confirmed orders directly to the nearest NovaExpress Distribution Center for same-day dispatch.
2. **A Business Intelligence & Executive Dashboard**: Where merchant business owners monitor sales velocity, delivery success rates (PODs), failed delivery root-causes, inventory stock levels across all DCs, and reconcile Cash-on-Delivery (COD) remittances against withdrawal balances.

---

## 2. User Roles & Permission Matrix

| Role | Permissions & Operational Scope |
|---|---|
| **Client Owner / Super Admin** | Full access to business metrics, SKU pricing, bank account settings, withdrawal requests, multi-DC stock audit, and user invitation (Admins, Telesales). |
| **Telesales Agent (`sales_agent`)** | Access to **Leads Inbox**, Call-to-Confirm modal, address refinement, upsell selector, and "Push to DC Fulfillment" action. Cannot view bank payout accounts or profit margins. |
| **Inventory Manager (`inventory_manager`)** | Manages SKU definitions, product batches, restock requisitions to NovaExpress DCs, and monitors in-transit stock vs. DC shelf stock. |
| **Finance Auditor (`finance_auditor`)** | Views COD remittance ledgers, delivery fee deductions, return fees, and generates financial settlement statements. |

---

## 3. Key Operational Workflows

### 3.1. Lead Inflow & Telesales Call-to-Confirm Workflow

```
Landing Page Webhook ──▶ [Sales Leads Inbox]
                                │
                                ▼
                       (Sales Agent Dial-In)
                                │
          ┌─────────────────────┴─────────────────────┐
          ▼                                           ▼
[Customer Confirmed]                         [Customer Cancelled / Fake]
  • Confirm Address & Landmark hints           • Tag reason (Fake, Price objection)
  • Select Package / Inject Upsell             • Archive lead
  • Choose Payment: POD Cash vs Transfer
          │
          ▼
[1-Tap "Push to DC Fulfillment"]
          │
          ▼
(Instantly queued in local DC Unassigned Pool)
```

#### Order Confirmation Screen Capabilities:
- **Nigerian Landmark Refinement**: Synthesizes unstructured addresses into canonical geocoding format (e.g., *"Behind Total filling station, Wuse 2, Abuja"*).
- **Dynamic Upsell Engine**: Pitch extra units or complementary products (e.g., +1 Grazer Tea for +₦10,000) directly during the call.
- **Delivery Date Scheduler**: Select specific delivery date and customer delivery time window (e.g., Morning 9am-12pm).

---

### 3.2. Merchant Executive Analytics & Business Intelligence

The Client Admin dashboard provides real-time operational transparency:

1. **Delivery Success Metric (Velocity)**:
   $$\text{Success Rate} = \frac{\text{Total Delivered Orders (POD)}}{\text{Total Confirmed Dispatched Orders}} \times 100\%$$
2. **Failure Analysis Breakdown**:
   - Customer Rescheduled / Call-Back ($32\%$)
   - Unreachable / Phone Switched Off ($28\%$)
   - Customer Changed Mind / Out of Cash ($18\%$)
   - Wrong Address / Outside Coverage ($12\%$)
   - Delayed by Traffic / Logistics ($10\%$)
3. **Multi-DC Stock Radar**:
   - **Abuja Central DC**: 250 Units available (7 days of inventory).
   - **Lagos Island DC**: 45 Units remaining (**LOW STOCK ALERT - Restock Requisition Needed**).
   - **Port Harcourt DC**: 120 Units available.

---

### 3.3. Financial Settlements & COD Remittance Reconciliation

- **Gross COD Collected**: Total cash collected from customers by NovaExpress PDAs on behalf of the client.
- **Logistics Fee Deductions**: Automatically calculates agreed client delivery fees (e.g., ₦3,500/delivery) and return handling fees.
- **Net Merchant Wallet Balance**: Instant withdrawal to linked Nigerian bank accounts (Monnify / Paystack automated transfer).

---

## 4. API & Integration Webhooks

- **Shopify / WooCommerce / Custom Form Ingestion**:
  - `POST /api/v1/merchant/leads/webhook`
  - Accepts standard order payloads: `customer_name`, `phone`, `delivery_address`, `ordered_sku`, `utm_source`, `order_total`.
- **Order Status Callbacks**:
  - `order.dispatched`, `order.in_transit`, `order.delivered_pod`, `order.failed_rescheduled`, `order.cash_remitted`.
