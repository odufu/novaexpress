import '../repositories/orders_repository.dart';

class LogDeliveryFailureUseCase {
  final OrdersRepository repository;

  LogDeliveryFailureUseCase(this.repository);

  Future<Map<String, dynamic>> call({
    required String orderId,
    required String agentId,
    required String reasonCode,
    String? notes,
    String? scheduledCallbackAt,
  }) {
    return repository.logDeliveryFailure(
      orderId: orderId,
      agentId: agentId,
      reasonCode: reasonCode,
      notes: notes,
      scheduledCallbackAt: scheduledCallbackAt,
    );
  }
}
