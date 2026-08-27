import '../entities/stock_item.dart';
import '../repositories/stock_repository.dart';

class GetVehicleStockItemsUseCase {
  final StockRepository repository;

  GetVehicleStockItemsUseCase(this.repository);

  Future<List<StockItemEntity>> call([String? agentId]) {
    return repository.getVehicleStockItems(agentId);
  }
}
