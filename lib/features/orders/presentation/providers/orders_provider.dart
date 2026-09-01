import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../../../core/services/local_storage_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/orders_remote_datasource.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/orders_repository_impl.dart';
import '../../data/services/geocoding_service.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/orders_repository.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../../finance/presentation/providers/finance_provider.dart';
import '../../../dc_console/presentation/providers/dc_console_provider.dart';

final ordersRemoteDataSourceProvider = Provider<OrdersRemoteDataSource>((ref) {
  try {
    return OrdersRemoteDataSourceImpl(Supabase.instance.client);
  } catch (_) {
    return MockOrdersRemoteDataSource();
  }
});

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepositoryImpl(ref.watch(ordersRemoteDataSourceProvider));
});

final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  try {
    return GeocodingService(Supabase.instance.client);
  } catch (_) {
    return GeocodingService();
  }
});

class OrdersState {
  final bool isLoading;
  final List<OrderEntity> orders;
  final String? errorMessage;

  OrdersState({
    this.isLoading = false,
    this.orders = const [],
    this.errorMessage,
  });

  OrdersState copyWith({
    bool? isLoading,
    List<OrderEntity>? orders,
    String? errorMessage,
  }) {
    return OrdersState(
      isLoading: isLoading ?? this.isLoading,
      orders: orders ?? this.orders,
      errorMessage: errorMessage,
    );
  }
}

class OrdersNotifier extends StateNotifier<OrdersState> {
  final OrdersRepository _repository;
  final GeocodingService? _geocodingService;
  final LocalStorageService _storageService;
  final Ref? _ref;
  RealtimeChannel? _realtimeChannel;
  Timer? _heartbeatTimer;

  OrdersNotifier(
    this._repository, [
    this._geocodingService,
    LocalStorageService? storageService,
    this._ref,
  ])  : _storageService = storageService ?? LocalStorageServiceImpl(),
        super(OrdersState()) {
    bool isTest = false;
    try {
      if (!kIsWeb && (Platform.environment.containsKey('FLUTTER_TEST') ||
          Platform.environment.containsKey('TEST_PLATFORM'))) {
        isTest = true;
      }
    } catch (_) {}
    try {
      final binding = WidgetsBinding.instance.runtimeType.toString().toLowerCase();
      if (binding.contains('test') || binding.contains('automated')) {
        isTest = true;
      }
    } catch (_) {}

    _initOrders(isTest);

    if (!isTest) {
      _setupRealtimeSubscription();
      _startHeartbeatTimer();
    }

    if (_ref != null) {
      _ref.listen<AuthState>(authProvider, (previous, next) {
        final nextAgentId = next.user?.deliveryAgentId ?? next.user?.id;
        if (nextAgentId != null && nextAgentId.isNotEmpty) {
          loadOrders(nextAgentId);
        }
      });
    }
  }

  bool _isRiderUser() {
    if (_ref != null) {
      final user = _ref.read(authProvider).user;
      if (user == null) return false;
      final role = user.role.toLowerCase();
      return (role.contains('rider') || role.contains('agent') || role.contains('driver') || user.isPda) &&
          ((user.deliveryAgentId != null && user.deliveryAgentId!.isNotEmpty) || user.id.isNotEmpty);
    }
    return false;
  }

  String _getActiveAgentId() {
    if (_ref != null) {
      final user = _ref.read(authProvider).user;
      if (user != null) {
        return user.deliveryAgentId ?? user.id;
      }
    }
    return '';
  }

  String _getScopeKey() {
    if (_isRiderUser()) {
      final agentId = _getActiveAgentId();
      return agentId.isNotEmpty ? 'rider_$agentId' : 'rider';
    }
    return 'dc';
  }

  List<OrderEntity> _sortOrdersByOperationalPriority(List<OrderEntity> rawOrders) {
    final list = [...rawOrders];
    list.sort((a, b) {
      int getOrderPriority(OrderEntity o) {
        switch (o.status.toLowerCase()) {
          case 'in_transit':
          case 'picked_up':
            return 0; // Top: Active in progress
          case 'pending':
          case 'assigned':
          case 'accepted':
          case 'new':
            return 1; // Next: Pending dispatch
          case 'call_back':
          case 'contacting':
          case 'upsell_pending':
            return 2; // Next: Call back
          case 'delivered':
            // Prioritize cash in vehicle custody awaiting remittance before already settled/remitted orders
            final isAwaitingRemittance = o.isUnremitted && !o.isDirectTransfer;
            return isAwaitingRemittance ? 3 : 4;
          case 'failed':
          case 'cancelled':
          case 'returned':
            return 5; // Bottom
          default:
            return 2;
        }
      }

      final pA = getOrderPriority(a);
      final pB = getOrderPriority(b);
      if (pA != pB) {
        return pA.compareTo(pB);
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  void _setupRealtimeSubscription() {
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
          .channel('public_orders_realtime_channel')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            callback: (payload) {
              debugPrint('[ORDERS_REALTIME] 🔔 Realtime event on orders table: ${payload.eventType}');
              final agentId = _getActiveAgentId();
              if (agentId.isNotEmpty) {
                _silentSyncOrders(agentId);
              } else {
                _silentSyncOrders();
              }
            },
          )
          .subscribe();
      debugPrint('[ORDERS_PROVIDER] 📡 Orders Realtime stream active.');
    } catch (e) {
      debugPrint('[ORDERS_PROVIDER] ℹ️ Realtime channel notice: $e');
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
      final agentId = _getActiveAgentId();
      if (agentId.isNotEmpty && _isRiderUser()) {
        _silentSyncOrders(agentId);
      } else {
        _silentSyncOrders();
      }
    });
  }

  Future<void> _silentSyncOrders([String? agentId]) async {
    if (!mounted) return;
    try {
      final isRider = _isRiderUser();
      final targetId = (agentId != null && agentId.isNotEmpty) ? agentId : _getActiveAgentId();
      final user = _ref?.read(authProvider).user;
      final dcId = user?.distributionCenterId ?? '22222222-2222-4222-8222-222222222222';

      List<OrderEntity> fetchedList;
      if (isRider && targetId.isNotEmpty) {
        fetchedList = await _repository.getAssignedOrders(targetId);
      } else {
        fetchedList = await _repository.getDistributionCenterOrders(dcId);
      }

      final freshList = _sortOrdersByOperationalPriority(fetchedList);

      if (!mounted) return;

      // Check if list or any order attribute changed
      bool hasChanges = freshList.length != state.orders.length;
      if (!hasChanges) {
        for (int i = 0; i < freshList.length; i++) {
          final f = freshList[i];
          final s = state.orders[i];
          if (f.id != s.id ||
              f.status != s.status ||
              f.paymentStatus != s.paymentStatus ||
              f.paymentType != s.paymentType ||
              f.remittanceStatus != s.remittanceStatus ||
              f.financialSettlementStatus != s.financialSettlementStatus ||
              f.deliveryAgentId != s.deliveryAgentId ||
              f.customerSignatureUrl != s.customerSignatureUrl ||
              f.photoProofUrl != s.photoProofUrl ||
              f.gatePassCode != s.gatePassCode ||
              f.latitude != s.latitude ||
              f.longitude != s.longitude ||
              f.deliveryNotes != s.deliveryNotes) {
            hasChanges = true;
            break;
          }
        }
      }

      if (hasChanges && mounted) {
        debugPrint('[ORDERS_PROVIDER] ⚡ Auto-synced ${freshList.length} orders in real time.');
        state = state.copyWith(orders: freshList);
        await _storageService.cacheOrders(freshList, _getScopeKey());
        if (_ref != null) {
          final activeTargetId = isRider ? targetId : dcId;
          _ref.read(financeProvider.notifier).loadRemittances(activeTargetId);
        }
      }
    } catch (_) {}
  }

  Future<void> _initOrders([bool skipRemoteFetch = false]) async {
    final cached = await _storageService.getCachedOrders(_getScopeKey());
    if (!mounted) return;
    if (cached != null && cached.isNotEmpty) {
      final sortedCached = _sortOrdersByOperationalPriority(cached);
      state = state.copyWith(orders: sortedCached);
      debugPrint('[ORDERS_PROVIDER] ⚡ Hydrated ${sortedCached.length} orders from local cache for scope (${_getScopeKey()}).');
    }
    if (skipRemoteFetch) return;
    final agentId = _getActiveAgentId();
    if (!mounted) return;
    if (agentId.isNotEmpty && _isRiderUser()) {
      await loadOrders(agentId);
    } else {
      await loadOrders();
    }
  }

  Future<void> fetchOrders() async {
    await loadOrders();
  }

  Future<void> loadOrders([String? agentId]) async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final isRider = _isRiderUser();
      if (isRider && ((agentId != null && agentId.isNotEmpty) || _getActiveAgentId().isNotEmpty)) {
        final idToLoad = (agentId != null && agentId.isNotEmpty) ? agentId : _getActiveAgentId();
        final rawOrders = await _repository.getAssignedOrders(idToLoad);
        if (!mounted) return;
        final orderEntities = _sortOrdersByOperationalPriority(rawOrders);
        state = state.copyWith(isLoading: false, orders: orderEntities);
        await _storageService.cacheOrders(orderEntities, _getScopeKey());
      } else {
        final rawOrders = await _repository.getDistributionCenterOrders('22222222-2222-4222-8222-222222222222');
        if (!mounted) return;
        final orderEntities = _sortOrdersByOperationalPriority(rawOrders);
        state = state.copyWith(isLoading: false, orders: orderEntities);
        await _storageService.cacheOrders(orderEntities, _getScopeKey());
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load manifest orders: $e',
      );
    }
  }

  Future<void> loadDcOrders([String? dcId]) async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final rawOrders = await _repository.getDistributionCenterOrders(dcId ?? '22222222-2222-4222-8222-222222222222');
      if (!mounted) return;
      final orderEntities = _sortOrdersByOperationalPriority(rawOrders);
      state = state.copyWith(isLoading: false, orders: orderEntities);
      await _storageService.cacheOrders(orderEntities, 'dc');
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to load DC orders: $e');
    }
  }

  Future<bool> createOrder(Map<String, dynamic> orderData) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final created = await _repository.createOrder(orderData);
      final rawUpdated = [
        created,
        ...state.orders.where((o) => o.id != created.id && o.orderNumber != created.orderNumber),
      ];
      final updatedOrders = _sortOrdersByOperationalPriority(rawUpdated);
      state = state.copyWith(
        isLoading: false,
        orders: updatedOrders,
      );
      await _storageService.cacheOrders(updatedOrders, _getScopeKey());
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to create order: $e');
      return false;
    }
  }

  /// Bulk creates orders from parsed CSV data
  Future<Map<String, dynamic>> bulkCreateOrders(List<Map<String, dynamic>> ordersList) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    int successCount = 0;
    int failCount = 0;
    final List<OrderEntity> newOrders = [];

    for (final orderData in ordersList) {
      try {
        final created = await _repository.createOrder(orderData);
        newOrders.add(created);
        successCount++;
      } catch (e) {
        failCount++;
      }
    }

    final rawUpdated = [
      ...newOrders,
      ...state.orders.where((o) => !newOrders.any((no) => no.id == o.id || no.orderNumber == o.orderNumber)),
    ];
    final updatedOrders = _sortOrdersByOperationalPriority(rawUpdated);
    state = state.copyWith(
      isLoading: false,
      orders: updatedOrders,
    );
    await _storageService.cacheOrders(updatedOrders, _getScopeKey());

    return {
      'success': successCount > 0,
      'importedCount': successCount,
      'failedCount': failCount,
      'totalCount': ordersList.length,
    };
  }

  Future<bool> assignOrderToRider({
    required String orderId,
    required String riderId,
    required String riderName,
    required String riderCode,
  }) async {
    try {
      final targetOrder = state.orders.firstWhere(
        (o) => o.id == orderId || o.orderNumber == orderId,
        orElse: () => OrderModel.empty(),
      );

      // Check stock custody if not a client package
      if (targetOrder.id.isNotEmpty && !targetOrder.isClientPackage && _ref != null) {
        final stockNotifier = _ref.read(stockProvider.notifier);
        final stockState = _ref.read(stockProvider);

        final totalCustody = stockState.getAllocationsForRider(riderId, riderCode).where((a) {
          final pA = a.productName.toLowerCase();
          final oP = targetOrder.productName.toLowerCase();
          return (oP.isNotEmpty && (pA.contains(oP) || oP.contains(pA))) ||
              (a.sku.isNotEmpty && oP.contains(a.sku.toLowerCase()));
        }).fold(0, (sum, a) => sum + a.inCustodyUnits);

        final available = stockNotifier.getRiderAvailableStock(
          riderId: riderId,
          riderCode: riderCode,
          productName: targetOrder.productName,
          activeOrders: state.orders.where((o) => o.id != targetOrder.id && o.orderNumber != targetOrder.orderNumber).toList(),
        );

        // If rider has no custody or available stock is less than required, reject assignment
        if (stockState.stockItems.isNotEmpty && (totalCustody == 0 || available < targetOrder.quantity)) {
          final errorMsg = totalCustody == 0
              ? 'Cannot assign order: Rider $riderName does not have "${targetOrder.productName}" in vehicle custody.'
              : 'Cannot assign order: Rider $riderName has insufficient stock ($available available, ${targetOrder.quantity} required).';
          debugPrint('[ORDERS_NOTIFIER] ❌ $errorMsg');
          state = state.copyWith(errorMessage: errorMsg);
          return false;
        }
      }

      await _repository.assignOrderToRider(
        orderId: orderId,
        riderId: riderId,
        riderName: riderName,
        riderCode: riderCode,
      );

      // Sync stock custody reservation
      if (targetOrder.id.isNotEmpty && _ref != null) {
        _ref.read(stockProvider.notifier).recordOrderAssignment(
          riderId: riderId,
          riderCode: riderCode,
          productName: targetOrder.productName,
          quantity: targetOrder.quantity,
        );
      }

      // Dynamic Rider Terms Lookup: read rider's custom contract terms from DC Console provider
      double dynamicEntitlement = targetOrder.agentEntitlement;
      double dynamicTransport = targetOrder.transportFee;
      if (_ref != null) {
        final dcDrivers = _ref.read(dcConsoleProvider).drivers;
        for (final d in dcDrivers) {
          if (d.id == riderId || d.driverCode == riderCode) {
            if (d.commissionRate > 0) dynamicEntitlement = d.commissionRate;
            if (d.transportAllowance > 0) dynamicTransport = d.transportAllowance;
            break;
          }
        }
      }

      final updatedList = state.orders.map((o) {
        if (o.id == orderId || o.orderNumber == orderId) {
          return OrderModel(
            id: o.id,
            orderNumber: o.orderNumber,
            customerName: o.customerName,
            customerPhone: o.customerPhone,
            customerAltPhone: o.customerAltPhone,
            deliveryState: o.deliveryState,
            deliveryCity: o.deliveryCity,
            deliveryAddress: o.deliveryAddress,
            landmark: o.landmark,
            lga: o.lga,
            productName: o.productName,
            status: 'in_transit',
            quantity: o.quantity,
            paidQuantity: o.paidQuantity,
            freeQuantity: o.freeQuantity,
            basePrice: o.basePrice,
            upsellAmount: o.upsellAmount,
            totalAmount: o.totalAmount,
            paymentType: o.paymentType,
            paymentStatus: o.paymentStatus,
            fulfillmentType: o.fulfillmentType,
            clientName: o.clientName,
            packageCustodyId: o.packageCustodyId,
            clientDeliveryFee: o.clientDeliveryFee,
            agentEntitlement: dynamicEntitlement,
            transportFee: dynamicTransport,
            deliveryNotes: o.deliveryNotes,
            createdAt: o.createdAt,
            deliveryAgentId: riderId,
            deliveryAgentName: riderName,
            deliveryAgentCode: riderCode,
            distributionCenterId: o.distributionCenterId ?? '22222222-2222-4222-8222-222222222222',
          );
        }
        return o;
      }).toList();

      final sortedList = _sortOrdersByOperationalPriority(updatedList);
      state = state.copyWith(orders: sortedList);
      await _storageService.cacheOrders(sortedList, _getScopeKey());
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> updateOrderStatus(
    String orderId,
    String newStatus, {
    String? paymentStatus,
    String? paymentType,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.updateOrderStatus(
        orderId,
        newStatus,
        paymentStatus: paymentStatus,
        paymentType: paymentType,
        notes: notes,
      );
      final updatedList = state.orders.map((o) {
        if (o.id == orderId || o.orderNumber == orderId) {
          return OrderEntity(
            id: o.id,
            orderNumber: o.orderNumber,
            customerName: o.customerName,
            customerPhone: o.customerPhone,
            customerAltPhone: o.customerAltPhone,
            deliveryCity: o.deliveryCity,
            deliveryState: o.deliveryState,
            deliveryAddress: o.deliveryAddress,
            landmark: o.landmark,
            lga: o.lga,
            productName: o.productName,
            status: newStatus,
            quantity: o.quantity,
            paidQuantity: o.paidQuantity,
            freeQuantity: o.freeQuantity,
            basePrice: o.basePrice,
            upsellAmount: o.upsellAmount,
            totalAmount: o.totalAmount,
            paymentType: paymentType ?? o.paymentType,
            paymentStatus: paymentStatus ?? (newStatus == 'delivered' ? 'paid' : o.paymentStatus),
            fulfillmentType: o.fulfillmentType,
            clientName: o.clientName,
            packageCustodyId: o.packageCustodyId,
            clientDeliveryFee: o.clientDeliveryFee,
            agentEntitlement: o.agentEntitlement,
            deliveryNotes: notes ?? o.deliveryNotes,
            createdAt: o.createdAt,
            deliveryAgentId: o.deliveryAgentId,
            deliveryAgentName: o.deliveryAgentName,
            deliveryAgentCode: o.deliveryAgentCode,
            distributionCenterId: o.distributionCenterId,
            latitude: o.latitude,
            longitude: o.longitude,
            geocodingStatus: o.geocodingStatus,
            geocodedAddress: o.geocodedAddress,
            locationConfidence: o.locationConfidence,
            isLocationVerified: o.isLocationVerified,
          );
        }
        return o;
      }).toList();
      final sortedList = _sortOrdersByOperationalPriority(updatedList);
      state = state.copyWith(isLoading: false, orders: sortedList);
      await _storageService.cacheOrders(sortedList, _getScopeKey());
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> updateOrderPaymentStatus({
    required String orderId,
    required String paymentStatus,
    required String remittanceStatus,
  }) async {
    try {
      await _repository.updateOrderStatus(
        orderId,
        'delivered',
        paymentStatus: remittanceStatus == 'remitted' ? 'remitted' : paymentStatus,
        notes: remittanceStatus == 'remitted' ? '[REMITTED & VERIFIED INTO DC TREASURY]' : null,
      );
      final updatedList = state.orders.map((o) {
        if (o.id == orderId || o.orderNumber == orderId) {
          return OrderModel.fromEntity(o).copyWith(
            paymentStatus: paymentStatus,
            remittanceStatus: remittanceStatus,
            financialSettlementStatus: remittanceStatus == 'remitted' ? 'cash_remitted_verified' : o.financialSettlementStatus,
            remittedAt: remittanceStatus == 'remitted' ? DateTime.now() : o.remittedAt,
          );
        }
        return o;
      }).toList();
      final sortedList = _sortOrdersByOperationalPriority(updatedList);
      state = state.copyWith(orders: sortedList);
      await _storageService.cacheOrders(sortedList, _getScopeKey());
    } catch (_) {}
  }

  void updateOrderInList(OrderEntity updatedOrder) {
    final updatedList = state.orders.map((o) {
      if (o.id == updatedOrder.id || o.orderNumber == updatedOrder.orderNumber) {
        return updatedOrder;
      }
      return o;
    }).toList();
    final sortedList = _sortOrdersByOperationalPriority(updatedList);
    state = state.copyWith(orders: sortedList);
    _storageService.cacheOrders(sortedList, _getScopeKey());
  }

  Future<Map<String, dynamic>> confirmDeliveryPod({
    required String orderId,
    required String agentId,
    required String paymentType,
    required String paymentMethod,
    required double amountCollected,
    String? customerSignatureUrl,
    String? photoProofUrl,
    String? gatePassCode,
    double? latitude,
    double? longitude,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final isDirectTransfer = paymentMethod == 'bank_transfer' ||
          paymentType == 'prepaid' ||
          (notes != null && (notes.contains('Monnify') || notes.contains('Direct Transfer')));
      final resolvedPaymentType = isDirectTransfer ? 'prepaid' : paymentType;
      final resolvedPaymentStatus = isDirectTransfer ? 'paid' : 'collected';

      final result = await _repository.confirmDeliveryPod(
        orderId: orderId,
        agentId: agentId,
        paymentType: resolvedPaymentType,
        paymentMethod: paymentMethod,
        amountCollected: amountCollected,
        customerSignatureUrl: customerSignatureUrl,
        photoProofUrl: photoProofUrl,
        gatePassCode: gatePassCode,
        latitude: latitude,
        longitude: longitude,
        notes: notes,
      );

      if (_ref != null) {
        final deliveredOrder = state.orders.firstWhere(
          (o) => o.id == orderId || o.orderNumber == orderId,
          orElse: () => OrderModel.empty(),
        );
        if (deliveredOrder.id.isNotEmpty) {
          _ref.read(stockProvider.notifier).recordOrderDelivered(
            riderId: deliveredOrder.deliveryAgentId ?? agentId,
            riderCode: deliveredOrder.deliveryAgentCode ?? '',
            productName: deliveredOrder.productName,
            quantity: deliveredOrder.quantity,
          );

          if (isDirectTransfer) {
            final user = _ref.read(authProvider).user;
            final commission = (user?.commissionRate != null && user!.commissionRate > 0)
                ? user.commissionRate
                : ((user?.isInHouseRider == true || user?.isPda == false) ? 700.0 : 1000.0);
            final transport = (user?.isInHouseRider == true || user?.isPda == false)
                ? ((user?.fuelAllowance != null && user!.fuelAllowance > 0) ? user.fuelAllowance : 800.0)
                : ((user?.transportAllowance != null && user!.transportAllowance > 0) ? user.transportAllowance : 1500.0);
            final totalEarning = deliveredOrder.agentEntitlement > 0
                ? deliveredOrder.agentEntitlement
                : (commission + transport);

            _ref.read(financeProvider.notifier).recordDirectTransferEarning(
              agentId: agentId,
              orderNumber: deliveredOrder.orderNumber.isNotEmpty ? deliveredOrder.orderNumber : orderId,
              amount: totalEarning,
              commission: commission,
              transport: transport,
            );
          }
        }
      }

      final updatedList = state.orders.map((o) {
        if (o.id == orderId || o.orderNumber == orderId) {
          final isCleared = isDirectTransfer;
          return o.copyWith(
            status: 'delivered',
            paymentType: resolvedPaymentType,
            paymentStatus: resolvedPaymentStatus,
            remittanceStatus: isCleared ? 'direct_transfer' : 'unremitted',
            financialSettlementStatus: isCleared ? 'direct_transfer_settled' : 'pending_remittance',
            deliveryNotes: notes ?? o.deliveryNotes,
            deliveredAt: DateTime.now(),
            customerSignatureUrl: customerSignatureUrl ?? o.customerSignatureUrl,
            photoProofUrl: photoProofUrl ?? o.photoProofUrl,
            gatePassCode: gatePassCode ?? o.gatePassCode,
            latitude: latitude ?? o.latitude,
            longitude: longitude ?? o.longitude,
            isLocationVerified: true,
            geocodingStatus: 'exact_verified',
          );
        }
        return o;
      }).toList();

      final sortedList = _sortOrdersByOperationalPriority(updatedList);
      state = state.copyWith(isLoading: false, orders: sortedList);
      await _storageService.cacheOrders(sortedList, _getScopeKey());
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return {'status': 'error', 'error': e.toString()};
    }
  }

  Future<void> markOrdersAsRemitted({
    required List<String> orderIds,
    required String remittanceId,
    required String status,
  }) async {
    final idSet = orderIds.toSet();
    final updatedList = state.orders.map((o) {
      if (idSet.contains(o.id) || idSet.contains(o.orderNumber)) {
        return o.copyWith(
          remittanceStatus: status,
          financialSettlementStatus: status == 'remitted' ? 'cash_remitted_verified' : 'pending_remittance',
          remittedAt: status == 'remitted' ? DateTime.now() : o.remittedAt,
          remittanceReference: remittanceId,
        );
      }
      return o;
    }).toList();
    final sortedList = _sortOrdersByOperationalPriority(updatedList);
    state = state.copyWith(orders: sortedList);
    await _storageService.cacheOrders(sortedList, _getScopeKey());
  }

  Future<Map<String, dynamic>> logDeliveryFailure({
    required String orderId,
    required String agentId,
    required String reasonCode,
    String? notes,
    String? scheduledCallbackAt,
    String? gatePassCode,
    double? latitude,
    double? longitude,
  }) async {
    state = state.copyWith(isLoading: true);
    final isCallback = reasonCode == 'rescheduled' || scheduledCallbackAt != null;
    final newStatus = isCallback ? 'call_back' : 'failed';
    try {
      final result = await _repository.logDeliveryFailure(
        orderId: orderId,
        agentId: agentId,
        reasonCode: reasonCode,
        notes: notes,
        scheduledCallbackAt: scheduledCallbackAt,
        gatePassCode: gatePassCode,
        latitude: latitude,
        longitude: longitude,
      );

      if (_ref != null) {
        final failedOrder = state.orders.firstWhere(
          (o) => o.id == orderId || o.orderNumber == orderId,
          orElse: () => OrderModel.empty(),
        );
        if (failedOrder.id.isNotEmpty) {
          _ref.read(stockProvider.notifier).recordOrderReturned(
            riderId: failedOrder.deliveryAgentId ?? agentId,
            riderCode: failedOrder.deliveryAgentCode ?? '',
            productName: failedOrder.productName,
            quantity: failedOrder.quantity,
          );
        }
      }

      final updatedList = state.orders.map((o) {
        if (o.id == orderId || o.orderNumber == orderId) {
          return o.copyWith(
            status: newStatus,
            deliveryNotes: notes ?? o.deliveryNotes,
            failureReason: notes ?? o.failureReason ?? 'Delivery failure reported by PDA',
            gatePassCode: gatePassCode ?? o.gatePassCode,
            latitude: latitude ?? o.latitude,
            longitude: longitude ?? o.longitude,
            isLocationVerified: true,
            geocodingStatus: 'exact_verified',
          );
        }
        return o;
      }).toList();

      state = state.copyWith(isLoading: false, orders: updatedList);
      _storageService.cacheOrders(updatedList);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return {'status': 'error', 'error': e.toString()};
    }
  }

  Future<void> updateOrderCoordinates({
    required String orderId,
    required double latitude,
    required double longitude,
    bool isLocationVerified = true,
    String? geocodedAddress,
  }) async {
    try {
      await _repository.updateOrderCoordinates(
        orderId: orderId,
        latitude: latitude,
        longitude: longitude,
        isLocationVerified: isLocationVerified,
        geocodedAddress: geocodedAddress,
      );

      final updatedList = state.orders.map((o) {
        if (o.id == orderId || o.orderNumber == orderId) {
          return o.copyWith(
            latitude: latitude,
            longitude: longitude,
            isLocationVerified: isLocationVerified,
            geocodedAddress: geocodedAddress ?? o.geocodedAddress,
            locationConfidence: isLocationVerified ? 'high' : 'medium',
            geocodingStatus: isLocationVerified ? 'exact_verified' : 'rooftop',
          );
        }
        return o;
      }).toList();

      state = state.copyWith(orders: updatedList);
    } catch (e) {
      // Ignored
    }
  }

  Future<void> updateOrderRemittance({
    required String orderId,
    required String remittanceStatus,
    String? remittanceReference,
  }) async {
    final updatedList = state.orders.map((o) {
      if (o.id == orderId || o.orderNumber == orderId) {
        final fStatus = remittanceStatus == 'cleared'
            ? 'cash_remitted_verified'
            : (o.isDirectTransfer ? 'direct_transfer_settled' : 'pending_remittance');
        return o.copyWith(
          remittanceStatus: remittanceStatus,
          financialSettlementStatus: fStatus,
          remittanceReference: remittanceReference ?? o.remittanceReference,
          remittedAt: remittanceStatus == 'cleared' ? DateTime.now() : o.remittedAt,
        );
      }
      return o;
    }).toList();

    state = state.copyWith(orders: updatedList);
    await _storageService.cacheOrders(updatedList, _getScopeKey());
  }

  /// Geocodes an order address and updates state
  Future<void> geocodeOrder(String orderId, {bool autoDispatch = false}) async {
    final order = state.orders.firstWhere((o) => o.id == orderId, orElse: () => throw Exception('Order not found'));
    final service = _geocodingService ?? GeocodingService(Supabase.instance.client);

    final result = await service.resolveAddress(
      address: order.deliveryAddress,
      city: order.deliveryCity,
      state: order.deliveryState,
      orderId: orderId,
      autoDispatch: autoDispatch,
    );

    await updateOrderCoordinates(
      orderId: orderId,
      latitude: result.latitude,
      longitude: result.longitude,
      isLocationVerified: result.geocodingStatus == 'exact_verified',
      geocodedAddress: result.geocodedAddress,
    );
  }

  /// Automatically assigns order to closest rider
  Future<Map<String, dynamic>> autoDispatchToNearestRider(String orderId, {double maxDistanceKm = 25.0}) async {
    final service = _geocodingService ?? GeocodingService(Supabase.instance.client);
    final result = await service.autoDispatchOrder(orderId, maxDistanceKm: maxDistanceKm);

    if (result['success'] == true && result['riderId'] != null) {
      final updatedList = state.orders.map((o) {
        if (o.id == orderId) {
          return OrderEntity(
            id: o.id,
            orderNumber: o.orderNumber,
            customerName: o.customerName,
            customerPhone: o.customerPhone,
            customerAltPhone: o.customerAltPhone,
            deliveryAddress: o.deliveryAddress,
            deliveryCity: o.deliveryCity,
            deliveryState: o.deliveryState,
            landmark: o.landmark,
            lga: o.lga,
            productName: o.productName,
            status: 'assigned',
            quantity: o.quantity,
            paidQuantity: o.paidQuantity,
            freeQuantity: o.freeQuantity,
            basePrice: o.basePrice,
            upsellAmount: o.upsellAmount,
            totalAmount: o.totalAmount,
            paymentType: o.paymentType,
            paymentStatus: o.paymentStatus,
            fulfillmentType: o.fulfillmentType,
            clientName: o.clientName,
            packageCustodyId: o.packageCustodyId,
            clientDeliveryFee: o.clientDeliveryFee,
            agentEntitlement: o.agentEntitlement,
            deliveryNotes: o.deliveryNotes,
            createdAt: o.createdAt,
            deliveryAgentId: result['riderId']?.toString(),
            deliveryAgentName: result['riderName']?.toString() ?? o.deliveryAgentName,
            deliveryAgentCode: result['riderCode']?.toString() ?? o.deliveryAgentCode,
            distributionCenterId: o.distributionCenterId,
            latitude: o.latitude,
            longitude: o.longitude,
            isLocationVerified: o.isLocationVerified,
            geocodedAddress: o.geocodedAddress,
            locationConfidence: o.locationConfidence,
            geocodingStatus: o.geocodingStatus,
          );
        }
        return o;
      }).toList();
      state = state.copyWith(orders: updatedList);
    }
    return result;
  }

  /// Sends live GPS heartbeat for the current delivery agent
  Future<void> sendRiderTelemetry({
    required String agentId,
    required double latitude,
    required double longitude,
  }) async {
    final service = _geocodingService ?? GeocodingService(Supabase.instance.client);
    await service.sendRiderTelemetry(
      agentId: agentId,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Records a verified physical gate pin for an order
  Future<Map<String, dynamic>> recordVerifiedGatePin({
    required String orderId,
    required double latitude,
    required double longitude,
    String? pinLabel,
  }) async {
    final service = _geocodingService ?? GeocodingService(Supabase.instance.client);
    final result = await service.recordVerifiedGatePin(
      orderId: orderId,
      latitude: latitude,
      longitude: longitude,
      pinLabel: pinLabel,
    );

    if (result['success'] == true) {
      final updatedList = state.orders.map((o) {
        if (o.id == orderId || o.orderNumber == orderId) {
          return OrderEntity(
            id: o.id,
            orderNumber: o.orderNumber,
            customerName: o.customerName,
            customerPhone: o.customerPhone,
            customerAltPhone: o.customerAltPhone,
            deliveryAddress: o.deliveryAddress,
            deliveryCity: o.deliveryCity,
            deliveryState: o.deliveryState,
            landmark: o.landmark,
            lga: o.lga,
            productName: o.productName,
            status: o.status,
            quantity: o.quantity,
            paidQuantity: o.paidQuantity,
            freeQuantity: o.freeQuantity,
            basePrice: o.basePrice,
            upsellAmount: o.upsellAmount,
            totalAmount: o.totalAmount,
            paymentType: o.paymentType,
            paymentStatus: o.paymentStatus,
            fulfillmentType: o.fulfillmentType,
            clientName: o.clientName,
            packageCustodyId: o.packageCustodyId,
            clientDeliveryFee: o.clientDeliveryFee,
            agentEntitlement: o.agentEntitlement,
            deliveryNotes: o.deliveryNotes,
            createdAt: o.createdAt,
            deliveryAgentId: o.deliveryAgentId,
            deliveryAgentName: o.deliveryAgentName,
            deliveryAgentCode: o.deliveryAgentCode,
            distributionCenterId: o.distributionCenterId,
            latitude: latitude,
            longitude: longitude,
            isLocationVerified: true,
            geocodedAddress: o.geocodedAddress ?? '${o.deliveryAddress} (Gate Pin Verified)',
            locationConfidence: 'high',
            geocodingStatus: 'exact_verified',
          );
        }
        return o;
      }).toList();
      state = state.copyWith(orders: updatedList);
    }
    return result;
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

final ordersProvider = StateNotifierProvider<OrdersNotifier, OrdersState>((ref) {
  // Re-bind whenever authenticated agent changes
  ref.watch(authProvider.select((s) => s.user?.deliveryAgentId ?? s.user?.id));
  final repository = ref.watch(ordersRepositoryProvider);
  final geocoding = ref.watch(geocodingServiceProvider);
  final storage = ref.watch(localStorageServiceProvider);

  return OrdersNotifier(
    repository,
    geocoding,
    storage,
    ref,
  );
});
