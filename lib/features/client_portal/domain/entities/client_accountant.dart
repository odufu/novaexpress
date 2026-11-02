class ClientAccountant {
  final String id;
  final String clientId;
  final String? userId;
  final String accountantCode; // e.g. ACC-NOVA-101 or ACC-ECL-101
  final String fullName;
  final String email;
  final String phone;
  final bool isActive;
  final bool canApproveSettlements; // Sign-off on daily DC remittances
  final bool canManageExpenses; // Record/review operating expenses
  final bool canDisbursePayouts; // Authorize closer/marketer payouts
  final int totalSettlementsValidated;
  final double totalAmountValidated;
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ClientAccountant({
    required this.id,
    required this.clientId,
    this.userId,
    required this.accountantCode,
    required this.fullName,
    required this.email,
    required this.phone,
    this.isActive = true,
    this.canApproveSettlements = true,
    this.canManageExpenses = true,
    this.canDisbursePayouts = true,
    this.totalSettlementsValidated = 0,
    this.totalAmountValidated = 0.0,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
  });

  ClientAccountant copyWith({
    String? id,
    String? clientId,
    String? userId,
    String? accountantCode,
    String? fullName,
    String? email,
    String? phone,
    bool? isActive,
    bool? canApproveSettlements,
    bool? canManageExpenses,
    bool? canDisbursePayouts,
    int? totalSettlementsValidated,
    double? totalAmountValidated,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClientAccountant(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      userId: userId ?? this.userId,
      accountantCode: accountantCode ?? this.accountantCode,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      canApproveSettlements: canApproveSettlements ?? this.canApproveSettlements,
      canManageExpenses: canManageExpenses ?? this.canManageExpenses,
      canDisbursePayouts: canDisbursePayouts ?? this.canDisbursePayouts,
      totalSettlementsValidated: totalSettlementsValidated ?? this.totalSettlementsValidated,
      totalAmountValidated: totalAmountValidated ?? this.totalAmountValidated,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ClientAccountant.fromJson(Map<String, dynamic> json) {
    return ClientAccountant(
      id: json['id']?.toString() ?? '',
      clientId: json['client_id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      accountantCode: json['accountant_code']?.toString() ?? json['staff_code']?.toString() ?? 'ACC-001',
      fullName: json['full_name']?.toString() ??
          json['name']?.toString() ??
          '${json['first_name'] ?? ''} ${json['last_name'] ?? ''}'.trim(),
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? json['phone_number']?.toString() ?? '',
      isActive: json['is_active'] != false && json['is_active'] != 0,
      canApproveSettlements: json['can_approve_settlements'] != false && json['can_approve_settlements'] != 0,
      canManageExpenses: json['can_manage_expenses'] != false && json['can_manage_expenses'] != 0,
      canDisbursePayouts: json['can_disburse_payouts'] != false && json['can_disburse_payouts'] != 0,
      totalSettlementsValidated: (json['total_settlements_validated'] as num?)?.toInt() ?? 0,
      totalAmountValidated: (json['total_amount_validated'] as num?)?.toDouble() ?? 0.0,
      avatarUrl: json['avatar_url']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'user_id': userId,
      'accountant_code': accountantCode,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'is_active': isActive,
      'can_approve_settlements': canApproveSettlements,
      'can_manage_expenses': canManageExpenses,
      'can_disburse_payouts': canDisbursePayouts,
      'total_settlements_validated': totalSettlementsValidated,
      'total_amount_validated': totalAmountValidated,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }
}

