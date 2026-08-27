import '../repositories/finance_repository.dart';

class GetPayoutRequestsUseCase {
  final FinanceRepository repository;

  GetPayoutRequestsUseCase(this.repository);

  Future<List<Map<String, dynamic>>> call(String agentId) {
    return repository.getPayoutRequests(agentId);
  }
}
