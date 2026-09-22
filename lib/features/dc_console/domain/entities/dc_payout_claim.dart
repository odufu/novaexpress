class DCPayoutClaim {
  final String id;
  final String claimNumber;
  final String riderId;
  final String riderName;
  final String riderCode;
  final double requestedAmount;
  final double currentBalance;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final DateTime requestedAt;
  final String status; // 'pending', 'pending_review', 'disbursed', 'approved', 'completed', 'confirmed', 'rejected'
  final String? disbursementRef;
  final String? proofOfPaymentUrl;
  final String? dcNotes;
  final DateTime? riderConfirmedAt;

  const DCPayoutClaim({
    required this.id,
    required this.claimNumber,
    required this.riderId,
    required this.riderName,
    required this.riderCode,
    required this.requestedAmount,
    required this.currentBalance,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.requestedAt,
    this.status = 'pending',
    this.disbursementRef,
    this.proofOfPaymentUrl,
    this.dcNotes,
    this.riderConfirmedAt,
  });

  bool get isPending => status == 'pending' || status == 'pending_review';
  bool get isApproved => status == 'approved' || status == 'disbursed';
  bool get isDisbursed => status == 'disbursed';
  bool get isConfirmed => status == 'completed' || status == 'confirmed';
  bool get isRejected => status == 'rejected';
  bool get hasReceipt => proofOfPaymentUrl != null && proofOfPaymentUrl!.trim().isNotEmpty;

  DCPayoutClaim copyWith({
    String? id,
    String? claimNumber,
    String? riderId,
    String? riderName,
    String? riderCode,
    double? requestedAmount,
    double? currentBalance,
    String? bankName,
    String? accountNumber,
    String? accountName,
    DateTime? requestedAt,
    String? status,
    String? disbursementRef,
    String? proofOfPaymentUrl,
    String? dcNotes,
    DateTime? riderConfirmedAt,
  }) {
    return DCPayoutClaim(
      id: id ?? this.id,
      claimNumber: claimNumber ?? this.claimNumber,
      riderId: riderId ?? this.riderId,
      riderName: riderName ?? this.riderName,
      riderCode: riderCode ?? this.riderCode,
      requestedAmount: requestedAmount ?? this.requestedAmount,
      currentBalance: currentBalance ?? this.currentBalance,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountName: accountName ?? this.accountName,
      requestedAt: requestedAt ?? this.requestedAt,
      status: status ?? this.status,
      disbursementRef: disbursementRef ?? this.disbursementRef,
      proofOfPaymentUrl: proofOfPaymentUrl ?? this.proofOfPaymentUrl,
      dcNotes: dcNotes ?? this.dcNotes,
      riderConfirmedAt: riderConfirmedAt ?? this.riderConfirmedAt,
    );
  }

  factory DCPayoutClaim.fromJson(Map<String, dynamic> json) {
    String rName = json['account_name']?.toString() ?? 'Delivery Agent';
    String rCode = 'PDA-7000';
    double cBalance = 0.0;
    String rId = json['delivery_agent_id']?.toString() ?? '';

    if (json['delivery_agents'] is Map) {
      final agentMap = json['delivery_agents'] as Map<String, dynamic>;
      rCode = agentMap['agent_code']?.toString() ?? rCode;
      cBalance = (agentMap['direct_transfer_balance'] as num?)?.toDouble() ??
          (agentMap['current_cod_balance'] as num?)?.toDouble() ?? 0.0;
      if (agentMap['users'] is Map) {
        final userMap = agentMap['users'] as Map<String, dynamic>;
        final fName = userMap['first_name']?.toString() ?? '';
        final lName = userMap['last_name']?.toString() ?? '';
        if (fName.isNotEmpty || lName.isNotEmpty) {
          rName = '$fName $lName'.trim();
        }
      }
    }

    return DCPayoutClaim(
      id: json['id']?.toString() ?? '',
      claimNumber: json['payout_number']?.toString() ?? json['claimNumber'] ?? 'PAY-0000',
      riderId: rId,
      riderName: json['rider_name']?.toString() ?? json['riderName'] ?? rName,
      riderCode: json['rider_code']?.toString() ?? json['riderCode'] ?? rCode,
      requestedAmount: (json['amount'] as num?)?.toDouble() ?? (json['requestedAmount'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (json['current_balance'] as num?)?.toDouble() ?? (json['currentBalance'] as num?)?.toDouble() ?? cBalance,
      bankName: json['bank_name']?.toString() ?? json['bankName'] ?? 'Access Bank',
      accountNumber: json['account_number']?.toString() ?? json['accountNumber'] ?? '0000000000',
      accountName: json['account_name']?.toString() ?? json['accountName'] ?? rName,
      requestedAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : (json['requestedAt'] != null ? DateTime.tryParse(json['requestedAt'].toString()) ?? DateTime.now() : DateTime.now()),
      status: (json['status'] ?? 'pending').toString(),
      disbursementRef: json['disbursement_ref']?.toString() ?? json['disbursementRef']?.toString(),
      proofOfPaymentUrl: json['proof_of_payment_url']?.toString() ?? json['proofOfPaymentUrl']?.toString(),
      dcNotes: json['dc_notes']?.toString() ?? json['dcNotes']?.toString(),
      riderConfirmedAt: json['rider_confirmed_at'] != null
          ? DateTime.tryParse(json['rider_confirmed_at'].toString())
          : (json['riderConfirmedAt'] != null ? DateTime.tryParse(json['riderConfirmedAt'].toString()) : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'claimNumber': claimNumber,
      'riderId': riderId,
      'riderName': riderName,
      'riderCode': riderCode,
      'requestedAmount': requestedAmount,
      'currentBalance': currentBalance,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountName': accountName,
      'requestedAt': requestedAt.toIso8601String(),
      'status': status,
      'disbursementRef': disbursementRef,
      'proof_of_payment_url': proofOfPaymentUrl,
      'dcNotes': dcNotes,
      'riderConfirmedAt': riderConfirmedAt?.toIso8601String(),
    };
  }
}
