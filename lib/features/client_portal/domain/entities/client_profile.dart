import 'package:flutter/material.dart';

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
  final bool hasInventoryManagement;
  final List<String> servicesEnabled;
  final List<String> operatingStates;
  final String? logoUrl;
  final String? primaryColor;
  final String? secondaryColor;
  final String? accentColor;
  final Map<String, dynamic>? brandTheme;

  double? get customPlatformFee => customPlatformFeeValue;
  String get name => companyName;

  Color get brandPrimaryColor => _parseColor(primaryColor) ?? const Color(0xFF0D9488);
  Color get brandSecondaryColor => _parseColor(secondaryColor) ?? const Color(0xFF1E293B);
  Color get brandAccentColor => _parseColor(accentColor) ?? const Color(0xFFF59E0B);

  static Color? _parseColor(String? hexString) {
    if (hexString == null || hexString.trim().isEmpty) return null;
    final buffer = StringBuffer();
    String cleanHex = hexString.replaceAll('#', '').trim();
    if (cleanHex.length == 6) {
      buffer.write('ff');
      buffer.write(cleanHex);
    } else if (cleanHex.length == 8) {
      buffer.write(cleanHex);
    } else {
      return null;
    }
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return null;
    }
  }

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
    this.hasInventoryManagement = true,
    this.servicesEnabled = const ['fulfillment', 'delivery', 'inventory_management'],
    this.operatingStates = const ['Federal Capital Territory', 'Lagos', 'Rivers', 'Kano', 'Oyo', 'Enugu'],
    this.logoUrl,
    this.primaryColor,
    this.secondaryColor,
    this.accentColor,
    this.brandTheme,
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

    List<String> opStates = const ['Federal Capital Territory', 'Lagos', 'Rivers', 'Kano', 'Oyo', 'Enugu'];
    if (json['operating_states'] is List) {
      opStates = (json['operating_states'] as List).map((e) => e.toString()).toList();
    }

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
      isActive: json['is_active'] == null ? true : (json['is_active'] == true || json['is_active'] == 1 || json['is_active'] == 'true'),
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
      hasInventoryManagement: json['has_inventory_management'] == true ||
          json['has_inventory'] == true ||
          isEnt ||
          resolvedCompany.toLowerCase().contains('novacare') ||
          resolvedCompany.toLowerCase().contains('novacale'),
      servicesEnabled: json['services_enabled'] is List
          ? (json['services_enabled'] as List).map((e) => e.toString()).toList()
          : const ['fulfillment', 'delivery', 'inventory_management'],
      operatingStates: opStates,
      logoUrl: json['logo_url']?.toString() ?? json['logo']?.toString(),
      primaryColor: json['brand_color_primary']?.toString() ??
          (json['brand_theme'] is Map ? json['brand_theme']['primary']?.toString() : null),
      secondaryColor: json['brand_color_secondary']?.toString() ??
          (json['brand_theme'] is Map ? json['brand_theme']['secondary']?.toString() : null),
      accentColor: json['brand_color_accent']?.toString() ??
          (json['brand_theme'] is Map ? json['brand_theme']['accent']?.toString() : null),
      brandTheme: json['brand_theme'] is Map<String, dynamic>
          ? json['brand_theme'] as Map<String, dynamic>
          : (json['brand_theme'] is Map
              ? Map<String, dynamic>.from(json['brand_theme'] as Map)
              : null),
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
      'has_inventory_management': hasInventoryManagement,
      'services_enabled': servicesEnabled,
      'operating_states': operatingStates,
      'logo_url': logoUrl,
      'brand_color_primary': primaryColor,
      'brand_color_secondary': secondaryColor,
      'brand_color_accent': accentColor,
      'brand_theme': brandTheme,
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
    bool? hasInventoryManagement,
    List<String>? servicesEnabled,
    List<String>? operatingStates,
    String? logoUrl,
    String? primaryColor,
    String? secondaryColor,
    String? accentColor,
    Map<String, dynamic>? brandTheme,
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
      hasInventoryManagement: hasInventoryManagement ?? this.hasInventoryManagement,
      servicesEnabled: servicesEnabled ?? this.servicesEnabled,
      operatingStates: operatingStates ?? this.operatingStates,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      accentColor: accentColor ?? this.accentColor,
      brandTheme: brandTheme ?? this.brandTheme,
    );
  }
}
