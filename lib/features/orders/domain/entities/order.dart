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
  final String clientName; // e.g. 'NovaCare'
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
  final bool isLocationVerified;
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
    this.clientName = 'NovaCare',
    this.packageCustodyId,
    this.clientDeliveryFee = 5000.0,
    this.agentEntitlement = 2500.0,
    this.deliveryNotes,
    this.deliveryAgentId,
    this.deliveryAgentName,
    this.deliveryAgentCode,
    this.distributionCenterId,
    this.latitude,
    this.longitude,
    this.geocodingStatus,
    this.geocodedAddress,
    this.locationConfidence,
    this.isLocationVerified = false,
    required this.createdAt,
  });

  bool get isDirectTransfer {
    final pt = paymentType.toLowerCase();
    if (pt == 'prepaid' || pt == 'direct_transfer' || pt == 'bank_transfer' || pt == 'monnify') {
      return true;
    }
    if (deliveryNotes != null) {
      final n = deliveryNotes!.toLowerCase();
      if (n.contains('monnify') ||
          n.contains('direct transfer') ||
          n.contains('bank transfer') ||
          n.contains('bank_transfer') ||
          n.contains('credited to my balance')) {
        return true;
      }
    }
    final ps = paymentStatus.toLowerCase();
    if (ps == 'transfer_verified' || ps == 'direct_transfer' || ps == 'paid_direct') {
      return true;
    }
    return false;
  }

  bool get isPod => (paymentType == 'pay_on_delivery' || paymentType == 'pod') && !isDirectTransfer;
  bool get isCashPod => (paymentType == 'pay_on_delivery' || paymentType == 'pod') && !isDirectTransfer;
  bool get isClientPackage => fulfillmentType == 'client_package';
  bool get isDistributedInventory => fulfillmentType == 'distributed_inventory';
  bool get isDelivered => status == 'delivered';
  int get totalPhysicalQuantity => paidQuantity + freeQuantity > 0 ? paidQuantity + freeQuantity : quantity;
  bool get hasCoordinates => latitude != null && longitude != null && latitude != 0.0 && longitude != 0.0;

  String get coordinatesFormatted => hasCoordinates
      ? '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'
      : 'Not Geocoded';

  String get confidenceDisplay {
    if (isLocationVerified) return 'Verified Gate PIN';
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
}

