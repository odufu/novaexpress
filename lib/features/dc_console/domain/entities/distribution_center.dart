import 'dart:convert';
import 'package:novexps/core/services/location_lookup_service.dart';

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
  final bool isHub;
  final bool isActive;
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
    this.isHub = false,
    this.isActive = true,
    this.operatingZones = const [],
    this.storageCapacityUnits = 25000,
    this.totalAssignedRiders = 0,
    this.activeInventoryBatches = 0,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPrimaryHub => isHub;
  String get fullLocation => '$city, $state';
  List<String> get coveredLgas => operatingZones;
  String get displayCapacity => '${storageCapacityUnits.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} Units';

  bool coversLga(String rawLga) {
    if (operatingZones.isEmpty) return true;
    final target = rawLga.trim().toLowerCase();
    if (target.isEmpty) return true;
    return operatingZones.any((zone) {
      final z = zone.trim().toLowerCase();
      return z == target || target.contains(z) || z.contains(target);
    });
  }

  bool coversLocation({required String stateName, required String lgaName}) {
    // Canonical State normalization
    final normSelf = LocationLookupService.normalizeStateName(state).trim().toLowerCase();
    final normTarget = LocationLookupService.normalizeStateName(stateName).trim().toLowerCase();

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
    bool? isHub,
    bool? isActive,
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
      isHub: isHub ?? this.isHub,
      isActive: isActive ?? this.isActive,
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

    return DistributionCenter(
      id: json['id']?.toString() ?? '',
      companyId: json['company_id']?.toString() ?? json['companyId']?.toString() ?? '11111111-1111-4111-8111-111111111111',
      name: json['name']?.toString() ?? 'Distribution Center',
      code: json['code']?.toString() ?? 'DC-001',
      state: json['state']?.toString() ?? 'Abuja FCT',
      city: json['city']?.toString() ?? 'Abuja',
      address: json['address']?.toString() ?? 'Warehouse Address',
      contactPhone: json['contact_phone']?.toString() ?? json['contactPhone']?.toString(),
      contactEmail: json['contact_email']?.toString() ?? json['contactEmail']?.toString(),
      managerName: json['manager_name']?.toString() ?? json['managerName']?.toString(),
      isHub: json['is_hub'] == true || json['isHub'] == true,
      isActive: json['is_active'] != false && json['isActive'] != false,
      operatingZones: parseZones(json['operating_zones'] ?? json['operatingZones'] ?? json['zones']),
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
      'is_hub': isHub,
      'is_active': isActive,
      'operating_zones': operatingZones,
      'storage_capacity_units': storageCapacityUnits,
      'total_assigned_riders': totalAssignedRiders,
      'active_inventory_batches': activeInventoryBatches,
      'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }
}
