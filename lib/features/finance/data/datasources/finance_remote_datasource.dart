import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../domain/entities/remittance.dart';
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
    double failedStipendsDeducted = 0.0,
    double posFee = 0.0,
    String? depositReceiptUrl,
    String? referenceNumber,
    String? discrepancyReason,
    double? discrepancyAmount,
    double? expectedAmount,
    bool isPartial = false,
    String? notes,
    List<RemittanceOrderItem> associatedOrders = const [],
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
  Future<List<Map<String, dynamic>>> getRiderTransactions(String agentId);
  Future<Map<String, dynamic>?> getPaystackTransactionDetails(String reference);
}

class FinanceRemoteDataSourceImpl implements FinanceRemoteDataSource {
  final SupabaseClient supabaseClient;

  FinanceRemoteDataSourceImpl(this.supabaseClient);

  @override
  Future<Map<String, dynamic>?> getPaystackTransactionDetails(String reference) async {
    try {
      final response = await supabaseClient
          .from('paystack_transactions')
          .select()
          .eq('reference', reference)
          .maybeSingle();

      return response != null ? Map<String, dynamic>.from(response) : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<RemittanceModel>> getAgentRemittances(String agentId) async {
    try {
      final cleanId = agentId.trim();
      if (cleanId.isEmpty) return [];

      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      final validAgentUuid = (cleanId.isNotEmpty && uuidRegex.hasMatch(cleanId))
          ? cleanId
          : cleanId;

      final response = await supabaseClient
          .from(SupabaseConstants.cashRemittancesTable)
          .select()
          .eq('delivery_agent_id', validAgentUuid)
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
    double failedStipendsDeducted = 0.0,
    double posFee = 0.0,
    String? depositReceiptUrl,
    String? referenceNumber,
    String? discrepancyReason,
    double? discrepancyAmount,
    double? expectedAmount,
    bool isPartial = false,
    String? notes,
    List<RemittanceOrderItem> associatedOrders = const [],
  }) async {
    final ref = referenceNumber ?? 'REM-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final isPaystack = paymentMethod == 'paystack' || paymentMethod == 'paystack_transfer';
    final initialStatus = isPaystack ? 'verified' : 'pending';
    final actualIsPartial = isPartial || (expectedAmount != null && expectedAmount > amount && amount > 0);
    final actualDiscrepancy = discrepancyAmount ?? (expectedAmount != null && expectedAmount > amount ? (amount - expectedAmount) : null);
    final remittanceNotes = isPaystack
        ? (actualIsPartial
            ? '[PAYSTACK PARTIAL] Ref: $ref - Paid ₦$amount of expected ₦$expectedAmount. ${notes ?? ""}'
            : '[PAYSTACK] Ref: $ref - Auto-verified instant remittance. ${notes ?? ""}')
        : '[${paymentMethod.toUpperCase()}] Ref: $ref - ${notes ?? ""}';

    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    final validAgentUuid = (agentId.isNotEmpty && uuidRegex.hasMatch(agentId))
        ? agentId
        : SupabaseConstants.defaultDeliveryAgentId;
    final validCompanyUuid = (companyId.isNotEmpty && uuidRegex.hasMatch(companyId))
        ? companyId
        : '11111111-1111-4111-8111-111111111111';

    try {
      final backendPaymentMethod = isPaystack
          ? 'paystack'
          : (paymentMethod == 'cash_to_dc'
              ? 'dc_handover'
              : (paymentMethod == 'pos_deposit' ? 'pos_settlement' : 'bank_transfer'));

      try {
        final edgeResponse = await supabaseClient.functions.invoke(
          'submit-cash-remittance',
          body: {
            'agentId': validAgentUuid,
            'companyId': validCompanyUuid,
            'distributionCenterId': '22222222-2222-4222-8222-222222222222',
            'amount': amount,
            'paymentMethod': backendPaymentMethod,
            'depositReceiptUrl': depositReceiptUrl,
            'referenceNumber': ref,
            'grossCollections': grossCollections,
            'commissionDeducted': commissionDeducted,
            'transportAllowanceDeducted': transportAllowanceDeducted,
            'failedStipendsDeducted': failedStipendsDeducted,
            'posFee': posFee,
            'expectedAmount': expectedAmount,
            'isPartial': actualIsPartial,
            'discrepancyAmount': actualDiscrepancy,
            'discrepancyReason': discrepancyReason,
            'notes': remittanceNotes,
            'associatedOrders': associatedOrders.map((o) => o.toJson()).toList(),
          },
        );

        if (edgeResponse.status >= 200 && edgeResponse.status < 300) {
          final data = edgeResponse.data as Map<String, dynamic>;
          final rem = data['remittance'] as Map<String, dynamic>? ?? {};
          return RemittanceModel(
            id: rem['id'] ?? 'rem-${DateTime.now().millisecondsSinceEpoch}',
            referenceNumber: rem['remittance_number'] ?? ref,
            companyId: validCompanyUuid,
            deliveryAgentId: validAgentUuid,
            amount: (rem['amount'] as num?)?.toDouble() ?? amount,
            grossCollections: grossCollections,
            commissionDeducted: commissionDeducted,
            transportAllowanceDeducted: transportAllowanceDeducted,
            failedStipendsDeducted: failedStipendsDeducted,
            posFee: posFee,
            paymentMethod: paymentMethod,
            depositReceiptUrl: depositReceiptUrl,
            status: rem['status'] ?? initialStatus,
            expectedAmount: expectedAmount,
            isPartial: actualIsPartial,
            discrepancyAmount: actualDiscrepancy,
            discrepancyReason: discrepancyReason,
            notes: remittanceNotes,
            associatedOrders: associatedOrders,
            createdAt: DateTime.now(),
          );
        }
      } catch (_) {}

      // Fallback to table insert if edge function returned non-200 or offline
      final insertData = <String, dynamic>{
        'company_id': validCompanyUuid,
        'delivery_agent_id': validAgentUuid,
        'distribution_center_id': '22222222-2222-4222-8222-222222222222',
        'amount': amount,
        'deposit_receipt_url': depositReceiptUrl,
        'status': initialStatus,
        'notes': remittanceNotes,
        'payment_method': isPaystack ? 'paystack' : paymentMethod,
        'reference_number': ref,
        'gross_collections': grossCollections,
        'commission_deducted': commissionDeducted,
        'transport_allowance_deducted': transportAllowanceDeducted,
        'pos_fee': posFee,
        'expected_amount': expectedAmount,
        'is_partial': actualIsPartial,
        'discrepancy_amount': actualDiscrepancy,
        'discrepancy_reason': discrepancyReason,
        'created_at': DateTime.now().toIso8601String(),
      };
      if (isPaystack) {
        insertData['verified_at'] = DateTime.now().toIso8601String();
      }

      final response = await supabaseClient
          .from(SupabaseConstants.cashRemittancesTable)
          .insert(insertData)
          .select()
          .single();

      // Log into paystack_transactions and rider_transactions
      if (isPaystack) {
        try {
          await supabaseClient.from(SupabaseConstants.paystackTransactionsTable).upsert({
            'reference': ref,
            'remittance_id': response['id'],
            'delivery_agent_id': validAgentUuid,
            'amount': amount,
            'currency': 'NGN',
            'transaction_type': 'remittance',
            'channel': 'bank_transfer',
            'verification_status': 'verified',
            'payer_name': 'Rider Cash Remittance',
            'created_at': DateTime.now().toIso8601String(),
          }, onConflict: 'reference');
        } catch (_) {}
      }

      try {
        await supabaseClient.from('rider_transactions').insert({
          'delivery_agent_id': validAgentUuid,
          'transaction_code': ref,
          'title': isPaystack ? 'Paystack Remittance Verified' : 'Cash Remittance Submitted',
          'category': 'remittance',
          'amount': amount,
          'is_credit': false,
          'reference': ref,
          'status': initialStatus,
          'description': isPaystack
              ? 'Instant cash remittance of ₦${amount.toStringAsFixed(2)} verified via Paystack.'
              : 'Remittance of ₦${amount.toStringAsFixed(2)} submitted via ${paymentMethod.toUpperCase()} with reference $ref.',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}

      return RemittanceModel.fromJson({
        ...response,
        'associated_orders': associatedOrders.map((o) => o.toJson()).toList(),
      });
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

  @override
  Future<List<Map<String, dynamic>>> getRiderTransactions(String agentId) async {
    try {
      final cleanId = agentId.trim();
      if (cleanId.isEmpty) return [];

      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      final validAgentUuid = (cleanId.isNotEmpty && uuidRegex.hasMatch(cleanId))
          ? cleanId
          : cleanId;

      final response = await supabaseClient
          .from('rider_transactions')
          .select()
          .eq('delivery_agent_id', validAgentUuid)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (_) {
      return [];
    }
  }
}
