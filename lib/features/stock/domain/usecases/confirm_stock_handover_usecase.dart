import '../repositories/stock_repository.dart';

class ConfirmStockHandoverUseCase {
  final StockRepository repository;

  ConfirmStockHandoverUseCase(this.repository);

  Future<Map<String, dynamic>> call({
    required String requestId,
    required String handoverCode,
    required String agentId,
  }) {
    return repository.confirmStockHandover(
      requestId: requestId,
      handoverCode: handoverCode,
      agentId: agentId,
    );
  }
}
