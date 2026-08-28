class RemittanceOrderItem {
  final String orderId;
  final String orderNumber;
  final String customerName;
  final String status; // 'delivered', 'failed', 'cancelled'
  final String paymentType; // 'pay_on_delivery', 'prepaid'
  final double cashCollected;
  final double riderCommission;
  final double transportAllowance;
  final double failedStipend;
  final double posFee;
  final DateTime date;

  const RemittanceOrderItem({
    required this.orderId,
    required this.orderNumber,
    required this.customerName,
    required this.status,
    this.paymentType = 'pay_on_delivery',
    this.cashCollected = 0.0,
    this.riderCommission = 0.0,
    this.transportAllowance = 0.0,
    this.failedStipend = 0.0,
    this.posFee = 0.0,
    required this.date,
  });

  bool get isDelivered => status.toLowerCase() == 'delivered';
  bool get isFailed => status.toLowerCase() == 'failed' || status.toLowerCase() == 'failed_attempt';

  double get netContribution {
    if (isFailed) {
      return -failedStipend; // Failed delivery stipend credit
    }
    return cashCollected - riderCommission - transportAllowance - posFee;
  }

  factory RemittanceOrderItem.fromJson(Map<String, dynamic> json) {
    return RemittanceOrderItem(
      orderId: json['order_id']?.toString() ?? json['id']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ?? 'ORD-UNKNOWN',
      customerName: json['customer_name']?.toString() ?? 'Valued Customer',
      status: json['status']?.toString() ?? 'delivered',
      paymentType: json['payment_type']?.toString() ?? 'pay_on_delivery',
      cashCollected: (json['cash_collected'] as num?)?.toDouble() ??
          ((json['status'] == 'delivered' && json['payment_type'] == 'pay_on_delivery')
              ? ((json['total_amount'] as num?)?.toDouble() ?? 0.0)
              : 0.0),
      riderCommission: (json['rider_commission'] as num?)?.toDouble() ??
          (json['agent_entitlement'] as num?)?.toDouble() ?? 0.0,
      transportAllowance: (json['transport_allowance'] as num?)?.toDouble() ?? 0.0,
      failedStipend: (json['failed_stipend'] as num?)?.toDouble() ??
          ((json['status'] == 'failed' || json['status'] == 'failed_attempt') ? 500.0 : 0.0),
      posFee: (json['pos_fee'] as num?)?.toDouble() ?? 0.0,
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() => {
    'order_id': orderId,
    'order_number': orderNumber,
    'customer_name': customerName,
    'status': status,
    'payment_type': paymentType,
    'cash_collected': cashCollected,
    'rider_commission': riderCommission,
    'transport_allowance': transportAllowance,
    'failed_stipend': failedStipend,
    'pos_fee': posFee,
    'date': date.toIso8601String(),
  };
}

class RemittanceEntity {
  final String id;
  final String referenceNumber;
  final String companyId;
  final String deliveryAgentId;
  final double amount;
  final double grossCollections;
  final double commissionDeducted;
  final double transportAllowanceDeducted;
  final double failedStipendsDeducted;
  final double posFee;
  final String paymentMethod; // 'bank_transfer', 'cash_to_dc', 'pos'
  final String? depositReceiptUrl;
  final String status; // 'pending', 'verified', 'rejected', 'disputed'
  final String? verifiedByUserId;
  final String? verifiedByName;
  final double? discrepancyAmount;
  final String? discrepancyReason;
  final double? expectedAmount;
  final bool isPartial;
  final String? paystackChannel;
  final String? paystackBank;
  final String? paystackAuthCode;
  final DateTime? paystackPaidAt;
  final String? payerEmail;
  final String? payerName;
  final String? gatewayResponse;
  final String destinationBankName;
  final String destinationAccountNumber;
  final String destinationAccountName;
  final String? notes;
  final List<RemittanceOrderItem> associatedOrders;
  final DateTime createdAt;
  final DateTime? verifiedAt;

  const RemittanceEntity({
    this.id = '',
    this.referenceNumber = 'REM-00482',
    this.companyId = '',
    this.deliveryAgentId = '',
    this.amount = 0.0,
    this.grossCollections = 0.0,
    this.commissionDeducted = 0.0,
    this.transportAllowanceDeducted = 0.0,
    this.failedStipendsDeducted = 0.0,
    this.posFee = 0.0,
    this.paymentMethod = 'bank_transfer',
    this.depositReceiptUrl,
    this.status = 'pending',
    this.verifiedByUserId,
    this.verifiedByName,
    this.discrepancyAmount,
    this.discrepancyReason,
    this.expectedAmount,
    this.isPartial = false,
    this.paystackChannel,
    this.paystackBank,
    this.paystackAuthCode,
    this.paystackPaidAt,
    this.payerEmail,
    this.payerName,
    this.gatewayResponse,
    this.destinationBankName = 'NovaExpress Main Account (Zenith Bank)',
    this.destinationAccountNumber = '1012398412',
    this.destinationAccountName = 'NovaExpress Logistics Limited',
    this.notes,
    this.associatedOrders = const [],
    required this.createdAt,
    this.verifiedAt,
  });

  int get ordersCount => associatedOrders.length;
  int get deliveredOrdersCount => associatedOrders.where((o) => o.isDelivered).length;
  int get failedOrdersCount => associatedOrders.where((o) => o.isFailed).length;

  double get totalDeductions =>
      commissionDeducted + transportAllowanceDeducted + failedStipendsDeducted + posFee;

  bool get isPartialRemittance =>
      isPartial ||
      (discrepancyAmount != null && discrepancyAmount! < -0.01) ||
      (expectedAmount != null && expectedAmount! > amount && amount > 0);

  double get remainingShortage {
    if (expectedAmount != null && expectedAmount! > amount) {
      return (expectedAmount! - amount);
    }
    if (discrepancyAmount != null && discrepancyAmount! < 0) {
      return discrepancyAmount!.abs();
    }
    return 0.0;
  }

  bool get isVerified =>
      status.toLowerCase() == 'verified' ||
      status.toLowerCase() == 'approved' ||
      status.toLowerCase() == 'settled' ||
      status.toLowerCase() == 'completed' ||
      status.toLowerCase() == 'paid' ||
      paymentMethod.toLowerCase() == 'paystack' ||
      paymentMethod.toLowerCase() == 'paystack_transfer' ||
      referenceNumber.toUpperCase().startsWith('PSTK') ||
      verifiedAt != null;

  bool get isPending =>
      !isVerified &&
      (status.toLowerCase() == 'pending' ||
          status.toLowerCase() == 'submitted' ||
          status.toLowerCase() == 'in_review');

  bool get isRejected => status.toLowerCase() == 'rejected';
  bool get isDisputed => status.toLowerCase() == 'disputed';

  String get statusDisplay {
    if (isRejected) return 'Rejected';
    if (isDisputed) return 'Disputed';
    if (isVerified) return 'Verified';
    return 'Submitted';
  }

  String get settlementDisplay {
    if (isRejected) return 'Rejected';
    if (isDisputed) return 'Disputed';
    if (isPartialRemittance) return 'Partial Remittance';
    return 'Complete Remittance';
  }

  String get paymentMethodDisplay {
    switch (paymentMethod.toLowerCase()) {
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'cash_to_dc':
        return 'Cash to DC';
      case 'pos':
        return 'POS / Agent Transfer';
      default:
        return paymentMethod.isNotEmpty ? paymentMethod : 'Bank Transfer';
    }
  }
}
