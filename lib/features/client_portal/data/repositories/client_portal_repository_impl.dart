import '../../domain/entities/client_closer.dart';
import '../../domain/entities/client_closer_payout.dart';
import '../../domain/entities/client_profile.dart';
import '../../domain/entities/client_settlement.dart';
import '../../domain/entities/customer_lead.dart';
import '../../domain/entities/client_supplier.dart';
import '../../domain/entities/client_stock_invoice.dart';
import '../../domain/entities/client_stock_balance.dart';
import '../../domain/repositories/client_portal_repository.dart';
import '../datasources/client_portal_remote_datasource.dart';

class ClientPortalRepositoryImpl implements ClientPortalRepository {
  final ClientPortalRemoteDataSource _remoteDataSource;

  ClientPortalRepositoryImpl([ClientPortalRemoteDataSource? remoteDataSource])
      : _remoteDataSource = remoteDataSource ?? ClientPortalRemoteDataSourceImpl();

  @override
  Future<ClientCloser> createCloser({
    required String clientId,
    required String fullName,
    required String email,
    required String phone,
    String? password,
    String? avatarUrl,
    String? closerCode,
    int dailyCallTarget = 50,
    double commissionRate = 500.0,
    bool isCommissionEnabled = true,
    String? bankName,
    String? accountNumber,
    String? accountName,
  }) async {
    return await _remoteDataSource.createCloser(
      clientId: clientId,
      fullName: fullName,
      email: email,
      phone: phone,
      password: password,
      avatarUrl: avatarUrl,
      closerCode: closerCode,
      dailyCallTarget: dailyCallTarget,
      commissionRate: commissionRate,
      isCommissionEnabled: isCommissionEnabled,
      bankName: bankName,
      accountNumber: accountNumber,
      accountName: accountName,
    );
  }

  @override
  Future<List<ClientCloser>> getClosers(String clientId) async {
    try {
      return await _remoteDataSource.fetchClosers(clientId);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> toggleCloserStatus({
    required String closerId,
    required bool isActive,
  }) async {
    await _remoteDataSource.updateCloserStatus(closerId: closerId, isActive: isActive);
  }

  @override
  Future<void> resetCloserPassword({
    required String closerId,
    String? userId,
    required String newPassword,
  }) async {
    await _remoteDataSource.resetCloserPassword(
      closerId: closerId,
      userId: userId,
      newPassword: newPassword,
    );
  }

  @override
  Future<void> updateCloserDetails({
    required String closerId,
    String? fullName,
    String? phone,
    String? email,
    double? commissionRate,
    int? dailyCallTarget,
    bool? isActive,
    bool? isCommissionEnabled,
    String? bankName,
    String? accountNumber,
    String? accountName,
  }) async {
    await _remoteDataSource.updateCloserDetails(
      closerId: closerId,
      fullName: fullName,
      phone: phone,
      email: email,
      commissionRate: commissionRate,
      dailyCallTarget: dailyCallTarget,
      isActive: isActive,
      isCommissionEnabled: isCommissionEnabled,
      bankName: bankName,
      accountNumber: accountNumber,
      accountName: accountName,
    );
  }

  @override
  Future<List<ClientCloserPayout>> getCloserPayouts(String closerId) async {
    return await _remoteDataSource.fetchCloserPayouts(closerId);
  }

  @override
  Future<List<ClientCloserPayout>> getClientCloserPayouts(String clientId) async {
    return await _remoteDataSource.fetchClientCloserPayouts(clientId);
  }

  @override
  Future<ClientCloserPayout> disburseCloserPayout({
    required String closerId,
    required String clientId,
    required double amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
    String? disbursementRef,
    String? proofOfPaymentUrl,
    String? notes,
  }) async {
    return await _remoteDataSource.disburseCloserPayout(
      closerId: closerId,
      clientId: clientId,
      amount: amount,
      bankName: bankName,
      accountNumber: accountNumber,
      accountName: accountName,
      disbursementRef: disbursementRef,
      proofOfPaymentUrl: proofOfPaymentUrl,
      notes: notes,
    );
  }

  @override
  Future<ClientCloserPayout> requestCloserPayout({
    required String closerId,
    required String clientId,
    required double amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
    String? notes,
  }) async {
    return await _remoteDataSource.requestCloserPayout(
      closerId: closerId,
      clientId: clientId,
      amount: amount,
      bankName: bankName,
      accountNumber: accountNumber,
      accountName: accountName,
      notes: notes,
    );
  }

  @override
  Future<void> confirmCloserPayout({
    required String payoutId,
    String? notes,
  }) async {
    await _remoteDataSource.confirmCloserPayout(
      payoutId: payoutId,
      notes: notes,
    );
  }

  @override
  Future<List<CustomerLead>> getLeads(String clientId) async {
    try {
      return await _remoteDataSource.fetchLeads(clientId);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> createLead(CustomerLead lead) async {
    await _remoteDataSource.insertLead(lead);
  }

  @override
  Future<void> updateLeadStatus({
    required String leadId,
    required String newStatus,
    String? notes,
  }) async {
    await _remoteDataSource.updateLeadStatus(
      leadId: leadId,
      newStatus: newStatus,
      notes: notes,
    );
  }

  @override
  Future<void> recordLeadConversion({
    required String leadId,
    required String orderId,
    String? closerId,
    int? totalLeadsConfirmed,
    int? totalOrdersBooked,
  }) async {
    await _remoteDataSource.recordLeadConversion(
      leadId: leadId,
      orderId: orderId,
      closerId: closerId,
      totalLeadsConfirmed: totalLeadsConfirmed,
      totalOrdersBooked: totalOrdersBooked,
    );
  }

  @override
  Future<ClientProfile?> getClientProfile(String clientId) async {
    try {
      return await _remoteDataSource.fetchClientProfile(clientId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<ClientSettlement>> getClientSettlements(String clientId) async {
    try {
      return await _remoteDataSource.fetchClientSettlements(clientId);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> getMerchantAssetCustody(String clientId) async {
    try {
      return await _remoteDataSource.fetchMerchantAssetCustody(clientId);
    } catch (_) {
      return {};
    }
  }

  @override
  Future<bool> approveSettlement({
    required String settlementId,
    required String clientId,
    String? notes,
  }) async {
    try {
      return await _remoteDataSource.approveSettlement(
        settlementId: settlementId,
        clientId: clientId,
        notes: notes,
      );
    } catch (_) {
      return false;
    }
  }

  // --- Inventory & Landed Cost Supply Management ---

  @override
  Future<List<ClientSupplier>> getSuppliers(String clientId) async {
    try {
      return await _remoteDataSource.fetchSuppliers(clientId);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<ClientSupplier> createSupplier(ClientSupplier supplier) async {
    return await _remoteDataSource.createSupplier(supplier);
  }

  @override
  Future<void> updateSupplier(ClientSupplier supplier) async {
    await _remoteDataSource.updateSupplier(supplier);
  }

  @override
  Future<List<ClientStockInvoice>> getStockInvoices(String clientId) async {
    try {
      return await _remoteDataSource.fetchStockInvoices(clientId);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<ClientStockInvoice> raiseStockInvoice({
    required ClientStockInvoice invoice,
    required List<ClientStockInvoiceItem> items,
  }) async {
    return await _remoteDataSource.raiseStockInvoice(invoice: invoice, items: items);
  }

  @override
  Future<void> attachPaymentReceipt({
    required String invoiceId,
    required String receiptUrl,
  }) async {
    await _remoteDataSource.attachPaymentReceipt(
      invoiceId: invoiceId,
      receiptUrl: receiptUrl,
    );
  }

  @override
  Future<List<ClientStockBalance>> getStockBalances(
    String clientId, {
    String? warehouseFilter,
    String? itemFilter,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      return await _remoteDataSource.fetchStockBalances(
        clientId,
        warehouseFilter: warehouseFilter,
        itemFilter: itemFilter,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> importStockBalanceCsv(String clientId, String csvContent) async {
    await _remoteDataSource.importStockBalanceCsv(clientId, csvContent);
  }
}
