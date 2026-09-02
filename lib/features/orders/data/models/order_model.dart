import '../../domain/entities/order.dart';

class OrderModel extends OrderEntity {
  const OrderModel({
    required super.id,
    required super.orderNumber,
    required super.customerName,
    required super.customerPhone,
    super.customerAltPhone,
    required super.deliveryState,
    required super.deliveryCity,
    required super.deliveryAddress,
    super.landmark,
    super.lga,
    super.productName,
    required super.status,
    required super.quantity,
    super.paidQuantity,
    super.freeQuantity,
    required super.basePrice,
    required super.upsellAmount,
    required super.totalAmount,
    required super.paymentType,
    required super.paymentStatus,
    super.fulfillmentType,
    super.clientId,
    super.clientName,
    super.clientCompany,
    super.clientPhone,
    super.clientEmail,
    super.packageDealId,
    super.packageDealName,
    super.packageCustodyId,
    super.clientDeliveryFee,
    super.agentEntitlement,
    super.deliveryNotes,
    super.deliveryAgentId,
    super.deliveryAgentName,
    super.deliveryAgentCode,
    super.deliveryAgentPhone,
    super.distributionCenterId,
    super.latitude,
    super.longitude,
    super.geocodingStatus,
    super.geocodedAddress,
    super.locationConfidence,
    super.customerSignatureUrl,
    super.photoProofUrl,
    super.gatePassCode,
    super.isLocationVerified = false,
    super.failureReason,
    super.remittanceStatus = 'unremitted',
    super.financialSettlementStatus = 'pending_remittance',
    super.remittanceReference,
    super.remittedAt,
    super.assignedAt,
    super.deliveredAt,
    super.transportFee = 1500.0,
    super.productSku,
    super.binLocation,
    super.batchNumber,
    super.closerId,
    super.closerName,
    super.closerCode,
    super.leadId,
    required super.createdAt,
  });

  factory OrderModel.empty() => OrderModel(
        id: '',
        orderNumber: '',
        customerName: '',
        customerPhone: '',
        deliveryState: '',
        deliveryCity: '',
        deliveryAddress: '',
        productName: '',
        status: 'pending',
        quantity: 0,
        basePrice: 0,
        upsellAmount: 0,
        totalAmount: 0,
        paymentType: 'cod',
        paymentStatus: 'pending',
        createdAt: DateTime.now(),
      );

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawProduct = json['products'];
    String name = 'Respira Detox Tea';
    String? sku = json['sku']?.toString() ?? json['product_sku']?.toString();
    if (rawProduct is Map) {
      if (rawProduct['name'] != null) name = rawProduct['name'].toString();
      if (rawProduct['sku'] != null) sku = rawProduct['sku'].toString();
    } else if (json['product_name'] != null) {
      name = json['product_name'].toString();
    }

    final notes = json['delivery_notes']?.toString() ?? '';
    String fulfillment = json['fulfillment_type'] ?? 'distributed_inventory';
    if (notes.contains('Client Package')) {
      fulfillment = 'client_package';
    }

    int paid = json['paid_quantity'] ?? json['quantity'] ?? 1;
    int free = json['free_quantity'] ?? 0;
    if (notes.contains('5 Paid + 1 Free')) {
      paid = 5;
      free = 1;
    }

    final lat = (json['latitude'] as num?)?.toDouble() ?? (json['lat'] as num?)?.toDouble();
    final lng = (json['longitude'] as num?)?.toDouble() ?? (json['lng'] as num?)?.toDouble();

    final pType = (json['payment_type']?.toString() ?? '').toLowerCase();
    final pStatus = (json['payment_status']?.toString() ?? '').toLowerCase();
    final orderStatus = (json['status']?.toString() ?? '').toLowerCase();

    // Determine smart remittance status
    String rStatus = json['remittance_status']?.toString() ?? '';
    if (rStatus.isEmpty) {
      if (notes.contains('[REMITTED') || pStatus == 'remitted' || pStatus == 'cleared' || pStatus == 'verified') {
        rStatus = 'remitted';
      } else if (orderStatus == 'delivered' || orderStatus == 'completed') {
        if (pType == 'paystack' || pType == 'direct_transfer' || pType == 'prepaid' || pStatus == 'transfer_verified') {
          rStatus = 'direct_transfer';
        } else {
          rStatus = 'unremitted';
        }
      } else {
        rStatus = 'unremitted';
      }
    }

    // Determine failure reason if any
    String? failReason = json['failure_reason']?.toString();
    final st = (json['status']?.toString() ?? '').toLowerCase();
    if (failReason == null && (st == 'failed' || st == 'call_back' || st == 'cancelled')) {
      if (notes.isNotEmpty && !notes.toLowerCase().contains('intake completed')) {
        failReason = notes;
      } else {
        failReason = st == 'call_back' ? 'Customer requested callback / reschedule' : 'Customer phone unreachable / switched off';
      }
    }

    DateTime? assignedDate;
    if (json['assigned_at'] != null) {
      assignedDate = DateTime.tryParse(json['assigned_at'].toString());
    } else if (json['delivery_agent_id'] != null) {
      assignedDate = json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null;
    }

    DateTime? deliveredDate;
    if (json['delivered_at'] != null) {
      deliveredDate = DateTime.tryParse(json['delivered_at'].toString());
    } else if (st == 'delivered') {
      deliveredDate = json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : DateTime.now();
    }

    DateTime? remittedDate;
    if (json['remitted_at'] != null) {
      remittedDate = DateTime.tryParse(json['remitted_at'].toString());
    } else if (rStatus == 'cleared' || rStatus == 'remitted') {
      remittedDate = deliveredDate ?? DateTime.now();
    }

    // Determine financial settlement status
    String fStatus = json['financial_settlement_status']?.toString() ?? '';
    if (fStatus.isEmpty) {
      if (rStatus == 'direct_transfer' || pType == 'paystack' || pType == 'direct_transfer') {
        fStatus = 'direct_transfer_settled';
      } else if (rStatus == 'cleared' || rStatus == 'remitted' || notes.contains('[REMITTED')) {
        fStatus = 'cash_remitted_verified';
      } else {
        fStatus = 'pending_remittance';
      }
    }

    String? gateCode = json['gate_pass_code']?.toString() ?? json['gate_pin']?.toString();
    if (gateCode == null && notes.isNotEmpty) {
      final pinMatch = RegExp(r'\[(?:Audit\s+)?Gate\s+PIN:\s*([A-Z0-9-]+)\]', caseSensitive: false).firstMatch(notes);
      if (pinMatch != null) gateCode = pinMatch.group(1);
    }

    final sigUrl = json['customer_signature_url']?.toString() ??
        json['proof_of_delivery_url']?.toString() ??
        json['signature_url']?.toString();

    return OrderModel(
      id: json['id'] ?? '',
      orderNumber: json['order_number'] ?? '',
      customerName: json['customer_name'] ?? 'Customer',
      customerPhone: json['customer_phone'] ?? '',
      customerAltPhone: json['customer_alt_phone'],
      deliveryState: json['delivery_state'] ?? '',
      deliveryCity: json['delivery_city'] ?? '',
      deliveryAddress: json['delivery_address'] ?? '',
      landmark: json['landmark'],
      lga: json['lga'],
      productName: name,
      status: (json['status'] == 'new' || json['status'] == 'unassigned') ? 'pending' : (json['status'] ?? 'pending'),
      quantity: json['quantity'] ?? 1,
      paidQuantity: paid,
      freeQuantity: free,
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0.0,
      upsellAmount: (json['upsell_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      paymentType: json['payment_type'] ?? 'pay_on_delivery',
      paymentStatus: json['payment_status'] ?? 'pending',
      fulfillmentType: fulfillment,
      clientId: json['client_id']?.toString(),
      clientName: json['client_name'] ?? 'Novacale Limited',
      clientCompany: json['client_company'] ?? json['client_name'] ?? 'Novacale Limited',
      clientPhone: json['client_phone']?.toString(),
      clientEmail: json['client_email']?.toString(),
      packageDealId: json['package_deal_id']?.toString(),
      packageDealName: json['package_deal_name']?.toString(),
      packageCustodyId: json['package_custody_id'],
      clientDeliveryFee: (json['client_delivery_fee'] as num?)?.toDouble() ?? 5000.0,
      agentEntitlement: (json['agent_entitlement'] as num?)?.toDouble() ?? 2500.0,
      deliveryNotes: json['delivery_notes'],
      deliveryAgentId: json['delivery_agent_id']?.toString(),
      deliveryAgentName: json['delivery_agent_name']?.toString(),
      deliveryAgentCode: json['delivery_agent_code']?.toString() ?? json['assigned_agent_code']?.toString(),
      deliveryAgentPhone: json['delivery_agent_phone']?.toString(),
      distributionCenterId: json['distribution_center_id']?.toString(),
      latitude: lat,
      longitude: lng,
      geocodingStatus: json['geocoding_status']?.toString(),
      geocodedAddress: json['geocoded_address']?.toString(),
      locationConfidence: json['location_confidence']?.toString() ?? (lat != null && lng != null ? 'high' : null),
      customerSignatureUrl: sigUrl,
      photoProofUrl: json['proof_photo_url']?.toString() ?? json['photo_proof_url']?.toString(),
      gatePassCode: gateCode,
      isLocationVerified: json['is_location_verified'] == true || json['is_location_verified'] == 'true',
      failureReason: failReason,
      remittanceStatus: rStatus,
      financialSettlementStatus: fStatus,
      remittanceReference: json['remittance_reference']?.toString() ?? (rStatus == 'cleared' ? 'RMT-00402' : null),
      remittedAt: remittedDate,
      assignedAt: assignedDate,
      deliveredAt: deliveredDate,
      transportFee: (json['transport_fee'] as num?)?.toDouble() ?? 1500.0,
      productSku: sku ?? 'SKU-RESP-01',
      binLocation: json['bin_location']?.toString() ?? 'BIN-A1-01',
      batchNumber: json['batch_number']?.toString() ?? 'LOT-2026-08',
      closerId: json['closer_id']?.toString(),
      closerName: json['closer_name']?.toString(),
      closerCode: json['closer_code']?.toString(),
      leadId: json['lead_id']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  factory OrderModel.fromEntity(OrderEntity entity) {
    return OrderModel(
      id: entity.id,
      orderNumber: entity.orderNumber,
      customerName: entity.customerName,
      customerPhone: entity.customerPhone,
      customerAltPhone: entity.customerAltPhone,
      deliveryState: entity.deliveryState,
      deliveryCity: entity.deliveryCity,
      deliveryAddress: entity.deliveryAddress,
      landmark: entity.landmark,
      lga: entity.lga,
      productName: entity.productName,
      status: entity.status,
      quantity: entity.quantity,
      paidQuantity: entity.paidQuantity,
      freeQuantity: entity.freeQuantity,
      basePrice: entity.basePrice,
      upsellAmount: entity.upsellAmount,
      totalAmount: entity.totalAmount,
      paymentType: entity.paymentType,
      paymentStatus: entity.paymentStatus,
      fulfillmentType: entity.fulfillmentType,
      clientId: entity.clientId,
      clientName: entity.clientName,
      clientCompany: entity.clientCompany,
      clientPhone: entity.clientPhone,
      clientEmail: entity.clientEmail,
      packageDealId: entity.packageDealId,
      packageDealName: entity.packageDealName,
      packageCustodyId: entity.packageCustodyId,
      clientDeliveryFee: entity.clientDeliveryFee,
      agentEntitlement: entity.agentEntitlement,
      deliveryNotes: entity.deliveryNotes,
      deliveryAgentId: entity.deliveryAgentId,
      deliveryAgentName: entity.deliveryAgentName,
      deliveryAgentCode: entity.deliveryAgentCode,
      deliveryAgentPhone: entity.deliveryAgentPhone,
      distributionCenterId: entity.distributionCenterId,
      latitude: entity.latitude,
      longitude: entity.longitude,
      geocodingStatus: entity.geocodingStatus,
      geocodedAddress: entity.geocodedAddress,
      locationConfidence: entity.locationConfidence,
      customerSignatureUrl: entity.customerSignatureUrl,
      photoProofUrl: entity.photoProofUrl,
      gatePassCode: entity.gatePassCode,
      isLocationVerified: entity.isLocationVerified,
      failureReason: entity.failureReason,
      remittanceStatus: entity.remittanceStatus,
      financialSettlementStatus: entity.financialSettlementStatus,
      remittanceReference: entity.remittanceReference,
      remittedAt: entity.remittedAt,
      assignedAt: entity.assignedAt,
      deliveredAt: entity.deliveredAt,
      transportFee: entity.transportFee,
      productSku: entity.productSku,
      binLocation: entity.binLocation,
      batchNumber: entity.batchNumber,
      closerId: entity.closerId,
      closerName: entity.closerName,
      closerCode: entity.closerCode,
      leadId: entity.leadId,
      createdAt: entity.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_alt_phone': customerAltPhone,
      'delivery_state': deliveryState,
      'delivery_city': deliveryCity,
      'delivery_address': deliveryAddress,
      'landmark': landmark,
      'lga': lga,
      'status': status,
      'quantity': quantity,
      'paid_quantity': paidQuantity,
      'free_quantity': freeQuantity,
      'base_price': basePrice,
      'upsell_amount': upsellAmount,
      'total_amount': totalAmount,
      'payment_type': paymentType,
      'payment_status': paymentStatus,
      'fulfillment_type': fulfillmentType,
      'client_id': clientId,
      'client_name': clientName,
      'client_company': clientCompany,
      'client_phone': clientPhone,
      'client_email': clientEmail,
      'package_deal_id': packageDealId,
      'package_deal_name': packageDealName,
      'delivery_agent_id': deliveryAgentId,
      'delivery_agent_name': deliveryAgentName,
      'delivery_agent_code': deliveryAgentCode,
      'delivery_agent_phone': deliveryAgentPhone,
      'distribution_center_id': distributionCenterId,
      'package_custody_id': packageCustodyId,
      'client_delivery_fee': clientDeliveryFee,
      'agent_entitlement': agentEntitlement,
      'delivery_notes': deliveryNotes,
      'latitude': latitude,
      'longitude': longitude,
      'geocoding_status': geocodingStatus,
      'geocoded_address': geocodedAddress,
      'location_confidence': locationConfidence,
      'customer_signature_url': customerSignatureUrl,
      'proof_photo_url': photoProofUrl,
      'gate_pass_code': gatePassCode,
      'is_location_verified': isLocationVerified,
      'failure_reason': failureReason,
      'remittance_status': remittanceStatus,
      'financial_settlement_status': financialSettlementStatus,
      'remittance_reference': remittanceReference,
      'remitted_at': remittedAt?.toIso8601String(),
      'assigned_at': assignedAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'transport_fee': transportFee,
      'product_sku': productSku,
      'bin_location': binLocation,
      'batch_number': batchNumber,
      'closer_id': closerId,
      'closer_name': closerName,
      'closer_code': closerCode,
      'lead_id': leadId,
    };
  }
}
