class ClientCloser {
  final String id;
  final String clientId;
  final String? userId;
  final String closerCode;
  final String fullName;
  final String email;
  final String phone;
  final bool isActive;
  final int dailyCallTarget;
  final int totalLeadsAssigned;
  final int totalLeadsConfirmed;
  final int totalOrdersBooked;
  final int totalOrdersDelivered;
  final double commissionRate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ClientCloser({
    required this.id,
    required this.clientId,
    this.userId,
    required this.closerCode,
    required this.fullName,
    required this.email,
    required this.phone,
    this.isActive = true,
    this.dailyCallTarget = 50,
    this.totalLeadsAssigned = 0,
    this.totalLeadsConfirmed = 0,
    this.totalOrdersBooked = 0,
    this.totalOrdersDelivered = 0,
    this.commissionRate = 500.0,
    this.createdAt,
    this.updatedAt,
  });

  double get conversionRate => totalLeadsAssigned > 0
      ? ((totalOrdersBooked / totalLeadsAssigned) * 100).clamp(0.0, 100.0)
      : (totalOrdersBooked > 0 ? 100.0 : 0.0);

  double get deliverySuccessRate => totalOrdersBooked > 0
      ? ((totalOrdersDelivered / totalOrdersBooked) * 100).clamp(0.0, 100.0)
      : 0.0;

  double get totalEarnedCommission => totalOrdersDelivered * commissionRate;

  factory ClientCloser.fromJson(Map<String, dynamic> json) {
    return ClientCloser(
      id: json['id']?.toString() ?? '',
      clientId: json['client_id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      closerCode: json['closer_code']?.toString() ?? 'CLS-001',
      fullName: json['full_name']?.toString() ?? json['name']?.toString() ?? 'Sales Closer',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      isActive: json['is_active'] == true || json['is_active'] == 'true',
      dailyCallTarget: (json['daily_call_target'] as num?)?.toInt() ?? 50,
      totalLeadsAssigned: (json['total_leads_assigned'] as num?)?.toInt() ?? 0,
      totalLeadsConfirmed: (json['total_leads_confirmed'] as num?)?.toInt() ?? 0,
      totalOrdersBooked: (json['total_orders_booked'] as num?)?.toInt() ?? 0,
      totalOrdersDelivered: (json['total_orders_delivered'] as num?)?.toInt() ?? 0,
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 500.0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'user_id': userId,
      'closer_code': closerCode,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'is_active': isActive,
      'daily_call_target': dailyCallTarget,
      'total_leads_assigned': totalLeadsAssigned,
      'total_leads_confirmed': totalLeadsConfirmed,
      'total_orders_booked': totalOrdersBooked,
      'total_orders_delivered': totalOrdersDelivered,
      'commission_rate': commissionRate,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  ClientCloser copyWith({
    String? id,
    String? clientId,
    String? userId,
    String? closerCode,
    String? fullName,
    String? email,
    String? phone,
    bool? isActive,
    int? dailyCallTarget,
    int? totalLeadsAssigned,
    int? totalLeadsConfirmed,
    int? totalOrdersBooked,
    int? totalOrdersDelivered,
    double? commissionRate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClientCloser(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      userId: userId ?? this.userId,
      closerCode: closerCode ?? this.closerCode,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      dailyCallTarget: dailyCallTarget ?? this.dailyCallTarget,
      totalLeadsAssigned: totalLeadsAssigned ?? this.totalLeadsAssigned,
      totalLeadsConfirmed: totalLeadsConfirmed ?? this.totalLeadsConfirmed,
      totalOrdersBooked: totalOrdersBooked ?? this.totalOrdersBooked,
      totalOrdersDelivered: totalOrdersDelivered ?? this.totalOrdersDelivered,
      commissionRate: commissionRate ?? this.commissionRate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
