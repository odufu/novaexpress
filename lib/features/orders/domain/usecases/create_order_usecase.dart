import '../entities/order.dart';
import '../repositories/orders_repository.dart';

class CreateOrderUseCase {
  final OrdersRepository repository;

  CreateOrderUseCase(this.repository);

  Future<OrderEntity> call(Map<String, dynamic> orderData) {
    return repository.createOrder(orderData);
  }
}
