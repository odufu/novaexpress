import 'dart:convert';
import 'package:flutter/foundation.dart';

@immutable
class AgentDailySaleItem {
  final String sku;
  final String productName;
  final int quantity;
  final double unitPrice;

  const AgentDailySaleItem({
    required this.sku,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  double get subtotal => quantity * unitPrice;

  Map<String, dynamic> toJson() => {
        'sku': sku,
        'product_name': productName,
        'quantity': quantity,
        'unit_price': unitPrice,
      };

  factory AgentDailySaleItem.fromJson(Map<String, dynamic> json) {
    return AgentDailySaleItem(
      sku: json['sku']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

@immutable
class AgentDailySaleRecord {
  final String id;
  final String agentId;
  final String agentName;
  final String agentCode;
  final String orderReference;
  final String customerName;
  final String customerPhone;
  final String deliveryLocation;
  final List<AgentDailySaleItem> items;
  final double totalAmount;
  final String paymentMethod; // 'cash_cod' | 'transfer' | 'pos'
  final String status; // 'delivered_collected' | 'partial_return' | 'remitted'
  final String loggedBy;
  final DateTime timestamp;
  final String? notes;
  final String? merchantId;
  final String? merchantName;
  final int replenishedUnits;
  final int returnedUnits;
  final String? dcName;

  const AgentDailySaleRecord({
    required this.id,
    required this.agentId,
    required this.agentName,
    required this.agentCode,
    required this.orderReference,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryLocation,
    required this.items,
    required this.totalAmount,
    this.paymentMethod = 'cash_cod',
    this.status = 'delivered_collected',
    required this.loggedBy,
    required this.timestamp,
    this.notes,
    this.merchantId,
    this.merchantName,
    this.replenishedUnits = 0,
    this.returnedUnits = 0,
    this.dcName,
  });

  int get totalUnits => items.fold(0, (sum, i) => sum + i.quantity);

  Map<String, dynamic> toJson() => {
        'id': id,
        'agent_id': agentId,
        'agent_name': agentName,
        'agent_code': agentCode,
        'order_reference': orderReference,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'delivery_location': deliveryLocation,
        'items': items.map((i) => i.toJson()).toList(),
        'total_amount': totalAmount,
        'payment_method': paymentMethod,
        'status': status,
        'logged_by': loggedBy,
        'timestamp': timestamp.toIso8601String(),
        'notes': notes,
        'merchant_id': merchantId,
        'merchant_name': merchantName,
        'replenished_units': replenishedUnits,
        'returned_units': returnedUnits,
        'dc_name': dcName,
      };

  factory AgentDailySaleRecord.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    List<AgentDailySaleItem> parsedItems = [];
    if (rawItems is List) {
      parsedItems = rawItems
          .map((i) => AgentDailySaleItem.fromJson(i as Map<String, dynamic>))
          .toList();
    } else if (rawItems is String) {
      try {
        final decoded = jsonDecode(rawItems);
        if (decoded is List) {
          parsedItems = decoded
              .map((i) => AgentDailySaleItem.fromJson(i as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {}
    }

    return AgentDailySaleRecord(
      id: json['id']?.toString() ?? '',
      agentId: json['agent_id']?.toString() ?? '',
      agentName: json['agent_name']?.toString() ?? 'Partner Agent',
      agentCode: json['agent_code']?.toString() ?? '',
      orderReference: json['order_reference']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? 'Customer',
      customerPhone: json['customer_phone']?.toString() ?? '',
      deliveryLocation: json['delivery_location']?.toString() ?? '',
      items: parsedItems,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method']?.toString() ?? 'cash_cod',
      status: json['status']?.toString() ?? 'delivered_collected',
      loggedBy: json['logged_by']?.toString() ?? 'Operator',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      notes: json['notes']?.toString(),
      merchantId: json['merchant_id']?.toString(),
      merchantName: json['merchant_name']?.toString(),
      replenishedUnits: (json['replenished_units'] as num?)?.toInt() ?? 0,
      returnedUnits: (json['returned_units'] as num?)?.toInt() ?? 0,
      dcName: json['dc_name']?.toString(),
    );
  }
}
