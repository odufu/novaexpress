import '../repositories/finance_repository.dart';

class RequestPayoutUseCase {
  final FinanceRepository repository;

  RequestPayoutUseCase(this.repository);

  Future<Map<String, dynamic>> call({
    required String agentId,
    required double amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
    String? notes,
  }) {
    return repository.requestPayout(
      agentId: agentId,
      amount: amount,
      bankName: bankName,
      accountNumber: accountNumber,
      accountName: accountName,
      notes: notes,
    );
  }
}
