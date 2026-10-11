import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/business_expenditure.dart';
import '../../domain/entities/merchant_financial_metrics.dart';
import '../../data/repositories/expenditure_repository.dart';
import '../providers/client_portal_provider.dart';
import 'client_add_expenditure_modal.dart';

class MerchantFinancialIntelligenceView extends ConsumerStatefulWidget {
  final String clientId;

  const MerchantFinancialIntelligenceView({
    super.key,
    required this.clientId,
  });

  @override
  ConsumerState<MerchantFinancialIntelligenceView> createState() => _MerchantFinancialIntelligenceViewState();
}

class _MerchantFinancialIntelligenceViewState extends ConsumerState<MerchantFinancialIntelligenceView> {
  final ExpenditureRepository _repo = ExpenditureRepository();

  String? _selectedProductId;
  late DateTime _startDate;
  late DateTime _endDate;
  String _selectedQuickRange = '30d';

  bool _isLoading = true;
  MerchantFinancialMetrics? _metrics;
  List<BusinessExpenditureEntity> _expenditures = [];

  final currencyFormat = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = _endDate.subtract(const Duration(days: 30));
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final metricsFuture = _repo.fetchMerchantFinancialDashboard(
        clientId: widget.clientId,
        productId: _selectedProductId,
        startDate: _startDate,
        endDate: _endDate,
      );

      final expFuture = _repo.fetchMerchantExpenditures(
        clientId: widget.clientId,
        productId: _selectedProductId,
        startDate: _startDate,
        endDate: _endDate,
      );

      final results = await Future.wait([metricsFuture, expFuture]);
      if (mounted) {
        setState(() {
          _metrics = results[0] as MerchantFinancialMetrics;
          _expenditures = results[1] as List<BusinessExpenditureEntity>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyQuickRange(String rangeKey) {
    final now = DateTime.now();
    setState(() {
      _selectedQuickRange = rangeKey;
      _endDate = now;
      if (rangeKey == 'today') {
        _startDate = DateTime(now.year, now.month, now.day);
      } else if (rangeKey == '7d') {
        _startDate = now.subtract(const Duration(days: 7));
      } else if (rangeKey == '30d') {
        _startDate = now.subtract(const Duration(days: 30));
      } else if (rangeKey == 'this_month') {
        _startDate = DateTime(now.year, now.month, 1);
      } else if (rangeKey == 'all_time') {
        _startDate = DateTime(2024, 1, 1);
      }
    });
    _loadData();
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF10B981),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedQuickRange = 'custom';
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientState = ref.watch(clientPortalProvider);
    final products = clientState.products;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 768;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
      ),
      padding: EdgeInsets.all(isCompact ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. HEADER WITH CONTROLS (Product Filter, Date Range & Record Action)
          _buildFilterControlBar(context, products, isCompact),
          const SizedBox(height: 20),

          // 2. LOADING OR DASHBOARD CONTENT
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF10B981)),
              ),
            )
          else ...[
            // 3. PRODUCT UNIT ECONOMICS BANNER (When a specific product is filtered)
            if (_selectedProductId != null && _metrics?.productEconomics != null) ...[
              _buildProductEconomicsBanner(_metrics!.productEconomics!),
              const SizedBox(height: 20),
            ],

            // 4. THE 8 CORE BUSINESS METRICS KPI GRID
            _buildLegacyEightMetricsGrid(isCompact),
            const SizedBox(height: 24),

            // 5. CHARTS: DUAL-SERIES COMPARISON & STATE BREAKDOWN
            _buildChartsSection(isCompact),
            const SizedBox(height: 24),

            // 6. RECENT EXPENDITURES TABLE
            _buildExpendituresLedgerTable(isCompact),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterControlBar(BuildContext context, List<dynamic> products, bool isCompact) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // Left: Product Filter Dropdown (The Ultimate Key Feature)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isCompact ? double.infinity : 360),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.filter_list_rounded, size: 14, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 6),
                    Text(
                      'PRODUCT FILTER',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: const Color(0xFF38BDF8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selectedProductId,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF0F172A),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8)),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            '🌟 All Products (Consolidated Business)',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ...products.map((p) {
                          return DropdownMenuItem<String?>(
                            value: p.id,
                            child: Text(
                              '📦 ${p.name} (${p.sku ?? 'SKU'})',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedProductId = val);
                        _loadData();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Center: Quick Date Range Chips & Range Picker
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildRangeChip('Today', 'today'),
              _buildRangeChip('7 Days', '7d'),
              _buildRangeChip('30 Days', '30d'),
              _buildRangeChip('This Month', 'this_month'),
              _buildRangeChip('All Time', 'all_time'),
              InkWell(
                onTap: _pickCustomDateRange,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _selectedQuickRange == 'custom'
                        ? const Color(0xFF10B981).withValues(alpha: 0.2)
                        : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedQuickRange == 'custom'
                          ? const Color(0xFF10B981)
                          : const Color(0xFF334155),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.date_range_rounded, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      Text(
                        '${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM').format(_endDate)}',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Right: Record Expenditure CTA Button
          ElevatedButton.icon(
            onPressed: () async {
              final result = await ClientAddExpenditureModal.show(
                context,
                clientId: widget.clientId,
                initialProductId: _selectedProductId,
              );
              if (result != null) {
                _loadData();
              }
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('Record Expense', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF43F5E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeChip(String label, String key) {
    final isSelected = _selectedQuickRange == key;
    return InkWell(
      onTap: () => _applyQuickRange(key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10B981) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  Widget _buildProductEconomicsBanner(ProductEconomicsEntity econ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1E3A8A).withValues(alpha: 0.3), const Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.analytics_rounded, color: Color(0xFF60A5FA), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SKU Unit Economics: ${econ.productName} (${econ.sku ?? 'SKU'})',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _subMeta('Units Sold', '${econ.unitsSold} pcs'),
                    _subMeta('Selling Price', '₦${currencyFormat.format(econ.basePrice)}'),
                    _subMeta('Cost Price', '₦${currencyFormat.format(econ.costPrice)}'),
                    _subMeta('Direct Ad Spend', '₦${currencyFormat.format(econ.directAdvertising)}'),
                    _subMeta('Direct Net Margin', '₦${currencyFormat.format(econ.directProfit)}', highlight: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _subMeta(String label, String value, {bool highlight = false}) {
    return RichText(
      text: TextSpan(
        text: '$label: ',
        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
        children: [
          TextSpan(
            text: value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: highlight ? const Color(0xFF10B981) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegacyEightMetricsGrid(bool isCompact) {
    final m = _metrics ?? MerchantFinancialMetrics.empty();

    final cards = [
      _MetricData(
        title: 'Expenditures',
        value: '₦${currencyFormat.format(m.totalExpenditures)}',
        icon: Icons.payments_rounded,
        color: const Color(0xFFF43F5E),
        badgeText: 'Total OpEx & Ads',
      ),
      _MetricData(
        title: 'Sales Revenue',
        value: '₦${currencyFormat.format(m.salesRevenue)}',
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF10B981),
        badgeText: 'Delivered Value',
      ),
      _MetricData(
        title: 'Quantity Sold',
        value: '${m.quantitySold} units',
        icon: Icons.shopping_bag_rounded,
        color: const Color(0xFF38BDF8),
        badgeText: 'Fulfilled Volume',
      ),
      _MetricData(
        title: 'Net Profit',
        value: '₦${currencyFormat.format(m.netProfit)}',
        icon: Icons.account_balance_wallet_rounded,
        color: m.netProfit >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        badgeText: m.salesRevenue > 0
            ? '${((m.netProfit / m.salesRevenue) * 100).toStringAsFixed(1)}% margin'
            : '0% margin',
      ),
      _MetricData(
        title: 'Available Stock',
        value: '${m.availableStock} pcs',
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFFA855F7),
        badgeText: 'Live Vault Balance',
      ),
      _MetricData(
        title: 'Advertisement',
        value: '₦${currencyFormat.format(m.advertisementExpenditure)}',
        icon: Icons.campaign_rounded,
        color: const Color(0xFFF59E0B),
        badgeText: 'Marketing Spend',
      ),
      _MetricData(
        title: 'Procurement',
        value: '₦${currencyFormat.format(m.procurementExpenditure)}',
        icon: Icons.local_shipping_rounded,
        color: const Color(0xFF06B6D4),
        badgeText: 'Restock Inflow',
      ),
      _MetricData(
        title: 'Revenue Till Date',
        value: '₦${currencyFormat.format(m.revenueTillDate)}',
        icon: Icons.stars_rounded,
        color: const Color(0xFFEC4899),
        badgeText: 'Lifetime Gross',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1100
            ? 4
            : constraints.maxWidth > 650
                ? 2
                : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: crossAxisCount == 1 ? 3.0 : 1.9,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final card = cards[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: card.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(card.icon, size: 20, color: card.color),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: card.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          card.badgeText,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: card.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.title,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        card.value,
                        style: GoogleFonts.outfit(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChartsSection(bool isCompact) {
    final dailyTrends = _metrics?.dailyTrends ?? [];
    final stateDist = _metrics?.stateDistribution ?? [];

    if (isCompact) {
      return Column(
        children: [
          _buildDailyTrendCard(dailyTrends),
          const SizedBox(height: 16),
          _buildStateDistributionCard(stateDist),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: _buildDailyTrendCard(dailyTrends)),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: _buildStateDistributionCard(stateDist)),
      ],
    );
  }

  Widget _buildDailyTrendCard(List<DailyTrendPoint> trends) {
    final hasData = trends.any((t) => t.sales > 0 || t.expenditure > 0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Revenue vs. Expenditures Trend',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Row(
                children: [
                  _legendDot('Sales', const Color(0xFF10B981)),
                  const SizedBox(width: 12),
                  _legendDot('Expenditure', const Color(0xFFF43F5E)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasData)
            Container(
              height: 180,
              alignment: Alignment.center,
              child: Text(
                'No transactions recorded in this date range.',
                style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: trends.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final pt = trends[index];
                  final maxVal = trends.fold<double>(1.0, (prev, e) => e.sales > prev ? e.sales : (e.expenditure > prev ? e.expenditure : prev));
                  final salesHeight = (pt.sales / maxVal) * 110.0;
                  final expHeight = (pt.expenditure / maxVal) * 110.0;

                  return SizedBox(
                    width: 44,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              width: 14,
                              height: salesHeight < 4 ? 4 : salesHeight,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 14,
                              height: expHeight < 4 ? 4 : expHeight,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF43F5E),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          pt.date.split('-').last,
                          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
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

  Widget _legendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFCBD5E1))),
      ],
    );
  }

  Widget _buildStateDistributionCard(List<StateRevenuePoint> states) {
    final totalStateRev = states.fold<double>(0.0, (prev, s) => prev + s.revenue);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue by States',
            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          if (states.isEmpty)
            Container(
              height: 180,
              alignment: Alignment.center,
              child: Text(
                'No regional orders delivered yet.',
                style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
              ),
            )
          else
            Column(
              children: states.take(5).map((st) {
                final pct = totalStateRev > 0 ? (st.revenue / totalStateRev) : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(st.state, style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
                          Text('₦${currencyFormat.format(st.revenue)} (${(pct * 100).toStringAsFixed(1)}%)', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF38BDF8))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 5,
                          backgroundColor: const Color(0xFF334155),
                          color: const Color(0xFF38BDF8),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildExpendituresLedgerTable(bool isCompact) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Operating Expenditures Ledger',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                '${_expenditures.length} Recorded Entries',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_expenditures.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 30),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 36, color: Color(0xFF64748B)),
                  const SizedBox(height: 8),
                  Text(
                    'No expenditures recorded in this period.',
                    style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _expenditures.length,
              separatorBuilder: (context, index) => const Divider(color: Color(0xFF334155), height: 1),
              itemBuilder: (context, index) {
                final exp = _expenditures[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_rounded, size: 18, color: Color(0xFFF43F5E)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exp.title,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${DateFormat('dd MMM yyyy').format(exp.expenditureDate)} • ${exp.category.label}',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₦${currencyFormat.format(exp.amount)}',
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFFF43F5E)),
                      ),
                      if (exp.hasReceipt) ...[
                        const SizedBox(width: 12),
                        IconButton(
                          icon: Icon(
                            exp.isPdfReceipt ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                            size: 18,
                            color: const Color(0xFF38BDF8),
                          ),
                          tooltip: 'View Attached Receipt',
                          onPressed: () async {
                            final uri = Uri.parse(exp.receiptUrl!);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _MetricData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String badgeText;

  _MetricData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.badgeText,
  });
}
