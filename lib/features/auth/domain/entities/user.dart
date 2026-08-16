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
  });

  String get fullName => '$firstName $lastName'.trim();
}
