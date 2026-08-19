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
    super.distributionCenterName,
    super.lifetimeDeliveriesCount,
    super.rating,
    super.personnelType,
    super.compensationType,
    super.commissionRate,
    super.transportAllowance,
    super.fuelAllowance,
    super.baseSalary,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, {String? deliveryAgentId}) {
    return UserModel(
      id: json['id'] ?? '',
      authUserId: json['auth_user_id'],
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'delivery_agent',
      companyId: json['company_id'],
      deliveryAgentId: deliveryAgentId,
      deliveryAgentCode: json['delivery_agent_code'] ?? json['agent_code'] ?? 'PDA-7000',
      distributionCenterName: json['distribution_center_name'] ?? json['dc_name'] ?? 'Wuse DC',
      lifetimeDeliveriesCount: (json['lifetime_deliveries_count'] as num?)?.toInt() ?? 4892,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.9,
      personnelType: json['personnel_type'] ?? 'pda',
      compensationType: json['compensation_type'] ?? 'commission',
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 1000.0,
      transportAllowance: (json['transport_allowance'] as num?)?.toDouble() ?? 1500.0,
      fuelAllowance: (json['fuel_allowance'] as num?)?.toDouble() ?? 800.0,
      baseSalary: (json['base_salary'] as num?)?.toDouble() ?? 150000.0,
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
    };
  }
}
