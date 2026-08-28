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

final financeRemoteDataSourceProvider = Provider<FinanceRemoteDataSource>((ref) {
  return FinanceRemoteDataSourceImpl(Supabase.instance.client);
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

  FinanceNotifier(this._repository, {LocalStorageService? storageService, Ref? ref})
      : _storageService = storageService ?? LocalStorageServiceImpl(),
        _ref = ref,
        super(FinanceState()) {
    _initCache();
    if (_ref != null) {
      _ref.listen<AuthState>(authProvider, (previous, next) {
        final nextAgentId = next.user?.deliveryAgentId ?? next.user?.id;
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

      final otherRemittances = state.remittances.where((r) =>
        r.referenceNumber != newRemittance.referenceNumber &&
        (r.id.isEmpty || r.id != newRemittance.id)
      ).toList();

      final updated = [newRemittance, ...otherRemittances];
      updated.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = state.copyWith(
        isLoading: false,
        remittances: updated,
      );

      await _storageService.cacheRemittances(updated);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to submit remittance: $e',
      );
      return false;
    }
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
}

final financeProvider = StateNotifierProvider<FinanceNotifier, FinanceState>((ref) {
  final repo = ref.watch(financeRepositoryProvider);
  final storage = ref.watch(localStorageServiceProvider);
  return FinanceNotifier(repo, storageService: storage, ref: ref);
});
