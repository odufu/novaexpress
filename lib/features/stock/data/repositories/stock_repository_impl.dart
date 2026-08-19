import '../../domain/entities/stock_item.dart';
import '../../domain/repositories/stock_repository.dart';
import '../datasources/stock_remote_datasource.dart';

class StockRepositoryImpl implements StockRepository {
  final StockRemoteDataSource remoteDataSource;

  StockRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<StockItemEntity>> getVehicleStockItems() async {
    return await remoteDataSource.getVehicleStockItems();
  }

  @override
  Future<Map<String, dynamic>> requestStockTransfer({
    required String agentId,
    required String companyId,
    required String sourceWarehouseId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    return await remoteDataSource.requestStockTransfer(
      agentId: agentId,
      companyId: companyId,
      sourceWarehouseId: sourceWarehouseId,
      items: items,
      notes: notes,
    );
  }

  @override
  Future<Map<String, dynamic>> confirmStockHandover({
    required String requestId,
    required String handoverCode,
    required String agentId,
  }) async {
    return await remoteDataSource.confirmStockHandover(
      requestId: requestId,
      handoverCode: handoverCode,
      agentId: agentId,
    );
  }

  @override
  Future<Map<String, dynamic>> processStockReturn({
    required String returnNumber,
    required String orderId,
    required String deliveryAgentId,
    required String productId,
    required int quantity,
    required String reason,
    String? notes,
  }) async {
    return await remoteDataSource.processStockReturn(
      returnNumber: returnNumber,
      orderId: orderId,
      deliveryAgentId: deliveryAgentId,
      productId: productId,
      quantity: quantity,
      reason: reason,
      notes: notes,
    );
  }

  @override
  Future<Map<String, dynamic>> submitInventoryAudit({
    required String distributionCenterId,
    required String auditedBy,
    required int totalPhysicalCounted,
    required int totalSystemExpected,
    required int discrepancyCount,
    String? notes,
  }) async {
    return await remoteDataSource.submitInventoryAudit(
      distributionCenterId: distributionCenterId,
      auditedBy: auditedBy,
      totalPhysicalCounted: totalPhysicalCounted,
      totalSystemExpected: totalSystemExpected,
      discrepancyCount: discrepancyCount,
      notes: notes,
    );
  }
}
