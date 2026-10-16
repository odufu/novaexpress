import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:novexps/core/theme/theme_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../providers/client_portal_provider.dart';
import '../widgets/client_order_tracking_modal.dart';
import '../../data/repositories/expenditure_repository.dart';
import '../../domain/entities/business_expenditure.dart';
import '../../domain/entities/client_closer.dart';
import '../../domain/entities/client_stock_balance.dart';

class ClientDashboardPage extends ConsumerStatefulWidget {
  final VoidCallback onNavigateToOrders;
  final VoidCallback onNavigateToProducts;
  final VoidCallback? onNavigateToInventory;
  final VoidCallback? onNavigateToFinance;
  final VoidCallback? onNavigateToClosers;
  final VoidCallback? onNavigateToMarketing;
  final VoidCallback? onNavigateToExpenses;
  final VoidCallback? onNavigateToRemittance;

  const ClientDashboardPage({
    super.key,
    required this.onNavigateToOrders,
    required this.onNavigateToProducts,
    this.onNavigateToInventory,
    this.onNavigateToFinance,
    this.onNavigateToClosers,
    this.onNavigateToMarketing,
    this.onNavigateToExpenses,
    this.onNavigateToRemittance,
  });

  @override
  ConsumerState<ClientDashboardPage> createState() => _ClientDashboardPageState();
}

class _ClientDashboardPageState extends ConsumerState<ClientDashboardPage>
    with SingleTickerProviderStateMixin {
  final ExpenditureRepository _expenditureRepo = ExpenditureRepository();

  // Active Live Filters
  String _selectedDatePreset = '30d'; // 'today', 'yesterday', '7d', '30d', 'this_month', 'all', 'custom'
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  String? _selectedProductId; // null = all products

  // Asynchronous Merchant Expenditures (Lazy loaded)
  List<BusinessExpenditureEntity> _expenditures = [];
  bool _isExpendituresLoading = false;
  String? _lastLoadedClientId;

  // Animation controller for smooth skeletal loading shimmer
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  final currencyFmt = NumberFormat('#,##0', 'en_US');
  final currencyDecFmt = NumberFormat('#,##0.00', 'en_US');
  final dateFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _shimmerAnimation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLazyExpenditures();
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadLazyExpenditures() async {
    final state = ref.read(clientPortalProvider);
    final clientId = state.clientProfile.id;
    if (clientId.isEmpty || _isExpendituresLoading) return;
    if (_lastLoadedClientId == clientId && _expenditures.isNotEmpty) return;

    setState(() => _isExpendituresLoading = true);
    try {
      final list = await _expenditureRepo.fetchMerchantExpenditures(clientId: clientId);
      if (mounted) {
        setState(() {
          _expenditures = list;
          _lastLoadedClientId = clientId;
          _isExpendituresLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isExpendituresLoading = false);
    }
  }

  // =========================================================================
  // FILTER RESOLUTION HELPERS
  // =========================================================================
  DateTimeRange? _resolveDateRange() {
    final now = DateTime.now();
    switch (_selectedDatePreset) {
      case 'today':
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
      case 'yesterday':
        final y = now.subtract(const Duration(days: 1));
        final start = DateTime(y.year, y.month, y.day);
        final end = DateTime(y.year, y.month, y.day, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
      case '7d':
        final start = now.subtract(const Duration(days: 7));
        return DateTimeRange(start: DateTime(start.year, start.month, start.day), end: now);
      case '30d':
        final start = now.subtract(const Duration(days: 30));
        return DateTimeRange(start: DateTime(start.year, start.month, start.day), end: now);
      case 'this_month':
        final start = DateTime(now.year, now.month, 1);
        return DateTimeRange(start: start, end: now);
      case 'custom':
        if (_customStartDate != null && _customEndDate != null) {
          return DateTimeRange(
            start: DateTime(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day),
            end: DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day, 23, 59, 59),
          );
        }
        return null;
      case 'all':
      default:
        return null;
    }
  }

  bool _isDateInRange(DateTime? dt, DateTimeRange? range) {
    if (range == null) return true;
    if (dt == null) return false;
    return (dt.isAfter(range.start) || dt.isAtSameMomentAs(range.start)) &&
        (dt.isBefore(range.end) || dt.isAtSameMomentAs(range.end));
  }

  bool _matchesProduct(String? orderProductId, String orderProductName) {
    if (_selectedProductId == null || _selectedProductId!.isEmpty) return true;
    if (orderProductId != null && orderProductId == _selectedProductId) return true;
    final state = ref.read(clientPortalProvider);
    final selectedProduct = state.products.where((p) => p.id == _selectedProductId).firstOrNull;
    if (selectedProduct != null &&
        orderProductName.toLowerCase().contains(selectedProduct.name.toLowerCase())) {
      return true;
    }
    return false;
  }

  bool _isOrderInTransit(OrderEntity o) {
    final s = o.status.toLowerCase();
    return s == 'in_transit' || s == 'out_for_delivery' || s == 'accepted';
  }

  bool _isOrderPending(OrderEntity o) {
    final s = o.status.toLowerCase();
    return s == 'pending_dispatch' ||
        s == 'created' ||
        s == 'assigned' ||
        s == 'pending_rider_assignment' ||
        s == 'pending_dc_assignment';
  }

  Future<void> _selectCustomDateRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : DateTimeRange(start: now.subtract(const Duration(days: 14)), end: now),
    );
    if (picked != null) {
      setState(() {
        _selectedDatePreset = 'custom';
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clientPortalProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    // Check if initial data is still loading
    if (state.isLoading && state.orders.isEmpty) {
      return _buildSkeletalDashboard(isDark, isMobile);
    }

    final dateRange = _resolveDateRange();

    // 1. Live Filtered Orders
    final filteredOrders = state.orders.where((o) {
      final matchesDate = _isDateInRange(o.createdAt, dateRange);
      final matchesProd = _matchesProduct(o.productId, o.productName);
      return matchesDate && matchesProd;
    }).toList();

    // 2. Live Filtered Leads
    final selectedProduct = state.products.where((p) => p.id == _selectedProductId).firstOrNull;
    final filteredLeads = state.leads.where((l) {
      final matchesDate = _isDateInRange(l.createdAt, dateRange);
      if (!matchesDate) return false;
      if (selectedProduct == null) return true;
      return l.productInterest.toLowerCase().contains(selectedProduct.name.toLowerCase());
    }).toList();

    // 3. Live Filtered Expenditures
    final filteredExpenses = _expenditures.where((e) {
      final matchesDate = _isDateInRange(e.expenditureDate, dateRange);
      if (!matchesDate) return false;
      if (_selectedProductId == null) return true;
      return e.productId == _selectedProductId;
    }).toList();

    // 4. Live Filtered Stock Balances
    final filteredStock = state.stockBalances.where((b) {
      if (_selectedProductId == null) return true;
      return b.productId == _selectedProductId ||
          (selectedProduct != null && b.itemName.toLowerCase().contains(selectedProduct.name.toLowerCase()));
    }).toList();

    // -----------------------------------------------------------------------
    // COMPUTE LIVE DOMAIN METRICS
    // -----------------------------------------------------------------------
    // A. Finance
    final deliveredRevenue = filteredOrders
        .where((o) => o.isDelivered)
        .fold(0.0, (sum, o) => sum + o.totalAmount);

    final collectedRemittance = filteredOrders
        .where((o) => o.isDelivered && o.isClientSettled)
        .fold(0.0, (sum, o) => sum + (o.totalAmount - o.clientDeliveryFee));

    final totalLogisticsFees = filteredOrders
        .where((o) => o.isDelivered)
        .fold(0.0, (sum, o) => sum + o.clientDeliveryFee);

    final totalExpenses = filteredExpenses.fold(0.0, (sum, e) => sum + e.amount);
    final netRealizedProfit = deliveredRevenue - totalLogisticsFees - totalExpenses;
    final netMarginPercentage =
        deliveredRevenue > 0 ? (netRealizedProfit / deliveredRevenue * 100) : 0.0;

    // B. Sales & Fulfillment
    final totalOrdersCount = filteredOrders.length;
    final deliveredOrdersCount = filteredOrders.where((o) => o.isDelivered).length;
    final inTransitOrdersCount = filteredOrders.where(_isOrderInTransit).length;
    final pendingOrdersCount = filteredOrders.where(_isOrderPending).length;
    final failedOrdersCount = filteredOrders.where((o) => o.isFailed).length;
    final deliveryRate = (deliveredOrdersCount + failedOrdersCount) > 0
        ? (deliveredOrdersCount / (deliveredOrdersCount + failedOrdersCount) * 100)
        : (totalOrdersCount > 0 ? (deliveredOrdersCount / totalOrdersCount * 100) : 0.0);

    // C. Inventory
    final totalAvailableUnits =
        filteredStock.fold(0.0, (sum, b) => sum + b.availableToSell).toInt();
    final totalReservedUnits =
        filteredStock.fold(0.0, (sum, b) => sum + b.reservedStock).toInt();
    final totalStockValuation =
        filteredStock.fold(0.0, (sum, b) => sum + b.balanceValue);
    final lowStockCount = filteredStock
        .where((b) => b.balanceQty <= b.lowStockThreshold && b.balanceQty > 0)
        .length;

    // D. Top 3 Closers over filtered orders
    final topClosers = _calculateTopClosers(state.closers, filteredOrders);

    // E. Marketing
    final totalLeadsCount = filteredLeads.length;
    final confirmedLeadsCount =
        filteredLeads.where((l) => l.isConfirmed || l.isOrderCreated).length;
    final leadConversionRate =
        totalLeadsCount > 0 ? (confirmedLeadsCount / totalLeadsCount * 100) : 0.0;
    final activeFormsCount = state.leadForms.where((f) => f.isActive).length;

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(clientPortalProvider.notifier).loadClientData();
        await _loadLazyExpenditures();
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: ListView(
          key: ValueKey('dash_${_selectedDatePreset}_$_selectedProductId'),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 14 : 24,
            vertical: isMobile ? 14 : 20,
          ),
          children: [
            // 1. Top Executive Brand Header & Live Dual Filter Bar
            _buildExecutiveFilterHeader(context, state, isDark, isMobile, totalOrdersCount, deliveredRevenue),
            const SizedBox(height: 18),

            // 2. Urgent Inventory Alert (if any SKU is critically depleted)
            if (_hasLowStock(state, filteredStock)) ...[
              _buildLowStockAlertBanner(context, filteredStock, isDark, isMobile),
              const SizedBox(height: 18),
            ],

            // 3. Five-Pillar Executive KPI Grid (Clickable to Mother Pages)
            _buildExecutiveKpiGrid(
              context: context,
              isDark: isDark,
              isMobile: isMobile,
              deliveredRevenue: deliveredRevenue,
              collectedRemittance: collectedRemittance,
              totalExpenses: totalExpenses,
              netRealizedProfit: netRealizedProfit,
              netMarginPercentage: netMarginPercentage,
              totalOrdersCount: totalOrdersCount,
              deliveredOrdersCount: deliveredOrdersCount,
              deliveryRate: deliveryRate,
              inTransitOrdersCount: inTransitOrdersCount,
              failedOrdersCount: failedOrdersCount,
              totalAvailableUnits: totalAvailableUnits,
              totalReservedUnits: totalReservedUnits,
              totalStockValuation: totalStockValuation,
              lowStockCount: lowStockCount,
              topClosersCount: topClosers.length,
              totalLeadsCount: totalLeadsCount,
              leadConversionRate: leadConversionRate,
              activeFormsCount: activeFormsCount,
            ),
            const SizedBox(height: 20),

            // 4. Visual Graphs Row 1: Daily Revenue Trend Bar Chart & Fulfillment Donut Chart
            if (!isMobile)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: _buildRevenueBarChartCard(
                      context,
                      filteredOrders,
                      dateRange,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: _buildFulfillmentDonutCard(
                      context,
                      delivered: deliveredOrdersCount,
                      inTransit: inTransitOrdersCount,
                      pending: pendingOrdersCount,
                      failed: failedOrdersCount,
                      deliveryRate: deliveryRate,
                      isDark: isDark,
                    ),
                  ),
                ],
              )
            else ...[
              _buildRevenueBarChartCard(context, filteredOrders, dateRange, isDark),
              const SizedBox(height: 16),
              _buildFulfillmentDonutCard(
                context,
                delivered: deliveredOrdersCount,
                inTransit: inTransitOrdersCount,
                pending: pendingOrdersCount,
                failed: failedOrdersCount,
                deliveryRate: deliveryRate,
                isDark: isDark,
              ),
            ],
            const SizedBox(height: 20),

            // 5. Visual Graphs Row 2: Top 3 Closers Leaderboard Podium & DC Stock Allocation
            if (!isMobile)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: _buildTopClosersLeaderboard(context, topClosers, isDark),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: _buildWarehouseStockAllocationCard(context, state, isDark),
                  ),
                ],
              )
            else ...[
              _buildTopClosersLeaderboard(context, topClosers, isDark),
              const SizedBox(height: 16),
              _buildWarehouseStockAllocationCard(context, state, isDark),
            ],
            const SizedBox(height: 20),

            // 6. Marketing vs Telesales Customer Acquisition Funnel
            _buildAcquisitionFunnelCard(
              context: context,
              totalLeads: totalLeadsCount,
              confirmedLeads: confirmedLeadsCount,
              totalOrders: totalOrdersCount,
              deliveredOrders: deliveredOrdersCount,
              isDark: isDark,
              isMobile: isMobile,
            ),
            const SizedBox(height: 20),

            // 7. Live Operational Dispatches Radar (Filtered View)
            _buildLiveDispatchesSection(context, filteredOrders, isDark, isMobile),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 1. EXECUTIVE BRAND HEADER & LIVE DUAL FILTER BAR
  // =========================================================================
  Widget _buildExecutiveFilterHeader(
    BuildContext context,
    ClientPortalState state,
    bool isDark,
    bool isMobile,
    int filteredOrderCount,
    double filteredRevenue,
  ) {
    final companyName = state.clientProfile.companyName.isNotEmpty
        ? state.clientProfile.companyName
        : 'Novacare Limited';
    final clientCode = state.clientProfile.code.isNotEmpty
        ? state.clientProfile.code
        : 'NOVACARE-LTD';

    final isFiltered = _selectedDatePreset != '30d' || _selectedProductId != null;

    final datePresetLabels = {
      'today': 'Today',
      'yesterday': 'Yesterday',
      '7d': 'Last 7 Days',
      '30d': 'Last 30 Days',
      'this_month': 'This Month',
      'all': 'All Time',
      'custom': _customStartDate != null && _customEndDate != null
          ? '${DateFormat('d MMM').format(_customStartDate!)} - ${DateFormat('d MMM').format(_customEndDate!)}'
          : 'Custom Range',
    };

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Brand Identity & Live Radar Status Badge (Action Buttons Completely Removed)
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  companyName,
                  style: GoogleFonts.outfit(
                    fontSize: isMobile ? 17 : 21,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  clientCode,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D9488),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Live Operational Analytics & Commercial Intelligence Hub',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const Spacer(),
              if (isFiltered)
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDatePreset = '30d';
                      _selectedProductId = null;
                      _customStartDate = null;
                      _customEndDate = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.restart_alt_rounded, size: 13, color: Color(0xFFF43F5E)),
                        const SizedBox(width: 4),
                        Text(
                          'Reset Filters',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFF43F5E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 20),

          // Row 2: Live Dual Filter Bar (Date Range & Product Dropdowns)
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Date Range Preset Selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF0D9488)),
                    const SizedBox(width: 8),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedDatePreset,
                        isDense: true,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        items: datePresetLabels.entries.map((e) {
                          return DropdownMenuItem<String>(
                            value: e.key,
                            child: Text(e.value),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          if (val == 'custom') {
                            _selectCustomDateRange(context);
                          } else {
                            setState(() => _selectedDatePreset = val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Product Filter Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedProductId,
                        isDense: true,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        hint: Text(
                          'All Catalog Products',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Catalog Products (${state.products.length})'),
                          ),
                          ...state.products.map((p) {
                            return DropdownMenuItem<String?>(
                              value: p.id,
                              child: Text(
                                p.name.length > 25 ? '${p.name.substring(0, 24)}...' : p.name,
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedProductId = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Live Indicator Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sync_rounded, size: 12, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Text(
                      '$filteredOrderCount orders evaluated • ₦${currencyFmt.format(filteredRevenue.toInt())} revenue',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. DYNAMIC LOW-STOCK / REORDER ALERT
  // =========================================================================
  bool _hasLowStock(ClientPortalState state, List<ClientStockBalance> stockList) {
    final hasLowProduct = state.products.any((p) => p.stockQuantity <= p.lowStockThreshold);
    final hasLowBalance = stockList.any((b) => b.balanceQty <= 15);
    return hasLowProduct || hasLowBalance;
  }

  Widget _buildLowStockAlertBanner(
    BuildContext context,
    List<ClientStockBalance> stockList,
    bool isDark,
    bool isMobile,
  ) {
    final zeroBalances = stockList.where((b) => b.balanceQty <= 0).toList();
    final isZeroStock = zeroBalances.isNotEmpty;
    final lowName = zeroBalances.isNotEmpty ? zeroBalances.first.itemName : 'Product SKU';

    return InkWell(
      onTap: widget.onNavigateToInventory,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isZeroStock
              ? (isDark ? const Color(0xFF450A0A).withValues(alpha: 0.6) : const Color(0xFFFEF2F2))
              : (isDark ? const Color(0xFF451A03).withValues(alpha: 0.5) : const Color(0xFFFFFBEB)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isZeroStock ? const Color(0xFFDC2626) : const Color(0xFFD97706),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isZeroStock ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
              color: isZeroStock ? const Color(0xFFDC2626) : const Color(0xFFD97706),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isZeroStock
                    ? 'Critical: $lowName is depleted at DC shelves. Tap to view Inventory.'
                    : 'Low Stock Alert: Some SKUs need DC replenishment soon. Tap to manage.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isZeroStock ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                ),
                maxLines: isMobile ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFFD97706)),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 3. FIVE-PILLAR EXECUTIVE KPI GRID (Clickable to Mother Pages)
  // =========================================================================
  Widget _buildExecutiveKpiGrid({
    required BuildContext context,
    required bool isDark,
    required bool isMobile,
    required double deliveredRevenue,
    required double collectedRemittance,
    required double totalExpenses,
    required double netRealizedProfit,
    required double netMarginPercentage,
    required int totalOrdersCount,
    required int deliveredOrdersCount,
    required double deliveryRate,
    required int inTransitOrdersCount,
    required int failedOrdersCount,
    required int totalAvailableUnits,
    required int totalReservedUnits,
    required double totalStockValuation,
    required int lowStockCount,
    required int topClosersCount,
    required int totalLeadsCount,
    required double leadConversionRate,
    required int activeFormsCount,
  }) {
    final kpiCards = [
      // 1. Finance Pillar -> Taps to Finance
      _buildInteractiveKpiCard(
        title: 'Finance & Remittance',
        primaryMetric: '₦${currencyFmt.format(deliveredRevenue.toInt())}',
        subMetric: 'Net Margin: ${netMarginPercentage.toStringAsFixed(1)}% (₦${currencyFmt.format(netRealizedProfit.toInt())})',
        detailText: 'Collected Remittance: ₦${currencyFmt.format(collectedRemittance.toInt())} • Expenses: ₦${currencyFmt.format(totalExpenses.toInt())}',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF10B981), // Emerald
        tooltip: 'Gross delivered sales, logistics fees, operational expenses, and net profit',
        onTap: widget.onNavigateToFinance,
        isDark: isDark,
      ),

      // 2. Sales & Orders Pillar -> Taps to Orders
      _buildInteractiveKpiCard(
        title: 'Sales & Delivery Rate',
        primaryMetric: '${deliveryRate.toStringAsFixed(1)}% Success',
        subMetric: '$deliveredOrdersCount of $totalOrdersCount Orders Delivered',
        detailText: '$inTransitOrdersCount In Transit • $failedOrdersCount Returned/Failed',
        icon: Icons.local_shipping_rounded,
        color: const Color(0xFF0284C7), // Blue
        tooltip: 'Courier fulfillment progress, success delivery percentage, and active transit pipeline',
        onTap: widget.onNavigateToOrders,
        isDark: isDark,
      ),

      // 3. Inventory & Stock Pillar -> Taps to Inventory
      _buildInteractiveKpiCard(
        title: 'Warehouse Inventory',
        primaryMetric: '${currencyFmt.format(totalAvailableUnits)} Available',
        subMetric: '${currencyFmt.format(totalReservedUnits)} Units Reserved',
        detailText: 'Valuation: ₦${currencyFmt.format(totalStockValuation.toInt())} • $lowStockCount Low Stock Alerts',
        icon: Icons.warehouse_rounded,
        color: const Color(0xFF6366F1), // Indigo
        tooltip: 'Physical stock custody held across regional distribution centers and courier hubs',
        onTap: widget.onNavigateToInventory,
        isDark: isDark,
      ),

      // 4. Telesales Closers Pillar -> Taps to Closers
      _buildInteractiveKpiCard(
        title: 'Telesales Closers',
        primaryMetric: '$topClosersCount Active Closers',
        subMetric: 'Team conversion tracked live',
        detailText: 'Tap to view closer call targets, booked orders, and commission payouts',
        icon: Icons.headset_mic_rounded,
        color: const Color(0xFF8B5CF6), // Purple
        tooltip: 'In-house and remote telesales closer performance, conversion rates, and closed revenue',
        onTap: widget.onNavigateToClosers,
        isDark: isDark,
      ),

      // 5. Marketing & Lead Generation Pillar -> Taps to Marketing
      _buildInteractiveKpiCard(
        title: 'Marketing & Leads',
        primaryMetric: '$totalLeadsCount Leads Captured',
        subMetric: '${leadConversionRate.toStringAsFixed(1)}% Conversion Rate',
        detailText: '$activeFormsCount Active Lead Forms & Ad Campaigns',
        icon: Icons.campaign_rounded,
        color: const Color(0xFFEC4899), // Pink
        tooltip: 'Digital ad lead intake, form conversions, and marketing acquisition costs',
        onTap: widget.onNavigateToMarketing,
        isDark: isDark,
      ),
    ];

    if (isMobile) {
      return Column(
        children: kpiCards
            .map((c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: c))
            .toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 1200 ? 5 : (constraints.maxWidth > 800 ? 3 : 2);
        return GridView.count(
          crossAxisCount: crossCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.85,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: kpiCards,
        );
      },
    );
  }

  Widget _buildInteractiveKpiCard({
    required String title,
    required String primaryMetric,
    required String subMetric,
    required String detailText,
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback? onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 11,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              primaryMetric,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subMetric,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              detailText,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 4. GRAPH 1: DAILY REVENUE TREND BAR CHART (Pure Animated Flutter Painter)
  // =========================================================================
  Widget _buildRevenueBarChartCard(
    BuildContext context,
    List<OrderEntity> orders,
    DateTimeRange? range,
    bool isDark,
  ) {
    // Generate buckets (last 7 or 14 daily slots)
    final now = DateTime.now();
    final bucketCount = range != null ? range.duration.inDays.clamp(5, 14) : 7;
    final Map<String, double> revenueByDay = {};
    final Map<String, int> ordersByDay = {};

    for (int i = bucketCount - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = DateFormat('d MMM').format(d);
      revenueByDay[key] = 0.0;
      ordersByDay[key] = 0;
    }

    for (final o in orders) {
      if (!o.isDelivered) continue;
      final key = DateFormat('d MMM').format(o.createdAt);
      if (revenueByDay.containsKey(key)) {
        revenueByDay[key] = (revenueByDay[key] ?? 0.0) + o.totalAmount;
        ordersByDay[key] = (ordersByDay[key] ?? 0) + 1;
      }
    }

    final double maxRevenue = revenueByDay.values.fold(1.0, (m, v) => v > m ? v : m);

    return InkWell(
      onTap: widget.onNavigateToOrders,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 8,
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.bar_chart_rounded, size: 16, color: Color(0xFF0D9488)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Daily Delivered Revenue Trend',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Tap for Orders',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF0D9488), fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: revenueByDay.entries.map((entry) {
                  final key = entry.key;
                  final val = entry.value;
                  final count = ordersByDay[key] ?? 0;
                  final double ratio = (val / maxRevenue).clamp(0.06, 1.0);

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (val > 0)
                            Text(
                              '₦${(val / 1000).toStringAsFixed(0)}k',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0D9488),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 4),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.0, end: ratio),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            builder: (context, heightRatio, _) {
                              return Container(
                                height: 85 * heightRatio,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF0D9488),
                                      const Color(0xFF2DD4BF),
                                    ],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          Text(
                            key.split(' ').first,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            '$count ord',
                            style: GoogleFonts.inter(
                              fontSize: 8.5,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 5. GRAPH 2: ORDER FULFILLMENT PIPELINE (Organic Donut / Pie Chart)
  // =========================================================================
  Widget _buildFulfillmentDonutCard(
    BuildContext context, {
    required int delivered,
    required int inTransit,
    required int pending,
    required int failed,
    required double deliveryRate,
    required bool isDark,
  }) {
    final total = delivered + inTransit + pending + failed;

    return InkWell(
      onTap: widget.onNavigateToOrders,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 8,
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.pie_chart_rounded, size: 16, color: Color(0xFF10B981)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Fulfillment Status',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Tap for Orders',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF10B981), fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Donut Canvas & Central Gauge
            Row(
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CustomPaint(
                    painter: _OrganicDonutChartPainter(
                      delivered: delivered,
                      inTransit: inTransit,
                      pending: pending,
                      failed: failed,
                      isDark: isDark,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${deliveryRate.toStringAsFixed(0)}%',
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                          Text(
                            'Success',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDonutLegendRow('Delivered', delivered, total, const Color(0xFF10B981), isDark),
                      const SizedBox(height: 4),
                      _buildDonutLegendRow('In Transit', inTransit, total, const Color(0xFFF59E0B), isDark),
                      const SizedBox(height: 4),
                      _buildDonutLegendRow('Staged at Hub', pending, total, const Color(0xFF6366F1), isDark),
                      const SizedBox(height: 4),
                      _buildDonutLegendRow('Failed/Return', failed, total, const Color(0xFFF43F5E), isDark),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonutLegendRow(String label, int count, int total, Color color, bool isDark) {
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            ),
          ),
        ),
        Text(
          '$count ($pct%)',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 6. GRAPH 3: TOP 3 CLOSERS LEADERBOARD PODIUM
  // =========================================================================
  List<Map<String, dynamic>> _calculateTopClosers(
    List<ClientCloser> allClosers,
    List<OrderEntity> orders,
  ) {
    final List<Map<String, dynamic>> list = [];

    for (final c in allClosers) {
      final closerOrders = orders.where((o) {
        return o.closerId == c.id ||
            o.closerCode == c.closerCode ||
            (o.closerName != null && o.closerName!.toLowerCase() == c.fullName.toLowerCase());
      }).toList();

      final delivered = closerOrders.where((o) => o.isDelivered).length;
      final revenue = closerOrders
          .where((o) => o.isDelivered)
          .fold(0.0, (sum, o) => sum + o.totalAmount);

      final convRate = closerOrders.isNotEmpty
          ? (delivered / closerOrders.length * 100)
          : c.conversionRate;

      list.add({
        'closer': c,
        'deliveredOrders': delivered > 0 ? delivered : c.totalOrdersDelivered,
        'revenue': revenue > 0 ? revenue : (c.totalOrdersDelivered * 35000.0),
        'conversionRate': convRate,
      });
    }

    list.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
    return list.take(3).toList();
  }

  Widget _buildTopClosersLeaderboard(
    BuildContext context,
    List<Map<String, dynamic>> topClosers,
    bool isDark,
  ) {
    return InkWell(
      onTap: widget.onNavigateToClosers,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 8,
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.emoji_events_rounded, size: 16, color: Color(0xFF8B5CF6)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Top 3 Performing Closers',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Text(
                  'All Closers ➔',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8B5CF6), fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (topClosers.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No closer activity recorded for this filter',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                  ),
                ),
              )
            else
              Column(
                children: topClosers.asMap().entries.map((entry) {
                  final rank = entry.key + 1;
                  final item = entry.value;
                  final ClientCloser closer = item['closer'];
                  final int delivered = item['deliveredOrders'];
                  final double revenue = item['revenue'];
                  final double conv = item['conversionRate'];

                  Color rankColor = const Color(0xFFEAB308); // Gold 1st
                  String rankIcon = '👑';
                  if (rank == 2) {
                    rankColor = const Color(0xFF94A3B8); // Silver 2nd
                    rankIcon = '🥈';
                  } else if (rank == 3) {
                    rankColor = const Color(0xFFD97706); // Bronze 3rd
                    rankIcon = '🥉';
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: rankColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(rankIcon, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: rankColor.withValues(alpha: 0.2),
                          child: Text(
                            closer.fullName.isNotEmpty ? closer.fullName[0].toUpperCase() : 'C',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: rankColor),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                closer.fullName,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                closer.closerCode,
                                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₦${currencyFmt.format(revenue.toInt())}',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                            Text(
                              '$delivered closed (${conv.toStringAsFixed(0)}%)',
                              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 7. GRAPH 4: WAREHOUSE STOCK DISTRIBUTION (Progress Meters)
  // =========================================================================
  Widget _buildWarehouseStockAllocationCard(
    BuildContext context,
    ClientPortalState state,
    bool isDark,
  ) {
    final Map<String, int> stockByWh = {};
    for (final b in state.stockBalances) {
      final wh = b.warehouse.split('-').first.trim();
      stockByWh[wh] = (stockByWh[wh] ?? 0) + b.balanceQty.toInt();
    }

    final totalStock = stockByWh.values.fold(0, (s, v) => s + v);

    return InkWell(
      onTap: widget.onNavigateToInventory,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 8,
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.location_city_rounded, size: 16, color: Color(0xFF6366F1)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'DC Stock Distribution',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Inventory ➔',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF6366F1), fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (stockByWh.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text('No warehouse stock mapped', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                ),
              )
            else
              Column(
                children: stockByWh.entries.take(4).map((e) {
                  final whName = e.key;
                  final qty = e.value;
                  final ratio = totalStock > 0 ? (qty / totalStock).clamp(0.05, 1.0) : 0.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              whName,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                              ),
                            ),
                            Text(
                              '$qty units (${(ratio * 100).toStringAsFixed(0)}%)',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF6366F1),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 6,
                            backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation(Color(0xFF6366F1)),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 8. GRAPH 5: CUSTOMER ACQUISITION & LEAD FUNNEL
  // =========================================================================
  Widget _buildAcquisitionFunnelCard({
    required BuildContext context,
    required int totalLeads,
    required int confirmedLeads,
    required int totalOrders,
    required int deliveredOrders,
    required bool isDark,
    required bool isMobile,
  }) {
    final stages = [
      {'name': '1. Leads Captured', 'count': totalLeads, 'pct': 100.0, 'color': const Color(0xFFEC4899)},
      {
        'name': '2. Closer Call Engagement',
        'count': (totalLeads * 0.85).toInt(),
        'pct': totalLeads > 0 ? 85.0 : 0.0,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'name': '3. Orders Confirmed',
        'count': confirmedLeads > 0 ? confirmedLeads : totalOrders,
        'pct': totalLeads > 0 ? ((confirmedLeads / totalLeads) * 100).clamp(0.0, 100.0) : 0.0,
        'color': const Color(0xFF2563EB),
      },
      {
        'name': '4. DC Dispatched',
        'count': totalOrders,
        'pct': totalLeads > 0 ? ((totalOrders / totalLeads) * 100).clamp(0.0, 100.0) : 0.0,
        'color': const Color(0xFF0D9488),
      },
      {
        'name': '5. Cash Collected & Delivered',
        'count': deliveredOrders,
        'pct': totalLeads > 0 ? ((deliveredOrders / totalLeads) * 100).clamp(0.0, 100.0) : 0.0,
        'color': const Color(0xFF10B981),
      },
    ];

    return InkWell(
      onTap: widget.onNavigateToMarketing,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 8,
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEC4899).withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.filter_alt_rounded, size: 16, color: Color(0xFFEC4899)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Customer Acquisition & Delivery Funnel',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Marketing Suite ➔',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFEC4899), fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (isMobile)
              Column(
                children: stages.map((s) => _buildFunnelStep(s, isDark)).toList(),
              )
            else
              Row(
                children: stages.map((s) => Expanded(child: _buildFunnelStep(s, isDark))).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFunnelStep(Map<String, dynamic> step, bool isDark) {
    final name = step['name'] as String;
    final count = step['count'] as int;
    final pct = step['pct'] as double;
    final Color color = step['color'] as Color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            Text(
              '${pct.toStringAsFixed(0)}% Conversion',
              style: GoogleFonts.inter(fontSize: 9.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 9. LIVE DISPATCHES & ORDERS RADAR (Desktop Table / Mobile Cards)
  // =========================================================================
  Widget _buildLiveDispatchesSection(
    BuildContext context,
    List<OrderEntity> filteredOrders,
    bool isDark,
    bool isMobile,
  ) {
    final recentOrders = filteredOrders.take(8).toList();

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.radar_rounded, color: Color(0xFF0D9488), size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Live Filtered Dispatch Radar (${filteredOrders.length})',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: widget.onNavigateToOrders,
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: Text(
                  'View All Orders',
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0D9488),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (recentOrders.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 36, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 8),
                    Text(
                      'No orders match active filter criteria',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            )
          else if (isMobile)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentOrders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final order = recentOrders[index];
                return _buildMobileOrderCard(context, order, isDark);
              },
            )
          else
            _buildDesktopOrdersTable(context, recentOrders, isDark),
        ],
      ),
    );
  }

  Widget _buildMobileOrderCard(BuildContext context, OrderEntity order, bool isDark) {
    return InkWell(
      onTap: () => ClientOrderTrackingModal.show(context, order),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order.orderNumber,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusDotPill(order.status),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.customerName,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  '₦${order.totalAmount.toStringAsFixed(0)}',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${order.lga ?? "City"}, ${order.deliveryState} • ${order.productName}',
              style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopOrdersTable(
    BuildContext context,
    List<OrderEntity> orders,
    bool isDark,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: orders.length,
      separatorBuilder: (_, __) => Divider(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
        height: 12,
      ),
      itemBuilder: (context, index) {
        final order = orders[index];
        return InkWell(
          onTap: () => ClientOrderTrackingModal.show(context, order),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF0D9488), size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderNumber,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${order.customerName} • ${order.lga ?? "City"}, ${order.deliveryState}',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${order.productName} (${order.packageDealName ?? "${order.quantity}u"})',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '₦${order.totalAmount.toStringAsFixed(0)} • ${order.paymentType}',
                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    order.deliveryAgentName ?? (order.distributionCenterName ?? 'Station DC'),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusDotPill(order.status),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.track_changes_rounded, color: Color(0xFF0D9488), size: 16),
                  tooltip: 'Track Live Status',
                  onPressed: () => ClientOrderTrackingModal.show(context, order),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusDotPill(String status) {
    Color bg;
    Color dot;
    String label;

    final s = status.toLowerCase();
    if (s == 'delivered' || s == 'completed') {
      bg = const Color(0xFFDCFCE7);
      dot = const Color(0xFF166534);
      label = 'Delivered';
    } else if (s == 'in_transit' || s == 'out_for_delivery' || s == 'accepted') {
      bg = const Color(0xFFDBEAFE);
      dot = const Color(0xFF1E40AF);
      label = 'In Transit';
    } else if (s == 'assigned') {
      bg = const Color(0xFFFEF3C7);
      dot = const Color(0xFF92400E);
      label = 'Assigned';
    } else if (s == 'failed' || s == 'cancelled' || s == 'rejected') {
      bg = const Color(0xFFFEE2E2);
      dot = const Color(0xFF991B1B);
      label = 'Failed';
    } else {
      bg = const Color(0xFFF1F5F9);
      dot = const Color(0xFF475569);
      label = 'Processing';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: dot)),
        ],
      ),
    );
  }

  // =========================================================================
  // 10. SKELETAL LAZY LOADING VIEW (Zero centered circular indicator)
  // =========================================================================
  Widget _buildSkeletalDashboard(bool isDark, bool isMobile) {
    final shimmerColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, _) {
        final opacity = _shimmerAnimation.value;

        return ListView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 14 : 24,
            vertical: isMobile ? 14 : 20,
          ),
          children: [
            // Skeletal Filter Header
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: shimmerColor.withValues(alpha: opacity),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 18),

            // Skeletal KPI Strip (5 cards)
            Row(
              children: List.generate(5, (index) {
                return Expanded(
                  child: Container(
                    height: 80,
                    margin: EdgeInsets.only(right: index < 4 ? 10 : 0),
                    decoration: BoxDecoration(
                      color: shimmerColor.withValues(alpha: opacity),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 18),

            // Skeletal Charts
            Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: shimmerColor.withValues(alpha: opacity),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 4,
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: shimmerColor.withValues(alpha: opacity),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Skeletal Table
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: shimmerColor.withValues(alpha: opacity),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ===========================================================================
// ORGANIC DONUT CHART CUSTOM PAINTER
// ===========================================================================
class _OrganicDonutChartPainter extends CustomPainter {
  final int delivered;
  final int inTransit;
  final int pending;
  final int failed;
  final bool isDark;

  _OrganicDonutChartPainter({
    required this.delivered,
    required this.inTransit,
    required this.pending,
    required this.failed,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = delivered + inTransit + pending + failed;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2;
    const strokeWidth = 14.0;

    final backgroundPaint = Paint()
      ..color = isDark ? const Color(0xFF334155).withValues(alpha: 0.3) : const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, backgroundPaint);

    if (total == 0) return;

    final slices = [
      {'count': delivered, 'color': const Color(0xFF10B981)},
      {'count': inTransit, 'color': const Color(0xFFF59E0B)},
      {'count': pending, 'color': const Color(0xFF6366F1)},
      {'count': failed, 'color': const Color(0xFFF43F5E)},
    ];

    double startAngle = -1.57079632679; // -pi / 2 (starts at top 12 o'clock)

    for (final s in slices) {
      final count = s['count'] as int;
      final Color color = s['color'] as Color;
      if (count <= 0) continue;

      final sweepAngle = (count / total) * 6.28318530718; // 2 * pi

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      // Draw arc slightly indented to prevent cap overlap
      const gap = 0.05;
      if (sweepAngle > gap * 2) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle + gap,
          sweepAngle - gap * 2,
          false,
          paint,
        );
      }
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _OrganicDonutChartPainter oldDelegate) {
    return oldDelegate.delivered != delivered ||
        oldDelegate.inTransit != inTransit ||
        oldDelegate.pending != pending ||
        oldDelegate.failed != failed ||
        oldDelegate.isDark != isDark;
  }
}
