import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/widgets/app_loading_overlay.dart';
import '../../../../core/widgets/app_skeleton_loader.dart';
import '../../../../core/widgets/product_image_widget.dart';
import '../../../stock/domain/entities/stock_item.dart';
import '../../../stock/domain/entities/rider_stock_allocation.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../domain/entities/dc_fleet_driver.dart';
import '../providers/dc_console_provider.dart';
import '../providers/product_catalog_provider.dart';
import '../widgets/dc_product_detail_modal.dart';

class DCStockPage extends ConsumerStatefulWidget {
  const DCStockPage({super.key});

  @override
  ConsumerState<DCStockPage> createState() => _DCStockPageState();
}

class _DCStockPageState extends ConsumerState<DCStockPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _pinController = TextEditingController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(stockProvider.notifier).fetchStockItems();
      ref.read(productCatalogProvider.notifier).reloadCatalog();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pinController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dcState = ref.watch(dcConsoleProvider);
    final stockState = ref.watch(stockProvider);

    return Column(
      children: [
        // Sub-Tab Navigation Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: const Color(0xFF2563EB),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF2563EB),
            indicatorWeight: 3,
            labelStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500),
            tabs: [
              Tab(
                icon: const Icon(Icons.dashboard_customize_outlined, size: 17),
                text: 'Master Products & Inventory (${stockState.stockItems.length})',
              ),
              Tab(
                icon: const Icon(Icons.inventory_2_outlined, size: 17),
                text: 'DC Warehouse Stock Batches (${dcState.warehouseBatches.length})',
              ),
              const Tab(
                icon: Icon(Icons.add_box_outlined, size: 17),
                text: 'Bulk Stock Intake (Waybill)',
              ),
              Tab(
                icon: const Icon(Icons.checklist_outlined, size: 17),
                text: 'Rider Picking Queue (${stockState.inboundRequests.length})',
              ),
              const Tab(
                icon: Icon(Icons.qr_code_scanner_rounded, size: 17),
                text: 'Dispatch Handover Counter',
              ),
            ],
          ),
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // 0. Master Products & Connected Stock Inventory
              _buildMasterProductsView(isDark, stockState, dcState),

              // 1. Warehouse Inventory & Bins
              _buildWarehouseBinsView(isDark, dcState),

              // 2. Bulk Stock Intake Form
              _buildBulkIntakeView(isDark),

              // 3. Rider Picking Queue
              _buildPickingQueueView(isDark, stockState),

              // 4. Dispatch Handover Counter
              _buildHandoverCounterView(isDark),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 0: MASTER PRODUCTS & CONNECTED INVENTORY
  // ==========================================
  Widget _buildMasterProductsView(bool isDark, StockState stockState, DCConsoleState dcState) {
    final hasItems = stockState.stockItems.isNotEmpty;
    final isLoading = stockState.isLoading && !hasItems;
    final hasError = stockState.errorMessage != null && !hasItems;
    final isOfflineWithData = stockState.errorMessage != null && hasItems;

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(stockProvider.notifier).fetchStockItems();
        await ref.read(productCatalogProvider.notifier).reloadCatalog();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Offline Warning Notice (if showing cached data during network instability)
            if (isOfflineWithData)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off_rounded, color: Color(0xFFF59E0B), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        stockState.errorMessage!,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => ref.read(stockProvider.notifier).fetchStockItems(),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.refresh_rounded, size: 12, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 4),
                            Text(
                              'Retry Sync',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFF59E0B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // 1. Top 4 Connected KPI Cards (Live or Skeleton)
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

                if (isLoading) {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: List.generate(
                      4,
                      (_) => SizedBox(width: cardWidth, child: const DCKpiCardSkeleton()),
                    ),
                  );
                }

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    // KPI 1: Total DC Stock
                    SizedBox(
                      width: cardWidth,
                      child: _buildStockKpiCard(
                        '📦 Total DC Stock',
                        '${stockState.totalDCStock} Units',
                        'Valuation: ${CurrencyFormatter.formatNaira(stockState.totalDCStockValuation)}',
                        const Color(0xFF2563EB),
                        isDark,
                      ),
                    ),

                    // KPI 2: Warehouse Shelf Stock (In Bins)
                    SizedBox(
                      width: cardWidth,
                      child: _buildStockKpiCard(
                        '🏢 Warehouse Shelf Stock',
                        '${stockState.totalWarehouseAvailable} Units',
                        'Available in DC bins to allocate',
                        const Color(0xFF10B981),
                        isDark,
                      ),
                    ),

                    // KPI 3: In Rider Custody
                    SizedBox(
                      width: cardWidth,
                      child: _buildStockKpiCard(
                        '🛵 In Rider Custody',
                        '${stockState.totalInRiderCustody} Units',
                        'Across all active fleet vehicles',
                        const Color(0xFF8B5CF6),
                        isDark,
                      ),
                    ),

                    // KPI 4: Low Stock Alerts
                    SizedBox(
                      width: cardWidth,
                      child: _buildStockKpiCard(
                        '⚠️ Low Stock Alerts',
                        '${stockState.lowStockCountFiltered} Products',
                        stockState.lowStockCountFiltered > 0 ? 'Requires warehouse restock' : 'All stock levels healthy ✓',
                        stockState.lowStockCountFiltered > 0 ? const Color(0xFFF59E0B) : const Color(0xFF059669),
                        isDark,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // 2. Action Header: Search, Filters & Primary CTA Buttons
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 700;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isNarrow) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Master Products & Stock',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  ref.read(stockProvider.notifier).fetchStockItems();
                                  ref.read(productCatalogProvider.notifier).reloadCatalog();
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                tooltip: 'Refresh Stock',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  isLoading ? '...' : '${stockState.stockItems.length} Products',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showReceiveStockDialog(context, isDark, stockState),
                              icon: const Icon(Icons.arrow_downward_rounded, size: 15, color: Colors.white),
                              label: const Text('Receive Stock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showAddNewProductDialog(context, isDark),
                              icon: const Icon(Icons.add_rounded, size: 15, color: Colors.white),
                              label: const Text('Add Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '📦 Products Master Catalogue',
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    isLoading ? '...' : '${stockState.stockItems.length} Products',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  ref.read(stockProvider.notifier).fetchStockItems();
                                  ref.read(productCatalogProvider.notifier).reloadCatalog();
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                tooltip: 'Refresh Stock & Catalog',
                              ),
                              const SizedBox(width: 4),
                              ElevatedButton.icon(
                                onPressed: () => _showReceiveStockDialog(context, isDark, stockState),
                                icon: const Icon(Icons.arrow_downward_rounded, size: 16, color: Colors.white),
                                label: const Text('Receive Stock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _showAddNewProductDialog(context, isDark),
                                icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                                label: const Text('Add New Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Search Bar & Filter Chips
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _searchController,
                            onChanged: (val) => ref.read(stockProvider.notifier).setSearchQuery(val),
                            decoration: InputDecoration(
                              hintText: 'Search products by name, SKU, category, merchant client...',
                              hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 16),
                                      onPressed: () {
                                        _searchController.clear();
                                        ref.read(stockProvider.notifier).setSearchQuery('');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildStockFilterChip('All (${stockState.stockItems.length})', StockFilter.all, stockState.activeFilter),
                                const SizedBox(width: 8),
                                _buildStockFilterChip('⚠️ Low Stock (${stockState.lowStockCountFiltered})', StockFilter.lowStock, stockState.activeFilter, activeColor: const Color(0xFFF59E0B)),
                                const SizedBox(width: 8),
                                _buildStockFilterChip('✅ Available (${stockState.availableCountFiltered})', StockFilter.available, stockState.activeFilter, activeColor: const Color(0xFF10B981)),
                                const SizedBox(width: 8),
                                _buildStockFilterChip('❌ Out of Stock (${stockState.outOfStockCountFiltered})', StockFilter.outOfStock, stockState.activeFilter, activeColor: const Color(0xFFEF4444)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            // 3. Products List / Skeletons / Network Error / Empty State
            if (isLoading)
              _buildStockSkeletons(isDark)
            else if (hasError)
              _buildNetworkErrorState(stockState.errorMessage!, isDark)
            else if (stockState.filteredStockItems.isEmpty)
              _buildEmptyState(
                _searchController.text.isNotEmpty || stockState.activeFilter != StockFilter.all
                    ? 'No products matched your search/filter criteria.'
                    : 'No products registered in warehouse inventory yet.',
                isDark,
              )
            else
              _buildMasterProductsList(stockState.filteredStockItems, isDark, dcState, stockState),
          ],
        ),
      ),
    );
  }

  Widget _buildStockFilterChip(String label, StockFilter filter, StockFilter activeFilter, {Color? activeColor}) {
    final isSelected = activeFilter == filter;
    final color = activeColor ?? const Color(0xFF2563EB);

    return InkWell(
      onTap: () => ref.read(stockProvider.notifier).setFilter(filter),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF64748B).withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? color : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildMasterProductsList(List<StockItemEntity> items, bool isDark, DCConsoleState dcState, StockState stockState) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 950;

        if (!isDesktop) {
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) => _buildMobileProductCard(items[i], isDark, dcState, stockState),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                showCheckboxColumn: false,
                columnSpacing: 18,
                horizontalMargin: 16,
                headingRowHeight: 44,
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
                  DataColumn(label: Text('CATEGORY & PRICE')),
                  DataColumn(label: Text('IN DC POSSESSION')),
                  DataColumn(label: Text('ASSIGNED TO RIDERS')),
                  DataColumn(label: Text('DELIVERED')),
                  DataColumn(label: Text('COMPLAINTS')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('ACTIONS')),
                ],
                rows: items.map((item) {
                  final inCustody = item.inRiderCustodyCount;

                  return DataRow(
                    onSelectChanged: (_) => _showProductDetailsModal(context, isDark, item, dcState.drivers, stockState.riderAllocations),
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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ProductImageWidget(
                              imageUrl: item.imageAsset,
                              width: 36,
                              height: 36,
                              borderRadius: 8,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  item.ownerName,
                                  style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Category & Price
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.category,
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              CurrencyFormatter.formatNaira(item.price),
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF10B981), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),

                      // In DC Possession
                      DataCell(
                        Row(
                          children: [
                            const Icon(Icons.store_mall_directory_outlined, size: 14, color: Color(0xFF10B981)),
                            const SizedBox(width: 5),
                            Text(
                              '${item.availableCount} Units',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: item.availableCount > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                            ),
                          ],
                        ),
                      ),

                      // In Rider Custody
                      DataCell(
                        Row(
                          children: [
                            const Icon(Icons.two_wheeler_outlined, size: 14, color: Color(0xFF8B5CF6)),
                            const SizedBox(width: 5),
                            Text(
                              '$inCustody Units',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6)),
                            ),
                          ],
                        ),
                      ),

                      // Delivered
                      DataCell(
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF2563EB)),
                            const SizedBox(width: 5),
                            Text(
                              '${item.deliveredCount} Units',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),

                      // Complaints / Damaged
                      DataCell(
                        Row(
                          children: [
                            Icon(Icons.report_problem_outlined, size: 14, color: item.complaintCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF94A3B8)),
                            const SizedBox(width: 5),
                            Text(
                              '${item.complaintCount} Units',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: item.complaintCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Status
                      DataCell(_buildStatusBadge(item)),

                      // Actions
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _showProductDetailsModal(context, isDark, item, dcState.drivers, stockState.riderAllocations),
                              icon: const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
                              tooltip: 'Product Details',
                            ),
                            IconButton(
                              onPressed: () => _showReceiveStockDialog(context, isDark, ref.read(stockProvider), preselectedItem: item),
                              icon: const Icon(Icons.arrow_downward_rounded, size: 16, color: Color(0xFF10B981)),
                              tooltip: 'Receive More Stock',
                            ),
                            IconButton(
                              onPressed: item.availableCount > 0
                                  ? () => _showAssignToRiderDialog(context, isDark, item, dcState.drivers)
                                  : null,
                              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16, color: Color(0xFF2563EB)),
                              tooltip: 'Assign to Rider',
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
      },
    );
  }

  Widget _buildMobileProductCard(StockItemEntity item, bool isDark, DCConsoleState dcState, StockState stockState) {
    final inCustody = item.inRiderCustodyCount;

    return InkWell(
      onTap: () => _showProductDetailsModal(context, isDark, item, dcState.drivers, stockState.riderAllocations),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isLowStock
                ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      item.sku,
                      style: GoogleFonts.firaCode(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        CurrencyFormatter.formatNaira(item.price),
                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(item),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ProductImageWidget(
                  imageUrl: item.imageAsset,
                  width: 48,
                  height: 48,
                  borderRadius: 10,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Company: ${item.ownerName} • ${item.category}',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 4 Live Quantities
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricMiniPill('🏢 In DC Possession', '${item.availableCount} Units', const Color(0xFF10B981)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricMiniPill('🛵 In Rider Custody', '$inCustody Units', const Color(0xFF8B5CF6)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricMiniPill('✅ Delivered', '${item.deliveredCount} Units', const Color(0xFF2563EB)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricMiniPill(
                          '⚠️ Complaints',
                          '${item.complaintCount} Units',
                          item.complaintCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showReceiveStockDialog(context, isDark, ref.read(stockProvider), preselectedItem: item),
                    icon: const Icon(Icons.arrow_downward_rounded, size: 14),
                    label: const Text('Add / Restock', style: TextStyle(fontSize: 11.5)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: item.availableCount > 0
                        ? () => _showAssignToRiderDialog(context, isDark, item, dcState.drivers)
                        : null,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 14, color: Colors.white),
                    label: const Text('Assign to Rider', style: TextStyle(fontSize: 11.5, color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricMiniPill(String title, String value, Color color) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$title: ',
            style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
          ),
          TextSpan(
            text: value,
            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }

  Widget _buildStatusBadge(StockItemEntity item) {
    if (item.availableCount <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'OUT OF STOCK',
          style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFFDC2626)),
        ),
      );
    } else if (item.isLowStock || (item.availableCount <= item.lowStockThreshold)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '⚠️ LOW STOCK (${item.availableCount} LEFT)',
          style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFFD97706)),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'AVAILABLE',
          style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF059669)),
        ),
      );
    }
  }

  void _showProductDetailsModal(
    BuildContext context,
    bool isDark,
    StockItemEntity item,
    List<DCFleetDriver> drivers,
    List<RiderStockAllocation> allAllocations,
  ) {
    final stockState = ref.read(stockProvider);

    DCProductDetailModal.show(
      context,
      item: item,
      drivers: drivers,
      allocations: allAllocations,
      onReceiveMoreStock: () => _showReceiveStockDialog(context, isDark, stockState, preselectedItem: item),
      onAssignToRider: () => _showAssignToRiderDialog(context, isDark, item, drivers),
      onReportDamage: () => _showRecordDamageModal(context, isDark, item, drivers),
    );
  }

  void _showRecordDamageModal(BuildContext context, bool isDark, StockItemEntity item, List<DCFleetDriver> drivers) {
    final Map<String, DCFleetDriver> uniqueDrivers = {};
    for (final d in drivers) {
      uniqueDrivers[d.id] = d;
    }
    final driverList = uniqueDrivers.values.toList();

    final qtyCtrl = TextEditingController(text: '1');
    final reasonCtrl = TextEditingController(text: 'Damaged packaging during transit');
    String selectedRiderId = driverList.isNotEmpty ? driverList.first.id : '';
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.report_problem_rounded, color: Color(0xFFEF4444), size: 22),
              const SizedBox(width: 8),
              Text('Report Damaged / Lost Units', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Product: ${item.name} (${item.sku})', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 12),
                if (driverList.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: (selectedRiderId.isNotEmpty && uniqueDrivers.containsKey(selectedRiderId)) ? selectedRiderId : driverList.first.id,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Reported by Rider'),
                    items: driverList.map((d) {
                      return DropdownMenuItem(
                        value: d.id,
                        child: Text(
                          '${d.name} (${d.driverCode})',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedRiderId = val);
                    },
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Number of Damaged / Lost Units *', hintText: '1'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(labelText: 'Reason / Notes *', hintText: 'Broken bottle, missing seal, etc.'),
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
                  messenger.showSnackBar(const SnackBar(content: Text('⚠️ Please enter a quantity greater than 0.'), backgroundColor: Color(0xFFEF4444)));
                  return;
                }
                final res = await ref.read(stockProvider.notifier).recordComplaintOrDamage(
                      productIdOrSku: item.id,
                      riderId: selectedRiderId,
                      quantity: qty,
                      reason: reasonCtrl.text.trim(),
                    );
                if (ctx.mounted) Navigator.of(ctx).pop();
                messenger.showSnackBar(
                  SnackBar(content: Text(res['message']?.toString() ?? 'Recorded stock issue.'), backgroundColor: const Color(0xFF10B981)),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              child: const Text('Record Issue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockKpiCard(String title, String val, String sub, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
          const SizedBox(height: 6),
          Text(
            val,
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 4),
          Text(sub, style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  // ==========================================
  // DIALOGS & ACTIONS
  // ==========================================

  void _showAddNewProductDialog(BuildContext context, bool isDark) {
    final nameCtrl = TextEditingController();
    final skuCtrl = TextEditingController(text: 'SKU-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');
    final catCtrl = TextEditingController(text: 'Health & Wellness');
    final priceCtrl = TextEditingController(text: '25000');
    final clientCtrl = TextEditingController(text: 'Novacare Limited');
    final initQtyCtrl = TextEditingController(text: '50');
    final lowThreshCtrl = TextEditingController(text: '5');
    final binCtrl = TextEditingController(text: 'BIN-A1-01');
    final descCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    String? selectedImageUrl;
    bool isUploadingImage = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.add_box_rounded, color: Color(0xFF2563EB), size: 22),
              const SizedBox(width: 8),
              Text('Register New Product', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image Upload Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            ProductImageWidget(
                              imageUrl: selectedImageUrl,
                              width: 64,
                              height: 64,
                              borderRadius: 10,
                              fit: BoxFit.cover,
                            ),
                            if (isUploadingImage)
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Product Image / Photo',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                selectedImageUrl != null
                                    ? 'Image attached for stock and catalog'
                                    : 'Upload a clear product photo or select standard',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: isUploadingImage
                                        ? null
                                        : () async {
                                            try {
                                              setDialogState(() => isUploadingImage = true);
                                              final result = await FilePickerPlatform.instance.pickFiles(
                                                type: FileType.image,
                                              );

                                              if (result.isNotEmpty) {
                                                final file = result.first;
                                                final bytes = await file.readAsBytes();

                                                if (bytes.isNotEmpty) {
                                                  final ext = file.extension?.toLowerCase() ?? 'jpg';
                                                  final mimeType = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
                                                  final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.$ext';
                                                  String? uploadedUrl;

                                                  try {
                                                    final supa = Supabase.instance.client;
                                                    await supa.storage.from('products').uploadBinary(
                                                          fileName,
                                                          bytes,
                                                          fileOptions: FileOptions(contentType: mimeType, upsert: true),
                                                        );
                                                    uploadedUrl = supa.storage.from('products').getPublicUrl(fileName);
                                                  } catch (_) {
                                                    try {
                                                      final supa = Supabase.instance.client;
                                                      await supa.storage.from('avatars').uploadBinary(
                                                            fileName,
                                                            bytes,
                                                            fileOptions: FileOptions(contentType: mimeType, upsert: true),
                                                          );
                                                      uploadedUrl = supa.storage.from('avatars').getPublicUrl(fileName);
                                                    } catch (_) {
                                                      uploadedUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
                                                    }
                                                  }

                                                  setDialogState(() {
                                                    selectedImageUrl = uploadedUrl;
                                                    isUploadingImage = false;
                                                  });
                                                } else {
                                                  setDialogState(() => isUploadingImage = false);
                                                }
                                              } else {
                                                setDialogState(() => isUploadingImage = false);
                                              }
                                            } catch (e) {
                                              setDialogState(() => isUploadingImage = false);
                                              messenger.showSnackBar(
                                                SnackBar(content: Text('⚠️ Image selection error: $e'), backgroundColor: const Color(0xFFEF4444)),
                                              );
                                            }
                                          },
                                    icon: const Icon(Icons.cloud_upload_rounded, size: 14, color: Colors.white),
                                    label: Text(
                                      selectedImageUrl != null ? 'Change Photo' : 'Upload Image',
                                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  if (selectedImageUrl != null)
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        setDialogState(() => selectedImageUrl = null);
                                      },
                                      icon: const Icon(Icons.close_rounded, size: 13, color: Color(0xFFEF4444)),
                                      label: const Text('Remove', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        side: const BorderSide(color: Color(0xFFEF4444)),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Product Name *', hintText: 'e.g. Respira Detox Tea')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: skuCtrl, decoration: const InputDecoration(labelText: 'SKU / Barcode Code *'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Category'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Selling Price (₦) *'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: clientCtrl, decoration: const InputDecoration(labelText: 'Merchant Client'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: initQtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Initial Shelf Stock (Units)'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: lowThreshCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Low Stock Alert Threshold'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: binCtrl, decoration: const InputDecoration(labelText: 'Warehouse Storage Bin Tag (e.g. BIN-A1-01)')),
                  const SizedBox(height: 12),
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Product Description (Optional)')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isUploadingImage
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final sku = skuCtrl.text.trim();
                      if (name.isEmpty || sku.isEmpty) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('⚠️ Product Name and SKU are required.'), backgroundColor: Color(0xFFEF4444)),
                        );
                        return;
                      }

                      final price = double.tryParse(priceCtrl.text.replaceAll(',', '')) ?? 0.0;
                      final qty = int.tryParse(initQtyCtrl.text) ?? 0;
                      final threshold = int.tryParse(lowThreshCtrl.text) ?? 3;
                      final binTag = binCtrl.text.trim().isNotEmpty ? binCtrl.text.trim() : 'BIN-A1-01';

                      try {
                        final created = await showAppLoadingDialog<StockItemEntity>(
                          context: ctx,
                          message: 'Registering New Product...',
                          subMessage: 'Syncing catalogue, SKU database & initial shelf inventory...',
                          isDark: isDark,
                          task: () async {
                            // Check for duplicate SKU in existing stock catalogue
                            final existingItem = ref.read(stockProvider).stockItems.where(
                                  (i) => i.sku.trim().toLowerCase() == sku.toLowerCase(),
                                ).firstOrNull;
                            if (existingItem != null) {
                              throw Exception("A product with SKU '$sku' already exists (${existingItem.name}). Please use a unique SKU code.");
                            }

                            final product = await ref.read(stockProvider.notifier).addNewProduct(
                                  name: name,
                                  sku: sku,
                                  category: catCtrl.text.trim(),
                                  price: price,
                                  ownerName: clientCtrl.text.trim(),
                                  initialQuantity: qty,
                                  lowStockThreshold: threshold,
                                  binLocation: binTag,
                                  description: descCtrl.text.trim(),
                                  imageAsset: selectedImageUrl,
                                );

                            // Also create corresponding warehouse batch
                            ref.read(dcConsoleProvider.notifier).addBatch(
                                  DCWarehouseBatch(
                                    id: 'batch_${DateTime.now().millisecondsSinceEpoch}',
                                    batchCode: 'LOT-${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
                                    productName: product.name,
                                    sku: product.sku,
                                    clientName: product.ownerName,
                                    waybillNumber: 'INIT-INTAKE',
                                    initialQuantity: qty,
                                    currentQuantity: qty,
                                    allocatedQuantity: 0,
                                    binLocation: binTag,
                                    manufactureDate: DateTime.now(),
                                    expiryDate: DateTime.now().add(const Duration(days: 365)),
                                  ),
                                );

                            // Immediately sync newly created product into the product catalog
                            ref.read(productCatalogProvider.notifier).syncFromStockItems([product]);

                            return product;
                          },
                        );

                        if (created != null) {
                          // Close the creation modal
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                          }
                          // Show rich Success Modal
                          if (context.mounted) {
                            _showProductCreationSuccessModal(
                              context: context,
                              isDark: isDark,
                              product: created,
                              initialQty: qty,
                              binTag: binTag,
                            );
                          }
                        }
                      } catch (e) {
                        var reason = e.toString();
                        if (reason.startsWith('Exception: ')) {
                          reason = reason.substring(11);
                        }
                        if (reason.contains('SocketException') || reason.contains('Failed host lookup') || reason.contains('ClientException')) {
                          reason = 'Network connection error: Unable to communicate with the database. Please verify your internet connection.';
                        }

                        if (ctx.mounted) {
                          _showProductCreationFailureModal(
                            context: ctx,
                            isDark: isDark,
                            reason: reason,
                            productName: name,
                            sku: sku,
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: const Text('Save & Register Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductCreationSuccessModal({
    required BuildContext context,
    required bool isDark,
    required StockItemEntity product,
    required int initialQty,
    required String binTag,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon Badge
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Product Registered Successfully!',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'The product has been enrolled in the master catalogue and assigned warehouse shelf inventory.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Product Info Summary Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        ProductImageWidget(
                          imageUrl: product.imageAsset,
                          width: 48,
                          height: 48,
                          borderRadius: 8,
                          fit: BoxFit.cover,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                product.category.isNotEmpty ? product.category : 'Health & Wellness',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    _buildConfirmationRow('SKU / Code:', product.sku, isDark, isBold: true),
                    const SizedBox(height: 6),
                    _buildConfirmationRow('Selling Price:', CurrencyFormatter.formatNaira(product.price), isDark, valueColor: const Color(0xFFF37021)),
                    const SizedBox(height: 6),
                    _buildConfirmationRow('Initial Shelf Stock:', '+$initialQty Units', isDark, isBold: true, valueColor: const Color(0xFF10B981)),
                    const SizedBox(height: 6),
                    _buildConfirmationRow('Warehouse Storage Bin:', binTag, isDark),
                    const SizedBox(height: 6),
                    _buildConfirmationRow('Merchant Client:', product.ownerName, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
              label: const Text(
                'Back to Product List',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProductCreationFailureModal({
    required BuildContext context,
    required bool isDark,
    required String reason,
    required String productName,
    required String sku,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error Icon Badge
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFEF4444),
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Product Registration Failed',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'We were unable to register "$productName" ($sku).',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Reason Callout Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reason / Diagnosis:',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            reason,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your input fields are preserved. You can review your details and try again.',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              icon: const Icon(Icons.edit_note_rounded, size: 16, color: Colors.white),
              label: const Text(
                'Back to Product Details',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReceiveStockDialog(BuildContext context, bool isDark, StockState stockState, {StockItemEntity? preselectedItem}) {
    // Deduplicate stock items and ensure preselectedItem is registered
    final Map<String, StockItemEntity> uniqueMap = {};
    for (final it in stockState.stockItems) {
      uniqueMap[it.id] = it;
    }
    if (preselectedItem != null) {
      uniqueMap[preselectedItem.id] = preselectedItem;
    }
    final itemsList = uniqueMap.values.toList();

    String? selectedProdId;
    if (preselectedItem != null && uniqueMap.containsKey(preselectedItem.id)) {
      selectedProdId = preselectedItem.id;
    } else if (itemsList.isNotEmpty) {
      selectedProdId = itemsList.first.id;
    }

    final qtyCtrl = TextEditingController(text: '50');
    final waybillCtrl = TextEditingController(text: 'WB-${DateTime.now().year}-${(DateTime.now().millisecondsSinceEpoch % 10000)}');
    final binCtrl = TextEditingController(text: preselectedItem?.binLocation ?? 'BIN-A1-02');
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.arrow_downward_rounded, color: Color(0xFF10B981), size: 22),
              const SizedBox(width: 8),
              Text('Receive Incoming Stock', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (itemsList.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: (selectedProdId != null && uniqueMap.containsKey(selectedProdId)) ? selectedProdId : itemsList.first.id,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Select Product to Restock *'),
                      items: itemsList.map((p) {
                        return DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            '${p.name} (${p.sku}) • Avail: ${p.availableCount}',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedProdId = val);
                        }
                      },
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity Received (Units) *', hintText: 'e.g. 50'),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: waybillCtrl, decoration: const InputDecoration(labelText: 'Inbound Waybill Reference *')),
                  const SizedBox(height: 12),
                  TextField(controller: binCtrl, decoration: const InputDecoration(labelText: 'Target Warehouse Storage Bin Tag')),
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
                    const SnackBar(content: Text('⚠️ Please enter a valid quantity greater than 0.'), backgroundColor: Color(0xFFEF4444)),
                  );
                  return;
                }

                final targetProd = (selectedProdId != null ? uniqueMap[selectedProdId] : null) ?? (itemsList.isNotEmpty ? itemsList.first : null);
                if (targetProd == null) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('⚠️ No product selected to restock.'), backgroundColor: Color(0xFFEF4444)),
                  );
                  return;
                }

                // Explicit secondary confirmation dialog with double-tap protection
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
                              child: const Icon(Icons.verified_outlined, color: Color(0xFF10B981), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Confirm Stock Intake',
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
                                'Please verify incoming pallet details to prevent accidental duplicate entries:',
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
                                    _buildConfirmationRow('Product:', targetProd.name, isDark),
                                    const SizedBox(height: 6),
                                    _buildConfirmationRow('SKU / Code:', targetProd.sku, isDark),
                                    const SizedBox(height: 6),
                                    _buildConfirmationRow('Inbound Waybill:', waybillCtrl.text.trim().isNotEmpty ? waybillCtrl.text.trim() : 'N/A', isDark),
                                    const SizedBox(height: 6),
                                    _buildConfirmationRow('Target Bin Tag:', binCtrl.text.trim().isNotEmpty ? binCtrl.text.trim() : 'BIN-A1-02', isDark),
                                    const Divider(height: 16),
                                    _buildConfirmationRow(
                                      'Units to Receive:',
                                      '+$qty Units',
                                      isDark,
                                      isBold: true,
                                      valueColor: const Color(0xFF10B981),
                                    ),
                                    const SizedBox(height: 4),
                                    _buildConfirmationRow(
                                      'New Shelf Balance:',
                                      '${targetProd.availableCount + qty} Units',
                                      isDark,
                                      valueColor: const Color(0xFF2563EB),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '⚠️ Double-tap protection enabled. Once confirmed, this will immediately register into DC warehouse batches.',
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
                                    final success = await showAppLoadingDialog(
                                      context: confirmCtx,
                                      message: 'Recording Inbound Stock Intake...',
                                      subMessage: 'Registering $qty units into warehouse shelf & batch logs...',
                                      isDark: isDark,
                                      task: () async {
                                        final ok = await ref.read(stockProvider.notifier).receiveStock(
                                              productIdOrSku: targetProd.id,
                                              quantity: qty,
                                              waybillNumber: waybillCtrl.text.trim(),
                                              binLocation: binCtrl.text.trim(),
                                            );
                                        if (ok) {
                                          ref.read(dcConsoleProvider.notifier).addBatch(
                                                DCWarehouseBatch(
                                                  id: 'batch_${DateTime.now().millisecondsSinceEpoch}',
                                                  batchCode: 'LOT-${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
                                                  productName: targetProd.name,
                                                  sku: targetProd.sku,
                                                  clientName: targetProd.ownerName,
                                                  waybillNumber: waybillCtrl.text.trim(),
                                                  initialQuantity: qty,
                                                  currentQuantity: qty,
                                                  allocatedQuantity: 0,
                                                  binLocation: binCtrl.text.trim().isNotEmpty ? binCtrl.text.trim() : 'BIN-A1-02',
                                                  manufactureDate: DateTime.now(),
                                                  expiryDate: DateTime.now().add(const Duration(days: 365)),
                                                ),
                                              );
                                        }
                                        return ok;
                                      },
                                    );

                                    if (success == true) {
                                      if (confirmCtx.mounted) Navigator.of(confirmCtx).pop();
                                      if (ctx.mounted) Navigator.of(ctx).pop();
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('✅ Successfully received $qty units of ${targetProd.name} into warehouse!'),
                                          backgroundColor: const Color(0xFF10B981),
                                        ),
                                      );
                                    } else {
                                      setConfirmState(() => isSubmitting = false);
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('❌ Failed to record incoming stock. Please check network connection.'),
                                          backgroundColor: Color(0xFFEF4444),
                                        ),
                                      );
                                    }
                                  },
                            icon: isSubmitting
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                            label: Text(
                              isSubmitting ? 'Receiving...' : 'Yes, Confirm & Add $qty Units',
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
              child: const Text('Confirm Inbound Receipt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignToRiderDialog(BuildContext context, bool isDark, StockItemEntity item, List<DCFleetDriver> drivers) {
    final Map<String, DCFleetDriver> uniqueDrivers = {};
    for (final d in drivers) {
      uniqueDrivers[d.id] = d;
    }
    final driverList = uniqueDrivers.values.toList();

    if (driverList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ No active riders available to assign stock.'), backgroundColor: Color(0xFFEF4444)),
      );
      return;
    }

    String selectedRiderId = driverList.first.id;
    final qtyCtrl = TextEditingController(text: item.availableCount > 0 ? (item.availableCount >= 5 ? '5' : '1') : '0');
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.two_wheeler_rounded, color: Color(0xFF2563EB), size: 22),
              const SizedBox(width: 8),
              Text('Assign Stock to Rider', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2_rounded, color: Color(0xFF2563EB), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('SKU: ${item.sku} • Warehouse Available: ${item.availableCount} Units', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: uniqueDrivers.containsKey(selectedRiderId) ? selectedRiderId : driverList.first.id,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Select Dispatch Rider *'),
                    items: driverList.map((d) {
                      return DropdownMenuItem(
                        value: d.id,
                        child: Text(
                          '${d.name} (${d.driverCode}) • ${d.assignedZone}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedRiderId = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantity to Transfer (Units) *',
                      helperText: 'Max available in warehouse: ${item.availableCount} units',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildQuickQtyButton('+1', () => qtyCtrl.text = '1'),
                      _buildQuickQtyButton('+5', () => qtyCtrl.text = '5'),
                      _buildQuickQtyButton('+10', () => qtyCtrl.text = '10'),
                      _buildQuickQtyButton('All (${item.availableCount})', () => qtyCtrl.text = '${item.availableCount}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final qty = int.tryParse(qtyCtrl.text) ?? 0;
                if (qty <= 0) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('⚠️ Please enter a quantity greater than 0.'), backgroundColor: Color(0xFFEF4444)),
                  );
                  return;
                }

                if (qty > item.availableCount) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('⚠️ Cannot transfer $qty units. Only ${item.availableCount} units available in warehouse.'), backgroundColor: const Color(0xFFEF4444)),
                  );
                  return;
                }

                final targetDriver = uniqueDrivers[selectedRiderId] ?? driverList.first;

                // Explicit secondary confirmation modal with double-tap protection & universal loading overlay
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
                                'Confirm Vehicle Transfer',
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
                                'Confirm physical handover of stock units to the assigned fleet driver:',
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
                                    _buildConfirmationRow('Product:', item.name, isDark),
                                    const SizedBox(height: 6),
                                    _buildConfirmationRow('Rider Recipient:', '${targetDriver.name} (${targetDriver.driverCode})', isDark),
                                    const SizedBox(height: 6),
                                    _buildConfirmationRow('Assigned Zone:', targetDriver.assignedZone, isDark),
                                    const Divider(height: 16),
                                    _buildConfirmationRow(
                                      'Units to Hand Over:',
                                      '$qty Units',
                                      isDark,
                                      isBold: true,
                                      valueColor: const Color(0xFF2563EB),
                                    ),
                                    const SizedBox(height: 4),
                                    _buildConfirmationRow(
                                      'Remaining Shelf Stock:',
                                      '${item.availableCount - qty} Units',
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
                                      message: 'Transferring Stock to Vehicle...',
                                      subMessage: 'Assigning custody to ${targetDriver.name} (${targetDriver.driverCode})...',
                                      isDark: isDark,
                                      task: () => ref.read(stockProvider.notifier).assignStockToRider(
                                            productIdOrSku: item.id,
                                            riderId: targetDriver.id,
                                            riderName: targetDriver.name,
                                            riderCode: targetDriver.driverCode,
                                            quantity: qty,
                                          ),
                                    );

                                    if (res?['success'] == true) {
                                      if (confirmCtx.mounted) Navigator.of(confirmCtx).pop();
                                      if (ctx.mounted) Navigator.of(ctx).pop();
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(res?['message']?.toString() ?? '✅ Stock assigned to ${targetDriver.name}!'),
                                          backgroundColor: const Color(0xFF10B981),
                                        ),
                                      );
                                    } else {
                                      setConfirmState(() => isSubmitting = false);
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(res?['message']?.toString() ?? '❌ Failed to transfer stock.'),
                                          backgroundColor: const Color(0xFFEF4444),
                                        ),
                                      );
                                    }
                                  },
                            icon: isSubmitting
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                            label: Text(
                              isSubmitting ? 'Transferring...' : 'Yes, Transfer $qty Units',
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Confirm Transfer to Vehicle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickQtyButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
      ),
    );
  }

  Widget _buildEmptyState(String msg, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: const Color(0xFF64748B).withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(msg, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _buildStockSkeletons(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 950;

        if (!isDesktop) {
          return const Column(
            children: [
              DCProductCardSkeleton(),
              DCProductCardSkeleton(),
              DCProductCardSkeleton(),
            ],
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: const Column(
            children: [
              DCProductTableRowSkeleton(),
              DCProductTableRowSkeleton(),
              DCProductTableRowSkeleton(),
              DCProductTableRowSkeleton(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNetworkErrorState(String errorMsg, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.1 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: Color(0xFFEF4444),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Network Connection & Sync Issue',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Text(
              'Unable to establish a real-time connection with NovaXpress inventory servers. Check your network or Wi-Fi connectivity and try refreshing.',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    errorMsg,
                    style: GoogleFonts.firaCode(
                      fontSize: 11,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(stockProvider.notifier).fetchStockItems();
                  ref.read(productCatalogProvider.notifier).reloadCatalog();
                },
                icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                label: const Text(
                  'Retry Connection & Sync Stock',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(productCatalogProvider.notifier).reloadCatalog();
                  ref.read(stockProvider.notifier).fetchStockItems();
                },
                icon: const Icon(Icons.cached_rounded, size: 16, color: Color(0xFF64748B)),
                label: Text(
                  'Reload Catalog',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationRow(String label, String value, bool isDark, {bool isBold = false, Color? valueColor}) {
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
  // TAB 1: WAREHOUSE STORAGE BINS & BATCHES
  // ==========================================
  Widget _buildWarehouseBinsView(bool isDark, DCConsoleState dcState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Warehouse Storage Bins & Lot Batches',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _tabController.animateTo(2),
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: const Text('Intake Shipment', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 420,
              mainAxisExtent: 230,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: dcState.warehouseBatches.length,
            itemBuilder: (ctx, i) {
              final batch = dcState.warehouseBatches[i];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B192C),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            batch.binLocation,
                            style: GoogleFonts.firaCode(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
                          ),
                        ),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Expires in ${batch.daysUntilExpiry}d',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(batch.productName, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                        Text('Batch: ${batch.batchCode} • ${batch.clientName}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: _buildMetricMini('Current Units', '${batch.currentQuantity}')),
                        Expanded(child: _buildMetricMini('Allocated', '${batch.allocatedQuantity}')),
                        Expanded(child: _buildMetricMini('Available', '${batch.availableQuantity}', isGreen: true)),
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

  Widget _buildMetricMini(String label, String val, {bool isGreen = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
        Text(
          val,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isGreen ? const Color(0xFF10B981) : null,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: BULK STOCK INTAKE (WAYBILL)
  // ==========================================
  Widget _buildBulkIntakeView(bool isDark) {
    final waybillCtrl = TextEditingController(text: 'WAY-2026-0820');
    final qtyCtrl = TextEditingController(text: '500');
    final binCtrl = TextEditingController(text: 'BIN-C3-01');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 650),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bulk Stock Intake & Waybill Receiving', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Record incoming pallets from merchants and generate warehouse bin barcodes', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
              const SizedBox(height: 20),
              TextField(controller: waybillCtrl, decoration: const InputDecoration(labelText: 'Inbound Waybill Reference')),
              const SizedBox(height: 14),
              TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity Received (Units)')),
              const SizedBox(height: 14),
              TextField(controller: binCtrl, decoration: const InputDecoration(labelText: 'Assigned Storage Bin Tag (e.g. BIN-C3-01)')),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Waybill intake registered. Warehouse barcode label printed.')),
                  );
                  _tabController.animateTo(1);
                },
                icon: const Icon(Icons.print_rounded, color: Colors.white),
                label: const Text('Save & Print Bin Label', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: RIDER PICKING QUEUE (REQ)
  // ==========================================
  Widget _buildPickingQueueView(bool isDark, StockState stockState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rider Restock Picking Queue', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(radius: 16, backgroundColor: Color(0xFF2563EB), child: Icon(Icons.person, color: Colors.white, size: 16)),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('REQ-00482 • Replenishment Handover', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                            Text('Requested: 20x Respira Detox Tea, 10x Grazer Herbal Tea', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12)),
                      child: Text('Ready for Collection', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFD97706))),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(onPressed: () {}, child: const Text('Print Picking Ticket')),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Handover PIN (HND-9921) generated and sent to rider.')),
                        );
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                      child: const Text('Approve & Generate Handover PIN', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: DISPATCH HANDOVER COUNTER
  // ==========================================
  Widget _buildHandoverCounterView(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 550),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Text('Dispatch Counter Handover Desk', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Scan rider QR code or enter Handover PIN (e.g. HND-9921)', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
              const SizedBox(height: 24),
              TextField(
                controller: _pinController,
                textAlign: TextAlign.center,
                style: GoogleFonts.firaCode(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4),
                decoration: const InputDecoration(
                  hintText: 'HND-9921',
                  labelText: 'Handover PIN',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(stockProvider.notifier).completeStockHandover('REQ-00482');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Physical stock handover verified! +30 units transferred to vehicle custody.'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                label: const Text('Confirm Physical Handover & Transfer Custody', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
