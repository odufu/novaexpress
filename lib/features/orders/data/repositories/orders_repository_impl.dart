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
  Future<List<OrderEntity>> getDistributionCenterOrders(String distributionCenterId) async {
    return await remoteDataSource.getDistributionCenterOrders(distributionCenterId);
  }

  @override
  Future<OrderEntity> createOrder(Map<String, dynamic> orderData) async {
    return await remoteDataSource.createOrder(orderData);
  }

  @override
  Future<void> assignOrderToRider({
    required String orderId,
    required String riderId,
    required String riderName,
    required String riderCode,
  }) async {
    await remoteDataSource.assignOrderToRider(
      orderId: orderId,
      riderId: riderId,
      riderName: riderName,
      riderCode: riderCode,
    );
  }

  @override
  Future<OrderEntity> getOrderById(String orderId) async {
    return await remoteDataSource.getOrderById(orderId);
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status, {String? paymentStatus, String? paymentType, String? notes}) async {
    await remoteDataSource.updateOrderStatus(orderId, status, paymentStatus: paymentStatus, paymentType: paymentType, notes: notes);
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

  @override
  Future<void> updateOrderCoordinates({
    required String orderId,
    required double latitude,
    required double longitude,
    bool isLocationVerified = true,
    String? geocodedAddress,
  }) async {
    await remoteDataSource.updateOrderCoordinates(
      orderId: orderId,
      latitude: latitude,
      longitude: longitude,
      isLocationVerified: isLocationVerified,
      geocodedAddress: geocodedAddress,
    );
  }
}
