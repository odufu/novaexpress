import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';
import '../../../auth/data/models/user_model.dart';
import '../../domain/entities/client_closer.dart';
import '../../domain/entities/client_profile.dart';
import '../../domain/entities/client_settlement.dart';
import '../../domain/entities/customer_lead.dart';

abstract class ClientPortalRemoteDataSource {
  Future<ClientCloser> createCloser({
    required String clientId,
    required String fullName,
    required String email,
    required String phone,
    String? password,
    String? avatarUrl,
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
  Future<void> updateClientProfile(ClientProfile profile);
  Future<List<ClientSettlement>> fetchClientSettlements(String clientId);
  Future<Map<String, dynamic>> fetchMerchantAssetCustody(String clientId);
}

class ClientPortalRemoteDataSourceImpl implements ClientPortalRemoteDataSource {
  final SupabaseClient? _client;
  SupabaseClient? _cachedAdminClient;

  ClientPortalRemoteDataSourceImpl([this._client]);

  SupabaseClient _getAdminClient() {
    return _cachedAdminClient ??= SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseServiceRoleKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  }

  SupabaseClient _getClient() {
    final c = _client;
    if (c != null) return c;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return _getAdminClient();
    }
  }

  String _generateUuid() {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(16).padLeft(12, '0');
    return 'c105e000-0000-4000-8000-$now'.substring(0, 36);
  }

  @override
  Future<ClientCloser> createCloser({
    required String clientId,
    required String fullName,
    required String email,
    required String phone,
    String? password,
    String? avatarUrl,
    int dailyCallTarget = 50,
    double commissionRate = 500.0,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final rawPassword = (password != null && password.trim().isNotEmpty) ? password.trim() : 'Closer123!';
    final adminDb = _getAdminClient();

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
    final closerCode = 'CLS-${DateTime.now().millisecond.toString().padLeft(3, '0')}';

    // 2. Provision Supabase Auth User with confirmed status so closer can sign in directly
    String authUserId = closerId;
    try {
      final authRes = await adminDb.auth.admin.createUser(
        AdminUserAttributes(
          email: cleanEmail,
          password: rawPassword,
          emailConfirm: true,
          userMetadata: {
            'role': 'closer',
            'client_id': clientId,
            'full_name': fullName.trim(),
          },
        ),
      );
      if (authRes.user != null) {
        authUserId = authRes.user!.id;
      }
    } catch (authErr) {
      final errStr = authErr.toString().toLowerCase();
      if (errStr.contains('already') || errStr.contains('exists') || errStr.contains('unique') || errStr.contains('422')) {
        try {
          final usersList = await adminDb.auth.admin.listUsers();
          final existing = usersList.firstWhere((u) => u.email?.toLowerCase() == cleanEmail);
          await adminDb.auth.admin.updateUserById(
            existing.id,
            attributes: AdminUserAttributes(
              password: rawPassword,
              emailConfirm: true,
              userMetadata: {
                'role': 'closer',
                'client_id': clientId,
                'full_name': fullName.trim(),
              },
            ),
          );
          authUserId = existing.id;
          debugPrint('[CLIENT_PORTAL] 🔄 Existing Supabase Auth Closer user updated: $authUserId');
        } catch (_) {
          throw Exception("A user with email '$cleanEmail' already exists. Please use a unique email address.");
        }
      } else {
        rethrow;
      }
    }

    final newCloser = ClientCloser(
      id: closerId,
      clientId: clientId,
      userId: authUserId,
      closerCode: closerCode,
      fullName: fullName.trim(),
      email: cleanEmail,
      phone: phone.trim(),
      avatarUrl: avatarUrl,
      dailyCallTarget: dailyCallTarget,
      commissionRate: commissionRate,
      isActive: true,
      createdAt: DateTime.now(),
    );

    // 3. Create Closer record
    await adminDb.from('client_closers').upsert(newCloser.toJson());

    // 4. Create User account for closer login
    final nameParts = fullName.trim().split(' ');
    final fName = nameParts.isNotEmpty ? nameParts.first : 'Closer';
    final lName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    await adminDb.from('users').upsert({
      'id': authUserId,
      'company_id': '11111111-1111-4111-8111-111111111111',
      'client_id': clientId,
      'email': cleanEmail,
      'phone_number': phone.trim(),
      'first_name': fName,
      'last_name': lName,
      'role': 'closer',
      if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatar_url': avatarUrl,
      'is_active': true,
    });

    // 5. Register in-memory session for immediate local/test authentication
    final closerUser = UserModel(
      id: authUserId,
      authUserId: authUserId,
      email: cleanEmail,
      firstName: fName,
      lastName: lName,
      phone: phone.trim(),
      role: 'closer',
      clientId: clientId,
      closerId: closerId,
      closerCode: closerCode,
      avatarUrl: avatarUrl,
    );
    AuthRemoteDataSourceImpl.registerUserInMemory(closerUser, rawPassword);

    return newCloser;
  }

  @override
  Future<List<ClientCloser>> fetchClosers(String clientId) async {
    final client = _getClient();
    final response = await client
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
  }

  @override
  Future<List<CustomerLead>> fetchLeads(String clientId) async {
    final client = _getClient();
    final response = await client
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
  }

  @override
  Future<void> updateCloserStatus({required String closerId, required bool isActive}) async {
    final adminDb = _getAdminClient();
    await adminDb.from('client_closers').update({
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', closerId);

    await adminDb.from('users').update({
      'is_active': isActive,
    }).eq('id', closerId);
  }

  @override
  Future<void> resetCloserPassword({
    required String closerId,
    String? userId,
    required String newPassword,
  }) async {
    final adminDb = _getAdminClient();
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

    try {
      final closerRes = await adminDb.from('client_closers').select('email').eq('id', closerId).maybeSingle();
      final email = closerRes?['email']?.toString();
      if (email != null && email.isNotEmpty) {
        final registered = AuthRemoteDataSourceImpl.getRegisteredUser(email);
        if (registered != null) {
          AuthRemoteDataSourceImpl.registerUserInMemory(registered, newPassword);
        }
      }
    } catch (_) {}
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
  }

  @override
  Future<void> insertLead(CustomerLead lead) async {
    final adminDb = _getAdminClient();
    await adminDb.from('customer_leads').insert(lead.toJson());
  }

  @override
  Future<void> updateLeadStatus({
    required String leadId,
    required String newStatus,
    String? notes,
  }) async {
    final adminDb = _getAdminClient();
    await adminDb.from('customer_leads').update({
      'status': newStatus,
      if (notes != null) 'call_notes': notes,
      'last_called_at': DateTime.now().toIso8601String(),
    }).eq('id', leadId);
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
  }

  @override
  Future<ClientProfile?> fetchClientProfile(String clientId) async {
    final adminDb = _getAdminClient();
    final response = await adminDb
        .from('clients')
        .select('*')
        .eq('id', clientId)
        .maybeSingle();

    if (response != null) {
      return ClientProfile.fromJson(response);
    }
    return null;
  }

  @override
  Future<void> updateClientProfile(ClientProfile profile) async {
    final adminDb = _getAdminClient();
    await adminDb
        .from('clients')
        .update(profile.toJson())
        .eq('id', profile.id);
  }

  @override
  Future<List<ClientSettlement>> fetchClientSettlements(String clientId) async {
    final adminDb = _getAdminClient();
    try {
      final response = await adminDb
          .from('client_settlements')
          .select('*')
          .eq('client_id', clientId)
          .order('settled_at', ascending: false);

      return (response as List).map((item) => ClientSettlement.fromJson(item)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> fetchMerchantAssetCustody(String clientId) async {
    final adminDb = _getAdminClient();
    try {
      final response = await adminDb.rpc('fn_calculate_merchant_asset_custody', params: {
        'p_client_id': clientId,
      });

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] ❌ fetchMerchantAssetCustody error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
