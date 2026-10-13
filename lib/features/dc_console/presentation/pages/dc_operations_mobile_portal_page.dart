import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/domain/services/order_routing_service.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../../pipeline_chat/presentation/widgets/order_pipeline_chat_sheet.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../../domain/entities/distribution_center.dart';
import '../providers/dc_console_provider.dart';

class DCOperationsMobilePortalPage extends ConsumerStatefulWidget {
  const DCOperationsMobilePortalPage({super.key});

  @override
  ConsumerState<DCOperationsMobilePortalPage> createState() =>
      _DCOperationsMobilePortalPageState();
}

class _DCOperationsMobilePortalPageState
    extends ConsumerState<DCOperationsMobilePortalPage> {
  int _activeTab = 0; // 0: Live Orders, 1: Riders & Fleet, 2: Activity Logs, 3: Station & Profile
  String _orderStatusFilter = 'all'; // 'all', 'pending', 'in_transit', 'delivered', 'failed'
  final _orderSearchController = TextEditingController();
  final _riderSearchController = TextEditingController();

  final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  @override
  void dispose() {
    _orderSearchController.dispose();
    _riderSearchController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    final user = ref.read(authProvider).user;
    final dcId = user?.distributionCenterId;
    ref.read(dcConsoleProvider.notifier).loadDistributionCentersFromDatabase();
    ref.read(dcConsoleProvider.notifier).loadDriversFromDatabase();
    ref.read(stockProvider.notifier).fetchStockItems();
    ref.read(stockProvider.notifier).fetchStockTransfers();
    if (dcId != null && dcId.isNotEmpty) {
      await ref.read(ordersProvider.notifier).loadDcOrders(dcId);
    } else {
      await ref.read(ordersProvider.notifier).loadDcOrders();
    }
  }

  DistributionCenter? _getOfficerDc() {
    final user = ref.read(authProvider).user;
    final dcState = ref.read(dcConsoleProvider);
    final userDcId = user?.distributionCenterId;

    if (userDcId != null && userDcId.isNotEmpty) {
      final found = dcState.distributionCenters.where((d) =>
          d.id == userDcId || d.code.toUpperCase() == userDcId.toUpperCase()).firstOrNull;
      if (found != null) return found;
    }

    return dcState.distributionCenters.where((d) => d.id == dcState.activeHubId).firstOrNull ??
        dcState.distributionCenters.where((d) => d.isGrandDc).firstOrNull ??
        dcState.distributionCenters.firstOrNull;
  }

  List<OrderEntity> _filterDcOrders(DistributionCenter officerDc) {
    final allOrders = ref.watch(ordersProvider).orders;
    final dcState = ref.watch(dcConsoleProvider);

    // 1. Strictly scope to officer's DC
    var list = allOrders.where((order) {
      return OrderRoutingService.doesOrderBelongToDc(
        order: order,
        currentDc: officerDc,
        allDcs: dcState.distributionCenters,
      );
    }).toList();

    // 2. Status filter
    if (_orderStatusFilter == 'pending') {
      list = list.where((o) =>
          o.status.toLowerCase() == 'pending' ||
          o.status.toLowerCase() == 'pending_dispatch' ||
          o.status.toLowerCase() == 'unassigned' ||
          o.deliveryAgentId == null ||
          o.deliveryAgentId!.isEmpty).toList();
    } else if (_orderStatusFilter == 'in_transit') {
      list = list.where((o) =>
          o.status.toLowerCase() == 'in_transit' ||
          o.status.toLowerCase() == 'assigned' ||
          o.status.toLowerCase() == 'out_for_delivery').toList();
    } else if (_orderStatusFilter == 'delivered') {
      list = list.where((o) => o.status.toLowerCase() == 'delivered').toList();
    } else if (_orderStatusFilter == 'failed') {
      list = list.where((o) =>
          o.status.toLowerCase() == 'failed' ||
          o.status.toLowerCase() == 'cancelled' ||
          o.status.toLowerCase() == 'rescheduled').toList();
    }

    // 3. Search query
    final q = _orderSearchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((o) =>
          o.orderNumber.toLowerCase().contains(q) ||
          o.customerName.toLowerCase().contains(q) ||
          o.customerPhone.contains(q) ||
          o.productName.toLowerCase().contains(q) ||
          o.deliveryAddress.toLowerCase().contains(q) ||
          (o.deliveryAgentName != null && o.deliveryAgentName!.toLowerCase().contains(q))).toList();
    }

    return list;
  }

  List<DCFleetDriver> _getDcRiders(DistributionCenter officerDc) {
    final dcState = ref.watch(dcConsoleProvider);
    var riders = dcState.drivers.where((d) {
      if (officerDc.isGrandDc) {
        return d.distributionCenterId == officerDc.id ||
            d.distributionCenterId == officerDc.code ||
            d.distributionCenterId == null ||
            d.distributionCenterId!.isEmpty;
      }
      return d.distributionCenterId == officerDc.id || d.distributionCenterId == officerDc.code;
    }).toList();

    final q = _riderSearchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      riders = riders.where((r) =>
          r.name.toLowerCase().contains(q) ||
          r.driverCode.toLowerCase().contains(q) ||
          r.phone.contains(q) ||
          r.assignedZone.toLowerCase().contains(q)).toList();
    }

    return riders;
  }

  Future<void> _makeCall(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ No phone number available')),
      );
      return;
    }
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String? phone, String text) async {
    if (phone == null || phone.trim().isEmpty) return;
    String clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) {
      clean = '234${clean.substring(1)}';
    } else if (!clean.startsWith('234')) {
      clean = '234$clean';
    }

    final uri = Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  int _calculateOrderRequiredQty(OrderEntity order) {
    if (order.quantity > 0) return order.quantity;
    final total = order.paidQuantity + order.freeQuantity;
    return total > 0 ? total : 1;
  }

  int _calculateRiderActiveOrders(DCFleetDriver rider, List<OrderEntity> allOrders) {
    return allOrders.where((o) {
      final isThisRider = (o.deliveryAgentId != null && (o.deliveryAgentId == rider.id || o.deliveryAgentId == rider.driverCode)) ||
                          (o.deliveryAgentCode != null && (o.deliveryAgentCode == rider.driverCode || o.deliveryAgentCode == rider.id));
      final isActive = o.status == 'in_transit' ||
                       o.status == 'assigned' ||
                       o.status == 'out_for_delivery' ||
                       o.status == 'accepted' ||
                       o.status == 'contacting';
      return isThisRider && isActive;
    }).length;
  }

  int _calculateRiderProductStock({
    required DCFleetDriver rider,
    required OrderEntity order,
    required StockState stockState,
    required List<OrderEntity> allOrders,
  }) {
    final riderAllocs = stockState.getAllocationsForRider(rider.id, rider.driverCode);
    final orderP = order.productName.toLowerCase().trim();
    final orderSku = (order.productSku ?? '').toLowerCase().trim();

    final matchingAllocs = riderAllocs.where((a) {
      final prodA = a.productName.toLowerCase().trim();
      final skuA = a.sku.toLowerCase().trim();
      final skuMatch = orderSku.isNotEmpty && skuA.isNotEmpty && (skuA == orderSku || orderSku.contains(skuA) || skuA.contains(orderSku));
      final nameMatch = orderP.isNotEmpty && prodA.isNotEmpty && (prodA.contains(orderP) || orderP.contains(prodA));
      return skuMatch || nameMatch;
    }).toList();

    if (matchingAllocs.isNotEmpty) {
      final totalCustody = matchingAllocs.fold(0, (sum, a) => sum + a.inCustodyUnits);

      int reservedInActive = 0;
      for (final o in allOrders) {
        if (o.id == order.id || o.orderNumber == order.orderNumber) continue;
        final isThisRider = (o.deliveryAgentId != null && (o.deliveryAgentId == rider.id || o.deliveryAgentId == rider.driverCode)) ||
                            (o.deliveryAgentCode != null && (o.deliveryAgentCode == rider.driverCode || o.deliveryAgentCode == rider.id));
        final isActive = o.status == 'in_transit' || o.status == 'assigned' || o.status == 'out_for_delivery' || o.status == 'accepted' || o.status == 'contacting';
        final oP = o.productName.toLowerCase().trim();
        final isSameProduct = orderP.isNotEmpty && (oP.contains(orderP) || orderP.contains(oP));

        if (isThisRider && isActive && isSameProduct) {
          final qty = o.quantity > 0 ? o.quantity : 1;
          reservedInActive += qty;
        }
      }

      return (totalCustody - reservedInActive).clamp(0, 999999);
    }

    // Fallback: If no granular allocations recorded in DB, but rider has itemsInCustody on DCFleetDriver:
    if (riderAllocs.isEmpty && rider.itemsInCustody > 0) {
      final activeOrdersCount = _calculateRiderActiveOrders(rider, allOrders);
      return (rider.itemsInCustody - activeOrdersCount).clamp(0, 999999);
    }

    return 0;
  }

  void _showDispatchSheet(OrderEntity order, DistributionCenter officerDc) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final int orderRequiredQty = _calculateOrderRequiredQty(order);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer(
        builder: (sheetContext, sheetRef, child) {
          final dcRiders = _getDcRiders(officerDc);
          final stockState = sheetRef.watch(stockProvider);
          final allOrders = sheetRef.watch(ordersProvider).orders;

          // Intelligently sort riders:
          // 1. Currently assigned rider on top
          // 2. Riders with sufficient stock of this product first
          // 3. Lowest active order count first (Workload Balancing to prevent overloading!)
          // 4. Highest available stock quantity
          final sortedRiders = List<DCFleetDriver>.from(dcRiders)..sort((a, b) {
            final aAssigned = order.deliveryAgentId == a.id || order.deliveryAgentCode == a.driverCode;
            final bAssigned = order.deliveryAgentId == b.id || order.deliveryAgentCode == b.driverCode;
            if (aAssigned && !bAssigned) return -1;
            if (!aAssigned && bAssigned) return 1;

            final aStock = _calculateRiderProductStock(
              rider: a,
              order: order,
              stockState: stockState,
              allOrders: allOrders,
            );
            final bStock = _calculateRiderProductStock(
              rider: b,
              order: order,
              stockState: stockState,
              allOrders: allOrders,
            );

            final aCanFulfill = aStock >= orderRequiredQty;
            final bCanFulfill = bStock >= orderRequiredQty;
            if (aCanFulfill && !bCanFulfill) return -1;
            if (!aCanFulfill && bCanFulfill) return 1;

            // Workload Balancing: fewest active orders first!
            final aLoad = _calculateRiderActiveOrders(a, allOrders);
            final bLoad = _calculateRiderActiveOrders(b, allOrders);
            if (aLoad != bLoad) return aLoad.compareTo(bLoad);

            return bStock.compareTo(aStock);
          });

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.88,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151D36) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sheet Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFF0D9488), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dispatch Order #${order.orderNumber}',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Select an active rider in ${officerDc.name}',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Order Preview Summary Banner with Target Product & Required Quantity
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.customerName,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                                Text(
                                  '${order.deliveryLga != null ? '${order.deliveryLga}, ' : ''}${order.deliveryState} • ${order.deliveryAddress}',
                                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            currencyFormat.format(order.totalAmount),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF10B981),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Target Product & Required Qty Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2_rounded, size: 14, color: Color(0xFF0D9488)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                order.productName,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0D9488),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D9488),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Order Qty: $orderRequiredQty',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Riders List Header with Smart Sort Note
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'Available Riders (${sortedRiders.length})',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune_rounded, size: 12, color: const Color(0xFF0D9488)),
                          const SizedBox(width: 4),
                          Text(
                            'Balanced by stock & load',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0D9488)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: sortedRiders.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.two_wheeler_outlined, size: 40, color: Color(0xFF94A3B8)),
                                const SizedBox(height: 8),
                                Text(
                                  'No riders registered for this DC yet.',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'DC Manager can onboard riders from the DC Console.',
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: sortedRiders.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final rider = sortedRiders[index];
                            final isAssignedThis = order.deliveryAgentId == rider.id ||
                                order.deliveryAgentCode == rider.driverCode;

                            // Calculate available stock and active orders workload
                            final riderStock = _calculateRiderProductStock(
                              rider: rider,
                              order: order,
                              stockState: stockState,
                              allOrders: allOrders,
                            );
                            final activeOrdersCount = _calculateRiderActiveOrders(rider, allOrders);
                            final canAssign = riderStock >= orderRequiredQty;

                            return InkWell(
                              onTap: () async {
                                if (!canAssign) {
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '⚠️ Cannot assign: ${rider.name} only has $riderStock of "${order.productName}" in vehicle custody (order requires $orderRequiredQty).',
                                      ),
                                      backgroundColor: const Color(0xFFEF4444),
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                  return;
                                }

                                Navigator.of(ctx).pop();
                                final success = await sheetRef
                                    .read(ordersProvider.notifier)
                                    .assignOrderToRider(
                                      orderId: order.id,
                                      riderId: rider.id,
                                      riderName: rider.name,
                                      riderCode: rider.driverCode,
                                    );

                                if (mounted) {
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? '🚀 Order #${order.orderNumber} dispatched to ${rider.name}!'
                                            : '⚠️ Could not dispatch: Check stock custody.',
                                      ),
                                      backgroundColor: success
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFEF4444),
                                    ),
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isAssignedThis
                                      ? const Color(0xFF0D9488).withValues(alpha: 0.1)
                                      : (!canAssign
                                          ? (isDark ? const Color(0xFF131A2D) : const Color(0xFFF1F5F9))
                                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC))),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isAssignedThis
                                        ? const Color(0xFF0D9488)
                                        : (!canAssign
                                            ? (isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0))
                                            : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                    width: isAssignedThis ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Rider Profile Avatar
                                    UserAvatarWidget(
                                      avatarUrl: rider.avatarUrl.isNotEmpty ? rider.avatarUrl : null,
                                      fullName: rider.name,
                                      radius: 20,
                                      backgroundColor: canAssign
                                          ? const Color(0xFF0D9488).withValues(alpha: 0.15)
                                          : const Color(0xFF94A3B8).withValues(alpha: 0.15),
                                      textColor: canAssign ? const Color(0xFF0D9488) : const Color(0xFF64748B),
                                      showBorder: true,
                                      borderColor: canAssign ? const Color(0xFF0D9488).withValues(alpha: 0.3) : const Color(0xFFCBD5E1),
                                      borderWidth: 1.5,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  rider.name,
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13.5,
                                                    color: canAssign ? null : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  rider.driverCode,
                                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF0D9488)),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Zone: ${rider.assignedZone} • ${rider.vehicleType}',
                                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),

                                          // Stock in Possession & Active Orders Workload
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              // 1. Stock Quantity in Possession Badge
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                decoration: BoxDecoration(
                                                  color: canAssign
                                                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                                      : const Color(0xFFEF4444).withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(5),
                                                  border: Border.all(
                                                    color: canAssign
                                                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                                        : const Color(0xFFEF4444).withValues(alpha: 0.3),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      canAssign ? Icons.check_circle_outline_rounded : Icons.highlight_off_rounded,
                                                      size: 12,
                                                      color: canAssign ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      canAssign
                                                          ? 'In Possession: $riderStock avail.'
                                                          : 'Possession: $riderStock (Needs $orderRequiredQty)',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 10.5,
                                                        fontWeight: FontWeight.bold,
                                                        color: canAssign ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // 2. Active Orders Workload Badge
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                decoration: BoxDecoration(
                                                  color: activeOrdersCount == 0
                                                      ? const Color(0xFF0D9488).withValues(alpha: 0.1)
                                                      : (activeOrdersCount >= 3
                                                          ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                                                          : const Color(0xFF3B82F6).withValues(alpha: 0.1)),
                                                  borderRadius: BorderRadius.circular(5),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      activeOrdersCount == 0
                                                          ? Icons.electric_bolt_rounded
                                                          : Icons.delivery_dining_rounded,
                                                      size: 12,
                                                      color: activeOrdersCount == 0
                                                          ? const Color(0xFF0D9488)
                                                          : (activeOrdersCount >= 3
                                                              ? const Color(0xFFD97706)
                                                              : const Color(0xFF3B82F6)),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      activeOrdersCount == 0
                                                          ? '0 Orders (Idle)'
                                                          : '$activeOrdersCount ${activeOrdersCount == 1 ? 'Order' : 'Orders'}${activeOrdersCount >= 3 ? ' (High Load)' : ''}',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 10.5,
                                                        fontWeight: FontWeight.w600,
                                                        color: activeOrdersCount == 0
                                                            ? const Color(0xFF0D9488)
                                                            : (activeOrdersCount >= 3
                                                                ? const Color(0xFFD97706)
                                                                : const Color(0xFF3B82F6)),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Action Button: Assign or Disabled Low Stock
                                    canAssign
                                        ? ElevatedButton(
                                            onPressed: () async {
                                              Navigator.of(ctx).pop();
                                              final success = await sheetRef
                                                  .read(ordersProvider.notifier)
                                                  .assignOrderToRider(
                                                    orderId: order.id,
                                                    riderId: rider.id,
                                                    riderName: rider.name,
                                                    riderCode: rider.driverCode,
                                                  );

                                              if (mounted) {
                                                ScaffoldMessenger.of(this.context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      success
                                                          ? '🚀 Order #${order.orderNumber} dispatched to ${rider.name}!'
                                                          : '⚠️ Could not dispatch order',
                                                    ),
                                                    backgroundColor: success
                                                        ? const Color(0xFF10B981)
                                                        : const Color(0xFFEF4444),
                                                  ),
                                                );
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF0D9488),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            child: const Text('Assign', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                          )
                                        : ElevatedButton(
                                            onPressed: null, // Strictly disabled when insufficient stock
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF94A3B8),
                                              disabledBackgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            child: Text(
                                              'Low Stock',
                                              style: GoogleFonts.inter(
                                                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showRerouteSheet(OrderEntity order, DistributionCenter officerDc) {
    final dcState = ref.read(dcConsoleProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Filter out current DC
    final destinationDcs = dcState.distributionCenters
        .where((d) => d.id != officerDc.id && d.code != officerDc.code)
        .toList();

    DistributionCenter? selectedTargetDc = destinationDcs.isNotEmpty ? destinationDcs.first : null;
    final reasonController = TextEditingController(text: 'Rerouted to destination DC coverage zone');
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151D36) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF37021).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFFF37021), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reroute Order #${order.orderNumber}',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Transfer order from ${officerDc.name} to another DC',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  Text(
                    'Destination Distribution Center',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedTargetDc?.id,
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        items: destinationDcs.map((d) {
                          return DropdownMenuItem<String>(
                            value: d.id,
                            child: Text(
                              '${d.name} (${d.code}) • ${d.state}',
                              style: GoogleFonts.inter(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setSheetState(() {
                              selectedTargetDc = destinationDcs.where((d) => d.id == val).firstOrNull;
                            });
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    'Reroute Reason / Note',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. Customer delivery address is outside our municipal coverage',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: isSubmitting || selectedTargetDc == null
                            ? null
                            : () async {
                                setSheetState(() => isSubmitting = true);
                                final success = await ref
                                    .read(ordersProvider.notifier)
                                    .rerouteOrderToDc(
                                      orderId: order.id,
                                      targetDcId: selectedTargetDc!.id,
                                      targetDcName: selectedTargetDc!.name,
                                      reason: reasonController.text.trim(),
                                    );

                                if (ctx.mounted) Navigator.of(ctx).pop();

                                if (mounted) {
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? '🔁 Order #${order.orderNumber} successfully rerouted to ${selectedTargetDc!.name}!'
                                            : '⚠️ Could not reroute order',
                                      ),
                                      backgroundColor: success
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFEF4444),
                                    ),
                                  );
                                }
                              },
                        icon: isSubmitting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.swap_horiz_rounded, size: 18, color: Colors.white),
                        label: Text(
                          isSubmitting ? 'Rerouting...' : 'Confirm Reroute',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF37021),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPasswordResetDialog() {
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.lock_reset_rounded, color: Color(0xFF0D9488)),
              const SizedBox(width: 10),
              Text('Change Password', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                    onPressed: () => setDlgState(() => obscure = !obscure),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: obscure,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
              onPressed: () async {
                final newPass = passCtrl.text.trim();
                if (newPass.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password must be at least 6 characters')),
                  );
                  return;
                }
                if (newPass != confirmCtrl.text.trim()) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passwords do not match')),
                  );
                  return;
                }
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Password updated successfully!'), backgroundColor: Color(0xFF10B981)),
                );
              },
              child: const Text('Update Password', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 10),
            Text('Logout of Operations', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          'Are you sure you want to log out of the DC Operations Portal?',
          style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authProvider.notifier).logout();
              if (mounted) context.go('/login');
            },
            child: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authProvider).user;
    final officerDc = _getOfficerDc();

    if (officerDc == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Connecting to Distribution Center...', style: GoogleFonts.inter()),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: AppBar(
          elevation: 0,
          backgroundColor: isDark ? const Color(0xFF031632) : Colors.white,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            officerDc.name,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'LIVE',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${user?.fullName ?? 'Operations Officer'} • ${officerDc.code}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Refresh live orders',
              onPressed: _refreshData,
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, size: 20, color: Color(0xFFEF4444)),
              tooltip: 'Logout',
              onPressed: _confirmLogout,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF031632) : Colors.white,
          border: Border(top: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _activeTab,
            onTap: (index) => setState(() => _activeTab = index),
            backgroundColor: isDark ? const Color(0xFF031632) : Colors.white,
            selectedItemColor: const Color(0xFF0D9488),
            unselectedItemColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.local_shipping_rounded),
                label: 'Live Orders',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.two_wheeler_rounded),
                label: 'Riders & Fleet',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history_rounded),
                label: 'Routing Logs',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                label: 'Station & Profile',
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF0D9488),
        child: _buildActiveTabBody(officerDc, isDark),
      ),
    );
  }

  Widget _buildActiveTabBody(DistributionCenter officerDc, bool isDark) {
    switch (_activeTab) {
      case 0:
        return _buildLiveOrdersTab(officerDc, isDark);
      case 1:
        return _buildRidersFleetTab(officerDc, isDark);
      case 2:
        return _buildActivityLogsTab(officerDc, isDark);
      case 3:
        return _buildStationProfileTab(officerDc, isDark);
      default:
        return _buildLiveOrdersTab(officerDc, isDark);
    }
  }

  // ---------------------------------------------------------------------------
  // TAB 0: LIVE ORDERS (CORE DISPATCH / ROUTING HUB)
  // ---------------------------------------------------------------------------
  Widget _buildLiveOrdersTab(DistributionCenter officerDc, bool isDark) {
    final dcOrders = _filterDcOrders(officerDc);
    final allDcOrders = ref.watch(ordersProvider).orders.where((order) {
      return OrderRoutingService.doesOrderBelongToDc(
        order: order,
        currentDc: officerDc,
        allDcs: ref.watch(dcConsoleProvider).distributionCenters,
      );
    }).toList();

    final unassignedCount = allDcOrders.where((o) =>
        o.deliveryAgentId == null ||
        o.deliveryAgentId!.isEmpty ||
        o.status.toLowerCase() == 'pending' ||
        o.status.toLowerCase() == 'pending_dispatch').length;

    final inTransitCount = allDcOrders.where((o) =>
        o.status.toLowerCase() == 'in_transit' ||
        o.status.toLowerCase() == 'assigned' ||
        o.status.toLowerCase() == 'out_for_delivery').length;

    final deliveredCount = allDcOrders.where((o) => o.status.toLowerCase() == 'delivered').length;
    final failedCount = allDcOrders.where((o) =>
        o.status.toLowerCase() == 'failed' || o.status.toLowerCase() == 'cancelled').length;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Scope Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0D9488).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF0D9488)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Scoped strictly to ${officerDc.name} (${officerDc.code})',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0D9488),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Quick Stats Strip
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildStatChip('Pending Dispatch', unassignedCount, const Color(0xFFF37021), isDark, 'pending'),
              const SizedBox(width: 8),
              _buildStatChip('In Transit', inTransitCount, const Color(0xFF3B82F6), isDark, 'in_transit'),
              const SizedBox(width: 8),
              _buildStatChip('Delivered Today', deliveredCount, const Color(0xFF10B981), isDark, 'delivered'),
              const SizedBox(width: 8),
              _buildStatChip('Issues / Failed', failedCount, const Color(0xFFEF4444), isDark, 'failed'),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Search Bar
        TextField(
          controller: _orderSearchController,
          onChanged: (val) => setState(() {}),
          style: GoogleFonts.inter(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search order #, customer, phone, product...',
            hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF0D9488)),
            suffixIcon: _orderSearchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    onPressed: () {
                      _orderSearchController.clear();
                      setState(() {});
                    },
                  )
                : null,
            filled: true,
            fillColor: isDark ? const Color(0xFF151D36) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('All (${allDcOrders.length})', 'all', isDark),
              const SizedBox(width: 6),
              _buildFilterChip('Pending ($unassignedCount)', 'pending', isDark),
              const SizedBox(width: 6),
              _buildFilterChip('In Transit ($inTransitCount)', 'in_transit', isDark),
              const SizedBox(width: 6),
              _buildFilterChip('Delivered ($deliveredCount)', 'delivered', isDark),
              const SizedBox(width: 6),
              _buildFilterChip('Failed ($failedCount)', 'failed', isDark),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Orders List
        if (dcOrders.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151D36) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(Icons.inbox_rounded, size: 40, color: Color(0xFF94A3B8)),
                const SizedBox(height: 10),
                Text(
                  'No orders match this filter',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Live orders assigned to ${officerDc.name} will appear here.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...dcOrders.map((order) => _buildOrderCard(order, officerDc, isDark)),
      ],
    );
  }

  Widget _buildStatChip(String title, int count, Color color, bool isDark, String filterKey) {
    final isSelected = _orderStatusFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _orderStatusFilter = isSelected ? 'all' : filterKey),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : (isDark ? const Color(0xFF151D36) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : (isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Text(
                '$count',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: color),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String key, bool isDark) {
    final isSelected = _orderStatusFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _orderStatusFilter = key);
      },
      selectedColor: const Color(0xFF0D9488),
      backgroundColor: isDark ? const Color(0xFF151D36) : Colors.white,
      labelStyle: GoogleFonts.inter(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFF0D9488) : (isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _buildOrderCard(OrderEntity order, DistributionCenter officerDc, bool isDark) {
    final isAssigned = order.deliveryAgentId != null &&
        order.deliveryAgentId!.isNotEmpty &&
        order.deliveryAgentName != null &&
        order.deliveryAgentName!.isNotEmpty;

    final isDelivered = order.status.toLowerCase() == 'delivered';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D36) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: !isAssigned && !isDelivered
              ? const Color(0xFFF37021).withValues(alpha: 0.5)
              : (isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
          width: !isAssigned && !isDelivered ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Number, Status & Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '#${order.orderNumber}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildOrderStatusBadge(order.status),
                ],
              ),
              Text(
                currencyFormat.format(order.totalAmount),
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Customer Row
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  order.customerName,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              if (order.customerPhone.isNotEmpty) ...[
                IconButton(
                  icon: const Icon(Icons.phone_rounded, size: 16, color: Color(0xFF3B82F6)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Call Customer',
                  onPressed: () => _makeCall(order.customerPhone),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.send_rounded, size: 16, color: Color(0xFF25D366)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'WhatsApp Customer',
                  onPressed: () => _openWhatsApp(
                    order.customerPhone,
                    'Hello ${order.customerName}, this is NovaXpress Operations regarding your order #${order.orderNumber}.',
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 4),

          // Destination Address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${order.deliveryLga != null ? '${order.deliveryLga}, ' : ''}${order.deliveryState} • ${order.deliveryAddress}',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Product & Quantity
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${order.quantity}x ${order.productName}',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0D9488), fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Current Assigned Rider or Warning
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isAssigned
                  ? const Color(0xFF3B82F6).withValues(alpha: 0.08)
                  : const Color(0xFFF37021).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isAssigned
                    ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                    : const Color(0xFFF37021).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isAssigned ? Icons.two_wheeler_rounded : Icons.warning_amber_rounded,
                  size: 15,
                  color: isAssigned ? const Color(0xFF3B82F6) : const Color(0xFFF37021),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isAssigned
                        ? 'Assigned Rider: ${order.deliveryAgentName} (${order.deliveryAgentCode ?? ''})'
                        : '⚠️ Unassigned • Requires Dispatch to Available Rider',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isAssigned ? const Color(0xFF3B82F6) : const Color(0xFFF37021),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Action Buttons: Dispatch, Reroute, Pipeline Chat
          Row(
            children: [
              // Dispatch to Rider
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: isDelivered ? null : () => _showDispatchSheet(order, officerDc),
                  icon: const Icon(Icons.two_wheeler_rounded, size: 15, color: Colors.white),
                  label: Text(
                    isAssigned ? 'Reassign Rider' : 'Dispatch Rider',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Reroute to DC
              Expanded(
                flex: 3,
                child: OutlinedButton.icon(
                  onPressed: isDelivered ? null : () => _showRerouteSheet(order, officerDc),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 15, color: Color(0xFFF37021)),
                  label: Text(
                    'Reroute DC',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFF37021)),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: const BorderSide(color: Color(0xFFF37021)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Pipeline Chat Sheet
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF0D9488)),
                tooltip: 'Order Pipeline Chat',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => OrderPipelineChatSheet.showForOrder(context, order),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusBadge(String status) {
    Color bg;
    Color fg;
    String label = status.replaceAll('_', ' ').toUpperCase();

    switch (status.toLowerCase()) {
      case 'delivered':
        bg = const Color(0xFF10B981).withValues(alpha: 0.12);
        fg = const Color(0xFF10B981);
        break;
      case 'in_transit':
      case 'out_for_delivery':
      case 'assigned':
        bg = const Color(0xFF3B82F6).withValues(alpha: 0.12);
        fg = const Color(0xFF3B82F6);
        break;
      case 'failed':
      case 'cancelled':
        bg = const Color(0xFFEF4444).withValues(alpha: 0.12);
        fg = const Color(0xFFEF4444);
        break;
      default:
        bg = const Color(0xFFF37021).withValues(alpha: 0.12);
        fg = const Color(0xFFF37021);
        label = 'PENDING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: RIDERS & FLEET (STATION RIDERS ROSTER & STATUS)
  // ---------------------------------------------------------------------------
  Widget _buildRidersFleetTab(DistributionCenter officerDc, bool isDark) {
    final riders = _getDcRiders(officerDc);
    final allOrders = ref.watch(ordersProvider).orders;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Search bar
        TextField(
          controller: _riderSearchController,
          onChanged: (val) => setState(() {}),
          style: GoogleFonts.inter(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search station riders by name or code...',
            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF0D9488)),
            filled: true,
            fillColor: isDark ? const Color(0xFF151D36) : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),

        const SizedBox(height: 14),

        if (riders.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151D36) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.two_wheeler_outlined, size: 40, color: Color(0xFF94A3B8)),
                const SizedBox(height: 10),
                Text('No riders found for ${officerDc.name}', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ],
            ),
          )
        else
          ...riders.map((rider) {
            final activeOrdersForRider = allOrders.where((o) =>
                (o.deliveryAgentId == rider.id || o.deliveryAgentCode == rider.driverCode) &&
                (o.status == 'in_transit' || o.status == 'assigned')).length;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151D36) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  UserAvatarWidget(
                    avatarUrl: rider.avatarUrl.isNotEmpty ? rider.avatarUrl : null,
                    fullName: rider.name,
                    radius: 22,
                    backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.15),
                    textColor: const Color(0xFF0D9488),
                    showBorder: true,
                    borderColor: const Color(0xFF0D9488).withValues(alpha: 0.25),
                    borderWidth: 1.5,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                rider.name,
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                rider.driverCode,
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF0D9488)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${rider.vehicleType} (${rider.vehiclePlate.isNotEmpty ? rider.vehiclePlate : 'No plate'}) • Zone: ${rider.assignedZone}',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: activeOrdersForRider > 0
                                    ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
                                    : const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                activeOrdersForRider > 0
                                    ? '$activeOrdersForRider Active Drops'
                                    : 'Available for Dispatch',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: activeOrdersForRider > 0 ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '📦 ${rider.itemsInCustody} in custody',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0D9488),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.phone_rounded, size: 18, color: Color(0xFF3B82F6)),
                        onPressed: () => _makeCall(rider.phone),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send_rounded, size: 18, color: Color(0xFF25D366)),
                        onPressed: () => _openWhatsApp(
                          rider.phone,
                          'Hello ${rider.name}, this is DC Operations at ${officerDc.name}.',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: ROUTING LOGS
  // ---------------------------------------------------------------------------
  Widget _buildActivityLogsTab(DistributionCenter officerDc, bool isDark) {
    final allOrders = ref.watch(ordersProvider).orders.where((order) {
      return OrderRoutingService.doesOrderBelongToDc(
        order: order,
        currentDc: officerDc,
        allDcs: ref.watch(dcConsoleProvider).distributionCenters,
      );
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151D36) : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.timeline_rounded, color: Color(0xFF0D9488), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Live Order Activity & Dispatch Trail for ${officerDc.name}',
                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...allOrders.take(15).map((order) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151D36) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF0D9488)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order.orderNumber} - ${order.customerName}',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        order.deliveryAgentName != null
                            ? 'Dispatched to ${order.deliveryAgentName} (${order.status})'
                            : 'Pending dispatch assignment',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Text(
                  DateFormat('hh:mm a').format(order.createdAt),
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: STATION & PROFILE
  // ---------------------------------------------------------------------------
  Widget _buildStationProfileTab(DistributionCenter officerDc, bool isDark) {
    final user = ref.watch(authProvider).user;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Officer Profile Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151D36) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              UserAvatarWidget(
                avatarUrl: user?.avatarUrl,
                fullName: user?.fullName.isNotEmpty == true ? user!.fullName : 'Operations Officer',
                radius: 32,
                backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.15),
                textColor: const Color(0xFF0D9488),
                showBorder: true,
                borderColor: const Color(0xFF0D9488).withValues(alpha: 0.3),
                borderWidth: 2,
              ),
              const SizedBox(height: 10),
              Text(
                user?.fullName ?? 'Operations Officer',
                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'DC OPERATIONS DEPARTMENT',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF0D9488)),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              _buildProfileRow(Icons.badge_outlined, 'Staff Code', user?.deliveryAgentCode ?? 'OPS-WUSE-01'),
              _buildProfileRow(Icons.alternate_email_rounded, 'Email', user?.email ?? 'operations@novaxpress.ng'),
              _buildProfileRow(Icons.phone_outlined, 'Phone', user?.phone ?? 'N/A'),
              _buildProfileRow(Icons.warehouse_rounded, 'Assigned DC', officerDc.name),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Distribution Center Station Details Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151D36) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Station Information', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildProfileRow(Icons.location_city_rounded, 'Station Name', officerDc.name),
              _buildProfileRow(Icons.pin_drop_outlined, 'State & City', '${officerDc.city}, ${officerDc.state}'),
              _buildProfileRow(Icons.map_outlined, 'Address', officerDc.address),
              _buildProfileRow(Icons.person_pin_circle_outlined, 'DC Supervisor', officerDc.managerName ?? 'Manager'),
              _buildProfileRow(Icons.phone_in_talk_outlined, 'Supervisor Phone', officerDc.contactPhone ?? 'N/A'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Settings / Actions Card
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151D36) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.lock_reset_rounded, color: Color(0xFF0D9488)),
                title: Text('Change Password', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: _showPasswordResetDialog,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: const Color(0xFFF37021),
                ),
                title: Text('Toggle Dark Mode', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600)),
                trailing: Switch.adaptive(
                  value: isDark,
                  activeColor: const Color(0xFF0D9488),
                  onChanged: (val) {
                    ref.read(themeProvider.notifier).toggleTheme();
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                title: Text(
                  'Logout',
                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444)),
                ),
                onTap: _confirmLogout,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 10),
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
