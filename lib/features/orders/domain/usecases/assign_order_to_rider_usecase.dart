import '../repositories/orders_repository.dart';

class AssignOrderToRiderUseCase {
  final OrdersRepository repository;

  AssignOrderToRiderUseCase(this.repository);

  Future<void> call({
    required String orderId,
    required String riderId,
    required String riderName,
    required String riderCode,
  }) {
    return repository.assignOrderToRider(
      orderId: orderId,
      riderId: riderId,
      riderName: riderName,
      riderCode: riderCode,
    );
  }
}
