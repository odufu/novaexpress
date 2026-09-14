import '../../domain/entities/rider_stock_allocation.dart';
import '../../domain/entities/stock_item.dart';
import '../../domain/entities/stock_transfer_record.dart';
import '../../domain/repositories/stock_repository.dart';
import '../datasources/stock_remote_datasource.dart';

class StockRepositoryImpl implements StockRepository {
  final StockRemoteDataSource remoteDataSource;

  StockRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<StockItemEntity>> getVehicleStockItems([String? agentId, String? dcId]) async {
    return await remoteDataSource.getVehicleStockItems(agentId, dcId);
  }

  @override
  Future<StockItemEntity> createProduct({
    required String name,
    required String sku,
    required String category,
    required double price,
    double? costPrice,
    String? barcode,
    double? weightKg,
    String? description,
    String? ownerName,
    int stockQuantity = 0,
    int lowStockThreshold = 3,
    String? binLocation,
    String? companyId,
    String? clientId,
    String? imageAsset,
    String? originDcId,
    List<String>? coveringStates,
    Map<String, int>? dcStocks,
  }) async {
    return await remoteDataSource.createProduct(
      name: name,
      sku: sku,
      category: category,
      price: price,
      costPrice: costPrice,
      barcode: barcode,
      weightKg: weightKg,
      description: description,
      ownerName: ownerName,
      stockQuantity: stockQuantity,
      lowStockThreshold: lowStockThreshold,
      binLocation: binLocation,
      companyId: companyId,
      clientId: clientId,
      imageAsset: imageAsset,
      originDcId: originDcId,
      coveringStates: coveringStates,
      dcStocks: dcStocks,
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
    String? distributionCenterId,
  }) async {
    return await remoteDataSource.receiveStock(
      productIdOrSku: productIdOrSku,
      quantity: quantity,
      waybillNumber: waybillNumber,
      supplierName: supplierName,
      distributionCenterId: distributionCenterId,
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
  Future<Map<String, dynamic>> transferStockBetweenDCs({
    required String productIdOrSku,
    required String sourceDcId,
    required String sourceDcName,
    required String destinationDcId,
    required String destinationDcName,
    required int quantity,
    String? senderId,
    String? senderName,
    String? notes,
  }) async {
    return await remoteDataSource.transferStockBetweenDCs(
      productIdOrSku: productIdOrSku,
      sourceDcId: sourceDcId,
      sourceDcName: sourceDcName,
      destinationDcId: destinationDcId,
      destinationDcName: destinationDcName,
      quantity: quantity,
      senderId: senderId,
      senderName: senderName,
      notes: notes,
    );
  }

  @override
  Future<Map<String, dynamic>> receiveInterDcTransfer({
    required String transferId,
    String? receiverId,
    String? receiverName,
    int? quantityReceived,
    String? notes,
  }) async {
    return await remoteDataSource.receiveInterDcTransfer(
      transferId: transferId,
      receiverId: receiverId,
      receiverName: receiverName,
      quantityReceived: quantityReceived,
      notes: notes,
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
    String? destinationDcId,
    String? condition,
    String? notes,
  }) async {
    return await remoteDataSource.processStockReturn(
      returnNumber: returnNumber,
      orderId: orderId,
      deliveryAgentId: deliveryAgentId,
      productId: productId,
      quantity: quantity,
      reason: reason,
      destinationDcId: destinationDcId,
      condition: condition,
      notes: notes,
    );
  }

  @override
  Future<List<RiderStockAllocation>> getRiderStockAllocations([String? riderId, String? dcId]) async {
    return await remoteDataSource.getRiderStockAllocations(riderId, dcId);
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

  @override
  Future<Map<String, dynamic>> dispatchClientSupply({
    required String clientId,
    required String dcId,
    required List<Map<String, dynamic>> items,
    String? senderId,
    required String senderName,
    String senderSignatureUrl = '',
    String? notes,
  }) async {
    return await remoteDataSource.dispatchClientSupply(
      clientId: clientId,
      dcId: dcId,
      items: items,
      senderId: senderId,
      senderName: senderName,
      senderSignatureUrl: senderSignatureUrl,
      notes: notes,
    );
  }

  @override
  Future<Map<String, dynamic>> receiveClientSupply({
    required String transferId,
    required String receiverId,
    required String receiverName,
    String receiverSignatureUrl = '',
    required List<Map<String, dynamic>> verifiedItems,
    String? notes,
  }) async {
    return await remoteDataSource.receiveClientSupply(
      transferId: transferId,
      receiverId: receiverId,
      receiverName: receiverName,
      receiverSignatureUrl: receiverSignatureUrl,
      verifiedItems: verifiedItems,
      notes: notes,
    );
  }

  @override
  Future<Map<String, dynamic>> issueDcStockToRiderWithSignature({
    required String dcId,
    required String riderId,
    required List<Map<String, dynamic>> items,
    required String senderId,
    required String senderName,
    String senderSignatureUrl = '',
    String? notes,
  }) async {
    return await remoteDataSource.issueDcStockToRiderWithSignature(
      dcId: dcId,
      riderId: riderId,
      items: items,
      senderId: senderId,
      senderName: senderName,
      senderSignatureUrl: senderSignatureUrl,
      notes: notes,
    );
  }

  @override
  Future<Map<String, dynamic>> acceptRiderStockHandover({
    required String transferId,
    required String riderId,
    required String riderName,
    String riderSignatureUrl = '',
    List<Map<String, dynamic>>? verifiedItems,
    String? notes,
  }) async {
    return await remoteDataSource.acceptRiderStockHandover(
      transferId: transferId,
      riderId: riderId,
      riderName: riderName,
      riderSignatureUrl: riderSignatureUrl,
      verifiedItems: verifiedItems,
      notes: notes,
    );
  }

  @override
  Future<Map<String, dynamic>> rejectRiderStockHandover({
    required String transferId,
    required String riderId,
    String? reason,
  }) async {
    return await remoteDataSource.rejectRiderStockHandover(
      transferId: transferId,
      riderId: riderId,
      reason: reason,
    );
  }

  @override
  Future<List<StockTransferRecord>> fetchStockTransfers({
    String? dcId,
    String? clientId,
    String? riderId,
    String? status,
    String? transferType,
  }) async {
    return await remoteDataSource.fetchStockTransfers(
      dcId: dcId,
      clientId: clientId,
      riderId: riderId,
      status: status,
      transferType: transferType,
    );
  }

  @override
  Future<StockTransferRecord?> getStockTransferById(String transferId) async {
    return await remoteDataSource.getStockTransferById(transferId);
  }

  @override
  Future<Map<String, dynamic>> receiveRiderStockReturn({
    required String returnId,
    required String dcId,
    required String receiverId,
    required int verifiedQuantity,
    String condition = 'good',
    String? notes,
  }) async {
    return await remoteDataSource.receiveRiderStockReturn(
      returnId: returnId,
      dcId: dcId,
      receiverId: receiverId,
      verifiedQuantity: verifiedQuantity,
      condition: condition,
      notes: notes,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPendingDcReturns(String dcId) async {
    return await remoteDataSource.fetchPendingDcReturns(dcId);
  }

  @override
  Future<Map<String, dynamic>> submitDetailedInventoryAudit({
    required String companyId,
    required String auditorId,
    required String auditType,
    required List<Map<String, dynamic>> items,
    String? dcId,
    String? riderId,
    String? notes,
  }) async {
    return await remoteDataSource.submitDetailedInventoryAudit(
      companyId: companyId,
      auditorId: auditorId,
      auditType: auditType,
      items: items,
      dcId: dcId,
      riderId: riderId,
      notes: notes,
    );
  }
}
