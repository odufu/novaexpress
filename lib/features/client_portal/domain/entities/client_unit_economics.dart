/// Unit Economics & Landed Cost Breakdown Entity
class ClientUnitEconomics {
  final String productName;
  final String productSku;
  final double baseSupplierPrice;
  final double packagingAddon;
  final double transportationAddon;
  final double handlingAddon;
  final double otherAddons;
  final double totalLandedCost;
  final double catalogRetailPrice;
  final double grossMarginAmount; // catalogRetailPrice - totalLandedCost
  final double grossMarginPercent; // (grossMarginAmount / catalogRetailPrice) * 100
  final double totalUnitsOnHand;
  final double totalInventoryValuation; // totalUnitsOnHand * totalLandedCost

  // Sales Performance (Recovered Revenue via Packages)
  final int quantitySold; // Total physical units delivered across orders
  final double valueSold; // Total monetary revenue recovered by selling packages (sum of order amounts)
  final int deliveredOrdersCount;
  final int failedOrdersCount;
  final int totalOrdersCount;

  // Operational Cost Deductions (Dynamic from onboarding client tariffs)
  final double deliveryFeeRate; // Negotiated delivery fee per order (e.g. ₦5,000)
  final double totalDeliveryFees; // deliveredOrdersCount * deliveryFeeRate
  final double failedFeeRate; // Negotiated failed delivery charge (e.g. ₦500 / ₦1,000)
  final double totalFailedFees; // failedOrdersCount * failedFeeRate
  final double platformChargeRate; // Platform fee value per transaction or %
  final String platformFeeType; // 'flat' or 'percent'
  final double totalPlatformCharges; // Total platform fee deducted
  final double totalOperationsCost; // totalDeliveryFees + totalFailedFees + totalPlatformCharges

  // Realized Accounting Profitability
  final double cogsDispatched; // quantitySold * totalLandedCost
  final double netRealizedProfit; // valueSold - cogsDispatched - totalOperationsCost
  final double netMarginPercent; // (netRealizedProfit / valueSold) * 100

  const ClientUnitEconomics({
    required this.productName,
    required this.productSku,
    required this.baseSupplierPrice,
    this.packagingAddon = 0.0,
    this.transportationAddon = 0.0,
    this.handlingAddon = 0.0,
    this.otherAddons = 0.0,
    required this.totalLandedCost,
    required this.catalogRetailPrice,
    required this.grossMarginAmount,
    required this.grossMarginPercent,
    this.totalUnitsOnHand = 0.0,
    this.totalInventoryValuation = 0.0,
    this.quantitySold = 0,
    this.valueSold = 0.0,
    this.deliveredOrdersCount = 0,
    this.failedOrdersCount = 0,
    this.totalOrdersCount = 0,
    this.deliveryFeeRate = 5000.0,
    this.totalDeliveryFees = 0.0,
    this.failedFeeRate = 500.0,
    this.totalFailedFees = 0.0,
    this.platformChargeRate = 500.0,
    this.platformFeeType = 'flat',
    this.totalPlatformCharges = 0.0,
    this.totalOperationsCost = 0.0,
    this.cogsDispatched = 0.0,
    this.netRealizedProfit = 0.0,
    this.netMarginPercent = 0.0,
  });

  factory ClientUnitEconomics.calculate({
    required String productName,
    required String productSku,
    required double baseSupplierPrice,
    double packagingAddon = 0.0,
    double transportationAddon = 0.0,
    double handlingAddon = 0.0,
    double otherAddons = 0.0,
    required double catalogRetailPrice,
    double totalUnitsOnHand = 0.0,
    int quantitySold = 0,
    double valueSold = 0.0,
    int deliveredOrdersCount = 0,
    int failedOrdersCount = 0,
    int totalOrdersCount = 0,
    double deliveryFeeRate = 5000.0,
    double failedFeeRate = 500.0,
    double platformChargeRate = 500.0,
    String platformFeeType = 'flat',
  }) {
    final landed = baseSupplierPrice + packagingAddon + transportationAddon + handlingAddon + otherAddons;
    final marginAmt = catalogRetailPrice - landed;
    final marginPct = catalogRetailPrice > 0 ? (marginAmt / catalogRetailPrice) * 100.0 : 0.0;
    final val = totalUnitsOnHand * landed;

    // Operational cost breakdown
    final deliveryFees = deliveredOrdersCount * deliveryFeeRate;
    final failedFees = failedOrdersCount * failedFeeRate;
    final isPercent = platformFeeType.toLowerCase().startsWith('percent');
    final platformCharges = isPercent
        ? (valueSold * (platformChargeRate / 100.0))
        : (deliveredOrdersCount * platformChargeRate);
    final totalOps = deliveryFees + failedFees + platformCharges;

    // Realized Net Profit
    final cogs = quantitySold * landed;
    final netProfit = valueSold - cogs - totalOps;
    final netMargin = valueSold > 0 ? (netProfit / valueSold) * 100.0 : 0.0;

    return ClientUnitEconomics(
      productName: productName,
      productSku: productSku,
      baseSupplierPrice: baseSupplierPrice,
      packagingAddon: packagingAddon,
      transportationAddon: transportationAddon,
      handlingAddon: handlingAddon,
      otherAddons: otherAddons,
      totalLandedCost: landed,
      catalogRetailPrice: catalogRetailPrice,
      grossMarginAmount: marginAmt,
      grossMarginPercent: marginPct,
      totalUnitsOnHand: totalUnitsOnHand,
      totalInventoryValuation: val,
      quantitySold: quantitySold,
      valueSold: valueSold,
      deliveredOrdersCount: deliveredOrdersCount,
      failedOrdersCount: failedOrdersCount,
      totalOrdersCount: totalOrdersCount,
      deliveryFeeRate: deliveryFeeRate,
      totalDeliveryFees: deliveryFees,
      failedFeeRate: failedFeeRate,
      totalFailedFees: failedFees,
      platformChargeRate: platformChargeRate,
      platformFeeType: platformFeeType,
      totalPlatformCharges: platformCharges,
      totalOperationsCost: totalOps,
      cogsDispatched: cogs,
      netRealizedProfit: netProfit,
      netMarginPercent: netMargin,
    );
  }
}
