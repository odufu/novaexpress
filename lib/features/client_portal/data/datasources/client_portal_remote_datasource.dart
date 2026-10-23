import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';
import '../../../auth/data/models/user_model.dart';
import '../../domain/entities/client_closer.dart';
import '../../domain/entities/client_profile.dart';
import '../../domain/entities/client_settlement.dart';
import '../../domain/entities/customer_lead.dart';
import '../../domain/entities/client_closer_payout.dart';
import '../../domain/entities/client_supplier.dart';
import '../../domain/entities/client_stock_invoice.dart';
import '../../domain/entities/client_stock_balance.dart';
import '../../domain/entities/stock_holder_custody.dart';
import '../../domain/entities/client_marketer.dart';
import '../../domain/entities/client_marketer_payout.dart';
import '../../domain/entities/lead_form.dart';
import '../../../../core/helpers/uuid_helper.dart';

abstract class ClientPortalRemoteDataSource {
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
    bool? isCommissionEnabled,
    String? bankName,
    String? accountNumber,
    String? accountName,
    List<String>? assignedProductIds,
    List<String>? assignedProductNames,
  });

  /// Digital Marketers & Lead Forms
  Future<List<ClientMarketer>> fetchMarketers(String clientId);
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
  });
  Future<void> updateMarketerStatus({required String marketerId, required bool isActive});
  Future<ClientMarketer> updateMarketerProfile({
    required String marketerId,
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? bankName,
    String? accountNumber,
    String? accountName,
  });
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
  });
  Future<void> deleteMarketer(String marketerId);
  Future<void> resetMarketerPassword({
    required String marketerId,
    required String newPassword,
  });
  Future<List<ClientMarketerPayout>> fetchMarketerPayouts(String marketerId);
  Future<List<ClientMarketerPayout>> fetchClientMarketerPayouts(String clientId);
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
  });
  Future<List<LeadForm>> fetchLeadForms(String clientId, {String? marketerId});
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
  });
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
  });
  Future<Map<String, dynamic>> submitMarketingLeadOrder(Map<String, dynamic> payload);
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
  });
  Future<List<ClientCloserPayout>> fetchCloserPayouts(String closerId);
  Future<List<ClientCloserPayout>> fetchClientCloserPayouts(String clientId);
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
  Future<bool> approveSettlement({
    required String settlementId,
    required String clientId,
    String? notes,
  });

  Future<bool> rejectSettlement({
    required String settlementId,
    required String clientId,
    required String reason,
    String? proofUrl,
  });

  // --- Inventory & Landed Cost Supply Management ---
  Future<List<ClientSupplier>> fetchSuppliers(String clientId);
  Future<ClientSupplier> createSupplier(ClientSupplier supplier);
  Future<void> updateSupplier(ClientSupplier supplier);
  Future<List<ClientStockInvoice>> fetchStockInvoices(String clientId);
  Future<ClientStockInvoice> raiseStockInvoice({
    required ClientStockInvoice invoice,
    required List<ClientStockInvoiceItem> items,
  });
  Future<void> attachPaymentReceipt({
    required String invoiceId,
    required String receiptUrl,
  });
  Future<List<ClientStockBalance>> fetchStockBalances(
    String clientId, {
    String? warehouseFilter,
    String? itemFilter,
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<void> importStockBalanceCsv(String clientId, String csvContent);
  Future<List<StockHolderCustodyEntity>> fetchProductHoldersCustody(
    String clientId, {
    String? productId,
    DateTime? startDate,
    DateTime? endDate,
    String? state,
    String? lga,
  });
}

class ClientPortalRemoteDataSourceImpl implements ClientPortalRemoteDataSource {
  final SupabaseClient? _client;
  SupabaseClient? _cachedAdminClient;
  final List<ClientSupplier> _inMemorySuppliers = [];
  final List<ClientStockInvoice> _inMemoryStockInvoices = [];
  final List<ClientStockBalance> _inMemoryStockBalances = [];

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
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && !session.isExpired) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return _getAdminClient();
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
    final cleanEmail = email.trim().toLowerCase();
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '').trim();
    final rawPassword = (password != null && password.trim().isNotEmpty) ? password.trim() : 'Closer123!';
    final adminDb = _getAdminClient();

    // 1. Pre-flight check: Email Uniqueness in users table
    final existingUsersByEmail = await adminDb
        .from('users')
        .select('id, email')
        .eq('email', cleanEmail)
        .limit(2);

    if ((existingUsersByEmail as List).isNotEmpty) {
      throw Exception("A user with email '$cleanEmail' already exists. Please use a unique email address.");
    }

    // 1b. Check if an orphaned/partial closer record exists with this email in client_closers
    final existingClosersByEmail = await adminDb
        .from('client_closers')
        .select('id, email, user_id')
        .eq('email', cleanEmail)
        .limit(2);

    if ((existingClosersByEmail as List).isNotEmpty) {
      final firstCloser = (existingClosersByEmail as List).first as Map<String, dynamic>;
      final existingUserId = firstCloser['user_id']?.toString();
      final List hasRealUser = existingUserId != null && existingUserId.isNotEmpty
          ? (await adminDb.from('users').select('id').eq('id', existingUserId).limit(1)) as List
          : const [];

      if (hasRealUser.isEmpty) {
        // Orphaned record from previous partial failure — clean it up so onboarding succeeds
        debugPrint('[CLIENT_PORTAL] 🧹 Cleaning up orphaned closer record for $cleanEmail');
        for (final row in (existingClosersByEmail as List)) {
          await adminDb.from('client_closers').delete().eq('id', row['id']);
        }
      } else {
        throw Exception("A sales closer with email '$cleanEmail' is already registered in the team.");
      }
    }

    // 1c. Pre-flight check: Phone Number Uniqueness in users table
    final phoneVariants = <String>{cleanPhone, phone.trim()};
    if (cleanPhone.startsWith('0') && cleanPhone.length == 11) {
      phoneVariants.add('+234${cleanPhone.substring(1)}');
      phoneVariants.add('234${cleanPhone.substring(1)}');
      phoneVariants.add('+234 ${cleanPhone.substring(1)}');
    } else if (cleanPhone.startsWith('+234') && cleanPhone.length == 14) {
      phoneVariants.add('0${cleanPhone.substring(4)}');
      phoneVariants.add('234${cleanPhone.substring(4)}');
    } else if (cleanPhone.startsWith('234') && cleanPhone.length == 13) {
      phoneVariants.add('0${cleanPhone.substring(3)}');
      phoneVariants.add('+234${cleanPhone.substring(3)}');
    }

    final phoneFilter = phoneVariants.map((p) => 'phone_number.eq.$p').join(',');
    final existingUsersByPhone = await adminDb
        .from('users')
        .select('id, phone_number, first_name, last_name, role')
        .or(phoneFilter)
        .limit(2);

    if ((existingUsersByPhone as List).isNotEmpty) {
      throw Exception("Phone number '$phone' is already registered to another account. Please use a unique phone number.");
    }

    // 2. Guaranteed-Unique Closer Code Generation (against actual DB records)
    final existingCodesRes = await adminDb
        .from('client_closers')
        .select('closer_code');

    final Set<String> existingCodes = {};
    for (final row in (existingCodesRes as List)) {
      final code = row['closer_code']?.toString().trim().toUpperCase();
      if (code != null && code.isNotEmpty) {
        existingCodes.add(code);
      }
    }

    // Determine prefix (e.g. CLS-NOVA-)
    String prefix = 'CLS-NOVA-';
    if (closerCode != null && closerCode.trim().isNotEmpty) {
      final match = RegExp(r'^(.*?)(\d+)$').firstMatch(closerCode.trim());
      if (match != null && match.group(1)!.isNotEmpty) {
        prefix = match.group(1)!;
      }
    }

    // Find highest suffix for this prefix across all existing database closers
    int maxSuffix = 0;
    for (final code in existingCodes) {
      if (code.startsWith(prefix.toUpperCase())) {
        final numPart = code.substring(prefix.length);
        final val = int.tryParse(numPart);
        if (val != null && val > maxSuffix) {
          maxSuffix = val;
        }
      }
    }

    int nextNum = maxSuffix >= 100 ? maxSuffix + 1 : (maxSuffix > 0 ? maxSuffix + 1 : 101);
    String candidateCode = '$prefix${nextNum.toString().padLeft(3, '0')}';
    while (existingCodes.contains(candidateCode.toUpperCase())) {
      nextNum++;
      candidateCode = '$prefix${nextNum.toString().padLeft(3, '0')}';
    }
    final effectiveCloserCode = candidateCode;
    debugPrint('[CLIENT_PORTAL] 🏷️ Resolved guaranteed unique closer code: $effectiveCloserCode');

    final closerId = _generateUuid();

    // 3. Provision Supabase Auth User with confirmed status
    String authUserId = closerId;
    bool createdNewAuthUser = false;
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
        createdNewAuthUser = true;
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
      closerCode: effectiveCloserCode,
      fullName: fullName.trim(),
      email: cleanEmail,
      phone: phone.trim(),
      avatarUrl: avatarUrl,
      dailyCallTarget: dailyCallTarget,
      commissionRate: commissionRate,
      isCommissionEnabled: isCommissionEnabled,
      bankName: bankName ?? '',
      accountNumber: accountNumber ?? '',
      accountName: accountName ?? '',
      assignedProductIds: assignedProductIds,
      assignedProductNames: assignedProductNames,
      isActive: true,
      createdAt: DateTime.now(),
    );

    try {
      // 4. Create Closer record with backward compatibility fallback
      try {
        await adminDb.from('client_closers').upsert(newCloser.toJson());
      } catch (upsertErr) {
        debugPrint('[CLIENT_PORTAL] ⚠️ Warning upserting closer with commission/bank columns: $upsertErr. Falling back to core columns.');
        final coreMap = Map<String, dynamic>.from(newCloser.toJson());
        coreMap.remove('is_commission_enabled');
        coreMap.remove('bank_name');
        coreMap.remove('account_number');
        coreMap.remove('account_name');
        coreMap.remove('unpaid_commission_balance');
        coreMap.remove('total_paid_commission');
        await adminDb.from('client_closers').upsert(coreMap);
      }

      // 5. Create User account for closer login
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

      // 5b. Sync client total_closers_count and auto-expand closer_limit
      try {
        final clientRows = await adminDb
            .from('clients')
            .select('total_closers_count, closer_limit')
            .eq('id', clientId)
            .limit(1);
        if ((clientRows as List).isNotEmpty) {
          final clientRes = (clientRows as List).first as Map<String, dynamic>;
          final totalCount = (clientRes['total_closers_count'] as num?)?.toInt() ?? 0;
          final currentLimit = (clientRes['closer_limit'] as num?)?.toInt() ?? 25;
          final newTotal = totalCount + 1;
          await adminDb.from('clients').update({
            'total_closers_count': newTotal,
            if (newTotal > currentLimit) 'closer_limit': newTotal + 15,
          }).eq('id', clientId);
          debugPrint('[CLIENT_PORTAL] 📈 Client closer count incremented to $newTotal (Limit: ${newTotal > currentLimit ? newTotal + 15 : currentLimit})');
        }
      } catch (clientErr) {
        debugPrint('[CLIENT_PORTAL] ⚠️ Error syncing client closer stats: $clientErr');
      }

      // 6. Register in-memory session for immediate local/test authentication
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
        closerCode: effectiveCloserCode,
        avatarUrl: avatarUrl,
      );
      AuthRemoteDataSourceImpl.registerUserInMemory(closerUser, rawPassword);

      return newCloser;
    } catch (upsertErr) {
      // Rollback on failure to prevent orphaned records
      debugPrint('[CLIENT_PORTAL] ❌ Upsert error during closer onboarding: $upsertErr. Initiating rollback.');
      try {
        await adminDb.from('client_closers').delete().eq('id', closerId);
      } catch (_) {}
      try {
        await adminDb.from('users').delete().eq('id', authUserId);
      } catch (_) {}
      if (createdNewAuthUser) {
        try {
          await adminDb.auth.admin.deleteUser(authUserId);
        } catch (_) {}
      }
      rethrow;
    }
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
    var targetUserId = userId;
    if (targetUserId == null || targetUserId.isEmpty) {
      try {
        final row = await adminDb.from('client_closers').select('user_id').eq('id', closerId).maybeSingle();
        targetUserId = row?['user_id']?.toString();
      } catch (_) {}
    }

    if (targetUserId != null && targetUserId.isNotEmpty) {
      try {
        await adminDb.auth.admin.updateUserById(
          targetUserId,
          attributes: AdminUserAttributes(password: newPassword),
        );
      } catch (authErr) {
        debugPrint('[CLIENT_PORTAL] ⚠️ resetCloserPassword auth admin error: $authErr');
      }
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
    bool? isCommissionEnabled,
    String? bankName,
    String? accountNumber,
    String? accountName,
    List<String>? assignedProductIds,
    List<String>? assignedProductNames,
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
        if (isCommissionEnabled != null) 'is_commission_enabled': isCommissionEnabled,
        if (bankName != null) 'bank_name': bankName,
        if (accountNumber != null) 'account_number': accountNumber,
        if (accountName != null) 'account_name': accountName,
        if (assignedProductIds != null) 'assigned_product_ids': assignedProductIds,
        if (assignedProductNames != null) 'assigned_product_names': assignedProductNames,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', closerId);
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] ⚠️ Notice updating closer with new columns: $e. Falling back to core columns.');
      await adminDb.from('client_closers').update({
        if (fullName != null) 'full_name': fullName,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (commissionRate != null) 'commission_rate': commissionRate,
        if (dailyCallTarget != null) 'daily_call_target': dailyCallTarget,
        if (isActive != null) 'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', closerId);
    }

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
  Future<List<ClientCloserPayout>> fetchCloserPayouts(String closerId) async {
    final client = _getClient();
    try {
      final res = await client
          .from('closer_payouts')
          .select('*')
          .eq('closer_id', closerId)
          .order('created_at', ascending: false);
      return (res as List).map((e) => ClientCloserPayout.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] ⚠️ fetchCloserPayouts notice: $e');
      return [];
    }
  }

  @override
  Future<List<ClientCloserPayout>> fetchClientCloserPayouts(String clientId) async {
    final client = _getClient();
    try {
      final res = await client
          .from('closer_payouts')
          .select('*')
          .eq('client_id', clientId)
          .order('created_at', ascending: false);
      return (res as List).map((e) => ClientCloserPayout.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] ⚠️ fetchClientCloserPayouts notice: $e');
      return [];
    }
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
    final adminDb = _getAdminClient();
    try {
      final rpcRes = await adminDb.rpc('fn_disburse_closer_payout', params: {
        'p_closer_id': closerId,
        'p_client_id': clientId,
        'p_amount': amount,
        'p_bank_name': bankName,
        'p_account_number': accountNumber,
        'p_account_name': accountName,
        'p_disbursement_ref': disbursementRef ?? '',
        'p_proof_of_payment_url': proofOfPaymentUrl ?? '',
        'p_notes': notes ?? '',
      });
      if (rpcRes != null && rpcRes['payout_id'] != null) {
        final payoutId = rpcRes['payout_id'].toString();
        final inserted = await adminDb.from('closer_payouts').select('*').eq('id', payoutId).maybeSingle();
        if (inserted != null) {
          return ClientCloserPayout.fromJson(inserted);
        }
      }
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] ℹ️ fn_disburse_closer_payout RPC not found, falling back to direct table write: $e');
    }

    final now = DateTime.now();
    final payoutNumber = 'CPAY-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecond.toString().padLeft(4, '0')}';
    final payout = ClientCloserPayout(
      id: '',
      closerId: closerId,
      clientId: clientId,
      payoutNumber: payoutNumber,
      amount: amount,
      bankName: bankName,
      accountNumber: accountNumber,
      accountName: accountName,
      disbursementRef: disbursementRef,
      proofOfPaymentUrl: proofOfPaymentUrl,
      status: 'remitted',
      disbursedAt: now,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );

    final payload = payout.toJson();
    payload.remove('id');

    try {
      final res = await adminDb.from('closer_payouts').insert(payload).select().single();
      try {
        final closerRow = await adminDb.from('client_closers').select('total_paid_commission, unpaid_commission_balance').eq('id', closerId).maybeSingle();
        if (closerRow != null) {
          final currentPaid = (closerRow['total_paid_commission'] as num?)?.toDouble() ?? 0.0;
          final currentUnpaid = (closerRow['unpaid_commission_balance'] as num?)?.toDouble() ?? 0.0;
          await adminDb.from('client_closers').update({
            'total_paid_commission': currentPaid + amount,
            'unpaid_commission_balance': (currentUnpaid - amount).clamp(0.0, double.infinity),
            'updated_at': now.toIso8601String(),
          }).eq('id', closerId);
        }
      } catch (_) {}
      return ClientCloserPayout.fromJson(res);
    } catch (err) {
      debugPrint('[CLIENT_PORTAL] ❌ Error inserting closer_payouts: $err');
      return payout.copyWith(id: 'CPAY-LOCAL-${now.millisecondsSinceEpoch}');
    }
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
    final adminDb = _getAdminClient();
    final now = DateTime.now();
    final payoutNumber = 'CREQ-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecond.toString().padLeft(4, '0')}';
    final payout = ClientCloserPayout(
      id: '',
      closerId: closerId,
      clientId: clientId,
      payoutNumber: payoutNumber,
      amount: amount,
      bankName: bankName,
      accountNumber: accountNumber,
      accountName: accountName,
      status: 'pending',
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );

    final payload = payout.toJson();
    payload.remove('id');

    try {
      final res = await adminDb.from('closer_payouts').insert(payload).select().single();
      return ClientCloserPayout.fromJson(res);
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] ⚠️ requestCloserPayout error: $e');
      return payout.copyWith(id: 'CREQ-LOCAL-${now.millisecondsSinceEpoch}');
    }
  }

  @override
  Future<void> confirmCloserPayout({
    required String payoutId,
    String? notes,
  }) async {
    final adminDb = _getAdminClient();
    try {
      await adminDb.rpc('fn_closer_confirm_payout', params: {
        'p_payout_id': payoutId,
        'p_notes': notes ?? '',
      });
      return;
    } catch (_) {}

    try {
      await adminDb.from('closer_payouts').update({
        'status': 'completed',
        'confirmed_at': DateTime.now().toIso8601String(),
        if (notes != null) 'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', payoutId);
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] ❌ Error confirming closer payout: $e');
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
    if (clientId.trim().isEmpty || !UuidHelper.isUuid(clientId)) return [];
    final adminDb = _getAdminClient();
    try {
      final response = await adminDb
          .from('client_settlements')
          .select('*')
          .eq('client_id', clientId)
          .order('settled_at', ascending: false);

      return (response as List)
          .map((item) => ClientSettlement.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] ❌ fetchClientSettlements error: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> fetchMerchantAssetCustody(String clientId) async {
    if (clientId.trim().isEmpty || !UuidHelper.isUuid(clientId)) return {};
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

  @override
  Future<bool> approveSettlement({
    required String settlementId,
    required String clientId,
    String? notes,
  }) async {
    final adminDb = _getAdminClient();
    try {
      // 1. Try stored procedure
      try {
        final res = await adminDb.rpc('fn_merchant_approve_settlement', params: {
          'p_settlement_id': settlementId,
          'p_client_id': clientId,
          if (notes != null) 'p_approval_notes': notes,
        });
        if (res != null && (res as Map)['success'] == true) {
          debugPrint('[CLIENT_PORTAL] ✅ Settlement approved via RPC: $settlementId');
          return true;
        }
      } catch (rpcErr) {
        debugPrint('[CLIENT_PORTAL] ℹ️ RPC notice ($rpcErr). Falling back to direct update.');
      }

      // 2. Direct PostgREST update fallback
      final noteSuffix = notes != null ? ' - $notes' : '';
      await adminDb.from('client_settlements').update({
        'status': 'completed',
        'notes': 'Merchant Approved & Confirmed on ${DateTime.now().toIso8601String()}$noteSuffix',
        'settled_at': DateTime.now().toIso8601String(),
      }).eq('id', settlementId);

      debugPrint('[CLIENT_PORTAL] ✅ Settlement approved via direct update: $settlementId');
      return true;
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] ❌ approveSettlement error: $e');
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
    final adminDb = _getAdminClient();
    try {
      final note = '[MERCHANT_REJECTED]: $reason${proofUrl != null ? " | Proof: $proofUrl" : ""}';
      await adminDb.from('client_settlements').update({
        'status': 'rejected',
        'notes': note,
      }).eq('id', settlementId);
      debugPrint('[CLIENT_PORTAL] 🚫 Settlement rejected/disputed: $settlementId');
      return true;
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] ❌ rejectSettlement error: $e');
      return false;
    }
  }

  // ===========================================================================
  // INVENTORY & LANDED COST SUPPLY MANAGEMENT IMPLEMENTATION
  // ===========================================================================

  @override
  Future<List<ClientSupplier>> fetchSuppliers(String clientId) async {
    if (clientId.trim().isEmpty) return [];
    final adminDb = _getAdminClient();
    try {
      final response = await adminDb
          .from('client_suppliers')
          .select('*')
          .eq('client_id', clientId)
          .order('created_at', ascending: false);

      final remoteSuppliers = response
          .map((item) => ClientSupplier.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();

      final combined = <ClientSupplier>[...remoteSuppliers];
      for (final s in _inMemorySuppliers.where((s) => s.clientId == clientId)) {
        if (!combined.any((c) => c.id == s.id || c.supplierName.toLowerCase() == s.supplierName.toLowerCase())) {
          combined.add(s);
        }
      }
      return combined;
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] ⚠️ Remote fetchSuppliers: $e');
      return _inMemorySuppliers.where((s) => s.clientId == clientId).toList();
    }
  }

  @override
  Future<ClientSupplier> createSupplier(ClientSupplier supplier) async {
    final adminDb = _getAdminClient();
    final withId = (supplier.id.isNotEmpty && UuidHelper.isUuid(supplier.id))
        ? supplier
        : supplier.copyWith(id: UuidHelper.generate());
    final payload = Map<String, dynamic>.from(withId.toJson())
      ..remove('lead_time_days');
    try {
      final res = await adminDb
          .from('client_suppliers')
          .insert(payload)
          .select()
          .single();
      final created = ClientSupplier.fromJson(Map<String, dynamic>.from(res as Map));
      _inMemorySuppliers.removeWhere((s) => s.id == created.id);
      _inMemorySuppliers.insert(0, created);
      return created;
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] ⚠️ Remote createSupplier: $e (using local mock echo)');
      _inMemorySuppliers.removeWhere((s) => s.id == withId.id);
      _inMemorySuppliers.insert(0, withId);
      return withId;
    }
  }

  @override
  Future<void> updateSupplier(ClientSupplier supplier) async {
    final adminDb = _getAdminClient();
    final payload = Map<String, dynamic>.from(supplier.toJson())
      ..remove('id')
      ..remove('lead_time_days')
      ..remove('created_at');
    try {
      await adminDb
          .from('client_suppliers')
          .update(payload)
          .eq('id', supplier.id);
      _inMemorySuppliers.removeWhere((s) => s.id == supplier.id);
      _inMemorySuppliers.insert(0, supplier);
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] ⚠️ Remote updateSupplier error: $e');
      _inMemorySuppliers.removeWhere((s) => s.id == supplier.id);
      _inMemorySuppliers.insert(0, supplier);
    }
  }

  @override
  Future<List<ClientStockInvoice>> fetchStockInvoices(String clientId) async {
    if (clientId.trim().isEmpty) return [];
    final adminDb = _getAdminClient();
    try {
      final res = await adminDb
          .from('client_stock_invoices')
          .select('*, client_stock_invoice_items(*)')
          .eq('client_id', clientId)
          .order('entry_date', ascending: false);

      final remoteInvoices = res
          .map((item) => ClientStockInvoice.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();

      final combined = <ClientStockInvoice>[...remoteInvoices];
      for (final mem in _inMemoryStockInvoices.where((i) => i.clientId == clientId)) {
        if (!combined.any((c) => c.id == mem.id || c.invoiceNumber == mem.invoiceNumber)) {
          combined.add(mem);
        }
      }
      return combined;
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] ⚠️ Remote fetchStockInvoices: $e');
      return _inMemoryStockInvoices.where((i) => i.clientId == clientId).toList();
    }
  }



  @override
  Future<ClientStockInvoice> raiseStockInvoice({
    required ClientStockInvoice invoice,
    required List<ClientStockInvoiceItem> items,
  }) async {
    final adminDb = _getAdminClient();
    final withId = (invoice.id.isNotEmpty && UuidHelper.isUuid(invoice.id))
        ? invoice
        : invoice.copyWith(id: UuidHelper.generate());
    try {
      final invoicePayload = withId.toJson();
      invoicePayload.remove('client_stock_invoice_items');
      if (invoicePayload['supplier_name'] == null || invoicePayload['supplier_name'].toString().trim().isEmpty) {
        invoicePayload['supplier_name'] = 'Direct Procurement Partner';
      }

      final invRes = await adminDb
          .from('client_stock_invoices')
          .insert(invoicePayload)
          .select()
          .single();

      final createdInv = ClientStockInvoice.fromJson(Map<String, dynamic>.from(invRes as Map));

      final itemsPayload = items.map((i) {
        final itemMap = i.toJson();
        itemMap['invoice_id'] = createdInv.id;
        if (itemMap['id'] == null || itemMap['id'].toString().isEmpty || !UuidHelper.isUuid(itemMap['id'].toString())) {
          itemMap.remove('id');
        }
        return itemMap;
      }).toList();

      await adminDb.from('client_stock_invoice_items').insert(itemsPayload);

      // Automatically register the physical DC consignment handshake in stock_transfers
      try {
        await adminDb.rpc('fn_create_dc_consignment_for_intake_invoice', params: {
          'p_invoice_id': createdInv.id,
          'p_sender_id': createdInv.clientId,
          'p_sender_name': createdInv.supplierName,
        });
        debugPrint('[CLIENT_PORTAL] ✅ Registered DC consignment handshake for invoice: ${createdInv.id}');
      } catch (handshakeErr) {
        debugPrint('[CLIENT_PORTAL] ⚠️ rpc fn_create_dc_consignment_for_intake_invoice: $handshakeErr');
      }

      final result = createdInv.copyWith(items: items);
      _inMemoryStockInvoices.removeWhere((i) => i.id == result.id);
      _inMemoryStockInvoices.insert(0, result);
      return result;
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] ⚠️ Remote raiseStockInvoice: $e (returning local instance)');
      final result = withId.copyWith(items: items);
      _inMemoryStockInvoices.removeWhere((i) => i.id == result.id);
      _inMemoryStockInvoices.insert(0, result);
      return result;
    }
  }

  @override
  Future<void> attachPaymentReceipt({
    required String invoiceId,
    required String receiptUrl,
  }) async {
    final adminDb = _getAdminClient();
    try {
      // 1. Try updating payment_receipt_url column
      try {
        await adminDb
            .from('client_stock_invoices')
            .update({'payment_receipt_url': receiptUrl})
            .eq('id', invoiceId);
        debugPrint('[CLIENT_PORTAL] ✅ Receipt attached via payment_receipt_url column: $invoiceId');
      } catch (colErr) {
        // 2. Fallback: embed into notes column
        debugPrint('[CLIENT_PORTAL] ℹ️ Updating receipt in notes fallback ($colErr)...');
        final current = await adminDb
            .from('client_stock_invoices')
            .select('notes')
            .eq('id', invoiceId)
            .maybeSingle();
        final currentNotes = current?['notes']?.toString() ?? '';
        final cleanNotes = currentNotes.replaceAll(RegExp(r'\[RECEIPT:\s*[^\]]+\]'), '').trim();
        final updatedNotes = cleanNotes.isNotEmpty
            ? '$cleanNotes\n[RECEIPT: $receiptUrl]'
            : '[RECEIPT: $receiptUrl]';
        await adminDb
            .from('client_stock_invoices')
            .update({'notes': updatedNotes})
            .eq('id', invoiceId);
        debugPrint('[CLIENT_PORTAL] ✅ Receipt attached via notes: $invoiceId');
      }

      // Update in-memory cache if present
      final idx = _inMemoryStockInvoices.indexWhere((i) => i.id == invoiceId);
      if (idx >= 0) {
        final old = _inMemoryStockInvoices[idx];
        _inMemoryStockInvoices[idx] = old.copyWith(paymentReceiptUrl: receiptUrl);
      }
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] ⚠️ attachPaymentReceipt: $e');
      final idx = _inMemoryStockInvoices.indexWhere((i) => i.id == invoiceId);
      if (idx >= 0) {
        final old = _inMemoryStockInvoices[idx];
        _inMemoryStockInvoices[idx] = old.copyWith(paymentReceiptUrl: receiptUrl);
      }
    }
  }

  @override
  Future<List<ClientStockBalance>> fetchStockBalances(
    String clientId, {
    String? warehouseFilter,
    String? itemFilter,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (clientId.trim().isEmpty) return [];
    final adminDb = _getAdminClient();
    try {
      // 1. If date range is specified, query dynamic RPC for opening/closing balance over period
      if (startDate != null && endDate != null) {
        try {
          final startStr = '${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
          final endStr = '${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
          final rpcRes = await adminDb.rpc('fn_get_client_stock_balance_period', params: {
            'p_client_id': clientId,
            'p_start_date': startStr,
            'p_end_date': endStr,
            'p_warehouse': (warehouseFilter != null && warehouseFilter != 'all' && warehouseFilter.isNotEmpty)
                ? warehouseFilter
                : 'All Warehouses',
            'p_item_group': 'All Item Groups',
          }).timeout(const Duration(seconds: 8));

          if (rpcRes is List) {
            return rpcRes
                .map((item) => ClientStockBalance.fromJson(Map<String, dynamic>.from(item as Map)))
                .toList();
          }
        } catch (rpcErr) {
          debugPrint('[CLIENT_PORTAL] ℹ️ RPC period stock balance notice: $rpcErr (falling back to snapshot)');
        }
      }

      var query = adminDb
          .from('client_stock_balances')
          .select('*')
          .eq('client_id', clientId);

      if (warehouseFilter != null && warehouseFilter != 'all' && warehouseFilter.isNotEmpty) {
        query = query.eq('warehouse', warehouseFilter);
      }
      if (itemFilter != null && itemFilter != 'all' && itemFilter.isNotEmpty) {
        query = query.eq('item_name', itemFilter);
      }

      final res = await query.order('balance_value', ascending: false);
      final remoteBalances = res
          .map((item) => ClientStockBalance.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();

      final combined = <ClientStockBalance>[...remoteBalances];
      for (final mem in _inMemoryStockBalances.where((b) => b.clientId == clientId)) {
        if (!combined.any((c) => c.itemCode == mem.itemCode && c.warehouse == mem.warehouse)) {
          combined.add(mem);
        }
      }

      var filtered = combined;
      if (warehouseFilter != null && warehouseFilter != 'all' && warehouseFilter.isNotEmpty) {
        filtered = filtered.where((b) => b.warehouse.toLowerCase().contains(warehouseFilter.toLowerCase())).toList();
      }
      if (itemFilter != null && itemFilter != 'all' && itemFilter.isNotEmpty) {
        filtered = filtered.where((b) => b.itemName.toLowerCase() == itemFilter.toLowerCase()).toList();
      }
      return filtered;
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] ⚠️ Remote fetchStockBalances: $e');
      return _inMemoryStockBalances.where((b) => b.clientId == clientId).toList();
    }
  }


  @override
  Future<void> importStockBalanceCsv(String clientId, String csvContent) async {
    final adminDb = _getAdminClient();
    final lines = csvContent.split('\n');
    if (lines.length < 2) return;

    final header = lines.first.split(',').map((c) => c.trim().replaceAll('"', '')).toList();
    final int itemCodeIdx = header.indexOf('Item');
    final int itemNameIdx = header.indexOf('Item Name');
    final int itemGroupIdx = header.indexOf('Item Group');
    final int whIdx = header.indexOf('Warehouse');
    final int uomIdx = header.indexOf('Stock UOM');
    final int balQtyIdx = header.indexOf('Balance Qty');
    final int balValIdx = header.indexOf('Balance Value');
    final int openQtyIdx = header.indexOf('Opening Qty');
    final int openValIdx = header.indexOf('Opening Value');
    final int inQtyIdx = header.indexOf('In Qty');
    final int inValIdx = header.indexOf('In Value');
    final int outQtyIdx = header.indexOf('Out Qty');
    final int outValIdx = header.indexOf('Out Value');
    final int rateIdx = header.indexOf('Valuation Rate');
    final int reservedIdx = header.indexOf('Reserved Stock');
    final int companyIdx = header.indexOf('Company');

    if ((itemCodeIdx < 0 && itemNameIdx < 0) || whIdx < 0) return;

    final List<Map<String, dynamic>> records = [];
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final cols = line.split(',');
      if (cols.length <= whIdx) continue;

      String itemCode = itemCodeIdx >= 0 && cols.length > itemCodeIdx ? cols[itemCodeIdx].trim().replaceAll('"', '') : '';
      String itemName = itemNameIdx >= 0 && cols.length > itemNameIdx ? cols[itemNameIdx].trim().replaceAll('"', '') : '';
      if (itemName.isEmpty && itemCode.isNotEmpty) {
        itemName = itemCode;
      }
      if (itemCode.isEmpty && itemName.isNotEmpty) {
        itemCode = 'SKU-${itemName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase().padRight(4, 'X').substring(0, 4)}';
      }
      final warehouse = cols[whIdx].trim().replaceAll('"', '');
      if (itemCode.isEmpty || warehouse.isEmpty) continue;

      final itemGroup = itemGroupIdx >= 0 && cols.length > itemGroupIdx ? cols[itemGroupIdx].trim().replaceAll('"', '') : 'Novacare';
      final stockUom = uomIdx >= 0 && cols.length > uomIdx ? cols[uomIdx].trim().replaceAll('"', '') : 'Nos';
      final balQty = balQtyIdx >= 0 && cols.length > balQtyIdx ? double.tryParse(cols[balQtyIdx].trim()) ?? 0.0 : 0.0;
      final rate = rateIdx >= 0 && cols.length > rateIdx ? double.tryParse(cols[rateIdx].trim()) ?? 0.0 : 0.0;
      final balVal = balValIdx >= 0 && cols.length > balValIdx ? double.tryParse(cols[balValIdx].trim()) ?? (balQty * rate) : (balQty * rate);
      final openQty = openQtyIdx >= 0 && cols.length > openQtyIdx ? double.tryParse(cols[openQtyIdx].trim()) ?? 0.0 : 0.0;
      final openVal = openValIdx >= 0 && cols.length > openValIdx ? double.tryParse(cols[openValIdx].trim()) ?? 0.0 : 0.0;
      final inQty = inQtyIdx >= 0 && cols.length > inQtyIdx ? double.tryParse(cols[inQtyIdx].trim()) ?? 0.0 : 0.0;
      final inVal = inValIdx >= 0 && cols.length > inValIdx ? double.tryParse(cols[inValIdx].trim()) ?? 0.0 : 0.0;
      final outQty = outQtyIdx >= 0 && cols.length > outQtyIdx ? double.tryParse(cols[outQtyIdx].trim()) ?? 0.0 : 0.0;
      final outVal = outValIdx >= 0 && cols.length > outValIdx ? double.tryParse(cols[outValIdx].trim()) ?? 0.0 : 0.0;
      final reserved = reservedIdx >= 0 && cols.length > reservedIdx ? double.tryParse(cols[reservedIdx].trim()) ?? 0.0 : 0.0;
      final company = companyIdx >= 0 && cols.length > companyIdx ? cols[companyIdx].trim().replaceAll('"', '') : 'Novacare Ltd';

      final balance = ClientStockBalance(
        id: 'imp-${DateTime.now().microsecondsSinceEpoch}-$i',
        clientId: clientId,
        itemCode: itemCode,
        itemName: itemName,
        itemGroup: itemGroup,
        warehouse: warehouse,
        stockUom: stockUom,
        openingQty: openQty,
        openingValue: openVal,
        inQty: inQty,
        inValue: inVal,
        outQty: outQty,
        outValue: outVal,
        balanceQty: balQty,
        balanceValue: balVal,
        valuationRate: rate,
        reservedStock: reserved,
        company: company,
        updatedAt: DateTime.now(),
      );

      _inMemoryStockBalances.removeWhere((b) => b.itemCode == itemCode && b.warehouse == warehouse);
      _inMemoryStockBalances.insert(0, balance);

      records.add({
        'client_id': clientId,
        'item_code': itemCode,
        'item_name': itemName,
        'item_group': itemGroup,
        'warehouse': warehouse,
        'stock_uom': stockUom,
        'balance_qty': balQty,
        'balance_value': balVal,
        'opening_qty': openQty,
        'opening_value': openVal,
        'in_qty': inQty,
        'in_value': inVal,
        'out_qty': outQty,
        'out_value': outVal,
        'valuation_rate': rate,
        'reserved_stock': reserved,
        'company': company,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    if (records.isNotEmpty) {
      try {
        await adminDb.from('client_stock_balances').upsert(records);
      } catch (e) {
        debugPrint('[CLIENT_PORTAL] ⚠️ Remote importStockBalanceCsv upsert: $e');
      }
    }
  }

  @override
  Future<List<StockHolderCustodyEntity>> fetchProductHoldersCustody(
    String clientId, {
    String? productId,
    DateTime? startDate,
    DateTime? endDate,
    String? state,
    String? lga,
  }) async {
    if (clientId.trim().isEmpty) return [];
    final adminDb = _getAdminClient();

    // 1. Try querying PostgreSQL RPC fn_get_product_holders_custody
    try {
      final startStr = startDate != null
          ? '${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}'
          : null;
      final endStr = endDate != null
          ? '${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}'
          : null;

      final rpcRes = await adminDb.rpc('fn_get_product_holders_custody', params: {
        'p_client_id': clientId,
        'p_product_id': (productId != null && productId.isNotEmpty && productId != 'all') ? productId : null,
        'p_start_date': startStr,
        'p_end_date': endStr,
        'p_state': (state != null && state != 'All States' && state.isNotEmpty) ? state : null,
        'p_lga': (lga != null && lga != 'All LGAs' && lga.isNotEmpty) ? lga : null,
      }).timeout(const Duration(seconds: 8));

      if (rpcRes is List && rpcRes.isNotEmpty) {
        return rpcRes
            .map((item) => StockHolderCustodyEntity.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (rpcErr) {
      debugPrint('[CLIENT_PORTAL] ℹ️ RPC fn_get_product_holders_custody notice: $rpcErr (using synthesized custody ledger)');
    }


    // 2. Database-driven dynamic physical custody breakdown from client_stock_balances
    try {
      final balances = await fetchStockBalances(
        clientId,
        itemFilter: (productId != null && productId.isNotEmpty && productId != 'all') ? null : null,
      );

      // Load live distribution centers to resolve authentic facility metadata
      final Map<String, Map<String, dynamic>> dcLookup = {};
      try {
        final dcsRes = await adminDb.from('distribution_centers').select('id, name, code, state, city, contact_phone, is_grand_dc, is_hub, operating_zones');
        for (final raw in dcsRes) {
          final dc = Map<String, dynamic>.from(raw);
          final nameKey = (dc['name'] ?? '').toString().trim().toLowerCase();
          final codeKey = (dc['code'] ?? '').toString().trim().toLowerCase();
          final idKey = (dc['id'] ?? '').toString().trim().toLowerCase();
          if (nameKey.isNotEmpty) dcLookup[nameKey] = dc;
          if (codeKey.isNotEmpty) dcLookup[codeKey] = dc;
          if (idKey.isNotEmpty) dcLookup[idKey] = dc;
        }
      } catch (dcErr) {
        debugPrint('[CLIENT_PORTAL] ℹ️ DC lookup notice: $dcErr');
      }

      final List<StockHolderCustodyEntity> dynamicList = balances.map((bal) {
        final wh = bal.warehouse.trim().toLowerCase();
        
        // Find matching DC from live database
        Map<String, dynamic>? matchedDc = dcLookup[wh];
        if (matchedDc == null) {
          for (final entry in dcLookup.entries) {
            if (entry.key.length >= 3 && (wh.contains(entry.key) || entry.key.contains(wh))) {
              matchedDc = entry.value;
              break;
            }
          }
        }

        final st = matchedDc?['state']?.toString() ?? 'Federal Capital Territory';
        final lgaName = (matchedDc?['operating_zones'] is List && (matchedDc!['operating_zones'] as List).isNotEmpty)
            ? matchedDc['operating_zones'][0].toString()
            : (matchedDc?['city']?.toString() ?? 'Central');
        final city = matchedDc?['city']?.toString() ?? 'Main Hub';
        final phone = matchedDc?['contact_phone']?.toString() ?? '';
        final isGrand = matchedDc?['is_grand_dc'] == true;
        final isHub = matchedDc?['is_hub'] == true;

        final holderType = isGrand
            ? 'Grand DC'
            : (isHub ? 'Hub DC' : 'General DC');

        return StockHolderCustodyEntity(
          id: 'custody-${bal.id}',
          holderId: matchedDc?['id']?.toString() ?? bal.warehouse,
          holderName: matchedDc?['name']?.toString() ?? bal.warehouse,
          holderType: holderType,
          state: st,
          lga: lgaName,
          city: city,
          phone: phone,
          productId: bal.productId ?? bal.itemCode,
          productSku: bal.itemCode,
          productName: bal.itemName,
          openingQty: bal.openingQty.toInt(),
          openingValue: bal.openingValue,
          inQty: bal.inQty.toInt(),
          inValue: bal.inValue,
          outQty: bal.outQty.toInt(),
          outValue: bal.outValue,
          closingQty: bal.balanceQty.toInt(),
          closingValue: bal.balanceValue,
          valuationRate: bal.valuationRate,
          lastUpdated: bal.updatedAt,
          status: bal.balanceQty > 0 ? 'Active Custody' : 'Out of Stock',
        );
      }).toList();

      // Also query live agent_inventory for PDA positions from database
      try {
        final agentsRes = await adminDb
            .from('agent_inventory')
            .select('id, total_in_custody, available_count, product_id, updated_at, delivery_agents(id, agent_code, bank_account_name, operating_city, operating_state)')
            .gt('available_count', 0);
        for (final raw in agentsRes) {
          final row = Map<String, dynamic>.from(raw);
          final pId = row['product_id']?.toString() ?? '';
          if (productId != null && productId.isNotEmpty && productId != 'all' && pId != productId) {
            continue;
          }
          final da = row['delivery_agents'] is Map ? Map<String, dynamic>.from(row['delivery_agents'] as Map) : null;
          final daName = da?['bank_account_name']?.toString() ?? 'Dispatch PDA';
          final daCode = da?['agent_code']?.toString() ?? 'PDA';
          final daCity = da?['operating_city']?.toString() ?? 'Central';
          final daState = da?['operating_state']?.toString() ?? 'Federal Capital Territory';
          final daPhone = da?['phone']?.toString() ?? '';
          final qty = (row['available_count'] as num?)?.toInt() ?? 0;

          dynamicList.add(StockHolderCustodyEntity(
            id: 'pda-custody-${row['id']}',
            holderId: da?['id']?.toString() ?? row['id'].toString(),
            holderName: '$daName ($daCode)',
            holderType: 'PDA / Dispatch Personnel',
            state: daState,
            lga: daCity,
            city: daCity,
            phone: daPhone,
            productId: pId,
            productSku: '',
            productName: '',
            openingQty: qty,
            openingValue: 0.0,
            inQty: 0,
            inValue: 0.0,
            outQty: 0,
            outValue: 0.0,
            closingQty: qty,
            closingValue: 0.0,
            valuationRate: 0.0,
            status: 'Active Custody',
            lastUpdated: DateTime.tryParse(row['updated_at']?.toString() ?? '') ?? DateTime.now(),
          ));
        }
      } catch (agentErr) {
        debugPrint('[CLIENT_PORTAL] ℹ️ Agent inventory notice: $agentErr');
      }

      return dynamicList.where((h) {
        if (productId != null && productId.isNotEmpty && productId != 'all') {
          final pId = productId.trim().toLowerCase();
          final matches = h.productId.toLowerCase() == pId ||
              h.productSku.toLowerCase() == pId ||
              h.productName.toLowerCase() == pId;
          if (!matches) return false;
        }
        if (state != null && state.isNotEmpty && state != 'All States') {
          if (h.state.toLowerCase() != state.toLowerCase()) return false;
        }
        if (lga != null && lga.isNotEmpty && lga != 'All LGAs') {
          if (!h.lga.toLowerCase().contains(lga.toLowerCase())) return false;
        }
        return true;
      }).toList();
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] ⚠️ Error generating dynamic custody list: $e');
      return [];
    }
  }

  @override
  Future<List<ClientMarketer>> fetchMarketers(String clientId) async {
    final client = _getClient();
    final response = await client
        .from('client_marketers')
        .select('*')
        .eq('client_id', clientId)
        .order('created_at', ascending: false);

    final List<ClientMarketer> list = [];
    for (final item in response as List) {
      try {
        list.add(ClientMarketer.fromJson(item as Map<String, dynamic>));
      } catch (_) {}
    }
    return list;
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
    final cleanEmail = email.trim().toLowerCase();
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '').trim();
    final rawPassword = (password != null && password.trim().isNotEmpty) ? password.trim() : 'Marketer123!';
    final adminDb = _getAdminClient();

    // 1. Pre-flight check & cleanup of any orphaned/partial marketer records
    try {
      final existingMarketersByEmail = await adminDb
          .from('client_marketers')
          .select('id, email, user_id')
          .eq('email', cleanEmail)
          .limit(2);

      if ((existingMarketersByEmail as List).isNotEmpty) {
        for (final row in (existingMarketersByEmail as List)) {
          final existingUserId = row['user_id']?.toString();
          final List hasRealUser = existingUserId != null && existingUserId.isNotEmpty
              ? (await adminDb.from('users').select('id').eq('id', existingUserId).limit(1)) as List
              : const [];

          if (hasRealUser.isEmpty) {
            // Orphaned record from previous partial failure — clean it up so onboarding succeeds
            debugPrint('[CLIENT_PORTAL] 🧹 Cleaning up orphaned marketer record for $cleanEmail');
            await adminDb.from('client_marketers').delete().eq('id', row['id']);
          } else {
            throw Exception("A digital marketer with email '$cleanEmail' is already registered in the team.");
          }
        }
      }
    } catch (e) {
      if (e.toString().contains('already registered')) rethrow;
      debugPrint('[CLIENT_PORTAL] ℹ️ Pre-flight marketer check note: $e');
    }

    // 2. Guaranteed-Unique Marketer Code Generation
    final existingCodesRes = await adminDb
        .from('client_marketers')
        .select('marketer_code');

    final Set<String> existingCodes = {};
    for (final row in (existingCodesRes as List)) {
      final code = row['marketer_code']?.toString().trim().toUpperCase();
      if (code != null && code.isNotEmpty) {
        existingCodes.add(code);
      }
    }

    String prefix = isSupervisor ? 'MKT-SUP-' : 'MKT-NOVA-';
    if (marketerCode != null && marketerCode.trim().isNotEmpty) {
      final match = RegExp(r'^(.*?)(\d+)$').firstMatch(marketerCode.trim());
      if (match != null && match.group(1)!.isNotEmpty) {
        prefix = match.group(1)!;
      } else {
        prefix = marketerCode.trim().endsWith('-') ? marketerCode.trim() : '${marketerCode.trim()}-';
      }
    }

    int maxSuffix = 0;
    for (final code in existingCodes) {
      if (code.startsWith(prefix.toUpperCase())) {
        final numPart = code.substring(prefix.length);
        final val = int.tryParse(numPart);
        if (val != null && val > maxSuffix) {
          maxSuffix = val;
        }
      }
    }

    int nextNum = maxSuffix >= 100 ? maxSuffix + 1 : (maxSuffix > 0 ? maxSuffix + 1 : 101);
    String candidateCode = '$prefix${nextNum.toString().padLeft(3, '0')}';
    while (existingCodes.contains(candidateCode.toUpperCase())) {
      nextNum++;
      candidateCode = '$prefix${nextNum.toString().padLeft(3, '0')}';
    }
    final effectiveCode = candidateCode;
    debugPrint('[CLIENT_PORTAL] 🏷️ Resolved guaranteed unique marketer code: $effectiveCode');

    final marketerId = _generateUuid();
    final roleStr = isSupervisor ? 'marketing_supervisor' : 'marketer';
    String authUserId = _generateUuid();
    bool createdNewAuthUser = false;

    // 3. Provision Supabase Auth User with confirmed status
    try {
      final authRes = await adminDb.auth.admin.createUser(
        AdminUserAttributes(
          email: cleanEmail,
          password: rawPassword,
          emailConfirm: true,
          userMetadata: {
            'role': roleStr,
            'client_id': clientId,
            'full_name': fullName.trim(),
            'is_supervisor': isSupervisor,
            'marketer_code': effectiveCode,
          },
        ),
      );
      if (authRes.user != null) {
        authUserId = authRes.user!.id;
        createdNewAuthUser = true;
        debugPrint('[CLIENT_PORTAL] 👤 Created Supabase Auth user for marketer: $authUserId');
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
                'role': roleStr,
                'client_id': clientId,
                'full_name': fullName.trim(),
                'is_supervisor': isSupervisor,
                'marketer_code': effectiveCode,
              },
            ),
          );
          authUserId = existing.id;
          debugPrint('[CLIENT_PORTAL] 🔄 Existing Supabase Auth Marketer user updated: $authUserId');
        } catch (listErr) {
          debugPrint('[CLIENT_PORTAL] ℹ️ Auth list/update note: $listErr');
          try {
            final existingUser = await adminDb.from('users').select('id').eq('email', cleanEmail).limit(1);
            if ((existingUser as List).isNotEmpty && existingUser.first['id'] != null) {
              authUserId = existingUser.first['id'].toString();
            }
          } catch (_) {}
        }
      } else {
        debugPrint('[CLIENT_PORTAL] ℹ️ Supabase Auth createUser note: $authErr');
      }
    }

    final nameParts = fullName.trim().split(' ');
    final fName = nameParts.isNotEmpty ? nameParts.first : 'Marketer';
    final lName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    // 4. CRITICAL: Upsert public.users BEFORE inserting into client_marketers!
    // This guarantees the foreign key constraint (user_id REFERENCES public.users(id)) is satisfied.
    try {
      try {
        await adminDb.from('users').upsert({
          'id': authUserId,
          'company_id': '11111111-1111-4111-8111-111111111111',
          'client_id': clientId,
          'email': cleanEmail,
          'phone_number': cleanPhone.isNotEmpty ? cleanPhone : phone.trim(),
          'first_name': fName,
          'last_name': lName,
          'role': roleStr,
          'is_active': true,
          'is_supervisor': isSupervisor,
          'marketer_id': marketerId,
          'marketer_code': effectiveCode,
        });
        debugPrint('[CLIENT_PORTAL] ✅ Users table record upserted: $authUserId ($cleanEmail)');
      } catch (userErr) {
        final errStr = userErr.toString().toLowerCase();
        debugPrint('[CLIENT_PORTAL] ⚠️ Warning upserting user: $userErr. Retrying without phone constraint.');
        if (errStr.contains('phone')) {
          await adminDb.from('users').upsert({
            'id': authUserId,
            'company_id': '11111111-1111-4111-8111-111111111111',
            'client_id': clientId,
            'email': cleanEmail,
            'first_name': fName,
            'last_name': lName,
            'role': roleStr,
            'is_active': true,
            'is_supervisor': isSupervisor,
            'marketer_id': marketerId,
            'marketer_code': effectiveCode,
          });
        } else {
          rethrow;
        }
      }

      // 5. Build and insert ClientMarketer entity
      final newMarketer = ClientMarketer(
        id: marketerId,
        clientId: clientId,
        userId: authUserId,
        marketerCode: effectiveCode,
        fullName: fullName.trim(),
        email: cleanEmail,
        phone: cleanPhone.isNotEmpty ? cleanPhone : phone.trim(),
        isSupervisor: isSupervisor,
        supervisorId: supervisorId,
        dailyAdSpendBudget: dailyAdSpendBudget,
        commissionModel: commissionModel,
        commissionRate: commissionRate,
        commissionPerFormSubmission: commissionPerFormSubmission > 0 ? commissionPerFormSubmission : commissionRate,
        commissionPerDeliveredOrder: commissionPerDeliveredOrder > 0 ? commissionPerDeliveredOrder : commissionRate,
        isCommissionEnabled: isCommissionEnabled,
        bankName: bankName ?? '',
        accountNumber: accountNumber ?? '',
        accountName: accountName ?? '',
        isActive: true,
        createdAt: DateTime.now(),
      );

      try {
        await adminDb.from('client_marketers').insert(newMarketer.toJson());
        debugPrint('[CLIENT_PORTAL] 🚀 Marketer inserted into client_marketers: $marketerId ($effectiveCode)');
      } catch (insertErr) {
        final errStr = insertErr.toString().toLowerCase();
        debugPrint('[CLIENT_PORTAL] ⚠️ Warning inserting marketer with full payload: $insertErr. Retrying with fallback.');

        // If foreign key constraint failed on user_id, decouple user_id temporarily, insert, then link back
        if (errStr.contains('foreign key') || errStr.contains('violates') || errStr.contains('user_id')) {
          debugPrint('[CLIENT_PORTAL] 🔄 Retrying marketer insert with decoupled user_id, then linking back');
          final decoupledMap = Map<String, dynamic>.from(newMarketer.toJson());
          decoupledMap['user_id'] = null;
          await adminDb.from('client_marketers').insert(decoupledMap);
          try {
            await adminDb.from('client_marketers').update({'user_id': authUserId}).eq('id', marketerId);
          } catch (linkErr) {
            debugPrint('[CLIENT_PORTAL] ⚠️ Deferred user_id linking note: $linkErr');
          }
        } else {
          final coreMap = Map<String, dynamic>.from(newMarketer.toJson());
          coreMap.remove('unpaid_commission_balance');
          coreMap.remove('total_paid_commission');
          coreMap.remove('total_commission_earned');
          await adminDb.from('client_marketers').insert(coreMap);
        }
      }

      // 6. Register in-memory session for immediate local/test authentication
      try {
        AuthRemoteDataSourceImpl.registerUserInMemory(
          UserModel(
            id: authUserId,
            authUserId: authUserId,
            email: cleanEmail,
            firstName: fName,
            lastName: lName,
            phone: cleanPhone.isNotEmpty ? cleanPhone : phone.trim(),
            role: roleStr,
            companyId: '11111111-1111-4111-8111-111111111111',
            clientId: clientId,
            marketerId: marketerId,
            marketerCode: effectiveCode,
            isSupervisor: isSupervisor,
          ),
          rawPassword,
        );
      } catch (_) {}

      return newMarketer;
    } catch (upsertErr) {
      debugPrint('[CLIENT_PORTAL] ❌ Fatal error during marketer onboarding: $upsertErr. Initiating rollback.');
      try {
        await adminDb.from('client_marketers').delete().eq('id', marketerId);
      } catch (_) {}
      try {
        await adminDb.from('users').delete().eq('id', authUserId);
      } catch (_) {}
      if (createdNewAuthUser) {
        try {
          await adminDb.auth.admin.deleteUser(authUserId);
        } catch (_) {}
      }
      rethrow;
    }
  }

  @override
  Future<void> updateMarketerStatus({required String marketerId, required bool isActive}) async {
    final adminDb = _getAdminClient();
    await adminDb.from('client_marketers').update({
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', marketerId);
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
    final adminDb = _getAdminClient();
    try {
      final res = await adminDb.rpc('fn_update_marketer_profile', params: {
        'p_marketer_id': marketerId,
        'p_full_name': fullName,
        'p_phone': phone,
        'p_avatar_url': avatarUrl,
        'p_bank_name': bankName,
        'p_account_number': accountNumber,
        'p_account_name': accountName,
      });

      if (res is Map && res['data'] is Map) {
        return ClientMarketer.fromJson(Map<String, dynamic>.from(res['data'] as Map));
      }
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] Notice calling fn_update_marketer_profile: $e');
    }

    final updateMap = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (fullName != null) updateMap['full_name'] = fullName;
    if (phone != null) updateMap['phone'] = phone;
    if (avatarUrl != null) updateMap['avatar_url'] = avatarUrl;
    if (bankName != null) updateMap['bank_name'] = bankName;
    if (accountNumber != null) updateMap['account_number'] = accountNumber;
    if (accountName != null) updateMap['account_name'] = accountName;

    final row = await adminDb
        .from('client_marketers')
        .update(updateMap)
        .eq('id', marketerId)
        .select()
        .single();

    return ClientMarketer.fromJson(row);
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
    final adminDb = _getAdminClient();
    final updateMap = <String, dynamic>{
      'full_name': fullName.trim(),
      'phone': phone.replaceAll(RegExp(r'[\s\-\(\)]'), '').trim(),
      'email': email.trim().toLowerCase(),
      'daily_ad_spend_budget': dailyAdSpendBudget,
      'commission_model': commissionModel,
      'commission_type': commissionModel,
      'commission_rate': commissionRate,
      'commission_per_form_submission': commissionPerFormSubmission > 0 ? commissionPerFormSubmission : commissionRate,
      'commission_per_delivered_order': commissionPerDeliveredOrder > 0 ? commissionPerDeliveredOrder : commissionRate,
      'is_commission_enabled': isCommissionEnabled,
      'is_supervisor': isSupervisor,
      'supervisor_id': isSupervisor ? null : supervisorId,
      'bank_name': bankName ?? '',
      'account_number': accountNumber ?? '',
      'account_name': accountName ?? '',
      'updated_at': DateTime.now().toIso8601String(),
    };

    final row = await adminDb
        .from('client_marketers')
        .update(updateMap)
        .eq('id', marketerId)
        .select()
        .single();

    final nameParts = fullName.trim().split(' ');
    final fName = nameParts.isNotEmpty ? nameParts.first : 'Marketer';
    final lName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
    await adminDb.from('users').update({
      'first_name': fName,
      'last_name': lName,
      'phone_number': phone,
      'email': email.trim().toLowerCase(),
      'is_supervisor': isSupervisor,
      'role': isSupervisor ? 'marketing_supervisor' : 'marketer',
    }).eq('marketer_id', marketerId);

    return ClientMarketer.fromJson(row);
  }

  @override
  Future<void> deleteMarketer(String marketerId) async {
    final adminDb = _getAdminClient();
    try {
      await adminDb.rpc('fn_delete_marketer', params: {'p_marketer_id': marketerId});
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] ℹ️ Error calling fn_delete_marketer, falling back to manual delete: $e');
      await adminDb.from('lead_forms').update({'marketer_id': null}).eq('marketer_id', marketerId);
      await adminDb.from('orders').update({'marketer_id': null}).eq('marketer_id', marketerId);
      await adminDb.from('client_marketers').update({'supervisor_id': null}).eq('supervisor_id', marketerId);
      await adminDb.from('client_marketers').delete().eq('id', marketerId);
    }
  }

  @override
  Future<void> resetMarketerPassword({
    required String marketerId,
    required String newPassword,
  }) async {
    final adminDb = _getAdminClient();
    try {
      final marketerRes = await adminDb.from('client_marketers').select('email').eq('id', marketerId).maybeSingle();
      final email = marketerRes?['email']?.toString();
      if (email != null && email.isNotEmpty) {
        final registered = AuthRemoteDataSourceImpl.getRegisteredUser(email);
        if (registered != null) {
          AuthRemoteDataSourceImpl.registerUserInMemory(registered, newPassword);
        }
      }
    } catch (_) {}
  }

  @override
  Future<List<ClientMarketerPayout>> fetchMarketerPayouts(String marketerId) async {
    final client = _getClient();
    try {
      final res = await client
          .from('marketer_payouts')
          .select('*')
          .eq('marketer_id', marketerId)
          .order('created_at', ascending: false);
      return (res as List).map((e) => ClientMarketerPayout.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] ⚠️ fetchMarketerPayouts notice: $e');
      return [];
    }
  }

  @override
  Future<List<ClientMarketerPayout>> fetchClientMarketerPayouts(String clientId) async {
    final client = _getClient();
    try {
      final res = await client
          .from('marketer_payouts')
          .select('*')
          .eq('client_id', clientId)
          .order('created_at', ascending: false);
      return (res as List).map((e) => ClientMarketerPayout.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] ⚠️ fetchClientMarketerPayouts notice: $e');
      return [];
    }
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
    final adminDb = _getAdminClient();
    try {
      final rpcRes = await adminDb.rpc('fn_disburse_marketer_payout', params: {
        'p_marketer_id': marketerId,
        'p_client_id': clientId,
        'p_amount': amount,
        'p_bank_name': bankName,
        'p_account_number': accountNumber,
        'p_account_name': accountName,
        'p_disbursement_ref': disbursementRef ?? '',
        'p_proof_of_payment_url': proofOfPaymentUrl ?? '',
        'p_notes': notes ?? '',
      });
      if (rpcRes != null && rpcRes['payout_id'] != null) {
        final payoutId = rpcRes['payout_id'].toString();
        final inserted = await adminDb.from('marketer_payouts').select('*').eq('id', payoutId).maybeSingle();
        if (inserted != null) {
          return ClientMarketerPayout.fromJson(inserted);
        }
      }
    } catch (e) {
      debugPrint('[CLIENT_PORTAL] ℹ️ fn_disburse_marketer_payout RPC notice: $e');
    }

    final now = DateTime.now();
    final payoutNumber = 'MPAY-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecond.toString().padLeft(4, '0')}';
    final payload = {
      'marketer_id': marketerId,
      'client_id': clientId,
      'payout_number': payoutNumber,
      'amount': amount,
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_name': accountName,
      'disbursement_ref': disbursementRef,
      'proof_of_payment_url': proofOfPaymentUrl,
      'status': 'remitted',
      'disbursed_at': now.toIso8601String(),
      'notes': notes,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };
    final res = await adminDb.from('marketer_payouts').insert(payload).select().single();
    await adminDb.from('client_marketers').update({
      'total_paid_commission': amount,
      'updated_at': now.toIso8601String(),
    }).eq('id', marketerId);

    return ClientMarketerPayout.fromJson(res);
  }

  @override
  Future<List<LeadForm>> fetchLeadForms(String clientId, {String? marketerId}) async {
    final client = _getClient();
    var query = client
        .from('lead_forms')
        .select('*')
        .eq('client_id', clientId);
    if (marketerId != null && marketerId.isNotEmpty) {
      query = query.eq('marketer_id', marketerId);
    }
    final response = await query.order('created_at', ascending: false);

    final List<LeadForm> list = [];
    for (final item in response as List) {
      try {
        list.add(LeadForm.fromJson(item as Map<String, dynamic>));
      } catch (_) {}
    }
    return list;
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
    final client = _getAdminClient();
    final slug = formSlug != null && formSlug.trim().isNotEmpty
        ? formSlug.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9\-]'), '-')
        : 'form-${DateTime.now().millisecondsSinceEpoch}';

    final payload = {
      'client_id': clientId,
      if (marketerId != null && marketerId.isNotEmpty) 'marketer_id': marketerId,
      'product_id': productId,
      'product_name': productName,
      'form_title': formTitle,
      'form_slug': slug,
      'description': description ?? '',
      'packages': packages,
      'redirect_url': redirectUrl,
      'pixel_id': pixelId,
      'capi_token': capiToken,
      'test_event_code': testEventCode,
      'field_options': fieldOptions ?? {'require_email': false, 'require_alt_phone': false, 'require_city': false, 'require_notes': false},
      'appearance': appearance ?? {'primary_color': '#F37021', 'button_text': 'Complete Order Now', 'badge_text': 'Pay On Delivery + Free Delivery'},
      'is_active': true,
      'total_views': 0,
      'total_submissions': 0,
    };

    final res = await client.from('lead_forms').insert(payload).select().single();
    return LeadForm.fromJson(res);
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
    final client = _getAdminClient();
    final updateData = <String, dynamic>{
      if (formTitle != null) 'form_title': formTitle,
      if (formSlug != null) 'form_slug': formSlug,
      if (description != null) 'description': description,
      if (productId != null) 'product_id': productId,
      if (productName != null) 'product_name': productName,
      if (packages != null) 'packages': packages,
      if (redirectUrl != null) 'redirect_url': redirectUrl,
      if (pixelId != null) 'pixel_id': pixelId,
      if (capiToken != null) 'capi_token': capiToken,
      if (testEventCode != null) 'test_event_code': testEventCode,
      if (fieldOptions != null) 'field_options': fieldOptions,
      if (appearance != null) 'appearance': appearance,
      if (isActive != null) 'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final res = await client.from('lead_forms').update(updateData).eq('id', formId).select().single();
    return LeadForm.fromJson(res);
  }

  @override
  Future<Map<String, dynamic>> submitMarketingLeadOrder(Map<String, dynamic> payload) async {
    final client = _getClient();
    final response = await client.rpc('fn_submit_marketing_lead_order', params: {
      'p_payload': payload,
    });
    return Map<String, dynamic>.from(response as Map);
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
    final client = _getClient();
    final response = await client.rpc('fn_confirm_closer_order', params: {
      'p_order_id': orderId,
      'p_closer_id': closerId,
      if (deliveryAddress != null) 'p_delivery_address': deliveryAddress,
      if (deliveryState != null) 'p_delivery_state': deliveryState,
      if (deliveryLga != null) 'p_delivery_lga': deliveryLga,
      if (notes != null) 'p_notes': notes,
      'p_action': action,
      if (customerName != null) 'p_customer_name': customerName,
      if (customerPhone != null) 'p_customer_phone': customerPhone,
      if (customerAltPhone != null) 'p_customer_alt_phone': customerAltPhone,
      if (packageDealName != null) 'p_package_deal_name': packageDealName,
      if (packageDealId != null) 'p_package_deal_id': packageDealId,
      if (quantity != null) 'p_quantity': quantity,
      if (paidQuantity != null) 'p_paid_quantity': paidQuantity,
      if (freeQuantity != null) 'p_free_quantity': freeQuantity,
      if (totalAmount != null) 'p_total_amount': totalAmount,
      if (scheduledDeliveryDate != null) 'p_scheduled_delivery_date': scheduledDeliveryDate.toIso8601String(),
      if (cancellationReason != null) 'p_cancellation_reason': cancellationReason,
    });
    return Map<String, dynamic>.from(response as Map);
  }
}
