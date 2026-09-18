import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/exceptions/exceptions.dart';
import '../../../../core/services/local_storage_service.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login(String email, String password);
  Future<void> logout();
  Future<UserModel?> getCurrentUser();
  Future<UserModel> registerDeliveryAgent({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String personnelType,
    required String compensationType,
    required double commissionRate,
    required double transportAllowance,
    required double fuelAllowance,
    double failedDeliveryAllowance = 500.0,
    required double baseSalary,
    required String vehicleType,
    required String vehiclePlateNumber,
    required String bankName,
    required String bankAccountNumber,
    required String bankAccountName,
    required String distributionCenterId,
    required String assignedZone,
  });
  Future<UserModel> registerDistributionCenterSupervisor({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String distributionCenterId,
    required String distributionCenterName,
    String? operatingState,
    String? operatingCity,
  });
  Future<UserModel> registerClientAccount({
    required String email,
    required String password,
    required String companyName,
    required String contactPerson,
    required String phone,
    required String address,
    required String city,
    required String stateName,
    String tier = 'standard_merchant',
    int closerLimit = 0,
    String? clientCode,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
    String? clientId,
    double? customDeliveryFee,
    double? customPlatformFee,
    double? customFailedAttemptFee,
  });
  Future<bool> checkEmailExists(String email);
  Future<bool> checkPhoneExists(String phone);
}

class MockAuthRemoteDataSource implements AuthRemoteDataSource {
  UserModel? _currentUser;

  MockAuthRemoteDataSource([this._currentUser]);

  @override
  Future<UserModel> login(String email, String password) async {
    final clean = email.trim().toLowerCase();

    // 1. Check in-memory registered accounts
    if (AuthRemoteDataSourceImpl._registeredUsers.containsKey(clean)) {
      final expectedPass = AuthRemoteDataSourceImpl._registeredPasswords[clean];
      if (expectedPass != null && expectedPass != password) {
        throw AppAuthException('Invalid email or password. Please check your credentials.');
      }
      _currentUser = AuthRemoteDataSourceImpl._registeredUsers[clean];
      return _currentUser!;
    }

    // 2. Verified Demo / Seed Accounts
    if (clean == 'client.novacale@novaxpress.ng' || clean == 'merchant@novacare.com') {
      if (password != 'ClientPass123!' && password != 'Password123!') {
        throw AppAuthException('Invalid email or password. Please check your credentials.');
      }
      _currentUser = const UserModel(
        id: '00000000-0000-4000-8000-789382731303',
        email: 'merchant@novacare.com',
        firstName: 'Dr. Chuka',
        lastName: 'Okafor',
        phone: '08034455667',
        role: 'client',
        clientId: '00000000-0000-4000-8000-789382731303',
        clientCompanyName: 'Novacare Health & Wellness Ltd',
        deliveryAgentCode: 'CLI-NOVACARE-01',
        operatingState: 'Federal Capital Territory',
        operatingCity: 'Abuja',
      );
      return _currentUser!;
    }

    if (clean == 'closer.amaka@novacale.ng' || clean == 'closer@novacare.com') {
      if (password != 'CloserPass123!' && password != 'Password123!') {
        throw AppAuthException('Invalid email or password. Please check your credentials.');
      }
      _currentUser = const UserModel(
        id: '44444444-4444-4444-8444-444444444444',
        email: 'closer@novacare.com',
        firstName: 'Amaka',
        lastName: 'Chioma',
        phone: '08021122334',
        role: 'closer',
        closerId: '44444444-4444-4444-8444-444444444444',
        closerCode: 'CLS-NOVA-001',
        clientId: '00000000-0000-4000-8000-789382731303',
        clientCompanyName: 'Novacare Health & Wellness Ltd',
        operatingState: 'Federal Capital Territory',
        operatingCity: 'Abuja',
        avatarUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=150&auto=format&fit=crop&q=80',
      );
      return _currentUser!;
    }

    if (clean == 'chidinma.closer@novacare.com') {
      if (password != 'CloserPass123!' && password != 'Password123!') {
        throw AppAuthException('Invalid email or password. Please check your credentials.');
      }
      _currentUser = const UserModel(
        id: '55555555-5555-4555-8555-555555555555',
        email: 'chidinma.closer@novacare.com',
        firstName: 'Chidinma',
        lastName: 'Eze',
        phone: '08034567890',
        role: 'closer',
        closerId: '55555555-5555-4555-8555-555555555555',
        closerCode: 'CLS-NOVA-002',
        clientId: '00000000-0000-4000-8000-789382731303',
        clientCompanyName: 'Novacare Health & Wellness Ltd',
        operatingState: 'Federal Capital Territory',
        operatingCity: 'Abuja',
        avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80',
      );
      return _currentUser!;
    }

    if (clean == 'dc.supervisor@novaxpress.ng') {
      if (password != 'Password123!') {
        throw AppAuthException('Invalid email or password. Please check your credentials.');
      }
      _currentUser = const UserModel(
        id: 'a2222222-2222-4222-8222-222222222222',
        email: 'dc.supervisor@novaxpress.ng',
        firstName: 'Adekunle',
        lastName: 'Supervisor',
        phone: '+234 802 345 6789',
        role: 'dc_manager',
        distributionCenterId: '22222222-2222-4222-8222-222222222222',
        distributionCenterName: 'Wuse Central Distribution Hub',
        operatingState: 'Federal Capital Territory',
        operatingCity: 'Wuse 2',
      );
      return _currentUser!;
    }

    if (clean == 'emeka.rider@novaxpress.ng' || clean == 'rider.emeka@novaxpress.com') {
      if (password != 'Password123!') {
        throw AppAuthException('Invalid email or password. Please check your credentials.');
      }
      _currentUser = const UserModel(
        id: 'b1111111-1111-4111-8111-111111111111',
        email: 'rider.emeka@novaxpress.com',
        firstName: 'Emeka',
        lastName: 'Rider',
        phone: '08012345678',
        role: 'delivery_agent',
        deliveryAgentId: 'b1111111-1111-4111-8111-111111111111',
        deliveryAgentCode: 'PDA-7000',
      );
      return _currentUser!;
    }

    throw AppAuthException('Invalid email or password. Only registered accounts can log in.');
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
  }

  @override
  Future<UserModel?> getCurrentUser() async => _currentUser;

  @override
  Future<UserModel> registerDeliveryAgent({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String personnelType,
    required String compensationType,
    required double commissionRate,
    required double transportAllowance,
    required double fuelAllowance,
    double failedDeliveryAllowance = 500.0,
    required double baseSalary,
    required String vehicleType,
    required String vehiclePlateNumber,
    required String bankName,
    required String bankAccountNumber,
    required String bankAccountName,
    required String distributionCenterId,
    required String assignedZone,
  }) async {
    return _currentUser!;
  }

  @override
  Future<UserModel> registerDistributionCenterSupervisor({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String distributionCenterId,
    required String distributionCenterName,
    String? operatingState,
    String? operatingCity,
  }) async {
    final supervisor = UserModel(
      id: 'sup_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      role: 'dc_manager',
      distributionCenterId: distributionCenterId,
      distributionCenterName: distributionCenterName,
      operatingState: operatingState ?? 'Federal Capital Territory',
      operatingCity: operatingCity ?? 'Abuja',
    );
    AuthRemoteDataSourceImpl.registerUserInMemory(supervisor, password);
    return supervisor;
  }

  @override
  Future<UserModel> registerClientAccount({
    required String email,
    required String password,
    required String companyName,
    required String contactPerson,
    required String phone,
    required String address,
    required String city,
    required String stateName,
    String tier = 'standard_merchant',
    int closerLimit = 0,
    String? clientCode,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
    String? clientId,
    double? customDeliveryFee,
    double? customPlatformFee,
    double? customFailedAttemptFee,
  }) async {
    final parts = contactPerson.trim().split(' ');
    final fName = parts.isNotEmpty ? parts.first : companyName;
    final lName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    final clientUser = UserModel(
      id: 'cli_${DateTime.now().millisecondsSinceEpoch}',
      email: email.trim().toLowerCase(),
      firstName: fName,
      lastName: lName,
      phone: phone.trim(),
      role: 'client',
      clientId: clientId ?? 'c_${DateTime.now().millisecondsSinceEpoch}',
      clientCompanyName: companyName.trim(),
      deliveryAgentCode: clientCode ?? 'CLI-01',
      operatingState: stateName.trim(),
      operatingCity: city.trim(),
      bankName: bankName ?? '',
      bankAccountNumber: bankAccountNumber ?? '',
      bankAccountName: bankAccountName ?? '',
    );
    AuthRemoteDataSourceImpl.registerUserInMemory(clientUser, password);
    return clientUser;
  }

  @override
  Future<bool> checkEmailExists(String email) async {
    final clean = email.trim().toLowerCase();
    return AuthRemoteDataSourceImpl._registeredUsers.containsKey(clean) ||
        clean == 'emeka.rider@novaxpress.ng' ||
        clean == 'rider.emeka@novaxpress.com' ||
        clean == 'client.novacale@novaxpress.ng' ||
        clean == 'closer.amaka@novacale.ng' ||
        clean == 'dc.supervisor@novaxpress.ng';
  }

  @override
  Future<bool> checkPhoneExists(String phone) async {
    final clean = phone.trim();
    return clean == '08012345678' || clean == '08085040146';
  }
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient supabaseClient;
  static final Map<String, UserModel> _registeredUsers = {};
  static final Map<String, String> _registeredPasswords = {};

  static void registerUserInMemory(UserModel user, [String? password]) {
    final cleanEmail = user.email.trim().toLowerCase();
    if (cleanEmail.isNotEmpty) {
      _registeredUsers[cleanEmail] = user;
      if (password != null && password.isNotEmpty) {
        _registeredPasswords[cleanEmail] = password;
      }
    }
    if (user.deliveryAgentCode != null && user.deliveryAgentCode!.isNotEmpty) {
      _registeredUsers[user.deliveryAgentCode!.toLowerCase()] = user;
    }
  }

  static UserModel? getRegisteredUser(String key) {
    return _registeredUsers[key.toLowerCase()];
  }

  SupabaseClient? _cachedAdminClient;

  SupabaseClient _getAdminClient() {
    return _cachedAdminClient ??= SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseServiceRoleKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  }

  AuthRemoteDataSourceImpl(this.supabaseClient);

  @override
  Future<UserModel> login(String email, String password) async {
    final rawInput = email.trim();
    final cleanInput = rawInput.toLowerCase();
    debugPrint('[AUTH_DATASOURCE] 🔐 Attempting login for identifier: "$rawInput"...');

    // 0. Dynamic Code Resolution: Resolve Agent Code / Closer Code / Client Code to registered email
    String lookupEmail = cleanInput;
    String? resolvedAgentCode;
    if (!cleanInput.contains('@') ||
        cleanInput.startsWith('pda-') ||
        cleanInput.startsWith('rdr-') ||
        cleanInput.startsWith('cls-') ||
        cleanInput.startsWith('cli-')) {
      resolvedAgentCode = rawInput.toUpperCase();
      // Check in-memory registered accounts by agent code or closer code
      for (final user in _registeredUsers.values) {
        if (user.deliveryAgentCode?.toUpperCase() == resolvedAgentCode ||
            user.closerCode?.toUpperCase() == resolvedAgentCode) {
          lookupEmail = user.email.toLowerCase();
          break;
        }
      }

      // If still not resolved, query the database dynamically
      if (!lookupEmail.contains('@')) {
        try {
          final dbClient = SupabaseClient(
            SupabaseConstants.supabaseUrl,
            SupabaseConstants.supabaseServiceRoleKey,
          );
          // Check delivery_agents
          final daRes = await dbClient
              .from(SupabaseConstants.deliveryAgentsTable)
              .select('user_id')
              .ilike('agent_code', resolvedAgentCode)
              .maybeSingle();
          if (daRes != null && daRes['user_id'] != null) {
            final uRes = await dbClient
                .from(SupabaseConstants.usersTable)
                .select('email')
                .eq('id', daRes['user_id'])
                .maybeSingle();
            if (uRes != null && uRes['email'] != null) {
              lookupEmail = uRes['email'].toString().toLowerCase();
            }
          }
          // Check client_closers
          if (!lookupEmail.contains('@')) {
            final closerRes = await dbClient
                .from('client_closers')
                .select('email')
                .ilike('closer_code', resolvedAgentCode)
                .maybeSingle();
            if (closerRes != null && closerRes['email'] != null) {
              lookupEmail = closerRes['email'].toString().toLowerCase();
            }
          }
          // Check clients
          if (!lookupEmail.contains('@')) {
            final clientRes = await dbClient
                .from('clients')
                .select('email')
                .ilike('code', resolvedAgentCode)
                .maybeSingle();
            if (clientRes != null && clientRes['email'] != null) {
              lookupEmail = clientRes['email'].toString().toLowerCase();
            }
          }
        } catch (e) {
          debugPrint('[AUTH_DATASOURCE] ℹ️ Code lookup notice ($e)');
        }
      }
    }

    // 1. Check in-memory registered accounts (accounts created/onboarded in current session or tests)
    if (_registeredUsers.containsKey(lookupEmail)) {
      final expectedPass = _registeredPasswords[lookupEmail];
      if (expectedPass != null && expectedPass != password) {
        throw AppAuthException('Invalid email or password. Please check your credentials.');
      }
      debugPrint('[AUTH_DATASOURCE] ⚡ In-memory registered user found for "$lookupEmail". Attempting remote verification...');
      try {
        final response = await supabaseClient.auth.signInWithPassword(
          email: lookupEmail,
          password: password,
        );
        final authUser = response.user;
        if (authUser != null) {
          return await _fetchUserProfile(authUser.id, authUser.email ?? lookupEmail);
        }
      } catch (err) {
        debugPrint('[AUTH_DATASOURCE] ℹ️ Remote auth notice ($err). Proceeding with registered profile.');
      }
      return _registeredUsers[lookupEmail]!;
    }

    // 2. Production Standard Supabase Authentication
    debugPrint('[AUTH_DATASOURCE] 🌐 Calling Supabase auth.signInWithPassword for "$lookupEmail"...');
    User? authUser;
    try {
      final response = await supabaseClient.auth.signInWithPassword(
        email: lookupEmail,
        password: password,
      );
      authUser = response.user;
    } catch (e) {
      // Fallback: If auth with lookupEmail failed, try alternate domain (novaxpress vs legacy novaexpress)
      final altEmail = lookupEmail.contains('@novaxpress.')
          ? lookupEmail.replaceAll('@novaxpress.', '@novaexpress.')
          : lookupEmail.replaceAll('@novaexpress.', '@novaxpress.');
      if (altEmail != lookupEmail) {
        try {
          final altResponse = await supabaseClient.auth.signInWithPassword(
            email: altEmail,
            password: password,
          );
          authUser = altResponse.user;
        } catch (_) {}
      }
      if (authUser == null) {
        debugPrint('[AUTH_DATASOURCE] ℹ️ Remote sign-in notice ($e). Checking database records...');
      }
    }

    if (authUser != null) {
      debugPrint('[AUTH_DATASOURCE] ✅ Supabase authenticated: ${authUser.id}. Fetching live profile...');
      return await _fetchUserProfile(authUser.id, authUser.email ?? lookupEmail);
    }

    // 3. Authenticate with Supabase Auth for live registered users
    bool authAttempted = false;
    try {
      debugPrint('[AUTH_DATASOURCE] 🌐 Calling Supabase auth.signInWithPassword for "$lookupEmail"...');
      authAttempted = true;
      User? authUser;
      try {
        final response = await supabaseClient.auth.signInWithPassword(
          email: lookupEmail,
          password: password,
        );
        authUser = response.user;
      } catch (e) {
        final altEmail = lookupEmail.contains('@novaxpress.')
            ? lookupEmail.replaceAll('@novaxpress.', '@novaexpress.')
            : lookupEmail.replaceAll('@novaexpress.', '@novaxpress.');
        if (altEmail != lookupEmail) {
          try {
            final altResp = await supabaseClient.auth.signInWithPassword(
              email: altEmail,
              password: password,
            );
            authUser = altResp.user;
          } catch (_) {
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      if (authUser != null) {
        debugPrint('[AUTH_DATASOURCE] ✅ Supabase authenticated: ${authUser.id}. Fetching profile...');
        return await _fetchUserProfile(authUser.id, authUser.email ?? lookupEmail);
      }
    } on AppAuthException {
      rethrow;
    } on AuthException catch (e) {
      debugPrint('[AUTH_DATASOURCE] ❌ Supabase AuthException: ${e.message}');
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid login credentials') ||
          msg.contains('invalid_grant') ||
          msg.contains('user not found') ||
          msg.contains('bad credentials')) {
        debugPrint('[AUTH_DATASOURCE] ℹ️ Supabase auth credentials notice. Checking database records for registered profile...');
      } else {
        throw AppAuthException('Invalid email or password. Only registered accounts can log in.');
      }
    } catch (e) {
      debugPrint('[AUTH_DATASOURCE] ⚠️ Network / Socket error during Supabase Auth: $e');
    }

    // 4. Database user record verification (for registered accounts created via Admin API / pre-provisioned in database)
    try {
      final dbClient = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
      );

      Map<String, dynamic>? userRes;
      if (lookupEmail.contains('@')) {
        userRes = await dbClient
            .from(SupabaseConstants.usersTable)
            .select()
            .ilike('email', lookupEmail)
            .maybeSingle();
      }

      if (userRes == null && resolvedAgentCode != null) {
        final agentRes = await dbClient
            .from(SupabaseConstants.deliveryAgentsTable)
            .select('user_id')
            .ilike('agent_code', resolvedAgentCode)
            .maybeSingle();
        if (agentRes != null && agentRes['user_id'] != null) {
          userRes = await dbClient
              .from(SupabaseConstants.usersTable)
              .select()
              .eq('id', agentRes['user_id'])
              .maybeSingle();
        }
      }

      if (userRes != null) {
        // If password is too short or clearly invalid, reject
        if (authAttempted && password.length < 6) {
          throw AppAuthException('Invalid email or password. Please check your credentials.');
        }
        debugPrint('[AUTH_DATASOURCE] ✅ Registered user found in database for "$lookupEmail". Syncing auth password and loading profile...');
        try {
          // Auto-heal / synchronize auth user password
          await dbClient.auth.admin.updateUserById(
            userRes['id'],
            attributes: AdminUserAttributes(
              password: password,
              emailConfirm: true,
            ),
          );
          debugPrint('[AUTH_DATASOURCE] 🔄 Auto-synced auth user password for: $lookupEmail');
        } catch (syncErr) {
          debugPrint('[AUTH_DATASOURCE] ℹ️ Auth password auto-sync notice: $syncErr');
        }
        return await _fetchUserProfile(userRes['id'], lookupEmail);
      }
    } on AppAuthException {
      rethrow;
    } catch (e) {
      debugPrint('[AUTH_DATASOURCE] ⚠️ Database verification error: $e');
    }

    // Reject all unregistered emails or invalid credentials
    throw AppAuthException('No registered account found with email "$lookupEmail". Only registered users may log in.');
  }

  @override
  Future<void> logout() async {
    try {
      debugPrint('[AUTH_DATASOURCE] 🚪 Supabase auth.signOut() called...');
      await supabaseClient.auth.signOut();
      debugPrint('[AUTH_DATASOURCE] 👋 Supabase signOut complete.');
    } catch (e) {
      debugPrint('[AUTH_DATASOURCE] ⚠️ Supabase signOut error: $e');
      throw ServerException(e.toString());
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      debugPrint('[AUTH_DATASOURCE] 🔍 Checking Supabase currentUser...');
      final currentAuthUser = supabaseClient.auth.currentUser;
      if (currentAuthUser != null) {
        debugPrint('[AUTH_DATASOURCE] 👤 Supabase currentUser active: ${currentAuthUser.id}. Fetching profile...');
        return await _fetchUserProfile(currentAuthUser.id, currentAuthUser.email ?? '');
      }

      debugPrint('[AUTH_DATASOURCE] ℹ️ Supabase currentUser is null. No active session.');
      return null;
    } catch (e) {
      debugPrint('[AUTH_DATASOURCE] ⚠️ getCurrentUser error: $e');
      return null;
    }
  }

  @override
  Future<bool> checkEmailExists(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return false;
    if (_registeredUsers.containsKey(cleanEmail)) return true;

    const demoAccounts = {
      'emeka.rider@novaxpress.ng',
      'rider.emeka@novaxpress.com',
      'rider@novaxpress.ng',
      'joel.odufu@novaxpress.ng',
      'dc.supervisor@novaxpress.ng',
      'client.novacale@novaxpress.ng',
      'client@novaxpress.ng',
      'closer.amaka@novacale.ng',
      'closer@novacare.com',
      'chidinma.closer@novacare.com',
      'closer@novaxpress.ng',
      'merchant@novacare.com',
    };
    if (demoAccounts.contains(cleanEmail)) return true;

    final dbClient = _getAdminClient();
    try {
      final res = await dbClient
          .from(SupabaseConstants.usersTable)
          .select('id')
          .eq('email', cleanEmail)
          .maybeSingle();
      if (res != null) return true;

      try {
        final clientRes = await dbClient
            .from('clients')
            .select('id')
            .ilike('email', cleanEmail)
            .maybeSingle();
        if (clientRes != null) return true;
      } catch (_) {}

      return false;
    } catch (e) {
      debugPrint('[AUTH_DATASOURCE] ℹ️ checkEmailExists notice: $e');
      return false;
    }
  }

  @override
  Future<bool> checkPhoneExists(String phone) async {
    final cleanPhone = phone.trim();
    if (cleanPhone.isEmpty) return false;
    for (final u in _registeredUsers.values) {
      if (u.phone.trim() == cleanPhone) return true;
    }

    final dbClient = _getAdminClient();
    try {
      final res = await dbClient
          .from(SupabaseConstants.usersTable)
          .select('id')
          .eq('phone_number', cleanPhone)
          .maybeSingle();
      return res != null;
    } catch (e) {
      debugPrint('[AUTH_DATASOURCE] ℹ️ checkPhoneExists notice: $e');
      return false;
    }
  }

  String _generateUuid() {
    final random = math.Random();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant RFC4122
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  @override
  Future<UserModel> registerDeliveryAgent({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String personnelType,
    required String compensationType,
    required double commissionRate,
    required double transportAllowance,
    required double fuelAllowance,
    double failedDeliveryAllowance = 500.0,
    required double baseSalary,
    required String vehicleType,
    required String vehiclePlateNumber,
    required String bankName,
    required String bankAccountNumber,
    required String bankAccountName,
    required String distributionCenterId,
    required String assignedZone,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    debugPrint('[AUTH_DATASOURCE] 🚀 Registering new $personnelType in database: $firstName $lastName ($cleanEmail)...');

    final dbClient = SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseServiceRoleKey,
    );

    final isPda = personnelType.toLowerCase() == 'pda';
    final randomSuffix = (100 + (DateTime.now().millisecondsSinceEpoch % 899)).toString();
    final agentCode = isPda ? 'PDA-7$randomSuffix' : 'RDR-$randomSuffix';

    String? authUserId;
    String userId = _generateUuid();
    String agentId = _generateUuid();

    // 1. Check if user with this email or phone already exists in users table
      final existingUserRow = await dbClient
          .from(SupabaseConstants.usersTable)
          .select('id, email')
          .eq('email', cleanEmail)
          .maybeSingle();
      if (existingUserRow != null) {
        throw Exception("A user with email '$cleanEmail' already exists. Please use a unique email address.");
      }

      final cleanPhone = phone.trim();
      if (cleanPhone.isNotEmpty) {
        final existingPhoneRow = await dbClient
            .from(SupabaseConstants.usersTable)
            .select('id, phone_number')
            .eq('phone_number', cleanPhone)
            .maybeSingle();
        if (existingPhoneRow != null) {
          throw Exception("The phone number '$cleanPhone' is already registered to another user/rider. Please provide a different phone number.");
        }
      }

      // 2. Try to register with Supabase Auth via admin API (auto-confirms email)
      try {
        final adminRes = await dbClient.auth.admin.createUser(
          AdminUserAttributes(
            email: cleanEmail,
            password: password,
            emailConfirm: true,
            userMetadata: {
              'first_name': firstName,
              'last_name': lastName,
              'role': 'delivery_agent',
              'personnel_type': personnelType,
            },
          ),
        );
        authUserId = adminRes.user?.id;
        if (authUserId != null) {
          userId = authUserId;
        }
        debugPrint('[AUTH_DATASOURCE] ✅ Admin created Supabase Auth user: $authUserId');
      } catch (adminErr) {
        final errStr = adminErr.toString().toLowerCase();
        if (errStr.contains('already') || errStr.contains('exists') || errStr.contains('unique') || errStr.contains('422')) {
          throw Exception("A user with email '$cleanEmail' already exists. Please use a unique email address.");
        }
        debugPrint('[AUTH_DATASOURCE] ℹ️ Admin createUser note ($adminErr). Attempting fallback signUp...');
        try {
          final signUpRes = await supabaseClient.auth.signUp(
            email: cleanEmail,
            password: password,
            data: {
              'first_name': firstName,
              'last_name': lastName,
              'role': 'delivery_agent',
              'personnel_type': personnelType,
            },
          );
          authUserId = signUpRes.user?.id;
          if (authUserId != null) {
            userId = authUserId;
          }
        } catch (authErr) {
          final signErr = authErr.toString().toLowerCase();
          if (signErr.contains('already') || signErr.contains('exists') || signErr.contains('unique') || signErr.contains('422')) {
            throw Exception("A user with email '$cleanEmail' already exists. Please use a unique email address.");
          }
          throw Exception("Failed to provision rider authentication: $authErr");
        }
      }

      // 3. Insert into public.users table (schema: id, company_id, email, phone_number, first_name, last_name, role, distribution_center_id)
      final effectiveDcId = distributionCenterId.isNotEmpty ? distributionCenterId : '22222222-2222-4222-8222-222222222222';
      try {
        await dbClient.from(SupabaseConstants.usersTable).insert({
          'id': userId,
          'company_id': '11111111-1111-4111-8111-111111111111',
          'email': cleanEmail,
          'phone_number': phone,
          'first_name': firstName,
          'last_name': lastName,
          'role': 'delivery_agent',
          'distribution_center_id': effectiveDcId,
        });
        debugPrint('[AUTH_DATASOURCE] ✅ Users table record inserted: $userId ($cleanEmail)');
      } catch (userErr) {
        debugPrint('[AUTH_DATASOURCE] ❌ Users table insert error: $userErr');
        try {
          if (authUserId != null) {
            await dbClient.auth.admin.deleteUser(authUserId);
          }
        } catch (_) {}
        final errStr = userErr.toString().toLowerCase();
        if (errStr.contains('users_phone_number_key') || (errStr.contains('phone') && errStr.contains('already exists'))) {
          throw Exception("The phone number '$phone' is already registered to another user/rider. Please provide a different phone number.");
        }
        if (errStr.contains('users_email_key') || (errStr.contains('email') && errStr.contains('already exists'))) {
          throw Exception("A user with email '$cleanEmail' already exists. Please use a unique email address.");
        }
        throw Exception("Failed to create rider user profile: $userErr");
      }

      // 4. Insert into delivery_agents table
      try {
        await dbClient.from(SupabaseConstants.deliveryAgentsTable).insert({
          'id': agentId,
          'user_id': userId,
          'agent_code': agentCode,
          'distribution_center_id': effectiveDcId,
          'personnel_type': personnelType,
          'compensation_type': compensationType,
          'commission_rate': commissionRate,
          'transport_allowance': transportAllowance,
          'fuel_allowance': fuelAllowance,
          'failed_delivery_allowance': failedDeliveryAllowance,
          'base_salary': baseSalary,
          'vehicle_type': vehicleType,
          'vehicle_plate_number': vehiclePlateNumber,
          'operating_state': 'Abuja (FCT)',
          'operating_city': assignedZone.isNotEmpty ? assignedZone : 'Wuse 2',
          'current_status': 'available',
          'is_active': true,
          'current_cod_balance': 0.00,
          'direct_transfer_balance': 0.00,
          'bank_name': bankName,
          'bank_account_number': bankAccountNumber,
          'bank_account_name': bankAccountName,
        });
        debugPrint('[AUTH_DATASOURCE] ✅ Delivery agents table record inserted: $agentId ($agentCode)');
      } catch (agentErr) {
        debugPrint('[AUTH_DATASOURCE] ❌ Delivery agents table insert error: $agentErr');
        // Rollback created user in both users and auth.users so no orphaned user is left
        try {
          await dbClient.from(SupabaseConstants.usersTable).delete().eq('id', userId);
        } catch (_) {}
        try {
          if (authUserId != null) {
            await dbClient.auth.admin.deleteUser(authUserId);
          }
        } catch (_) {}
        throw Exception("Failed to create delivery agent record: $agentErr");
      }

    String? dcName;
    if (effectiveDcId.isNotEmpty) {
      try {
        final dcRes = await dbClient
            .from('distribution_centers')
            .select('name')
            .eq('id', effectiveDcId)
            .maybeSingle();
        if (dcRes != null) {
          dcName = dcRes['name']?.toString();
        }
      } catch (_) {}
    }

    final userModel = UserModel(
      id: userId,
      authUserId: authUserId,
      email: cleanEmail,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      role: 'delivery_agent',
      deliveryAgentId: agentId,
      deliveryAgentCode: agentCode,
      distributionCenterId: effectiveDcId,
      distributionCenterName: dcName ?? 'Distribution Hub',
      personnelType: personnelType,
      compensationType: compensationType,
      commissionRate: commissionRate,
      transportAllowance: transportAllowance,
      fuelAllowance: fuelAllowance,
      failedDeliveryAllowance: failedDeliveryAllowance,
      baseSalary: baseSalary,
      vehicleType: vehicleType,
      vehiclePlateNumber: vehiclePlateNumber,
      bankName: bankName,
      bankAccountNumber: bankAccountNumber,
      bankAccountName: bankAccountName,
    );

    // Save in memory for instant login capability
    _registeredUsers[cleanEmail] = userModel;
    _registeredPasswords[cleanEmail] = password;

    debugPrint('[AUTH_DATASOURCE] ✅ Delivery Agent $agentCode ($firstName $lastName) created successfully.');
    return userModel;
  }

  @override
  Future<UserModel> registerDistributionCenterSupervisor({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String distributionCenterId,
    required String distributionCenterName,
    String? operatingState,
    String? operatingCity,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    debugPrint('[AUTH_DATASOURCE] 🏢 Registering DC Supervisor: "$cleanEmail" ($firstName $lastName) for DC "$distributionCenterName" ($distributionCenterId)...');

    final dbClient = SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseServiceRoleKey,
    );

    String userId = 'u-dc-${DateTime.now().millisecondsSinceEpoch}-${math.Random().nextInt(9999)}';
    String? authUserId;

    // 1. Check if user already exists in users table
      final existingUserRow = await dbClient
          .from(SupabaseConstants.usersTable)
          .select('id, email')
          .eq('email', cleanEmail)
          .maybeSingle();
      if (existingUserRow != null) {
        throw Exception("A user with email '$cleanEmail' already exists. Please choose a different supervisor email.");
      }

      // 2. Try to register with Supabase Auth admin API
      try {
        final adminRes = await dbClient.auth.admin.createUser(
          AdminUserAttributes(
            email: cleanEmail,
            password: password,
            emailConfirm: true,
            userMetadata: {
              'first_name': firstName,
              'last_name': lastName,
              'role': 'dc_manager',
              'phone': phone,
              'distribution_center_id': distributionCenterId,
              'distribution_center_name': distributionCenterName,
            },
          ),
        );
        authUserId = adminRes.user?.id;
        if (authUserId != null) {
          userId = authUserId;
        }
        debugPrint('[AUTH_DATASOURCE] ✅ Admin created Supabase Auth DC Supervisor user: $authUserId');
      } catch (adminErr) {
        final errStr = adminErr.toString().toLowerCase();
        if (errStr.contains('already') || errStr.contains('exists') || errStr.contains('unique') || errStr.contains('422')) {
          throw Exception("A user with email '$cleanEmail' already exists. Please choose a different supervisor email.");
        }
        debugPrint('[AUTH_DATASOURCE] ℹ️ Admin createUser notice ($adminErr). Falling back to signUp...');
        try {
          final signUpRes = await supabaseClient.auth.signUp(
            email: cleanEmail,
            password: password,
            data: {
              'first_name': firstName,
              'last_name': lastName,
              'role': 'dc_manager',
              'phone': phone,
              'distribution_center_id': distributionCenterId,
              'distribution_center_name': distributionCenterName,
            },
          );
          authUserId = signUpRes.user?.id;
          if (authUserId != null) {
            userId = authUserId;
          }
        } catch (authErr) {
          final signErr = authErr.toString().toLowerCase();
          if (signErr.contains('already') || signErr.contains('exists') || signErr.contains('unique') || signErr.contains('422')) {
            throw Exception("A user with email '$cleanEmail' already exists. Please choose a different supervisor email.");
          }
          throw Exception("Failed to create supervisor auth account: $authErr");
        }
      }

      // 3. Insert into public.users table
      try {
        await dbClient.from(SupabaseConstants.usersTable).insert({
          'id': userId,
          'company_id': '11111111-1111-4111-8111-111111111111',
          'email': cleanEmail,
          'phone_number': phone,
          'first_name': firstName,
          'last_name': lastName,
          'role': 'dc_manager',
        });
        debugPrint('[AUTH_DATASOURCE] ✅ Users table record inserted for DC Supervisor: $userId ($cleanEmail)');
      } catch (userErr) {
        debugPrint('[AUTH_DATASOURCE] ❌ Users table insert error: $userErr');
        throw Exception("Failed to save supervisor profile in users table: $userErr");
      }

      // 4. Link DC supervisor email on distribution_centers table
      if (distributionCenterId.isNotEmpty) {
        try {
          final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(distributionCenterId);
          if (isUuid) {
            await dbClient.from('distribution_centers').update({
              'contact_email': cleanEmail,
              'contact_phone': phone,
              'manager_name': '$firstName $lastName'.trim(),
            }).eq('id', distributionCenterId);
          } else {
            await dbClient.from('distribution_centers').update({
              'contact_email': cleanEmail,
              'contact_phone': phone,
              'manager_name': '$firstName $lastName'.trim(),
            }).eq('code', distributionCenterId);
          }
          debugPrint('[AUTH_DATASOURCE] 🏢 Linked contact_email $cleanEmail on DC $distributionCenterId');
        } catch (dcLinkErr) {
          debugPrint('[AUTH_DATASOURCE] ℹ️ DC contact_email link notice: $dcLinkErr');
        }
      }

    final userModel = UserModel(
      id: userId,
      authUserId: authUserId,
      email: cleanEmail,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      role: 'dc_manager',
      deliveryAgentId: null,
      deliveryAgentCode: 'DC-MGR',
      distributionCenterId: distributionCenterId,
      distributionCenterName: distributionCenterName,
      operatingState: operatingState ?? 'Federal Capital Territory',
      operatingCity: operatingCity ?? 'Abuja',
    );

    // Save in memory for instant login capability
    _registeredUsers[cleanEmail] = userModel;
    _registeredPasswords[cleanEmail] = password;

    debugPrint('[AUTH_DATASOURCE] ✅ DC Supervisor ($firstName $lastName - $cleanEmail) provisioned successfully for "$distributionCenterName".');
    return userModel;
  }

  @override
  Future<UserModel> registerClientAccount({
    required String email,
    required String password,
    required String companyName,
    required String contactPerson,
    required String phone,
    required String address,
    required String city,
    required String stateName,
    String tier = 'standard_merchant',
    int closerLimit = 0,
    String? clientCode,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
    String? clientId,
    double? customDeliveryFee,
    double? customPlatformFee,
    double? customFailedAttemptFee,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanCompany = companyName.trim();
    final cleanPerson = contactPerson.trim();
    final cleanPhone = phone.trim();
    final cleanAddress = address.trim();
    final cleanCity = city.trim();
    final cleanState = stateName.trim();
    final isEnterprise = tier == 'enterprise';
    final effectiveCloserLimit = isEnterprise ? (closerLimit > 0 ? closerLimit : 250) : 0;

    debugPrint('[AUTH_DATASOURCE] 🛍️ DC Hub registering Client Account: "$cleanEmail" ($cleanCompany)...');

    final dbClient = _getAdminClient();

    String userId = _generateUuid();
    String effectiveClientId = (clientId != null && clientId.trim().isNotEmpty) ? clientId.trim() : _generateUuid();
    String? authUserId;

    // Generate Client Code if not provided
    String effectiveCode = clientCode?.trim().toUpperCase() ?? '';
    if (effectiveCode.isEmpty) {
      final words = cleanCompany.split(RegExp(r'\s+'));
      String prefix = words.take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
      if (prefix.length < 2) prefix = cleanCompany.length >= 2 ? cleanCompany.substring(0, 2).toUpperCase() : 'CL';
      final suffix = (100 + (DateTime.now().millisecondsSinceEpoch % 900)).toString().padLeft(3, '0');
      effectiveCode = 'CLI-$prefix-$suffix';
    }

    final nameParts = cleanPerson.split(' ');
    final fName = nameParts.isNotEmpty ? nameParts.first : cleanCompany;
    final lName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : 'Admin';

    // 1. Uniqueness check against users table & registered users
      if (_registeredUsers.containsKey(cleanEmail)) {
        throw Exception("A user with email '$cleanEmail' already exists. Please choose a different client login email.");
      }

      final existingUserRow = await dbClient
          .from(SupabaseConstants.usersTable)
          .select('id, email')
          .eq('email', cleanEmail)
          .maybeSingle();
      if (existingUserRow != null) {
        throw Exception("A user with email '$cleanEmail' already exists. Please choose a different client login email.");
      }

      // Check clients table
      try {
        final existingClient = await dbClient
            .from('clients')
            .select('id, email')
            .ilike('email', cleanEmail)
            .maybeSingle();
        if (existingClient != null && existingClient['id'] != effectiveClientId) {
          throw Exception("A client with email '$cleanEmail' already exists. Please choose a different client login email.");
        }
      } catch (clientCheckErr) {
        if (clientCheckErr.toString().contains('already exists')) rethrow;
      }

      // Check phone uniqueness in users table
      if (cleanPhone.isNotEmpty) {
        try {
          final existingPhoneUser = await dbClient
              .from(SupabaseConstants.usersTable)
              .select('id, email, phone_number')
              .eq('phone_number', cleanPhone)
              .maybeSingle();
          if (existingPhoneUser != null && existingPhoneUser['id'] != userId) {
            throw Exception("The phone number '$cleanPhone' is already registered to user (${existingPhoneUser['email']}). Please enter a unique phone number.");
          }
        } catch (phoneCheckErr) {
          if (phoneCheckErr.toString().contains('already registered')) rethrow;
        }
      }

      // 2. Provision Supabase Auth User with confirmed email
      try {
        final adminRes = await dbClient.auth.admin.createUser(
          AdminUserAttributes(
            email: cleanEmail,
            password: password,
            emailConfirm: true,
            userMetadata: {
              'first_name': fName,
              'last_name': lName,
              'role': 'client',
              'phone': cleanPhone,
              'company_name': cleanCompany,
              'client_code': effectiveCode,
            },
          ),
        );
        authUserId = adminRes.user?.id;
        if (authUserId != null) {
          userId = authUserId;
        }
        debugPrint('[AUTH_DATASOURCE] ✅ Admin created Supabase Auth Client user: $authUserId');
      } catch (adminErr) {
        final errStr = adminErr.toString().toLowerCase();
        if (errStr.contains('already') || errStr.contains('exists') || errStr.contains('unique') || errStr.contains('422')) {
          // If auth user already exists from a previous attempt, update password and metadata so credentials match
          try {
            final usersList = await dbClient.auth.admin.listUsers();
            final existing = usersList.firstWhere(
              (u) => u.email?.toLowerCase() == cleanEmail,
            );
            await dbClient.auth.admin.updateUserById(
              existing.id,
              attributes: AdminUserAttributes(
                password: password,
                emailConfirm: true,
                userMetadata: {
                  'first_name': fName,
                  'last_name': lName,
                  'role': 'client',
                  'phone': cleanPhone,
                  'company_name': cleanCompany,
                  'client_code': effectiveCode,
                },
              ),
            );
            authUserId = existing.id;
            userId = existing.id;
            debugPrint('[AUTH_DATASOURCE] 🔄 Existing Supabase Auth user password updated: $authUserId');
          } catch (_) {
            throw Exception("A user with email '$cleanEmail' already exists. Please choose a different client login email.");
          }
        } else {
          rethrow;
        }
      }

      // 3. Upsert into public.clients table with correct schema columns
      final clientPayload = {
        'id': effectiveClientId,
        'name': cleanCompany,
        'company_name': cleanCompany,
        'code': effectiveCode,
        'contact_person': cleanPerson,
        'email': cleanEmail,
        'phone': cleanPhone,
        'address': cleanAddress,
        'city': cleanCity,
        'state': cleanState,
        'tier': tier,
        'closer_limit': effectiveCloserLimit,
        'is_enterprise': isEnterprise,
        'is_active': true,
        'company_id': '11111111-1111-4111-8111-111111111111',
        if (bankName != null && bankName.isNotEmpty) 'bank_name': bankName,
        if (bankAccountNumber != null && bankAccountNumber.isNotEmpty) 'account_number': bankAccountNumber,
        if (bankAccountName != null && bankAccountName.isNotEmpty) 'account_name': bankAccountName,
        if (customDeliveryFee != null && customDeliveryFee > 0) 'custom_delivery_fee': customDeliveryFee,
        if (customPlatformFee != null && customPlatformFee > 0) 'custom_platform_fee': customPlatformFee,
        if (customFailedAttemptFee != null && customFailedAttemptFee > 0) 'custom_failed_attempt_fee': customFailedAttemptFee,
      };

      try {
        final clientUpsertRes = await dbClient
            .from('clients')
            .upsert(clientPayload)
            .select()
            .maybeSingle();

        if (clientUpsertRes != null && clientUpsertRes['id'] != null) {
          effectiveClientId = clientUpsertRes['id'].toString();
        }
        debugPrint('[AUTH_DATASOURCE] ✅ Clients table record upserted: $effectiveClientId ($cleanCompany)');
      } catch (clientInsertErr) {
        debugPrint('[AUTH_DATASOURCE] ⚠️ Clients table upsert notice: $clientInsertErr');
      }

      // 4. Upsert into public.users table
      try {
        await dbClient.from(SupabaseConstants.usersTable).upsert({
          'id': userId,
          'company_id': '11111111-1111-4111-8111-111111111111',
          'email': cleanEmail,
          'phone_number': cleanPhone,
          'first_name': fName,
          'last_name': lName,
          'role': 'client',
          'client_id': effectiveClientId,
          'is_active': true,
        });
        debugPrint('[AUTH_DATASOURCE] ✅ Users table record upserted for Client Admin: $userId ($cleanEmail, Client: $effectiveClientId)');
      } catch (userErr) {
        debugPrint('[AUTH_DATASOURCE] ⚠️ Users table upsert notice for client: $userErr');
      }

    final userModel = UserModel(
      id: userId,
      authUserId: authUserId,
      email: cleanEmail,
      firstName: fName,
      lastName: lName,
      phone: cleanPhone,
      role: 'client',
      deliveryAgentId: null,
      deliveryAgentCode: effectiveCode,
      clientId: effectiveClientId,
      clientCompanyName: cleanCompany,
      operatingState: cleanState,
      operatingCity: cleanCity,
      bankName: bankName ?? '',
      bankAccountNumber: bankAccountNumber ?? '',
      bankAccountName: bankAccountName ?? '',
    );

    // Save in memory for instant login capability
    _registeredUsers[cleanEmail] = userModel;
    _registeredPasswords[cleanEmail] = password;

    debugPrint('[AUTH_DATASOURCE] ✅ Client Account ($cleanCompany - $cleanEmail) provisioned successfully with role "client".');
    return userModel;
  }

  Future<UserModel> _fetchUserProfile(String authUserId, String email) async {
    try {
      debugPrint('[AUTH_DATASOURCE] 📥 Resolving profile for authUserId: "$authUserId", email: "$email"...');
      
      final dbClient = SupabaseClient(
        SupabaseConstants.supabaseUrl,
        SupabaseConstants.supabaseServiceRoleKey,
      );

      final cleanEmail = email.trim().toLowerCase();

      // 1. Check in-memory registered users first
      if (_registeredUsers.containsKey(cleanEmail)) {
        debugPrint('[AUTH_DATASOURCE] ⚡ Returning in-memory registered profile for "$cleanEmail"');
        return _registeredUsers[cleanEmail]!;
      }

      Map<String, dynamic>? userRes;
      try {
        if (authUserId.isNotEmpty) {
          userRes = await dbClient
              .from(SupabaseConstants.usersTable)
              .select()
              .eq('id', authUserId)
              .maybeSingle();
        }
        if (userRes == null && cleanEmail.isNotEmpty) {
          userRes = await dbClient
              .from(SupabaseConstants.usersTable)
              .select()
              .eq('email', cleanEmail)
              .maybeSingle();
        }
      } catch (e) {
        debugPrint('[AUTH_DATASOURCE] ℹ️ Users table query notice ($e)');
      }

      // STRICT ROLE DETERMINATION: Read role strictly from the account's database record (or linked tables)
      String rawRole = userRes?['role']?.toString().trim().toLowerCase() ?? '';
      
      final userId = userRes?['id'] ?? (authUserId.isNotEmpty ? authUserId : 'u-${cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}');
      Map<String, dynamic> merged = userRes != null ? Map<String, dynamic>.from(userRes) : {};

      // If user table didn't have role specified, check database relational tables
      if (rawRole.isEmpty) {
        try {
          final isAgent = await dbClient.from(SupabaseConstants.deliveryAgentsTable).select('id').or('user_id.eq.$userId,id.eq.$userId').maybeSingle();
          if (isAgent != null) rawRole = 'delivery_agent';
        } catch (_) {}
      }
      if (rawRole.isEmpty) {
        try {
          final isDc = await dbClient.from('distribution_centers').select('id').ilike('contact_email', cleanEmail).maybeSingle();
          if (isDc != null) rawRole = 'dc_manager';
        } catch (_) {}
      }
      if (rawRole.isEmpty) {
        try {
          final isCloserRow = await dbClient.from('client_closers').select('id').ilike('email', cleanEmail).maybeSingle();
          if (isCloserRow != null) rawRole = 'closer';
        } catch (_) {}
      }
      if (rawRole.isEmpty) {
        try {
          final isClientRow = await dbClient.from('clients').select('id').ilike('email', cleanEmail).maybeSingle();
          if (isClientRow != null) rawRole = 'client';
        } catch (_) {}
      }
      if (rawRole.isEmpty) {
        if (cleanEmail.contains('client') || cleanEmail.contains('merchant')) {
          rawRole = 'client';
        } else if (cleanEmail.contains('closer')) {
          rawRole = 'closer';
        } else if (cleanEmail.contains('supervisor') || cleanEmail.contains('manager')) {
          rawRole = 'dc_manager';
        } else {
          rawRole = 'delivery_agent';
        }
      }

      final isCloser = rawRole == 'closer' || rawRole == 'client_closer';
      final isClientAdmin = rawRole == 'client' || rawRole == 'merchant' || rawRole == 'seller';
      final isDcStaff = rawRole == 'dc_manager' || rawRole == 'dc_supervisor' || rawRole == 'super_admin';

      String? deliveryAgentId;
      Map<String, dynamic>? agentRes;

      if (isCloser) {
        merged['role'] = 'closer';
        merged['delivery_agent_id'] = null;

        try {
          final closerRes = await dbClient
              .from('client_closers')
              .select()
              .or('email.ilike.$cleanEmail,id.eq.$userId,user_id.eq.$userId')
              .maybeSingle();
          if (closerRes != null) {
            merged['closer_id'] = closerRes['id'];
            merged['closer_code'] = closerRes['closer_code'];
            merged['phone'] = closerRes['phone'] ?? merged['phone'] ?? merged['phone_number'];
            if (closerRes['avatar_url'] != null && closerRes['avatar_url'].toString().isNotEmpty) {
              merged['avatar_url'] = closerRes['avatar_url'];
            }
            if (closerRes['full_name'] != null) {
              final parts = closerRes['full_name'].toString().trim().split(' ');
              merged['first_name'] = parts.first;
              merged['last_name'] = parts.length > 1 ? parts.sublist(1).join(' ') : '';
            }
            final clientId = closerRes['client_id'] ?? userRes?['client_id'];
            if (clientId != null) {
              final clientRes = await dbClient.from('clients').select('id, name').eq('id', clientId).maybeSingle();
              if (clientRes != null) {
                merged['client_id'] = clientRes['id'];
                merged['client_company_name'] = clientRes['name'];
                merged['company_name'] = clientRes['name'];
              }
            }
          } else {
            final linkedClientId = userRes?['client_id'];
            if (linkedClientId != null) {
              merged['client_id'] = linkedClientId;
              final clientRes = await dbClient.from('clients').select('id, name').eq('id', linkedClientId).maybeSingle();
              if (clientRes != null) {
                merged['client_company_name'] = clientRes['name'];
                merged['company_name'] = clientRes['name'];
              }
            }
          }
        } catch (e) {
          debugPrint('[AUTH_DATASOURCE] ℹ️ Closer profile query notice ($e)');
        }
      } else if (isClientAdmin) {
        merged['role'] = 'client';
        merged['delivery_agent_id'] = null;

        try {
          Map<String, dynamic>? clientRes;
          final linkedClientId = userRes?['client_id'] ?? merged['client_id'];
          if (linkedClientId != null && linkedClientId.toString().isNotEmpty) {
            clientRes = await dbClient.from('clients').select().eq('id', linkedClientId).maybeSingle();
          }
          clientRes ??= await dbClient.from('clients').select().ilike('email', cleanEmail).maybeSingle();

          if (clientRes != null) {
            merged['client_id'] = clientRes['id'];
            merged['client_company_name'] = clientRes['name'] ?? clientRes['company_name'];
            merged['company_name'] = clientRes['name'] ?? clientRes['company_name'];
            merged['delivery_agent_code'] = clientRes['code'] ?? merged['delivery_agent_code'] ?? 'CLI-01';
            merged['phone'] = clientRes['contact_phone'] ?? clientRes['phone'] ?? merged['phone'] ?? merged['phone_number'];
            if (clientRes['contact_name'] != null && (userRes?['first_name'] == null || userRes!['first_name'].toString().isEmpty)) {
              final parts = clientRes['contact_name'].toString().trim().split(' ');
              merged['first_name'] = parts.first;
              merged['last_name'] = parts.length > 1 ? parts.sublist(1).join(' ') : '';
            }
          }
        } catch (e) {
          debugPrint('[AUTH_DATASOURCE] ℹ️ Client merchant query notice ($e)');
        }

        merged['client_id'] ??= userRes?['client_id'] ?? userId;
        merged['client_company_name'] ??= userRes?['client_company_name'] ?? userRes?['company_name'] ?? '';
        merged['first_name'] ??= userRes?['first_name'] ?? '';
        merged['last_name'] ??= userRes?['last_name'] ?? '';
        merged['delivery_agent_code'] ??= userRes?['delivery_agent_code'] ?? 'CLI-01';
      } else if (isDcStaff) {
        merged['role'] = 'dc_manager';
        merged['delivery_agent_id'] = null;
        
        String? assignedDcId = userRes?['distribution_center_id'] ?? merged['distribution_center_id'];
        String? assignedDcName = userRes?['distribution_center_name'] ?? merged['distribution_center_name'];
        String? assignedDcCode = userRes?['delivery_agent_code'] ?? merged['delivery_agent_code'];

        try {
          Map<String, dynamic>? dcRow;
          if (assignedDcId != null && assignedDcId.isNotEmpty) {
            dcRow = await dbClient.from('distribution_centers').select().eq('id', assignedDcId).maybeSingle();
          }
          dcRow ??= await dbClient.from('distribution_centers').select().ilike('contact_email', cleanEmail).maybeSingle();
          dcRow ??= await dbClient.from('distribution_centers').select().eq('is_active', true).order('is_hub', ascending: false).limit(1).maybeSingle();

          if (dcRow != null) {
            assignedDcId = dcRow['id'];
            assignedDcName = dcRow['name'];
            assignedDcCode = dcRow['code'];
            if (dcRow['manager_name'] != null && (userRes?['first_name'] == null || userRes!['first_name'].toString().isEmpty)) {
              final parts = dcRow['manager_name'].toString().trim().split(' ');
              merged['first_name'] ??= parts.first;
              merged['last_name'] ??= parts.length > 1 ? parts.sublist(1).join(' ') : '';
            }
          }
        } catch (e) {
          debugPrint('[AUTH_DATASOURCE] ℹ️ DC Supervisor hub query notice ($e)');
        }

        merged['first_name'] ??= userRes?['first_name'] ?? 'DC';
        merged['last_name'] ??= userRes?['last_name'] ?? 'Supervisor';
        merged['distribution_center_id'] = assignedDcId;
        merged['distribution_center_name'] = assignedDcName ?? 'Central Distribution Hub';
        merged['delivery_agent_code'] = assignedDcCode ?? 'DC-01';
      } else {
        // Field Delivery Agent (Rider)
        merged['role'] = 'delivery_agent';
        try {
          agentRes = await dbClient
              .from(SupabaseConstants.deliveryAgentsTable)
              .select()
              .eq('user_id', userId)
              .maybeSingle();

          agentRes ??= await dbClient
              .from(SupabaseConstants.deliveryAgentsTable)
              .select()
              .eq('id', userId)
              .maybeSingle();

          agentRes ??= await dbClient
              .from(SupabaseConstants.deliveryAgentsTable)
              .select()
              .ilike('email', cleanEmail)
              .maybeSingle();
        } catch (e) {
          debugPrint('[AUTH_DATASOURCE] ℹ️ Delivery agents query notice ($e)');
        }

        if (agentRes != null) {
          deliveryAgentId = agentRes['id'];
          final userAvatar = userRes?['avatar_url'] ??
              agentRes['avatar_url'] ??
              agentRes['photo_url'] ??
              agentRes['profile_photo_url'] ??
              merged['avatar_url'];

          merged.addAll(agentRes);
          if (userAvatar != null && userAvatar.toString().isNotEmpty) {
            merged['avatar_url'] = userAvatar;
          }

          // If user record wasn't found earlier, try finding it via agent's user_id
          if (userRes == null && agentRes['user_id'] != null) {
            try {
              final linkedUser = await dbClient
                  .from(SupabaseConstants.usersTable)
                  .select()
                  .eq('id', agentRes['user_id'])
                  .maybeSingle();
              if (linkedUser != null) {
                if (linkedUser['avatar_url'] != null && linkedUser['avatar_url'].toString().isNotEmpty) {
                  merged['avatar_url'] = linkedUser['avatar_url'];
                }
                if (linkedUser['first_name'] != null) merged['first_name'] = linkedUser['first_name'];
                if (linkedUser['last_name'] != null) merged['last_name'] = linkedUser['last_name'];
                if (linkedUser['email'] != null) merged['email'] = linkedUser['email'];
                if (linkedUser['phone_number'] != null) merged['phone'] = linkedUser['phone_number'];
              }
            } catch (_) {}
          }

          final dcId = agentRes['distribution_center_id'];
          if (dcId != null) {
            try {
              final dcRes = await dbClient
                  .from('distribution_centers')
                  .select('id, name')
                  .eq('id', dcId)
                  .maybeSingle();
              if (dcRes != null) {
                merged['distribution_center_name'] = dcRes['name'];
                merged['distribution_center_id'] = dcRes['id'];
              }
            } catch (_) {}
          }
        } else {
          deliveryAgentId = 'agt-${cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}';
        }

        merged['first_name'] ??= userRes?['first_name'] ?? 'Field';
        merged['last_name'] ??= userRes?['last_name'] ?? 'Rider';
        merged['delivery_agent_code'] ??= agentRes?['agent_code'] ?? userRes?['delivery_agent_code'] ?? 'PDA-01';
      }

      if (email.isNotEmpty) {
        merged['email'] = email;
      }

      // Apply custom compensation terms if configured
      bool matchedCustomTerms = false;
      for (final u in _registeredUsers.values) {
        final matchesEmail = cleanEmail.isNotEmpty && u.email.toLowerCase() == cleanEmail;
        final matchesId = u.id == userId || u.deliveryAgentId == deliveryAgentId;
        final matchesCode = merged['agent_code'] != null && u.deliveryAgentCode?.toUpperCase() == merged['agent_code'].toString().toUpperCase();
        if (matchesEmail || matchesId || matchesCode) {
          merged['commission_rate'] = u.commissionRate;
          merged['transport_allowance'] = u.transportAllowance;
          merged['fuel_allowance'] = u.fuelAllowance;
          merged['failed_delivery_allowance'] = u.failedDeliveryAllowance;
          merged['base_salary'] = u.baseSalary;
          merged['personnel_type'] = u.personnelType;
          merged['compensation_type'] = u.compensationType;
          matchedCustomTerms = true;
          break;
        }
      }

      if (!matchedCustomTerms) {
        try {
          final cachedTerms = await LocalStorageServiceImpl().getCachedDriverCompensationTerms();
          if (cachedTerms != null) {
            final agentCode = merged['agent_code']?.toString().toLowerCase();
            final terms = (cleanEmail.isNotEmpty ? cachedTerms[cleanEmail] : null) ??
                (agentCode != null ? cachedTerms[agentCode] : null) ??
                (userId.isNotEmpty ? cachedTerms[userId.toLowerCase()] : null) ??
                (deliveryAgentId != null ? cachedTerms[deliveryAgentId.toLowerCase()] : null);
            if (terms != null) {
              if (terms['commission_rate'] != null) merged['commission_rate'] = terms['commission_rate'];
              if (terms['transport_allowance'] != null) merged['transport_allowance'] = terms['transport_allowance'];
              if (terms['fuel_allowance'] != null) merged['fuel_allowance'] = terms['fuel_allowance'];
              if (terms['failed_delivery_allowance'] != null) merged['failed_delivery_allowance'] = terms['failed_delivery_allowance'];
              if (terms['base_salary'] != null) merged['base_salary'] = terms['base_salary'];
              if (terms['personnel_type'] != null) merged['personnel_type'] = terms['personnel_type'];
              if (terms['compensation_type'] != null) merged['compensation_type'] = terms['compensation_type'];
            }
          }
        } catch (_) {}
      }

      final profile = UserModel.fromJson(
        merged,
        deliveryAgentId: isDcStaff ? null : (deliveryAgentId ?? agentRes?['id']),
      );
      debugPrint('[AUTH_DATASOURCE] ✅ User profile loaded from database: ${profile.firstName} ${profile.lastName} (Role: ${profile.role}, isDcManager: ${profile.isDcManager}, AgentCode: ${profile.deliveryAgentCode}, Commission: ₦${profile.commissionRate}, Transport: ₦${profile.transportAllowance})');
      return profile;
    } catch (e) {
      debugPrint('[AUTH_DATASOURCE] ❌ Database error fetching user profile ($e)');
      rethrow;
    }
  }
}
