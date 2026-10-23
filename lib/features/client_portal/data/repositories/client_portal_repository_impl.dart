import '../../domain/entities/client_closer.dart';
import '../../domain/entities/client_closer_payout.dart';
import '../../domain/entities/client_profile.dart';
import '../../domain/entities/client_settlement.dart';
import '../../domain/entities/customer_lead.dart';
import '../../domain/entities/client_supplier.dart';
import '../../domain/entities/client_stock_invoice.dart';
import '../../domain/entities/client_stock_balance.dart';
import '../../domain/entities/stock_holder_custody.dart';
import '../../domain/entities/client_marketer.dart';
import '../../domain/entities/client_marketer_payout.dart';
import '../../domain/entities/lead_form.dart';
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
    List<String> assignedProductIds = const [],
    List<String> assignedProductNames = const [],
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
      assignedProductIds: assignedProductIds,
      assignedProductNames: assignedProductNames,
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
    List<String>? assignedProductIds,
    List<String>? assignedProductNames,
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
      assignedProductIds: assignedProductIds,
      assignedProductNames: assignedProductNames,
    );
  }

  @override
  Future<List<ClientMarketer>> getMarketers(String clientId) async {
    try {
      return await _remoteDataSource.fetchMarketers(clientId);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<ClientMarketer> createMarketer({
    required String clientId,
    required String fullName,
    required String email,
    required String phone,
    String? password,
    String? marketerCode,
    double dailyAdSpendBudget = 0.0,
    double commissionRate = 0.0,
    bool isCommissionEnabled = false,
    bool isSupervisor = false,
    String? supervisorId,
    String commissionModel = 'per_form_submission',
    double commissionPerFormSubmission = 0.0,
    double commissionPerDeliveredOrder = 0.0,
    String? bankName,
    String? accountNumber,
    String? accountName,
  }) async {
    return await _remoteDataSource.createMarketer(
      clientId: clientId,
      fullName: fullName,
      email: email,
      phone: phone,
      password: password,
      marketerCode: marketerCode,
      dailyAdSpendBudget: dailyAdSpendBudget,
      commissionRate: commissionRate,
      isCommissionEnabled: isCommissionEnabled,
      isSupervisor: isSupervisor,
      supervisorId: supervisorId,
      commissionModel: commissionModel,
      commissionPerFormSubmission: commissionPerFormSubmission,
      commissionPerDeliveredOrder: commissionPerDeliveredOrder,
      bankName: bankName,
      accountNumber: accountNumber,
      accountName: accountName,
    );
  }

  @override
  Future<void> toggleMarketerStatus({
    required String marketerId,
    required bool isActive,
  }) async {
    await _remoteDataSource.updateMarketerStatus(marketerId: marketerId, isActive: isActive);
  }

  @override
  Future<ClientMarketer> updateMarketerProfile({
    required String marketerId,
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? bankName,
    String? accountNumber,
    String? accountName,
  }) async {
    return await _remoteDataSource.updateMarketerProfile(
      marketerId: marketerId,
      fullName: fullName,
      phone: phone,
      avatarUrl: avatarUrl,
      bankName: bankName,
      accountNumber: accountNumber,
      accountName: accountName,
    );
  }

  @override
  Future<ClientMarketer> updateMarketerDetails({
    required String marketerId,
    required String fullName,
    required String phone,
    required String email,
    required double dailyAdSpendBudget,
    required String commissionModel,
    required double commissionRate,
    required double commissionPerFormSubmission,
    required double commissionPerDeliveredOrder,
    required bool isCommissionEnabled,
    required bool isSupervisor,
    String? supervisorId,
    String? bankName,
    String? accountNumber,
    String? accountName,
  }) async {
    return await _remoteDataSource.updateMarketerDetails(
      marketerId: marketerId,
      fullName: fullName,
      phone: phone,
      email: email,
      dailyAdSpendBudget: dailyAdSpendBudget,
      commissionModel: commissionModel,
      commissionRate: commissionRate,
      commissionPerFormSubmission: commissionPerFormSubmission,
      commissionPerDeliveredOrder: commissionPerDeliveredOrder,
      isCommissionEnabled: isCommissionEnabled,
      isSupervisor: isSupervisor,
      supervisorId: supervisorId,
      bankName: bankName,
      accountNumber: accountNumber,
      accountName: accountName,
    );
  }

  @override
  Future<void> deleteMarketer(String marketerId) async {
    await _remoteDataSource.deleteMarketer(marketerId);
  }

  @override
  Future<void> resetMarketerPassword({
    required String marketerId,
    required String newPassword,
  }) async {
    await _remoteDataSource.resetMarketerPassword(
      marketerId: marketerId,
      newPassword: newPassword,
    );
  }

  @override
  Future<List<ClientMarketerPayout>> getMarketerPayouts(String marketerId) async {
    return await _remoteDataSource.fetchMarketerPayouts(marketerId);
  }

  @override
  Future<List<ClientMarketerPayout>> getClientMarketerPayouts(String clientId) async {
    return await _remoteDataSource.fetchClientMarketerPayouts(clientId);
  }

  @override
  Future<ClientMarketerPayout> disburseMarketerPayout({
    required String marketerId,
    required String clientId,
    required double amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
    String? disbursementRef,
    String? proofOfPaymentUrl,
    String? notes,
  }) async {
    return await _remoteDataSource.disburseMarketerPayout(
      marketerId: marketerId,
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
  Future<List<LeadForm>> getLeadForms(String clientId, {String? marketerId}) async {
    try {
      return await _remoteDataSource.fetchLeadForms(clientId, marketerId: marketerId);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<LeadForm> createLeadForm({
    required String clientId,
    String? marketerId,
    required String productId,
    required String productName,
    required String formTitle,
    String? formSlug,
    String? description,
    List<Map<String, dynamic>> packages = const [],
    String redirectUrl = '',
    String pixelId = '',
    String capiToken = '',
    String testEventCode = '',
    Map<String, dynamic>? fieldOptions,
    Map<String, dynamic>? appearance,
  }) async {
    return await _remoteDataSource.createLeadForm(
      clientId: clientId,
      marketerId: marketerId,
      productId: productId,
      productName: productName,
      formTitle: formTitle,
      formSlug: formSlug,
      description: description,
      packages: packages,
      redirectUrl: redirectUrl,
      pixelId: pixelId,
      capiToken: capiToken,
      testEventCode: testEventCode,
      fieldOptions: fieldOptions,
      appearance: appearance,
    );
  }

  @override
  Future<LeadForm> updateLeadForm({
    required String formId,
    String? formTitle,
    String? formSlug,
    String? description,
    String? productId,
    String? productName,
    List<Map<String, dynamic>>? packages,
    String? redirectUrl,
    String? pixelId,
    String? capiToken,
    String? testEventCode,
    Map<String, dynamic>? fieldOptions,
    Map<String, dynamic>? appearance,
    bool? isActive,
  }) async {
    return await _remoteDataSource.updateLeadForm(
      formId: formId,
      formTitle: formTitle,
      formSlug: formSlug,
      description: description,
      productId: productId,
      productName: productName,
      packages: packages,
      redirectUrl: redirectUrl,
      pixelId: pixelId,
      capiToken: capiToken,
      testEventCode: testEventCode,
      fieldOptions: fieldOptions,
      appearance: appearance,
      isActive: isActive,
    );
  }

  @override
  Future<Map<String, dynamic>> submitMarketingLeadOrder(Map<String, dynamic> payload) async {
    return await _remoteDataSource.submitMarketingLeadOrder(payload);
  }

  @override
  Future<Map<String, dynamic>> confirmCloserOrder({
    required String orderId,
    required String closerId,
    String? deliveryAddress,
    String? deliveryState,
    String? deliveryLga,
    String? notes,
    String action = 'confirm',
    String? customerName,
    String? customerPhone,
    String? customerAltPhone,
    String? packageDealName,
    String? packageDealId,
    int? quantity,
    int? paidQuantity,
    int? freeQuantity,
    double? totalAmount,
    DateTime? scheduledDeliveryDate,
    String? cancellationReason,
  }) async {
    return await _remoteDataSource.confirmCloserOrder(
      orderId: orderId,
      closerId: closerId,
      deliveryAddress: deliveryAddress,
      deliveryState: deliveryState,
      deliveryLga: deliveryLga,
      notes: notes,
      action: action,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAltPhone: customerAltPhone,
      packageDealName: packageDealName,
      packageDealId: packageDealId,
      quantity: quantity,
      paidQuantity: paidQuantity,
      freeQuantity: freeQuantity,
      totalAmount: totalAmount,
      scheduledDeliveryDate: scheduledDeliveryDate,
      cancellationReason: cancellationReason,
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

  @override
  Future<bool> rejectSettlement({
    required String settlementId,
    required String clientId,
    required String reason,
    String? proofUrl,
  }) async {
    try {
      return await _remoteDataSource.rejectSettlement(
        settlementId: settlementId,
        clientId: clientId,
        reason: reason,
        proofUrl: proofUrl,
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

  @override
  Future<List<StockHolderCustodyEntity>> getProductHoldersCustody(
    String clientId, {
    String? productId,
    DateTime? startDate,
    DateTime? endDate,
    String? state,
    String? lga,
  }) async {
    try {
      return await _remoteDataSource.fetchProductHoldersCustody(
        clientId,
        productId: productId,
        startDate: startDate,
        endDate: endDate,
        state: state,
        lga: lga,
      );
    } catch (_) {
      return [];
    }
  }
}
