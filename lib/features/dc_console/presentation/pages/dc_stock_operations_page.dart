import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/user_avatar_widget.dart';
import '../../../stock/domain/entities/stock_item.dart';
import '../../../stock/domain/entities/rider_stock_allocation.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../../domain/entities/distribution_center.dart';
import '../providers/dc_console_provider.dart';
import '../widgets/dc_staff_profile_settings_tab.dart';

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
  });
}

class DCStockOperationsPage extends ConsumerStatefulWidget {
  const DCStockOperationsPage({super.key});

  @override
  ConsumerState<DCStockOperationsPage> createState() => _DCStockOperationsPageState();
}

class _DCStockOperationsPageState extends ConsumerState<DCStockOperationsPage> {
  int _activeTab = 0; // 0: Assign & Requests, 1: Rider Balancing, 2: DC Transfers, 3: Damaged Returns, 4: Profile & Settings
  int _tab0Segment = 0; // 0: In-Field Custody, 1: Restock Requests
  String _requestFilter = 'all'; // 'all', 'pending', 'fulfilled'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStockData();
    });
  }

  void _loadStockData() {
    final activeHubId = ref.read(dcConsoleProvider).activeHubId;
    ref.read(stockProvider.notifier).fetchStockItems(null, activeHubId);
    ref.read(stockProvider.notifier).fetchStockTransfers(dcId: activeHubId);
    ref.read(stockProvider.notifier).fetchStockRequests(activeHubId);
    ref.read(dcConsoleProvider.notifier).loadDriversFromDatabase();
    ref.read(dcConsoleProvider.notifier).loadDistributionCentersFromDatabase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RiderStockSummary> _buildRiderSummaries(
    List<RiderStockAllocation> allocations,
    List<DCFleetDriver> drivers,
  ) {
    final Map<String, List<RiderStockAllocation>> allocByRider = {};
    for (final a in allocations) {
      allocByRider.putIfAbsent(a.riderId, () => []).add(a);
    }

    final Map<String, DCFleetDriver> driverMap = {for (var d in drivers) d.id: d};
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
      ));
      processedRiderIds.add(rId);
    }

    // Include other drivers attached to this DC who don't have stock yet
    for (final driver in drivers) {
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

    final int totalWarehouseUnits = warehouseItems.fold(0, (sum, i) => sum + i.availableCount);
    final int totalFieldCustodyUnits = riderAllocations.fold(0, (sum, a) => sum + a.inCustodyUnits);
    final int totalDamagedUnits = warehouseItems.fold(0, (sum, i) => sum + i.complaintCount);
    final int pendingRequestsCount = inboundRequests.where((r) => r.isPending).length;
    final interDcTransfers = stockState.stockTransfers.where((t) => t.isInterDc).toList();

    final currentDc = dcState.distributionCenters.where((d) => d.id == dcState.activeHubId).firstOrNull ??
        dcState.distributionCenters.firstOrNull;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stock Operations Console',
              style: GoogleFonts.inter(fontSize: 16.5, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${dcState.activeHubName} • Station & Field Inventory Control',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF0284C7), fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
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
                  isLabelVisible: pendingRequestsCount > 0,
                  label: Text('$pendingRequestsCount'),
                  backgroundColor: const Color(0xFFF37021),
                  child: const Icon(Icons.inventory_2_outlined),
                ),
                label: 'Stock & Queue',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.swap_horiz_rounded),
                label: 'Balancing',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: interDcTransfers.isNotEmpty,
                  label: Text('${interDcTransfers.length}'),
                  backgroundColor: const Color(0xFFF37021),
                  child: const Icon(Icons.local_shipping_outlined),
                ),
                label: 'Transfers',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: totalDamagedUnits > 0,
                  label: Text('$totalDamagedUnits'),
                  backgroundColor: const Color(0xFFDC2626),
                  child: const Icon(Icons.report_problem_outlined),
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
              // 2x2 Grid KPI Metrics Header (NO Horizontal Scrolling, ZERO Overflow)
              if (_activeTab != 4)
                _buildKpiGrid(
                  totalWarehouseUnits,
                  totalFieldCustodyUnits,
                  pendingRequestsCount,
                  totalDamagedUnits,
                  isDark,
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
                  isDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // RESPONSIVE 2x2 KPI GRID (NO SCROLLING)
  // ==========================================
  Widget _buildKpiGrid(
    int warehouseUnits,
    int custodyUnits,
    int pendingReqs,
    int damagedUnits,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildCompactKpiCard(
                  title: 'STATION ON-HAND',
                  value: '$warehouseUnits',
                  unit: 'Units',
                  subtitle: 'In DC Warehouse',
                  icon: Icons.inventory_2_outlined,
                  color: const Color(0xFF2563EB),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactKpiCard(
                  title: 'RIDER CUSTODY',
                  value: '$custodyUnits',
                  unit: 'Units',
                  subtitle: 'In Field Vehicles',
                  icon: Icons.motorcycle_outlined,
                  color: const Color(0xFF16A34A),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildCompactKpiCard(
                  title: 'RESTOCK QUEUE',
                  value: '$pendingReqs',
                  unit: 'Pending',
                  subtitle: 'Awaiting Action',
                  icon: Icons.move_to_inbox_rounded,
                  color: const Color(0xFFF37021),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactKpiCard(
                  title: 'RETURNS / SPOILAGE',
                  value: '$damagedUnits',
                  unit: 'Units',
                  subtitle: 'Quarantined Stock',
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFDC2626),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactKpiCard({
    required String title,
    required String value,
    required String unit,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : color.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
    bool isDark,
  ) {
    switch (_activeTab) {
      case 0:
        return _buildAssignStockView(
          warehouseItems,
          riderAllocations,
          drivers,
          inboundRequests,
          isDark,
        );
      case 1:
        return _buildRiderToRiderView(riderAllocations, drivers, isDark);
      case 2:
        return _buildDcToDcTransfersView(warehouseItems, interDcTransfers, dcs, activeHubId, isDark);
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
          isDark,
        );
    }
  }

  // ==========================================
  // TAB 0: ASSIGN STOCK & RESTOCK REQUESTS
  // ==========================================
  Widget _buildAssignStockView(
    List<StockItemEntity> warehouseItems,
    List<RiderStockAllocation> allocations,
    List<DCFleetDriver> drivers,
    List<InboundStockRequest> inboundRequests,
    bool isDark,
  ) {
    final riderSummaries = _buildRiderSummaries(allocations, drivers);
    final pendingCount = inboundRequests.where((r) => r.isPending).length;

    return Column(
      children: [
        // Sub-Tab Switcher Pills: In-Field Custody vs Restock Queue
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tab0Segment = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _tab0Segment == 0
                          ? const Color(0xFF00522A)
                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.motorcycle_rounded,
                          size: 15,
                          color: _tab0Segment == 0 ? Colors.white : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'In-Field Custody (${riderSummaries.length})',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _tab0Segment == 0 ? Colors.white : const Color(0xFF64748B),
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
                  onTap: () => setState(() => _tab0Segment = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _tab0Segment == 1
                          ? const Color(0xFFF37021)
                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.move_to_inbox_rounded,
                          size: 15,
                          color: _tab0Segment == 1 ? Colors.white : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Restock Queue',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _tab0Segment == 1 ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                        if (pendingCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: _tab0Segment == 1 ? Colors.white : const Color(0xFFF37021),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$pendingCount',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _tab0Segment == 1 ? const Color(0xFFF37021) : Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Sub-Tab Content
        Expanded(
          child: _tab0Segment == 0
              ? _buildInFieldCustodySegment(
                  riderSummaries,
                  warehouseItems,
                  allocations,
                  drivers,
                  isDark,
                )
              : _buildRestockQueueSegment(
                  inboundRequests,
                  warehouseItems,
                  allocations,
                  drivers,
                  isDark,
                ),
        ),
      ],
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
        Expanded(
          child: riderSummaries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.motorcycle_rounded, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text('No Active Delivery Agents', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      const Text('Riders attached to this DC will appear here.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
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
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
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
                )
              : ListView.separated(
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
                    else
                      DropdownButtonFormField<String>(
                        value: selectedDonorRiderId,
                        isExpanded: true,
                        items: otherAllocations.map((a) {
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
                      ),
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
  // TAB 2: DC-TO-DC TRANSFERS
  // ==========================================
  Widget _buildDcToDcTransfersView(
    List<StockItemEntity> warehouseItems,
    List<dynamic> interDcTransfers,
    List<DistributionCenter> dcs,
    String activeHubId,
    bool isDark,
  ) {
    return Column(
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
                child: Text(
                  'Inter-DC Transfers (${interDcTransfers.length})',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _openInterDcTransferModal(context, warehouseItems, dcs, activeHubId, isDark),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00522A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.send_rounded, size: 15),
                label: const Text('Initiate DC Transfer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),

        Expanded(
          child: interDcTransfers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_shipping_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text('No Inter-DC Transfers Logged', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      const Text('Initiate stock transfers to or from other distribution centers across Nigeria.', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: interDcTransfers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final t = interDcTransfers[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.alt_route_rounded, color: Color(0xFF2563EB), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${t.sourceDcName} → ${t.destinationDcName}',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Item: ${t.productName} • Waybill: ${t.transferNumber}',
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
                                '${t.quantityShipped} Units',
                                style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  (t.status as String).toUpperCase(),
                                  style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                                ),
                              ),
                            ],
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
  // TAB 3: DAMAGED / SPOILAGE RETURNS
  // ==========================================
  Widget _buildSpoilageReturnsView(
    List<StockItemEntity> warehouseItems,
    List<RiderStockAllocation> allocations,
    List<DCFleetDriver> drivers,
    bool isDark,
  ) {
    final damagedItems = warehouseItems.where((i) => i.complaintCount > 0).toList();

    return Column(
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
                child: Text(
                  'Damaged & Quarantine (${damagedItems.length} SKUs)',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _openSpoilageModal(context, warehouseItems, drivers, isDark),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.report_problem_rounded, size: 15),
                label: const Text('Log Damaged Return', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),

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
  }) {
    if (warehouseItems.isEmpty || drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot allocate: Ensure warehouse has items and drivers exist.')),
      );
      return;
    }

    String selectedProductId = warehouseItems.first.id;
    String selectedDriverId = preselectedDriverId != null && drivers.any((d) => d.id == preselectedDriverId)
        ? preselectedDriverId
        : drivers.first.id;
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
                  const SizedBox(height: 14),

                  // Select Rider
                  Text('Select Rider', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedDriverId,
                    isExpanded: true,
                    items: drivers.map((d) => DropdownMenuItem(value: d.id, child: Text('${d.name} (${d.driverCode})', style: const TextStyle(fontSize: 12.5)))).toList(),
                    onChanged: (v) => setModalState(() => selectedDriverId = v!),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Select Product
                  Text('Select Product', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedProductId,
                    isExpanded: true,
                    items: warehouseItems.map((i) => DropdownMenuItem(value: i.id, child: Text('${i.name} (DC Available: ${i.availableCount})', style: const TextStyle(fontSize: 12.5)))).toList(),
                    onChanged: (v) => setModalState(() => selectedProductId = v!),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
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
                        final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                        if (qty <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid quantity.')));
                          return;
                        }
                        final driver = drivers.firstWhere((d) => d.id == selectedDriverId);
                        Navigator.pop(ctx);

                        final res = await ref.read(stockProvider.notifier).assignStockToRider(
                          productIdOrSku: selectedProductId,
                          riderId: driver.id,
                          riderName: driver.name,
                          riderCode: driver.driverCode,
                          quantity: qty,
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

    RiderStockAllocation selectedSourceAlloc = preselectedSourceRiderId != null &&
            availableAllocations.any((a) => a.riderId == preselectedSourceRiderId)
        ? availableAllocations.firstWhere((a) => a.riderId == preselectedSourceRiderId)
        : availableAllocations.first;

    String selectedDestDriverId = drivers.firstWhere((d) => d.id != selectedSourceAlloc.riderId, orElse: () => drivers.first).id;
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
                  DropdownButtonFormField<RiderStockAllocation>(
                    value: selectedSourceAlloc,
                    isExpanded: true,
                    items: availableAllocations.map((a) => DropdownMenuItem(value: a, child: Text('${a.riderName} (${a.productName} • ${a.inCustodyUnits} in hand)', style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) {
                      setModalState(() {
                        selectedSourceAlloc = v!;
                        if (selectedDestDriverId == selectedSourceAlloc.riderId) {
                          selectedDestDriverId = drivers.firstWhere((d) => d.id != selectedSourceAlloc.riderId, orElse: () => drivers.first).id;
                        }
                      });
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Destination Rider
                  Text('Destination Rider (Receiving Stock)', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedDestDriverId,
                    isExpanded: true,
                    items: drivers.where((d) => d.id != selectedSourceAlloc.riderId).map((d) => DropdownMenuItem(value: d.id, child: Text('${d.name} (${d.driverCode})', style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) => setModalState(() => selectedDestDriverId = v!),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
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
                        final destDriver = drivers.firstWhere((d) => d.id == selectedDestDriverId);
                        Navigator.pop(ctx);

                        final res = await ref.read(stockProvider.notifier).transferStockBetweenRiders(
                          productIdOrSku: selectedSourceAlloc.productId,
                          sourceRiderId: selectedSourceAlloc.riderId,
                          sourceRiderName: selectedSourceAlloc.riderName,
                          destinationRiderId: destDriver.id,
                          destinationRiderName: destDriver.name,
                          destinationRiderCode: destDriver.driverCode,
                          quantity: qty,
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
    final availableDcs = dcs.where((d) => d.id != activeHubId).toList();
    if (warehouseItems.isEmpty || availableDcs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need available warehouse stock and at least 2 distribution centers.')),
      );
      return;
    }

    String selectedProductId = warehouseItems.first.id;
    String selectedDestDcId = availableDcs.first.id;
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
                  DropdownButtonFormField<String>(
                    value: selectedDestDcId,
                    isExpanded: true,
                    items: availableDcs.map((d) => DropdownMenuItem(value: d.id, child: Text('${d.name} (${d.city}, ${d.state})', style: const TextStyle(fontSize: 12.5)))).toList(),
                    onChanged: (v) => setModalState(() => selectedDestDcId = v!),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Product
                  Text('Product to Transfer', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedProductId,
                    isExpanded: true,
                    items: warehouseItems.map((i) => DropdownMenuItem(value: i.id, child: Text('${i.name} (DC Stock: ${i.availableCount})', style: const TextStyle(fontSize: 12.5)))).toList(),
                    onChanged: (v) => setModalState(() => selectedProductId = v!),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
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
                        final destDc = dcs.firstWhere((d) => d.id == selectedDestDcId);
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
    if (warehouseItems.isEmpty || drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need products and drivers to log damage report.')),
      );
      return;
    }

    String selectedProductId = warehouseItems.first.id;
    String selectedDriverId = drivers.first.id;
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
                  DropdownButtonFormField<String>(
                    value: selectedDriverId,
                    isExpanded: true,
                    items: drivers.map((d) => DropdownMenuItem(value: d.id, child: Text('${d.name} (${d.driverCode})', style: const TextStyle(fontSize: 12.5)))).toList(),
                    onChanged: (v) => setModalState(() => selectedDriverId = v!),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Product
                  Text('Damaged Product SKU', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedProductId,
                    isExpanded: true,
                    items: warehouseItems.map((i) => DropdownMenuItem(value: i.id, child: Text('${i.name} (${i.sku})', style: const TextStyle(fontSize: 12.5)))).toList(),
                    onChanged: (v) => setModalState(() => selectedProductId = v!),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Damage Reason
                  Text('Condition / Damage Category', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    isExpanded: true,
                    items: damageReasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12.5)))).toList(),
                    onChanged: (v) => setModalState(() => selectedReason = v!),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
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
                  const SizedBox(height: 20),

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
                        final driver = drivers.firstWhere((d) => d.id == selectedDriverId);
                        final returnNum = 'RET-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                        Navigator.pop(ctx);

                        final res = await ref.read(stockProvider.notifier).processStockReturn(
                          returnNumber: returnNum,
                          orderId: 'MANUAL-DAMAGE-RETURN',
                          deliveryAgentId: driver.id,
                          productId: selectedProductId,
                          quantity: qty,
                          reason: selectedReason,
                          condition: 'damaged',
                          notes: notesController.text.trim(),
                        );

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: res['success'] == true ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              content: Text(res['message']?.toString() ?? 'Damage report logged into quarantine ledger.'),
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
}
