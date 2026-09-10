import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/product_image_widget.dart';
import '../../../dc_console/domain/entities/product_package.dart';
import '../../../dc_console/presentation/providers/product_catalog_provider.dart';
import '../providers/client_portal_provider.dart';
import '../widgets/client_add_product_modal.dart';
import '../widgets/client_create_order_modal.dart';
import '../widgets/client_product_detail_modal.dart';
import '../widgets/client_supply_stock_modal.dart';

class ClientProductsPage extends ConsumerStatefulWidget {
  const ClientProductsPage({super.key});

  @override
  ConsumerState<ClientProductsPage> createState() => _ClientProductsPageState();
}

class _ClientProductsPageState extends ConsumerState<ClientProductsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All Categories';
  String _selectedStockFilter = 'All Inventory';
  String _selectedSortBy = 'Name (A-Z)';
  bool? _userPreferredIsTable;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_searchQuery != _searchController.text) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddProductDialog() {
    ClientAddProductModal.show(context);
  }

  void _openProductDetail(CatalogProduct product, {int initialTabIndex = 0}) {
    ClientProductDetailModal.show(context, product: product, initialTabIndex: initialTabIndex);
  }

  @override
  Widget build(BuildContext context) {
    final catalogState = ref.watch(productCatalogProvider);
    final state = ref.watch(clientPortalProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final rawProducts = catalogState.products.isNotEmpty ? catalogState.products : state.products;

    // Precompute product sales & metrics map for fast access and sorting
    final Map<String, _ProductMetrics> metricsMap = {};
    int grandUnitsSold = 0;
    double grandDeliveredRevenue = 0.0;
    int grandHubStock = 0;
    int grandDealsCount = 0;

    for (final product in rawProducts) {
      final packages = catalogState.getPackagesForProduct(product.name);
      grandDealsCount += packages.length;
      grandHubStock += product.totalStockAcrossHubs;

      final productOrders = state.orders.where((o) {
        final matchName = o.productName.trim().toLowerCase() == product.name.trim().toLowerCase();
        final matchSku = o.productSku != null &&
            o.productSku!.trim().isNotEmpty &&
            product.sku.isNotEmpty &&
            o.productSku!.trim().toLowerCase() == product.sku.trim().toLowerCase();
        return matchName || matchSku;
      }).toList();

      final deliveredOrders = productOrders.where((o) {
        final s = o.status.toLowerCase();
        return s == 'delivered' || s == 'completed';
      }).toList();

      final unitsSold = deliveredOrders.fold<int>(
        0,
        (sum, o) => sum + (o.quantity > 0 ? o.quantity : 1),
      );

      final revenue = deliveredOrders.fold<double>(
        0.0,
        (sum, o) => sum + o.totalAmount,
      );

      final inTransit = productOrders.where((o) {
        final s = o.status.toLowerCase();
        return s == 'in_transit' || s == 'out_for_delivery' || s == 'accepted';
      }).length;

      grandUnitsSold += unitsSold;
      grandDeliveredRevenue += revenue;

      metricsMap[product.id.isNotEmpty ? product.id : product.name] = _ProductMetrics(
        unitsSold: unitsSold,
        revenue: revenue,
        inTransitCount: inTransit,
        packagesCount: packages.length,
      );
    }

    // Extract dynamic categories
    final categories = <String>{'All Categories'};
    for (final p in rawProducts) {
      if (p.category.trim().isNotEmpty) {
        categories.add(p.category.trim());
      }
    }

    // Filter products
    List<CatalogProduct> filtered = rawProducts.where((p) {
      // Search filter
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchName = p.name.toLowerCase().contains(q);
        final matchSku = p.sku.toLowerCase().contains(q);
        final matchCategory = p.category.toLowerCase().contains(q);
        if (!matchName && !matchSku && !matchCategory) return false;
      }

      // Category filter
      if (_selectedCategory != 'All Categories') {
        if (p.category.trim().toLowerCase() != _selectedCategory.toLowerCase()) {
          return false;
        }
      }

      // Stock status filter
      if (_selectedStockFilter == 'In Stock (> 0)') {
        if (p.totalStockAcrossHubs <= 0) return false;
      } else if (_selectedStockFilter == 'Out of Stock (0)') {
        if (p.totalStockAcrossHubs > 0) return false;
      }

      return true;
    }).toList();

    // Sort products
    filtered.sort((a, b) {
      final keyA = a.id.isNotEmpty ? a.id : a.name;
      final keyB = b.id.isNotEmpty ? b.id : b.name;
      final mA = metricsMap[keyA] ?? const _ProductMetrics();
      final mB = metricsMap[keyB] ?? const _ProductMetrics();

      switch (_selectedSortBy) {
        case 'Name (Z-A)':
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case 'Units Sold (High to Low)':
          return mB.unitsSold.compareTo(mA.unitsSold);
        case 'Revenue (High to Low)':
          return mB.revenue.compareTo(mA.revenue);
        case 'Stock (High to Low)':
          return b.totalStockAcrossHubs.compareTo(a.totalStockAcrossHubs);
        case 'Stock (Low to High)':
          return a.totalStockAcrossHubs.compareTo(b.totalStockAcrossHubs);
        case 'Price (High to Low)':
          return b.defaultUnitPrice.compareTo(a.defaultUnitPrice);
        case 'Price (Low to High)':
          return a.defaultUnitPrice.compareTo(b.defaultUnitPrice);
        case 'Name (A-Z)':
        default:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 768;
        // Default to Data Table on desktop, Cards on mobile (unless user made explicit choice)
        final isTableView = _userPreferredIsTable ?? isDesktop;

        return RefreshIndicator(
          onRefresh: () => ref.read(clientPortalProvider.notifier).loadClientData(),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            children: [
              // 1. Header Bar
              _buildTopHeader(isDark),
              const SizedBox(height: 18),

              // 2. Executive Product KPIs Row
              _buildKpiRow(
                totalProducts: rawProducts.length,
                grandUnitsSold: grandUnitsSold,
                grandDeliveredRevenue: grandDeliveredRevenue,
                grandHubStock: grandHubStock,
                grandDealsCount: grandDealsCount,
                isDark: isDark,
                isDesktop: isDesktop,
              ),
              const SizedBox(height: 20),

              // 3. Search, Filter, Sort & View Mode Switcher
              _buildToolbar(
                categories: categories.toList(),
                isDark: isDark,
                isDesktop: isDesktop,
                isTableView: isTableView,
              ),
              const SizedBox(height: 18),

              // 4. Products Presentation (Data Table or Cards)
              if (rawProducts.isEmpty)
                _buildEmptyCatalog(isDark)
              else if (filtered.isEmpty)
                _buildEmptySearchResults(isDark)
              else if (isTableView)
                _buildDataTable(filtered, metricsMap, catalogState, isDark)
              else
                _buildCardView(filtered, metricsMap, catalogState, isDark, constraints.maxWidth),
            ],
          ),
        );
      },
    );
  }

  // --- 1. Top Header ---
  Widget _buildTopHeader(bool isDark) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF37021).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2_rounded, size: 20, color: Color(0xFFF37021)),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Products & Catalog Management',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Track product performance, regional hub stock, and manage promotional deal packages',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF37021),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          onPressed: _showAddProductDialog,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(
            'Add Product',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  // --- 2. Executive Product KPIs Row ---
  Widget _buildKpiRow({
    required int totalProducts,
    required int grandUnitsSold,
    required double grandDeliveredRevenue,
    required int grandHubStock,
    required int grandDealsCount,
    required bool isDark,
    required bool isDesktop,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = 5;
        if (width < 600) {
          crossAxisCount = 2;
        } else if (width < 960) {
          crossAxisCount = 3;
        }

        final cards = [
          _KpiItem(
            title: 'Catalog Products',
            value: '$totalProducts',
            subtitle: 'SKUs in registry',
            icon: Icons.category_rounded,
            color: const Color(0xFF2563EB),
          ),
          _KpiItem(
            title: 'Delivered Units',
            value: '$grandUnitsSold',
            subtitle: 'Units sold & fulfilled',
            icon: Icons.local_fire_department_rounded,
            color: const Color(0xFFF37021),
          ),
          _KpiItem(
            title: 'Delivered Revenue',
            value: '₦${Formatters.currency(grandDeliveredRevenue)}',
            subtitle: 'Total sales volume',
            icon: Icons.payments_rounded,
            color: const Color(0xFF10B981),
          ),
          _KpiItem(
            title: 'Hub Shelf Stock',
            value: '$grandHubStock units',
            subtitle: 'Across regional hubs',
            icon: Icons.warehouse_rounded,
            color: const Color(0xFF8B5CF6),
          ),
          _KpiItem(
            title: 'Package Deals',
            value: '$grandDealsCount deals',
            subtitle: 'Configured bundles',
            icon: Icons.local_offer_rounded,
            color: const Color(0xFFEC4899),
          ),
        ];

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards.map((item) {
            final cardWidth = (width - (12 * (crossAxisCount - 1))) / crossAxisCount - 0.5;
            return Container(
              width: cardWidth.clamp(140, 400),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151D36) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(item.icon, size: 20, color: item.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.value,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          item.subtitle,
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
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // --- 3. Toolbar (Search, Filter, Sort, View Mode) ---
  Widget _buildToolbar({
    required List<String> categories,
    required bool isDark,
    required bool isDesktop,
    required bool isTableView,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D36) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search box
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 200, maxWidth: 320),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Search product name, SKU...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                filled: true,
                fillColor: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFF37021), width: 1.5),
                ),
              ),
            ),
          ),

          // Filters & Sort Controls
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Category Filter Dropdown
              _buildDropdown(
                value: _selectedCategory,
                items: categories,
                icon: Icons.filter_list_rounded,
                isDark: isDark,
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),

              // Stock Status Filter Dropdown
              _buildDropdown(
                value: _selectedStockFilter,
                items: const ['All Inventory', 'In Stock (> 0)', 'Out of Stock (0)'],
                icon: Icons.warehouse_outlined,
                isDark: isDark,
                onChanged: (val) {
                  if (val != null) setState(() => _selectedStockFilter = val);
                },
              ),

              // Sort Dropdown
              _buildDropdown(
                value: _selectedSortBy,
                items: const [
                  'Name (A-Z)',
                  'Name (Z-A)',
                  'Units Sold (High to Low)',
                  'Revenue (High to Low)',
                  'Stock (High to Low)',
                  'Stock (Low to High)',
                  'Price (High to Low)',
                  'Price (Low to High)',
                ],
                icon: Icons.sort_rounded,
                isDark: isDark,
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSortBy = val);
                },
              ),

              // View Mode Switcher (Table vs Card)
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildViewModeButton(
                      label: 'Table',
                      icon: Icons.table_chart_outlined,
                      isActive: isTableView,
                      isDark: isDark,
                      onTap: () => setState(() => _userPreferredIsTable = true),
                    ),
                    _buildViewModeButton(
                      label: 'Cards',
                      icon: Icons.grid_view_rounded,
                      isActive: !isTableView,
                      isDark: isDark,
                      onTap: () => setState(() => _userPreferredIsTable = false),
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

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required IconData icon,
    required bool isDark,
    required ValueChanged<String?> onChanged,
  }) {
    final effectiveValue = items.contains(value) ? value : items.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: effectiveValue,
              dropdownColor: isDark ? const Color(0xFF151D36) : Colors.white,
              isDense: true,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? const Color(0xFF2563EB).withValues(alpha: 0.25) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isActive && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive
                  ? const Color(0xFF2563EB)
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? const Color(0xFF2563EB)
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 4A. Data Table View (Desktop Default) ---
  Widget _buildDataTable(
    List<CatalogProduct> products,
    Map<String, _ProductMetrics> metricsMap,
    ProductCatalogState catalogState,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D36) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1000),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
              ),
              dataRowMinHeight: 68,
              dataRowMaxHeight: 74,
              horizontalMargin: 16,
              columnSpacing: 24,
              columns: [
                DataColumn(
                  label: Text(
                    'PRODUCT',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'RETAIL PRICE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'UNITS SOLD',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'REVENUE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'HUB STOCK',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'DEALS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'COVERAGE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'ACTIONS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
              rows: products.map((product) {
                final key = product.id.isNotEmpty ? product.id : product.name;
                final metrics = metricsMap[key] ?? const _ProductMetrics();
                final packages = catalogState.getPackagesForProduct(product.name);

                return DataRow(
                  cells: [
                    // Column 1: Product Thumbnail & Name
                    DataCell(
                      InkWell(
                        onTap: () => _openProductDetail(product),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                                  width: 1.2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: ProductImageWidget(
                                  imageUrl: product.imageUrl,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    product.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E294A) : const Color(0xFFE2E8F0),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          product.sku,
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          product.category,
                                          style: GoogleFonts.inter(
                                            fontSize: 10.5,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
                    ),

                    // Column 2: Retail Price
                    DataCell(
                      Text(
                        '₦${Formatters.currency(product.defaultUnitPrice)}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFF37021),
                        ),
                      ),
                    ),

                    // Column 3: Units Sold
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF37021).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFF37021).withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department_rounded, size: 13, color: Color(0xFFF37021)),
                            const SizedBox(width: 4),
                            Text(
                              '${metrics.unitsSold} sold',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFF37021),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Column 4: Revenue
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.payments_rounded, size: 13, color: Color(0xFF10B981)),
                            const SizedBox(width: 4),
                            Text(
                              '₦${Formatters.currency(metrics.revenue)}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Column 5: Hub Stock
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: product.totalStockAcrossHubs > 0
                              ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                              : const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: product.totalStockAcrossHubs > 0
                                ? const Color(0xFF2563EB).withValues(alpha: 0.25)
                                : const Color(0xFFEF4444).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inventory_2_rounded,
                              size: 13,
                              color: product.totalStockAcrossHubs > 0
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFFEF4444),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              product.totalStockAcrossHubs > 0
                                  ? '${product.totalStockAcrossHubs} units'
                                  : 'Out of stock (0)',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: product.totalStockAcrossHubs > 0
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Column 6: Deals (Compact Clickable Badge to open Product Detail Deals Tab)
                    DataCell(
                      InkWell(
                        onTap: () => _openProductDetail(product, initialTabIndex: 2),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: packages.isNotEmpty
                                ? const Color(0xFFEC4899).withValues(alpha: 0.12)
                                : (isDark ? const Color(0xFF1E294A) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: packages.isNotEmpty
                                  ? const Color(0xFFEC4899).withValues(alpha: 0.3)
                                  : (isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_offer_rounded,
                                size: 12,
                                color: packages.isNotEmpty
                                    ? const Color(0xFFEC4899)
                                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                packages.isNotEmpty ? '${packages.length} Deals' : '+ Deal',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: packages.isNotEmpty
                                      ? const Color(0xFFEC4899)
                                      : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Column 7: Coverage
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(
                          product.coveringStates.isNotEmpty
                              ? '${product.coveringStates.length} states (${product.coveringStates.join(", ")})'
                              : 'All Regional Hubs',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                    // Column 8: Actions
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Supply Stock
                          IconButton(
                            tooltip: 'Supply Stock',
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.12),
                              foregroundColor: const Color(0xFF10B981),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            icon: const Icon(Icons.local_shipping_rounded, size: 15),
                            onPressed: () => ClientSupplyStockModal.show(context, product),
                          ),
                          const SizedBox(width: 6),

                          // Create Order
                          IconButton(
                            tooltip: 'Create Order',
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF37021).withValues(alpha: 0.12),
                              foregroundColor: const Color(0xFFF37021),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            icon: const Icon(Icons.add_shopping_cart_rounded, size: 15),
                            onPressed: () => ClientCreateOrderModal.show(context, product: product),
                          ),
                          const SizedBox(width: 6),

                          // View Details & Deals
                          IconButton(
                            tooltip: 'Details & Deals',
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.12),
                              foregroundColor: const Color(0xFF2563EB),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            icon: const Icon(Icons.insights_rounded, size: 15),
                            onPressed: () => _openProductDetail(product),
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
      ),
    );
  }

  // --- 4B. Cards View (Mobile Default) ---
  Widget _buildCardView(
    List<CatalogProduct> products,
    Map<String, _ProductMetrics> metricsMap,
    ProductCatalogState catalogState,
    bool isDark,
    double maxWidth,
  ) {
    // 1 column on mobile, 2 columns on wide screens
    final isTwoColumn = maxWidth >= 640;

    return isTwoColumn
        ? GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.6,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              return _buildProductCard(
                product: products[index],
                metricsMap: metricsMap,
                catalogState: catalogState,
                isDark: isDark,
              );
            },
          )
        : ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              return _buildProductCard(
                product: products[index],
                metricsMap: metricsMap,
                catalogState: catalogState,
                isDark: isDark,
              );
            },
          );
  }

  Widget _buildProductCard({
    required CatalogProduct product,
    required Map<String, _ProductMetrics> metricsMap,
    required ProductCatalogState catalogState,
    required bool isDark,
  }) {
    final key = product.id.isNotEmpty ? product.id : product.name;
    final metrics = metricsMap[key] ?? const _ProductMetrics();
    final packages = catalogState.getPackagesForProduct(product.name);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D36) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
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
          // Top Row: Image, Name, SKU, Category, Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => _openProductDetail(product),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: ProductImageWidget(
                      imageUrl: product.imageUrl,
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                    ),
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
                        Expanded(
                          child: InkWell(
                            onTap: () => _openProductDetail(product),
                            child: Text(
                              product.name,
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E294A) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            product.sku,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          '₦${Formatters.currency(product.defaultUnitPrice)}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFF37021),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '•',
                          style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            product.category,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Key Metrics Badges
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: [
              // Units Sold
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF37021).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department_rounded, size: 11, color: Color(0xFFF37021)),
                    const SizedBox(width: 3),
                    Text(
                      '${metrics.unitsSold} Sold',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFF37021),
                      ),
                    ),
                  ],
                ),
              ),

              // Revenue
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.payments_rounded, size: 11, color: Color(0xFF10B981)),
                    const SizedBox(width: 3),
                    Text(
                      '₦${Formatters.currency(metrics.revenue)} Vol',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),

              // Stock Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: product.totalStockAcrossHubs > 0
                      ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                      : const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inventory_2_rounded,
                      size: 11,
                      color: product.totalStockAcrossHubs > 0 ? const Color(0xFF2563EB) : const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      product.totalStockAcrossHubs > 0
                          ? '${product.totalStockAcrossHubs} in stock'
                          : '0 in stock',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: product.totalStockAcrossHubs > 0 ? const Color(0xFF2563EB) : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),

              // In Transit
              if (metrics.inTransitCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.delivery_dining_rounded, size: 11, color: Color(0xFF0EA5E9)),
                      const SizedBox(width: 3),
                      Text(
                        '${metrics.inTransitCount} In Transit',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0EA5E9),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Deals Strip: Clean, compact deal indicator pointing directly to details modal
          InkWell(
            onTap: () => _openProductDetail(product, initialTabIndex: 2),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: packages.isNotEmpty
                    ? const Color(0xFFEC4899).withValues(alpha: 0.08)
                    : (isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: packages.isNotEmpty
                      ? const Color(0xFFEC4899).withValues(alpha: 0.25)
                      : (isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_offer_rounded,
                    size: 13,
                    color: packages.isNotEmpty ? const Color(0xFFEC4899) : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      packages.isNotEmpty
                          ? '${packages.length} Package Deals Available'
                          : 'No package deals created yet',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: packages.isNotEmpty
                            ? (isDark ? Colors.white : const Color(0xFF0F172A))
                            : const Color(0xFF94A3B8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    packages.isNotEmpty ? 'Manage Deals →' : '+ Add Deal →',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFEC4899),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Action Buttons
          Row(
            children: [
              // Supply Stock
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                    elevation: 0,
                  ),
                  onPressed: () => ClientSupplyStockModal.show(context, product),
                  icon: const Icon(Icons.local_shipping_rounded, size: 13),
                  label: Text(
                    'Supply Stock',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Create Order
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF37021),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                    elevation: 0,
                  ),
                  onPressed: () => ClientCreateOrderModal.show(context, product: product),
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 13),
                  label: Text(
                    'Create Order',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Details & Stats
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF2563EB)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                ),
                onPressed: () => _openProductDetail(product),
                child: const Icon(Icons.insights_rounded, size: 15),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 5. Empty States ---
  Widget _buildEmptyCatalog(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D36) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(
              'No products registered yet',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Get started by adding your first retail product to the catalog.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF37021),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _showAddProductDialog,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Product Now'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearchResults(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D36) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 44, color: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(
              'No products match your search or filters',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try changing your search query or reset the active filters.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  _selectedCategory = 'All Categories';
                  _selectedStockFilter = 'All Inventory';
                  _selectedSortBy = 'Name (A-Z)';
                });
              },
              child: const Text('Reset All Filters'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductMetrics {
  final int unitsSold;
  final double revenue;
  final int inTransitCount;
  final int packagesCount;

  const _ProductMetrics({
    this.unitsSold = 0,
    this.revenue = 0.0,
    this.inTransitCount = 0,
    this.packagesCount = 0,
  });
}

class _KpiItem {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _KpiItem({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
