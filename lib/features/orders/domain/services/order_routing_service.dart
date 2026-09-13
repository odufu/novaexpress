import 'package:novexps/features/dc_console/domain/entities/dc_fleet_driver.dart';
import 'package:novexps/features/dc_console/domain/entities/distribution_center.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/stock/domain/entities/rider_stock_allocation.dart';

enum RoutingStatus {
  assignedToRider,
  routedToDcOnly,
  unrouted,
}

class OrderRoutingResult {
  final RoutingStatus status;
  final DistributionCenter? distributionCenter;
  final DCFleetDriver? driver;
  final String dispatchDiagnosis;
  final int availableRiderStock;
  final OrderEntity routedOrder;

  const OrderRoutingResult({
    required this.status,
    this.distributionCenter,
    this.driver,
    required this.dispatchDiagnosis,
    this.availableRiderStock = 0,
    required this.routedOrder,
  });

  bool get isAssignedToRider => status == RoutingStatus.assignedToRider && driver != null;
  bool get isRoutedToDc => distributionCenter != null;
}

class OrderRoutingService {
  /// Evaluates and auto-routes an order to the lowest level of handling matching state, LGA and vehicle stock.
  static OrderRoutingResult routeOrder({
    required OrderEntity order,
    required List<DistributionCenter> distributionCenters,
    required List<DCFleetDriver> drivers,
    required List<RiderStockAllocation> stockAllocations,
  }) {
    final orderState = order.deliveryState.trim();
    final orderLga = (order.lga ?? '').trim();
    final orderProductSku = (order.productSku ?? '').trim().toLowerCase();
    final orderProductName = order.productName.trim().toLowerCase();
    final requiredQty = order.quantity > 0 ? order.quantity : 1;

    // 1. Match Distribution Center by State and LGA
    DistributionCenter? matchedDc;

    // A. Priority 1: Exact state and LGA coverage match
    final lgaMatchingDcs = distributionCenters.where((dc) {
      if (!dc.isActive) return false;
      return dc.coversLocation(stateName: orderState, lgaName: orderLga);
    }).toList();

    if (lgaMatchingDcs.isNotEmpty) {
      // Pick specific hub or first matching LGA DC
      matchedDc = lgaMatchingDcs.firstWhere((dc) => dc.isHub, orElse: () => lgaMatchingDcs.first);
    } else {
      // B. Priority 2: State-level match across regional DCs in this state
      final stateMatchingDcs = distributionCenters.where((dc) {
        if (!dc.isActive) return false;
        return dc.coversLocation(stateName: orderState, lgaName: '');
      }).toList();

      if (stateMatchingDcs.isNotEmpty) {
        matchedDc = stateMatchingDcs.firstWhere((dc) => dc.isHub, orElse: () => stateMatchingDcs.first);
      }
    }

    // FALLBACK A: No DC matched -> Route to Grand DC HQ for manual triage
    if (matchedDc == null) {
      DistributionCenter? grandDc;
      try {
        grandDc = distributionCenters.firstWhere(
          (dc) => dc.isGrandDc && dc.isActive,
          orElse: () => distributionCenters.firstWhere(
            (dc) => dc.isHub && dc.isActive,
            orElse: () => distributionCenters.first,
          ),
        );
      } catch (_) {
        grandDc = null;
      }

      final routedOrder = order.copyWith(
        distributionCenterId: grandDc?.id,
        deliveryAgentId: null,
        deliveryAgentName: null,
        deliveryAgentCode: null,
        deliveryAgentPhone: null,
        status: 'pending_dispatch',
      );

      return OrderRoutingResult(
        status: RoutingStatus.unrouted,
        distributionCenter: grandDc,
        dispatchDiagnosis: grandDc != null
            ? '🚨 Escalated to Grand DC (${grandDc.name}). No regional DC configured for State: "$orderState", LGA: "$orderLga".'
            : 'No distribution center found covering ${order.deliveryState} (LGA: ${order.lga ?? "N/A"}).',
        routedOrder: routedOrder,
      );
    }

    // 2. Find eligible active riders under this DC covering the LGA
    final eligibleDrivers = drivers.where((d) {
      if (!d.isActive) return false;
      // If driver is tied to a specific DC, ensure DC ID matches
      if (d.distributionCenterId != null && d.distributionCenterId!.isNotEmpty && d.distributionCenterId != matchedDc!.id) {
        return false;
      }
      // Check if driver covers this LGA
      return d.coversLga(orderLga);
    }).toList();

    if (eligibleDrivers.isEmpty) {
      // Route to DC only (no matching rider covering this LGA)
      final routedOrder = order.copyWith(
        distributionCenterId: matchedDc.id,
        deliveryAgentId: null,
        deliveryAgentName: null,
        deliveryAgentCode: null,
        deliveryAgentPhone: null,
        status: 'pending_dispatch',
      );

      return OrderRoutingResult(
        status: RoutingStatus.routedToDcOnly,
        distributionCenter: matchedDc,
        dispatchDiagnosis: '⚠️ Routed to ${matchedDc.name} (${matchedDc.code}). Awaiting manual rider assignment for LGA: "$orderLga".',
        routedOrder: routedOrder,
      );
    }

    // 3. Stock Check: Filter riders who have sufficient stock for the ordered product if stock records are supplied
    DCFleetDriver? bestDriver;
    int bestStockCount = 0;

    if (stockAllocations.isEmpty) {
      // Pure geographic State/LGA multi-zone routing
      bestDriver = eligibleDrivers.first;
      bestStockCount = 0;
    } else {
      for (final driver in eligibleDrivers) {
        // Calculate rider's current custody count for the requested product
        final driverAllocations = stockAllocations.where((a) {
          if (a.riderId != driver.id && a.riderName.toLowerCase() != driver.name.toLowerCase()) {
            return false;
          }

          final skuMatches = orderProductSku.isNotEmpty && a.sku.trim().toLowerCase() == orderProductSku;
          final nameMatches = a.productName.trim().toLowerCase().contains(orderProductName) ||
              orderProductName.contains(a.productName.trim().toLowerCase());

          return skuMatches || nameMatches;
        }).toList();

        final currentCustody = driverAllocations.fold<int>(0, (sum, a) => sum + a.inCustodyUnits);

        // Strict enforcement: Rider must have >= order quantity
        if (currentCustody >= requiredQty) {
          if (bestDriver == null || currentCustody > bestStockCount) {
            bestDriver = driver;
            bestStockCount = currentCustody;
          }
        }
      }
    }

    if (bestDriver != null) {
      // Successfully auto-assigned to lowest level handler with stock!
      final routedOrder = order.copyWith(
        distributionCenterId: matchedDc.id,
        deliveryAgentId: bestDriver.id,
        deliveryAgentName: bestDriver.name,
        deliveryAgentCode: bestDriver.driverCode,
        deliveryAgentPhone: bestDriver.phone,
        status: 'assigned',
        assignedAt: DateTime.now(),
      );

      return OrderRoutingResult(
        status: RoutingStatus.assignedToRider,
        distributionCenter: matchedDc,
        driver: bestDriver,
        availableRiderStock: bestStockCount,
        dispatchDiagnosis: 'Auto-assigned to ${bestDriver.name} ($bestStockCount units in custody for LGA "$orderLga").',
        routedOrder: routedOrder,
      );
    } else {
      // Eligible riders exist in LGA, but none have sufficient stock
      final routedOrder = order.copyWith(
        distributionCenterId: matchedDc.id,
        deliveryAgentId: null,
        deliveryAgentName: null,
        deliveryAgentCode: null,
        deliveryAgentPhone: null,
        status: 'pending_dispatch',
      );

      return OrderRoutingResult(
        status: RoutingStatus.routedToDcOnly,
        distributionCenter: matchedDc,
        dispatchDiagnosis: 'Routed to ${matchedDc.name} (${matchedDc.code}). ${eligibleDrivers.length} rider(s) cover LGA "$orderLga", but none have sufficient vehicle stock ($requiredQty needed) for "${order.productName}".',
        routedOrder: routedOrder,
      );
    }
  }

  /// Validates whether a manual assignment to a rider is safe from a stock perspective
  static bool validateManualAssignmentStock({
    required OrderEntity order,
    required DCFleetDriver driver,
    required List<RiderStockAllocation> stockAllocations,
  }) {
    final orderProductSku = (order.productSku ?? '').trim().toLowerCase();
    final orderProductName = order.productName.trim().toLowerCase();
    final requiredQty = order.quantity > 0 ? order.quantity : 1;

    final driverAllocations = stockAllocations.where((a) {
      if (a.riderId != driver.id && a.riderName.toLowerCase() != driver.name.toLowerCase()) {
        return false;
      }
      final skuMatches = orderProductSku.isNotEmpty && a.sku.trim().toLowerCase() == orderProductSku;
      final nameMatches = a.productName.trim().toLowerCase().contains(orderProductName) ||
          orderProductName.contains(a.productName.trim().toLowerCase());
      return skuMatches || nameMatches;
    }).toList();

    final currentCustody = driverAllocations.fold<int>(0, (sum, a) => sum + a.inCustodyUnits);
    return currentCustody >= requiredQty;
  }

  /// Determines whether a given order belongs to [currentDc].
  ///
  /// Business Rules:
  /// 1. Regional DC (Dedicated, non-Grand DC, e.g. Otukpo DC):
  ///    - An order belongs to this Regional DC if:
  ///      a) order.distributionCenterId matches currentDc.id or currentDc.code, OR
  ///      b) order.distributionCenterId is null/empty AND currentDc covers the order's state & LGA.
  ///    - An order NEVER belongs to this Regional DC if:
  ///      - It is assigned to a different DC, OR
  ///      - Its delivery location (State / LGA) is outside this Regional DC's coverage.
  ///
  /// 2. Grand DC (Primary Hub Headquarters, e.g. Wuse Central / Abuja Main DC):
  ///    - If an active dedicated Regional DC exists in [allDcs] that handles the order's State / LGA
  ///      (e.g. Otukpo DC covering Benue):
  ///      -> The order belongs to that Regional DC and MUST NOT show in the Grand DC!
  ///    - The order DOES show in the Grand DC if:
  ///      a) It targets the Grand DC's own geographic jurisdiction (e.g. Abuja / FCT), OR
  ///      b) There is NO dedicated regional DC configured in [allDcs] to handle that State / LGA
  ///         (unrouted/orphan orders escalate to Grand DC HQ for manual triage).
  static bool doesOrderBelongToDc({
    required OrderEntity order,
    required DistributionCenter currentDc,
    required List<DistributionCenter> allDcs,
  }) {
    final orderDcId = order.distributionCenterId?.trim() ?? '';
    final orderState = order.deliveryState.trim();
    final orderLga = (order.deliveryLga ?? order.lga ?? '').trim();

    // Find Grand DC if available
    final grandDc = allDcs.where((d) => d.isGrandDc && d.isActive).firstOrNull ??
        allDcs.where((d) => d.isHub && d.isActive).firstOrNull;
    final grandDcId = grandDc?.id ?? '22222222-2222-4222-8222-222222222222';
    final grandDcCode = grandDc?.code ?? 'DC-WUSE-01';

    // 1. Regional DC (Dedicated, non-Grand DC, e.g. Otukpo DC)
    if (!currentDc.isGrandDc) {
      // A. Explicit assignment to this Regional DC
      if (orderDcId.isNotEmpty &&
          (orderDcId == currentDc.id || orderDcId == currentDc.code)) {
        return true;
      }

      // B. If assigned to another regional DC, it belongs to that other DC
      if (orderDcId.isNotEmpty &&
          orderDcId != currentDc.id &&
          orderDcId != currentDc.code &&
          orderDcId != grandDcId &&
          orderDcId != grandDcCode) {
        return false;
      }

      // C. Unassigned or tagged with Grand DC fallback:
      // Does this regional DC cover the order's State & LGA?
      return currentDc.coversLocation(stateName: orderState, lgaName: orderLga);
    }

    // 2. Grand DC (Hub Headquarters, e.g. Abuja Main DC)
    // Check if there is an active, dedicated Regional DC covering this order's destination
    final dedicatedRegionalDc = allDcs.where((dc) {
      if (dc.id == currentDc.id || dc.isGrandDc || !dc.isActive) return false;
      // If order is explicitly tagged to this regional DC
      if (orderDcId.isNotEmpty && (orderDcId == dc.id || orderDcId == dc.code)) {
        return true;
      }
      // Or if this regional DC covers the order's State and LGA
      return dc.coversLocation(stateName: orderState, lgaName: orderLga);
    }).firstOrNull;

    if (dedicatedRegionalDc != null) {
      // A dedicated regional DC exists and handles this order -> MUST NOT show in Grand DC!
      return false;
    }

    // If order was explicitly assigned to another DC that is not this Grand DC
    if (orderDcId.isNotEmpty &&
        orderDcId != currentDc.id &&
        orderDcId != currentDc.code) {
      return false;
    }

    // Order targets Grand DC's own territory (e.g. Abuja) OR has no dedicated DC anywhere
    return true;
  }
}
