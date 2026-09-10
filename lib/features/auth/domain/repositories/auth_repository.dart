import '../entities/user.dart';

abstract class AuthRepository {
  Future<UserEntity> login(String email, String password);
  Future<void> logout();
  Future<UserEntity?> getCurrentUser();
  Future<UserEntity> registerDeliveryAgent({
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
    required double baseSalary,
    required String vehicleType,
    required String vehiclePlateNumber,
    required String bankName,
    required String bankAccountNumber,
    required String bankAccountName,
    required String distributionCenterId,
    required String assignedZone,
  });
  Future<UserEntity> registerDistributionCenterSupervisor({
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
  Future<UserEntity> registerClientAccount({
    required String email,
    required String password,
    required String companyName,
    required String contactPerson,
    required String phone,
    required String address,
    required String city,
    required String stateName,
    String tier,
    int closerLimit,
    String? clientCode,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
  });
}
