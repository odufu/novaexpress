class RemittanceEntity {
  final String id;
  final String referenceNumber;
  final String companyId;
  final String deliveryAgentId;
  final double amount;
  final double grossCollections;
  final double commissionDeducted;
  final double transportAllowanceDeducted;
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
    required this.createdAt,
    this.verifiedAt,
  });

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
      status.toLowerCase() != 'rejected' &&
      status.toLowerCase() != 'disputed';

  bool get isPending => status.toLowerCase() == 'disputed';

  bool get isRejected => status.toLowerCase() == 'rejected';
  bool get isDisputed => status.toLowerCase() == 'disputed';

  String get statusDisplay {
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
