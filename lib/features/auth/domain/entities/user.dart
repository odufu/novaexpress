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
  final String? personnelType; // 'pda' (own vehicle) | 'in_house_rider' (company bike)
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
  final String? accountantId;
  final String? accountantCode;
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
    this.accountantId,
    this.accountantCode,
    this.avatarUrl,
    this.isSupervisor = false,
  });

  String get fullName => '$firstName $lastName'.trim();
  String get riderCode => deliveryAgentCode ?? 'PDA';
  bool get isAvailable =>
      (agentStatus.toLowerCase() == 'available' ||
          agentStatus.toLowerCase() == 'active' ||
          agentStatus.toLowerCase() == 'online') &&
      agentStatus.toLowerCase() != 'offline' &&
      agentStatus.toLowerCase() != 'inactive' &&
      agentStatus.toLowerCase() != 'banned' &&
      agentStatus.toLowerCase() != 'unavailable';
  bool get isUnavailable => !isAvailable;
  bool get isRider =>
      (role == 'delivery_agent' || role == 'pda' || role == 'rider') &&
      !isCloserSupervisor &&
      !isDcManager &&
      !isDcOperations &&
      !isGeneralAccountant &&
      !isMerchantAccountant;
  bool get isDeliveryAgent => isRider;
  bool get isPda => isRider && personnelType == 'pda';
  bool get isInHouseRider => isRider && personnelType == 'in_house_rider';
  bool get isSuperAdmin =>
      role == 'super_admin' ||
      role == 'admin' ||
      role == 'platform_admin' ||
      role == 'system_admin';
  bool get isDcManager => role == 'dc_manager' || role == 'dc_supervisor' || isSuperAdmin;
  bool get isDcOrdersAdmin =>
      role == 'dc_operations' ||
      role == 'operations_officer' ||
      role == 'dispatcher' ||
      role == 'ops_officer' ||
      role == 'operations' ||
      role == 'dc_orders_admin' ||
      role == 'orders_admin';
  bool get isDcStockAdmin =>
      role == 'dc_stock_admin' ||
      role == 'dc_stock_officer' ||
      role == 'stock_admin' ||
      role == 'stock_officer' ||
      role == 'inventory_officer';
  bool get isDcFinanceAdmin =>
      role == 'dc_finance_admin' ||
      role == 'dc_finance_officer' ||
      role == 'finance_admin' ||
      role == 'finance_officer' ||
      role == 'remittance_officer';
  bool get isGeneralAccountant =>
      role == 'general_accountant' ||
      role == 'chief_accountant' ||
      role == 'accountant' ||
      role == 'finance_director';
  bool get isDcOperations => isDcOrdersAdmin || isDcStockAdmin || isDcFinanceAdmin;
  bool get isCloserSupervisor =>
      (isCloserRaw && isSupervisor) ||
      role == 'sales_supervisor' ||
      role == 'closer_supervisor' ||
      role == 'sales_rep_supervisor';
  bool get isCloserRaw => role == 'closer' || role == 'client_closer';
  bool get isCloser => isCloserRaw || isCloserSupervisor;
  bool get isMarketerRaw => role == 'marketer' || role == 'digital_marketer';
  bool get isMarketerSupervisor =>
      (isMarketerRaw && isSupervisor) ||
      role == 'marketing_supervisor' ||
      role == 'supervisor_marketer';
  bool get isMarketer => isMarketerRaw || isMarketerSupervisor;
  bool get isClientAdmin => role == 'client' || role == 'merchant' || role == 'seller';
  bool get isMerchantAccountant =>
      role == 'merchant_accountant' ||
      role == 'client_accountant' ||
      role == 'client_finance' ||
      role == 'merchant_finance';
  bool get isClient => isClientAdmin || isCloser || isMarketer || isMerchantAccountant;

  String get roleDescription {
    if (isSuperAdmin) return 'Super Administrator';
    if (isCloserSupervisor) return 'Merchant Sales Rep Supervisor';
    if (isGeneralAccountant) return 'General Accountant';
    if (isMerchantAccountant) return 'Merchant Finance Accountant';
    if (isDcManager) return 'DC Operations Supervisor';
    if (isDcStockAdmin) return 'DC Stock Management Officer';
    if (isDcFinanceAdmin) return 'DC Finance & Remittance Officer';
    if (isDcOrdersAdmin) return 'DC Orders & Dispatch Officer';
    if (isCloser) return 'Telesales Closer';
    if (isMarketerSupervisor) return 'Marketing Supervisor';
    if (isMarketer) return 'Digital Marketer';
    if (isClientAdmin) return 'E-Commerce Merchant Admin';
    if (isRider) return 'Field Delivery Agent (PDA)';
    return 'User';
  }

  /// Canonical console route strictly governed by the user's operational role
  String get homeConsoleRoute {
    if (isSuperAdmin) return '/admin';
    if (isCloserSupervisor) return '/sales-supervisor';
    if (isGeneralAccountant) return '/accountant';
    if (isMerchantAccountant) return '/merchant-settlements';
    if (isDcManager) return '/dc';
    if (isDcStockAdmin) return '/stock-ops';
    if (isDcFinanceAdmin) return '/finance-ops';
    if (isDcOrdersAdmin) return '/ops';
    if (isCloser) return '/closer';
    if (isMarketer) return '/marketer';
    if (isClientAdmin) return '/client';
    if (isRider) return '/';
    return '/login';
  }

  UserEntity copyWith({
    String? id,
    String? authUserId,
    String? email,
    String? firstName,
    String? lastName,
    String? phone,
    String? role,
    String? companyId,
    String? deliveryAgentId,
    String? deliveryAgentCode,
    String? distributionCenterId,
    String? distributionCenterName,
    int? lifetimeDeliveriesCount,
    double? rating,
    String? personnelType,
    String? compensationType,
    double? commissionRate,
    double? transportAllowance,
    double? fuelAllowance,
    double? failedDeliveryAllowance,
    double? baseSalary,
    String? vehicleType,
    String? vehiclePlateNumber,
    String? operatingState,
    String? operatingCity,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
    String? agentStatus,
    String? clientId,
    String? clientCompanyName,
    String? closerId,
    String? closerCode,
    String? marketerId,
    String? marketerCode,
    String? accountantId,
    String? accountantCode,
    String? avatarUrl,
    bool? isSupervisor,
  }) {
    return UserEntity(
      id: id ?? this.id,
      authUserId: authUserId ?? this.authUserId,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      companyId: companyId ?? this.companyId,
      deliveryAgentId: deliveryAgentId ?? this.deliveryAgentId,
      deliveryAgentCode: deliveryAgentCode ?? this.deliveryAgentCode,
      distributionCenterId: distributionCenterId ?? this.distributionCenterId,
      distributionCenterName: distributionCenterName ?? this.distributionCenterName,
      lifetimeDeliveriesCount: lifetimeDeliveriesCount ?? this.lifetimeDeliveriesCount,
      rating: rating ?? this.rating,
      personnelType: personnelType ?? this.personnelType,
      compensationType: compensationType ?? this.compensationType,
      commissionRate: commissionRate ?? this.commissionRate,
      transportAllowance: transportAllowance ?? this.transportAllowance,
      fuelAllowance: fuelAllowance ?? this.fuelAllowance,
      failedDeliveryAllowance: failedDeliveryAllowance ?? this.failedDeliveryAllowance,
      baseSalary: baseSalary ?? this.baseSalary,
      vehicleType: vehicleType ?? this.vehicleType,
      vehiclePlateNumber: vehiclePlateNumber ?? this.vehiclePlateNumber,
      operatingState: operatingState ?? this.operatingState,
      operatingCity: operatingCity ?? this.operatingCity,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      agentStatus: agentStatus ?? this.agentStatus,
      clientId: clientId ?? this.clientId,
      clientCompanyName: clientCompanyName ?? this.clientCompanyName,
      closerId: closerId ?? this.closerId,
      closerCode: closerCode ?? this.closerCode,
      marketerId: marketerId ?? this.marketerId,
      marketerCode: marketerCode ?? this.marketerCode,
      accountantId: accountantId ?? this.accountantId,
      accountantCode: accountantCode ?? this.accountantCode,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isSupervisor: isSupervisor ?? this.isSupervisor,
    );
  }
}
