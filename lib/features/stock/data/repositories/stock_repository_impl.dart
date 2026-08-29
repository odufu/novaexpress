import '../../domain/entities/rider_stock_allocation.dart';
import '../../domain/entities/stock_item.dart';
import '../../domain/repositories/stock_repository.dart';
import '../datasources/stock_remote_datasource.dart';

class StockRepositoryImpl implements StockRepository {
  final StockRemoteDataSource remoteDataSource;

  StockRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<StockItemEntity>> getVehicleStockItems([String? agentId]) async {
    return await remoteDataSource.getVehicleStockItems(agentId);
  }

  @override
  Future<StockItemEntity> createProduct({
    required String name,
    required String sku,
    required String category,
    required double price,
    String? description,
    String? ownerName,
    int stockQuantity = 0,
    int lowStockThreshold = 3,
    String? binLocation,
    String? companyId,
    String? imageAsset,
  }) async {
    return await remoteDataSource.createProduct(
      name: name,
      sku: sku,
      category: category,
      price: price,
      description: description,
      ownerName: ownerName,
      stockQuantity: stockQuantity,
      lowStockThreshold: lowStockThreshold,
      binLocation: binLocation,
      companyId: companyId,
      imageAsset: imageAsset,
    );
  }

  @override
  Future<Map<String, dynamic>> assignStockToRider({
    required String productIdOrSku,
    required String riderId,
    required String riderName,
    required String riderCode,
    required int quantity,
    String? distributionCenterId,
  }) async {
    return await remoteDataSource.assignStockToRider(
      productIdOrSku: productIdOrSku,
      riderId: riderId,
      riderName: riderName,
      riderCode: riderCode,
      quantity: quantity,
      distributionCenterId: distributionCenterId,
    );
  }

  @override
  Future<bool> receiveStock({
    required String productIdOrSku,
    required int quantity,
    String? waybillNumber,
    String? supplierName,
  }) async {
    return await remoteDataSource.receiveStock(
      productIdOrSku: productIdOrSku,
      quantity: quantity,
      waybillNumber: waybillNumber,
      supplierName: supplierName,
    );
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
  Future<List<RiderStockAllocation>> getRiderStockAllocations([String? riderId]) async {
    return await remoteDataSource.getRiderStockAllocations(riderId);
  }

  @override
  Future<void> updateRiderStockCustody({
    required String riderId,
    required String productId,
    int deliveredDelta = 0,
    int returnedDelta = 0,
    int inCustodyDelta = 0,
  }) async {
    return await remoteDataSource.updateRiderStockCustody(
      riderId: riderId,
      productId: productId,
      deliveredDelta: deliveredDelta,
      returnedDelta: returnedDelta,
      inCustodyDelta: inCustodyDelta,
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
