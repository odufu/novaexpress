import 'package:flutter/foundation.dart';
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

  SupabaseClient _getAuthDbClient() {
    try {
      return SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
    } catch (_) {
      return supabaseClient;
    }
  }

  @override
  Future<Map<String, dynamic>?> getPaystackTransactionDetails(String reference) async {
    final dbClient = _getAuthDbClient();
    try {
      final response = await dbClient
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
    final dbClient = _getAuthDbClient();
    try {
      final cleanId = agentId.trim();
      final isAllOrDc = cleanId.isEmpty || cleanId == 'all' || cleanId == '22222222-2222-4222-8222-222222222222';

      var query = dbClient.from(SupabaseConstants.cashRemittancesTable).select();
      if (!isAllOrDc) {
        final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
        final validAgentUuid = uuidRegex.hasMatch(cleanId) ? cleanId : SupabaseConstants.defaultDeliveryAgentId;
        query = query.eq('delivery_agent_id', validAgentUuid);
      }

      final response = await query.order('created_at', ascending: false);

      final list = (response as List)
          .map((item) => RemittanceModel.fromJson(item))
          .toList();

      debugPrint('[FINANCE_DATASOURCE] 📋 Loaded ${list.length} remittances from live Supabase for scope: $cleanId');
      return list;
    } catch (e) {
      debugPrint('[FINANCE_DATASOURCE] ⚠️ getAgentRemittances error: $e');
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
    final dbClient = _getAuthDbClient();
    try {
      final ref = referenceNumber ?? 'REM-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final isPaystack = paymentMethod == 'paystack' || paymentMethod == 'paystack_transfer';
      final initialStatus = isPaystack ? 'verified' : 'pending';
      final actualIsPartial = isPartial || (expectedAmount != null && expectedAmount > amount && amount > 0);
      final actualDiscrepancy = discrepancyAmount ?? (expectedAmount != null && expectedAmount > amount ? (amount - expectedAmount) : null);
      final discInfo = actualDiscrepancy != null ? ' [Discrepancy: ₦$actualDiscrepancy ${discrepancyReason != null ? "($discrepancyReason)" : ""}]' : '';
      final orderRefs = associatedOrders.map((o) => o.orderNumber).where((orderNo) => orderNo.isNotEmpty).join(', ');
      final orderMeta = orderRefs.isNotEmpty ? ' [Orders: $orderRefs]' : '';
      final structuredNote = isPaystack
          ? (actualIsPartial
              ? '[PAYSTACK PARTIAL] Ref: $ref$orderMeta - Paid ₦$amount of expected ₦$expectedAmount.$discInfo ${notes ?? ""}'
              : '[PAYSTACK] Ref: $ref$orderMeta - Auto-verified instant remittance.$discInfo ${notes ?? ""}')
          : '[${paymentMethod.toUpperCase()}] Ref: $ref$orderMeta -$discInfo ${notes ?? ""}';

      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      final validAgentUuid = (agentId.isNotEmpty && uuidRegex.hasMatch(agentId))
          ? agentId
          : SupabaseConstants.defaultDeliveryAgentId;
      final validCompanyUuid = (companyId.isNotEmpty && uuidRegex.hasMatch(companyId))
          ? companyId
          : '11111111-1111-4111-8111-111111111111';

      final backendPaymentMethod = isPaystack
          ? 'paystack'
          : (paymentMethod == 'cash_to_dc'
              ? 'dc_handover'
              : (paymentMethod == 'pos_deposit' ? 'pos_settlement' : 'bank_transfer'));

      // Construct payload containing only valid columns in cash_remittances table
      final insertData = <String, dynamic>{
        'company_id': validCompanyUuid,
        'delivery_agent_id': validAgentUuid,
        'amount': amount,
        'gross_collections': grossCollections > 0 ? grossCollections : amount,
        'commission_deducted': commissionDeducted,
        'transport_allowance_deducted': transportAllowanceDeducted,
        'deposit_receipt_url': depositReceiptUrl,
        'reference_number': ref,
        'status': isPaystack ? 'verified' : initialStatus,
        'notes': structuredNote,
        'payment_method': backendPaymentMethod,
        'created_at': DateTime.now().toIso8601String(),
      };
      if (isPaystack) {
        insertData['verified_at'] = DateTime.now().toIso8601String();
      }

      final response = await dbClient
          .from(SupabaseConstants.cashRemittancesTable)
          .insert(insertData)
          .select()
          .single();

      final remId = response['id']?.toString() ?? 'rem-${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('[FINANCE_DATASOURCE] ✅ Successfully created cash_remittance in Supabase: $remId (Ref: $ref)');

      // Update associated orders in Supabase using existing columns only
      final orderIds = associatedOrders.map((o) => o.orderId).where((id) => id.isNotEmpty).toList();
      for (final oId in orderIds) {
        try {
          final oRes = await dbClient.from('orders').select('delivery_notes').eq('id', oId).limit(1);
          final existingNotes = (oRes as List).isNotEmpty ? (oRes.first['delivery_notes']?.toString() ?? '') : '';
          final updatedNotes = existingNotes.contains(ref)
              ? existingNotes
              : '$existingNotes [REMITTED: $ref | Amount: ₦$amount]'.trim();
          await dbClient.from('orders').update({
            'payment_status': 'collected',
            'delivery_notes': updatedNotes,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', oId);
          debugPrint('[FINANCE_DATASOURCE] 📋 Marked order $oId as remitted in Supabase DB.');
        } catch (ordErr) {
          debugPrint('[FINANCE_DATASOURCE] ℹ️ order update notice: $ordErr');
        }
      }

      // Log into paystack_transactions and rider_transactions
      if (isPaystack) {
        try {
          await dbClient.from(SupabaseConstants.paystackTransactionsTable).upsert({
            'reference': ref,
            'remittance_id': remId,
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
        await dbClient.from('rider_transactions').insert({
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
      debugPrint('[FINANCE_DATASOURCE] ⚠️ submitRemittance error: $e');
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
    final dbClient = _getAuthDbClient();
    try {
      final response = await dbClient.from('payout_claims').insert({
        'delivery_agent_id': agentId,
        'amount': amount,
        'bank_name': bankName,
        'account_number': accountNumber,
        'account_name': accountName,
        'notes': notes,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      return {'status': 'success', 'data': response};
    } catch (e) {
      return {'status': 'offline_fallback', 'message': e.toString()};
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPayoutRequests(String agentId) async {
    final dbClient = _getAuthDbClient();
    try {
      final cleanId = agentId.trim();
      final response = await dbClient
          .from('payout_claims')
          .select()
          .eq('delivery_agent_id', cleanId)
          .order('created_at', ascending: false);

      return (response as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getRiderTransactions(String agentId) async {
    final dbClient = _getAuthDbClient();
    try {
      final cleanId = agentId.trim();
      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      final validAgentUuid = (cleanId.isNotEmpty && uuidRegex.hasMatch(cleanId))
          ? cleanId
          : SupabaseConstants.defaultDeliveryAgentId;

      final response = await dbClient
          .from('rider_transactions')
          .select()
          .eq('delivery_agent_id', validAgentUuid)
          .order('created_at', ascending: false);

      return (response as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }
}
