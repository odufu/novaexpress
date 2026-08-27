import '../entities/transaction_item.dart';
import '../repositories/finance_repository.dart';

class GetRiderTransactionsUseCase {
  final FinanceRepository repository;

  GetRiderTransactionsUseCase(this.repository);

  Future<List<TransactionItem>> call(String agentId) {
    return repository.getRiderTransactions(agentId);
  }
}
