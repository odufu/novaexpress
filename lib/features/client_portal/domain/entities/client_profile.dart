/// Client / Merchant Profile Entity
class ClientProfile {
  final String id;
  final String companyName;
  final String contactPerson;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String state;
  final String code;
  final String tier; // 'enterprise' | 'standard_merchant'
  final int closerLimit;
  final bool isEnterprise;
  final int totalClosersCount;
  final bool isActive;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final String settlementFrequency;
  final String settlementDay;
  final DateTime? createdAt;
  final double? customDeliveryFee;
  final String? customPlatformFeeType;
  final double? customPlatformFeeValue;
  final String? customPaystackFeeAbsorbedBy;
  final double? customFailedAttemptFee;

  double? get customPlatformFee => customPlatformFeeValue;
  String get name => companyName;

  const ClientProfile({
    required this.id,
    required this.companyName,
    required this.contactPerson,
    required this.email,
    required this.phone,
    required this.address,
    this.city = '',
    this.state = '',
    this.code = '',
    this.tier = 'standard_merchant',
    this.closerLimit = 0,
    this.isEnterprise = false,
    this.totalClosersCount = 0,
    this.isActive = true,
    this.bankName = '',
    this.accountNumber = '',
    this.accountName = '',
    this.settlementFrequency = 'weekly',
    this.settlementDay = 'Friday',
    this.createdAt,
    this.customDeliveryFee,
    this.customPlatformFeeType,
    this.customPlatformFeeValue,
    this.customPaystackFeeAbsorbedBy,
    this.customFailedAttemptFee,
  });

  factory ClientProfile.fromJson(Map<String, dynamic> json) {
    final isEnt = json['is_enterprise'] == true ||
        json['tier']?.toString().toLowerCase() == 'enterprise';

    int closersCount = 0;
    if (json['client_closers'] is List) {
      closersCount = (json['client_closers'] as List).length;
    } else {
      closersCount = (json['total_closers_count'] as num?)?.toInt() ?? 0;
    }

    final resolvedCompany = json['company_name']?.toString() ?? json['name']?.toString() ?? '';
    final resolvedContact = json['contact_person']?.toString() ??
        json['contact_name']?.toString() ??
        json['manager_name']?.toString() ??
        '';
    final resolvedEmail = json['email']?.toString() ?? '';

    return ClientProfile(
      id: json['id']?.toString() ?? '',
      companyName: resolvedCompany,
      contactPerson: resolvedContact,
      email: resolvedEmail,
      phone: json['phone']?.toString() ?? json['phone_number']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      tier: json['tier']?.toString() ?? (isEnt ? 'enterprise' : 'standard_merchant'),
      closerLimit: (json['closer_limit'] as num?)?.toInt() ?? (isEnt ? 250 : 0),
      isEnterprise: isEnt,
      totalClosersCount: closersCount,
      isActive: json['is_active'] == true || json['is_active'] == 1,
      bankName: json['bank_name']?.toString() ?? '',
      accountNumber: json['account_number']?.toString() ?? '',
      accountName: json['account_name']?.toString() ?? resolvedCompany,
      settlementFrequency: json['settlement_frequency']?.toString() ?? 'weekly',
      settlementDay: json['settlement_day']?.toString() ?? 'Friday',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      customDeliveryFee: (json['custom_delivery_fee'] as num?)?.toDouble(),
      customPlatformFeeType: json['custom_platform_fee_type']?.toString(),
      customPlatformFeeValue: (json['custom_platform_fee_value'] as num?)?.toDouble() ??
          (json['custom_platform_fee'] as num?)?.toDouble(),
      customPaystackFeeAbsorbedBy: json['custom_paystack_fee_absorbed_by']?.toString(),
      customFailedAttemptFee: (json['custom_failed_attempt_fee'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_name': companyName,
      'contact_person': contactPerson,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'state': state,
      'code': code,
      'tier': tier,
      'closer_limit': closerLimit,
      'is_enterprise': isEnterprise,
      'total_closers_count': totalClosersCount,
      'is_active': isActive,
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_name': accountName,
      'settlement_frequency': settlementFrequency,
      'settlement_day': settlementDay,
      'created_at': createdAt?.toIso8601String(),
      'custom_delivery_fee': customDeliveryFee,
      'custom_platform_fee_type': customPlatformFeeType,
      'custom_platform_fee_value': customPlatformFeeValue,
      'custom_platform_fee': customPlatformFee,
      'custom_paystack_fee_absorbed_by': customPaystackFeeAbsorbedBy,
      'custom_failed_attempt_fee': customFailedAttemptFee,
    };
  }

  ClientProfile copyWith({
    String? id,
    String? companyName,
    String? contactPerson,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? state,
    String? code,
    String? tier,
    int? closerLimit,
    bool? isEnterprise,
    int? totalClosersCount,
    bool? isActive,
    String? bankName,
    String? accountNumber,
    String? accountName,
    String? settlementFrequency,
    String? settlementDay,
    DateTime? createdAt,
    double? customDeliveryFee,
    String? customPlatformFeeType,
    double? customPlatformFeeValue,
    String? customPaystackFeeAbsorbedBy,
    double? customFailedAttemptFee,
  }) {
    return ClientProfile(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      contactPerson: contactPerson ?? this.contactPerson,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      code: code ?? this.code,
      tier: tier ?? this.tier,
      closerLimit: closerLimit ?? this.closerLimit,
      isEnterprise: isEnterprise ?? this.isEnterprise,
      totalClosersCount: totalClosersCount ?? this.totalClosersCount,
      isActive: isActive ?? this.isActive,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountName: accountName ?? this.accountName,
      settlementFrequency: settlementFrequency ?? this.settlementFrequency,
      settlementDay: settlementDay ?? this.settlementDay,
      createdAt: createdAt ?? this.createdAt,
      customDeliveryFee: customDeliveryFee ?? this.customDeliveryFee,
      customPlatformFeeType: customPlatformFeeType ?? this.customPlatformFeeType,
      customPlatformFeeValue: customPlatformFeeValue ?? this.customPlatformFeeValue,
      customPaystackFeeAbsorbedBy: customPaystackFeeAbsorbedBy ?? this.customPaystackFeeAbsorbedBy,
      customFailedAttemptFee: customFailedAttemptFee ?? this.customFailedAttemptFee,
    );
  }
}
