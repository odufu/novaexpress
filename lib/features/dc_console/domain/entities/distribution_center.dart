import 'dart:convert';
import 'package:novexps/core/services/location_lookup_service.dart';

/// 3-Tier Distribution Center Hierarchy
/// - Grand DC: Apex National Distribution Center (Wuse Central branch default)
/// - Hub DC: Regional Hub Distribution Center serving clusters of satellite stations
/// - General DC: Standard Local/Branch Distribution Center
enum DistributionCenterTier {
  grandDc,     // Grand DC (Wuse Central branch default)
  hubDc,       // Hub Distribution Center
  generalDc,   // General Distribution Center
}

class DistributionCenter {
  final String id;
  final String companyId;
  final String name;
  final String code;
  final String state;
  final String city;
  final String address;
  final String? contactPhone;
  final String? contactEmail;
  final String? managerName;
  final bool isGrandDc;
  final bool isHub;
  final bool isActive;
  final String? parentDcId;
  final List<String> operatingZones;
  final int storageCapacityUnits;
  final int totalAssignedRiders;
  final int activeInventoryBatches;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DistributionCenter({
    required this.id,
    this.companyId = '11111111-1111-4111-8111-111111111111',
    required this.name,
    required this.code,
    required this.state,
    required this.city,
    required this.address,
    this.contactPhone,
    this.contactEmail,
    this.managerName,
    this.isGrandDc = false,
    this.isHub = false,
    this.isActive = true,
    this.parentDcId,
    this.operatingZones = const [],
    this.storageCapacityUnits = 25000,
    this.totalAssignedRiders = 0,
    this.activeInventoryBatches = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// Distribution Center Tier Hierarchy
  DistributionCenterTier get dcTier {
    if (isGrandDc) return DistributionCenterTier.grandDc;
    if (isHub) return DistributionCenterTier.hubDc;
    return DistributionCenterTier.generalDc;
  }

  String get dcTierLabel {
    switch (dcTier) {
      case DistributionCenterTier.grandDc:
        return 'Grand DC';
      case DistributionCenterTier.hubDc:
        return 'Hub Distribution Center';
      case DistributionCenterTier.generalDc:
        return 'General Distribution Center';
    }
  }

  String get tierBadge {
    switch (dcTier) {
      case DistributionCenterTier.grandDc:
        return '[Grand DC - Central]';
      case DistributionCenterTier.hubDc:
        return '[Hub DC]';
      case DistributionCenterTier.generalDc:
        return '[General DC]';
    }
  }

  bool get isGrand => isGrandDc;
  bool get isHubDc => isHub && !isGrandDc;
  bool get isGeneralDc => !isGrandDc && !isHub;
  bool get isPrimaryHub => isHub || isGrandDc;
  bool get isGrandHeadquarters => isGrandDc;
  String get fullLocation => '$city, $state';
  List<String> get coveredLgas => operatingZones;
  String get displayCapacity => '${storageCapacityUnits.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} Units';

  bool coversLga(String rawLga) {
    if (operatingZones.isEmpty) return true;
    final target = rawLga.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (target.isEmpty) return true;
    return operatingZones.any((zone) {
      final z = zone.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      return z == target || target.contains(z) || z.contains(target);
    });
  }

  bool coversLocation({required String stateName, required String lgaName}) {
    // Canonical State normalization
    final normSelf = LocationLookupService.normalizeStateName(state).trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final normTarget = LocationLookupService.normalizeStateName(stateName).trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    final stateMatches = normSelf == normTarget ||
        normSelf.contains(normTarget) ||
        normTarget.contains(normSelf);

    if (!stateMatches) return false;
    if (lgaName.trim().isEmpty) return true;
    return coversLga(lgaName);
  }

  DistributionCenter copyWith({
    String? id,
    String? companyId,
    String? name,
    String? code,
    String? state,
    String? city,
    String? address,
    String? contactPhone,
    String? contactEmail,
    String? managerName,
    bool? isGrandDc,
    bool? isHub,
    bool? isActive,
    String? parentDcId,
    List<String>? operatingZones,
    int? storageCapacityUnits,
    int? totalAssignedRiders,
    int? activeInventoryBatches,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DistributionCenter(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      code: code ?? this.code,
      state: state ?? this.state,
      city: city ?? this.city,
      address: address ?? this.address,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      managerName: managerName ?? this.managerName,
      isGrandDc: isGrandDc ?? this.isGrandDc,
      isHub: isHub ?? this.isHub,
      isActive: isActive ?? this.isActive,
      parentDcId: parentDcId ?? this.parentDcId,
      operatingZones: operatingZones ?? this.operatingZones,
      storageCapacityUnits: storageCapacityUnits ?? this.storageCapacityUnits,
      totalAssignedRiders: totalAssignedRiders ?? this.totalAssignedRiders,
      activeInventoryBatches: activeInventoryBatches ?? this.activeInventoryBatches,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory DistributionCenter.fromJson(Map<String, dynamic> json) {
    List<String> parseZones(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      if (raw is String) {
        if (raw.startsWith('[') && raw.endsWith(']')) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is List) {
              return decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
            }
          } catch (_) {}
        }
        return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      return [];
    }

    final codeStr = json['code']?.toString() ?? 'DC-001';
    final rawType = json['dc_type']?.toString().toLowerCase() ?? json['dcType']?.toString().toLowerCase() ?? '';
    final isGrand = json['is_grand_dc'] == true ||
        json['isGrandDc'] == true ||
        rawType == 'grand_dc' ||
        rawType.contains('grand') ||
        codeStr == 'DC-ABJ-01' ||
        codeStr == 'DC-WUSE-01' ||
        json['id'] == '22222222-2222-4222-8222-222222222222';

    final nameLower = (json['name']?.toString() ?? '').toLowerCase();
    final isHub = isGrand ||
        json['is_hub'] == true ||
        json['isHub'] == true ||
        rawType == 'hub_dc' ||
        rawType.contains('hub') ||
        nameLower.contains('hub') ||
        codeStr == 'DC-KD-001' ||
        json['id'] == '00000000-0000-4000-8000-789382566045';

    return DistributionCenter(
      id: json['id']?.toString() ?? '',
      companyId: json['company_id']?.toString() ?? json['companyId']?.toString() ?? '11111111-1111-4111-8111-111111111111',
      name: json['name']?.toString() ?? 'Distribution Center',
      code: codeStr,
      state: json['state']?.toString() ?? 'Abuja FCT',
      city: json['city']?.toString() ?? 'Abuja',
      address: json['address']?.toString() ?? 'Warehouse Address',
      contactPhone: json['contact_phone']?.toString() ?? json['contactPhone']?.toString(),
      contactEmail: json['contact_email']?.toString() ?? json['contactEmail']?.toString(),
      managerName: json['manager_name']?.toString() ?? json['managerName']?.toString(),
      isGrandDc: isGrand,
      isHub: isHub,
      isActive: json['is_active'] != false && json['isActive'] != false,
      parentDcId: json['parent_dc_id']?.toString() ?? json['parentDcId']?.toString(),
      operatingZones: parseZones(json['operating_zones'] ?? json['operatingZones'] ?? json['zones'] ?? json['covered_lgas']),
      storageCapacityUnits: (json['storage_capacity_units'] as num?)?.toInt() ?? (json['storageCapacityUnits'] as num?)?.toInt() ?? 25000,
      totalAssignedRiders: (json['total_assigned_riders'] as num?)?.toInt() ?? (json['totalAssignedRiders'] as num?)?.toInt() ?? 0,
      activeInventoryBatches: (json['active_inventory_batches'] as num?)?.toInt() ?? (json['activeInventoryBatches'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : (json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now() : DateTime.now()),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now() : (json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now() : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'name': name,
      'code': code,
      'state': state,
      'city': city,
      'address': address,
      'contact_phone': contactPhone,
      'contact_email': contactEmail,
      'manager_name': managerName,
      'is_grand_dc': isGrandDc,
      'is_hub': isHub,
      'dc_type': isGrandDc ? 'grand_dc' : (isHub ? 'hub_dc' : 'general_dc'),
      'is_active': isActive,
      'parent_dc_id': parentDcId,
      'operating_zones': operatingZones,
      'storage_capacity_units': storageCapacityUnits,
      'total_assigned_riders': totalAssignedRiders,
      'active_inventory_batches': activeInventoryBatches,
      'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }
}
