import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dc_console/presentation/providers/dc_console_provider.dart';
import '../../data/datasources/stock_remote_datasource.dart';
import '../../data/repositories/stock_repository_impl.dart';
import '../../domain/entities/inbound_stock_request.dart';
import '../../domain/entities/rider_stock_allocation.dart';
import '../../domain/entities/stock_item.dart';
import '../../domain/entities/stock_transfer_record.dart';
import '../../domain/repositories/stock_repository.dart';

export '../../domain/entities/inbound_stock_request.dart';

enum StockFilter {
  all,
  available,
  lowStock,
  outOfStock,
}

class StockState {
  final bool isLoading;
  final bool isTransfersLoading;
  final List<StockItemEntity> stockItems;
  final List<RiderStockAllocation> riderAllocations;
  final List<InboundStockRequest> inboundRequests;
  final List<StockTransferRecord> stockTransfers;
  final String searchQuery;
  final StockFilter activeFilter;
  final String? errorMessage;
  final DateTime? lastAuditedTime;
  final bool isAuditRequired;

  const StockState({
    this.isLoading = true,
    this.isTransfersLoading = false,
    this.stockItems = const [],
    this.riderAllocations = const [],
    this.inboundRequests = const [],
    this.stockTransfers = const [],
    this.searchQuery = '',
    this.activeFilter = StockFilter.all,
    this.errorMessage,
    this.lastAuditedTime,
    this.isAuditRequired = false,
  });

  List<StockTransferRecord> get pendingClientSupplies =>
      stockTransfers.where((t) => t.isClientSupply && (t.isPendingReception || t.isDispatched)).toList();

  List<StockTransferRecord> get pendingInterDcTransfers =>
      stockTransfers.where((t) => t.isInterDc && (t.isPendingDestinationAcceptance || t.isPendingReception)).toList();

  List<StockTransferRecord> get pendingRiderHandovers =>
      stockTransfers.where((t) => t.isDcToRider && t.isPendingRiderAcceptance).toList();

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
    final cleanId = riderId.trim().toLowerCase();
    final cleanCode = riderCode?.trim().toLowerCase() ?? '';
    return riderAllocations.where((a) {
      final aId = a.riderId.trim().toLowerCase();
      final aCode = a.riderCode.trim().toLowerCase();
      final aName = a.riderName.trim().toLowerCase();

      final matchesId = aId.isNotEmpty && (aId == cleanId || aName == cleanId || (aName.isNotEmpty && cleanId.isNotEmpty && (aName.contains(cleanId) || cleanId.contains(aName))));
      final matchesCode = cleanCode.isNotEmpty && (aCode == cleanCode || aId == cleanCode);
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
        list = list.where((i) => i.availableCount > 0).toList();
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
    bool? isTransfersLoading,
    List<StockItemEntity>? stockItems,
    List<RiderStockAllocation>? riderAllocations,
    List<InboundStockRequest>? inboundRequests,
    List<StockTransferRecord>? stockTransfers,
    String? searchQuery,
    StockFilter? activeFilter,
    String? errorMessage,
    DateTime? lastAuditedTime,
    bool? isAuditRequired,
  }) {
    return StockState(
      isLoading: isLoading ?? this.isLoading,
      isTransfersLoading: isTransfersLoading ?? this.isTransfersLoading,
      stockItems: stockItems ?? this.stockItems,
      riderAllocations: riderAllocations ?? this.riderAllocations,
      inboundRequests: inboundRequests ?? this.inboundRequests,
      stockTransfers: stockTransfers ?? this.stockTransfers,
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
  final Ref? _ref;
  String? _lastAgentId;

  StockNotifier({
    required this.repository,
    LocalStorageService? storageService,
    Ref? ref,
  })  : _storageService = storageService ?? LocalStorageServiceImpl(),
        _ref = ref,
        super(const StockState(stockItems: [], riderAllocations: [])) {
    _initCache();
    _subscribeToRealtimeStock();
    if (_ref != null) {
      _ref.listen<AuthState>(authProvider, (previous, next) {
        final user = next.user;
        final role = user?.role.toLowerCase() ?? '';
        final isRiderOrAgent = role.contains('rider') ||
            role.contains('agent') ||
            role.contains('driver') ||
            user?.isPda == true;
        if (isRiderOrAgent) {
          final nextAgentId = user?.deliveryAgentId ?? user?.id;
          if (nextAgentId != null && nextAgentId.isNotEmpty && nextAgentId != _lastAgentId) {
            fetchStockItems(nextAgentId);
          }
        } else {
          // For DC manager, supervisor, admin, etc.: reset agent target and fetch master inventory
          _lastAgentId = null;
          fetchStockItems(null);
        }
      });
    }
  }

  RealtimeChannel? _stockRealtimeChannel;

  void _subscribeToRealtimeStock() {
    try {
      final client = Supabase.instance.client;
      _stockRealtimeChannel = client.channel('public:stock_channel')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'products',
          callback: (payload) {
            debugPrint('[STOCK_PROVIDER] ⚡ Realtime event on products (${payload.eventType}). Refreshing stock...');
            fetchStockItems();
          },
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'stock_transfers',
          callback: (payload) {
            debugPrint('[STOCK_PROVIDER] ⚡ Realtime event on stock_transfers (${payload.eventType}). Refreshing transfers & custody...');
            fetchStockTransfers();
            fetchStockItems();
          },
        )
        ..subscribe();
      debugPrint('[STOCK_PROVIDER] 📡 Realtime channel active for warehouse and vehicle stock.');
    } catch (e) {
      debugPrint('[STOCK_PROVIDER] ℹ️ Realtime subscription notice: $e');
    }
  }

  @override
  void dispose() {
    _stockRealtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _initCache() async {
    final cached = await _storageService.getCachedStockItems();
    final cachedAllocations = await _storageService.getCachedRiderStockAllocations();
    if (!mounted) return;
    if (state.stockItems.isEmpty) {
      if (cached != null && cached.isNotEmpty) {
        state = state.copyWith(stockItems: cached);
      }
    }
    if (!mounted) return;
    if (state.riderAllocations.isEmpty) {
      if (cachedAllocations != null && cachedAllocations.isNotEmpty) {
        state = state.copyWith(riderAllocations: cachedAllocations);
      }
    }
    if (!mounted) return;
    state = state.copyWith(isLoading: false);
  }

  /// Retrieves the current stock allocated to NovaXpress Logistics by NovaXpress Master Stock Keeper (Damilare).
  Future<Map<String, int>> getNovaXpressLogisticsPlatformAllocation() async {
    // 1. Check local SharedPreferences cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('nova_all_agent_held_stock');
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final nxMap = decoded['NX-ABJ-01'] ??
              decoded['agent-novaxpress-logistics'] ??
              decoded['bd21930d-a2c7-546f-8fd6-1c61849ae4d6'];
          if (nxMap is Map && nxMap.isNotEmpty) {
            return nxMap.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
          }
        }
      }
    } catch (_) {}

    // 2. Check Supabase delivery_agents table for agent_code == 'NX-ABJ-01'
    try {
      final res = await Supabase.instance.client
          .from('delivery_agents')
          .select('held_stock')
          .eq('agent_code', 'NX-ABJ-01')
          .maybeSingle();
      if (res != null && res['held_stock'] is Map) {
        final m = res['held_stock'] as Map;
        if (m.isNotEmpty) {
          return m.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
        }
      }
    } catch (_) {}

    // 3. Fallback to default allocated seed stock for NovaXpress Logistics
    return {
      'NOVA-GRAZER-01': 100,
      'NOVA-RESPIRA-02': 75,
      'NOVA-URACLR-03': 30,
      'NOVA-HAIRDYE-04': 50,
      'SKU-GHT': 100,
      'SKU-UCT': 30,
    };
  }

  /// Updates or refreshes the platform allocation for NovaXpress Logistics and recalculates DC shelf stock.
  Future<void> updateNovaXpressLogisticsPlatformAllocation(Map<String, int> allocations) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('nova_all_agent_held_stock') ?? '{}';
      final Map<String, dynamic> stockMasterMap = jsonDecode(raw) is Map
          ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
          : {};
      stockMasterMap['NX-ABJ-01'] = allocations;
      stockMasterMap['agent-novaxpress-logistics'] = allocations;
      await prefs.setString('nova_all_agent_held_stock', jsonEncode(stockMasterMap));
    } catch (_) {}
    await fetchStockItems();
  }

  Future<void> fetchStockItems([String? agentId, String? dcId]) async {
    state = state.copyWith(isLoading: state.stockItems.isEmpty, errorMessage: null);
    try {
      final user = _ref?.read(authProvider).user;
      final role = user?.role.toLowerCase() ?? '';
      final isRiderOrAgent = role.contains('rider') ||
          role.contains('agent') ||
          role.contains('driver') ||
          user?.isPda == true;

      String? targetAgentId;
      if (isRiderOrAgent) {
        targetAgentId = (agentId != null && agentId.isNotEmpty)
            ? agentId
            : (_lastAgentId ?? user?.deliveryAgentId ?? user?.id);
        if (targetAgentId != null && targetAgentId.isNotEmpty) {
          _lastAgentId = targetAgentId;
        }
      } else {
        // Warehouse manager / DC supervisor / Admin:
        // Only target a specific agent if explicitly provided in this call
        if (agentId != null && agentId.isNotEmpty) {
          targetAgentId = agentId;
        } else {
          targetAgentId = null;
          _lastAgentId = null;
        }
      }

      String? targetDcId = (dcId != null && dcId.isNotEmpty) ? dcId : null;
      if (targetDcId == null) {
        try {
          targetDcId = _ref?.read(dcConsoleProvider).activeHubId;
        } catch (_) {}
      }
      if (targetDcId == null || targetDcId.isEmpty) {
        targetDcId = user?.distributionCenterId;
      }

      if (targetAgentId != null && targetAgentId.isNotEmpty) {
        final resolvedAgentId = targetAgentId;
        // Fetch real stock and active allocations assigned to this specific rider from Supabase
        final items = await repository.getVehicleStockItems(resolvedAgentId, targetDcId);
        final allocations = await repository.getRiderStockAllocations(resolvedAgentId, targetDcId);

        final Map<String, StockItemEntity> itemMap = {
          for (final it in items) it.name.toLowerCase(): it,
        };

        // Merge live repository allocations
        for (final alloc in allocations) {
          final key = alloc.productName.toLowerCase();
          if (itemMap.containsKey(key)) {
            final existing = itemMap[key]!;
            final mergedAvailable = alloc.inCustodyUnits > 0 ? alloc.inCustodyUnits : existing.availableCount;
            final mergedAssigned = alloc.allocatedUnits > 0 ? alloc.allocatedUnits : existing.assignedCount;
            itemMap[key] = existing.copyWith(
              availableCount: mergedAvailable,
              assignedCount: mergedAssigned,
              totalInCustody: mergedAvailable,
              deliveredCount: math.max(existing.deliveredCount, alloc.deliveredUnits),
              returnedCount: math.max(existing.returnedCount, alloc.returnedUnits),
            );
          } else if (alloc.inCustodyUnits > 0 || alloc.allocatedUnits > 0) {
            itemMap[key] = StockItemEntity(
              id: alloc.productId,
              sku: alloc.sku,
              name: alloc.productName,
              description: '${alloc.productName} - Vehicle custody allocated by DC',
              price: alloc.unitPrice,
              ownerName: alloc.clientName,
              inventoryType: InventoryType.distributedInventory,
              totalInCustody: alloc.inCustodyUnits,
              assignedCount: alloc.allocatedUnits,
              deliveredCount: alloc.deliveredUnits,
              availableCount: alloc.inCustodyUnits,
              returnedCount: alloc.returnedUnits,
              complaintCount: 0,
              lowStockThreshold: 3,
              category: 'Vehicle Stock',
              binLocation: 'Motorbike / Vehicle',
              batchNumber: 'LOT-2026-08',
              lastAuditDate: DateTime.now().toIso8601String().substring(0, 10),
            );
          }
        }

        final List<StockItemEntity> riderItems = itemMap.values.toList();

        state = state.copyWith(
          isLoading: false,
          stockItems: riderItems,
          riderAllocations: allocations.isNotEmpty ? allocations : state.riderAllocations,
          lastAuditedTime: DateTime.now().subtract(const Duration(hours: 4)),
          isAuditRequired: false,
        );
        _storageService.cacheStockItems(riderItems);
        if (allocations.isNotEmpty) {
          _storageService.cacheRiderStockAllocations(allocations);
        }
      } else {
        // DC Master Overview: Scoped strictly to active DC
        final items = await repository.getVehicleStockItems(null, targetDcId);
        final allocations = await repository.getRiderStockAllocations(null, targetDcId);

        // Enforce NovaXpress Logistics stock allocation dependency from NovaXpress platform (Damilare)
        final platformAllocations = await getNovaXpressLogisticsPlatformAllocation();

        final syncedItems = items.map((it) {
          // Find allocation units provided by Damilare (NovaXpress Master Stock Keeper)
          final platformAllocated = platformAllocations[it.sku] ??
              platformAllocations[it.name] ??
              platformAllocations[it.id] ??
              (platformAllocations.isEmpty ? it.availableCount : 0);

          // Calculate total units currently held by NovaXpress Logistics riders
          final int riderCustodyUnits = allocations
              .where((a) =>
                  (a.sku.toLowerCase() == it.sku.toLowerCase() ||
                   a.productName.toLowerCase() == it.name.toLowerCase() ||
                   a.productId == it.id) &&
                  !a.riderCode.toUpperCase().startsWith('AG-') &&
                  a.riderCode.toUpperCase() != 'NX-ABJ-01')
              .fold(0, (sum, a) => sum + a.inCustodyUnits);

          // DC Available = (Platform Allocated - Rider Custody)
          final availableInDc = (platformAllocated - riderCustodyUnits).clamp(0, platformAllocated);

          return it.copyWith(
            availableCount: availableInDc,
            totalInCustody: availableInDc,
            assignedCount: riderCustodyUnits,
          );
        }).toList();

        if (!mounted) return;
        state = state.copyWith(
          isLoading: false,
          stockItems: syncedItems,
          riderAllocations: allocations,
        );
        _storageService.cacheStockItems(syncedItems);
        _storageService.cacheRiderStockAllocations(allocations);
        await fetchStockRequests(targetDcId);
      }
    } catch (e) {
      debugPrint('[STOCK_PROVIDER] ❌ fetchStockItems error: $e');
      if (!mounted) return;
      final cached = await _storageService.getCachedStockItems();
      final cachedAllocations = await _storageService.getCachedRiderStockAllocations();

      if (!mounted) return;
      final fallbackItems = (cached != null && cached.isNotEmpty) ? cached : state.stockItems;
      final fallbackAlloc = (cachedAllocations != null && cachedAllocations.isNotEmpty) ? cachedAllocations : state.riderAllocations;

      state = state.copyWith(
        isLoading: false,
        stockItems: fallbackItems,
        riderAllocations: fallbackAlloc,
        errorMessage: fallbackItems.isEmpty
            ? 'Unable to connect to NovaXpress server. Please check your network connection and try again.'
            : 'Offline Mode: Showing cached inventory. Live sync failed due to network instability.',
      );
    }
  }

  Future<void> fetchStockRequests([String? dcId]) async {
    try {
      final remoteReqs = await repository.fetchStockRequests(dcId);
      if (remoteReqs.isNotEmpty) {
        final Set<String> remoteIds = remoteReqs.map((r) => r.requestId).toSet();
        final localOnly = state.inboundRequests.where((r) => !remoteIds.contains(r.requestId)).toList();
        state = state.copyWith(inboundRequests: [...remoteReqs, ...localOnly]);
      }
    } catch (e) {
      debugPrint('[STOCK_PROVIDER] ⚠️ fetchStockRequests error: $e');
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilter(StockFilter filter) {
    state = state.copyWith(activeFilter: filter);
  }

  Future<void> addStockRequest({
    required String dcName,
    required Map<String, int> quantities,
    String? riderId,
    String? riderName,
    String? riderCode,
    String? notes,
    List<StockRequestItemModel>? items,
  }) async {
    final newReqId = 'REQ-${(10000 + state.inboundRequests.length + 1).toString().substring(1)}';
    final newRequest = InboundStockRequest(
      requestId: newReqId,
      dcName: dcName,
      riderId: riderId,
      riderName: riderName ?? 'Delivery Agent',
      riderCode: riderCode ?? 'PDA-RIDER',
      notes: notes,
      status: 'pending',
      requestDate: DateTime.now(),
      requestedQuantities: quantities,
      approvedQuantities: quantities,
      items: items ?? [],
    );

    state = state.copyWith(
      inboundRequests: [newRequest, ...state.inboundRequests],
    );

    // Asynchronously log to Supabase stock_requests table
    try {
      final client = Supabase.instance.client;
      final srRes = await client.from('stock_requests').insert({
        'request_number': newReqId,
        if (riderId != null) 'delivery_agent_id': riderId,
        'status': 'pending',
        'request_type': 'restock',
        'notes': notes ?? 'Restock request submitted via app',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select('id').single();

      final srId = srRes['id']?.toString() ?? '';
      if (srId.isNotEmpty && items != null && items.isNotEmpty) {
        for (final item in items) {
          if (item.productId.isNotEmpty && item.requestedQuantity > 0) {
            await client.from('stock_request_items').insert({
              'stock_request_id': srId,
              'product_id': item.productId,
              'requested_quantity': item.requestedQuantity,
              'approved_quantity': item.requestedQuantity,
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>> fulfillStockRequest({
    required String requestId,
    required String fulfillmentMode, // 'dc_warehouse' or 'rider_transfer'
    required String destinationRiderId,
    required String destinationRiderName,
    required String destinationRiderCode,
    String? sourceRiderId,
    String? sourceRiderName,
    required List<Map<String, dynamic>> items,
    String? dcId,
    String? notes,
  }) async {
    try {
      if (fulfillmentMode == 'dc_warehouse') {
        for (final it in items) {
          final pId = it['productId']?.toString() ?? it['product_id']?.toString() ?? '';
          final qty = (it['quantity'] as num?)?.toInt() ?? 0;
          if (pId.isNotEmpty && qty > 0) {
            final res = await assignStockToRider(
              productIdOrSku: pId,
              riderId: destinationRiderId,
              riderName: destinationRiderName,
              riderCode: destinationRiderCode,
              quantity: qty,
              distributionCenterId: dcId,
            );
            if (res['success'] != true) {
              return res;
            }
          }
        }
      } else if (fulfillmentMode == 'rider_transfer') {
        if (sourceRiderId == null || sourceRiderName == null) {
          return {'success': false, 'message': 'Source rider required for in-field stock rebalancing.'};
        }
        for (final it in items) {
          final pId = it['productId']?.toString() ?? it['product_id']?.toString() ?? '';
          final qty = (it['quantity'] as num?)?.toInt() ?? 0;
          if (pId.isNotEmpty && qty > 0) {
            final r2rRes = await transferStockBetweenRiders(
              productIdOrSku: pId,
              sourceRiderId: sourceRiderId,
              sourceRiderName: sourceRiderName,
              destinationRiderId: destinationRiderId,
              destinationRiderName: destinationRiderName,
              destinationRiderCode: destinationRiderCode,
              quantity: qty,
              notes: notes ?? 'Fulfillment of restock request #$requestId',
            );
            if (r2rRes['success'] != true) {
              return r2rRes;
            }
          }
        }
      }

      // Persist fulfillment status to backend
      try {
        await repository.fulfillStockRequest(
          requestId: requestId,
          status: 'fulfilled',
          notes: notes,
        );
      } catch (_) {}

      // Update in local state
      final updatedReqs = state.inboundRequests.map((r) {
        if (r.id == requestId || r.requestId == requestId) {
          return r.copyWith(status: 'fulfilled');
        }
        return r;
      }).toList();
      state = state.copyWith(inboundRequests: updatedReqs);

      // Refresh items and allocations
      await fetchStockItems(null, dcId);

      return {
        'success': true,
        'message': 'Restock request successfully fulfilled via ${fulfillmentMode == 'dc_warehouse' ? 'DC Warehouse Stock' : 'Rider Rebalancing ($sourceRiderName)'}.',
      };
    } catch (e) {
      debugPrint('[STOCK_PROVIDER] ⚠️ fulfillStockRequest error: $e');
      return {'success': false, 'message': 'Fulfillment failed: $e'};
    }
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
    double? costPrice,
    String? barcode,
    double? weightKg,
    String ownerName = '',
    String? clientId,
    int initialQuantity = 0,
    int lowStockThreshold = 3,
    String description = '',
    String? binLocation,
    String? imageAsset,
    String? originDcId,
    List<String>? coveringStates,
    Map<String, int>? dcStocks,
  }) async {
    String? resolvedOriginDcId = (originDcId != null && originDcId.isNotEmpty) ? originDcId : null;
    if (resolvedOriginDcId == null) {
      try {
        resolvedOriginDcId = _ref?.read(dcConsoleProvider).activeHubId;
      } catch (_) {}
    }
    if (resolvedOriginDcId == null || resolvedOriginDcId.isEmpty) {
      resolvedOriginDcId = _ref?.read(authProvider).user?.distributionCenterId;
    }

    // 1. Create on remote backend via repository
    StockItemEntity newItem;
    try {
      newItem = await repository.createProduct(
        name: name,
        sku: sku,
        category: category,
        price: price,
        costPrice: costPrice,
        barcode: barcode,
        weightKg: weightKg,
        ownerName: ownerName,
        clientId: clientId,
        stockQuantity: initialQuantity,
        lowStockThreshold: lowStockThreshold,
        description: description,
        binLocation: binLocation,
        imageAsset: imageAsset,
        originDcId: resolvedOriginDcId,
        coveringStates: coveringStates,
        dcStocks: dcStocks,
      );
    } catch (e, st) {
      debugPrint('[STOCK_PROVIDER] ⚠️ Remote repository.createProduct notice: $e\n$st');
      final newId = 'prod_${DateTime.now().millisecondsSinceEpoch}';
      newItem = StockItemEntity(
        id: newId,
        sku: sku.trim().toUpperCase(),
        name: name.trim(),
        description: description.trim().isNotEmpty ? description.trim() : '$name - Distributed Inventory',
        price: price,
        costPrice: costPrice ?? 0.0,
        barcode: barcode,
        weightKg: weightKg ?? 0.5,
        ownerName: ownerName.trim(),
        inventoryType: InventoryType.distributedInventory,
        totalInCustody: initialQuantity,
        assignedCount: 0,
        deliveredCount: 0,
        availableCount: initialQuantity,
        returnedCount: 0,
        lowStockThreshold: lowStockThreshold,
        category: category.trim().isNotEmpty ? category.trim() : 'General',
        imageAsset: imageAsset,
        batchNumber: 'LOT-${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
        lastAuditDate: DateTime.now().toIso8601String().split('T').first,
      );
    }

    final updatedItems = [newItem, ...state.stockItems.where((i) => i.id != newItem.id && i.sku.toLowerCase() != newItem.sku.toLowerCase())];
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
    String? distributionCenterId,
  }) async {
    if (quantity <= 0) return false;

    String? resolvedDcId = (distributionCenterId != null && distributionCenterId.isNotEmpty) ? distributionCenterId : null;
    if (resolvedDcId == null) {
      try {
        resolvedDcId = _ref?.read(dcConsoleProvider).activeHubId;
      } catch (_) {}
    }
    if (resolvedDcId == null || resolvedDcId.isEmpty) {
      resolvedDcId = _ref?.read(authProvider).user?.distributionCenterId;
    }

    // 1. Update remote backend via repository
    try {
      await repository.receiveStock(
        productIdOrSku: productIdOrSku,
        quantity: quantity,
        waybillNumber: waybillNumber,
        supplierName: supplierName,
        distributionCenterId: resolvedDcId,
      );
    } catch (_) {}

    // 2. Update local state & cache
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
  /// Rider initiates peer-to-peer stock transfer to another rider
  Future<Map<String, dynamic>> initiateRiderToRiderTransfer({
    required String productId,
    required String productName,
    required String sku,
    required int quantity,
    required String senderRiderId,
    required String senderRiderName,
    required String senderRiderCode,
    required String recipientRiderId,
    required String recipientRiderName,
    required String recipientRiderCode,
    String? notes,
  }) async {
    try {
      final res = await repository.initiateRiderToRiderTransfer(
        productId: productId,
        productName: productName,
        sku: sku,
        quantity: quantity,
        senderRiderId: senderRiderId,
        senderRiderName: senderRiderName,
        senderRiderCode: senderRiderCode,
        recipientRiderId: recipientRiderId,
        recipientRiderName: recipientRiderName,
        recipientRiderCode: recipientRiderCode,
        notes: notes,
      );

      // Refresh transfers for sender
      await fetchStockTransfers(riderId: senderRiderId);
      return res;
    } catch (e) {
      debugPrint('[STOCK_PROVIDER] ⚠️ initiateRiderToRiderTransfer error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> assignStockToRider({
    required String productIdOrSku,
    required String riderId,
    required String riderName,
    required String riderCode,
    required int quantity,
    String? distributionCenterId,
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
        'message': target.availableCount <= 0
            ? 'Cannot allocate: NovaXpress Logistics has 0 available units from NovaXpress platform. Request stock allocation from Damilare (NovaXpress Master Stock Ops) first.'
            : 'Insufficient DC warehouse stock. Available: ${target.availableCount} units, Requested: $quantity units',
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

    // 3. Persist stock transfer to Supabase backend
    String? effectiveDcId = (distributionCenterId != null && distributionCenterId.isNotEmpty)
        ? distributionCenterId
        : null;
    if (effectiveDcId == null || effectiveDcId.isEmpty) {
      try {
        effectiveDcId = _ref?.read(dcConsoleProvider).activeHubId;
      } catch (_) {}
    }
    if (effectiveDcId == null || effectiveDcId.isEmpty) {
      effectiveDcId = _ref?.read(authProvider).user?.distributionCenterId;
    }

    try {
      await repository.assignStockToRider(
        productIdOrSku: target.id,
        riderId: riderId,
        riderName: riderName,
        riderCode: riderCode,
        quantity: quantity,
        distributionCenterId: effectiveDcId,
      );
    } catch (_) {}

    return {
      'success': true,
      'message': 'Successfully assigned $quantity units of ${target.name} to $riderName. Remaining in warehouse: ${updatedTarget.availableCount} units.',
      'remainingWarehouseStock': updatedTarget.availableCount,
      'allocatedUnits': quantity,
    };
  }

  Future<Map<String, dynamic>> transferStockBetweenRiders({
    required String productIdOrSku,
    required String sourceRiderId,
    required String sourceRiderName,
    required String destinationRiderId,
    required String destinationRiderName,
    required String destinationRiderCode,
    required int quantity,
    String? distributionCenterId,
    String? notes,
  }) async {
    if (quantity <= 0) {
      return {'success': false, 'message': 'Quantity must be greater than 0'};
    }

    final srcIdx = state.riderAllocations.indexWhere((a) =>
        (a.riderId == sourceRiderId || a.riderCode == sourceRiderId) &&
        (a.productId == productIdOrSku ||
            a.sku.toLowerCase() == productIdOrSku.toLowerCase() ||
            a.productName.toLowerCase() == productIdOrSku.toLowerCase()));

    if (srcIdx == -1 || state.riderAllocations[srcIdx].inCustodyUnits < quantity) {
      final available = srcIdx != -1 ? state.riderAllocations[srcIdx].inCustodyUnits : 0;
      return {
        'success': false,
        'message': 'Source rider only has $available units in custody. Requested: $quantity units.',
      };
    }

    final srcAlloc = state.riderAllocations[srcIdx];
    final updatedAllocations = List<RiderStockAllocation>.from(state.riderAllocations);

    // Deduct from source rider
    updatedAllocations[srcIdx] = srcAlloc.copyWith(
      inCustodyUnits: srcAlloc.inCustodyUnits - quantity,
      allocatedUnits: (srcAlloc.allocatedUnits - quantity).clamp(0, 999999),
    );

    // Add to destination rider
    final destIdx = updatedAllocations.indexWhere((a) =>
        a.riderId == destinationRiderId &&
        (a.productId == srcAlloc.productId ||
            a.sku.toLowerCase() == srcAlloc.sku.toLowerCase() ||
            a.productName.toLowerCase() == srcAlloc.productName.toLowerCase()));

    if (destIdx != -1) {
      final destAlloc = updatedAllocations[destIdx];
      updatedAllocations[destIdx] = destAlloc.copyWith(
        inCustodyUnits: destAlloc.inCustodyUnits + quantity,
        allocatedUnits: destAlloc.allocatedUnits + quantity,
        allocatedAt: DateTime.now(),
      );
    } else {
      updatedAllocations.add(RiderStockAllocation(
        id: 'alloc_${DateTime.now().millisecondsSinceEpoch}',
        riderId: destinationRiderId,
        riderName: destinationRiderName,
        riderCode: destinationRiderCode,
        productId: srcAlloc.productId,
        productName: srcAlloc.productName,
        sku: srcAlloc.sku,
        clientName: srcAlloc.clientName,
        allocatedUnits: quantity,
        deliveredUnits: 0,
        inCustodyUnits: quantity,
        unitPrice: srcAlloc.unitPrice,
        allocatedAt: DateTime.now(),
        fulfillmentType: 'in_field_transfer',
      ));
    }

    state = state.copyWith(riderAllocations: updatedAllocations);
    await _storageService.cacheRiderStockAllocations(updatedAllocations);

    String? effectiveDcId = (distributionCenterId != null && distributionCenterId.isNotEmpty)
        ? distributionCenterId
        : null;
    if (effectiveDcId == null || effectiveDcId.isEmpty) {
      try {
        effectiveDcId = _ref?.read(dcConsoleProvider).activeHubId;
      } catch (_) {}
    }
    effectiveDcId ??= _ref?.read(authProvider).user?.distributionCenterId;

    // Persist connected Rider-to-Rider custody transfer via repository
    try {
      await repository.executeRiderToRiderBalance(
        productIdOrSku: srcAlloc.productId.isNotEmpty ? srcAlloc.productId : productIdOrSku,
        sourceRiderId: sourceRiderId,
        sourceRiderName: sourceRiderName,
        destinationRiderId: destinationRiderId,
        destinationRiderName: destinationRiderName,
        destinationRiderCode: destinationRiderCode,
        quantity: quantity,
        distributionCenterId: effectiveDcId,
        notes: notes,
      );
    } catch (_) {}

    return {
      'success': true,
      'message': 'Successfully balanced $quantity units of ${srcAlloc.productName} from $sourceRiderName to $destinationRiderName.',
    };
  }

  /// Transfer stock units directly from current DC warehouse to another Distribution Center
  Future<Map<String, dynamic>> transferStockBetweenDCs({
    required String productIdOrSku,
    required String sourceDcId,
    required String sourceDcName,
    required String destinationDcId,
    required String destinationDcName,
    required int quantity,
    String? senderId,
    String? senderName,
    String? notes,
  }) async {
    if (quantity <= 0) {
      return {'success': false, 'message': 'Transfer quantity must be greater than 0'};
    }

    final targetIdx = state.stockItems.indexWhere((i) =>
        i.id == productIdOrSku ||
        i.sku.toLowerCase() == productIdOrSku.toLowerCase() ||
        i.name.toLowerCase() == productIdOrSku.toLowerCase());

    if (targetIdx == -1) {
      return {'success': false, 'message': 'Product not found in current DC warehouse'};
    }

    final target = state.stockItems[targetIdx];
    if (target.availableCount < quantity) {
      return {
        'success': false,
        'message': 'Insufficient warehouse stock. Available: ${target.availableCount} units, Requested transfer: $quantity units',
      };
    }

    // 1. Deduct from local warehouse available stock
    final updatedTarget = target.copyWith(
      availableCount: target.availableCount - quantity,
      totalInCustody: (target.totalInCustody - quantity).clamp(0, 999999),
    );
    final updatedItems = List<StockItemEntity>.from(state.stockItems);
    updatedItems[targetIdx] = updatedTarget;

    state = state.copyWith(stockItems: updatedItems);
    await _storageService.cacheStockItems(updatedItems);

    // 2. Persist to Supabase backend
    Map<String, dynamic> remoteRes = {'success': true};
    try {
      remoteRes = await repository.transferStockBetweenDCs(
        productIdOrSku: target.id,
        sourceDcId: sourceDcId,
        sourceDcName: sourceDcName,
        destinationDcId: destinationDcId,
        destinationDcName: destinationDcName,
        quantity: quantity,
        senderId: senderId,
        senderName: senderName,
        notes: notes,
      );
      await fetchStockTransfers(dcId: sourceDcId);
    } catch (e) {
      debugPrint('[STOCK_PROVIDER] ℹ️ Remote transfer notice: $e');
    }

    final waybill = remoteRes['waybillNumber'] ?? 'WB-DC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    return {
      'success': true,
      'transfer_id': remoteRes['transfer_id'] ?? remoteRes['transferId'],
      'transferId': remoteRes['transfer_id'] ?? remoteRes['transferId'],
      'waybillNumber': waybill,
      'remainingWarehouseStock': updatedTarget.availableCount,
      'transferredUnits': quantity,
      'message': 'Successfully dispatched $quantity units of ${target.name} to $destinationDcName ($waybill). Remaining stock: ${updatedTarget.availableCount} units.',
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
    String? distributionCenterId,
    String condition = 'good',
    String reason = 'Rider stock return',
    String? notes,
  }) async {
    if (quantity <= 0) {
      return {'success': false, 'message': 'Quantity must be greater than 0'};
    }

    final allocIdx = state.riderAllocations.indexWhere((a) =>
        (a.riderId == riderId || a.riderCode == riderId) &&
        (a.productId == skuOrName ||
            a.sku.toLowerCase() == skuOrName.toLowerCase() ||
            a.productName.toLowerCase() == skuOrName.toLowerCase()));

    if (allocIdx == -1) {
      return {'success': false, 'message': 'Allocation record not found for this rider'};
    }

    final alloc = state.riderAllocations[allocIdx];
    if (alloc.inCustodyUnits < quantity) {
      return {'success': false, 'message': 'Cannot return more than units held in custody (${alloc.inCustodyUnits} units)'};
    }

    final cleanCond = condition.trim().toLowerCase();
    final isGood = cleanCond == 'good' || cleanCond == 'sellable' || cleanCond == 'sealed';

    // 1. Decrement rider custody & record returned units
    final updatedAlloc = alloc.copyWith(
      inCustodyUnits: alloc.inCustodyUnits - quantity,
      returnedUnits: alloc.returnedUnits + quantity,
    );
    final updatedAllocations = List<RiderStockAllocation>.from(state.riderAllocations);
    updatedAllocations[allocIdx] = updatedAlloc;

    // 2. Balance DC warehouse stock (restore availableCount only for good units; track damagedCount for spoiled units)
    final prodIdx = state.stockItems.indexWhere((i) =>
        i.id == alloc.productId ||
        i.sku.toLowerCase() == alloc.sku.toLowerCase() ||
        i.name.toLowerCase() == alloc.productName.toLowerCase());

    List<StockItemEntity> updatedItems = List<StockItemEntity>.from(state.stockItems);
    if (prodIdx != -1) {
      final prod = updatedItems[prodIdx];
      updatedItems[prodIdx] = prod.copyWith(
        availableCount: isGood ? prod.availableCount + quantity : prod.availableCount,
        assignedCount: (prod.assignedCount - quantity).clamp(0, 999999),
        returnedCount: prod.returnedCount + quantity,
        damagedCount: isGood ? prod.damagedCount : prod.damagedCount + quantity,
        complaintCount: isGood ? prod.complaintCount : prod.complaintCount + quantity,
      );
    }

    state = state.copyWith(
      stockItems: updatedItems,
      riderAllocations: updatedAllocations,
    );

    await _storageService.cacheStockItems(updatedItems);
    await _storageService.cacheRiderStockAllocations(updatedAllocations);

    String? effectiveDcId = (distributionCenterId != null && distributionCenterId.isNotEmpty)
        ? distributionCenterId
        : null;
    if (effectiveDcId == null || effectiveDcId.isEmpty) {
      try {
        effectiveDcId = _ref?.read(dcConsoleProvider).activeHubId;
      } catch (_) {}
    }
    effectiveDcId ??= _ref?.read(authProvider).user?.distributionCenterId;

    try {
      await repository.syncRiderReturnToDc(
        riderId: riderId,
        productIdOrSku: alloc.productId.isNotEmpty ? alloc.productId : skuOrName,
        quantity: quantity,
        condition: condition,
        distributionCenterId: effectiveDcId,
        reason: reason,
        notes: notes,
        logReturnRow: true,
      );
    } catch (_) {}

    return {
      'success': true,
      'message': 'Successfully returned $quantity units of ${alloc.productName} back to DC warehouse.',
    };
  }

  /// Record end-of-day daily physical sales for a rider, automatically balancing system inventory and optionally closing forgotten open orders
  Future<Map<String, dynamic>> recordDailyRiderSales({
    required String riderId,
    String? riderName,
    required String productId,
    required int unitsSold,
    String? distributionCenterId,
    List<String> reconcileOrderIds = const [],
    String? notes,
  }) async {
    if (unitsSold <= 0 && reconcileOrderIds.isEmpty) {
      return {'success': false, 'message': 'Units sold must be greater than 0.'};
    }

    final allocIdx = state.riderAllocations.indexWhere(
      (a) =>
          (a.riderId == riderId || a.riderCode == riderId) &&
          (a.productId == productId ||
              a.sku.toLowerCase() == productId.toLowerCase() ||
              a.productName.toLowerCase() == productId.toLowerCase()),
    );

    final updatedAllocations = List<RiderStockAllocation>.from(state.riderAllocations);
    final updatedItems = List<StockItemEntity>.from(state.stockItems);

    String targetProdId = productId;
    String resolvedRiderName = riderName?.trim().isNotEmpty == true ? riderName!.trim() : riderId;
    int actualUnitsSold = unitsSold;
    int remainingCustody = 0;

    if (allocIdx != -1) {
      final alloc = state.riderAllocations[allocIdx];
      targetProdId = alloc.productId.isNotEmpty ? alloc.productId : productId;
      resolvedRiderName = riderName?.trim().isNotEmpty == true ? riderName!.trim() : alloc.riderName;
      if (unitsSold > 0) {
        actualUnitsSold = alloc.inCustodyUnits > 0 ? unitsSold.clamp(0, alloc.inCustodyUnits) : unitsSold;
      } else {
        actualUnitsSold = alloc.inCustodyUnits;
      }
      remainingCustody = (alloc.inCustodyUnits - actualUnitsSold).clamp(0, 999999);

      updatedAllocations[allocIdx] = alloc.copyWith(
        inCustodyUnits: remainingCustody,
        deliveredUnits: alloc.deliveredUnits + actualUnitsSold,
      );

      final prodIdx = updatedItems.indexWhere(
        (i) =>
            i.id == alloc.productId ||
            i.sku.toLowerCase() == alloc.sku.toLowerCase() ||
            i.name.toLowerCase() == alloc.productName.toLowerCase(),
      );
      if (prodIdx != -1) {
        final p = updatedItems[prodIdx];
        updatedItems[prodIdx] = p.copyWith(
          assignedCount: (p.assignedCount - actualUnitsSold).clamp(0, 999999),
          deliveredCount: p.deliveredCount + actualUnitsSold,
        );
      }
    } else {
      // Fallback: match directly in stockItems when rider has no explicit prior allocation record yet
      final prodIdx = updatedItems.indexWhere(
        (i) =>
            i.id == productId ||
            i.sku.toLowerCase() == productId.toLowerCase() ||
            i.name.toLowerCase() == productId.toLowerCase(),
      );
      if (prodIdx == -1) {
        return {'success': false, 'message': 'No allocation record found for this rider and product.'};
      }
      final p = updatedItems[prodIdx];
      targetProdId = p.id;
      actualUnitsSold = unitsSold > 0 ? unitsSold : 1;
      remainingCustody = (p.availableCount - actualUnitsSold).clamp(0, 999999);
      updatedItems[prodIdx] = p.copyWith(
        availableCount: remainingCustody,
        assignedCount: (p.assignedCount - actualUnitsSold).clamp(0, 999999),
        deliveredCount: p.deliveredCount + actualUnitsSold,
      );
      updatedAllocations.add(RiderStockAllocation(
        id: 'alloc_eod_${DateTime.now().millisecondsSinceEpoch}',
        riderId: riderId,
        riderName: resolvedRiderName,
        riderCode: riderId,
        productId: p.id,
        productName: p.name,
        sku: p.sku,
        clientName: p.ownerName,
        allocatedUnits: actualUnitsSold,
        deliveredUnits: actualUnitsSold,
        inCustodyUnits: 0,
        unitPrice: p.price,
        allocatedAt: DateTime.now(),
        fulfillmentType: 'eod_reconciled',
      ));
    }

    state = state.copyWith(
      riderAllocations: updatedAllocations,
      stockItems: updatedItems,
    );

    await _storageService.cacheRiderStockAllocations(updatedAllocations);
    await _storageService.cacheStockItems(updatedItems);

    String? effectiveDcId = (distributionCenterId != null && distributionCenterId.isNotEmpty)
        ? distributionCenterId
        : null;
    if (effectiveDcId == null || effectiveDcId.isEmpty) {
      try {
        effectiveDcId = _ref?.read(dcConsoleProvider).activeHubId;
      } catch (_) {}
    }
    effectiveDcId ??= _ref?.read(authProvider).user?.distributionCenterId;

    // Persist connected Daily Sales, Order Closure, & System-Wide Inventory Balancing to Supabase
    try {
      await repository.syncDailyRiderSales(
        riderId: riderId,
        riderName: resolvedRiderName,
        productIdOrSku: targetProdId,
        unitsSold: actualUnitsSold,
        distributionCenterId: effectiveDcId,
        reconcileOrderIds: reconcileOrderIds,
        notes: notes,
      );
    } catch (_) {}

    final ordersNote = reconcileOrderIds.isNotEmpty
        ? ' Closed ${reconcileOrderIds.length} open order(s).'
        : '';
    return {
      'success': true,
      'message':
          'Recorded $actualUnitsSold units sold for $resolvedRiderName. Remaining custody: $remainingCustody units.$ordersNote',
    };
  }

  /// Record damaged, defective, or lost stock reported by riders during custody sync
  Future<Map<String, dynamic>> recordComplaintOrDamage({
    required String productIdOrSku,
    required String riderId,
    required int quantity,
    required String reason,
    String? distributionCenterId,
    String? notes,
  }) async {
    if (quantity <= 0) return {'success': false, 'message': 'Quantity must be greater than 0'};

    // 1. Update stock item complaint + damaged counts
    final targetIdx = state.stockItems.indexWhere((i) =>
        i.id == productIdOrSku ||
        i.sku.toLowerCase() == productIdOrSku.toLowerCase() ||
        i.name.toLowerCase() == productIdOrSku.toLowerCase());

    if (targetIdx == -1) return {'success': false, 'message': 'Product not found in catalogue'};

    final target = state.stockItems[targetIdx];
    final updatedTarget = target.copyWith(
      complaintCount: target.complaintCount + quantity,
      damagedCount: target.damagedCount + quantity,
      assignedCount: (target.assignedCount - quantity).clamp(0, 999999),
    );
    final updatedItems = List<StockItemEntity>.from(state.stockItems);
    updatedItems[targetIdx] = updatedTarget;

    // 2. Decrement rider custody if reported by a rider
    List<RiderStockAllocation> updatedAllocations = List<RiderStockAllocation>.from(state.riderAllocations);
    final allocIdx = updatedAllocations.indexWhere((a) =>
        (a.riderId == riderId || a.riderCode == riderId) &&
        (a.productId == target.id ||
            a.sku.toLowerCase() == target.sku.toLowerCase() ||
            a.productName.toLowerCase() == target.name.toLowerCase()));

    if (allocIdx != -1) {
      final alloc = updatedAllocations[allocIdx];
      updatedAllocations[allocIdx] = alloc.copyWith(
        inCustodyUnits: (alloc.inCustodyUnits - quantity).clamp(0, 999999),
        returnedUnits: alloc.returnedUnits + quantity,
      );
    }

    state = state.copyWith(
      stockItems: updatedItems,
      riderAllocations: updatedAllocations,
    );

    await _storageService.cacheStockItems(updatedItems);
    await _storageService.cacheRiderStockAllocations(updatedAllocations);

    String? effectiveDcId = (distributionCenterId != null && distributionCenterId.isNotEmpty)
        ? distributionCenterId
        : null;
    if (effectiveDcId == null || effectiveDcId.isEmpty) {
      try {
        effectiveDcId = _ref?.read(dcConsoleProvider).activeHubId;
      } catch (_) {}
    }
    effectiveDcId ??= _ref?.read(authProvider).user?.distributionCenterId;

    try {
      await repository.syncRiderReturnToDc(
        riderId: riderId,
        productIdOrSku: target.id,
        quantity: quantity,
        condition: 'damaged',
        distributionCenterId: effectiveDcId,
        reason: reason,
        notes: notes,
        logReturnRow: true,
      );
    } catch (_) {}

    return {
      'success': true,
      'message': 'Recorded $quantity reported issue(s) ($reason) for ${target.name}.',
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

  /// Rider initiates a return of physical stock from their vehicle custody back to the host DC warehouse
  Future<Map<String, dynamic>> returnStockToDC({
    required String productIdOrSku,
    required String riderId,
    required int quantity,
    required String reason,
    String? destinationDcId,
    String? condition,
    String? notes,
  }) async {
    if (quantity <= 0) {
      return {'success': false, 'message': 'Quantity must be greater than 0'};
    }

    // 1. Find allocation for this rider
    final allocIdx = state.riderAllocations.indexWhere((a) =>
        (a.riderId.toLowerCase() == riderId.toLowerCase() || a.riderCode.toLowerCase() == riderId.toLowerCase()) &&
        (a.productId == productIdOrSku ||
            a.sku.toLowerCase() == productIdOrSku.toLowerCase() ||
            a.productName.toLowerCase() == productIdOrSku.toLowerCase()));

    RiderStockAllocation? targetAlloc;
    List<RiderStockAllocation> updatedAllocations = List<RiderStockAllocation>.from(state.riderAllocations);

    if (allocIdx != -1) {
      final alloc = state.riderAllocations[allocIdx];
      if (alloc.inCustodyUnits < quantity) {
        return {
          'success': false,
          'message': 'Cannot return more than units held in vehicle custody (${alloc.inCustodyUnits} units)',
        };
      }
      targetAlloc = alloc.copyWith(
        inCustodyUnits: (alloc.inCustodyUnits - quantity).clamp(0, 999999),
        returnedUnits: alloc.returnedUnits + quantity,
      );
      updatedAllocations[allocIdx] = targetAlloc;
    }

    // 2. Update Rider's StockItemEntity
    final updatedItems = state.stockItems.map((item) {
      final matches = item.id == productIdOrSku ||
          item.sku.toLowerCase() == productIdOrSku.toLowerCase() ||
          item.name.toLowerCase() == productIdOrSku.toLowerCase();

      if (matches) {
        return item.copyWith(
          availableCount: (item.availableCount - quantity).clamp(0, 999999),
          returnedCount: item.returnedCount + quantity,
        );
      }
      return item;
    }).toList();

    state = state.copyWith(
      stockItems: updatedItems,
      riderAllocations: updatedAllocations,
    );

    await _storageService.cacheStockItems(updatedItems);
    await _storageService.cacheRiderStockAllocations(updatedAllocations);

    // 3. Process backend stock return if Supabase is connected
    String generatedReturnNumber = 'RET-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    try {
      final res = await repository.processStockReturn(
        returnNumber: generatedReturnNumber,
        orderId: 'DC-VEHICLE-RETURN',
        deliveryAgentId: riderId,
        productId: targetAlloc?.productId ?? productIdOrSku,
        quantity: quantity,
        reason: reason,
        destinationDcId: destinationDcId,
        condition: condition,
        notes: notes,
      );
      if (res['returnNumber'] != null) {
        generatedReturnNumber = res['returnNumber'].toString();
      }
    } catch (_) {}

    final productName = targetAlloc?.productName ?? productIdOrSku;
    return {
      'success': true,
      'returnNumber': generatedReturnNumber,
      'message': 'Successfully created return handshake $generatedReturnNumber for $quantity units of $productName ($reason).',
      'remainingInVehicle': targetAlloc?.inCustodyUnits ?? 0,
    };
  }

  /// Real-time Rider Stock Availability Check
  int getRiderAvailableStock({
    required String riderId,
    required String riderCode,
    required String productName,
    List<dynamic>? activeOrders,
  }) {
    final driverAllocations = state.getAllocationsForRider(riderId, riderCode);
    final matchingAlloc = driverAllocations.where((a) {
      final prodA = a.productName.toLowerCase();
      final orderP = productName.toLowerCase();
      return (orderP.isNotEmpty && (prodA.contains(orderP) || orderP.contains(prodA))) ||
          (a.sku.isNotEmpty && orderP.contains(a.sku.toLowerCase()));
    }).toList();

    final totalCustody = matchingAlloc.fold(0, (sum, a) => sum + a.inCustodyUnits);
    if (activeOrders == null || activeOrders.isEmpty) {
      return totalCustody;
    }

    int reservedUnits = 0;
    for (final order in activeOrders) {
      final agentId = order.deliveryAgentId?.toString() ?? '';
      final agentCode = order.deliveryAgentCode?.toString() ?? '';
      final status = order.status?.toString().toLowerCase() ?? '';
      final pName = order.productName?.toString().toLowerCase() ?? '';
      final int qty = (order.quantity is num) ? (order.quantity as num).toInt() : 1;

      final isThisDriver = (agentId.isNotEmpty && agentId == riderId) || (agentCode.isNotEmpty && agentCode == riderCode);
      final isActive = status == 'in_transit' || status == 'accepted' || status == 'out_for_delivery' || status == 'assigned' || status == 'contacting';
      final isSameProduct = pName.contains(productName.toLowerCase()) || productName.toLowerCase().contains(pName);

      if (isThisDriver && isActive && isSameProduct) {
        reservedUnits += qty;
      }
    }

    return (totalCustody - reservedUnits).clamp(0, 999999);
  }

  /// Record order assignment in rider stock custody
  void recordOrderAssignment({
    required String riderId,
    required String riderCode,
    required String productName,
    required int quantity,
  }) {
    final allocIdx = state.riderAllocations.indexWhere((a) =>
        (a.riderId.toLowerCase() == riderId.toLowerCase() || a.riderCode.toLowerCase() == riderCode.toLowerCase()) &&
        (a.productName.toLowerCase().contains(productName.toLowerCase()) || productName.toLowerCase().contains(a.productName.toLowerCase())));

    if (allocIdx != -1) {
      final alloc = state.riderAllocations[allocIdx];
      final updatedAllocations = List<RiderStockAllocation>.from(state.riderAllocations);
      updatedAllocations[allocIdx] = alloc.copyWith(
        allocatedAt: DateTime.now(),
      );
      state = state.copyWith(riderAllocations: updatedAllocations);
      _storageService.cacheRiderStockAllocations(updatedAllocations);
    }
  }

  /// Record order successfully delivered POD: decrements custody units and increments delivered count
  Future<void> recordOrderDelivered({
    required String riderId,
    required String riderCode,
    required String productName,
    required int quantity,
  }) async {
    final allocIdx = state.riderAllocations.indexWhere((a) =>
        (a.riderId.toLowerCase() == riderId.toLowerCase() || a.riderCode.toLowerCase() == riderCode.toLowerCase()) &&
        (a.productName.toLowerCase().contains(productName.toLowerCase()) || productName.toLowerCase().contains(a.productName.toLowerCase())));

    List<RiderStockAllocation> updatedAllocations = List<RiderStockAllocation>.from(state.riderAllocations);
    if (allocIdx != -1) {
      final alloc = state.riderAllocations[allocIdx];
      updatedAllocations[allocIdx] = alloc.copyWith(
        inCustodyUnits: (alloc.inCustodyUnits - quantity).clamp(0, 999999),
        deliveredUnits: alloc.deliveredUnits + quantity,
      );
    }

    // Also deduct assignedCount and increment deliveredCount in warehouse stock items
    List<StockItemEntity> updatedStockItems = List<StockItemEntity>.from(state.stockItems);
    final itemIdx = state.stockItems.indexWhere((i) =>
        i.name.toLowerCase().contains(productName.toLowerCase()) ||
        productName.toLowerCase().contains(i.name.toLowerCase()) ||
        i.sku.toLowerCase() == productName.toLowerCase());

    if (itemIdx != -1) {
      final item = state.stockItems[itemIdx];
      updatedStockItems[itemIdx] = item.copyWith(
        assignedCount: (item.assignedCount - quantity).clamp(0, 999999),
        deliveredCount: item.deliveredCount + quantity,
      );
    }

    state = state.copyWith(
      riderAllocations: updatedAllocations,
      stockItems: updatedStockItems,
    );
    await _storageService.cacheRiderStockAllocations(updatedAllocations);
    await _storageService.cacheStockItems(updatedStockItems);
  }

  /// Record order returned / failed: updates returned count
  Future<void> recordOrderReturned({
    required String riderId,
    required String riderCode,
    required String productName,
    required int quantity,
  }) async {
    final allocIdx = state.riderAllocations.indexWhere((a) =>
        (a.riderId.toLowerCase() == riderId.toLowerCase() || a.riderCode.toLowerCase() == riderCode.toLowerCase()) &&
        (a.productName.toLowerCase().contains(productName.toLowerCase()) || productName.toLowerCase().contains(a.productName.toLowerCase())));

    if (allocIdx != -1) {
      final alloc = state.riderAllocations[allocIdx];
      final updatedAllocations = List<RiderStockAllocation>.from(state.riderAllocations);
      updatedAllocations[allocIdx] = alloc.copyWith(
        returnedUnits: alloc.returnedUnits + quantity,
      );
      state = state.copyWith(riderAllocations: updatedAllocations);
      await _storageService.cacheRiderStockAllocations(updatedAllocations);
    }
  }

  Future<Map<String, dynamic>> processStockReturn({
    required String returnNumber,
    required String orderId,
    required String deliveryAgentId,
    required String productId,
    required int quantity,
    required String reason,
    String? destinationDcId,
    String? condition,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final isImmediateSync =
          orderId == 'MANUAL-DAMAGE-RETURN' || orderId == 'OFFBOARD-CLEARANCE';
      final cleanCond = (condition ?? 'good').trim().toLowerCase();
      final isGood = cleanCond == 'good' || cleanCond == 'sellable' || cleanCond == 'sealed';

      if (isImmediateSync && quantity > 0) {
        final updatedAllocations = state.riderAllocations.map((a) {
          final sameRider = a.riderId == deliveryAgentId || a.riderCode == deliveryAgentId;
          final sameProd = a.productId == productId ||
              a.sku.toLowerCase() == productId.toLowerCase() ||
              a.productName.toLowerCase() == productId.toLowerCase();
          if (sameRider && sameProd) {
            return a.copyWith(
              inCustodyUnits: (a.inCustodyUnits - quantity).clamp(0, 999999),
              returnedUnits: a.returnedUnits + quantity,
            );
          }
          return a;
        }).toList();

        final updatedItems = state.stockItems.map((item) {
          final sameProd = item.id == productId ||
              item.sku.toLowerCase() == productId.toLowerCase() ||
              item.name.toLowerCase() == productId.toLowerCase();
          if (sameProd) {
            return item.copyWith(
              availableCount: isGood ? item.availableCount + quantity : item.availableCount,
              assignedCount: (item.assignedCount - quantity).clamp(0, 999999),
              returnedCount: item.returnedCount + quantity,
              damagedCount: isGood ? item.damagedCount : item.damagedCount + quantity,
              complaintCount: isGood ? item.complaintCount : item.complaintCount + quantity,
            );
          }
          return item;
        }).toList();

        state = state.copyWith(
          riderAllocations: updatedAllocations,
          stockItems: updatedItems,
        );
        await _storageService.cacheRiderStockAllocations(updatedAllocations);
        await _storageService.cacheStockItems(updatedItems);
      }

      String? effectiveDcId = (destinationDcId != null && destinationDcId.isNotEmpty)
          ? destinationDcId
          : null;
      if (effectiveDcId == null || effectiveDcId.isEmpty) {
        try {
          effectiveDcId = _ref?.read(dcConsoleProvider).activeHubId;
        } catch (_) {}
      }
      effectiveDcId ??= _ref?.read(authProvider).user?.distributionCenterId;

      final result = await repository.processStockReturn(
        returnNumber: returnNumber,
        orderId: orderId,
        deliveryAgentId: deliveryAgentId,
        productId: productId,
        quantity: quantity,
        reason: reason,
        destinationDcId: effectiveDcId,
        condition: condition,
        notes: notes,
      );

      final user = _ref?.read(authProvider).user;
      final isDcOperator = user != null && (user.isDcManager || user.isDcOperations || user.isDcStockAdmin);
      await fetchStockItems(
        isDcOperator ? null : deliveryAgentId,
        effectiveDcId,
      );
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

  /// Automatically deducts physical units from rider vehicle stock and records delivered count upon order POD completion
  Future<void> recordDeliveredOrderStock({
    required String productNameOrSku,
    required String riderId,
    required int physicalQuantity,
  }) async {
    if (physicalQuantity <= 0) return;

    final q = physicalQuantity;

    // 1. Update Rider Stock Allocation
    final updatedAllocations = state.riderAllocations.map((alloc) {
      final matchesRider = alloc.riderId == riderId;
      final matchesProd = alloc.productName.toLowerCase() == productNameOrSku.toLowerCase() ||
          alloc.sku.toLowerCase() == productNameOrSku.toLowerCase() ||
          alloc.productId == productNameOrSku;

      if (matchesRider && matchesProd) {
        final newInCustody = (alloc.inCustodyUnits - q).clamp(0, 999999);
        final newDelivered = alloc.deliveredUnits + q;
        return alloc.copyWith(
          inCustodyUnits: newInCustody,
          deliveredUnits: newDelivered,
        );
      }
      return alloc;
    }).toList();

    // 2. Update Master Stock Items
    final updatedItems = state.stockItems.map((item) {
      final matchesProd = item.name.toLowerCase() == productNameOrSku.toLowerCase() ||
          item.sku.toLowerCase() == productNameOrSku.toLowerCase() ||
          item.id == productNameOrSku;

      if (matchesProd) {
        final newAvailable = (item.availableCount - q).clamp(0, 999999);
        final newDelivered = item.deliveredCount + q;
        return item.copyWith(
          availableCount: newAvailable,
          deliveredCount: newDelivered,
        );
      }
      return item;
    }).toList();

    state = state.copyWith(
      stockItems: updatedItems,
      riderAllocations: updatedAllocations,
    );

    await _storageService.cacheStockItems(updatedItems);
    await _storageService.cacheRiderStockAllocations(updatedAllocations);

    try {
      await repository.updateRiderStockCustody(
        riderId: riderId,
        productId: productNameOrSku,
        deliveredDelta: q,
        inCustodyDelta: -q,
      );
    } catch (_) {}
  }

  /// Reconcile a single product in rider vehicle custody directly
  Future<void> reconcileRiderProductStock({
    required String productIdOrSku,
    required String riderId,
    required int physicalCounted,
    String? reason,
    String? notes,
  }) async {
    final updatedAllocations = state.riderAllocations.map((alloc) {
      final matchesRider = alloc.riderId == riderId;
      final matchesProd = alloc.productId == productIdOrSku ||
          alloc.sku.toLowerCase() == productIdOrSku.toLowerCase() ||
          alloc.productName.toLowerCase() == productIdOrSku.toLowerCase();

      if (matchesRider && matchesProd) {
        return alloc.copyWith(
          inCustodyUnits: physicalCounted,
        );
      }
      return alloc;
    }).toList();

    final updatedItems = state.stockItems.map((item) {
      final matchesProd = item.id == productIdOrSku ||
          item.sku.toLowerCase() == productIdOrSku.toLowerCase() ||
          item.name.toLowerCase() == productIdOrSku.toLowerCase();

      if (matchesProd) {
        return item.copyWith(
          availableCount: physicalCounted,
          lastAuditDate: DateTime.now().toIso8601String().substring(0, 10),
        );
      }
      return item;
    }).toList();

    state = state.copyWith(
      stockItems: updatedItems,
      riderAllocations: updatedAllocations,
      lastAuditedTime: DateTime.now(),
      isAuditRequired: false,
    );

    await _storageService.cacheStockItems(updatedItems);
    await _storageService.cacheRiderStockAllocations(updatedAllocations);
  }

  /// Reconcile all products in rider vehicle custody from the audit page
  Future<void> submitRiderStockAudit({
    required String riderId,
    required Map<String, int> physicalCounts,
    Map<String, String>? varianceReasons,
    Map<String, String>? notes,
  }) async {
    final updatedAllocations = state.riderAllocations.map((alloc) {
      if (alloc.riderId == riderId && physicalCounts.containsKey(alloc.productId)) {
        final count = physicalCounts[alloc.productId]!;
        return alloc.copyWith(inCustodyUnits: count);
      }
      return alloc;
    }).toList();

    final updatedItems = state.stockItems.map((item) {
      if (physicalCounts.containsKey(item.id)) {
        final count = physicalCounts[item.id]!;
        return item.copyWith(
          availableCount: count,
          lastAuditDate: DateTime.now().toIso8601String().substring(0, 10),
        );
      }
      return item;
    }).toList();

    state = state.copyWith(
      stockItems: updatedItems,
      riderAllocations: updatedAllocations,
      lastAuditedTime: DateTime.now(),
      isAuditRequired: false,
    );

    await _storageService.cacheStockItems(updatedItems);
    await _storageService.cacheRiderStockAllocations(updatedAllocations);

    // Persist audit header & line items to Supabase public.inventory_audits
    try {
      final List<Map<String, dynamic>> auditLineItems = [];
      physicalCounts.forEach((prodId, physicalCount) {
        final alloc = state.riderAllocations.firstWhere(
          (a) => a.productId == prodId && a.riderId == riderId,
          orElse: () => RiderStockAllocation.empty(),
        );
        final expected = alloc.inCustodyUnits;
        final variance = physicalCount - expected;
        auditLineItems.add({
          'product_id': prodId,
          'expected_quantity': expected,
          'actual_quantity': physicalCount,
          'variance': variance,
          'variance_reason': varianceReasons?[prodId] ?? (variance == 0 ? 'Exact count match' : 'Discrepancy reported during mobile audit'),
        });
      });

      final authUser = Supabase.instance.client.auth.currentUser;
      final companyId = authUser?.userMetadata?['company_id']?.toString() ??
          (authUser != null ? authUser.appMetadata['company_id']?.toString() : null) ??
          '';

      await repository.submitDetailedInventoryAudit(
        companyId: companyId.isNotEmpty ? companyId : '00000000-0000-0000-0000-000000000000',
        auditorId: authUser?.id ?? riderId,
        auditType: 'rider_mobile',
        riderId: riderId,
        items: auditLineItems,
        notes: notes != null && notes.isNotEmpty ? notes.values.join('; ') : 'Mobile Rider Vehicle Audit',
      );
    } catch (e) {
      debugPrint('[STOCK_PROVIDER] ⚠️ submitDetailedInventoryAudit persistence notice: $e');
    }
  }

  /// DC Supervisor accepts and restocks a rider return
  Future<Map<String, dynamic>> receiveRiderReturn({
    required String returnId,
    required String dcId,
    required String receiverId,
    required int verifiedQuantity,
    String condition = 'good',
    String? notes,
  }) async {
    final res = await repository.receiveRiderStockReturn(
      returnId: returnId,
      dcId: dcId,
      receiverId: receiverId,
      verifiedQuantity: verifiedQuantity,
      condition: condition,
      notes: notes,
    );
    await fetchStockItems(null, dcId);
    return res;
  }

  /// DC Supervisor queries pending rider returns
  Future<List<Map<String, dynamic>>> fetchPendingDcReturns(String dcId) async {
    return await repository.fetchPendingDcReturns(dcId);
  }

  /// Fetch stock transfers with joined items & dual signatures
  Future<void> fetchStockTransfers({
    String? dcId,
    String? clientId,
    String? riderId,
    String? status,
    String? transferType,
  }) async {
    state = state.copyWith(isTransfersLoading: true);
    try {
      final transfers = await repository.fetchStockTransfers(
        dcId: dcId,
        clientId: clientId,
        riderId: riderId,
        status: status,
        transferType: transferType,
      );
      state = state.copyWith(
        stockTransfers: transfers,
        isTransfersLoading: false,
      );
    } catch (e) {
      debugPrint('[STOCK_PROVIDER] ⚠️ fetchStockTransfers error: $e');
      state = state.copyWith(isTransfersLoading: false);
    }
  }

  /// Destination DC accepts and balances an inbound Inter-DC stock transfer
  Future<Map<String, dynamic>> receiveInterDcTransfer({
    required String transferId,
    String? receiverId,
    String? receiverName,
    int? quantityReceived,
    String? notes,
    String? dcId,
  }) async {
    try {
      final res = await repository.receiveInterDcTransfer(
        transferId: transferId,
        receiverId: receiverId,
        receiverName: receiverName,
        quantityReceived: quantityReceived,
        notes: notes,
      );
      // Refresh inventory and transfers
      await fetchStockItems(null, dcId);
      await fetchStockTransfers(dcId: dcId);
      return res;
    } catch (e) {
      debugPrint('[STOCK_PROVIDER] ⚠️ receiveInterDcTransfer error: $e');
      rethrow;
    }
  }

  /// Party A (Merchant/Client): Dispatches consignment request to DC (Two-Way Handshake)
  Future<Map<String, dynamic>> dispatchClientSupply({
    required String clientId,
    required String dcId,
    required List<Map<String, dynamic>> items,
    String? senderId,
    required String senderName,
    String senderSignatureUrl = '',
    String? notes,
  }) async {
    try {
      final res = await repository.dispatchClientSupply(
        clientId: clientId,
        dcId: dcId,
        items: items,
        senderId: senderId,
        senderName: senderName,
        senderSignatureUrl: senderSignatureUrl,
        notes: notes,
      );
      // Refresh transfers
      await fetchStockTransfers(clientId: clientId, dcId: dcId);
      return res;
    } catch (e) {
      debugPrint('[STOCK_PROVIDER] ⚠️ dispatchClientSupply error: $e');
      rethrow;
    }
  }

  /// Universal Handshake Reception for Inbound Consignments (Client Supply or Inter-DC)
  Future<Map<String, dynamic>> receiveSupplyConsignmentHandshake({
    required String transferId,
    required String receiverId,
    required String receiverName,
    String receiverRole = 'dc_supervisor',
    String receiverSignatureUrl = '',
    String carrierDriverName = '',
    String carrierPhone = '',
    String carrierLicensePlate = '',
    String waybillSlipUrl = '',
    String destinationBin = '',
    required List<Map<String, dynamic>> verifiedItems,
    String? notes,
    String? dcId,
  }) async {
    try {
      final res = await repository.receiveSupplyConsignmentHandshake(
        transferId: transferId,
        receiverId: receiverId,
        receiverName: receiverName,
        receiverRole: receiverRole,
        receiverSignatureUrl: receiverSignatureUrl,
        carrierDriverName: carrierDriverName,
        carrierPhone: carrierPhone,
        carrierLicensePlate: carrierLicensePlate,
        waybillSlipUrl: waybillSlipUrl,
        destinationBin: destinationBin,
        verifiedItems: verifiedItems,
        notes: notes,
      );
      // Refresh inventory and transfers
      await fetchStockItems(null, dcId);
      await fetchStockTransfers(dcId: dcId);
      return res;
    } catch (e) {
      debugPrint('[STOCK_PROVIDER] ⚠️ receiveSupplyConsignmentHandshake error: $e');
      rethrow;
    }
  }

  /// Party B (DC Supervisor): Inspects physical items, verifies counts, and accepts inbound stock into DC
  Future<Map<String, dynamic>> receiveClientSupply({
    required String transferId,
    required String receiverId,
    required String receiverName,
    String receiverSignatureUrl = '',
    required List<Map<String, dynamic>> verifiedItems,
    String? notes,
    String? dcId,
  }) async {
    return receiveSupplyConsignmentHandshake(
      transferId: transferId,
      receiverId: receiverId,
      receiverName: receiverName,
      receiverSignatureUrl: receiverSignatureUrl,
      verifiedItems: verifiedItems,
      notes: notes,
      dcId: dcId,
    );
  }

  /// Party A (DC Supervisor): Issues stock to rider (reserves shelf stock)
  Future<Map<String, dynamic>> issueDcStockToRiderWithSignature({
    required String dcId,
    required String riderId,
    required List<Map<String, dynamic>> items,
    required String senderId,
    required String senderName,
    String senderSignatureUrl = '',
    String? notes,
  }) async {
    try {
      final res = await repository.issueDcStockToRiderWithSignature(
        dcId: dcId,
        riderId: riderId,
        items: items,
        senderId: senderId,
        senderName: senderName,
        senderSignatureUrl: senderSignatureUrl,
        notes: notes,
      );
      // Refresh inventory and transfers
      await fetchStockItems(null, dcId);
      await fetchStockTransfers(dcId: dcId);
      return res;
    } catch (e) {
      debugPrint('[STOCK_PROVIDER] ⚠️ issueDcStockToRiderWithSignature error: $e');
      rethrow;
    }
  }

  /// Party B (Rider): Verifies physical items in hand and accepts custody
  Future<Map<String, dynamic>> acceptRiderStockHandover({
    required String transferId,
    required String riderId,
    required String riderName,
    String riderSignatureUrl = '',
    List<Map<String, dynamic>>? verifiedItems,
    String? notes,
  }) async {
    try {
      final res = await repository.acceptRiderStockHandover(
        transferId: transferId,
        riderId: riderId,
        riderName: riderName,
        riderSignatureUrl: riderSignatureUrl,
        verifiedItems: verifiedItems,
        notes: notes,
      );
      // Refresh inventory, allocations, and transfers
      await fetchStockItems(riderId);
      await fetchStockTransfers(riderId: riderId);
      return res;
    } catch (e) {
      debugPrint('[STOCK_PROVIDER] ⚠️ acceptRiderStockHandover error: $e');
      rethrow;
    }
  }

  /// Party B (Rider): Rejects handover (returns units back to DC shelf)
  Future<Map<String, dynamic>> rejectRiderStockHandover({
    required String transferId,
    required String riderId,
    String? reason,
  }) async {
    try {
      final res = await repository.rejectRiderStockHandover(
        transferId: transferId,
        riderId: riderId,
        reason: reason,
      );
      // Refresh inventory and transfers
      await fetchStockItems(riderId);
      await fetchStockTransfers(riderId: riderId);
      return res;
    } catch (e) {
      debugPrint('[STOCK_PROVIDER] ⚠️ rejectRiderStockHandover error: $e');
      rethrow;
    }
  }

  /// Reconciles inventory when Dispatch Ops marks an order delivered on behalf of a rider (or direct DC handover).
  /// - When fulfillingRiderId is present: decrements ONLY that rider's vehicle custody (`inCustodyUnits` & `agent_inventory`)
  ///   and increments `deliveredCount` without double-deducting DC warehouse shelf `availableCount`.
  /// - When fulfillingRiderId is null/empty (Direct DC Counter Handover): decrements DC warehouse shelf `availableCount`
  ///   and increments `deliveredCount` without touching any rider's custody.
  Future<void> recordDispatchDeliveredStock({
    required String productNameOrSku,
    String? productId,
    String? riderId,
    String? riderCode,
    String? distributionCenterId,
    required int physicalQuantity,
    String? orderId,
    String? orderNumber,
  }) async {
    if (physicalQuantity <= 0) return;
    final q = physicalQuantity;
    final hasRider = riderId != null && riderId.trim().isNotEmpty;
    final cleanRiderId = riderId?.trim().toLowerCase() ?? '';
    final cleanRiderCode = riderCode?.trim().toLowerCase() ?? '';
    final cleanProdId = productId?.trim() ?? '';
    final cleanProdQuery = productNameOrSku.trim().toLowerCase();

    bool matchesProduct(String id, String sku, String name) {
      if (cleanProdId.isNotEmpty && id == cleanProdId) return true;
      if (cleanProdQuery.isEmpty) return false;
      final n = name.toLowerCase().trim();
      final s = sku.toLowerCase().trim();
      return id.toLowerCase() == cleanProdQuery ||
          (s.isNotEmpty && s == cleanProdQuery) ||
          n == cleanProdQuery ||
          (n.isNotEmpty && (n.contains(cleanProdQuery) || cleanProdQuery.contains(n)));
    }

    // 1. Update Rider Custody ONLY if a fulfilling rider was resolved
    List<RiderStockAllocation> updatedAllocations = state.riderAllocations;
    if (hasRider) {
      updatedAllocations = state.riderAllocations.map((alloc) {
        final allocRId = alloc.riderId.trim().toLowerCase();
        final allocRCode = alloc.riderCode.trim().toLowerCase();
        final matchesRider = (cleanRiderId.isNotEmpty && allocRId == cleanRiderId) ||
            (cleanRiderCode.isNotEmpty && allocRCode == cleanRiderCode);
        final matchesProd = matchesProduct(alloc.productId, alloc.sku, alloc.productName);
        if (matchesRider && matchesProd) {
          return alloc.copyWith(
            inCustodyUnits: (alloc.inCustodyUnits - q).clamp(0, 999999),
            deliveredUnits: alloc.deliveredUnits + q,
          );
        }
        return alloc;
      }).toList();
    }

    // 2. Update Master DC Stock Items (avoiding double-deduction when fulfilled from rider custody)
    StockItemEntity? matchedItem;
    final updatedItems = state.stockItems.map((item) {
      if (matchesProduct(item.id, item.sku, item.name)) {
        matchedItem ??= item;
        return hasRider
            ? item.copyWith(
                assignedCount: (item.assignedCount - q).clamp(0, 999999),
                deliveredCount: item.deliveredCount + q,
              )
            : item.copyWith(
                availableCount: (item.availableCount - q).clamp(0, 999999),
                deliveredCount: item.deliveredCount + q,
              );
      }
      return item;
    }).toList();

    state = state.copyWith(
      stockItems: updatedItems,
      riderAllocations: updatedAllocations,
    );
    await _storageService.cacheStockItems(updatedItems);
    await _storageService.cacheRiderStockAllocations(updatedAllocations);

    // 3. Best-effort live Postgres persistence (skipped in automated test harnesses)
    bool isTest = false;
    try {
      final binding = WidgetsBinding.instance.runtimeType.toString().toLowerCase();
      if (binding.contains('test') || binding.contains('automated')) {
        isTest = true;
      }
    } catch (_) {}
    if (isTest) return;

    try {
      SupabaseClient? dbClient;
      if (SupabaseConstants.supabaseServiceRoleKey.isNotEmpty) {
        dbClient = SupabaseClient(
          SupabaseConstants.supabaseUrl,
          SupabaseConstants.supabaseServiceRoleKey,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
      } else {
        dbClient = Supabase.instance.client;
      }

      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      final nowIso = DateTime.now().toIso8601String();

      Map<String, dynamic>? prodRow;
      final lookupId = cleanProdId.isNotEmpty ? cleanProdId : (matchedItem?.id ?? '');
      if (lookupId.isNotEmpty && uuidRegex.hasMatch(lookupId)) {
        final r = await dbClient.from(SupabaseConstants.productsTable).select().eq('id', lookupId).limit(1);
        if ((r as List).isNotEmpty) prodRow = Map<String, dynamic>.from(r.first as Map);
      }
      if (prodRow == null && productNameOrSku.trim().isNotEmpty) {
        final r = await dbClient
            .from(SupabaseConstants.productsTable)
            .select()
            .ilike('name', productNameOrSku.trim())
            .limit(1);
        if ((r as List).isNotEmpty) prodRow = Map<String, dynamic>.from(r.first as Map);
      }

      final resolvedProdId = prodRow?['id']?.toString() ?? lookupId;
      final isProdUuid = uuidRegex.hasMatch(resolvedProdId);

      // Update rider agent_inventory if rider-fulfilled
      if (hasRider && isProdUuid && uuidRegex.hasMatch(riderId.trim())) {
        try {
          final existingRows = await dbClient
              .from('agent_inventory')
              .select()
              .eq('delivery_agent_id', riderId.trim())
              .eq('product_id', resolvedProdId)
              .limit(1);
          if ((existingRows as List).isNotEmpty) {
            final row = Map<String, dynamic>.from(existingRows.first as Map);
            final curAvail = (row['available_count'] as num?)?.toInt() ?? 0;
            final curCustody = (row['total_in_custody'] as num?)?.toInt() ?? 0;
            final curDelivered = (row['delivered_count_today'] as num?)?.toInt() ?? 0;
            await dbClient.from('agent_inventory').update({
              'available_count': (curAvail - q).clamp(0, 999999),
              'total_in_custody': (curCustody - q).clamp(0, 999999),
              'delivered_count_today': curDelivered + q,
              'updated_at': nowIso,
            }).eq('id', row['id']);
          }
        } catch (aiErr) {
          debugPrint('[STOCK_PROVIDER] ℹ️ dispatch delivery agent_inventory notice: $aiErr');
        }
      }

      // Update products row
      if (prodRow != null && isProdUuid) {
        try {
          final curDelivered = (prodRow['delivered_count'] as num?)?.toInt() ?? 0;
          final productUpdate = <String, dynamic>{
            'delivered_count': curDelivered + q,
            'updated_at': nowIso,
          };
          if (!hasRider) {
            // Direct DC counter handover: deduct DC shelf stock without double-deducting rider custody
            final curAvail = (prodRow['available_count'] as num?)?.toInt() ??
                (prodRow['stock_quantity'] as num?)?.toInt() ??
                0;
            final curQty = (prodRow['stock_quantity'] as num?)?.toInt() ?? curAvail;
            productUpdate['available_count'] = (curAvail - q).clamp(0, 999999);
            productUpdate['stock_quantity'] = (curQty - q).clamp(0, 999999);

            final rawDcStocks = prodRow['dc_stocks'];
            final Map<String, int> dcStocks = {};
            if (rawDcStocks is Map) {
              rawDcStocks.forEach((k, v) {
                dcStocks[k.toString()] = (v as num?)?.toInt() ?? 0;
              });
            }
            final dcKey = distributionCenterId?.trim() ?? '';
            if (dcKey.isNotEmpty) {
              final curDc = dcStocks[dcKey] ?? curAvail;
              dcStocks[dcKey] = (curDc - q).clamp(0, 999999);
              productUpdate['dc_stocks'] = dcStocks;
              var desc = prodRow['description']?.toString() ?? '';
              final jsonTag = jsonEncode(dcStocks);
              if (desc.contains('[DC_STOCKS:')) {
                desc = desc.replaceAll(RegExp(r'\[DC_STOCKS:\s*\{.*?\}\]'), '[DC_STOCKS: $jsonTag]');
              } else {
                desc = desc.isEmpty ? '[DC_STOCKS: $jsonTag]' : '$desc [DC_STOCKS: $jsonTag]';
              }
              productUpdate['description'] = desc;
            }
          }
          await dbClient.from(SupabaseConstants.productsTable).update(productUpdate).eq('id', resolvedProdId);
        } catch (pErr) {
          debugPrint('[STOCK_PROVIDER] ℹ️ dispatch delivery products notice: $pErr');
        }

        // Record outgoing ledger entry in client_stock_balances & client_stock_ledger_entries
        try {
          var clientId = prodRow['client_id']?.toString().trim() ?? '';
          final clientName = prodRow['client_name']?.toString().trim() ?? '';
          if (clientId.isEmpty && clientName.isNotEmpty) {
            final cRes = await dbClient.from('clients').select('id').ilike('company_name', clientName).limit(1);
            if ((cRes as List).isNotEmpty) clientId = cRes.first['id']?.toString() ?? '';
          }
          if (clientId.isNotEmpty) {
            final sku = prodRow['sku']?.toString().trim() ?? '';
            final name = prodRow['name']?.toString().trim() ?? productNameOrSku;
            final balRes = await dbClient.from('client_stock_balances').select().eq('client_id', clientId);
            Map<String, dynamic>? bal;
            for (final r in balRes as List) {
              final b = Map<String, dynamic>.from(r as Map);
              if (b['product_id']?.toString() == resolvedProdId ||
                  (sku.isNotEmpty && b['item_code']?.toString().toUpperCase() == sku.toUpperCase()) ||
                  b['item_name']?.toString().toLowerCase() == name.toLowerCase()) {
                bal = b;
                break;
              }
            }
            final double valRate = (bal?['valuation_rate'] as num?)?.toDouble() ??
                (prodRow['cost_price'] as num?)?.toDouble() ??
                0.0;
            if (bal != null) {
              final curOutQty = (bal['out_qty'] as num?)?.toDouble() ?? 0.0;
              final curOutVal = (bal['out_value'] as num?)?.toDouble() ?? 0.0;
              final curBalQty = (bal['balance_qty'] as num?)?.toDouble() ?? 0.0;
              final newBalQty = (curBalQty - q).clamp(0.0, 999999999.0);
              await dbClient.from('client_stock_balances').update({
                'out_qty': curOutQty + q,
                'out_value': curOutVal + (q * valRate),
                'balance_qty': newBalQty,
                'balance_value': newBalQty * valRate,
                'updated_at': nowIso,
              }).eq('id', bal['id']);
            }
            await dbClient.from('client_stock_ledger_entries').insert({
              'client_id': clientId,
              'warehouse': bal?['warehouse']?.toString() ?? 'Distribution Center',
              'item_code': bal?['item_code']?.toString() ?? (sku.isNotEmpty ? sku : resolvedProdId),
              'item_name': bal?['item_name']?.toString() ?? name,
              'item_group': bal?['item_group']?.toString() ?? (clientName.isNotEmpty ? clientName : 'Novacare'),
              'voucher_type': 'sales_order_delivery',
              'voucher_no': orderNumber?.isNotEmpty == true
                  ? 'DISP-$orderNumber'
                  : 'DISP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
              if (orderId != null && uuidRegex.hasMatch(orderId)) 'order_id': orderId,
              'posting_date': DateTime.now().toIso8601String().split('T').first,
              'posting_at': nowIso,
              'qty_change': -q,
              'incoming_qty': 0,
              'outgoing_qty': q,
              'valuation_rate': valRate,
              'total_value': q * valRate,
              'notes': 'Dispatch Ops marked delivered (${hasRider ? "Rider custody: $riderCode" : "Direct DC handover"})',
            });
          }
        } catch (lErr) {
          debugPrint('[STOCK_PROVIDER] ℹ️ dispatch delivery ledger notice: $lErr');
        }
      }
    } catch (e) {
      debugPrint('[STOCK_PROVIDER] ℹ️ recordDispatchDeliveredStock persistence notice: $e');
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
      supabaseClient: SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseAnonKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
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
  return StockNotifier(repository: repo, storageService: storage, ref: ref);
});
