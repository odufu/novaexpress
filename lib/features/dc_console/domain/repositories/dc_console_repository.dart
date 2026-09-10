import '../../../client_portal/domain/entities/client_profile.dart';
import '../entities/dc_finance_settings.dart';
import '../entities/dc_fleet_driver.dart';
import '../entities/dc_payout_claim.dart';
import '../entities/dc_transaction_record.dart';
import '../entities/distribution_center.dart';

abstract class DCConsoleRepository {
  /// Fetches all distribution centers from remote backend
  Future<List<DistributionCenter>> getDistributionCenters();

  /// Creates a new distribution center and provisions supervisor
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

  /// Updates distribution center metadata
  Future<void> updateDistributionCenter(DistributionCenter dc);

  /// Toggles active/inactive status of a distribution center
  Future<void> toggleDistributionCenterStatus(String dcId, bool isActive);

  /// Updates delivery coverage zones of a distribution center
  Future<void> updateOperatingZones(String dcId, List<String> zones);

  /// Deletes a distribution center from the network
  Future<void> deleteDistributionCenter(String dcId);

  /// Fetches fleet drivers from remote backend
  Future<List<DCFleetDriver>> getDrivers();

  /// Updates custom compensation terms for a fleet driver
  Future<void> updateDriverCompensationTerms(DCFleetDriver driver);

  /// Fetches finance and settlement settings for the active DC
  Future<DCFinanceSettings?> getFinanceSettings();

  /// Saves updated finance and settlement settings
  Future<void> updateFinanceSettings(DCFinanceSettings settings);

  /// Fetches payout claims from riders
  Future<List<DCPayoutClaim>> getPayoutClaims();

  /// Approves a rider's payout claim and clears entitlement
  Future<void> approvePayoutClaim({
    required String claimId,
    required double amount,
    required String driverId,
  });

  /// Rejects a rider's payout claim with an explanatory reason
  Future<void> rejectPayoutClaim({
    required String claimId,
    required String reason,
  });

  /// Fetches consolidated DC transactions from ledger
  Future<List<DCTransactionRecord>> getDcTransactions();

  /// Fetches registered enterprise clients and merchants
  Future<List<ClientProfile>> getClients();

  /// Checks if an email address is already registered in the system
  Future<bool> checkEmailExists(String email);

  /// Creates a new enterprise merchant / client account
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
    dynamic authDataSource,
  });
}
