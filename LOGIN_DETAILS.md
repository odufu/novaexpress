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

## 📱 Distribution Center Operations Department (Strictly Mobile)

| Credential Field | Value | Notes |
| :--- | :--- | :--- |
| **Login Portal URL** | `/login` | Mobile Web or Android App |
| **Primary Email** | `abigail@novaxpress.ng` | Live Onboarded Operations Officer |
| **Password** | `bG5y2mZdrW` | Dedicated Officer Password |
| **Account Name** | Abigail Operations | Incoming Order Routing & Dispatch Officer |
| **Staff Code** | `OPS-WUSE-01-748` | Official badge code |
| **Role Key** | `dc_operations` | Operations Staff |
| **Designated Portal** | `/ops` | **Strictly Mobile Portal** (Automatically routed upon sign-in) |
| **Assigned Distribution Center** | Wuse Grand Central Hub | Scoped to: `22222222-2222-4222-8222-222222222222` |
| **Operational Scope** | Live Order Dispatch & Routing | Scoped strictly to Wuse DC orders & riders |

### Additional Demo Officer:
| Credential Field | Value | Notes |
| :--- | :--- | :--- |
| **Email** | `ops.wuse@novaxpress.ng` | Demo Operations Officer |
| **Password** | `Password123!` | Standard password |
| **Account Name** | Ibrahim Garba | Operations & Dispatch Officer (`OPS-WUSE-01`) |

### Operations Officer Capabilities:
1. **Live DC Orders**: View live incoming orders targeting their assigned DC only.
2. **Dispatch to Available Riders**: Assign unrouted orders to active riders registered at this DC, with rider stock custody validation and active order load balancing.
3. **Reroute across DCs**: Transfer misrouted orders to another distribution center with notes.
4. **Order Pipeline Chat**: Communicate directly with merchant closers and supervisors on any order.
5. **Zero Financial Access**: Strict security isolation from DC ledger, cash vaults, payouts, or settings.

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

---

## 📱 Mobile APK for Field Testing (Sales Reps / Riders / Station Agents)

* **Root APK Location**: [`NovaXpress-Release.apk`](file:///c:/PROJECT/NoveXPS/NovaXpress-Release.apk)
* **Build Artifact Location**: [`build/app/outputs/flutter-apk/app-release.apk`](file:///c:/PROJECT/NoveXPS/build/app/outputs/flutter-apk/app-release.apk)
* **File Size**: ~111.9 MB
* **App Label**: `NovaXpress`
* **Compatibility**: Android 5.0+ (ARM64 & ARMv7 devices)
* **Permissions Included**: Internet, Network State, Camera (for receipt & proof intake), Geo/Map Navigation, WhatsApp integration.

### How to Install on Sales Rep Phones:
1. Send `NovaXpress-Release.apk` to the phone via USB cable, Google Drive, WhatsApp, or Telegram.
2. Open the file on the phone and tap **Install** (enable "Allow from this source" if prompted by Android security).
3. Open the app, and log in with the designated field account or DC supervisor credentials.

