import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../domain/entities/client_closer.dart';
import '../../domain/entities/client_profile.dart';
import '../../domain/entities/customer_lead.dart';

abstract class ClientPortalRemoteDataSource {
  Future<ClientCloser> createCloser({
    required String clientId,
    required String fullName,
    required String email,
    required String phone,
    int dailyCallTarget = 50,
    double commissionRate = 500.0,
  });

  Future<List<ClientCloser>> fetchClosers(String clientId);
  Future<void> updateCloserStatus({required String closerId, required bool isActive});
  Future<void> resetCloserPassword({required String closerId, String? userId, required String newPassword});
  Future<void> updateCloserDetails({
    required String closerId,
    String? fullName,
    String? phone,
    String? email,
    double? commissionRate,
    int? dailyCallTarget,
    bool? isActive,
  });
  Future<List<CustomerLead>> fetchLeads(String clientId);
  Future<void> insertLead(CustomerLead lead);
  Future<void> updateLeadStatus({required String leadId, required String newStatus, String? notes});
  Future<void> recordLeadConversion({
    required String leadId,
    required String orderId,
    String? closerId,
    int? totalLeadsConfirmed,
    int? totalOrdersBooked,
  });
  Future<ClientProfile?> fetchClientProfile(String clientId);
}

class ClientPortalRemoteDataSourceImpl implements ClientPortalRemoteDataSource {
  final SupabaseClient? _client;

  ClientPortalRemoteDataSourceImpl([SupabaseClient? client]) : _client = client;

  SupabaseClient _getAdminClient() {
    if (_client != null) return _client;
    return SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseServiceRoleKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  }

  @override
  Future<ClientCloser> createCloser({
    required String clientId,
    required String fullName,
    required String email,
    required String phone,
    int dailyCallTarget = 50,
    double commissionRate = 500.0,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final adminDb = _getAdminClient();

    try {
      // 1. Pre-flight check against users table for duplicate email
      final existingUser = await adminDb
          .from('users')
          .select('id, email')
          .eq('email', cleanEmail)
          .maybeSingle();

      if (existingUser != null) {
        throw Exception("A user with email '$cleanEmail' already exists. Please use a unique email address.");
      }

      final closerId = _generateUuid();
      final closerCode = 'CLS-NOVA-${DateTime.now().millisecond.toString().padLeft(3, '0')}';

      final newCloser = ClientCloser(
        id: closerId,
        clientId: clientId,
        closerCode: closerCode,
        fullName: fullName.trim(),
        email: cleanEmail,
        phone: phone.trim(),
        dailyCallTarget: dailyCallTarget,
        commissionRate: commissionRate,
        isActive: true,
        createdAt: DateTime.now(),
      );

      // 2. Create Closer record
      await adminDb.from('client_closers').insert(newCloser.toJson());

      // 3. Create User account for closer login
      final nameParts = fullName.trim().split(' ');
      final fName = nameParts.isNotEmpty ? nameParts.first : 'Closer';
      final lName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      await adminDb.from('users').insert({
        'id': closerId,
        'company_id': '11111111-1111-4111-8111-111111111111',
        'email': cleanEmail,
        'phone_number': phone.trim(),
        'first_name': fName,
        'last_name': lName,
        'role': 'closer',
        'is_active': true,
      });

      return newCloser;
    } finally {
      adminDb.dispose();
    }
  }

  @override
  Future<List<ClientCloser>> fetchClosers(String clientId) async {
    final adminDb = _getAdminClient();
    try {
      final response = await adminDb
          .from('client_closers')
          .select('*')
          .eq('client_id', clientId)
          .order('created_at', ascending: false);

      final List<ClientCloser> list = [];
      for (final item in response as List) {
        try {
          list.add(ClientCloser.fromJson(item as Map<String, dynamic>));
        } catch (_) {}
      }
      return list;
    } finally {
      adminDb.dispose();
    }
  }

  @override
  Future<List<CustomerLead>> fetchLeads(String clientId) async {
    final adminDb = _getAdminClient();
    try {
      final response = await adminDb
          .from('customer_leads')
          .select('*')
          .eq('client_id', clientId)
          .order('created_at', ascending: false);

      final List<CustomerLead> list = [];
      for (final item in response as List) {
        try {
          list.add(CustomerLead.fromJson(item as Map<String, dynamic>));
        } catch (_) {}
      }
      return list;
    } finally {
      adminDb.dispose();
    }
  }

  @override
  Future<void> updateCloserStatus({required String closerId, required bool isActive}) async {
    final adminDb = _getAdminClient();
    try {
      await adminDb.from('client_closers').update({
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', closerId);

      await adminDb.from('users').update({
        'is_active': isActive,
      }).eq('id', closerId);
    } finally {
      adminDb.dispose();
    }
  }

  @override
  Future<void> resetCloserPassword({
    required String closerId,
    String? userId,
    required String newPassword,
  }) async {
    final adminDb = _getAdminClient();
    try {
      if (userId != null && userId.isNotEmpty) {
        await adminDb.auth.admin.updateUserById(
          userId,
          attributes: AdminUserAttributes(password: newPassword),
        );
      } else {
        await adminDb.from('users').update({
          'raw_user_meta_data': {'default_password_changed': true},
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', closerId);
      }
    } finally {
      adminDb.dispose();
    }
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
    final adminDb = _getAdminClient();
    try {
      await adminDb.from('client_closers').update({
        if (fullName != null) 'full_name': fullName,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (commissionRate != null) 'commission_rate': commissionRate,
        if (dailyCallTarget != null) 'daily_call_target': dailyCallTarget,
        if (isActive != null) 'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', closerId);

      if (fullName != null || phone != null || isActive != null) {
        await adminDb.from('users').update({
          if (fullName != null) 'first_name': fullName.split(' ').first,
          if (fullName != null) 'last_name': fullName.split(' ').skip(1).join(' '),
          if (phone != null) 'phone_number': phone,
          if (isActive != null) 'is_active': isActive,
        }).eq('id', closerId);
      }
    } finally {
      adminDb.dispose();
    }
  }

  @override
  Future<void> insertLead(CustomerLead lead) async {
    final adminDb = _getAdminClient();
    try {
      await adminDb.from('customer_leads').insert(lead.toJson());
    } finally {
      adminDb.dispose();
    }
  }

  @override
  Future<void> updateLeadStatus({
    required String leadId,
    required String newStatus,
    String? notes,
  }) async {
    final adminDb = _getAdminClient();
    try {
      await adminDb.from('customer_leads').update({
        'status': newStatus,
        if (notes != null) 'call_notes': notes,
        'last_called_at': DateTime.now().toIso8601String(),
      }).eq('id', leadId);
    } finally {
      adminDb.dispose();
    }
  }

  @override
  Future<void> recordLeadConversion({
    required String leadId,
    required String orderId,
    String? closerId,
    int? totalLeadsConfirmed,
    int? totalOrdersBooked,
  }) async {
    final adminDb = _getAdminClient();
    try {
      await adminDb.from('customer_leads').update({
        'status': 'order_created',
        'converted_order_id': orderId,
        'last_called_at': DateTime.now().toIso8601String(),
      }).eq('id', leadId);

      if (closerId != null && closerId.isNotEmpty) {
        await adminDb.from('client_closers').update({
          if (totalLeadsConfirmed != null) 'total_leads_confirmed': totalLeadsConfirmed,
          if (totalOrdersBooked != null) 'total_orders_booked': totalOrdersBooked,
        }).eq('id', closerId);
      }
    } finally {
      adminDb.dispose();
    }
  }

  @override
  Future<ClientProfile?> fetchClientProfile(String clientId) async {
    final adminDb = _getAdminClient();
    try {
      final response = await adminDb
          .from('clients')
          .select('*')
          .eq('id', clientId)
          .maybeSingle();

      if (response != null) {
        return ClientProfile.fromJson(response);
      }
      return null;
    } finally {
      adminDb.dispose();
    }
  }

  String _generateUuid() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final r = (now % 1000000000000).toString().padLeft(12, '0');
    return '00000000-0000-4000-8000-$r';
  }
}
