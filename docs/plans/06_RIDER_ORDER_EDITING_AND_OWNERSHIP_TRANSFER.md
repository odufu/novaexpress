# Rider Order Editing & Dynamic Ownership Transfer: Integration Plan

## 1. Overview & Verification

This document specifies the exact integration of the **Rider Order Product/Package Editing & Ownership Transfer** feature into the active rider mobile workflow.

- **Stored Procedure**: `transfer_order_product_and_ownership` (PostgreSQL RPC) is already **active and live** in the remote Supabase database.
- **UI Modal**: `OrderProductSwitchModal` is implemented in `lib/features/orders/presentation/widgets/order_product_switch_modal.dart`.
- **Target File**: `lib/features/orders/presentation/pages/order_detail_page.dart`.

---

## 2. Integration into `OrderDetailPage`

### 2.1 Imports
Add the following imports to `lib/features/orders/presentation/pages/order_detail_page.dart`:
```dart
import '../widgets/order_product_switch_modal.dart';
import '../../../pipeline_chat/presentation/widgets/order_pipeline_chat_sheet.dart';
```

### 2.2 Pipeline Chat Button in Customer Header
In `order_detail_page.dart` (around line 570, in the Customer Information card action buttons):
- Add a direct **💬 Pipeline Chat** button:
```dart
IconButton.filled(
  style: IconButton.styleFrom(
    backgroundColor: const Color(0xFF0D9488),
    foregroundColor: Colors.white,
  ),
  icon: const Icon(Icons.forum_outlined, size: 18),
  tooltip: 'Pipeline Group Chat (Client + DC)',
  onPressed: () => OrderPipelineChatSheet.showForOrder(context, order),
),
```

### 2.3 Replacing Legacy Upsell Modal with `OrderProductSwitchModal`
In `order_detail_page.dart` (around line 710):
- Remove the legacy `UpsellSelectorModal.show(...)` button.
- Insert a prominent, modern action card:
```dart
if (order.status != 'delivered' && order.status != 'cancelled')
  Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 8),
    child: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF6366F1),
        side: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () {
        showDialog(
          context: context,
          builder: (ctx) => OrderProductSwitchModal(
            orderId: order.id,
            orderNumber: order.orderNumber,
            currentProductName: order.productName,
            currentPackageName: order.packageDealName,
            currentTotalAmount: order.totalAmount,
            currentClientId: order.clientId,
            currentClientName: order.clientName,
          ),
        );
      },
      icon: const Icon(Icons.swap_horizontal_circle_outlined, size: 18),
      label: Text(
        'Modify Product or Package Deal (On-Site Upgrade/Switch)',
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
      ),
    ),
  ),
```

---

## 3. Atomic Execution Flow

1. **Rider opens modal**: Displays current product, commercial package, and price.
2. **Same-Client Package Upgrade**:
   - Rider selects higher package (e.g. 1 Box -> 3 Boxes).
   - Order price updates to package price.
   - DB trigger posts `product_changed` announcement into `order_conversation_messages`.
   - Remittance target remains with original client.
3. **Cross-Client Product Switch**:
   - Rider selects product belonging to a different client.
   - Notice banner displays: *"⚠️ This product belongs to [Client B]. Order ownership and cash remittances will transfer to [Client B]."*
   - Stored proc `transfer_order_product_and_ownership` atomically:
     - Updates `orders.client_id`, `orders.client_name`, `orders.client_company` to Client B.
     - Sets `orders.original_client_id` and `orders.original_client_name` to Client A.
     - Sets `orders.ownership_transferred_at = now()`.
     - Updates `order_conversations.client_id` to Client B.
     - Generates system event `ownership_transferred` in `order_conversation_messages`.
4. **App Feedback**: Shows success snackbar and refreshes order state via `ref.read(ordersProvider.notifier).fetchOrders()`.
