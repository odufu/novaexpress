import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../client_portal/data/repositories/expenditure_repository.dart';
import '../../../client_portal/presentation/widgets/client_add_expenditure_modal.dart';

class DcFinancialIntelligenceView extends ConsumerStatefulWidget {
  final String? dcId;
  final bool isGrandDc;

  const DcFinancialIntelligenceView({
    super.key,
    this.dcId,
    required this.isGrandDc,
  });

  @override
  ConsumerState<DcFinancialIntelligenceView> createState() => _DcFinancialIntelligenceViewState();
}

class _DcFinancialIntelligenceViewState extends ConsumerState<DcFinancialIntelligenceView> {
  final ExpenditureRepository _repo = ExpenditureRepository();
  final currencyFormat = NumberFormat('#,##0.00', 'en_US');

  bool _isLoading = true;
  Map<String, dynamic> _data = {};
  late DateTime _startDate;
  late DateTime _endDate;
  String _selectedQuickRange = '30d';

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
      final res = await _repo.fetchDcLogisticsDashboard(
        dcId: widget.isGrandDc ? null : widget.dcId,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (mounted) {
        setState(() {
          _data = res;
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

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 768;

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
          // Header Bar
          _buildHeaderBar(isCompact),
          const SizedBox(height: 20),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8))),
            )
          else ...[
            // The 8 Logistics Business Metrics KPI Cards
            _buildLogisticsEightKpiGrid(isCompact),
            const SizedBox(height: 24),

            // Regional Hub Breakdown (for Grand DC view)
            if (widget.isGrandDc && (_data['dc_breakdown'] is List && (_data['dc_breakdown'] as List).isNotEmpty)) ...[
              _buildRegionalHubBreakdownTable(isCompact),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderBar(bool isCompact) {
    final title = widget.isGrandDc
        ? 'Grand Console: Enterprise Logistics Intelligence'
        : 'Station Logistics Financial Intelligence';
    final sub = widget.isGrandDc
        ? 'Consolidated Network Revenue, Fleet OpEx, Vault Balances & Platform Margin'
        : 'Local Hub Operating Revenue, Station Generator Diesel & Rider Compensation';

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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.hub_rounded, color: Color(0xFF38BDF8), size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(sub, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                ],
              ),
            ],
          ),

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

              ElevatedButton.icon(
                onPressed: () async {
                  final result = await ClientAddExpenditureModal.show(
                    context,
                    clientId: widget.dcId ?? '11111111-1111-4111-8111-111111111111',
                  );
                  if (result != null) {
                    _loadData();
                  }
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text('Record OpEx', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF43F5E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.black : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  Widget _buildLogisticsEightKpiGrid(bool isCompact) {
    final gross = (_data['logistics_gross_revenue'] is num) ? (_data['logistics_gross_revenue'] as num).toDouble() : 0.0;
    final opex = (_data['network_opex'] is num) ? (_data['network_opex'] as num).toDouble() : 0.0;
    final parcels = (_data['total_parcels_handled'] is num) ? (_data['total_parcels_handled'] as num).toInt() : 0;
    final netMargin = (_data['net_logistics_margin'] is num) ? (_data['net_logistics_margin'] as num).toDouble() : 0.0;
    final vault = (_data['vault_inventory'] is num) ? (_data['vault_inventory'] as num).toInt() : 0;
    final riderPayout = (_data['rider_allowances'] is num) ? (_data['rider_allowances'] as num).toDouble() : 0.0;
    final facilityCapex = (_data['facility_capex'] is num) ? (_data['facility_capex'] as num).toDouble() : 0.0;
    final cumulative = (_data['cumulative_revenue'] is num) ? (_data['cumulative_revenue'] as num).toDouble() : 0.0;

    final cards = [
      _DcKpiData(
        title: widget.isGrandDc ? 'Network Operating Exp' : 'Local Station OpEx',
        value: '₦${currencyFormat.format(opex)}',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFFF43F5E),
        badgeText: 'Diesel, Repairs, Hub Leases',
      ),
      _DcKpiData(
        title: widget.isGrandDc ? 'Logistics Gross Revenue' : 'Station Handling Revenue',
        value: '₦${currencyFormat.format(gross)}',
        icon: Icons.local_shipping_rounded,
        color: const Color(0xFF10B981),
        badgeText: 'Delivery Fee Billings',
      ),
      _DcKpiData(
        title: 'Parcels Dispatched',
        value: '$parcels items',
        icon: Icons.inventory_rounded,
        color: const Color(0xFF38BDF8),
        badgeText: 'Network Throughput',
      ),
      _DcKpiData(
        title: 'Net Platform Profit',
        value: '₦${currencyFormat.format(netMargin)}',
        icon: Icons.account_balance_rounded,
        color: netMargin >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        badgeText: gross > 0 ? '${((netMargin / gross) * 100).toStringAsFixed(1)}% margin' : '0% margin',
      ),
      _DcKpiData(
        title: 'Consolidated Vault Stock',
        value: '$vault pcs',
        icon: Icons.warehouse_rounded,
        color: const Color(0xFFA855F7),
        badgeText: 'Physical Custody',
      ),
      _DcKpiData(
        title: 'Rider Allowances & Fuel',
        value: '₦${currencyFormat.format(riderPayout)}',
        icon: Icons.two_wheeler_rounded,
        color: const Color(0xFFF59E0B),
        badgeText: 'Fleet Payouts',
      ),
      _DcKpiData(
        title: 'Facility Capex & Maintenance',
        value: '₦${currencyFormat.format(facilityCapex)}',
        icon: Icons.build_rounded,
        color: const Color(0xFF06B6D4),
        badgeText: 'Generator & Station Upkeep',
      ),
      _DcKpiData(
        title: 'Cumulative System Revenue',
        value: '₦${currencyFormat.format(cumulative)}',
        icon: Icons.workspace_premium_rounded,
        color: const Color(0xFFEC4899),
        badgeText: 'Lifetime Logistics Fees',
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
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: card.color),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.title, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                      const SizedBox(height: 4),
                      Text(
                        card.value,
                        style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
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

  Widget _buildRegionalHubBreakdownTable(bool isCompact) {
    final list = _data['dc_breakdown'] as List;

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
                'Regional Hub Performance & Revenue Breakdown',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text('${list.length} Distribution Hubs Active', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (context, index) => const Divider(color: Color(0xFF334155), height: 1),
            itemBuilder: (context, index) {
              final hub = Map<String, dynamic>.from(list[index]);
              final rev = (hub['revenue'] is num) ? (hub['revenue'] as num).toDouble() : 0.0;
              final parcels = (hub['parcels'] is num) ? (hub['parcels'] as num).toInt() : 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.location_city_rounded, size: 18, color: Color(0xFF38BDF8)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hub['dc_name']?.toString() ?? 'Hub',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            '${hub['city'] ?? 'Nigeria'} • $parcels consignments delivered',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₦${currencyFormat.format(rev)}',
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
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
}

class _DcKpiData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String badgeText;

  _DcKpiData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.badgeText,
  });
}
