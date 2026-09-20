# Phase 6: Expanded Merchant Executive Dashboard Specification

**Module:** Merchant Operations Hub & Executive Telemetry  
**Target Files:**  
- `lib/features/client_portal/presentation/pages/client_dashboard_page.dart`
- `lib/features/client_portal/presentation/providers/client_portal_provider.dart`

---

### 1. Architectural Vision

The Merchant Dashboard (`ClientDashboardPage`) must serve as an all-inclusive executive cockpit for business owners. With the introduction of landed costs, multi-hub inventory custody, supplier lead times, and package deal pricing, the dashboard must synthesize:
1. **Financial Health**: Live COD cash collected in DC vaults vs. daily bank settlement pipeline.
2. **Physical Asset Custody**: Total inventory units on hand and consolidated landed stock valuation across all regional distribution centers.
3. **Operational Inventory Alerts**: Real-time warnings when SKUs approach reorder thresholds, calculating replenishment urgency based on supplier lead times.
4. **Commercial Velocity**: Fast-moving package deals, unit economics, and gross margins.

---

### 2. Upgraded Dashboard Layout & Sections

```
┌────────────────────────────────────────────────────────────────────────┐
│  [Merchant Banner] Novacare Health & Wellness Ltd (CLI-NOVACARE)      │
│  Managing Director: Dr. Chuke Okafor • Abuja, FCT                      │
│  [ + Create Order ]  [ + Stock Intake ]  [ 📦 View Inventory ]         │
└────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────┐
│  ⚡ CRITICAL STOCK REORDER BANNER (Dynamic - only when low stock <= 10) │
│  ⚠️ Ura Clear Tea has dropped to 8 units in Ibadan Depot (7d Lead)     │
│  [ Contact Apex Labs via WhatsApp ]    [ + Raise Stock Intake Bill ]   │
└────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────┐
│  💵 Live Cash Accumulator & Settlement Pipeline (10:00 PM Batch)       │
│  Expected Settlement: ₦384,005  |  Gross COD: ₦442,500  |  Fees: -₦58k │
└────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────┐  ┌───────────────────────────┐
│ 📦 Total Inventory Value   │  │ 🏭 Physical Stock On Hand  │
│ ₦345,420,000              │  │ 18,450 units              │
│ 6 Regional Warehouses     │  │ Across 32 Stock Positions │
└───────────────────────────┘  └───────────────────────────┘
┌───────────────────────────┐  ┌───────────────────────────┐
│ 🚚 Active Dispatches      │  │ ✅ Delivered Value Today   │
│ 17 Shipments (3 Pending)  │  │ ₦599,500 (14 Completed)   │
│ 100% On-Time Delivery     │  │ Direct Cash / COD Remitted│
└───────────────────────────┘  └───────────────────────────┘

┌────────────────────────────────────────────────────────────────────────┐
│  📦 Package Deals Commercial Performance & Run-Rate Velocity           │
│  • Respira Lung Tea (4 Boxes + 1 Free @ ₦55,000): 42 sold this week    │
│  • Grazer Detox Tea (3 Boxes @ ₦45,000): 31 sold this week             │
│  • Oravita Capsules (2 Boxes @ ₦35,000): 19 sold this week             │
└────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────┐
│  🚚 Real-Time Order & Transit Pipeline                                  │
│  [Order Cards with Status Badges, Customer, Hub, Payment, and Chat]    │
└────────────────────────────────────────────────────────────────────────┘
```

---

### 3. Key Components & Implementation Details

#### 3.1. Physical Inventory & Asset Valuation Card
- Computes total network stock valuation dynamically:
  ```dart
  final totalValuation = state.stockBalances.fold(0.0, (sum, b) => sum + b.balanceValue);
  final totalUnits = state.stockBalances.fold(0.0, (sum, b) => sum + b.balanceQty).toInt();
  final activeWarehousesCount = state.stockBalances.map((b) => b.warehouse).toSet().length;
  ```
- Renders rich metric cards with emerald/sapphire gradients and a shortcut button to the **Stock Ledger**.

#### 3.2. Proactive Low-Stock & Replenishment Alert Banner
- Scans `state.products` and `state.stockBalances`:
  ```dart
  final lowStockItems = state.stockBalances.where((b) => b.balanceQty <= 15).toList();
  ```
- If any item is low:
  - Identifies the preferred supplier and lead time from `state.suppliers`.
  - Renders a warning alert with:
    - **"Contact Vendor"** (opens WhatsApp or Phone dialer).
    - **"Raise Intake Bill"** (opens `ClientRaiseStockInvoiceModal` pre-populated with that product and supplier).

#### 3.3. Package Deal Velocity Card
- Showcases the merchant's configured bundles and their retail price points:
  - 1 Box = ₦21,500
  - 2 Boxes = ₦35,000
  - 3 Boxes = ₦45,000
  - 4 Boxes + 1 Free = ₦55,000
- Shows physical unit depletion rate (e.g. 5 physical units depleted per bundle sold).
