import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/widgets/app_loading_overlay.dart';
import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../../stock/domain/entities/rider_stock_allocation.dart';
import '../../../stock/domain/entities/stock_item.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../domain/entities/dc_finance_settings.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../../domain/entities/dc_transaction_record.dart';
import '../providers/dc_console_provider.dart';

final riderOrdersSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final riderOrdersFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');
final riderOrdersSortProvider = StateProvider.autoDispose<String>((ref) => 'newest');

final riderRemittanceSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final riderRemittanceFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');
final riderRemittanceSortProvider = StateProvider.autoDispose<String>((ref) => 'newest');

final riderStockSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final riderStockFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');
final riderStockSortProvider = StateProvider.autoDispose<String>((ref) => 'quantity_high');

class DCRiderDetailModal extends ConsumerStatefulWidget {
  final DCFleetDriver driver;

  const DCRiderDetailModal({super.key, required this.driver});

  static Future<void> show(BuildContext context, DCFleetDriver driver) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DCRiderDetailModal(driver: driver),
    );
  }

  @override
  ConsumerState<DCRiderDetailModal> createState() => _DCRiderDetailModalState();
}

class _DCRiderDetailModalState extends ConsumerState<DCRiderDetailModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _ordersSearchController = TextEditingController();
  final TextEditingController _remittanceSearchController = TextEditingController();
  final TextEditingController _stockSearchController = TextEditingController();
  Timer? _searchDebounceTimer;

  void _onDebouncedSearch(void Function() action) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        action();
      }
    });
  }

  // Profile & Terms Edit Controllers
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _vehicleTypeController;
  late TextEditingController _vehiclePlateController;
  late TextEditingController _vehicleModelController;
  late TextEditingController _assignedZoneController;
  late TextEditingController _commissionRateController;
  late TextEditingController _transportAllowanceController;
  late TextEditingController _failedDeliveryAllowanceController;
  late TextEditingController _baseSalaryController;
  late TextEditingController _bankNameController;
  late TextEditingController _bankAccountNumberController;
  late TextEditingController _bankAccountNameController;
  late TextEditingController _passwordController;

  late String _personnelType;
  late String _compensationType;
  late bool _isActive;
  bool _isPasswordVisible = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    final d = widget.driver;
    _nameController = TextEditingController(text: d.name);
    _phoneController = TextEditingController(text: d.phone);
    _emailController = TextEditingController(text: d.email);
    _vehicleTypeController = TextEditingController(text: d.vehicleType);
    _vehiclePlateController = TextEditingController(text: d.vehiclePlate);
    _vehicleModelController = TextEditingController(text: d.vehicleModel);
    _assignedZoneController = TextEditingController(text: d.assignedZone);
    _commissionRateController = TextEditingController(text: d.commissionRate.toStringAsFixed(0));
    _transportAllowanceController = TextEditingController(text: d.transportAllowance.toStringAsFixed(0));
    _failedDeliveryAllowanceController = TextEditingController(text: d.failedDeliveryAllowance.toStringAsFixed(0));
    _baseSalaryController = TextEditingController(text: d.baseSalary.toStringAsFixed(0));
    _bankNameController = TextEditingController(text: d.bankName);
    _bankAccountNumberController = TextEditingController(text: d.bankAccountNumber);
    _bankAccountNameController = TextEditingController(text: d.bankAccountName);
    _passwordController = TextEditingController();

    _personnelType = d.personnelType;
    _compensationType = d.compensationType;
    _isActive = d.status.toLowerCase() != 'inactive' && d.status.toLowerCase() != 'deactivated';
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _tabController.dispose();
    _ordersSearchController.dispose();
    _remittanceSearchController.dispose();
    _stockSearchController.dispose();

    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _vehicleTypeController.dispose();
    _vehiclePlateController.dispose();
    _vehicleModelController.dispose();
    _assignedZoneController.dispose();
    _commissionRateController.dispose();
    _transportAllowanceController.dispose();
    _failedDeliveryAllowanceController.dispose();
    _baseSalaryController.dispose();
    _bankNameController.dispose();
    _bankAccountNumberController.dispose();
    _bankAccountNameController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final dcState = ref.watch(dcConsoleProvider);
    final currentDriver = dcState.drivers.firstWhere(
      (d) => d.id == widget.driver.id || d.driverCode == widget.driver.driverCode || (d.email.isNotEmpty && d.email.toLowerCase() == widget.driver.email.toLowerCase()),
      orElse: () => widget.driver,
    );
    final driver = currentDriver;

    final ordersState = ref.watch(ordersProvider);
    final stockState = ref.watch(stockProvider);

    // 1. Get real orders for this driver
    final assignedOrders = ordersState.orders.where((o) {
      return (o.deliveryAgentId != null && o.deliveryAgentId == driver.id) ||
          (o.deliveryAgentCode != null && o.deliveryAgentCode == driver.driverCode) ||
          (o.deliveryAgentName != null &&
              o.deliveryAgentName!.toLowerCase() == driver.name.toLowerCase());
    }).toList();

    // 2. Get real transactions/remittances for this driver
    final driverTransactions = dcState.transactions.where((t) {
      return (t.riderId.isNotEmpty && t.riderId == driver.id) ||
          (t.riderCode.isNotEmpty && t.riderCode == driver.driverCode) ||
          (t.riderName.isNotEmpty &&
              t.riderName.toLowerCase() == driver.name.toLowerCase());
    }).toList();

    // 3. Compute real stocks in custody for this driver (merging orders & direct warehouse allocations)
    final riderAllocations = stockState.getAllocationsForRider(driver.id, driver.driverCode);
    final custodyStockMap = _computeDriverStockCustody(assignedOrders, stockState.stockItems, riderAllocations);

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 768;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 16,
        vertical: isMobile ? 12 : 20,
      ),
      child: Container(
        width: isMobile ? double.infinity : 1000,
        constraints: BoxConstraints(maxHeight: isMobile ? screenHeight * 0.96 : 880),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Modal Top Header
            _buildModalHeader(context, isDark, driver),

            // Tab Navigation Bar
            _buildTabBar(isDark, assignedOrders.length, driverTransactions.length, custodyStockMap.length),

            // Tab Content Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Details, Live KPIs & Personal Terms
                  _buildProfileAndTermsTab(isDark, driver, assignedOrders, driverTransactions),

                  // Tab 2: Orders
                  _buildOrdersTab(isDark, assignedOrders, driver),

                  // Tab 3: Remittance & Finance
                  _buildRemittanceTab(isDark, driverTransactions, assignedOrders, driver, dcState.financeSettings),

                  // Tab 4: Stocks in Custody
                  _buildStocksTab(isDark, custodyStockMap, assignedOrders, driver),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // HEADER
  // ==========================================
  Widget _buildModalHeader(BuildContext context, bool isDark, DCFleetDriver driver) {
    final isPda = driver.isPda;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 650;

          final vehicleInfo = driver.vehiclePlate.isNotEmpty
              ? (driver.vehicleModel.isNotEmpty
                  ? (driver.vehicleModel.contains(driver.vehiclePlate)
                      ? driver.vehicleModel
                      : '${driver.vehicleModel} (${driver.vehiclePlate})')
                  : '${driver.vehicleType} (${driver.vehiclePlate})')
              : (driver.vehicleModel.isNotEmpty ? driver.vehicleModel : driver.vehicleType);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDriverAvatar(
                driver,
                radius: isCompact ? 22 : 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          driver.name,
                          style: GoogleFonts.inter(
                            fontSize: isCompact ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPda
                                ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                                : const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isPda ? 'PDA (Personal)' : 'In-House Fleet',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: isPda ? const Color(0xFF2563EB) : const Color(0xFF059669),
                            ),
                          ),
                        ),
                        _buildStatusBadge(driver.status),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (driver.driverCode.isNotEmpty)
                          _buildHeaderMetaChip(Icons.badge_outlined, driver.driverCode, isDark),
                        if (driver.phone.isNotEmpty)
                          _buildHeaderMetaChip(Icons.phone_outlined, driver.phone, isDark),
                        if (vehicleInfo.isNotEmpty)
                          _buildHeaderMetaChip(Icons.two_wheeler_outlined, vehicleInfo, isDark),
                        if (driver.assignedZone.isNotEmpty)
                          _buildHeaderMetaChip(Icons.location_on_outlined, driver.assignedZone, isDark),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!isCompact) ...[
                IconButton.filledTonal(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: driver.phone));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('📋 Copied ${driver.name}\'s phone number (${driver.phone}) to clipboard.')),
                    );
                  },
                  icon: const Icon(Icons.phone_rounded, size: 18),
                  tooltip: 'Copy Phone Number',
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('⚠️ Alert notification dispatched to ${driver.name}.')),
                    );
                  },
                  icon: const Icon(Icons.notifications_active_rounded, size: 18),
                  tooltip: 'Send DC Alert',
                ),
                const SizedBox(width: 6),
              ],
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: 'Close Modal',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDriverAvatar(
    DCFleetDriver driver, {
    double radius = 24,
    Color? backgroundColor,
    Color? textColor,
  }) {
    return UserAvatarWidget(
      avatarUrl: driver.avatarUrl,
      fullName: driver.name,
      radius: radius,
      backgroundColor: backgroundColor ?? const Color(0xFF2563EB).withValues(alpha: 0.15),
      textColor: textColor ?? const Color(0xFF2563EB),
    );
  }

  Widget _buildHeaderMetaChip(IconData icon, String label, bool isDark) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label = status.toUpperCase().replaceAll('_', ' ');

    switch (status.toLowerCase()) {
      case 'active':
      case 'available':
        bg = const Color(0xFF10B981).withValues(alpha: 0.15);
        fg = const Color(0xFF059669);
        break;
      case 'delayed':
      case 'on_delivery':
        bg = const Color(0xFFF37021).withValues(alpha: 0.15);
        fg = const Color(0xFFF37021);
        break;
      case 'inactive':
      case 'deactivated':
        bg = const Color(0xFFEF4444).withValues(alpha: 0.15);
        fg = const Color(0xFFDC2626);
        break;
      default:
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
        fg = const Color(0xFFD97706);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  // ==========================================
  // TAB BAR
  // ==========================================
  Widget _buildTabBar(bool isDark, int orderCount, int txnCount, int stockCount) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF1F5F9),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: const Color(0xFF2563EB),
        unselectedLabelColor: const Color(0xFF64748B),
        indicatorColor: const Color(0xFF2563EB),
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
        labelStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500),
        tabs: [
          const Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_outline_rounded, size: 15),
                SizedBox(width: 6),
                Text('Profile'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inventory_2_outlined, size: 15),
                const SizedBox(width: 6),
                Text('Orders ($orderCount)'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 15),
                const SizedBox(width: 6),
                Text('Remittances ($txnCount)'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.layers_outlined, size: 15),
                const SizedBox(width: 6),
                Text('Stock ($stockCount)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: ORDERS
  // ==========================================
  Widget _buildOrdersTab(bool isDark, List<OrderEntity> allOrders, DCFleetDriver driver) {
    // 1. Compute real dynamic KPI aggregators
    final totalAssigned = allOrders.length;
    final deliveredCount = allOrders.where((o) => o.status == 'delivered').length;
    final inTransitCount = allOrders.where((o) => o.status == 'in_transit' || o.status == 'pending').length;
    final failedCount = allOrders.where((o) => o.status == 'failed' || o.status == 'cancelled' || o.status == 'returned').length;
    final totalOrderValue = allOrders.fold<double>(0.0, (sum, o) => sum + o.totalAmount);
    final successRate = totalAssigned > 0 ? (deliveredCount / totalAssigned) * 100 : 100.0;

    // 2. Filter orders
    final ordersSearchQuery = ref.watch(riderOrdersSearchProvider);
    final ordersFilter = ref.watch(riderOrdersFilterProvider);
    final ordersSort = ref.watch(riderOrdersSortProvider);

    // 2. Filter orders
    var filtered = allOrders.where((o) {
      if (ordersFilter != 'all') {
        if (ordersFilter == 'delivered' && o.status != 'delivered') return false;
        if (ordersFilter == 'in_transit' && o.status != 'in_transit') return false;
        if (ordersFilter == 'pending' && o.status != 'pending') return false;
        if (ordersFilter == 'failed' && o.status != 'failed' && o.status != 'cancelled' && o.status != 'returned') return false;
      }
      if (ordersSearchQuery.trim().isNotEmpty) {
        final q = ordersSearchQuery.toLowerCase().trim();
        final matchesCode = o.orderNumber.toLowerCase().contains(q);
        final matchesCustomer = o.customerName.toLowerCase().contains(q);
        final matchesPhone = o.customerPhone.contains(q);
        final matchesAddress = o.deliveryAddress.toLowerCase().contains(q);
        final matchesProduct = o.productName.toLowerCase().contains(q);
        return matchesCode || matchesCustomer || matchesPhone || matchesAddress || matchesProduct;
      }
      return true;
    }).toList();

    // 3. Sort orders
    if (ordersSort == 'newest') {
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else if (ordersSort == 'oldest') {
      filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else if (ordersSort == 'amount_high') {
      filtered.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    } else if (ordersSort == 'name_az') {
      filtered.sort((a, b) => a.customerName.compareTo(b.customerName));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. KPI Cards in One Row (Responsive)
          LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth;
              if (constraints.maxWidth < 600) {
                cardWidth = constraints.maxWidth;
              } else if (constraints.maxWidth < 900) {
                cardWidth = (constraints.maxWidth - 12) / 2;
              } else {
                cardWidth = (constraints.maxWidth - 36) / 4;
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _buildKpiCard(
                      '📦 Total Assigned',
                      '$totalAssigned Orders',
                      'Gross value: ${CurrencyFormatter.formatNaira(totalOrderValue)}',
                      const Color(0xFF2563EB),
                      isDark,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildKpiCard(
                      '✅ Delivered / POD',
                      '$deliveredCount Done',
                      '${successRate.toStringAsFixed(1)}% fulfillment rate',
                      const Color(0xFF10B981),
                      isDark,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildKpiCard(
                      '🚚 Active on Route',
                      '$inTransitCount In-Transit',
                      '${driver.assignedZone} sector',
                      const Color(0xFFF37021),
                      isDark,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildKpiCard(
                      '❌ Failed / Returned',
                      '$failedCount Orders',
                      'Undelivered or cancelled drops',
                      const Color(0xFFEF4444),
                      isDark,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 18),

          // 2. Search Bar, Filters & Sorting
          _buildSearchAndFilterControls(
            isDark: isDark,
            searchController: _ordersSearchController,
            searchHint: 'Search orders by code, customer, phone, or address...',
            onSearchChanged: (val) => _onDebouncedSearch(() => ref.read(riderOrdersSearchProvider.notifier).state = val),
            filterChips: [
              _buildFilterButton('All ($totalAssigned)', 'all', ordersFilter, (val) => ref.read(riderOrdersFilterProvider.notifier).state = val),
              _buildFilterButton('✅ Delivered ($deliveredCount)', 'delivered', ordersFilter, (val) => ref.read(riderOrdersFilterProvider.notifier).state = val, activeColor: const Color(0xFF10B981)),
              _buildFilterButton('🚚 In-Transit ($inTransitCount)', 'in_transit', ordersFilter, (val) => ref.read(riderOrdersFilterProvider.notifier).state = val, activeColor: const Color(0xFFF37021)),
              _buildFilterButton('❌ Failed ($failedCount)', 'failed', ordersFilter, (val) => ref.read(riderOrdersFilterProvider.notifier).state = val, activeColor: const Color(0xFFEF4444)),
            ],
            sortWidget: _buildSortDropdown(
              value: ordersSort,
              items: const [
                DropdownMenuItem(value: 'newest', child: Text('Newest First')),
                DropdownMenuItem(value: 'oldest', child: Text('Oldest First')),
                DropdownMenuItem(value: 'amount_high', child: Text('Highest Value')),
                DropdownMenuItem(value: 'name_az', child: Text('Customer A-Z')),
              ],
              onChanged: (val) => ref.read(riderOrdersSortProvider.notifier).state = val ?? 'newest',
              isDark: isDark,
            ),
          ),

          const SizedBox(height: 14),

          // 3. Minimalist Orders Table
          if (filtered.isEmpty)
            _buildEmptyState('No orders found matching the filter criteria.', isDark)
          else
            _buildMinimalistOrdersTable(filtered, isDark),
        ],
      ),
    );
  }

  Widget _buildMinimalistOrdersTable(List<OrderEntity> orders, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 750;

          if (isNarrow) {
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: orders.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              itemBuilder: (ctx, i) => _buildMobileOrderCard(orders[i], isDark),
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columnSpacing: 20,
                horizontalMargin: 16,
                headingRowHeight: 40,
                headingRowColor: WidgetStateProperty.all(
                  isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
                ),
                headingTextStyle: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
                columns: const [
                  DataColumn(label: Text('ORDER #')),
                  DataColumn(label: Text('CUSTOMER & DESTINATION')),
                  DataColumn(label: Text('PRODUCT & QTY')),
                  DataColumn(label: Text('CHANNEL')),
                  DataColumn(label: Text('AMOUNT')),
                  DataColumn(label: Text('STATUS')),
                ],
                rows: orders.map((order) {
                  return DataRow(
                    cells: [
                      // Order Number
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_shipping_outlined, size: 15, color: Color(0xFF2563EB)),
                            const SizedBox(width: 6),
                            Text(
                              order.orderNumber,
                              style: GoogleFonts.firaCode(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Customer & Destination
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.customerName,
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${order.customerPhone} • ${order.deliveryAddress}',
                              style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Product & Qty
                      DataCell(
                        Text(
                          '${order.quantity}x ${order.productName}',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),

                      // Channel
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              order.isDirectTransfer ? Icons.bolt_rounded : Icons.payments_rounded,
                              size: 14,
                              color: order.isDirectTransfer ? const Color(0xFF2563EB) : const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              order.isDirectTransfer ? 'Paystack' : 'Cash POD',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: order.isDirectTransfer ? const Color(0xFF2563EB) : const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Amount
                      DataCell(
                        Text(
                          CurrencyFormatter.formatNaira(order.totalAmount),
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),

                      // Status
                      DataCell(_buildOrderStatusPill(order.status)),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileOrderCard(OrderEntity order, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.orderNumber,
                style: GoogleFonts.firaCode(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
              ),
              _buildOrderStatusPill(order.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(order.customerName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
          Text('${order.customerPhone} • ${order.deliveryAddress}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${order.quantity}x ${order.productName}', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8))),
              Text(CurrencyFormatter.formatNaira(order.totalAmount), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: REMITTANCE & FINANCE
  // ==========================================
  // TAB 2: REMITTANCE & FINANCE (Paystack Automated)
  // ==========================================
  Widget _buildRemittanceTab(
    bool isDark,
    List<DCTransactionRecord> transactions,
    List<OrderEntity> orders,
    DCFleetDriver driver,
    DCFinanceSettings settings,
  ) {
    // 1. Compute real dynamic KPI aggregators (matching unified FinancialSummary)
    final deliveredOrders = orders.where((o) => o.status == 'delivered').toList();
    final deliveredCashOrders = deliveredOrders.where((o) => !o.isDirectTransfer).toList();
    final deliveredDirectOrders = deliveredOrders.where((o) => o.isDirectTransfer).toList();

    final totalCashCollected = deliveredCashOrders.fold<double>(0.0, (s, o) => s + o.totalAmount);
    final totalDirectPaystack = deliveredDirectOrders.fold<double>(0.0, (s, o) => s + o.totalAmount);
    final totalGrossCollected = totalCashCollected + totalDirectPaystack;

    // Retained Earnings (Commission + Transport allowance on cash orders)
    final cashCommissionRetained = deliveredCashOrders.length * driver.commissionRate;
    final cashTransportRetained = deliveredCashOrders.length * driver.transportAllowance;
    final cashEarningsRetained = cashCommissionRetained + cashTransportRetained;

    // Retained POS / Transfer fees factoring active DC policy (Flat vs Dynamic applied per remittance transaction)
    final totalTransferFeesRetained = settings.isPosFeeReimbursable
        ? transactions
            .where((t) => t.isRemittance && t.isVerified)
            .fold<double>(
              0.0,
              (acc, t) => acc + (t.transactionFee > 0 ? t.transactionFee : settings.computePosFee(t.amount)),
            )
        : 0.0;

    // Total Cash POD remittances completed & verified into company Paystack account
    final totalRemittedCash = transactions
        .where((t) => t.isRemittance && t.isVerified)
        .fold<double>(0.0, (s, t) => s + t.amount);

    final toRemit = (totalCashCollected - cashEarningsRetained - totalTransferFeesRetained - totalRemittedCash).clamp(0.0, double.infinity);

    // Total Commission (Transport + Commission) across all delivered orders
    final totalCommissionEarned = deliveredOrders.length * driver.totalPerDeliveryEntitlement;

    // His Balance (Company payout due to rider for direct Paystack orders)
    final hisBalanceDue = deliveredDirectOrders.length * driver.totalPerDeliveryEntitlement;

    final remittanceSearchQuery = ref.watch(riderRemittanceSearchProvider);
    final remittanceFilter = ref.watch(riderRemittanceFilterProvider);
    final remittanceSort = ref.watch(riderRemittanceSortProvider);

    // 2. Filter transactions
    var filtered = transactions.where((t) {
      if (remittanceFilter != 'all') {
        if (remittanceFilter == 'paystack' && !t.isPaystack) return false;
        if (remittanceFilter == 'cash' && !t.isCashPod && !t.isRemittance) return false;
        if (remittanceFilter == 'remitted' && !(t.isRemittance && t.isVerified)) return false;
        if (remittanceFilter == 'settled' && !(t.isPaystack && t.isVerified)) return false;
        if (remittanceFilter == 'pending' && !t.isPending) return false;
      }
      if (remittanceSearchQuery.trim().isNotEmpty) {
        final q = remittanceSearchQuery.toLowerCase().trim();
        final matchesCode = t.transactionCode.toLowerCase().contains(q);
        final matchesOrder = t.orderNumber != null && t.orderNumber!.toLowerCase().contains(q);
        final matchesRef = t.gatewayReference != null && t.gatewayReference!.toLowerCase().contains(q);
        final matchesCustomer = t.customerName != null && t.customerName!.toLowerCase().contains(q);
        return matchesCode || matchesOrder || matchesRef || matchesCustomer;
      }
      return true;
    }).toList();

    // 3. Sort
    if (remittanceSort == 'newest') {
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else if (remittanceSort == 'amount_high') {
      filtered.sort((a, b) => b.amount.compareTo(a.amount));
    } else if (remittanceSort == 'fee_high') {
      filtered.sort((a, b) => b.effectiveTransactionFee.compareTo(a.effectiveTransactionFee));
    } else if (remittanceSort == 'status') {
      filtered.sort((a, b) => a.status.compareTo(b.status));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Four Major KPI Cards in One Row (Responsive)
          LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth;
              if (constraints.maxWidth < 600) {
                cardWidth = constraints.maxWidth;
              } else if (constraints.maxWidth < 950) {
                cardWidth = (constraints.maxWidth - 12) / 2;
              } else {
                cardWidth = (constraints.maxWidth - 36) / 4;
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  // KPI 1: Gross Collected
                  SizedBox(
                    width: cardWidth,
                    child: _buildKpiCard(
                      '💵 Gross Collected',
                      CurrencyFormatter.formatNaira(totalGrossCollected),
                      'POD: ${CurrencyFormatter.formatNaira(totalCashCollected)} • Paystack: ${CurrencyFormatter.formatNaira(totalDirectPaystack)}',
                      const Color(0xFF10B981),
                      isDark,
                    ),
                  ),

                  // KPI 2: To Remit
                  SizedBox(
                    width: cardWidth,
                    child: _buildKpiCard(
                      '⏳ To Remit',
                      CurrencyFormatter.formatNaira(toRemit),
                      toRemit > 0 ? 'Physical cash in hand to deposit' : 'All Cash POD remitted ✓',
                      toRemit > 0 ? const Color(0xFFF59E0B) : const Color(0xFF059669),
                      isDark,
                    ),
                  ),

                  // KPI 3: Commission (Transport + Commission)
                  SizedBox(
                    width: cardWidth,
                    child: _buildKpiCard(
                      '💼 Commission',
                      CurrencyFormatter.formatNaira(totalCommissionEarned),
                      '₦${driver.commissionRate.toInt()} Comm + ₦${driver.transportAllowance.toInt()} Transport / drop',
                      const Color(0xFF8B5CF6),
                      isDark,
                    ),
                  ),

                  // KPI 4: His Balance (Company Payout Due)
                  SizedBox(
                    width: cardWidth,
                    child: _buildKpiCard(
                      '🏦 His Balance',
                      CurrencyFormatter.formatNaira(hisBalanceDue),
                      'Company payout due for ${deliveredDirectOrders.length} direct orders',
                      const Color(0xFF2563EB),
                      isDark,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 18),

          // 2. Search Bar, Filters & Sorting
          _buildSearchAndFilterControls(
            isDark: isDark,
            searchController: _remittanceSearchController,
            searchHint: 'Search remittances by TX code, order ref, or gateway reference...',
            onSearchChanged: (val) => _onDebouncedSearch(() => ref.read(riderRemittanceSearchProvider.notifier).state = val),
            filterChips: [
              _buildFilterButton('All (${transactions.length})', 'all', remittanceFilter, (val) => ref.read(riderRemittanceFilterProvider.notifier).state = val),
              _buildFilterButton('⚡ Paystack', 'paystack', remittanceFilter, (val) => ref.read(riderRemittanceFilterProvider.notifier).state = val, activeColor: const Color(0xFF2563EB)),
              _buildFilterButton('💵 Cash POD', 'cash', remittanceFilter, (val) => ref.read(riderRemittanceFilterProvider.notifier).state = val, activeColor: const Color(0xFF10B981)),
              _buildFilterButton('✅ Remitted', 'remitted', remittanceFilter, (val) => ref.read(riderRemittanceFilterProvider.notifier).state = val, activeColor: const Color(0xFF059669)),
              _buildFilterButton('⚡ Settled', 'settled', remittanceFilter, (val) => ref.read(riderRemittanceFilterProvider.notifier).state = val, activeColor: const Color(0xFF2563EB)),
              _buildFilterButton('⏳ Pending', 'pending', remittanceFilter, (val) => ref.read(riderRemittanceFilterProvider.notifier).state = val, activeColor: const Color(0xFFF59E0B)),
            ],
            sortWidget: _buildSortDropdown(
              value: remittanceSort,
              items: const [
                DropdownMenuItem(value: 'newest', child: Text('Newest First')),
                DropdownMenuItem(value: 'amount_high', child: Text('Highest Amount')),
                DropdownMenuItem(value: 'fee_high', child: Text('Highest Fee')),
                DropdownMenuItem(value: 'status', child: Text('By Status')),
              ],
              onChanged: (val) => ref.read(riderRemittanceSortProvider.notifier).state = val ?? 'newest',
              isDark: isDark,
            ),
          ),

          const SizedBox(height: 14),

          // 3. Minimalist Remittance Table
          if (filtered.isEmpty)
            _buildEmptyState('No remittance records found for this agent.', isDark)
          else
            _buildMinimalistRemittanceTable(filtered, isDark, driver, settings),
        ],
      ),
    );
  }

  Widget _buildMinimalistRemittanceTable(List<DCTransactionRecord> txns, bool isDark, DCFleetDriver driver, DCFinanceSettings settings) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 850;

          if (isNarrow) {
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: txns.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              itemBuilder: (ctx, i) => _buildMobileRemittanceCard(txns[i], isDark, driver, settings),
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columnSpacing: 18,
                horizontalMargin: 16,
                headingRowHeight: 40,
                headingRowColor: WidgetStateProperty.all(
                  isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
                ),
                headingTextStyle: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
                columns: const [
                  DataColumn(label: Text('TX / REF CODE')),
                  DataColumn(label: Text('ORDER REF')),
                  DataColumn(label: Text('PAYMENT CHANNEL')),
                  DataColumn(label: Text('COLLECTED AMOUNT')),
                  DataColumn(label: Text('TRANSACTION FEE')),
                  DataColumn(label: Text('COMMISSION')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('DATE & TIME')),
                ],
                rows: txns.map((txn) {
                  final fee = txn.transactionFee > 0
                      ? txn.transactionFee
                      : (txn.isPaystack
                          ? settings.computePaystackFee(txn.amount)
                          : (txn.isRemittance || txn.isCashPod ? settings.computePosFee(txn.amount) : 0.0));
                  final feeType = txn.effectiveFeeType;

                  return DataRow(
                    cells: [
                      // Tx Code
                      DataCell(
                        Text(
                          txn.transactionCode,
                          style: GoogleFonts.firaCode(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                          ),
                        ),
                      ),

                      // Order Ref
                      DataCell(
                        Text(
                          txn.orderNumber ?? 'Direct Remit',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),

                      // Channel
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              txn.isPaystack ? Icons.bolt_rounded : Icons.account_balance_rounded,
                              size: 14,
                              color: txn.isPaystack ? const Color(0xFF2563EB) : const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 4),
                            Text(txn.channel, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),

                      // Collected Amount
                      DataCell(
                        Text(
                          CurrencyFormatter.formatNaira(txn.amount),
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),

                      // Transaction Fee (Paystack or POS Transfer Agent)
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fee > 0 ? CurrencyFormatter.formatNaira(fee) : '₦0.00',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: fee > 0 ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626)) : const Color(0xFF64748B),
                              ),
                            ),
                            if (fee > 0)
                              Text(
                                feeType,
                                style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B)),
                              ),
                          ],
                        ),
                      ),

                      // Commission (Transport + Commission)
                      DataCell(
                        Text(
                          CurrencyFormatter.formatNaira(driver.totalPerDeliveryEntitlement),
                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                        ),
                      ),

                      // Status (REMITTED, SETTLED, PENDING, PARTIAL)
                      DataCell(_buildTxnStatusPill(txn.paystackStatusDisplay)),

                      // Date & Time
                      DataCell(
                        Text(
                          '${txn.createdAt.day}/${txn.createdAt.month}/${txn.createdAt.year} ${txn.createdAt.hour.toString().padLeft(2, '0')}:${txn.createdAt.minute.toString().padLeft(2, '0')}',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileRemittanceCard(DCTransactionRecord txn, bool isDark, DCFleetDriver driver, DCFinanceSettings settings) {
    final fee = txn.transactionFee > 0
        ? txn.transactionFee
        : (txn.isPaystack
            ? settings.computePaystackFee(txn.amount)
            : (txn.isRemittance || txn.isCashPod ? settings.computePosFee(txn.amount) : 0.0));
    final feeType = txn.effectiveFeeType;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(txn.transactionCode, style: GoogleFonts.firaCode(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
              _buildTxnStatusPill(txn.paystackStatusDisplay),
            ],
          ),
          const SizedBox(height: 4),
          Text(txn.orderNumber != null ? 'Order: ${txn.orderNumber}' : 'Direct DC Remittance', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
          Text('Channel: ${txn.channel}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Collected Amount', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                  Text(CurrencyFormatter.formatNaira(txn.amount), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Fee: ${CurrencyFormatter.formatNaira(fee)} ($feeType)', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFEF4444))),
                  Text('Commission: ${CurrencyFormatter.formatNaira(driver.totalPerDeliveryEntitlement)}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF059669))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${txn.createdAt.day}/${txn.createdAt.month} ${txn.createdAt.hour}:${txn.createdAt.minute.toString().padLeft(2, '0')}',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: STOCKS IN CUSTODY & VEHICLE ALLOCATION
  // ==========================================
  Widget _buildStocksTab(
    bool isDark,
    List<_DriverCustodyStockItem> custodyItems,
    List<OrderEntity> orders,
    DCFleetDriver driver,
  ) {
    final stockState = ref.watch(stockProvider);

    // 1. Compute real dynamic KPI aggregators
    final totalUnitsHeld = custodyItems.fold<int>(0, (s, item) => s + item.inCustodyUnits);
    final shelfUnits = custodyItems.where((i) => i.fulfillmentType == 'distributed_inventory').fold<int>(0, (s, i) => s + i.inCustodyUnits);
    final clientPackages = custodyItems.where((i) => i.fulfillmentType == 'client_package').fold<int>(0, (s, i) => s + i.inCustodyUnits);
    final awaitingReturnUnits = custodyItems.fold<int>(0, (s, i) => s + i.awaitingReturnUnits);
    final totalStockValue = custodyItems.fold<double>(0.0, (s, i) => s + (i.inCustodyUnits * i.unitPrice));
    final lowStockCount = custodyItems.where((i) => i.isLowStock).length;

    final stockSearchQuery = ref.watch(riderStockSearchProvider);
    final stockFilter = ref.watch(riderStockFilterProvider);
    final stockSort = ref.watch(riderStockSortProvider);

    // 2. Filter
    var filtered = custodyItems.where((item) {
      if (stockFilter != 'all') {
        if (stockFilter == 'low_stock' && !item.isLowStock) return false;
        if (stockFilter == 'shelf' && item.fulfillmentType != 'distributed_inventory') return false;
        if (stockFilter == 'client_package' && item.fulfillmentType != 'client_package') return false;
        if (stockFilter == 'awaiting_return' && item.awaitingReturnUnits <= 0) return false;
      }
      if (stockSearchQuery.trim().isNotEmpty) {
        final q = stockSearchQuery.toLowerCase().trim();
        final matchesSku = item.sku.toLowerCase().contains(q);
        final matchesName = item.productName.toLowerCase().contains(q);
        final matchesClient = item.clientName.toLowerCase().contains(q);
        return matchesSku || matchesName || matchesClient;
      }
      return true;
    }).toList();

    // 3. Sort
    if (stockSort == 'quantity_high') {
      filtered.sort((a, b) => b.inCustodyUnits.compareTo(a.inCustodyUnits));
    } else if (stockSort == 'sku_az') {
      filtered.sort((a, b) => a.sku.compareTo(b.sku));
    } else if (stockSort == 'value_high') {
      filtered.sort((a, b) => (b.inCustodyUnits * b.unitPrice).compareTo(a.inCustodyUnits * a.unitPrice));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. KPI Cards in One Row (Responsive)
          LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth;
              if (constraints.maxWidth < 600) {
                cardWidth = constraints.maxWidth;
              } else if (constraints.maxWidth < 900) {
                cardWidth = (constraints.maxWidth - 12) / 2;
              } else {
                cardWidth = (constraints.maxWidth - 36) / 4;
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _buildKpiCard(
                      '📦 Units in Custody',
                      '$totalUnitsHeld Units',
                      'Valuation: ${CurrencyFormatter.formatNaira(totalStockValue)}',
                      const Color(0xFF2563EB),
                      isDark,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildKpiCard(
                      '🏢 Shelf Stock Items',
                      '$shelfUnits Units',
                      'From DC central warehouse shelf',
                      const Color(0xFF10B981),
                      isDark,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildKpiCard(
                      '⚠️ Low Stock Items',
                      '$lowStockCount Items',
                      lowStockCount > 0 ? 'Requires vehicle top up' : 'Vehicle stock healthy ✓',
                      lowStockCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFF059669),
                      isDark,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildKpiCard(
                      '🔄 Awaiting Return',
                      '$awaitingReturnUnits Units',
                      'From failed deliveries to check in',
                      const Color(0xFFEF4444),
                      isDark,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 18),

          // 2. Action Header: Assign New Product Button & Search / Filter Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vehicle Stock Inventory',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAssignProductToThisRiderDialog(context, isDark, driver, stockState.stockItems),
                icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                label: const Text('Assign New Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _buildSearchAndFilterControls(
            isDark: isDark,
            searchController: _stockSearchController,
            searchHint: 'Search stock items by SKU, product name, or merchant client...',
            onSearchChanged: (val) => _onDebouncedSearch(() => ref.read(riderStockSearchProvider.notifier).state = val),
            filterChips: [
              _buildFilterButton('All (${custodyItems.length})', 'all', stockFilter, (val) => ref.read(riderStockFilterProvider.notifier).state = val),
              _buildFilterButton('⚠️ Low Stock ($lowStockCount)', 'low_stock', stockFilter, (val) => ref.read(riderStockFilterProvider.notifier).state = val, activeColor: const Color(0xFFF59E0B)),
              _buildFilterButton('🏢 DC Shelf Stock ($shelfUnits)', 'shelf', stockFilter, (val) => ref.read(riderStockFilterProvider.notifier).state = val, activeColor: const Color(0xFF10B981)),
              _buildFilterButton('📦 Client Packages ($clientPackages)', 'client_package', stockFilter, (val) => ref.read(riderStockFilterProvider.notifier).state = val, activeColor: const Color(0xFF8B5CF6)),
              _buildFilterButton('🔄 Awaiting Return ($awaitingReturnUnits)', 'awaiting_return', stockFilter, (val) => ref.read(riderStockFilterProvider.notifier).state = val, activeColor: const Color(0xFFEF4444)),
            ],
            sortWidget: _buildSortDropdown(
              value: stockSort,
              items: const [
                DropdownMenuItem(value: 'quantity_high', child: Text('Highest Units')),
                DropdownMenuItem(value: 'sku_az', child: Text('SKU (A-Z)')),
                DropdownMenuItem(value: 'value_high', child: Text('Highest Value')),
              ],
              onChanged: (val) => ref.read(riderStockSortProvider.notifier).state = val ?? 'quantity_high',
              isDark: isDark,
            ),
          ),

          const SizedBox(height: 14),

          // 3. Minimalist Stock Table
          if (filtered.isEmpty)
            _buildEmptyState('No physical stock or packages currently matching criteria.', isDark)
          else
            _buildMinimalistStockTable(filtered, isDark, driver),
        ],
      ),
    );
  }

  Widget _buildMinimalistStockTable(List<_DriverCustodyStockItem> items, bool isDark, DCFleetDriver driver) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 850;

          if (isNarrow) {
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              itemBuilder: (ctx, i) => _buildMobileStockCard(items[i], isDark, driver),
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columnSpacing: 18,
                horizontalMargin: 16,
                headingRowHeight: 40,
                headingRowColor: WidgetStateProperty.all(
                  isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
                ),
                headingTextStyle: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
                columns: const [
                  DataColumn(label: Text('SKU / CODE')),
                  DataColumn(label: Text('PRODUCT & CLIENT')),
                  DataColumn(label: Text('FULFILLMENT TYPE')),
                  DataColumn(label: Text('ASSIGNED')),
                  DataColumn(label: Text('DELIVERED')),
                  DataColumn(label: Text('IN CUSTODY')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('EST. VALUE')),
                  DataColumn(label: Text('ACTIONS')),
                ],
                rows: items.map((item) {
                  final totalValue = item.inCustodyUnits * item.unitPrice;
                  return DataRow(
                    cells: [
                      // SKU
                      DataCell(
                        Text(
                          item.sku,
                          style: GoogleFonts.firaCode(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                          ),
                        ),
                      ),

                      // Product & Client
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Client: ${item.clientName}',
                              style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Fulfillment Type
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: item.fulfillmentType == 'distributed_inventory'
                                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                : const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.fulfillmentType == 'distributed_inventory' ? '🏢 Shelf Stock' : '📦 Client Package',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: item.fulfillmentType == 'distributed_inventory'
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                      ),

                      // Assigned Units
                      DataCell(Text('${item.assignedUnits}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600))),

                      // Delivered Units
                      DataCell(
                        Text(
                          '${item.deliveredUnits}',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                        ),
                      ),

                      // In Custody Units
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: item.isLowStock
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                : const Color(0xFF2563EB).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${item.inCustodyUnits} units',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: item.isLowStock ? const Color(0xFFD97706) : const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ),

                      // Status Badge
                      DataCell(
                        item.isLowStock
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '⚠️ LOW STOCK',
                                  style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFFD97706)),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'IN CUSTODY',
                                  style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF059669)),
                                ),
                              ),
                      ),

                      // Estimated Value
                      DataCell(
                        Text(
                          CurrencyFormatter.formatNaira(totalValue),
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),

                      // Actions: Increase Stock
                      DataCell(
                        ElevatedButton.icon(
                          onPressed: () => _showTopUpRiderStockDialog(context, isDark, driver, item),
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 14, color: Colors.white),
                          label: const Text('Top Up', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileStockCard(_DriverCustodyStockItem item, bool isDark, DCFleetDriver driver) {
    final totalValue = item.inCustodyUnits * item.unitPrice;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(item.sku, style: GoogleFonts.firaCode(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
              Wrap(
                spacing: 6,
                children: [
                  if (item.isLowStock)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('⚠️ LOW (${item.inCustodyUnits})', style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFFD97706))),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${item.inCustodyUnits} in custody', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(item.productName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
          Text('Client: ${item.clientName} • ${item.fulfillmentType == 'distributed_inventory' ? 'Shelf Stock' : 'Client Package'}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Assigned: ${item.assignedUnits} • Done: ${item.deliveredUnits}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
              Text(CurrencyFormatter.formatNaira(totalValue), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showTopUpRiderStockDialog(context, isDark, driver, item),
                icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                label: const Text('Top Up Stock', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAssignProductToThisRiderDialog(BuildContext context, bool isDark, DCFleetDriver driver, List<StockItemEntity> stockItems) {
    final Map<String, StockItemEntity> uniqueMap = {};
    for (final p in stockItems.where((p) => p.availableCount > 0)) {
      uniqueMap[p.id] = p;
    }
    final availableProducts = uniqueMap.values.toList();

    if (availableProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ No stock currently in DC warehouse possession to allocate. Please receive or add stock to warehouse first.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    String selectedProdId = availableProducts.first.id;
    final qtyCtrl = TextEditingController(text: availableProducts.first.availableCount >= 5 ? '5' : '1');
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final targetProd = uniqueMap[selectedProdId] ?? availableProducts.first;

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.inventory_2_rounded, color: Color(0xFF2563EB), size: 22),
                const SizedBox(width: 8),
                Text('Assign Product to ${driver.name}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: uniqueMap.containsKey(selectedProdId) ? selectedProdId : availableProducts.first.id,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Select Product in DC Possession *'),
                      items: availableProducts.map((p) {
                        return DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            '${p.name} (${p.sku}) • In DC: ${p.availableCount} units',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedProdId = val;
                            final newTarget = availableProducts.firstWhere((p) => p.id == val, orElse: () => availableProducts.first);
                            qtyCtrl.text = newTarget.availableCount >= 5 ? '5' : '${newTarget.availableCount}';
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.store_rounded, color: Color(0xFF10B981), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'DC Warehouse Shelf Available: ${targetProd.availableCount} units',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity to Allocate (Units) *',
                        hintText: 'e.g. 5',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildQuickQtyPill('+1', () => qtyCtrl.text = '1'),
                        const SizedBox(width: 6),
                        _buildQuickQtyPill('+5', () => qtyCtrl.text = '5'),
                        const SizedBox(width: 6),
                        _buildQuickQtyPill('+10', () => qtyCtrl.text = '10'),
                        const SizedBox(width: 6),
                        _buildQuickQtyPill('All (${targetProd.availableCount})', () => qtyCtrl.text = '${targetProd.availableCount}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final qty = int.tryParse(qtyCtrl.text) ?? 0;
                  if (qty <= 0) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('⚠️ Please enter a quantity greater than 0.'), backgroundColor: Color(0xFFEF4444)),
                    );
                    return;
                  }

                  if (qty > targetProd.availableCount) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('⚠️ Cannot allocate $qty units. Only ${targetProd.availableCount} units available in DC warehouse.'), backgroundColor: const Color(0xFFEF4444)),
                    );
                    return;
                  }

                  // Confirmation dialog with double-tap protection & universal loading overlay
                  showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (confirmCtx) {
                      bool isSubmitting = false;
                      return StatefulBuilder(
                        builder: (confirmCtx, setConfirmState) => AlertDialog(
                          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFF2563EB), size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Confirm Vehicle Allocation',
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          content: SizedBox(
                            width: 420,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Confirm physical handover of stock units to the assigned rider:',
                                  style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    children: [
                                      _buildModalConfirmRow('Product:', targetProd.name, isDark),
                                      const SizedBox(height: 6),
                                      _buildModalConfirmRow('Rider Recipient:', '${driver.name} (${driver.driverCode})', isDark),
                                      const SizedBox(height: 6),
                                      _buildModalConfirmRow('Vehicle Zone:', driver.assignedZone, isDark),
                                      const Divider(height: 16),
                                      _buildModalConfirmRow(
                                        'Units to Transfer:',
                                        '$qty Units',
                                        isDark,
                                        isBold: true,
                                        valueColor: const Color(0xFF2563EB),
                                      ),
                                      const SizedBox(height: 4),
                                      _buildModalConfirmRow(
                                        'Remaining Shelf Stock:',
                                        '${targetProd.availableCount - qty} Units',
                                        isDark,
                                        valueColor: const Color(0xFF10B981),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '⚠️ Double-tap protection active. This will shift custody to the rider vehicle immediately.',
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: isSubmitting ? null : () => Navigator.of(confirmCtx).pop(),
                              child: const Text('Go Back / Edit'),
                            ),
                            ElevatedButton.icon(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      setConfirmState(() => isSubmitting = true);
                                      final res = await showAppLoadingDialog(
                                        context: confirmCtx,
                                        message: 'Allocating Stock to Vehicle...',
                                        subMessage: 'Assigning $qty units to ${driver.name} (${driver.driverCode})...',
                                        isDark: isDark,
                                        task: () => ref.read(stockProvider.notifier).assignStockToRider(
                                              productIdOrSku: targetProd.id,
                                              riderId: driver.id,
                                              riderName: driver.name,
                                              riderCode: driver.driverCode,
                                              quantity: qty,
                                            ),
                                      );

                                      if (res?['success'] == true) {
                                        if (confirmCtx.mounted) Navigator.of(confirmCtx).pop();
                                        if (ctx.mounted) Navigator.of(ctx).pop();
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(res?['message']?.toString() ?? '✅ Stock assigned to ${driver.name}!'),
                                            backgroundColor: const Color(0xFF10B981),
                                          ),
                                        );
                                      } else {
                                        setConfirmState(() => isSubmitting = false);
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(res?['message']?.toString() ?? '❌ Failed to assign stock.'),
                                            backgroundColor: const Color(0xFFEF4444),
                                          ),
                                        );
                                      }
                                    },
                              icon: isSubmitting
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                              label: Text(
                                isSubmitting ? 'Allocating...' : 'Yes, Transfer $qty Units',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                child: const Text('Allocate to Vehicle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTopUpRiderStockDialog(BuildContext context, bool isDark, DCFleetDriver driver, _DriverCustodyStockItem item) {
    final stockState = ref.read(stockProvider);
    StockItemEntity? matched;
    for (final p in stockState.stockItems) {
      if (p.sku.toLowerCase() == item.sku.toLowerCase() || p.name.toLowerCase() == item.productName.toLowerCase()) {
        matched = p;
        break;
      }
    }
    final targetProd = matched ?? (stockState.stockItems.isNotEmpty ? stockState.stockItems.first : StockItemEntity.empty);

    final qtyCtrl = TextEditingController(text: '5');
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF10B981), size: 22),
            const SizedBox(width: 8),
            Text('Top Up: ${item.productName}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current in Custody', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                        Text('${item.inCustodyUnits} Units', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Warehouse Shelf Stock', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                        Text('${targetProd.availableCount} Units', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Units to Top Up *',
                  hintText: 'e.g. 5',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildQuickQtyPill('+5', () => qtyCtrl.text = '5'),
                  const SizedBox(width: 8),
                  _buildQuickQtyPill('+10', () => qtyCtrl.text = '10'),
                  const SizedBox(width: 8),
                  _buildQuickQtyPill('+20', () => qtyCtrl.text = '20'),
                  const SizedBox(width: 8),
                  _buildQuickQtyPill('All (${targetProd.availableCount})', () => qtyCtrl.text = '${targetProd.availableCount}'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final qty = int.tryParse(qtyCtrl.text) ?? 0;
              if (qty <= 0) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('⚠️ Please enter a quantity greater than 0.'), backgroundColor: Color(0xFFEF4444)),
                );
                return;
              }

              if (targetProd.availableCount > 0 && qty > targetProd.availableCount) {
                messenger.showSnackBar(
                  SnackBar(content: Text('⚠️ Cannot top up $qty units. Only ${targetProd.availableCount} available in warehouse.'), backgroundColor: const Color(0xFFEF4444)),
                );
                return;
              }

              // Confirmation dialog with double-tap protection & universal loading overlay
              showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (confirmCtx) {
                  bool isSubmitting = false;
                  return StatefulBuilder(
                    builder: (confirmCtx, setConfirmState) => AlertDialog(
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      title: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF10B981), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Confirm Stock Top Up',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      content: SizedBox(
                        width: 420,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Confirm adding more stock units into the rider\'s active vehicle custody:',
                              style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  _buildModalConfirmRow('Product:', item.productName, isDark),
                                  const SizedBox(height: 6),
                                  _buildModalConfirmRow('Rider Recipient:', '${driver.name} (${driver.driverCode})', isDark),
                                  const Divider(height: 16),
                                  _buildModalConfirmRow(
                                    'Units to Add:',
                                    '+$qty Units',
                                    isDark,
                                    isBold: true,
                                    valueColor: const Color(0xFF10B981),
                                  ),
                                  const SizedBox(height: 4),
                                  _buildModalConfirmRow(
                                    'New Rider Custody Total:',
                                    '${item.inCustodyUnits + qty} Units',
                                    isDark,
                                    valueColor: const Color(0xFF2563EB),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '⚠️ Double-tap protection active. Inventory balance will update immediately upon confirmation.',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: isSubmitting ? null : () => Navigator.of(confirmCtx).pop(),
                          child: const Text('Go Back / Edit'),
                        ),
                        ElevatedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  setConfirmState(() => isSubmitting = true);
                                  final res = await showAppLoadingDialog(
                                    context: confirmCtx,
                                    message: 'Topping Up Vehicle Stock...',
                                    subMessage: 'Transferring +$qty units to ${driver.name}...',
                                    isDark: isDark,
                                    task: () => ref.read(stockProvider.notifier).increaseRiderStock(
                                          skuOrName: item.sku.isNotEmpty ? item.sku : item.productName,
                                          riderId: driver.id,
                                          riderName: driver.name,
                                          riderCode: driver.driverCode,
                                          additionalUnits: qty,
                                        ),
                                  );

                                  if (res?['success'] == true) {
                                    if (confirmCtx.mounted) Navigator.of(confirmCtx).pop();
                                    if (ctx.mounted) Navigator.of(ctx).pop();
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(res?['message']?.toString() ?? '✅ +$qty units transferred to ${driver.name}!'),
                                        backgroundColor: const Color(0xFF10B981),
                                      ),
                                    );
                                  } else {
                                    setConfirmState(() => isSubmitting = false);
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(res?['message']?.toString() ?? '❌ Failed to top up stock.'),
                                        backgroundColor: const Color(0xFFEF4444),
                                      ),
                                    );
                                  }
                                },
                          icon: isSubmitting
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                          label: Text(
                            isSubmitting ? 'Adding...' : 'Yes, Top Up +$qty Units',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Confirm Top Up', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickQtyPill(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
      ),
    );
  }

  Widget _buildModalConfirmRow(String label, String value, bool isDark, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // SHARED REUSABLE COMPONENTS
  // ==========================================
  Widget _buildKpiCard(String title, String mainVal, String subVal, Color color, bool isDark) {
    return Container(
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
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            mainVal,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subVal,
            style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterControls({
    required bool isDark,
    required TextEditingController searchController,
    required String searchHint,
    required Function(String) onSearchChanged,
    required List<Widget> filterChips,
    required Widget sortWidget,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search & Sort Bar
        LayoutBuilder(
          builder: (context, constraints) {
            final isVeryNarrow = constraints.maxWidth < 420;
            if (isVeryNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 38,
                    child: TextField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      style: GoogleFonts.inter(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: searchHint,
                        hintStyle: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: sortWidget,
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      style: GoogleFonts.inter(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: searchHint,
                        hintStyle: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                sortWidget,
              ],
            );
          },
        ),

        const SizedBox(height: 10),

        // Filter Chips Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: filterChips),
        ),
      ],
    );
  }

  Widget _buildFilterButton(
    String label,
    String filterKey,
    String currentFilter,
    Function(String) onSelect, {
    Color? activeColor,
  }) {
    final isSelected = currentFilter.toLowerCase() == filterKey.toLowerCase();
    final color = activeColor ?? const Color(0xFF2563EB);

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => onSelect(filterKey),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.transparent : const Color(0xFFCBD5E1),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortDropdown({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
    required bool isDark,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          icon: const Icon(Icons.sort_rounded, size: 16),
          style: GoogleFonts.inter(fontSize: 11.5, color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        ),
      ),
    );
  }

  Widget _buildOrderStatusPill(String status) {
    Color bg;
    Color fg;
    String label = status.toUpperCase().replaceAll('_', ' ');

    switch (status.toLowerCase()) {
      case 'delivered':
        bg = const Color(0xFF10B981).withValues(alpha: 0.15);
        fg = const Color(0xFF059669);
        break;
      case 'in_transit':
        bg = const Color(0xFF2563EB).withValues(alpha: 0.15);
        fg = const Color(0xFF2563EB);
        break;
      case 'failed':
      case 'cancelled':
      case 'returned':
        bg = const Color(0xFFEF4444).withValues(alpha: 0.15);
        fg = const Color(0xFFDC2626);
        break;
      default:
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
        fg = const Color(0xFFD97706);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  Widget _buildTxnStatusPill(String status) {
    Color bg;
    Color fg;
    String label = status.toUpperCase().replaceAll('_', ' ');

    switch (status.toLowerCase()) {
      case 'remitted':
      case 'verified':
      case 'approved':
      case 'completed':
        bg = const Color(0xFF10B981).withValues(alpha: 0.15);
        fg = const Color(0xFF059669);
        break;
      case 'settled':
      case 'success':
      case 'successful':
        bg = const Color(0xFF2563EB).withValues(alpha: 0.15);
        fg = const Color(0xFF2563EB);
        break;
      case 'partial':
        bg = const Color(0xFF8B5CF6).withValues(alpha: 0.15);
        fg = const Color(0xFF7C3AED);
        break;
      case 'rejected':
      case 'failed':
        bg = const Color(0xFFEF4444).withValues(alpha: 0.15);
        fg = const Color(0xFFDC2626);
        break;
      case 'pending':
      default:
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
        fg = const Color(0xFFD97706);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  Widget _buildEmptyState(String msg, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 36, color: Color(0xFF94A3B8)),
          const SizedBox(height: 10),
          Text(
            msg,
            style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: PROFILE, TERMS & ACCOUNT CONTROLS
  // ==========================================
  Widget _buildProfileAndTermsTab(
    bool isDark,
    DCFleetDriver driver,
    List<OrderEntity> assignedOrders,
    List<DCTransactionRecord> driverTransactions,
  ) {
    final commRate = double.tryParse(_commissionRateController.text.replaceAll(',', '')) ?? driver.commissionRate;
    final transRate = double.tryParse(_transportAllowanceController.text.replaceAll(',', '')) ?? driver.transportAllowance;
    final totalEntitlement = commRate + transRate;

    // 1. Performance / Fulfillment Rate
    final totalAssigned = assignedOrders.length;
    final deliveredOrders = assignedOrders.where((o) => o.status == 'delivered').toList();
    final deliveredCount = deliveredOrders.length;
    final fulfillmentRate = totalAssigned > 0 ? (deliveredCount / totalAssigned) * 100 : 0.0;

    // 2. Amount Waiting to be Remitted (To Remit)
    final deliveredCashOrders = deliveredOrders.where((o) => !o.isDirectTransfer).toList();
    final deliveredDirectOrders = deliveredOrders.where((o) => o.isDirectTransfer).toList();

    final totalCashCollected = deliveredCashOrders.fold<double>(0.0, (s, o) => s + o.totalAmount);
    final cashCommissionRetained = deliveredCashOrders.length * commRate;
    final cashTransportRetained = deliveredCashOrders.length * transRate;
    final cashEarningsRetained = cashCommissionRetained + cashTransportRetained;

    final totalRemittedCash = driverTransactions
        .where((t) => t.isRemittance && t.isVerified)
        .fold<double>(0.0, (s, t) => s + t.amount);

    final pendingToRemit = (totalCashCollected - cashEarningsRetained - totalRemittedCash).clamp(0.0, double.infinity);

    // 3. His Balance (Withdrawable Direct Transfers / Paystack Earnings)
    final hisBalance = deliveredDirectOrders.length * totalEntitlement;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 0. Major Rider KPIs (Fulfillment %, Waiting to Remit, His Balance)
          LayoutBuilder(
            builder: (context, constraints) {
              final is3Col = constraints.maxWidth > 700;
              final is2Col = constraints.maxWidth > 480 && !is3Col;
              final cardWidth = is3Col
                  ? (constraints.maxWidth - 24) / 3
                  : is2Col
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _buildKpiCard(
                      '🎯 Delivery Performance',
                      '${fulfillmentRate.toStringAsFixed(1)}%',
                      '$deliveredCount of $totalAssigned delivered',
                      const Color(0xFF10B981),
                      isDark,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildKpiCard(
                      '⏳ Waiting to Remit',
                      CurrencyFormatter.formatNaira(pendingToRemit),
                      'Cash POD in custody',
                      const Color(0xFFF59E0B),
                      isDark,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildKpiCard(
                      '🏦 His Balance',
                      CurrencyFormatter.formatNaira(hisBalance),
                      'Direct transfers & earnings',
                      const Color(0xFF2563EB),
                      isDark,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // 1. Account Status & Quick Control Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _isActive
                  ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.12 : 0.08)
                  : const Color(0xFFEF4444).withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isActive
                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                    : const Color(0xFFEF4444).withValues(alpha: 0.3),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 600;

                final statusInfo = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: _isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      child: Icon(
                        _isActive ? Icons.check_circle_outline : Icons.block_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                _isActive ? 'Rider Status: ACTIVE & DISPATCH READY' : 'Rider Status: DEACTIVATED / BLOCKED',
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  color: _isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Text(
                                  driver.driverCode,
                                  style: GoogleFonts.firaCode(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isActive
                                ? 'This rider is active and will appear on the dispatch manifest to receive orders.'
                                : 'Deactivated riders are blocked from dispatch and cannot accept new orders.',
                            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final actionBtn = ElevatedButton.icon(
                  onPressed: () {
                    _toggleRiderStatusConfirmation(context, driver);
                  },
                  icon: Icon(_isActive ? Icons.power_settings_new_rounded : Icons.replay_rounded, size: 16),
                  label: Text(_isActive ? 'Deactivate Rider' : 'Reactivate Rider'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isActive ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      statusInfo,
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: actionBtn,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: statusInfo),
                    const SizedBox(width: 12),
                    actionBtn,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // 2. Personal Compensation Terms (The Primary Override Request)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.payments_outlined, size: 20, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Personal Compensation Terms',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Overrides DC Defaults',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Rates configured here directly override generic DC settings in order earnings and remittance deductions.',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Live Entitlement Formula Callout Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.15 : 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.auto_graph_rounded, color: Color(0xFF2563EB), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Total Entitlement per Delivered Cash POD: ${CurrencyFormatter.formatNaira(totalEntitlement)} (${CurrencyFormatter.formatNaira(commRate)} Commission + ${CurrencyFormatter.formatNaira(transRate)} Transport/Fuel)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            height: 1.35,
                            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Form Fields Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final is2Col = constraints.maxWidth > 550;
                    final fieldWidth = is2Col ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

                    return Wrap(
                      spacing: 16,
                      runSpacing: 14,
                      children: [
                        SizedBox(
                          width: fieldWidth,
                          child: _buildFormField(
                            label: 'Commission per Order (₦)',
                            controller: _commissionRateController,
                            isDark: isDark,
                            prefixIcon: Icons.percent_rounded,
                            keyboardType: TextInputType.number,
                            onChanged: (_) {},
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: _buildFormField(
                            label: 'Transport / Fuel Allowance (₦)',
                            controller: _transportAllowanceController,
                            isDark: isDark,
                            prefixIcon: Icons.local_gas_station_rounded,
                            keyboardType: TextInputType.number,
                            onChanged: (_) {},
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: _buildFormField(
                            label: 'Failed Delivery Allowance (₦)',
                            controller: _failedDeliveryAllowanceController,
                            isDark: isDark,
                            prefixIcon: Icons.cancel_outlined,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: _buildFormField(
                            label: 'Monthly Base Salary (₦ - optional for salaried)',
                            controller: _baseSalaryController,
                            isDark: isDark,
                            prefixIcon: Icons.account_balance_wallet_outlined,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Personnel Agreement Type', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                              const SizedBox(height: 6),
                              Container(
                                height: 42,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: borderColor),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _personnelType,
                                    isExpanded: true,
                                    items: const [
                                      DropdownMenuItem(value: 'pda', child: Text('PDA (Personal Distribution Agent - Contractor)')),
                                      DropdownMenuItem(value: 'in_house_rider', child: Text('In-House Rider (Full Company Staff)')),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) {
                                        _personnelType = v;
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Compensation Scheme', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                              const SizedBox(height: 6),
                              Container(
                                height: 42,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: borderColor),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _compensationType,
                                    isExpanded: true,
                                    items: const [
                                      DropdownMenuItem(value: 'commission', child: Text('Pure Commission & Allowances per Drop')),
                                      DropdownMenuItem(value: 'salary', child: Text('Fixed Base Salary')),
                                      DropdownMenuItem(value: 'hybrid', child: Text('Hybrid (Salary + Performance Commission)')),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) {
                                        _compensationType = v;
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Personal Profile Information
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text('Personal & Contact Information', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 16),

                // Rider Uploaded Profile Picture Display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      UserAvatarWidget(
                        avatarUrl: driver.avatarUrl,
                        fullName: driver.name,
                        radius: 28,
                        showBorder: true,
                        borderColor: const Color(0xFF2563EB),
                        borderWidth: 2,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  driver.avatarUrl.trim().isNotEmpty
                                      ? Icons.verified_user_rounded
                                      : Icons.account_circle_outlined,
                                  size: 16,
                                  color: driver.avatarUrl.trim().isNotEmpty
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  driver.avatarUrl.trim().isNotEmpty
                                      ? 'Rider Profile Photo (Active)'
                                      : 'No Profile Photo Uploaded',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: driver.avatarUrl.trim().isNotEmpty
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              driver.avatarUrl.trim().isNotEmpty
                                  ? 'Synced from rider mobile profile image.'
                                  : 'System is currently displaying initials fallback. Rider can upload a photo via his Profile.',
                              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final is2Col = constraints.maxWidth > 550;
                    final fieldWidth = is2Col ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

                    return Wrap(
                      spacing: 16,
                      runSpacing: 14,
                      children: [
                        SizedBox(
                          width: fieldWidth,
                          child: _buildFormField(
                            label: 'Full Name',
                            controller: _nameController,
                            isDark: isDark,
                            prefixIcon: Icons.badge_outlined,
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: _buildFormField(
                            label: 'Phone Number',
                            controller: _phoneController,
                            isDark: isDark,
                            prefixIcon: Icons.phone_outlined,
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: _buildFormField(
                            label: 'Email Address',
                            controller: _emailController,
                            isDark: isDark,
                            prefixIcon: Icons.email_outlined,
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: _buildFormField(
                            label: 'Assigned Operating Zone / Hub',
                            controller: _assignedZoneController,
                            isDark: isDark,
                            prefixIcon: Icons.location_on_outlined,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. Vehicle & Fleet Assets
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.two_wheeler_outlined, size: 20, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text('Vehicle & Asset Allocation', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final is3Col = constraints.maxWidth > 700;
                    final fieldWidth = is3Col ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth;

                    return Wrap(
                      spacing: 16,
                      runSpacing: 14,
                      children: [
                        SizedBox(
                          width: fieldWidth,
                          child: _buildFormField(
                            label: 'Vehicle Type',
                            controller: _vehicleTypeController,
                            isDark: isDark,
                            prefixIcon: Icons.directions_bike_outlined,
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: _buildFormField(
                            label: 'Plate Number',
                            controller: _vehiclePlateController,
                            isDark: isDark,
                            prefixIcon: Icons.pin_outlined,
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: _buildFormField(
                            label: 'Vehicle Model / Notes',
                            controller: _vehicleModelController,
                            isDark: isDark,
                            prefixIcon: Icons.description_outlined,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 5. Banking & Settlement Accounts
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_outlined, size: 20, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text('Bank & Settlement Payout Account', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final is3Col = constraints.maxWidth > 700;
                    final fieldWidth = is3Col ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth;

                    return Wrap(
                      spacing: 16,
                      runSpacing: 14,
                      children: [
                        SizedBox(
                          width: fieldWidth,
                          child: _buildFormField(
                            label: 'Bank Name',
                            controller: _bankNameController,
                            isDark: isDark,
                            prefixIcon: Icons.account_balance_rounded,
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: _buildFormField(
                            label: 'Account Number (NUBAN)',
                            controller: _bankAccountNumberController,
                            isDark: isDark,
                            prefixIcon: Icons.credit_card_outlined,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: _buildFormField(
                            label: 'Account Name',
                            controller: _bankAccountNameController,
                            isDark: isDark,
                            prefixIcon: Icons.badge_outlined,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 6. Security & Password Reset
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_reset_rounded, size: 20, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text('Security & Password Management', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Set a new login password for this rider. Leave this field blank to keep the rider\'s current password unchanged.',
                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'New Password (min 6 characters)',
                    labelStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.key_rounded, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                        color: const Color(0xFF64748B),
                      ),
                      onPressed: () {
                        _isPasswordVisible = !_isPasswordVisible;
                      },
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 7. Save Action Button Bar
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 10,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(color: borderColor),
                ),
                child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : () => _saveDriverProfileAndTerms(context, driver),
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(
                  _isSaving ? 'Saving Changes...' : 'Save All Changes',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required bool isDark,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    Function(String)? onChanged,
  }) {
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
        const SizedBox(height: 6),
        SizedBox(
          height: 42,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: GoogleFonts.inter(fontSize: 12.5),
            decoration: InputDecoration(
              prefixIcon: Icon(prefixIcon, size: 16, color: const Color(0xFF94A3B8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveDriverProfileAndTerms(BuildContext context, DCFleetDriver driver) async {
    _isSaving = true;

    final comm = double.tryParse(_commissionRateController.text.replaceAll(',', '')) ?? driver.commissionRate;
    final trans = double.tryParse(_transportAllowanceController.text.replaceAll(',', '')) ?? driver.transportAllowance;
    final failed = double.tryParse(_failedDeliveryAllowanceController.text.replaceAll(',', '')) ?? driver.failedDeliveryAllowance;
    final salary = double.tryParse(_baseSalaryController.text.replaceAll(',', '')) ?? driver.baseSalary;

    final updated = driver.copyWith(
      name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : driver.name,
      phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : driver.phone,
      email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : driver.email,
      assignedZone: _assignedZoneController.text.trim().isNotEmpty ? _assignedZoneController.text.trim() : driver.assignedZone,
      vehicleType: _vehicleTypeController.text.trim().isNotEmpty ? _vehicleTypeController.text.trim() : driver.vehicleType,
      vehiclePlate: _vehiclePlateController.text.trim().isNotEmpty ? _vehiclePlateController.text.trim() : driver.vehiclePlate,
      vehicleModel: _vehicleModelController.text.trim().isNotEmpty ? _vehicleModelController.text.trim() : driver.vehicleModel,
      bankName: _bankNameController.text.trim(),
      bankAccountNumber: _bankAccountNumberController.text.trim(),
      bankAccountName: _bankAccountNameController.text.trim(),
      commissionRate: comm,
      transportAllowance: trans,
      failedDeliveryAllowance: failed,
      baseSalary: salary,
      personnelType: _personnelType,
      compensationType: _compensationType,
      status: _isActive ? 'active' : 'inactive',
    );

    final newPass = _passwordController.text.trim();

    await ref.read(dcConsoleProvider.notifier).updateDriverProfileAndTerms(
      updatedDriver: updated,
      newPassword: newPass.length >= 6 ? newPass : null,
    );

    if (context.mounted) {
      _isSaving = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '✅ ${updated.name} updated! Personal Terms: ${CurrencyFormatter.formatNaira(comm)} commission + ${CurrencyFormatter.formatNaira(trans)} transport.',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _toggleRiderStatusConfirmation(BuildContext context, DCFleetDriver driver) {
    final nextStatus = !_isActive;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              nextStatus ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              color: nextStatus ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
            const SizedBox(width: 10),
            Text(nextStatus ? 'Activate Rider?' : 'Deactivate Rider?'),
          ],
        ),
        content: Text(
          nextStatus
              ? 'Are you sure you want to reactivate ${driver.name}? They will be available for order dispatching immediately.'
              : 'Are you sure you want to deactivate ${driver.name}? They will be blocked from receiving new delivery dispatches.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              _isActive = nextStatus;
              await _saveDriverProfileAndTerms(context, driver);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: nextStatus ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: Text(nextStatus ? 'Yes, Activate' : 'Yes, Deactivate'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HELPER: CUSTODY AGGREGATION
  // ==========================================
  List<_DriverCustodyStockItem> _computeDriverStockCustody(
    List<OrderEntity> orders,
    List<StockItemEntity> systemStocks,
    List<RiderStockAllocation> riderAllocations,
  ) {
    final Map<String, _DriverCustodyStockItem> itemsMap = {};

    // 1. Process direct warehouse allocations for this rider
    for (final alloc in riderAllocations) {
      final key = '${alloc.productName}_${alloc.fulfillmentType}';
      itemsMap[key] = _DriverCustodyStockItem(
        sku: alloc.sku,
        productName: alloc.productName,
        clientName: alloc.clientName,
        fulfillmentType: alloc.fulfillmentType,
        assignedUnits: alloc.allocatedUnits,
        deliveredUnits: alloc.deliveredUnits,
        inCustodyUnits: alloc.inCustodyUnits,
        awaitingReturnUnits: 0,
        unitPrice: alloc.unitPrice,
      );
    }

    // 2. Process order-based packages and assignments
    for (final order in orders) {
      final key = '${order.productName}_${order.fulfillmentType}';
      final isDelivered = order.status == 'delivered';
      final isFailed = order.status == 'failed' || order.status == 'cancelled' || order.status == 'returned';
      final inCustody = isDelivered ? 0 : order.quantity;
      final awaitingReturn = isFailed ? order.quantity : 0;

      final matchedStock = systemStocks.where((s) => s.name.toLowerCase() == order.productName.toLowerCase() || s.sku.toLowerCase() == order.productName.toLowerCase()).firstOrNull;
      final sku = matchedStock?.sku ?? 'SKU-${order.productName.replaceAll(' ', '-').toUpperCase().substring(0, order.productName.length.clamp(0, 8))}';
      final price = order.basePrice > 0 ? (order.totalAmount / order.quantity.clamp(1, 999)) : (matchedStock?.price ?? 20000.0);

      if (!itemsMap.containsKey(key)) {
        itemsMap[key] = _DriverCustodyStockItem(
          sku: sku,
          productName: order.productName,
          clientName: order.clientName,
          fulfillmentType: order.fulfillmentType,
          assignedUnits: order.quantity,
          deliveredUnits: isDelivered ? order.quantity : 0,
          inCustodyUnits: inCustody,
          awaitingReturnUnits: awaitingReturn,
          unitPrice: price,
        );
      } else {
        final existing = itemsMap[key]!;
        itemsMap[key] = _DriverCustodyStockItem(
          sku: existing.sku,
          productName: existing.productName,
          clientName: existing.clientName,
          fulfillmentType: existing.fulfillmentType,
          assignedUnits: existing.assignedUnits + order.quantity,
          deliveredUnits: existing.deliveredUnits + (isDelivered ? order.quantity : 0),
          inCustodyUnits: existing.inCustodyUnits + inCustody,
          awaitingReturnUnits: existing.awaitingReturnUnits + awaitingReturn,
          unitPrice: existing.unitPrice > 0 ? existing.unitPrice : price,
        );
      }
    }

    return itemsMap.values.toList();
  }
}

class _DriverCustodyStockItem {
  final String sku;
  final String productName;
  final String clientName;
  final String fulfillmentType;
  final int assignedUnits;
  final int deliveredUnits;
  final int inCustodyUnits;
  final int awaitingReturnUnits;
  final double unitPrice;

  const _DriverCustodyStockItem({
    required this.sku,
    required this.productName,
    required this.clientName,
    required this.fulfillmentType,
    required this.assignedUnits,
    required this.deliveredUnits,
    required this.inCustodyUnits,
    required this.awaitingReturnUnits,
    required this.unitPrice,
  });

  bool get isLowStock => inCustodyUnits <= 2 && inCustodyUnits > 0;
}
