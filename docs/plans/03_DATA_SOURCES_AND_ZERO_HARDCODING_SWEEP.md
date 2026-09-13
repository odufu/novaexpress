# Core Data Sources & Zero-Hardcoding Sweep: Surgical Execution Plan

## 1. Overview

This document provides the line-by-line surgical execution instructions to:
1. Eradicate ephemeral static in-memory caching (`_createdOrders`) from `orders_remote_datasource.dart`.
2. Remove all 12 remaining occurrences of hardcoded demo fallback identities (`'Novacale Limited'`, `'Novacare Limited'`, `'Dr. Chuka Okafor'`, `'CLI-NOVACALE-01'`, `'08034455667'`, `'33333333-...'`).
3. Guarantee that all order, stock, and authentication operations read and write strictly to the live Supabase tables.

---

## 2. Datasource Layer Fixes

### 2.1 `lib/features/orders/data/datasources/orders_remote_datasource.dart`
- **Target Line 68**:
  - Remove `static final List<OrderModel> _createdOrders = [];`.
- **Target Lines 126–136**:
  - Remove the loop that iterates through `_createdOrders` and prepends them to the result list in `getAssignedOrders`.
- **Target Lines 313, 317, 318**:
  - Replace `'product_name': insertPayload['product_name']?.toString() ?? 'Respira Detox Tea'` with `insertPayload['product_name']?.toString() ?? 'Product'`.
  - Replace `'delivery_state': insertPayload['delivery_state']?.toString() ?? 'FCT - Abuja'` with `insertPayload['delivery_state']?.toString() ?? ''`.
  - Replace `'delivery_city': insertPayload['delivery_city']?.toString() ?? 'Abuja'` with `insertPayload['delivery_city']?.toString() ?? ''`.
- **Target Lines 431–437**:
  - Remove `_createdOrders.removeWhere(...)` and `_createdOrders.insert(...)` in `createOrder`.
- **Target Lines 512–518**:
  - Remove `_createdOrders` lookup loop in `getOrdersByDistributionCenter`.
- **Target Lines 607–613**:
  - Remove `_createdOrders` lookup loop in `getClientOrders`.
- **Target Lines 681–683**:
  - Remove `_createdOrders.removeWhere` in `acceptOrder`.
- **Target Lines 753–757**:
  - Remove `_createdOrders` loop in `updateOrderStatus`.
- **Target Lines 786–795**:
  - Remove `_createdOrders` loop in `getOrderById`.

### 2.2 `lib/features/auth/data/datasources/auth_remote_datasource.dart`
- **Target Lines 1378–1383**:
  - Replace `first_name = 'Merchant'`, `last_name = 'Admin'`, `delivery_agent_code = 'CLI-01'` with dynamic lookup of client contact person from `clients` table using `user.client_id`.
- **Target Lines 1387–1388 & 1415–1417**:
  - Replace `Adekunle Supervisor`, `Wuse Central Distribution Hub`, and hardcoded DC UUID `22222222-2222-4222-8222-222222222222` with dynamic lookup from `distribution_centers` table.
- **Target Lines 1421–1425**:
  - Replace hardcoded `Joel/Emeka Rider` and default DC ID with dynamic lookup from `delivery_agents` table using `user.delivery_agent_id`.

### 2.3 `lib/features/stock/data/datasources/stock_remote_datasource.dart`
- **Target Lines 465, 530, 602, 952**:
  - Replace `'Novacare Limited'` fallback strings with `oMap['client_name']?.toString() ?? json['owner_name']?.toString() ?? ''`.

---

## 3. Provider & Presentation Layer Zero-Hardcoding Fixes

### 3.1 `lib/features/client_portal/presentation/providers/client_portal_provider.dart`
- **Target Lines 476–489**:
  - In `ClientPortalNotifier` constructor, initialize `ClientPortalState.clientProfile` with empty strings:
    ```dart
    clientProfile: const ClientProfile(
      id: '',
      companyName: '',
      contactPerson: '',
      email: '',
      phone: '',
      address: '',
      city: '',
      state: '',
      code: '',
      tier: 'standard',
      closerLimit: 50,
      isEnterprise: false,
    ),
    ```
- **Target Lines 569–571**:
  - Remove `'33333333-3333-4333-8333-333333333333'` fallback for `clientId`. If `user?.clientId` is null, set `clientId = ''`.
  - Remove `'Novacale Limited'` fallback for `companyName`. If `user?.clientCompanyName` is null, set `companyName = user?.fullName ?? ''`.
- **Target Lines 594–597**:
  - Remove `if (clientOrders.isEmpty && isNovacale) { clientOrders = _generateSeedOrders(...); }`.
- **Target Lines 646, 666**:
  - Replace `(isNovacale ? 'Dr. Chuka Okafor' : 'Merchant Admin')` with `user?.fullName ?? ''`.

### 3.2 `lib/features/dc_console/presentation/providers/dc_console_provider.dart`
- **Target Lines 72–103**:
  - Remove `defaultRegisteredClients` static list containing Novacare and Novacale entries.
  - In `loadDistributionCenterData()`, if the database query returns clients, use them; otherwise, set `clients = []`.

### 3.3 `lib/features/dc_console/presentation/widgets/dc_create_order_modal.dart`
- **Target Lines 40–55**:
  - In `DCCreateOrderDraftState`:
    - `selectedProductName = ''` (was `'Grazer Tea'`)
    - `unitPrice = 0.0` (was `22000.0`)
    - `clientId = ''` (was `'cli-novacale-001'`)
    - `clientName = ''` (was `'Dr. Chuka Okafor'`)
    - `clientCompany = ''` (was `'Novacale Limited'`)
    - `clientPhone = ''` (was `'08034455667'`)
    - `clientEmail = ''` (was `'orders@novacale.com'`)

### 3.4 `lib/features/dc_console/presentation/widgets/dc_csv_order_import_modal.dart`
- **Target Lines 307–313**:
  - In CSV column parsing, remove default fallbacks `'Respira Detox Tea'` and `'Novacare Limited'`. Prompt validation error if client or product cannot be resolved from CSV.

### 3.5 `lib/features/dc_console/presentation/pages/dc_stock_page.dart`
- **Target Line 1132**:
  - Remove `final clientCtrl = TextEditingController(text: 'Novacare Limited');`. Initialize controller with empty text or selected client name.
- **Target Lines 1160–1166**:
  - Remove `companyMap['Novacare Limited']` hardcoding. Populate `companyMap` purely from registered clients.

### 3.6 `lib/features/dc_console/presentation/pages/dc_orders_page.dart`
- **Target Line 736**:
  - Replace `o.clientName.isNotEmpty ? o.clientName : 'Novacare'` with `o.clientName.isNotEmpty ? o.clientName : 'Unassigned Client'`.

### 3.7 `lib/features/dc_console/presentation/providers/product_catalog_provider.dart`
- **Target Lines 73, 93, 245, 534, 705**:
  - Replace `'Novacare Limited'` fallback strings with `prod?.clientName ?? ''` or required parameters.

### 3.8 `lib/features/stock/presentation/providers/stock_provider.dart`
- **Target Lines 511, 559**:
  - Replace `String ownerName = 'Novacare Limited'` with `String ownerName = ''`.

### 3.9 `lib/features/stock/domain/entities/rider_stock_allocation.dart`
- **Target Lines 26, 83**:
  - Replace `this.clientName = 'Novacare Limited'` with `this.clientName = ''` and `json['client_name']?.toString() ?? ''`.

### 3.10 `lib/features/orders/presentation/widgets/upsell_selector_modal.dart`
- **Target Lines 49, 65, 81**:
  - Replace all invocations with `OrderProductSwitchModal`.
