import 'package:flutter/foundation.dart';

@immutable
class DailyTrendPoint {
  final String date;
  final double sales;
  final double expenditure;
  final int unitsSold;
  final double netMargin;

  const DailyTrendPoint({
    required this.date,
    required this.sales,
    required this.expenditure,
    required this.unitsSold,
    required this.netMargin,
  });

  factory DailyTrendPoint.fromMap(Map<String, dynamic> map) {
    return DailyTrendPoint(
      date: map['date']?.toString() ?? '',
      sales: (map['sales'] is num) ? (map['sales'] as num).toDouble() : 0.0,
      expenditure: (map['expenditure'] is num) ? (map['expenditure'] as num).toDouble() : 0.0,
      unitsSold: (map['units_sold'] is num) ? (map['units_sold'] as num).toInt() : 0,
      netMargin: (map['net_margin'] is num) ? (map['net_margin'] as num).toDouble() : 0.0,
    );
  }
}

@immutable
class StateRevenuePoint {
  final String state;
  final int orderCount;
  final double revenue;

  const StateRevenuePoint({
    required this.state,
    required this.orderCount,
    required this.revenue,
  });

  factory StateRevenuePoint.fromMap(Map<String, dynamic> map) {
    return StateRevenuePoint(
      state: map['state']?.toString() ?? 'Other',
      orderCount: (map['order_count'] is num) ? (map['order_count'] as num).toInt() : 0,
      revenue: (map['revenue'] is num) ? (map['revenue'] as num).toDouble() : 0.0,
    );
  }
}

@immutable
class ProductEconomicsEntity {
  final String productId;
  final String productName;
  final String? sku;
  final double basePrice;
  final double costPrice;
  final int unitsSold;
  final double directRevenue;
  final double directAdvertising;
  final double directProcurement;

  const ProductEconomicsEntity({
    required this.productId,
    required this.productName,
    this.sku,
    required this.basePrice,
    required this.costPrice,
    required this.unitsSold,
    required this.directRevenue,
    required this.directAdvertising,
    required this.directProcurement,
  });

  double get directProfit => directRevenue - directAdvertising - directProcurement - (unitsSold * costPrice);

  factory ProductEconomicsEntity.fromMap(Map<String, dynamic> map) {
    return ProductEconomicsEntity(
      productId: map['product_id']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? 'Product',
      sku: map['sku']?.toString(),
      basePrice: (map['base_price'] is num) ? (map['base_price'] as num).toDouble() : 0.0,
      costPrice: (map['cost_price'] is num) ? (map['cost_price'] as num).toDouble() : 0.0,
      unitsSold: (map['units_sold'] is num) ? (map['units_sold'] as num).toInt() : 0,
      directRevenue: (map['direct_revenue'] is num) ? (map['direct_revenue'] as num).toDouble() : 0.0,
      directAdvertising: (map['direct_advertising'] is num) ? (map['direct_advertising'] as num).toDouble() : 0.0,
      directProcurement: (map['direct_procurement'] is num) ? (map['direct_procurement'] as num).toDouble() : 0.0,
    );
  }
}

@immutable
class MerchantFinancialMetrics {
  final String clientId;
  final String? productId;
  final DateTime startDate;
  final DateTime endDate;
  final double salesRevenue; // 1. Sales
  final double totalExpenditures; // 2. Expenditures
  final int quantitySold; // 3. Quantity Sold
  final double netProfit; // 4. Net Profit
  final int availableStock; // 5. Available Stock
  final double advertisementExpenditure; // 6. Advertisement
  final double procurementExpenditure; // 7. Procurement
  final double revenueTillDate; // 8. Revenue Till Date
  final List<DailyTrendPoint> dailyTrends;
  final List<StateRevenuePoint> stateDistribution;
  final ProductEconomicsEntity? productEconomics;

  const MerchantFinancialMetrics({
    required this.clientId,
    this.productId,
    required this.startDate,
    required this.endDate,
    required this.salesRevenue,
    required this.totalExpenditures,
    required this.quantitySold,
    required this.netProfit,
    required this.availableStock,
    required this.advertisementExpenditure,
    required this.procurementExpenditure,
    required this.revenueTillDate,
    this.dailyTrends = const [],
    this.stateDistribution = const [],
    this.productEconomics,
  });

  factory MerchantFinancialMetrics.empty() {
    return MerchantFinancialMetrics(
      clientId: '',
      startDate: DateTime.now().subtract(const Duration(days: 30)),
      endDate: DateTime.now(),
      salesRevenue: 0.0,
      totalExpenditures: 0.0,
      quantitySold: 0,
      netProfit: 0.0,
      availableStock: 0,
      advertisementExpenditure: 0.0,
      procurementExpenditure: 0.0,
      revenueTillDate: 0.0,
      dailyTrends: const [],
      stateDistribution: const [],
    );
  }

  factory MerchantFinancialMetrics.fromMap(Map<String, dynamic> map) {
    return MerchantFinancialMetrics(
      clientId: map['client_id']?.toString() ?? '',
      productId: map['product_id']?.toString(),
      startDate: map['start_date'] != null
          ? DateTime.tryParse(map['start_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endDate: map['end_date'] != null
          ? DateTime.tryParse(map['end_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      salesRevenue: (map['sales_revenue'] is num) ? (map['sales_revenue'] as num).toDouble() : 0.0,
      totalExpenditures: (map['total_expenditures'] is num) ? (map['total_expenditures'] as num).toDouble() : 0.0,
      quantitySold: (map['quantity_sold'] is num) ? (map['quantity_sold'] as num).toInt() : 0,
      netProfit: (map['net_profit'] is num) ? (map['net_profit'] as num).toDouble() : 0.0,
      availableStock: (map['available_stock'] is num) ? (map['available_stock'] as num).toInt() : 0,
      advertisementExpenditure: (map['advertisement_expenditure'] is num) ? (map['advertisement_expenditure'] as num).toDouble() : 0.0,
      procurementExpenditure: (map['procurement_expenditure'] is num) ? (map['procurement_expenditure'] as num).toDouble() : 0.0,
      revenueTillDate: (map['revenue_till_date'] is num) ? (map['revenue_till_date'] as num).toDouble() : 0.0,
      dailyTrends: (map['daily_trends'] is List)
          ? (map['daily_trends'] as List).map((i) => DailyTrendPoint.fromMap(Map<String, dynamic>.from(i))).toList()
          : [],
      stateDistribution: (map['state_distribution'] is List)
          ? (map['state_distribution'] as List).map((i) => StateRevenuePoint.fromMap(Map<String, dynamic>.from(i))).toList()
          : [],
      productEconomics: map['product_economics'] != null && map['product_economics'] is Map
          ? ProductEconomicsEntity.fromMap(Map<String, dynamic>.from(map['product_economics']))
          : null,
    );
  }
}
