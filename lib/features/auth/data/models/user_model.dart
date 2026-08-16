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
    };
  }
}
