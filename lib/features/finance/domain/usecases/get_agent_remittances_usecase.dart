import '../entities/remittance.dart';
import '../repositories/finance_repository.dart';

class GetAgentRemittancesUseCase {
  final FinanceRepository repository;

  GetAgentRemittancesUseCase(this.repository);

  Future<List<RemittanceEntity>> call(String agentId) {
    return repository.getAgentRemittances(agentId);
  }
}
