import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../models/remittance_model.dart';

abstract class FinanceRemoteDataSource {
  Future<List<RemittanceModel>> getAgentRemittances(String agentId);
  Future<RemittanceModel> submitRemittance({
    required String agentId,
    required String companyId,
    required double amount,
    required String paymentMethod,
    double grossCollections = 0.0,
    double commissionDeducted = 0.0,
    double transportAllowanceDeducted = 0.0,
    double posFee = 0.0,
    String? depositReceiptUrl,
    String? referenceNumber,
    String? discrepancyReason,
    double? discrepancyAmount,
    String? notes,
  });
  Future<Map<String, dynamic>> requestPayout({
    required String agentId,
    required double amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
    String? notes,
  });
  Future<List<Map<String, dynamic>>> getPayoutRequests(String agentId);
}

class FinanceRemoteDataSourceImpl implements FinanceRemoteDataSource {
  final SupabaseClient supabaseClient;

  FinanceRemoteDataSourceImpl(this.supabaseClient);

  @override
  Future<List<RemittanceModel>> getAgentRemittances(String agentId) async {
    try {
      final agentFilter = agentId.isNotEmpty
          ? 'delivery_agent_id.eq.$agentId,delivery_agent_id.eq.b1111111-1111-4111-8111-111111111111,delivery_agent_id.is.null'
          : 'delivery_agent_id.eq.b1111111-1111-4111-8111-111111111111,delivery_agent_id.is.null';

      final response = await supabaseClient
          .from(SupabaseConstants.cashRemittancesTable)
          .select()
          .or(agentFilter)
          .order('created_at', ascending: false);

      final list = (response as List)
          .map((item) => RemittanceModel.fromJson(item))
          .toList();

      return list;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<RemittanceModel> submitRemittance({
    required String agentId,
    required String companyId,
    required double amount,
    required String paymentMethod,
    double grossCollections = 0.0,
    double commissionDeducted = 0.0,
    double transportAllowanceDeducted = 0.0,
    double posFee = 0.0,
    String? depositReceiptUrl,
    String? referenceNumber,
    String? discrepancyReason,
    double? discrepancyAmount,
    String? notes,
  }) async {
    final ref = referenceNumber ?? 'REM-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final remittanceNotes = '[${paymentMethod.toUpperCase()}] Ref: $ref - ${notes ?? ""}';

    try {
      final backendPaymentMethod = paymentMethod == 'cash_to_dc'
          ? 'dc_handover'
          : (paymentMethod == 'pos_deposit' ? 'pos_settlement' : 'bank_transfer');

      final edgeResponse = await supabaseClient.functions.invoke(
        'submit-cash-remittance',
        body: {
          'agentId': agentId,
          'companyId': companyId,
          'amount': amount,
          'paymentMethod': backendPaymentMethod,
          'depositReceiptUrl': depositReceiptUrl,
          'referenceNumber': ref,
          'notes': notes,
        },
      );

      if (edgeResponse.status >= 200 && edgeResponse.status < 300) {
        final data = edgeResponse.data as Map<String, dynamic>;
        final rem = data['remittance'] as Map<String, dynamic>? ?? {};
        return RemittanceModel(
          id: rem['id'] ?? 'rem-${DateTime.now().millisecondsSinceEpoch}',
          referenceNumber: rem['remittance_number'] ?? ref,
          companyId: companyId,
          deliveryAgentId: agentId,
          amount: (rem['amount'] as num?)?.toDouble() ?? amount,
          grossCollections: grossCollections,
          commissionDeducted: commissionDeducted,
          transportAllowanceDeducted: transportAllowanceDeducted,
          posFee: posFee,
          paymentMethod: paymentMethod,
          depositReceiptUrl: depositReceiptUrl,
          status: rem['status'] ?? 'pending',
          notes: remittanceNotes,
          createdAt: DateTime.now(),
        );
      }

      // Fallback to table insert if edge function returned non-200
      final response = await supabaseClient
          .from(SupabaseConstants.cashRemittancesTable)
          .insert({
            'company_id': companyId,
            'delivery_agent_id': agentId,
            'amount': amount,
            'deposit_receipt_url': depositReceiptUrl,
            'status': 'pending',
            'notes': remittanceNotes,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return RemittanceModel.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> requestPayout({
    required String agentId,
    required double amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
    String? notes,
  }) async {
    try {
      final response = await supabaseClient.functions.invoke(
        'request-balance-payout',
        body: {
          'agentId': agentId,
          'amount': amount,
          'bankName': bankName,
          'accountNumber': accountNumber,
          'accountName': accountName,
          'notes': notes,
        },
      );

      if (response.status >= 200 && response.status < 300) {
        return response.data as Map<String, dynamic>? ?? {'status': 'success'};
      }
    } catch (_) {}

    final dbRes = await supabaseClient
        .from('payout_requests')
        .insert({
          'delivery_agent_id': agentId,
          'amount': amount,
          'bank_name': bankName,
          'account_number': accountNumber,
          'account_name': accountName,
          'notes': notes,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    return dbRes;
  }

  @override
  Future<List<Map<String, dynamic>>> getPayoutRequests(String agentId) async {
    try {
      final response = await supabaseClient
          .from('payout_requests')
          .select()
          .eq('delivery_agent_id', agentId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (_) {
      return [];
    }
  }
}
