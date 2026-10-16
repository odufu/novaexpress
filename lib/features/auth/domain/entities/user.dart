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
  final String? clientId;
  final String? clientCompanyName;
  final String? closerId;
  final String? closerCode;
  final String? marketerId;
  final String? marketerCode;
  final String? avatarUrl;
  final bool isSupervisor;

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
    this.clientId,
    this.clientCompanyName,
    this.closerId,
    this.closerCode,
    this.marketerId,
    this.marketerCode,
    this.avatarUrl,
    this.isSupervisor = false,
  });

  String get fullName => '$firstName $lastName'.trim();
  String get riderCode => deliveryAgentCode ?? 'PDA';
  bool get isRider => role == 'delivery_agent' || role == 'pda' || role == 'rider';
  bool get isPda => isRider && personnelType == 'pda';
  bool get isInHouseRider => isRider && personnelType == 'in_house_rider';
  bool get isDcManager => role == 'dc_manager' || role == 'dc_supervisor' || role == 'super_admin';
  bool get isDcOperations =>
      role == 'dc_operations' ||
      role == 'operations_officer' ||
      role == 'dispatcher' ||
      role == 'ops_officer' ||
      role == 'operations';
  bool get isCloser => role == 'closer' || role == 'client_closer';
  bool get isMarketerSupervisor => isSupervisor || role == 'marketing_supervisor' || role == 'supervisor_marketer';
  bool get isMarketer => role == 'marketer' || role == 'digital_marketer' || isMarketerSupervisor;
  bool get isClientAdmin => role == 'client' || role == 'merchant' || role == 'seller';
  bool get isClient => isClientAdmin || isCloser || isMarketer;

  String get roleDescription {
    if (isDcManager) return 'DC Operations Supervisor';
    if (isDcOperations) return 'DC Operations & Dispatch Officer';
    if (isCloser) return 'Telesales Closer';
    if (isMarketerSupervisor) return 'Marketing Supervisor';
    if (isMarketer) return 'Digital Marketer';
    if (isClientAdmin) return 'E-Commerce Merchant Admin';
    if (isRider) return 'Field Delivery Agent (PDA)';
    return 'User';
  }

  /// Canonical console route strictly governed by the user's operational role
  String get homeConsoleRoute {
    if (isDcManager) return '/dc';
    if (isDcOperations) return '/ops';
    if (isCloser) return '/closer';
    if (isMarketer) return '/marketer';
    if (isClientAdmin) return '/client';
    if (isRider) return '/';
    return '/login';
  }
}
