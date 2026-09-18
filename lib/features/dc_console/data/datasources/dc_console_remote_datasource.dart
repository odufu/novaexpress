import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../client_portal/domain/entities/client_profile.dart';
import '../../../client_portal/domain/entities/client_settlement.dart';
import '../../domain/entities/dc_finance_settings.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../../domain/entities/dc_payout_claim.dart';
import '../../domain/entities/dc_transaction_record.dart';
import '../../domain/entities/distribution_center.dart';

abstract class DCConsoleRemoteDataSource {
  Future<List<DistributionCenter>> fetchDistributionCenters();
  Future<DistributionCenter> createDistributionCenter({
    required String name,
    required String code,
    required String stateName,
    required String city,
    required String address,
    String? contactPhone,
    String? contactEmail,
    String? managerName,
    bool isHub = false,
    String? parentDcId,
    int storageCapacityUnits = 25000,
    List<String> operatingZones = const [],
    String? supervisorEmail,
    String? supervisorPassword,
    dynamic authDataSource,
  });
  Future<void> updateDistributionCenter(DistributionCenter dc);
  Future<void> toggleDistributionCenterStatus(String dcId, bool isActive);
  Future<void> updateOperatingZones(String dcId, List<String> zones);
  Future<void> deleteDistributionCenter(String dcId);
  Future<List<DCFleetDriver>> fetchDrivers();
  Future<void> updateDriverCompensationTerms(DCFleetDriver driver);
  Future<DCFinanceSettings?> fetchFinanceSettings();
  Future<void> updateFinanceSettings(DCFinanceSettings settings);
  Future<List<DCPayoutClaim>> fetchPayoutClaims();
  Future<void> approvePayoutClaim({
    required String claimId,
    required double amount,
    required String driverId,
    String? disbursementRef,
  });
  Future<void> rejectPayoutClaim({
    required String claimId,
    required String reason,
  });
  Future<List<DCTransactionRecord>> fetchDcTransactions();
  Future<List<ClientProfile>> fetchClients();
  Future<bool> checkEmailExists(String email);
  Future<ClientProfile> createClient({
    required String companyName,
    required String contactPerson,
    required String email,
    required String phone,
    required String address,
    required String city,
    required String stateName,
    String tier = 'standard',
    int closerLimit = 100,
    String? password,
    String? clientCode,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
    double? customDeliveryFee,
    double? customPlatformFee,
    double? customFailedAttemptFee,
    dynamic authDataSource,
  });
  Future<Map<String, dynamic>> approveCashRemittance({
    required String remittanceId,
    String? supervisorId,
  });
  Future<Map<String, dynamic>> generateDailyMerchantSettlement({
    required String clientId,
    required String dcId,
    required DateTime periodStart,
    required DateTime periodEnd,
    Map<String, dynamic>? customDeductions,
    List<String>? orderIds,
  });
  Future<List<ClientSettlement>> fetchDcClientSettlements({
    required String dcId,
    String? clientId,
  });
  Future<Map<String, dynamic>> fetchMerchantAssetCustody({
    required String clientId,
    String? dcId,
  });
  Future<ClientProfile> updateClientFinancialTariffs({
    required String clientId,
    required double customDeliveryFee,
    required double customFailedAttemptFee,
    required double customPlatformFee,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
  });
}

class DCConsoleRemoteDataSourceImpl implements DCConsoleRemoteDataSource {
  final SupabaseClient? _client;
  SupabaseClient? _cachedAdminClient;

  DCConsoleRemoteDataSourceImpl([SupabaseClient? client]) : _client = client;

  SupabaseClient _getAdminClient() {
    return _cachedAdminClient ??= SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseServiceRoleKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  }

  SupabaseClient _getClient() {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return _getAdminClient();
    }
  }

  @override
  Future<List<DistributionCenter>> fetchDistributionCenters() async {
    final response = await _getClient()
        .from('distribution_centers')
        .select('*')
        .order('name', ascending: true);

    final List<DistributionCenter> list = [];
    for (final item in response as List) {
      try {
        list.add(DistributionCenter.fromJson(item as Map<String, dynamic>));
      } catch (e) {
        debugPrint('[DC_DATASOURCE] ⚠️ Parse notice for DC: $e');
      }
    }
    return list;
  }

  @override
  Future<DistributionCenter> createDistributionCenter({
    required String name,
    required String code,
    required String stateName,
    required String city,
    required String address,
    String? contactPhone,
    String? contactEmail,
    String? managerName,
    bool isHub = false,
    String? parentDcId,
    int storageCapacityUnits = 25000,
    List<String> operatingZones = const [],
    String? supervisorEmail,
    String? supervisorPassword,
    dynamic authDataSource,
  }) async {
    final cleanCode = code.trim().toUpperCase();
    final cleanName = name.trim();
    final supEmail = (supervisorEmail != null && supervisorEmail.trim().isNotEmpty)
        ? supervisorEmail.trim().toLowerCase()
        : (contactEmail?.trim().isNotEmpty == true ? contactEmail!.trim().toLowerCase() : 'supervisor.${cleanCode.toLowerCase()}@novaxpress.ng');
    final supPass = (supervisorPassword != null && supervisorPassword.trim().length >= 6)
        ? supervisorPassword.trim()
        : 'Password123!';

    final newDcId = _generateUuid();
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    String persistentId = newDcId;

    final cleanAddress = address.trim();
    final effectiveAddress = cleanAddress.isNotEmpty ? cleanAddress : '${city.trim()}, ${stateName.trim()} State';
    final effectiveZones = operatingZones.isNotEmpty ? operatingZones : [city.trim()];
    final effectiveManager = managerName?.trim().isNotEmpty == true ? managerName!.trim() : 'Station Supervisor';
    final effectivePhone = contactPhone?.trim().isNotEmpty == true ? contactPhone!.trim() : '+234 800 000 0000';
    final effectiveCapacity = storageCapacityUnits > 0 ? storageCapacityUnits : 25000;

    final adminDb = _getAdminClient();
      // 1. Pre-flight check against users table for duplicate email
      final existingUser = await adminDb
          .from('users')
          .select('id, email')
          .eq('email', supEmail)
          .maybeSingle();
      if (existingUser != null) {
        throw Exception("A user with email '$supEmail' already exists. Please choose a different supervisor email.");
      }

      // 2. Pre-flight check against distribution_centers for duplicate code
      final existingDcRow = await adminDb
          .from('distribution_centers')
          .select('id, code, name')
          .eq('code', cleanCode)
          .maybeSingle();
      if (existingDcRow != null) {
        throw Exception("A distribution center with code '$cleanCode' already exists (${existingDcRow['name']}). Please choose a unique DC code.");
      }

      // 3. Persist Distribution Center row
      final insertPayload = <String, dynamic>{
        'id': newDcId,
        'name': cleanName,
        'code': cleanCode,
        'state': stateName.trim(),
        'city': city.trim(),
        'address': effectiveAddress,
        'contact_phone': effectivePhone,
        'contact_email': supEmail,
        'manager_name': effectiveManager,
        'is_hub': isHub,
        'is_active': true,
        'operating_zones': effectiveZones,
        'storage_capacity_units': effectiveCapacity,
        'company_id': '11111111-1111-4111-8111-111111111111',
      };
      if (parentDcId != null && uuidRegex.hasMatch(parentDcId)) {
        insertPayload['parent_dc_id'] = parentDcId;
      }

      final insertRes = await adminDb
          .from('distribution_centers')
          .insert(insertPayload)
          .select()
          .single();

      if (insertRes['id'] != null) {
        persistentId = insertRes['id'].toString();
      }

    // 4. Provision Auth Account for DC Station Supervisor
    final nameParts = effectiveManager.split(' ');
    final fName = nameParts.isNotEmpty ? nameParts.first : 'Station';
    final lName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : 'Supervisor';

    try {
      if (authDataSource != null) {
        await authDataSource.registerDistributionCenterSupervisor(
          email: supEmail,
          password: supPass,
          firstName: fName,
          lastName: lName,
          phone: effectivePhone,
          distributionCenterId: persistentId,
          distributionCenterName: cleanName,
        );
      } else {
        final authDs = AuthRemoteDataSourceImpl(_getAdminClient());
        await authDs.registerDistributionCenterSupervisor(
          email: supEmail,
          password: supPass,
          firstName: fName,
          lastName: lName,
          phone: effectivePhone,
          distributionCenterId: persistentId,
          distributionCenterName: cleanName,
        );
      }
    } catch (authErr) {
      debugPrint('[DC_DATASOURCE] ❌ Supervisor auth provisioning error: $authErr');
      // Rollback created DC row to prevent orphan unmanaged records
      final rollbackDb = _getAdminClient();
      try {
        await rollbackDb.from('distribution_centers').delete().eq('id', persistentId);
      } catch (_) {} finally {
        rollbackDb.dispose();
      }
      rethrow;
    }

    return DistributionCenter(
      id: persistentId,
      companyId: '11111111-1111-4111-8111-111111111111',
      name: cleanName,
      code: cleanCode,
      state: stateName.trim(),
      city: city.trim(),
      address: address.trim(),
      managerName: effectiveManager,
      contactPhone: effectivePhone,
      contactEmail: supEmail,
      isHub: isHub,
      isActive: true,
      parentDcId: parentDcId,
      storageCapacityUnits: effectiveCapacity,
      operatingZones: effectiveZones,
      totalAssignedRiders: 0,
      activeInventoryBatches: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> updateDistributionCenter(DistributionCenter dc) async {
    final adminDb = _getAdminClient();
      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      final updatePayload = <String, dynamic>{
        'name': dc.name,
        'code': dc.code,
        'state': dc.state,
        'city': dc.city,
        'address': dc.address,
        'contact_phone': dc.contactPhone,
        'contact_email': dc.contactEmail,
        'manager_name': dc.managerName,
        'is_hub': dc.isHub,
        'is_active': dc.isActive,
        'operating_zones': dc.operatingZones,
        'storage_capacity_units': dc.storageCapacityUnits,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (dc.parentDcId != null && uuidRegex.hasMatch(dc.parentDcId!)) {
        updatePayload['parent_dc_id'] = dc.parentDcId;
      }

      if (uuidRegex.hasMatch(dc.id)) {
        await adminDb.from('distribution_centers').update(updatePayload).eq('id', dc.id);
      } else {
        await adminDb.from('distribution_centers').update(updatePayload).eq('code', dc.code);
      }
  }

  @override
  Future<void> toggleDistributionCenterStatus(String dcId, bool isActive) async {
    final adminDb = _getAdminClient();
      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      if (uuidRegex.hasMatch(dcId)) {
        await adminDb.from('distribution_centers').update({'is_active': isActive}).eq('id', dcId);
      }
  }

  @override
  Future<void> updateOperatingZones(String dcId, List<String> zones) async {
    final adminDb = _getAdminClient();
      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      if (uuidRegex.hasMatch(dcId)) {
        await adminDb.from('distribution_centers').update({'operating_zones': zones}).eq('id', dcId);
      }
  }

  @override
  Future<void> deleteDistributionCenter(String dcId) async {
    final adminDb = _getAdminClient();
      await adminDb.from('distribution_centers').delete().eq('id', dcId);
  }

  @override
  Future<List<DCFleetDriver>> fetchDrivers() async {
    final client = _getAdminClient();
      final response = await client
          .from('delivery_agents')
          .select('*, users(first_name, last_name, email, phone_number, avatar_url)')
          .order('created_at', ascending: false);

      final List<DCFleetDriver> list = [];
      for (final item in response as List) {
        try {
          list.add(DCFleetDriver.fromJson(item as Map<String, dynamic>));
        } catch (e) {
          debugPrint('[DC_DATASOURCE] ⚠️ Parse notice for driver: $e');
        }
      }
      return list;
  }

  @override
  Future<void> updateDriverCompensationTerms(DCFleetDriver driver) async {
    final adminDb = _getAdminClient();
      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      final extendedPayload = <String, dynamic>{
        'commission_rate': driver.commissionRate,
        'transport_allowance': driver.transportAllowance,
        'failed_delivery_allowance': driver.failedDeliveryAllowance,
        'base_salary': driver.baseSalary,
        'personnel_type': driver.personnelType,
        'compensation_type': driver.compensationType,
        'covered_lgas': driver.coveredLgas,
      };
      if (driver.distributionCenterId != null && uuidRegex.hasMatch(driver.distributionCenterId!)) {
        extendedPayload['distribution_center_id'] = driver.distributionCenterId;
      }

      if (uuidRegex.hasMatch(driver.id)) {
        await adminDb.from('delivery_agents').update(extendedPayload).eq('id', driver.id);
      } else {
        await adminDb.from('delivery_agents').update(extendedPayload).eq('agent_code', driver.driverCode);
      }
  }

  @override
  Future<DCFinanceSettings?> fetchFinanceSettings() async {
    final adminDb = _getAdminClient();
      final response = await adminDb
          .from('dc_finance_settings')
          .select()
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return DCFinanceSettings.fromJson(response);
      }
      return null;
  }

  @override
  Future<void> updateFinanceSettings(DCFinanceSettings settings) async {
    final adminDb = _getAdminClient();
      final payload = <String, dynamic>{
        'id': 'global_finance_config',
        'pos_charge_mode': settings.posChargeMode,
        'pos_tier_amount': settings.posTierAmount,
        'pos_tier_fee': settings.posTierFee,
        'pos_flat_rate': settings.posFlatRate,
        'pos_max_cap_fee': settings.posMaxCapFee,
        'is_pos_fee_reimbursable': settings.isPosFeeReimbursable,
        'default_commission_rate': settings.defaultCommissionRate,
        'default_transport_allowance': settings.defaultTransportAllowance,
        'default_failed_delivery_allowance': settings.defaultFailedDeliveryAllowance,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await adminDb.from('dc_finance_settings').upsert(payload);
  }

  @override
  Future<List<DCPayoutClaim>> fetchPayoutClaims() async {
    final adminDb = _getAdminClient();
      final response = await adminDb
          .from('payout_requests')
          .select('*, delivery_agents(agent_code, current_cod_balance, direct_transfer_balance, users(first_name, last_name, email, phone_number))')
          .order('created_at', ascending: false);

      final List<DCPayoutClaim> list = [];
      for (final item in response as List) {
        try {
          list.add(DCPayoutClaim.fromJson(item as Map<String, dynamic>));
        } catch (_) {}
      }
      return list;
  }

  @override
  Future<void> approvePayoutClaim({
    required String claimId,
    required double amount,
    required String driverId,
    String? disbursementRef,
  }) async {
    final adminDb = _getAdminClient();
    final nowIso = DateTime.now().toIso8601String();
    await adminDb.from('payout_requests').update({
      'status': 'disbursed',
      if (disbursementRef != null && disbursementRef.isNotEmpty) 'disbursement_ref': disbursementRef,
      'approved_at': nowIso,
      'reviewed_at': nowIso,
      'updated_at': nowIso,
    }).eq('id', claimId);

    // Decrement driver entitlement
    try {
      await adminDb.rpc('decrement_driver_entitlement', params: {
        'p_driver_id': driverId,
        'p_amount': amount,
      });
    } catch (_) {}
  }

  @override
  Future<void> rejectPayoutClaim({
    required String claimId,
    required String reason,
  }) async {
    final adminDb = _getAdminClient();
      await adminDb.from('payout_requests').update({
        'status': 'rejected',
        'rejection_reason': reason,
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', claimId);
  }

  @override
  Future<List<DCTransactionRecord>> fetchDcTransactions() async {
    final adminDb = _getAdminClient();
      final List<DCTransactionRecord> results = [];

      // 1. Paystack Transactions
      try {
        final pstkRes = await adminDb
            .from('paystack_transactions')
            .select('*, orders(order_number, customer_name), delivery_agents(agent_code, users(first_name, last_name))')
            .order('created_at', ascending: false)
            .limit(50);
        for (final item in pstkRes as List) {
          try {
            results.add(DCTransactionRecord.fromJson(item as Map<String, dynamic>));
          } catch (_) {}
        }
      } catch (_) {}

      // 2. Rider Ledger Transactions
      try {
        final riderTxnRes = await adminDb
            .from('rider_transactions')
            .select('*, delivery_agents(agent_code, users(first_name, last_name))')
            .order('created_at', ascending: false)
            .limit(50);
        for (final item in riderTxnRes as List) {
          try {
            results.add(DCTransactionRecord.fromJson(item as Map<String, dynamic>));
          } catch (_) {}
        }
      } catch (_) {}

      // 3. Cash Remittances
      try {
        final remRes = await adminDb
            .from('cash_remittances')
            .select('*, delivery_agents(agent_code, users(first_name, last_name))')
            .order('created_at', ascending: false)
            .limit(50);
        for (final item in remRes as List) {
          try {
            results.add(DCTransactionRecord.fromJson(item as Map<String, dynamic>));
          } catch (_) {}
        }
      } catch (_) {}

      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return results;
  }

  @override
  Future<List<ClientProfile>> fetchClients() async {
    final adminDb = _getAdminClient();
      dynamic response;
      try {
        response = await adminDb
            .from('clients')
            .select('*, client_closers(id, is_active)')
            .order('created_at', ascending: false);
      } catch (_) {
        response = await adminDb
            .from('clients')
            .select('*')
            .order('created_at', ascending: false);
      }

      final List<ClientProfile> list = [];
      for (final item in response as List) {
        try {
          list.add(ClientProfile.fromJson(item as Map<String, dynamic>));
        } catch (_) {}
      }
      return list;
  }

  @override
  Future<bool> checkEmailExists(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return false;

    const demoAccounts = {
      'emeka.rider@novaxpress.ng',
      'rider.emeka@novaxpress.com',
      'joel.odufu@novaxpress.ng',
      'dc.supervisor@novaxpress.ng',
    };
    if (demoAccounts.contains(cleanEmail)) return true;

    final registeredUser = AuthRemoteDataSourceImpl.getRegisteredUser(cleanEmail);
    if (registeredUser != null) return true;

    final adminDb = _getAdminClient();
    try {
      final existingUser = await adminDb
          .from('users')
          .select('id, email')
          .eq('email', cleanEmail)
          .maybeSingle();
      if (existingUser != null) return true;

      final existingClient = await adminDb
          .from('clients')
          .select('id, email')
          .ilike('email', cleanEmail)
          .maybeSingle();
      if (existingClient != null) return true;

      return false;
    } catch (e) {
      debugPrint('[DC_DATASOURCE] ℹ️ checkEmailExists notice: $e');
      return false;
    }
  }

  @override
  Future<ClientProfile> createClient({
    required String companyName,
    required String contactPerson,
    required String email,
    required String phone,
    required String address,
    required String city,
    required String stateName,
    String tier = 'standard',
    int closerLimit = 100,
    String? password,
    String? clientCode,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
    double? customDeliveryFee,
    double? customPlatformFee,
    double? customFailedAttemptFee,
    dynamic authDataSource,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = companyName.trim();
    final cleanPerson = contactPerson.trim();
    final cleanPhone = phone.trim();
    final cleanAddress = address.trim();
    final cleanCity = city.trim();
    final cleanState = stateName.trim();
    final isEnt = tier.toLowerCase() == 'enterprise';
    final effectiveCloserLimit = isEnt ? (closerLimit > 0 ? closerLimit : 250) : 0;
    final effectivePassword = (password != null && password.trim().length >= 6)
        ? password.trim()
        : 'ClientPass123!';

    final adminDb = _getAdminClient();

    // 1. Determine or generate unique Client Code
    String effectiveCode = clientCode?.trim().toUpperCase() ?? '';
    if (effectiveCode.isEmpty) {
      final words = cleanName.split(RegExp(r'\s+'));
      String prefix = words.take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
      if (prefix.length < 2) prefix = cleanName.length >= 2 ? cleanName.substring(0, 2).toUpperCase() : 'CL';
      final suffix = (100 + (DateTime.now().millisecondsSinceEpoch % 900)).toString().padLeft(3, '0');
      effectiveCode = 'CLI-$prefix-$suffix';
    }

    String persistentClientId = _generateUuid();

    // 2. Pre-flight check against users table & registered in-memory users for duplicate email
    final registeredUser = AuthRemoteDataSourceImpl.getRegisteredUser(cleanEmail);
    if (registeredUser != null) {
      throw Exception("A user with email '$cleanEmail' already exists. Please use a unique email address.");
    }

    final existingUser = await adminDb
        .from('users')
        .select('id, email')
        .eq('email', cleanEmail)
        .maybeSingle();

    if (existingUser != null) {
      throw Exception("A user with email '$cleanEmail' already exists. Please use a unique email address.");
    }

    // Check duplicate phone in users table
    if (cleanPhone.isNotEmpty) {
        try {
          final existingPhoneUser = await adminDb
              .from('users')
              .select('id, email, phone_number')
              .eq('phone_number', cleanPhone)
              .maybeSingle();
          if (existingPhoneUser != null) {
            throw Exception("The phone number '$cleanPhone' is already registered to user (${existingPhoneUser['email'] ?? 'another account'}). Please use a distinct phone number for this client.");
          }
        } catch (phoneErr) {
          if (phoneErr.toString().contains('already registered')) rethrow;
        }
      }

      // Check duplicate against clients table
      try {
        final existingClient = await adminDb
            .from('clients')
            .select('id, email')
            .ilike('email', cleanEmail)
            .maybeSingle();
        if (existingClient != null) {
          throw Exception("A client with email '$cleanEmail' already exists. Please use a unique email address.");
        }
      } catch (clientCheckErr) {
        if (clientCheckErr.toString().contains('already exists')) rethrow;
      }

      // 3. Insert/Upsert record into clients table with authoritative column names
      final clientPayload = {
        'id': persistentClientId,
        'company_name': cleanName,
        'name': cleanName,
        'code': effectiveCode,
        'contact_person': cleanPerson,
        'email': cleanEmail,
        'phone': cleanPhone,
        'address': cleanAddress,
        'city': cleanCity,
        'state': cleanState,
        'tier': tier,
        'closer_limit': effectiveCloserLimit,
        'is_enterprise': isEnt,
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
        final insertRes = await adminDb
            .from('clients')
            .upsert(clientPayload)
            .select()
            .single();
        if (insertRes['id'] != null) {
          persistentClientId = insertRes['id'].toString();
        }
      } catch (dbErr) {
        debugPrint('[DC_DATASOURCE] ⚠️ Clients table upsert notice: $dbErr');
        if (dbErr.toString().contains('already exists')) rethrow;
      }

      // 4. Provision Authentication Account for the Client Admin
      final effectiveAuthDs = (authDataSource is AuthRemoteDataSource)
          ? authDataSource
          : AuthRemoteDataSourceImpl(_getAdminClient());

      await effectiveAuthDs.registerClientAccount(
        email: cleanEmail,
        password: effectivePassword,
        companyName: cleanName,
        contactPerson: cleanPerson,
        phone: cleanPhone,
        address: cleanAddress,
        city: cleanCity,
        stateName: cleanState,
        tier: tier,
        closerLimit: effectiveCloserLimit,
        clientCode: effectiveCode,
        bankName: bankName,
        bankAccountNumber: bankAccountNumber,
        bankAccountName: bankAccountName,
        clientId: persistentClientId,
        customDeliveryFee: customDeliveryFee,
        customPlatformFee: customPlatformFee,
        customFailedAttemptFee: customFailedAttemptFee,
      );

      // Also register in-memory for instant immediate capability in active session
      final nameParts = cleanPerson.split(' ');
      final fName = nameParts.isNotEmpty ? nameParts.first : cleanName;
      final lName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : 'Admin';
      AuthRemoteDataSourceImpl.registerUserInMemory(
        UserModel(
          id: persistentClientId,
          email: cleanEmail,
          firstName: fName,
          lastName: lName,
          phone: cleanPhone,
          role: 'client',
          clientId: persistentClientId,
          clientCompanyName: cleanName,
          deliveryAgentCode: effectiveCode,
          operatingState: cleanState,
          operatingCity: cleanCity,
          bankName: bankName ?? '',
          bankAccountNumber: bankAccountNumber ?? '',
          bankAccountName: bankAccountName ?? '',
        ),
        effectivePassword,
      );

    return ClientProfile(
      id: persistentClientId,
      companyName: cleanName,
      contactPerson: cleanPerson,
      email: cleanEmail,
      phone: cleanPhone,
      address: cleanAddress,
      city: cleanCity,
      state: cleanState,
      code: effectiveCode,
      tier: tier,
      closerLimit: effectiveCloserLimit,
      isEnterprise: isEnt,
      totalClosersCount: 0,
      isActive: true,
      bankName: bankName ?? '',
      accountNumber: bankAccountNumber ?? '',
      accountName: bankAccountName ?? cleanName,
      customDeliveryFee: customDeliveryFee,
      customPlatformFeeValue: customPlatformFee,
      customFailedAttemptFee: customFailedAttemptFee,
      createdAt: DateTime.now(),
    );
  }

  String _generateUuid() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final r = (now % 1000000000000).toString().padLeft(12, '0');
    return '00000000-0000-4000-8000-$r';
  }

  @override
  Future<Map<String, dynamic>> approveCashRemittance({
    required String remittanceId,
    String? supervisorId,
  }) async {
    final adminDb = _getAdminClient();
    try {
      final response = await adminDb.rpc('fn_approve_cash_remittance', params: {
        'p_remittance_id': remittanceId,
        if (supervisorId != null) 'p_supervisor_id': supervisorId,
      });

      debugPrint('[DC_CONSOLE] ✅ Remittance $remittanceId verified and COD balance cleared.');
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('[DC_CONSOLE] ❌ approveCashRemittance error: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> generateDailyMerchantSettlement({
    required String clientId,
    required String dcId,
    required DateTime periodStart,
    required DateTime periodEnd,
    Map<String, dynamic>? customDeductions,
    List<String>? orderIds,
  }) async {
    final adminDb = _getAdminClient();
    try {
      final response = await adminDb.rpc('fn_generate_merchant_daily_settlement', params: {
        'p_client_id': clientId,
        'p_dc_id': dcId,
        'p_period_start': periodStart.toIso8601String(),
        'p_period_end': periodEnd.toIso8601String(),
        if (customDeductions != null) 'p_custom_deductions': customDeductions,
        if (orderIds != null && orderIds.isNotEmpty) 'p_order_ids': orderIds,
      });

      debugPrint('[DC_CONSOLE] ✅ Client settlement generated: ${response['settlement_number']}');
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('[DC_CONSOLE] ❌ generateDailyMerchantSettlement error: $e');
      rethrow;
    }
  }

  @override
  Future<List<ClientSettlement>> fetchDcClientSettlements({
    required String dcId,
    String? clientId,
  }) async {
    final adminDb = _getAdminClient();
    try {
      var query = adminDb.from('client_settlements').select('*');
      if (clientId != null && clientId.isNotEmpty && clientId != 'all') {
        query = query.eq('client_id', clientId);
      } else {
        query = query.eq('distribution_center_id', dcId);
      }

      final response = await query.order('settled_at', ascending: false);
      return (response as List).map((json) => ClientSettlement.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[DC_CONSOLE] ❌ fetchDcClientSettlements error: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> fetchMerchantAssetCustody({
    required String clientId,
    String? dcId,
  }) async {
    final adminDb = _getAdminClient();
    try {
      final response = await adminDb.rpc('fn_calculate_merchant_asset_custody', params: {
        'p_client_id': clientId,
        if (dcId != null) 'p_dc_id': dcId,
      });

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('[DC_CONSOLE] ❌ fetchMerchantAssetCustody error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  @override
  Future<ClientProfile> updateClientFinancialTariffs({
    required String clientId,
    required double customDeliveryFee,
    required double customFailedAttemptFee,
    required double customPlatformFee,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
  }) async {
    final adminDb = _getAdminClient();
    try {
      final updatePayload = <String, dynamic>{
        'custom_delivery_fee': customDeliveryFee,
        'custom_failed_attempt_fee': customFailedAttemptFee,
        'custom_platform_fee': customPlatformFee,
        'custom_platform_fee_value': customPlatformFee,
        if (bankName != null && bankName.trim().isNotEmpty) 'bank_name': bankName.trim(),
        if (bankAccountNumber != null && bankAccountNumber.trim().isNotEmpty) 'account_number': bankAccountNumber.trim(),
        if (bankAccountName != null && bankAccountName.trim().isNotEmpty) 'account_name': bankAccountName.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await adminDb
          .from('clients')
          .update(updatePayload)
          .eq('id', clientId)
          .select('*, client_closers(id, is_active)')
          .single();

      debugPrint('[DC_CONSOLE] ✅ Successfully updated financial agreements for client $clientId in Supabase.');
      return ClientProfile.fromJson(response);
    } catch (e) {
      debugPrint('[DC_CONSOLE] ❌ updateClientFinancialTariffs error: $e');
      rethrow;
    }
  }
}
