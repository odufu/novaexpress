# NovaXpress Logistics Platform — Active Login Credentials

> **Current Environment Status**: Clean Slate Initialized  
> All mock transactional data, test clients, dummy products, and fake couriers have been purged from the Supabase database. Only the authentic **Grand Distribution Center (HQ Logistics)** is active for end-to-end operational testing.

---

## 🏢 Grand Distribution Center (HQ Operations)

| Credential Field | Value | Notes |
| :--- | :--- | :--- |
| **Login Portal URL** | `/login` | Multi-Tenant Unified Sign-In |
| **Primary Email** | `dc.supervisor@novaxpress.ng` | Corporate login identifier |
| **Legacy Alias Email** | `dc.supervisor@novaexpress.ng` | Supported alternate alias |
| **Password** | `Password123!` | Standard testing password |
| **Account Name** | Ahmed Bello | Operations Supervisor |
| **Role Key** | `dc_manager` | Distribution Center Operations Lead |
| **Designated Console** | `/dc` | Automatically routed upon successful sign-in |
| **Assigned Distribution Center** | Wuse Grand Central Hub | Code: `DC-WUSE-01` |
| **Distribution Center ID** | `22222222-2222-4222-8222-222222222222` | Live Supabase UUID |
| **Company / Organization** | NovaXpress Logistics HQ | ID: `11111111-1111-4111-8111-111111111111` |
| **Territory / City** | Abuja, Federal Capital Territory | Headquarters Operational Zone |

---

## 🔐 Sign-In Instructions for DC Personnel

1. **Navigate to the Login Screen**: Open the web application at the root or `/login`.
2. **Manual Credential Entry**:
   * **Account Email or Agent ID**: `dc.supervisor@novaxpress.ng`
   * **Password**: `Password123!`
   *(Note: Automatic pre-filling and demo bypasses have been disabled. The form requires manual entry).*
3. **Submit**: Click **"Sign In to Assigned Workspace"**.
4. **Console Access**: The security router verifies the `dc_manager` role and automatically redirects to the **Grand DC Logistics Control Tower** (`/dc`).

---

## 🎯 Key Features Ready for Testing in the Grand DC Console

* **Distribution Center Selector**:
  * **`🌐 All Distribution Centers (Cumulative Network Control Tower)`**: Aggregates enterprise-wide logistics revenue, total vault inventory, fleet cash custody, and displays the **Regional Hub Matrix**.
  * **`🏢 Wuse Grand Central Distribution Center`**: Scopes all 8 KPIs, vault stock, cash in fleet custody, and driver manifests strictly to the Wuse Hub.
* **Inline Timeframe Filters**: Toggle between `Today`, `7D`, `30D`, `This Month`, `All Time`, and `Custom Range`.
* **Station OpEx Recording**: Click **`+ Record Station OpEx`** to log station diesel fuel, hub equipment maintenance, or facility rent directly to the DC ledger.
* **Fleet Management**: Click **`+ Onboard Rider`** to provision new delivery agents and view live driver manifests.
* **Network Radar Telemetry**: Real-time Abuja and regional transit node visualization.

---

## ⚙️ Backend Connectivity Reference

* **Supabase Project ID**: `oygtaeriljuelhshfvkv`
* **Public User ID**: `a2222222-2222-4222-8222-222222222222`
* **RPC Endpoint**: `public.fn_get_dc_logistics_dashboard`
