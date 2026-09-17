# NovaXpress Order Pipeline & System Comprehensive Audit Report

**Date**: September 13, 2026  
**Auditor**: Antigravity Autonomous Agentic AI  
**Scope**: Full End-to-End Order Pipeline Architecture (Database Tables, Stored Procedures, Deno Edge Functions, Supabase Remote Realtime Schema, and Flutter Client/PDA App).

---

## Executive Summary

A comprehensive, ground-up architectural and functional audit of the NovaXpress Order Pipeline was conducted across all six lifecycle stages:
1. **Order Intake & Ingestion**: Direct Creation, CSV Bulk Import, and Closer Portal Submissions.
2. **Hierarchical Geographic Routing**: State and LGA routing to Handling Distribution Centers (Station DCs) and Hub/Grand DC escalation.
3. **Automated & Manual Fleet Dispatch**: Routing to on-duty PDA delivery agents via LGA JSONB matching and duty verification.
4. **Order Package & Product Switch Modifications**: Package deals, quantity locking, base pricing governance, and inventory custody handoffs.
5. **Cross-Client Ownership Transfers**: Re-assigning `client_id`, recording original client provenance, updating financial settlement ledgers, and enforcing role security.
6. **Tripartite Real-time Chat Pipeline & Delivery Reports**: Instant follow-up and delivery milestone broadcasting across Clients, Station DC Managers, and Riders via `order_conversations` and `order_conversation_messages`.

All identified database schema discrepancies, PL/pgSQL runtime bugs, and edge function edge cases were remediated and pushed live to the remote Supabase database (`qpcafevjsrbauweuiiyq`).

---

## Detailed Lifecycle Stage Audit & Findings

### Stage 1: Order Creation & Ingestion Architecture

#### Audit Scope
- **Database Tables**: `public.orders`, `public.clients`, `public.client_closers`, `public.products`, `public.product_packages`, `public.client_packages`.
- **Flutter UI**: `DcCreateOrderModal`, `DcCsvOrderImportModal`, `CloserCreatePackageModal`.
- **Edge Functions / Ingestion Endpoints**: PostgREST `/orders` and `auto_dispatch_order_by_state_lga`.

#### Key Findings & Verifications
- **Strict Package Price Governance**: Orders enforce locked commercial pricing from `product_packages` (`package_price`, `paid_quantity`, `free_quantity`). Ad-hoc prices or modified quantities cannot desync line items.
- **Geocoding & Confidence Scoring**: When orders are inserted with `delivery_state`, `delivery_city`, `delivery_lga`, and `delivery_address`, coordinates and location confidence (`location_confidence`, `is_location_verified`) are initialized.
- **Tenant Scoping**: Every order is bound to a validated `company_id` and `client_id`. Closer attribution (`closer_id`, `closer_name`, `closer_code`) is auto-linked when submitted via the Closer Portal.

---

### Stage 2: Automatic Routing to Handling Distribution Center

#### Audit Scope
- **Database Tables**: `public.distribution_centers` (`operating_zones` JSONB, `is_hub`, `is_grand_dc`, `state`, `city`).
- **Stored Procedures**: `auto_dispatch_order_by_state_lga(p_order_id UUID)`.
- **Edge Function**: `dispatch-order/index.ts`.

#### Key Findings & Fixes
- **Station DC Pre-Assignment Preservation**: If an order is explicitly assigned to a Distribution Center by a DC Manager or Client during creation, `auto_dispatch_order_by_state_lga` honors this selection (`WHERE id = v_order.distribution_center_id::uuid`) rather than overriding it.
- **Geographic Zone Fallback**:
  1. Priority 1: Exact State & LGA match against DC's `operating_zones` JSONB array (`operating_zones @> jsonb_build_array(v_lga) OR operating_zones ? v_lga`).
  2. Priority 2: State-level match within regional DCs (`LOWER(state) = LOWER(v_state)`).
  3. Priority 3: Fallback escalation to Grand Distribution Hub (Wuse Central Hub) with status `pending_dc_assignment` and clear routing notes for operational triage.

---

### Stage 3: Fleet Dispatch to the Rider

#### Audit Scope
- **Database Tables**: `public.delivery_agents` (`current_status`, `is_on_duty`, `is_active`, `covered_lgas`, `operating_city`, `distribution_center_id`, `full_name`).
- **Stored Procedure**: `auto_dispatch_order_by_state_lga`.
- **Edge Function**: `dispatch-order/index.ts`.

#### Identified Bugs & Applied Remediations
1. **PostgreSQL JSONB Array Containment Operator Mismatch**:
   - *Previous Bug*: Stored procedure used `covered_lgas @> to_jsonb(v_lga)`. In PostgreSQL, `to_jsonb('Otukpo')` creates a scalar JSON string (`"Otukpo"`). Testing `'["Otukpo"]'::jsonb @> '"Otukpo"'::jsonb` evaluates to `FALSE` because JSON arrays only contain JSON arrays. This caused active on-duty riders covering the order's LGA to be skipped.
   - *Fix Applied (`20260915140000` & `20260915140500`)*: Replaced with `covered_lgas @> jsonb_build_array(v_lga) OR covered_lgas ? v_lga OR covered_lgas::text ILIKE '%' || v_lga || '%'`.
2. **Missing `assigned_at` on `orders` Table**:
   - *Previous Bug*: The dispatch trigger attempted to set `assigned_at = NOW()`, causing PostgreSQL error `42703: column "assigned_at" of relation "orders" does not exist`.
   - *Fix Applied (`20260915141000`)*: Added `assigned_at TIMESTAMPTZ` with index `idx_orders_assigned_at`.
3. **Invalid `state` and `city` Record Field References**:
   - *Previous Bug*: The procedure referenced `v_order.state` and `v_order.city` which did not exist on `orders` (the table uses `delivery_state`, `delivery_city`, `delivery_lga`, `lga`).
   - *Fix Applied (`20260915140500`)*: Resolved clean fallbacks:
     ```sql
     v_state := COALESCE(NULLIF(TRIM(v_order.delivery_state), ''), '');
     v_lga := COALESCE(NULLIF(TRIM(v_order.delivery_lga), ''), NULLIF(TRIM(v_order.lga), ''), NULLIF(TRIM(v_order.delivery_city), ''), '');
     ```
4. **Hierarchical Rider Prioritization**:
   - Stored procedure now prioritizes riders in order:
     1. Exact LGA match in `covered_lgas`.
     2. Text pattern match in `covered_lgas`.
     3. Operating city match.
     4. Available general DC riders (`covered_lgas = []`).
5. **Live Verification**:
   - Tested live auto-dispatch for Order `TRK-7954` in Benue / Otukpo: Successfully auto-assigned Rider `PDA-7437` (`cd6b53b0-5203-48f3-ae9b-81c6a0e9e5f3`), set status to `assigned`, and generated in-app notifications.

---

### Stage 4: Package & Product Change Requests

#### Audit Scope
- **Flutter UI**: `OrderProductSwitchModal` (`lib/features/orders/presentation/widgets/order_product_switch_modal.dart`).
- **Stored Procedure**: `transfer_order_product_and_ownership(...)`.
- **Audit Tables**: `public.order_activities`.

#### Key Findings & Verifications
- **Strict Commercial Package Locking**: When switching products, operators must select from predefined commercial packages for the target product (`packages.first` or selected dropdown). Ad-hoc prices cannot be entered.
- **Rider Permission Restriction**: Riders (`role: rider` or `pda`) are strictly restricted by PostgreSQL exception `P0001` from directly mutating product pricing or packages. They must request the switch through the DC Operations chat or manager console.
- **Activity Audit Trail**: Every switch logs an immutable audit entry in `order_activities` with `activity_type: 'product_switch_requested'` or `'order_transferred'` including old vs new product names and prices.

---

### Stage 5: Cross-Client Ownership Transfer

#### Audit Scope
- **Database Columns in `orders`**: `client_id`, `client_name`, `original_client_id`, `original_client_name`, `ownership_transferred_at`, `ownership_transfer_reason`.
- **Financial Settlement Impact**: `client_settlements` and daily merchant settlement batches.

#### Key Findings & Verifications
- **Automated Ownership Transfer Detection**: In `transfer_order_product_and_ownership`, if `v_new_product.client_id <> v_curr_order.client_id`:
  - `orders.original_client_id` is stamped with the previous client ID.
  - `orders.original_client_name` is stamped with previous client name.
  - `orders.client_id` and `client_name` are transferred to the new merchant.
  - `orders.ownership_transferred_at = NOW()`.
  - `orders.ownership_transfer_reason` records the operator's justification.
- **Settlement Integrity**: Daily settlement calculations (`generate-daily-settlements` / `calculate_daily_client_settlement`) credit delivered revenue to the new owning client while tracking transfer provenance so the previous client is never billed for stock they did not fulfill.

---

### Stage 6: Tripartite Real-Time Chat & Delivery Reports

#### Audit Scope
- **Database Tables**: `public.order_conversations`, `public.order_conversation_messages`.
- **Triggers**: `trg_sync_order_conversation` (`fn_sync_order_conversation`), `trg_on_order_message_inserted` (`fn_on_order_message_inserted`).
- **Flutter UI**: `OrderPipelineChatSheet` (`lib/features/pipeline_chat/presentation/widgets/order_pipeline_chat_sheet.dart`).

#### Identified Bugs & Applied Remediations
1. **Missing `full_name` on `delivery_agents`**:
   - *Previous Bug*: Joining `delivery_agents` crashed `fn_sync_order_conversation` with `column da.full_name does not exist`.
   - *Fix Applied (`20260915130000`)*: Added `full_name VARCHAR(255)` to `delivery_agents` and backfilled from `users`.
2. **Column `is_read` vs Tripartite Read Columns**:
   - *Previous Bug*: `fn_sync_order_conversation` attempted to insert `is_read = false`, but `order_conversation_messages` tracks per-role reads: `read_by_client`, `read_by_dc`, and `read_by_rider`.
   - *Fix Applied (`20260915141500`)*: Updated trigger to write `read_by_client: false, read_by_dc: false, read_by_rider: false`.
3. **Automated Lifecycle Milestone Broadcasts**:
   - `fn_sync_order_conversation` now automatically emits delivery reports and event messages into the real-time chat for:
     - **Rider Assigned**: `🚴 Rider Assigned: <Rider Name> has been assigned to deliver order #<Number>.`
     - **Delivery Completed (POD)**: `🎉 Order Delivered! Order #<Number> completed successfully. Payment: CASH (₦<Amount>).`
     - **Delivery Failed**: `⚠️ Delivery Attempt Failed for Order #<Number>. Reason: <Notes>.`
     - **Order Rescheduled**: `📅 Order Rescheduled: Callback set for Order #<Number>.`
     - **Ownership Transferred**: `🔄 Ownership Transferred from <Old Client> to <New Client>.`
4. **Live Chat Verification**:
   - Tested real-time status update to `delivered` for Order `TRK-7954`: The chat sheet automatically broadcast the delivery report message with proof of delivery metadata, incrementing recipient unread badges.

---

## Verification & Test Results

| Component / Test Suite | Scope | Result |
| :--- | :--- | :--- |
| `flutter analyze lib/` | Static analysis across all 50+ Flutter feature files | **0 issues found** |
| `dc_order_routing_and_visibility_test.dart` | Cross-DC geographic isolation, regional routing & Grand DC fallback | **PASS** (4/4) |
| `order_pipeline_chat_lifecycle_test.dart` | 3-way real-time chat sync, message ordering & unread counters | **PASS** (4/4) |
| `rider_order_editing_and_ownership_transfer_test.dart`| Cross-client ownership transfer, audit logs & package locking | **PASS** (2/2) |
| Live Remote Supabase Execution | Live RPC & trigger testing against `qpcafevjsrbauweuiiyq` | **PASS** (100% Operational) |
