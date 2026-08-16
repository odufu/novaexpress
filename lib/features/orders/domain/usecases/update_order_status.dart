import '../repositories/orders_repository.dart';

class UpdateOrderStatusUseCase {
  final OrdersRepository repository;
  UpdateOrderStatusUseCase(this.repository);

  Future<void> execute(String orderId, String status, {String? paymentStatus, String? notes}) async {
    await repository.updateOrderStatus(orderId, status, paymentStatus: paymentStatus, notes: notes);
  }
}
