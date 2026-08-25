class DCTransactionRecord {
  final String id;
  final String transactionCode;
  final String? orderNumber;
  final String? orderId;
  final String? productName;
  final String? customerName;
  final String? customerPhone;
  final String? deliveryLocation;
  final String riderId;
  final String riderName;
  final String riderCode;
  final double amount;
  final double commission;
  final double transportAllowance;
  final String category; // 'paystack_direct', 'cash_pod', 'remittance', 'payout', 'allowance'
  final String paymentMethod; // 'paystack', 'cash', 'bank_transfer', 'pos'
  final String? gatewayReference;
  final String channel; // 'Titan Trust / Paystack', 'Cash in Hand', 'GTBank NIP', 'POS Terminal'
  final String status; // 'verified', 'collected', 'pending', 'partial', 'disbursed', 'disputed'
  final bool isCredit;
  final bool isPartial;
  final double? expectedAmount;
  final double? discrepancyAmount;
  final String? discrepancyReason;
  final String? notes;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  const DCTransactionRecord({
    required this.id,
    required this.transactionCode,
    this.orderNumber,
    this.orderId,
    this.productName,
    this.customerName,
    this.customerPhone,
    this.deliveryLocation,
    required this.riderId,
    required this.riderName,
    required this.riderCode,
    required this.amount,
    this.commission = 1000.0,
    this.transportAllowance = 1500.0,
    required this.category,
    required this.paymentMethod,
    this.gatewayReference,
    required this.channel,
    required this.status,
    required this.isCredit,
    this.isPartial = false,
    this.expectedAmount,
    this.discrepancyAmount,
    this.discrepancyReason,
    this.notes,
    required this.createdAt,
    this.metadata,
  });

  bool get isPaystack => paymentMethod == 'paystack' || category == 'paystack_direct';
  bool get isCashPod => category == 'cash_pod' || paymentMethod == 'cash';
  bool get isRemittance => category == 'remittance';
  bool get isPayout => category == 'payout';
  bool get isVerified =>
      status == 'verified' || status == 'settled' || status == 'approved' || status == 'complete' || status == 'completed';
  bool get isPending => status == 'pending' || status == 'pending_review' || status == 'submitted';

  bool get isPartialRemittance =>
      isPartial ||
      status.toLowerCase().contains('partial') ||
      (metadata != null && (metadata!['is_partial'] == true || metadata!['isPartial'] == true)) ||
      (notes != null && notes!.toLowerCase().contains('partial')) ||
      (discrepancyAmount != null && discrepancyAmount! < -0.01) ||
      (expectedAmount != null && expectedAmount! > amount && amount > 0);

  bool get isCompleteRemittance =>
      isRemittance && !isPartialRemittance && (isVerified || !isPending);

  double get totalRiderEntitlement => commission + transportAllowance;

  double get remainingShortage {
    if (expectedAmount != null && expectedAmount! > amount) {
      return expectedAmount! - amount;
    }
    if (discrepancyAmount != null && discrepancyAmount! < 0) {
      return discrepancyAmount!.abs();
    }
    return 0.0;
  }

  String get categoryDisplay {
    switch (category.toLowerCase()) {
      case 'paystack_direct':
        return 'Paystack Direct Transfer';
      case 'cash_pod':
        return 'Cash POD Collection';
      case 'remittance':
        return isPartialRemittance ? 'Partial Cash Remittance' : 'Rider Cash Remittance';
      case 'payout':
        return 'Rider Balance Payout';
      case 'allowance':
        return 'Delivery Compensation';
      default:
        return category.toUpperCase();
    }
  }

  factory DCTransactionRecord.fromJson(Map<String, dynamic> json) {
    String rName = json['rider_name']?.toString() ?? 'Joel Rider';
    String rCode = json['rider_code']?.toString() ?? 'PDA-7000';
    String rId = json['delivery_agent_id']?.toString() ?? json['rider_id']?.toString() ?? '';

    if (json['delivery_agents'] is Map) {
      final agentMap = json['delivery_agents'] as Map<String, dynamic>;
      rCode = agentMap['agent_code']?.toString() ?? rCode;
      if (agentMap['users'] is Map) {
        final userMap = agentMap['users'] as Map<String, dynamic>;
        final fName = userMap['first_name']?.toString() ?? '';
        final lName = userMap['last_name']?.toString() ?? '';
        if (fName.isNotEmpty || lName.isNotEmpty) {
          rName = '$fName $lName'.trim();
        }
      }
    }

    String? oNumber = json['order_number']?.toString();
    String? pName = json['product_name']?.toString();
    String? cName = json['customer_name']?.toString();
    String? cPhone = json['customer_phone']?.toString();
    String? dLocation = json['delivery_location']?.toString();

    if (json['orders'] is Map) {
      final orderMap = json['orders'] as Map<String, dynamic>;
      oNumber = orderMap['order_number']?.toString() ?? oNumber;
      cName = orderMap['customer_name']?.toString() ?? cName;
      cPhone = orderMap['customer_phone']?.toString() ?? cPhone;
      dLocation = '${orderMap['delivery_city'] ?? ''}, ${orderMap['delivery_state'] ?? ''}'.trim();
      if (orderMap['products'] is Map) {
        pName = orderMap['products']['name']?.toString() ?? pName;
      }
    }

    final cat = json['category']?.toString().toLowerCase() ?? 'cash_pod';
    final pMethod = json['payment_method']?.toString().toLowerCase() ??
        (cat.contains('paystack') ? 'paystack' : (cat.contains('remittance') ? 'bank_transfer' : 'cash'));

    final chan = json['channel']?.toString() ??
        (pMethod == 'paystack'
            ? 'Titan Trust / Paystack'
            : (pMethod == 'cash' ? 'Cash in Hand' : (pMethod == 'pos' ? 'POS Terminal' : 'Bank Transfer')));

    final bool isPartialVal = json['is_partial'] == true ||
        json['isPartial'] == true ||
        (json['status']?.toString().toLowerCase().contains('partial') ?? false) ||
        (json['metadata'] is Map && (json['metadata']['is_partial'] == true || json['metadata']['isPartial'] == true)) ||
        (json['notes']?.toString().toLowerCase().contains('partial') ?? false);

    return DCTransactionRecord(
      id: json['id']?.toString() ?? 'txn-${DateTime.now().millisecondsSinceEpoch}',
      transactionCode: json['transaction_code']?.toString() ?? json['reference']?.toString() ?? 'TXN-0000',
      orderNumber: oNumber,
      orderId: json['order_id']?.toString(),
      productName: pName ?? 'Respira Detox Formula',
      customerName: cName,
      customerPhone: cPhone,
      deliveryLocation: dLocation,
      riderId: rId,
      riderName: rName,
      riderCode: rCode,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      commission: (json['commission'] as num?)?.toDouble() ?? 1000.0,
      transportAllowance: (json['transport_allowance'] as num?)?.toDouble() ?? 1500.0,
      category: cat,
      paymentMethod: pMethod,
      gatewayReference: json['gateway_reference']?.toString() ?? json['reference']?.toString(),
      channel: chan,
      status: json['status']?.toString() ?? (isPartialVal ? 'partial' : 'verified'),
      isCredit: json['is_credit'] == true || json['isCredit'] == true,
      isPartial: isPartialVal,
      expectedAmount: (json['expected_amount'] as num?)?.toDouble(),
      discrepancyAmount: (json['discrepancy_amount'] as num?)?.toDouble(),
      discrepancyReason: json['discrepancy_reason']?.toString(),
      notes: json['notes']?.toString() ?? json['description']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : (json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now() : DateTime.now()),
      metadata: json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_code': transactionCode,
      'order_number': orderNumber,
      'order_id': orderId,
      'product_name': productName,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'delivery_location': deliveryLocation,
      'rider_id': riderId,
      'rider_name': riderName,
      'rider_code': riderCode,
      'amount': amount,
      'commission': commission,
      'transport_allowance': transportAllowance,
      'category': category,
      'payment_method': paymentMethod,
      'gateway_reference': gatewayReference,
      'channel': channel,
      'status': status,
      'is_credit': isCredit,
      'is_partial': isPartial,
      'expected_amount': expectedAmount,
      'discrepancy_amount': discrepancyAmount,
      'discrepancy_reason': discrepancyReason,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }
}
