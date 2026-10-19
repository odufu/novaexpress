import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/business_expenditure.dart';
import '../../domain/entities/merchant_financial_metrics.dart';

class ExpenditureRepository {
  final SupabaseClient _supabase;

  ExpenditureRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Fetch expenditures list for a client/merchant
  Future<List<BusinessExpenditureEntity>> fetchMerchantExpenditures({
    required String clientId,
    String? productId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase
          .from('business_expenditures')
          .select()
          .eq('client_id', clientId)
          .eq('entity_type', 'merchant');

      if (productId != null && productId.isNotEmpty) {
        query = query.or('product_id.eq.$productId,product_id.is.null');
      }

      if (startDate != null) {
        query = query.gte('expenditure_date', startDate.toIso8601String().split('T').first);
      }

      if (endDate != null) {
        query = query.lte('expenditure_date', endDate.toIso8601String().split('T').first);
      }

      final response = await query.order('expenditure_date', ascending: false);
      return (response as List)
          .map((row) => BusinessExpenditureEntity.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching merchant expenditures: $e');
      return [];
    }
  }

  /// Create a new business expenditure
  Future<BusinessExpenditureEntity?> createExpenditure(BusinessExpenditureEntity expenditure) async {
    try {
      final payload = expenditure.toMap();
      final response = await _supabase
          .from('business_expenditures')
          .insert(payload)
          .select()
          .single();

      return BusinessExpenditureEntity.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error creating expenditure: $e');
      rethrow;
    }
  }

  /// Upload receipt or invoice attachment (PDF or Image) to Supabase Storage bucket 'expenditure-receipts'
  Future<String?> uploadReceiptAttachment({
    required Uint8List fileBytes,
    required String fileName,
    required String mimeType,
    required String entityId,
  }) async {
    try {
      final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'receipts/${entityId}_${timestamp}_$cleanName';

      await _supabase.storage.from('expenditure-receipts').uploadBinary(
        storagePath,
        fileBytes,
        fileOptions: FileOptions(
          contentType: mimeType,
          upsert: true,
        ),
      );

      final publicUrl = _supabase.storage.from('expenditure-receipts').getPublicUrl(storagePath);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading receipt attachment: $e');
      rethrow;
    }
  }

  /// Delete / Archive an expenditure record
  Future<bool> deleteExpenditure(String id) async {
    try {
      await _supabase.from('business_expenditures').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting expenditure: $e');
      return false;
    }
  }

  /// Update an existing expenditure record
  Future<BusinessExpenditureEntity?> updateExpenditure(String id, Map<String, dynamic> updates) async {
    try {
      final response = await _supabase
          .from('business_expenditures')
          .update(updates)
          .eq('id', id)
          .select()
          .single();
      return BusinessExpenditureEntity.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error updating expenditure: $e');
      return null;
    }
  }

  /// Query the 8 core merchant metrics from fn_get_merchant_financial_dashboard RPC
  Future<MerchantFinancialMetrics> fetchMerchantFinancialDashboard({
    required String clientId,
    String? productId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final rpcParams = {
        'p_client_id': clientId,
        if (productId != null && productId.isNotEmpty) 'p_product_id': productId,
        if (startDate != null) 'p_start_date': startDate.toIso8601String().split('T').first,
        if (endDate != null) 'p_end_date': endDate.toIso8601String().split('T').first,
      };

      final response = await _supabase.rpc('fn_get_merchant_financial_dashboard', params: rpcParams);
      if (response != null && response is Map) {
        return MerchantFinancialMetrics.fromMap(Map<String, dynamic>.from(response));
      }
      return MerchantFinancialMetrics.empty();
    } catch (e) {
      debugPrint('Error calling fn_get_merchant_financial_dashboard RPC: $e');
      return MerchantFinancialMetrics.empty();
    }
  }

  /// Query DC Logistics financial metrics from fn_get_dc_logistics_dashboard RPC
  Future<Map<String, dynamic>> fetchDcLogisticsDashboard({
    String? dcId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final rpcParams = {
        if (dcId != null && dcId.isNotEmpty) 'p_dc_id': dcId,
        if (startDate != null) 'p_start_date': startDate.toIso8601String().split('T').first,
        if (endDate != null) 'p_end_date': endDate.toIso8601String().split('T').first,
      };

      final response = await _supabase.rpc('fn_get_dc_logistics_dashboard', params: rpcParams);
      if (response != null && response is Map) {
        return Map<String, dynamic>.from(response);
      }
      return {};
    } catch (e) {
      debugPrint('Error calling fn_get_dc_logistics_dashboard RPC: $e');
      return {};
    }
  }

  /// Fetch expenditures for Distribution Centers (supports multi-DC scoping)
  Future<List<BusinessExpenditureEntity>> fetchDcExpenditures({
    String? dcId,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase
          .from('business_expenditures')
          .select()
          .not('distribution_center_id', 'is', null);

      if (dcId != null && dcId != 'all' && dcId.isNotEmpty) {
        query = query.eq('distribution_center_id', dcId);
      }

      if (category != null && category != 'all' && category.isNotEmpty) {
        query = query.eq('category', category);
      }

      if (startDate != null) {
        query = query.gte('expenditure_date', startDate.toIso8601String().split('T').first);
      }

      if (endDate != null) {
        query = query.lte('expenditure_date', endDate.toIso8601String().split('T').first);
      }

      final response = await query.order('expenditure_date', ascending: false);
      return (response as List)
          .map((row) => BusinessExpenditureEntity.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching DC expenditures: $e');
      return [];
    }
  }
}

