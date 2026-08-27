import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../data/datasources/stock_remote_datasource.dart';
import '../../data/repositories/stock_repository_impl.dart';
import '../../domain/entities/stock_item.dart';
import '../../domain/repositories/stock_repository.dart';

enum StockFilter {
  all,
  available,
  lowStock,
  outOfStock,
}

class InboundStockRequest {
  final String requestId;
  final String dcName;
  final String status; // 'Awaiting DC Review', 'Partially Approved', 'Ready for Collection', 'Completed'
  final DateTime? requestDate;
  final Map<String, int> requestedQuantities;
  final Map<String, int> approvedQuantities;

  const InboundStockRequest({
    required this.requestId,
    required this.dcName,
    required this.status,
    this.requestDate,
    required this.requestedQuantities,
    required this.approvedQuantities,
  });
}

class StockState {
  final bool isLoading;
  final List<StockItemEntity> stockItems;
  final List<InboundStockRequest> inboundRequests;
  final String searchQuery;
  final StockFilter activeFilter;
  final String? errorMessage;
  final DateTime? lastAuditedTime;
  final bool isAuditRequired;

  const StockState({
    this.isLoading = true,
    this.stockItems = const [],
    this.inboundRequests = const [],
    this.searchQuery = '',
    this.activeFilter = StockFilter.all,
    this.errorMessage,
    this.lastAuditedTime,
    this.isAuditRequired = false,
  });

  int get totalInCustody {
    return stockItems.fold(0, (acc, item) => acc + item.assignedCount);
  }

  int get totalReserved {
    return stockItems.fold(0, (acc, item) => acc + item.reservedCount);
  }

  int get totalAvailable {
    return stockItems.fold(0, (acc, item) => acc + item.availableCount);
  }

  int get totalAwaitingReturn {
    return stockItems.fold(0, (acc, item) => acc + item.awaitingReturnCount);
  }

  int get totalUnitsHeld => totalAvailable;

  int get availableCountFiltered => stockItems.where((i) => i.status == StockStatus.available).length;
  int get lowStockCountFiltered => stockItems.where((i) => i.status == StockStatus.lowStock).length;
  int get outOfStockCountFiltered => stockItems.where((i) => i.status == StockStatus.outOfStock).length;

  List<StockItemEntity> get lowStockItems => stockItems.where((i) => i.status == StockStatus.lowStock).toList();

  List<StockItemEntity> get filteredStockItems {
    var list = stockItems;

    // Apply Filter
    switch (activeFilter) {
      case StockFilter.all:
        break;
      case StockFilter.available:
        list = list.where((i) => i.status == StockStatus.available).toList();
        break;
      case StockFilter.lowStock:
        list = list.where((i) => i.status == StockStatus.lowStock).toList();
        break;
      case StockFilter.outOfStock:
        list = list.where((i) => i.status == StockStatus.outOfStock).toList();
        break;
    }

    // Apply Search Query
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list.where((item) {
        return item.name.toLowerCase().contains(q) ||
            item.sku.toLowerCase().contains(q) ||
            item.category.toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }

  StockState copyWith({
    bool? isLoading,
    List<StockItemEntity>? stockItems,
    List<InboundStockRequest>? inboundRequests,
    String? searchQuery,
    StockFilter? activeFilter,
    String? errorMessage,
    DateTime? lastAuditedTime,
    bool? isAuditRequired,
  }) {
    return StockState(
      isLoading: isLoading ?? this.isLoading,
      stockItems: stockItems ?? this.stockItems,
      inboundRequests: inboundRequests ?? this.inboundRequests,
      searchQuery: searchQuery ?? this.searchQuery,
      activeFilter: activeFilter ?? this.activeFilter,
      errorMessage: errorMessage,
      lastAuditedTime: lastAuditedTime ?? this.lastAuditedTime,
      isAuditRequired: isAuditRequired ?? this.isAuditRequired,
    );
  }
}

class StockNotifier extends StateNotifier<StockState> {
  final StockRepository repository;
  final LocalStorageService _storageService;

  StockNotifier({
    required this.repository,
    LocalStorageService? storageService,
  })  : _storageService = storageService ?? LocalStorageServiceImpl(),
        super(const StockState()) {
    _initCache();
    fetchStockItems();
  }

  Future<void> _initCache() async {
    final cached = await _storageService.getCachedStockItems();
    if (cached != null && cached.isNotEmpty) {
      state = state.copyWith(
        isLoading: false,
        stockItems: cached,
      );
    }
  }

  Future<void> fetchStockItems([String? agentId]) async {
    state = state.copyWith(isLoading: state.stockItems.isEmpty, errorMessage: null);
    try {
      final items = await repository.getVehicleStockItems(agentId);
      final defaultRequests = [
        const InboundStockRequest(
          requestId: 'REQ-00482',
          dcName: 'Wuse Distribution Center',
          status: 'Ready for Collection',
          requestDate: null,
          requestedQuantities: {
            'Respira Detox Tea': 10,
            'Grazer Herbal Tea': 20,
          },
          approvedQuantities: {
            'Respira Detox Tea': 10,
            'Grazer Herbal Tea': 20,
          },
        ),
      ];

      state = state.copyWith(
        isLoading: false,
        stockItems: items,
        inboundRequests: state.inboundRequests.isNotEmpty ? state.inboundRequests : defaultRequests,
        lastAuditedTime: DateTime.now().subtract(const Duration(hours: 4)),
        isAuditRequired: false,
      );
      _storageService.cacheStockItems(items);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to sync vehicle stock.',
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilter(StockFilter filter) {
    state = state.copyWith(activeFilter: filter);
  }

  void addStockRequest({
    required String dcName,
    required Map<String, int> quantities,
  }) {
    final newReqId = 'REQ-${(10000 + state.inboundRequests.length + 1).toString().substring(1)}';
    final newRequest = InboundStockRequest(
      requestId: newReqId,
      dcName: dcName,
      status: 'Awaiting DC Review',
      requestDate: DateTime.now(),
      requestedQuantities: quantities,
      approvedQuantities: quantities,
    );

    state = state.copyWith(
      inboundRequests: [newRequest, ...state.inboundRequests],
    );
  }

  void completeStockHandover(String requestId) {
    InboundStockRequest? targetReq;
    final updatedRequests = state.inboundRequests.map((r) {
      if (r.requestId == requestId) {
        targetReq = r;
        return InboundStockRequest(
          requestId: r.requestId,
          dcName: r.dcName,
          status: 'Completed',
          requestDate: r.requestDate,
          requestedQuantities: r.requestedQuantities,
          approvedQuantities: r.approvedQuantities,
        );
      }
      return r;
    }).toList();

    List<StockItemEntity> updatedItems = state.stockItems;
    if (targetReq != null) {
      final approved = targetReq!.approvedQuantities;
      updatedItems = state.stockItems.map((item) {
        int addUnits = 0;
        approved.forEach((pName, qty) {
          if (item.name.toLowerCase().contains(pName.toLowerCase()) || pName.toLowerCase().contains(item.name.toLowerCase())) {
            addUnits += qty;
          }
        });
        if (addUnits > 0) {
          return StockItemEntity(
            id: item.id,
            sku: item.sku,
            name: item.name,
            description: item.description,
            price: item.price,
            ownerName: item.ownerName,
            inventoryType: item.inventoryType,
            totalInCustody: item.totalInCustody + addUnits,
            reservedCount: item.reservedCount,
            assignedCount: item.assignedCount + addUnits,
            deliveredCount: item.deliveredCount,
            availableCount: item.availableCount + addUnits,
            returnedCount: item.returnedCount,
            awaitingReturnCount: item.awaitingReturnCount,
            lowStockThreshold: item.lowStockThreshold,
            reorderLevel: item.reorderLevel,
            category: item.category,
            imageAsset: item.imageAsset,
            batchNumber: item.batchNumber,
            lastAuditDate: item.lastAuditDate,
          );
        }
        return item;
      }).toList();
    }

    state = state.copyWith(
      inboundRequests: updatedRequests,
      stockItems: updatedItems,
    );
  }

  void recordAuditSubmission() {
    state = state.copyWith(
      lastAuditedTime: DateTime.now(),
      isAuditRequired: false,
    );
  }

  Future<Map<String, dynamic>> requestStockTransfer({
    required String agentId,
    required String companyId,
    required String sourceWarehouseId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await repository.requestStockTransfer(
        agentId: agentId,
        companyId: companyId,
        sourceWarehouseId: sourceWarehouseId,
        items: items,
        notes: notes,
      );
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return {'status': 'error', 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> confirmStockHandover({
    required String requestId,
    required String handoverCode,
    required String agentId,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await repository.confirmStockHandover(
        requestId: requestId,
        handoverCode: handoverCode,
        agentId: agentId,
      );
      completeStockHandover(requestId);
      await fetchStockItems();
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return {'status': 'error', 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> processStockReturn({
    required String returnNumber,
    required String orderId,
    required String deliveryAgentId,
    required String productId,
    required int quantity,
    required String reason,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await repository.processStockReturn(
        returnNumber: returnNumber,
        orderId: orderId,
        deliveryAgentId: deliveryAgentId,
        productId: productId,
        quantity: quantity,
        reason: reason,
        notes: notes,
      );
      await fetchStockItems();
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return {'status': 'error', 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> submitInventoryAudit({
    required String distributionCenterId,
    required String auditedBy,
    required int totalPhysicalCounted,
    required int totalSystemExpected,
    required int discrepancyCount,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await repository.submitInventoryAudit(
        distributionCenterId: distributionCenterId,
        auditedBy: auditedBy,
        totalPhysicalCounted: totalPhysicalCounted,
        totalSystemExpected: totalSystemExpected,
        discrepancyCount: discrepancyCount,
        notes: notes,
      );
      recordAuditSubmission();
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return {'status': 'error', 'error': e.toString()};
    }
  }
}

final stockRemoteDataSourceProvider = Provider<StockRemoteDataSource>((ref) {
  try {
    return StockRemoteDataSourceImpl(
      supabaseClient: Supabase.instance.client,
    );
  } catch (_) {
    return StockRemoteDataSourceImpl(
      supabaseClient: SupabaseClient('https://mock.supabase.co', 'mock-anon-key'),
    );
  }
});

final stockRepositoryProvider = Provider<StockRepository>((ref) {
  final remote = ref.watch(stockRemoteDataSourceProvider);
  return StockRepositoryImpl(remoteDataSource: remote);
});

final stockProvider = StateNotifierProvider<StockNotifier, StockState>((ref) {
  final repo = ref.watch(stockRepositoryProvider);
  final storage = ref.watch(localStorageServiceProvider);
  return StockNotifier(repository: repo, storageService: storage);
});
