import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:novexps/core/theme/theme_provider.dart';
import '../../../dc_console/domain/entities/product_package.dart';
import '../../../orders/domain/entities/order.dart';
import '../providers/client_portal_provider.dart';
import '../widgets/client_create_order_modal.dart';
import '../widgets/client_order_tracking_modal.dart';
import '../../../orders/presentation/widgets/smart_order_paste_modal.dart';
import '../widgets/client_add_expenditure_modal.dart';
import '../widgets/client_add_package_modal.dart';
import '../widgets/client_raise_stock_invoice_modal.dart';
import '../widgets/client_supply_stock_modal.dart';

class ClientDashboardPage extends ConsumerWidget {
  final VoidCallback onNavigateToOrders;
  final VoidCallback onNavigateToProducts;
  final VoidCallback? onNavigateToInventory;
  final VoidCallback? onNavigateToFinance;

  const ClientDashboardPage({
    super.key,
    required this.onNavigateToOrders,
    required this.onNavigateToProducts,
    this.onNavigateToInventory,
    this.onNavigateToFinance,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clientPortalProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return RefreshIndicator(
      onRefresh: () => ref.read(clientPortalProvider.notifier).loadClientData(),
      child: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 14 : 24,
          vertical: isMobile ? 14 : 20,
        ),
        children: [
          // 1. Executive Mission Control Header
          _buildExecutiveHeader(context, state, isDark, isMobile),
          const SizedBox(height: 18),

          // 2. Urgent Inventory Alert Radar (Dynamic - only when replenishment is needed)
          if (_hasLowStock(state)) ...[
            _buildLowStockAlertBanner(context, state, isDark, isMobile),
            const SizedBox(height: 18),
          ],

          // 3. Operational Pulse KPI Strip (Organic, Non-Boxy, Semantic Tooltips)
          _buildKpiPulseStrip(context, state, isDark, isMobile),
          const SizedBox(height: 20),

          // 4. Financial Settlement Snapshot Teaser
          _buildSettlementTeaserCard(context, state, isDark, isMobile),
          const SizedBox(height: 20),

          // 5. Commercial Package Deals Velocity Strip
          if (_getAllPackages(state).isNotEmpty) ...[
            _buildPackageDealsSection(context, state, isDark, isMobile),
            const SizedBox(height: 20),
          ],

          // 6. Live Active Dispatches (Desktop Scannable Table / Mobile Card-to-Sheet)
          _buildLiveDispatchesSection(context, state, isDark, isMobile),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. EXECUTIVE MISSION CONTROL HEADER
  // =========================================================================
  Widget _buildExecutiveHeader(
    BuildContext context,
    ClientPortalState state,
    bool isDark,
    bool isMobile,
  ) {
    final companyName = state.clientProfile.companyName.isNotEmpty
        ? state.clientProfile.companyName
        : 'Novacare Limited';
    final clientCode = state.clientProfile.code.isNotEmpty
        ? state.clientProfile.code
        : 'NOVACARE-LTD';

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
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
          // Row 1: Merchant Identity & Status Badge
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
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
                    fontSize: isMobile ? 18 : 22,
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
          const SizedBox(height: 6),
          Text(
            'Live Dispatch Radar & Commercial Command Hub',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),

          // Row 2: Streamlined Quick Action Buttons (With Tooltips)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              Tooltip(
                message: 'Dispatch a single customer order to courier network',
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => ClientCreateOrderModal.show(context),
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                  label: Text(
                    '+ New Order',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Tooltip(
                message: 'Paste multiple customer orders from WhatsApp or Excel in 1 click',
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => SmartOrderPasteModal.show(context),
                  icon: const Icon(Icons.paste_rounded, size: 16, color: Color(0xFF0D9488)),
                  label: Text(
                    '⚡ Smart Paste',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Tooltip(
                message: 'Record advertising, packaging, or operational expenditures with receipts',
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => ClientAddExpenditureModal.show(
                    context,
                    clientId: state.clientProfile.id,
                  ),
                  icon: const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFFF43F5E)),
                  label: Text(
                    '+ Expense',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Tooltip(
                message: 'Notify distribution center of incoming inventory delivery',
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    if (state.clientProfile.hasInventoryManagement) {
                      ClientRaiseStockInvoiceModal.show(context);
                    } else if (state.products.isNotEmpty) {
                      ClientSupplyStockModal.show(context, state.products.first);
                    }
                  },
                  icon: const Icon(Icons.warehouse_rounded, size: 16, color: Color(0xFF8B5CF6)),
                  label: Text(
                    '📦 Inbound Stock',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
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
  bool _hasLowStock(ClientPortalState state) {
    final hasLowProduct = state.products.any((p) => p.stockQuantity <= p.lowStockThreshold);
    final hasLowBalance = state.stockBalances.any((b) => b.balanceQty <= 15);
    final hasZeroProduct = state.products.any((p) => p.stockQuantity <= 0);
    final hasZeroBalance = state.stockBalances.any((b) => b.balanceQty <= 0);
    return hasLowProduct || hasLowBalance || hasZeroProduct || hasZeroBalance;
  }

  Widget _buildLowStockAlertBanner(
    BuildContext context,
    ClientPortalState state,
    bool isDark,
    bool isMobile,
  ) {
    final zeroProducts = state.products.where((p) => p.stockQuantity <= 0).toList();
    final zeroBalances = state.stockBalances.where((b) => b.balanceQty <= 0).toList();
    final isZeroStock = zeroProducts.isNotEmpty || zeroBalances.isNotEmpty;

    final lowProducts = state.products.where((p) => p.stockQuantity <= p.lowStockThreshold).toList();
    final firstProduct = zeroProducts.isNotEmpty
        ? zeroProducts.first
        : (lowProducts.isNotEmpty ? lowProducts.first : null);

    final lowName = firstProduct?.name ?? (zeroBalances.isNotEmpty ? zeroBalances.first.itemName : 'Product SKU');
    final lowQty = firstProduct?.stockQuantity ?? (zeroBalances.isNotEmpty ? zeroBalances.first.balanceQty.toInt() : 0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isZeroStock
            ? (isDark ? const Color(0xFF450A0A).withValues(alpha: 0.6) : const Color(0xFFFEF2F2))
            : (isDark ? const Color(0xFF451A03).withValues(alpha: 0.5) : const Color(0xFFFFFBEB)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isZeroStock
              ? (isDark ? const Color(0xFFDC2626) : const Color(0xFFFCA5A5))
              : (isDark ? const Color(0xFFD97706) : const Color(0xFFFDE68A)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isZeroStock ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
            color: isZeroStock ? const Color(0xFFDC2626) : const Color(0xFFD97706),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isZeroStock ? 'Critical: Out of Stock at DC' : 'Low Stock Reorder Alert',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isZeroStock ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                  ),
                ),
                Text(
                  '$lowName has $lowQty units remaining on DC shelves. Dispatch fresh batch to avoid order holds.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                  ),
                  maxLines: isMobile ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isZeroStock ? const Color(0xFFDC2626) : const Color(0xFFD97706),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () {
              if (state.clientProfile.hasInventoryManagement) {
                ClientRaiseStockInvoiceModal.show(context, initialProduct: firstProduct);
              } else if (firstProduct != null) {
                ClientSupplyStockModal.show(context, firstProduct);
              }
            },
            child: Text(
              '+ Dispatch Stock',
              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 3. OPERATIONAL KPI PULSE STRIP (Organic, Non-Boxy, Semantic Tooltips)
  // =========================================================================
  Widget _buildKpiPulseStrip(
    BuildContext context,
    ClientPortalState state,
    bool isDark,
    bool isMobile,
  ) {
    final currencyFmt = NumberFormat('#,##0', 'en_US');

    final cards = [
      _buildPulseMetricCard(
        label: "Today's Revenue",
        value: '₦${currencyFmt.format(state.totalRevenue)}',
        contextText: '₦${currencyFmt.format(state.pendingCodRemittances)} pending COD',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF10B981),
        tooltip: 'Delivered customer cash collections today across distribution hubs',
        isDark: isDark,
      ),
      _buildPulseMetricCard(
        label: 'Active Pipeline',
        value: '${state.inTransitOrdersCount} In Transit',
        contextText: '${state.pendingOrdersCount} awaiting hub dispatch',
        icon: Icons.local_shipping_rounded,
        color: const Color(0xFF2563EB),
        tooltip: 'Shipments currently with courier PDA riders or staged for dispatch',
        isDark: isDark,
      ),
      _buildPulseMetricCard(
        label: 'Delivery Rate',
        value: '${state.deliverySuccessRate.toStringAsFixed(1)}%',
        contextText: '${state.deliveredOrdersCount} orders delivered today',
        icon: Icons.task_alt_rounded,
        color: const Color(0xFF0D9488),
        tooltip: 'Percentage of dispatched packages successfully closed and collected',
        isDark: isDark,
      ),
      _buildPulseMetricCard(
        label: 'Warehouse Stock',
        value: '${currencyFmt.format(state.stockBalances.fold(0.0, (s, b) => s + b.balanceQty).toInt())} Units',
        contextText: '${state.stockBalances.length} active SKU positions',
        icon: Icons.warehouse_rounded,
        color: const Color(0xFF8B5CF6),
        tooltip: 'Physical inventory custody safely held across regional distribution centers',
        isDark: isDark,
      ),
    ];

    if (isMobile) {
      return Column(
        children: cards
            .map((c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: c))
            .toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 950 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossCount,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 2.2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cards,
        );
      },
    );
  }

  Widget _buildPulseMetricCard({
    required String label,
    required String value,
    required String contextText,
    required IconData icon,
    required Color color,
    required String tooltip,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: tooltip,
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 13,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  contextText,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 4. FINANCIAL SETTLEMENT SNAPSHOT TEASER (No Duplicate Ledgers)
  // =========================================================================
  Widget _buildSettlementTeaserCard(
    BuildContext context,
    ClientPortalState state,
    bool isDark,
    bool isMobile,
  ) {
    final netExpected = state.todayNetExpectedPayout;
    final currencyFmt = NumberFormat('#,##0.00', 'en_US');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.payments_rounded, color: Color(0xFF10B981), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "Today's Net Remittance Expected",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '10:00 PM Batch',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '₦${currencyFmt.format(netExpected)}',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
          if (onNavigateToFinance != null)
            TextButton.icon(
              onPressed: onNavigateToFinance,
              icon: const Icon(Icons.arrow_forward_rounded, size: 14),
              label: Text(
                isMobile ? 'Finance' : 'Finance Console',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0D9488),
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // 5. COMMERCIAL PACKAGE DEALS STRIP
  // =========================================================================
  List<ProductPackage> _getAllPackages(ClientPortalState state) {
    return state.products.expand((p) => p.packages).toList();
  }

  Widget _buildPackageDealsSection(
    BuildContext context,
    ClientPortalState state,
    bool isDark,
    bool isMobile,
  ) {
    final allPackages = _getAllPackages(state);
    final currencyFmt = NumberFormat('#,###', 'en_US');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              Row(
                children: [
                  const Icon(Icons.sell_rounded, size: 16, color: Color(0xFFEC4899)),
                  const SizedBox(width: 8),
                  Text(
                    'Active Commercial Bundles',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => ClientAddPackageModal.show(context),
                icon: const Icon(Icons.add_rounded, size: 14),
                label: Text(
                  '+ Bundle',
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFEC4899),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: allPackages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final pkg = allPackages[index];
                return Container(
                  width: 200,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFDF2F8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFFBCFE8),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              pkg.packageName,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (pkg.freeQuantity > 0)
                            Text(
                              '+${pkg.freeQuantity} Free',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₦${currencyFmt.format(pkg.packagePrice)}',
                            style: GoogleFonts.outfit(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFEC4899),
                            ),
                          ),
                          Text(
                            '${pkg.quantity} units (₦${currencyFmt.format(pkg.unitPrice)}/u)',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: const Color(0xFF64748B),
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
      ),
    );
  }

  // =========================================================================
  // 6. LIVE DISPATCHES & ORDERS (Desktop Table / Mobile Card-to-Sheet)
  // =========================================================================
  Widget _buildLiveDispatchesSection(
    BuildContext context,
    ClientPortalState state,
    bool isDark,
    bool isMobile,
  ) {
    final recentOrders = state.orders.take(8).toList();

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF0D9488), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Live Dispatch Radar',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: onNavigateToOrders,
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: Text(
                  'All Orders',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
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
                    const Icon(Icons.inventory_2_outlined, size: 40, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 10),
                    Text(
                      'No active dispatches right now',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap "+ New Order" or "⚡ Smart Paste" to dispatch to customers',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            )
          else if (isMobile)
            // Mobile: Condensed Organic Cards -> Tapping opens Detail Bottom Sheet
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentOrders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final order = recentOrders[index];
                return _buildMobileOrderCard(context, order, isDark);
              },
            )
          else
            // Desktop: High-Density Scannable Table
            _buildDesktopOrdersTable(context, recentOrders, isDark),
        ],
      ),
    );
  }

  // =========================================================================
  // MOBILE ORDER CARD & DETAIL BOTTOM SHEET
  // =========================================================================
  Widget _buildMobileOrderCard(BuildContext context, OrderEntity order, bool isDark) {
    return InkWell(
      onTap: () => _showOrderDetailSheet(context, order, isDark),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
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
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusDotPill(order.status),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order.customerName,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '₦${order.totalAmount.toStringAsFixed(0)}',
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${order.lga ?? "City"}, ${order.deliveryState} • ${order.productName}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Text(
                      'Details',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0D9488),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF0D9488)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderDetailSheet(BuildContext context, OrderEntity order, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row: Order Number & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderNumber,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Destination: ${order.lga ?? "City"}, ${order.deliveryState}',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                _buildStatusDotPill(order.status),
              ],
            ),
            const Divider(height: 24),

            // Customer Contact Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_rounded, size: 16, color: Color(0xFF0D9488)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.customerName,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '📍 ${order.deliveryAddress}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                    ),
                  ),
                  Text(
                    '${order.lga ?? "City"}, ${order.deliveryState}',
                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () async {
                          final cleanPhone = order.customerPhone.replaceAll(RegExp(r'[^0-9+]'), '');
                          final uri = Uri.parse('tel:$cleanPhone');
                          if (await canLaunchUrl(uri)) await launchUrl(uri);
                        },
                        icon: const Icon(Icons.call_rounded, size: 13),
                        label: Text('Call', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF25D366),
                          side: const BorderSide(color: Color(0xFF25D366)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () async {
                          var cleanPhone = order.customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
                          if (cleanPhone.startsWith('0')) cleanPhone = '234${cleanPhone.substring(1)}';
                          final uri = Uri.parse('https://wa.me/$cleanPhone');
                          if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                        icon: const Icon(Icons.chat_bubble_rounded, size: 13),
                        label: Text('WhatsApp', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Order Items & Courier Details
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Item Ordered', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text(
                          '${order.productName} (${order.packageDealName ?? "${order.quantity} units"})',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '₦${order.totalAmount.toStringAsFixed(0)} • ${order.paymentType}',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Courier / Hub', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text(
                          order.deliveryAgentName ?? (order.distributionCenterName ?? 'Station DC'),
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          order.deliveryAgentPhone ?? 'Auto-Assigned',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Live Tracking Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  ClientOrderTrackingModal.show(context, order);
                },
                icon: const Icon(Icons.track_changes_rounded, size: 16),
                label: Text('Track Full Shipment Progress', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // DESKTOP ORDERS TABLE
  // =========================================================================
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
        height: 14,
      ),
      itemBuilder: (context, index) {
        final order = orders[index];
        return InkWell(
          onTap: () => ClientOrderTrackingModal.show(context, order),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF0D9488), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderNumber,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${order.customerName} • ${order.lga ?? "City"}, ${order.deliveryState}',
                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
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
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '₦${order.totalAmount.toStringAsFixed(0)} • ${order.paymentType}',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.deliveryAgentName ?? (order.distributionCenterName ?? 'Station DC'),
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        order.deliveryAgentPhone ?? 'Auto-Assigned',
                        style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusDotPill(order.status),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.track_changes_rounded, color: Color(0xFF0D9488), size: 18),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: dot,
            ),
          ),
        ],
      ),
    );
  }
}
