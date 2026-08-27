import '../../domain/entities/remittance.dart';

class RemittanceModel extends RemittanceEntity {
  const RemittanceModel({
    super.id = '',
    super.referenceNumber = 'REM-00482',
    super.companyId = '',
    super.deliveryAgentId = '',
    super.amount = 0.0,
    super.grossCollections = 0.0,
    super.commissionDeducted = 0.0,
    super.transportAllowanceDeducted = 0.0,
    super.failedStipendsDeducted = 0.0,
    super.posFee = 0.0,
    super.paymentMethod = 'bank_transfer',
    super.depositReceiptUrl,
    super.status = 'pending',
    super.verifiedByUserId,
    super.verifiedByName,
    super.discrepancyAmount,
    super.discrepancyReason,
    super.expectedAmount,
    super.isPartial = false,
    super.paystackChannel,
    super.paystackBank,
    super.paystackAuthCode,
    super.paystackPaidAt,
    super.payerEmail,
    super.payerName,
    super.gatewayResponse,
    super.destinationBankName = 'NovaExpress Main Account (Zenith Bank)',
    super.destinationAccountNumber = '1012398412',
    super.destinationAccountName = 'NovaExpress Logistics Limited',
    super.notes,
    super.associatedOrders = const [],
    required super.createdAt,
    super.verifiedAt,
  });

  factory RemittanceModel.fromJson(Map<String, dynamic> json) {
    final dynamic rawAmount = json['amount'] ?? json['net_remitted'] ?? json['total_amount'];
    final double amount = (rawAmount is num)
        ? rawAmount.toDouble()
        : (double.tryParse(rawAmount?.toString() ?? '') ?? 0.0);

    final dynamic rawGross = json['gross_collections'] ?? json['collected_amount'];
    final double grossCollections = (rawGross is num)
        ? rawGross.toDouble()
        : (double.tryParse(rawGross?.toString() ?? '') ?? amount);

    final dynamic rawComm = json['commission_deducted'] ?? json['agent_commission'];
    final double commissionDeducted = (rawComm is num)
        ? rawComm.toDouble()
        : (double.tryParse(rawComm?.toString() ?? '') ?? 0.0);

    final dynamic rawTransport = json['transport_allowance_deducted'] ?? json['transport_allowance'];
    final double transportAllowanceDeducted = (rawTransport is num)
        ? rawTransport.toDouble()
        : (double.tryParse(rawTransport?.toString() ?? '') ?? 0.0);

    final dynamic rawFailedStipends = json['failed_stipends_deducted'] ?? json['failed_stipends'];
    final double failedStipendsDeducted = (rawFailedStipends is num)
        ? rawFailedStipends.toDouble()
        : (double.tryParse(rawFailedStipends?.toString() ?? '') ?? 0.0);

    final dynamic rawPos = json['pos_fee'];
    final double posFee = (rawPos is num)
        ? rawPos.toDouble()
        : (double.tryParse(rawPos?.toString() ?? '') ?? 0.0);

    final dynamic rawExpected = json['expected_amount'];
    final double? expectedAmount = (rawExpected is num)
        ? rawExpected.toDouble()
        : (rawExpected != null ? double.tryParse(rawExpected.toString()) : null);

    final dynamic rawDiscrepancy = json['discrepancy_amount'];
    final double? discrepancyAmount = (rawDiscrepancy is num)
        ? rawDiscrepancy.toDouble()
        : (rawDiscrepancy != null ? double.tryParse(rawDiscrepancy.toString()) : null);

    final bool isPartial = json['is_partial'] == true ||
        (discrepancyAmount != null && discrepancyAmount < -0.01) ||
        (expectedAmount != null && expectedAmount > amount && amount > 0);

    final id = json['id']?.toString() ?? '';
    final ref = json['reference_number']?.toString() ??
        json['reference']?.toString() ??
        (id.length > 5 ? 'REM-${id.substring(0, 5)}' : 'REM-00482');

    DateTime parsedCreated;
    try {
      parsedCreated = json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now();
    } catch (_) {
      parsedCreated = DateTime.now();
    }

    DateTime? parsedVerified;
    try {
      parsedVerified = json['verified_at'] != null
          ? DateTime.parse(json['verified_at'].toString())
          : null;
    } catch (_) {
      parsedVerified = null;
    }

    DateTime? parsedPaystackPaidAt;
    try {
      parsedPaystackPaidAt = json['paystack_paid_at'] != null
          ? DateTime.parse(json['paystack_paid_at'].toString())
          : null;
    } catch (_) {
      parsedPaystackPaidAt = null;
    }

    final List<dynamic>? rawOrders = json['associated_orders'] ?? json['orders'] ?? json['order_breakdown'];
    final List<RemittanceOrderItem> orders = rawOrders != null
        ? rawOrders.map((o) => RemittanceOrderItem.fromJson(Map<String, dynamic>.from(o))).toList()
        : const [];

    return RemittanceModel(
      id: id,
      referenceNumber: ref,
      companyId: json['company_id']?.toString() ?? '',
      deliveryAgentId: json['delivery_agent_id']?.toString() ?? '',
      amount: amount,
      grossCollections: grossCollections,
      commissionDeducted: commissionDeducted,
      transportAllowanceDeducted: transportAllowanceDeducted,
      failedStipendsDeducted: failedStipendsDeducted,
      posFee: posFee,
      paymentMethod: json['payment_method']?.toString() ?? 'bank_transfer',
      depositReceiptUrl: json['deposit_receipt_url']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      verifiedByUserId: json['verified_by_finance_user_id']?.toString() ?? json['verified_by_user_id']?.toString(),
      verifiedByName: json['verified_by_name']?.toString() ?? 'Paystack Settlement Gateway',
      discrepancyAmount: discrepancyAmount,
      discrepancyReason: json['discrepancy_reason']?.toString(),
      expectedAmount: expectedAmount,
      isPartial: isPartial,
      paystackChannel: json['paystack_channel']?.toString() ?? json['channel']?.toString(),
      paystackBank: json['paystack_bank']?.toString() ?? json['bank_name']?.toString(),
      paystackAuthCode: json['paystack_auth_code']?.toString(),
      paystackPaidAt: parsedPaystackPaidAt,
      payerEmail: json['payer_email']?.toString(),
      payerName: json['payer_name']?.toString(),
      gatewayResponse: json['gateway_response']?.toString(),
      destinationBankName: json['destination_bank_name']?.toString() ?? 'NovaExpress Main Account (Zenith Bank)',
      destinationAccountNumber: json['destination_account_number']?.toString() ?? '1012398412',
      destinationAccountName: json['destination_account_name']?.toString() ?? 'NovaExpress Logistics Limited',
      notes: json['notes']?.toString(),
      associatedOrders: orders,
      createdAt: parsedCreated,
      verifiedAt: parsedVerified,
    );
  }

  factory RemittanceModel.fromEntity(RemittanceEntity entity) {
    return RemittanceModel(
      id: entity.id,
      referenceNumber: entity.referenceNumber,
      companyId: entity.companyId,
      deliveryAgentId: entity.deliveryAgentId,
      amount: entity.amount,
      grossCollections: entity.grossCollections,
      commissionDeducted: entity.commissionDeducted,
      transportAllowanceDeducted: entity.transportAllowanceDeducted,
      failedStipendsDeducted: entity.failedStipendsDeducted,
      posFee: entity.posFee,
      paymentMethod: entity.paymentMethod,
      depositReceiptUrl: entity.depositReceiptUrl,
      status: entity.status,
      verifiedByUserId: entity.verifiedByUserId,
      verifiedByName: entity.verifiedByName,
      discrepancyAmount: entity.discrepancyAmount,
      discrepancyReason: entity.discrepancyReason,
      expectedAmount: entity.expectedAmount,
      isPartial: entity.isPartial,
      paystackChannel: entity.paystackChannel,
      paystackBank: entity.paystackBank,
      paystackAuthCode: entity.paystackAuthCode,
      paystackPaidAt: entity.paystackPaidAt,
      payerEmail: entity.payerEmail,
      payerName: entity.payerName,
      gatewayResponse: entity.gatewayResponse,
      destinationBankName: entity.destinationBankName,
      destinationAccountNumber: entity.destinationAccountNumber,
      destinationAccountName: entity.destinationAccountName,
      notes: entity.notes,
      associatedOrders: entity.associatedOrders,
      createdAt: entity.createdAt,
      verifiedAt: entity.verifiedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reference_number': referenceNumber,
      'company_id': companyId,
      'delivery_agent_id': deliveryAgentId,
      'amount': amount,
      'gross_collections': grossCollections,
      'commission_deducted': commissionDeducted,
      'transport_allowance_deducted': transportAllowanceDeducted,
      'failed_stipends_deducted': failedStipendsDeducted,
      'pos_fee': posFee,
      'payment_method': paymentMethod,
      'deposit_receipt_url': depositReceiptUrl,
      'status': status,
      'verified_by_name': verifiedByName,
      'discrepancy_amount': discrepancyAmount,
      'discrepancy_reason': discrepancyReason,
      'expected_amount': expectedAmount,
      'is_partial': isPartial,
      'paystack_channel': paystackChannel,
      'paystack_bank': paystackBank,
      'paystack_auth_code': paystackAuthCode,
      'paystack_paid_at': paystackPaidAt?.toIso8601String(),
      'payer_email': payerEmail,
      'payer_name': payerName,
      'gateway_response': gatewayResponse,
      'destination_bank_name': destinationBankName,
      'destination_account_number': destinationAccountNumber,
      'destination_account_name': destinationAccountName,
      'notes': notes,
      'associated_orders': associatedOrders.map((o) => o.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'verified_at': verifiedAt?.toIso8601String(),
    };
  }
}
