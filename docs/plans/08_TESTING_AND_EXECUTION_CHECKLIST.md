# Testing, Verification & Execution Checklist

## 1. Overview

This document specifies the verification suites, automated test scripts, and regression benchmarks to validate the holistic system fix.

---

## 2. Automated Test Suites

### 2.1 Test 1: Order Pipeline Chat Lifecycle
- **File**: `test/order_pipeline_chat_lifecycle_test.dart`
- **Scenarios Tested**:
  1. Creating an order ensures a corresponding conversation row exists in `order_conversations`.
  2. Assigning a rider generates a `rider_assigned` milestone event message.
  3. Client, DC supervisor, and rider can send and receive messages with correct role badges.
  4. Parent conversation `last_message_text` and `last_message_at` update on every message.

### 2.2 Test 2: Rider Order Editing & Ownership Transfer
- **File**: `test/rider_order_editing_and_ownership_transfer_test.dart`
- **Scenarios Tested**:
  1. **Package Deal Upgrade**: Order upgraded to higher package deal -> verifies order amount recalculates, package ID updates, and milestone event is posted.
  2. **Cross-Merchant Product Switch**: Order product changed to a different merchant's product -> verifies:
     - `orders.client_id` transferred to new merchant.
     - `orders.original_client_id` records previous merchant.
     - `order_conversations.client_id` transferred to new merchant.
     - `ownership_transferred` system message posted.
     - COD remittance attribution shifts to new merchant.

### 2.3 Test 3: Zero-Hardcoding Regression Verification
- **Automated Regex Scan**:
  - Assert 0 occurrences of `'Novacale Limited'` and `'Novacare Limited'` fallback strings in `lib/`.
  - Assert 0 occurrences of `_createdOrders` static caching in `lib/features/orders/data/datasources/orders_remote_datasource.dart`.

### 2.4 Test 4: Compilation & Lint Health
- `flutter analyze lib/` must complete with **0 issues found**.

---

## 3. Step-by-Step Execution Sequence

| Phase | Milestone | Execution Steps | Verification Gate |
|---|---|---|---|
| **Phase 1** | **Rider Experience Integration** | 1. Add Chat button to `OrderDetailPage`.<br>2. Replace `UpsellSelectorModal` with `OrderProductSwitchModal`. | Visual check & interaction test |
| **Phase 2** | **Client Portal Chat Integration** | 1. Add Chat button to `ClientOrderTrackingModal`.<br>2. Add Chat action to `ClientOrdersPage`. | Visual check & interaction test |
| **Phase 3** | **Autonomous Package Deals** | Remove lines 605–616 in `product_catalog_provider.dart`. | Package deletion unit test |
| **Phase 4** | **Eradicate `_createdOrders` Cache** | Remove static list & all related loops in `orders_remote_datasource.dart`. | Database persistence test |
| **Phase 5** | **Zero-Hardcoding Sweep** | Line-by-line cleanups across all 12 remaining files. | Automated regex scan passes |
| **Phase 6** | **Automated Test Suites** | Write and execute `test/order_pipeline_chat_lifecycle_test.dart` and `test/rider_order_editing_and_ownership_transfer_test.dart`. | All tests pass |
