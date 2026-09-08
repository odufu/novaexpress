import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';
import '../../../client_portal/domain/entities/client_profile.dart';
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
  });
  Future<void> rejectPayoutClaim({
    required String claimId,
    required String reason,
  });
  Future<List<DCTransactionRecord>> fetchDcTransactions();
  Future<List<ClientProfile>> fetchClients();
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
  });
}

class DCConsoleRemoteDataSourceImpl implements DCConsoleRemoteDataSource {
  final SupabaseClient? _client;

  DCConsoleRemoteDataSourceImpl([SupabaseClient? client]) : _client = client;

  SupabaseClient _getAdminClient() {
    if (_client != null) return _client;
    return SupabaseClient(
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
        : (contactEmail?.trim().isNotEmpty == true ? contactEmail!.trim().toLowerCase() : 'supervisor.${cleanCode.toLowerCase()}@novaexpress.ng');
    final supPass = (supervisorPassword != null && supervisorPassword.trim().length >= 6)
        ? supervisorPassword.trim()
        : 'Password123!';

    final newDcId = _generateUuid();
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    String persistentId = newDcId;

    final effectiveZones = operatingZones.isNotEmpty ? operatingZones : [city.trim()];
    final effectiveManager = managerName?.trim().isNotEmpty == true ? managerName!.trim() : 'Station Supervisor';
    final effectivePhone = contactPhone?.trim().isNotEmpty == true ? contactPhone!.trim() : '+234 800 000 0000';
    final effectiveCapacity = storageCapacityUnits > 0 ? storageCapacityUnits : 25000;

    final adminDb = _getAdminClient();
    try {
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
        'address': address.trim(),
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
    } finally {
      adminDb.dispose();
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
    try {
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
    } finally {
      adminDb.dispose();
    }
  }

  @override
  Future<void> toggleDistributionCenterStatus(String dcId, bool isActive) async {
    final adminDb = _getAdminClient();
    try {
      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      if (uuidRegex.hasMatch(dcId)) {
        await adminDb.from('distribution_centers').update({'is_active': isActive}).eq('id', dcId);
      }
    } finally {
      adminDb.dispose();
    }
  }

  @override
  Future<void> updateOperatingZones(String dcId, List<String> zones) async {
    final adminDb = _getAdminClient();
    try {
      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      if (uuidRegex.hasMatch(dcId)) {
        await adminDb.from('distribution_centers').update({'operating_zones': zones}).eq('id', dcId);
      }
    } finally {
      adminDb.dispose();
    }
  }

  @override
  Future<void> deleteDistributionCenter(String dcId) async {
    final adminDb = _getAdminClient();
    try {
      await adminDb.from('distribution_centers').delete().eq('id', dcId);
    } finally {
      adminDb.dispose();
    }
  }

  @override
  Future<List<DCFleetDriver>> fetchDrivers() async {
    final client = _getAdminClient();
    try {
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
    } finally {
      if (_client == null) {
        client.dispose();
      }
    }
  }

  @override
  Future<void> updateDriverCompensationTerms(DCFleetDriver driver) async {
    final adminDb = _getAdminClient();
    try {
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
    } finally {
      adminDb.dispose();
    }
  }

  @override
  Future<DCFinanceSettings?> fetchFinanceSettings() async {
    final adminDb = _getAdminClient();
    try {
      final response = await adminDb
          .from('dc_finance_settings')
          .select()
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return DCFinanceSettings.fromJson(response);
      }
      return null;
    } finally {
      adminDb.dispose();
    }
  }

  @override
  Future<void> updateFinanceSettings(DCFinanceSettings settings) async {
    final adminDb = _getAdminClient();
    try {
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
    } finally {
      adminDb.dispose();
    }
  }

  @override
  Future<List<DCPayoutClaim>> fetchPayoutClaims() async {
    final adminDb = _getAdminClient();
    try {
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
    } finally {
      adminDb.dispose();
    }
  }

  @override
  Future<void> approvePayoutClaim({
    required String claimId,
    required double amount,
    required String driverId,
  }) async {
    final adminDb = _getAdminClient();
    try {
      await adminDb.from('payout_requests').update({
        'status': 'approved',
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', claimId);

      // Decrement driver entitlement
      try {
        await adminDb.rpc('decrement_driver_entitlement', params: {
          'p_driver_id': driverId,
          'p_amount': amount,
        });
      } catch (_) {}
    } finally {
      adminDb.dispose();
    }
  }

  @override
  Future<void> rejectPayoutClaim({
    required String claimId,
    required String reason,
  }) async {
    final adminDb = _getAdminClient();
    try {
      await adminDb.from('payout_requests').update({
        'status': 'rejected',
        'rejection_reason': reason,
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', claimId);
    } finally {
      adminDb.dispose();
    }
  }

  @override
  Future<List<DCTransactionRecord>> fetchDcTransactions() async {
    final adminDb = _getAdminClient();
    try {
      final List<DCTransactionRecord> results = [];

      // 1. Paystack Transactions
      try {
        final pstkRes = await adminDb
            .from('paystack_transactions')
            .select('*, orders(order_number, recipient_name), delivery_agents(agent_code, users(first_name, last_name))')
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
    } finally {
      adminDb.dispose();
    }
  }

  @override
  Future<List<ClientProfile>> fetchClients() async {
    final adminDb = _getAdminClient();
    try {
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
    } finally {
      adminDb.dispose();
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
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final adminDb = _getAdminClient();

    try {
      // Pre-flight check against users table for duplicate email
      final existingUser = await adminDb
          .from('users')
          .select('id, email')
          .eq('email', cleanEmail)
          .maybeSingle();

      if (existingUser != null) {
        throw Exception("A user with email '$cleanEmail' already exists. Please use a unique email address.");
      }

      final cleanName = companyName.trim();
      final words = cleanName.split(RegExp(r'\s+'));
      String prefix = words.take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
      if (prefix.length < 2) prefix = cleanName.length >= 2 ? cleanName.substring(0, 2).toUpperCase() : 'CL';
      final clientCode = 'CLI-$prefix-${DateTime.now().millisecond.toString().padLeft(3, '0')}';

      final clientPayload = {
        'company_name': cleanName,
        'code': clientCode,
        'contact_person': contactPerson.trim(),
        'email': cleanEmail,
        'phone': phone.trim(),
        'address': address.trim(),
        'city': city.trim(),
        'state': stateName.trim(),
        'tier': tier,
        'closer_limit': closerLimit,
        'is_active': true,
        'company_id': '11111111-1111-4111-8111-111111111111',
      };

      final insertRes = await adminDb
          .from('clients')
          .insert(clientPayload)
          .select()
          .single();

      return ClientProfile.fromJson(insertRes);
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
