import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../data/datasources/stock_remote_datasource.dart';
import '../../data/repositories/stock_repository_impl.dart';
import '../../domain/entities/rider_stock_allocation.dart';
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
  final List<RiderStockAllocation> riderAllocations;
  final List<InboundStockRequest> inboundRequests;
  final String searchQuery;
  final StockFilter activeFilter;
  final String? errorMessage;
  final DateTime? lastAuditedTime;
  final bool isAuditRequired;

  const StockState({
    this.isLoading = true,
    this.stockItems = const [],
    this.riderAllocations = const [],
    this.inboundRequests = const [],
    this.searchQuery = '',
    this.activeFilter = StockFilter.all,
    this.errorMessage,
    this.lastAuditedTime,
    this.isAuditRequired = false,
  });

  // --- Connected Stock Accounting Properties ---

  /// Warehouse shelf stock currently available in DC storage bins
  int get totalWarehouseAvailable {
    return stockItems.fold(0, (acc, item) => acc + item.availableCount);
  }

  /// Total physical units currently held in custody across all riders' vehicles
  int get totalInRiderCustody {
    final allocationsSum = riderAllocations.fold(0, (acc, item) => acc + item.inCustodyUnits);
    final assignedOrdersSum = stockItems.fold(0, (acc, item) => acc + (item.assignedCount - item.deliveredCount - item.returnedCount).clamp(0, 999999));
    return allocationsSum > assignedOrdersSum ? allocationsSum : assignedOrdersSum;
  }

  /// Total DC Stock = Warehouse Shelf Available + In Rider Custody
  int get totalDCStock {
    return totalWarehouseAvailable + totalInRiderCustody;
  }

  /// Total monetary valuation of all stock in DC custody
  double get totalDCStockValuation {
    return stockItems.fold(0.0, (acc, item) => acc + ((item.availableCount + item.assignedCount) * item.price));
  }

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
  int get lowStockCountFiltered => stockItems.where((i) => i.status == StockStatus.lowStock || (i.availableCount <= i.lowStockThreshold && i.availableCount > 0)).length;
  int get outOfStockCountFiltered => stockItems.where((i) => i.status == StockStatus.outOfStock || i.availableCount <= 0).length;

  List<StockItemEntity> get lowStockItems => stockItems.where((i) => i.status == StockStatus.lowStock || (i.availableCount <= i.lowStockThreshold && i.availableCount > 0)).toList();

  List<RiderStockAllocation> getAllocationsForRider(String riderId, [String? riderCode]) {
    return riderAllocations.where((a) {
      final matchesId = a.riderId.isNotEmpty && a.riderId == riderId;
      final matchesCode = riderCode != null && riderCode.isNotEmpty && a.riderCode == riderCode;
      return (matchesId || matchesCode) && a.inCustodyUnits > 0;
    }).toList();
  }

  List<StockItemEntity> get filteredStockItems {
    var list = stockItems;

    // Apply Filter
    switch (activeFilter) {
      case StockFilter.all:
        break;
      case StockFilter.available:
        list = list.where((i) => i.availableCount > i.lowStockThreshold).toList();
        break;
      case StockFilter.lowStock:
        list = list.where((i) => i.status == StockStatus.lowStock || (i.availableCount <= i.lowStockThreshold && i.availableCount > 0)).toList();
        break;
      case StockFilter.outOfStock:
        list = list.where((i) => i.status == StockStatus.outOfStock || i.availableCount <= 0).toList();
        break;
    }

    // Apply Search Query
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list.where((item) {
        return item.name.toLowerCase().contains(q) ||
            item.sku.toLowerCase().contains(q) ||
            item.category.toLowerCase().contains(q) ||
            item.ownerName.toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }

  StockState copyWith({
    bool? isLoading,
    List<StockItemEntity>? stockItems,
    List<RiderStockAllocation>? riderAllocations,
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
      riderAllocations: riderAllocations ?? this.riderAllocations,
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
    final cachedAllocations = await _storageService.getCachedRiderStockAllocations();
    if ((cached != null && cached.isNotEmpty) || (cachedAllocations != null && cachedAllocations.isNotEmpty)) {
      state = state.copyWith(
        isLoading: false,
        stockItems: cached ?? state.stockItems,
        riderAllocations: cachedAllocations ?? state.riderAllocations,
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

  // ==========================================
  // INVENTORY MUTATIONS & CONNECTED DC WORKFLOWS
  // ==========================================

  /// Register a brand new product in the DC inventory catalogue
  Future<StockItemEntity> addNewProduct({
    required String name,
    required String sku,
    required String category,
    required double price,
    String ownerName = 'Novacare Limited',
    int initialQuantity = 0,
    int lowStockThreshold = 3,
    String description = '',
    String? binLocation,
  }) async {
    final newId = 'prod_${DateTime.now().millisecondsSinceEpoch}';
    final newItem = StockItemEntity(
      id: newId,
      sku: sku.trim().toUpperCase(),
      name: name.trim(),
      description: description.trim().isNotEmpty ? description.trim() : '$name - Distributed Inventory',
      price: price,
      ownerName: ownerName.trim().isNotEmpty ? ownerName.trim() : 'Novacare Limited',
      inventoryType: InventoryType.distributedInventory,
      totalInCustody: initialQuantity,
      assignedCount: 0,
      deliveredCount: 0,
      availableCount: initialQuantity,
      returnedCount: 0,
      lowStockThreshold: lowStockThreshold,
      category: category.trim().isNotEmpty ? category.trim() : 'General',
      batchNumber: 'LOT-${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
      lastAuditDate: DateTime.now().toIso8601String().split('T').first,
    );

    final updatedItems = [newItem, ...state.stockItems];
    state = state.copyWith(stockItems: updatedItems);
    await _storageService.cacheStockItems(updatedItems);
    return newItem;
  }

  /// Receive incoming shipment / waybill and increase available warehouse stock
  Future<bool> receiveStock({
    required String productIdOrSku,
    required int quantity,
    String? waybillNumber,
    String? supplierName,
    String? binLocation,
  }) async {
    if (quantity <= 0) return false;

    bool found = false;
    final updatedItems = state.stockItems.map((item) {
      if (item.id == productIdOrSku ||
          item.sku.toLowerCase() == productIdOrSku.toLowerCase() ||
          item.name.toLowerCase() == productIdOrSku.toLowerCase()) {
        found = true;
        return item.copyWith(
          availableCount: item.availableCount + quantity,
          totalInCustody: item.totalInCustody + quantity,
        );
      }
      return item;
    }).toList();

    if (found) {
      state = state.copyWith(stockItems: updatedItems);
      await _storageService.cacheStockItems(updatedItems);
      return true;
    }
    return false;
  }

  /// Assign stock directly from DC warehouse to a rider's custody
  Future<Map<String, dynamic>> assignStockToRider({
    required String productIdOrSku,
    required String riderId,
    required String riderName,
    required String riderCode,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      return {'success': false, 'message': 'Quantity must be greater than 0'};
    }

    final targetIdx = state.stockItems.indexWhere((i) =>
        i.id == productIdOrSku ||
        i.sku.toLowerCase() == productIdOrSku.toLowerCase() ||
        i.name.toLowerCase() == productIdOrSku.toLowerCase());

    if (targetIdx == -1) {
      return {'success': false, 'message': 'Product not found in DC warehouse catalogue'};
    }

    final target = state.stockItems[targetIdx];
    if (target.availableCount < quantity) {
      return {
        'success': false,
        'message': 'Insufficient warehouse stock. Available: ${target.availableCount} units, Requested: $quantity units',
      };
    }

    // 1. Deduct from warehouse available stock, increment assigned count
    final updatedTarget = target.copyWith(
      availableCount: target.availableCount - quantity,
      assignedCount: target.assignedCount + quantity,
    );
    final updatedItems = List<StockItemEntity>.from(state.stockItems);
    updatedItems[targetIdx] = updatedTarget;

    // 2. Add or update RiderStockAllocation
    final existingAllocIdx = state.riderAllocations.indexWhere((a) =>
        (a.riderId == riderId || a.riderCode == riderCode) &&
        (a.productId == target.id ||
            a.sku.toLowerCase() == target.sku.toLowerCase() ||
            a.productName.toLowerCase() == target.name.toLowerCase()));

    List<RiderStockAllocation> updatedAllocations = List<RiderStockAllocation>.from(state.riderAllocations);
    if (existingAllocIdx != -1) {
      final existing = updatedAllocations[existingAllocIdx];
      updatedAllocations[existingAllocIdx] = existing.copyWith(
        allocatedUnits: existing.allocatedUnits + quantity,
        inCustodyUnits: existing.inCustodyUnits + quantity,
        allocatedAt: DateTime.now(),
      );
    } else {
      final newAlloc = RiderStockAllocation(
        id: 'alloc_${DateTime.now().millisecondsSinceEpoch}',
        riderId: riderId,
        riderName: riderName,
        riderCode: riderCode,
        productId: target.id,
        productName: target.name,
        sku: target.sku,
        clientName: target.ownerName,
        allocatedUnits: quantity,
        deliveredUnits: 0,
        inCustodyUnits: quantity,
        unitPrice: target.price,
        allocatedAt: DateTime.now(),
        fulfillmentType: 'distributed_inventory',
      );
      updatedAllocations.add(newAlloc);
    }

    state = state.copyWith(
      stockItems: updatedItems,
      riderAllocations: updatedAllocations,
    );

    await _storageService.cacheStockItems(updatedItems);
    await _storageService.cacheRiderStockAllocations(updatedAllocations);

    return {
      'success': true,
      'message': 'Successfully assigned $quantity units of ${target.name} to $riderName. Remaining in warehouse: ${updatedTarget.availableCount} units.',
      'remainingWarehouseStock': updatedTarget.availableCount,
      'allocatedUnits': quantity,
    };
  }

  /// Increase/Top-Up stock for a rider from warehouse inventory
  Future<Map<String, dynamic>> increaseRiderStock({
    required String skuOrName,
    required String riderId,
    required String riderName,
    required String riderCode,
    required int additionalUnits,
  }) async {
    return assignStockToRider(
      productIdOrSku: skuOrName,
      riderId: riderId,
      riderName: riderName,
      riderCode: riderCode,
      quantity: additionalUnits,
    );
  }

  /// Return physical stock from rider custody back to DC warehouse storage bin
  Future<Map<String, dynamic>> returnStockFromRider({
    required String skuOrName,
    required String riderId,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      return {'success': false, 'message': 'Quantity must be greater than 0'};
    }

    final allocIdx = state.riderAllocations.indexWhere((a) =>
        a.riderId == riderId &&
        (a.sku.toLowerCase() == skuOrName.toLowerCase() ||
            a.productName.toLowerCase() == skuOrName.toLowerCase()));

    if (allocIdx == -1) {
      return {'success': false, 'message': 'Allocation record not found for this rider'};
    }

    final alloc = state.riderAllocations[allocIdx];
    if (alloc.inCustodyUnits < quantity) {
      return {'success': false, 'message': 'Cannot return more than units held in custody (${alloc.inCustodyUnits} units)'};
    }

    // 1. Decrement rider custody
    final updatedAlloc = alloc.copyWith(
      inCustodyUnits: alloc.inCustodyUnits - quantity,
    );
    final updatedAllocations = List<RiderStockAllocation>.from(state.riderAllocations);
    updatedAllocations[allocIdx] = updatedAlloc;

    // 2. Increment warehouse available stock
    final prodIdx = state.stockItems.indexWhere((i) =>
        i.id == alloc.productId ||
        i.sku.toLowerCase() == alloc.sku.toLowerCase() ||
        i.name.toLowerCase() == alloc.productName.toLowerCase());

    List<StockItemEntity> updatedItems = List<StockItemEntity>.from(state.stockItems);
    if (prodIdx != -1) {
      final prod = updatedItems[prodIdx];
      updatedItems[prodIdx] = prod.copyWith(
        availableCount: prod.availableCount + quantity,
        assignedCount: (prod.assignedCount - quantity).clamp(0, 999999),
        returnedCount: prod.returnedCount + quantity,
      );
    }

    state = state.copyWith(
      stockItems: updatedItems,
      riderAllocations: updatedAllocations,
    );

    await _storageService.cacheStockItems(updatedItems);
    await _storageService.cacheRiderStockAllocations(updatedAllocations);

    return {
      'success': true,
      'message': 'Successfully returned $quantity units of ${alloc.productName} back to DC warehouse.',
    };
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
