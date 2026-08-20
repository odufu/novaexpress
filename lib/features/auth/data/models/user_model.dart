import '../../domain/entities/user.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    super.authUserId,
    required super.email,
    required super.firstName,
    required super.lastName,
    required super.phone,
    required super.role,
    super.companyId,
    super.deliveryAgentId,
    super.deliveryAgentCode,
    super.distributionCenterId,
    super.distributionCenterName,
    super.lifetimeDeliveriesCount,
    super.rating,
    super.personnelType,
    super.compensationType,
    super.commissionRate,
    super.transportAllowance,
    super.fuelAllowance,
    super.baseSalary,
    super.vehicleType,
    super.vehiclePlateNumber,
    super.operatingState,
    super.operatingCity,
    super.bankName,
    super.bankAccountNumber,
    super.bankAccountName,
    super.agentStatus,
    super.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, {String? deliveryAgentId}) {
    final String stateVal = json['operating_state'] ?? 
        (json['coverage_states'] is List && (json['coverage_states'] as List).isNotEmpty 
            ? (json['coverage_states'] as List).first.toString() 
            : 'Abuja (FCT)');

    return UserModel(
      id: json['id'] ?? '',
      authUserId: json['auth_user_id'],
      email: json['email'] ?? 'rider.emeka@novaexpress.com',
      firstName: json['first_name'] ?? 'Emeka',
      lastName: json['last_name'] ?? 'Rider',
      phone: json['phone'] ?? json['phone_number'] ?? '08031234567',
      role: json['role'] ?? 'delivery_agent',
      companyId: json['company_id'] ?? '11111111-1111-4111-8111-111111111111',
      deliveryAgentId: deliveryAgentId ?? json['delivery_agent_id'] ?? (json['role'] == 'dc_manager' ? null : 'b1111111-1111-4111-8111-111111111111'),
      deliveryAgentCode: json['delivery_agent_code'] ?? json['agent_code'] ?? (json['role'] == 'dc_manager' ? 'DC-MGR' : 'PDA-7000'),
      distributionCenterId: json['distribution_center_id'] ?? '22222222-2222-4222-8222-222222222222',
      distributionCenterName: json['distribution_center_name'] ?? json['dc_name'] ?? 'Wuse Distribution Center',
      lifetimeDeliveriesCount: (json['lifetime_deliveries_count'] as num?)?.toInt() ?? 4892,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      personnelType: json['personnel_type'] ?? 'pda',
      compensationType: json['compensation_type'] ?? 'commission',
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 1000.0,
      transportAllowance: (json['transport_allowance'] as num?)?.toDouble() ?? 1500.0,
      fuelAllowance: (json['fuel_allowance'] as num?)?.toDouble() ?? 2500.0,
      baseSalary: (json['base_salary'] as num?)?.toDouble() ?? 0.0,
      vehicleType: json['vehicle_type'] ?? 'Motorcycle (Bajaj Boxer)',
      vehiclePlateNumber: json['vehicle_plate_number'] ?? 'ABJ-894-XA',
      operatingState: stateVal,
      operatingCity: json['operating_city'] ?? 'Wuse II',
      bankName: json['bank_name'] ?? 'First Bank of Nigeria',
      bankAccountNumber: json['bank_account_number'] ?? '3081294821',
      bankAccountName: json['bank_account_name'] ?? 'Emeka Rider Logistics',
      agentStatus: json['current_status'] ?? 'available',
      avatarUrl: json['avatar_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'auth_user_id': authUserId,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'role': role,
      'company_id': companyId,
      'delivery_agent_code': deliveryAgentCode,
      'distribution_center_name': distributionCenterName,
      'lifetime_deliveries_count': lifetimeDeliveriesCount,
      'rating': rating,
      'personnel_type': personnelType,
      'compensation_type': compensationType,
      'commission_rate': commissionRate,
      'transport_allowance': transportAllowance,
      'fuel_allowance': fuelAllowance,
      'base_salary': baseSalary,
      'vehicle_type': vehicleType,
      'vehicle_plate_number': vehiclePlateNumber,
      'operating_state': operatingState,
      'operating_city': operatingCity,
      'bank_name': bankName,
      'bank_account_number': bankAccountNumber,
      'bank_account_name': bankAccountName,
      'current_status': agentStatus,
      'avatar_url': avatarUrl,
    };
  }
}
