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
    super.posFee = 0.0,
    super.paymentMethod = 'bank_transfer',
    super.depositReceiptUrl,
    super.status = 'pending',
    super.verifiedByUserId,
    super.verifiedByName,
    super.discrepancyAmount,
    super.discrepancyReason,
    super.notes,
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

    final dynamic rawPos = json['pos_fee'];
    final double posFee = (rawPos is num)
        ? rawPos.toDouble()
        : (double.tryParse(rawPos?.toString() ?? '') ?? 0.0);

    final dynamic rawDiscrepancy = json['discrepancy_amount'];
    final double? discrepancyAmount = (rawDiscrepancy is num)
        ? rawDiscrepancy.toDouble()
        : (rawDiscrepancy != null ? double.tryParse(rawDiscrepancy.toString()) : null);

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

    return RemittanceModel(
      id: id,
      referenceNumber: ref,
      companyId: json['company_id']?.toString() ?? '',
      deliveryAgentId: json['delivery_agent_id']?.toString() ?? '',
      amount: amount,
      grossCollections: grossCollections,
      commissionDeducted: commissionDeducted,
      transportAllowanceDeducted: transportAllowanceDeducted,
      posFee: posFee,
      paymentMethod: json['payment_method']?.toString() ?? 'bank_transfer',
      depositReceiptUrl: json['deposit_receipt_url']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      verifiedByUserId: json['verified_by_finance_user_id']?.toString() ?? json['verified_by_user_id']?.toString(),
      verifiedByName: json['verified_by_name']?.toString() ?? 'Wuse DC — Operations',
      discrepancyAmount: discrepancyAmount,
      discrepancyReason: json['discrepancy_reason']?.toString(),
      notes: json['notes']?.toString(),
      createdAt: parsedCreated,
      verifiedAt: parsedVerified,
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
      'pos_fee': posFee,
      'payment_method': paymentMethod,
      'deposit_receipt_url': depositReceiptUrl,
      'status': status,
      'verified_by_name': verifiedByName,
      'discrepancy_amount': discrepancyAmount,
      'discrepancy_reason': discrepancyReason,
      'notes': notes,
    };
  }
}
