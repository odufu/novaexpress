import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/nova_tooltip.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../../orders/presentation/widgets/smart_order_paste_modal.dart';
import '../../../stock/domain/entities/rider_stock_allocation.dart';
import '../../../stock/domain/entities/stock_item.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../../domain/entities/distribution_center.dart';
import '../providers/dc_console_provider.dart';

/// NovaXpress Logistics Admin Dashboard (`/logistics-admin`)
///
/// Dedicated operational execution console for NovaXpress Logistics (the operating agent).
/// Governs:
/// 1. DC Station & Regional Hub Command (National Fleet)
/// 2. Live WhatsApp Order Intake Pipeline & 3-Criteria Smart Dispatch compliance
/// 3. Fleet & Field Courier Management with exact In-Vehicle Stock Custody tracking
/// 4. DC Cash Operations, Direct Transfer Clearances & 10:00 PM batch remittance staging
/// 5. Delivery SLAs (FADR, same-day rate, failure diagnostics)
/// 6. Inter-Station 2-Week Stock Redistribution Tracking
class NovaXpressLogisticsAdminDashboardPage extends ConsumerStatefulWidget {
  const NovaXpressLogisticsAdminDashboardPage({super.key});

  @override
  ConsumerState<NovaXpressLogisticsAdminDashboardPage> createState() =>
      _NovaXpressLogisticsAdminDashboardPageState();
}

class _NovaXpressLogisticsAdminDashboardPageState
    extends ConsumerState<NovaXpressLogisticsAdminDashboardPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;
  int _activeTabIndex = 0;
  String? _selectedDcFilterId; // null = All Stations (National)
  String _courierSearchQuery = '';
  String _courierStatusFilter = 'all'; // all, active, at_rest, offline

  final currencyFmt = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

  final List<Map<String, dynamic>> _tabs = const [
    {
      'title': 'Command Telemetry',
      'icon': Icons.dashboard_outlined,
      'activeIcon': Icons.dashboard_rounded,
      'tooltip': 'National logistics velocity, fleet availability, intake rates and cash liabilities',
    },
    {
      'title': 'DC Stations & Hubs',
      'icon': Icons.hub_outlined,
      'activeIcon': Icons.hub_rounded,
      'tooltip': 'Regional distribution centers, storage utilization and station personnel',
    },
    {
      'title': 'WhatsApp Dispatch Queue',
      'icon': Icons.chat_bubble_outline_rounded,
      'activeIcon': Icons.chat_bubble_rounded,
      'tooltip': 'Live WhatsApp intake pipeline, 15-min SLA aging & 3-criteria smart ranking',
    },
    {
      'title': 'Fleet & Vehicle Custody',
      'icon': Icons.motorcycle_outlined,
      'activeIcon': Icons.motorcycle_rounded,
      'tooltip': 'Courier roster, on-duty status, in-vehicle trunk stock audits & cash liabilities',
    },
    {
      'title': 'DC Cash & Treasury',
      'icon': Icons.payments_outlined,
      'activeIcon': Icons.payments_rounded,
      'tooltip': 'Courier cash balances, direct transfer clearances & 10:00 PM remittance staging',
    },
    {
      'title': 'Delivery SLAs & Diagnostics',
      'icon': Icons.analytics_outlined,
      'activeIcon': Icons.analytics_rounded,
      'tooltip': 'First-Attempt Delivery Rate (FADR), same-day completion & failure root causes',
    },
    {
      'title': 'Inter-Station Balancing',
      'icon': Icons.swap_horiz_rounded,
      'activeIcon': Icons.swap_horiz_rounded,
      'tooltip': '2-week lead-time regional stock redistribution manifests & balance alerts',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.index != _activeTabIndex) {
        setState(() {
          _activeTabIndex = _tabController.index;
        });
      }
    });

    // Refresh state on initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dcConsoleProvider.notifier).loadDriversFromDatabase();
      ref.read(dcConsoleProvider.notifier).loadDistributionCentersFromDatabase();
      ref.read(stockProvider.notifier).fetchStockItems();
      ref.read(ordersProvider.notifier).loadOrders();
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
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final dcState = ref.watch(dcConsoleProvider);
    final stockState = ref.watch(stockProvider);
    final ordersState = ref.watch(ordersProvider);

    // Apply station filter across data sets
    final dcs = dcState.distributionCenters;
    final allDrivers = dcState.drivers;
    final filteredDrivers = _selectedDcFilterId == null
        ? allDrivers
        : allDrivers.where((d) => d.distributionCenterId == _selectedDcFilterId).toList();

    final allOrders = ordersState.orders;
    final filteredOrders = _selectedDcFilterId == null
        ? allOrders
        : allOrders.where((o) {
            // Match order by DC id or driver's DC
            if (o.deliveryAgentId != null) {
              final driver = allDrivers.where((d) => d.id == o.deliveryAgentId).firstOrNull;
              if (driver != null && driver.distributionCenterId != null) {
                return driver.distributionCenterId == _selectedDcFilterId;
              }
            }
            return true;
          }).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF0B132B) : const Color(0xFFF1F5F9),
      drawer: isDesktop ? null : Drawer(child: _buildSidebar(isDark, dcs)),
      body: Row(
        children: [
          // Desktop Fixed Left Sidebar
          if (isDesktop)
            SizedBox(
              width: 260,
              child: _buildSidebar(isDark, dcs),
            ),

          // Main Logistics Operations Body
          Expanded(
            child: Column(
              children: [
                // Top Operational Navigation & Switcher Header
                _buildTopHeader(isDark, isDesktop, dcs),

                // Secondary Mobile Tab Bar (if screen is not desktop)
                if (!isDesktop) _buildMobileTabBar(isDark),

                // Main Tab Content View
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCommandTelemetryTab(isDark, filteredDrivers, filteredOrders, dcs, stockState),
                      _buildDcStationsTab(isDark, dcs, allDrivers, stockState),
                      _buildWhatsAppDispatchQueueTab(isDark, filteredOrders, filteredDrivers),
                      _buildFleetAndVehicleCustodyTab(isDark, filteredDrivers, stockState.riderAllocations, stockState.stockItems),
                      _buildDcCashAndTreasuryTab(isDark, filteredDrivers, filteredOrders),
                      _buildDeliverySlasAndDiagnosticsTab(isDark, filteredOrders),
                      _buildInterStationBalancingTab(isDark, dcs, stockState.stockItems),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TOP BAR & SWITCHER HEADER
  // ==========================================
  Widget _buildTopHeader(bool isDark, bool isDesktop, List<DistributionCenter> dcs) {
    if (!isDesktop) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.menu_rounded, size: 20),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_shipping_rounded, size: 12, color: Color(0xFFF97316)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'LOGISTICS ADMIN',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFF97316),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  onPressed: () => context.go('/admin'),
                  icon: const Icon(Icons.language_rounded, size: 12, color: Colors.white),
                  label: Text(
                    'Platform Admin',
                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 17),
                  onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedDcFilterId,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                        hint: Text(
                          '🌐 National Fleet (All Stations)',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              '🌐 National Fleet (All Stations)',
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                          ...dcs.map(
                            (dc) => DropdownMenuItem<String?>(
                              value: dc.id,
                              child: Text(
                                '${dc.name} (${dc.city})',
                                style: GoogleFonts.inter(fontSize: 11.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedDcFilterId = val;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _openSmartOrderPasteModal(context),
                  icon: const Icon(Icons.paste_rounded, size: 14, color: Colors.white),
                  label: Text(
                    'Intake WhatsApp',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Drawer Trigger on Mobile
          if (!isDesktop)
            IconButton(
              icon: const Icon(Icons.menu_rounded, size: 22),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),

          // Logistics Admin Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_shipping_rounded, size: 14, color: Color(0xFFF97316)),
                const SizedBox(width: 6),
                Text(
                  'LOGISTICS ADMIN',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFF97316),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Station Scope Filter Dropdown
          Flexible(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedDcFilterId,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                  hint: Text(
                    '🌐 National Fleet (All Stations)',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        '🌐 National Fleet (All Stations)',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...dcs.map(
                      (dc) => DropdownMenuItem<String?>(
                        value: dc.id,
                        child: Text(
                          '${dc.name} (${dc.city})',
                          style: GoogleFonts.inter(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedDcFilterId = val;
                    });
                  },
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // SWITCHER BUTTON: Switch to NovaXpress Platform Admin
          NovaTooltip(
            message: 'Switch to NovaXpress Platform Admin (Merchants, 3PL Partners & 10 PM Settlements)',
            child: ElevatedButton.icon(
              onPressed: () => context.go('/admin'),
              icon: const Icon(Icons.language_rounded, size: 15, color: Colors.white),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Platform Admin',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white70),
                ],
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Quick Action: Paste Order from WhatsApp
          NovaTooltip(
            message: 'DC Dispatch Ops: Paste new order received from WhatsApp',
            child: ElevatedButton.icon(
              onPressed: () => _openSmartOrderPasteModal(context),
              icon: const Icon(Icons.paste_rounded, size: 15, color: Colors.white),
              label: Text(
                'Intake WhatsApp',
                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Refresh Telemetry
          NovaTooltip(
            message: 'Refresh live fleet & telemetry data',
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: () {
                ref.read(dcConsoleProvider.notifier).loadDriversFromDatabase();
                ref.read(dcConsoleProvider.notifier).loadDistributionCentersFromDatabase();
                ref.read(stockProvider.notifier).fetchStockItems();
                ref.read(ordersProvider.notifier).loadOrders();
              },
            ),
          ),

          // Dark/Light Theme Toggle
          NovaTooltip(
            message: isDark ? 'Switch to light mode' : 'Switch to dark mode',
            child: IconButton(
              icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 20),
              onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SIDEBAR (DESKTOP & MOBILE DRAWER)
  // ==========================================
  Widget _buildSidebar(bool isDark, List<DistributionCenter> dcs) {
    return Container(
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Branding Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF97316).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NovaXpress',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'LOGISTICS COMMAND',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFF97316),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Operational Identity Notice
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFF97316)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Operational Agent Console for DC Stations, Fleet Couriers, In-Vehicle Custody & Daily Remittances.',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Navigation Items
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              itemCount: _tabs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                final isSelected = _activeTabIndex == index;

                return NovaTooltip(
                  message: tab['tooltip'] as String,
                  child: InkWell(
                    onTap: () {
                      _tabController.animateTo(index);
                      if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
                        Navigator.pop(context);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFF97316).withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.3))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? tab['activeIcon'] as IconData : tab['icon'] as IconData,
                            size: 19,
                            color: isSelected
                                ? const Color(0xFFF97316)
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              tab['title'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFFF97316)
                                    : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // User Footer Profile & Console Route Indicator
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFF97316).withValues(alpha: 0.2),
                  child: const Icon(Icons.person_rounded, size: 18, color: Color(0xFFF97316)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fleet Controller',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'NovaXpress Logistics',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFEF4444)),
                  tooltip: 'Sign out',
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MOBILE TAB BAR
  // ==========================================
  Widget _buildMobileTabBar(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: const Color(0xFFF97316),
        indicatorWeight: 3,
        labelColor: const Color(0xFFF97316),
        unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        tabs: _tabs.map((t) => Tab(text: t['title'] as String)).toList(),
      ),
    );
  }

  // ==========================================
  // TAB 1: COMMAND TELEMETRY
  // ==========================================
  Widget _buildCommandTelemetryTab(
    bool isDark,
    List<DCFleetDriver> drivers,
    List<OrderEntity> orders,
    List<DistributionCenter> dcs,
    StockState stockState,
  ) {
    final activeDrivers = drivers.where((d) => d.status == 'active').length;
    final totalDrivers = drivers.length;
    final pendingOrders = orders.where((o) => !o.isDelivered && !o.isCancelled).length;
    final inTransitOrders = orders.where((o) => o.status.toLowerCase() == 'in_transit').length;
    final deliveredToday = orders.where((o) => o.isDelivered).length;

    // Total cash custody currently held by field couriers
    final totalCashLiabilities = drivers.fold<double>(0.0, (acc, d) => acc + d.cashInCustody);

    // Total stock in courier vehicle custody
    final totalVehicleUnits = stockState.riderAllocations.fold<int>(0, (acc, a) => acc + a.inCustodyUnits);
    final totalWarehouseUnits = stockState.stockItems.fold<int>(0, (acc, i) => acc + i.availableCount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner: Fleet Execution Overview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFFFFFFFF), const Color(0xFFF8FAFC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '● LIVE FLEET TELEMETRY',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ),
                          Text(
                            _selectedDcFilterId == null ? '36 States Fleet Operations' : 'Regional DC Station Command',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'NovaXpress Field Logistics Command Hub',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Live tracking of WhatsApp intake velocity, courier vehicle custody, in-field cash liabilities, and station stock balancing.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.radar_rounded, size: 36, color: Color(0xFFF97316)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Primary Logistics Telemetry KPI Cards
          LayoutBuilder(builder: (context, constraints) {
            final cardWidth = constraints.maxWidth > 900
                ? (constraints.maxWidth - 48) / 4
                : (constraints.maxWidth > 600 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth);

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildKpiCard(
                  width: cardWidth,
                  title: 'Active Couriers On-Duty',
                  value: '$activeDrivers / $totalDrivers',
                  subtitle: '${((activeDrivers / (totalDrivers > 0 ? totalDrivers : 1)) * 100).toStringAsFixed(0)}% Fleet Capacity',
                  icon: Icons.two_wheeler_rounded,
                  accentColor: const Color(0xFF06B6D4),
                  isDark: isDark,
                ),
                _buildKpiCard(
                  width: cardWidth,
                  title: 'In-Transit Deliveries',
                  value: '$inTransitOrders',
                  subtitle: '$pendingOrders total pending deliveries',
                  icon: Icons.local_shipping_rounded,
                  accentColor: const Color(0xFFF97316),
                  isDark: isDark,
                ),
                _buildKpiCard(
                  width: cardWidth,
                  title: 'In-Field Cash Liabilities',
                  value: currencyFmt.format(totalCashLiabilities),
                  subtitle: 'Pending clearance or 10 PM deposit',
                  icon: Icons.payments_rounded,
                  accentColor: const Color(0xFF10B981),
                  isDark: isDark,
                ),
                _buildKpiCard(
                  width: cardWidth,
                  title: 'Trunk Custody vs Shelf Stock',
                  value: '$totalVehicleUnits / $totalWarehouseUnits',
                  subtitle: 'Trunk custody units / DC shelf units',
                  icon: Icons.inventory_2_rounded,
                  accentColor: const Color(0xFF8B5CF6),
                  isDark: isDark,
                ),
              ],
            );
          }),
          const SizedBox(height: 20),

          // Station Readiness & 10:00 PM Remittance Health Staging Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_filled_rounded, size: 18, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 240),
                          child: Text(
                            '10:00 PM Daily Remittance & Settlement Cycle',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'STAGING READY',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Per the Board Directive: All field agents and couriers remit collected funds to NovaXpress stations. Finance Ops verifies direct transfer bank receipts and clears cash liabilities. NovaXpress Platform Admin executes final merchant settlements on or before 10:00 PM daily.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildPillBadge(
                      label: 'Delivered Today: $deliveredToday drops',
                      color: const Color(0xFF10B981),
                      isDark: isDark,
                    ),
                    _buildPillBadge(
                      label: 'Couriers with Cash Liabilities: ${drivers.where((d) => d.cashInCustody > 0).length}',
                      color: const Color(0xFFF59E0B),
                      isDark: isDark,
                    ),
                    _buildPillBadge(
                      label: 'Active Stations: ${dcs.length}',
                      color: const Color(0xFF2563EB),
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // DC Stations Summary Table
          Text(
            'Distribution Center Station Summary',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          _buildDcStationsMiniTable(isDark, dcs, drivers),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: DC STATIONS & WAREHOUSING
  // ==========================================
  Widget _buildDcStationsTab(
    bool isDark,
    List<DistributionCenter> dcs,
    List<DCFleetDriver> drivers,
    StockState stockState,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Regional Distribution Centers & Hubs',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Physical warehousing, storage capacity utilization and station personnel',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => context.go('/admin'),
                icon: const Icon(Icons.add_business_rounded, size: 15, color: Colors.white),
                label: Text(
                  'Manage in Admin',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // DC Cards Grid
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dcs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final dc = dcs[index];
              final stationDrivers = drivers.where((d) => d.distributionCenterId == dc.id).toList();
              final activeCouriers = stationDrivers.where((d) => d.status == 'active').length;
              final totalStationCash = stationDrivers.fold<double>(0.0, (acc, d) => acc + d.cashInCustody);

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: dc.isGrandDc
                                ? const Color(0xFFF97316).withValues(alpha: 0.15)
                                : const Color(0xFF2563EB).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            dc.isGrandDc ? Icons.stars_rounded : Icons.store_mall_directory_rounded,
                            color: dc.isGrandDc ? const Color(0xFFF97316) : const Color(0xFF2563EB),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    dc.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      dc.code,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF10B981),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${dc.address}, ${dc.city}, ${dc.state}',
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: dc.isActive
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : const Color(0xFFEF4444).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            dc.isActive ? 'OPERATIONAL' : 'OFFLINE',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: dc.isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Metrics Row
                    Wrap(
                      spacing: 20,
                      runSpacing: 10,
                      children: [
                        _buildMetricChip(
                          icon: Icons.motorcycle_rounded,
                          label: 'Assigned Fleet',
                          value: '$activeCouriers on-duty (${stationDrivers.length} total)',
                          isDark: isDark,
                        ),
                        _buildMetricChip(
                          icon: Icons.inventory_2_rounded,
                          label: 'Storage Capacity',
                          value: '${dc.storageCapacityUnits} units cap',
                          isDark: isDark,
                        ),
                        _buildMetricChip(
                          icon: Icons.payments_rounded,
                          label: 'Courier Cash in Custody',
                          value: currencyFmt.format(totalStationCash),
                          isDark: isDark,
                        ),
                        if (dc.bankName != null && dc.bankAccountNumber != null)
                          _buildMetricChip(
                            icon: Icons.account_balance_rounded,
                            label: 'Station Bank (Direct COD)',
                            value: '${dc.bankName} - ${dc.bankAccountNumber}',
                            isDark: isDark,
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
    );
  }

  // ==========================================
  // TAB 3: WHATSAPP DISPATCH QUEUE
  // ==========================================
  Widget _buildWhatsAppDispatchQueueTab(
    bool isDark,
    List<OrderEntity> orders,
    List<DCFleetDriver> drivers,
  ) {
    // Orders waiting for assignment or recently assigned
    final unassignedOrders = orders.where((o) => o.deliveryAgentId == null && !o.isCancelled && !o.isDelivered).toList();
    final inTransitOrders = orders.where((o) => o.status.toLowerCase() == 'in_transit').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Quick Intake Trigger
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WhatsApp Order Intake & Smart Dispatch',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'DC Dispatch Ops intake workflow: Orders pasted from WhatsApp -> 3-criteria smart courier ranking',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _openSmartOrderPasteModal(context),
                icon: const Icon(Icons.paste_rounded, size: 16, color: Colors.white),
                label: Text(
                  'Paste WhatsApp Order',
                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3-Criteria Ranking Compliance Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, size: 16, color: Color(0xFF06B6D4)),
                    const SizedBox(width: 8),
                    Text(
                      '3-CRITERIA MANDATORY SMART DISPATCH COMPLIANCE',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF06B6D4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'When DC Dispatch Ops assigns an order, the system strictly ranks available couriers by:\n'
                  '1. Exact In-Vehicle Stock: Courier must have the requested product and quantity in custody.\n'
                  '2. Available Status: Courier must be marked "On-Duty" and under maximum active order load.\n'
                  '3. Delivery Geofence: Proximity to customer delivery address verified after pre-call confirmation.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Unassigned Orders Queue Section
          Row(
            children: [
              Text(
                'Unassigned Queue (${unassignedOrders.length})',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 10),
              if (unassignedOrders.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'REQUIRES DISPATCH ACTION',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (unassignedOrders.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 36, color: Color(0xFF10B981)),
                  const SizedBox(height: 8),
                  Text(
                    'All Ingested WhatsApp Orders Assigned to Couriers!',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'No orders waiting in queue. Fresh orders will appear here immediately upon intake.',
                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: unassignedOrders.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final order = unassignedOrders[index];
                return _buildOrderQueueRow(isDark, order, drivers);
              },
            ),

          const SizedBox(height: 24),

          // Active In-Transit Orders Pipeline
          Text(
            'Active In-Transit Pipeline (${inTransitOrders.length})',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: inTransitOrders.take(10).length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final order = inTransitOrders[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.two_wheeler_rounded, size: 18, color: Color(0xFFF97316)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                order.orderNumber,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFF97316),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                order.customerName,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${order.productName} • ${order.deliveryAddress}',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currencyFmt.format(order.totalAmount),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                        Text(
                          'Courier: ${order.deliveryAgentName ?? 'Assigned'}',
                          style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
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
    );
  }

  // ==========================================
  // TAB 4: FLEET & FIELD COURIERS
  // ==========================================
  Widget _buildFleetAndVehicleCustodyTab(
    bool isDark,
    List<DCFleetDriver> drivers,
    List<RiderStockAllocation> allocations,
    List<StockItemEntity> warehouseItems,
  ) {
    // Filter drivers by search and status
    final filtered = drivers.where((d) {
      if (_courierStatusFilter != 'all' && d.status != _courierStatusFilter) {
        return false;
      }
      if (_courierSearchQuery.isNotEmpty) {
        final q = _courierSearchQuery.toLowerCase();
        final matchesName = d.name.toLowerCase().contains(q);
        final matchesCode = d.driverCode.toLowerCase().contains(q);
        final matchesPlate = d.vehiclePlate.toLowerCase().contains(q);
        return matchesName || matchesCode || matchesPlate;
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fleet Roster & In-Vehicle Stock Custody',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Exact in-vehicle inventory breakdown, in-hand cash liabilities & rider agreements',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Text(
                '${filtered.length} Couriers Listed',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFF97316),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search and Filters Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _courierSearchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search courier by name, code or plate number...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _courierStatusFilter,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                      DropdownMenuItem(value: 'active', child: Text('On-Duty / Active')),
                      DropdownMenuItem(value: 'at_rest', child: Text('At Rest')),
                      DropdownMenuItem(value: 'offline', child: Text('Offline')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _courierStatusFilter = val;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Couriers Cards List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final driver = filtered[index];
              final driverAllocations = allocations.where((a) => a.riderId == driver.id || a.riderCode == driver.driverCode).toList();
              final totalUnitsInTrunk = driverAllocations.fold<int>(0, (acc, a) => acc + a.inCustodyUnits);

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFFF97316).withValues(alpha: 0.15),
                          child: Text(
                            driver.name.isNotEmpty ? driver.name[0].toUpperCase() : 'R',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFF97316),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    driver.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      driver.driverCode,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF06B6D4),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: driver.personnelType == 'pda'
                                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                                          : const Color(0xFF10B981).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      driver.personnelType.toUpperCase(),
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: driver.personnelType == 'pda'
                                            ? const Color(0xFF8B5CF6)
                                            : const Color(0xFF10B981),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${driver.vehicleModel} • ${driver.vehiclePlate} • ${driver.assignedZone}',
                                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: driver.status == 'active'
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : const Color(0xFF64748B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                driver.status.toUpperCase(),
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: driver.status == 'active'
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${driver.efficiencyRating.toStringAsFixed(1)}% Rating',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Cash & In-Vehicle Trunk Stock Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.inventory_2_rounded, size: 16, color: Color(0xFFF97316)),
                            const SizedBox(width: 6),
                            Text(
                              'In-Vehicle Custody: ',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                            ),
                            Text(
                              '$totalUnitsInTrunk units in trunk',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.payments_rounded, size: 16, color: Color(0xFF10B981)),
                            const SizedBox(width: 6),
                            Text(
                              'Cash in Hand: ',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                            ),
                            Text(
                              currencyFmt.format(driver.cashInCustody),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // In-Vehicle Products Pills Breakdown
                    if (driverAllocations.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: driverAllocations.where((a) => a.inCustodyUnits > 0).map((a) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              '${a.productName}: ${a.inCustodyUnits} units',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 5: DC CASH & TREASURY
  // ==========================================
  Widget _buildDcCashAndTreasuryTab(
    bool isDark,
    List<DCFleetDriver> drivers,
    List<OrderEntity> orders,
  ) {
    final totalCashLiabilities = drivers.fold<double>(0.0, (acc, d) => acc + d.cashInCustody);
    final deliveredOrders = orders.where((o) => o.isDelivered).toList();
    final directTransfers = deliveredOrders.where((o) => o.paymentType.toLowerCase().contains('transfer') || o.paymentStatus.toLowerCase().contains('transfer')).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DC Cash Operations & Daily Remittance',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Courier cash liabilities, direct transfer clearances & 10:00 PM batch remittance staging',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'TOTAL COD: ${currencyFmt.format(totalCashLiabilities)}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Operational Rules Notice
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, size: 20, color: Color(0xFFF59E0B)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Board Policy: All agents remit daily to NovaXpress stations. Finance Ops clears direct transfers and reconciles rider commission/fuel allowances. NovaXpress settles net merchant payouts by 10:00 PM.',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Direct Bank Transfer Clearance Ledger
          Text(
            'Direct Bank Transfer Incoming Clearances (${directTransfers.length})',
            style: GoogleFonts.inter(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),

          if (directTransfers.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Text(
                'No pending direct bank transfer orders requiring clearance.',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: directTransfers.take(8).length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final order = directTransfers[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF10B981)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${order.orderNumber} • ${order.customerName}',
                              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Direct Transfer into DC Account • Courier: ${order.deliveryAgentName ?? 'Courier'}',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        currencyFmt.format(order.totalAmount),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 20),

          // Courier Cash Liabilities Table
          Text(
            'In-Field Courier Cash Liabilities',
            style: GoogleFonts.inter(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          _buildCourierCashTable(isDark, drivers),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 6: DELIVERY SLAS & DIAGNOSTICS
  // ==========================================
  Widget _buildDeliverySlasAndDiagnosticsTab(bool isDark, List<OrderEntity> orders) {
    final totalOrders = orders.isNotEmpty ? orders.length : 1;
    final delivered = orders.where((o) => o.isDelivered).length;
    final inTransit = orders.where((o) => o.status.toLowerCase() == 'in_transit').length;
    final cancelledOrFailed = orders.where((o) => o.isCancelled).length;

    final deliverySuccessRate = (delivered / totalOrders) * 100;
    final failureRate = (cancelledOrFailed / totalOrders) * 100;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery SLA Performance & Failure Diagnostics',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          Text(
            'First-Attempt Delivery Rate (FADR), same-day completion velocity & delivery failure reasons',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),

          // SLA Metrics Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  title: 'First-Attempt Rate (FADR)',
                  value: '${deliverySuccessRate.toStringAsFixed(1)}%',
                  status: 'Benchmark: ≥ 85%',
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricBox(
                  title: 'Same-Day Completion',
                  value: '$delivered Delivered',
                  status: '$inTransit In-Transit',
                  color: const Color(0xFF06B6D4),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricBox(
                  title: 'Delivery Failure Rate',
                  value: '${failureRate.toStringAsFixed(1)}%',
                  status: '$cancelledOrFailed Returns/Failed',
                  color: const Color(0xFFEF4444),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Delivery Failure Reasons Breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top Delivery Failure Reasons (Rider Logs)',
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                _buildFailureReasonRow('Customer Phone Switched Off / Unreachable', '42%', const Color(0xFFF97316)),
                const SizedBox(height: 8),
                _buildFailureReasonRow('Rescheduled by Customer (Out of Town)', '28%', const Color(0xFF3B82F6)),
                const SizedBox(height: 8),
                _buildFailureReasonRow('Customer Declined Payment / Price Dispute', '18%', const Color(0xFFEF4444)),
                const SizedBox(height: 8),
                _buildFailureReasonRow('Incorrect Address / Location Outside Geofence', '12%', const Color(0xFF8B5CF6)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 7: INTER-STATION BALANCING
  // ==========================================
  Widget _buildInterStationBalancingTab(
    bool isDark,
    List<DistributionCenter> dcs,
    List<StockItemEntity> warehouseItems,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inter-Station Stock Balancing & Redistribution',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Redistribution manifests between regional hubs with standard 2-week lead-time tracking',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '2-WEEK LEAD TIME NOTICE',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFF97316),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Inter-Station Transfer Manifests Cards
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dcs.take(4).length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final dc = dcs[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${dc.name} (${dc.city})',
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'BALANCED',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Shelf holding: ${warehouseItems.length} catalog SKUs • Inter-station lead time: 14 business days',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================
  Widget _buildKpiCard({
    required double width,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFFF97316)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPillBadge({
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMetricBox({
    required String title,
    required String value,
    required String status,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(status, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildFailureReasonRow(String reason, String percentage, Color color) {
    return Row(
      children: [
        Expanded(
          child: Text(
            reason,
            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            percentage,
            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildDcStationsMiniTable(
    bool isDark,
    List<DistributionCenter> dcs,
    List<DCFleetDriver> drivers,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: dcs.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        itemBuilder: (context, index) {
          final dc = dcs[index];
          final stationDrivers = drivers.where((d) => d.distributionCenterId == dc.id).length;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dc.name,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${dc.city}, ${dc.state}',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${dc.storageCapacityUnits} units',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '$stationDrivers couriers',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ONLINE',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCourierCashTable(bool isDark, List<DCFleetDriver> drivers) {
    final withCash = drivers.where((d) => d.cashInCustody > 0).toList();

    if (withCash.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          'No couriers currently holding unremitted cash liabilities.',
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: withCash.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        itemBuilder: (context, index) {
          final driver = withCash[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.name,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${driver.driverCode} • ${driver.vehiclePlate}',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Text(
                  currencyFmt.format(driver.cashInCustody),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderQueueRow(bool isDark, OrderEntity order, List<DCFleetDriver> drivers) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.timer_outlined, size: 18, color: Color(0xFFEF4444)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      order.orderNumber,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      order.customerName,
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  '${order.productName} • ${order.deliveryAddress}',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Quick jump to DC Operations mobile portal or assign order
              context.go('/ops');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text(
              'Assign Courier',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _openSmartOrderPasteModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SmartOrderPasteModal(),
    );
  }
}
