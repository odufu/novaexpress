import '../repositories/stock_repository.dart';

class SubmitInventoryAuditUseCase {
  final StockRepository repository;

  SubmitInventoryAuditUseCase(this.repository);

  Future<Map<String, dynamic>> call({
    required String distributionCenterId,
    required String auditedBy,
    required int totalPhysicalCounted,
    required int totalSystemExpected,
    required int discrepancyCount,
    String? notes,
  }) {
    return repository.submitInventoryAudit(
      distributionCenterId: distributionCenterId,
      auditedBy: auditedBy,
      totalPhysicalCounted: totalPhysicalCounted,
      totalSystemExpected: totalSystemExpected,
      discrepancyCount: discrepancyCount,
      notes: notes,
    );
  }
}
