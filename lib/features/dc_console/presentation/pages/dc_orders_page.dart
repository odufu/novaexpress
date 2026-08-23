import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/helpers/geo_proximity_calculator.dart';
import '../../../../core/widgets/app_skeleton_loader.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../providers/dc_console_provider.dart';
import '../widgets/dc_create_order_modal.dart';

class DCOrdersPage extends ConsumerStatefulWidget {
  const DCOrdersPage({super.key});

  @override
  ConsumerState<DCOrdersPage> createState() => _DCOrdersPageState();
}

class _DCOrdersPageState extends ConsumerState<DCOrdersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ordersProvider.notifier).loadDcOrders('22222222-2222-4222-8222-222222222222');
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ordersState = ref.watch(ordersProvider);
    final dcState = ref.watch(dcConsoleProvider);

    final unassignedOrders = ordersState.orders.where((o) {
      final isUnassigned = o.deliveryAgentId == null || o.deliveryAgentId!.isEmpty;
      return isUnassigned && o.status != 'delivered' && o.status != 'cancelled' && o.status != 'failed';
    }).toList();

    final inTransitOrders = ordersState.orders.where((o) {
      final isAssigned = o.deliveryAgentId != null && o.deliveryAgentId!.isNotEmpty;
      return isAssigned && o.status != 'delivered' && o.status != 'cancelled' && o.status != 'failed';
    }).toList();

    final deliveredOrders = ordersState.orders.where((o) => o.status == 'delivered').toList();
    final failedOrders = ordersState.orders.where((o) => o.status == 'cancelled' || o.status == 'failed' || o.status == 'call_back').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-Tab Navigation Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: const Color(0xFFF37021),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFFF37021),
            indicatorWeight: 3,
            labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
            tabs: [
              Tab(icon: const Icon(Icons.outbox_rounded, size: 18), text: 'Unassigned Pool (${unassignedOrders.length})'),
              Tab(icon: const Icon(Icons.local_shipping_rounded, size: 18), text: 'In-Transit Routes (${inTransitOrders.length})'),
              Tab(icon: const Icon(Icons.check_circle_outline_rounded, size: 18), text: 'Delivered / POD (${deliveredOrders.length})'),
              Tab(icon: const Icon(Icons.warning_amber_rounded, size: 18), text: 'Failed / Rescheduled (${failedOrders.length})'),
            ],
          ),
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // 1. Unassigned Orders Pool
              _buildUnassignedPoolView(isDark, unassignedOrders, dcState, ordersState),

              // 2. In-Transit Routes Monitor
              _buildInTransitView(isDark, inTransitOrders, dcState),

              // 3. Delivered & POD Verified
              _buildDeliveredView(isDark, deliveredOrders),

              // 4. Failed / Rescheduled Deliveries
              _buildFailedView(isDark, failedOrders),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnassignedPoolView(
    bool isDark,
    List<OrderEntity> orders,
    DCConsoleState dcState,
    OrdersState ordersState,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 650;
              final headerInfo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unassigned Orders Pool', style: GoogleFonts.inter(fontSize: isMobile ? 18 : 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Assign incoming merchant shipments to riders based on delivery zones & workload', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                ],
              );

              final actionButtons = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => const DCCreateOrderModal(),
                      );
                    },
                    icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    label: const Text('Create New Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF37021),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  if (orders.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () => _autoAssignPool(orders, dcState, ordersState),
                      icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                      label: const Text('Auto-Assign', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                ],
              );

              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerInfo,
                    const SizedBox(height: 12),
                    actionButtons,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: headerInfo),
                  const SizedBox(width: 12),
                  actionButtons,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (ordersState.isLoading)
            Column(
              children: List.generate(3, (index) => const OrderCardSkeleton()),
            )
          else if (orders.isEmpty)
            _buildEmptyState(
              isDark,
              icon: Icons.check_circle_outline_rounded,
              title: 'All Orders Dispatched',
              subtitle: 'There are currently no unassigned orders in the Wuse DC manifest. All orders are active on rider routes.',
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < orders.length; i++) ...[
                    _buildOrderRow(
                      orderCode: orders[i].orderNumber,
                      customer: orders[i].customerName,
                      phone: orders[i].customerPhone,
                      address: orders[i].deliveryAddress,
                      product: orders[i].productName,
                      amount: orders[i].totalAmount,
                      paymentType: orders[i].paymentType == 'pay_on_delivery' ? 'POD Cash' : 'Prepaid Direct',
                      isUnassigned: true,
                      onAssign: () => _showAssignRiderModal(context, isDark, orders[i], dcState, ordersState),
                    ),
                    if (i < orders.length - 1)
                      Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInTransitView(bool isDark, List<OrderEntity> orders, DCConsoleState dcState) {
    final ordersState = ref.watch(ordersProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 650;
              final titleCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Live In-Transit Deliveries', style: GoogleFonts.inter(fontSize: isMobile ? 18 : 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Active delivery routes currently in custody of distribution center riders', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                ],
              );
              final badge = Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${orders.length} Active Routes',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                ),
              );

              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleCol,
                    const SizedBox(height: 10),
                    badge,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: titleCol),
                  const SizedBox(width: 12),
                  badge,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (ordersState.isLoading)
            Column(
              children: List.generate(3, (index) => const OrderCardSkeleton()),
            )
          else if (orders.isEmpty)
            _buildEmptyState(
              isDark,
              icon: Icons.local_shipping_outlined,
              title: 'No In-Transit Orders',
              subtitle: 'Assign orders from the Unassigned Pool to dispatch riders out on their routes.',
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < orders.length; i++) ...[
                    _buildOrderRow(
                      orderCode: orders[i].orderNumber,
                      customer: orders[i].customerName,
                      phone: orders[i].customerPhone,
                      address: orders[i].deliveryAddress,
                      product: orders[i].productName,
                      amount: orders[i].totalAmount,
                      paymentType: orders[i].paymentType == 'pay_on_delivery' ? 'POD Cash' : 'Prepaid Direct',
                      riderName: orders[i].deliveryAgentName != null
                          ? '${orders[i].deliveryAgentName} (${orders[i].deliveryAgentCode ?? "PDA"})'
                          : (orders[i].deliveryAgentCode != null ? 'Agent: ${orders[i].deliveryAgentCode}' : 'Field Agent'),
                      statusPill: 'IN-TRANSIT',
                      isUnassigned: false,
                    ),
                    if (i < orders.length - 1)
                      Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeliveredView(bool isDark, List<OrderEntity> orders) {
    final ordersState = ref.watch(ordersProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Delivered & POD Verified Audit', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (ordersState.isLoading)
            Column(
              children: List.generate(3, (index) => const OrderCardSkeleton()),
            )
          else if (orders.isEmpty)
            _buildEmptyState(
              isDark,
              icon: Icons.check_circle_outline,
              title: 'No Delivered Orders Yet',
              subtitle: 'Delivered orders verified with digital proof of delivery will appear here.',
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < orders.length; i++) ...[
                    _buildOrderRow(
                      orderCode: orders[i].orderNumber,
                      customer: orders[i].customerName,
                      phone: orders[i].customerPhone,
                      address: orders[i].deliveryAddress,
                      product: orders[i].productName,
                      amount: orders[i].totalAmount,
                      paymentType: orders[i].paymentType == 'pay_on_delivery' ? 'POD Cash (Collected)' : 'Prepaid Verified',
                      riderName: orders[i].deliveryAgentName != null
                          ? '${orders[i].deliveryAgentName} (${orders[i].deliveryAgentCode ?? "PDA"})'
                          : (orders[i].deliveryAgentCode != null ? 'Agent: ${orders[i].deliveryAgentCode}' : 'Field Agent'),
                      statusPill: 'DELIVERED (POD)',
                    ),
                    if (i < orders.length - 1)
                      Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFailedView(bool isDark, List<OrderEntity> orders) {
    final ordersState = ref.watch(ordersProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Failed & Rescheduled Delivery Tickets', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (ordersState.isLoading)
            Column(
              children: List.generate(3, (index) => const OrderCardSkeleton()),
            )
          else if (orders.isEmpty)
            _buildEmptyState(
              isDark,
              icon: Icons.done_all_rounded,
              title: 'Zero Failed Deliveries',
              subtitle: 'All delivery runs have succeeded or are currently in progress without issues.',
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < orders.length; i++) ...[
                    _buildOrderRow(
                      orderCode: orders[i].orderNumber,
                      customer: orders[i].customerName,
                      phone: orders[i].customerPhone,
                      address: orders[i].deliveryAddress,
                      product: orders[i].productName,
                      amount: orders[i].totalAmount,
                      paymentType: 'POD Cash',
                      riderName: orders[i].deliveryAgentName != null
                          ? '${orders[i].deliveryAgentName} (${orders[i].deliveryAgentCode ?? "PDA"})'
                          : (orders[i].deliveryAgentCode != null ? 'Agent: ${orders[i].deliveryAgentCode}' : 'Field Agent'),
                      statusPill: 'FAILED (RETURN PENDING)',
                    ),
                    if (i < orders.length - 1)
                      Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: const Color(0xFF64748B)),
          const SizedBox(height: 12),
          Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderRow({
    required String orderCode,
    required String customer,
    required String phone,
    required String address,
    required String product,
    required double amount,
    required String paymentType,
    String? riderName,
    String? statusPill,
    bool isUnassigned = false,
    VoidCallback? onAssign,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 600;

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_shipping_outlined, color: Color(0xFF2563EB), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$orderCode • $customer ($phone)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(address, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                          Text('Product: $product • Channel: $paymentType', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                          if (riderName != null)
                            Text('Assigned Rider: $riderName', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(CurrencyFormatter.formatNaira(amount), style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                    if (isUnassigned)
                      ElevatedButton.icon(
                        onPressed: onAssign,
                        icon: const Icon(Icons.send_rounded, size: 14, color: Colors.white),
                        label: const Text('Assign Rider', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      )
                    else if (statusPill != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusPill.contains('DELIVERED')
                              ? const Color(0xFFECFDF5)
                              : (statusPill.contains('FAILED') ? const Color(0xFFFEF2F2) : const Color(0xFFEDE9FE)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusPill,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusPill.contains('DELIVERED')
                                ? const Color(0xFF059669)
                                : (statusPill.contains('FAILED') ? const Color(0xFFDC2626) : const Color(0xFF7C3AED)),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_shipping_outlined, color: Color(0xFF2563EB), size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$orderCode • $customer ($phone)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(address, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text('Product: $product • Channel: $paymentType', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis),
                          if (riderName != null)
                            Text('Assigned Rider: $riderName', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(CurrencyFormatter.formatNaira(amount), style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  if (isUnassigned)
                    ElevatedButton.icon(
                      onPressed: onAssign,
                      icon: const Icon(Icons.send_rounded, size: 14, color: Colors.white),
                      label: const Text('Assign Rider', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    )
                  else if (statusPill != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusPill.contains('DELIVERED')
                            ? const Color(0xFFECFDF5)
                            : (statusPill.contains('FAILED') ? const Color(0xFFFEF2F2) : const Color(0xFFEDE9FE)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusPill,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusPill.contains('DELIVERED')
                              ? const Color(0xFF059669)
                              : (statusPill.contains('FAILED') ? const Color(0xFFDC2626) : const Color(0xFF7C3AED)),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAssignRiderModal(
    BuildContext context,
    bool isDark,
    OrderEntity order,
    DCConsoleState dcState,
    OrdersState ordersState,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF151D36) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_pin_circle_rounded, color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 10),
                Text('Dispatch Order ${order.orderNumber}', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${order.customerName} • ${order.deliveryAddress}',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Order Amount: ${CurrencyFormatter.formatNaira(order.totalAmount)}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('Payment: ${order.paymentType == "pay_on_delivery" ? "POD Cash" : "Prepaid"}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                if (order.hasCoordinates) ...[
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      DCFleetDriver? nearestDriver;
                      double minDistanceKm = 999999.0;

                      for (final driver in dcState.drivers) {
                        double dLat = 9.0765;
                        double dLng = 7.4832;
                        if (driver.id.contains('sanni')) {
                          dLat = 9.0882;
                          dLng = 7.4933;
                        } else if (driver.id.contains('b1111111') || driver.driverCode == 'PDA-7000') {
                          dLat = 9.0765;
                          dLng = 7.4832;
                        } else {
                          dLat = 9.0345;
                          dLng = 7.4891;
                        }

                        final dist = GeoProximityCalculator.calculateDistanceKm(
                          lat1: order.latitude!,
                          lon1: order.longitude!,
                          lat2: dLat,
                          lon2: dLng,
                        );

                        if (dist < minDistanceKm) {
                          minDistanceKm = dist;
                          nearestDriver = driver;
                        }
                      }

                      if (nearestDriver != null) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [const Color(0xFF1E3A8A).withValues(alpha: 0.35), const Color(0xFF1E293B)]
                                  : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF3B82F6), width: 1.2),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.radar_rounded, color: Color(0xFF2563EB), size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '🎯 GIS Nearest Rider Match',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                                    ),
                                    Text(
                                      '${nearestDriver.name} (${nearestDriver.driverCode}) • ${GeoProximityCalculator.formatDistance(minDistanceKm)} away',
                                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  Navigator.pop(ctx);
                                  await ref.read(ordersProvider.notifier).assignOrderToRider(
                                    orderId: order.id,
                                    riderId: nearestDriver!.id,
                                    riderName: nearestDriver.name,
                                    riderCode: nearestDriver.driverCode,
                                  );
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('⚡ Auto-matched order ${order.orderNumber} to nearest rider ${nearestDriver.name}!'),
                                      backgroundColor: const Color(0xFF10B981),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.flash_on_rounded, size: 14),
                                label: const Text('Auto-Dispatch', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
                const SizedBox(height: 14),
                Text('Select an active rider (ordered by lightest workload):', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                const SizedBox(height: 10),
                ...dcState.drivers.map((driver) {
                  // Calculate live workload for this rider
                  final activeOrdersCount = ordersState.orders.where((o) {
                    final isMatchingAgent = o.deliveryAgentId == driver.id || 
                                           o.deliveryAgentCode == driver.driverCode ||
                                           (driver.id.contains('sanni') && (o.deliveryAgentId?.contains('sanni') == true || o.deliveryAgentCode == 'PDA-7588')) ||
                                           (driver.id == 'b1111111-1111-4111-8111-111111111111' && o.deliveryAgentCode == 'PDA-7000');
                    return isMatchingAgent && o.status != 'delivered' && o.status != 'cancelled' && o.status != 'failed';
                  }).length;

                  final bool isAvailable = activeOrdersCount == 0;
                  final bool isLightLoad = activeOrdersCount <= 3;
                  final bool isHeavyLoad = activeOrdersCount > 6;

                  final workloadColor = isAvailable || isLightLoad
                      ? const Color(0xFF10B981)
                      : (isHeavyLoad ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));

                  final workloadLabel = isAvailable
                      ? '🟢 Available (0 Active)'
                      : (isLightLoad
                          ? '🟢 Light Load ($activeOrdersCount Active)'
                          : (isHeavyLoad
                              ? '🔴 Heavy Load ($activeOrdersCount Active)'
                              : '🟡 Moderate ($activeOrdersCount Active)'));

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isAvailable ? const Color(0xFF10B981).withValues(alpha: 0.5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        width: isAvailable ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                          child: Text(driver.name.substring(0, 1), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(driver.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(driver.driverCode, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: workloadColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      workloadLabel,
                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: workloadColor),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${driver.vehicleModel} • Zone: ${driver.assignedZone}',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.pop(ctx);
                            final success = await ref.read(ordersProvider.notifier).assignOrderToRider(
                              orderId: order.id,
                              riderId: driver.id,
                              riderName: driver.name,
                              riderCode: driver.driverCode,
                            );

                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(success
                                    ? '✅ Order ${order.orderNumber} successfully dispatched to ${driver.name} (${driver.driverCode}).'
                                    : '⚠️ Failed to assign order. Please retry.'),
                                backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          child: const Text('Dispatch', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }

  void _autoAssignPool(List<OrderEntity> unassigned, DCConsoleState dcState, OrdersState ordersState) async {
    if (dcState.drivers.isEmpty) return;

    int assignedCount = 0;
    for (int i = 0; i < unassigned.length; i++) {
      final order = unassigned[i];

      // 1. Try server-side proximity auto-dispatch
      final proximityResult = await ref.read(ordersProvider.notifier).autoDispatchToNearestRider(order.id);
      if (proximityResult['success'] == true && proximityResult['riderId'] != null) {
        assignedCount++;
        continue;
      }

      // 2. Fallback: Pick driver with lowest current workload
      final sortedDrivers = [...dcState.drivers];
      sortedDrivers.sort((a, b) {
        final aCount = ordersState.orders.where((o) => o.deliveryAgentId == a.id || o.deliveryAgentCode == a.driverCode).length;
        final bCount = ordersState.orders.where((o) => o.deliveryAgentId == b.id || o.deliveryAgentCode == b.driverCode).length;
        return aCount.compareTo(bCount);
      });

      final targetDriver = sortedDrivers.first;
      await ref.read(ordersProvider.notifier).assignOrderToRider(
        orderId: order.id,
        riderId: targetDriver.id,
        riderName: targetDriver.name,
        riderCode: targetDriver.driverCode,
      );
      assignedCount++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚡ Auto-dispatched $assignedCount orders using proximity GIS and workload balancing.'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }
}
