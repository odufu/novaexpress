import '../../domain/entities/client_closer.dart';
import '../../domain/entities/client_profile.dart';
import '../../domain/entities/customer_lead.dart';
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
    int dailyCallTarget = 50,
    double commissionRate = 500.0,
  }) async {
    return await _remoteDataSource.createCloser(
      clientId: clientId,
      fullName: fullName,
      email: email,
      phone: phone,
      dailyCallTarget: dailyCallTarget,
      commissionRate: commissionRate,
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
  }) async {
    await _remoteDataSource.updateCloserDetails(
      closerId: closerId,
      fullName: fullName,
      phone: phone,
      email: email,
      commissionRate: commissionRate,
      dailyCallTarget: dailyCallTarget,
      isActive: isActive,
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
}
