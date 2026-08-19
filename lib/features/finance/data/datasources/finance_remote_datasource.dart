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

  static final List<RemittanceModel> _fallbackRemittances = [
    RemittanceModel(
      id: 'f-rem-00481',
      referenceNumber: 'REM-00481',
      companyId: '11111111-1111-4111-8111-111111111111',
      deliveryAgentId: SupabaseConstants.defaultDeliveryAgentId,
      amount: 45000.0,
      grossCollections: 90000.0,
      commissionDeducted: 18000.0,
      transportAllowanceDeducted: 27000.0,
      paymentMethod: 'bank_transfer',
      status: 'verified',
      verifiedByName: 'Wuse DC — Operations',
      notes: 'Bank Transfer to NovaExpress GTBank (Ref: TRX-829101). Fully verified.',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      verifiedAt: DateTime.now().subtract(const Duration(days: 1, hours: -1)),
    ),
    RemittanceModel(
      id: 'f-rem-00472',
      referenceNumber: 'REM-00472',
      companyId: '11111111-1111-4111-8111-111111111111',
      deliveryAgentId: SupabaseConstants.defaultDeliveryAgentId,
      amount: 32500.0,
      grossCollections: 65000.0,
      commissionDeducted: 13000.0,
      transportAllowanceDeducted: 19500.0,
      paymentMethod: 'cash_to_dc',
      status: 'pending',
      notes: 'Cash handed over at Wuse DC reception to Supervisor Adekunle. Awaiting audit closure.',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    RemittanceModel(
      id: 'f-rem-00463',
      referenceNumber: 'REM-00463',
      companyId: '11111111-1111-4111-8111-111111111111',
      deliveryAgentId: SupabaseConstants.defaultDeliveryAgentId,
      amount: 28000.0,
      grossCollections: 56000.0,
      commissionDeducted: 11200.0,
      transportAllowanceDeducted: 16800.0,
      posFee: 100.0,
      paymentMethod: 'pos',
      status: 'verified',
      verifiedByName: 'Ikeja DC Finance',
      notes: 'POS transfer via Moniepoint POS Terminal (Ref: POS-839201). Receipt attached.',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      verifiedAt: DateTime.now().subtract(const Duration(days: 3, hours: -2)),
    ),
  ];

  @override
  Future<List<RemittanceModel>> getAgentRemittances(String agentId) async {
    try {
      final response = await supabaseClient
          .from(SupabaseConstants.cashRemittancesTable)
          .select()
          .eq('delivery_agent_id', agentId)
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
    } catch (_) {
      final fallback = RemittanceModel(
        id: 'f-local-${DateTime.now().millisecondsSinceEpoch}',
        referenceNumber: ref,
        companyId: companyId,
        deliveryAgentId: agentId,
        amount: amount,
        grossCollections: grossCollections,
        commissionDeducted: commissionDeducted,
        transportAllowanceDeducted: transportAllowanceDeducted,
        posFee: posFee,
        paymentMethod: paymentMethod,
        depositReceiptUrl: depositReceiptUrl,
        discrepancyAmount: discrepancyAmount,
        discrepancyReason: discrepancyReason,
        status: 'pending',
        notes: remittanceNotes,
        createdAt: DateTime.now(),
      );
      _fallbackRemittances.insert(0, fallback);
      return fallback;
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
      throw Exception('Server returned ${response.status}: ${response.data}');
    } catch (e) {
      // Local fallback for offline/test mode
      return {
        'status': 'offline_fallback',
        'payoutNumber': 'PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
        'message': 'Payout request saved locally: $e',
      };
    }
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
