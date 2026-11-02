import 'package:flutter/foundation.dart';

/// Representation of a managed user within the Admin Console
@immutable
class AdminUserItem {
  final String id;
  final String? authUserId;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final String role;
  final String? distributionCenterId;
  final String? distributionCenterName;
  final String? clientId;
  final String? clientCompanyName;
  final String status; // 'active' | 'suspended' | 'pending'
  final String? deliveryAgentCode;
  final String? closerCode;
  final DateTime? createdAt;
  final DateTime? lastActiveAt;

  const AdminUserItem({
    required this.id,
    this.authUserId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.role,
    this.distributionCenterId,
    this.distributionCenterName,
    this.clientId,
    this.clientCompanyName,
    this.status = 'active',
    this.deliveryAgentCode,
    this.closerCode,
    this.createdAt,
    this.lastActiveAt,
  });

  String get fullName => '$firstName $lastName'.trim().isEmpty ? email : '$firstName $lastName'.trim();
  bool get isActive => status == 'active';
  bool get isSuspended => status == 'suspended';

  AdminUserItem copyWith({
    String? id,
    String? authUserId,
    String? email,
    String? firstName,
    String? lastName,
    String? phone,
    String? role,
    String? distributionCenterId,
    String? distributionCenterName,
    String? clientId,
    String? clientCompanyName,
    String? status,
    String? deliveryAgentCode,
    String? closerCode,
    DateTime? createdAt,
    DateTime? lastActiveAt,
  }) {
    return AdminUserItem(
      id: id ?? this.id,
      authUserId: authUserId ?? this.authUserId,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      distributionCenterId: distributionCenterId ?? this.distributionCenterId,
      distributionCenterName: distributionCenterName ?? this.distributionCenterName,
      clientId: clientId ?? this.clientId,
      clientCompanyName: clientCompanyName ?? this.clientCompanyName,
      status: status ?? this.status,
      deliveryAgentCode: deliveryAgentCode ?? this.deliveryAgentCode,
      closerCode: closerCode ?? this.closerCode,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }

  factory AdminUserItem.fromJson(Map<String, dynamic> json) {
    return AdminUserItem(
      id: json['id']?.toString() ?? '',
      authUserId: json['auth_user_id']?.toString() ?? json['user_id']?.toString(),
      email: json['email']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: json['role']?.toString() ?? 'client',
      distributionCenterId: json['distribution_center_id']?.toString(),
      distributionCenterName: json['distribution_center_name']?.toString(),
      clientId: json['client_id']?.toString(),
      clientCompanyName: json['client_company_name']?.toString(),
      status: json['status']?.toString() ?? 'active',
      deliveryAgentCode: json['delivery_agent_code']?.toString(),
      closerCode: json['closer_code']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      lastActiveAt: json['last_sign_in_at'] != null ? DateTime.tryParse(json['last_sign_in_at'].toString()) : null,
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
      'distribution_center_id': distributionCenterId,
      'client_id': clientId,
      'status': status,
    };
  }
}

/// Distribution Center managed resource
@immutable
class AdminDistributionCenter {
  final String id;
  final String code;
  final String name;
  final String city;
  final String state;
  final String address;
  final String? supervisorId;
  final String supervisorName;
  final int capacity;
  final int activeRiders;
  final int currentStockCount;
  final double vaultBalance;
  final String status; // 'operational' | 'congested' | 'maintenance'
  final bool isGrandDc;

  const AdminDistributionCenter({
    required this.id,
    required this.code,
    required this.name,
    required this.city,
    required this.state,
    required this.address,
    this.supervisorId,
    this.supervisorName = 'Unassigned',
    this.capacity = 5000,
    this.activeRiders = 0,
    this.currentStockCount = 0,
    this.vaultBalance = 0.0,
    this.status = 'operational',
    this.isGrandDc = false,
  });

  AdminDistributionCenter copyWith({
    String? id,
    String? code,
    String? name,
    String? city,
    String? state,
    String? address,
    String? supervisorId,
    String? supervisorName,
    int? capacity,
    int? activeRiders,
    int? currentStockCount,
    double? vaultBalance,
    String? status,
    bool? isGrandDc,
  }) {
    return AdminDistributionCenter(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      city: city ?? this.city,
      state: state ?? this.state,
      address: address ?? this.address,
      supervisorId: supervisorId ?? this.supervisorId,
      supervisorName: supervisorName ?? this.supervisorName,
      capacity: capacity ?? this.capacity,
      activeRiders: activeRiders ?? this.activeRiders,
      currentStockCount: currentStockCount ?? this.currentStockCount,
      vaultBalance: vaultBalance ?? this.vaultBalance,
      status: status ?? this.status,
      isGrandDc: isGrandDc ?? this.isGrandDc,
    );
  }

  factory AdminDistributionCenter.fromJson(Map<String, dynamic> json) {
    return AdminDistributionCenter(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? json['hub_code']?.toString() ?? 'DC',
      name: json['name']?.toString() ?? 'Distribution Center',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      supervisorId: json['supervisor_id']?.toString(),
      supervisorName: json['supervisor_name']?.toString() ?? 'Unassigned',
      capacity: int.tryParse(json['capacity']?.toString() ?? '') ?? 5000,
      activeRiders: int.tryParse(json['active_riders']?.toString() ?? '') ?? 0,
      currentStockCount: int.tryParse(json['current_stock_count']?.toString() ?? '') ?? 0,
      vaultBalance: double.tryParse(json['vault_balance']?.toString() ?? '') ?? 0.0,
      status: json['status']?.toString() ?? 'operational',
      isGrandDc: json['is_grand_dc'] == true || json['is_primary'] == true,
    );
  }
}

/// Merchant / Client account managed resource
@immutable
class AdminMerchant {
  final String id;
  final String businessName;
  final String contactName;
  final String phone;
  final String email;
  final String tier; // 'Standard' | 'Enterprise'
  final int closerCount;
  final int closerLimit;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final bool isBankVerified;
  final String settlementSchedule; // 'daily_t1' | 'biweekly' | 'weekly'
  final String status; // 'active' | 'pending' | 'suspended'
  final int activeOrdersCount;
  final double totalRemittedNaira;

  const AdminMerchant({
    required this.id,
    required this.businessName,
    required this.contactName,
    required this.phone,
    required this.email,
    this.tier = 'Standard',
    this.closerCount = 0,
    this.closerLimit = 3,
    this.bankName = '',
    this.accountNumber = '',
    this.accountName = '',
    this.isBankVerified = false,
    this.settlementSchedule = 'daily_t1',
    this.status = 'active',
    this.activeOrdersCount = 0,
    this.totalRemittedNaira = 0.0,
  });

  bool get isEnterprise => tier.toLowerCase() == 'enterprise';

  AdminMerchant copyWith({
    String? id,
    String? businessName,
    String? contactName,
    String? phone,
    String? email,
    String? tier,
    int? closerCount,
    int? closerLimit,
    String? bankName,
    String? accountNumber,
    String? accountName,
    bool? isBankVerified,
    String? settlementSchedule,
    String? status,
    int? activeOrdersCount,
    double? totalRemittedNaira,
  }) {
    return AdminMerchant(
      id: id ?? this.id,
      businessName: businessName ?? this.businessName,
      contactName: contactName ?? this.contactName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      tier: tier ?? this.tier,
      closerCount: closerCount ?? this.closerCount,
      closerLimit: closerLimit ?? this.closerLimit,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountName: accountName ?? this.accountName,
      isBankVerified: isBankVerified ?? this.isBankVerified,
      settlementSchedule: settlementSchedule ?? this.settlementSchedule,
      status: status ?? this.status,
      activeOrdersCount: activeOrdersCount ?? this.activeOrdersCount,
      totalRemittedNaira: totalRemittedNaira ?? this.totalRemittedNaira,
    );
  }

  factory AdminMerchant.fromJson(Map<String, dynamic> json) {
    return AdminMerchant(
      id: json['id']?.toString() ?? '',
      businessName: json['company_name']?.toString() ?? json['business_name']?.toString() ?? 'Merchant',
      contactName: json['contact_person']?.toString() ?? json['contact_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      tier: json['tier']?.toString() ?? (json['is_enterprise'] == true ? 'Enterprise' : 'Standard'),
      closerCount: int.tryParse(json['closers_count']?.toString() ?? '') ?? 0,
      closerLimit: int.tryParse(json['closer_limit']?.toString() ?? '') ?? 3,
      bankName: json['bank_name']?.toString() ?? '',
      accountNumber: json['bank_account_number']?.toString() ?? '',
      accountName: json['bank_account_name']?.toString() ?? '',
      isBankVerified: json['is_bank_verified'] == true,
      settlementSchedule: json['settlement_schedule']?.toString() ?? 'daily_t1',
      status: json['status']?.toString() ?? 'active',
      activeOrdersCount: int.tryParse(json['active_orders']?.toString() ?? '') ?? 0,
      totalRemittedNaira: double.tryParse(json['total_remitted']?.toString() ?? '') ?? 0.0,
    );
  }
}

/// App settings and business policies
@immutable
class AdminAppSettings {
  final bool mandatorySignature;
  final bool mandatoryPhoto;
  final bool allowOtpFallback;
  final bool requireFailureVoiceNote;
  final double upgAutoApproveLimit;
  final double maxRiderCashHolding;
  final int voiceNoteMaxSeconds;
  final String defaultThemeMode; // 'dark' | 'light' | 'system'
  final String currencySymbol;
  final bool enableLiveGpsTracking;

  const AdminAppSettings({
    this.mandatorySignature = true,
    this.mandatoryPhoto = true,
    this.allowOtpFallback = true,
    this.requireFailureVoiceNote = false,
    this.upgAutoApproveLimit = 15000.0,
    this.maxRiderCashHolding = 250000.0,
    this.voiceNoteMaxSeconds = 120,
    this.defaultThemeMode = 'system',
    this.currencySymbol = '₦',
    this.enableLiveGpsTracking = true,
  });

  AdminAppSettings copyWith({
    bool? mandatorySignature,
    bool? mandatoryPhoto,
    bool? allowOtpFallback,
    bool? requireFailureVoiceNote,
    double? upgAutoApproveLimit,
    double? maxRiderCashHolding,
    int? voiceNoteMaxSeconds,
    String? defaultThemeMode,
    String? currencySymbol,
    bool? enableLiveGpsTracking,
  }) {
    return AdminAppSettings(
      mandatorySignature: mandatorySignature ?? this.mandatorySignature,
      mandatoryPhoto: mandatoryPhoto ?? this.mandatoryPhoto,
      allowOtpFallback: allowOtpFallback ?? this.allowOtpFallback,
      requireFailureVoiceNote: requireFailureVoiceNote ?? this.requireFailureVoiceNote,
      upgAutoApproveLimit: upgAutoApproveLimit ?? this.upgAutoApproveLimit,
      maxRiderCashHolding: maxRiderCashHolding ?? this.maxRiderCashHolding,
      voiceNoteMaxSeconds: voiceNoteMaxSeconds ?? this.voiceNoteMaxSeconds,
      defaultThemeMode: defaultThemeMode ?? this.defaultThemeMode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      enableLiveGpsTracking: enableLiveGpsTracking ?? this.enableLiveGpsTracking,
    );
  }

  factory AdminAppSettings.fromJson(Map<String, dynamic> json) {
    return AdminAppSettings(
      mandatorySignature: json['mandatory_signature'] ?? true,
      mandatoryPhoto: json['mandatory_photo'] ?? true,
      allowOtpFallback: json['allow_otp_fallback'] ?? true,
      requireFailureVoiceNote: json['require_failure_voice_note'] ?? false,
      upgAutoApproveLimit: double.tryParse(json['upg_auto_approve_limit']?.toString() ?? '') ?? 15000.0,
      maxRiderCashHolding: double.tryParse(json['max_rider_cash_holding']?.toString() ?? '') ?? 250000.0,
      voiceNoteMaxSeconds: int.tryParse(json['voice_note_max_seconds']?.toString() ?? '') ?? 120,
      defaultThemeMode: json['default_theme_mode']?.toString() ?? 'system',
      currencySymbol: json['currency_symbol']?.toString() ?? '₦',
      enableLiveGpsTracking: json['enable_live_gps_tracking'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mandatory_signature': mandatorySignature,
      'mandatory_photo': mandatoryPhoto,
      'allow_otp_fallback': allowOtpFallback,
      'require_failure_voice_note': requireFailureVoiceNote,
      'upg_auto_approve_limit': upgAutoApproveLimit,
      'max_rider_cash_holding': maxRiderCashHolding,
      'voice_note_max_seconds': voiceNoteMaxSeconds,
      'default_theme_mode': defaultThemeMode,
      'currency_symbol': currencySymbol,
      'enable_live_gps_tracking': enableLiveGpsTracking,
    };
  }
}

/// Server side configuration & API keys
@immutable
class AdminServerSettings {
  final String paystackPublicKey;
  final String paystackSecretKey;
  final bool paystackLiveMode;
  final String monnifyApiKey;
  final String monnifySecretKey;
  final String monnifyContractCode;
  final String termiiApiKey;
  final String termiiSenderId;
  final String whatsappToken;
  final String whatsappPhoneId;
  final String supabasePoolerUrl;
  final bool isDbHealthy;
  final int lastPingMs;
  final DateTime? lastSyncTime;

  const AdminServerSettings({
    this.paystackPublicKey = 'pk_live_********************',
    this.paystackSecretKey = 'sk_live_********************',
    this.paystackLiveMode = true,
    this.monnifyApiKey = 'MK_PROD_********************',
    this.monnifySecretKey = '********************',
    this.monnifyContractCode = '8829401923',
    this.termiiApiKey = 'TL_KEY_********************',
    this.termiiSenderId = 'NovaXpress',
    this.whatsappToken = 'EAAX********************',
    this.whatsappPhoneId = '109283746501928',
    this.supabasePoolerUrl = 'aws-0-eu-west-1.pooler.supabase.com',
    this.isDbHealthy = true,
    this.lastPingMs = 38,
    this.lastSyncTime,
  });

  AdminServerSettings copyWith({
    String? paystackPublicKey,
    String? paystackSecretKey,
    bool? paystackLiveMode,
    String? monnifyApiKey,
    String? monnifySecretKey,
    String? monnifyContractCode,
    String? termiiApiKey,
    String? termiiSenderId,
    String? whatsappToken,
    String? whatsappPhoneId,
    String? supabasePoolerUrl,
    bool? isDbHealthy,
    int? lastPingMs,
    DateTime? lastSyncTime,
  }) {
    return AdminServerSettings(
      paystackPublicKey: paystackPublicKey ?? this.paystackPublicKey,
      paystackSecretKey: paystackSecretKey ?? this.paystackSecretKey,
      paystackLiveMode: paystackLiveMode ?? this.paystackLiveMode,
      monnifyApiKey: monnifyApiKey ?? this.monnifyApiKey,
      monnifySecretKey: monnifySecretKey ?? this.monnifySecretKey,
      monnifyContractCode: monnifyContractCode ?? this.monnifyContractCode,
      termiiApiKey: termiiApiKey ?? this.termiiApiKey,
      termiiSenderId: termiiSenderId ?? this.termiiSenderId,
      whatsappToken: whatsappToken ?? this.whatsappToken,
      whatsappPhoneId: whatsappPhoneId ?? this.whatsappPhoneId,
      supabasePoolerUrl: supabasePoolerUrl ?? this.supabasePoolerUrl,
      isDbHealthy: isDbHealthy ?? this.isDbHealthy,
      lastPingMs: lastPingMs ?? this.lastPingMs,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

/// Routing tariff matrix and rider compensation rules
@immutable
class AdminRoutingTariff {
  final String stateName;
  final String assignedHubId;
  final String assignedHubName;
  final double intraStateBaseRate;
  final double interStateBaseRate;
  final int slaDeliveryDays;
  final double coldChainSurchargePct;
  final double pdaCommission;
  final double inHouseCommission;
  final double dailyFuelAllowance;

  const AdminRoutingTariff({
    required this.stateName,
    required this.assignedHubId,
    required this.assignedHubName,
    this.intraStateBaseRate = 2500.0,
    this.interStateBaseRate = 4500.0,
    this.slaDeliveryDays = 1,
    this.coldChainSurchargePct = 25.0,
    this.pdaCommission = 1000.0,
    this.inHouseCommission = 500.0,
    this.dailyFuelAllowance = 1200.0,
  });

  AdminRoutingTariff copyWith({
    String? stateName,
    String? assignedHubId,
    String? assignedHubName,
    double? intraStateBaseRate,
    double? interStateBaseRate,
    int? slaDeliveryDays,
    double? coldChainSurchargePct,
    double? pdaCommission,
    double? inHouseCommission,
    double? dailyFuelAllowance,
  }) {
    return AdminRoutingTariff(
      stateName: stateName ?? this.stateName,
      assignedHubId: assignedHubId ?? this.assignedHubId,
      assignedHubName: assignedHubName ?? this.assignedHubName,
      intraStateBaseRate: intraStateBaseRate ?? this.intraStateBaseRate,
      interStateBaseRate: interStateBaseRate ?? this.interStateBaseRate,
      slaDeliveryDays: slaDeliveryDays ?? this.slaDeliveryDays,
      coldChainSurchargePct: coldChainSurchargePct ?? this.coldChainSurchargePct,
      pdaCommission: pdaCommission ?? this.pdaCommission,
      inHouseCommission: inHouseCommission ?? this.inHouseCommission,
      dailyFuelAllowance: dailyFuelAllowance ?? this.dailyFuelAllowance,
    );
  }
}

/// Immutable security audit trail
@immutable
class AdminAuditLog {
  final String id;
  final DateTime timestamp;
  final String actorName;
  final String actorEmail;
  final String actorRole;
  final String action; // 'CREATE_DC_ADMIN' | 'CREATE_ADMIN_USER' | 'UPDATE_POLICY' | 'UPDATE_TARIFF' | 'RESET_PASS'
  final String resource; // 'Users' | 'DistributionCenters' | 'Settings' | 'Tariffs' | 'Orders' | 'Remittances' | 'Inventory' | 'Expenditures'
  final String details;
  final String ipAddress;
  final String? distributionCenterId;
  final String? distributionCenterName;
  final Map<String, dynamic>? metadata;

  const AdminAuditLog({
    required this.id,
    required this.timestamp,
    required this.actorName,
    required this.actorEmail,
    required this.actorRole,
    required this.action,
    required this.resource,
    required this.details,
    this.ipAddress = '102.89.44.12',
    this.distributionCenterId,
    this.distributionCenterName,
    this.metadata,
  });

  factory AdminAuditLog.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['created_at']?.toString() ?? json['timestamp']?.toString() ?? DateTime.now().toIso8601String());
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return AdminAuditLog(
      id: json['id']?.toString() ?? 'LOG-${DateTime.now().millisecondsSinceEpoch}',
      timestamp: parsedDate,
      actorName: json['actor_name']?.toString() ?? 'System Operator',
      actorEmail: json['actor_email']?.toString() ?? 'operations@novaxpress.ng',
      actorRole: json['actor_role']?.toString() ?? 'dc_manager',
      action: json['action']?.toString() ?? 'GENERAL_ACTION',
      resource: json['resource']?.toString() ?? 'System',
      details: json['details']?.toString() ?? '',
      ipAddress: json['ip_address']?.toString() ?? '102.89.44.12',
      distributionCenterId: json['distribution_center_id']?.toString(),
      distributionCenterName: json['distribution_center_name']?.toString(),
      metadata: json['metadata'] is Map<String, dynamic> ? json['metadata'] as Map<String, dynamic> : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'actor_name': actorName,
    'actor_email': actorEmail,
    'actor_role': actorRole,
    'action': action,
    'resource': resource,
    'details': details,
    'ip_address': ipAddress,
    'distribution_center_id': distributionCenterId,
    'distribution_center_name': distributionCenterName,
    'metadata': metadata,
    'created_at': timestamp.toIso8601String(),
  };
}
