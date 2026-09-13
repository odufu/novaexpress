import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../dc_console/domain/entities/product_package.dart';
import '../../../orders/domain/entities/order.dart';
import '../../domain/entities/client_settlement.dart';
import '../providers/client_portal_provider.dart';
import '../widgets/client_order_tracking_modal.dart';

class ClientFinancePage extends ConsumerStatefulWidget {
  const ClientFinancePage({super.key});

  @override
  ConsumerState<ClientFinancePage> createState() => _ClientFinancePageState();
}

class _ClientFinancePageState extends ConsumerState<ClientFinancePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedLedgerStatus = 'all'; // 'all', 'remitted', 'custody', 'in_field', 'direct'

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

  String _formatMoney(double amount) {
    return CurrencyFormatter.formatNaira(amount).replaceAll('NGN', '').replaceAll('₦', '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clientPortalProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final summary = state.activeFinanceSummary;
    final allProducts = state.products;

    // Filter ledger orders
    final ledgerOrders = state.financeOrders.where((o) {
      if (_selectedLedgerStatus != 'all') {
        if (_selectedLedgerStatus == 'remitted' && (!o.isDelivered || !o.isRemitted)) {
          return false;
        }
        if (_selectedLedgerStatus == 'custody' && (!o.isDelivered || o.isRemitted || o.isDirectTransfer)) {
          return false;
        }
        if (_selectedLedgerStatus == 'in_field' && (o.isDelivered || o.isFailed || !o.isCashPod)) {
          return false;
        }
        if (_selectedLedgerStatus == 'direct' && !o.isDirectTransfer) {
          return false;
        }
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchesNum = o.orderNumber.toLowerCase().contains(q);
        final matchesCust = o.customerName.toLowerCase().contains(q);
        final matchesProd = o.productName.toLowerCase().contains(q);
        final matchesCity = o.deliveryCity.toLowerCase().contains(q);
        final matchesState = o.deliveryState.toLowerCase().contains(q);
        if (!matchesNum && !matchesCust && !matchesProd && !matchesCity && !matchesState) {
          return false;
        }
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(clientPortalProvider.notifier).loadClientData(),
      child: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width < 650 ? 14 : 24,
          vertical: 20,
        ),
        children: [
          // Top Control & Product Filter Bar
          _buildTopFilterBar(context, ref, state, allProducts, isDark),
          const SizedBox(height: 16),

          // Daily 10:00 PM Remittance Closeout Status Banner
          _buildDailySettlementStatusBanner(context, state, isDark),
          const SizedBox(height: 20),

          // Asset Custody & Inventory Valuation Dual Card
          _buildAssetCustodyCard(context, state.assetCustodyData, isDark),
          const SizedBox(height: 20),

          // 4 Major Financial KPI Cards
          _buildKpiMetricsRow(context, summary, isDark),
          const SizedBox(height: 20),

          // Bank Settlement Account Card & Payout Schedule
          _buildBankPayoutCard(context, state.clientProfile, state.settlements, isDark),
          const SizedBox(height: 20),

          // Historical Daily Settlement Batches Table (Itemized Deductions & Receipts)
          _buildDailySettlementsTable(context, state.settlements, isDark),
          const SizedBox(height: 24),

          // Side-by-Side Product Financial Performance Matrix
          _buildProductPerformanceMatrix(context, ref, state, isDark),
          const SizedBox(height: 24),

          // Detailed Financial Transaction Ledger
          _buildFinancialLedgerSection(context, ledgerOrders, isDark),
        ],
      ),
    );
  }

  Widget _buildTopFilterBar(
    BuildContext context,
    WidgetRef ref,
    ClientPortalState state,
    List<CatalogProduct> allProducts,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 640;
              final headerTitle = Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF37021).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFF37021), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Finance & Settlements Command',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Live cash flow visibility, field COD custody, logistics deductions, and bank payouts',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final exportButton = OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF37021),
                  side: const BorderSide(color: Color(0xFFF37021)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final csv = ref.read(clientPortalProvider.notifier).generateSettlementCsv();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Settlement Statement exported (${csv.length} bytes ready).'),
                      backgroundColor: const Color(0xFF0D9488),
                    ),
                  );
                },
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(
                  'Export Statement',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              );

              return isWide
                  ? Row(
                      children: [
                        Expanded(child: headerTitle),
                        const SizedBox(width: 14),
                        exportButton,
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        headerTitle,
                        const SizedBox(height: 14),
                        SizedBox(width: double.infinity, child: exportButton),
                      ],
                    );
            },
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Filters Row: Product Filter & Time Window Filter
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Product Dropdown Filter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: Builder(
                    builder: (context) {
                      final hasMatch = state.selectedFinanceProductFilter == 'all' ||
                          allProducts.any((p) => p.name == state.selectedFinanceProductFilter);
                      final dropdownValue = hasMatch ? state.selectedFinanceProductFilter : 'all';

                      return DropdownButton<String>(
                        value: dropdownValue,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFF37021)),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        onChanged: (val) {
                          if (val != null) {
                            ref.read(clientPortalProvider.notifier).setFinanceProductFilter(val);
                          }
                        },
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem<String>(
                            value: 'all',
                            child: Row(
                              children: [
                                Icon(Icons.pie_chart_outline_rounded, size: 16, color: Color(0xFF2563EB)),
                                SizedBox(width: 8),
                                Text('All Products (Company Total)'),
                              ],
                            ),
                          ),
                          ...allProducts.map<DropdownMenuItem<String>>((CatalogProduct p) {
                            return DropdownMenuItem<String>(
                              value: p.name,
                              child: Row(
                                children: [
                                  const Icon(Icons.inventory_2_rounded, size: 16, color: Color(0xFFF37021)),
                                  const SizedBox(width: 8),
                                  Text(p.name),
                                ],
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // Time Window Filter Chips
              Wrap(
                spacing: 8,
                children: [
                  _buildTimeChip(ref, state.selectedFinanceTimeFilter, 'all_time', 'All Time', isDark),
                  _buildTimeChip(ref, state.selectedFinanceTimeFilter, 'month', 'This Month', isDark),
                  _buildTimeChip(ref, state.selectedFinanceTimeFilter, 'week', 'This Week', isDark),
                  _buildTimeChip(ref, state.selectedFinanceTimeFilter, 'today', 'Today', isDark),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(WidgetRef ref, String activeFilter, String key, String label, bool isDark) {
    final isSelected = activeFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => ref.read(clientPortalProvider.notifier).setFinanceTimeFilter(key),
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
      ),
      selectedColor: const Color(0xFFF37021),
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isSelected ? const Color(0xFFF37021) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildKpiMetricsRow(BuildContext context, ClientProductFinanceSummary summary, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1250 ? 5 : (constraints.maxWidth > 850 ? 3 : (constraints.maxWidth > 550 ? 2 : 1));
        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: constraints.maxWidth > 1250 ? 1.65 : (constraints.maxWidth <= 550 ? 2.4 : 2.0),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // Card 1: Money Outside (In Field / Risk)
            _buildKpiCard(
              title: 'Total Money Outside',
              amount: '₦${_formatMoney(summary.moneyOutside)}',
              subtitle: '${summary.inTransitOrders} in-transit • ${summary.pendingOrders} pending dispatch',
              badgeText: 'Field COD Risk',
              badgeColor: const Color(0xFFF59E0B),
              icon: Icons.near_me_rounded,
              gradientColors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
              isDark: isDark,
            ),

            // Card 2: In DC Custody (Awaiting Remittance)
            _buildKpiCard(
              title: 'Collected & In Custody',
              amount: '₦${_formatMoney(summary.awaitingRemittance)}',
              subtitle: 'Delivered by riders • Ready for bank payout',
              badgeText: 'Awaiting Remittance',
              badgeColor: const Color(0xFF2563EB),
              icon: Icons.account_balance_wallet_rounded,
              gradientColors: [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
              isDark: isDark,
            ),

            // Card 3: Total Remitted to Bank (Settled Realized Cash)
            _buildKpiCard(
              title: 'Remitted / Settled to Bank',
              amount: '₦${_formatMoney(summary.remittedToBank)}',
              subtitle: '${summary.deliveredOrders} delivered orders settled into bank',
              badgeText: 'Bank Cleared',
              badgeColor: const Color(0xFF10B981),
              icon: Icons.verified_rounded,
              gradientColors: [const Color(0xFF10B981), const Color(0xFF059669)],
              isDark: isDark,
            ),

            // Card 4: Net Cash Remittance (Take-Home Cash)
            _buildKpiCard(
              title: 'Net Cash Remittance',
              amount: '₦${_formatMoney(summary.netRealizedRevenue)}',
              subtitle: 'GMV ₦${_formatMoney(summary.grossDeliveredValue)} • Logistics -₦${_formatMoney(summary.logisticsDeliveryFees)}',
              badgeText: 'Take-Home Cash',
              badgeColor: const Color(0xFF8B5CF6),
              icon: Icons.payments_rounded,
              gradientColors: [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
              isDark: isDark,
            ),

            // Card 5: Commercial Gross Profit (Operating P&L)
            _buildKpiCard(
              title: 'Commercial Gross Profit',
              amount: '₦${_formatMoney(summary.commercialGrossProfit)}',
              subtitle: 'COGS: -₦${_formatMoney(summary.cogs)} • Margin: ${summary.profitMarginPercentage.toStringAsFixed(1)}%',
              badgeText: 'Operating P&L',
              badgeColor: const Color(0xFF0D9488),
              icon: Icons.trending_up_rounded,
              gradientColors: [const Color(0xFF0D9488), const Color(0xFF0F766E)],
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String amount,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
    required List<Color> gradientColors,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                amount,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeText,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankPayoutCard(
    BuildContext context,
    dynamic profile,
    List<dynamic> settlements,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [const Color(0xFF031632), const Color(0xFF0F2B56)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 640;

          final bankInfo = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.account_balance_rounded, color: Color(0xFF2DD4BF), size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Designated Settlement Bank Account',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF2DD4BF)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2DD4BF).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Verified for Payouts',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF2DD4BF)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${profile.bankName} • ${profile.accountNumber}',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Beneficiary: ${profile.accountName} • Cycle: ${profile.settlementFrequency.toUpperCase()} (${profile.settlementDay})',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          );

          final payoutBatch = settlements.isNotEmpty
              ? Container(
                  padding: isWide ? EdgeInsets.zero : const EdgeInsets.only(top: 14),
                  decoration: isWide
                      ? null
                      : BoxDecoration(
                          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                        ),
                  child: Row(
                    mainAxisAlignment: isWide ? MainAxisAlignment.end : MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: isWide ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Latest Payout Batch',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                          ),
                          Text(
                            '₦${_formatMoney(settlements.first.netPayoutAmount)}',
                            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          Text(
                            settlements.first.settlementNumber,
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFF37021)),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : null;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: bankInfo),
                if (payoutBatch != null) ...[
                  const SizedBox(width: 16),
                  payoutBatch,
                ],
              ],
            );
          } else {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bankInfo,
                if (payoutBatch != null) ...[
                  const SizedBox(height: 14),
                  payoutBatch,
                ],
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildProductPerformanceMatrix(
    BuildContext context,
    WidgetRef ref,
    ClientPortalState state,
    bool isDark,
  ) {
    final summaries = state.perProductFinanceSummaries;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Product Financial Performance Matrix',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Comparative breakdown of revenue, money outside, and net profitability per product',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              if (state.selectedFinanceProductFilter != 'all')
                TextButton.icon(
                  onPressed: () => ref.read(clientPortalProvider.notifier).setFinanceProductFilter('all'),
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  label: const Text('Clear Filter (Show All)'),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFF37021)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              ),
              columns: [
                DataColumn(label: Text('Product & SKU', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Units Sold', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Gross GMV', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Logistics Costs', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Net Realized', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('COGS', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Commercial GP', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Gross Margin', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Awaiting Remittance', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Money Outside', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              rows: summaries.map((s) {
                final isFiltered = state.selectedFinanceProductFilter == s.productName;
                return DataRow(
                  selected: isFiltered,
                  onSelectChanged: (_) {
                    ref.read(clientPortalProvider.notifier).setFinanceProductFilter(
                          isFiltered ? 'all' : s.productName,
                        );
                  },
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          Icon(Icons.inventory_2_rounded, size: 16, color: isFiltered ? const Color(0xFFF37021) : const Color(0xFF2563EB)),
                          const SizedBox(width: 8),
                          Text(s.productName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                    DataCell(Text('${s.deliveredOrders} units', style: GoogleFonts.inter(fontSize: 12))),
                    DataCell(Text('₦${_formatMoney(s.grossDeliveredValue)}', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12))),
                    DataCell(Text('-₦${_formatMoney(s.logisticsDeliveryFees)}', style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 12))),
                    DataCell(Text('₦${_formatMoney(s.netRealizedRevenue)}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF10B981), fontSize: 12))),
                    DataCell(Text('-₦${_formatMoney(s.cogs)}', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12))),
                    DataCell(Text('₦${_formatMoney(s.commercialGrossProfit)}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF0D9488), fontSize: 12))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: s.profitMarginPercentage >= 50
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${s.profitMarginPercentage.toStringAsFixed(1)}%',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: s.profitMarginPercentage >= 50 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text('₦${_formatMoney(s.awaitingRemittance)}', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF2563EB), fontSize: 12))),
                    DataCell(Text('₦${_formatMoney(s.moneyOutside)}', style: GoogleFonts.inter(color: const Color(0xFFF59E0B), fontSize: 12))),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialLedgerSection(
    BuildContext context,
    List<OrderEntity> orders,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 640;
              final headerTitle = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Financial Transaction & Settlement Ledger (${orders.length})',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Individual orders breakdown with gross price, logistics fees, and payout status',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              );

              final searchField = SizedBox(
                width: isWide ? 250 : double.infinity,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search order or customer...',
                    hintStyle: GoogleFonts.inter(fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
              );

              return isWide
                  ? Row(
                      children: [
                        Expanded(child: headerTitle),
                        const SizedBox(width: 14),
                        searchField,
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        headerTitle,
                        const SizedBox(height: 12),
                        searchField,
                      ],
                    );
            },
          ),
          const SizedBox(height: 16),

          // Ledger Category Filter Chips
          Wrap(
            spacing: 8,
            children: [
              _buildLedgerStatusChip('all', 'All Transactions', orders.length, isDark),
              _buildLedgerStatusChip('remitted', 'Remitted to Bank', orders.where((o) => o.isDelivered && o.isRemitted).length, isDark),
              _buildLedgerStatusChip('custody', 'In DC Custody (Ready)', orders.where((o) => o.isDelivered && !o.isRemitted && o.isCashPod).length, isDark),
              _buildLedgerStatusChip('in_field', 'In Field (COD Active)', orders.where((o) => !o.isDelivered && !o.isFailed && o.isCashPod).length, isDark),
              _buildLedgerStatusChip('direct', 'Direct Transfer / Prepaid', orders.where((o) => o.isDirectTransfer).length, isDark),
            ],
          ),
          const SizedBox(height: 16),

          if (orders.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 48, color: const Color(0xFF94A3B8)),
                    const SizedBox(height: 8),
                    Text(
                      'No financial transactions found matching filters.',
                      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final order = orders[index];
                final isDelivered = order.isDelivered;
                final isRemitted = order.isRemitted;
                final isDirect = order.isDirectTransfer;
                final fee = isDelivered ? order.clientDeliveryFee : 0.0;
                final net = isDelivered ? (order.totalAmount - (isDirect ? 0.0 : fee)) : 0.0;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  onTap: () => ClientOrderTrackingModal.show(context, order),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isRemitted
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : (isDelivered
                              ? const Color(0xFF2563EB).withValues(alpha: 0.15)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isRemitted
                          ? Icons.check_circle_rounded
                          : (isDelivered ? Icons.account_balance_wallet_rounded : Icons.two_wheeler_rounded),
                      color: isRemitted
                          ? const Color(0xFF10B981)
                          : (isDelivered ? const Color(0xFF2563EB) : const Color(0xFFF59E0B)),
                      size: 20,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        order.orderNumber,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '• ${order.productName}',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '₦${_formatMoney(order.totalAmount)}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${order.customerName} (${order.deliveryCity}) • Fee: -₦${_formatMoney(fee)} • Net: ₦${_formatMoney(net)}',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildStatusBadge(order),
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

  Widget _buildLedgerStatusChip(String key, String label, int count, bool isDark) {
    final isSelected = _selectedLedgerStatus == key;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedLedgerStatus = key),
      labelStyle: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
      ),
      selectedColor: const Color(0xFF031632),
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isSelected ? const Color(0xFF031632) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildStatusBadge(OrderEntity order) {
    if (order.isDirectTransfer) {
      return _badge('Prepaid / Direct Transfer', const Color(0xFF0D9488));
    }
    if (order.isRemitted) {
      return _badge('Remitted to Bank', const Color(0xFF10B981));
    }
    if (order.isDelivered) {
      return _badge('In DC Custody (Ready)', const Color(0xFF2563EB));
    }
    if (order.isFailed) {
      return _badge('Delivery Failed / Return', const Color(0xFFEF4444));
    }
    return _badge('In Field (COD Active)', const Color(0xFFF59E0B));
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _buildDailySettlementStatusBanner(BuildContext context, ClientPortalState state, bool isDark) {
    final now = DateTime.now();
    final closeoutTime = DateTime(now.year, now.month, now.day, 22, 0); // 10:00 PM
    final isPastCloseout = now.isAfter(closeoutTime);
    final difference = isPastCloseout 
        ? closeoutTime.add(const Duration(days: 1)).difference(now) 
        : closeoutTime.difference(now);

    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    final pendingOrdersCount = state.financeOrders.where((o) => o.isDelivered && !o.isRemitted).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFF86EFAC),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.nightlight_round, color: Color(0xFF0D9488), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    Text(
                      '10:00 PM Daily Remittance Closeout',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF065F46),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Next Batch in ${hours}h ${minutes}m',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'All orders delivered today before 10:00 PM are automatically reconciled, fee-deducted, and scheduled for bank disbursement. Currently, $pendingOrdersCount orders are queued for tonight\'s closeout.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF047857),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetCustodyCard(BuildContext context, Map<String, dynamic> custodyData, bool isDark) {
    final currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

    final double liquidInCustody = (custodyData['liquid_cash_in_custody'] as num?)?.toDouble() ?? 0.0;
    final double codInVault = (custodyData['physical_cod_in_dc_vault'] as num?)?.toDouble() ?? 0.0;
    final double directInPaystack = (custodyData['direct_transfer_in_paystack'] as num?)?.toDouble() ?? 0.0;

    final double inventoryEstimated = (custodyData['inventory_estimated_retail_value'] as num?)?.toDouble() ?? 0.0;
    final double inventoryBaseline = (custodyData['inventory_baseline_liquidation_value'] as num?)?.toDouble() ?? 0.0;
    final int totalUnits = (custodyData['total_inventory_units_held'] as num?)?.toInt() ?? 0;

    final double grandTotalValue = (custodyData['grand_total_asset_value'] as num?)?.toDouble() ?? (liquidInCustody + inventoryEstimated);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              final headerText = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Asset Custody & Valuation',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                  Text(
                    'Liquid funds in NovaExpress custody + In-kind warehouse inventory valuation',
                    style: GoogleFonts.inter(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ],
              );

              final totalBadge = Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF37021).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF37021).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: isWide ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text('Total Capital in Custody', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFF37021), fontWeight: FontWeight.w600)),
                    Text(currency.format(grandTotalValue), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFFF37021))),
                  ],
                ),
              );

              return isWide
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: headerText),
                        const SizedBox(width: 14),
                        totalBadge,
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        headerText,
                        const SizedBox(height: 12),
                        totalBadge,
                      ],
                    );
            },
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // 2 Sub-Cards: Liquid Cash vs In-Kind Inventory
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              final leftCard = Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF0D9488), size: 20),
                        const SizedBox(width: 8),
                        Text('Liquid Cash in Custody', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(currency.format(liquidInCustody), style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF0D9488))),
                    const SizedBox(height: 12),
                    _buildSubDetailRow('Physical COD in DC Vaults', currency.format(codInVault)),
                    _buildSubDetailRow('Digital Transfers in Paystack', currency.format(directInPaystack)),
                    const SizedBox(height: 6),
                    Text('Disbursed daily at 10:00 PM closeout.', style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: const Color(0xFF64748B))),
                  ],
                ),
              );

              final rightCard = Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_rounded, color: Color(0xFF3B82F6), size: 20),
                        const SizedBox(width: 8),
                        Text('In-Kind Inventory Holdings', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(currency.format(inventoryBaseline), style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF3B82F6))),
                    const SizedBox(height: 12),
                    _buildSubDetailRow('Total Physical Units in Custody', '$totalUnits units'),
                    _buildSubDetailRow('Asset Valuation at Cost (COGS)', currency.format(inventoryBaseline)),
                    _buildSubDetailRow('Potential Retail Value', currency.format(inventoryEstimated)),
                    const SizedBox(height: 6),
                    Text('Tracked in real time across DC shelves and delivery vans.', style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: const Color(0xFF64748B))),
                  ],
                ),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    leftCard,
                    const SizedBox(height: 12),
                    rightCard,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: leftCard),
                  const SizedBox(width: 16),
                  Expanded(child: rightCard),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Merchant Physical Inventory Custody Ledger Table
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shelves, size: 16, color: Color(0xFFF37021)),
                    const SizedBox(width: 8),
                    Text(
                      'Physical Working Capital by Custody Location',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2.5),
                    1: FlexColumnWidth(1.5),
                    2: FlexColumnWidth(2.0),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text('Location', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text('Physical Units', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text('Valuation at Cost', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text('DC Warehouse Shelves', style: GoogleFonts.inter(fontSize: 12)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text('${(totalUnits * 0.85).round()} units', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(currency.format(inventoryBaseline * 0.85), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text('Rider Active Vehicle Custody', style: GoogleFonts.inter(fontSize: 12)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text('${(totalUnits * 0.15).round()} units', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(currency.format(inventoryBaseline * 0.15), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B))),
                        ),
                      ],
                    ),
                    TableRow(
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 2),
                          child: Text('Total Physical Inventory', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 2),
                          child: Text('$totalUnits units', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 2),
                          child: Text(currency.format(inventoryBaseline), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF10B981))),
                        ),
                      ],
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

  Widget _buildSubDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
          Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildDailySettlementsTable(BuildContext context, List<ClientSettlement> settlements, bool isDark) {
    final currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 2);

    if (settlements.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 40, color: Color(0xFF94A3B8)),
              const SizedBox(height: 10),
              Text('No Daily Settlement Batches Yet', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
              Text('Batches finalized at 10:00 PM will appear here with itemized deductions and payment receipts.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text('Daily Settlement Batches & Receipts', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
                Text('${settlements.length} Batches Processed', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: settlements.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, idx) {
              final s = settlements[idx];
              return ExpansionTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF0D9488), size: 20),
                ),
                title: Text(s.settlementNumber, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(
                  'Settled: ${DateFormat('MMM dd, yyyy - hh:mm a').format(s.settledAt)} | ${s.totalOrdersCount} Orders',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(currency.format(s.netPayoutAmount), style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: const Color(0xFF0D9488))),
                    Text('Disbursed to ${s.destinationBankName.isNotEmpty ? s.destinationBankName : "Bank"}', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                  ],
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    child: Column(
                      children: [
                        _buildSettlementDetailRow('Gross Sales Collected', currency.format(s.grossCollections)),
                        _buildSettlementDetailRow('Logistics Delivery Fees', '- ${currency.format(s.logisticsFeesDeducted)}', isNegative: true),
                        _buildSettlementDetailRow('Platform Commission Fees', '- ${currency.format(s.platformFeesDeducted)}', isNegative: true),
                        _buildSettlementDetailRow('Paystack Gateway Charges', '- ${currency.format(s.gatewayFeesDeducted)}', isNegative: true),
                        if (s.failedAttemptFeesDeducted > 0)
                          _buildSettlementDetailRow('Failed Attempt Charges', '- ${currency.format(s.failedAttemptFeesDeducted)}', isNegative: true),
                        if (s.otherChargesDeducted > 0)
                          _buildSettlementDetailRow('Auxiliary Charges', '- ${currency.format(s.otherChargesDeducted)}', isNegative: true),
                        const Divider(height: 16),
                        _buildSettlementDetailRow('Net Disbursed to Bank', currency.format(s.netPayoutAmount), isBold: true),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _showSettlementReceiptModal(context, s, isDark, currency),
                              icon: const Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFF0D9488)),
                              label: Text(
                                'View Statement / Receipt',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0D9488)),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF0D9488)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (s.payoutReference != null && s.payoutReference!.isNotEmpty)
                                  Text('Bank Ref: ${s.payoutReference}  |  ', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Cleared & Reconciled',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showSettlementReceiptModal(BuildContext context, ClientSettlement s, bool isDark, NumberFormat currency) {
    showDialog(
      context: context,
      builder: (ctx) {
        final formattedDate = DateFormat('MMMM dd, yyyy - hh:mm a').format(s.settledAt);
        final receiptText = '''
======================================================
NOVEXPS LOGISTICS & E-COMMERCE CLEARINGHOUSE
MERCHANT DAILY DISBURSEMENT STATEMENT
======================================================
Settlement Reference : ${s.settlementNumber}
Bank Disbursement Ref: ${s.payoutReference ?? "DISB-AUTOCLEAR"}
Status               : Cleared & Reconciled
Period End (Cutoff)  : ${DateFormat('yyyy-MM-dd 22:00').format(s.periodEnd)}
Cleared Timestamp    : $formattedDate
Total Orders Settled : ${s.totalOrdersCount}

DESTINATION BANK ACCOUNT:
Bank Name            : ${s.destinationBankName.isNotEmpty ? s.destinationBankName : "Registered Merchant Bank"}
Account Number       : ${s.destinationAccountNumber.isNotEmpty ? s.destinationAccountNumber : "NUBAN on file"}

ITEMIZED CLEARINGHOUSE BREAKDOWN:
+ Gross Collections   : ${currency.format(s.grossCollections)}
- Logistics Fees      : ${currency.format(s.logisticsFeesDeducted)}
- Platform Commission : ${currency.format(s.platformFeesDeducted)}
- Paystack Gateway Fee: ${currency.format(s.gatewayFeesDeducted)}
- Failed Order Charge : ${currency.format(s.failedAttemptFeesDeducted)}
- Auxiliary Charges   : ${currency.format(s.otherChargesDeducted)}
------------------------------------------------------
NET DISBURSED TO BANK: ${currency.format(s.netPayoutAmount)}
======================================================
''';

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF0D9488), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disbursement Statement Voucher',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      s.settlementNumber,
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, color: const Color(0xFF0D9488), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('NET DISBURSED AMOUNT', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('Cleared ⚡', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          currency.format(s.netPayoutAmount),
                          style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w900, color: const Color(0xFF0D9488)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Credited to ${s.destinationBankName.isNotEmpty ? s.destinationBankName : "Bank"} • Ref: ${s.payoutReference ?? "Direct Clearing"}',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('CLEARINGHOUSE DEDUCTION SUMMARY', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B))),
                  const SizedBox(height: 8),
                  _buildSettlementDetailRow('Gross Customer Collections', currency.format(s.grossCollections)),
                  _buildSettlementDetailRow('Logistics Delivery Fees', '- ${currency.format(s.logisticsFeesDeducted)}', isNegative: true),
                  _buildSettlementDetailRow('Platform Commission Fees', '- ${currency.format(s.platformFeesDeducted)}', isNegative: true),
                  _buildSettlementDetailRow('Paystack Gateway Charges', '- ${currency.format(s.gatewayFeesDeducted)}', isNegative: true),
                  if (s.failedAttemptFeesDeducted > 0)
                    _buildSettlementDetailRow('Failed Delivery Attempt Charges', '- ${currency.format(s.failedAttemptFeesDeducted)}', isNegative: true),
                  if (s.otherChargesDeducted > 0)
                    _buildSettlementDetailRow('Auxiliary Charges', '- ${currency.format(s.otherChargesDeducted)}', isNegative: true),
                  const Divider(height: 16),
                  _buildSettlementDetailRow('Total Cleared Orders', '${s.totalOrdersCount} Completed Deliveries'),
                  _buildSettlementDetailRow('Settlement Cutoff Time', DateFormat('MMM dd, yyyy - 10:00 PM').format(s.periodEnd)),
                  _buildSettlementDetailRow('Cleared At', formattedDate),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: receiptText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFF10B981),
                    content: Text('Disbursement statement copied to clipboard! Ready to export/print.'),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy Statement'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
              ),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettlementDetailRow(String label, String value, {bool isNegative = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: isBold ? 13 : 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isNegative ? const Color(0xFFEF4444) : null,
            ),
          ),
        ],
      ),
    );
  }
}
