# Phase 3: Flutter Stock Core, Data Sources & Providers Plan

**Document Path:** `c:\PROJECT\NoveXPS\inventry fix\03_flutter_stock_core_and_providers_plan.md`  
**Target Files:**
1. `lib/features/stock/data/datasources/stock_remote_datasource.dart`
2. `lib/features/stock/domain/repositories/stock_repository.dart`
3. `lib/features/stock/data/repositories/stock_repository_impl.dart`
4. `lib/features/stock/presentation/providers/stock_provider.dart`
5. `lib/features/stock/presentation/providers/product_catalog_provider.dart`
6. `lib/features/stock/domain/entities/product_entity.dart`

---

## 1. Remediation for `stock_remote_datasource.dart`

### 1.1 Eliminate Hardcoded ₦25,000 Fallbacks
* **Line 483**:
  ```dart
  // BEFORE:
  double unitPrice = (p['base_price'] as num?)?.toDouble() ?? 25000.0;
  // AFTER:
  double unitPrice = (p['base_price'] as num?)?.toDouble() ?? 0.0;
  ```
* **Line 1013**:
  ```dart
  // BEFORE:
  final price = (prod['base_price'] as num?)?.toDouble() ?? 25000.0;
  // AFTER:
  final price = (prod['base_price'] as num?)?.toDouble() ?? 0.0;
  ```

### 1.2 Query `public.agent_inventory` Directly Instead of In-Memory Recomputation
Currently, lines 1000-1095 reconstruct rider balances by pulling all historical waybills and orders from Supabase and running nested loops on the client device. This is O(N) over all time, prone to client clock skew, and ignores database constraints.

**Remediation**:
Replace dynamic reconstruction with a direct query to `agent_inventory`:
```dart
Future<List<StockItemModel>> getRiderLiveInventory(String agentId) async {
  final response = await _supabase
      .from('agent_inventory')
      .select('*, products(*)')
      .eq('delivery_agent_id', agentId);

  return (response as List).map((row) {
    final prod = row['products'] as Map<String, dynamic>? ?? {};
    return StockItemModel(
      productId: row['product_id'] as String,
      productName: prod['name'] as String? ?? 'Unknown SKU',
      sku: prod['sku'] as String? ?? 'SKU-UNKNOWN',
      currentStock: (row['available_count'] as num?)?.toInt() ?? 0,
      totalInCustody: (row['total_in_custody'] as num?)?.toInt() ?? 0,
      deliveredToday: (row['delivered_count_today'] as num?)?.toInt() ?? 0,
      returnedCount: (row['returned_count'] as num?)?.toInt() ?? 0,
      unitPrice: (prod['base_price'] as num?)?.toDouble() ?? 0.0,
      costPrice: (prod['cost_price'] as num?)?.toDouble() ?? 0.0,
      category: prod['category'] as String? ?? 'General',
      lastAuditDate: DateTime.tryParse(row['updated_at'] ?? ''),
    );
  }).toList();
}
```

### 1.3 Remove the Dummy `stock_returns` Hack
In `stock_remote_datasource.dart:1138`:
Remove the hack where delivering an order inserted a fake row into `stock_returns` with reason `'Real-time lifecycle balance update'`. Order deliveries must strictly be tracked in `orders` and `agent_inventory.delivered_count_today`.

### 1.4 Wire `recordRiderStockAudit` to Supabase
Replace local-only SharedPreferences writes with calls to `public.inventory_audits` and `public.inventory_audit_items`:
```dart
Future<void> submitStockAuditToSupabase({
  required String companyId,
  required String auditorId,
  required String auditType, // 'rider_mobile' | 'dc_warehouse'
  required List<Map<String, dynamic>> items,
  String? dcId,
  String? riderId,
  String? notes,
}) async {
  final auditRes = await _supabase.from('inventory_audits').insert({
    'company_id': companyId,
    'auditor_id': auditorId,
    'audit_type': auditType,
    'distribution_center_id': dcId,
    'delivery_agent_id': riderId,
    'notes': notes,
    'status': 'submitted',
    'created_at': DateTime.now().toIso8601String(),
  }).select('id').single();

  final auditId = auditRes['id'] as String;

  final lineItems = items.map((it) => {
    'audit_id': auditId,
    'product_id': it['product_id'],
    'expected_quantity': it['expected_quantity'],
    'actual_quantity': it['actual_quantity'],
    'variance': it['variance'],
    'variance_reason': it['variance_reason'],
  }).toList();

  await _supabase.from('inventory_audit_items').insert(lineItems);
}
```

### 1.5 Implement `receiveRiderStockReturn` in DataSource
```dart
Future<void> receiveRiderStockReturn({
  required String returnId,
  required String dcId,
  required String receiverId,
  required int verifiedQuantity,
  required String condition, // 'good' | 'damaged' | 'expired'
  String? notes,
}) async {
  final res = await _supabase.rpc('fn_receive_rider_stock_return', params: {
    'p_return_id': returnId,
    'p_dc_id': dcId,
    'p_receiver_id': receiverId,
    'p_verified_quantity': verifiedQuantity,
    'p_condition': condition,
    'p_notes': notes ?? '',
  });

  if (res['success'] != true) {
    throw Exception(res['message'] ?? 'Failed to receive stock return');
  }
}
```

---

## 2. Remediation for `product_catalog_provider.dart`

### 2.1 Remove Hardcoded ₦25,000 on Line 184
```dart
// BEFORE:
final basePrice = (item['base_price'] as num?)?.toDouble() ?? 25000.0;
// AFTER:
final basePrice = (item['base_price'] as num?)?.toDouble() ?? 0.0;
final costPrice = (item['cost_price'] as num?)?.toDouble() ?? 0.0;
```

### 2.2 Extend Domain Entity `ProductEntity`
Add `costPrice`, `barcode`, `weightKg`, and `lowStockThreshold` to `ProductEntity`:
```dart
class ProductEntity {
  final String id;
  final String name;
  final String sku;
  final double basePrice;
  final double costPrice; // Wholesale procurement cost (COGS)
  final String? barcode;
  final double weightKg;
  final int stockQuantity;
  final int lowStockThreshold;
  final Map<String, int> dcStocks;
  // ... constructor and copyWith
}
```

---

## 3. Remediation for `StockNotifier` in `stock_provider.dart`

1. **Listen to Supabase Real-Time Changes**:
   Subscribe to `agent_inventory` table changes for the active rider ID so vehicle counts immediately reflect deliveries and returns.
2. **Expose Supervisor Methods**:
   - `receiveRiderReturn(String returnId, int verifiedCount, String condition)`
   - `fetchPendingDcReturns(String dcId)`
3. **Persist Audits**:
   Update `submitRiderStockAudit` so it calls `submitStockAuditToSupabase` in addition to caching locally for offline continuity.

---

## 4. Verification Plan

- Run unit tests: `flutter test test/features/stock/`
- Ensure zero static analysis errors: `flutter analyze lib/features/stock/`
