import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:novexps/core/helpers/formatters.dart';
import 'package:novexps/core/theme/theme_provider.dart';
import 'package:novexps/features/orders/domain/entities/order.dart';
import 'package:novexps/features/client_portal/data/repositories/expenditure_repository.dart';
import 'package:novexps/features/client_portal/domain/entities/business_expenditure.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';

class ClientProfitsView extends ConsumerStatefulWidget {
  const ClientProfitsView({super.key});

  @override
  ConsumerState<ClientProfitsView> createState() => _ClientProfitsViewState();
}

class _ClientProfitsViewState extends ConsumerState<ClientProfitsView> {
  final ExpenditureRepository _expRepo = ExpenditureRepository();

  String? _selectedProductId; // null = all
  String _selectedDateRange = '30d'; // 'today', '7d', '30d', 'this_month', 'all'

  List<BusinessExpenditureEntity> _expenditures = [];

  final currencyFormat = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final state = ref.read(clientPortalProvider);
    final clientId = state.clientProfile.id;
    if (clientId.isEmpty) return;

    try {
      final list = await _expRepo.fetchMerchantExpenditures(clientId: clientId);
      if (mounted) {
        setState(() {
          _expenditures = list;
        });
      }
    } catch (_) {}
  }

  String _formatMoney(double amount) {
    return CurrencyFormatter.formatNaira(amount).replaceAll('NGN', '').replaceAll('₦', '').trim();
  }

  (DateTime?, DateTime?) _getDateBounds() {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end = now;

    if (_selectedDateRange == 'today') {
      start = DateTime(now.year, now.month, now.day);
    } else if (_selectedDateRange == '7d') {
      start = now.subtract(const Duration(days: 7));
    } else if (_selectedDateRange == '30d') {
      start = now.subtract(const Duration(days: 30));
    } else if (_selectedDateRange == 'this_month') {
      start = DateTime(now.year, now.month, 1);
    }
    return (start, end);
  }

  List<OrderEntity> _getFilteredOrders(List<OrderEntity> orders) {
    final (start, end) = _getDateBounds();

    return orders.where((o) {
      if (!o.isDelivered) return false;

      // Date filter
      if (start != null) {
        final oDate = DateTime(o.createdAt.year, o.createdAt.month, o.createdAt.day);
        final startDateOnly = DateTime(start.year, start.month, start.day);
        if (oDate.isBefore(startDateOnly)) return false;
      }
      if (end != null) {
        final oDate = DateTime(o.createdAt.year, o.createdAt.month, o.createdAt.day);
        final endDateOnly = DateTime(end.year, end.month, end.day, 23, 59, 59);
        if (oDate.isAfter(endDateOnly)) return false;
      }

      // Product filter
      if (_selectedProductId != null && _selectedProductId!.isNotEmpty) {
        if (o.productId != _selectedProductId) return false;
      }

      return true;
    }).toList();
  }

  List<BusinessExpenditureEntity> _getFilteredExpenses() {
    final (start, end) = _getDateBounds();

    return _expenditures.where((exp) {
      if (start != null) {
        final expDate = DateTime(exp.expenditureDate.year, exp.expenditureDate.month, exp.expenditureDate.day);
        final startDateOnly = DateTime(start.year, start.month, start.day);
        if (expDate.isBefore(startDateOnly)) return false;
      }
      if (end != null) {
        final expDate = DateTime(exp.expenditureDate.year, exp.expenditureDate.month, exp.expenditureDate.day);
        final endDateOnly = DateTime(end.year, end.month, end.day, 23, 59, 59);
        if (expDate.isAfter(endDateOnly)) return false;
      }

      if (_selectedProductId != null && _selectedProductId!.isNotEmpty) {
        if (exp.productId != _selectedProductId) return false;
      }

      return true;
    }).toList();
  }

  void _showProductProfitSheet(BuildContext context, _ProductProfitData prod, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          prod.name,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: prod.netProfit >= 0
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : const Color(0xFFEF4444).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${prod.marginPercent.toStringAsFixed(1)}% Margin',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: prod.netProfit >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Net Profit Callout Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (prod.netProfit >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: (prod.netProfit >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Commercial Net Profit',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: prod.netProfit >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₦${currencyFormat.format(prod.netProfit)}',
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: prod.netProfit >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          prod.netProfit >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                          color: prod.netProfit >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          size: 30,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text('Unit & Commercial Economics', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),

                  _buildSheetDetailRow('Total Delivered Orders', '${prod.deliveredOrders} orders', isDark),
                  _buildSheetDetailRow('Physical Units Delivered', '${prod.unitsDelivered} units', isDark),
                  _buildSheetDetailRow('Gross Delivered Revenue', '₦${currencyFormat.format(prod.grossRevenue)}', isDark),
                  _buildSheetDetailRow('Logistics Waybill Fees', '- ₦${currencyFormat.format(prod.logisticsFees)}', isDark, isNegative: true),
                  _buildSheetDetailRow('Cost of Goods Sold (COGS)', '- ₦${currencyFormat.format(prod.cogs)}', isDark, isNegative: true),
                  _buildSheetDetailRow('Attributed Marketing / Expenses', '- ₦${currencyFormat.format(prod.expenses)}', isDark, isNegative: true),

                  const Divider(height: 24),
                  _buildSheetDetailRow('Net Profit Realized', '₦${currencyFormat.format(prod.netProfit)}', isDark, isBold: true),
                  _buildSheetDetailRow('Net Profit Margin', '${prod.marginPercent.toStringAsFixed(1)}%', isDark, isBold: true),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Done', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetDetailRow(String label, String value, bool isDark, {bool isNegative = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isBold ? 14 : 12.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isNegative ? const Color(0xFFEF4444) : (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
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

    final allOrders = state.financeOrders;
    final filteredOrders = _getFilteredOrders(allOrders);
    final filteredExpenses = _getFilteredExpenses();

    // DYNAMIC PROFIT CALCULATIONS
    double totalGrossRevenue = 0;
    double totalLogisticsFees = 0;
    double totalCogs = 0;
    double totalExpenses = 0;

    for (final exp in filteredExpenses) {
      totalExpenses += exp.amount;
    }

    // Map per product
    final Map<String, _ProductProfitData> productMap = {};

    for (final o in filteredOrders) {
      totalGrossRevenue += o.totalAmount;
      totalLogisticsFees += o.clientDeliveryFee;

      // Estimate COGS from totalAmount baseline 35%
      final unitCost = o.totalAmount * 0.35;
      final itemCogs = unitCost;
      totalCogs += itemCogs;

      final pId = o.productId ?? 'unassigned';
      if (!productMap.containsKey(pId)) {
        productMap[pId] = _ProductProfitData(
          id: pId,
          name: o.productName.isNotEmpty ? o.productName : 'Product $pId',
        );
      }

      final p = productMap[pId]!;
      p.deliveredOrders += 1;
      p.unitsDelivered += (o.quantity > 0 ? o.quantity : 1);
      p.grossRevenue += o.totalAmount;
      p.logisticsFees += o.clientDeliveryFee;
      p.cogs += itemCogs;
    }

    // Add attributed expenses per product
    for (final exp in filteredExpenses) {
      if (exp.productId != null && productMap.containsKey(exp.productId!)) {
        productMap[exp.productId!]!.expenses += exp.amount;
      }
    }

    final productList = productMap.values.toList();
    for (final p in productList) {
      p.netProfit = p.grossRevenue - p.logisticsFees - p.cogs - p.expenses;
      p.marginPercent = p.grossRevenue > 0 ? (p.netProfit / p.grossRevenue) * 100 : 0.0;
    }

    final totalNetProfit = totalGrossRevenue - totalLogisticsFees - totalCogs - totalExpenses;
    final overallMargin = totalGrossRevenue > 0 ? (totalNetProfit / totalGrossRevenue) * 100 : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(clientPortalProvider.notifier).loadClientData();
          await _loadExpenses();
        },
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 24, vertical: 18),
          children: [
            // 1. OPEN METRIC STRIP (Dynamically recalculates on filter changes)
            _buildOpenMetricStrip(
              grossRevenue: totalGrossRevenue,
              logisticsFees: totalLogisticsFees,
              cogs: totalCogs,
              expenses: totalExpenses,
              netProfit: totalNetProfit,
              marginPercent: overallMargin,
              isDark: isDark,
              isMobile: isMobile,
            ),
            const SizedBox(height: 20),

            // 2. COMMERCIAL PROFIT & LOSS WATERFALL CARD
            _buildPnLWaterfallCard(
              grossRevenue: totalGrossRevenue,
              logisticsFees: totalLogisticsFees,
              cogs: totalCogs,
              expenses: totalExpenses,
              netProfit: totalNetProfit,
              isDark: isDark,
              isMobile: isMobile,
            ),
            const SizedBox(height: 20),

            // 3. INTEGRATED FILTER TOOLBAR
            _buildIntegratedFilterBar(context, state.products, isDark, isMobile),
            const SizedBox(height: 18),

            // 4. DATA PRESENTATION: DESKTOP MATRIX vs MOBILE CARDS
            if (productList.isEmpty)
              _buildEmptyState(isDark)
            else if (isMobile)
              _buildMobileCardsList(context, productList, isDark)
            else
              _buildDesktopComparisonMatrix(context, productList, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenMetricStrip({
    required double grossRevenue,
    required double logisticsFees,
    required double cogs,
    required double expenses,
    required double netProfit,
    required double marginPercent,
    required bool isDark,
    required bool isMobile,
  }) {
    final metrics = [
      (
        label: 'Delivered Sales',
        value: '₦${currencyFormat.format(grossRevenue)}',
        subtext: 'Delivered order volume',
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF3B82F6),
      ),
      (
        label: 'COGS & Sourcing',
        value: '-₦${currencyFormat.format(cogs)}',
        subtext: 'Product cost baseline',
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFF64748B),
      ),
      (
        label: 'Logistics & Ads',
        value: '-₦${currencyFormat.format(logisticsFees + expenses)}',
        subtext: 'Waybill & operational spend',
        icon: Icons.local_shipping_rounded,
        color: const Color(0xFFEF4444),
      ),
      (
        label: 'Net Profit Realized',
        value: '₦${currencyFormat.format(netProfit)}',
        subtext: '${marginPercent.toStringAsFixed(1)}% commercial margin',
        icon: Icons.account_balance_wallet_rounded,
        color: netProfit >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: isMobile
          ? Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildMetricItem(metrics[0], isDark)),
                    Container(height: 50, width: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    Expanded(child: _buildMetricItem(metrics[1], isDark)),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildMetricItem(metrics[2], isDark)),
                    Container(height: 50, width: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    Expanded(child: _buildMetricItem(metrics[3], isDark)),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: _buildMetricItem(metrics[0], isDark)),
                Container(height: 55, width: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                Expanded(child: _buildMetricItem(metrics[1], isDark)),
                Container(height: 55, width: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                Expanded(child: _buildMetricItem(metrics[2], isDark)),
                Container(height: 55, width: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                Expanded(child: _buildMetricItem(metrics[3], isDark)),
              ],
            ),
    );
  }

  Widget _buildMetricItem(
    ({String label, String value, String subtext, IconData icon, Color color}) item,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.icon, size: 14, color: item.color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  item.label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            item.subtext,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPnLWaterfallCard({
    required double grossRevenue,
    required double logisticsFees,
    required double cogs,
    required double expenses,
    required double netProfit,
    required bool isDark,
    required bool isMobile,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Commercial P&L Flow Breakdown',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Delivered Orders Only',
                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF0D9488)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildWaterfallStep('Gross Delivered', '₦${_formatMoney(grossRevenue)}', const Color(0xFF2563EB), false),
              const Icon(Icons.remove, size: 16, color: Colors.grey),
              _buildWaterfallStep('Logistics Fees', '₦${_formatMoney(logisticsFees)}', const Color(0xFFEF4444), false),
              const Icon(Icons.remove, size: 16, color: Colors.grey),
              _buildWaterfallStep('Product COGS', '₦${_formatMoney(cogs)}', const Color(0xFF64748B), false),
              const Icon(Icons.remove, size: 16, color: Colors.grey),
              _buildWaterfallStep('Ad & OpEx', '₦${_formatMoney(expenses)}', const Color(0xFFF59E0B), false),
              const Icon(Icons.drag_handle, size: 16, color: Colors.grey),
              _buildWaterfallStep('Net Profit', '₦${_formatMoney(netProfit)}', netProfit >= 0 ? const Color(0xFF10B981) : const Color(0xFFDC2626), true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaterfallStep(String label, String amount, Color color, bool isResult) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(
          amount,
          style: GoogleFonts.inter(
            fontSize: isResult ? 15 : 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildIntegratedFilterBar(
    BuildContext context,
    dynamic products,
    bool isDark,
    bool isMobile,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: isMobile
          ? Column(
              children: [
                _buildProductDropdown(products, isDark),
                const SizedBox(height: 10),
                _buildDateDropdown(isDark),
              ],
            )
          : Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildProductDropdown(products, isDark),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 170,
                  child: _buildDateDropdown(isDark),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Exporting P&L Statement to CSV...')),
                    );
                  },
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: Text('Export P&L', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
    );
  }

  Widget _buildProductDropdown(dynamic products, bool isDark) {
    return DropdownButtonFormField<String?>(
      value: _selectedProductId,
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('All Products (Consolidated)', style: TextStyle(fontSize: 12))),
        if (products is List)
          ...products.map(
            (p) => DropdownMenuItem(
              value: p.id as String,
              child: Text(p.name as String, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
            ),
          ),
      ],
      onChanged: (val) {
        setState(() => _selectedProductId = val);
      },
    );
  }

  Widget _buildDateDropdown(bool isDark) {
    return DropdownButtonFormField<String>(
      value: _selectedDateRange,
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      items: const [
        DropdownMenuItem(value: 'today', child: Text('Today', style: TextStyle(fontSize: 12))),
        DropdownMenuItem(value: '7d', child: Text('Last 7 Days', style: TextStyle(fontSize: 12))),
        DropdownMenuItem(value: '30d', child: Text('Last 30 Days', style: TextStyle(fontSize: 12))),
        DropdownMenuItem(value: 'this_month', child: Text('This Month', style: TextStyle(fontSize: 12))),
        DropdownMenuItem(value: 'all', child: Text('All Time', style: TextStyle(fontSize: 12))),
      ],
      onChanged: (val) {
        if (val != null) setState(() => _selectedDateRange = val);
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.analytics_outlined, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(
              'No Profit Data Found',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Delivered orders and expenditures matching the selected filters will generate profitability matrices here.',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCardsList(
    BuildContext context,
    List<_ProductProfitData> list,
    bool isDark,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final prod = list[idx];

        return Material(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => _showProductProfitSheet(context, prod, isDark),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line 1: Product Name + Margin Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          prod.name,
                          style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: prod.netProfit >= 0
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : const Color(0xFFEF4444).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${prod.marginPercent.toStringAsFixed(1)}% Margin',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: prod.netProfit >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Line 2: Delivered Units + Gross Revenue
                  Row(
                    children: [
                      Text(
                        '${prod.unitsDelivered} units delivered',
                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                      ),
                      Text(' • ', style: GoogleFonts.inter(color: Colors.grey)),
                      Text(
                        'Gross: ₦${currencyFormat.format(prod.grossRevenue)}',
                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Line 3: Net Profit + Chevron
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Net Profit Contribution', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                          Text(
                            '₦${currencyFormat.format(prod.netProfit)}',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: prod.netProfit >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopComparisonMatrix(
    BuildContext context,
    List<_ProductProfitData> list,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(
                bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('PRODUCT NAME', style: _tableHeaderStyle())),
                Expanded(flex: 1, child: Text('UNITS', style: _tableHeaderStyle())),
                Expanded(flex: 2, child: Text('GROSS SALES', style: _tableHeaderStyle())),
                Expanded(flex: 2, child: Text('LOGISTICS FEES', style: _tableHeaderStyle())),
                Expanded(flex: 2, child: Text('COGS', style: _tableHeaderStyle())),
                Expanded(flex: 2, child: Text('AD & OPEX', style: _tableHeaderStyle())),
                Expanded(flex: 2, child: Text('NET PROFIT', style: _tableHeaderStyle())),
                Expanded(flex: 2, child: Text('MARGIN %', style: _tableHeaderStyle())),
                SizedBox(width: 50, child: Text('', style: _tableHeaderStyle())),
              ],
            ),
          ),

          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            itemBuilder: (context, idx) {
              final prod = list[idx];

              return InkWell(
                onTap: () => _showProductProfitSheet(context, prod, isDark),
                hoverColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Product Name
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2_rounded, size: 16, color: Color(0xFF3B82F6)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                prod.name,
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Units
                      Expanded(
                        flex: 1,
                        child: Text(
                          '${prod.unitsDelivered}',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      // Gross Sales
                      Expanded(
                        flex: 2,
                        child: Text(
                          '₦${currencyFormat.format(prod.grossRevenue)}',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      // Logistics Fees
                      Expanded(
                        flex: 2,
                        child: Text(
                          '-₦${currencyFormat.format(prod.logisticsFees)}',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFFEF4444)),
                        ),
                      ),
                      // COGS
                      Expanded(
                        flex: 2,
                        child: Text(
                          '-₦${currencyFormat.format(prod.cogs)}',
                          style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                        ),
                      ),
                      // Ad & OpEx
                      Expanded(
                        flex: 2,
                        child: Text(
                          '-₦${currencyFormat.format(prod.expenses)}',
                          style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFFF59E0B)),
                        ),
                      ),
                      // Net Profit
                      Expanded(
                        flex: 2,
                        child: Text(
                          '₦${currencyFormat.format(prod.netProfit)}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: prod.netProfit >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                      // Margin %
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: prod.netProfit >= 0
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : const Color(0xFFEF4444).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${prod.marginPercent.toStringAsFixed(1)}%',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: prod.netProfit >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Ghost Action
                      SizedBox(
                        width: 50,
                        child: IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, size: 18),
                          tooltip: 'View Economics',
                          onPressed: () => _showProductProfitSheet(context, prod, isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  TextStyle _tableHeaderStyle() {
    return GoogleFonts.inter(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF64748B),
      letterSpacing: 0.5,
    );
  }
}

class _ProductProfitData {
  final String id;
  final String name;
  int deliveredOrders = 0;
  int unitsDelivered = 0;
  double grossRevenue = 0;
  double logisticsFees = 0;
  double cogs = 0;
  double expenses = 0;
  double netProfit = 0;
  double marginPercent = 0;

  _ProductProfitData({required this.id, required this.name});
}
