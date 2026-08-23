import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../data/datasources/finance_remote_datasource.dart';
import '../../data/repositories/finance_repository_impl.dart';
import '../../domain/entities/remittance.dart';
import '../../domain/entities/transaction_item.dart';
import '../../domain/repositories/finance_repository.dart';

import '../../../../core/services/local_storage_service.dart';

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

  FinanceNotifier(this._repository, [LocalStorageService? storageService])
      : _storageService = storageService ?? LocalStorageServiceImpl(),
        super(FinanceState()) {
    _initCache();
    loadRemittances();
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

  Future<void> fetchRemittances() async {
    await loadRemittances();
  }

  Future<void> loadRemittances([String? agentId]) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final targetAgentId = agentId ?? SupabaseConstants.defaultDeliveryAgentId;
      final items = await _repository.getAgentRemittances(targetAgentId);
      final txns = await _repository.getRiderTransactions(targetAgentId);
      state = state.copyWith(
        isLoading: false,
        remittances: items,
        transactions: txns,
      );
      _storageService.cacheRemittances(items);
      _storageService.cacheTransactions(txns);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load remittances: $e',
      );
    }
  }

  Future<void> loadTransactions([String? agentId]) async {
    try {
      final targetAgentId = agentId ?? SupabaseConstants.defaultDeliveryAgentId;
      final txns = await _repository.getRiderTransactions(targetAgentId);
      state = state.copyWith(transactions: txns);
      _storageService.cacheTransactions(txns);
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
    double posFee = 0.0,
    String? depositReceiptUrl,
    String? referenceNumber,
    String? discrepancyReason,
    double? discrepancyAmount,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final targetAgentId = (agentId != null && agentId.isNotEmpty)
          ? agentId
          : SupabaseConstants.defaultDeliveryAgentId;
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
        posFee: posFee,
        depositReceiptUrl: depositReceiptUrl,
        referenceNumber: referenceNumber,
        discrepancyReason: discrepancyReason,
        discrepancyAmount: discrepancyAmount,
        notes: notes,
      );

      final updatedList = [newRemittance, ...state.remittances];
      state = state.copyWith(isLoading: false, remittances: updatedList);
      _storageService.cacheRemittances(updatedList);
      loadRemittances(targetAgentId);
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
      state = state.copyWith(isLoading: false);
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
  return FinanceNotifier(repo, storage);
});
