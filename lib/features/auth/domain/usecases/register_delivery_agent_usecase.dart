import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class RegisterDeliveryAgentUseCase {
  final AuthRepository repository;

  RegisterDeliveryAgentUseCase(this.repository);

  Future<UserEntity> call({
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
  }) {
    return repository.registerDeliveryAgent(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      personnelType: personnelType,
      compensationType: compensationType,
      commissionRate: commissionRate,
      transportAllowance: transportAllowance,
      fuelAllowance: fuelAllowance,
      baseSalary: baseSalary,
      vehicleType: vehicleType,
      vehiclePlateNumber: vehiclePlateNumber,
      bankName: bankName,
      bankAccountNumber: bankAccountNumber,
      bankAccountName: bankAccountName,
      distributionCenterId: distributionCenterId,
      assignedZone: assignedZone,
    );
  }
}
