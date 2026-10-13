class DCOperationsOfficer {
  final String id;
  final String? authUserId;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final String staffCode;
  final String distributionCenterId;
  final String distributionCenterName;
  final bool isActive;
  final int totalDispatchedOrders;
  final String? avatarUrl;
  final String? rawPassword;
  final String? assignedZone;
  final DateTime createdAt;

  const DCOperationsOfficer({
    required this.id,
    this.authUserId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.staffCode,
    required this.distributionCenterId,
    required this.distributionCenterName,
    this.isActive = true,
    this.totalDispatchedOrders = 0,
    this.avatarUrl,
    this.rawPassword,
    this.assignedZone,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName'.trim();
  String get name => fullName;

  DCOperationsOfficer copyWith({
    String? id,
    String? authUserId,
    String? email,
    String? firstName,
    String? lastName,
    String? phone,
    String? staffCode,
    String? distributionCenterId,
    String? distributionCenterName,
    bool? isActive,
    int? totalDispatchedOrders,
    String? avatarUrl,
    String? rawPassword,
    String? assignedZone,
    DateTime? createdAt,
  }) {
    return DCOperationsOfficer(
      id: id ?? this.id,
      authUserId: authUserId ?? this.authUserId,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      staffCode: staffCode ?? this.staffCode,
      distributionCenterId: distributionCenterId ?? this.distributionCenterId,
      distributionCenterName: distributionCenterName ?? this.distributionCenterName,
      isActive: isActive ?? this.isActive,
      totalDispatchedOrders: totalDispatchedOrders ?? this.totalDispatchedOrders,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      rawPassword: rawPassword ?? this.rawPassword,
      assignedZone: assignedZone ?? this.assignedZone,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory DCOperationsOfficer.fromJson(Map<String, dynamic> json) {
    return DCOperationsOfficer(
      id: json['id']?.toString() ?? '',
      authUserId: json['auth_user_id']?.toString(),
      email: json['email']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      phone: json['phone_number']?.toString() ?? json['phone']?.toString() ?? '',
      staffCode: json['delivery_agent_code']?.toString() ?? json['staff_code']?.toString() ?? 'OPS-001',
      distributionCenterId: json['distribution_center_id']?.toString() ?? '',
      distributionCenterName: json['distribution_center_name']?.toString() ?? '',
      isActive: json['is_active'] == true || json['is_active'] == null,
      totalDispatchedOrders: (json['dispatched_orders_count'] as num?)?.toInt() ?? 0,
      avatarUrl: json['avatar_url']?.toString(),
      rawPassword: json['raw_password']?.toString(),
      assignedZone: json['assigned_zone']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'auth_user_id': authUserId,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'phone_number': phone,
      'delivery_agent_code': staffCode,
      'distribution_center_id': distributionCenterId,
      'distribution_center_name': distributionCenterName,
      'is_active': isActive,
      'role': 'dc_operations',
      'avatar_url': avatarUrl,
      'raw_password': rawPassword,
      'assigned_zone': assignedZone,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
