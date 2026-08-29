import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/finance_remote_datasource.dart';
import '../../data/repositories/finance_repository_impl.dart';
import '../../domain/entities/remittance.dart';
import '../../domain/entities/transaction_item.dart';
import '../../domain/repositories/finance_repository.dart';
import '../../../orders/presentation/providers/orders_provider.dart';

final financeRemoteDataSourceProvider = Provider<FinanceRemoteDataSource>((ref) {
  try {
    return FinanceRemoteDataSourceImpl(Supabase.instance.client);
  } catch (_) {
    return FinanceRemoteDataSourceImpl(
      SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseAnonKey,
      ),
    );
  }
});

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepositoryImpl(ref.watch(financeRemoteDataSourceProvider));
});

class FinanceState {
  final bool isLoading;
  final List<RemittanceEntity> remittances;
  final List<TransactionItem> transactions;
  final String activeFilter; // 'All', 'Verified', 'Pending', 'Rejected', 'Disputed'
  final String? errorMessage;
  final double cashInCustody;
  final double totalEarnedBalance;

  FinanceState({
    this.isLoading = false,
    this.remittances = const [],
    this.transactions = const [],
    this.activeFilter = 'All',
    this.errorMessage,
    this.cashInCustody = 0.0,
    this.totalEarnedBalance = 0.0,
  });

  FinanceState copyWith({
    bool? isLoading,
    List<RemittanceEntity>? remittances,
    List<TransactionItem>? transactions,
    String? activeFilter,
    String? errorMessage,
    double? cashInCustody,
    double? totalEarnedBalance,
  }) {
    return FinanceState(
      isLoading: isLoading ?? this.isLoading,
      remittances: remittances ?? this.remittances,
      transactions: transactions ?? this.transactions,
      activeFilter: activeFilter ?? this.activeFilter,
      errorMessage: errorMessage,
      cashInCustody: cashInCustody ?? this.cashInCustody,
      totalEarnedBalance: totalEarnedBalance ?? this.totalEarnedBalance,
    );
  }

  double get totalVerifiedRemitted => remittances
      .where((r) => r.isVerified)
      .fold(0.0, (sum, r) => sum + r.amount);

  double get totalPendingRemittance => remittances
      .where((r) => r.isPending)
      .fold(0.0, (sum, r) => sum + r.amount);

  List<RemittanceEntity> get filteredRemittances {
    if (activeFilter == 'All') return remittances;
    if (activeFilter == 'Verified') return remittances.where((r) => r.isVerified).toList();
    if (activeFilter == 'Pending') return remittances.where((r) => r.isPending).toList();
    if (activeFilter == 'Rejected') return remittances.where((r) => r.isRejected).toList();
    if (activeFilter == 'Disputed') return remittances.where((r) => r.isDisputed).toList();
    return remittances;
  }
}

class FinanceNotifier extends StateNotifier<FinanceState> {
  final FinanceRepository _repository;
  final LocalStorageService _storageService;
  final Ref? _ref;

  String? _lastAgentId;
  RealtimeChannel? _realtimeChannel;
  Timer? _heartbeatTimer;

  FinanceNotifier(this._repository, {LocalStorageService? storageService, Ref? ref})
      : _storageService = storageService ?? LocalStorageServiceImpl(),
        _ref = ref,
        super(FinanceState()) {
    _initCache();
    _initRealtimeSubscription();
    _startHeartbeatTimer();
    if (_ref != null) {
      _ref.listen<AuthState>(authProvider, (previous, next) {
        final nextAgentId = next.user?.deliveryAgentId ?? next.user?.distributionCenterId ?? next.user?.id;
        if (nextAgentId != null && nextAgentId.isNotEmpty && nextAgentId != _lastAgentId) {
          loadRemittances(nextAgentId);
        }
      });
    }
  }

  Future<void> _initCache() async {
    final cachedRem = await _storageService.getCachedRemittances();
    final cachedTxns = await _storageService.getCachedTransactions();
    if ((cachedRem != null && cachedRem.isNotEmpty) || (cachedTxns != null && cachedTxns.isNotEmpty)) {
      state = state.copyWith(
        remittances: cachedRem ?? state.remittances,
        transactions: cachedTxns ?? state.transactions,
      );
    }
  }

  void _initRealtimeSubscription() {
    try {
      final binding = WidgetsBinding.instance.runtimeType.toString().toLowerCase();
      if (binding.contains('test') || binding.contains('automated')) {
        return;
      }
    } catch (_) {}
    try {
      if (!kIsWeb && (Platform.environment.containsKey('FLUTTER_TEST') ||
          Platform.environment.containsKey('TEST_PLATFORM'))) {
        return;
      }
    } catch (_) {}
    try {
      _realtimeChannel = Supabase.instance.client
          .channel('public_cash_remittances_realtime_channel')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'cash_remittances',
            callback: (payload) {
              debugPrint('[FINANCE_REALTIME] 🔔 Realtime event on cash_remittances: ${payload.eventType}');
              _silentSyncRemittances();
            },
          )
          .subscribe();
      debugPrint('[FINANCE_PROVIDER] 📡 Finance Realtime stream active.');
    } catch (e) {
      debugPrint('[FINANCE_PROVIDER] ℹ️ Realtime channel notice: $e');
    }
  }

  void _startHeartbeatTimer() {
    try {
      if (WidgetsBinding.instance.runtimeType.toString().toLowerCase().contains('test')) {
        return;
      }
    } catch (_) {}
    if (!kIsWeb) {
      try {
        if (Platform.environment.containsKey('FLUTTER_TEST') ||
            Platform.environment.containsKey('TEST_PLATFORM')) {
          return;
        }
      } catch (_) {}
    }
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      _silentSyncRemittances();
    });
  }

  Future<void> _silentSyncRemittances() async {
    if (!mounted) return;
    try {
      String? targetId = _lastAgentId;
      if ((targetId == null || targetId.isEmpty) && _ref != null) {
        final user = _ref.read(authProvider).user;
        targetId = user?.deliveryAgentId ?? user?.distributionCenterId ?? user?.id;
      }
      if (targetId == null || targetId.isEmpty) return;

      final remoteItems = await _repository.getAgentRemittances(targetId);
      final finalItems = List<RemittanceEntity>.from(remoteItems);
      finalItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;

      bool hasChanges = finalItems.length != state.remittances.length;
      if (!hasChanges) {
        for (int i = 0; i < finalItems.length; i++) {
          final f = finalItems[i];
          final s = state.remittances[i];
          if (f.id != s.id ||
              f.status != s.status ||
              f.amount != s.amount ||
              f.verifiedAt != s.verifiedAt) {
            hasChanges = true;
            break;
          }
        }
      }

      if (hasChanges && mounted) {
        debugPrint('[FINANCE_PROVIDER] ⚡ Auto-synced ${finalItems.length} remittances in real time.');
        state = state.copyWith(remittances: finalItems);
        await _storageService.cacheRemittances(finalItems);
      }
    } catch (_) {}
  }

  Future<void> fetchRemittances([String? agentId]) async {
    await loadRemittances(agentId);
  }

  Future<void> loadRemittances([String? agentId]) async {
    String? targetAgentId = (agentId != null && agentId.isNotEmpty) ? agentId : _lastAgentId;
    if ((targetAgentId == null || targetAgentId.isEmpty) && _ref != null) {
      final user = _ref.read(authProvider).user;
      final role = user?.role.toLowerCase() ?? '';
      if (role.contains('rider') || role.contains('agent') || role.contains('driver') || user?.isPda == true) {
        targetAgentId = user?.deliveryAgentId ?? user?.id;
      } else {
        targetAgentId = user?.distributionCenterId ?? user?.id;
      }
    }
    if (targetAgentId == null || targetAgentId.isEmpty) {
      return;
    }
    _lastAgentId = targetAgentId;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final remoteItems = await _repository.getAgentRemittances(targetAgentId);
      final txns = await _repository.getRiderTransactions(targetAgentId);

      final finalItems = List<RemittanceEntity>.from(remoteItems);
      finalItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = state.copyWith(
        isLoading: false,
        remittances: finalItems,
        transactions: txns.isNotEmpty ? txns : state.transactions,
      );
      _storageService.cacheRemittances(finalItems);
      if (txns.isNotEmpty) _storageService.cacheTransactions(txns);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load remittances: $e',
      );
    }
  }

  Future<void> loadTransactions([String? agentId]) async {
    try {
      String? targetAgentId = (agentId != null && agentId.isNotEmpty) ? agentId : _lastAgentId;
      if ((targetAgentId == null || targetAgentId.isEmpty) && _ref != null) {
        final user = _ref.read(authProvider).user;
        targetAgentId = user?.deliveryAgentId ?? user?.id;
      }
      if (targetAgentId != null && targetAgentId.isNotEmpty) {
        final txns = await _repository.getRiderTransactions(targetAgentId);
        state = state.copyWith(transactions: txns);
        _storageService.cacheTransactions(txns);
      }
    } catch (_) {}
  }

  void setFilter(String filter) {
    state = state.copyWith(activeFilter: filter);
  }

  Future<bool> submitRemittance({
    required double amount,
    required String paymentMethod,
    String? agentId,
    String? companyId,
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
    state = state.copyWith(isLoading: true);
    try {
      final targetAgentId = (agentId != null && agentId.isNotEmpty)
          ? agentId
          : (_lastAgentId != null && _lastAgentId!.isNotEmpty ? _lastAgentId! : SupabaseConstants.defaultDeliveryAgentId);
      final targetCompanyId = (companyId != null && companyId.isNotEmpty)
          ? companyId
          : '11111111-1111-4111-8111-111111111111';

      final newRemittance = await _repository.submitRemittance(
        agentId: targetAgentId,
        companyId: targetCompanyId,
        amount: amount,
        paymentMethod: paymentMethod,
        grossCollections: grossCollections,
        commissionDeducted: commissionDeducted,
        transportAllowanceDeducted: transportAllowanceDeducted,
        failedStipendsDeducted: failedStipendsDeducted,
        posFee: posFee,
        depositReceiptUrl: depositReceiptUrl,
        referenceNumber: referenceNumber,
        discrepancyReason: discrepancyReason,
        discrepancyAmount: discrepancyAmount,
        expectedAmount: expectedAmount,
        isPartial: isPartial,
        notes: notes,
        associatedOrders: associatedOrders,
      );

      final updated = [newRemittance, ...state.remittances.where((r) => r.id != newRemittance.id)];
      updated.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = state.copyWith(
        isLoading: false,
        remittances: updated,
      );

      await _storageService.cacheRemittances(updated);
      if (_ref != null) {
        final orderStatusToSet = newRemittance.isVerified ? 'remitted' : 'remittance_pending';
        for (final ao in associatedOrders) {
          if (ao.orderId.isNotEmpty) {
            await _ref.read(ordersProvider.notifier).updateOrderPaymentStatus(
              orderId: ao.orderId,
              paymentStatus: 'collected',
              remittanceStatus: orderStatusToSet,
            );
          }
        }
      }
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to submit remittance: $e',
      );
      return false;
    }
  }

  Future<void> recordDirectTransferEarning({
    required String agentId,
    required String orderNumber,
    required double amount,
    double commission = 0.0,
    double transport = 0.0,
  }) async {
    try {
      final newTxn = TransactionItem(
        id: 'TXN-EARN-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Direct Transfer POD Earning',
        category: 'earning',
        amount: amount,
        isCredit: true,
        timestamp: DateTime.now(),
        reference: 'EARN-$orderNumber-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
        status: 'completed',
        description: 'Direct Transfer POD commission (₦${commission.toStringAsFixed(0)}) + transport (₦${transport.toStringAsFixed(0)}) credited for Order $orderNumber.',
      );

      final updatedTxns = [newTxn, ...state.transactions];
      final newBalance = state.totalEarnedBalance + amount;
      state = state.copyWith(
        transactions: updatedTxns,
        totalEarnedBalance: newBalance,
      );
      await _storageService.cacheTransactions(updatedTxns);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> requestPayout({
    required String agentId,
    required double amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _repository.requestPayout(
        agentId: agentId,
        amount: amount,
        bankName: bankName,
        accountNumber: accountNumber,
        accountName: accountName,
        notes: notes,
      );

      final newTxn = TransactionItem(
        id: result['id']?.toString() ?? 'TXN-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Balance Payout Requested',
        category: 'payout',
        amount: amount,
        isCredit: false,
        timestamp: DateTime.now(),
        reference: result['reference']?.toString() ?? 'PAYOUT-${DateTime.now().millisecondsSinceEpoch}',
        status: 'pending',
        description: 'Payout of ₦${amount.toStringAsFixed(2)} to $bankName ($accountNumber).',
      );
      final updatedTxns = [newTxn, ...state.transactions];
      state = state.copyWith(isLoading: false, transactions: updatedTxns);
      _storageService.cacheTransactions(updatedTxns);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return {'status': 'error', 'error': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> loadPayoutRequests(String agentId) async {
    try {
      return await _repository.getPayoutRequests(agentId);
    } catch (_) {
      return [];
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    try {
      _realtimeChannel?.unsubscribe();
    } catch (_) {}
    super.dispose();
  }
}

final financeProvider = StateNotifierProvider<FinanceNotifier, FinanceState>((ref) {
  final repo = ref.watch(financeRepositoryProvider);
  final storage = ref.watch(localStorageServiceProvider);
  return FinanceNotifier(repo, storageService: storage, ref: ref);
});
