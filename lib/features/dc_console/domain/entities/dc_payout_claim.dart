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
  final String status; // 'pending', 'pending_review', 'approved', 'rejected'
  final String? disbursementRef;
  final String? dcNotes;

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
    this.dcNotes,
  });

  bool get isPending => status == 'pending' || status == 'pending_review';
  bool get isApproved => status == 'approved' || status == 'disbursed';
  bool get isRejected => status == 'rejected';

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
    String? dcNotes,
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
      dcNotes: dcNotes ?? this.dcNotes,
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
      status: json['status']?.toString() ?? 'pending',
      disbursementRef: json['disbursement_ref']?.toString() ?? json['disbursementRef'],
      dcNotes: json['dc_notes']?.toString() ?? json['dcNotes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'payout_number': claimNumber,
      'claimNumber': claimNumber,
      'delivery_agent_id': riderId,
      'rider_name': riderName,
      'rider_code': riderCode,
      'amount': requestedAmount,
      'requestedAmount': requestedAmount,
      'current_balance': currentBalance,
      'currentBalance': currentBalance,
      'bank_name': bankName,
      'bankName': bankName,
      'account_number': accountNumber,
      'accountNumber': accountNumber,
      'account_name': accountName,
      'accountName': accountName,
      'created_at': requestedAt.toIso8601String(),
      'requestedAt': requestedAt.toIso8601String(),
      'status': status,
      'disbursement_ref': disbursementRef,
      'disbursementRef': disbursementRef,
      'dc_notes': dcNotes,
      'dcNotes': dcNotes,
    };
  }
}
