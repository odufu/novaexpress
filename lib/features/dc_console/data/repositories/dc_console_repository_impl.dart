import '../../../../core/services/local_storage_service.dart';
import '../../../client_portal/domain/entities/client_profile.dart';
import '../../domain/entities/dc_finance_settings.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../../domain/entities/dc_payout_claim.dart';
import '../../domain/entities/dc_transaction_record.dart';
import '../../domain/entities/distribution_center.dart';
import '../../domain/repositories/dc_console_repository.dart';
import '../datasources/dc_console_remote_datasource.dart';

class DCConsoleRepositoryImpl implements DCConsoleRepository {
  final DCConsoleRemoteDataSource _remoteDataSource;
  final LocalStorageService _storageService;

  DCConsoleRepositoryImpl({
    required DCConsoleRemoteDataSource remoteDataSource,
    required LocalStorageService storageService,
  })  : _remoteDataSource = remoteDataSource,
        _storageService = storageService;

  @override
  Future<List<DistributionCenter>> getDistributionCenters() async {
    try {
      final remoteDcs = await _remoteDataSource.fetchDistributionCenters();
      if (remoteDcs.isNotEmpty) {
        await _storageService.cacheDistributionCenters(remoteDcs);
      }
      return remoteDcs;
    } catch (_) {
      final cached = await _storageService.getCachedDistributionCenters();
      return cached ?? [];
    }
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
    final created = await _remoteDataSource.createDistributionCenter(
      name: name,
      code: code,
      stateName: stateName,
      city: city,
      address: address,
      contactPhone: contactPhone,
      contactEmail: contactEmail,
      managerName: managerName,
      isHub: isHub,
      parentDcId: parentDcId,
      storageCapacityUnits: storageCapacityUnits,
      operatingZones: operatingZones,
      supervisorEmail: supervisorEmail,
      supervisorPassword: supervisorPassword,
      authDataSource: authDataSource,
    );

    // Update local cache
    final cached = await _storageService.getCachedDistributionCenters() ?? [];
    final updatedList = [
      created,
      ...cached.where((d) => d.code != created.code && d.id != created.id),
    ];
    await _storageService.cacheDistributionCenters(updatedList);

    return created;
  }

  @override
  Future<void> updateDistributionCenter(DistributionCenter dc) async {
    await _remoteDataSource.updateDistributionCenter(dc);
    final cached = await _storageService.getCachedDistributionCenters() ?? [];
    final updatedList = cached.map((d) => d.id == dc.id ? dc : d).toList();
    await _storageService.cacheDistributionCenters(updatedList);
  }

  @override
  Future<void> toggleDistributionCenterStatus(String dcId, bool isActive) async {
    await _remoteDataSource.toggleDistributionCenterStatus(dcId, isActive);
    final cached = await _storageService.getCachedDistributionCenters() ?? [];
    final updatedList = cached.map((d) => d.id == dcId ? d.copyWith(isActive: isActive) : d).toList();
    await _storageService.cacheDistributionCenters(updatedList);
  }

  @override
  Future<void> updateOperatingZones(String dcId, List<String> zones) async {
    await _remoteDataSource.updateOperatingZones(dcId, zones);
    final cached = await _storageService.getCachedDistributionCenters() ?? [];
    final updatedList = cached.map((d) => d.id == dcId ? d.copyWith(operatingZones: zones) : d).toList();
    await _storageService.cacheDistributionCenters(updatedList);
  }

  @override
  Future<void> deleteDistributionCenter(String dcId) async {
    await _remoteDataSource.deleteDistributionCenter(dcId);
    final cached = await _storageService.getCachedDistributionCenters() ?? [];
    final updatedList = cached.where((d) => d.id != dcId).toList();
    await _storageService.cacheDistributionCenters(updatedList);
  }

  @override
  Future<List<DCFleetDriver>> getDrivers() async {
    try {
      final remoteDrivers = await _remoteDataSource.fetchDrivers();
      await _storageService.cacheFleetDrivers(remoteDrivers);
      return remoteDrivers;
    } catch (_) {
      final cached = await _storageService.getCachedFleetDrivers();
      return cached ?? [];
    }
  }

  @override
  Future<void> updateDriverCompensationTerms(DCFleetDriver driver) async {
    await _remoteDataSource.updateDriverCompensationTerms(driver);
    final cached = await _storageService.getCachedFleetDrivers() ?? [];
    final updatedList = cached.map((d) => d.id == driver.id ? driver : d).toList();
    await _storageService.cacheFleetDrivers(updatedList);
  }

  @override
  Future<DCFinanceSettings?> getFinanceSettings() async {
    try {
      final remote = await _remoteDataSource.fetchFinanceSettings();
      if (remote != null) {
        await _storageService.cacheFinanceSettings(remote);
      }
      return remote;
    } catch (_) {
      return await _storageService.getCachedFinanceSettings();
    }
  }

  @override
  Future<void> updateFinanceSettings(DCFinanceSettings settings) async {
    await _remoteDataSource.updateFinanceSettings(settings);
    await _storageService.cacheFinanceSettings(settings);
  }

  @override
  Future<List<DCPayoutClaim>> getPayoutClaims() async {
    try {
      final claims = await _remoteDataSource.fetchPayoutClaims();
      await _storageService.cachePayoutClaims(claims);
      return claims;
    } catch (_) {
      final cached = await _storageService.getCachedPayoutClaims();
      return cached ?? [];
    }
  }

  @override
  Future<void> approvePayoutClaim({
    required String claimId,
    required double amount,
    required String driverId,
  }) async {
    await _remoteDataSource.approvePayoutClaim(
      claimId: claimId,
      amount: amount,
      driverId: driverId,
    );
  }

  @override
  Future<void> rejectPayoutClaim({
    required String claimId,
    required String reason,
  }) async {
    await _remoteDataSource.rejectPayoutClaim(
      claimId: claimId,
      reason: reason,
    );
  }

  @override
  Future<List<DCTransactionRecord>> getDcTransactions() async {
    try {
      final txns = await _remoteDataSource.fetchDcTransactions();
      await _storageService.cacheDcTransactions(txns);
      return txns;
    } catch (_) {
      final cached = await _storageService.getCachedDcTransactions();
      return cached ?? [];
    }
  }

  @override
  Future<List<ClientProfile>> getClients() async {
    return await _remoteDataSource.fetchClients();
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
    return await _remoteDataSource.createClient(
      companyName: companyName,
      contactPerson: contactPerson,
      email: email,
      phone: phone,
      address: address,
      city: city,
      stateName: stateName,
      tier: tier,
      closerLimit: closerLimit,
    );
  }
}
