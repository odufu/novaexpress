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

class DCStockOperationsPage extends ConsumerStatefulWidget {
  const DCStockOperationsPage({super.key});

  @override
  ConsumerState<DCStockOperationsPage> createState() => _DCStockOperationsPageState();
}

class _DCStockOperationsPageState extends ConsumerState<DCStockOperationsPage> {
  int _activeTab = 0; // 0: Assign Stock, 1: Rider Balancing, 2: DC Transfers, 3: Damaged Returns, 4: Profile & Settings
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
    ref.read(dcConsoleProvider.notifier).loadDriversFromDatabase();
    ref.read(dcConsoleProvider.notifier).loadDistributionCentersFromDatabase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

    final int totalWarehouseUnits = warehouseItems.fold(0, (sum, i) => sum + i.availableCount);
    final int totalFieldCustodyUnits = riderAllocations.fold(0, (sum, a) => sum + a.inCustodyUnits);
    final int totalDamagedUnits = warehouseItems.fold(0, (sum, i) => sum + i.complaintCount);
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
              style: GoogleFonts.inter(fontSize: 17.5, fontWeight: FontWeight.bold),
            ),
            Text(
              '${dcState.activeHubName} • Station & Field Inventory Control',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF0284C7), fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Inventory',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStockData,
          ),
          const SizedBox(width: 8),
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
                  isLabelVisible: riderAllocations.isNotEmpty,
                  label: Text('${riderAllocations.length}'),
                  backgroundColor: const Color(0xFF0284C7),
                  child: const Icon(Icons.assignment_ind_outlined),
                ),
                label: 'Allocation',
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
      body: Column(
        children: [
          // KPI Metric Header - Horizontally Scrollable & Overflow-Free (only on Operational Tabs)
          if (_activeTab != 4)
            Container(
              height: 98,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  SizedBox(
                    width: 175,
                    child: _buildKpiCard(
                      'STATION ON-HAND',
                      '$totalWarehouseUnits Units',
                      'Available in DC warehouse',
                      Icons.inventory_2_outlined,
                      const Color(0xFF2563EB),
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 175,
                    child: _buildKpiCard(
                      'RIDER CUSTODY',
                      '$totalFieldCustodyUnits Units',
                      'In delivery vehicles',
                      Icons.motorcycle_outlined,
                      const Color(0xFF16A34A),
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 185,
                    child: _buildKpiCard(
                      'DAMAGED / SPOILAGE',
                      '$totalDamagedUnits Units',
                      'Quarantined from delivery',
                      Icons.warning_amber_rounded,
                      const Color(0xFFDC2626),
                      isDark,
                    ),
                  ),
                ],
              ),
            ),

          // Main Tabs
          Expanded(
            child: _buildActiveTabBody(
              warehouseItems,
              riderAllocations,
              drivers,
              interDcTransfers,
              dcs,
              currentDc,
              dcState.activeHubId,
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTabBody(
    List<StockItemEntity> warehouseItems,
    List<RiderStockAllocation> riderAllocations,
    List<DCFleetDriver> drivers,
    List<dynamic> interDcTransfers,
    List<DistributionCenter> dcs,
    DistributionCenter? currentDc,
    String activeHubId,
    bool isDark,
  ) {
    switch (_activeTab) {
      case 0:
        return _buildAssignStockView(warehouseItems, riderAllocations, drivers, isDark);
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
        return _buildAssignStockView(warehouseItems, riderAllocations, drivers, isDark);
    }
  }

  Widget _buildKpiCard(
    String label,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: ASSIGN STOCK TO RIDERS
  // ==========================================
  Widget _buildAssignStockView(
    List<StockItemEntity> warehouseItems,
    List<RiderStockAllocation> allocations,
    List<DCFleetDriver> drivers,
    bool isDark,
  ) {
    return Column(
      children: [
        // Top Action Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active In-Field Rider Stock Allocations (${allocations.length})',
                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _openAssignStockModal(context, warehouseItems, drivers, isDark),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00522A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Allocate Stock to Rider', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              ),
            ],
          ),
        ),

        // Allocations Table / Cards
        Expanded(
          child: allocations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text('No Active Rider Stock Allocations', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      const Text('Click "Allocate Stock to Rider" to assign physical stock to field delivery agents.'),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: allocations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final alloc = allocations[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          UserAvatarWidget(fullName: alloc.riderName, radius: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(alloc.riderName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF37021).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        alloc.riderCode,
                                        style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFFF37021)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Product: ${alloc.productName} (${alloc.sku})',
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${alloc.inCustodyUnits} Units in Custody',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF00522A),
                                ),
                              ),
                              Text(
                                'Allocated: ${alloc.allocatedUnits} • Delivered: ${alloc.deliveredUnits}',
                                style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
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
  // TAB 2: RIDER-TO-RIDER STOCK BALANCING
  // ==========================================
  Widget _buildRiderToRiderView(
    List<RiderStockAllocation> allocations,
    List<DCFleetDriver> drivers,
    bool isDark,
  ) {
    return Column(
      children: [
        // Top Action Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'In-Field Stock Balancing (Rider to Rider)',
                      style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Re-distribute inventory between riders in neighboring delivery sectors.',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openRiderToRiderModal(context, allocations, drivers, isDark),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: const Text('Balance Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              ),
            ],
          ),
        ),

        // Information / Overview
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Rider-to-Rider stock balancing enables dynamic inventory reallocation in the field when one rider has excess items while another is running low on orders in proximity.',
                        style: GoogleFonts.inter(fontSize: 12.5, color: isDark ? Colors.white70 : const Color(0xFF1E3A8A), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Available Rider Custody Units for Balancing:',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...allocations.where((a) => a.inCustodyUnits > 0).map((a) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.motorcycle_rounded, color: Color(0xFF2563EB)),
                    title: Text('${a.riderName} (${a.riderCode})', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Product: ${a.productName}'),
                    trailing: Text(
                      '${a.inCustodyUnits} units available',
                      style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
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
  // TAB 3: DC-TO-DC TRANSFERS
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
        // Action Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Inter-Distribution Center Transfers (${interDcTransfers.length})',
                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _openInterDcTransferModal(context, warehouseItems, dcs, activeHubId, isDark),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00522A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('Initiate DC Transfer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
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
                      const Text('Initiate stock transfers to or from other distribution centers across Nigeria.'),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: interDcTransfers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final t = interDcTransfers[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.alt_route_rounded, color: Color(0xFF2563EB), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${t.sourceDcName} ➔ ${t.destinationDcName}',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Item: ${t.productName} • Waybill: ${t.transferNumber}',
                                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${t.quantityShipped} Units',
                                style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  (t.status as String).toUpperCase(),
                                  style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
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
  // TAB 4: DAMAGED / SPOILAGE RETURNS
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
        // Top Action Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quarantine & Damaged Goods Ledger (${damagedItems.length} SKUs)',
                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _openSpoilageModal(context, warehouseItems, drivers, isDark),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.report_problem_rounded, size: 16),
                label: const Text('Log Damaged Return', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
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
                      Text('Zero Damaged or Spoiled Stock! 🎉', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      const Text('No quarantined or defective items recorded at this distribution center.'),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: damagedItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = damagedItems[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.broken_image_rounded, color: Color(0xFFDC2626), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                const SizedBox(height: 2),
                                Text('SKU: ${item.sku} • Merchant: ${item.ownerName}', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${item.complaintCount} Defective Units',
                                style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
                              ),
                              Text('Quarantined from Dispatch', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFDC2626))),
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
  // MODAL 1: ASSIGN STOCK TO RIDER
  // ==========================================
  void _openAssignStockModal(
    BuildContext context,
    List<StockItemEntity> warehouseItems,
    List<DCFleetDriver> drivers,
    bool isDark,
  ) {
    if (warehouseItems.isEmpty || drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot allocate: Ensure warehouse has items and drivers exist.')),
      );
      return;
    }

    String selectedProductId = warehouseItems.first.id;
    String selectedDriverId = drivers.first.id;
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
                    items: drivers.map((d) => DropdownMenuItem(value: d.id, child: Text('${d.name} (${d.driverCode})', style: const TextStyle(fontSize: 13)))).toList(),
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
                    items: warehouseItems.map((i) => DropdownMenuItem(value: i.id, child: Text('${i.name} (Available: ${i.availableCount})', style: const TextStyle(fontSize: 13)))).toList(),
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
                      hintText: 'e.g., Morning dispatch batch #4',
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
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00522A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      child: const Text('Confirm Allocation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
    bool isDark,
  ) {
    final availableAllocations = allocations.where((a) => a.inCustodyUnits > 0).toList();
    if (availableAllocations.isEmpty || drivers.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need at least 1 rider with stock in custody and 2 drivers to balance stock.')),
      );
      return;
    }

    RiderStockAllocation selectedSourceAlloc = availableAllocations.first;
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
                    onChanged: (v) => setModalState(() => selectedSourceAlloc = v!),
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
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      child: const Text('Execute Rider Transfer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                    items: warehouseItems.map((i) => DropdownMenuItem(value: i.id, child: Text('${i.name} (Stock: ${i.availableCount})', style: const TextStyle(fontSize: 12.5)))).toList(),
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
                  Text('Transfer Quantity', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
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
                  Text('Waybill Reference Code', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
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
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00522A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                        if (qty <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid quantity.')));
                          return;
                        }
                        final destDc = dcs.firstWhere((d) => d.id == selectedDestDcId);
                        final currentDc = dcs.firstWhere((d) => d.id == activeHubId, orElse: () => destDc);
                        Navigator.pop(ctx);

                        final res = await ref.read(stockProvider.notifier).transferStockBetweenDCs(
                          productIdOrSku: selectedProductId,
                          sourceDcId: currentDc.id,
                          sourceDcName: currentDc.name,
                          destinationDcId: destDc.id,
                          destinationDcName: destDc.name,
                          quantity: qty,
                          notes: 'Waybill: ${waybillController.text.trim()}',
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
                      child: const Text('Dispatch Inter-DC Transfer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                    items: warehouseItems.map((i) => DropdownMenuItem(value: i.id, child: Text(i.name, style: const TextStyle(fontSize: 12.5)))).toList(),
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
                  Text('Damage Category / Defect Reason', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
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
                  Text('Quantity Damaged', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
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

                  // Remarks
                  Text('Inspection Notes', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      hintText: 'e.g., Leaking bottle returned by customer upon unboxing',
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
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                        if (qty <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid quantity.')));
                          return;
                        }
                        Navigator.pop(ctx);

                        final res = await ref.read(stockProvider.notifier).recordComplaintOrDamage(
                          productIdOrSku: selectedProductId,
                          riderId: selectedDriverId,
                          quantity: qty,
                          reason: selectedReason,
                          notes: notesController.text.trim(),
                        );

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: res['success'] == true ? const Color(0xFFDC2626) : Colors.grey,
                              content: Text(res['message']?.toString() ?? 'Damage recorded and quarantined.'),
                            ),
                          );
                          _loadStockData();
                        }
                      },
                      child: const Text('Quarantine Damaged Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
