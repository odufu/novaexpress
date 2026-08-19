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
    this.notes,
    required this.createdAt,
    this.verifiedAt,
  });

  bool get isVerified => status.toLowerCase() == 'verified';
  bool get isPending => status.toLowerCase() == 'pending' || status.toLowerCase() == 'pending verification';
  bool get isRejected => status.toLowerCase() == 'rejected';
  bool get isDisputed => status.toLowerCase() == 'disputed';

  String get statusDisplay {
    if (isVerified) return 'Verified ✓';
    if (isPending) return 'Pending Verification';
    if (isRejected) return 'Rejected';
    if (isDisputed) return 'Disputed';
    return status.toUpperCase();
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
