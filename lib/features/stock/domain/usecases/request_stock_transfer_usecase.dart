import '../repositories/stock_repository.dart';

class RequestStockTransferUseCase {
  final StockRepository repository;

  RequestStockTransferUseCase(this.repository);

  Future<Map<String, dynamic>> call({
    required String agentId,
    required String companyId,
    required String sourceWarehouseId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) {
    return repository.requestStockTransfer(
      agentId: agentId,
      companyId: companyId,
      sourceWarehouseId: sourceWarehouseId,
      items: items,
      notes: notes,
    );
  }
}
