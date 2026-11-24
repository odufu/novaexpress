import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../../core/widgets/nova_searchable_picker.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../stock/domain/entities/stock_item.dart';
import '../../../stock/domain/entities/rider_stock_allocation.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../../domain/entities/distribution_center.dart';
import '../providers/dc_console_provider.dart';
import '../widgets/dc_staff_profile_settings_tab.dart';
import '../../domain/entities/dc_stock_velocity.dart';
import '../widgets/dc_unified_inbound_modal.dart';
import '../widgets/dc_product_detail_modal.dart';
import '../widgets/dc_notify_merchant_restock_modal.dart';
import '../widgets/dc_stock_notifications_modal.dart';
import '../widgets/dc_stock_settings_modal.dart';
import '../../../stock/domain/entities/stock_transfer_record.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../../../core/helpers/map_launcher_helper.dart';
import '../../../pipeline_chat/presentation/providers/pipeline_chat_provider.dart';
import '../../../pipeline_chat/presentation/widgets/conversation_list_modal.dart';


class RiderStockSummary {
  final String riderId;
  final String riderName;
  final String riderCode;
  final String? phone;
  final String? vehiclePlate;
  final String? vehicleType;
  final int totalCustodyUnits;
  final int totalDeliveredUnits;
  final int totalReturnedUnits;
  final List<RiderStockAllocation> allocations;
  final bool isExternalPda;

  RiderStockSummary({
    required this.riderId,
    required this.riderName,
    required this.riderCode,
    this.phone,
    this.vehiclePlate,
    this.vehicleType,
    required this.totalCustodyUnits,
    required this.totalDeliveredUnits,
    required this.totalReturnedUnits,
    required this.allocations,
    this.isExternalPda = false,
  });
}

class DCStockOperationsPage extends ConsumerStatefulWidget {
  const DCStockOperationsPage({super.key});

  @override
  ConsumerState<DCStockOperationsPage> createState() => _DCStockOperationsPageState();
}

class _DCStockOperationsPageState extends ConsumerState<DCStockOperationsPage> {
  int _activeTab = 0; // 0: Stock Desk & KPIs, 1: Rider Balancing & Sales, 2: Order Chat, 3: Spoilage & Returns, 4: Profile
  int _tab0Segment = 0; // 0: Products Velocity & KPIs, 1: Inbound, 2: Field Riders, 3: Requests
  int _balancingSegment = 0; // 0: Daily Sold & Reconciliation, 1: In-Field Transfers, 2: Laid-off Couriers Retrieval
  int _returnsSegment = 0; // 0: Pending Rider Returns, 1: Damaged Quarantine
  String _requestFilter = 'all'; // 'all', 'pending', 'fulfilled'
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _productSearchController = TextEditingController();
  String _productAlertFilter = 'all'; // 'all', 'critical', 'warning', 'healthy'
  String _inboundChannelFilter = 'all'; // 'all', 'merchant', 'dc', 'rider'
  String? _selectedDistributionProductId;
  String _distributionKpiFilter = 'all'; // 'all', 'stocked', 'unstocked'
  int _riderSafetyBufferThreshold = 5;
  int _dcFacilityMinThreshold = 50;
  Map<String, int> _productThresholds = {};
  Map<String, int> _riderProductThresholds = {};

  @override
  void initState() {
    super.initState();
    _loadThresholdPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStockData();
    });
  }

  Future<void> _loadThresholdPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dcMin = prefs.getInt('dc_facility_min_threshold') ?? 50;
      final rBuf = prefs.getInt('dc_rider_safety_threshold') ?? 5;
      final pThreshJson = prefs.getString('dc_product_thresholds');
      final rThreshJson = prefs.getString('dc_rider_product_thresholds');

      Map<String, int> pMap = {};
      if (pThreshJson != null) {
        final decoded = jsonDecode(pThreshJson) as Map<String, dynamic>;
        pMap = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
      }

      Map<String, int> rMap = {};
      if (rThreshJson != null) {
        final decoded = jsonDecode(rThreshJson) as Map<String, dynamic>;
        rMap = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
      }

      if (mounted) {
        setState(() {
          _dcFacilityMinThreshold = dcMin;
          _riderSafetyBufferThreshold = rBuf;
          _productThresholds = pMap;
          _riderProductThresholds = rMap;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveThresholdPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('dc_facility_min_threshold', _dcFacilityMinThreshold);
      await prefs.setInt('dc_rider_safety_threshold', _riderSafetyBufferThreshold);
      await prefs.setString('dc_product_thresholds', jsonEncode(_productThresholds));
      await prefs.setString('dc_rider_product_thresholds', jsonEncode(_riderProductThresholds));
    } catch (_) {}
  }

  void _loadStockData() {
    bool isTest = false;
    try {
      if (!kIsWeb && (Platform.environment.containsKey('FLUTTER_TEST') ||
          Platform.environment.containsKey('TEST_PLATFORM'))) {
        isTest = true;
      }
      if (WidgetsBinding.instance.runtimeType.toString().toLowerCase().contains('test')) {
        isTest = true;
      }
    } catch (_) {}
    if (isTest) return;

    final activeHubId = ref.read(dcConsoleProvider).activeHubId;
    ref.read(stockProvider.notifier).fetchStockItems(null, activeHubId);
    ref.read(stockProvider.notifier).fetchStockTransfers(dcId: activeHubId);
    ref.read(stockProvider.notifier).fetchStockRequests(activeHubId);
    ref.read(dcConsoleProvider.notifier).loadDriversFromDatabase();
    ref.read(dcConsoleProvider.notifier).loadDistributionCentersFromDatabase();
    ref.read(ordersProvider.notifier).loadOrders();
    ref.read(pipelineChatProvider.notifier).loadScopedConversations(silent: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  List<RiderStockSummary> _buildRiderSummaries(
    List<RiderStockAllocation> allocations,
    List<DCFleetDriver> drivers,
  ) {
    // Strictly filter out platform agents (ADICHA, Victor Ogbenyi, AG-*, NX-ABJ-01 corporate entity)
    final filteredDrivers = drivers.where((d) => !d.isPlatformAgent).toList();

    final filteredAllocations = allocations.where((a) =>
        !a.riderCode.toUpperCase().startsWith('AG-') &&
        a.riderCode.toUpperCase() != 'NX-ABJ-01' &&
        !a.riderName.toLowerCase().contains('internal fleet') &&
        !a.riderName.toLowerCase().contains('adicha') &&
        !a.riderName.toLowerCase().contains('victor ogbenyi')).toList();

    final Map<String, List<RiderStockAllocation>> allocByRider = {};
    for (final a in filteredAllocations) {
      allocByRider.putIfAbsent(a.riderId, () => []).add(a);
    }

    final Map<String, DCFleetDriver> driverMap = {for (var d in filteredDrivers) d.id: d};
    final List<RiderStockSummary> summaries = [];
    final Set<String> processedRiderIds = {};

    for (final entry in allocByRider.entries) {
      final rId = entry.key;
      final rAllocs = entry.value;
      final driver = driverMap[rId];
      final name = driver?.name.isNotEmpty == true
          ? driver!.name
          : (rAllocs.isNotEmpty ? rAllocs.first.riderName : 'Delivery Agent');
      final code = driver?.driverCode.isNotEmpty == true
          ? driver!.driverCode
          : (rAllocs.isNotEmpty ? rAllocs.first.riderCode : 'PDA');
      final phone = driver?.phone;
      final plate = driver?.vehiclePlate;
      final vType = driver?.vehicleType;

      final totalCustody = rAllocs.fold(0, (sum, a) => sum + a.inCustodyUnits);
      final totalDelivered = rAllocs.fold(0, (sum, a) => sum + a.deliveredUnits);
      final totalReturned = rAllocs.fold(0, (sum, a) => sum + a.returnedUnits);

      final isExt = (driver != null && driver.isExternalPda) || code.toUpperCase().startsWith('EXT-');

      summaries.add(RiderStockSummary(
        riderId: rId,
        riderName: name,
        riderCode: code,
        phone: phone,
        vehiclePlate: plate,
        vehicleType: vType,
        totalCustodyUnits: totalCustody,
        totalDeliveredUnits: totalDelivered,
        totalReturnedUnits: totalReturned,
        allocations: rAllocs,
        isExternalPda: isExt,
      ));
      processedRiderIds.add(rId);
    }

    // Include other drivers attached to this DC who don't have stock yet
    for (final driver in filteredDrivers) {
      if (!processedRiderIds.contains(driver.id)) {
        summaries.add(RiderStockSummary(
          riderId: driver.id,
          riderName: driver.name,
          riderCode: driver.driverCode,
          phone: driver.phone,
          vehiclePlate: driver.vehiclePlate,
          vehicleType: driver.vehicleType,
          totalCustodyUnits: 0,
          totalDeliveredUnits: 0,
          totalReturnedUnits: 0,
          allocations: [],
        ));
      }
    }

    // Sort: Riders with custody units first, then alphabetically
    summaries.sort((a, b) {
      if (b.totalCustodyUnits != a.totalCustodyUnits) {
        return b.totalCustodyUnits.compareTo(a.totalCustodyUnits);
      }
      return a.riderName.compareTo(b.riderName);
    });

    return summaries;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stockState = ref.watch(stockProvider);
    final dcState = ref.watch(dcConsoleProvider);

    final warehouseItems = stockState.stockItems;
    final riderAllocations = stockState.riderAllocations;
    final drivers = dcState.drivers;
    final dcs = dcState.distributionCenters;
    final inboundRequests = stockState.inboundRequests;
    final transfers = stockState.stockTransfers;

    // Filter incoming inbounds destined for this DC
    final pendingInbounds = transfers.where((t) {
      final isDestMatch = t.destinationDcId == null || t.destinationDcId == dcState.activeHubId;
      final isPending = t.status != 'completed' && t.status != 'rejected';
      return (t.isClientSupply || t.isInterDc || t.isRiderReturn ||
              t.transferType == 'client_supply' || t.transferType == 'dc_to_dc' || t.transferType == 'rider_return') &&
          isDestMatch && isPending;
    }).toList();

    // Compute Product Velocities & Restock Alerts
    final List<DCStockVelocity> productVelocities = warehouseItems.map((item) {
      final inField = riderAllocations
          .where((a) => a.productId == item.id)
          .fold(0, (sum, a) => sum + a.inCustodyUnits);
      return DCStockVelocity.calculate(
        product: item,
        dcShelfStock: item.availableCount,
        inFieldCustody: inField,
        deliveredUnits: item.deliveredCount,
      );
    }).toList();

    final int totalWarehouseUnits = warehouseItems.fold(0, (sum, i) => sum + i.availableCount);
    final int totalFieldCustodyUnits = riderAllocations.fold(0, (sum, a) => sum + a.inCustodyUnits);
    final int totalDamagedUnits = warehouseItems.fold(0, (sum, i) => sum + i.complaintCount);
    final int pendingRequestsCount = inboundRequests.where((r) => r.isPending).length;
    final interDcTransfers = transfers.where((t) => t.isInterDc).toList();
    final double totalDailyBurnRate = productVelocities.fold(0.0, (sum, v) => sum + v.dailyBurnRate);
    final criticalItems = productVelocities.where((v) => v.severity == RestockAlertSeverity.critical).toList();

    final currentDc = dcState.distributionCenters.where((d) => d.id == dcState.activeHubId).firstOrNull ??
        dcState.distributionCenters.firstOrNull;
    final unreadChatCount = ref.watch(pipelineChatProvider.select((s) => s.getUnreadCountForRole('dc_manager')));
    final user = ref.watch(authProvider).user;

    final int lowWarehouseCount = warehouseItems.where((i) {
      final thresh = _productThresholds[i.id] ?? _dcFacilityMinThreshold;
      return i.availableCount <= thresh;
    }).length;
    final int lowCourierCount = riderAllocations.where((a) {
      if (a.inCustodyUnits <= 0) return false;
      final key = '${a.riderId}_${a.productId}';
      final thresh = _riderProductThresholds[key] ?? _riderSafetyBufferThreshold;
      return a.inCustodyUnits <= thresh;
    }).length;
    final int totalStockNotificationsCount = lowWarehouseCount + lowCourierCount + pendingInbounds.length + (totalDamagedUnits > 0 ? 1 : 0);
    final String keeperName = user?.fullName.split(' ').first.isNotEmpty == true ? user!.fullName.split(' ').first : 'Stock Keeper';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Welcome, $keeperName',
              style: GoogleFonts.inter(fontSize: 16.5, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${dcState.activeHubName} • Stock Keeper Console',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF0284C7), fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Stock Notifications & Alerts',
            icon: Badge(
              isLabelVisible: totalStockNotificationsCount > 0,
              label: Text('$totalStockNotificationsCount'),
              backgroundColor: const Color(0xFFDC2626),
              child: const Icon(Icons.notifications_outlined, size: 22),
            ),
            onPressed: () => _openStockNotificationsModal(context, isDark),
          ),
          IconButton(
            tooltip: 'Stock Keeper Settings',
            icon: const Icon(Icons.settings_outlined, size: 21),
            onPressed: () => _openStockSettingsModal(context, isDark),
          ),
          IconButton(
            tooltip: 'Refresh Inventory',
            icon: const Icon(Icons.refresh_rounded, size: 21),
            onPressed: _loadStockData,
          ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 14,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _activeTab,
            onTap: (index) => setState(() => _activeTab = index),
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            selectedItemColor: const Color(0xFF0284C7),
            unselectedItemColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 10.5),
            items: [
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: (pendingRequestsCount + pendingInbounds.length) > 0,
                  label: Text('${pendingRequestsCount + pendingInbounds.length}'),
                  backgroundColor: const Color(0xFFF37021),
                  child: const Icon(Icons.inventory_2_outlined),
                ),
                label: 'Stock & KPIs',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.swap_horiz_rounded),
                label: 'Balancing',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: unreadChatCount > 0,
                  label: Text('$unreadChatCount'),
                  backgroundColor: const Color(0xFFEF4444),
                  child: const Icon(Icons.forum_rounded),
                ),
                label: 'Order Chat',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: totalDamagedUnits > 0,
                  label: Text('$totalDamagedUnits'),
                  backgroundColor: const Color(0xFFDC2626),
                  child: const Icon(Icons.assignment_return_outlined),
                ),
                label: 'Returns',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              if (_activeTab == 0)
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildKpiGrid(
                          warehouseUnits: totalWarehouseUnits,
                          custodyUnits: totalFieldCustodyUnits,
                          dailyBurnRate: totalDailyBurnRate,
                          isDark: isDark,
                        ),

                        // Product Quantities & Stock Distribution KPIs immediately after KPI summary
                        _buildAssignStockView(
                          warehouseItems,
                          riderAllocations,
                          drivers,
                          inboundRequests,
                          pendingInbounds,
                          productVelocities,
                          isDark,
                        ),

                        // Dynamic Restock Alert Banner (when critical products exist)
                        if (criticalItems.isNotEmpty && _tab0Segment != 1)
                          _buildCriticalRestockAlertBanner(
                            criticalItems: criticalItems,
                            onViewCritical: () {
                              setState(() {
                                _tab0Segment = 0;
                                _productAlertFilter = 'critical';
                              });
                            },
                            isDark: isDark,
                          ),

                        // Quick Action Grid with Icons & Tooltips
                        _buildQuickActionGrid(
                          context: context,
                          warehouseItems: warehouseItems,
                          riderAllocations: riderAllocations,
                          drivers: drivers,
                          dcs: dcs,
                          activeHubId: dcState.activeHubId,
                          pendingInbounds: pendingInbounds,
                          criticalItemsCount: criticalItems.length,
                          damagedCount: totalDamagedUnits,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                if (_activeTab != 4 && _activeTab != 2)
                  _buildKpiGrid(
                    warehouseUnits: totalWarehouseUnits,
                    custodyUnits: totalFieldCustodyUnits,
                    dailyBurnRate: totalDailyBurnRate,
                    isDark: isDark,
                  ),

                // Main Operational Tab Body
                Expanded(
                  child: _buildActiveTabBody(
                    warehouseItems,
                    riderAllocations,
                    drivers,
                    inboundRequests,
                    interDcTransfers,
                    dcs,
                    currentDc,
                    dcState.activeHubId,
                    pendingInbounds,
                    productVelocities,
                    isDark,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // ORGANIC AMBIENT STATS HEADER (ICON-BASED, BORDERLESS)
  // ==========================================
  Widget _buildKpiGrid({
    required int warehouseUnits,
    required int custodyUnits,
    required double dailyBurnRate,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.7) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Station Shelf
          Expanded(
            child: _buildOrganicMetricItem(
              icon: Icons.warehouse_rounded,
              iconColor: const Color(0xFF2563EB),
              value: '$warehouseUnits',
              label: 'Station',
              isDark: isDark,
            ),
          ),
          Container(width: 1, height: 28, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
          // In Field
          Expanded(
            child: _buildOrganicMetricItem(
              icon: Icons.two_wheeler_rounded,
              iconColor: const Color(0xFF16A34A),
              value: '$custodyUnits',
              label: 'In Field',
              isDark: isDark,
            ),
          ),
          Container(width: 1, height: 28, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
          // Sales Velocity
          Expanded(
            child: _buildOrganicMetricItem(
              icon: Icons.bolt_rounded,
              iconColor: const Color(0xFF0284C7),
              value: dailyBurnRate.toStringAsFixed(1),
              label: 'Burn/d',
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganicMetricItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required bool isDark,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // QUICK ACTION GRID WITH ICONS & TOOLTIPS
  // ==========================================
  Widget _buildQuickActionGrid({
    required BuildContext context,
    required List<StockItemEntity> warehouseItems,
    required List<RiderStockAllocation> riderAllocations,
    required List<DCFleetDriver> drivers,
    required List<DistributionCenter> dcs,
    required String activeHubId,
    required List<StockTransferRecord> pendingInbounds,
    required int criticalItemsCount,
    required int damagedCount,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildQuickActionTile(
                  icon: Icons.move_to_inbox_rounded,
                  color: const Color(0xFF059669),
                  label: 'Inbound',
                  tooltip: 'Receive and verify inbound stock consignments from merchants and transfers',
                  badgeCount: pendingInbounds.length,
                  onTap: () => DCUnifiedInboundModal.show(context: context),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildQuickActionTile(
                  icon: Icons.person_add_alt_1_rounded,
                  color: const Color(0xFF0284C7),
                  label: 'Allocate',
                  tooltip: 'Assign and release warehouse inventory to dispatch couriers',
                  onTap: () => _openAssignStockModal(context, warehouseItems, drivers, isDark),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildQuickActionTile(
                  icon: Icons.campaign_rounded,
                  color: const Color(0xFFD97706),
                  label: 'Requisition',
                  tooltip: 'Request restock from merchants (~2 weeks lead time required)',
                  badgeCount: criticalItemsCount,
                  onTap: () {
                    final low = warehouseItems.where((i) {
                      final thresh = _productThresholds[i.id] ?? _dcFacilityMinThreshold;
                      return i.availableCount <= thresh;
                    }).firstOrNull ?? warehouseItems.firstOrNull;
                    if (low != null) {
                      final dcName = ref.read(dcConsoleProvider).activeHubName;
                      DCNotifyMerchantRestockModal.show(context, item: low, dcName: dcName);
                    }
                  },
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildQuickActionTile(
                  icon: Icons.point_of_sale_rounded,
                  color: const Color(0xFF10B981),
                  label: 'Daily Sales',
                  tooltip: 'Record daily units sold by couriers to reconcile field custody',
                  onTap: () => _openDailySalesQuickAction(context, drivers, riderAllocations, isDark),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionTile(
                  icon: Icons.swap_horiz_rounded,
                  color: const Color(0xFF7C3AED),
                  label: 'Rider Balance',
                  tooltip: 'Transfer stock directly between riders in the field to balance coverage',
                  onTap: () => _openRiderToRiderModal(context, riderAllocations, drivers, isDark),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildQuickActionTile(
                  icon: Icons.assignment_return_rounded,
                  color: const Color(0xFFDC2626),
                  label: 'Spoilage',
                  tooltip: 'Accept returned damaged/spoiled items from couriers and issue replacements',
                  badgeCount: damagedCount,
                  onTap: () => _openSpoilageModal(context, warehouseItems, drivers, isDark),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildQuickActionTile(
                  icon: Icons.local_shipping_rounded,
                  color: const Color(0xFF2563EB),
                  label: 'DC Transfer',
                  tooltip: 'Dispatch inter-station stock transfers to other distribution centers',
                  onTap: () => _openInterDcTransferModal(context, warehouseItems, dcs, activeHubId, isDark),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildQuickActionTile(
                  icon: Icons.person_off_rounded,
                  color: const Color(0xFFE11D48),
                  label: 'Retrieve Stock',
                  tooltip: 'Retrieve all warehouse inventory from laid-off or exiting couriers',
                  onTap: () => _openRetrieveRiderStockQuickAction(context, drivers, riderAllocations, warehouseItems, isDark),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required Color color,
    required String label,
    required String tooltip,
    required VoidCallback onTap,
    required bool isDark,
    int badgeCount = 0,
  }) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 250),
      showDuration: const Duration(seconds: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      textStyle: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.7) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Badge(
                  isLabelVisible: badgeCount > 0,
                  label: Text('$badgeCount', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                  backgroundColor: const Color(0xFFDC2626),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 17, color: color),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openDailySalesQuickAction(
    BuildContext context,
    List<DCFleetDriver> drivers,
    List<RiderStockAllocation> allocations,
    bool isDark,
  ) {
    final driversWithCustody = drivers.where((d) => allocations.any((a) => a.riderId == d.id && a.inCustodyUnits > 0)).toList();
    final driverList = driversWithCustody.isNotEmpty ? driversWithCustody : drivers;

    if (driverList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active couriers found.')));
      return;
    }

    if (driverList.length == 1) {
      _openAuditSalesDialog(context, driverList.first, allocations, isDark);
      return;
    }

    final uniqueDrivers = <DCFleetDriver>[];
    final seenDriverIds = <String>{};
    for (final d in driverList) {
      if (seenDriverIds.add(d.id)) {
        uniqueDrivers.add(d);
      }
    }
    if (uniqueDrivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active couriers found.')));
      return;
    }

    DCFleetDriver selectedDriver = uniqueDrivers.first;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.point_of_sale_rounded, color: Color(0xFF10B981), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text('Select Courier', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Choose courier to record end-of-day product sales:', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                const SizedBox(height: 10),
                Builder(builder: (context) {
                  final effDriverId = uniqueDrivers.any((d) => d.id == selectedDriver.id)
                      ? selectedDriver.id
                      : (uniqueDrivers.isNotEmpty ? uniqueDrivers.first.id : null);
                  return NovaSearchableSelectField<String>(
                    label: 'Courier / Driver',
                    placeholder: 'Tap to select courier...',
                    value: effDriverId,
                    prefixIcon: Icons.two_wheeler_rounded,
                    brandColor: const Color(0xFF10B981),
                    pickerTitle: 'Select Courier',
                    pickerSubtitle: 'Choose courier to record end-of-day sales',
                    options: uniqueDrivers.map((d) {
                      final custody = allocations
                          .where((a) => a.riderId == d.id || a.riderCode == d.driverCode)
                          .fold(0, (sum, a) => sum + a.inCustodyUnits);
                      final isExt = d.isExternalPda || d.driverCode.startsWith('EXT-');
                      return NovaPickerOption<String>(
                        value: d.id,
                        title: d.name,
                        subtitle: 'Code: ${d.driverCode} • ${d.vehicleType ?? "Motorcycle"}',
                        badgeText: isExt ? 'EXT-PDA' : 'FLEET',
                        badgeColor: isExt ? const Color(0xFFF59E0B) : const Color(0xFF0284C7),
                        icon: Icons.two_wheeler_rounded,
                        trailingText: '$custody held',
                        trailingTextColor: const Color(0xFF10B981),
                        searchTerms: [d.name, d.driverCode, d.phone ?? ''],
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedDriver = uniqueDrivers.firstWhere((d) => d.id == val, orElse: () => uniqueDrivers.first);
                        });
                      }
                    },
                  );
                }),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openAuditSalesDialog(context, selectedDriver, allocations, isDark);
                    },
                    child: const Text('Continue to Daily Sales', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openRetrieveRiderStockQuickAction(
    BuildContext context,
    List<DCFleetDriver> drivers,
    List<RiderStockAllocation> allocations,
    List<StockItemEntity> warehouseItems,
    bool isDark,
  ) {
    final laidOffOrWithCustody = drivers.where((d) => allocations.any((a) => a.riderId == d.id && a.inCustodyUnits > 0)).toList();
    final candidateDrivers = laidOffOrWithCustody.isNotEmpty ? laidOffOrWithCustody : drivers;

    final uniqueCandidates = <DCFleetDriver>[];
    final seenCandidateIds = <String>{};
    for (final d in candidateDrivers) {
      if (seenCandidateIds.add(d.id)) {
        uniqueCandidates.add(d);
      }
    }

    if (uniqueCandidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No couriers with active custody found to retrieve.')));
      return;
    }

    if (uniqueCandidates.length == 1) {
      _openRetrieveRiderStockModal(context, uniqueCandidates.first, allocations, warehouseItems, isDark);
      return;
    }

    DCFleetDriver selected = uniqueCandidates.first;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.person_off_rounded, color: Color(0xFFE11D48), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text('Retrieve Courier Stock', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Select courier to retrieve and return all inventory to DC storage:', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                const SizedBox(height: 10),
                Builder(builder: (context) {
                  final effSelectedId = uniqueCandidates.any((d) => d.id == selected.id)
                      ? selected.id
                      : (uniqueCandidates.isNotEmpty ? uniqueCandidates.first.id : null);
                  return DropdownButtonFormField<String>(
                    value: effSelectedId,
                    isExpanded: true,
                    items: uniqueCandidates.map((d) {
                      final custody = allocations.where((a) => a.riderId == d.id).fold(0, (sum, a) => sum + a.inCustodyUnits);
                      return DropdownMenuItem(value: d.id, child: Text('${d.name} ($custody units in custody)', style: const TextStyle(fontSize: 12)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selected = uniqueCandidates.firstWhere((d) => d.id == val, orElse: () => uniqueCandidates.first);
                        });
                      }
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  );
                }),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openRetrieveRiderStockModal(context, selected, allocations, warehouseItems, isDark);
                    },
                    child: const Text('Proceed to Stock Retrieval', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openStockNotificationsModal(BuildContext context, bool isDark) {
    DCStockNotificationsModal.show(
      context: context,
      dcMinThreshold: _dcFacilityMinThreshold,
      riderSafetyThreshold: _riderSafetyBufferThreshold,
      productThresholds: _productThresholds,
      riderProductThresholds: _riderProductThresholds,
      onOpenAllocate: () {
        final stockState = ref.read(stockProvider);
        final dcState = ref.read(dcConsoleProvider);
        _openAssignStockModal(context, stockState.stockItems, dcState.drivers, isDark);
      },
      onOpenRiderBalance: () {
        final stockState = ref.read(stockProvider);
        final dcState = ref.read(dcConsoleProvider);
        _openRiderToRiderModal(context, stockState.riderAllocations, dcState.drivers, isDark);
      },
      onOpenRetrieveStock: () {
        final stockState = ref.read(stockProvider);
        final dcState = ref.read(dcConsoleProvider);
        _openRetrieveRiderStockQuickAction(context, dcState.drivers, stockState.riderAllocations, stockState.stockItems, isDark);
      },
    );
  }

  void _openStockSettingsModal(BuildContext context, bool isDark) {
    DCStockSettingsModal.show(
      context: context,
      initialDcMinThreshold: _dcFacilityMinThreshold,
      initialRiderSafetyThreshold: _riderSafetyBufferThreshold,
      initialProductThresholds: _productThresholds,
      initialRiderProductThresholds: _riderProductThresholds,
      onSaveSettings: ({
        required int dcMinThreshold,
        required int riderSafetyThreshold,
        required Map<String, int> productThresholds,
        required Map<String, int> riderProductThresholds,
      }) {
        setState(() {
          _dcFacilityMinThreshold = dcMinThreshold;
          _riderSafetyBufferThreshold = riderSafetyThreshold;
          _productThresholds = Map<String, int>.from(productThresholds);
          _riderProductThresholds = Map<String, int>.from(riderProductThresholds);
        });
        _saveThresholdPreferences();
      },
    );
  }

  // ==========================================
  // ORGANIC 1-LINE ALERT CAPSULE
  // ==========================================
  Widget _buildCriticalRestockAlertBanner({
    required List<DCStockVelocity> criticalItems,
    required VoidCallback onViewCritical,
    required bool isDark,
  }) {
    if (criticalItems.isEmpty) return const SizedBox.shrink();

    final count = criticalItems.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withValues(alpha: isDark ? 0.2 : 0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count items low or out of stock',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFDC2626),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: onViewCritical,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Review',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFFDC2626)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ACTIVE TAB ROUTER
  // ==========================================
  Widget _buildActiveTabBody(
    List<StockItemEntity> warehouseItems,
    List<RiderStockAllocation> riderAllocations,
    List<DCFleetDriver> drivers,
    List<InboundStockRequest> inboundRequests,
    List<dynamic> interDcTransfers,
    List<DistributionCenter> dcs,
    DistributionCenter? currentDc,
    String activeHubId,
    List<StockTransferRecord> pendingInbounds,
    List<DCStockVelocity> productVelocities,
    bool isDark,
  ) {
    switch (_activeTab) {
      case 0:
        return _buildAssignStockView(
          warehouseItems,
          riderAllocations,
          drivers,
          inboundRequests,
          pendingInbounds,
          productVelocities,
          isDark,
        );
      case 1:
        return _buildRiderBalancingTabView(
          warehouseItems,
          riderAllocations,
          drivers,
          isDark,
        );
      case 2:
        return const ConversationListModal(isEmbeddedTab: true);
      case 3:
        return _buildSpoilageReturnsView(warehouseItems, riderAllocations, drivers, isDark);
      case 4:
        return DCStaffProfileSettingsTab(
          roleBadgeTitle: 'DC Stock Controller',
          departmentLabel: 'INVENTORY & WAREHOUSE CONTROL',
          accentColor: const Color(0xFF0284C7),
          roleIcon: Icons.inventory_2_outlined,
          station: currentDc,
        );
      default:
        return _buildAssignStockView(
          warehouseItems,
          riderAllocations,
          drivers,
          inboundRequests,
          pendingInbounds,
          productVelocities,
          isDark,
        );
    }
  }

  // ==========================================
  // TAB 0: ORGANIC CAPSULE SELECTOR & VIEWS
  // ==========================================
  Widget _buildAssignStockView(
    List<StockItemEntity> warehouseItems,
    List<RiderStockAllocation> allocations,
    List<DCFleetDriver> drivers,
    List<InboundStockRequest> inboundRequests,
    List<StockTransferRecord> pendingInbounds,
    List<DCStockVelocity> productVelocities,
    bool isDark,
  ) {
    final riderSummaries = _buildRiderSummaries(allocations, drivers);
    final pendingCount = inboundRequests.where((r) => r.isPending).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Organic Rounded Capsule Selector
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(26),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildOrganicSegmentPill(
                  index: 0,
                  label: 'Products',
                  badgeCount: warehouseItems.length,
                  icon: Icons.inventory_2_outlined,
                  activeColor: const Color(0xFF0284C7),
                  isDark: isDark,
                ),
                const SizedBox(width: 4),
                _buildOrganicSegmentPill(
                  index: 1,
                  label: 'Inbound',
                  badgeCount: pendingInbounds.length,
                  icon: Icons.download_rounded,
                  activeColor: const Color(0xFF00522A),
                  highlightBadge: pendingInbounds.isNotEmpty,
                  isDark: isDark,
                ),
                const SizedBox(width: 4),
                _buildOrganicSegmentPill(
                  index: 2,
                  label: 'Field Riders',
                  badgeCount: riderSummaries.length,
                  icon: Icons.two_wheeler_rounded,
                  activeColor: const Color(0xFF16A34A),
                  isDark: isDark,
                ),
                const SizedBox(width: 4),
                _buildOrganicSegmentPill(
                  index: 3,
                  label: 'Requests',
                  badgeCount: pendingCount,
                  icon: Icons.move_to_inbox_rounded,
                  activeColor: const Color(0xFFF37021),
                  highlightBadge: pendingCount > 0,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),

        // Sub-Tab Content
        () {
          switch (_tab0Segment) {
            case 0:
              return _buildProductsVelocitySegment(
                productVelocities,
                warehouseItems,
                allocations,
                drivers,
                isDark,
              );
            case 1:
              return _buildInboundQueueSegment(
                pendingInbounds,
                warehouseItems,
                isDark,
              );
            case 2:
              return _buildInFieldCustodySegment(
                riderSummaries,
                warehouseItems,
                allocations,
                drivers,
                isDark,
              );
            case 3:
            default:
              return _buildRestockQueueSegment(
                inboundRequests,
                warehouseItems,
                allocations,
                drivers,
                isDark,
              );
          }
        }(),
      ],
    );
  }

  // ==========================================
  // SUB-TAB 0.0: ORGANIC PRODUCTS & VELOCITY
  // ==========================================
  Widget _buildProductsVelocitySegment(
    List<DCStockVelocity> velocities,
    List<StockItemEntity> warehouseItems,
    List<RiderStockAllocation> allocations,
    List<DCFleetDriver> drivers,
    bool isDark,
  ) {
    final query = _productSearchController.text.trim().toLowerCase();
    final filtered = velocities.where((v) {
      if (query.isNotEmpty) {
        final matchName = v.product.name.toLowerCase().contains(query);
        final matchSku = v.product.sku.toLowerCase().contains(query);
        final matchCat = v.product.category.toLowerCase().contains(query);
        if (!matchName && !matchSku && !matchCat) return false;
      }
      if (_productAlertFilter == 'critical') {
        return v.severity == RestockAlertSeverity.critical;
      } else if (_productAlertFilter == 'warning') {
        return v.severity == RestockAlertSeverity.warning;
      } else if (_productAlertFilter == 'healthy') {
        return v.severity == RestockAlertSeverity.healthy || v.severity == RestockAlertSeverity.wellStocked;
      }
      return true;
    }).toList();

    final criticalCount = velocities.where((v) => v.severity == RestockAlertSeverity.critical).length;
    final healthyCount = velocities.where((v) => v.severity == RestockAlertSeverity.healthy || v.severity == RestockAlertSeverity.wellStocked).length;

    final dcName = ref.read(dcConsoleProvider).activeHubName;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stock Distribution KPIs & Coverage Analytics (Req 7)
        _buildStockDistributionKpiCard(
          warehouseItems: warehouseItems,
          allocations: allocations,
          drivers: drivers,
          isDark: isDark,
        ),

        // Minimal Organic Search & Filter Strip
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
          child: Column(
            children: [
              TextField(
                controller: _productSearchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  hintStyle: GoogleFonts.inter(fontSize: 12.0, color: const Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 17, color: Color(0xFF94A3B8)),
                  suffixIcon: _productSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 15),
                          onPressed: () => setState(() => _productSearchController.clear()),
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCustomFilterChip(
                      label: 'All (${velocities.length})',
                      isSelected: _productAlertFilter == 'all',
                      color: const Color(0xFF0284C7),
                      onTap: () => setState(() => _productAlertFilter = 'all'),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildCustomFilterChip(
                      label: 'Critical Alert ($criticalCount)',
                      isSelected: _productAlertFilter == 'critical',
                      color: const Color(0xFFDC2626),
                      onTap: () => setState(() => _productAlertFilter = 'critical'),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildCustomFilterChip(
                      label: 'In Stock ($healthyCount)',
                      isSelected: _productAlertFilter == 'healthy',
                      color: const Color(0xFF16A34A),
                      onTap: () => setState(() => _productAlertFilter = 'healthy'),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Products List
        filtered.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 40, color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                      const SizedBox(height: 8),
                      Text(
                        'No Products Found',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final v = filtered[index];
                  return _buildProductVelocityCard(
                    velocity: v,
                    warehouseItems: warehouseItems,
                    allocations: allocations,
                    drivers: drivers,
                    dcName: dcName,
                    isDark: isDark,
                  );
                },
              ),
      ],
    );
  }

  // ==========================================
  // ORGANIC PRODUCT CARD (ICON-BASED, BORDERLESS)
  // ==========================================
  Widget _buildProductVelocityCard({
    required DCStockVelocity velocity,
    required List<StockItemEntity> warehouseItems,
    required List<RiderStockAllocation> allocations,
    required List<DCFleetDriver> drivers,
    required String dcName,
    required bool isDark,
  }) {
    final v = velocity;
    final alertColor = v.severityColor;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.8) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Header (Icon Avatar + Title + Status Pill)
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: alertColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  v.dcShelfStock == 0 ? Icons.remove_shopping_cart_outlined : Icons.inventory_2_outlined,
                  size: 18,
                  color: alertColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.product.name,
                      style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      v.product.category.isNotEmpty ? v.product.category : 'General',
                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: alertColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  v.dcShelfStock == 0
                      ? 'Out of Stock'
                      : (v.daysRemaining <= 3 ? 'Critical' : (v.daysRemaining <= 7 ? '${v.daysRemaining.toStringAsFixed(0)}d left' : 'In Stock')),
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: alertColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Icon-Based Stat Line (NO SUB-BOXES!)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warehouse_rounded, size: 14, color: alertColor),
                    const SizedBox(width: 4),
                    Text(
                      '${v.dcShelfStock}',
                      style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w900, color: alertColor),
                    ),
                    const SizedBox(width: 3),
                    const Text('Station', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                  ],
                ),
                const Text('•', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.two_wheeler_rounded, size: 14, color: Color(0xFF16A34A)),
                    const SizedBox(width: 4),
                    Text(
                      '${v.inFieldCustody}',
                      style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF16A34A)),
                    ),
                    const SizedBox(width: 3),
                    const Text('Field', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                  ],
                ),
                const Text('•', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF0284C7)),
                    const SizedBox(width: 4),
                    Text(
                      v.dailyBurnRate.toStringAsFixed(1),
                      style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF0284C7)),
                    ),
                    const SizedBox(width: 3),
                    const Text('/d', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Row 3: Organic Capsule Action Buttons
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00522A).withValues(alpha: 0.12),
                    foregroundColor: const Color(0xFF00522A),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 13),
                  label: const Text('Allocate', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => _openAssignStockModal(
                    context,
                    warehouseItems,
                    drivers,
                    isDark,
                    preselectedProductId: v.product.id,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    foregroundColor: const Color(0xFFD97706),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.campaign_outlined, size: 13),
                  label: const Text('Restock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => DCNotifyMerchantRestockModal.show(
                    context,
                    item: v.product,
                    dcName: dcName,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Product Details',
                icon: const Icon(Icons.more_horiz_rounded, size: 17),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
                  padding: const EdgeInsets.all(6),
                ),
                onPressed: () => DCProductDetailModal.show(
                  context,
                  item: v.product,
                  drivers: drivers,
                  allocations: allocations,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SUB-TAB 0.1: ORGANIC INBOUND RECEPTION QUEUE
  // ==========================================
  Widget _buildInboundQueueSegment(
    List<StockTransferRecord> pendingInbounds,
    List<StockItemEntity> warehouseItems,
    bool isDark,
  ) {
    final filtered = pendingInbounds.where((t) {
      if (_inboundChannelFilter == 'merchant') {
        return t.isClientSupply || t.transferType == 'client_supply';
      } else if (_inboundChannelFilter == 'dc') {
        return t.isInterDc || t.transferType == 'dc_to_dc';
      } else if (_inboundChannelFilter == 'rider') {
        return t.isRiderReturn || t.transferType == 'rider_return';
      }
      return true;
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Filter Channel Tabs + Direct Supply Action
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Inbound Reception (${pendingInbounds.length})',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF00522A),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    icon: const Icon(Icons.add_box_rounded, size: 14),
                    label: const Text('Open Intake', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => DCUnifiedInboundModal.show(context: context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCustomFilterChip(
                      label: 'All (${pendingInbounds.length})',
                      isSelected: _inboundChannelFilter == 'all',
                      color: const Color(0xFF0284C7),
                      onTap: () => setState(() => _inboundChannelFilter = 'all'),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildCustomFilterChip(
                      label: 'Merchants',
                      isSelected: _inboundChannelFilter == 'merchant',
                      color: const Color(0xFF2563EB),
                      onTap: () => setState(() => _inboundChannelFilter = 'merchant'),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildCustomFilterChip(
                      label: 'DCs',
                      isSelected: _inboundChannelFilter == 'dc',
                      color: const Color(0xFF9333EA),
                      onTap: () => setState(() => _inboundChannelFilter = 'dc'),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildCustomFilterChip(
                      label: 'Riders',
                      isSelected: _inboundChannelFilter == 'rider',
                      color: const Color(0xFF0D9488),
                      onTap: () => setState(() => _inboundChannelFilter = 'rider'),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Inbounds List
        filtered.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mark_email_read_outlined, size: 40, color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                      const SizedBox(height: 8),
                      Text(
                        'No Pending Inbounds',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final inbound = filtered[index];
                  return _buildInboundTransferCard(inbound, warehouseItems, isDark);
                },
              ),
      ],
    );
  }

  // ==========================================
  // ORGANIC INBOUND CARD
  // ==========================================
  Widget _buildInboundTransferCard(
    StockTransferRecord inbound,
    List<StockItemEntity> warehouseItems,
    bool isDark,
  ) {
    final isMerchant = inbound.isClientSupply || inbound.transferType == 'client_supply';
    final isDc = inbound.isInterDc || inbound.transferType == 'dc_to_dc';

    Color channelColor;
    String channelLabel;
    IconData channelIcon;
    int tabIndex = 0;

    if (isMerchant) {
      channelColor = const Color(0xFF2563EB);
      channelLabel = 'MERCHANT';
      channelIcon = Icons.storefront_rounded;
      tabIndex = 0;
    } else if (isDc) {
      channelColor = const Color(0xFF9333EA);
      channelLabel = 'DC TRANSFER';
      channelIcon = Icons.swap_horiz_rounded;
      tabIndex = 1;
    } else {
      channelColor = const Color(0xFF0D9488);
      channelLabel = 'RIDER OFFLOAD';
      channelIcon = Icons.two_wheeler_rounded;
      tabIndex = 2;
    }

    final totalUnits = inbound.items.fold(0, (sum, i) => sum + i.quantity);
    final productSummary = inbound.items.isNotEmpty
        ? inbound.items.map((i) => '${i.quantity}x ${i.productName}').join(', ')
        : 'Inbound Inventory Shipment';

    final senderInfo = inbound.clientName ??
        inbound.sourceWarehouseName ??
        inbound.senderName ??
        (isMerchant ? 'Merchant' : (isDc ? 'Origin DC' : 'Rider'));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.8) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Channel Tag + Waybill + Units
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(channelIcon, size: 14, color: channelColor),
                  const SizedBox(width: 4),
                  Text(
                    channelLabel,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: channelColor),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    inbound.transferNumber.isNotEmpty ? inbound.transferNumber : '#${inbound.id.substring(0, 8)}',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: channelColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalUnits Units',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w900, color: channelColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Text(
            productSummary,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'From: $senderInfo',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: channelColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
              label: const Text('Verify & Receive', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              onPressed: () => DCUnifiedInboundModal.show(context: context, initialTab: tabIndex),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomFilterChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected ? color : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildOrganicSegmentPill({
    required int index,
    required String label,
    int? badgeCount,
    required IconData icon,
    required Color activeColor,
    bool highlightBadge = false,
    required bool isDark,
    int? currentIndex,
    VoidCallback? onTap,
  }) {
    final isSelected = (currentIndex ?? _tab0Segment) == index;
    return GestureDetector(
      onTap: onTap ?? () => setState(() => _tab0Segment = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? const Color(0xFF1E293B) : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13.5,
              color: isSelected ? activeColor : const Color(0xFF64748B),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? (isDark ? Colors.white : const Color(0xFF0F172A)) : const Color(0xFF64748B),
              ),
            ),
            if (badgeCount != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withValues(alpha: 0.15)
                      : (highlightBadge ? const Color(0xFFF37021).withValues(alpha: 0.15) : Colors.transparent),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeCount.toString(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? activeColor
                        : (highlightBadge ? const Color(0xFFF37021) : const Color(0xFF64748B)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SUB-TAB 0.A: IN-FIELD RIDER CUSTODY
  // ==========================================
  Widget _buildInFieldCustodySegment(
    List<RiderStockSummary> riderSummaries,
    List<StockItemEntity> warehouseItems,
    List<RiderStockAllocation> allocations,
    List<DCFleetDriver> drivers,
    bool isDark,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Action Bar (Overflow-Proof with Expanded)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Riders in Delivery Field (${riderSummaries.length})',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Tap any rider to view items & allocate stock',
                      style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _openAssignStockModal(context, warehouseItems, drivers, isDark),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00522A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add_rounded, size: 15),
                label: const Text('Allocate Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),

        // List of Grouped Riders
        riderSummaries.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.motorcycle_rounded, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text('No Active Delivery Agents', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      const Text('Riders attached to this DC will appear here.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: riderSummaries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final rider = riderSummaries[index];
                    final bool hasStock = rider.totalCustodyUnits > 0;

                    return InkWell(
                      onTap: () => _showRiderStockDetailsModal(
                        context,
                        rider,
                        warehouseItems,
                        drivers,
                        isDark,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasStock
                                ? const Color(0xFF16A34A).withValues(alpha: isDark ? 0.4 : 0.3)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            width: hasStock ? 1.2 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                UserAvatarWidget(fullName: rider.riderName, radius: 19),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              rider.riderName,
                                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF37021).withValues(alpha: 0.14),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              rider.riderCode,
                                              style: GoogleFonts.jetBrainsMono(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFFF37021),
                                              ),
                                            ),
                                          ),
                                          if (rider.isExternalPda) ...[
                                            const SizedBox(width: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFD97706).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                                              ),
                                              child: const Text('EXT-PDA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${rider.vehicleType ?? "Vehicle"} • ${rider.vehiclePlate ?? "Plate Pending"}',
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
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: hasStock
                                            ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                                            : Colors.grey.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        hasStock ? '${rider.totalCustodyUnits} Units' : 'No Stock',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w900,
                                          color: hasStock ? const Color(0xFF16A34A) : Colors.grey,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${rider.allocations.length} Products',
                                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // Product breakdown chips preview if rider has stock
                            if (rider.allocations.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: rider.allocations.map((a) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Text(
                                      '${a.productName}: ${a.inCustodyUnits}',
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],

                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Delivered today: ${rider.totalDeliveredUnits}',
                                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      'View stock details',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF0284C7),
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFF0284C7)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      ],
    );
  }

  // ==========================================
  // SUB-TAB 0.B: RESTOCK REQUESTS QUEUE
  // ==========================================
  Widget _buildRestockQueueSegment(
    List<InboundStockRequest> inboundRequests,
    List<StockItemEntity> warehouseItems,
    List<RiderStockAllocation> allocations,
    List<DCFleetDriver> drivers,
    bool isDark,
  ) {
    List<InboundStockRequest> filtered = inboundRequests;
    if (_requestFilter == 'pending') {
      filtered = inboundRequests.where((r) => r.isPending).toList();
    } else if (_requestFilter == 'fulfilled') {
      filtered = inboundRequests.where((r) => r.isFulfilled).toList();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Filter Pills
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              _buildFilterChip('All (${inboundRequests.length})', 'all', isDark),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Pending (${inboundRequests.where((r) => r.isPending).length})',
                'pending',
                isDark,
                accentColor: const Color(0xFFF37021),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Fulfilled (${inboundRequests.where((r) => r.isFulfilled).length})',
                'fulfilled',
                isDark,
                accentColor: const Color(0xFF16A34A),
              ),
            ],
          ),
        ),

        // Requests List
        filtered.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text('No Restock Requests', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(
                        _requestFilter == 'pending'
                            ? 'All restock requests have been fulfilled.'
                            : 'When delivery agents request stock from PDA, requests appear here.',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final req = filtered[index];
                    final isPending = req.isPending;

                    return Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPending
                              ? const Color(0xFFF37021).withValues(alpha: isDark ? 0.4 : 0.3)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Request number & Status Pill
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      req.requestId,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0284C7),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (req.requestDate != null)
                                    Text(
                                      '${req.requestDate!.day}/${req.requestDate!.month} ${req.requestDate!.hour.toString().padLeft(2, '0')}:${req.requestDate!.minute.toString().padLeft(2, '0')}',
                                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                    ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: isPending
                                      ? const Color(0xFFF37021).withValues(alpha: 0.12)
                                      : const Color(0xFF16A34A).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isPending ? 'AWAITING FULFILLMENT' : 'FULFILLED',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: isPending ? const Color(0xFFF37021) : const Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Rider Profile
                          Row(
                            children: [
                              UserAvatarWidget(fullName: req.riderName, radius: 15),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      req.riderName,
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Agent Code: ${req.riderCode}',
                                      style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Requested Items List
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Requested Items (${req.totalUnitsRequested} Total Units):',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                if (req.items.isNotEmpty)
                                  ...req.items.map((it) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '• ${it.productName}',
                                                style: GoogleFonts.inter(fontSize: 11.5),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              '${it.requestedQuantity} Units',
                                              style: GoogleFonts.jetBrainsMono(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF00522A),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ))
                                else
                                  ...req.requestedQuantities.entries.map((e) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '• ${e.key}',
                                                style: GoogleFonts.inter(fontSize: 11.5),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              '${e.value} Units',
                                              style: GoogleFonts.jetBrainsMono(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF00522A),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                              ],
                            ),
                          ),

                          if (req.notes != null && req.notes!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Notes: ${req.notes}',
                              style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: const Color(0xFF64748B)),
                            ),
                          ],

                          if (isPending) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 38,
                              child: ElevatedButton.icon(
                                onPressed: () => _openFulfillRequestModal(
                                  context,
                                  req,
                                  warehouseItems,
                                  allocations,
                                  drivers,
                                  isDark,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00522A),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                label: const Text('Fulfill Request (DC or Rider Stock)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark, {Color accentColor = const Color(0xFF0284C7)}) {
    final isSelected = _requestFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _requestFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.15) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? accentColor : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? accentColor : (isDark ? Colors.white70 : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // MODAL: RIDER STOCK INVENTORY DETAILS
  // ==========================================
  void _showRiderStockDetailsModal(
    BuildContext context,
    RiderStockSummary rider,
    List<StockItemEntity> warehouseItems,
    List<DCFleetDriver> drivers,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with rider info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          UserAvatarWidget(fullName: rider.riderName, radius: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        rider.riderName,
                                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF37021).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        rider.riderCode,
                                        style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFFF37021)),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${rider.vehicleType ?? "Motorcycle"} • ${rider.vehiclePlate ?? "Plate N/A"}${rider.phone != null ? " • ${rider.phone}" : ""}',
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Metrics summary strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${rider.totalCustodyUnits}',
                              style: GoogleFonts.jetBrainsMono(fontSize: 17, fontWeight: FontWeight.w900, color: const Color(0xFF16A34A)),
                            ),
                            Text('In Custody', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      Container(height: 24, width: 1, color: Colors.grey.withValues(alpha: 0.3)),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${rider.totalDeliveredUnits}',
                              style: GoogleFonts.jetBrainsMono(fontSize: 17, fontWeight: FontWeight.w900, color: const Color(0xFF2563EB)),
                            ),
                            Text('Delivered', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      Container(height: 24, width: 1, color: Colors.grey.withValues(alpha: 0.3)),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${rider.totalReturnedUnits}',
                              style: GoogleFonts.jetBrainsMono(fontSize: 17, fontWeight: FontWeight.w900, color: const Color(0xFFDC2626)),
                            ),
                            Text('Returned', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Product items in rider custody
                Text(
                  'Inventory in Possession (${rider.allocations.length} Products):',
                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                if (rider.allocations.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 28, color: Colors.grey),
                        const SizedBox(height: 6),
                        Text(
                          'No stock currently allocated to this delivery agent.',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ...rider.allocations.map((a) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.productName,
                                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'SKU: ${a.sku}${a.clientName.isNotEmpty ? " • ${a.clientName}" : ""}',
                                  style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
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
                                '${a.inCustodyUnits} In Custody',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF16A34A),
                                ),
                              ),
                              Text(
                                'Delivered: ${a.deliveredUnits}',
                                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00522A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openAssignStockModal(
                            context,
                            warehouseItems,
                            drivers,
                            isDark,
                            preselectedDriverId: rider.riderId,
                          );
                        },
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Assign Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                      ),
                    ),
                    if (rider.totalCustodyUnits > 0) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB),
                            side: const BorderSide(color: Color(0xFF2563EB)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openRiderToRiderModal(
                              context,
                              rider.allocations,
                              drivers,
                              isDark,
                              preselectedSourceRiderId: rider.riderId,
                            );
                          },
                          icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                          label: const Text('Balance Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // MODAL: FULFILL RESTOCK REQUEST (DC OR RIDER)
  // ==========================================
  void _openFulfillRequestModal(
    BuildContext context,
    InboundStockRequest request,
    List<StockItemEntity> warehouseItems,
    List<RiderStockAllocation> allocations,
    List<DCFleetDriver> drivers,
    bool isDark,
  ) {
    int fulfillMode = 0; // 0: From DC Warehouse, 1: From Another Rider
    String? selectedDonorRiderId;
    final notesController = TextEditingController(text: 'Fulfillment of ${request.requestId}');

    // Find riders with stock in custody (excluding the requesting rider)
    final otherAllocations = allocations.where((a) => a.riderId != request.riderId && a.inCustodyUnits > 0).toList();
    if (otherAllocations.isNotEmpty) {
      selectedDonorRiderId = otherAllocations.first.riderId;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fulfill Restock Request',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${request.requestId} • ${request.riderName} (${request.riderCode})',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF0284C7), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Fulfillment Source Toggle
                  Text('Fulfillment Source:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => fulfillMode = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: fulfillMode == 0
                                  ? const Color(0xFF00522A)
                                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.warehouse_rounded, size: 14, color: fulfillMode == 0 ? Colors.white : const Color(0xFF64748B)),
                                const SizedBox(width: 5),
                                Text(
                                  'DC Warehouse',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: fulfillMode == 0 ? Colors.white : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => fulfillMode = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: fulfillMode == 1
                                  ? const Color(0xFF2563EB)
                                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.motorcycle_rounded, size: 14, color: fulfillMode == 1 ? Colors.white : const Color(0xFF64748B)),
                                const SizedBox(width: 5),
                                Text(
                                  'Another Rider Stock',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: fulfillMode == 1 ? Colors.white : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Source Details & Validation
                  if (fulfillMode == 0) ...[
                    // DC Warehouse details
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DC Warehouse Stock Availability:', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          if (request.items.isNotEmpty)
                            ...request.items.map((it) {
                              final wh = warehouseItems.where((w) => w.id == it.productId || w.name.toLowerCase().contains(it.productName.toLowerCase())).firstOrNull;
                              final available = wh?.availableCount ?? 0;
                              final isShortage = available < it.requestedQuantity;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${it.productName} (Req: ${it.requestedQuantity})',
                                        style: GoogleFonts.inter(fontSize: 11.5),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '$available in DC',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: isShortage ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            })
                          else
                            ...request.requestedQuantities.entries.map((e) {
                              final wh = warehouseItems.where((w) => w.name.toLowerCase().contains(e.key.toLowerCase())).firstOrNull;
                              final available = wh?.availableCount ?? 0;
                              final isShortage = available < e.value;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text('${e.key} (Req: ${e.value})', style: GoogleFonts.inter(fontSize: 11.5), overflow: TextOverflow.ellipsis),
                                    ),
                                    Text(
                                      '$available in DC',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: isShortage ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Donor Rider details
                    Text('Select Providing Rider (Stock will be deducted from this rider):', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    if (otherAllocations.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'No other riders currently hold stock in custody for in-field transfer.',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFDC2626)),
                        ),
                      )
                    else ...[
                      Builder(builder: (context) {
                        final uniqueDonors = <RiderStockAllocation>[];
                        final seenRiderIds = <String>{};
                        for (final a in otherAllocations) {
                          if (seenRiderIds.add(a.riderId)) {
                            uniqueDonors.add(a);
                          }
                        }
                        final effectiveDonorId = (selectedDonorRiderId != null && uniqueDonors.any((d) => d.riderId == selectedDonorRiderId))
                            ? selectedDonorRiderId
                            : (uniqueDonors.isNotEmpty ? uniqueDonors.first.riderId : null);

                        return DropdownButtonFormField<String>(
                          value: effectiveDonorId,
                          isExpanded: true,
                          items: uniqueDonors.map((a) {
                            return DropdownMenuItem(
                              value: a.riderId,
                              child: Text(
                                '${a.riderName} (${a.productName} • ${a.inCustodyUnits} in hand)',
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }).toList(),
                          onChanged: (v) => setModalState(() => selectedDonorRiderId = v),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        );
                      }),
                    ],
                  ],

                  const SizedBox(height: 12),
                  Text('Fulfillment Notes (Optional)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: fulfillMode == 0 ? const Color(0xFF00522A) : const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);

                        final dcId = ref.read(dcConsoleProvider).activeHubId;
                        final donor = otherAllocations.where((a) => a.riderId == selectedDonorRiderId).firstOrNull;

                        // Build items list
                        final List<Map<String, dynamic>> fulfillItems = [];
                        if (request.items.isNotEmpty) {
                          for (final it in request.items) {
                            fulfillItems.add({
                              'productId': it.productId,
                              'productName': it.productName,
                              'quantity': it.requestedQuantity,
                            });
                          }
                        } else {
                          for (final e in request.requestedQuantities.entries) {
                            final matchWh = warehouseItems.where((w) => w.name.toLowerCase().contains(e.key.toLowerCase())).firstOrNull;
                            fulfillItems.add({
                              'productId': matchWh?.id ?? e.key,
                              'productName': e.key,
                              'quantity': e.value,
                            });
                          }
                        }

                        final res = await ref.read(stockProvider.notifier).fulfillStockRequest(
                          requestId: request.id.isNotEmpty ? request.id : request.requestId,
                          fulfillmentMode: fulfillMode == 0 ? 'dc_warehouse' : 'rider_transfer',
                          destinationRiderId: request.riderId ?? '',
                          destinationRiderName: request.riderName,
                          destinationRiderCode: request.riderCode,
                          sourceRiderId: fulfillMode == 1 ? donor?.riderId : null,
                          sourceRiderName: fulfillMode == 1 ? donor?.riderName : null,
                          items: fulfillItems,
                          dcId: dcId,
                          notes: notesController.text.trim(),
                        );

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: res['success'] == true ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              content: Text(res['message']?.toString() ?? 'Fulfillment executed.'),
                            ),
                          );
                          _loadStockData();
                        }
                      },
                      child: Text(
                        fulfillMode == 0 ? 'Confirm DC Fulfillment' : 'Confirm In-Field Transfer',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: RIDER-TO-RIDER STOCK BALANCING
  // ==========================================
  Widget _buildRiderToRiderView(
    List<RiderStockAllocation> allocations,
    List<DCFleetDriver> drivers,
    bool isDark,
  ) {
    return Column(
      children: [
        // Top Action Bar (Overflow-Proof with Expanded)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'In-Field Stock Balancing (Rider to Rider)',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Re-distribute inventory between riders in neighboring sectors.',
                      style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _openRiderToRiderModal(context, allocations, drivers, isDark),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 15),
                label: const Text('Balance Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),

        // Information / Overview
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Rider-to-Rider stock balancing enables dynamic inventory reallocation in the field when one rider has excess items while another is running low on orders in proximity.',
                        style: GoogleFonts.inter(fontSize: 11.5, color: isDark ? Colors.white70 : const Color(0xFF1E3A8A), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Available Rider Custody Units for Balancing:',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...allocations.where((a) => a.inCustodyUnits > 0).map((a) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: const Icon(Icons.motorcycle_rounded, color: Color(0xFF2563EB)),
                    title: Text('${a.riderName} (${a.riderCode})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('Product: ${a.productName}', style: const TextStyle(fontSize: 11.5)),
                    trailing: Text(
                      '${a.inCustodyUnits} units available',
                      style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: const Color(0xFF2563EB), fontSize: 12.5),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 3: DAMAGED / SPOILAGE RETURNS
  // ==========================================
  Widget _buildSpoilageReturnsView(
    List<StockItemEntity> warehouseItems,
    List<RiderStockAllocation> allocations,
    List<DCFleetDriver> drivers,
    bool isDark,
  ) {
    final damagedItems = warehouseItems.where((i) => i.complaintCount > 0 || i.damagedCount > 0).toList();
    final stockState = ref.watch(stockProvider);
    final pendingReturns = stockState.stockTransfers.where((t) =>
        (t.transferType == 'rider_return' || t.isRiderReturn) &&
        (t.status == 'pending_dc_acceptance' || t.status == 'in_transit' || t.status == 'dispatched')).toList();

    return Column(
      children: [
        // Segment Bar: Pending Returns vs Damaged SKUs
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _returnsSegment = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _returnsSegment == 0
                              ? const Color(0xFF0284C7)
                              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Incoming Returns',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: _returnsSegment == 0 ? Colors.white : const Color(0xFF64748B),
                              ),
                            ),
                            if (pendingReturns.isNotEmpty) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${pendingReturns.length}',
                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _returnsSegment = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _returnsSegment == 1
                              ? const Color(0xFFDC2626)
                              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Quarantine & Damaged (${damagedItems.length})',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: _returnsSegment == 1 ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_returnsSegment == 1)
                ElevatedButton.icon(
                  onPressed: () => _openSpoilageModal(context, warehouseItems, drivers, isDark),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.report_problem_rounded, size: 14),
                  label: const Text('Log Damaged', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                ),
            ],
          ),
        ),
        if (_returnsSegment == 0)
          Expanded(
            child: pendingReturns.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.assignment_turned_in_outlined, size: 48, color: Color(0xFF16A34A)),
                        const SizedBox(height: 12),
                        Text('No Pending Rider Returns', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        const Text('When riders drop off unsold stock at the hub, transfers will appear here for verification.', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: pendingReturns.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final ret = pendingReturns[index];
                      final itemsSummary = ret.items.map((i) => '${i.quantity}x ${i.productName}').join(', ');

                      return Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3), width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        ret.transferNumber,
                                        style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7)),
                                      ),
                                    ),
                                    Text(
                                      'From: ${ret.senderName ?? "Rider"}',
                                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('AWAITING VERIFICATION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Returned Items: $itemsSummary',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            if (ret.notes != null && ret.notes!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                'Rider Note: ${ret.notes}',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                            ],
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Row(
                                        children: [
                                          const Icon(Icons.verified_rounded, color: Color(0xFF16A34A)),
                                          const SizedBox(width: 8),
                                          const Text('Confirm Stock Return Receipt'),
                                        ],
                                      ),
                                      content: Text(
                                        'Have you physically inspected and verified $itemsSummary returned by ${ret.senderName ?? "Rider"} back into the DC warehouse shelf?\n\nProceed?',
                                        style: GoogleFonts.inter(fontSize: 13),
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Yes, Confirm & Restock'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed == true) {
                                    final totalQty = ret.items.fold<int>(0, (sum, i) => sum + i.quantity);
                                    final user = ref.read(authProvider).user;
                                    await ref.read(stockProvider.notifier).receiveRiderReturn(
                                      returnId: ret.id,
                                      dcId: user?.distributionCenterId ?? '22222222-2222-4222-8222-222222222222',
                                      receiverId: user?.id ?? '',
                                      verifiedQuantity: totalQty,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          backgroundColor: Color(0xFF16A34A),
                                          content: Text('Return verified! Stock restocked to warehouse inventory.'),
                                        ),
                                      );
                                      _loadStockData();
                                    }
                                  }
                                },
                                icon: const Icon(Icons.check_circle_rounded, size: 16),
                                label: const Text('Verify & Accept Stock to Warehouse', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          )
        else

        Expanded(
          child: damagedItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified_user_outlined, size: 48, color: Color(0xFF16A34A)),
                      const SizedBox(height: 12),
                      Text('No Damaged Items in Quarantine', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      const Text('Any returned damaged goods logged by riders will appear here.', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: damagedItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = damagedItems[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text('SKU: ${item.sku}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          Text(
                            '${item.complaintCount} Quarantined',
                            style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ==========================================
  // MODAL 1: ASSIGN STOCK TO RIDER
  // ==========================================
  void _openAssignStockModal(
    BuildContext context,
    List<StockItemEntity> warehouseItems,
    List<DCFleetDriver> drivers,
    bool isDark, {
    String? preselectedDriverId,
    String? preselectedProductId,
  }) {
    final uniqueWarehouseItems = <StockItemEntity>[];
    final seenProductIds = <String>{};
    for (final it in warehouseItems) {
      if (it.availableCount > 0 && seenProductIds.add(it.id)) {
        uniqueWarehouseItems.add(it);
      }
    }
    // Fallback if all items are 0 count: include warehouse items so admin can see items
    if (uniqueWarehouseItems.isEmpty) {
      for (final it in warehouseItems) {
        if (seenProductIds.add(it.id)) {
          uniqueWarehouseItems.add(it);
        }
      }
    }
    final uniqueDrivers = <DCFleetDriver>[];
    final seenDriverIds = <String>{};
    for (final d in drivers.where((d) => !d.isPlatformAgent)) {
      if (seenDriverIds.add(d.id)) {
        uniqueDrivers.add(d);
      }
    }

    if (uniqueWarehouseItems.isEmpty || uniqueDrivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot allocate: Ensure warehouse has items and drivers exist.')),
      );
      return;
    }

    String selectedProductId = preselectedProductId != null && uniqueWarehouseItems.any((i) => i.id == preselectedProductId)
        ? preselectedProductId
        : uniqueWarehouseItems.first.id;
    String selectedDriverId = preselectedDriverId != null && uniqueDrivers.any((d) => d.id == preselectedDriverId)
        ? preselectedDriverId
        : uniqueDrivers.first.id;
    final qtyController = TextEditingController(text: '1');
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Allocate Stock to Rider', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // NovaXpress Logistics Stock Badge
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00522A).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF00522A).withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user_outlined, size: 16, color: Color(0xFF00522A)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'NovaXpress Logistics Stock: Physical custody is allocated strictly from DC hub shelf inventory.',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF00522A)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Select Rider
                  Builder(builder: (context) {
                    final effDriverId = uniqueDrivers.any((d) => d.id == selectedDriverId)
                        ? selectedDriverId
                        : (uniqueDrivers.isNotEmpty ? uniqueDrivers.first.id : null);
                    return NovaSearchableSelectField<String>(
                      label: 'Select Delivery Personnel / Rider *',
                      placeholder: 'Tap to select delivery personnel...',
                      value: effDriverId,
                      prefixIcon: Icons.two_wheeler_rounded,
                      brandColor: const Color(0xFF00522A),
                      pickerTitle: 'Select Delivery Personnel',
                      pickerSubtitle: 'Choose in-house fleet rider, external PDA, or distributor',
                      options: uniqueDrivers.map((d) {
                        final isExt = d.isExternalPda;
                        final isDist = d.isDistributor;
                        return NovaPickerOption<String>(
                          value: d.id,
                          title: d.name,
                          subtitle: '${d.driverCode} • ${d.phone}',
                          badgeText: isExt ? 'EXT-PDA' : (isDist ? 'DISTRIBUTOR' : 'IN-HOUSE'),
                          badgeColor: isExt ? const Color(0xFFD97706) : (isDist ? const Color(0xFF7C3AED) : const Color(0xFF059669)),
                          icon: isExt ? Icons.local_shipping_rounded : (isDist ? Icons.storefront_rounded : Icons.two_wheeler_rounded),
                          searchTerms: [d.name, d.driverCode, d.phone],
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedDriverId = v);
                      },
                    );
                  }),
                  const SizedBox(height: 14),

                  // Select Product
                  Builder(builder: (context) {
                    final effProdId = uniqueWarehouseItems.any((i) => i.id == selectedProductId)
                        ? selectedProductId
                        : (uniqueWarehouseItems.isNotEmpty ? uniqueWarehouseItems.first.id : null);
                    final curProd = uniqueWarehouseItems.firstWhere((i) => i.id == effProdId, orElse: () => uniqueWarehouseItems.first);
                    final isOutOfStock = curProd.availableCount <= 0;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        NovaSearchableSelectField<String>(
                          label: 'Select Product SKU *',
                          placeholder: 'Tap to select product...',
                          value: effProdId,
                          prefixIcon: Icons.inventory_2_outlined,
                          brandColor: const Color(0xFF00522A),
                          pickerTitle: 'Select Product SKU',
                          pickerSubtitle: 'Choose from station warehouse stock',
                          options: uniqueWarehouseItems.map((i) {
                            final hasStock = i.availableCount > 0;
                            return NovaPickerOption<String>(
                              value: i.id,
                              title: i.name,
                              subtitle: 'SKU: ${i.sku} • Available on Shelf: ${i.availableCount} units',
                              badgeText: hasStock ? '${i.availableCount} AVAIL' : 'NO REPLENISHMENT',
                              badgeColor: hasStock ? const Color(0xFF059669) : const Color(0xFFDC2626),
                              icon: Icons.inventory_2_rounded,
                              trailingText: '${i.availableCount} pcs',
                              trailingTextColor: hasStock ? const Color(0xFF059669) : const Color(0xFFDC2626),
                              searchTerms: [i.name, i.sku, i.ownerName],
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setModalState(() => selectedProductId = v);
                          },
                        ),
                        if (isOutOfStock) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Cannot allocate: 0 units available on station shelf. NovaXpress Master Stock Keeper (Damilare) has not allocated stock of this product to NovaXpress Logistics yet. Request replenishment from Damilare.',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFDC2626)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  }),
                  const SizedBox(height: 14),

                  // Quantity
                  Text('Quantity to Allocate', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Notes
                  Text('Allocation Notes (Optional)', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      hintText: 'e.g., Morning dispatch batch',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00522A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                      onPressed: () async {
                        final selProd = uniqueWarehouseItems.firstWhere((i) => i.id == selectedProductId, orElse: () => uniqueWarehouseItems.first);
                        if (selProd.availableCount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Color(0xFFDC2626),
                              content: Text('Cannot allocate: NovaXpress Logistics has 0 available units from NovaXpress platform. Request stock allocation from Damilare first.'),
                            ),
                          );
                          return;
                        }
                        final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                        if (qty <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid quantity.')));
                          return;
                        }
                        if (qty > selProd.availableCount) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFFDC2626),
                              content: Text('Cannot allocate: Requested $qty units exceeds available station shelf stock (${selProd.availableCount} units).'),
                            ),
                          );
                          return;
                        }
                        final driver = uniqueDrivers.where((d) => d.id == selectedDriverId).firstOrNull ?? uniqueDrivers.first;
                        Navigator.pop(ctx);

                        final res = await ref.read(stockProvider.notifier).assignStockToRider(
                          productIdOrSku: selectedProductId,
                          riderId: driver.id,
                          riderName: driver.name,
                          riderCode: driver.driverCode,
                          quantity: qty,
                          distributionCenterId: ref.read(dcConsoleProvider).activeHubId,
                        );

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: res['success'] == true ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              content: Text(res['message']?.toString() ?? 'Stock assigned.'),
                            ),
                          );
                          _loadStockData();
                        }
                      },
                      child: const Text('Confirm Allocation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // MODAL 2: RIDER-TO-RIDER BALANCING
  // ==========================================
  void _openRiderToRiderModal(
    BuildContext context,
    List<RiderStockAllocation> allocations,
    List<DCFleetDriver> drivers,
    bool isDark, {
    String? preselectedSourceRiderId,
  }) {
    final availableAllocations = allocations.where((a) => a.inCustodyUnits > 0).toList();
    if (availableAllocations.isEmpty || drivers.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need at least 1 rider with stock in custody and 2 drivers to balance stock.')),
      );
      return;
    }

    final uniqueAllocations = <RiderStockAllocation>[];
    final seenAllocIds = <String>{};
    for (final a in availableAllocations) {
      if (seenAllocIds.add(a.id)) {
        uniqueAllocations.add(a);
      }
    }

    final uniqueDrivers = <DCFleetDriver>[];
    final seenDriverIds = <String>{};
    for (final d in drivers.where((d) => !d.isPlatformAgent)) {
      if (seenDriverIds.add(d.id)) {
        uniqueDrivers.add(d);
      }
    }

    if (uniqueAllocations.isEmpty || uniqueDrivers.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need at least 1 rider with active stock and another rider to receive.')),
      );
      return;
    }

    String selectedSourceAllocId = (preselectedSourceRiderId != null &&
            uniqueAllocations.any((a) => a.riderId == preselectedSourceRiderId))
        ? (uniqueAllocations.where((a) => a.riderId == preselectedSourceRiderId).firstOrNull ?? uniqueAllocations.first).id
        : uniqueAllocations.first.id;

    RiderStockAllocation selectedSourceAlloc = uniqueAllocations.firstWhere((a) => a.id == selectedSourceAllocId, orElse: () => uniqueAllocations.first);

    final initialAvailableDests = uniqueDrivers.where((d) => d.id != selectedSourceAlloc.riderId).toList();
    String selectedDestDriverId = initialAvailableDests.isNotEmpty ? initialAvailableDests.first.id : uniqueDrivers.first.id;
    final qtyController = TextEditingController(text: '1');
    final reasonController = TextEditingController(text: 'In-field stock rebalancing');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Balance Stock Between Riders', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Source Rider with Stock
                  Text('Source Rider (Transferring Stock Out)', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Builder(builder: (context) {
                    final effSourceId = uniqueAllocations.any((a) => a.id == selectedSourceAllocId)
                        ? selectedSourceAllocId
                        : (uniqueAllocations.isNotEmpty ? uniqueAllocations.first.id : null);
                    return DropdownButtonFormField<String>(
                      value: effSourceId,
                      isExpanded: true,
                      items: uniqueAllocations.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.riderName} (${a.productName} • ${a.inCustodyUnits} in hand)', style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setModalState(() {
                            selectedSourceAllocId = v;
                            selectedSourceAlloc = uniqueAllocations.firstWhere((a) => a.id == v, orElse: () => uniqueAllocations.first);
                            final availableDests = uniqueDrivers.where((d) => d.id != selectedSourceAlloc.riderId).toList();
                            if (availableDests.isNotEmpty && !availableDests.any((d) => d.id == selectedDestDriverId)) {
                              selectedDestDriverId = availableDests.first.id;
                            }
                          });
                        }
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    );
                  }),
                  const SizedBox(height: 14),

                  // Destination Rider
                  Text('Destination Rider (Receiving Stock)', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Builder(
                    builder: (context) {
                      final availableDests = uniqueDrivers.where((d) => d.id != selectedSourceAlloc.riderId).toList();
                      final effectiveDestId = availableDests.any((d) => d.id == selectedDestDriverId)
                          ? selectedDestDriverId
                          : (availableDests.isNotEmpty ? availableDests.first.id : null);

                      return DropdownButtonFormField<String>(
                        value: effectiveDestId,
                        isExpanded: true,
                        items: availableDests.map((d) => DropdownMenuItem(value: d.id, child: Text('${d.name} (${d.driverCode})', style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (v) {
                          if (v != null) setModalState(() => selectedDestDriverId = v);
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // Quantity
                  Text('Quantity to Transfer', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                      onPressed: () async {
                        final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                        if (qty <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid quantity.')));
                          return;
                        }
                        final destDriver = drivers.where((d) => d.id == selectedDestDriverId).firstOrNull ?? drivers.first;
                        Navigator.pop(ctx);

                        final res = await ref.read(stockProvider.notifier).transferStockBetweenRiders(
                          productIdOrSku: selectedSourceAlloc.productId,
                          sourceRiderId: selectedSourceAlloc.riderId,
                          sourceRiderName: selectedSourceAlloc.riderName,
                          destinationRiderId: destDriver.id,
                          destinationRiderName: destDriver.name,
                          destinationRiderCode: destDriver.driverCode,
                          quantity: qty,
                          distributionCenterId: ref.read(dcConsoleProvider).activeHubId,
                          notes: reasonController.text.trim(),
                        );

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: res['success'] == true ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              content: Text(res['message']?.toString() ?? 'Balance completed.'),
                            ),
                          );
                          _loadStockData();
                        }
                      },
                      child: const Text('Execute Rider Transfer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // MODAL 3: INTER-DC TRANSFERS
  // ==========================================
  void _openInterDcTransferModal(
    BuildContext context,
    List<StockItemEntity> warehouseItems,
    List<DistributionCenter> dcs,
    String activeHubId,
    bool isDark,
  ) {
    final uniqueWarehouseItems = <StockItemEntity>[];
    final seenProductIds = <String>{};
    for (final it in warehouseItems) {
      if (it.availableCount > 0 && seenProductIds.add(it.id)) {
        uniqueWarehouseItems.add(it);
      }
    }
    // Fallback if all items are 0 count: include warehouse items so admin can see items
    if (uniqueWarehouseItems.isEmpty) {
      for (final it in warehouseItems) {
        if (seenProductIds.add(it.id)) {
          uniqueWarehouseItems.add(it);
        }
      }
    }
    final uniqueDcs = <DistributionCenter>[];
    final seenDcIds = <String>{};
    for (final d in dcs) {
      if (d.id != activeHubId && seenDcIds.add(d.id)) {
        uniqueDcs.add(d);
      }
    }

    if (uniqueWarehouseItems.isEmpty || uniqueDcs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need available warehouse stock and at least 2 distribution centers.')),
      );
      return;
    }

    String selectedProductId = uniqueWarehouseItems.first.id;
    String selectedDestDcId = uniqueDcs.first.id;
    final qtyController = TextEditingController(text: '5');
    final waybillController = TextEditingController(text: 'WB-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Initiate Inter-DC Transfer', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Destination DC
                  Text('Destination Distribution Center', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Builder(builder: (context) {
                    final effDcId = uniqueDcs.any((d) => d.id == selectedDestDcId)
                        ? selectedDestDcId
                        : (uniqueDcs.isNotEmpty ? uniqueDcs.first.id : null);
                    return DropdownButtonFormField<String>(
                      value: effDcId,
                      isExpanded: true,
                      items: uniqueDcs.map((d) => DropdownMenuItem(value: d.id, child: Text('${d.name} (${d.city}, ${d.state})', style: const TextStyle(fontSize: 12.5)))).toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedDestDcId = v);
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    );
                  }),
                  const SizedBox(height: 14),

                  // Product
                  Text('Product to Transfer', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Builder(builder: (context) {
                    final effProdId = uniqueWarehouseItems.any((i) => i.id == selectedProductId)
                        ? selectedProductId
                        : (uniqueWarehouseItems.isNotEmpty ? uniqueWarehouseItems.first.id : null);
                    return DropdownButtonFormField<String>(
                      value: effProdId,
                      isExpanded: true,
                      items: uniqueWarehouseItems.map((i) => DropdownMenuItem(value: i.id, child: Text('${i.name} (DC Stock: ${i.availableCount})', style: const TextStyle(fontSize: 12.5)))).toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedProductId = v);
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    );
                  }),
                  const SizedBox(height: 14),

                  // Quantity
                  Text('Quantity', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Waybill
                  Text('Waybill Number', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: waybillController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00522A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                      onPressed: () async {
                        final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                        if (qty <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid quantity.')));
                          return;
                        }
                        final destDc = dcs.where((d) => d.id == selectedDestDcId).firstOrNull ?? dcs.first;
                        final currentHub = dcs.where((d) => d.id == activeHubId).firstOrNull;
                        Navigator.pop(ctx);

                        final res = await ref.read(stockProvider.notifier).transferStockBetweenDCs(
                          productIdOrSku: selectedProductId,
                          sourceDcId: activeHubId,
                          sourceDcName: currentHub?.name ?? 'Hub',
                          destinationDcId: destDc.id,
                          destinationDcName: destDc.name,
                          quantity: qty,
                          notes: 'Inter-DC Transfer Waybill: ${waybillController.text.trim()}',
                        );

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: res['success'] == true ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              content: Text(res['message']?.toString() ?? 'Transfer initiated.'),
                            ),
                          );
                          _loadStockData();
                        }
                      },
                      child: const Text('Dispatch Inter-DC Transfer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // MODAL 4: DAMAGED / SPOILAGE RETURNS
  // ==========================================
  void _openSpoilageModal(
    BuildContext context,
    List<StockItemEntity> warehouseItems,
    List<DCFleetDriver> drivers,
    bool isDark,
  ) {
    final uniqueWarehouseItems = <StockItemEntity>[];
    final seenProductIds = <String>{};
    for (final it in warehouseItems) {
      if (it.availableCount > 0 && seenProductIds.add(it.id)) {
        uniqueWarehouseItems.add(it);
      }
    }
    // Fallback if all items are 0 count: include warehouse items so admin can see items
    if (uniqueWarehouseItems.isEmpty) {
      for (final it in warehouseItems) {
        if (seenProductIds.add(it.id)) {
          uniqueWarehouseItems.add(it);
        }
      }
    }
    final uniqueDrivers = <DCFleetDriver>[];
    final seenDriverIds = <String>{};
    for (final d in drivers.where((d) => !d.isPlatformAgent)) {
      if (seenDriverIds.add(d.id)) {
        uniqueDrivers.add(d);
      }
    }

    if (uniqueWarehouseItems.isEmpty || uniqueDrivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need products and drivers to log damage report.')),
      );
      return;
    }

    String selectedProductId = uniqueWarehouseItems.first.id;
    String selectedDriverId = uniqueDrivers.first.id;
    String selectedReason = 'Spoilage / Expired';
    final qtyController = TextEditingController(text: '1');
    final notesController = TextEditingController();

    final damageReasons = [
      'Spoilage / Expired',
      'Broken Packaging / Seal',
      'Liquid Leakage / Defective Bottle',
      'Transit Impact Damage',
      'Customer Rejected Defective Item',
    ];
    bool issueImmediateReplacement = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Log Damaged / Spoilage Return', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Returning Rider
                  Text('Rider Returning Damaged Stock', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Builder(builder: (context) {
                    final effDriverId = uniqueDrivers.any((d) => d.id == selectedDriverId)
                        ? selectedDriverId
                        : (uniqueDrivers.isNotEmpty ? uniqueDrivers.first.id : null);
                    return DropdownButtonFormField<String>(
                      value: effDriverId,
                      isExpanded: true,
                      items: uniqueDrivers.map((d) {
                        final isExt = d.isExternalPda;
                        return DropdownMenuItem(
                          value: d.id,
                          child: Row(
                            children: [
                              if (isExt) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD97706).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                                  ),
                                  child: const Text('EXT-PDA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                                ),
                              ],
                              Expanded(
                                child: Text(
                                  '${d.name} (${d.driverCode})${isExt ? " • Offline 3PL" : ""}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isExt ? FontWeight.bold : FontWeight.normal,
                                    color: isExt ? const Color(0xFFD97706) : null,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedDriverId = v);
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    );
                  }),
                  const SizedBox(height: 14),

                  // Product
                  Text('Damaged Product SKU', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Builder(builder: (context) {
                    final effProdId = uniqueWarehouseItems.any((i) => i.id == selectedProductId)
                        ? selectedProductId
                        : (uniqueWarehouseItems.isNotEmpty ? uniqueWarehouseItems.first.id : null);
                    return DropdownButtonFormField<String>(
                      value: effProdId,
                      isExpanded: true,
                      items: uniqueWarehouseItems.map((i) => DropdownMenuItem(value: i.id, child: Text('${i.name} (${i.sku})', style: const TextStyle(fontSize: 12.5)))).toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedProductId = v);
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    );
                  }),
                  const SizedBox(height: 14),

                  // Damage Reason
                  Text('Condition / Damage Category', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Builder(builder: (context) {
                    final effReason = damageReasons.contains(selectedReason)
                        ? selectedReason
                        : (damageReasons.isNotEmpty ? damageReasons.first : null);
                    return DropdownButtonFormField<String>(
                      value: effReason,
                      isExpanded: true,
                      items: damageReasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12.5)))).toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedReason = v);
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    );
                  }),
                  const SizedBox(height: 14),

                  // Quantity
                  Text('Damaged Quantity', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Notes
                  Text('Inspection Notes', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      hintText: 'e.g., Cracked seal upon delivery attempt',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Immediate Replacement Toggle (Req 2)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: issueImmediateReplacement
                          ? const Color(0xFF16A34A).withValues(alpha: 0.1)
                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: issueImmediateReplacement
                            ? const Color(0xFF16A34A)
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.replay_circle_filled_rounded,
                          size: 22,
                          color: issueImmediateReplacement ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Issue Immediate Replacement Units',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: issueImmediateReplacement
                                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                      : const Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                'Instantly re-allocate good shelf units to courier from DC shelf.',
                                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: issueImmediateReplacement,
                          activeColor: const Color(0xFF16A34A),
                          onChanged: (val) => setModalState(() => issueImmediateReplacement = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                      onPressed: () async {
                        final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                        if (qty <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid quantity.')));
                          return;
                        }
                        final driver = drivers.where((d) => d.id == selectedDriverId).firstOrNull ?? drivers.first;
                        final returnNum = 'RET-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                        Navigator.pop(ctx);

                        final res = await ref.read(stockProvider.notifier).processStockReturn(
                          returnNumber: returnNum,
                          orderId: 'MANUAL-DAMAGE-RETURN',
                          deliveryAgentId: driver.id,
                          productId: selectedProductId,
                          quantity: qty,
                          reason: selectedReason,
                          destinationDcId: ref.read(dcConsoleProvider).activeHubId,
                          condition: 'damaged',
                          notes: notesController.text.trim(),
                        );

                        // If immediate replacement enabled, allocate good units from DC shelf
                        if (issueImmediateReplacement && res['success'] == true) {
                          final activeHubId = ref.read(dcConsoleProvider).activeHubId;
                          await ref.read(stockProvider.notifier).assignStockToRider(
                            productIdOrSku: selectedProductId,
                            riderId: driver.id,
                            riderName: driver.name,
                            riderCode: driver.driverCode,
                            quantity: qty,
                            distributionCenterId: activeHubId,
                          );
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: res['success'] == true ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              content: Text(
                                res['success'] == true
                                    ? (issueImmediateReplacement
                                        ? 'Damage logged ($qty units quarantined). $qty replacement units assigned to ${driver.name} from DC shelf!'
                                        : 'Damage report logged into quarantine ledger.')
                                    : (res['message']?.toString() ?? 'Damage report logged into quarantine ledger.'),
                              ),
                            ),
                          );
                          _loadStockData();
                        }
                      },
                      child: const Text('Log into Quarantine Ledger', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // REQ 7: STOCK DISTRIBUTION KPIS & COVERAGE
  // ==========================================
  Widget _buildStockDistributionKpiCard({
    required List<StockItemEntity> warehouseItems,
    required List<RiderStockAllocation> allocations,
    required List<DCFleetDriver> drivers,
    required bool isDark,
  }) {
    if (warehouseItems.isEmpty) return const SizedBox.shrink();

    // Deduplicate warehouse items by ID to strictly ensure exactly one DropdownMenuItem per product
    final uniqueWarehouseItems = <StockItemEntity>[];
    final seenProductIds = <String>{};
    for (final it in warehouseItems) {
      if (it.availableCount > 0 && seenProductIds.add(it.id)) {
        uniqueWarehouseItems.add(it);
      }
    }
    // Fallback if all items are 0 count: include warehouse items so admin can see items
    if (uniqueWarehouseItems.isEmpty) {
      for (final it in warehouseItems) {
        if (seenProductIds.add(it.id)) {
          uniqueWarehouseItems.add(it);
        }
      }
    }
    if (uniqueWarehouseItems.isEmpty) return const SizedBox.shrink();

    final currentProductId = (_selectedDistributionProductId != null &&
            uniqueWarehouseItems.any((i) => i.id == _selectedDistributionProductId))
        ? _selectedDistributionProductId!
        : uniqueWarehouseItems.first.id;

    final totalRiders = drivers.length;
    final List<DCFleetDriver> stockedRiders = [];
    final List<DCFleetDriver> unstockedRiders = [];

    for (final driver in drivers) {
      final alloc = allocations.where((a) => a.riderId == driver.id && a.productId == currentProductId).firstOrNull;
      if (alloc != null && alloc.inCustodyUnits > 0) {
        stockedRiders.add(driver);
      } else {
        unstockedRiders.add(driver);
      }
    }

    final int stockedCount = stockedRiders.length;
    final int unstockedCount = unstockedRiders.length;
    final double stockedPct = totalRiders > 0 ? (stockedCount / totalRiders * 100) : 0.0;
    final double unstockedPct = totalRiders > 0 ? (unstockedCount / totalRiders * 100) : 0.0;
    final riderSummaries = _buildRiderSummaries(allocations, drivers);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.all(14),
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
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.pie_chart_rounded, size: 18, color: Color(0xFF0284C7)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stock Distribution KPIs & Coverage',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Real-time courier inventory penetration across DC covering area',
                      style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Product Selector Dropdown (Req 7)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: Builder(builder: (context) {
                final effProdId = uniqueWarehouseItems.any((i) => i.id == currentProductId)
                    ? currentProductId
                    : (uniqueWarehouseItems.isNotEmpty ? uniqueWarehouseItems.first.id : null);
                return DropdownButton<String>(
                  value: effProdId,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                  items: uniqueWarehouseItems.map((item) {
                    return DropdownMenuItem<String>(
                      value: item.id,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.name} (${item.sku})',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${item.availableCount} Shelf',
                              style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedDistributionProductId = val;
                        _distributionKpiFilter = 'all';
                      });
                    }
                  },
                );
              }),
            ),
          ),
          const SizedBox(height: 12),

          // Dual-Colored Distribution Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (stockedPct > 0)
                    Expanded(
                      flex: (stockedPct * 10).toInt().clamp(1, 1000),
                      child: Container(color: const Color(0xFF16A34A)),
                    ),
                  if (unstockedPct > 0)
                    Expanded(
                      flex: (unstockedPct * 10).toInt().clamp(1, 1000),
                      child: Container(color: const Color(0xFFDC2626)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 2 Interactive Percentage Cards
          Row(
            children: [
              // Stocked Card
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _distributionKpiFilter = _distributionKpiFilter == 'stocked' ? 'all' : 'stocked';
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: _distributionKpiFilter == 'stocked'
                          ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _distributionKpiFilter == 'stocked'
                            ? const Color(0xFF16A34A)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                            const SizedBox(width: 4),
                            Text(
                              'Stocked Riders',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${stockedPct.toStringAsFixed(1)}%',
                          style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF16A34A)),
                        ),
                        Text(
                          '$stockedCount of $totalRiders couriers',
                          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Unstocked Card (Interactive trigger)
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _distributionKpiFilter = _distributionKpiFilter == 'unstocked' ? 'all' : 'unstocked';
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: _distributionKpiFilter == 'unstocked'
                          ? const Color(0xFFDC2626).withValues(alpha: 0.15)
                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFFEF2F2)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _distributionKpiFilter == 'unstocked'
                            ? const Color(0xFFDC2626)
                            : (unstockedCount > 0 ? const Color(0xFFFCA5A5) : Colors.transparent),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                            const SizedBox(width: 4),
                            Text(
                              'Unstocked Riders',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${unstockedPct.toStringAsFixed(1)}%',
                          style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFFDC2626)),
                        ),
                        Text(
                          '$unstockedCount couriers (0 units) • Tap to view',
                          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFDC2626), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Interactive List of Riders when Filter is Active (Req 7)
          if (_distributionKpiFilter != 'all') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _distributionKpiFilter == 'unstocked'
                            ? 'Unstocked Couriers (${unstockedRiders.length})'
                            : 'Stocked Couriers (${stockedRiders.length})',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      InkWell(
                        onTap: () => setState(() => _distributionKpiFilter = 'all'),
                        child: Text(
                          'Close List',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0284C7)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if ((_distributionKpiFilter == 'unstocked' ? unstockedRiders : stockedRiders).isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Center(
                        child: Text(
                          _distributionKpiFilter == 'unstocked'
                              ? '🎉 100% Coverage! All couriers currently hold stock of this product.'
                              : 'No couriers currently hold stock of this product.',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ...(_distributionKpiFilter == 'unstocked' ? unstockedRiders : stockedRiders).map((driver) {
                      final alloc = allocations.where((a) => a.riderId == driver.id && a.productId == currentProductId).firstOrNull;
                      final units = alloc?.inCustodyUnits ?? 0;
                      final summary = riderSummaries.where(
                        (r) => r.riderId == driver.id,
                      ).firstOrNull ?? RiderStockSummary(
                        riderId: driver.id,
                        riderName: driver.name,
                        riderCode: driver.driverCode,
                        phone: driver.phone,
                        vehiclePlate: driver.vehiclePlate,
                        vehicleType: driver.vehicleType,
                        totalCustodyUnits: 0,
                        totalDeliveredUnits: 0,
                        totalReturnedUnits: 0,
                        allocations: [],
                      );

                      return InkWell(
                        onTap: () => _showRiderStockDetailsModal(context, summary, warehouseItems, drivers, isDark),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              UserAvatarWidget(fullName: driver.name, radius: 14),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      driver.name,
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${driver.driverCode} • ${driver.phone.isNotEmpty ? driver.phone : "No phone"}',
                                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: units > 0
                                      ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                                      : const Color(0xFFDC2626).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  units > 0 ? '$units units' : '0 units',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: units > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (units == 0)
                                SizedBox(
                                  height: 28,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0284C7),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    onPressed: () => _openAssignStockModal(context, warehouseItems, drivers, isDark, preselectedDriverId: driver.id),
                                    child: const Text('Restock', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF94A3B8)),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: RIDER BALANCING & SALES TAB ROUTER
  // ==========================================
  Widget _buildRiderBalancingTabView(
    List<StockItemEntity> warehouseItems,
    List<RiderStockAllocation> allocations,
    List<DCFleetDriver> drivers,
    bool isDark,
  ) {
    final riderSummaries = _buildRiderSummaries(allocations, drivers);

    return Column(
      children: [
        // 3-way Segment Selector
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildOrganicSegmentPill(
                  index: 0,
                  label: 'Daily Sales',
                  icon: Icons.checklist_rounded,
                  activeColor: const Color(0xFF0284C7),
                  isDark: isDark,
                  currentIndex: _balancingSegment,
                  onTap: () => setState(() => _balancingSegment = 0),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildOrganicSegmentPill(
                  index: 1,
                  label: 'Peer Transfer',
                  icon: Icons.swap_horiz_rounded,
                  activeColor: const Color(0xFF2563EB),
                  isDark: isDark,
                  currentIndex: _balancingSegment,
                  onTap: () => setState(() => _balancingSegment = 1),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildOrganicSegmentPill(
                  index: 2,
                  label: 'Offboarded',
                  icon: Icons.person_off_rounded,
                  activeColor: const Color(0xFFDC2626),
                  isDark: isDark,
                  currentIndex: _balancingSegment,
                  onTap: () => setState(() => _balancingSegment = 2),
                ),
              ),
            ],
          ),
        ),

        // Sub-Tab Content
        Expanded(
          child: () {
            switch (_balancingSegment) {
              case 0:
                return _buildDailyReconciliationView(riderSummaries, warehouseItems, allocations, drivers, isDark);
              case 1:
                return _buildRiderToRiderView(allocations, drivers, isDark);
              case 2:
              default:
                return _buildLaidOffCouriersRetrievalView(warehouseItems, allocations, drivers, isDark);
            }
          }(),
        ),
      ],
    );
  }

  // ==========================================
  // REQ 3: DAILY SOLD & CUSTODY RECONCILIATION
  // ==========================================
  Widget _buildDailyReconciliationView(
    List<RiderStockSummary> riderSummaries,
    List<StockItemEntity> warehouseItems,
    List<RiderStockAllocation> allocations,
    List<DCFleetDriver> drivers,
    bool isDark,
  ) {
    final allOrders = ref.watch(ordersProvider).orders;

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: riderSummaries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final rider = riderSummaries[index];
        final driver = drivers.where(
          (d) => d.id == rider.riderId,
        ).firstOrNull ?? DCFleetDriver(
          id: rider.riderId,
          name: rider.riderName,
          phone: rider.phone ?? '',
          driverCode: rider.riderCode,
          assignedZone: 'Central Hub',
        );
        final int inCustody = rider.totalCustodyUnits;
        final int deliveredTotal = rider.totalDeliveredUnits;

        final int todayDelivered = allOrders.where((o) =>
            o.deliveryAgentId == rider.riderId &&
            o.status.toLowerCase() == 'delivered').length;

        final bool isLowStock = inCustody < _riderSafetyBufferThreshold;
        final bool isOutOfStock = inCustody == 0;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isOutOfStock
                  ? const Color(0xFFDC2626).withValues(alpha: 0.5)
                  : (isLowStock ? const Color(0xFFF59E0B).withValues(alpha: 0.5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              width: (isOutOfStock || isLowStock) ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rider Info Header
              Row(
                children: [
                  UserAvatarWidget(fullName: rider.riderName, radius: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                rider.riderName,
                                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: (isOutOfStock
                                        ? const Color(0xFFDC2626)
                                        : (isLowStock ? const Color(0xFFF59E0B) : const Color(0xFF16A34A)))
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isOutOfStock ? 'OUT OF STOCK' : (isLowStock ? 'LOW BUFFER' : 'STOCKED'),
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isOutOfStock
                                      ? const Color(0xFFDC2626)
                                      : (isLowStock ? const Color(0xFFF59E0B) : const Color(0xFF16A34A)),
                                ),
                              ),
                            ),
                            if (rider.isExternalPda) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD97706).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                                ),
                                child: const Text('EXT-PDA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${rider.riderCode} • Plate: ${rider.vehiclePlate ?? "N/A"}',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  // Phone & WhatsApp
                  IconButton(
                    icon: const Icon(Icons.phone_rounded, size: 18, color: Color(0xFF0284C7)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Call Courier',
                    onPressed: () {
                      if (rider.phone != null && rider.phone!.isNotEmpty) {
                        MapLauncherHelper.launchPhoneCall(context: context, phoneNumber: rider.phone!);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF16A34A)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'WhatsApp Courier',
                    onPressed: () {
                      if (rider.phone != null && rider.phone!.isNotEmpty) {
                        MapLauncherHelper.launchWhatsApp(
                          context: context,
                          customerPhone: rider.phone!,
                          message: 'Hello ${rider.riderName}, regarding your daily stock balance at NovaXpress DC.',
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // 3-Card Metrics Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Custody Balance', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                          Text(
                            '$inCustody units',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isOutOfStock ? const Color(0xFFDC2626) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sold Today', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                          Text(
                            '$todayDelivered orders',
                            style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Delivered', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                          Text(
                            '$deliveredTotal units',
                            style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Action Buttons Row: Restock from DC, Transfer from Peer, Audit Sales
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0284C7),
                      side: const BorderSide(color: Color(0xFF0284C7)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 14),
                    label: const Text('DC Restock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => _openAssignStockModal(context, warehouseItems, drivers, isDark, preselectedDriverId: rider.riderId),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                    label: const Text('Peer Transfer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => _openRiderToRiderModal(context, allocations, drivers, isDark),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.edit_note_rounded, size: 14),
                    label: const Text('Record Sales', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => _openAuditSalesDialog(context, driver, allocations, isDark),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // REQ 4: LAID-OFF COURIERS RETRIEVAL VIEW
  // ==========================================
  Widget _buildLaidOffCouriersRetrievalView(
    List<StockItemEntity> warehouseItems,
    List<RiderStockAllocation> allocations,
    List<DCFleetDriver> drivers,
    bool isDark,
  ) {
    final couriersWithStock = drivers.where((d) {
      final held = allocations.where((a) => a.riderId == d.id).fold(0, (sum, a) => sum + a.inCustodyUnits);
      return held > 0;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Information Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.gavel_rounded, color: Color(0xFFDC2626), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Laid-Off & Offboarding Couriers Custody Retrieval',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'When any rider is laid off or deactivated, the stock keeper retrieves all products in their custody back into the DC shelf balance, clears custody to 0, and generates an official audit clearance certificate.',
                      style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF7F1D1D), height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Couriers with Active Custody Units (${couriersWithStock.length}):',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        if (couriersWithStock.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 40, color: Color(0xFF16A34A)),
                  const SizedBox(height: 8),
                  Text('No Outstanding Custody Held', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  const Text('All couriers have 0 units in custody or are fully cleared.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          )
        else
          ...couriersWithStock.map((driver) {
            final driverAllocs = allocations.where((a) => a.riderId == driver.id && a.inCustodyUnits > 0).toList();
            final totalUnits = driverAllocs.fold(0, (sum, a) => sum + a.inCustodyUnits);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(13),
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
                      UserAvatarWidget(fullName: driver.name, radius: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(driver.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                            Text('${driver.driverCode} • Plate: ${driver.vehiclePlate.isNotEmpty ? driver.vehiclePlate : "N/A"}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$totalUnits Units',
                          style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: driverAllocs.map((a) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${a.inCustodyUnits}x ${a.productName}',
                          style: GoogleFonts.inter(fontSize: 10.5, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.assignment_returned_rounded, size: 16),
                      label: const Text('Offboard & Retrieve All Units', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () => _openRetrieveRiderStockModal(context, driver, allocations, warehouseItems, isDark),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ==========================================
  // REQ 4: RETRIEVE ALL STOCK MODAL (LAID-OFF RIDER)
  // ==========================================
  void _openRetrieveRiderStockModal(
    BuildContext context,
    DCFleetDriver driver,
    List<RiderStockAllocation> allocations,
    List<StockItemEntity> warehouseItems,
    bool isDark,
  ) {
    final driverAllocations = allocations.where((a) => a.riderId == driver.id && a.inCustodyUnits > 0).toList();
    final totalUnits = driverAllocations.fold(0, (sum, a) => sum + a.inCustodyUnits);
    final activeHubName = ref.read(dcConsoleProvider).activeHubName;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.person_off_rounded, size: 18, color: Color(0xFFDC2626)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Offboard Courier & Retrieve Stock',
                          style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      UserAvatarWidget(fullName: driver.name, radius: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driver.name,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Code: ${driver.driverCode} • Plate: ${driver.vehiclePlate.isNotEmpty ? driver.vehiclePlate : "N/A"}',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                            Text(
                              'Phone: ${driver.phone.isNotEmpty ? driver.phone : "N/A"}',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$totalUnits Units Held',
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text('Custody Units to Retrieve to DC Shelf:', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                if (driverAllocations.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '✅ Rider currently holds 0 units in custody. Ready for clean clearance.',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF16A34A), fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                else
                  ...driverAllocations.map((alloc) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  alloc.productName,
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'SKU: ${alloc.sku}',
                                  style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${alloc.inCustodyUnits} units -> DC Shelf',
                              style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.archive_rounded, size: 18),
                    label: Text(
                      totalUnits > 0 ? 'Retrieve All $totalUnits Units & Offboard' : 'Complete Offboarding Clearance',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);

                      for (final alloc in driverAllocations) {
                        final returnNum = 'RET-OFFBOARD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                        await ref.read(stockProvider.notifier).processStockReturn(
                          returnNumber: returnNum,
                          orderId: 'OFFBOARD-CLEARANCE',
                          deliveryAgentId: driver.id,
                          productId: alloc.productId,
                          quantity: alloc.inCustodyUnits,
                          reason: 'Courier Laid-Off / Offboarding Inventory Recall',
                          destinationDcId: ref.read(dcConsoleProvider).activeHubId,
                          condition: 'good',
                          notes: 'Recalled back to DC shelf due to offboarding.',
                        );
                      }

                      _loadStockData();

                      if (context.mounted) {
                        _showClearanceCertificateDialog(context, driver, totalUnits, activeHubName, isDark);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // REQ 4: CLEARANCE CERTIFICATE DIALOG
  // ==========================================
  void _showClearanceCertificateDialog(
    BuildContext context,
    DCFleetDriver driver,
    int totalUnitsReturned,
    String dcName,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFF16A34A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, size: 30, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                'Courier Inventory Clearance Certificate',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Official Custody Release & Stock Reconciliation',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildCertificateRow('Courier Name', driver.name, isDark),
                    _buildCertificateRow('Driver ID / Code', driver.driverCode, isDark),
                    _buildCertificateRow('Station Facility', dcName, isDark),
                    _buildCertificateRow('Returned to Shelf', '$totalUnitsReturned Units', isDark, isHighlight: true),
                    _buildCertificateRow('Custody Balance', '0 Units (CLEARED)', isDark, isHighlight: true),
                    _buildCertificateRow('Date of Release', DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()), isDark),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Acknowledge & Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCertificateRow(String label, String value, bool isDark, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isHighlight ? const Color(0xFF16A34A) : (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // REQ 3: RECORD DAILY SALES DIALOG
  // ==========================================
  void _openAuditSalesDialog(
    BuildContext context,
    DCFleetDriver driver,
    List<RiderStockAllocation> allocations,
    bool isDark,
  ) {
    // Deduplicate allocations by productId to prevent duplicate DropdownMenuItem error
    final uniqueDriverAllocations = <RiderStockAllocation>[];
    final seenProductIds = <String>{};
    for (final a in allocations.where((a) => a.riderId == driver.id || a.riderCode == driver.driverCode)) {
      if (a.productId.isNotEmpty && seenProductIds.add(a.productId)) {
        uniqueDriverAllocations.add(a);
      }
    }

    // Fallback: allow reconciling directly against DC products even if rider has no formal allocation row yet
    if (uniqueDriverAllocations.isEmpty) {
      final warehouseItems = ref.read(stockProvider).stockItems;
      for (final item in warehouseItems) {
        if (item.id.isNotEmpty && seenProductIds.add(item.id)) {
          uniqueDriverAllocations.add(RiderStockAllocation(
            id: 'fallback_${item.id}',
            riderId: driver.id,
            riderName: driver.name,
            riderCode: driver.driverCode,
            productId: item.id,
            productName: item.name,
            sku: item.sku,
            clientName: item.ownerName,
            allocatedUnits: item.assignedCount,
            deliveredUnits: item.deliveredCount,
            inCustodyUnits: item.availableCount,
            unitPrice: item.price,
            allocatedAt: DateTime.now(),
          ));
        }
      }
    }

    if (uniqueDriverAllocations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No products or allocations found to reconcile for this courier.')),
      );
      return;
    }

    String selectedProductId = uniqueDriverAllocations.first.productId;
    final soldCtrl = TextEditingController(text: '1');
    final notesCtrl = TextEditingController();
    final selectedOrderIds = <String>{};
    final allOrders = ref.read(ordersProvider).orders;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final selectedAlloc = uniqueDriverAllocations.firstWhere(
            (a) => a.productId == selectedProductId,
            orElse: () => uniqueDriverAllocations.first,
          );
          final pLower = selectedAlloc.productName.toLowerCase();
          final openOrdersForSelected = allOrders.where((o) {
            if (o.isDelivered || o.isCancelled) return false;
            final matchesRider = o.deliveryAgentId == driver.id ||
                o.assignedAgentId == driver.id ||
                (o.deliveryAgentCode != null && o.deliveryAgentCode == driver.driverCode) ||
                (o.deliveryAgentName != null && o.deliveryAgentName!.toLowerCase() == driver.name.toLowerCase());
            if (!matchesRider) return false;
            final oProdLower = o.productName.toLowerCase();
            return (selectedAlloc.productId.isNotEmpty && o.productId == selectedAlloc.productId) ||
                (pLower.isNotEmpty &&
                    oProdLower.isNotEmpty &&
                    (oProdLower.contains(pLower) || pLower.contains(oProdLower)));
          }).toList();

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Record Daily Sales & Balance', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Courier: ${driver.name} (${driver.driverCode})', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                    const SizedBox(height: 14),

                    Builder(builder: (context) {
                      final effectiveProdId = uniqueDriverAllocations.any((a) => a.productId == selectedProductId)
                          ? selectedProductId
                          : (uniqueDriverAllocations.isNotEmpty ? uniqueDriverAllocations.first.productId : null);
                      return NovaSearchableSelectField<String>(
                        label: 'Select Product SKU *',
                        placeholder: 'Tap to select product...',
                        value: effectiveProdId,
                        prefixIcon: Icons.inventory_2_outlined,
                        brandColor: const Color(0xFF0284C7),
                        pickerTitle: 'Select Product SKU',
                        pickerSubtitle: 'Choose product to reconcile sales',
                        options: uniqueDriverAllocations.map((a) {
                          return NovaPickerOption<String>(
                            value: a.productId,
                            title: a.productName,
                            subtitle: 'Product ID: ${a.productId}',
                            badgeText: '${a.inCustodyUnits} units',
                            badgeColor: const Color(0xFF0284C7),
                            icon: Icons.inventory_2_outlined,
                            trailingText: 'Custody: ${a.inCustodyUnits}',
                            searchTerms: [a.productName, a.productId],
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedProductId = val;
                              selectedOrderIds.clear();
                            });
                          }
                        },
                      );
                    }),
                    const SizedBox(height: 14),

                    if (openOrdersForSelected.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.playlist_add_check_rounded, size: 16, color: Color(0xFF0284C7)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Unmarked Open Orders to Close (${openOrdersForSelected.length})',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 170),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: openOrdersForSelected.length,
                          itemBuilder: (context, idx) {
                            final ord = openOrdersForSelected[idx];
                            final checked = selectedOrderIds.contains(ord.id);
                            return CheckboxListTile(
                              dense: true,
                              value: checked,
                              activeColor: const Color(0xFF16A34A),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                              title: Text(
                                '#${ord.orderNumber} • ${ord.customerName}',
                                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${ord.quantity} unit(s) • ${ord.status.replaceAll('_', ' ').toUpperCase()}',
                                style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                              ),
                              onChanged: (v) {
                                setModalState(() {
                                  if (v == true) {
                                    selectedOrderIds.add(ord.id);
                                  } else {
                                    selectedOrderIds.remove(ord.id);
                                  }
                                  final checkedQty = openOrdersForSelected
                                      .where((o) => selectedOrderIds.contains(o.id))
                                      .fold(0, (s, o) => s + o.quantity);
                                  if (checkedQty > 0) {
                                    soldCtrl.text = '$checkedQty';
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    Text('Units Sold Today', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: soldCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Enter units confirmed sold / delivered',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text('Reconciliation Notes (Optional)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. End-of-day physical stock count confirmed',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          final sold = int.tryParse(soldCtrl.text.trim()) ?? 0;
                          if (sold <= 0 && selectedOrderIds.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enter sold units or select open orders to balance.')),
                            );
                            return;
                          }
                          final activeHubId = ref.read(dcConsoleProvider).activeHubId;
                          Navigator.pop(ctx);

                          final res = await ref.read(stockProvider.notifier).recordDailyRiderSales(
                            riderId: driver.id,
                            riderName: driver.name,
                            productId: selectedProductId,
                            unitsSold: sold,
                            distributionCenterId: activeHubId,
                            reconcileOrderIds: selectedOrderIds.toList(),
                            notes: notesCtrl.text.trim(),
                          );
                          if (selectedOrderIds.isNotEmpty) {
                            ref.read(ordersProvider.notifier).loadOrders();
                          }

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: res['success'] == true ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                content: Text(res['message']?.toString() ?? 'Daily sales count recorded successfully.'),
                              ),
                            );
                            _loadStockData();
                          }
                        },
                        child: const Text('Save Daily Sales & Balance Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
