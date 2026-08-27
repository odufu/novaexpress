import '../../domain/entities/remittance.dart';
import '../../domain/entities/transaction_item.dart';
import '../../domain/repositories/finance_repository.dart';
import '../datasources/finance_remote_datasource.dart';

class FinanceRepositoryImpl implements FinanceRepository {
  final FinanceRemoteDataSource remoteDataSource;

  FinanceRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<RemittanceEntity>> getAgentRemittances(String agentId) async {
    return await remoteDataSource.getAgentRemittances(agentId);
  }

  @override
  Future<RemittanceEntity> submitRemittance({
    required String agentId,
    required String companyId,
    required double amount,
    required String paymentMethod,
    double grossCollections = 0.0,
    double commissionDeducted = 0.0,
    double transportAllowanceDeducted = 0.0,
    double failedStipendsDeducted = 0.0,
    double posFee = 0.0,
    String? depositReceiptUrl,
    String? referenceNumber,
    String? discrepancyReason,
    double? discrepancyAmount,
    double? expectedAmount,
    bool isPartial = false,
    String? notes,
    List<RemittanceOrderItem> associatedOrders = const [],
  }) async {
    return await remoteDataSource.submitRemittance(
      agentId: agentId,
      companyId: companyId,
      amount: amount,
      paymentMethod: paymentMethod,
      grossCollections: grossCollections,
      commissionDeducted: commissionDeducted,
      transportAllowanceDeducted: transportAllowanceDeducted,
      failedStipendsDeducted: failedStipendsDeducted,
      posFee: posFee,
      depositReceiptUrl: depositReceiptUrl,
      referenceNumber: referenceNumber,
      discrepancyReason: discrepancyReason,
      discrepancyAmount: discrepancyAmount,
      expectedAmount: expectedAmount,
      isPartial: isPartial,
      notes: notes,
      associatedOrders: associatedOrders,
    );
  }

  @override
  Future<Map<String, dynamic>> requestPayout({
    required String agentId,
    required double amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
    String? notes,
  }) async {
    return await remoteDataSource.requestPayout(
      agentId: agentId,
      amount: amount,
      bankName: bankName,
      accountNumber: accountNumber,
      accountName: accountName,
      notes: notes,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getPayoutRequests(String agentId) async {
    return await remoteDataSource.getPayoutRequests(agentId);
  }

  @override
  Future<List<TransactionItem>> getRiderTransactions(String agentId) async {
    final rawList = await remoteDataSource.getRiderTransactions(agentId);
    return rawList.map((json) => TransactionItem.fromJson(json)).toList();
  }

  @override
  Future<Map<String, dynamic>?> getPaystackTransactionDetails(String reference) async {
    return await remoteDataSource.getPaystackTransactionDetails(reference);
  }
}
