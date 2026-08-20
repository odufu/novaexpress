class TransactionItem {
  final String id;
  final String title;
  final String category; // 'earnings', 'remittance', 'direct_transfer', 'payout'
  final double amount;
  final bool isCredit;
  final DateTime timestamp;
  final String reference;
  final String status; // 'settled', 'verified', 'pending', 'approved', 'rejected'
  final String description;

  const TransactionItem({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.isCredit,
    required this.timestamp,
    required this.reference,
    required this.status,
    required this.description,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'];
    final double parsedAmount = (rawAmount is num)
        ? rawAmount.toDouble()
        : (double.tryParse(rawAmount?.toString() ?? '0') ?? 0.0);

    return TransactionItem(
      id: (json['transaction_code']?.toString().isNotEmpty == true)
          ? json['transaction_code'].toString()
          : (json['id']?.toString().length == 36
              ? 'TXN-${json['id'].toString().substring(0, 4).toUpperCase()}'
              : (json['id']?.toString() ?? 'TXN-0000')),
      title: json['title']?.toString() ?? 'Account Transaction',
      category: json['category']?.toString().toLowerCase() ?? 'earnings',
      amount: parsedAmount,
      isCredit: json['is_credit'] == true,
      timestamp: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      reference: json['reference']?.toString() ?? 'N/A',
      status: json['status']?.toString().toLowerCase() ?? 'settled',
      description: json['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transaction_code': id,
      'title': title,
      'category': category,
      'amount': amount,
      'is_credit': isCredit,
      'reference': reference,
      'status': status,
      'description': description,
      'created_at': timestamp.toIso8601String(),
    };
  }
}
