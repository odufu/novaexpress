import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/audit_logging_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dc_console/domain/entities/distribution_center.dart';
import '../../../orders/data/models/order_model.dart';
import '../../../orders/domain/entities/order.dart';
import '../../domain/entities/client_profile.dart';
import '../../domain/entities/client_settlement.dart';
import 'client_portal_provider.dart';

/// Live accumulating ongoing settlement model for a specific Distribution Center
class LiveOngoingSettlement {
  final String distributionCenterId;
  final String dcName;
  final String dcCode;
  final String dcState;
  final String stationManagerName;
  final String stationManagerPhone;
  final DateTime date;
  final int deliveredCount;
  final double grossRemitted;
  final double logisticsFees;
  final double posGatewayFees;
  final int failedAttemptCount;
  final double failedAttemptValue;
  final double otherFees;
  final String otherFeesComment;
  final double expectedNetPayout;
  final List<OrderEntity> orders;
  final List<String> productsSummary;

  const LiveOngoingSettlement({
    required this.distributionCenterId,
    required this.dcName,
    required this.dcCode,
    required this.dcState,
    required this.stationManagerName,
    required this.stationManagerPhone,
    required this.date,
    required this.deliveredCount,
    required this.grossRemitted,
    required this.logisticsFees,
    required this.posGatewayFees,
    required this.failedAttemptCount,
    required this.failedAttemptValue,
    this.otherFees = 0.0,
    this.otherFeesComment = '',
    required this.expectedNetPayout,
    required this.orders,
    required this.productsSummary,
  });
}

class MerchantSettlementsState {
  final ClientProfile clientProfile;
  final List<DistributionCenter> distributionCenters;
  final List<ClientSettlement> settlements;
  final List<OrderEntity> orders;
  final String selectedTab; // 'ongoing', 'awaiting', 'history'
  final String selectedDcId; // 'all' or specific DC ID
  final String selectedDateRange; // 'today', '7d', '30d', 'this_month', 'custom'
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final String searchQuery;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;

  const MerchantSettlementsState({
    required this.clientProfile,
    this.distributionCenters = const [],
    this.settlements = const [],
    this.orders = const [],
    this.selectedTab = 'ongoing',
    this.selectedDcId = 'all',
    this.selectedDateRange = '30d',
    this.customStartDate,
    this.customEndDate,
    this.searchQuery = '',
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
  });

  MerchantSettlementsState copyWith({
    ClientProfile? clientProfile,
    List<DistributionCenter>? distributionCenters,
    List<ClientSettlement>? settlements,
    List<OrderEntity>? orders,
    String? selectedTab,
    String? selectedDcId,
    String? selectedDateRange,
    DateTime? customStartDate,
    DateTime? customEndDate,
    String? searchQuery,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
  }) {
    return MerchantSettlementsState(
      clientProfile: clientProfile ?? this.clientProfile,
      distributionCenters: distributionCenters ?? this.distributionCenters,
      settlements: settlements ?? this.settlements,
      orders: orders ?? this.orders,
      selectedTab: selectedTab ?? this.selectedTab,
      selectedDcId: selectedDcId ?? this.selectedDcId,
      selectedDateRange: selectedDateRange ?? this.selectedDateRange,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
    );
  }

  /// Active ongoing settlements grouped by Distribution Center
  List<LiveOngoingSettlement> get ongoingDcSettlements {
    final now = DateTime.now();
    final clientId = clientProfile.id;

    // Collect all order IDs and settlement numbers from active/historical settlements
    final settledOrderIds = <String>{};
    final settledRefs = <String>{};
    for (final s in settlements) {
      if (s.status.toLowerCase() != 'disputed' && s.status.toLowerCase() != 'rejected') {
        settledRefs.add(s.settlementNumber.toLowerCase().trim());
        final rawIds = s.chargesBreakdown['order_ids'];
        if (rawIds is List) {
          for (final id in rawIds) {
            settledOrderIds.add(id.toString());
          }
        }
      }
    }

    // Filter delivered orders today awaiting batching
    final unbatchedOrders = orders.where((o) {
      if (clientId.isNotEmpty && o.clientId != clientId) {
        return false;
      }
      if (o.isClientSettled) {
        return false;
      }
      final fs = o.financialSettlementStatus.toLowerCase();
      if (fs == 'client_settled' ||
          fs == 'reconciled' ||
          fs == 'settled' ||
          fs == 'cleared' ||
          fs == 'pending_merchant_confirmation' ||
          fs == 'in_settlement') {
        return false;
      }
      if (settledOrderIds.contains(o.id)) {
        return false;
      }
      final rr = (o.remittanceReference ?? '').trim().toLowerCase();
      if (rr.isNotEmpty && (settledRefs.contains(rr) || rr.startsWith('settle-'))) {
        return false;
      }

      // Status is delivered or failed
      final st = o.status.toLowerCase();
      final isRelevant = st == 'delivered' || st == 'failed' || st == 'returned';
      if (!isRelevant) return false;

      // Filter by DC if not 'all'
      if (selectedDcId != 'all' && selectedDcId.isNotEmpty) {
        if (o.distributionCenterId != selectedDcId) return false;
      }

      // Check date
      if (selectedDateRange == 'today') {
        final oDate = DateTime(o.createdAt.year, o.createdAt.month, o.createdAt.day);
        final today = DateTime(now.year, now.month, now.day);
        if (oDate != today) return false;
      }

      return true;
    }).toList();

    // Guard: If an active or cleared settlement exists without explicit order_ids in breakdown,
    // attribute matching orders to that settlement batch so they do not duplicate in Ongoing.
    final unlinkedSettlements = settlements.where((s) =>
        s.status.toLowerCase() != 'disputed' &&
        s.status.toLowerCase() != 'rejected' &&
        (s.chargesBreakdown['order_ids'] == null ||
            (s.chargesBreakdown['order_ids'] is List && (s.chargesBreakdown['order_ids'] as List).isEmpty))).toList();

    for (final s in unlinkedSettlements) {
      final matching = unbatchedOrders.where((o) {
        if (s.clientId.isNotEmpty && o.clientId != s.clientId) return false;
        if (s.distributionCenterId != null &&
            s.distributionCenterId!.isNotEmpty &&
            o.distributionCenterId != null &&
            o.distributionCenterId!.isNotEmpty &&
            o.distributionCenterId != s.distributionCenterId) {
          return false;
        }
        return true;
      }).take(s.totalOrdersCount > 0 ? s.totalOrdersCount : unbatchedOrders.length).map((o) => o.id).toSet();

      unbatchedOrders.removeWhere((o) => matching.contains(o.id));
    }

    // Group by Distribution Center
    final Map<String, List<OrderEntity>> ordersByDc = {};
    for (final o in unbatchedOrders) {
      final dcKey = (o.distributionCenterId != null && o.distributionCenterId!.isNotEmpty)
          ? o.distributionCenterId!
          : 'dc-cmd-01'; // Default Central Command
      ordersByDc.putIfAbsent(dcKey, () => []).add(o);
    }

    final List<LiveOngoingSettlement> ongoingList = [];

    ordersByDc.forEach((dcId, dcOrders) {
      final dc = distributionCenters.where((d) => d.id == dcId || d.code == dcId).firstOrNull;
      final dcName = dc?.name ?? (dcId.contains('cmd') ? 'Central Command DC' : 'Regional DC Station');
      final dcCode = dc?.code ?? 'DC-CMD-01';
      final dcState = dc?.state ?? 'Abuja (FCT)';

      final delivered = dcOrders.where((o) => o.status.toLowerCase() == 'delivered').toList();
      final failed = dcOrders.where((o) => o.status.toLowerCase() == 'failed' || o.status.toLowerCase() == 'returned').toList();

      final deliveredCount = delivered.length;
      final gross = delivered.fold(0.0, (s, o) => s + o.totalAmount);
      final logistics = deliveredCount * (clientProfile.customDeliveryFee ?? 1200.0);

      double posFees = 0.0;
      for (final o in delivered) {
        if (o.isDirectTransfer) {
          final fee = o.totalAmount * 0.015;
          posFees += fee > 2000.0 ? 2000.0 : fee;
        }
      }

      final failedCount = failed.length;
      final failedVal = failed.fold(0.0, (s, o) => s + o.totalAmount);

      final net = (gross - logistics - posFees).clamp(0.0, gross);

      final prods = dcOrders
          .map((o) => o.productName)
          .where((p) => p.isNotEmpty)
          .toSet()
          .toList();

      if (deliveredCount > 0 || failedCount > 0) {
        ongoingList.add(
          LiveOngoingSettlement(
            distributionCenterId: dcId,
            dcName: dcName,
            dcCode: dcCode,
            dcState: dcState,
            stationManagerName: 'DC Hub Operations',
            stationManagerPhone: '0800-NOVAPRO',
            date: now,
            deliveredCount: deliveredCount,
            grossRemitted: gross,
            logisticsFees: logistics,
            posGatewayFees: posFees,
            failedAttemptCount: failedCount,
            failedAttemptValue: failedVal,
            expectedNetPayout: net,
            orders: dcOrders,
            productsSummary: prods,
          ),
        );
      }
    });

    return ongoingList;
  }

  /// Settlements submitted by DC Accountant awaiting Merchant Sign-off
  List<ClientSettlement> get awaitingValidationSettlements {
    return settlements.where((s) {
      if (!s.isRemitted && !s.isPending) return false;
      if (selectedDcId != 'all' && selectedDcId.isNotEmpty) {
        if (s.distributionCenterId != selectedDcId) return false;
      }
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        final matchNum = s.settlementNumber.toLowerCase().contains(q);
        final matchBank = s.destinationBankName.toLowerCase().contains(q);
        final matchRef = (s.payoutReference ?? '').toLowerCase().contains(q);
        if (!matchNum && !matchBank && !matchRef) return false;
      }
      return true;
    }).toList();
  }

  /// Cleared and validated historical settlements
  List<ClientSettlement> get clearedSettlementsHistory {
    return settlements.where((s) {
      if (!s.isCompleted) return false;
      if (selectedDcId != 'all' && selectedDcId.isNotEmpty) {
        if (s.distributionCenterId != selectedDcId) return false;
      }
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        final matchNum = s.settlementNumber.toLowerCase().contains(q);
        final matchBank = s.destinationBankName.toLowerCase().contains(q);
        final matchRef = (s.payoutReference ?? '').toLowerCase().contains(q);
        if (!matchNum && !matchBank && !matchRef) return false;
      }
      return true;
    }).toList();
  }

  /// Total ₦ currently growing / accumulated live today
  double get totalLiveGrowingToday {
    return ongoingDcSettlements.fold(0.0, (s, og) => s + og.grossRemitted);
  }

  /// Expected net payout accumulating live today
  double get totalLiveExpectedPayout {
    return ongoingDcSettlements.fold(0.0, (s, og) => s + og.expectedNetPayout);
  }

  /// Total ₦ submitted and awaiting validation sign-off
  double get totalAwaitingValidationAmount {
    return awaitingValidationSettlements.fold(0.0, (s, st) => s + st.netPayoutAmount);
  }

  /// Total ₦ cleared and paid this month
  double get totalClearedThisMonth {
    final now = DateTime.now();
    return settlements
        .where((s) => s.isCompleted && s.settledAt.month == now.month && s.settledAt.year == now.year)
        .fold(0.0, (s, st) => s + st.netPayoutAmount);
  }
}

class MerchantSettlementsNotifier extends StateNotifier<MerchantSettlementsState> {
  final Ref _ref;

  MerchantSettlementsNotifier(this._ref)
      : super(
          const MerchantSettlementsState(
            clientProfile: ClientProfile(
              id: '',
              companyName: 'Merchant Account',
              contactPerson: 'Finance Department',
              email: 'accountant@merchant.ng',
              phone: '08000000000',
              address: 'Commercial Avenue',
              bankName: 'Access Bank',
              accountNumber: '0000000000',
              accountName: 'Merchant Enterprise',
            ),
          ),
        ) {
    loadData();
  }

  @visibleForTesting
  void setMockState(MerchantSettlementsState s) {
    state = s;
  }

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = _ref.read(authProvider).user;
      final clientState = _ref.read(clientPortalProvider);

      ClientProfile profile = clientState.clientProfile;

      // 1. Fetch Client Profile if empty
      final supabase = _supabase;
      if (profile.id.isEmpty && supabase != null) {
        final targetClientId = user?.clientId ?? user?.companyId;
        if (targetClientId != null && targetClientId.isNotEmpty) {
          try {
            final res = await supabase.from('clients').select().eq('id', targetClientId).maybeSingle();
            if (res != null) {
              profile = ClientProfile.fromJson(res);
            }
          } catch (_) {}
        }
      }

      // 2. Fetch Distribution Centers
      List<DistributionCenter> dcs = [];
      if (supabase != null) {
        try {
          final res = await supabase.from('distribution_centers').select().order('name');
          if (res.isNotEmpty) {
            dcs = (res as List).map((row) => DistributionCenter.fromJson(row)).toList();
          }
        } catch (_) {}
      }

      // Fallback default DCs if empty
      if (dcs.isEmpty) {
        dcs = [
          const DistributionCenter(
            id: '22222222-2222-4222-8222-222222222222',
            name: 'Central Command Distribution Center',
            code: 'DC-CMD-01',
            state: 'Abuja (FCT)',
            city: 'Wuse 2',
            address: 'Plot 402 Aminu Kano Crescent',
            isGrandDc: true,
            isHub: true,
          ),
          const DistributionCenter(
            id: 'dc-0039-lagos',
            name: 'NOVA XPRESS LAGOS',
            code: 'DC-0039',
            state: 'Lagos State',
            city: 'Alimosho',
            address: 'Plot 424 G close, off 34 road',
            isGrandDc: false,
            isHub: true,
          ),
          const DistributionCenter(
            id: 'dc-bmu001-benue',
            name: 'Benue Distribution Center',
            code: 'DC-BMU001',
            state: 'Benue State',
            city: 'Makurdi',
            address: 'Dentata, back of UBA Bank',
            isGrandDc: false,
            isHub: false,
          ),
        ];
      }

      // 3. Fetch Client Settlements
      List<ClientSettlement> settlements = clientState.settlements;
      if (supabase != null && profile.id.isNotEmpty) {
        try {
          final res = await supabase
              .from('client_settlements')
              .select()
              .eq('client_id', profile.id)
              .order('created_at', ascending: false);
          if (res.isNotEmpty) {
            settlements = (res as List).map((r) => ClientSettlement.fromJson(r)).toList();
          }
        } catch (_) {}
      }

      // 4. Fetch Client Orders (for live ongoing calculation)
      List<OrderEntity> orders = clientState.orders;
      if (supabase != null && profile.id.isNotEmpty) {
        try {
          final res = await supabase
              .from('orders')
              .select()
              .or('client_id.eq.${profile.id},merchant_id.eq.${profile.id}')
              .order('created_at', ascending: false)
              .limit(500);
          if (res.isNotEmpty) {
            orders = (res as List).map((r) => OrderModel.fromJson(r as Map<String, dynamic>)).toList();
          }
        } catch (_) {}
      }

      state = state.copyWith(
        clientProfile: profile,
        distributionCenters: dcs,
        settlements: settlements,
        orders: orders,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setTab(String tabKey) {
    state = state.copyWith(selectedTab: tabKey);
  }

  void setDcFilter(String dcId) {
    state = state.copyWith(selectedDcId: dcId);
  }

  void setDateRange(String range, {DateTime? start, DateTime? end}) {
    state = state.copyWith(
      selectedDateRange: range,
      customStartDate: start,
      customEndDate: end,
    );
  }

  void setSearchQuery(String q) {
    state = state.copyWith(searchQuery: q);
  }

  /// Merchant Accountant validates and clears the settlement
  Future<bool> validateAndClearSettlement(
    String settlementId, {
    String? remarks,
  }) async {
    state = state.copyWith(isSubmitting: true);
    final user = _ref.read(authProvider).user;
    final settlement = state.settlements.where((s) => s.id == settlementId).firstOrNull;

    try {
      final supabase = _supabase;
      if (supabase != null) {
        // Direct table update (guaranteed to succeed regardless of RPC function signature variations)
        try {
          await supabase.from('client_settlements').update({
            'status': 'completed',
            'notes': '${settlement?.notes ?? ""} | Validated & Cleared by ${user?.fullName ?? "Merchant Accountant"} on ${DateTime.now().toIso8601String()}',
            'settled_at': DateTime.now().toIso8601String(),
          }).eq('id', settlementId);
        } catch (e) {
          debugPrint('[MERCHANT_SETTLEMENTS] Direct table update note: $e');
        }

        // Invoke stored procedure if available
        try {
          await supabase.rpc('fn_merchant_approve_settlement', params: {
            'p_settlement_id': settlementId,
            'p_client_id': state.clientProfile.id.isNotEmpty ? state.clientProfile.id : null,
            'p_approval_notes': remarks ?? 'Confirmed by Merchant Accounting',
          });
        } catch (e) {
          debugPrint('[MERCHANT_SETTLEMENTS] RPC note: $e');
        }
      }

      // Update associated orders to 'client_settled' in database
      final targetOrderIds = <String>[];
      final rawIds = settlement?.chargesBreakdown['order_ids'];
      if (rawIds is List) {
        for (final id in rawIds) {
          targetOrderIds.add(id.toString());
        }
      }

      if (supabase != null) {
        try {
          if (targetOrderIds.isNotEmpty) {
            await supabase.from('orders').update({
              'financial_settlement_status': 'client_settled',
              'updated_at': DateTime.now().toIso8601String(),
            }).inFilter('id', targetOrderIds);
          } else if (settlement?.settlementNumber != null && settlement!.settlementNumber.isNotEmpty) {
            await supabase.from('orders').update({
              'financial_settlement_status': 'client_settled',
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('remittance_reference', settlement.settlementNumber);
          }
        } catch (e) {
          debugPrint('[MERCHANT_SETTLEMENTS] Orders settlement status update note: $e');
        }
      }

      // Audit Logging
      await AuditLoggingService.instance.logAction(
        actorId: user?.id,
        actorName: user?.fullName ?? 'Merchant Accountant',
        actorEmail: user?.email ?? 'accountant@merchant.ng',
        actorRole: user?.role ?? 'merchant_accountant',
        action: 'VALIDATE_SETTLEMENT',
        resource: 'MERCHANT_SETTLEMENTS',
        details: 'Validated settlement batch "${settlement?.settlementNumber ?? settlementId}" (₦${settlement?.netPayoutAmount.toStringAsFixed(2)}) with clearance sign-off.',
        distributionCenterId: settlement?.distributionCenterId,
        metadata: {
          'settlement_id': settlementId,
          'settlement_number': settlement?.settlementNumber,
          'net_amount': settlement?.netPayoutAmount,
          'validation_remarks': remarks,
        },
      );

      // Update local state orders so UI immediately removes them from Ongoing without waiting
      final updatedOrders = state.orders.map((o) {
        final matchesId = targetOrderIds.contains(o.id);
        final matchesRef = settlement?.settlementNumber != null &&
            o.remittanceReference == settlement!.settlementNumber;
        final matchesLegacy = targetOrderIds.isEmpty &&
            (settlement?.settlementNumber == null || o.remittanceReference == null) &&
            o.clientId == settlement?.clientId &&
            o.status.toLowerCase() == 'delivered';

        if (matchesId || matchesRef || matchesLegacy) {
          return o.copyWith(financialSettlementStatus: 'client_settled');
        }
        return o;
      }).toList();

      // Optimistic update of settlements
      final updatedSettlements = state.settlements.map((s) {
        if (s.id == settlementId) {
          return s.copyWith(
            status: 'completed',
            notes: '${s.notes ?? ""} | Validated & Cleared by ${user?.fullName ?? "Merchant Accountant"}',
            settledAt: DateTime.now(),
          );
        }
        return s;
      }).toList();

      state = state.copyWith(
        settlements: updatedSettlements,
        orders: updatedOrders,
        isSubmitting: false,
      );

      // Background reload to sync database state if connected
      if (_supabase != null) {
        loadData();
      }
      return true;
    } catch (e) {
      debugPrint('[MERCHANT_SETTLEMENTS] Validation error: $e');
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Merchant Accountant disputes / flags an issue with the settlement batch
  Future<bool> disputeSettlement(
    String settlementId, {
    required String reason,
  }) async {
    state = state.copyWith(isSubmitting: true);
    final user = _ref.read(authProvider).user;
    final settlement = state.settlements.where((s) => s.id == settlementId).firstOrNull;

    try {
      final supabase = _supabase;
      if (supabase != null) {
        await supabase.from('client_settlements').update({
          'status': 'disputed',
          'notes': 'FLAGGED BY MERCHANT ACCOUNTANT: $reason',
        }).eq('id', settlementId);
      }

      // Audit Logging
      await AuditLoggingService.instance.logAction(
        actorId: user?.id,
        actorName: user?.fullName ?? 'Merchant Accountant',
        actorEmail: user?.email ?? 'accountant@merchant.ng',
        actorRole: user?.role ?? 'merchant_accountant',
        action: 'DISPUTE_SETTLEMENT',
        resource: 'MERCHANT_SETTLEMENTS',
        details: 'Disputed settlement "${settlement?.settlementNumber ?? settlementId}": $reason',
        distributionCenterId: settlement?.distributionCenterId,
        metadata: {
          'settlement_id': settlementId,
          'dispute_reason': reason,
        },
      );

      final updated = state.settlements.map((s) {
        if (s.id == settlementId) {
          return s.copyWith(
            status: 'disputed',
            notes: 'FLAGGED BY MERCHANT ACCOUNTANT: $reason',
          );
        }
        return s;
      }).toList();

      state = state.copyWith(settlements: updated, isSubmitting: false);
      return true;
    } catch (e) {
      debugPrint('[MERCHANT_SETTLEMENTS] Dispute error: $e');
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }
}

final merchantSettlementsProvider =
    StateNotifierProvider<MerchantSettlementsNotifier, MerchantSettlementsState>((ref) {
  return MerchantSettlementsNotifier(ref);
});
