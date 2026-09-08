import '../entities/client_closer.dart';
import '../entities/client_profile.dart';
import '../entities/customer_lead.dart';

abstract class ClientPortalRepository {
  /// Onboards a new Closer for an Enterprise Client
  Future<ClientCloser> createCloser({
    required String clientId,
    required String fullName,
    required String email,
    required String phone,
    int dailyCallTarget = 50,
    double commissionRate = 500.0,
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
}
