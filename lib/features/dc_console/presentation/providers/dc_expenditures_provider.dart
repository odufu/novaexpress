import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../client_portal/data/repositories/expenditure_repository.dart';
import '../../../client_portal/domain/entities/business_expenditure.dart';
import '../../domain/entities/distribution_center.dart';
import 'dc_console_provider.dart';

final expenditureRepositoryProvider = Provider<ExpenditureRepository>((ref) {
  return ExpenditureRepository();
});

class DCExpendituresState {
  final List<BusinessExpenditureEntity> expenditures;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final String searchQuery;
  final String selectedCategory; // 'all' or db category value
  final String selectedDcId; // 'all' or specific DC UUID
  final DateTime? startDate;
  final DateTime? endDate;
  final String datePreset; // 'This Month', 'Today', 'This Week', 'All Time', 'Custom'

  const DCExpendituresState({
    this.expenditures = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.searchQuery = '',
    this.selectedCategory = 'all',
    this.selectedDcId = 'all',
    this.startDate,
    this.endDate,
    this.datePreset = 'This Month',
  });

  DCExpendituresState copyWith({
    List<BusinessExpenditureEntity>? expenditures,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    String? searchQuery,
    String? selectedCategory,
    String? selectedDcId,
    DateTime? startDate,
    DateTime? endDate,
    String? datePreset,
  }) {
    return DCExpendituresState(
      expenditures: expenditures ?? this.expenditures,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedDcId: selectedDcId ?? this.selectedDcId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      datePreset: datePreset ?? this.datePreset,
    );
  }

  /// Filtered expenditures based on search, category, and station
  List<BusinessExpenditureEntity> get filteredExpenditures {
    final query = searchQuery.trim().toLowerCase();
    return expenditures.where((exp) {
      // 1. DC Filter
      if (selectedDcId != 'all' && selectedDcId.isNotEmpty) {
        if (exp.distributionCenterId != selectedDcId) return false;
      }

      // 2. Category Filter
      if (selectedCategory != 'all' && selectedCategory.isNotEmpty) {
        if (exp.category.toDbValue() != selectedCategory) return false;
      }

      // 3. Search Query Filter
      if (query.isNotEmpty) {
        final titleMatch = exp.title.toLowerCase().contains(query);
        final descMatch = (exp.description ?? '').toLowerCase().contains(query);
        final vendorMatch = (exp.vendorName ?? '').toLowerCase().contains(query);
        final invMatch = (exp.invoiceNumber ?? '').toLowerCase().contains(query);
        if (!titleMatch && !descMatch && !vendorMatch && !invMatch) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // Core business KPIs
  double get totalExpenditure =>
      filteredExpenditures.fold(0.0, (sum, e) => sum + e.amount);

  double get fuelAndLogisticsTotal => filteredExpenditures
      .where((e) =>
          e.category == ExpenditureCategory.dieselFuel ||
          e.category == ExpenditureCategory.riderAllowance ||
          e.category == ExpenditureCategory.logistics)
      .fold(0.0, (sum, e) => sum + e.amount);

  double get facilityAndUtilitiesTotal => filteredExpenditures
      .where((e) =>
          e.category == ExpenditureCategory.rentUtilities ||
          e.category == ExpenditureCategory.equipmentMaintenance ||
          e.category == ExpenditureCategory.facilitySupplies ||
          e.category == ExpenditureCategory.security)
      .fold(0.0, (sum, e) => sum + e.amount);

  double get packagingTotal => filteredExpenditures
      .where((e) =>
          e.category == ExpenditureCategory.packaging ||
          e.category == ExpenditureCategory.stationery)
      .fold(0.0, (sum, e) => sum + e.amount);

  int get totalInvoicesCount => filteredExpenditures.length;

  int get receiptsAttachedCount =>
      filteredExpenditures.where((e) => e.hasReceipt).length;

  double get receiptVerificationRate => totalInvoicesCount > 0
      ? (receiptsAttachedCount / totalInvoicesCount) * 100.0
      : 0.0;
}

class DCExpendituresNotifier extends StateNotifier<DCExpendituresState> {
  final ExpenditureRepository _repository;
  final Ref _ref;

  DCExpendituresNotifier(this._repository, this._ref)
      : super(DCExpendituresState(
          startDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
          endDate: DateTime.now(),
        )) {
    _initDefaultsAndLoad();
  }

  void _initDefaultsAndLoad() {
    final authUser = _ref.read(authProvider).user;
    final dcList = _ref.read(dcConsoleProvider).distributionCenters;

    // Determine if logged-in user is Main DC (Abuja) or a branch DC
    final userDcId = authUser?.distributionCenterId;
    final isAbujaMain = _isMainDc(userDcId, dcList);

    if (isAbujaMain || userDcId == null || userDcId.isEmpty) {
      // Main DC can see All DCs by default
      state = state.copyWith(selectedDcId: 'all');
    } else {
      // Branch DC is locked to their DC
      state = state.copyWith(selectedDcId: userDcId);
    }

    loadExpenditures();
  }

  static bool _isMainDc(String? dcId, List<DistributionCenter> dcs) {
    if (dcId == null || dcId.isEmpty) return true; // Defaults to high permission if unassigned
    final dc = dcs.where((d) => d.id == dcId || d.code == dcId).firstOrNull;
    if (dc == null) return false;
    final name = dc.name.toLowerCase();
    final code = dc.code.toLowerCase();
    return name.contains('wuse') ||
        name.contains('abuja') ||
        code.contains('wuse') ||
        code == 'dc-wuse-01';
  }

  Future<void> loadExpenditures() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final authUser = _ref.read(authProvider).user;
      final dcList = _ref.read(dcConsoleProvider).distributionCenters;
      final userDcId = authUser?.distributionCenterId;
      final isAbujaMain = _isMainDc(userDcId, dcList);

      // Scoping security: if not Main DC, force scoping to user's DC
      final effectiveDcId = isAbujaMain ? state.selectedDcId : (userDcId ?? state.selectedDcId);

      final list = await _repository.fetchDcExpenditures(
        dcId: effectiveDcId,
        category: state.selectedCategory,
        startDate: state.startDate,
        endDate: state.endDate,
      );

      state = state.copyWith(
        expenditures: list,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load expenditures: $e',
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
    loadExpenditures();
  }

  void setDcFilter(String dcId) {
    state = state.copyWith(selectedDcId: dcId);
    loadExpenditures();
  }

  void setDateRange(DateTime? start, DateTime? end, {String? preset}) {
    state = state.copyWith(
      startDate: start,
      endDate: end,
      datePreset: preset ?? 'Custom',
    );
    loadExpenditures();
  }

  Future<bool> createExpenditure({
    required String title,
    String? description,
    required ExpenditureCategory category,
    required double amount,
    required DateTime expenditureDate,
    required String distributionCenterId,
    String? invoiceNumber,
    String? vendorName,
    String? paymentMethod,
    Uint8List? receiptBytes,
    String? receiptFileName,
    String? receiptMimeType,
    String? receiptUrlDirect,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      String? receiptUrl = receiptUrlDirect;
      String? storedFileName = receiptFileName;
      String? storedMimeType = receiptMimeType;

      // 1. Upload receipt attachment if bytes provided
      if (receiptBytes != null && receiptFileName != null) {
        final uploaded = await _repository.uploadReceiptAttachment(
          fileBytes: receiptBytes,
          fileName: receiptFileName,
          mimeType: receiptMimeType ?? 'image/jpeg',
          entityId: distributionCenterId,
        );
        receiptUrl = uploaded;
        storedFileName = receiptFileName;
        storedMimeType = receiptMimeType;
      }

      final authUser = _ref.read(authProvider).user;
      final dcList = _ref.read(dcConsoleProvider).distributionCenters;
      final isAbujaMain = _isMainDc(distributionCenterId, dcList);

      final entity = BusinessExpenditureEntity(
        id: '', // Will be assigned by database gen_random_uuid()
        entityType: isAbujaMain ? 'grand_dc' : 'sub_dc',
        distributionCenterId: distributionCenterId,
        title: title,
        description: description,
        category: category,
        amount: amount,
        expenditureDate: expenditureDate,
        invoiceNumber: invoiceNumber,
        vendorName: vendorName,
        paymentMethod: paymentMethod ?? 'transfer',
        status: 'approved',
        receiptUrl: receiptUrl,
        receiptFileName: storedFileName,
        receiptMimeType: storedMimeType,
        createdBy: authUser?.id,
        createdAt: DateTime.now(),
      );

      final created = await _repository.createExpenditure(entity);
      if (created != null) {
        state = state.copyWith(
          expenditures: [created, ...state.expenditures],
          isSubmitting: false,
        );
        return true;
      }
      state = state.copyWith(isSubmitting: false);
      return false;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Failed to record expenditure: $e',
      );
      return false;
    }
  }

  Future<bool> deleteExpenditure(String id) async {
    try {
      final ok = await _repository.deleteExpenditure(id);
      if (ok) {
        state = state.copyWith(
          expenditures: state.expenditures.where((e) => e.id != id).toList(),
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting expenditure: $e');
      return false;
    }
  }
}

final dcExpendituresProvider =
    StateNotifierProvider<DCExpendituresNotifier, DCExpendituresState>((ref) {
  final repo = ref.watch(expenditureRepositoryProvider);
  return DCExpendituresNotifier(repo, ref);
});
