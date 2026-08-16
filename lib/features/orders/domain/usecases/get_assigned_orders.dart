import '../entities/order.dart';
import '../repositories/orders_repository.dart';

class GetAssignedOrdersUseCase {
  final OrdersRepository repository;
  GetAssignedOrdersUseCase(this.repository);

  Future<List<OrderEntity>> execute(String deliveryAgentId) async {
    return await repository.getAssignedOrders(deliveryAgentId);
  }
}
