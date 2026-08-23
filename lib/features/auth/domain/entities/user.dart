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
  final String? distributionCenterId;
  final String? distributionCenterName;
  final int? lifetimeDeliveriesCount;
  final double? rating;
  final String personnelType; // 'pda' (own vehicle) | 'in_house_rider' (company bike)
  final String compensationType; // 'commission' | 'salary' | 'hybrid'
  final double commissionRate; // e.g. 1000.0 (PDA) or 500.0 (Rider)
  final double transportAllowance; // e.g. 1500.0 (PDA transport)
  final double fuelAllowance; // e.g. 800.0 (In-House Rider fuel)
  final double failedDeliveryAllowance; // e.g. 500.0 (PDA) or 300.0 (Rider)
  final double baseSalary; // e.g. 150000.0
  final String vehicleType; // 'motorcycle' | 'van' | 'car'
  final String vehiclePlateNumber;
  final String operatingState;
  final String operatingCity;
  final String bankName;
  final String bankAccountNumber;
  final String bankAccountName;
  final String agentStatus; // 'available' | 'on_delivery' | 'offline'
  final String? avatarUrl;

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
    this.deliveryAgentCode = '',
    this.distributionCenterId,
    this.distributionCenterName = '',
    this.lifetimeDeliveriesCount = 0,
    this.rating = 0.0,
    this.personnelType = 'pda',
    this.compensationType = 'commission',
    this.commissionRate = 0.0,
    this.transportAllowance = 0.0,
    this.fuelAllowance = 0.0,
    this.failedDeliveryAllowance = 500.0,
    this.baseSalary = 0.0,
    this.vehicleType = '',
    this.vehiclePlateNumber = '',
    this.operatingState = '',
    this.operatingCity = '',
    this.bankName = '',
    this.bankAccountNumber = '',
    this.bankAccountName = '',
    this.agentStatus = 'available',
    this.avatarUrl,
  });

  String get fullName => '$firstName $lastName'.trim();
  bool get isPda => (role == 'delivery_agent' || role == 'pda') && personnelType == 'pda';
  bool get isInHouseRider => role == 'delivery_agent' && personnelType == 'in_house_rider';
  bool get isDcManager => role == 'dc_manager' || role == 'dc_supervisor' || role == 'super_admin';
}
