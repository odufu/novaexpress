import '../repositories/orders_repository.dart';

class ConfirmDeliveryPodUseCase {
  final OrdersRepository repository;

  ConfirmDeliveryPodUseCase(this.repository);

  Future<Map<String, dynamic>> call({
    required String orderId,
    required String agentId,
    required String paymentType,
    required String paymentMethod,
    required double amountCollected,
    String? customerSignatureUrl,
    String? photoProofUrl,
    String? notes,
  }) {
    return repository.confirmDeliveryPod(
      orderId: orderId,
      agentId: agentId,
      paymentType: paymentType,
      paymentMethod: paymentMethod,
      amountCollected: amountCollected,
      customerSignatureUrl: customerSignatureUrl,
      photoProofUrl: photoProofUrl,
      notes: notes,
    );
  }
}
