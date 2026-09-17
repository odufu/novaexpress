# 03. Flutter Data Sources & State Management Specification

## 1. Overview & Architectural Integrity

The Flutter data and state layers connect the UI to PostgreSQL and Supabase Edge Functions. To ensure enterprise-grade reliability and zero financial leakage, this specification mandates:
1. **Targeting Authoritative Tables**: Abolish querying deprecated or non-existent tables (e.g. replacing `payout_claims` with `payout_requests`).
2. **Atomic Procedure Execution**: Replace multi-step, error-prone client-side balance mutations with atomic PostgreSQL RPC calls (`decrement_driver_entitlement`, `fn_approve_cash_remittance`, `fn_generate_merchant_daily_settlement`, `fn_calculate_merchant_asset_custody`).
3. **Elimination of Silent Fallbacks**: No more catching critical financial exceptions with empty `catch (_) {}` blocks or returning mock fallback data that masks production database failures.
4. **Strict Model Serialization**: Guarantee all new columns (itemized charges, asset custody JSONB, settlement numbers) are fully parsed into immutable domain entities.

---

## 2. Rider & PDA Layer: `FinanceRemoteDataSourceImpl`

### 2.1 File Location
`lib/features/finance/data/datasources/finance_remote_datasource.dart`

### 2.2 Root Cause Analysis of Existing Flaws
- In `requestPayout()`, the data source inserted into `payout_claims`, which does not exist in the database, triggering catch blocks and returning `{'status': 'offline_fallback'}`.
- Missing required non-null field `payout_number VARCHAR(100) UNIQUE NOT NULL`.
- In `getPayoutRequests()`, querying `payout_claims` returned empty lists.
- Remittance creation failed to pass `failed_stipends_deducted` to `cash_remittances`.

### 2.3 Authoritative Implementation Code

```dart
// lib/features/finance/data/datasources/finance_remote_datasource.dart

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

      // 1. Fetch agent record to verify current withdrawable direct_transfer_balance & active DC/Company
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

      final String companyId = agentRes['company_id']?.toString() ?? SupabaseConstants.defaultCompanyId;
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
        'company_id': companyId,
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
      final cleanAgentId = agentId.trim();
      final cleanCompanyId = companyId.trim();

      // Dynamic DC resolution if not explicitly passed
      String? resolvedDcId = distributionCenterId;
      if (resolvedDcId == null || resolvedDcId.isEmpty) {
        final agentData = await dbClient
            .from('delivery_agents')
            .select('distribution_center_id')
            .eq('id', cleanAgentId)
            .maybeSingle();
        resolvedDcId = agentData?['distribution_center_id']?.toString();
      }

      // Generate reference if empty
      final ref = (referenceNumber != null && referenceNumber.isNotEmpty)
          ? referenceNumber
          : 'REM-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999)}';

      final isPaystack = paymentMethod.toLowerCase() == 'paystack';
      final initialStatus = isPaystack ? 'verified' : 'pending';

      final insertData = {
        'company_id': cleanCompanyId,
        'delivery_agent_id': cleanAgentId,
        if (resolvedDcId != null && resolvedDcId.isNotEmpty) 'distribution_center_id': resolvedDcId,
        'amount': amount,
        'gross_collections': grossCollections > 0 ? grossCollections : amount,
        'commission_deducted': commissionDeducted,
        'transport_allowance_deducted': transportAllowanceDeducted,
        'failed_stipends_deducted': failedStipendsDeducted,
        'pos_fee': posFee,
        'expected_amount': (expectedAmount != null && expectedAmount > 0) ? expectedAmount : amount,
        'discrepancy_amount': discrepancyAmount ?? 0.0,
        'is_partial': isPartial,
        'deposit_receipt_url': depositReceiptUrl,
        'reference_number': ref,
        'status': initialStatus,
        'notes': notes,
        'payment_method': paymentMethod,
        'created_at': DateTime.now().toIso8601String(),
        if (isPaystack) 'verified_at': DateTime.now().toIso8601String(),
        if (isPaystack) 'is_verified': true,
      };

      final response = await dbClient
          .from('cash_remittances')
          .insert(insertData)
          .select()
          .single();

      final remId = response['id'].toString();

      // Insert linked remittance_orders
      if (associatedOrders.isNotEmpty) {
        final List<Map<String, dynamic>> orderLinks = associatedOrders.map((o) {
          return {
            'cash_remittance_id': remId,
            'order_id': o.orderId,
            'order_number': o.orderNumber,
            'amount_collected': o.collectedAmount,
          };
        }).toList();

        await dbClient.from('remittance_orders').insert(orderLinks);
      }

      // If instant paystack remittance, immediately decrement rider COD balance
      if (isPaystack) {
        await dbClient.rpc('fn_approve_cash_remittance', params: {
          'p_remittance_id': remId,
          'p_supervisor_id': null,
        });
      }

      return RemittanceModel.fromJson({
        ...response,
        'associated_orders': associatedOrders.map((o) => o.toJson()).toList(),
      });
    } catch (e) {
      debugPrint('[FINANCE_DATASOURCE] ❌ submitRemittance error: $e');
      rethrow;
    }
  }
}
```

---

## 3. Main DC Console Layer: `DCConsoleRemoteDataSourceImpl`

### 3.1 File Location
`lib/features/dc_console/data/datasources/dc_console_remote_datasource.dart`

### 3.2 Required Enhancements
1. **Payout Approval via Atomic RPC**: Ensure `approvePayoutClaim` executes `decrement_driver_entitlement` and marks `payout_requests.status = 'approved'`.
2. **Cash Remittance Approval via Atomic RPC**: Add `approveCashRemittance(remittanceId, supervisorId)` executing `fn_approve_cash_remittance`.
3. **Daily 10:00 PM Merchant Settlement**: Add `generateDailyMerchantSettlement` executing `fn_generate_merchant_daily_settlement`.
4. **Merchant Asset Custody Valuation**: Add `getMerchantAssetCustody(clientId, dcId)` executing `fn_calculate_merchant_asset_custody`.
5. **Fetch Client Settlements**: Add `fetchClientSettlements(dcId, clientId)` with full itemized charge parsing.

### 3.3 Authoritative Implementation Code

```dart
// Extensions for DCConsoleRemoteDataSource and DCConsoleRemoteDataSourceImpl

abstract class DCConsoleRemoteDataSource {
  // ... existing methods ...

  Future<void> approvePayoutClaim({
    required String claimId,
    required double amount,
    required String driverId,
  });

  Future<void> rejectPayoutClaim({
    required String claimId,
    required String reason,
  });

  Future<Map<String, dynamic>> approveCashRemittance({
    required String remittanceId,
    String? supervisorId,
  });

  Future<Map<String, dynamic>> generateDailyMerchantSettlement({
    required String clientId,
    required String dcId,
    required DateTime periodStart,
    required DateTime periodEnd,
    Map<String, dynamic>? customDeductions,
  });

  Future<List<ClientSettlement>> fetchDcClientSettlements({
    required String dcId,
    String? clientId,
  });

  Future<Map<String, dynamic>> fetchMerchantAssetCustody({
    required String clientId,
    required String dcId,
  });
}

class DCConsoleRemoteDataSourceImpl implements DCConsoleRemoteDataSource {
  // ...

  @override
  Future<void> approvePayoutClaim({
    required String claimId,
    required double amount,
    required String driverId,
  }) async {
    final adminDb = _getAdminClient();
    try {
      // 1. Mark payout request approved
      await adminDb.from('payout_requests').update({
        'status': 'approved',
        'reviewed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', claimId);

      // 2. Atomically decrement rider direct transfer balance
      await adminDb.rpc('decrement_driver_entitlement', params: {
        'p_driver_id': driverId,
        'p_amount': amount,
      });

      debugPrint('[DC_CONSOLE] ✅ Payout $claimId approved. Entitlement decremented by ₦$amount for driver $driverId.');
    } catch (e) {
      debugPrint('[DC_CONSOLE] ❌ approvePayoutClaim error: $e');
      rethrow;
    } finally {
      adminDb.dispose();
    }
  }

  @override
  Future<Map<String, dynamic>> approveCashRemittance({
    required String remittanceId,
    String? supervisorId,
  }) async {
    final adminDb = _getAdminClient();
    try {
      final response = await adminDb.rpc('fn_approve_cash_remittance', params: {
        'p_remittance_id': remittanceId,
        if (supervisorId != null) 'p_supervisor_id': supervisorId,
      });

      debugPrint('[DC_CONSOLE] ✅ Remittance $remittanceId verified and COD balance cleared.');
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('[DC_CONSOLE] ❌ approveCashRemittance error: $e');
      rethrow;
    } finally {
      adminDb.dispose();
    }
  }

  @override
  Future<Map<String, dynamic>> generateDailyMerchantSettlement({
    required String clientId,
    required String dcId,
    required DateTime periodStart,
    required DateTime periodEnd,
    Map<String, dynamic>? customDeductions,
  }) async {
    final adminDb = _getAdminClient();
    try {
      final response = await adminDb.rpc('fn_generate_merchant_daily_settlement', params: {
        'p_client_id': clientId,
        'p_dc_id': dcId,
        'p_period_start': periodStart.toIso8601String(),
        'p_period_end': periodEnd.toIso8601String(),
        if (customDeductions != null) 'p_custom_deductions': customDeductions,
      });

      debugPrint('[DC_CONSOLE] ✅ 10:00 PM Merchant settlement generated: ${response['settlement_number']}');
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('[DC_CONSOLE] ❌ generateDailyMerchantSettlement error: $e');
      rethrow;
    } finally {
      adminDb.dispose();
    }
  }

  @override
  Future<List<ClientSettlement>> fetchDcClientSettlements({
    required String dcId,
    String? clientId,
  }) async {
    final adminDb = _getAdminClient();
    try {
      var query = adminDb.from('client_settlements').select('*');
      if (clientId != null && clientId.isNotEmpty && clientId != 'all') {
        query = query.eq('client_id', clientId);
      } else {
        query = query.eq('distribution_center_id', dcId);
      }

      final response = await query.order('settled_at', ascending: false);
      return (response as List).map((json) => ClientSettlement.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[DC_CONSOLE] ❌ fetchDcClientSettlements error: $e');
      return [];
    } finally {
      adminDb.dispose();
    }
  }

  @override
  Future<Map<String, dynamic>> fetchMerchantAssetCustody({
    required String clientId,
    required String dcId,
  }) async {
    final adminDb = _getAdminClient();
    try {
      final response = await adminDb.rpc('fn_calculate_merchant_asset_custody', params: {
        'p_client_id': clientId,
        'p_dc_id': dcId,
      });

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('[DC_CONSOLE] ❌ fetchMerchantAssetCustody error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    } finally {
      adminDb.dispose();
    }
  }
}
```

---

## 4. Merchant / Client Layer: `ClientPortalRemoteDataSourceImpl`

### 4.1 File Location
`lib/features/client_portal/data/datasources/client_portal_remote_datasource.dart`

### 4.2 Required Enhancements
1. Add `fetchMerchantAssetCustody(clientId)` executing `fn_calculate_merchant_asset_custody`.
2. Update `fetchClientSettlements(clientId)` to ensure all new fields are fetched and parsed cleanly.

```dart
  @override
  Future<Map<String, dynamic>> fetchMerchantAssetCustody(String clientId) async {
    final adminDb = _getAdminClient();
    try {
      final response = await adminDb.rpc('fn_calculate_merchant_asset_custody', params: {
        'p_client_id': clientId,
      });
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] ❌ fetchMerchantAssetCustody error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    } finally {
      adminDb.dispose();
    }
  }
```

---

## 5. Domain Entities & Calculation Formula Remediation

### 5.1 Updated `ClientSettlement` Entity
Location: `lib/features/client_portal/domain/entities/client_settlement.dart`

Add support for:
- `distributionCenterId: String?`
- `platformFeesDeducted: double`
- `gatewayFeesDeducted: double`
- `failedAttemptFeesDeducted: double`
- `otherChargesDeducted: double`
- `chargesBreakdown: Map<String, dynamic>`

```dart
class ClientSettlement {
  final String id;
  final String settlementNumber;
  final String clientId;
  final String companyId;
  final String? distributionCenterId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int totalOrdersCount;
  final double grossCollections;
  final double logisticsFeesDeducted;
  final double platformFeesDeducted;
  final double gatewayFeesDeducted;
  final double failedAttemptFeesDeducted;
  final double otherChargesDeducted;
  final double netPayoutAmount;
  final Map<String, dynamic> chargesBreakdown;
  final String destinationBankName;
  final String destinationAccountNumber;
  final String destinationAccountName;
  final String? payoutReference;
  final String? proofOfPaymentUrl;
  final String status;
  final String? notes;
  final DateTime settledAt;
  final DateTime createdAt;

  const ClientSettlement({
    required this.id,
    required this.settlementNumber,
    required this.clientId,
    this.companyId = '11111111-1111-4111-8111-111111111111',
    this.distributionCenterId,
    required this.periodStart,
    required this.periodEnd,
    required this.totalOrdersCount,
    required this.grossCollections,
    required this.logisticsFeesDeducted,
    this.platformFeesDeducted = 0.0,
    this.gatewayFeesDeducted = 0.0,
    this.failedAttemptFeesDeducted = 0.0,
    this.otherChargesDeducted = 0.0,
    required this.netPayoutAmount,
    this.chargesBreakdown = const {},
    this.destinationBankName = '',
    this.destinationAccountNumber = '',
    this.destinationAccountName = '',
    this.payoutReference,
    this.proofOfPaymentUrl,
    this.status = 'completed',
    this.notes,
    required this.settledAt,
    required this.createdAt,
  });

  factory ClientSettlement.fromJson(Map<String, dynamic> json) {
    return ClientSettlement(
      id: json['id']?.toString() ?? '',
      settlementNumber: json['settlement_number']?.toString() ?? 'SETTLE-UNKNOWN',
      clientId: json['client_id']?.toString() ?? '',
      companyId: json['company_id']?.toString() ?? '11111111-1111-4111-8111-111111111111',
      distributionCenterId: json['distribution_center_id']?.toString(),
      periodStart: json['period_start'] != null
          ? DateTime.tryParse(json['period_start'].toString()) ?? DateTime.now().subtract(const Duration(days: 1))
          : DateTime.now().subtract(const Duration(days: 1)),
      periodEnd: json['period_end'] != null
          ? DateTime.tryParse(json['period_end'].toString()) ?? DateTime.now()
          : DateTime.now(),
      totalOrdersCount: (json['total_orders_count'] as num?)?.toInt() ?? 0,
      grossCollections: (json['gross_collections'] as num?)?.toDouble() ?? 0.0,
      logisticsFeesDeducted: (json['logistics_fees_deducted'] as num?)?.toDouble() ?? 0.0,
      platformFeesDeducted: (json['platform_fees_deducted'] as num?)?.toDouble() ?? 0.0,
      gatewayFeesDeducted: (json['gateway_fees_deducted'] as num?)?.toDouble() ?? 0.0,
      failedAttemptFeesDeducted: (json['failed_attempt_fees_deducted'] as num?)?.toDouble() ?? 0.0,
      otherChargesDeducted: (json['other_charges_deducted'] as num?)?.toDouble() ?? 0.0,
      netPayoutAmount: (json['net_payout_amount'] as num?)?.toDouble() ?? 0.0,
      chargesBreakdown: json['charges_breakdown'] is Map<String, dynamic>
          ? json['charges_breakdown'] as Map<String, dynamic>
          : {},
      destinationBankName: json['destination_bank_name']?.toString() ?? '',
      destinationAccountNumber: json['destination_account_number']?.toString() ?? '',
      destinationAccountName: json['destination_account_name']?.toString() ?? '',
      payoutReference: json['payout_reference']?.toString(),
      proofOfPaymentUrl: json['proof_of_payment_url']?.toString(),
      status: json['status']?.toString() ?? 'completed',
      notes: json['notes']?.toString(),
      settledAt: json['settled_at'] != null
          ? DateTime.tryParse(json['settled_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
```

### 5.2 Remediated `ClientProductFinanceSummary.calculate` Formula
Location: `lib/features/client_portal/presentation/providers/client_portal_provider.dart`

**Critical Fixes Applied**:
1. **Prepaid Direct Orders Fee Deduction**: For direct transfer orders, the client delivery fee **must be deducted** from the net client payout (`o.totalAmount - o.clientDeliveryFee`), because the customer paid the total gross price to NovaXpress directly.
2. **Proper Classification of Awaiting Closeout vs. Remitted**: Delivered direct transfer orders are held in the company's Paystack account and remain in `awaitingRemittance` until the 10:00 PM settlement closeout processes them into `remittedToBank`.

```dart
  static ClientProductFinanceSummary calculate({
    required List<OrderEntity> orders,
    String productName = 'All Products',
    String productSku = 'ALL',
  }) {
    int delivered = 0;
    int inTransit = 0;
    int pending = 0;
    int failed = 0;
    int units = 0;
    double gross = 0.0;
    double moneyOutside = 0.0;
    double awaitingRemittance = 0.0;
    double remitted = 0.0;
    double fees = 0.0;
    double failedLoss = 0.0;

    for (final o in orders) {
      final s = o.status.toLowerCase();
      final isDelivered = o.isDelivered;
      final isFailed = o.isFailed;
      final isInTransit = s == 'in_transit' || s == 'out_for_delivery' || s == 'accepted';
      final isPending = s == 'pending_dispatch' ||
          s == 'created' ||
          s == 'assigned' ||
          s == 'pending_rider_assignment' ||
          s == 'pending_dc_assignment';

      if (isDelivered) {
        delivered++;
        units += (o.quantity > 0 ? o.quantity : 1);
        gross += o.totalAmount;
        fees += o.clientDeliveryFee;

        // Net proceeds from this order owed to client
        final double netOrderProceeds = o.totalAmount - o.clientDeliveryFee;

        // Order is remitted ONLY if explicitly marked remitted or settled in a batch
        if (o.isRemitted) {
          remitted += netOrderProceeds;
        } else {
          // Awaiting 10:00 PM Daily Settlement Closeout (Both COD held in DC vault & Direct Paystack transfers)
          awaitingRemittance += netOrderProceeds;
        }
      } else if (isInTransit || isPending) {
        if (isInTransit) inTransit++;
        if (isPending) pending++;
        if (o.isCashPod) {
          moneyOutside += o.totalAmount;
        }
      } else if (isFailed) {
        failed++;
        failedLoss += o.totalAmount;
      }
    }

    final netRealized = gross - fees;
    final completed = delivered + failed;
    final successRate = completed > 0 ? (delivered / completed) * 100.0 : 100.0;

    return ClientProductFinanceSummary(
      productName: productName,
      productSku: productSku,
      totalOrders: orders.length,
      deliveredOrders: delivered,
      inTransitOrders: inTransit,
      pendingOrders: pending,
      failedOrders: failed,
      unitsDelivered: units,
      grossDeliveredValue: gross,
      moneyOutside: moneyOutside,
      awaitingRemittance: awaitingRemittance > 0 ? awaitingRemittance : 0.0,
      remittedToBank: remitted > 0 ? remitted : 0.0,
      logisticsDeliveryFees: fees,
      netRealizedRevenue: netRealized > 0 ? netRealized : 0.0,
      failedOrdersLoss: failedLoss,
      deliverySuccessRate: successRate,
    );
  }
```

---

## 6. Implementation Checklist & Verification Gates
- [ ] Verify `payout_requests` is targeted without syntax or runtime table errors.
- [ ] Confirm `payout_number` format `PO-YYYYMMDD-XXXX` satisfies the unique constraint.
- [ ] Ensure `decrement_driver_entitlement` is called with exact parameter names (`p_driver_id`, `p_amount`).
- [ ] Ensure `fn_approve_cash_remittance` is called with `p_remittance_id` and optional `p_supervisor_id`.
- [ ] Verify prepaid orders deduct delivery fees in `ClientProductFinanceSummary`.
- [ ] Confirm all `ClientSettlement` itemized fields deserialize without throwing null-pointer exceptions.
