import 'package:flutter/material.dart';
import '../../../stock/domain/entities/stock_item.dart';

enum RestockAlertSeverity {
  critical, // <= 3 days of stock remaining or 0 shelf stock
  warning, // 4 to 7 days of stock remaining or <= lowStockThreshold
  healthy, // > 7 days of stock remaining
  wellStocked, // > 30 days of stock remaining or surplus
}

class DCStockVelocity {
  final StockItemEntity product;
  final int dcShelfStock;
  final int inFieldCustody;
  final int deliveredUnits;
  final double dailyBurnRate;
  final double daysRemaining;
  final RestockAlertSeverity severity;
  final String statusLabel;
  final String recommendation;

  int get totalUnits => dcShelfStock + inFieldCustody;

  Color get severityColor {
    switch (severity) {
      case RestockAlertSeverity.critical:
        return const Color(0xFFDC2626);
      case RestockAlertSeverity.warning:
        return const Color(0xFFF59E0B);
      case RestockAlertSeverity.healthy:
        return const Color(0xFF16A34A);
      case RestockAlertSeverity.wellStocked:
        return const Color(0xFF0284C7);
    }
  }

  const DCStockVelocity({
    required this.product,
    required this.dcShelfStock,
    required this.inFieldCustody,
    required this.deliveredUnits,
    required this.dailyBurnRate,
    required this.daysRemaining,
    required this.severity,
    required this.statusLabel,
    required this.recommendation,
  });

  static DCStockVelocity calculate({
    required StockItemEntity product,
    required int dcShelfStock,
    required int inFieldCustody,
    required int deliveredUnits,
    int? customThreshold,
  }) {
    // Determine burn rate based on actual delivery volume and active custody
    double rate = 0.0;
    if (deliveredUnits > 0) {
      rate = deliveredUnits / 7.0; // 7-day rolling window
    } else if (inFieldCustody > 0) {
      rate = inFieldCustody / 14.0;
    }

    final double effectiveRate = rate > 0.05
        ? double.parse(rate.toStringAsFixed(1))
        : (deliveredUnits > 0 ? 0.5 : 0.0);

    final double daysLeft = effectiveRate > 0
        ? (dcShelfStock / effectiveRate)
        : (dcShelfStock > 0 ? 999.0 : 0.0);

    final int threshold = customThreshold ?? (product.lowStockThreshold > 0 ? product.lowStockThreshold : 15);

    final RestockAlertSeverity severity;
    final String statusLabel;
    final String recommendation;

    if (dcShelfStock <= 0) {
      severity = RestockAlertSeverity.critical;
      statusLabel = 'OUT OF STOCK';
      recommendation = 'Zero warehouse stock! Restock immediately to resume distribution.';
    } else if (daysLeft <= 3.0 || (effectiveRate > 0 && dcShelfStock <= threshold)) {
      severity = RestockAlertSeverity.critical;
      statusLabel = 'CRITICAL RESTOCK';
      recommendation = 'Stock depleting in ~${daysLeft.toStringAsFixed(1)} days ($effectiveRate units/day). Urgent reorder required!';
    } else if (daysLeft <= 7.0 || dcShelfStock <= threshold * 2) {
      severity = RestockAlertSeverity.warning;
      statusLabel = 'LOW STOCK WARNING';
      recommendation = 'Stock running low (~${daysLeft.toStringAsFixed(0)} days runway). Plan replenishment.';
    } else if (daysLeft <= 30.0) {
      severity = RestockAlertSeverity.healthy;
      statusLabel = 'HEALTHY COVERAGE';
      recommendation = 'Optimal inventory balance (~${daysLeft.toStringAsFixed(0)} days runway).';
    } else {
      severity = RestockAlertSeverity.wellStocked;
      statusLabel = 'WELL STOCKED';
      recommendation = 'Abundant inventory available on shelves for distribution.';
    }

    return DCStockVelocity(
      product: product,
      dcShelfStock: dcShelfStock,
      inFieldCustody: inFieldCustody,
      deliveredUnits: deliveredUnits,
      dailyBurnRate: effectiveRate,
      daysRemaining: daysLeft,
      severity: severity,
      statusLabel: statusLabel,
      recommendation: recommendation,
    );
  }
}
