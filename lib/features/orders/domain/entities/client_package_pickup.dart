import 'package:flutter/foundation.dart';

@immutable
class ClientPackagePickupEntity {
  final String id;
  final String orderId;
  final int stopSequence;
  final String stopLabel;
  final String locationId;
  final String locationName;
  final String pickupAddress;
  final String city;
  final String state;
  final String? lga;
  final String? landmark;
  final double? latitude;
  final double? longitude;
  final String contactPerson;
  final String contactPhone;
  final String? contactWhatsapp;
  final List<dynamic> itemsToCollect;
  final String sealedBagRef;
  final String? scannedBagRef;
  final String status; // 'pending', 'rider_assigned', 'rider_arrived', 'bag_verified_collected', 'exception_failed'
  final String? failureReason;
  final DateTime? collectedAt;
  final DateTime createdAt;

  const ClientPackagePickupEntity({
    required this.id,
    required this.orderId,
    required this.stopSequence,
    required this.stopLabel,
    required this.locationId,
    required this.locationName,
    required this.pickupAddress,
    required this.city,
    required this.state,
    this.lga,
    this.landmark,
    this.latitude,
    this.longitude,
    required this.contactPerson,
    required this.contactPhone,
    this.contactWhatsapp,
    this.itemsToCollect = const [],
    required this.sealedBagRef,
    this.scannedBagRef,
    required this.status,
    this.failureReason,
    this.collectedAt,
    required this.createdAt,
  });

  bool get isCollected => status == 'bag_verified_collected';

  factory ClientPackagePickupEntity.fromMap(Map<String, dynamic> map) {
    return ClientPackagePickupEntity(
      id: map['id']?.toString() ?? '',
      orderId: map['order_id']?.toString() ?? '',
      stopSequence: (map['stop_sequence'] is num) ? (map['stop_sequence'] as num).toInt() : 1,
      stopLabel: map['stop_label']?.toString() ?? 'Pickup Stop',
      locationId: map['location_id']?.toString() ?? '',
      locationName: map['location_name']?.toString() ?? 'Pharmacy / Shop',
      pickupAddress: map['pickup_address']?.toString() ?? '',
      city: map['city']?.toString() ?? 'Abuja',
      state: map['state']?.toString() ?? 'Federal Capital Territory',
      lga: map['lga']?.toString(),
      landmark: map['landmark']?.toString(),
      latitude: (map['latitude'] is num) ? (map['latitude'] as num).toDouble() : null,
      longitude: (map['longitude'] is num) ? (map['longitude'] as num).toDouble() : null,
      contactPerson: map['contact_person']?.toString() ?? 'Contact Person',
      contactPhone: map['contact_phone']?.toString() ?? '',
      contactWhatsapp: map['contact_whatsapp']?.toString(),
      itemsToCollect: map['items_to_collect'] is List ? map['items_to_collect'] as List : [],
      sealedBagRef: map['sealed_bag_ref']?.toString() ?? '',
      scannedBagRef: map['scanned_bag_ref']?.toString(),
      status: map['status']?.toString() ?? 'pending',
      failureReason: map['failure_reason']?.toString(),
      collectedAt: map['collected_at'] != null ? DateTime.tryParse(map['collected_at'].toString()) : null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
