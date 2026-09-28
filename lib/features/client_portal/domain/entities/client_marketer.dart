class ClientMarketer {
  final String id;
  final String clientId;
  final String? userId;
  final String marketerCode;
  final String fullName;
  final String email;
  final String phone;
  final bool isActive;
  final bool isSupervisor;
  final String? supervisorId;
  final String? supervisorName;
  final double dailyAdSpendBudget;
  final String commissionModel; // 'per_form_submission' | 'per_delivered_order'
  final double commissionRate;
  final double commissionPerFormSubmission;
  final double commissionPerDeliveredOrder;
  final bool isCommissionEnabled;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final String? avatarUrl;
  final int totalLeadsGenerated;
  final int totalOrdersGenerated;
  final int totalOrdersDelivered;
  final double totalCommissionEarned;
  final double unpaidCommissionBalance;
  final double totalPaidCommission;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ClientMarketer({
    required this.id,
    required this.clientId,
    this.userId,
    required this.marketerCode,
    required this.fullName,
    required this.email,
    required this.phone,
    this.isActive = true,
    this.isSupervisor = false,
    this.supervisorId,
    this.supervisorName,
    this.dailyAdSpendBudget = 0.0,
    this.commissionModel = 'per_form_submission',
    this.commissionRate = 0.0,
    this.commissionPerFormSubmission = 0.0,
    this.commissionPerDeliveredOrder = 0.0,
    this.isCommissionEnabled = false,
    this.bankName = '',
    this.accountNumber = '',
    this.accountName = '',
    this.avatarUrl,
    this.totalLeadsGenerated = 0,
    this.totalOrdersGenerated = 0,
    this.totalOrdersDelivered = 0,
    this.totalCommissionEarned = 0.0,
    this.unpaidCommissionBalance = 0.0,
    this.totalPaidCommission = 0.0,
    this.createdAt,
    this.updatedAt,
  });

  bool get hasBankDetails =>
      accountNumber.trim().isNotEmpty && bankName.trim().isNotEmpty;

  double get effectiveCommissionPerSubmission =>
      commissionPerFormSubmission > 0 ? commissionPerFormSubmission : commissionRate;

  double get effectiveCommissionPerDelivery =>
      commissionPerDeliveredOrder > 0 ? commissionPerDeliveredOrder : commissionRate;

  double get conversionRate => totalLeadsGenerated > 0
      ? ((totalOrdersGenerated / totalLeadsGenerated) * 100).clamp(0.0, 100.0)
      : (totalOrdersGenerated > 0 ? 100.0 : 0.0);

  double get deliverySuccessRate => totalOrdersGenerated > 0
      ? ((totalOrdersDelivered / totalOrdersGenerated) * 100).clamp(0.0, 100.0)
      : 0.0;

  factory ClientMarketer.fromJson(Map<String, dynamic> json) {
    return ClientMarketer(
      id: json['id']?.toString() ?? '',
      clientId: json['client_id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      marketerCode: json['marketer_code']?.toString() ?? 'MKT-001',
      fullName: json['full_name']?.toString() ?? json['name']?.toString() ?? 'Digital Marketer',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      isActive: json['is_active'] == true || json['is_active'] == 'true' || json['is_active'] == 1,
      isSupervisor: json['is_supervisor'] == true || json['is_supervisor'] == 'true' || json['is_supervisor'] == 1,
      supervisorId: json['supervisor_id']?.toString(),
      supervisorName: json['supervisor_name']?.toString(),
      dailyAdSpendBudget: (json['daily_ad_spend_budget'] as num?)?.toDouble() ?? 0.0,
      commissionModel: json['commission_model']?.toString() ?? 'per_form_submission',
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 0.0,
      commissionPerFormSubmission: (json['commission_per_form_submission'] as num?)?.toDouble() ?? (json['commission_rate'] as num?)?.toDouble() ?? 0.0,
      commissionPerDeliveredOrder: (json['commission_per_delivered_order'] as num?)?.toDouble() ?? (json['commission_rate'] as num?)?.toDouble() ?? 0.0,
      isCommissionEnabled: json['is_commission_enabled'] == true ||
          json['is_commission_enabled'] == 'true' ||
          json['is_commission_enabled'] == 1,
      bankName: json['bank_name']?.toString() ?? '',
      accountNumber: json['account_number']?.toString() ?? '',
      accountName: json['account_name']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
      totalLeadsGenerated: (json['total_leads_generated'] as num?)?.toInt() ?? 0,
      totalOrdersGenerated: (json['total_orders_generated'] as num?)?.toInt() ?? 0,
      totalOrdersDelivered: (json['total_orders_delivered'] as num?)?.toInt() ?? 0,
      totalCommissionEarned: (json['total_commission_earned'] as num?)?.toDouble() ?? 0.0,
      unpaidCommissionBalance: (json['unpaid_commission_balance'] as num?)?.toDouble() ??
          (((json['total_commission_earned'] as num?)?.toDouble() ?? 0.0) - ((json['total_paid_commission'] as num?)?.toDouble() ?? 0.0)),
      totalPaidCommission: (json['total_paid_commission'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'user_id': userId,
      'marketer_code': marketerCode,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'is_active': isActive,
      'is_supervisor': isSupervisor,
      if (supervisorId != null) 'supervisor_id': supervisorId,
      'daily_ad_spend_budget': dailyAdSpendBudget,
      'commission_model': commissionModel,
      'commission_type': commissionModel,
      'commission_rate': commissionRate,
      'commission_per_form_submission': commissionPerFormSubmission,
      'commission_per_delivered_order': commissionPerDeliveredOrder,
      'is_commission_enabled': isCommissionEnabled,
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_name': accountName,
      'avatar_url': avatarUrl,
      'total_leads_generated': totalLeadsGenerated,
      'total_orders_generated': totalOrdersGenerated,
      'total_orders_delivered': totalOrdersDelivered,
      'total_commission_earned': totalCommissionEarned,
      'unpaid_commission_balance': unpaidCommissionBalance,
      'total_paid_commission': totalPaidCommission,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  ClientMarketer copyWith({
    String? id,
    String? clientId,
    String? userId,
    String? marketerCode,
    String? fullName,
    String? email,
    String? phone,
    bool? isActive,
    bool? isSupervisor,
    String? supervisorId,
    String? supervisorName,
    double? dailyAdSpendBudget,
    String? commissionModel,
    double? commissionRate,
    double? commissionPerFormSubmission,
    double? commissionPerDeliveredOrder,
    bool? isCommissionEnabled,
    String? bankName,
    String? accountNumber,
    String? accountName,
    String? avatarUrl,
    int? totalLeadsGenerated,
    int? totalOrdersGenerated,
    int? totalOrdersDelivered,
    double? totalCommissionEarned,
    double? unpaidCommissionBalance,
    double? totalPaidCommission,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClientMarketer(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      userId: userId ?? this.userId,
      marketerCode: marketerCode ?? this.marketerCode,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      isSupervisor: isSupervisor ?? this.isSupervisor,
      supervisorId: supervisorId ?? this.supervisorId,
      supervisorName: supervisorName ?? this.supervisorName,
      dailyAdSpendBudget: dailyAdSpendBudget ?? this.dailyAdSpendBudget,
      commissionModel: commissionModel ?? this.commissionModel,
      commissionRate: commissionRate ?? this.commissionRate,
      commissionPerFormSubmission: commissionPerFormSubmission ?? this.commissionPerFormSubmission,
      commissionPerDeliveredOrder: commissionPerDeliveredOrder ?? this.commissionPerDeliveredOrder,
      isCommissionEnabled: isCommissionEnabled ?? this.isCommissionEnabled,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountName: accountName ?? this.accountName,
      avatarUrl: avatarUrl != null ? (avatarUrl.isEmpty ? null : avatarUrl) : this.avatarUrl,
      totalLeadsGenerated: totalLeadsGenerated ?? this.totalLeadsGenerated,
      totalOrdersGenerated: totalOrdersGenerated ?? this.totalOrdersGenerated,
      totalOrdersDelivered: totalOrdersDelivered ?? this.totalOrdersDelivered,
      totalCommissionEarned: totalCommissionEarned ?? this.totalCommissionEarned,
      unpaidCommissionBalance: unpaidCommissionBalance ?? this.unpaidCommissionBalance,
      totalPaidCommission: totalPaidCommission ?? this.totalPaidCommission,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
