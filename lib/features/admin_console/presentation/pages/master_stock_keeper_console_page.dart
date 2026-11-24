import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/helpers/formatters.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/admin_models.dart';
import '../../domain/entities/agent_daily_sale_record.dart';
import '../providers/admin_console_provider.dart';
import '../widgets/admin_allocate_to_agent_modal.dart';
import '../widgets/admin_log_daily_sale_modal.dart';
import '../widgets/admin_manage_agent_custody_modal.dart';
import '../widgets/admin_reallocate_between_agents_modal.dart';

/// Dedicated Warehouse & NovaXpress Master Stock Keeper Console
/// Tailored specifically for Damilare Ajani (`novaxpress_stock_keeper`)
/// to oversee holistic multi-merchant stock, manage DC shelves, allocate inventory
/// to agents (including NovaXpress Logistics), re-allocate stock, and record agent daily sales.
class MasterStockKeeperConsolePage extends ConsumerStatefulWidget {
  const MasterStockKeeperConsolePage({super.key});

  @override
  ConsumerState<MasterStockKeeperConsolePage> createState() =>
      _MasterStockKeeperConsolePageState();
}

class _MasterStockKeeperConsolePageState
    extends ConsumerState<MasterStockKeeperConsolePage> {
  int _currentTab = 0; // 0: Agent Allocation Matrix, 1: DC Shelves & Catalog, 2: Daily Sales Feed, 3: Audit Trail
  String _selectedMerchantFilter = 'all';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(adminConsoleProvider);
    final notifier = ref.read(adminConsoleProvider.notifier);
    final currentUser = ref.watch(authProvider).user;
    final operatorName = currentUser?.fullName.isNotEmpty == true
        ? currentUser!.fullName
        : 'Damilare Ajani';

    // 1. Filter Agents
    final filteredAgents = state.agents.where((agent) {
      if (_selectedMerchantFilter != 'all') {
        final mFilter = _selectedMerchantFilter.toLowerCase();
        final isNovacare = mFilter.contains('nova');
        final assignedMatch = agent.assignedMerchantIds.any((id) => id.toLowerCase() == mFilter) ||
            agent.assignedMerchantNames.any((name) => name.toLowerCase().contains(mFilter));
        final hasStock = agent.heldStock.values.any((q) => q > 0);
        if (!assignedMatch && !hasStock && !isNovacare) {
          return false;
        }
      }
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        final matchesName = agent.name.toLowerCase().contains(q);
        final matchesCode = agent.agentCode.toLowerCase().contains(q);
        final matchesStates = agent.coverageStates.any((s) => s.toLowerCase().contains(q));
        final matchesSkus = agent.heldStock.keys.any((sku) => sku.toLowerCase().contains(q));
        return matchesName || matchesCode || matchesStates || matchesSkus;
      }
      return true;
    }).toList();

    // 2. Filter Global Stock
    final filteredStock = state.globalStock.where((p) {
      if (_selectedMerchantFilter != 'all') {
        final mFilter = _selectedMerchantFilter.toLowerCase();
        if (p.merchantId.toLowerCase() != mFilter && !p.merchantName.toLowerCase().contains(mFilter)) {
          return false;
        }
      }
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        return p.productName.toLowerCase().contains(q) ||
            p.sku.toLowerCase().contains(q) ||
            p.merchantName.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    // 3. Filter Sales Feed
    final filteredSales = state.dailySales.where((s) {
      if (_selectedMerchantFilter != 'all') {
        final mFilter = _selectedMerchantFilter.toLowerCase();
        final matchesId = s.merchantId != null && s.merchantId!.toLowerCase() == mFilter;
        final matchesName = s.merchantName != null && s.merchantName!.toLowerCase().contains(mFilter);
        final isNovacare = mFilter.contains('nova');
        if (!matchesId && !matchesName && !isNovacare) {
          return false;
        }
      }
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        return s.agentName.toLowerCase().contains(q) ||
            s.orderReference.toLowerCase().contains(q) ||
            s.customerName.toLowerCase().contains(q) ||
            s.items.any((i) => i.productName.toLowerCase().contains(q));
      }
      return true;
    }).toList();

    // 4. Calculate Aggregate Bento Metrics
    int totalWarehouseUnits = 0;
    int totalCustodyUnits = 0;
    for (final p in filteredStock) {
      totalWarehouseUnits += p.totalWarehouseStock;
      totalCustodyUnits += p.totalRiderCustodyStock;
    }
    final int totalPlatformUnits = totalWarehouseUnits + totalCustodyUnits;

    // NovaXpress Logistics Fleet Allocation Units
    final nxAgent = state.agents.cast<AdminLogisticsAgent?>().firstWhere(
          (a) => a?.agentCode == 'NX-ABJ-01' || a?.id == 'agent-novaxpress-logistics',
          orElse: () => null,
        );
    final int nxLogisticsUnits = nxAgent?.heldStock.values.fold<int>(0, (sum, v) => sum + v) ?? 0;

    // Today's Sales
    final today = DateTime.now();
    final todaySales = filteredSales.where((s) =>
        s.timestamp.year == today.year && s.timestamp.month == today.month && s.timestamp.day == today.day);
    final int todayUnitsSold = todaySales.fold<int>(0, (sum, s) => sum + s.items.fold<int>(0, (iSum, i) => iSum + i.quantity));
    final double todayRevenue = todaySales.fold<double>(0.0, (sum, s) => sum + s.totalAmount);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top Modern Glassmorphism Bar
            _buildTopBar(context, isDark, operatorName, state, notifier),

            // Merchant Filter Pills Row
            _buildMerchantFilterRow(isDark),

            // Scrollable Main Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => notifier.loadAll(),
                color: const Color(0xFF0D9488),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // NovaXpress Logistics Zero-Stock Alert Banner (if unallocated)
                      if (nxLogisticsUnits == 0)
                        _buildZeroStockAlertBanner(context, isDark, nxAgent),

                      // Bento Grid Metrics
                      _buildBentoKpiGrid(
                        isDark: isDark,
                        totalPlatformUnits: totalPlatformUnits,
                        totalWarehouseUnits: totalWarehouseUnits,
                        totalCustodyUnits: totalCustodyUnits,
                        nxLogisticsUnits: nxLogisticsUnits,
                        todayUnitsSold: todayUnitsSold,
                        todayRevenue: todayRevenue,
                      ),
                      const SizedBox(height: 16),

                      // Fast Actions Bar
                      _buildFastActionBar(context, isDark, nxAgent),
                      const SizedBox(height: 16),

                      // Search & View Tabs
                      _buildSearchAndTabRow(isDark),
                      const SizedBox(height: 16),

                      // Tab Views
                      if (_currentTab == 0)
                        _buildAgentMatrixTab(context, isDark, filteredAgents, operatorName, notifier, state)
                      else if (_currentTab == 1)
                        _buildDcShelvesTab(context, isDark, filteredStock)
                      else if (_currentTab == 2)
                        _buildDailySalesTab(context, isDark, filteredSales)
                      else
                        _buildAuditTrailTab(context, isDark, state.auditLogs),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TOP APP BAR
  // ==========================================
  Widget _buildTopBar(
    BuildContext context,
    bool isDark,
    String operatorName,
    AdminConsoleState state,
    AdminConsoleNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // Profile Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.warehouse_rounded, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 12),

          // User Info & Role Badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        operatorName,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'MASTER STOCK KEEPER',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0D9488),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Abuja Central DC • Multi-Merchant Platform Oversight',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons: Refresh & Logout
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Sync Live Stock',
            onPressed: () => notifier.loadAll(),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20, color: Color(0xFFDC2626)),
            tooltip: 'Logout',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MERCHANT FILTER CHIPS
  // ==========================================
  Widget _buildMerchantFilterRow(bool isDark) {
    final merchants = [
      {'id': 'all', 'name': 'All Merchants'},
      {'id': 'merchant-novacare', 'name': 'Novacare Limited'},
      {'id': 'merchant-shopeleven', 'name': 'Shop Eleven Limited'},
      {'id': 'merchant-leafora', 'name': 'Leafora Wellness'},
    ];

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: merchants.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, idx) {
          final m = merchants[idx];
          final isSelected = _selectedMerchantFilter == m['id'];
          return ChoiceChip(
            label: Text(m['name']!),
            selected: isSelected,
            selectedColor: const Color(0xFF0D9488),
            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            labelStyle: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            onSelected: (val) {
              if (val) setState(() => _selectedMerchantFilter = m['id']!);
            },
          );
        },
      ),
    );
  }

  // ==========================================
  // ZERO-STOCK ALERT BANNER
  // ==========================================
  Widget _buildZeroStockAlertBanner(
    BuildContext context,
    bool isDark,
    AdminLogisticsAgent? nxAgent,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        border: Border.all(color: const Color(0xFFF59E0B)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Awaiting Stock Allocation: NovaXpress Logistics (Internal Fleet)',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'NovaXpress Logistics (NX-ABJ-01) currently has 0 units allocated. Station Stock Ops (Ani Willis) and riders cannot dispatch or fulfill orders until you allocate products from DC shelves.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: const Color(0xFF78350F),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => AdminAllocateToAgentModal.show(
                    context: context,
                    initialAgent: nxAgent,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                  label: Text(
                    'Allocate Stock to NovaXpress Logistics Now',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
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
  // BENTO GRID METRICS RIBBON
  // ==========================================
  Widget _buildBentoKpiGrid({
    required bool isDark,
    required int totalPlatformUnits,
    required int totalWarehouseUnits,
    required int totalCustodyUnits,
    required int nxLogisticsUnits,
    required int todayUnitsSold,
    required double todayRevenue,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        final cardWidth = isWide ? (constraints.maxWidth - 24) / 3 : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            // Card 1: Total Platform Stock
            _buildBentoCard(
              isDark: isDark,
              width: cardWidth,
              title: 'Total Platform Stock',
              value: NumberFormat('#,###').format(totalPlatformUnits),
              unit: 'units',
              subtitle: 'DC Shelves + Agent Custody',
              icon: Icons.inventory_2_rounded,
              color: const Color(0xFF0D9488),
            ),

            // Card 2: Central DC Shelf Available
            _buildBentoCard(
              isDark: isDark,
              width: cardWidth,
              title: 'Central DC Shelves',
              value: NumberFormat('#,###').format(totalWarehouseUnits),
              unit: 'units',
              subtitle: 'Ready in Warehouse Shelves',
              icon: Icons.warehouse_rounded,
              color: const Color(0xFF3B82F6),
            ),

            // Card 3: Total Agent Custody
            _buildBentoCard(
              isDark: isDark,
              width: cardWidth,
              title: 'Partner Agent Custody',
              value: NumberFormat('#,###').format(totalCustodyUnits),
              unit: 'units',
              subtitle: 'Held across 94+ Delivery Partners',
              icon: Icons.local_shipping_rounded,
              color: const Color(0xFF8B5CF6),
            ),

            // Card 4: NovaXpress Logistics Fleet Allocation (Featured Card)
            _buildBentoCard(
              isDark: isDark,
              width: cardWidth,
              title: 'NovaXpress Fleet (NX-ABJ-01)',
              value: NumberFormat('#,###').format(nxLogisticsUnits),
              unit: 'units',
              subtitle: nxLogisticsUnits > 0
                  ? 'Allocated & Ready for Station Ops'
                  : '0 Units (Awaiting Replenishment)',
              icon: Icons.electric_moped_rounded,
              color: nxLogisticsUnits > 0 ? const Color(0xFF059669) : const Color(0xFFF59E0B),
              isAlert: nxLogisticsUnits == 0,
            ),

            // Card 5: Today's Agent Sales
            _buildBentoCard(
              isDark: isDark,
              width: cardWidth,
              title: "Today's Agent Sales",
              value: NumberFormat('#,###').format(todayUnitsSold),
              unit: 'units',
              subtitle: 'Revenue: ${CurrencyFormatter.formatNaira(todayRevenue)}',
              icon: Icons.point_of_sale_rounded,
              color: const Color(0xFF10B981),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBentoCard({
    required bool isDark,
    required double width,
    required String title,
    required String value,
    required String unit,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isAlert = false,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border.all(
          color: isAlert ? color : (isDark ? Colors.white10 : Colors.grey.shade200),
          width: isAlert ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
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
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isAlert ? color : (isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : Colors.black45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: isAlert ? FontWeight.w600 : FontWeight.w400,
              color: isAlert ? color : (isDark ? Colors.white60 : Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // FAST ACTION BUTTONS BAR
  // ==========================================
  Widget _buildFastActionBar(
    BuildContext context,
    bool isDark,
    AdminLogisticsAgent? nxAgent,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FAST ACTIONS',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white60 : Colors.black54,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Action 1: Allocate from DC to Agent
              ElevatedButton.icon(
                onPressed: () => AdminAllocateToAgentModal.show(context: context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                label: Text(
                  'Allocate from DC',
                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),

              // Action 2: Re-allocate Stock Between Agents
              ElevatedButton.icon(
                onPressed: () => AdminReallocateBetweenAgentsModal.show(context: context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: Text(
                  'Re-allocate Between Agents',
                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),

              // Action 3: Log Agent Daily Sales
              ElevatedButton.icon(
                onPressed: () => AdminLogDailySaleModal.show(context: context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.point_of_sale_rounded, size: 16),
                label: Text(
                  'Log Agent Daily Sales',
                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SEARCH & TAB NAVIGATION
  // ==========================================
  Widget _buildSearchAndTabRow(bool isDark) {
    return Column(
      children: [
        // Search Input
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search agent, code, product SKU, or territory...',
            hintStyle: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white38 : Colors.grey),
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {});
                    },
                  )
                : null,
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),

        // Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTabPill(0, 'Agent Custody Matrix', Icons.badge_rounded, isDark),
              const SizedBox(width: 8),
              _buildTabPill(1, 'DC Shelves & SKUs', Icons.warehouse_rounded, isDark),
              const SizedBox(width: 8),
              _buildTabPill(2, 'Daily Sales Ledger', Icons.receipt_long_rounded, isDark),
              const SizedBox(width: 8),
              _buildTabPill(3, 'Audit Trail', Icons.history_rounded, isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabPill(int index, String label, IconData icon, bool isDark) {
    final isSelected = _currentTab == index;
    return InkWell(
      onTap: () => setState(() => _currentTab = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0D9488)
              : (isDark ? const Color(0xFF0F172A) : Colors.white),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D9488) : (isDark ? Colors.white10 : Colors.grey.shade200),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 0: AGENT CUSTODY MATRIX
  // ==========================================
  Widget _buildAgentMatrixTab(
    BuildContext context,
    bool isDark,
    List<AdminLogisticsAgent> agents,
    String operatorName,
    AdminConsoleNotifier notifier,
    AdminConsoleState state,
  ) {
    if (agents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'No matching agents found.',
            style: GoogleFonts.inter(color: isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: agents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, idx) {
        final agent = agents[idx];
        final isNxLogistics = agent.agentCode == 'NX-ABJ-01' || agent.id == 'agent-novaxpress-logistics';
        final totalUnits = agent.heldStock.values.fold(0, (sum, v) => sum + v);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            border: Border.all(
              color: isNxLogistics
                  ? (totalUnits > 0 ? const Color(0xFF0D9488) : const Color(0xFFF59E0B))
                  : (isDark ? Colors.white10 : Colors.grey.shade200),
              width: isNxLogistics ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Agent Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isNxLogistics
                          ? const Color(0xFF0D9488).withValues(alpha: 0.12)
                          : const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isNxLogistics ? Icons.electric_moped_rounded : Icons.local_shipping_rounded,
                      color: isNxLogistics ? const Color(0xFF0D9488) : const Color(0xFF3B82F6),
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
                            Flexible(
                              child: Text(
                                agent.name,
                                style: GoogleFonts.inter(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isNxLogistics
                                    ? const Color(0xFF0D9488).withValues(alpha: 0.15)
                                    : const Color(0xFF3B82F6).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isNxLogistics ? 'INTERNAL FLEET' : '3PL AGENT',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: isNxLogistics ? const Color(0xFF0D9488) : const Color(0xFF3B82F6),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${agent.agentCode} • ${agent.coverageStates.join(", ")} • Contact: ${agent.phone}',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Total Custody Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: totalUnits > 0
                          ? const Color(0xFF0D9488).withValues(alpha: 0.12)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$totalUnits',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: totalUnits > 0 ? const Color(0xFF0D9488) : const Color(0xFFD97706),
                          ),
                        ),
                        Text(
                          'Units in Custody',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: totalUnits > 0 ? const Color(0xFF0D9488) : const Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Stock SKUs Chips / Table
              if (agent.heldStock.isEmpty || totalUnits == 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: isNxLogistics ? const Color(0xFFD97706) : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isNxLogistics
                            ? 'Awaiting Initial Replenishment from DC Shelves (0 Units)'
                            : 'No physical stock currently held in custody.',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: isNxLogistics ? FontWeight.w600 : FontWeight.w400,
                          color: isNxLogistics
                              ? const Color(0xFFD97706)
                              : (isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: agent.heldStock.entries.map((e) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            e.key,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${e.value}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

              const Divider(height: 20),

              // Action Buttons Row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 1. Allocate from DC
                  TextButton.icon(
                    onPressed: () => AdminAllocateToAgentModal.show(
                      context: context,
                      initialAgent: agent,
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0D9488),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 15),
                    label: Text(
                      'Allocate from DC',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),

                  // 2. Transfer / Re-allocate
                  TextButton.icon(
                    onPressed: () => AdminReallocateBetweenAgentsModal.show(
                      context: context,
                      initialSourceAgent: totalUnits > 0 ? agent : null,
                      initialDestinationAgent: totalUnits == 0 ? agent : null,
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF3B82F6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 15),
                    label: Text(
                      'Transfer',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),

                  // 3. Log Daily Sales
                  TextButton.icon(
                    onPressed: () => AdminLogDailySaleModal.show(
                      context: context,
                      initialAgent: agent,
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.point_of_sale_rounded, size: 15),
                    label: Text(
                      'Log Sales',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),

                  // 4. Manual Custody Adjustment
                  IconButton(
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    tooltip: 'Adjust Custody',
                    onPressed: () => AdminManageAgentCustodyModal.show(
                      context: context,
                      agent: agent,
                      catalogProducts: state.globalStock,
                    ),
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
  // TAB 1: DC SHELVES & CATALOG
  // ==========================================
  Widget _buildDcShelvesTab(
    BuildContext context,
    bool isDark,
    List<AdminGlobalStockItem> stockItems,
  ) {
    if (stockItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'No matching products found in warehouse catalog.',
            style: GoogleFonts.inter(color: isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stockItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, idx) {
        final p = stockItems[idx];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.productName,
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '${p.sku} • Merchant: ${p.merchantName} • Price: ${CurrencyFormatter.formatNaira(p.unitPrice)}',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => AdminAllocateToAgentModal.show(
                      context: context,
                      initialSku: p.sku,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 14),
                    label: Text(
                      'Allocate',
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Stock Split Bar (DC Shelves vs Agent Custody)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Central DC Shelf Stock',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${p.totalWarehouseStock} units',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1D4ED8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Partner Agent Custody',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF7C3AED),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${p.totalRiderCustodyStock} units',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF6D28D9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Agent Breakdown List if any
              if (p.agentStockBreakdown.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Agent Custody Breakdown:',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: p.agentStockBreakdown.entries.map((e) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${e.key}: ${e.value} units',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
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
    );
  }

  // ==========================================
  // TAB 2: DAILY SALES FEED
  // ==========================================
  Widget _buildDailySalesTab(
    BuildContext context,
    bool isDark,
    List<AgentDailySaleRecord> sales,
  ) {
    if (sales.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'No agent daily sales records found.',
            style: GoogleFonts.inter(color: isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sales.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) {
        final s = sales[idx];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_rounded, color: Color(0xFF10B981), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          s.orderReference,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatNaira(s.totalAmount),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${s.agentName} (${s.agentCode}) • Customer: ${s.customerName}',
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.items.map((i) => '${i.quantity}x ${i.productName}').join(', '),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM dd, yyyy • hh:mm a').format(s.timestamp),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: isDark ? Colors.white38 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 3: AUDIT TRAIL
  // ==========================================
  Widget _buildAuditTrailTab(
    BuildContext context,
    bool isDark,
    List<AdminAuditLog> auditLogs,
  ) {
    if (auditLogs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'No audit log entries recorded yet.',
            style: GoogleFonts.inter(color: isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: auditLogs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, idx) {
        final log = auditLogs[idx];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF0D9488)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          log.action,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0D9488),
                          ),
                        ),
                        Text(
                          DateFormat('HH:mm:ss').format(log.timestamp),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            color: isDark ? Colors.white38 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      log.details,
                      style: GoogleFonts.inter(fontSize: 11.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Operator: ${log.actorName} • Hub: ${log.distributionCenterName ?? "Abuja Central DC"}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
