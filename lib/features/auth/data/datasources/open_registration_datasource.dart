import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../dc_console/domain/entities/dc_operations_officer.dart';
import '../../../dc_console/domain/entities/distribution_center.dart';
import '../../../dc_console/presentation/providers/dc_console_provider.dart';
import '../../domain/entities/registration_lookups.dart';
import '../models/user_model.dart';
import 'auth_remote_datasource.dart';

abstract class OpenRegistrationDataSource {
  Future<List<RegistrationMerchantOption>> fetchRegistrationMerchants();
  Future<List<DistributionCenter>> fetchRegistrationDistributionCenters();
  Future<List<RegistrationSupervisorOption>> fetchMerchantSupervisors(
    String clientId, {
    bool isMarketer = false,
  });
  Future<bool> checkEmailExists(String email);
  Future<bool> checkPhoneExists(String phone);
  Future<UserModel> registerOpenAccount(OpenRegistrationRequest request);
}

class OpenRegistrationDataSourceImpl implements OpenRegistrationDataSource {
  final SupabaseClient supabaseClient;
  final AuthRemoteDataSource authRemoteDataSource;
  SupabaseClient? _cachedAdminClient;

  OpenRegistrationDataSourceImpl(
    this.supabaseClient,
    this.authRemoteDataSource,
  );

  SupabaseClient _getAdminClient() {
    return _cachedAdminClient ??= SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseServiceRoleKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  }

  String _generateUuid() {
    final random = math.Random();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  Set<String> _buildPhoneVariants(String rawPhone) {
    final cleanPhone =
        rawPhone.replaceAll(RegExp(r'[\s\-\(\)]'), '').trim();
    final variants = <String>{
      if (cleanPhone.isNotEmpty) cleanPhone,
      if (rawPhone.trim().isNotEmpty) rawPhone.trim(),
    };
    if (cleanPhone.startsWith('0') && cleanPhone.length == 11) {
      variants.add('+234${cleanPhone.substring(1)}');
      variants.add('234${cleanPhone.substring(1)}');
      variants.add('+234 ${cleanPhone.substring(1)}');
    } else if (cleanPhone.startsWith('+234') && cleanPhone.length == 14) {
      variants.add('0${cleanPhone.substring(4)}');
      variants.add('234${cleanPhone.substring(4)}');
    } else if (cleanPhone.startsWith('234') && cleanPhone.length == 13) {
      variants.add('0${cleanPhone.substring(3)}');
      variants.add('+234${cleanPhone.substring(3)}');
    }
    return variants;
  }

  @override
  Future<List<RegistrationMerchantOption>> fetchRegistrationMerchants() async {
    final db = _getAdminClient();
    try {
      final rows = await db
          .from('clients')
          .select('id, company_name, name, code, city, state, tier, is_enterprise, is_active')
          .order('company_name', ascending: true);

      final list = <RegistrationMerchantOption>[];
      for (final raw in (rows as List)) {
        final map = Map<String, dynamic>.from(raw as Map);
        if (map['is_active'] == false) continue;
        final option = RegistrationMerchantOption.fromJson(map);
        if (option.id.isNotEmpty) {
          list.add(option);
        }
      }
      if (list.isNotEmpty) return list;
    } catch (e) {
      debugPrint('[OPEN_REG] ⚠️ Error fetching merchants: $e');
    }
    return const [
      RegistrationMerchantOption(
        id: '00000000-0000-4000-8000-791731264594',
        name: 'NOVACARE LIMITED',
        code: 'CLI-S1-212',
        city: 'Abuja',
        state: 'Federal Capital Territory',
        tier: 'enterprise',
        isEnterprise: true,
      ),
    ];
  }

  @override
  Future<List<DistributionCenter>> fetchRegistrationDistributionCenters() async {
    final db = _getAdminClient();
    try {
      final rows = await db
          .from('distribution_centers')
          .select('*')
          .order('is_grand_dc', ascending: false)
          .order('is_hub', ascending: false)
          .order('name', ascending: true);

      final list = <DistributionCenter>[];
      for (final raw in (rows as List)) {
        try {
          final dc = DistributionCenter.fromJson(Map<String, dynamic>.from(raw as Map));
          if (dc.id.isNotEmpty && dc.isActive) {
            list.add(dc);
          }
        } catch (_) {}
      }
      if (list.isNotEmpty) return list;
    } catch (e) {
      debugPrint('[OPEN_REG] ⚠️ Error fetching distribution centers: $e');
    }
    return List<DistributionCenter>.from(defaultDistributionCenters);
  }

  @override
  Future<List<RegistrationSupervisorOption>> fetchMerchantSupervisors(
    String clientId, {
    bool isMarketer = false,
  }) async {
    if (clientId.trim().isEmpty) return const [];
    final db = _getAdminClient();
    final tableName = isMarketer ? 'client_marketers' : 'client_closers';
    final codeCol = isMarketer ? 'marketer_code' : 'closer_code';

    try {
      final rows = await db
          .from(tableName)
          .select('id, user_id, full_name, $codeCol, client_id, is_supervisor, is_active')
          .eq('client_id', clientId)
          .eq('is_supervisor', true);

      final list = <RegistrationSupervisorOption>[];
      for (final raw in (rows as List)) {
        final map = Map<String, dynamic>.from(raw as Map);
        if (map['is_active'] == false) continue;
        list.add(
          RegistrationSupervisorOption(
            id: map['id']?.toString() ?? '',
            userId: map['user_id']?.toString(),
            code: map[codeCol]?.toString() ??
                (isMarketer ? 'MKT-SUP' : 'SUP-CLS'),
            fullName: map['full_name']?.toString() ?? 'Team Supervisor',
            clientId: clientId,
            isMarketer: isMarketer,
          ),
        );
      }
      return list;
    } catch (e) {
      debugPrint('[OPEN_REG] ℹ️ Supervisor lookup note ($tableName): $e');
      return const [];
    }
  }

  @override
  Future<bool> checkEmailExists(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return false;
    if (AuthRemoteDataSourceImpl.hasEmailInMemory(cleanEmail)) return true;

    final baseExists = await authRemoteDataSource.checkEmailExists(cleanEmail);
    if (baseExists) return true;

    final db = _getAdminClient();
    for (final table in const [
      'client_closers',
      'client_marketers',
      'client_accountants',
    ]) {
      try {
        final row = await db
            .from(table)
            .select('id')
            .ilike('email', cleanEmail)
            .maybeSingle();
        if (row != null) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<bool> checkPhoneExists(String phone) async {
    final variants = _buildPhoneVariants(phone);
    if (variants.isEmpty) return false;
    if (AuthRemoteDataSourceImpl.hasPhoneInMemory(variants)) return true;

    final db = _getAdminClient();
    try {
      final phoneFilter =
          variants.map((p) => 'phone_number.eq.$p').join(',');
      final existing = await db
          .from(SupabaseConstants.usersTable)
          .select('id')
          .or(phoneFilter)
          .limit(1);
      if ((existing as List).isNotEmpty) return true;
    } catch (_) {
      return await authRemoteDataSource.checkPhoneExists(phone);
    }
    return false;
  }

  Future<void> _ensureUniqueIdentity({
    required String email,
    required String phone,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (await checkEmailExists(cleanEmail)) {
      throw Exception(
        "An account with email '$cleanEmail' is already registered. Please sign in or use a different email address.",
      );
    }
    if (phone.trim().isNotEmpty && await checkPhoneExists(phone)) {
      throw Exception(
        "The phone number '${phone.trim()}' is already linked to an existing account. Please use a unique phone number.",
      );
    }
  }

  Future<String> _resolveMerchantName(
    SupabaseClient db,
    String clientId,
    String? fallbackName,
  ) async {
    if (fallbackName != null && fallbackName.trim().isNotEmpty) {
      return fallbackName.trim();
    }
    try {
      final row = await db
          .from('clients')
          .select('company_name, name')
          .eq('id', clientId)
          .maybeSingle();
      if (row != null) {
        final c = row['company_name']?.toString().trim();
        final n = row['name']?.toString().trim();
        if (c != null && c.isNotEmpty) return c;
        if (n != null && n.isNotEmpty) return n;
      }
    } catch (_) {}
    return 'Partner Merchant';
  }

  Future<String> _generateUniqueCode({
    required SupabaseClient db,
    required String table,
    required String column,
    required String defaultPrefix,
    String? preferredCode,
  }) async {
    final Set<String> existingCodes = {};
    try {
      final rows = await db.from(table).select(column);
      for (final r in (rows as List)) {
        final val = r[column]?.toString().trim().toUpperCase();
        if (val != null && val.isNotEmpty) existingCodes.add(val);
      }
    } catch (_) {}

    String prefix = defaultPrefix;
    if (preferredCode != null && preferredCode.trim().isNotEmpty) {
      final cleanPref = preferredCode.trim().toUpperCase();
      if (!existingCodes.contains(cleanPref)) {
        return cleanPref;
      }
      final match = RegExp(r'^(.*?)(\d+)$').firstMatch(cleanPref);
      if (match != null && match.group(1)!.isNotEmpty) {
        prefix = match.group(1)!;
      } else {
        prefix = cleanPref.endsWith('-') ? cleanPref : '$cleanPref-';
      }
    }

    int maxSuffix = 0;
    for (final code in existingCodes) {
      if (code.startsWith(prefix.toUpperCase())) {
        final numPart = code.substring(prefix.length);
        final parsed = int.tryParse(numPart);
        if (parsed != null && parsed > maxSuffix) maxSuffix = parsed;
      }
    }
    int nextNum =
        maxSuffix >= 100 ? maxSuffix + 1 : (maxSuffix > 0 ? maxSuffix + 1 : 101);
    String candidate = '$prefix${nextNum.toString().padLeft(3, '0')}';
    while (existingCodes.contains(candidate.toUpperCase())) {
      nextNum++;
      candidate = '$prefix${nextNum.toString().padLeft(3, '0')}';
    }
    return candidate;
  }

  Future<({String userId, bool createdNewAuthUser})> _createSupabaseAuthUser({
    required SupabaseClient db,
    required String cleanEmail,
    required String password,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      final adminRes = await db.auth.admin.createUser(
        AdminUserAttributes(
          email: cleanEmail,
          password: password,
          emailConfirm: true,
          userMetadata: metadata,
        ),
      );
      if (adminRes.user != null) {
        return (userId: adminRes.user!.id, createdNewAuthUser: true);
      }
    } catch (adminErr) {
      final errStr = adminErr.toString().toLowerCase();
      if (errStr.contains('already') ||
          errStr.contains('exists') ||
          errStr.contains('unique') ||
          errStr.contains('422')) {
        throw Exception(
          "An account with email '$cleanEmail' is already registered. Please sign in or use a different email address.",
        );
      }
      debugPrint('[OPEN_REG] ℹ️ Admin createUser notice: $adminErr. Trying signUp.');
      try {
        final signUpRes = await supabaseClient.auth.signUp(
          email: cleanEmail,
          password: password,
          data: metadata,
        );
        if (signUpRes.user != null) {
          return (userId: signUpRes.user!.id, createdNewAuthUser: true);
        }
      } catch (signUpErr) {
        final sErr = signUpErr.toString().toLowerCase();
        if (sErr.contains('already') ||
            sErr.contains('exists') ||
            sErr.contains('unique') ||
            sErr.contains('422')) {
          throw Exception(
            "An account with email '$cleanEmail' is already registered. Please sign in or use a different email address.",
          );
        }
        throw Exception('Failed to provision authentication account: $signUpErr');
      }
    }
    return (userId: _generateUuid(), createdNewAuthUser: false);
  }

  @override
  Future<UserModel> registerOpenAccount(OpenRegistrationRequest req) async {
    switch (req.accountType) {
      case RegistrationAccountType.deliveryAgent:
        final dcId = req.distributionCenterId?.trim() ?? '';
        if (dcId.isEmpty) {
          throw Exception('Please select an assigned Distribution Center.');
        }
        await _ensureUniqueIdentity(email: req.email, phone: req.phone);
        final user = await authRemoteDataSource.registerDeliveryAgent(
          email: req.email,
          password: req.password,
          firstName: req.firstName,
          lastName: req.lastName,
          phone: req.phone,
          personnelType: req.personnelType,
          compensationType: req.compensationType,
          commissionRate: req.commissionRate,
          transportAllowance: req.transportAllowance,
          fuelAllowance: req.fuelAllowance,
          failedDeliveryAllowance: req.failedDeliveryAllowance,
          baseSalary: req.baseSalary,
          vehicleType: req.vehicleType,
          vehiclePlateNumber: req.vehiclePlateNumber,
          bankName: req.bankName,
          bankAccountNumber: req.bankAccountNumber,
          bankAccountName: req.bankAccountName,
          distributionCenterId: dcId,
          assignedZone: req.assignedZone?.trim().isNotEmpty == true
              ? req.assignedZone!.trim()
              : (req.operatingCity?.trim() ?? 'Central Hub'),
        );
        return user;

      case RegistrationAccountType.dcOperations:
      case RegistrationAccountType.dcStockAdmin:
      case RegistrationAccountType.dcFinanceAdmin:
      case RegistrationAccountType.generalAccountant:
        final dcId = req.distributionCenterId?.trim() ?? '';
        final dcName = req.distributionCenterName?.trim() ?? '';
        if (dcId.isEmpty) {
          throw Exception('Please select an assigned Distribution Center.');
        }
        await _ensureUniqueIdentity(email: req.email, phone: req.phone);
        return await authRemoteDataSource.registerDcOperationsOfficer(
          email: req.email,
          password: req.password,
          firstName: req.firstName,
          lastName: req.lastName,
          phone: req.phone,
          distributionCenterId: dcId,
          distributionCenterName:
              dcName.isNotEmpty ? dcName : 'Distribution Center',
          staffCode: req.staffCode,
          role: req.accountType.roleKey,
        );

      case RegistrationAccountType.dcManager:
        return await _registerDcManagerSelfSignup(req);

      case RegistrationAccountType.client:
        await _ensureUniqueIdentity(email: req.email, phone: req.phone);
        return await authRemoteDataSource.registerClientAccount(
          email: req.email,
          password: req.password,
          companyName: req.companyName?.trim() ?? '',
          contactPerson: '${req.firstName.trim()} ${req.lastName.trim()}'.trim(),
          phone: req.phone.trim(),
          address: req.address?.trim() ?? '',
          city: req.city?.trim() ?? 'Abuja',
          stateName: req.stateName?.trim() ?? 'FCT - Abuja',
          tier: req.merchantTier,
          closerLimit: req.merchantTier == 'enterprise' ? 250 : 0,
          clientCode: req.clientCode,
          bankName: req.bankName.trim(),
          bankAccountNumber: req.bankAccountNumber.trim(),
          bankAccountName: req.bankAccountName.trim(),
        );

      case RegistrationAccountType.closer:
      case RegistrationAccountType.salesSupervisor:
        return await _registerCloserOrSupervisor(req);

      case RegistrationAccountType.marketer:
      case RegistrationAccountType.marketingSupervisor:
        return await _registerMarketerOrSupervisor(req);

      case RegistrationAccountType.merchantAccountant:
        return await _registerMerchantAccountant(req);
    }
  }

  Future<UserModel> _registerDcManagerSelfSignup(
    OpenRegistrationRequest req,
  ) async {
    final dcId = req.distributionCenterId?.trim() ?? '';
    final dcName = req.distributionCenterName?.trim() ?? 'Distribution Hub';
    if (dcId.isEmpty) {
      throw Exception('Please select a Distribution Center to manage.');
    }
    await _ensureUniqueIdentity(email: req.email, phone: req.phone);

    final db = _getAdminClient();
    final cleanEmail = req.email.trim().toLowerCase();
    final cleanPhone = req.phone.trim();
    final fName = req.firstName.trim();
    final lName = req.lastName.trim();
    final staffCode = req.staffCode?.trim().isNotEmpty == true
        ? req.staffCode!.trim().toUpperCase()
        : 'DC-MGR-${100 + (DateTime.now().millisecondsSinceEpoch % 900)}';

    final authResult = await _createSupabaseAuthUser(
      db: db,
      cleanEmail: cleanEmail,
      password: req.password,
      metadata: {
        'first_name': fName,
        'last_name': lName,
        'role': 'dc_manager',
        'phone': cleanPhone,
        'staff_code': staffCode,
        'distribution_center_id': dcId,
        'distribution_center_name': dcName,
      },
    );
    final authUserId = authResult.userId;

    try {
      await db.from(SupabaseConstants.usersTable).upsert({
        'id': authUserId,
        'company_id': '11111111-1111-4111-8111-111111111111',
        'email': cleanEmail,
        'phone_number': cleanPhone,
        'first_name': fName,
        'last_name': lName,
        'role': 'dc_manager',
        'distribution_center_id': dcId,
        'distribution_center_name': dcName,
        'is_active': true,
      });
    } catch (userErr) {
      try {
        await db.from(SupabaseConstants.usersTable).upsert({
          'id': authUserId,
          'company_id': '11111111-1111-4111-8111-111111111111',
          'email': cleanEmail,
          'phone_number': cleanPhone,
          'first_name': fName,
          'last_name': lName,
          'role': 'dc_manager',
          'distribution_center_id': dcId,
          'is_active': true,
        });
      } catch (retryErr) {
        if (authResult.createdNewAuthUser) {
          try {
            await db.auth.admin.deleteUser(authUserId);
          } catch (_) {}
        }
        throw Exception('Failed to save DC Manager profile: $retryErr');
      }
      debugPrint('[OPEN_REG] ℹ️ DC Manager users retry note: $userErr');
    }

    // Cache locally alongside operations staff so team directory includes co-managers
    try {
      final storage = LocalStorageServiceImpl();
      final cached = (await storage.getCachedOperationsOfficers()) ?? [];
      final officer = DCOperationsOfficer(
        id: authUserId,
        authUserId: authUserId,
        email: cleanEmail,
        firstName: fName,
        lastName: lName,
        phone: cleanPhone,
        staffCode: staffCode,
        distributionCenterId: dcId,
        distributionCenterName: dcName,
        isActive: true,
        createdAt: DateTime.now(),
      );
      await storage.cacheOperationsOfficers([
        officer,
        ...cached.where((o) => o.email.toLowerCase() != cleanEmail),
      ]);
    } catch (_) {}

    final userModel = UserModel(
      id: authUserId,
      authUserId: authUserId,
      email: cleanEmail,
      firstName: fName,
      lastName: lName,
      phone: cleanPhone,
      role: 'dc_manager',
      deliveryAgentCode: staffCode,
      distributionCenterId: dcId,
      distributionCenterName: dcName,
      operatingState: req.operatingState?.trim().isNotEmpty == true
          ? req.operatingState!.trim()
          : 'Federal Capital Territory',
      operatingCity: req.operatingCity?.trim().isNotEmpty == true
          ? req.operatingCity!.trim()
          : 'Abuja',
    );
    AuthRemoteDataSourceImpl.registerUserInMemory(userModel, req.password);
    return userModel;
  }

  Future<UserModel> _registerCloserOrSupervisor(
    OpenRegistrationRequest req,
  ) async {
    final clientId = req.clientId?.trim() ?? '';
    if (clientId.isEmpty) {
      throw Exception('Please select your Partner Merchant.');
    }
    await _ensureUniqueIdentity(email: req.email, phone: req.phone);

    final db = _getAdminClient();
    final cleanEmail = req.email.trim().toLowerCase();
    final cleanPhone = req.phone.trim();
    final fName = req.firstName.trim();
    final lName = req.lastName.trim();
    final fullName = '$fName $lName'.trim();
    final isSupervisor =
        req.accountType == RegistrationAccountType.salesSupervisor;
    final roleKey = isSupervisor ? 'sales_supervisor' : 'closer';
    final merchantName =
        await _resolveMerchantName(db, clientId, req.clientCompanyName);

    final closerCode = await _generateUniqueCode(
      db: db,
      table: 'client_closers',
      column: 'closer_code',
      defaultPrefix: isSupervisor ? 'SUP-CLS-' : 'CLS-NOVA-',
      preferredCode: req.staffCode,
    );
    final closerId = _generateUuid();

    final authResult = await _createSupabaseAuthUser(
      db: db,
      cleanEmail: cleanEmail,
      password: req.password,
      metadata: {
        'first_name': fName,
        'last_name': lName,
        'full_name': fullName,
        'role': roleKey,
        'client_id': clientId,
        'is_supervisor': isSupervisor,
        'closer_code': closerCode,
      },
    );
    final authUserId = authResult.userId;

    try {
      // 1. Upsert public.users BEFORE client_closers so FK user_id -> users(id) succeeds
      await db.from(SupabaseConstants.usersTable).upsert({
        'id': authUserId,
        'company_id': '11111111-1111-4111-8111-111111111111',
        'client_id': clientId,
        'email': cleanEmail,
        'phone_number': cleanPhone,
        'first_name': fName,
        'last_name': lName,
        'role': roleKey,
        if (isSupervisor) 'is_supervisor': true,
        'is_active': true,
      });

      final closerPayload = <String, dynamic>{
        'id': closerId,
        'client_id': clientId,
        'user_id': authUserId,
        'closer_code': closerCode,
        'full_name': fullName,
        'email': cleanEmail,
        'phone': cleanPhone,
        'daily_call_target': req.dailyCallTarget,
        'commission_rate': isSupervisor ? 0.0 : 500.0,
        'is_commission_enabled': !isSupervisor,
        'bank_name': req.bankName.trim(),
        'account_number': req.bankAccountNumber.trim(),
        'account_name': req.bankAccountName.trim().isNotEmpty
            ? req.bankAccountName.trim()
            : fullName,
        'is_supervisor': isSupervisor,
        if (!isSupervisor && req.supervisorId != null && req.supervisorId!.isNotEmpty)
          'supervisor_id': req.supervisorId,
        if (!isSupervisor && req.supervisorName != null && req.supervisorName!.isNotEmpty)
          'supervisor_name': req.supervisorName,
        'base_salary': 80000.0,
        'approval_status': 'approved',
        'is_active': true,
      };

      try {
        await db.from('client_closers').upsert(closerPayload);
      } catch (extErr) {
        debugPrint('[OPEN_REG] ⚠️ Extended client_closers columns note: $extErr');
        final corePayload = <String, dynamic>{
          'id': closerId,
          'client_id': clientId,
          'user_id': authUserId,
          'closer_code': closerCode,
          'full_name': fullName,
          'email': cleanEmail,
          'phone': cleanPhone,
          'commission_rate': isSupervisor ? 0.0 : 500.0,
          'is_active': true,
        };
        await db.from('client_closers').upsert(corePayload);
      }

      // Sync merchant closer counters
      try {
        final clientRows = await db
            .from('clients')
            .select('total_closers_count, closer_limit')
            .eq('id', clientId)
            .limit(1);
        if ((clientRows as List).isNotEmpty) {
          final clientRes = (clientRows as List).first as Map<String, dynamic>;
          final totalCount =
              (clientRes['total_closers_count'] as num?)?.toInt() ?? 0;
          final currentLimit =
              (clientRes['closer_limit'] as num?)?.toInt() ?? 25;
          final newTotal = totalCount + 1;
          await db.from('clients').update({
            'total_closers_count': newTotal,
            if (newTotal > currentLimit) 'closer_limit': newTotal + 15,
          }).eq('id', clientId);
        }
      } catch (_) {}
    } catch (err) {
      try {
        await db.from('client_closers').delete().eq('id', closerId);
      } catch (_) {}
      try {
        await db.from(SupabaseConstants.usersTable).delete().eq('id', authUserId);
      } catch (_) {}
      if (authResult.createdNewAuthUser) {
        try {
          await db.auth.admin.deleteUser(authUserId);
        } catch (_) {}
      }
      rethrow;
    }

    final userModel = UserModel(
      id: authUserId,
      authUserId: authUserId,
      email: cleanEmail,
      firstName: fName,
      lastName: lName,
      phone: cleanPhone,
      role: roleKey,
      clientId: clientId,
      clientCompanyName: merchantName,
      closerId: closerId,
      closerCode: closerCode,
      deliveryAgentCode: closerCode,
      bankName: req.bankName.trim(),
      bankAccountNumber: req.bankAccountNumber.trim(),
      bankAccountName: req.bankAccountName.trim(),
      isSupervisor: isSupervisor,
    );
    AuthRemoteDataSourceImpl.registerUserInMemory(userModel, req.password);
    return userModel;
  }

  Future<UserModel> _registerMarketerOrSupervisor(
    OpenRegistrationRequest req,
  ) async {
    final clientId = req.clientId?.trim() ?? '';
    if (clientId.isEmpty) {
      throw Exception('Please select your Partner Merchant.');
    }
    await _ensureUniqueIdentity(email: req.email, phone: req.phone);

    final db = _getAdminClient();
    final cleanEmail = req.email.trim().toLowerCase();
    final cleanPhone = req.phone.trim();
    final fName = req.firstName.trim();
    final lName = req.lastName.trim();
    final fullName = '$fName $lName'.trim();
    final isSupervisor =
        req.accountType == RegistrationAccountType.marketingSupervisor;
    final roleKey = isSupervisor ? 'marketing_supervisor' : 'marketer';
    final merchantName =
        await _resolveMerchantName(db, clientId, req.clientCompanyName);

    final marketerCode = await _generateUniqueCode(
      db: db,
      table: 'client_marketers',
      column: 'marketer_code',
      defaultPrefix: isSupervisor ? 'MKT-SUP-' : 'MKT-NOVA-',
      preferredCode: req.staffCode,
    );
    final marketerId = _generateUuid();

    final authResult = await _createSupabaseAuthUser(
      db: db,
      cleanEmail: cleanEmail,
      password: req.password,
      metadata: {
        'first_name': fName,
        'last_name': lName,
        'full_name': fullName,
        'role': roleKey,
        'client_id': clientId,
        'is_supervisor': isSupervisor,
        'marketer_code': marketerCode,
      },
    );
    final authUserId = authResult.userId;

    try {
      await db.from(SupabaseConstants.usersTable).upsert({
        'id': authUserId,
        'company_id': '11111111-1111-4111-8111-111111111111',
        'client_id': clientId,
        'email': cleanEmail,
        'phone_number': cleanPhone,
        'first_name': fName,
        'last_name': lName,
        'role': roleKey,
        'is_supervisor': isSupervisor,
        'marketer_id': marketerId,
        'marketer_code': marketerCode,
        'is_active': true,
      });

      final marketerPayload = <String, dynamic>{
        'id': marketerId,
        'client_id': clientId,
        'user_id': authUserId,
        'marketer_code': marketerCode,
        'full_name': fullName,
        'email': cleanEmail,
        'phone': cleanPhone,
        'is_supervisor': isSupervisor,
        if (!isSupervisor && req.supervisorId != null && req.supervisorId!.isNotEmpty)
          'supervisor_id': req.supervisorId,
        'daily_ad_spend_budget': req.dailyAdSpendBudget,
        'commission_model': req.commissionModel,
        'commission_type': req.commissionModel,
        'commission_rate': 500.0,
        'commission_per_form_submission':
            req.commissionModel == 'per_form_submission' ? 500.0 : 0.0,
        'commission_per_delivered_order':
            req.commissionModel == 'per_delivered_order' ? 1000.0 : 0.0,
        'is_commission_enabled': true,
        'bank_name': req.bankName.trim(),
        'account_number': req.bankAccountNumber.trim(),
        'account_name': req.bankAccountName.trim().isNotEmpty
            ? req.bankAccountName.trim()
            : fullName,
        'is_active': true,
      };

      try {
        await db.from('client_marketers').insert(marketerPayload);
      } catch (extErr) {
        debugPrint('[OPEN_REG] ⚠️ Extended client_marketers columns note: $extErr');
        final corePayload = <String, dynamic>{
          'id': marketerId,
          'client_id': clientId,
          'user_id': authUserId,
          'marketer_code': marketerCode,
          'full_name': fullName,
          'email': cleanEmail,
          'phone': cleanPhone,
          'daily_ad_spend_budget': req.dailyAdSpendBudget,
          'bank_name': req.bankName.trim(),
          'account_number': req.bankAccountNumber.trim(),
          'account_name': req.bankAccountName.trim(),
          'is_active': true,
        };
        await db.from('client_marketers').insert(corePayload);
      }
    } catch (err) {
      try {
        await db.from('client_marketers').delete().eq('id', marketerId);
      } catch (_) {}
      try {
        await db.from(SupabaseConstants.usersTable).delete().eq('id', authUserId);
      } catch (_) {}
      if (authResult.createdNewAuthUser) {
        try {
          await db.auth.admin.deleteUser(authUserId);
        } catch (_) {}
      }
      rethrow;
    }

    final userModel = UserModel(
      id: authUserId,
      authUserId: authUserId,
      email: cleanEmail,
      firstName: fName,
      lastName: lName,
      phone: cleanPhone,
      role: roleKey,
      clientId: clientId,
      clientCompanyName: merchantName,
      marketerId: marketerId,
      marketerCode: marketerCode,
      deliveryAgentCode: marketerCode,
      bankName: req.bankName.trim(),
      bankAccountNumber: req.bankAccountNumber.trim(),
      bankAccountName: req.bankAccountName.trim(),
      isSupervisor: isSupervisor,
    );
    AuthRemoteDataSourceImpl.registerUserInMemory(userModel, req.password);
    return userModel;
  }

  Future<UserModel> _registerMerchantAccountant(
    OpenRegistrationRequest req,
  ) async {
    final clientId = req.clientId?.trim() ?? '';
    if (clientId.isEmpty) {
      throw Exception('Please select your Partner Merchant.');
    }
    await _ensureUniqueIdentity(email: req.email, phone: req.phone);

    final db = _getAdminClient();
    final cleanEmail = req.email.trim().toLowerCase();
    final cleanPhone = req.phone.trim();
    final fName = req.firstName.trim();
    final lName = req.lastName.trim();
    final fullName = '$fName $lName'.trim();
    final merchantName =
        await _resolveMerchantName(db, clientId, req.clientCompanyName);

    final accountantCode = await _generateUniqueCode(
      db: db,
      table: 'client_accountants',
      column: 'accountant_code',
      defaultPrefix: 'ACC-NOVA-',
      preferredCode: req.staffCode,
    );
    final accountantId = _generateUuid();

    final authResult = await _createSupabaseAuthUser(
      db: db,
      cleanEmail: cleanEmail,
      password: req.password,
      metadata: {
        'first_name': fName,
        'last_name': lName,
        'full_name': fullName,
        'role': 'merchant_accountant',
        'client_id': clientId,
        'accountant_code': accountantCode,
      },
    );
    final authUserId = authResult.userId;

    try {
      await db.from(SupabaseConstants.usersTable).upsert({
        'id': authUserId,
        'company_id': '11111111-1111-4111-8111-111111111111',
        'client_id': clientId,
        'email': cleanEmail,
        'phone_number': cleanPhone,
        'first_name': fName,
        'last_name': lName,
        'role': 'merchant_accountant',
        'is_active': true,
      });

      await db.from('client_accountants').upsert({
        'id': accountantId,
        'client_id': clientId,
        'user_id': authUserId,
        'accountant_code': accountantCode,
        'full_name': fullName,
        'email': cleanEmail,
        'phone': cleanPhone,
        'can_approve_settlements': req.canApproveSettlements,
        'can_manage_expenses': req.canManageExpenses,
        'can_disburse_payouts': req.canDisbursePayouts,
        'is_active': true,
      });
    } catch (err) {
      try {
        await db.from('client_accountants').delete().eq('id', accountantId);
      } catch (_) {}
      try {
        await db.from(SupabaseConstants.usersTable).delete().eq('id', authUserId);
      } catch (_) {}
      if (authResult.createdNewAuthUser) {
        try {
          await db.auth.admin.deleteUser(authUserId);
        } catch (_) {}
      }
      rethrow;
    }

    final userModel = UserModel(
      id: authUserId,
      authUserId: authUserId,
      email: cleanEmail,
      firstName: fName,
      lastName: lName,
      phone: cleanPhone,
      role: 'merchant_accountant',
      clientId: clientId,
      clientCompanyName: merchantName,
      accountantId: accountantId,
      accountantCode: accountantCode,
      deliveryAgentCode: accountantCode,
    );
    AuthRemoteDataSourceImpl.registerUserInMemory(userModel, req.password);
    return userModel;
  }
}

class MockOpenRegistrationDataSource implements OpenRegistrationDataSource {
  final List<RegistrationMerchantOption> _merchants = [
    const RegistrationMerchantOption(
      id: '00000000-0000-4000-8000-791731264594',
      name: 'NOVACARE LIMITED',
      code: 'CLI-S1-212',
      city: 'Abuja',
      state: 'Federal Capital Territory',
      tier: 'enterprise',
      isEnterprise: true,
    ),
    const RegistrationMerchantOption(
      id: '00000000-0000-4000-8000-791731264595',
      name: 'NOVA HERBALS ENTERPRISE',
      code: 'CLI-NH-304',
      city: 'Lagos',
      state: 'Lagos',
      tier: 'enterprise',
      isEnterprise: true,
    ),
  ];

  final List<DistributionCenter> _dcs = [
    ...defaultDistributionCenters,
    DistributionCenter(
      id: '33333333-3333-4333-8333-333333333333',
      name: 'Lagos Mainland Regional Hub',
      code: 'DC-LOS-01',
      state: 'Lagos',
      city: 'Ikeja',
      address: '14 Allen Avenue, Ikeja, Lagos',
      isHub: true,
      operatingZones: const [
        'Ikeja (GRA / Allen / Alausa)',
        'Lekki Phase 1 & 2',
        'Victoria Island (VI)',
        'Surulere',
      ],
      coveredStates: const ['Lagos', 'Ogun'],
    ),
    DistributionCenter(
      id: '44444444-4444-4444-8444-444444444444',
      name: 'Rivers Port Harcourt Station',
      code: 'DC-PHC-01',
      state: 'Rivers',
      city: 'Port Harcourt',
      address: 'Plot 28 Trans-Amadi Industrial Layout, PH',
      operatingZones: const [
        'Port Harcourt City (Old GRA / Town)',
        'Obio-Akpor (New GRA / Rumuokoro / Rumuola)',
        'Trans-Amadi Industrial Layout',
      ],
      coveredStates: const ['Rivers', 'Bayelsa'],
    ),
  ];

  final List<RegistrationSupervisorOption> _supervisors = [
    const RegistrationSupervisorOption(
      id: 'sup-joelsupervisor',
      userId: 'bcf5a83f-684f-4e5b-855e-b24115c178e1',
      code: 'SUP-CLS-01',
      fullName: 'Joel Supervisor',
      clientId: '00000000-0000-4000-8000-791731264594',
      isMarketer: false,
    ),
    const RegistrationSupervisorOption(
      id: 'sup-mkt-adaeze',
      userId: 'sup-mkt-user-01',
      code: 'MKT-SUP-01',
      fullName: 'Adaeze Growth Lead',
      clientId: '00000000-0000-4000-8000-791731264594',
      isMarketer: true,
    ),
  ];

  @override
  Future<List<RegistrationMerchantOption>> fetchRegistrationMerchants() async =>
      List.unmodifiable(_merchants);

  @override
  Future<List<DistributionCenter>>
      fetchRegistrationDistributionCenters() async => List.unmodifiable(_dcs);

  @override
  Future<List<RegistrationSupervisorOption>> fetchMerchantSupervisors(
    String clientId, {
    bool isMarketer = false,
  }) async {
    return _supervisors
        .where((s) => s.clientId == clientId && s.isMarketer == isMarketer)
        .toList();
  }

  @override
  Future<bool> checkEmailExists(String email) async {
    final clean = email.trim().toLowerCase();
    return AuthRemoteDataSourceImpl.hasEmailInMemory(clean) ||
        clean == 'emeka.rider@novaxpress.ng' ||
        clean == 'closer@novacare.com' ||
        clean == 'dc.supervisor@novaxpress.ng' ||
        clean == 'novacare@novaxpress.net';
  }

  @override
  Future<bool> checkPhoneExists(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '').trim();
    return AuthRemoteDataSourceImpl.hasPhoneInMemory([clean, phone.trim()]) ||
        clean == '08012345678' ||
        clean == '08085040146';
  }

  @override
  Future<UserModel> registerOpenAccount(OpenRegistrationRequest req) async {
    final cleanEmail = req.email.trim().toLowerCase();
    if (await checkEmailExists(cleanEmail)) {
      throw Exception(
        "An account with email '$cleanEmail' is already registered.",
      );
    }
    if (req.phone.trim().isNotEmpty && await checkPhoneExists(req.phone)) {
      throw Exception(
        "Phone number '${req.phone.trim()}' is already registered.",
      );
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final suffix = (100 + (ts % 900)).toString();
    final fName = req.firstName.trim();
    final lName = req.lastName.trim();
    final cleanPhone = req.phone.trim();

    if (req.accountType.requiresMerchant &&
        (req.clientId == null || req.clientId!.trim().isEmpty)) {
      throw Exception('Please select your Partner Merchant.');
    }
    if (req.accountType.requiresDistributionCenter &&
        (req.distributionCenterId == null ||
            req.distributionCenterId!.trim().isEmpty)) {
      throw Exception('Please select an assigned Distribution Center.');
    }

    final matchedMerchant = _merchants
        .where((m) => m.id == req.clientId)
        .firstOrNull;
    final matchedDc = _dcs
        .where((d) => d.id == req.distributionCenterId)
        .firstOrNull;

    late final UserModel userModel;
    switch (req.accountType) {
      case RegistrationAccountType.deliveryAgent:
        final isPda = req.personnelType.toLowerCase() == 'pda';
        final code = isPda ? 'PDA-7$suffix' : 'RDR-$suffix';
        final id = 'agt-$ts';
        userModel = UserModel(
          id: id,
          authUserId: id,
          email: cleanEmail,
          firstName: fName,
          lastName: lName,
          phone: cleanPhone,
          role: 'delivery_agent',
          deliveryAgentId: id,
          deliveryAgentCode: code,
          distributionCenterId: req.distributionCenterId,
          distributionCenterName:
              req.distributionCenterName ?? matchedDc?.name ?? 'Distribution Hub',
          operatingState:
              req.operatingState ?? matchedDc?.state ?? 'Federal Capital Territory',
          operatingCity:
              req.assignedZone ?? req.operatingCity ?? matchedDc?.city ?? 'Abuja',
          personnelType: req.personnelType,
          compensationType: req.compensationType,
          commissionRate: req.commissionRate,
          transportAllowance: req.transportAllowance,
          fuelAllowance: req.fuelAllowance,
          failedDeliveryAllowance: req.failedDeliveryAllowance,
          baseSalary: req.baseSalary,
          vehicleType: req.vehicleType,
          vehiclePlateNumber: req.vehiclePlateNumber.trim(),
          bankName: req.bankName.trim(),
          bankAccountNumber: req.bankAccountNumber.trim(),
          bankAccountName: req.bankAccountName.trim(),
        );
        break;

      case RegistrationAccountType.dcOperations:
      case RegistrationAccountType.dcStockAdmin:
      case RegistrationAccountType.dcFinanceAdmin:
      case RegistrationAccountType.dcManager:
      case RegistrationAccountType.generalAccountant:
        final prefix = switch (req.accountType) {
          RegistrationAccountType.dcStockAdmin => 'STK',
          RegistrationAccountType.dcFinanceAdmin => 'FIN',
          RegistrationAccountType.dcManager => 'MGR',
          RegistrationAccountType.generalAccountant => 'ACC-HQ',
          _ => 'OPS',
        };
        final code = req.staffCode?.trim().isNotEmpty == true
            ? req.staffCode!.trim().toUpperCase()
            : '$prefix-$suffix';
        final id = 'dc-$ts';
        userModel = UserModel(
          id: id,
          authUserId: id,
          email: cleanEmail,
          firstName: fName,
          lastName: lName,
          phone: cleanPhone,
          role: req.accountType.roleKey,
          deliveryAgentCode: code,
          distributionCenterId: req.distributionCenterId,
          distributionCenterName:
              req.distributionCenterName ?? matchedDc?.name ?? 'Distribution Hub',
          operatingState:
              req.operatingState ?? matchedDc?.state ?? 'Federal Capital Territory',
          operatingCity:
              req.assignedZone ?? req.operatingCity ?? matchedDc?.city ?? 'Abuja',
        );
        break;

      case RegistrationAccountType.client:
        final cid = 'cli-$ts';
        final cName = req.companyName?.trim() ?? '$fName Store';
        final code = req.clientCode?.trim().isNotEmpty == true
            ? req.clientCode!.trim().toUpperCase()
            : 'CLI-$suffix';
        _merchants.add(
          RegistrationMerchantOption(
            id: cid,
            name: cName,
            code: code,
            city: req.city ?? 'Abuja',
            state: req.stateName ?? 'FCT - Abuja',
            tier: req.merchantTier,
            isEnterprise: req.merchantTier == 'enterprise',
          ),
        );
        userModel = UserModel(
          id: 'u-$ts',
          authUserId: 'u-$ts',
          email: cleanEmail,
          firstName: fName,
          lastName: lName,
          phone: cleanPhone,
          role: 'client',
          clientId: cid,
          clientCompanyName: cName,
          deliveryAgentCode: code,
          operatingState: req.stateName ?? 'FCT - Abuja',
          operatingCity: req.city ?? 'Abuja',
          bankName: req.bankName.trim(),
          bankAccountNumber: req.bankAccountNumber.trim(),
          bankAccountName: req.bankAccountName.trim(),
        );
        break;

      case RegistrationAccountType.closer:
      case RegistrationAccountType.salesSupervisor:
        final isSup = req.accountType == RegistrationAccountType.salesSupervisor;
        final code = req.staffCode?.trim().isNotEmpty == true
            ? req.staffCode!.trim().toUpperCase()
            : (isSup ? 'SUP-CLS-$suffix' : 'CLS-NOVA-$suffix');
        final id = 'cls-$ts';
        if (isSup) {
          _supervisors.add(
            RegistrationSupervisorOption(
              id: id,
              userId: id,
              code: code,
              fullName: '$fName $lName'.trim(),
              clientId: req.clientId!,
              isMarketer: false,
            ),
          );
        }
        userModel = UserModel(
          id: id,
          authUserId: id,
          email: cleanEmail,
          firstName: fName,
          lastName: lName,
          phone: cleanPhone,
          role: req.accountType.roleKey,
          clientId: req.clientId,
          clientCompanyName:
              req.clientCompanyName ?? matchedMerchant?.name ?? 'Partner Merchant',
          closerId: id,
          closerCode: code,
          deliveryAgentCode: code,
          bankName: req.bankName.trim(),
          bankAccountNumber: req.bankAccountNumber.trim(),
          bankAccountName: req.bankAccountName.trim(),
          isSupervisor: isSup,
        );
        break;

      case RegistrationAccountType.marketer:
      case RegistrationAccountType.marketingSupervisor:
        final isSup =
            req.accountType == RegistrationAccountType.marketingSupervisor;
        final code = req.staffCode?.trim().isNotEmpty == true
            ? req.staffCode!.trim().toUpperCase()
            : (isSup ? 'MKT-SUP-$suffix' : 'MKT-NOVA-$suffix');
        final id = 'mkt-$ts';
        if (isSup) {
          _supervisors.add(
            RegistrationSupervisorOption(
              id: id,
              userId: id,
              code: code,
              fullName: '$fName $lName'.trim(),
              clientId: req.clientId!,
              isMarketer: true,
            ),
          );
        }
        userModel = UserModel(
          id: id,
          authUserId: id,
          email: cleanEmail,
          firstName: fName,
          lastName: lName,
          phone: cleanPhone,
          role: req.accountType.roleKey,
          clientId: req.clientId,
          clientCompanyName:
              req.clientCompanyName ?? matchedMerchant?.name ?? 'Partner Merchant',
          marketerId: id,
          marketerCode: code,
          deliveryAgentCode: code,
          bankName: req.bankName.trim(),
          bankAccountNumber: req.bankAccountNumber.trim(),
          bankAccountName: req.bankAccountName.trim(),
          isSupervisor: isSup,
        );
        break;

      case RegistrationAccountType.merchantAccountant:
        final code = req.staffCode?.trim().isNotEmpty == true
            ? req.staffCode!.trim().toUpperCase()
            : 'ACC-NOVA-$suffix';
        final id = 'acc-$ts';
        userModel = UserModel(
          id: id,
          authUserId: id,
          email: cleanEmail,
          firstName: fName,
          lastName: lName,
          phone: cleanPhone,
          role: 'merchant_accountant',
          clientId: req.clientId,
          clientCompanyName:
              req.clientCompanyName ?? matchedMerchant?.name ?? 'Partner Merchant',
          accountantId: id,
          accountantCode: code,
          deliveryAgentCode: code,
        );
        break;
    }

    AuthRemoteDataSourceImpl.registerUserInMemory(userModel, req.password);
    return userModel;
  }
}

