import 'dart:math';
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
    String? distributionCenterId,
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
  Future<Map<String, dynamic>> confirmPayoutReceipt({
    required String payoutId,
    required String agentId,
    String? notes,
  });
}

class FinanceRemoteDataSourceImpl implements FinanceRemoteDataSource {
  final SupabaseClient supabaseClient;

  FinanceRemoteDataSourceImpl({required this.supabaseClient});

  SupabaseClient _getAuthDbClient() {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && !session.isExpired) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return supabaseClient;
  }

  @override
  Future<Map<String, dynamic>> confirmPayoutReceipt({
    required String payoutId,
    required String agentId,
    String? notes,
  }) async {
    final dbClient = _getAuthDbClient();
    final cleanPayoutId = payoutId.trim();
    final cleanAgentId = agentId.trim();
    final nowIso = DateTime.now().toIso8601String();

    // 1. Try RPC fn_rider_confirm_payout_receipt
    try {
      final rpcRes = await dbClient.rpc('fn_rider_confirm_payout_receipt', params: {
        'p_payout_id': cleanPayoutId,
        'p_agent_id': cleanAgentId,
        'p_notes': notes ?? 'Confirmed received by rider in PDA app',
      });
      if (rpcRes != null && (rpcRes['success'] == true || rpcRes['status'] == 'completed')) {
        debugPrint('[FINANCE_DATASOURCE] ✅ fn_rider_confirm_payout_receipt RPC executed successfully.');
        return Map<String, dynamic>.from(rpcRes as Map);
      }
    } catch (rpcErr) {
      debugPrint('[FINANCE_DATASOURCE] ℹ️ RPC fn_rider_confirm_payout_receipt notice ($rpcErr). Falling back to direct update.');
    }

    // 2. Direct Table Update fallback
    try {
      final response = await dbClient
          .from('payout_requests')
          .update({
            'status': 'completed',
            'rider_confirmed_at': nowIso,
            'rider_confirmation_notes': notes ?? 'Confirmed received by rider in PDA app',
            'updated_at': nowIso,
          })
          .eq('id', cleanPayoutId)
          .select()
          .maybeSingle();

      // Settle corresponding rider_transactions ledger entry
      try {
        await dbClient
            .from('rider_transactions')
            .update({'status': 'settled'})
            .eq('delivery_agent_id', cleanAgentId)
            .eq('category', 'payout');
      } catch (_) {}

      return response != null ? Map<String, dynamic>.from(response) : {'success': true, 'payout_id': cleanPayoutId};
    } catch (e) {
      debugPrint('[FINANCE_DATASOURCE] ⚠️ confirmPayoutReceipt fallback error: $e');
      return {'success': false, 'error': e.toString()};
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
      if (cleanId.isEmpty) return [];

      var query = dbClient.from(SupabaseConstants.cashRemittancesTable).select();
      if (cleanId == 'all') {
        final response = await query.order('created_at', ascending: false);
        return (response as List).map((item) => RemittanceModel.fromJson(item)).toList();
      }

      // Check if cleanId matches a distribution center
      final dcCheck = await dbClient
          .from('distribution_centers')
          .select('id')
          .eq('id', cleanId)
          .maybeSingle();

      if (dcCheck != null) {
        // Query remittances directly assigned to this DC or to any riders attached to this DC
        final ridersRes = await dbClient
            .from('delivery_agents')
            .select('id')
            .eq('distribution_center_id', cleanId);
        final riderIds = (ridersRes as List)
            .map((r) => r['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toList();

        if (riderIds.isNotEmpty) {
          final inList = riderIds.map((id) => '"$id"').join(',');
          query = query.or('distribution_center_id.eq.$cleanId,delivery_agent_id.in.($inList)');
        } else {
          query = query.eq('distribution_center_id', cleanId);
        }
      } else {
        // cleanId is an agent / rider ID
        final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
        final validAgentUuid = uuidRegex.hasMatch(cleanId) ? cleanId : SupabaseConstants.defaultDeliveryAgentId;
        query = query.or('delivery_agent_id.eq.$validAgentUuid,distribution_center_id.eq.$cleanId');
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
    String? distributionCenterId,
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

      String? resolvedDcId = distributionCenterId;
      if (resolvedDcId == null || resolvedDcId.isEmpty) {
        try {
          final agentRow = await dbClient
              .from('delivery_agents')
              .select('distribution_center_id')
              .eq('id', validAgentUuid)
              .maybeSingle();
          if (agentRow != null && agentRow['distribution_center_id'] != null) {
            resolvedDcId = agentRow['distribution_center_id'].toString();
          }
        } catch (_) {}
      }

      final backendPaymentMethod = isPaystack
          ? 'paystack'
          : (paymentMethod == 'cash_to_dc'
              ? 'dc_handover'
              : (paymentMethod == 'pos_deposit' ? 'pos_settlement' : 'bank_transfer'));

      // Construct payload containing all valid columns in cash_remittances table
      final insertData = <String, dynamic>{
        'company_id': validCompanyUuid,
        'delivery_agent_id': validAgentUuid,
        if (resolvedDcId != null && resolvedDcId.isNotEmpty) 'distribution_center_id': resolvedDcId,
        'amount': amount,
        'gross_collections': grossCollections > 0 ? grossCollections : amount,
        'commission_deducted': commissionDeducted,
        'transport_allowance_deducted': transportAllowanceDeducted,
        'failed_stipends_deducted': failedStipendsDeducted,
        'pos_fee': posFee,
        'expected_amount': (expectedAmount != null && expectedAmount > 0) ? expectedAmount : amount,
        'discrepancy_amount': actualDiscrepancy ?? 0.0,
        'is_partial': actualIsPartial,
        'deposit_receipt_url': depositReceiptUrl,
        'reference_number': ref,
        'status': isPaystack ? 'verified' : initialStatus,
        'notes': structuredNote,
        'payment_method': backendPaymentMethod,
        'created_at': DateTime.now().toIso8601String(),
      };
      if (isPaystack) {
        insertData['verified_at'] = DateTime.now().toIso8601String();
        insertData['is_verified'] = true;
      }

      final response = await dbClient
          .from(SupabaseConstants.cashRemittancesTable)
          .insert(insertData)
          .select()
          .single();

      final remId = response['id']?.toString() ?? 'rem-${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('[FINANCE_DATASOURCE] ✅ Successfully created cash_remittance in Supabase: $remId (Ref: $ref)');

      // If instant paystack remittance, atomically clear rider COD balance & update orders
      if (isPaystack) {
        try {
          await dbClient.rpc('fn_approve_cash_remittance', params: {
            'p_remittance_id': remId,
          });
        } catch (rpcErr) {
          debugPrint('[FINANCE_DATASOURCE] ℹ️ fn_approve_cash_remittance notice: $rpcErr');
        }
      }

      // Update associated orders in Supabase using proper remittance statuses
      final orderIds = associatedOrders.map((o) => o.orderId).where((id) => id.isNotEmpty).toList();
      for (final oId in orderIds) {
        try {
          final oRes = await dbClient.from('orders').select('delivery_notes').eq('id', oId).limit(1);
          final existingNotes = (oRes as List).isNotEmpty ? (oRes.first['delivery_notes']?.toString() ?? '') : '';
          final tag = actualIsPartial
              ? '[PARTIAL REMITTANCE: $ref | Paid: ₦$amount]'
              : '[REMITTED: $ref | Amount: ₦$amount]';
          final updatedNotes = existingNotes.contains(ref)
              ? existingNotes
              : '$existingNotes $tag'.trim();
          await dbClient.from('orders').update({
            'payment_status': actualIsPartial ? 'collected' : 'remitted',
            'delivery_notes': updatedNotes,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', oId);
          debugPrint('[FINANCE_DATASOURCE] 📋 Marked order $oId payment_status as ${actualIsPartial ? "collected" : "remitted"} in Supabase DB.');
        } catch (ordErr) {
          debugPrint('[FINANCE_DATASOURCE] ℹ️ order update notice: $ordErr');
        }
      }

      // Link associated orders into public.remittance_orders relational table
      if (associatedOrders.isNotEmpty) {
        final orderLinks = associatedOrders.map((o) => {
          'cash_remittance_id': remId,
          'order_id': o.orderId,
          'order_amount': o.cashCollected,
          'payment_type': o.paymentType.isNotEmpty ? o.paymentType : 'pay_on_delivery',
        }).toList();
        try {
          await dbClient.from('remittance_orders').insert(orderLinks);
          debugPrint('[FINANCE_DATASOURCE] 🔗 Linked ${orderLinks.length} orders into remittance_orders.');
        } catch (roErr) {
          debugPrint('[FINANCE_DATASOURCE] ℹ️ remittance_orders insert notice: $roErr');
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
      final cleanAgentId = agentId.trim();
      if (cleanAgentId.isEmpty) {
        throw Exception('Invalid agent ID provided for payout request.');
      }

      // 1. Verify agent record and balance
      final agentRes = await dbClient
          .from('delivery_agents')
          .select('id, company_id, distribution_center_id, direct_transfer_balance')
          .eq('id', cleanAgentId)
          .maybeSingle();

      if (agentRes == null) {
        throw Exception('Delivery agent not found: $cleanAgentId');
      }

      final double currentBalance = (agentRes['direct_transfer_balance'] as num?)?.toDouble() ?? 0.0;
      if (amount > currentBalance) {
        throw Exception(
          'Insufficient direct transfer balance. Available: ₦${currentBalance.toStringAsFixed(2)}, Requested: ₦${amount.toStringAsFixed(2)}',
        );
      }

      final String? companyId = agentRes['company_id']?.toString();
      final String? dcId = agentRes['distribution_center_id']?.toString();

      // 2. Generate unique payout sequence number (PO-YYYYMMDD-XXXX)
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final randomSuffix = (1000 + Random().nextInt(9000)).toString();
      final payoutNumber = 'PO-$dateStr-$randomSuffix';

      // 3. Insert into authoritative public.payout_requests table
      final insertData = {
        'payout_number': payoutNumber,
        'delivery_agent_id': cleanAgentId,
        if (companyId != null && companyId.isNotEmpty) 'company_id': companyId,
        if (dcId != null && dcId.isNotEmpty) 'distribution_center_id': dcId,
        'amount': amount,
        'bank_name': bankName.trim(),
        'account_number': accountNumber.trim(),
        'account_name': accountName.trim(),
        'notes': notes?.trim(),
        'status': 'pending',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final response = await dbClient
          .from('payout_requests')
          .insert(insertData)
          .select()
          .single();

      debugPrint('[FINANCE_DATASOURCE] ✅ Payout request created successfully: $payoutNumber (ID: ${response['id']})');

      // 4. Record pending withdrawal in rider_transactions
      try {
        await dbClient.from('rider_transactions').insert({
          'delivery_agent_id': cleanAgentId,
          'transaction_code': payoutNumber,
          'title': 'Balance Payout Requested',
          'category': 'payout',
          'amount': amount,
          'is_credit': false,
          'reference': payoutNumber,
          'status': 'pending',
          'description': 'Withdrawal requested to $bankName ($accountNumber). Awaiting DC approval.',
          'created_at': now.toIso8601String(),
        });
      } catch (_) {}

      return {'status': 'success', 'data': response};
    } catch (e) {
      debugPrint('[FINANCE_DATASOURCE] ❌ requestPayout error: $e');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPayoutRequests(String agentId) async {
    final dbClient = _getAuthDbClient();
    try {
      final cleanId = agentId.trim();
      if (cleanId.isEmpty) return [];

      final response = await dbClient
          .from('payout_requests')
          .select()
          .eq('delivery_agent_id', cleanId)
          .order('created_at', ascending: false);

      return (response as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('[FINANCE_DATASOURCE] ❌ getPayoutRequests error: $e');
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
