import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/widgets/product_image_widget.dart';
import '../../../dc_console/domain/entities/distribution_center.dart';
import '../../../dc_console/domain/entities/product_package.dart';
import '../../../dc_console/presentation/providers/dc_console_provider.dart';
import '../../../dc_console/presentation/providers/product_catalog_provider.dart';
import 'client_order_tracking_modal.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../stock/domain/entities/stock_item.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../providers/client_portal_provider.dart';
import 'client_add_package_modal.dart';
import 'client_create_order_modal.dart';
import 'client_supply_stock_modal.dart';

class ClientProductDetailModal extends ConsumerStatefulWidget {
  final CatalogProduct product;
  final int initialTabIndex;

  const ClientProductDetailModal({
    super.key,
    required this.product,
    this.initialTabIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required CatalogProduct product,
    int initialTabIndex = 0,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ClientProductDetailModal(
        product: product,
        initialTabIndex: initialTabIndex,
      ),
    );
  }

  @override
  ConsumerState<ClientProductDetailModal> createState() => _ClientProductDetailModalState();
}

class _ClientProductDetailModalState extends ConsumerState<ClientProductDetailModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _stateMatches(String dcState, String targetState) {
    final cleanDc = dcState.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final cleanTarget = targetState.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (cleanDc.isEmpty || cleanTarget.isEmpty) return false;
    if (cleanDc == cleanTarget) return true;
    if (cleanDc.contains(cleanTarget) || cleanTarget.contains(cleanDc)) return true;
    if ((cleanDc.contains('abuja') || cleanDc.contains('fct')) &&
        (cleanTarget.contains('abuja') || cleanTarget.contains('fct'))) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final clientState = ref.watch(clientPortalProvider);
    final catalogState = ref.watch(productCatalogProvider);
    final stockState = ref.watch(stockProvider);
    final dcState = ref.watch(dcConsoleProvider);

    // Keep product entity synced if updated in catalog
    final liveProduct = catalogState.products.firstWhere(
      (p) => p.name.toLowerCase() == widget.product.name.toLowerCase() ||
             p.sku.toLowerCase() == widget.product.sku.toLowerCase(),
      orElse: () => widget.product,
    );

    // Find all orders for this product
    final productOrders = clientState.orders.where((o) {
      final matchName = o.productName.trim().toLowerCase() == liveProduct.name.trim().toLowerCase();
      final matchSku = o.productSku != null &&
          o.productSku!.trim().isNotEmpty &&
          liveProduct.sku.isNotEmpty &&
          o.productSku!.trim().toLowerCase() == liveProduct.sku.trim().toLowerCase();
      return matchName || matchSku;
    }).toList();

    // Categorized Orders
    final deliveredOrders = productOrders.where((o) {
      final s = o.status.toLowerCase();
      return s == 'delivered' || s == 'completed';
    }).toList();

    final inTransitOrders = productOrders.where((o) {
      final s = o.status.toLowerCase();
      return s == 'in_transit' || s == 'out_for_delivery' || s == 'accepted';
    }).toList();

    final pendingOrders = productOrders.where((o) {
      final s = o.status.toLowerCase();
      return s == 'pending_dispatch' ||
          s == 'created' ||
          s == 'pending_rider_assignment' ||
          s == 'pending_dc_assignment' ||
          s == 'assigned';
    }).toList();

    final returnedOrders = productOrders.where((o) {
      final s = o.status.toLowerCase();
      return s == 'failed' || s == 'cancelled' || s == 'returned';
    }).toList();

    // Volume & Metrics
    final totalUnitsSold = deliveredOrders.fold<int>(
      0,
      (sum, o) => sum + (o.quantity > 0 ? o.quantity : 1),
    );

    final totalPaidUnitsSold = deliveredOrders.fold<int>(
      0,
      (sum, o) => sum + (o.paidQuantity > 0 ? o.paidQuantity : (o.quantity > 0 ? o.quantity : 1)),
    );

    final totalFreePromoUnits = deliveredOrders.fold<int>(
      0,
      (sum, o) => sum + o.freeQuantity,
    );

    final totalRevenue = deliveredOrders.fold<double>(
      0.0,
      (sum, o) => sum + o.totalAmount,
    );

    final completedOrReturned = deliveredOrders.length + returnedOrders.length;
    final deliveryRate = completedOrReturned > 0
        ? ((deliveredOrders.length / completedOrReturned) * 100).toStringAsFixed(1)
        : (productOrders.isNotEmpty ? '100.0' : '0.0');

    // Packages
    final packages = catalogState.getPackagesForProduct(liveProduct.name);

    // Distribution Centers
    final allDcs = dcState.distributionCenters.isNotEmpty
        ? dcState.distributionCenters
        : defaultDistributionCenters;

    final coveringDcs = allDcs.where((dc) {
      return liveProduct.coveringStates.any((st) => _stateMatches(dc.state, st));
    }).toList();

    // Stock Item Entity
    StockItemEntity? matchedStockItem;
    for (final item in stockState.stockItems) {
      if (item.name.toLowerCase() == liveProduct.name.toLowerCase() ||
          item.sku.toLowerCase() == liveProduct.sku.toLowerCase()) {
        matchedStockItem = item;
        break;
      }
    }

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 860),
        child: Column(
          children: [
            // Modal Header
            _buildHeader(context, liveProduct, isDark),

            // Top Quick Action Bar
            _buildActionBar(context, liveProduct, isDark),

            // Tab Bar
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
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
                indicatorColor: const Color(0xFF2563EB),
                indicatorWeight: 3,
                labelColor: const Color(0xFF2563EB),
                unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: [
                  Tab(
                    icon: const Icon(Icons.analytics_rounded, size: 16),
                    text: 'Sales Performance ($totalUnitsSold sold)',
                  ),
                  Tab(
                    icon: const Icon(Icons.warehouse_rounded, size: 16),
                    text: 'Hub Inventory (${liveProduct.totalStockAcrossHubs} units)',
                  ),
                  Tab(
                    icon: const Icon(Icons.local_offer_rounded, size: 16),
                    text: 'Deal Packages (${packages.length})',
                  ),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Sales Performance & Orders
                  _buildPerformanceTab(
                    context: context,
                    product: liveProduct,
                    productOrders: productOrders,
                    totalUnitsSold: totalUnitsSold,
                    totalPaidUnitsSold: totalPaidUnitsSold,
                    totalFreePromoUnits: totalFreePromoUnits,
                    totalRevenue: totalRevenue,
                    deliveredCount: deliveredOrders.length,
                    inTransitCount: inTransitOrders.length,
                    pendingCount: pendingOrders.length,
                    returnedCount: returnedOrders.length,
                    deliveryRate: deliveryRate,
                    isDark: isDark,
                  ),

                  // Tab 2: Hub Inventory & DC Distribution
                  _buildInventoryTab(
                    context: context,
                    product: liveProduct,
                    stockItem: matchedStockItem,
                    coveringDcs: coveringDcs,
                    isDark: isDark,
                  ),

                  // Tab 3: Commercial Deal Packages
                  _buildPackagesTab(
                    context: context,
                    product: liveProduct,
                    packages: packages,
                    productOrders: productOrders,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, CatalogProduct product, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // High-Res Product Image with subtle border
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ProductImageWidget(
                imageUrl: product.imageUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Title & Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        product.name,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        product.sku,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text(
                      'Category: ${product.category}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      '•',
                      style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                    ),
                    Text(
                      'Retail Price: ₦${Formatters.currency(product.defaultUnitPrice)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    Text(
                      '•',
                      style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                    ),
                    Text(
                      'Covering States: ${product.coveringStates.isNotEmpty ? product.coveringStates.join(", ") : "All Hubs"}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Close Button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, CatalogProduct product, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Text(
            'Quick Actions:',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF37021),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  ClientCreateOrderModal.show(context, product: product);
                },
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 14),
                label: Text(
                  'Create Order',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                ),
                onPressed: () {
                  ClientSupplyStockModal.show(context, product);
                },
                icon: const Icon(Icons.local_shipping_rounded, size: 14),
                label: Text(
                  'Supply Stock',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF2563EB)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                ),
                onPressed: () {
                  ClientAddPackageModal.show(context, product: product);
                },
                icon: const Icon(Icons.add_rounded, size: 14),
                label: Text(
                  'Add Deal Package',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTab({
    required BuildContext context,
    required CatalogProduct product,
    required List<OrderEntity> productOrders,
    required int totalUnitsSold,
    required int totalPaidUnitsSold,
    required int totalFreePromoUnits,
    required double totalRevenue,
    required int deliveredCount,
    required int inTransitCount,
    required int pendingCount,
    required int returnedCount,
    required String deliveryRate,
    required bool isDark,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Text(
            'Performance Overview',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          // KPI Cards Grid (Responsive)
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              final cardWidth = isWide ? (constraints.maxWidth - 24) / 3 : (constraints.maxWidth - 12) / 2;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildMetricCard(
                    title: 'Total Units Sold',
                    value: '$totalUnitsSold units',
                    subValue: '$totalPaidUnitsSold paid • $totalFreePromoUnits promo free',
                    icon: Icons.local_fire_department_rounded,
                    accentColor: const Color(0xFFF37021),
                    width: cardWidth,
                    isDark: isDark,
                  ),
                  _buildMetricCard(
                    title: 'Total Sales Revenue',
                    value: '₦${Formatters.currency(totalRevenue)}',
                    subValue: 'Delivered volume collected',
                    icon: Icons.payments_rounded,
                    accentColor: const Color(0xFF10B981),
                    width: cardWidth,
                    isDark: isDark,
                  ),
                  _buildMetricCard(
                    title: 'Delivery Success Rate',
                    value: '$deliveryRate%',
                    subValue: '$deliveredCount delivered of ${deliveredCount + returnedCount} closed',
                    icon: Icons.verified_rounded,
                    accentColor: const Color(0xFF2563EB),
                    width: cardWidth,
                    isDark: isDark,
                  ),
                  _buildMetricCard(
                    title: 'Customer Orders',
                    value: '${productOrders.length} orders',
                    subValue: '$deliveredCount completed • $inTransitCount in transit • $pendingCount pending',
                    icon: Icons.shopping_bag_rounded,
                    accentColor: const Color(0xFF8B5CF6),
                    width: cardWidth,
                    isDark: isDark,
                  ),
                  _buildMetricCard(
                    title: 'Live Hub Stock',
                    value: '${product.totalStockAcrossHubs} units',
                    subValue: 'Valuation: ₦${Formatters.currency(product.totalStockAcrossHubs * product.defaultUnitPrice)}',
                    icon: Icons.inventory_2_rounded,
                    accentColor: product.totalStockAcrossHubs > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    width: cardWidth,
                    isDark: isDark,
                  ),
                  _buildMetricCard(
                    title: 'Active In-Transit',
                    value: '$inTransitCount orders',
                    subValue: 'Currently with riders in field',
                    icon: Icons.delivery_dining_rounded,
                    accentColor: const Color(0xFF0EA5E9),
                    width: cardWidth,
                    isDark: isDark,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Orders Breakdown & History
          Row(
            children: [
              Text(
                'Recent Orders for ${product.name}',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${productOrders.length} total',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (productOrders.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.receipt_long_rounded, size: 36, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 8),
                    Text(
                      'No customer orders recorded for this product yet',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF37021),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        ClientCreateOrderModal.show(context, product: product);
                      },
                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 14),
                      label: const Text('Place First Order'),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: productOrders.take(15).length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
                itemBuilder: (context, index) {
                  final order = productOrders[index];
                  return _buildOrderRow(context, order, isDark);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subValue,
    required IconData icon,
    required Color accentColor,
    required double width,
    required bool isDark,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
            subValue,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderRow(BuildContext context, OrderEntity order, bool isDark) {
    Color statusColor;
    String statusLabel = order.status.toUpperCase().replaceAll('_', ' ');

    switch (order.status.toLowerCase()) {
      case 'delivered':
      case 'completed':
        statusColor = const Color(0xFF10B981);
        break;
      case 'in_transit':
      case 'out_for_delivery':
        statusColor = const Color(0xFF0EA5E9);
        break;
      case 'pending_dispatch':
      case 'created':
      case 'assigned':
        statusColor = const Color(0xFFF37021);
        break;
      case 'failed':
      case 'cancelled':
      case 'returned':
        statusColor = const Color(0xFFEF4444);
        break;
      default:
        statusColor = const Color(0xFF64748B);
    }

    return InkWell(
      onTap: () => ClientOrderTrackingModal.show(context, order),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.receipt_rounded, size: 16, color: statusColor),
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
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• ${order.customerName}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${order.deliveryCity}, ${order.deliveryState} ${order.lga != null ? "(${order.lga})" : ""} • Qty: ${order.quantity > 0 ? order.quantity : 1} units ${order.packageDealName != null ? "(${order.packageDealName})" : ""}',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
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
                  '₦${Formatters.currency(order.totalAmount)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 16, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryTab({
    required BuildContext context,
    required CatalogProduct product,
    required StockItemEntity? stockItem,
    required List<DistributionCenter> coveringDcs,
    required bool isDark,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Distribution Center Stock Allocation',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Physical shelf stock distributed across NovaExpress fulfillment hubs',
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
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () => ClientSupplyStockModal.show(context, product),
                icon: const Icon(Icons.local_shipping_rounded, size: 14),
                label: const Text('Supply Stock to Hubs'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (coveringDcs.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Text('No active Distribution Centers operating in this product\'s covering states.'),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: coveringDcs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final dc = coveringDcs[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.warehouse_rounded, color: Color(0xFF2563EB), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  dc.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    dc.state,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'City: ${dc.city} • Capacity: ${dc.storageCapacityUnits} units • Zones: ${dc.operatingZones.isNotEmpty ? dc.operatingZones.join(", ") : "Statewide"}',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Shelf Stock',
                              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF10B981), fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${stockItem?.availableCount ?? product.totalStockAcrossHubs} units',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                            ),
                          ],
                        ),
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

  Widget _buildPackagesTab({
    required BuildContext context,
    required CatalogProduct product,
    required List<ProductPackage> packages,
    required List<OrderEntity> productOrders,
    required bool isDark,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Commercial Deal Packages',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Multi-pack bundles configured for marketing campaigns, high conversion & promotions',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF37021),
                  side: const BorderSide(color: Color(0xFFF37021)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () => ClientAddPackageModal.show(context, product: product),
                icon: const Icon(Icons.add_rounded, size: 14),
                label: const Text('Add Deal Package'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (packages.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Text('No promotional package deals created for this product yet.'),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: packages.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final pkg = packages[index];

                // Count how many orders used this package
                final pkgOrdersCount = productOrders.where((o) {
                  return o.packageDealId == pkg.id ||
                      (o.packageDealName != null &&
                          o.packageDealName!.toLowerCase() == pkg.packageName.toLowerCase());
                }).length;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, itemConstraints) {
                      final isWide = itemConstraints.maxWidth >= 520;
                      final actionsRow = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit Deal',
                            onPressed: () {
                              ClientAddPackageModal.show(
                                context,
                                product: product,
                                packageToEdit: pkg,
                              );
                            },
                            icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'Delete Deal',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  title: const Text('Delete Deal Package?'),
                                  content: Text('Are you sure you want to delete "${pkg.packageName}"?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFEF4444),
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => Navigator.of(ctx).pop(true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await ref.read(clientPortalProvider.notifier).deletePackage(
                                  productName: product.name,
                                  packageId: pkg.id,
                                );
                              }
                            },
                            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF37021),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              ClientCreateOrderModal.show(
                                context,
                                product: product,
                                package: pkg,
                              );
                            },
                            icon: const Icon(Icons.add_shopping_cart_rounded, size: 13),
                            label: Text(
                              'Order Deal',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      );

                      if (isWide) {
                        return Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF37021).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.local_offer_rounded, color: Color(0xFFF37021), size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        pkg.packageName,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      if (pkg.freeQuantity > 0) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '+${pkg.freeQuantity} FREE PROMO',
                                            style: GoogleFonts.inter(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF10B981),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Deal Price: ₦${Formatters.currency(pkg.packagePrice)} • Units: ${pkg.totalPhysicalQuantity} (${pkg.paidQuantity} paid) • Orders Driven: $pkgOrdersCount',
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                            actionsRow,
                          ],
                        );
                      } else {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF37021).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.local_offer_rounded, color: Color(0xFFF37021), size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pkg.packageName,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      if (pkg.freeQuantity > 0) ...[
                                        const SizedBox(height: 3),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '+${pkg.freeQuantity} FREE PROMO',
                                            style: GoogleFonts.inter(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF10B981),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Deal Price: ₦${Formatters.currency(pkg.packagePrice)} • Units: ${pkg.totalPhysicalQuantity} (${pkg.paidQuantity} paid) • Orders Driven: $pkgOrdersCount',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: actionsRow,
                            ),
                          ],
                        );
                      }
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
