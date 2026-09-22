import 'package:flutter/foundation.dart';

@immutable
class ClientCloserPayout {
  final String id;
  final String closerId;
  final String clientId;
  final String payoutNumber;
  final double amount;
  final int ordersCount;
  final List<String> orderIds;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final String? disbursementRef;
  final String? proofOfPaymentUrl;
  final String status; // 'pending', 'remitted', 'completed', 'rejected'
  final DateTime? disbursedAt;
  final DateTime? confirmedAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClientCloserPayout({
    required this.id,
    required this.closerId,
    required this.clientId,
    required this.payoutNumber,
    required this.amount,
    this.ordersCount = 0,
    this.orderIds = const [],
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    this.disbursementRef,
    this.proofOfPaymentUrl,
    this.status = 'remitted',
    this.disbursedAt,
    this.confirmedAt,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => status == 'pending';
  bool get isRemitted => status == 'remitted';
  bool get isCompleted => status == 'completed';
  bool get isRejected => status == 'rejected';
  bool get hasReceipt => proofOfPaymentUrl != null && proofOfPaymentUrl!.trim().isNotEmpty;

  factory ClientCloserPayout.fromJson(Map<String, dynamic> json) {
    List<String> parsedOrderIds = [];
    if (json['order_ids'] is List) {
      parsedOrderIds = (json['order_ids'] as List).map((e) => e.toString()).toList();
    }

    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val == null) return fallback;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return fallback;
      }
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return null;
      }
    }

    final now = DateTime.now();

    return ClientCloserPayout(
      id: (json['id'] ?? '').toString(),
      closerId: (json['closer_id'] ?? '').toString(),
      clientId: (json['client_id'] ?? '').toString(),
      payoutNumber: (json['payout_number'] ?? json['payoutNumber'] ?? 'CPAY-001').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      ordersCount: (json['orders_count'] as num?)?.toInt() ?? 0,
      orderIds: parsedOrderIds,
      bankName: (json['bank_name'] ?? json['bankName'] ?? '').toString(),
      accountNumber: (json['account_number'] ?? json['accountNumber'] ?? '').toString(),
      accountName: (json['account_name'] ?? json['accountName'] ?? '').toString(),
      disbursementRef: json['disbursement_ref']?.toString() ?? json['disbursementRef']?.toString(),
      proofOfPaymentUrl: json['proof_of_payment_url']?.toString() ?? json['proofOfPaymentUrl']?.toString(),
      status: (json['status'] ?? 'remitted').toString().toLowerCase(),
      disbursedAt: parseNullableDate(json['disbursed_at'] ?? json['disbursedAt']),
      confirmedAt: parseNullableDate(json['confirmed_at'] ?? json['confirmedAt']),
      notes: json['notes']?.toString(),
      createdAt: parseDate(json['created_at'], now),
      updatedAt: parseDate(json['updated_at'], now),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'closer_id': closerId,
      'client_id': clientId,
      'payout_number': payoutNumber,
      'amount': amount,
      'orders_count': ordersCount,
      'order_ids': orderIds,
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_name': accountName,
      'disbursement_ref': disbursementRef,
      'proof_of_payment_url': proofOfPaymentUrl,
      'status': status,
      'disbursed_at': disbursedAt?.toIso8601String(),
      'confirmed_at': confirmedAt?.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ClientCloserPayout copyWith({
    String? id,
    String? closerId,
    String? clientId,
    String? payoutNumber,
    double? amount,
    int? ordersCount,
    List<String>? orderIds,
    String? bankName,
    String? accountNumber,
    String? accountName,
    String? disbursementRef,
    String? proofOfPaymentUrl,
    String? status,
    DateTime? disbursedAt,
    DateTime? confirmedAt,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClientCloserPayout(
      id: id ?? this.id,
      closerId: closerId ?? this.closerId,
      clientId: clientId ?? this.clientId,
      payoutNumber: payoutNumber ?? this.payoutNumber,
      amount: amount ?? this.amount,
      ordersCount: ordersCount ?? this.ordersCount,
      orderIds: orderIds ?? this.orderIds,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountName: accountName ?? this.accountName,
      disbursementRef: disbursementRef ?? this.disbursementRef,
      proofOfPaymentUrl: proofOfPaymentUrl ?? this.proofOfPaymentUrl,
      status: status ?? this.status,
      disbursedAt: disbursedAt ?? this.disbursedAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
