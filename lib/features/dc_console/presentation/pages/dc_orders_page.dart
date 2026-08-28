import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/widgets/app_skeleton_loader.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../providers/dc_console_provider.dart';
import '../widgets/dc_create_order_modal.dart';
import '../widgets/dc_order_detail_modal.dart';
import '../widgets/dc_csv_order_import_modal.dart';
import '../widgets/dc_assign_order_modal.dart';

final dcDeliveredSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final dcDeliveredFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');
final dcOrdersDateFilterProvider = StateProvider.autoDispose<String>((ref) => 'all_time');
final dcOrdersCustomDateRangeProvider = StateProvider.autoDispose<DateTimeRange?>((ref) => null);

// Master Orders Directory Multi-Attribute Filters
final dcMasterSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final dcMasterStatusFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');
final dcMasterRiderFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');
final dcMasterProductFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');
final dcMasterClientFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');
final dcMasterViewModeProvider = StateProvider.autoDispose<String>((ref) => 'table');

class DCOrdersPage extends ConsumerStatefulWidget {
  const DCOrdersPage({super.key});

  @override
  ConsumerState<DCOrdersPage> createState() => _DCOrdersPageState();
}

class _DCOrdersPageState extends ConsumerState<DCOrdersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _deliveredSearchController = TextEditingController();
  final TextEditingController _masterSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ordersProvider.notifier).loadDcOrders('22222222-2222-4222-8222-222222222222');
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _deliveredSearchController.dispose();
    _masterSearchController.dispose();
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

    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        // Sub-Tab Navigation Bar (5 Business Tabs)
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
              Tab(icon: const Icon(Icons.list_alt_rounded, size: 18), text: 'All Orders (${dateFilteredOrders.length})'),
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
              // 0. Master All Orders Directory (with Multi-attribute Filters & Fulfillment Tracker)
              _buildAllOrdersView(isDark, dateFilteredOrders, dcState, ordersState, unassignedOrders.length, inTransitOrders.length, deliveredOrders.length, failedOrders.length),

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
      ),
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

  // ==========================================
  // 0. MASTER ALL ORDERS DIRECTORY VIEW
  // ==========================================

  Widget _buildAllOrdersView(
    bool isDark,
    List<OrderEntity> allOrders,
    DCConsoleState dcState,
    OrdersState ordersState,
    int unassignedCount,
    int inTransitCount,
    int deliveredCount,
    int failedCount,
  ) {
    final masterSearch = ref.watch(dcMasterSearchProvider).trim().toLowerCase();
    final masterStatus = ref.watch(dcMasterStatusFilterProvider);
    final masterRider = ref.watch(dcMasterRiderFilterProvider);
    final masterProduct = ref.watch(dcMasterProductFilterProvider);
    final masterClient = ref.watch(dcMasterClientFilterProvider);
    final viewMode = ref.watch(dcMasterViewModeProvider);

    // Apply multi-attribute filters
    final filtered = allOrders.where((o) {
      // 1. Status Filter
      if (masterStatus != 'all') {
        if (masterStatus == 'unassigned') {
          final isUnassigned = o.deliveryAgentId == null || o.deliveryAgentId!.isEmpty;
          if (!isUnassigned || o.status == 'delivered' || o.status == 'cancelled' || o.status == 'failed') return false;
        } else if (masterStatus == 'in_transit') {
          final isAssigned = o.deliveryAgentId != null && o.deliveryAgentId!.isNotEmpty;
          if (!isAssigned || o.status == 'delivered' || o.status == 'cancelled' || o.status == 'failed') return false;
        } else if (masterStatus == 'delivered') {
          if (o.status != 'delivered') return false;
        } else if (masterStatus == 'failed') {
          if (o.status != 'cancelled' && o.status != 'failed' && o.status != 'call_back') return false;
        } else if (masterStatus == 'returned') {
          if (o.status != 'returned') return false;
        }
      }

      // 2. Rider Filter
      if (masterRider != 'all') {
        if (masterRider == 'unassigned') {
          if (o.deliveryAgentId != null && o.deliveryAgentId!.isNotEmpty) return false;
        } else {
          final matchesId = o.deliveryAgentId == masterRider;
          final matchesCode = o.deliveryAgentCode == masterRider;
          final matchesName = o.deliveryAgentName != null && o.deliveryAgentName!.toLowerCase() == masterRider.toLowerCase();
          if (!matchesId && !matchesCode && !matchesName) return false;
        }
      }

      // 3. Product Filter
      if (masterProduct != 'all') {
        if (!o.productName.toLowerCase().contains(masterProduct.toLowerCase()) &&
            !masterProduct.toLowerCase().contains(o.productName.toLowerCase())) {
          return false;
        }
      }

      // 4. Client Filter
      if (masterClient != 'all') {
        if (!o.clientName.toLowerCase().contains(masterClient.toLowerCase()) &&
            !masterClient.toLowerCase().contains(o.clientName.toLowerCase())) {
          return false;
        }
      }

      // 5. Search Query Filter
      if (masterSearch.isNotEmpty) {
        final matchOrderNo = o.orderNumber.toLowerCase().contains(masterSearch);
        final matchCust = o.customerName.toLowerCase().contains(masterSearch);
        final matchPhone = o.customerPhone.toLowerCase().contains(masterSearch);
        final matchAddress = o.deliveryAddress.toLowerCase().contains(masterSearch);
        final matchCity = o.deliveryCity.toLowerCase().contains(masterSearch);
        final matchState = o.deliveryState.toLowerCase().contains(masterSearch);
        final matchProd = o.productName.toLowerCase().contains(masterSearch);
        final matchClient = o.clientName.toLowerCase().contains(masterSearch);
        final matchRiderName = o.deliveryAgentName != null && o.deliveryAgentName!.toLowerCase().contains(masterSearch);
        final matchRiderCode = o.deliveryAgentCode != null && o.deliveryAgentCode!.toLowerCase().contains(masterSearch);

        if (!matchOrderNo && !matchCust && !matchPhone && !matchAddress && !matchCity && !matchState && !matchProd && !matchClient && !matchRiderName && !matchRiderCode) {
          return false;
        }
      }

      return true;
    }).toList();

    final double totalValuation = filtered.fold(0.0, (acc, o) => acc + o.totalAmount);
    final double deliveredRevenue = filtered.where((o) => o.status == 'delivered').fold(0.0, (acc, o) => acc + o.totalAmount);

    // Extract dynamic dropdown items
    final uniqueProducts = allOrders.map((o) => o.productName).where((p) => p.isNotEmpty).toSet().toList()..sort();
    final uniqueClients = allOrders.map((o) => o.clientName).where((c) => c.isNotEmpty).toSet().toList()..sort();
    final fleetDrivers = dcState.drivers;

    final bool hasActiveFilters = masterSearch.isNotEmpty ||
        masterStatus != 'all' ||
        masterRider != 'all' ||
        masterProduct != 'all' ||
        masterClient != 'all';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Toolbar with Action Buttons
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 750;
              final headerCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Master Orders Directory',
                        style: GoogleFonts.inter(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${filtered.length} of ${allOrders.length} Orders',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Complete overview of all DC shipments including unassigned pool, in-transit routes, and completed deliveries',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                ],
              );

              final actionsWrap = Wrap(
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
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => const DCCsvOrderImportModal(),
                      );
                    },
                    icon: const Icon(Icons.upload_file_rounded, size: 16, color: Colors.white),
                    label: const Text('Import CSV', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  if (unassignedCount > 0)
                    ElevatedButton.icon(
                      onPressed: () {
                        final unassignedList = allOrders.where((o) => (o.deliveryAgentId == null || o.deliveryAgentId!.isEmpty) && o.status != 'delivered').toList();
                        _autoAssignPool(unassignedList, dcState, ordersState);
                      },
                      icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                      label: const Text('Auto-Assign Pool', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                    headerCol,
                    const SizedBox(height: 12),
                    actionsWrap,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: headerCol),
                  const SizedBox(width: 14),
                  actionsWrap,
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // 2. Summary KPI Metric Cards (5 Cards)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 950;
              final cardWidth = isNarrow ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 48) / 5;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildDeliveredKpiCard(
                    isDark,
                    title: 'Total Filtered Orders',
                    value: '${filtered.length} Orders',
                    subtitle: 'Gross: ${CurrencyFormatter.formatNaira(totalValuation)}',
                    icon: Icons.inventory_2_rounded,
                    iconColor: const Color(0xFF2563EB),
                    width: cardWidth,
                  ),
                  _buildDeliveredKpiCard(
                    isDark,
                    title: '📦 Unassigned Pool',
                    value: '$unassignedCount Pending',
                    subtitle: 'Awaiting rider dispatch',
                    icon: Icons.outbox_rounded,
                    iconColor: const Color(0xFFF37021),
                    width: cardWidth,
                  ),
                  _buildDeliveredKpiCard(
                    isDark,
                    title: '🚴 In-Transit Live',
                    value: '$inTransitCount Active',
                    subtitle: 'Out on delivery routes',
                    icon: Icons.local_shipping_rounded,
                    iconColor: const Color(0xFF0284C7),
                    width: cardWidth,
                  ),
                  _buildDeliveredKpiCard(
                    isDark,
                    title: '🟢 Fulfilled / POD',
                    value: '$deliveredCount Delivered',
                    subtitle: 'Rev: ${CurrencyFormatter.formatNaira(deliveredRevenue)}',
                    icon: Icons.check_circle_rounded,
                    iconColor: const Color(0xFF16A34A),
                    width: cardWidth,
                  ),
                  _buildDeliveredKpiCard(
                    isDark,
                    title: '⚠️ Failed / Returns',
                    value: '$failedCount Issues',
                    subtitle: 'Call backs & returns',
                    icon: Icons.warning_amber_rounded,
                    iconColor: const Color(0xFFDC2626),
                    width: cardWidth,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // 3. Multi-Attribute Filter Toolbar Card
          Container(
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
                // Top Row: Search & View Mode Switcher
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('dc_master_search_input'),
                        controller: _masterSearchController,
                        onChanged: (val) => ref.read(dcMasterSearchProvider.notifier).state = val,
                        decoration: InputDecoration(
                          hintText: 'Search by Order #, Customer Name, Phone, Address, Product, Client, or Rider...',
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                          suffixIcon: masterSearch.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16),
                                  onPressed: () {
                                    _masterSearchController.clear();
                                    ref.read(dcMasterSearchProvider.notifier).state = '';
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // View Mode Switcher Toggle
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.table_rows_rounded,
                              size: 18,
                              color: viewMode == 'table' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                            ),
                            tooltip: 'Data Table View',
                            onPressed: () => ref.read(dcMasterViewModeProvider.notifier).state = 'table',
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.grid_view_rounded,
                              size: 18,
                              color: viewMode == 'grid' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                            ),
                            tooltip: 'Cards Grid View',
                            onPressed: () => ref.read(dcMasterViewModeProvider.notifier).state = 'grid',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Bottom Row: Dropdown Filters (Status, Rider, Product, Client, Reset)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // 1. Status Filter Dropdown
                    _buildFilterDropdown(
                      label: 'Status',
                      icon: Icons.filter_alt_outlined,
                      value: masterStatus,
                      isDark: isDark,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                        DropdownMenuItem(value: 'unassigned', child: Text('📦 Unassigned (Pending)')),
                        DropdownMenuItem(value: 'in_transit', child: Text('🚴 In Transit (Assigned)')),
                        DropdownMenuItem(value: 'delivered', child: Text('🟢 Delivered (Fulfilled)')),
                        DropdownMenuItem(value: 'failed', child: Text('⚠️ Failed / Call Back')),
                        DropdownMenuItem(value: 'returned', child: Text('↩️ Returned to DC')),
                      ],
                      onChanged: (val) {
                        if (val != null) ref.read(dcMasterStatusFilterProvider.notifier).state = val;
                      },
                    ),

                    // 2. Rider Filter Dropdown
                    _buildFilterDropdown(
                      label: 'Rider',
                      icon: Icons.two_wheeler_rounded,
                      value: masterRider,
                      isDark: isDark,
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('All Riders')),
                        const DropdownMenuItem(value: 'unassigned', child: Text('📦 Unassigned Only')),
                        ...fleetDrivers.map((d) {
                          return DropdownMenuItem(
                            value: d.id,
                            child: Text('🚴 ${d.name} (${d.driverCode})'),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        if (val != null) ref.read(dcMasterRiderFilterProvider.notifier).state = val;
                      },
                    ),

                    // 3. Product Filter Dropdown
                    _buildFilterDropdown(
                      label: 'Product',
                      icon: Icons.inventory_2_outlined,
                      value: masterProduct,
                      isDark: isDark,
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('All Products')),
                        ...uniqueProducts.map((p) {
                          return DropdownMenuItem(
                            value: p,
                            child: Text(p),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        if (val != null) ref.read(dcMasterProductFilterProvider.notifier).state = val;
                      },
                    ),

                    // 4. Client Filter Dropdown
                    _buildFilterDropdown(
                      label: 'Client',
                      icon: Icons.business_rounded,
                      value: masterClient,
                      isDark: isDark,
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('All Clients')),
                        ...uniqueClients.map((c) {
                          return DropdownMenuItem(
                            value: c,
                            child: Text(c),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        if (val != null) ref.read(dcMasterClientFilterProvider.notifier).state = val;
                      },
                    ),

                    // Reset Filters Button
                    if (hasActiveFilters)
                      TextButton.icon(
                        onPressed: () {
                          _masterSearchController.clear();
                          ref.read(dcMasterSearchProvider.notifier).state = '';
                          ref.read(dcMasterStatusFilterProvider.notifier).state = 'all';
                          ref.read(dcMasterRiderFilterProvider.notifier).state = 'all';
                          ref.read(dcMasterProductFilterProvider.notifier).state = 'all';
                          ref.read(dcMasterClientFilterProvider.notifier).state = 'all';
                        },
                        icon: const Icon(Icons.restart_alt_rounded, size: 16, color: Color(0xFFEF4444)),
                        label: const Text('Reset Filters', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Orders Directory View (Table or Grid)
          if (ordersState.isLoading)
            Column(
              children: List.generate(4, (index) => const OrderCardSkeleton()),
            )
          else if (filtered.isEmpty)
            _buildEmptyState(
              isDark,
              icon: Icons.search_off_rounded,
              title: 'No Orders Match Your Filters',
              subtitle: 'Try adjusting your search query, status, rider, product, or date filters to find matching shipments.',
            )
          else if (viewMode == 'table')
            _buildMasterOrdersTable(context, isDark, filtered, dcState, ordersState)
          else
            _buildMasterOrdersGrid(context, isDark, filtered, dcState, ordersState),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required IconData icon,
    required String value,
    required bool isDark,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    // Ensure value exists in items
    final bool valueExists = items.any((item) => item.value == value);
    final safeValue = valueExists ? value : 'all';

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: safeValue != 'all' ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: safeValue != 'all' ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: safeValue != 'all' ? FontWeight.bold : FontWeight.w500,
                color: safeValue != 'all' ? const Color(0xFF2563EB) : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              items: items,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterOrdersTable(
    BuildContext context,
    bool isDark,
    List<OrderEntity> orders,
    DCConsoleState dcState,
    OrdersState ordersState,
  ) {
    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
            headingRowHeight: 46,
            dataRowMaxHeight: 64,
            columnSpacing: 18,
            columns: [
              const DataColumn(label: Text('Order # & Date', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text('Customer & Phone', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text('Destination', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text('Product & Qty', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text('Amount & Payment', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text('Client', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text('Assigned Rider', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: orders.map((order) {
              final isUnassigned = order.deliveryAgentId == null || order.deliveryAgentId!.isEmpty;
              final isDelivered = order.status == 'delivered';
              final isFailed = order.status == 'cancelled' || order.status == 'failed' || order.status == 'call_back';
              final isReturned = order.status == 'returned';
              final isPrepaid = order.paymentType == 'prepaid' || order.isDirectTransfer;

              return DataRow(
                cells: [
                  // 1. Order # & Date
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '#${order.orderNumber}',
                          style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                        ),
                        Text(
                          DateTimeFormatter.formatRelativeTime(order.createdAt),
                          style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),

                  // 2. Customer & Phone
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          order.customerName,
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          order.customerPhone,
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),

                  // 3. Destination
                  DataCell(
                    Container(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            order.deliveryAddress,
                            style: GoogleFonts.inter(fontSize: 11.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${order.deliveryCity}, ${order.deliveryState}',
                            style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 4. Product & Qty
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${order.quantity}x',
                            style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF7C3AED)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(
                            order.productName,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 5. Amount & Payment
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          CurrencyFormatter.formatNaira(order.totalAmount),
                          style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isPrepaid ? const Color(0xFFE0E7FF) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isPrepaid ? 'PREPAID' : 'POD CASH',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isPrepaid ? const Color(0xFF4338CA) : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 6. Client
                  DataCell(
                    Text(
                      order.clientName.isNotEmpty ? order.clientName : 'Novacare Limited',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // 7. Assigned Rider
                  DataCell(
                    isUnassigned
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF37021).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Unassigned',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFF37021)),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.two_wheeler_rounded, size: 14, color: Color(0xFF2563EB)),
                              const SizedBox(width: 4),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    order.deliveryAgentName ?? 'Assigned Rider',
                                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    order.deliveryAgentCode ?? 'PDA-7000',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),

                  // 8. Status Badge
                  DataCell(
                    _buildOrderStatusBadge(order),
                  ),

                  // 9. Actions
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isUnassigned && !isDelivered && !isFailed && !isReturned) ...[
                          ElevatedButton.icon(
                            onPressed: () {
                              _showAssignRiderModal(context, isDark, order, dcState, ordersState);
                            },
                            icon: const Icon(Icons.send_rounded, size: 13, color: Colors.white),
                            label: const Text('Assign Rider', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF37021),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF2563EB)),
                          tooltip: 'View Order Details & Audit Trail',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => DCOrderDetailModal(order: order),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMasterOrdersGrid(
    BuildContext context,
    bool isDark,
    List<OrderEntity> orders,
    DCConsoleState dcState,
    OrdersState ordersState,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 650 ? 1 : (constraints.maxWidth < 1100 ? 2 : 3);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.6,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: orders.length,
          itemBuilder: (ctx, idx) {
            final order = orders[idx];
            final isUnassigned = order.deliveryAgentId == null || order.deliveryAgentId!.isEmpty;
            final isDelivered = order.status == 'delivered';
            final isFailed = order.status == 'cancelled' || order.status == 'failed' || order.status == 'call_back';

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('#${order.orderNumber}', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
                      _buildOrderStatusBadge(order),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.customerName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('${order.customerPhone} • ${order.deliveryAddress}, ${order.deliveryCity}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('${order.quantity}x ${order.productName} • ${CurrencyFormatter.formatNaira(order.totalAmount)}', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF16A34A))),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isUnassigned ? 'Unassigned' : '🚴 ${order.deliveryAgentName ?? "Rider"}',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: isUnassigned ? const Color(0xFFF37021) : const Color(0xFF2563EB)),
                      ),
                      Row(
                        children: [
                          if (isUnassigned && !isDelivered && !isFailed)
                            ElevatedButton(
                              onPressed: () => _showAssignRiderModal(context, isDark, order, dcState, ordersState),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF37021),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              child: const Text('Assign', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          const SizedBox(width: 6),
                          OutlinedButton(
                            onPressed: () => showDialog(context: context, builder: (ctx) => DCOrderDetailModal(order: order)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: const Text('Details', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOrderStatusBadge(OrderEntity order) {
    final status = order.status.toLowerCase();
    final isUnassigned = order.deliveryAgentId == null || order.deliveryAgentId!.isEmpty;

    if (status == 'delivered') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
        child: Text('DELIVERED', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
      );
    }
    if (status == 'returned') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
        child: Text('RETURNED', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFFB45309))),
      );
    }
    if (status == 'failed' || status == 'cancelled' || status == 'call_back') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(6)),
        child: Text('FAILED / CB', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626))),
      );
    }
    if (isUnassigned) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFFFEDD5))),
        child: Text('UNASSIGNED', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFFEA580C))),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
      child: Text('IN TRANSIT', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
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
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => const DCCsvOrderImportModal(),
                      );
                    },
                    icon: const Icon(Icons.upload_file_rounded, size: 16, color: Colors.white),
                    label: const Text('Import CSV', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
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
      barrierDismissible: false,
      builder: (ctx) => DCAssignOrderModal(order: order),
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
    final riderName = order.deliveryAgentName ?? 'Assigned Rider';
    final riderCode = order.deliveryAgentCode ?? 'PDA-RIDER';

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
