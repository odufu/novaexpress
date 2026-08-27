import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/helpers/geo_proximity_calculator.dart';
import '../../../../core/widgets/app_skeleton_loader.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../../stock/domain/entities/stock_item.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../providers/dc_console_provider.dart';
import '../widgets/dc_create_order_modal.dart';
import '../widgets/dc_order_detail_modal.dart';

final dcDeliveredSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final dcDeliveredFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');
final dcOrdersDateFilterProvider = StateProvider.autoDispose<String>((ref) => 'all_time');
final dcOrdersCustomDateRangeProvider = StateProvider.autoDispose<DateTimeRange?>((ref) => null);

class DCOrdersPage extends ConsumerStatefulWidget {
  const DCOrdersPage({super.key});

  @override
  ConsumerState<DCOrdersPage> createState() => _DCOrdersPageState();
}

class _DCOrdersPageState extends ConsumerState<DCOrdersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _deliveredSearchController = TextEditingController();

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
    _deliveredSearchController.dispose();
    super.dispose();
  }

  List<OrderEntity> _filterOrdersByDate(List<OrderEntity> orders, String dateFilter, DateTimeRange? customRange) {
    if (dateFilter == 'all_time') return orders;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return orders.where((o) {
      final date = o.createdAt;
      switch (dateFilter) {
        case 'today':
          return date.isAfter(todayStart) && date.isBefore(todayEnd);
        case 'yesterday':
          final yesterdayStart = todayStart.subtract(const Duration(days: 1));
          final yesterdayEnd = todayStart.subtract(const Duration(seconds: 1));
          return date.isAfter(yesterdayStart) && date.isBefore(yesterdayEnd);
        case 'this_week':
          final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
          return date.isAfter(weekStart);
        case 'this_month':
          final monthStart = DateTime(now.year, now.month, 1);
          return date.isAfter(monthStart);
        case 'custom':
          if (customRange == null) return true;
          final start = DateTime(customRange.start.year, customRange.start.month, customRange.start.day);
          final end = DateTime(customRange.end.year, customRange.end.month, customRange.end.day, 23, 59, 59);
          return (date.isAfter(start) || date.isAtSameMomentAs(start)) &&
                 (date.isBefore(end) || date.isAtSameMomentAs(end));
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ordersState = ref.watch(ordersProvider);
    final dcState = ref.watch(dcConsoleProvider);
    final activeDateFilter = ref.watch(dcOrdersDateFilterProvider);
    final customRange = ref.watch(dcOrdersCustomDateRangeProvider);

    final dateFilteredOrders = _filterOrdersByDate(ordersState.orders, activeDateFilter, customRange);

    final unassignedOrders = dateFilteredOrders.where((o) {
      final isUnassigned = o.deliveryAgentId == null || o.deliveryAgentId!.isEmpty;
      return isUnassigned && o.status != 'delivered' && o.status != 'cancelled' && o.status != 'failed';
    }).toList();

    final inTransitOrders = dateFilteredOrders.where((o) {
      final isAssigned = o.deliveryAgentId != null && o.deliveryAgentId!.isNotEmpty;
      return isAssigned && o.status != 'delivered' && o.status != 'cancelled' && o.status != 'failed';
    }).toList();

    final deliveredOrders = dateFilteredOrders.where((o) => o.status == 'delivered').toList();
    final failedOrders = dateFilteredOrders.where((o) => o.status == 'cancelled' || o.status == 'failed' || o.status == 'call_back').toList();

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

        // Date Range Filter Toolbar
        _buildDateFilterBar(context, isDark, activeDateFilter, customRange),

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

  Widget _buildDateFilterBar(BuildContext context, bool isDark, String activeDateFilter, DateTimeRange? customRange) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              '📅 Filter by Date:',
              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            _buildDateFilterChip('All Time', 'all_time', activeDateFilter, isDark),
            const SizedBox(width: 6),
            _buildDateFilterChip('Today', 'today', activeDateFilter, isDark),
            const SizedBox(width: 6),
            _buildDateFilterChip('Yesterday', 'yesterday', activeDateFilter, isDark),
            const SizedBox(width: 6),
            _buildDateFilterChip('This Week', 'this_week', activeDateFilter, isDark),
            const SizedBox(width: 6),
            _buildDateFilterChip('This Month', 'this_month', activeDateFilter, isDark),
            const SizedBox(width: 6),
            InkWell(
              onTap: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2025, 1, 1),
                  lastDate: DateTime(2030, 12, 31),
                  initialDateRange: customRange ?? DateTimeRange(start: DateTime.now().subtract(const Duration(days: 7)), end: DateTime.now()),
                );
                if (picked != null) {
                  ref.read(dcOrdersCustomDateRangeProvider.notifier).state = picked;
                  ref.read(dcOrdersDateFilterProvider.notifier).state = 'custom';
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: activeDateFilter == 'custom' ? const Color(0xFF2563EB).withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: activeDateFilter == 'custom' ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.date_range_rounded, size: 13, color: Color(0xFF2563EB)),
                    const SizedBox(width: 4),
                    Text(
                      customRange != null
                          ? '${customRange.start.day}/${customRange.start.month} - ${customRange.end.day}/${customRange.end.month}'
                          : 'Custom Range 📅',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: activeDateFilter == 'custom' ? FontWeight.bold : FontWeight.w500,
                        color: activeDateFilter == 'custom' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilterChip(String label, String key, String activeKey, bool isDark) {
    final isSelected = activeKey == key;
    return InkWell(
      onTap: () {
        ref.read(dcOrdersDateFilterProvider.notifier).state = key;
        if (key != 'custom') {
          ref.read(dcOrdersCustomDateRangeProvider.notifier).state = null;
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
          ),
        ),
      ),
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
                      context: context,
                      isDark: isDark,
                      order: orders[i],
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
                      context: context,
                      isDark: isDark,
                      order: orders[i],
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
    final stockState = ref.watch(stockProvider);

    // Calculate Summary Metrics
    final totalRevenue = orders.fold<double>(0.0, (acc, o) => acc + o.totalAmount);
    final paystackOrders = orders.where((o) => o.isDirectTransfer).toList();
    final clearedOrders = orders.where((o) => o.isRemitted).toList();
    final unremittedOrders = orders.where((o) => o.isUnremitted).toList();

    final clearedRevenue = clearedOrders.fold<double>(0.0, (acc, o) => acc + o.totalAmount);
    final unremittedRevenue = unremittedOrders.fold<double>(0.0, (acc, o) => acc + o.totalAmount);
    final paystackRevenue = paystackOrders.fold<double>(0.0, (acc, o) => acc + o.totalAmount);

    final deliveredFilter = ref.watch(dcDeliveredFilterProvider);
    final deliveredSearchQuery = ref.watch(dcDeliveredSearchProvider);

    // Filter by query and payment/remittance channel
    final filteredOrders = orders.where((o) {
      final matchesFilter = deliveredFilter == 'all' ||
          (deliveredFilter == 'paystack' && o.isDirectTransfer) ||
          (deliveredFilter == 'cleared' && o.isRemitted) ||
          (deliveredFilter == 'unremitted' && o.isUnremitted) ||
          (deliveredFilter == 'cash' && !o.isDirectTransfer);
      if (!matchesFilter) return false;

      if (deliveredSearchQuery.trim().isEmpty) return true;
      final q = deliveredSearchQuery.toLowerCase().trim();
      return o.orderNumber.toLowerCase().contains(q) ||
          o.customerName.toLowerCase().contains(q) ||
          o.customerPhone.toLowerCase().contains(q) ||
          (o.deliveryAgentName != null && o.deliveryAgentName!.toLowerCase().contains(q)) ||
          (o.deliveryAgentCode != null && o.deliveryAgentCode!.toLowerCase().contains(q)) ||
          (o.remittanceReference != null && o.remittanceReference!.toLowerCase().contains(q)) ||
          o.deliveryAddress.toLowerCase().contains(q) ||
          o.productName.toLowerCase().contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Delivered Orders & Fulfillment Audit', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Review confirmed proof of delivery, settlement finances, and warehouse stock deductions', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 5),
                    Text('${orders.length} Fulfilled', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4-Metric Summary Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 900;
              final cardWidth = isNarrow ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 36) / 4;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildDeliveredKpiCard(
                    isDark,
                    title: 'Total Delivered Revenue',
                    value: CurrencyFormatter.formatNaira(totalRevenue),
                    subtitle: '${orders.length} shipments fulfilled',
                    icon: Icons.payments_rounded,
                    iconColor: const Color(0xFF2563EB),
                    width: cardWidth,
                  ),
                  _buildDeliveredKpiCard(
                    isDark,
                    title: '🟢 Remitted & Cleared',
                    value: CurrencyFormatter.formatNaira(clearedRevenue),
                    subtitle: '${clearedOrders.length} reconciled orders',
                    icon: Icons.check_circle_rounded,
                    iconColor: const Color(0xFF10B981),
                    width: cardWidth,
                  ),
                  _buildDeliveredKpiCard(
                    isDark,
                    title: '🟡 In Rider Custody',
                    value: CurrencyFormatter.formatNaira(unremittedRevenue),
                    subtitle: '${unremittedOrders.length} unremitted cash runs',
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: const Color(0xFFF37021),
                    width: cardWidth,
                  ),
                  _buildDeliveredKpiCard(
                    isDark,
                    title: '⚡ Direct to Bank',
                    value: CurrencyFormatter.formatNaira(paystackRevenue),
                    subtitle: '${paystackOrders.length} direct settled',
                    icon: Icons.bolt_rounded,
                    iconColor: const Color(0xFF00A2D3),
                    width: cardWidth,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Search and Channel Filters
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _deliveredSearchController,
                  onChanged: (val) => ref.read(dcDeliveredSearchProvider.notifier).state = val,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search by Order #, Customer, Phone, Rider, Ref #, or Address...',
                    hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                    suffixIcon: deliveredSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              _deliveredSearchController.clear();
                              ref.read(dcDeliveredSearchProvider.notifier).state = '';
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildDeliveredFilterChip(
                        label: 'All Delivered (${orders.length})',
                        isSelected: deliveredFilter == 'all',
                        onTap: () => ref.read(dcDeliveredFilterProvider.notifier).state = 'all',
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildDeliveredFilterChip(
                        label: '🟢 Remitted & Cleared (${clearedOrders.length})',
                        isSelected: deliveredFilter == 'cleared',
                        onTap: () => ref.read(dcDeliveredFilterProvider.notifier).state = 'cleared',
                        isDark: isDark,
                        activeColor: const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 8),
                      _buildDeliveredFilterChip(
                        label: '🟡 In Rider Custody / Unremitted (${unremittedOrders.length})',
                        isSelected: deliveredFilter == 'unremitted',
                        onTap: () => ref.read(dcDeliveredFilterProvider.notifier).state = 'unremitted',
                        isDark: isDark,
                        activeColor: const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 8),
                      _buildDeliveredFilterChip(
                        label: '⚡ Direct Transfer (${paystackOrders.length})',
                        isSelected: deliveredFilter == 'paystack',
                        onTap: () => ref.read(dcDeliveredFilterProvider.notifier).state = 'paystack',
                        isDark: isDark,
                        activeColor: const Color(0xFF00A2D3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Orders Feed
          if (ordersState.isLoading)
            Column(children: List.generate(3, (_) => const OrderCardSkeleton()))
          else if (filteredOrders.isEmpty)
            _buildEmptyState(
              isDark,
              icon: Icons.search_off_rounded,
              title: deliveredSearchQuery.isNotEmpty ? 'No Matching Delivered Orders' : 'No Delivered Orders in this Category',
              subtitle: deliveredSearchQuery.isNotEmpty
                  ? 'No delivered orders matched "$deliveredSearchQuery". Try adjusting your search query or filter.'
                  : 'Delivered orders will appear here once fulfilled by riders.',
            )
          else
            Column(
              children: filteredOrders.map((o) {
                return _buildDeliveredOrderCard(context, isDark, o, stockState);
              }).toList(),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Failed & Rescheduled Delivery Tickets', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Shipments with delivery exceptions, callbacks, or customer rescheduling', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${orders.length} Incidents', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626))),
              ),
            ],
          ),
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
                      context: context,
                      isDark: isDark,
                      order: orders[i],
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
    required BuildContext context,
    required bool isDark,
    required OrderEntity order,
    bool isUnassigned = false,
    VoidCallback? onAssign,
    String? statusPill,
  }) {
    final orderCode = order.orderNumber;
    final customer = order.customerName;
    final phone = order.customerPhone;
    final address = order.deliveryAddress;
    final product = order.productName;
    final amount = order.totalAmount;
    final paymentType = order.paymentType == 'pay_on_delivery' ? 'POD Cash' : 'Prepaid Direct';
    final riderName = order.deliveryAgentName != null
        ? '${order.deliveryAgentName} (${order.deliveryAgentCode ?? "PDA"})'
        : (order.deliveryAgentCode != null ? 'Agent: ${order.deliveryAgentCode}' : null);

    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => DCOrderDetailModal(order: order),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 650;

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
                        child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('$orderCode • $customer', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 6),
                                _buildOrderRemittanceBadge(order),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('$phone • $address', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text('📦 ${order.quantity}x $product • $paymentType', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                            if (riderName != null)
                              Text('🛵 Custody: $riderName', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
                            if (order.isFailed && order.failureReason != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text('⚠️ Reason: ${order.failureReason}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626))),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(CurrencyFormatter.formatNaira(amount), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                          Text('Net: ${CurrencyFormatter.formatNaira(order.netMerchantSettlement)}', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF10B981), fontWeight: FontWeight.w600)),
                        ],
                      ),
                      if (isUnassigned)
                        ElevatedButton.icon(
                          onPressed: onAssign,
                          icon: const Icon(Icons.send_rounded, size: 13, color: Colors.white),
                          label: const Text('Assign Rider', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => DCOrderDetailModal(order: order),
                            );
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 13),
                          label: const Text('Details', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
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
                        child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('$orderCode • $customer ($phone)', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                const SizedBox(width: 8),
                                _buildOrderRemittanceBadge(order),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(address, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text('📦 ${order.quantity}x $product • $paymentType', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis),
                            if (riderName != null)
                              Text('🛵 Custody: $riderName', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)), overflow: TextOverflow.ellipsis),
                            if (order.isFailed && order.failureReason != null)
                              Text('⚠️ Reason: ${order.failureReason}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(CurrencyFormatter.formatNaira(amount), style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.bold)),
                        Text('Net: ${CurrencyFormatter.formatNaira(order.netMerchantSettlement)}', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF10B981), fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(width: 12),
                    if (isUnassigned)
                      ElevatedButton.icon(
                        onPressed: onAssign,
                        icon: const Icon(Icons.send_rounded, size: 13, color: Colors.white),
                        label: const Text('Assign Rider', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => DCOrderDetailModal(order: order),
                          );
                        },
                        icon: const Icon(Icons.receipt_long_rounded, size: 13, color: Colors.white),
                        label: const Text('View Ticket', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrderRemittanceBadge(OrderEntity order) {
    if (order.isDelivered) {
      if (order.isDirectTransfer) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF0284C7).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('⚡ DIRECT TRANSFER', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7))),
        );
      } else if (order.isRemitted) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('🟢 REMITTED & CLEARED', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF059669))),
        );
      } else {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFD97706).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('🟡 IN RIDER CUSTODY', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFFD97706))),
        );
      }
    } else if (order.isFailed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('🔴 FAILED ATTEMPT', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626))),
      );
    }
    return const SizedBox.shrink();
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

                  // Connected Stock Custody Check for this order
                  final stockState = ref.read(stockProvider);
                  final requiredProduct = order.productName.isNotEmpty ? order.productName : 'Respira Detox Tea';
                  final requiredQuantity = order.quantity > 0 ? order.quantity : 1;

                  final driverAllocations = stockState.getAllocationsForRider(driver.id, driver.driverCode);
                  int riderCustodyUnits = 0;
                  for (final a in driverAllocations) {
                    if (a.productName.toLowerCase().contains(requiredProduct.toLowerCase()) ||
                        requiredProduct.toLowerCase().contains(a.productName.toLowerCase()) ||
                        (a.sku.isNotEmpty && requiredProduct.toLowerCase().contains(a.sku.toLowerCase()))) {
                      riderCustodyUnits += a.inCustodyUnits;
                    }
                  }

                  final targetWarehouseItem = stockState.stockItems.firstWhere(
                    (i) => i.name.toLowerCase().contains(requiredProduct.toLowerCase()) ||
                           requiredProduct.toLowerCase().contains(i.name.toLowerCase()) ||
                           i.sku.toLowerCase().contains(requiredProduct.toLowerCase()),
                    orElse: () => stockState.stockItems.isNotEmpty
                        ? stockState.stockItems.first
                        : const StockItemEntity(id: '', sku: '', name: '', description: '', price: 0, assignedCount: 0, deliveredCount: 0, availableCount: 0, returnedCount: 0, category: ''),
                  );

                  final warehouseAvailable = targetWarehouseItem.availableCount;
                  final bool hasSufficientStock = riderCustodyUnits >= requiredQuantity;

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
                              const SizedBox(height: 5),
                              // Live Stock in Custody Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: hasSufficientStock
                                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                      : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  hasSufficientStock
                                      ? '📦 In Vehicle: $riderCustodyUnits units (Ready for ${requiredQuantity}x $requiredProduct)'
                                      : '⚠️ In Vehicle: $riderCustodyUnits units (Needs ${requiredQuantity}x $requiredProduct • DC Shelf: $warehouseAvailable)',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: hasSufficientStock ? const Color(0xFF059669) : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);

                            if (!hasSufficientStock) {
                              final neededUnits = requiredQuantity - riderCustodyUnits;
                              if (warehouseAvailable >= neededUnits) {
                                // Prompt to allocate stock and dispatch
                                final shouldAllocate = await showDialog<bool>(
                                  context: context,
                                  builder: (dlgCtx) => AlertDialog(
                                    backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: Row(
                                      children: [
                                        const Icon(Icons.inventory_2_rounded, color: Color(0xFF2563EB), size: 22),
                                        const SizedBox(width: 8),
                                        const Text('Allocate Stock & Dispatch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      ],
                                    ),
                                    content: Text(
                                      '${driver.name} currently holds $riderCustodyUnits units of $requiredProduct (Order requires $requiredQuantity units).\n\n'
                                      'DC Warehouse currently possesses $warehouseAvailable shelf units.\n\n'
                                      'Would you like to allocate the needed $neededUnits units from warehouse possession to ${driver.name} and dispatch this order?',
                                      style: GoogleFonts.inter(fontSize: 12.5),
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(dlgCtx, false), child: const Text('Cancel')),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(dlgCtx, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                                        child: Text('Allocate $neededUnits Units & Dispatch', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                );

                                if (shouldAllocate != true) return;

                                // 1. Allocate stock to rider
                                await ref.read(stockProvider.notifier).assignStockToRider(
                                  productIdOrSku: targetWarehouseItem.id,
                                  riderId: driver.id,
                                  riderName: driver.name,
                                  riderCode: driver.driverCode,
                                  quantity: neededUnits,
                                );
                              } else {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('❌ Cannot assign order. ${driver.name} has only $riderCustodyUnits units and DC Warehouse possesses only $warehouseAvailable units of $requiredProduct. Please intake/receive stock first.'),
                                    backgroundColor: const Color(0xFFEF4444),
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                                return;
                              }
                            }

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }

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

  // ==========================================
  // DELIVERED ORDERS WIDGET HELPERS & MODALS
  // ==========================================

  Widget _buildDeliveredKpiCard(
    bool isDark, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveredFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    Color activeColor = const Color(0xFFF37021),
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? activeColor : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveredOrderCard(
    BuildContext context,
    bool isDark,
    OrderEntity order,
    StockState stockState,
  ) {
    final isDirect = order.isDirectTransfer;
    final riderName = order.deliveryAgentName ?? 'Emeka Rider';
    final riderCode = order.deliveryAgentCode ?? 'PDA-7000';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Order ID, Channel Badge, & POD Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDirect
                          ? const Color(0xFF00A2D3).withValues(alpha: 0.12)
                          : const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isDirect ? Icons.bolt_rounded : Icons.payments_rounded,
                      size: 18,
                      color: isDirect ? const Color(0xFF00A2D3) : const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${order.orderNumber}',
                        style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        isDirect ? 'Direct Bank Transfer (Paystack)' : 'Cash on Delivery (POD)',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDirect ? const Color(0xFF00A2D3) : const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF16A34A)),
                    const SizedBox(width: 4),
                    Text(
                      'DELIVERED (POD)',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Row 2: Customer, Address & Rider Details
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              final infoColumn1 = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        '${order.customerName} • ${order.customerPhone}',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${order.deliveryAddress}, ${order.deliveryCity}',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              );

              final infoColumn2 = Column(
                crossAxisAlignment: isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.two_wheeler_rounded, size: 14, color: Color(0xFF2563EB)),
                      const SizedBox(width: 6),
                      Text(
                        '$riderName ($riderCode)',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${order.quantity}x ${order.productName} • ',
                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                      ),
                      Text(
                        CurrencyFormatter.formatNaira(order.totalAmount),
                        style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    infoColumn1,
                    const SizedBox(height: 8),
                    infoColumn2,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: infoColumn1),
                  const SizedBox(width: 14),
                  infoColumn2,
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // Row 3: 3 Prominent Interactive Action Buttons (Finance, Stock, Order & POD Details)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // 1. Finance Modal Button
              OutlinedButton.icon(
                onPressed: () => _openOrderFinanceModal(context, isDark, order),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(
                    color: isDirect ? const Color(0xFF00A2D3) : const Color(0xFF10B981),
                  ),
                ),
                icon: Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 15,
                  color: isDirect ? const Color(0xFF00A2D3) : const Color(0xFF10B981),
                ),
                label: Text(
                  '💰 Finance & Collections',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDirect ? const Color(0xFF00A2D3) : const Color(0xFF10B981),
                  ),
                ),
              ),

              // 2. Stock / Inventory Modal Button
              OutlinedButton.icon(
                onPressed: () => _openOrderStockModal(context, isDark, order, stockState),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: const BorderSide(color: Color(0xFF8B5CF6)),
                ),
                icon: const Icon(Icons.inventory_2_outlined, size: 15, color: Color(0xFF8B5CF6)),
                label: Text(
                  '📦 Stock & Inventory (${order.quantity} units)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ),

              // 3. Order & POD Details Modal Button
              ElevatedButton.icon(
                onPressed: () => _openOrderDetailsModal(context, isDark, order),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.receipt_long_rounded, size: 15),
                label: Text(
                  '📍 Order & POD Signature',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openOrderFinanceModal(BuildContext context, bool isDark, OrderEntity order) {
    showDialog(
      context: context,
      builder: (ctx) => DCOrderDetailModal(order: order),
    );
  }

  void _openOrderStockModal(BuildContext context, bool isDark, OrderEntity order, StockState stockState) {
    showDialog(
      context: context,
      builder: (ctx) => DCOrderDetailModal(order: order),
    );
  }

  void _openOrderDetailsModal(BuildContext context, bool isDark, OrderEntity order) {
    showDialog(
      context: context,
      builder: (ctx) => DCOrderDetailModal(order: order),
    );
  }
}
