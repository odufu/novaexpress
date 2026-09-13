import '../entities/rider_stock_allocation.dart';
import '../entities/stock_item.dart';
import '../entities/stock_transfer_record.dart';

abstract class StockRepository {
  Future<List<StockItemEntity>> getVehicleStockItems([String? agentId, String? dcId]);
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
  });
  Future<Map<String, dynamic>> assignStockToRider({
    required String productIdOrSku,
    required String riderId,
    required String riderName,
    required String riderCode,
    required int quantity,
    String? distributionCenterId,
  });
  Future<bool> receiveStock({
    required String productIdOrSku,
    required int quantity,
    String? waybillNumber,
    String? supplierName,
    String? distributionCenterId,
  });
  Future<Map<String, dynamic>> requestStockTransfer({
    required String agentId,
    required String companyId,
    required String sourceWarehouseId,
    required List<Map<String, dynamic>> items,
    String? notes,
  });
  Future<Map<String, dynamic>> confirmStockHandover({
    required String requestId,
    required String handoverCode,
    required String agentId,
  });
  Future<Map<String, dynamic>> transferStockBetweenDCs({
    required String productIdOrSku,
    required String sourceDcId,
    required String sourceDcName,
    required String destinationDcId,
    required String destinationDcName,
    required int quantity,
    String? notes,
  });
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
  });
  Future<List<RiderStockAllocation>> getRiderStockAllocations([String? riderId, String? dcId]);
  Future<void> updateRiderStockCustody({
    required String riderId,
    required String productId,
    int deliveredDelta = 0,
    int returnedDelta = 0,
    int inCustodyDelta = 0,
  });
  Future<Map<String, dynamic>> submitInventoryAudit({
    required String distributionCenterId,
    required String auditedBy,
    required int totalPhysicalCounted,
    required int totalSystemExpected,
    required int discrepancyCount,
    String? notes,
  });
  Future<Map<String, dynamic>> dispatchClientSupply({
    required String clientId,
    required String dcId,
    required List<Map<String, dynamic>> items,
    String? senderId,
    required String senderName,
    required String senderSignatureUrl,
    String? notes,
  });
  Future<Map<String, dynamic>> receiveClientSupply({
    required String transferId,
    required String receiverId,
    required String receiverName,
    required String receiverSignatureUrl,
    required List<Map<String, dynamic>> verifiedItems,
    String? notes,
  });
  Future<Map<String, dynamic>> issueDcStockToRiderWithSignature({
    required String dcId,
    required String riderId,
    required List<Map<String, dynamic>> items,
    required String senderId,
    required String senderName,
    required String senderSignatureUrl,
    String? notes,
  });
  Future<Map<String, dynamic>> acceptRiderStockHandover({
    required String transferId,
    required String riderId,
    required String riderName,
    required String riderSignatureUrl,
    List<Map<String, dynamic>>? verifiedItems,
    String? notes,
  });
  Future<Map<String, dynamic>> rejectRiderStockHandover({
    required String transferId,
    required String riderId,
    String? reason,
  });
  Future<List<StockTransferRecord>> fetchStockTransfers({
    String? dcId,
    String? clientId,
    String? riderId,
    String? status,
    String? transferType,
  });
  Future<StockTransferRecord?> getStockTransferById(String transferId);
  Future<Map<String, dynamic>> receiveRiderStockReturn({
    required String returnId,
    required String dcId,
    required String receiverId,
    required int verifiedQuantity,
    String condition = 'good',
    String? notes,
  });
  Future<List<Map<String, dynamic>>> fetchPendingDcReturns(String dcId);
  Future<Map<String, dynamic>> submitDetailedInventoryAudit({
    required String companyId,
    required String auditorId,
    required String auditType,
    required List<Map<String, dynamic>> items,
    String? dcId,
    String? riderId,
    String? notes,
  });
}
