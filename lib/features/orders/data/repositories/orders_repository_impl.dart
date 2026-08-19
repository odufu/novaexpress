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

  @override
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
    return await remoteDataSource.confirmDeliveryPod(
      orderId: orderId,
      agentId: agentId,
      paymentType: paymentType,
      paymentMethod: paymentMethod,
      amountCollected: amountCollected,
      customerSignatureUrl: customerSignatureUrl,
      photoProofUrl: photoProofUrl,
      notes: notes,
    );
  }

  @override
  Future<Map<String, dynamic>> logDeliveryFailure({
    required String orderId,
    required String agentId,
    required String reasonCode,
    String? notes,
    String? scheduledCallbackAt,
  }) async {
    return await remoteDataSource.logDeliveryFailure(
      orderId: orderId,
      agentId: agentId,
      reasonCode: reasonCode,
      notes: notes,
      scheduledCallbackAt: scheduledCallbackAt,
    );
  }
}
