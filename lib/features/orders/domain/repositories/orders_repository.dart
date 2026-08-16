import '../entities/order.dart';

abstract class OrdersRepository {
  Future<List<OrderEntity>> getAssignedOrders(String deliveryAgentId);
  Future<OrderEntity> getOrderById(String orderId);
  Future<void> updateOrderStatus(String orderId, String status, {String? paymentStatus, String? notes});
}
