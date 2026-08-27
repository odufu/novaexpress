import '../entities/remittance.dart';
import '../repositories/finance_repository.dart';

class SubmitRemittanceUseCase {
  final FinanceRepository repository;

  SubmitRemittanceUseCase(this.repository);

  Future<RemittanceEntity> call({
    required String agentId,
    required String companyId,
    required double amount,
    required String paymentMethod,
    double grossCollections = 0.0,
    double commissionDeducted = 0.0,
    double transportAllowanceDeducted = 0.0,
    double posFee = 0.0,
    String? depositReceiptUrl,
    String? referenceNumber,
    String? discrepancyReason,
    double? discrepancyAmount,
    double? expectedAmount,
    bool isPartial = false,
    String? notes,
  }) {
    return repository.submitRemittance(
      agentId: agentId,
      companyId: companyId,
      amount: amount,
      paymentMethod: paymentMethod,
      grossCollections: grossCollections,
      commissionDeducted: commissionDeducted,
      transportAllowanceDeducted: transportAllowanceDeducted,
      posFee: posFee,
      depositReceiptUrl: depositReceiptUrl,
      referenceNumber: referenceNumber,
      discrepancyReason: discrepancyReason,
      discrepancyAmount: discrepancyAmount,
      expectedAmount: expectedAmount,
      isPartial: isPartial,
      notes: notes,
    );
  }
}
