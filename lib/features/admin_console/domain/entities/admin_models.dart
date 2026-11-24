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
  final List<String> assignedAgentNames;

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
    this.assignedAgentNames = const [],
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
    List<String>? assignedAgentNames,
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
      assignedAgentNames: assignedAgentNames ?? this.assignedAgentNames,
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
      assignedAgentNames: (json['assigned_agent_names'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          (json['assigned_agents'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
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
  final List<String> assignedAgentIds;
  final List<String> assignedAgentNames;
  final List<String> productsDistributed;
  final double todayGrossCod;
  final double todayDeliveryFees;
  final double todayFailedFees;
  final double todayNetRemittance;

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
    this.assignedAgentIds = const [],
    this.assignedAgentNames = const [],
    this.productsDistributed = const [],
    this.todayGrossCod = 0.0,
    this.todayDeliveryFees = 0.0,
    this.todayFailedFees = 0.0,
    this.todayNetRemittance = 0.0,
  });

  bool get isEnterprise => tier.toLowerCase() == 'enterprise';
  bool get isActive => status == 'active';

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
    List<String>? assignedAgentIds,
    List<String>? assignedAgentNames,
    List<String>? productsDistributed,
    double? todayGrossCod,
    double? todayDeliveryFees,
    double? todayFailedFees,
    double? todayNetRemittance,
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
      assignedAgentIds: assignedAgentIds ?? this.assignedAgentIds,
      assignedAgentNames: assignedAgentNames ?? this.assignedAgentNames,
      productsDistributed: productsDistributed ?? this.productsDistributed,
      todayGrossCod: todayGrossCod ?? this.todayGrossCod,
      todayDeliveryFees: todayDeliveryFees ?? this.todayDeliveryFees,
      todayFailedFees: todayFailedFees ?? this.todayFailedFees,
      todayNetRemittance: todayNetRemittance ?? this.todayNetRemittance,
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
      assignedAgentIds: (json['assigned_agent_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      assignedAgentNames: (json['assigned_agent_names'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      productsDistributed: (json['products_distributed'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      todayGrossCod: double.tryParse(json['today_gross_cod']?.toString() ?? '') ?? 0.0,
      todayDeliveryFees: double.tryParse(json['today_delivery_fees']?.toString() ?? '') ?? 0.0,
      todayFailedFees: double.tryParse(json['today_failed_fees']?.toString() ?? '') ?? 0.0,
      todayNetRemittance: double.tryParse(json['today_net_remittance']?.toString() ?? '') ?? 0.0,
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

/// Representation of 3PL Partners, Regional Distributors, and Rider Courier Agents
@immutable
class AdminLogisticsAgent {
  final String id;
  final String name;
  final String agentCode;
  final String type; // 'internal_logistics' | '3pl_partner' | 'distributor_agent' | 'rider_agent'
  final String contactPerson;
  final String phone;
  final String email;
  final List<String> coverageStates;
  final int activeRidersCount;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final String status; // 'active' | 'pending_approval' | 'suspended'
  final double rating;
  final int totalDeliveries;
  final double totalRemittedNaira;
  final double deliveryFee; // flat-rate delivery fee, e.g. 2500.0
  final double failedDeliveryFee; // flat-rate failed delivery fee, e.g. 1000.0
  final String? assignedWarehouseId;
  final String? assignedWarehouseName;
  final List<String> assignedMerchantIds;
  final List<String> assignedMerchantNames;
  final double commissionRate; // e.g. 5.0 for 5% or customized per-delivery commission
  final Map<String, int> heldStock; // Product Name / SKU -> Units Held
  final DateTime? lastBalancedAt;
  final DateTime createdAt;

  const AdminLogisticsAgent({
    required this.id,
    required this.name,
    required this.agentCode,
    required this.type,
    required this.contactPerson,
    required this.phone,
    required this.email,
    this.coverageStates = const [],
    this.activeRidersCount = 0,
    this.bankName = '',
    this.accountNumber = '',
    this.accountName = '',
    this.status = 'active',
    this.rating = 4.8,
    this.totalDeliveries = 0,
    this.totalRemittedNaira = 0.0,
    this.deliveryFee = 2500.0,
    this.failedDeliveryFee = 1000.0,
    this.assignedWarehouseId,
    this.assignedWarehouseName,
    this.assignedMerchantIds = const [],
    this.assignedMerchantNames = const [],
    this.commissionRate = 0.0,
    this.heldStock = const {},
    this.lastBalancedAt,
    required this.createdAt,
  });

  bool get isActive => status == 'active';
  bool get isPendingApproval => status == 'pending_approval';

  bool isAssignedToMerchant(String merchantId) =>
      assignedMerchantIds.contains(merchantId);

  String get typeLabel {
    switch (type) {
      case 'internal_logistics':
        return 'Internal Hub (NovaXpress)';
      case '3pl_partner':
        return '3PL Logistics Company';
      case 'distributor_agent':
        return 'Regional Distributor';
      case 'rider_agent':
        return 'Rider Courier Agent';
      default:
        return 'Logistics Agent';
    }
  }

  AdminLogisticsAgent copyWith({
    String? id,
    String? name,
    String? agentCode,
    String? type,
    String? contactPerson,
    String? phone,
    String? email,
    List<String>? coverageStates,
    int? activeRidersCount,
    String? bankName,
    String? accountNumber,
    String? accountName,
    String? status,
    double? rating,
    int? totalDeliveries,
    double? totalRemittedNaira,
    double? deliveryFee,
    double? failedDeliveryFee,
    String? assignedWarehouseId,
    String? assignedWarehouseName,
    List<String>? assignedMerchantIds,
    List<String>? assignedMerchantNames,
    double? commissionRate,
    Map<String, int>? heldStock,
    DateTime? lastBalancedAt,
    DateTime? createdAt,
  }) {
    return AdminLogisticsAgent(
      id: id ?? this.id,
      name: name ?? this.name,
      agentCode: agentCode ?? this.agentCode,
      type: type ?? this.type,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      coverageStates: coverageStates ?? this.coverageStates,
      activeRidersCount: activeRidersCount ?? this.activeRidersCount,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountName: accountName ?? this.accountName,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      totalRemittedNaira: totalRemittedNaira ?? this.totalRemittedNaira,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      failedDeliveryFee: failedDeliveryFee ?? this.failedDeliveryFee,
      assignedWarehouseId: assignedWarehouseId ?? this.assignedWarehouseId,
      assignedWarehouseName: assignedWarehouseName ?? this.assignedWarehouseName,
      assignedMerchantIds: assignedMerchantIds ?? this.assignedMerchantIds,
      assignedMerchantNames: assignedMerchantNames ?? this.assignedMerchantNames,
      commissionRate: commissionRate ?? this.commissionRate,
      heldStock: heldStock ?? this.heldStock,
      lastBalancedAt: lastBalancedAt ?? this.lastBalancedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory AdminLogisticsAgent.fromJson(Map<String, dynamic> json) {
    Map<String, int> stockMap = {};
    if (json['held_stock'] is Map) {
      (json['held_stock'] as Map).forEach((k, v) {
        stockMap[k.toString()] = int.tryParse(v.toString()) ?? 0;
      });
    }

    return AdminLogisticsAgent(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Logistics Partner',
      agentCode: json['agent_code']?.toString() ?? json['code']?.toString() ?? 'AGT',
      type: json['type']?.toString() ?? '3pl_partner',
      contactPerson: json['contact_person']?.toString() ?? json['contact_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      coverageStates: (json['coverage_states'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      activeRidersCount: int.tryParse(json['active_riders_count']?.toString() ?? '') ?? 0,
      bankName: json['bank_name']?.toString() ?? '',
      accountNumber: json['account_number']?.toString() ?? '',
      accountName: json['account_name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      rating: double.tryParse(json['rating']?.toString() ?? '') ?? 4.8,
      totalDeliveries: int.tryParse(json['total_deliveries']?.toString() ?? '') ?? 0,
      totalRemittedNaira: double.tryParse(json['total_remitted_naira']?.toString() ?? '') ?? 0.0,
      deliveryFee: double.tryParse(json['delivery_fee']?.toString() ?? '') ?? 2500.0,
      failedDeliveryFee: double.tryParse(json['failed_delivery_fee']?.toString() ?? '') ?? 1000.0,
      assignedWarehouseId: json['assigned_warehouse_id']?.toString(),
      assignedWarehouseName: json['assigned_warehouse_name']?.toString(),
      assignedMerchantIds: (json['assigned_merchant_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      assignedMerchantNames: (json['assigned_merchant_names'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      commissionRate: double.tryParse(json['commission_rate']?.toString() ?? '') ?? 0.0,
      heldStock: stockMap,
      lastBalancedAt: json['last_balanced_at'] != null ? DateTime.tryParse(json['last_balanced_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'agent_code': agentCode,
      'type': type,
      'contact_person': contactPerson,
      'phone': phone,
      'email': email,
      'coverage_states': coverageStates,
      'active_riders_count': activeRidersCount,
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_name': accountName,
      'status': status,
      'rating': rating,
      'total_deliveries': totalDeliveries,
      'total_remitted_naira': totalRemittedNaira,
      'delivery_fee': deliveryFee,
      'failed_delivery_fee': failedDeliveryFee,
      'assigned_warehouse_id': assignedWarehouseId,
      'assigned_warehouse_name': assignedWarehouseName,
      'assigned_merchant_ids': assignedMerchantIds,
      'assigned_merchant_names': assignedMerchantNames,
      'commission_rate': commissionRate,
      'held_stock': heldStock,
      'last_balanced_at': lastBalancedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Representation of a Warehouse / Distribution Center Operational Expense
@immutable
class AdminWarehouseExpense {
  final String id;
  final String warehouseId;
  final String warehouseName;
  final String title;
  final String category; // 'diesel_generator', 'facility_rent', 'packaging_materials', 'vehicle_fleet', 'security_utilities', 'other'
  final double amount;
  final String recordedBy;
  final DateTime recordedAt;
  final String status; // 'approved', 'pending_audit', 'reimbursed'
  final String receiptNumber;
  final String notes;

  const AdminWarehouseExpense({
    required this.id,
    required this.warehouseId,
    required this.warehouseName,
    required this.title,
    required this.category,
    required this.amount,
    required this.recordedBy,
    required this.recordedAt,
    this.status = 'approved',
    this.receiptNumber = '',
    this.notes = '',
  });

  String get categoryLabel {
    switch (category) {
      case 'diesel_generator':
        return 'Diesel & Power';
      case 'facility_rent':
        return 'Facility & Rent';
      case 'packaging_materials':
        return 'Packaging & Boxes';
      case 'vehicle_fleet':
        return 'Fleet & Maintenance';
      case 'security_utilities':
        return 'Security & Utilities';
      default:
        return 'Operational Expense';
    }
  }

  AdminWarehouseExpense copyWith({
    String? id,
    String? warehouseId,
    String? warehouseName,
    String? title,
    String? category,
    double? amount,
    String? recordedBy,
    DateTime? recordedAt,
    String? status,
    String? receiptNumber,
    String? notes,
  }) {
    return AdminWarehouseExpense(
      id: id ?? this.id,
      warehouseId: warehouseId ?? this.warehouseId,
      warehouseName: warehouseName ?? this.warehouseName,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      recordedBy: recordedBy ?? this.recordedBy,
      recordedAt: recordedAt ?? this.recordedAt,
      status: status ?? this.status,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      notes: notes ?? this.notes,
    );
  }

  factory AdminWarehouseExpense.fromJson(Map<String, dynamic> json) {
    return AdminWarehouseExpense(
      id: json['id']?.toString() ?? '',
      warehouseId: json['warehouse_id']?.toString() ?? '',
      warehouseName: json['warehouse_name']?.toString() ?? 'Distribution Center',
      title: json['title']?.toString() ?? 'Operational Expense',
      category: json['category']?.toString() ?? 'other',
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0.0,
      recordedBy: json['recorded_by']?.toString() ?? 'Station Admin',
      recordedAt: json['recorded_at'] != null ? DateTime.tryParse(json['recorded_at'].toString()) ?? DateTime.now() : DateTime.now(),
      status: json['status']?.toString() ?? 'approved',
      receiptNumber: json['receipt_number']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'warehouse_id': warehouseId,
      'warehouse_name': warehouseName,
      'title': title,
      'category': category,
      'amount': amount,
      'recorded_by': recordedBy,
      'recorded_at': recordedAt.toIso8601String(),
      'status': status,
      'receipt_number': receiptNumber,
      'notes': notes,
    };
  }
}

/// Representation of Cross-Hub Live Inventory for Platform Admin oversight
@immutable
class AdminGlobalStockItem {
  final String id;
  final String productId;
  final String productName;
  final String sku;
  final String merchantId;
  final String merchantName;
  final double unitPrice;
  final int totalWarehouseStock;
  final int totalRiderCustodyStock;
  final int totalStock;
  final int lowStockDcCount;
  final Map<String, int> dcStockBreakdown; // e.g. {'Abuja Central DC': 450, 'Lagos Grand Hub': 920}
  final Map<String, int> agentStockBreakdown; // e.g. {'NovaXpress Logistics': 35, 'GIG Logistics': 150}

  const AdminGlobalStockItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.merchantId,
    required this.merchantName,
    required this.unitPrice,
    required this.totalWarehouseStock,
    required this.totalRiderCustodyStock,
    required this.totalStock,
    this.lowStockDcCount = 0,
    this.dcStockBreakdown = const {},
    this.agentStockBreakdown = const {},
  });

  AdminGlobalStockItem copyWith({
    String? id,
    String? productId,
    String? productName,
    String? sku,
    String? merchantId,
    String? merchantName,
    double? unitPrice,
    int? totalWarehouseStock,
    int? totalRiderCustodyStock,
    int? totalStock,
    int? lowStockDcCount,
    Map<String, int>? dcStockBreakdown,
    Map<String, int>? agentStockBreakdown,
  }) {
    return AdminGlobalStockItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      sku: sku ?? this.sku,
      merchantId: merchantId ?? this.merchantId,
      merchantName: merchantName ?? this.merchantName,
      unitPrice: unitPrice ?? this.unitPrice,
      totalWarehouseStock: totalWarehouseStock ?? this.totalWarehouseStock,
      totalRiderCustodyStock: totalRiderCustodyStock ?? this.totalRiderCustodyStock,
      totalStock: totalStock ?? this.totalStock,
      lowStockDcCount: lowStockDcCount ?? this.lowStockDcCount,
      dcStockBreakdown: dcStockBreakdown ?? this.dcStockBreakdown,
      agentStockBreakdown: agentStockBreakdown ?? this.agentStockBreakdown,
    );
  }

  factory AdminGlobalStockItem.fromJson(Map<String, dynamic> json) {
    Map<String, int> dcMap = {};
    if (json['dc_stock_breakdown'] is Map) {
      (json['dc_stock_breakdown'] as Map).forEach((k, v) {
        dcMap[k.toString()] = int.tryParse(v.toString()) ?? 0;
      });
    }
    Map<String, int> agentMap = {};
    if (json['agent_stock_breakdown'] is Map) {
      (json['agent_stock_breakdown'] as Map).forEach((k, v) {
        agentMap[k.toString()] = int.tryParse(v.toString()) ?? 0;
      });
    }

    return AdminGlobalStockItem(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      merchantId: json['merchant_id']?.toString() ?? '',
      merchantName: json['merchant_name']?.toString() ?? '',
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '') ?? 0.0,
      totalWarehouseStock: int.tryParse(json['total_warehouse_stock']?.toString() ?? '') ?? 0,
      totalRiderCustodyStock: int.tryParse(json['total_rider_custody_stock']?.toString() ?? '') ?? 0,
      totalStock: int.tryParse(json['total_stock']?.toString() ?? '') ?? 0,
      lowStockDcCount: int.tryParse(json['low_stock_dc_count']?.toString() ?? '') ?? 0,
      dcStockBreakdown: dcMap,
      agentStockBreakdown: agentMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'sku': sku,
      'merchant_id': merchantId,
      'merchant_name': merchantName,
      'unit_price': unitPrice,
      'total_warehouse_stock': totalWarehouseStock,
      'total_rider_custody_stock': totalRiderCustodyStock,
      'total_stock': totalStock,
      'low_stock_dc_count': lowStockDcCount,
      'dc_stock_breakdown': dcStockBreakdown,
      'agent_stock_breakdown': agentStockBreakdown,
    };
  }
}

/// Custodian Type for multi-hub stock representation (Agents & DC Shelves)
enum AdminStockHolderType {
  dcShelf,
  internalFleet,
  external3pl,
  distributorAgent,
  riderAgent,
}

/// Row representation for Multi-Hub Stock DataTable:
/// Agents and Warehouse Shelves in ROWS, Products in COLUMNS
@immutable
class AdminStockHolderRow {
  final String id;
  final String name;
  final String code;
  final AdminStockHolderType type;
  final String hubName;
  final String hubId;
  final List<String> assignedMerchantIds;
  final List<String> assignedMerchantNames;
  final String contactPerson;
  final String phone;
  final Map<String, int> productQuantities; // key: SKU -> quantity held
  final int totalUnits;
  final double totalValueNaira;
  final String status;
  final DateTime? lastBalancedAt;
  final AdminLogisticsAgent? agentRef;
  final AdminDistributionCenter? dcRef;

  const AdminStockHolderRow({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.hubName,
    required this.hubId,
    this.assignedMerchantIds = const [],
    this.assignedMerchantNames = const [],
    this.contactPerson = '',
    this.phone = '',
    this.productQuantities = const {},
    required this.totalUnits,
    required this.totalValueNaira,
    this.status = 'active',
    this.lastBalancedAt,
    this.agentRef,
    this.dcRef,
  });

  bool get isDcShelf => type == AdminStockHolderType.dcShelf;
  bool get isInternalFleet => type == AdminStockHolderType.internalFleet;
  bool get is3pl => type == AdminStockHolderType.external3pl;

  String get typeLabel {
    switch (type) {
      case AdminStockHolderType.dcShelf:
        return 'Warehouse Shelf';
      case AdminStockHolderType.internalFleet:
        return 'Internal Fleet';
      case AdminStockHolderType.external3pl:
        return '3PL Partner';
      case AdminStockHolderType.distributorAgent:
        return 'Regional Distributor';
      case AdminStockHolderType.riderAgent:
        return 'Courier Agent';
    }
  }

  int quantityForSku(String sku) {
    if (productQuantities.containsKey(sku)) {
      return productQuantities[sku]!;
    }
    final normalized = sku.toLowerCase().trim();
    for (final e in productQuantities.entries) {
      if (e.key.toLowerCase().trim() == normalized) {
        return e.value;
      }
    }
    return 0;
  }
}

/// Representation of 10:00 PM Daily Settlement & Reconciliation Record
@immutable
class AdminSettlementReconciliation {
  final String id;
  final DateTime date;
  final double totalGrossCodCollected;
  final double totalCourierDeliveryFees;
  final double totalFuelAllowances;
  final double totalPlatformCommissions;
  final double totalNetMerchantPayout;
  final int totalOrdersSettled;
  final int participatingAgentsCount;
  final int participatingMerchantsCount;
  final String status; // 'awaiting_cutoff' | 'settled' | 'processing'
  final DateTime? settledAt;

  const AdminSettlementReconciliation({
    required this.id,
    required this.date,
    required this.totalGrossCodCollected,
    required this.totalCourierDeliveryFees,
    required this.totalFuelAllowances,
    required this.totalPlatformCommissions,
    required this.totalNetMerchantPayout,
    required this.totalOrdersSettled,
    required this.participatingAgentsCount,
    required this.participatingMerchantsCount,
    this.status = 'awaiting_cutoff',
    this.settledAt,
  });

  bool get isSettled => status == 'settled';

  AdminSettlementReconciliation copyWith({
    String? id,
    DateTime? date,
    double? totalGrossCodCollected,
    double? totalCourierDeliveryFees,
    double? totalFuelAllowances,
    double? totalPlatformCommissions,
    double? totalNetMerchantPayout,
    int? totalOrdersSettled,
    int? participatingAgentsCount,
    int? participatingMerchantsCount,
    String? status,
    DateTime? settledAt,
  }) {
    return AdminSettlementReconciliation(
      id: id ?? this.id,
      date: date ?? this.date,
      totalGrossCodCollected: totalGrossCodCollected ?? this.totalGrossCodCollected,
      totalCourierDeliveryFees: totalCourierDeliveryFees ?? this.totalCourierDeliveryFees,
      totalFuelAllowances: totalFuelAllowances ?? this.totalFuelAllowances,
      totalPlatformCommissions: totalPlatformCommissions ?? this.totalPlatformCommissions,
      totalNetMerchantPayout: totalNetMerchantPayout ?? this.totalNetMerchantPayout,
      totalOrdersSettled: totalOrdersSettled ?? this.totalOrdersSettled,
      participatingAgentsCount: participatingAgentsCount ?? this.participatingAgentsCount,
      participatingMerchantsCount: participatingMerchantsCount ?? this.participatingMerchantsCount,
      status: status ?? this.status,
      settledAt: settledAt ?? this.settledAt,
    );
  }

  factory AdminSettlementReconciliation.fromJson(Map<String, dynamic> json) {
    return AdminSettlementReconciliation(
      id: json['id']?.toString() ?? '',
      date: json['date'] != null ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now() : DateTime.now(),
      totalGrossCodCollected: double.tryParse(json['total_gross_cod_collected']?.toString() ?? '') ?? 0.0,
      totalCourierDeliveryFees: double.tryParse(json['total_courier_delivery_fees']?.toString() ?? '') ?? 0.0,
      totalFuelAllowances: double.tryParse(json['total_fuel_allowances']?.toString() ?? '') ?? 0.0,
      totalPlatformCommissions: double.tryParse(json['total_platform_commissions']?.toString() ?? '') ?? 0.0,
      totalNetMerchantPayout: double.tryParse(json['total_net_merchant_payout']?.toString() ?? '') ?? 0.0,
      totalOrdersSettled: int.tryParse(json['total_orders_settled']?.toString() ?? '') ?? 0,
      participatingAgentsCount: int.tryParse(json['participating_agents_count']?.toString() ?? '') ?? 0,
      participatingMerchantsCount: int.tryParse(json['participating_merchants_count']?.toString() ?? '') ?? 0,
      status: json['status']?.toString() ?? 'awaiting_cutoff',
      settledAt: json['settled_at'] != null ? DateTime.tryParse(json['settled_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'total_gross_cod_collected': totalGrossCodCollected,
      'total_courier_delivery_fees': totalCourierDeliveryFees,
      'total_fuel_allowances': totalFuelAllowances,
      'total_platform_commissions': totalPlatformCommissions,
      'total_net_merchant_payout': totalNetMerchantPayout,
      'total_orders_settled': totalOrdersSettled,
      'participating_agents_count': participatingAgentsCount,
      'participating_merchants_count': participatingMerchantsCount,
      'status': status,
      'settled_at': settledAt?.toIso8601String(),
    };
  }
}
