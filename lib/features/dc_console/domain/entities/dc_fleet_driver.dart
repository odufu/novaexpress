class DCFleetDriver {
  final String id;
  final String driverCode;
  final String name;
  final String phone;
  final String email;
  final String avatarUrl;
  final String vehicleModel;
  final String vehiclePlate;
  final String vehicleType; // 'Motorcycle', 'Tricycle', 'Van', 'Car', 'Truck'
  final String status; // 'active', 'at_rest', 'delayed', 'offline'
  final String assignedZone;
  final int totalAssignedOrders;
  final int completedOrders;
  final double routeProgressPercent; // 0.0 to 100.0
  final double efficiencyRating; // e.g. 98.4%
  final double cashInCustody;
  final int itemsInCustody;
  final double currentLatitude;
  final double currentLongitude;

  // Onboarding & Unique Compensation Agreement
  final String personnelType; // 'pda' (Personal Distribution Agent) | 'in_house_rider' (Company Rider)
  final String compensationType; // 'commission' | 'salary' | 'hybrid'
  final double commissionRate; // e.g. ₦1,000.00 (PDA) or ₦500.00 (In-House)
  final double transportAllowance; // e.g. ₦1,500.00 (PDA transport) or ₦800.00 (Fuel allowance)
  final double failedDeliveryAllowance; // e.g. ₦500.00
  final double baseSalary; // e.g. ₦150,000.00
  final double upsellBonusPercent; // e.g. 10.0%
  final String bankName;
  final String bankAccountNumber;
  final String bankAccountName;
  final String guarantorName;
  final String guarantorPhone;

  const DCFleetDriver({
    required this.id,
    required this.driverCode,
    required this.name,
    required this.phone,
    this.email = '',
    required this.avatarUrl,
    required this.vehicleModel,
    required this.vehiclePlate,
    required this.vehicleType,
    required this.status,
    required this.assignedZone,
    required this.totalAssignedOrders,
    required this.completedOrders,
    required this.routeProgressPercent,
    required this.efficiencyRating,
    required this.cashInCustody,
    required this.itemsInCustody,
    this.currentLatitude = 9.0765,
    this.currentLongitude = 7.3986,
    this.personnelType = 'pda',
    this.compensationType = 'commission',
    this.commissionRate = 1000.0,
    this.transportAllowance = 1500.0,
    this.failedDeliveryAllowance = 500.0,
    this.baseSalary = 0.0,
    this.upsellBonusPercent = 10.0,
    this.bankName = '',
    this.bankAccountNumber = '',
    this.bankAccountName = '',
    this.guarantorName = '',
    this.guarantorPhone = '',
  });

  bool get isActive => status.toLowerCase() == 'active';
  bool get isDelayed => status.toLowerCase() == 'delayed';
  bool get isAtRest => status.toLowerCase() == 'at_rest';
  bool get isPda => personnelType.toLowerCase() == 'pda';
  bool get isInHouseRider => personnelType.toLowerCase() == 'in_house_rider';
  double get totalPerDeliveryEntitlement => commissionRate + transportAllowance;

  DCFleetDriver copyWith({
    String? id,
    String? driverCode,
    String? name,
    String? phone,
    String? email,
    String? avatarUrl,
    String? vehicleModel,
    String? vehiclePlate,
    String? vehicleType,
    String? status,
    String? assignedZone,
    int? totalAssignedOrders,
    int? completedOrders,
    double? routeProgressPercent,
    double? efficiencyRating,
    double? cashInCustody,
    int? itemsInCustody,
    double? currentLatitude,
    double? currentLongitude,
    String? personnelType,
    String? compensationType,
    double? commissionRate,
    double? transportAllowance,
    double? failedDeliveryAllowance,
    double? baseSalary,
    double? upsellBonusPercent,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
    String? guarantorName,
    String? guarantorPhone,
  }) {
    return DCFleetDriver(
      id: id ?? this.id,
      driverCode: driverCode ?? this.driverCode,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      vehicleType: vehicleType ?? this.vehicleType,
      status: status ?? this.status,
      assignedZone: assignedZone ?? this.assignedZone,
      totalAssignedOrders: totalAssignedOrders ?? this.totalAssignedOrders,
      completedOrders: completedOrders ?? this.completedOrders,
      routeProgressPercent: routeProgressPercent ?? this.routeProgressPercent,
      efficiencyRating: efficiencyRating ?? this.efficiencyRating,
      cashInCustody: cashInCustody ?? this.cashInCustody,
      itemsInCustody: itemsInCustody ?? this.itemsInCustody,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      personnelType: personnelType ?? this.personnelType,
      compensationType: compensationType ?? this.compensationType,
      commissionRate: commissionRate ?? this.commissionRate,
      transportAllowance: transportAllowance ?? this.transportAllowance,
      failedDeliveryAllowance: failedDeliveryAllowance ?? this.failedDeliveryAllowance,
      baseSalary: baseSalary ?? this.baseSalary,
      upsellBonusPercent: upsellBonusPercent ?? this.upsellBonusPercent,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      guarantorName: guarantorName ?? this.guarantorName,
      guarantorPhone: guarantorPhone ?? this.guarantorPhone,
    );
  }
}
