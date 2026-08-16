import '../../domain/entities/order.dart';
import '../../domain/repositories/orders_repository.dart';
import '../datasources/orders_remote_datasource.dart';

class OrdersRepositoryImpl implements OrdersRepository {
  final OrdersRemoteDataSource remoteDataSource;

  OrdersRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<OrderEntity>> getAssignedOrders(String deliveryAgentId) async {
    return await remoteDataSource.getAssignedOrders(deliveryAgentId);
  }

  @override
  Future<OrderEntity> getOrderById(String orderId) async {
    return await remoteDataSource.getOrderById(orderId);
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status, {String? paymentStatus, String? notes}) async {
    await remoteDataSource.updateOrderStatus(orderId, status, paymentStatus: paymentStatus, notes: notes);
  }
}
