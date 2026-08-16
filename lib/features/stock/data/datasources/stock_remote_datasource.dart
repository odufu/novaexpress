import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../models/stock_item_model.dart';

abstract class StockRemoteDataSource {
  Future<List<StockItemModel>> getVehicleStockItems();
}

class StockRemoteDataSourceImpl implements StockRemoteDataSource {
  final SupabaseClient supabaseClient;

  StockRemoteDataSourceImpl({required this.supabaseClient});

  static const List<Map<String, dynamic>> _fallbackStockData = [
    {
      'id': 'stk-001',
      'sku': 'SKU: GRAZER-001',
      'name': 'Grazer Herbal Tea',
      'description': 'Premium organic herbal tea blend formulated for colon detox and digestive health.',
      'base_price': 15000.0,
      'quantity_held': 20,
      'available_count': 8,
      'allocated_count': 12,
      'category': 'Herbal Detox',
    },
    {
      'id': 'stk-002',
      'sku': 'SKU: RESPIRA-002',
      'name': 'Respira Vitality Tonic',
      'description': 'Natural respiratory wellness tonic formulated for lung function and stamina.',
      'base_price': 18000.0,
      'quantity_held': 15,
      'available_count': 5,
      'allocated_count': 10,
      'category': 'Respiratory Care',
    },
    {
      'id': 'stk-003',
      'sku': 'SKU: ALPHAMAN-003',
      'name': 'Alpha Man Organic',
      'description': 'Daily organic vitality supplement for mens physical endurance and wellness.',
      'base_price': 22000.0,
      'quantity_held': 10,
      'available_count': 4,
      'allocated_count': 6,
      'category': 'Mens Wellness',
    },
  ];

  @override
  Future<List<StockItemModel>> getVehicleStockItems() async {
    try {
      final response = await supabaseClient
          .from(SupabaseConstants.productsTable)
          .select();

      final List<dynamic> data = response as List<dynamic>;

      if (data.isEmpty) {
        return _fallbackStockData
            .map((json) => StockItemModel.fromJson(json))
            .toList();
      }

      return data
          .map((json) => StockItemModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // In case of network disconnection or query error, safely return fallback seeded stock items
      return _fallbackStockData
          .map((json) => StockItemModel.fromJson(json))
          .toList();
    }
  }
}
