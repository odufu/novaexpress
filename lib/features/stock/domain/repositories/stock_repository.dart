import '../entities/stock_item.dart';

abstract class StockRepository {
  Future<List<StockItemEntity>> getVehicleStockItems();
}
