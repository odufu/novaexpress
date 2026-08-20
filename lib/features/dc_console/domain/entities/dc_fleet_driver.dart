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

  factory DCFleetDriver.fromJson(Map<String, dynamic> json) {
    final user = json['users'] as Map<String, dynamic>?;
    final firstName = user?['first_name'] as String? ?? json['first_name'] as String? ?? 'Delivery';
    final lastName = user?['last_name'] as String? ?? json['last_name'] as String? ?? 'Agent';
    final fullName = json['name'] as String? ?? '$firstName $lastName';
    final email = user?['email'] as String? ?? json['email'] as String? ?? '';
    final phone = user?['phone_number'] as String? ?? user?['phone'] as String? ?? json['phone'] as String? ?? '08031234567';
    final avatar = user?['avatar_url'] as String? ?? json['avatar_url'] as String? ?? 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150';

    final agentCode = json['agent_code'] as String? ?? json['driver_code'] as String? ?? json['driverCode'] as String? ?? 'PDA-7000';
    final pType = json['personnel_type'] as String? ?? json['personnelType'] as String? ?? 'pda';
    final cType = json['compensation_type'] as String? ?? json['compensationType'] as String? ?? 'commission';

    return DCFleetDriver(
      id: json['id'] as String? ?? 'drv-${DateTime.now().millisecondsSinceEpoch}',
      driverCode: agentCode,
      name: fullName,
      phone: phone,
      email: email,
      avatarUrl: avatar,
      vehicleModel: json['vehicle_model'] as String? ?? json['vehicleModel'] as String? ?? '${json['vehicle_type'] ?? "Motorcycle"} (${json['vehicle_plate_number'] ?? "ABJ-204-XY"})',
      vehiclePlate: json['vehicle_plate_number'] as String? ?? json['vehiclePlate'] as String? ?? 'ABJ-204-XY',
      vehicleType: json['vehicle_type'] as String? ?? json['vehicleType'] as String? ?? 'Motorcycle',
      status: json['current_status'] as String? ?? json['status'] as String? ?? 'active',
      assignedZone: json['operating_city'] as String? ?? json['assigned_zone'] as String? ?? json['assignedZone'] as String? ?? 'Wuse 2 & Central',
      totalAssignedOrders: json['total_assigned_orders'] as int? ?? json['totalAssignedOrders'] as int? ?? 0,
      completedOrders: json['completed_orders'] as int? ?? json['completedOrders'] as int? ?? 0,
      routeProgressPercent: (json['route_progress_percent'] as num?)?.toDouble() ?? (json['routeProgressPercent'] as num?)?.toDouble() ?? 0.0,
      efficiencyRating: (json['efficiency_rating'] as num?)?.toDouble() ?? (json['efficiencyRating'] as num?)?.toDouble() ?? 98.5,
      cashInCustody: (json['current_cod_balance'] as num?)?.toDouble() ?? (json['cashInCustody'] as num?)?.toDouble() ?? 0.0,
      itemsInCustody: json['items_in_custody'] as int? ?? json['itemsInCustody'] as int? ?? 0,
      currentLatitude: (json['current_latitude'] as num?)?.toDouble() ?? (json['currentLatitude'] as num?)?.toDouble() ?? 9.0765,
      currentLongitude: (json['current_longitude'] as num?)?.toDouble() ?? (json['currentLongitude'] as num?)?.toDouble() ?? 7.3986,
      personnelType: pType,
      compensationType: cType,
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? (json['commissionRate'] as num?)?.toDouble() ?? (pType == 'pda' ? 1000.0 : 500.0),
      transportAllowance: (json['transport_allowance'] as num?)?.toDouble() ?? (json['transportAllowance'] as num?)?.toDouble() ?? (pType == 'pda' ? 1500.0 : 800.0),
      failedDeliveryAllowance: (json['failed_delivery_allowance'] as num?)?.toDouble() ?? (json['failedDeliveryAllowance'] as num?)?.toDouble() ?? 500.0,
      baseSalary: (json['base_salary'] as num?)?.toDouble() ?? (json['baseSalary'] as num?)?.toDouble() ?? (pType == 'pda' ? 0.0 : 120000.0),
      upsellBonusPercent: (json['upsell_bonus_percent'] as num?)?.toDouble() ?? (json['upsellBonusPercent'] as num?)?.toDouble() ?? 10.0,
      bankName: json['bank_name'] as String? ?? json['bankName'] as String? ?? 'GTBank',
      bankAccountNumber: json['bank_account_number'] as String? ?? json['bankAccountNumber'] as String? ?? '0129482910',
      bankAccountName: json['bank_account_name'] as String? ?? json['bankAccountName'] as String? ?? fullName,
      guarantorName: json['guarantor_name'] as String? ?? json['guarantorName'] as String? ?? '',
      guarantorPhone: json['guarantor_phone'] as String? ?? json['guarantorPhone'] as String? ?? '',
    );
  }
}
