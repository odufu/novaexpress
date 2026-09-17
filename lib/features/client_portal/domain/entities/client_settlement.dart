/// Client Settlement Payout Batch Entity
class ClientSettlement {
  final String id;
  final String settlementNumber;
  final String clientId;
  final String companyId;
  final String? distributionCenterId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int totalOrdersCount;
  final double grossCollections;
  final double logisticsFeesDeducted;
  final double platformFeesDeducted;
  final double gatewayFeesDeducted;
  final double failedAttemptFeesDeducted;
  final double otherChargesDeducted;
  final double netPayoutAmount;
  final Map<String, dynamic> chargesBreakdown;
  final String destinationBankName;
  final String destinationAccountNumber;
  final String destinationAccountName;
  final String? payoutReference;
  final String? proofOfPaymentUrl;
  final String status; // 'pending', 'processing', 'completed', 'disputed'
  final String? notes;
  final DateTime settledAt;
  final DateTime createdAt;

  const ClientSettlement({
    required this.id,
    required this.settlementNumber,
    required this.clientId,
    this.companyId = '11111111-1111-4111-8111-111111111111',
    this.distributionCenterId,
    required this.periodStart,
    required this.periodEnd,
    required this.totalOrdersCount,
    required this.grossCollections,
    required this.logisticsFeesDeducted,
    this.platformFeesDeducted = 0.0,
    this.gatewayFeesDeducted = 0.0,
    this.failedAttemptFeesDeducted = 0.0,
    this.otherChargesDeducted = 0.0,
    required this.netPayoutAmount,
    this.chargesBreakdown = const {},
    this.destinationBankName = '',
    this.destinationAccountNumber = '',
    this.destinationAccountName = '',
    this.payoutReference,
    this.proofOfPaymentUrl,
    this.status = 'completed',
    this.notes,
    required this.settledAt,
    required this.createdAt,
  });

  bool get isCompleted =>
      status.toLowerCase() == 'completed' ||
      status.toLowerCase() == 'settled';
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isProcessing => status.toLowerCase() == 'processing';

  factory ClientSettlement.fromJson(Map<String, dynamic> json) {
    return ClientSettlement(
      id: json['id']?.toString() ?? '',
      settlementNumber: json['settlement_number']?.toString() ?? 'SETTLE-UNKNOWN',
      clientId: json['client_id']?.toString() ?? '',
      companyId: json['company_id']?.toString() ?? '11111111-1111-4111-8111-111111111111',
      distributionCenterId: json['distribution_center_id']?.toString(),
      periodStart: json['period_start'] != null
          ? DateTime.tryParse(json['period_start'].toString()) ?? DateTime.now().subtract(const Duration(days: 1))
          : DateTime.now().subtract(const Duration(days: 1)),
      periodEnd: json['period_end'] != null
          ? DateTime.tryParse(json['period_end'].toString()) ?? DateTime.now()
          : DateTime.now(),
      totalOrdersCount: (json['total_orders_count'] as num?)?.toInt() ?? 0,
      grossCollections: (json['gross_collections'] as num?)?.toDouble() ?? 0.0,
      logisticsFeesDeducted: (json['logistics_fees_deducted'] as num?)?.toDouble() ?? 0.0,
      platformFeesDeducted: (json['platform_fees_deducted'] as num?)?.toDouble() ?? 0.0,
      gatewayFeesDeducted: (json['gateway_fees_deducted'] as num?)?.toDouble() ?? 0.0,
      failedAttemptFeesDeducted: (json['failed_attempt_fees_deducted'] as num?)?.toDouble() ?? 0.0,
      otherChargesDeducted: (json['other_charges_deducted'] as num?)?.toDouble() ?? 0.0,
      netPayoutAmount: (json['net_payout_amount'] as num?)?.toDouble() ?? 0.0,
      chargesBreakdown: json['charges_breakdown'] is Map
          ? Map<String, dynamic>.from(json['charges_breakdown'] as Map)
          : {},
      destinationBankName: json['destination_bank_name']?.toString() ?? '',
      destinationAccountNumber: json['destination_account_number']?.toString() ?? '',
      destinationAccountName: json['destination_account_name']?.toString() ?? '',
      payoutReference: json['payout_reference']?.toString(),
      proofOfPaymentUrl: json['proof_of_payment_url']?.toString(),
      status: json['status']?.toString() ?? 'completed',
      notes: json['notes']?.toString(),
      settledAt: json['settled_at'] != null
          ? DateTime.tryParse(json['settled_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'settlement_number': settlementNumber,
      'client_id': clientId,
      'company_id': companyId,
      if (distributionCenterId != null) 'distribution_center_id': distributionCenterId,
      'period_start': periodStart.toIso8601String(),
      'period_end': periodEnd.toIso8601String(),
      'total_orders_count': totalOrdersCount,
      'gross_collections': grossCollections,
      'logistics_fees_deducted': logisticsFeesDeducted,
      'platform_fees_deducted': platformFeesDeducted,
      'gateway_fees_deducted': gatewayFeesDeducted,
      'failed_attempt_fees_deducted': failedAttemptFeesDeducted,
      'other_charges_deducted': otherChargesDeducted,
      'charges_breakdown': chargesBreakdown,
      'net_payout_amount': netPayoutAmount,
      'destination_bank_name': destinationBankName,
      'destination_account_number': destinationAccountNumber,
      'destination_account_name': destinationAccountName,
      'payout_reference': payoutReference,
      'proof_of_payment_url': proofOfPaymentUrl,
      'status': status,
      'notes': notes,
      'settled_at': settledAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
