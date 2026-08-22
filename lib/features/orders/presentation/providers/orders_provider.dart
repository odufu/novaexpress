import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/orders_remote_datasource.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/orders_repository_impl.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/orders_repository.dart';

final ordersRemoteDataSourceProvider = Provider<OrdersRemoteDataSource>((ref) {
  return OrdersRemoteDataSourceImpl(Supabase.instance.client);
});

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepositoryImpl(ref.watch(ordersRemoteDataSourceProvider));
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

  OrdersNotifier(this._repository) : super(OrdersState()) {
    loadOrders();
  }

  Future<void> fetchOrders() async {
    await loadOrders();
  }

  Future<void> loadOrders([String? agentId]) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      if (agentId != null && agentId.isNotEmpty) {
        final orderEntities = await _repository.getAssignedOrders(agentId);
        state = state.copyWith(isLoading: false, orders: orderEntities);
      } else {
        final orderEntities = await _repository.getDistributionCenterOrders('22222222-2222-4222-8222-222222222222');
        state = state.copyWith(isLoading: false, orders: orderEntities);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load manifest orders: $e',
      );
    }
  }

  Future<void> loadDcOrders([String? dcId]) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final orderEntities = await _repository.getDistributionCenterOrders(dcId ?? '22222222-2222-4222-8222-222222222222');
      state = state.copyWith(isLoading: false, orders: orderEntities);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to load DC orders: $e');
    }
  }

  Future<bool> createOrder(Map<String, dynamic> orderData) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final created = await _repository.createOrder(orderData);
      state = state.copyWith(
        isLoading: false,
        orders: [created, ...state.orders.where((o) => o.id != created.id && o.orderNumber != created.orderNumber)],
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to create order: $e');
      return false;
    }
  }

  Future<bool> assignOrderToRider({
    required String orderId,
    required String riderId,
    required String riderName,
    required String riderCode,
  }) async {
    try {
      await _repository.assignOrderToRider(
        orderId: orderId,
        riderId: riderId,
        riderName: riderName,
        riderCode: riderCode,
      );

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
            deliveryAgentId: riderId,
            deliveryAgentName: riderName,
            deliveryAgentCode: riderCode,
            distributionCenterId: o.distributionCenterId ?? '22222222-2222-4222-8222-222222222222',
          );
        }
        return o;
      }).toList();

      state = state.copyWith(orders: updatedList);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> updateOrderStatus(
    String orderId,
    String newStatus, {
    String? paymentStatus,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.updateOrderStatus(
        orderId,
        newStatus,
        paymentStatus: paymentStatus,
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
            paymentType: o.paymentType,
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
      state = state.copyWith(isLoading: false, orders: updatedList);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<Map<String, dynamic>> confirmDeliveryPod({
    required String orderId,
    required String agentId,
    required String paymentType,
    required String paymentMethod,
    required double amountCollected,
    String? customerSignatureUrl,
    String? photoProofUrl,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _repository.confirmDeliveryPod(
        orderId: orderId,
        agentId: agentId,
        paymentType: paymentType,
        paymentMethod: paymentMethod,
        amountCollected: amountCollected,
        customerSignatureUrl: customerSignatureUrl,
        photoProofUrl: photoProofUrl,
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
            status: 'delivered',
            quantity: o.quantity,
            paidQuantity: o.paidQuantity,
            freeQuantity: o.freeQuantity,
            basePrice: o.basePrice,
            upsellAmount: o.upsellAmount,
            totalAmount: o.totalAmount,
            paymentType: paymentType,
            paymentStatus: 'paid',
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

      state = state.copyWith(isLoading: false, orders: updatedList);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return {'status': 'error', 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> logDeliveryFailure({
    required String orderId,
    required String agentId,
    required String reasonCode,
    String? notes,
    String? scheduledCallbackAt,
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
            paymentType: o.paymentType,
            paymentStatus: o.paymentStatus,
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

      state = state.copyWith(isLoading: false, orders: updatedList);
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
}

final ordersProvider = StateNotifierProvider<OrdersNotifier, OrdersState>((ref) {
  return OrdersNotifier(ref.watch(ordersRepositoryProvider));
});
