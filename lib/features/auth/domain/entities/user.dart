class UserEntity {
  final String id;
  final String? authUserId;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final String role;
  final String? companyId;
  final String? deliveryAgentId;
  final String? deliveryAgentCode;
  final String? distributionCenterName;
  final int? lifetimeDeliveriesCount;
  final double? rating;
  final String personnelType; // 'pda' (own vehicle) | 'in_house_rider' (company bike)
  final String compensationType; // 'commission' | 'salary' | 'hybrid'
  final double commissionRate; // e.g. 1000.0 (PDA) or 500.0 (Rider)
  final double transportAllowance; // e.g. 1500.0 (PDA transport)
  final double fuelAllowance; // e.g. 800.0 (Rider fuel)
  final double baseSalary; // e.g. 150000.0
  final String vehicleType; // 'motorcycle' | 'van' | 'car'
  final String vehiclePlateNumber;
  final String operatingState;
  final String operatingCity;
  final String bankName;
  final String bankAccountNumber;
  final String bankAccountName;
  final String agentStatus; // 'available' | 'on_delivery' | 'offline'

  const UserEntity({
    required this.id,
    this.authUserId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.role,
    this.companyId,
    this.deliveryAgentId,
    this.deliveryAgentCode = 'PDA-7000',
    this.distributionCenterName = 'Wuse DC',
    this.lifetimeDeliveriesCount = 4892,
    this.rating = 4.9,
    this.personnelType = 'pda',
    this.compensationType = 'commission',
    this.commissionRate = 1000.0,
    this.transportAllowance = 1500.0,
    this.fuelAllowance = 800.0,
    this.baseSalary = 150000.0,
    this.vehicleType = 'Motorcycle',
    this.vehiclePlateNumber = 'ABJ-894-XA',
    this.operatingState = 'Abuja (FCT)',
    this.operatingCity = 'Wuse 2',
    this.bankName = 'Kuda Microfinance Bank',
    this.bankAccountNumber = '2019847291',
    this.bankAccountName = 'Emeka Rider',
    this.agentStatus = 'available',
  });

  String get fullName => '$firstName $lastName'.trim();
  bool get isPda => personnelType == 'pda';
  bool get isInHouseRider => personnelType == 'in_house_rider';
}
