import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../data/datasources/orders_remote_datasource.dart';
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

  Future<void> loadOrders() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final orderEntities = await _repository.getAssignedOrders(
        SupabaseConstants.defaultDeliveryAgentId,
      );
      state = state.copyWith(isLoading: false, orders: orderEntities);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load manifest orders: $e',
      );
    }
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.updateOrderStatus(orderId, newStatus);
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
            status: newStatus,
            quantity: o.quantity,
            basePrice: o.basePrice,
            upsellAmount: o.upsellAmount,
            totalAmount: o.totalAmount,
            paymentType: o.paymentType,
            paymentStatus: newStatus == 'delivered' ? 'collected' : o.paymentStatus,
            deliveryNotes: o.deliveryNotes,
            createdAt: o.createdAt,
          );
        }
        return o;
      }).toList();
      state = state.copyWith(isLoading: false, orders: updatedList);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }
}

final ordersProvider = StateNotifierProvider<OrdersNotifier, OrdersState>((ref) {
  return OrdersNotifier(ref.watch(ordersRepositoryProvider));
});
