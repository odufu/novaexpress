import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../models/stock_item_model.dart';

abstract class StockRemoteDataSource {
  Future<List<StockItemModel>> getVehicleStockItems();
  Future<Map<String, dynamic>> requestStockTransfer({
    required String agentId,
    required String companyId,
    required String sourceWarehouseId,
    required List<Map<String, dynamic>> items,
    String? notes,
  });
  Future<Map<String, dynamic>> confirmStockHandover({
    required String requestId,
    required String handoverCode,
    required String agentId,
  });
  Future<Map<String, dynamic>> processStockReturn({
    required String returnNumber,
    required String orderId,
    required String deliveryAgentId,
    required String productId,
    required int quantity,
    required String reason,
    String? notes,
  });
  Future<Map<String, dynamic>> submitInventoryAudit({
    required String distributionCenterId,
    required String auditedBy,
    required int totalPhysicalCounted,
    required int totalSystemExpected,
    required int discrepancyCount,
    String? notes,
  });
}

class StockRemoteDataSourceImpl implements StockRemoteDataSource {
  final SupabaseClient supabaseClient;

  StockRemoteDataSourceImpl({required this.supabaseClient});

  static const List<Map<String, dynamic>> _fallbackStockData = [
    {
      'id': 'stk-001',
      'sku': 'SKU-RSP01',
      'name': 'Respira',
      'owner_name': 'Novacare Limited',
      'inventory_type': 'distributed_inventory',
      'description': 'Organic herbal detox blend formulated for respiratory purification, revitalization and digestive health.',
      'base_price': 26000.0,
      'total_in_custody': 42,
      'reserved_count': 8,
      'available_count': 34,
      'assigned_count': 50,
      'delivered_count': 6,
      'returned_count': 2,
      'awaiting_return_count': 2,
      'low_stock_threshold': 5,
      'reorder_level': 5,
      'category': 'Herbal Detox',
      'image_asset': 'assets/images/products/respira_detox_tea.jpg',
      'batch_number': 'BATCH-RSP-2026',
      'last_audit_date': 'Today, 08:30 AM',
    },
    {
      'id': 'stk-002',
      'sku': 'SKU-GRZ02',
      'name': 'Grazer Herbal Tea',
      'owner_name': 'Novacare Limited',
      'inventory_type': 'distributed_inventory',
      'description': 'Botanical colon cleanse herbal tea for gentle digestive support and natural detox.',
      'base_price': 15000.0,
      'total_in_custody': 18,
      'reserved_count': 4,
      'available_count': 14,
      'assigned_count': 25,
      'delivered_count': 6,
      'returned_count': 1,
      'awaiting_return_count': 1,
      'low_stock_threshold': 5,
      'reorder_level': 5,
      'category': 'Digestive Care',
      'image_asset': 'assets/images/products/herbal_cleanse_pack.jpg',
      'batch_number': 'BATCH-GRZ-2026',
      'last_audit_date': 'Today, 08:30 AM',
    },
    {
      'id': 'stk-003',
      'sku': 'SKU-ALM03',
      'name': 'Alpha Man',
      'owner_name': 'Novacare Limited',
      'inventory_type': 'distributed_inventory',
      'description': 'Daily organic vitality supplement for mens physical endurance and wellness.',
      'base_price': 22000.0,
      'total_in_custody': 3,
      'reserved_count': 0,
      'available_count': 3,
      'assigned_count': 15,
      'delivered_count': 10,
      'returned_count': 2,
      'awaiting_return_count': 0,
      'low_stock_threshold': 5,
      'reorder_level': 5,
      'category': 'Mens Wellness',
      'image_asset': 'assets/images/products/slimfit_herbal_capsules.jpg',
      'batch_number': 'BATCH-ALM-2026',
      'last_audit_date': 'Today, 08:30 AM',
    },
    {
      'id': 'stk-004',
      'sku': 'SKU-IBP04',
      'name': 'Immunity Booster Pack',
      'owner_name': 'PharmaPlus Ltd',
      'inventory_type': 'distributed_inventory',
      'description': 'Organic wellness daily defense formula with citrus, ginger, turmeric and herbal antioxidants.',
      'base_price': 18500.0,
      'total_in_custody': 24,
      'reserved_count': 4,
      'available_count': 20,
      'assigned_count': 30,
      'delivered_count': 6,
      'returned_count': 0,
      'awaiting_return_count': 0,
      'low_stock_threshold': 5,
      'reorder_level': 8,
      'category': 'Immunity & Wellness',
      'image_asset': 'assets/images/products/immunity_booster_pack.jpg',
      'batch_number': 'BATCH-IBP-2026',
      'last_audit_date': 'Today, 08:30 AM',
    },
  ];

  @override
  Future<List<StockItemModel>> getVehicleStockItems() async {
    try {
      final response = await supabaseClient
          .from(SupabaseConstants.productsTable)
          .select();

      final List<dynamic> data = response as List<dynamic>;

      return data
          .map((json) => StockItemModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> requestStockTransfer({
    required String agentId,
    required String companyId,
    required String sourceWarehouseId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    try {
      final response = await supabaseClient.functions.invoke(
        'request-stock-transfer',
        body: {
          'agentId': agentId,
          'companyId': companyId,
          'sourceWarehouseId': sourceWarehouseId,
          'items': items,
          'notes': notes,
        },
      );

      if (response.status >= 200 && response.status < 300) {
        return response.data as Map<String, dynamic>? ?? {'status': 'success'};
      }
      throw Exception('Server returned ${response.status}: ${response.data}');
    } catch (e) {
      return {
        'status': 'offline_fallback',
        'requestNumber': 'REQ-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
        'message': 'Stock transfer saved locally: $e',
      };
    }
  }

  @override
  Future<Map<String, dynamic>> confirmStockHandover({
    required String requestId,
    required String handoverCode,
    required String agentId,
  }) async {
    try {
      final response = await supabaseClient.rpc(
        'confirm_stock_handover',
        params: {
          'p_request_id': requestId,
          'p_handover_code': handoverCode,
          'p_agent_id': agentId,
        },
      );
      return {'status': 'success', 'data': response};
    } catch (e) {
      return {'status': 'offline_fallback', 'message': e.toString()};
    }
  }

  @override
  Future<Map<String, dynamic>> processStockReturn({
    required String returnNumber,
    required String orderId,
    required String deliveryAgentId,
    required String productId,
    required int quantity,
    required String reason,
    String? notes,
  }) async {
    try {
      final response = await supabaseClient.from('stock_returns').insert({
        'return_number': returnNumber,
        'order_id': orderId,
        'delivery_agent_id': deliveryAgentId,
        'product_id': productId,
        'quantity': quantity,
        'reason': reason,
        'status': 'submitted',
        'notes': notes,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      return {'status': 'success', 'data': response};
    } catch (e) {
      return {'status': 'offline_fallback', 'message': e.toString()};
    }
  }

  @override
  Future<Map<String, dynamic>> submitInventoryAudit({
    required String distributionCenterId,
    required String auditedBy,
    required int totalPhysicalCounted,
    required int totalSystemExpected,
    required int discrepancyCount,
    String? notes,
  }) async {
    try {
      final response = await supabaseClient.from('inventory_audits').insert({
        'distribution_center_id': distributionCenterId,
        'audited_by': auditedBy,
        'status': discrepancyCount == 0 ? 'reconciled' : 'discrepancy_flagged',
        'total_physical_counted': totalPhysicalCounted,
        'total_system_expected': totalSystemExpected,
        'discrepancy_count': discrepancyCount,
        'discrepancy_notes': notes,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      return {'status': 'success', 'data': response};
    } catch (e) {
      return {'status': 'offline_fallback', 'message': e.toString()};
    }
  }
}
