import '../repositories/stock_repository.dart';

class ProcessStockReturnUseCase {
  final StockRepository repository;

  ProcessStockReturnUseCase(this.repository);

  Future<Map<String, dynamic>> call({
    required String returnNumber,
    required String orderId,
    required String deliveryAgentId,
    required String productId,
    required int quantity,
    required String reason,
    String? notes,
  }) {
    return repository.processStockReturn(
      returnNumber: returnNumber,
      orderId: orderId,
      deliveryAgentId: deliveryAgentId,
      productId: productId,
      quantity: quantity,
      reason: reason,
      notes: notes,
    );
  }
}
