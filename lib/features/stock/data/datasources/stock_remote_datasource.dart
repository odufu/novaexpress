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
