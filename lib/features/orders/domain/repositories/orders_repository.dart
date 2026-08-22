import '../entities/order.dart';

abstract class OrdersRepository {
  Future<List<OrderEntity>> getAssignedOrders(String deliveryAgentId);
  Future<List<OrderEntity>> getDistributionCenterOrders(String distributionCenterId);
  Future<OrderEntity> createOrder(Map<String, dynamic> orderData);
  Future<void> assignOrderToRider({
    required String orderId,
    required String riderId,
    required String riderName,
    required String riderCode,
  });
  Future<OrderEntity> getOrderById(String orderId);
  Future<void> updateOrderStatus(String orderId, String status, {String? paymentStatus, String? notes});
  Future<Map<String, dynamic>> confirmDeliveryPod({
    required String orderId,
    required String agentId,
    required String paymentType,
    required String paymentMethod,
    required double amountCollected,
    String? customerSignatureUrl,
    String? photoProofUrl,
    String? notes,
  });
  Future<Map<String, dynamic>> logDeliveryFailure({
    required String orderId,
    required String agentId,
    required String reasonCode,
    String? notes,
    String? scheduledCallbackAt,
  });
  Future<void> updateOrderCoordinates({
    required String orderId,
    required double latitude,
    required double longitude,
    bool isLocationVerified = true,
    String? geocodedAddress,
  });
}
