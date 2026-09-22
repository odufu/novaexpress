import '../entities/client_closer.dart';
import '../entities/client_closer_payout.dart';
import '../entities/client_profile.dart';
import '../entities/client_settlement.dart';
import '../entities/customer_lead.dart';
import '../entities/client_supplier.dart';
import '../entities/client_stock_invoice.dart';
import '../entities/client_stock_balance.dart';

abstract class ClientPortalRepository {
  /// Onboards a new Closer for an Enterprise Client
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
  });

  /// Fetches all closers for a client
  Future<List<ClientCloser>> getClosers(String clientId);

  /// Toggles active status of a closer
  Future<void> toggleCloserStatus({
    required String closerId,
    required bool isActive,
  });

  /// Resets a closer's login password
  Future<void> resetCloserPassword({
    required String closerId,
    String? userId,
    required String newPassword,
  });

  /// Updates details of a closer
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
  });

  /// Closer Payout Management
  Future<List<ClientCloserPayout>> getCloserPayouts(String closerId);
  Future<List<ClientCloserPayout>> getClientCloserPayouts(String clientId);
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
  });
  Future<ClientCloserPayout> requestCloserPayout({
    required String closerId,
    required String clientId,
    required double amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
    String? notes,
  });
  Future<void> confirmCloserPayout({
    required String payoutId,
    String? notes,
  });

  /// Fetches client customer leads
  Future<List<CustomerLead>> getLeads(String clientId);

  /// Creates a new lead in the database
  Future<void> createLead(CustomerLead lead);

  /// Updates status and call notes of a lead
  Future<void> updateLeadStatus({
    required String leadId,
    required String newStatus,
    String? notes,
  });

  /// Records conversion of a lead into an order
  Future<void> recordLeadConversion({
    required String leadId,
    required String orderId,
    String? closerId,
    int? totalLeadsConfirmed,
    int? totalOrdersBooked,
  });

  /// Fetches client profile details
  Future<ClientProfile?> getClientProfile(String clientId);

  /// Fetches client settlement history
  Future<List<ClientSettlement>> getClientSettlements(String clientId);

  /// Fetches live merchant asset custody breakdown (liquid cash & in-kind inventory)
  Future<Map<String, dynamic>> getMerchantAssetCustody(String clientId);

  /// Approves and confirms a client settlement
  Future<bool> approveSettlement({
    required String settlementId,
    required String clientId,
    String? notes,
  });

  // --- Inventory & Landed Cost Supply Management ---
  Future<List<ClientSupplier>> getSuppliers(String clientId);
  Future<ClientSupplier> createSupplier(ClientSupplier supplier);
  Future<void> updateSupplier(ClientSupplier supplier);
  Future<List<ClientStockInvoice>> getStockInvoices(String clientId);
  Future<ClientStockInvoice> raiseStockInvoice({
    required ClientStockInvoice invoice,
    required List<ClientStockInvoiceItem> items,
  });
  Future<void> attachPaymentReceipt({
    required String invoiceId,
    required String receiptUrl,
  });
  Future<List<ClientStockBalance>> getStockBalances(
    String clientId, {
    String? warehouseFilter,
    String? itemFilter,
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<void> importStockBalanceCsv(String clientId, String csvContent);
}
