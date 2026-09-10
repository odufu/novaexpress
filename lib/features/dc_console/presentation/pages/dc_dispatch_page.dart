import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../providers/dc_console_provider.dart';
import '../widgets/dc_assign_order_modal.dart';

class DCDispatchPage extends ConsumerWidget {
  const DCDispatchPage({super.key});

  void _showAssignModal(BuildContext context, OrderEntity order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DCAssignOrderModal(order: order),
    );
  }

  Future<void> _autoDispatchPendingOrders(
    BuildContext context,
    WidgetRef ref,
    List<OrderEntity> unassignedOrders,
    DCConsoleState dcState,
  ) async {
    if (unassignedOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No unassigned hub orders awaiting dispatch.')),
      );
      return;
    }

    if (dcState.drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active fleet riders available in this Distribution Center.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    int dispatched = 0;
    for (final order in unassignedOrders) {
      // 1. Try server proximity / zone match
      final proximityRes = await ref.read(ordersProvider.notifier).autoDispatchToNearestRider(order.id);
      if (proximityRes['success'] == true && proximityRes['riderId'] != null) {
        dispatched++;
        continue;
      }

      // 2. Fallback: match by covered LGA or pick active driver
      final activeDrivers = dcState.drivers
          .where((d) => d.status.toLowerCase() == 'active' || d.status.toLowerCase() == 'online')
          .toList();
      final pool = activeDrivers.isNotEmpty ? activeDrivers : dcState.drivers;

      final matchedDriver = pool.firstWhere(
        (d) => order.deliveryCity.isNotEmpty &&
            d.coveredLgas.any((lga) => lga.toLowerCase().contains(order.deliveryCity.toLowerCase())),
        orElse: () => pool.first,
      );

      final success = await ref.read(ordersProvider.notifier).assignOrderToRider(
        orderId: order.id,
        riderId: matchedDriver.id,
        riderName: matchedDriver.name,
        riderCode: matchedDriver.driverCode,
      );
      if (success) {
        dispatched++;
      }
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '⚡ Auto-dispatched $dispatched order(s) across active hub riders!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ordersState = ref.watch(ordersProvider);
    final dcState = ref.watch(dcConsoleProvider);

    final unassignedOrders = ordersState.orders.where((o) =>
      (o.deliveryAgentId == null || o.deliveryAgentId!.isEmpty) &&
      o.status != 'cancelled' &&
      o.status != 'delivered'
    ).toList();

    final inTransitOrders = ordersState.orders.where((o) =>
      o.status == 'in_transit' || o.status == 'assigned'
    ).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page Header
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 650;
              final headerInfo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deliveries & Route Dispatch',
                    style: GoogleFonts.inter(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Assign pending hub orders, cluster zones and monitor in-transit deliveries live',
                    style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                  ),
                ],
              );

              final actionBtn = ElevatedButton.icon(
                onPressed: unassignedOrders.isEmpty
                    ? null
                    : () => _autoDispatchPendingOrders(context, ref, unassignedOrders, dcState),
                icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                label: Text(
                  'Auto-Dispatch Zones (${unassignedOrders.length})',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  disabledBackgroundColor: const Color(0xFF94A3B8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );

              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerInfo,
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: actionBtn),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: headerInfo),
                  const SizedBox(width: 16),
                  actionBtn,
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Quick Metric Counters
          Row(
            children: [
              _buildMetricPill(
                label: 'Unassigned Pool',
                count: unassignedOrders.length,
                color: const Color(0xFFF59E0B),
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _buildMetricPill(
                label: 'In-Transit Deliveries',
                count: inTransitOrders.length,
                color: const Color(0xFF2563EB),
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _buildMetricPill(
                label: 'Active Hub Drivers',
                count: dcState.drivers.length,
                color: const Color(0xFF10B981),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // SECTION 1: Unassigned Orders Awaiting Rider Dispatch
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.pending_actions_rounded, color: Color(0xFFD97706), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Unassigned Orders Awaiting Rider',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: unassignedOrders.isEmpty
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${unassignedOrders.length} Pending',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: unassignedOrders.isEmpty ? const Color(0xFF059669) : const Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (unassignedOrders.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.task_alt_rounded, size: 36, color: Color(0xFF10B981)),
                          const SizedBox(height: 8),
                          Text(
                            'All hub orders are assigned to riders',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'New client and closer orders will appear here live for dispatch.',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: unassignedOrders.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                    itemBuilder: (ctx, i) {
                      final order = unassignedOrders[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '#${order.orderNumber}',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF2563EB),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        order.customerName,
                                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      if (order.customerPhone.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '(${order.customerPhone})',
                                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${order.deliveryAddress}, ${order.deliveryCity}',
                                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (order.clientName.isNotEmpty || order.packageDealName != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.inventory_2_outlined, size: 13, color: Color(0xFF8B5CF6)),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Client: ${order.clientName.isNotEmpty ? order.clientName : "Merchant"} ${order.packageDealName != null ? "• Package: ${order.packageDealName}" : ""}',
                                          style: GoogleFonts.inter(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF8B5CF6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyFormatter.formatNaira(order.totalAmount),
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                ElevatedButton.icon(
                                  onPressed: () => _showAssignModal(context, order),
                                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 14, color: Colors.white),
                                  label: const Text(
                                    'Assign Rider',
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // SECTION 2: In-Transit Deliveries Monitor
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.local_shipping_outlined, color: Color(0xFF2563EB), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Active In-Transit Hub Deliveries',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${inTransitOrders.length} En Route',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF7C3AED)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (inTransitOrders.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 36, color: Color(0xFF10B981)),
                          const SizedBox(height: 8),
                          Text(
                            'No active in-transit deliveries at this moment',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Dispatched routes will appear here in real time.',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: inTransitOrders.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                    itemBuilder: (ctx, i) {
                      final order = inTransitOrders[i];
                      final orderNum = order.orderNumber;
                      final custName = order.customerName;
                      final city = order.deliveryCity;
                      final amount = order.totalAmount;
                      final agentDisplay = order.deliveryAgentName != null && order.deliveryAgentName!.isNotEmpty
                          ? '${order.deliveryAgentName} (${order.deliveryAgentCode ?? 'PDA'})'
                          : 'Assigned Rider';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.local_shipping_outlined, color: Color(0xFF2563EB), size: 18),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$orderNum • $custName',
                                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Zone: $city • Delivery Agent: $agentDisplay',
                                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (order.clientName.isNotEmpty) ...[
                                          Text(
                                            'Client: ${order.clientName} ${order.packageDealName != null ? "(${order.packageDealName})" : ""}',
                                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8B5CF6)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Row(
                              children: [
                                Text(
                                  CurrencyFormatter.formatNaira(amount),
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDE9FE),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'IN-TRANSIT',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF7C3AED),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill({
    required String label,
    required int count,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count.toString(),
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    label,
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

