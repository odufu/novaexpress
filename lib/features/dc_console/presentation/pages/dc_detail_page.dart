import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/widgets/product_image_widget.dart';
import '../../../finance/presentation/providers/finance_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../../stock/domain/entities/stock_item.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../../domain/entities/distribution_center.dart';
import '../providers/dc_console_provider.dart';
import '../widgets/dc_create_order_modal.dart';
import '../widgets/dc_csv_order_import_modal.dart';
import '../widgets/dc_onboard_client_modal.dart';
import '../widgets/dc_onboard_rider_modal.dart';
import '../widgets/dc_order_detail_modal.dart';
import '../widgets/dc_product_detail_modal.dart';
import '../widgets/dc_remittance_detail_modal.dart';
import '../widgets/dc_rider_detail_modal.dart';

class DCDetailPage extends ConsumerStatefulWidget {
  final DistributionCenter dc;
  final VoidCallback onBack;
  final Function(DistributionCenter updatedDc)? onDcUpdated;

  const DCDetailPage({
    super.key,
    required this.dc,
    required this.onBack,
    this.onDcUpdated,
  });

  @override
  ConsumerState<DCDetailPage> createState() => _DCDetailPageState();
}

class _DCDetailPageState extends ConsumerState<DCDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DistributionCenter _currentDc;

  // Search controllers
  final TextEditingController _ordersSearchController = TextEditingController();
  final TextEditingController _remittanceSearchController = TextEditingController();
  final TextEditingController _stockSearchController = TextEditingController();
  final TextEditingController _ridersSearchController = TextEditingController();

  // Settings controllers
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _managerController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _capacityController;
  late TextEditingController _oldPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;

  // View modes
  String _ordersViewMode = 'table';
  String _remittanceViewMode = 'table';
  String _stockViewMode = 'table';
  String _ridersViewMode = 'table';

  // Filters - Orders
  String _orderStatusFilter = 'all';
  String _orderPaymentFilter = 'all';
  String _orderDateFilter = 'all_time';
  String _orderRiderFilter = 'all';

  // Filters - Remittance
  String _remittanceStatusFilter = 'all';

  // Filters - Stock
  String _stockStatusFilter = 'all';

  // Filters - Riders
  String _riderStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _currentDc = widget.dc;
    _tabController = TabController(length: 5, vsync: this);

    _nameController = TextEditingController(text: _currentDc.name);
    _phoneController = TextEditingController(text: _currentDc.contactPhone ?? '');
    _emailController = TextEditingController(text: _currentDc.contactEmail ?? '');
    _managerController = TextEditingController(text: _currentDc.managerName ?? '');
    _addressController = TextEditingController(text: _currentDc.address);
    _cityController = TextEditingController(text: _currentDc.city);
    _stateController = TextEditingController(text: _currentDc.state);
    _capacityController = TextEditingController(text: _currentDc.storageCapacityUnits.toString());
    _oldPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        ref.read(ordersProvider.notifier).loadDcOrders(_currentDc.id);
      } catch (_) {}
      try {
        ref.read(financeProvider.notifier).loadRemittances(_currentDc.id);
      } catch (_) {}
      try {
        ref.read(stockProvider.notifier).fetchStockItems(null, _currentDc.id);
      } catch (_) {}
      try {
        ref.read(dcConsoleProvider.notifier).loadDriversFromDatabase();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ordersSearchController.dispose();
    _remittanceSearchController.dispose();
    _stockSearchController.dispose();
    _ridersSearchController.dispose();

    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _managerController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _capacityController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- Filtering Helpers ---

  List<OrderEntity> _getDcOrders(List<OrderEntity> allOrders) {
    return allOrders.where((o) {
      final matchesDc = o.distributionCenterId == _currentDc.id ||
          o.deliveryAgentCode == _currentDc.code ||
          _currentDc.coversLocation(stateName: o.deliveryState, lgaName: o.lga ?? '');
      if (!matchesDc) return false;

      // Search
      final q = _ordersSearchController.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        final matches = o.orderNumber.toLowerCase().contains(q) ||
            o.customerName.toLowerCase().contains(q) ||
            o.customerPhone.toLowerCase().contains(q) ||
            o.deliveryAddress.toLowerCase().contains(q) ||
            o.productName.toLowerCase().contains(q) ||
            o.clientCompany.toLowerCase().contains(q) ||
            (o.deliveryAgentName?.toLowerCase().contains(q) ?? false);
        if (!matches) return false;
      }

      // Status
      if (_orderStatusFilter != 'all') {
        if (_orderStatusFilter == 'unassigned' && (o.deliveryAgentId != null && o.deliveryAgentId!.isNotEmpty)) return false;
        if (_orderStatusFilter == 'in_transit' && o.status.toLowerCase() != 'in_transit') return false;
        if (_orderStatusFilter == 'delivered' && o.status.toLowerCase() != 'delivered') return false;
        if (_orderStatusFilter == 'failed' && o.status.toLowerCase() != 'failed' && o.status.toLowerCase() != 'returned') return false;
      }

      // Payment
      if (_orderPaymentFilter != 'all') {
        if (_orderPaymentFilter == 'cash' && !o.isPod) return false;
        if (_orderPaymentFilter == 'direct' && o.isPod) return false;
      }

      // Rider
      if (_orderRiderFilter != 'all') {
        if (o.deliveryAgentId != _orderRiderFilter && o.deliveryAgentName != _orderRiderFilter) return false;
      }

      return true;
    }).toList();
  }

  List<DCRemittanceLifecycleItem> _getDcRemittances(List<OrderEntity> dcOrders, List<DCFleetDriver> allDrivers) {
    final driverMap = {for (var d in allDrivers) d.id: d};
    final Map<String, List<OrderEntity>> riderOrders = {};

    for (final order in dcOrders) {
      final riderId = order.deliveryAgentId ?? 'unassigned';
      riderOrders.putIfAbsent(riderId, () => []).add(order);
    }

    final List<DCRemittanceLifecycleItem> items = [];

    riderOrders.forEach((riderId, orders) {
      if (orders.isEmpty) return;
      final driver = driverMap[riderId];
      final riderName = driver?.name ?? orders.first.deliveryAgentName ?? 'Assigned Rider ($riderId)';
      final riderCode = driver?.driverCode ?? 'PDA-RDR';

      final cashOrders = orders.where((o) => o.isPod).toList();
      final directOrders = orders.where((o) => !o.isPod).toList();

      if (cashOrders.isNotEmpty) {
        final gross = cashOrders.fold<double>(0.0, (s, o) => s + o.totalAmount);
        final comm = cashOrders.length * 500.0;
        final net = gross - comm;
        final isAllDelivered = cashOrders.every((o) => o.status.toLowerCase() == 'delivered');

        items.add(
          DCRemittanceLifecycleItem(
            id: 'rem-cash-$riderId',
            referenceNumber: 'REM-${_currentDc.code}-${riderCode.replaceAll(RegExp(r'[^0-9]'), '')}',
            riderId: riderId,
            riderName: riderName,
            riderCode: riderCode,
            riderPhone: driver?.phone,
            type: 'cash_pod',
            status: isAllDelivered ? 'verified' : 'awaiting_remittance',
            openingDate: orders.first.createdAt,
            closingDate: isAllDelivered ? DateTime.now() : null,
            grossAmount: gross,
            commissionAmount: comm,
            netAmount: net,
            orders: cashOrders,
            paymentMethod: 'Cash POD',
          ),
        );
      }

      if (directOrders.isNotEmpty) {
        final gross = directOrders.fold<double>(0.0, (s, o) => s + o.totalAmount);
        items.add(
          DCRemittanceLifecycleItem(
            id: 'rem-direct-$riderId',
            referenceNumber: 'DIR-${_currentDc.code}-${riderCode.replaceAll(RegExp(r'[^0-9]'), '')}',
            riderId: riderId,
            riderName: riderName,
            riderCode: riderCode,
            riderPhone: driver?.phone,
            type: 'direct_transfer',
            status: 'direct_settled',
            openingDate: orders.first.createdAt,
            closingDate: DateTime.now(),
            grossAmount: gross,
            commissionAmount: 0.0,
            netAmount: gross,
            orders: directOrders,
            paymentMethod: 'Monnify / Paystack',
          ),
        );
      }
    });

    return items.where((rem) {
      final q = _remittanceSearchController.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        final matches = rem.riderName.toLowerCase().contains(q) ||
            rem.riderCode.toLowerCase().contains(q) ||
            rem.referenceNumber.toLowerCase().contains(q);
        if (!matches) return false;
      }

      if (_remittanceStatusFilter == 'not_remitted' && rem.status != 'awaiting_remittance') return false;
      if (_remittanceStatusFilter == 'cleared' && rem.status != 'verified') return false;
      if (_remittanceStatusFilter == 'direct' && rem.type != 'direct_transfer') return false;

      return true;
    }).toList();
  }

  List<StockItemEntity> _getDcStocks(List<StockItemEntity> allStocks) {
    return allStocks.where((s) {
      final q = _stockSearchController.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        final matches = s.name.toLowerCase().contains(q) ||
            s.sku.toLowerCase().contains(q) ||
            s.category.toLowerCase().contains(q);
        if (!matches) return false;
      }

      if (_stockStatusFilter == 'low' && s.availableCount > s.lowStockThreshold) return false;
      if (_stockStatusFilter == 'out' && s.availableCount > 0) return false;
      if (_stockStatusFilter == 'in' && s.availableCount <= 0) return false;

      return true;
    }).toList();
  }

  List<DCFleetDriver> _getDcRiders(List<DCFleetDriver> allDrivers) {
    return allDrivers.where((d) {
      final matchesDc = d.distributionCenterId == _currentDc.id ||
          d.driverCode.startsWith(_currentDc.code) ||
          _currentDc.coversLga(d.assignedZone);

      if (!matchesDc) return false;

      final q = _ridersSearchController.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        final matches = d.name.toLowerCase().contains(q) ||
            d.phone.toLowerCase().contains(q) ||
            d.driverCode.toLowerCase().contains(q) ||
            d.assignedZone.toLowerCase().contains(q) ||
            d.vehiclePlate.toLowerCase().contains(q);
        if (!matches) return false;
      }

      if (_riderStatusFilter == 'active' && !d.isActive) return false;
      if (_riderStatusFilter == 'inactive' && d.isActive) return false;

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1000;

    final dcState = ref.watch(dcConsoleProvider);
    final notifier = ref.read(dcConsoleProvider.notifier);
    final isCurrentActive = _currentDc.id == dcState.activeHubId || _currentDc.code == dcState.activeHubCode;

    final ordersState = ref.watch(ordersProvider);
    final allOrders = ordersState.orders;
    final dcOrders = _getDcOrders(allOrders);

    final allDrivers = dcState.dcDrivers;
    final dcRiders = _getDcRiders(allDrivers);

    final dcRemittances = _getDcRemittances(allOrders.where((o) => o.distributionCenterId == _currentDc.id || _currentDc.coversLocation(stateName: o.deliveryState, lgaName: o.lga ?? '')).toList(), allDrivers);

    final stockState = ref.watch(stockProvider);
    final dcStocks = _getDcStocks(stockState.stockItems);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // 1. Top Breadcrumb & Profile Header Bar
          _buildDcTopHeader(context, isDark, isDesktop, isCurrentActive, notifier),

          // 2. Navigation Tab Bar (with counts)
          _buildNavigationTabBar(isDark, isDesktop, dcOrders.length, dcRemittances.length, dcStocks.length, dcRiders.length),

          // 3. Tab Views Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Orders
                _buildOrdersTab(context, isDark, isDesktop, dcOrders, allOrders),

                // Tab 2: Remittances
                _buildRemittancesTab(context, isDark, isDesktop, dcRemittances),

                // Tab 3: Inventory & Stocks
                _buildStockTab(context, isDark, isDesktop, dcStocks),

                // Tab 4: Riders & Fleet
                _buildRidersTab(context, isDark, isDesktop, dcRiders),

                // Tab 5: Settings & Profile Updates
                _buildSettingsTab(context, isDark, isDesktop, notifier),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Top DC Profile Header
  // ===========================================================================
  Widget _buildDcTopHeader(
    BuildContext context,
    bool isDark,
    bool isDesktop,
    bool isCurrentActive,
    DCConsoleNotifier notifier,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back Button & Breadcrumbs
          Row(
            children: [
              InkWell(
                onTap: widget.onBack,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back_rounded, size: 16, color: Color(0xFFF37021)),
                      const SizedBox(width: 6),
                      Text(
                        'All Distribution Centers',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('/', style: TextStyle(color: const Color(0xFF94A3B8))),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  _currentDc.name,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Main Header Details Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _currentDc.isHub
                      ? const Color(0xFFF37021).withValues(alpha: 0.15)
                      : const Color(0xFF2563EB).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _currentDc.isHub ? const Color(0xFFF37021) : const Color(0xFF2563EB),
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  _currentDc.isHub ? Icons.warehouse_rounded : Icons.apartment_rounded,
                  color: _currentDc.isHub ? const Color(0xFFF37021) : const Color(0xFF2563EB),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _currentDc.name,
                            style: GoogleFonts.inter(
                              fontSize: isDesktop ? 22 : 17,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF2563EB)),
                          ),
                          child: Text(
                            _currentDc.code,
                            style: GoogleFonts.firaCode(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                        if (isCurrentActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF37021),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'CURRENT ACTIVE HUB',
                              style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          '📍 ${_currentDc.address}, ${_currentDc.fullLocation}',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                        if (_currentDc.managerName != null)
                          Text(
                            '👤 Manager: ${_currentDc.managerName} (${_currentDc.contactPhone ?? 'No Phone'})',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                          ),
                        Text(
                          '📦 Capacity: ${_currentDc.displayCapacity}',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (ctx) => const DCOnboardClientModal(),
                    ),
                    icon: const Icon(Icons.add_business_rounded, size: 16, color: Colors.white),
                    label: Text(
                      isDesktop ? 'Onboard Client' : 'Client +',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  if (!isCurrentActive) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        notifier.switchActiveHub(_currentDc);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Switched Active Console Hub to ${_currentDc.name}'),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      },
                      icon: const Icon(Icons.flash_on_rounded, size: 16, color: Colors.white),
                      label: Text(
                        isDesktop ? 'Set as Active Console Hub' : 'Set Active',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF37021),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Tab Navigation Bar
  // ===========================================================================
  Widget _buildNavigationTabBar(
    bool isDark,
    bool isDesktop,
    int ordersCount,
    int remittanceCount,
    int stockCount,
    int ridersCount,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: const Color(0xFFF37021),
        indicatorWeight: 3,
        labelColor: const Color(0xFFF37021),
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        tabs: [
          Tab(
            child: Row(
              children: [
                const Icon(Icons.local_shipping_rounded, size: 16),
                const SizedBox(width: 8),
                Text('Orders ($ordersCount)'),
              ],
            ),
          ),
          Tab(
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, size: 16),
                const SizedBox(width: 8),
                Text('Remittances ($remittanceCount)'),
              ],
            ),
          ),
          Tab(
            child: Row(
              children: [
                const Icon(Icons.inventory_2_rounded, size: 16),
                const SizedBox(width: 8),
                Text('Inventory & Stocks ($stockCount)'),
              ],
            ),
          ),
          Tab(
            child: Row(
              children: [
                const Icon(Icons.badge_rounded, size: 16),
                const SizedBox(width: 8),
                Text('Riders & Fleet ($ridersCount)'),
              ],
            ),
          ),
          const Tab(
            child: Row(
              children: [
                Icon(Icons.tune_rounded, size: 16),
                SizedBox(width: 8),
                Text('Settings & Profile'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: ORDERS
  // ===========================================================================
  Widget _buildOrdersTab(
    BuildContext context,
    bool isDark,
    bool isDesktop,
    List<OrderEntity> orders,
    List<OrderEntity> allOrders,
  ) {
    // Compute Orders KPIs for this DC
    final totalOrders = orders.length;
    final totalGross = orders.fold<double>(0.0, (s, o) => s + o.totalAmount);
    final unassigned = orders.where((o) => o.deliveryAgentId == null || o.deliveryAgentId!.isEmpty).length;
    final inTransit = orders.where((o) => o.status.toLowerCase() == 'in_transit').length;
    final delivered = orders.where((o) => o.status.toLowerCase() == 'delivered').length;
    final deliveredGross = orders.where((o) => o.status.toLowerCase() == 'delivered').fold<double>(0.0, (s, o) => s + o.totalAmount);
    final cashInCustody = orders.where((o) => o.isPod && o.status.toLowerCase() == 'in_transit').fold<double>(0.0, (s, o) => s + o.totalAmount);
    final failed = orders.where((o) => o.status.toLowerCase() == 'failed' || o.status.toLowerCase() == 'returned').length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 20 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 6 KPI Summary Cards (Matching Screenshot 1)
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cardWidth = isDesktop ? (constraints.maxWidth - 50) / 6 : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildStatCard(
                    width: cardWidth,
                    title: 'Total Filtered Orders',
                    value: '$totalOrders Orders',
                    subtext: 'Gross: ${CurrencyFormatter.formatNaira(totalGross)}',
                    icon: Icons.inventory_rounded,
                    color: const Color(0xFF2563EB),
                    isDark: isDark,
                  ),
                  _buildStatCard(
                    width: cardWidth,
                    title: 'Unassigned Pool',
                    value: '$unassigned Pending',
                    subtext: 'Awaiting rider dispatch',
                    icon: Icons.schedule_send_rounded,
                    color: const Color(0xFFF97316),
                    isDark: isDark,
                  ),
                  _buildStatCard(
                    width: cardWidth,
                    title: 'In-Transit Live',
                    value: '$inTransit Active',
                    subtext: 'Out on delivery routes',
                    icon: Icons.local_shipping_rounded,
                    color: const Color(0xFF0284C7),
                    isDark: isDark,
                  ),
                  _buildStatCard(
                    width: cardWidth,
                    title: 'Fulfilled / POD',
                    value: '$delivered Delivered',
                    subtext: 'Rev: ${CurrencyFormatter.formatNaira(deliveredGross)}',
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                  _buildStatCard(
                    width: cardWidth,
                    title: 'Cash In Custody',
                    value: CurrencyFormatter.formatNaira(cashInCustody),
                    subtext: '0 awaiting remittance',
                    icon: Icons.account_balance_wallet_rounded,
                    color: const Color(0xFFF59E0B),
                    isDark: isDark,
                  ),
                  _buildStatCard(
                    width: cardWidth,
                    title: 'Failed / Returns',
                    value: '$failed Issues',
                    subtext: 'Call backs & returns',
                    icon: Icons.warning_rounded,
                    color: const Color(0xFFEF4444),
                    isDark: isDark,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Action CTAs: Create Order & Import CSV
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => showDialog(context: context, builder: (ctx) => const DCCreateOrderModal()),
                icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                label: const Text('+ Create New Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF37021),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => showDialog(context: context, builder: (ctx) => const DCCsvOrderImportModal()),
                icon: const Icon(Icons.file_upload_outlined, size: 18, color: Color(0xFF10B981)),
                label: const Text('Import CSV', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF10B981)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filter Toolbar (Search + Filters + View Mode Switcher)
          _buildOrdersFilterToolbar(context, isDark, isDesktop),
          const SizedBox(height: 14),

          // Data Table or Cards
          if (orders.isEmpty)
            _buildEmptyState('No orders match your active filter for this Distribution Center.', isDark)
          else if (_ordersViewMode == 'table' && isDesktop)
            _buildOrdersTable(context, orders, isDark)
          else
            _buildOrdersCardsList(context, orders, isDark),
        ],
      ),
    );
  }

  Widget _buildOrdersFilterToolbar(BuildContext context, bool isDark, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: TextField(
                    controller: _ordersSearchController,
                    onChanged: (val) => setState(() {}),
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Search by Order #, Customer Name, Phone, Address, Product, Client, or Rider...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // View Mode Toggle
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.table_chart_rounded, size: 18, color: _ordersViewMode == 'table' ? const Color(0xFFF37021) : const Color(0xFF94A3B8)),
                      tooltip: 'Table View',
                      onPressed: () => setState(() => _ordersViewMode = 'table'),
                    ),
                    IconButton(
                      icon: Icon(Icons.grid_view_rounded, size: 18, color: _ordersViewMode == 'cards' ? const Color(0xFFF37021) : const Color(0xFF94A3B8)),
                      tooltip: 'Cards View',
                      onPressed: () => setState(() => _ordersViewMode = 'cards'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Filters row: Desktop dropdowns vs Mobile icons
          if (isDesktop) ...[
            Row(
              children: [
                _buildFilterDropdown(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date: $_orderDateFilter',
                  items: ['all_time', 'today', 'this_week', 'this_month'],
                  value: _orderDateFilter,
                  onChanged: (v) => setState(() => _orderDateFilter = v!),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterDropdown(
                  icon: Icons.filter_alt_rounded,
                  label: 'Status: $_orderStatusFilter',
                  items: ['all', 'unassigned', 'in_transit', 'delivered', 'failed'],
                  value: _orderStatusFilter,
                  onChanged: (v) => setState(() => _orderStatusFilter = v!),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterDropdown(
                  icon: Icons.payments_rounded,
                  label: 'Settlement: $_orderPaymentFilter',
                  items: ['all', 'cash', 'direct'],
                  value: _orderPaymentFilter,
                  onChanged: (v) => setState(() => _orderPaymentFilter = v!),
                  isDark: isDark,
                ),
              ],
            ),
          ] else ...[
            // Mobile Icon-based Filters (as requested: "Filter represented with icons on mobile")
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMobileFilterIconBtn(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date',
                  isActive: _orderDateFilter != 'all_time',
                  onTap: () => _showMobileFilterOptions(
                    context,
                    'Date Filter',
                    ['all_time', 'today', 'this_week', 'this_month'],
                    _orderDateFilter,
                    (v) => setState(() => _orderDateFilter = v),
                    isDark,
                  ),
                ),
                _buildMobileFilterIconBtn(
                  icon: Icons.filter_alt_rounded,
                  label: 'Status',
                  isActive: _orderStatusFilter != 'all',
                  onTap: () => _showMobileFilterOptions(
                    context,
                    'Status Filter',
                    ['all', 'unassigned', 'in_transit', 'delivered', 'failed'],
                    _orderStatusFilter,
                    (v) => setState(() => _orderStatusFilter = v),
                    isDark,
                  ),
                ),
                _buildMobileFilterIconBtn(
                  icon: Icons.payments_rounded,
                  label: 'Payment',
                  isActive: _orderPaymentFilter != 'all',
                  onTap: () => _showMobileFilterOptions(
                    context,
                    'Payment Filter',
                    ['all', 'cash', 'direct'],
                    _orderPaymentFilter,
                    (v) => setState(() => _orderPaymentFilter = v),
                    isDark,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrdersTable(BuildContext context, List<OrderEntity> orders, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
            horizontalMargin: 16,
            columnSpacing: 20,
            columns: const [
              DataColumn(label: Text('Order # & Date', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Customer & Phone', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Destination', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Product & Qty', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Amount & Payment', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Client', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Assigned Rider', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: orders.map((o) {
              final isDelivered = o.status.toLowerCase() == 'delivered';
              final isFailed = o.status.toLowerCase() == 'failed';
              final isInTransit = o.status.toLowerCase() == 'in_transit';

              final Color statusColor = isDelivered
                  ? const Color(0xFF10B981)
                  : isFailed
                      ? const Color(0xFFEF4444)
                      : isInTransit
                          ? const Color(0xFF0284C7)
                          : const Color(0xFFF97316);

              return DataRow(
                onSelectChanged: (_) {
                  showDialog(context: context, builder: (ctx) => DCOrderDetailModal(order: o));
                },
                cells: [
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          o.orderNumber.startsWith('#') ? o.orderNumber : '#${o.orderNumber}',
                          style: GoogleFonts.firaCode(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                        ),
                        Text(
                          DateFormat('dd MMM, hh:mm a').format(o.createdAt),
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(o.customerName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        Text(o.customerPhone, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  DataCell(
                    Text('${o.lga ?? 'LGA'}, ${_currentDc.state}', style: const TextStyle(fontSize: 12)),
                  ),
                  DataCell(
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('${o.quantity}x', style: const TextStyle(fontSize: 11, color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 6),
                        Text(o.productName, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(CurrencyFormatter.formatNaira(o.totalAmount), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                        Text(o.isPod ? '💵 Pay on Del' : '💳 Prepaid', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  DataCell(Text(o.clientCompany, style: const TextStyle(fontSize: 12))),
                  DataCell(
                    Text(
                      o.deliveryAgentName ?? (o.deliveryAgentId != null ? 'Assigned' : 'Unassigned'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: o.deliveryAgentId != null ? FontWeight.bold : FontWeight.normal,
                        color: o.deliveryAgentId != null ? const Color(0xFF2563EB) : const Color(0xFFF97316),
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        o.status.toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                  ),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF2563EB)),
                      onPressed: () {
                        showDialog(context: context, builder: (ctx) => DCOrderDetailModal(order: o));
                      },
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

  Widget _buildOrdersCardsList(BuildContext context, List<OrderEntity> orders, bool isDark) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: orders.length,
      itemBuilder: (ctx, i) {
        final o = orders[i];
        final isDelivered = o.status.toLowerCase() == 'delivered';
        final isFailed = o.status.toLowerCase() == 'failed';
        final statusColor = isDelivered ? const Color(0xFF10B981) : (isFailed ? const Color(0xFFEF4444) : const Color(0xFF2563EB));

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: InkWell(
            onTap: () => showDialog(context: context, builder: (ctx) => DCOrderDetailModal(order: o)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(o.orderNumber.startsWith('#') ? o.orderNumber : '#${o.orderNumber}', style: GoogleFonts.firaCode(fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(o.status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(o.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                Text('${o.customerPhone} • ${o.lga ?? 'LGA'}, ${_currentDc.state}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${o.quantity}x ${o.productName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(CurrencyFormatter.formatNaira(o.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // TAB 2: REMITTANCES
  // ===========================================================================
  Widget _buildRemittancesTab(
    BuildContext context,
    bool isDark,
    bool isDesktop,
    List<DCRemittanceLifecycleItem> remittances,
  ) {
    final totalValue = remittances.fold<double>(0.0, (s, r) => s + r.grossAmount);
    final directPaid = remittances.where((r) => r.isDirectTransfer).fold<double>(0.0, (s, r) => s + r.grossAmount);
    final notRemitted = remittances.where((r) => r.isAwaitingRemittance).fold<double>(0.0, (s, r) => s + r.grossAmount);
    final reconciled = remittances.where((r) => r.isVerified && !r.isDirectTransfer).fold<double>(0.0, (s, r) => s + r.grossAmount);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 20 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4 Remittance KPIs (Matching Screenshot 2 & 3)
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cardWidth = isDesktop ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildStatCard(
                    width: cardWidth,
                    title: 'TOTAL MONITORED VALUE',
                    value: CurrencyFormatter.formatNaira(totalValue),
                    subtext: '${remittances.length} Shipments Audited',
                    icon: Icons.receipt_long_rounded,
                    color: const Color(0xFF2563EB),
                    isDark: isDark,
                  ),
                  _buildStatCard(
                    width: cardWidth,
                    title: 'DIRECT PAYSTACK PAID',
                    value: CurrencyFormatter.formatNaira(directPaid),
                    subtext: '${remittances.where((r) => r.isDirectTransfer).length} Direct Settlements • ₦0 Held',
                    icon: Icons.bolt_rounded,
                    color: const Color(0xFF0284C7),
                    isDark: isDark,
                  ),
                  _buildStatCard(
                    width: cardWidth,
                    title: 'NOT REMITTED (HELD BY RIDERS)',
                    value: CurrencyFormatter.formatNaira(notRemitted),
                    subtext: '${remittances.where((r) => r.isAwaitingRemittance).length} Open Batches',
                    icon: Icons.warning_amber_rounded,
                    color: const Color(0xFFF59E0B),
                    isDark: isDark,
                  ),
                  _buildStatCard(
                    width: cardWidth,
                    title: 'REMITTED & RECONCILED',
                    value: CurrencyFormatter.formatNaira(reconciled),
                    subtext: '${remittances.where((r) => r.isVerified).length} Batches Cleared into Treasury',
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Remittance Filter Bar (Search + Filter pills + View Mode)
          _buildRemittanceFilterToolbar(context, isDark, isDesktop, remittances.length),
          const SizedBox(height: 14),

          // Data Table or Cards
          if (remittances.isEmpty)
            _buildEmptyState('No remittances found for this Distribution Center.', isDark)
          else if (_remittanceViewMode == 'table' && isDesktop)
            _buildRemittanceTable(context, remittances, isDark)
          else
            _buildRemittanceCardsList(context, remittances, isDark),
        ],
      ),
    );
  }

  Widget _buildRemittanceFilterToolbar(BuildContext context, bool isDark, bool isDesktop, int totalCount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: TextField(
                    controller: _remittanceSearchController,
                    onChanged: (val) => setState(() {}),
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      hintText: 'Search by Rider Name, Code, Ref #, or Order...',
                      hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.table_chart_rounded, size: 18, color: _remittanceViewMode == 'table' ? const Color(0xFFF37021) : const Color(0xFF94A3B8)),
                      onPressed: () => setState(() => _remittanceViewMode = 'table'),
                    ),
                    IconButton(
                      icon: Icon(Icons.grid_view_rounded, size: 18, color: _remittanceViewMode == 'cards' ? const Color(0xFFF37021) : const Color(0xFF94A3B8)),
                      onPressed: () => setState(() => _remittanceViewMode = 'cards'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Filter pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildRemittancePill('all', 'All Remittances ($totalCount)', isDark),
                const SizedBox(width: 8),
                _buildRemittancePill('not_remitted', '⚠️ Not Remitted', isDark),
                const SizedBox(width: 8),
                _buildRemittancePill('cleared', '✅ Remitted & Cleared', isDark),
                const SizedBox(width: 8),
                _buildRemittancePill('direct', '⚡ Direct Paystack', isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemittancePill(String key, String label, bool isDark) {
    final isSelected = _remittanceStatusFilter == key;
    return InkWell(
      onTap: () => setState(() => _remittanceStatusFilter = key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF37021) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFF37021) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildRemittanceTable(BuildContext context, List<DCRemittanceLifecycleItem> remittances, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
            columns: const [
              DataColumn(label: Text('RIDER / AGENT', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('ORDERS', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('AMOUNT TO REMIT', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('NET REMITTANCE', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('PAYMENT METHOD', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('OPENING DATE', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('CLOSING DATE', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('REMITTANCE STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: remittances.map((r) {
              return DataRow(
                onSelectChanged: (_) {
                  // User explicitly requested: "on tapping it it shows that remitance details"
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => DCRemittanceDetailModal(remittance: r),
                  );
                },
                cells: [
                  DataCell(
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.2),
                          child: Text(r.riderName.isNotEmpty ? r.riderName[0].toUpperCase() : 'R', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(r.riderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            Text(r.riderCode, style: GoogleFonts.firaCode(fontSize: 10.5, color: const Color(0xFF94A3B8))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('${r.orderCount} Orders', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                    ),
                  ),
                  DataCell(Text(CurrencyFormatter.formatNaira(r.grossAmount), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold))),
                  DataCell(Text(CurrencyFormatter.formatNaira(r.netAmount), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)))),
                  DataCell(Text(r.paymentMethod, style: const TextStyle(fontSize: 12))),
                  DataCell(Text(DateFormat('dd MMM, hh:mm a').format(r.openingDate), style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)))),
                  DataCell(Text(r.closingDate != null ? DateFormat('dd MMM, hh:mm a').format(r.closingDate!) : 'Open', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: r.isVerified ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        r.isVerified ? 'REMITTED & CLEARED' : 'AWAITING REMITTANCE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: r.isVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        ),
                      ),
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

  Widget _buildRemittanceCardsList(BuildContext context, List<DCRemittanceLifecycleItem> remittances, bool isDark) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: remittances.length,
      itemBuilder: (ctx, i) {
        final r = remittances[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => DCRemittanceDetailModal(remittance: r),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(r.riderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: r.isVerified ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        r.isVerified ? 'CLEARED' : 'PENDING',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: r.isVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${r.riderCode} • ${r.orderCount} Orders • ${r.paymentMethod}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Gross: ${CurrencyFormatter.formatNaira(r.grossAmount)}', style: const TextStyle(fontSize: 12)),
                    Text('Net: ${CurrencyFormatter.formatNaira(r.netAmount)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // TAB 3: INVENTORY & STOCKS
  // ===========================================================================
  Widget _buildStockTab(
    BuildContext context,
    bool isDark,
    bool isDesktop,
    List<StockItemEntity> stocks,
  ) {
    final totalSkus = stocks.length;
    final totalUnits = stocks.fold<int>(0, (s, item) => s + item.availableCount);
    final inTransitUnits = stocks.fold<int>(0, (s, item) => s + item.assignedCount);
    final lowStock = stocks.where((item) => item.availableCount <= item.lowStockThreshold).length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 20 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stock KPIs
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cardWidth = isDesktop ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildStatCard(
                    width: cardWidth,
                    title: 'Total SKU Catalog',
                    value: '$totalSkus SKUs',
                    subtext: 'Active catalog lines',
                    icon: Icons.category_rounded,
                    color: const Color(0xFF2563EB),
                    isDark: isDark,
                  ),
                  _buildStatCard(
                    width: cardWidth,
                    title: 'In-Warehouse Units',
                    value: '$totalUnits Units',
                    subtext: 'On DC storage shelves',
                    icon: Icons.inventory_2_rounded,
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                  _buildStatCard(
                    width: cardWidth,
                    title: 'Dispatched Saddlebag',
                    value: '$inTransitUnits Units',
                    subtext: 'In rider active custody',
                    icon: Icons.two_wheeler_rounded,
                    color: const Color(0xFFF97316),
                    isDark: isDark,
                  ),
                  _buildStatCard(
                    width: cardWidth,
                    title: 'Low Stock Alerts',
                    value: '$lowStock SKUs',
                    subtext: 'Threshold < 20 units',
                    icon: Icons.warning_rounded,
                    color: const Color(0xFFEF4444),
                    isDark: isDark,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Search & Filter Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    child: TextField(
                      controller: _stockSearchController,
                      onChanged: (val) => setState(() {}),
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: const InputDecoration(
                        hintText: 'Search products by title, SKU code, or category...',
                        hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.table_chart_rounded, size: 18, color: _stockViewMode == 'table' ? const Color(0xFFF37021) : const Color(0xFF94A3B8)),
                        onPressed: () => setState(() => _stockViewMode = 'table'),
                      ),
                      IconButton(
                        icon: Icon(Icons.grid_view_rounded, size: 18, color: _stockViewMode == 'cards' ? const Color(0xFFF37021) : const Color(0xFF94A3B8)),
                        onPressed: () => setState(() => _stockViewMode = 'cards'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Stock Items Table or Cards
          if (stocks.isEmpty)
            _buildEmptyState('No inventory items stocked at this facility yet.', isDark)
          else if (_stockViewMode == 'table' && isDesktop)
            _buildStockTable(context, stocks, isDark)
          else
            _buildStockCardsList(context, stocks, isDark),
        ],
      ),
    );
  }

  Widget _buildStockTable(BuildContext context, List<StockItemEntity> stocks, bool isDark) {
    final dcDrivers = ref.watch(dcConsoleProvider).dcDrivers;
    final stockState = ref.watch(stockProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
            columns: const [
              DataColumn(label: Text('Product & SKU', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Warehouse Shelf', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('In-Transit Saddlebag', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Total Available', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: stocks.map((item) {
              final isLow = item.availableCount <= item.lowStockThreshold;
              return DataRow(
                cells: [
                  DataCell(
                    Row(
                      children: [
                        ProductImageWidget(imageUrl: item.imageAsset, width: 32, height: 32, borderRadius: 6),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            Text(item.sku, style: GoogleFonts.firaCode(fontSize: 10.5, color: const Color(0xFF2563EB))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text(item.category, style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${item.availableCount} units', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                  DataCell(Text('${item.assignedCount} units', style: const TextStyle(color: Color(0xFFF97316), fontSize: 12.5))),
                  DataCell(Text('${item.availableCount + item.assignedCount} units', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isLow ? const Color(0xFFEF4444).withValues(alpha: 0.12) : const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isLow ? 'LOW STOCK' : 'HEALTHY',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isLow ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
                      ),
                    ),
                  ),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF2563EB)),
                      onPressed: () {
                        DCProductDetailModal.show(
                          context,
                          item: item,
                          drivers: dcDrivers,
                          allocations: stockState.riderAllocations,
                        );
                      },
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

  Widget _buildStockCardsList(BuildContext context, List<StockItemEntity> stocks, bool isDark) {
    final dcDrivers = ref.watch(dcConsoleProvider).dcDrivers;
    final stockState = ref.watch(stockProvider);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stocks.length,
      itemBuilder: (ctx, i) {
        final item = stocks[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: InkWell(
            onTap: () {
              DCProductDetailModal.show(
                context,
                item: item,
                drivers: dcDrivers,
                allocations: stockState.riderAllocations,
              );
            },
            child: Row(
              children: [
                ProductImageWidget(imageUrl: item.imageAsset, width: 44, height: 44, borderRadius: 8),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      Text('${item.sku} • Shelf: ${item.availableCount} • Transit: ${item.assignedCount}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // TAB 4: RIDERS & FLEET
  // ===========================================================================
  Widget _buildRidersTab(
    BuildContext context,
    bool isDark,
    bool isDesktop,
    List<DCFleetDriver> riders,
  ) {
    final activeCount = riders.where((r) => r.isActive).length;
    final inHouse = riders.where((r) => r.isInHouseRider).length;
    final pda = riders.where((r) => r.isPda).length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 20 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Riders KPIs
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cardWidth = isDesktop ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildStatCard(
                    width: cardWidth,
                    title: 'Total Attached Fleet',
                    value: '${riders.length} Riders',
                    subtext: 'Bound to this hub',
                    icon: Icons.two_wheeler_rounded,
                    color: const Color(0xFF2563EB),
                    isDark: isDark,
                  ),
                  _buildStatCard(
                    width: cardWidth,
                    title: 'Active On-Duty',
                    value: '$activeCount Riders',
                    subtext: 'Available for dispatch',
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                  _buildStatCard(
                    width: cardWidth,
                    title: 'In-House Personnel',
                    value: '$inHouse Riders',
                    subtext: 'Dedicated logistics staff',
                    icon: Icons.badge_rounded,
                    color: const Color(0xFFF97316),
                    isDark: isDark,
                  ),
                  _buildStatCard(
                    width: cardWidth,
                    title: 'Contract / PDA Agents',
                    value: '$pda Agents',
                    subtext: 'Commission agreements',
                    icon: Icons.handshake_rounded,
                    color: const Color(0xFF8B5CF6),
                    isDark: isDark,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Onboard Button + Search
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => DCOnboardRiderModal.show(context),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: Colors.white),
                label: const Text('+ Onboard Rider to this Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF37021),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: TextField(
                    controller: _ridersSearchController,
                    onChanged: (val) => setState(() {}),
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      hintText: 'Search rider by name, code, phone, or zone...',
                      hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Riders Table or Cards
          if (riders.isEmpty)
            _buildEmptyState('No delivery personnel attached to this hub yet.', isDark)
          else if (_ridersViewMode == 'table' && isDesktop)
            _buildRidersTable(context, riders, isDark)
          else
            _buildRidersCardsList(context, riders, isDark),
        ],
      ),
    );
  }

  Widget _buildRidersTable(BuildContext context, List<DCFleetDriver> riders, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
            columns: const [
              DataColumn(label: Text('RIDER / AGENT', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('PHONE', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('VEHICLE & PLATE', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('OPERATIONAL ZONE', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: riders.map((r) {
              return DataRow(
                onSelectChanged: (_) {
                  DCRiderDetailModal.show(context, r);
                },
                cells: [
                  DataCell(
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                          child: Text(r.name.isNotEmpty ? r.name[0].toUpperCase() : 'R', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            Text(r.driverCode, style: GoogleFonts.firaCode(fontSize: 10.5, color: const Color(0xFF2563EB))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text(r.phone, style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${r.vehicleType.toUpperCase()} (${r.vehiclePlate.isNotEmpty ? r.vehiclePlate : 'N/A'})', style: const TextStyle(fontSize: 12))),
                  DataCell(Text(r.assignedZone, style: const TextStyle(fontSize: 12))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: r.isActive ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFF94A3B8).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(r.isActive ? 'ACTIVE' : 'OFF-DUTY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: r.isActive ? const Color(0xFF10B981) : const Color(0xFF64748B))),
                    ),
                  ),
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF2563EB)),
                          tooltip: 'View Profile',
                          onPressed: () {
                            DCRiderDetailModal.show(context, r);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.phone_outlined, size: 18, color: Color(0xFF10B981)),
                          tooltip: 'Contact / View Profile',
                          onPressed: () {
                            DCRiderDetailModal.show(context, r);
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

  Widget _buildRidersCardsList(BuildContext context, List<DCFleetDriver> riders, bool isDark) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: riders.length,
      itemBuilder: (ctx, i) {
        final r = riders[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: InkWell(
            onTap: () => DCRiderDetailModal.show(context, r),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  child: Text(r.name.isNotEmpty ? r.name[0].toUpperCase() : 'R', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      Text('${r.driverCode} • ${r.phone} • ${r.assignedZone}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // TAB 5: SETTINGS & PROFILE UPDATES
  // ===========================================================================
  Widget _buildSettingsTab(
    BuildContext context,
    bool isDark,
    bool isDesktop,
    DCConsoleNotifier notifier,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: DC Facility Profile
          Text('Distribution Center Profile Details', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Update core facility identifiers, location, and storage capacity parameters.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildTextField('Hub / DC Name', _nameController, isDark)),
                    const SizedBox(width: 14),
                    Expanded(child: _buildTextField('Contact Phone', _phoneController, isDark)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Physical Address', _addressController, isDark)),
                    const SizedBox(width: 14),
                    Expanded(child: _buildTextField('City', _cityController, isDark)),
                    const SizedBox(width: 14),
                    Expanded(child: _buildTextField('State', _stateController, isDark)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Storage Capacity Units', _capacityController, isDark)),
                    const SizedBox(width: 14),
                    Expanded(child: _buildTextField('Contact Email', _emailController, isDark)),
                  ],
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () {
                      final updated = DistributionCenter(
                        id: _currentDc.id,
                        name: _nameController.text.trim(),
                        code: _currentDc.code,
                        state: _stateController.text.trim(),
                        city: _cityController.text.trim(),
                        address: _addressController.text.trim(),
                        contactPhone: _phoneController.text.trim(),
                        contactEmail: _emailController.text.trim(),
                        managerName: _managerController.text.trim(),
                        storageCapacityUnits: int.tryParse(_capacityController.text) ?? _currentDc.storageCapacityUnits,
                        operatingZones: _currentDc.operatingZones,
                        isHub: _currentDc.isHub,
                        isGrandDc: _currentDc.isGrandDc,
                        isActive: _currentDc.isActive,
                        parentDcId: _currentDc.parentDcId,
                      );
                      setState(() => _currentDc = updated);
                      widget.onDcUpdated?.call(updated);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Distribution Center Profile Updated Successfully!'), backgroundColor: Color(0xFF10B981)),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                    child: const Text('Save Facility Details', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 2: Supervisor & Password Reset / Security Credentials
          Text('Hub Supervisor Credentials & Password Reset', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Manage access security credentials and PIN reset for this DC console.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField('Assigned Hub Supervisor', _managerController, isDark),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Current Password / Admin PIN', _oldPasswordController, isDark, isPassword: true)),
                    const SizedBox(width: 14),
                    Expanded(child: _buildTextField('New Password / PIN', _newPasswordController, isDark, isPassword: true)),
                    const SizedBox(width: 14),
                    Expanded(child: _buildTextField('Confirm New Password', _confirmPasswordController, isDark, isPassword: true)),
                  ],
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_newPasswordController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a new password.'), backgroundColor: Colors.red),
                        );
                        return;
                      }
                      if (_newPasswordController.text != _confirmPasswordController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('New passwords do not match!'), backgroundColor: Colors.red),
                        );
                        return;
                      }
                      _oldPasswordController.clear();
                      _newPasswordController.clear();
                      _confirmPasswordController.clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Supervisor Credentials & Password Updated Successfully!'), backgroundColor: Color(0xFF10B981)),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF37021), foregroundColor: Colors.white),
                    child: const Text('Update Password & Credentials', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 3: Operating Zones Coverage
          Text('Operational Coverage Zones (LGAs)', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('The smart routing matrix assigns incoming deliveries strictly to these local zones.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _currentDc.operatingZones.map((zone) {
                    return Chip(
                      label: Text(zone, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                    );
                  }).toList(),
                ),
                if (_currentDc.operatingZones.isEmpty)
                  const Text('No specific zones assigned. Serves all general regional requests.', style: TextStyle(color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, bool isDark, {bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 11)),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Shared Utilities
  // ===========================================================================
  Widget _buildStatCard({
    required double width,
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            subtext,
            style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required IconData icon,
    required String label,
    required List<String> items,
    required String value,
    required Function(String?) onChanged,
    required bool isDark,
  }) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i.replaceAll('_', ' ').toUpperCase()))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildMobileFilterIconBtn({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFF37021).withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? const Color(0xFFF37021) : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isActive ? const Color(0xFFF37021) : const Color(0xFF64748B)),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isActive ? const Color(0xFFF37021) : const Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  void _showMobileFilterOptions(
    BuildContext context,
    String title,
    List<String> options,
    String selected,
    Function(String) onSelect,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...options.map((opt) {
                final isCurrent = opt == selected;
                return ListTile(
                  title: Text(opt.replaceAll('_', ' ').toUpperCase()),
                  trailing: isCurrent ? const Icon(Icons.check, color: Color(0xFFF37021)) : null,
                  onTap: () {
                    onSelect(opt);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, size: 40, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 10),
          Text(
            message,
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
