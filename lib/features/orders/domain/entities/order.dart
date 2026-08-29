class OrderEntity {
  final String id;
  final String orderNumber;
  final String customerName;
  final String customerPhone;
  final String? customerAltPhone;
  final String deliveryState;
  final String deliveryCity;
  final String deliveryAddress;
  final String? landmark;
  final String? lga;
  final String productName;
  final String status;
  final int quantity;
  final int paidQuantity;
  final int freeQuantity;
  final double basePrice;
  final double upsellAmount;
  final double totalAmount;
  final String paymentType; // 'pay_on_delivery' | 'prepaid'
  final String paymentStatus;
  final String fulfillmentType; // 'distributed_inventory' | 'client_package'
  final String? clientId; // e.g. 'cli-novacale-001'
  final String clientName; // e.g. 'Dr. Chuka Okafor'
  final String clientCompany; // e.g. 'Novacale Limited'
  final String? clientPhone;
  final String? clientEmail;
  final String? packageDealId; // e.g. 'pkg-alpha-02'
  final String? packageDealName; // e.g. 'Triple Treatment Pack (2 + 1 Free)'
  final String? packageCustodyId;
  final double clientDeliveryFee; // e.g. 5000.0
  final double agentEntitlement; // e.g. 2500.0
  final String? deliveryNotes;
  final String? deliveryAgentId;
  final String? deliveryAgentName;
  final String? deliveryAgentCode;
  final String? distributionCenterId;
  final double? latitude;
  final double? longitude;
  final String? geocodingStatus; // 'exact_verified', 'rooftop', 'landmark_match', 'locality_fallback', 'pending'
  final String? geocodedAddress;
  final String? locationConfidence; // 'high', 'medium', 'low', 'unresolved'
  final String? customerSignatureUrl;
  final String? photoProofUrl;
  final String? gatePassCode;
  final bool isLocationVerified;
  final String? failureReason;
  final String remittanceStatus; // 'cleared', 'unremitted', 'pending_verification', 'direct_transfer', 'prepaid'
  final String financialSettlementStatus; // 'pending_remittance', 'direct_transfer_settled', 'cash_remitted_verified'
  final String? remittanceReference;
  final DateTime? remittedAt;
  final DateTime? assignedAt;
  final DateTime? deliveredAt;
  final double transportFee;
  final String? productSku;
  final String? binLocation;
  final String? batchNumber;
  final String? deliveryAgentPhone;
  final DateTime createdAt;

  const OrderEntity({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.customerPhone,
    this.customerAltPhone,
    required this.deliveryState,
    required this.deliveryCity,
    required this.deliveryAddress,
    this.landmark,
    this.lga,
    this.productName = 'Respira Detox Tea',
    required this.status,
    required this.quantity,
    this.paidQuantity = 1,
    this.freeQuantity = 0,
    required this.basePrice,
    required this.upsellAmount,
    required this.totalAmount,
    required this.paymentType,
    required this.paymentStatus,
    this.fulfillmentType = 'distributed_inventory',
    this.clientId,
    this.clientName = 'Novacale Limited',
    this.clientCompany = 'Novacale Limited',
    this.clientPhone,
    this.clientEmail,
    this.packageDealId,
    this.packageDealName,
    this.packageCustodyId,
    this.clientDeliveryFee = 5000.0,
    this.agentEntitlement = 2500.0,
    this.deliveryNotes,
    this.deliveryAgentId,
    this.deliveryAgentName,
    this.deliveryAgentCode,
    this.deliveryAgentPhone,
    this.distributionCenterId,
    this.latitude,
    this.longitude,
    this.geocodingStatus,
    this.geocodedAddress,
    this.locationConfidence,
    this.customerSignatureUrl,
    this.photoProofUrl,
    this.gatePassCode,
    this.isLocationVerified = false,
    this.failureReason,
    this.remittanceStatus = 'unremitted',
    this.financialSettlementStatus = 'pending_remittance',
    this.remittanceReference,
    this.remittedAt,
    this.assignedAt,
    this.deliveredAt,
    this.transportFee = 1500.0,
    this.productSku,
    this.binLocation,
    this.batchNumber,
    required this.createdAt,
  });

  bool get isDirectTransfer {
    final pt = paymentType.toLowerCase();
    if (pt == 'pay_on_delivery' ||
        pt == 'pod' ||
        pt == 'cash' ||
        pt == 'cod' ||
        pt == 'cash_pod' ||
        pt == 'cash_on_delivery' ||
        pt == 'pay_on_pickup') {
      return false;
    }
    if (pt == 'paystack' ||
        pt == 'direct_transfer' ||
        pt == 'bank_transfer' ||
        pt == 'prepaid' ||
        pt == 'monnify') {
      return true;
    }
    if (deliveryNotes != null) {
      final n = deliveryNotes!.toLowerCase();
      if (n.contains('paystack') ||
          n.contains('direct transfer') ||
          n.contains('monnify direct transfer') ||
          n.contains('transfer verified') ||
          n.contains('credited to my balance')) {
        return true;
      }
    }
    final ps = paymentStatus.toLowerCase();
    if (ps == 'transfer_verified' ||
        ps == 'direct_transfer' ||
        ps == 'paid_direct') {
      return true;
    }
    return false;
  }

  bool get isPod {
    if (isDirectTransfer) return false;
    final pt = paymentType.toLowerCase();
    return pt == 'pay_on_delivery' ||
        pt == 'pod' ||
        pt == 'cash' ||
        pt == 'cod' ||
        pt == 'cash_pod' ||
        pt == 'cash_on_delivery' ||
        pt == 'pay_on_pickup' ||
        pt == 'collected' ||
        pt.isEmpty;
  }

  bool get isCashPod => isPod;
  bool get isClientPackage => fulfillmentType == 'client_package';
  bool get isDistributedInventory => fulfillmentType == 'distributed_inventory';
  bool get isDelivered => status.toLowerCase() == 'delivered' || status.toLowerCase() == 'completed';
  bool get isFailed => status.toLowerCase() == 'failed' || status.toLowerCase() == 'failed_attempt' || status.toLowerCase() == 'call_back' || status.toLowerCase() == 'cancelled';
  bool get isCancelled => status.toLowerCase() == 'cancelled';
  bool get isUnassigned => deliveryAgentId == null || deliveryAgentId!.isEmpty;
  bool get isAssignedInTransit => !isUnassigned && !isDelivered && !isFailed;

  bool get isRemitted {
    if (isDirectTransfer) return true;
    final rs = remittanceStatus.toLowerCase();
    return rs == 'cleared' || rs == 'remitted';
  }

  bool get isUnremitted {
    if (!isDelivered) return false;
    if (isDirectTransfer) return false;
    final rs = remittanceStatus.toLowerCase();
    return rs == 'unremitted' || rs == 'pending' || rs.isEmpty;
  }

  bool get isPendingVerification {
    return remittanceStatus.toLowerCase() == 'pending_verification';
  }

  double get netMerchantSettlement {
    final net = totalAmount - agentEntitlement - transportFee;
    return net > 0 ? net : 0.0;
  }

  int get totalPhysicalQuantity => paidQuantity + freeQuantity > 0 ? paidQuantity + freeQuantity : quantity;
  bool get hasCoordinates => latitude != null && longitude != null && latitude != 0.0 && longitude != 0.0;
  bool get hasSignature => customerSignatureUrl != null && customerSignatureUrl!.isNotEmpty;
  bool get hasPhotoProof => photoProofUrl != null && photoProofUrl!.isNotEmpty;

  /// Returns the explicit or deterministic audit Gate PIN for this order
  String get effectiveGatePin {
    if (gatePassCode != null && gatePassCode!.trim().isNotEmpty) {
      return gatePassCode!.trim().toUpperCase();
    }
    if (deliveryNotes != null) {
      final pinMatch = RegExp(r'\[(?:Audit\s+)?Gate\s+PIN:\s*([A-Z0-9-]+)\]', caseSensitive: false).firstMatch(deliveryNotes!);
      if (pinMatch != null && pinMatch.group(1) != null) {
        return pinMatch.group(1)!.trim().toUpperCase();
      }
    }
    final cleanNo = orderNumber.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
    final suffix = cleanNo.length >= 4 ? cleanNo.substring(cleanNo.length - 4) : '7182';
    return 'GT-$suffix';
  }

  String get coordinatesFormatted => hasCoordinates
      ? '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'
      : 'Not Geocoded';

  /// Returns the extracted GPS proof string or coordinates showing physical presence
  String? get loggedGpsProof {
    if (deliveryNotes != null) {
      final gpsMatch = RegExp(r'\[(?:Audit\s+)?GPS(?:\s+Proof)?:\s*([^\]]+)\]', caseSensitive: false).firstMatch(deliveryNotes!);
      if (gpsMatch != null && gpsMatch.group(1) != null) {
        return gpsMatch.group(1)!.trim();
      }
    }
    if (hasCoordinates) {
      return '${latitude!.toStringAsFixed(5)}°, ${longitude!.toStringAsFixed(5)}°';
    }
    return null;
  }

  String get presenceProofSummary {
    if (hasCoordinates) {
      return 'GPS: ${latitude!.toStringAsFixed(5)}°, ${longitude!.toStringAsFixed(5)}° (Presence Verified)';
    }
    if (loggedGpsProof != null) {
      return 'GPS Proof: $loggedGpsProof';
    }
    return 'Location Pending';
  }

  String get confidenceDisplay {
    if (isLocationVerified) return 'Verified Gate PIN ($effectiveGatePin)';
    switch (locationConfidence?.toLowerCase()) {
      case 'high':
        return 'High Accuracy PIN';
      case 'medium':
        return 'Landmark Approx';
      case 'low':
        return 'Area Centroid (Needs PIN)';
      default:
        return hasCoordinates ? 'Approximate GPS' : 'Address Pending';
    }
  }

  /// Generates the deep-link navigation URI for Google Maps Turn-by-Turn GPS.
  Uri get googleMapsNavUri {
    if (hasCoordinates) {
      return Uri.parse('google.navigation:q=$latitude,$longitude&mode=d');
    }
    final fullSearch = '$deliveryAddress, $deliveryCity, $deliveryState, Nigeria';
    final encoded = Uri.encodeComponent(fullSearch);
    return Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
  }

  /// Generates web/universal directions URI for fallback.
  Uri get googleMapsWebDirectionsUri {
    if (hasCoordinates) {
      return Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving');
    }
    final fullSearch = '$deliveryAddress, $deliveryCity, $deliveryState, Nigeria';
    final encoded = Uri.encodeComponent(fullSearch);
    return Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$encoded');
  }

  /// Formats clean international Nigerian phone number (234...) for WhatsApp wa.me links
  String get formattedWhatsAppPhone {
    String clean = customerPhone.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.startsWith('+234')) {
      return clean.substring(1);
    } else if (clean.startsWith('234')) {
      return clean;
    } else if (clean.startsWith('0')) {
      return '234${clean.substring(1)}';
    }
    return clean.replaceAll('+', '');
  }

  /// Generates the prefilled message body requesting customer live location pin
  String getWhatsAppLocationRequestText({String? riderName}) {
    final name = riderName != null && riderName.isNotEmpty ? riderName : 'your NovaExpress Dispatcher';
    return '''Hello ${customerName.trim()}, this is $name from NovaExpress Logistics regarding your order ($orderNumber - $productName) 📦.

I am currently en route / preparing your delivery to:
"${deliveryAddress.trim()}".

Kindly tap the "📎" attach button below and share your *Current Location / Live Pin* on WhatsApp so I can navigate straight to your gate without delay. Thank you! 🙏''';
  }

  /// Generates the direct native whatsapp:// application URI (bypasses 3rd party web interceptors)
  Uri getWhatsAppNativeAppUri({String? riderName}) {
    final message = getWhatsAppLocationRequestText(riderName: riderName);
    final encodedMsg = Uri.encodeComponent(message);
    final phone = formattedWhatsAppPhone;
    return Uri.parse('whatsapp://send?phone=$phone&text=$encodedMsg');
  }

  /// Generates the web wa.me URI requesting the customer to send their live location pin
  Uri getWhatsAppLocationRequestUri({String? riderName}) {
    final message = getWhatsAppLocationRequestText(riderName: riderName);
    final encodedMsg = Uri.encodeComponent(message);
    final phone = formattedWhatsAppPhone;
    return Uri.parse('https://wa.me/$phone?text=$encodedMsg');
  }

  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'in_transit':
        return 'In Transit';
      case 'accepted':
        return 'Accepted';
      case 'delivered':
        return 'Delivered';
      case 'failed':
        return 'Failed';
      case 'call_back':
        return 'Call Back';
      case 'new':
      case 'pending':
        return 'Pending';
      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }

  bool get isFullySettledToCompany {
    if (isDirectTransfer) return true;
    if (isDelivered && (remittanceStatus.toLowerCase() == 'cleared' || financialSettlementStatus == 'cash_remitted_verified')) {
      return true;
    }
    return false;
  }

  bool get isPendingRemittance {
    return isDelivered && !isFullySettledToCompany;
  }

  OrderEntity copyWith({
    String? id,
    String? orderNumber,
    String? customerName,
    String? customerPhone,
    String? customerAltPhone,
    String? deliveryState,
    String? deliveryCity,
    String? deliveryAddress,
    String? landmark,
    String? lga,
    String? productName,
    String? status,
    int? quantity,
    int? paidQuantity,
    int? freeQuantity,
    double? basePrice,
    double? upsellAmount,
    double? totalAmount,
    String? paymentType,
    String? paymentStatus,
    String? fulfillmentType,
    String? clientId,
    String? clientName,
    String? clientCompany,
    String? clientPhone,
    String? clientEmail,
    String? packageDealId,
    String? packageDealName,
    String? packageCustodyId,
    double? clientDeliveryFee,
    double? agentEntitlement,
    String? deliveryNotes,
    String? deliveryAgentId,
    String? deliveryAgentName,
    String? deliveryAgentCode,
    String? deliveryAgentPhone,
    String? distributionCenterId,
    double? latitude,
    double? longitude,
    String? geocodingStatus,
    String? geocodedAddress,
    String? locationConfidence,
    String? customerSignatureUrl,
    String? photoProofUrl,
    String? gatePassCode,
    bool? isLocationVerified,
    String? failureReason,
    String? remittanceStatus,
    String? financialSettlementStatus,
    String? remittanceReference,
    DateTime? remittedAt,
    DateTime? assignedAt,
    DateTime? deliveredAt,
    double? transportFee,
    String? productSku,
    String? binLocation,
    String? batchNumber,
    DateTime? createdAt,
  }) {
    return OrderEntity(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAltPhone: customerAltPhone ?? this.customerAltPhone,
      deliveryState: deliveryState ?? this.deliveryState,
      deliveryCity: deliveryCity ?? this.deliveryCity,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      landmark: landmark ?? this.landmark,
      lga: lga ?? this.lga,
      productName: productName ?? this.productName,
      status: status ?? this.status,
      quantity: quantity ?? this.quantity,
      paidQuantity: paidQuantity ?? this.paidQuantity,
      freeQuantity: freeQuantity ?? this.freeQuantity,
      basePrice: basePrice ?? this.basePrice,
      upsellAmount: upsellAmount ?? this.upsellAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentType: paymentType ?? this.paymentType,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      fulfillmentType: fulfillmentType ?? this.fulfillmentType,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientCompany: clientCompany ?? this.clientCompany,
      clientPhone: clientPhone ?? this.clientPhone,
      clientEmail: clientEmail ?? this.clientEmail,
      packageDealId: packageDealId ?? this.packageDealId,
      packageDealName: packageDealName ?? this.packageDealName,
      packageCustodyId: packageCustodyId ?? this.packageCustodyId,
      clientDeliveryFee: clientDeliveryFee ?? this.clientDeliveryFee,
      agentEntitlement: agentEntitlement ?? this.agentEntitlement,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      deliveryAgentId: deliveryAgentId ?? this.deliveryAgentId,
      deliveryAgentName: deliveryAgentName ?? this.deliveryAgentName,
      deliveryAgentCode: deliveryAgentCode ?? this.deliveryAgentCode,
      deliveryAgentPhone: deliveryAgentPhone ?? this.deliveryAgentPhone,
      distributionCenterId: distributionCenterId ?? this.distributionCenterId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      geocodingStatus: geocodingStatus ?? this.geocodingStatus,
      geocodedAddress: geocodedAddress ?? this.geocodedAddress,
      locationConfidence: locationConfidence ?? this.locationConfidence,
      customerSignatureUrl: customerSignatureUrl ?? this.customerSignatureUrl,
      photoProofUrl: photoProofUrl ?? this.photoProofUrl,
      gatePassCode: gatePassCode ?? this.gatePassCode,
      isLocationVerified: isLocationVerified ?? this.isLocationVerified,
      failureReason: failureReason ?? this.failureReason,
      remittanceStatus: remittanceStatus ?? this.remittanceStatus,
      financialSettlementStatus: financialSettlementStatus ?? this.financialSettlementStatus,
      remittanceReference: remittanceReference ?? this.remittanceReference,
      remittedAt: remittedAt ?? this.remittedAt,
      assignedAt: assignedAt ?? this.assignedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      transportFee: transportFee ?? this.transportFee,
      productSku: productSku ?? this.productSku,
      binLocation: binLocation ?? this.binLocation,
      batchNumber: batchNumber ?? this.batchNumber,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

