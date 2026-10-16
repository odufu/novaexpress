import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:novexps/core/helpers/formatters.dart';
import 'package:novexps/core/theme/theme_provider.dart';
import 'package:novexps/features/client_portal/domain/entities/client_settlement.dart';
import 'package:novexps/features/client_portal/presentation/providers/client_portal_provider.dart';
import 'package:novexps/features/client_portal/presentation/widgets/client_daily_accumulator_modal.dart';
import 'package:novexps/features/client_portal/presentation/widgets/client_settlement_detail_modal.dart';

class ClientRemittanceView extends ConsumerStatefulWidget {
  const ClientRemittanceView({super.key});

  @override
  ConsumerState<ClientRemittanceView> createState() => _ClientRemittanceViewState();
}

class _ClientRemittanceViewState extends ConsumerState<ClientRemittanceView> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedStatus = 'all'; // 'all', 'completed', 'remitted'
  String _selectedDateRange = '30d'; // 'today', '7d', '30d', 'this_month', 'all', 'custom'
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  String _searchQuery = '';

  final currencyFormat = NumberFormat('#,##0.00', 'en_US');
  final dateFormat = DateFormat('dd MMM yyyy');
  final dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_searchQuery != _searchController.text) {
        setState(() => _searchQuery = _searchController.text);
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

  List<ClientSettlement> _getFilteredSettlements(List<ClientSettlement> all) {
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
    } else if (_selectedDateRange == 'custom' && _customStartDate != null) {
      start = _customStartDate;
      end = _customEndDate ?? now;
    }

    return all.where((s) {
      // Date filter (using settledAt or createdAt)
      if (start != null) {
        final sDate = DateTime(s.settledAt.year, s.settledAt.month, s.settledAt.day);
        final startDateOnly = DateTime(start.year, start.month, start.day);
        if (sDate.isBefore(startDateOnly)) return false;
      }
      if (end != null) {
        final sDate = DateTime(s.settledAt.year, s.settledAt.month, s.settledAt.day);
        final endDateOnly = DateTime(end.year, end.month, end.day, 23, 59, 59);
        if (sDate.isAfter(endDateOnly)) return false;
      }

      // Status filter
      if (_selectedStatus != 'all') {
        if (_selectedStatus == 'completed' && !s.isCompleted) return false;
        if (_selectedStatus == 'remitted' && !s.isRemitted) return false;
      }

      // Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchNum = s.settlementNumber.toLowerCase().contains(q);
        final matchBank = s.destinationBankName.toLowerCase().contains(q);
        final matchRef = (s.payoutReference ?? '').toLowerCase().contains(q);
        final matchAcc = s.destinationAccountNumber.toLowerCase().contains(q);
        if (!matchNum && !matchBank && !matchRef && !matchAcc) return false;
      }

      return true;
    }).toList();
  }

  void _showSettlementDetailSheet(BuildContext context, ClientSettlement s, bool isDark) {
    final profile = ref.read(clientPortalProvider).clientProfile;

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
          maxHeight: MediaQuery.of(context).size.height * 0.88,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.settlementNumber,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Settled: ${dateTimeFormat.format(s.settledAt)}',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: s.isRemitted
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                              : const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          s.isRemitted ? 'Pending Approval' : 'Settled & Paid',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: s.isRemitted ? const Color(0xFFD97706) : const Color(0xFF059669),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Net Payout Highlight Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Net Disbursed to Bank',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0D9488),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₦${currencyFormat.format(s.netPayoutAmount)}',
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0D9488),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.account_balance_rounded, color: Color(0xFF0D9488), size: 22),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text('Deduction Breakdown', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),

                  _buildSheetDetailRow('Gross Delivered Sales (${s.totalOrdersCount} orders)', '₦${currencyFormat.format(s.grossCollections)}', isDark),
                  _buildSheetDetailRow('NovaXpress Logistics Fees', '- ₦${currencyFormat.format(s.logisticsFeesDeducted)}', isDark, isNegative: true),
                  if (s.platformFeesDeducted > 0)
                    _buildSheetDetailRow('Platform Service Fee', '- ₦${currencyFormat.format(s.platformFeesDeducted)}', isDark, isNegative: true),
                  if (s.gatewayFeesDeducted > 0)
                    _buildSheetDetailRow('Payment Gateway Charges', '- ₦${currencyFormat.format(s.gatewayFeesDeducted)}', isDark, isNegative: true),
                  if (s.failedAttemptFeesDeducted > 0)
                    _buildSheetDetailRow('Failed Attempt Surcharge', '- ₦${currencyFormat.format(s.failedAttemptFeesDeducted)}', isDark, isNegative: true),
                  if (s.otherChargesDeducted > 0)
                    _buildSheetDetailRow('Auxiliary Operational Deductions', '- ₦${currencyFormat.format(s.otherChargesDeducted)}', isDark, isNegative: true),

                  const Divider(height: 24),
                  Text('Destination Bank Account', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),

                  _buildSheetDetailRow('Bank Name', s.destinationBankName.isNotEmpty ? s.destinationBankName : 'Verified Corporate Bank', isDark),
                  _buildSheetDetailRow('Account Number', s.destinationAccountNumber.isNotEmpty ? s.destinationAccountNumber : 'N/A', isDark),
                  if (s.destinationAccountName.isNotEmpty)
                    _buildSheetDetailRow('Account Name', s.destinationAccountName, isDark),
                  if (s.payoutReference != null && s.payoutReference!.isNotEmpty)
                    _buildSheetDetailRow('Transfer Reference', s.payoutReference!, isDark),

                  // Receipt Section if available
                  if (s.hasReceipt) ...[
                    const SizedBox(height: 20),
                    Text('Bank Transfer Proof / Receipt', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => launchUrl(Uri.parse(s.proofOfPaymentUrl!)),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long_rounded, color: Color(0xFF0D9488), size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Settlement Transfer Slip Attached', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                                  Text('Tap to preview or download official bank proof', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                                ],
                              ),
                            ),
                            const Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF0D9488)),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            ClientSettlementDetailModal.show(
                              context: context,
                              settlement: s,
                              clientName: profile.companyName,
                              clientLogo: profile.logoUrl,
                            );
                          },
                          icon: const Icon(Icons.list_alt_rounded, size: 16),
                          label: Text('Full Order Ledger', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D9488),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: Text('Close', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
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
    );
  }

  Widget _buildSheetDetailRow(String label, String value, bool isDark, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
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

    final allSettlements = state.settlements;
    final filteredSettlements = _getFilteredSettlements(allSettlements);

    // DYNAMIC FILTER RECALCULATION
    double totalCollected = 0;
    double totalLogisticsFees = 0;
    double totalNetRemitted = 0;
    int totalBatches = filteredSettlements.length;

    for (final s in filteredSettlements) {
      totalCollected += s.grossCollections;
      totalLogisticsFees += s.logisticsFeesDeducted;
      totalNetRemitted += s.netPayoutAmount;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isMobile
          ? FloatingActionButton.extended(
              onPressed: () => ClientDailyAccumulatorModal.show(context),
              backgroundColor: const Color(0xFF0D9488),
              icon: const Icon(Icons.analytics_rounded, color: Colors.white),
              label: Text('Accumulator', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(clientPortalProvider.notifier).loadClientData(),
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 24, vertical: 18),
          children: [
            // 1. OPEN METRIC STRIP (Dynamic recalculation on filter changes)
            _buildOpenMetricStrip(
              totalCollected: totalCollected,
              totalLogisticsFees: totalLogisticsFees,
              totalNetRemitted: totalNetRemitted,
              batchCount: totalBatches,
              isDark: isDark,
              isMobile: isMobile,
            ),
            const SizedBox(height: 20),

            // 2. DAILY 10:00 PM CLOSEOUT BANNER
            _buildLiveAccumulatorBanner(context, state, isDark, isMobile),
            const SizedBox(height: 20),

            // 3. INTEGRATED FILTER TOOLBAR WITH ACTION BUTTON ON FAR RIGHT
            _buildIntegratedFilterBar(context, isDark, isMobile),
            const SizedBox(height: 18),

            // 4. DATA PRESENTATION: DESKTOP TABLE vs MOBILE CONDENSED CARDS
            if (filteredSettlements.isEmpty)
              _buildEmptyState(isDark)
            else if (isMobile)
              _buildMobileCardsList(context, filteredSettlements, isDark)
            else
              _buildDesktopTable(context, filteredSettlements, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenMetricStrip({
    required double totalCollected,
    required double totalLogisticsFees,
    required double totalNetRemitted,
    required int batchCount,
    required bool isDark,
    required bool isMobile,
  }) {
    final metrics = [
      (
        label: 'Gross Collected',
        value: '₦${currencyFormat.format(totalCollected)}',
        subtext: 'Delivered COD collections',
        icon: Icons.payments_rounded,
        color: const Color(0xFF3B82F6),
      ),
      (
        label: 'Logistics Deductions',
        value: '-₦${currencyFormat.format(totalLogisticsFees)}',
        subtext: 'NovaXpress waybill fees',
        icon: Icons.local_shipping_rounded,
        color: const Color(0xFFEF4444),
      ),
      (
        label: 'Net Remitted',
        value: '₦${currencyFormat.format(totalNetRemitted)}',
        subtext: 'Disbursed to bank',
        icon: Icons.account_balance_rounded,
        color: const Color(0xFF10B981),
      ),
      (
        label: 'Settlement Batches',
        value: '$batchCount',
        subtext: 'Processed remittances',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF8B5CF6),
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

  Widget _buildLiveAccumulatorBanner(
    BuildContext context,
    ClientPortalState state,
    bool isDark,
    bool isMobile,
  ) {
    final awaitingOrders = state.financeOrders.where((o) => o.isDelivered && !o.isClientSettled).toList();
    final awaitingCount = awaitingOrders.length;
    final grossHolding = awaitingOrders.fold(0.0, (acc, o) => acc + o.totalAmount);
    final totalCharges = awaitingOrders.fold(0.0, (acc, o) => acc + o.clientDeliveryFee);
    final netExpected = (grossHolding - totalCharges).clamp(0.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
        ),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.schedule_rounded, color: Color(0xFF10B981), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily 10:00 PM Remittance',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Today\'s pending collection closeout',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Unsettled Net:', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                    Text('₦${_formatMoney(netExpected)}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0D9488))),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: () => ClientDailyAccumulatorModal.show(context),
                    icon: const Icon(Icons.analytics_rounded, size: 16),
                    label: Text('View Live Accumulator ($awaitingCount orders)', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.schedule_rounded, color: Color(0xFF10B981), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily 10:00 PM Settlement Automation',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'NovaXpress closes out daily collections at 10:00 PM and disburses net remittance to your bank with itemized deductions.',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Unsettled Today ($awaitingCount Orders)',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                    ),
                    Text(
                      '₦${_formatMoney(netExpected)}',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF0D9488)),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: () => ClientDailyAccumulatorModal.show(context),
                  icon: const Icon(Icons.analytics_rounded, size: 16),
                  label: Text(
                    'Live Accumulator',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildIntegratedFilterBar(BuildContext context, bool isDark, bool isMobile) {
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchField(isDark),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildStatusDropdown(isDark)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildDateDropdown(isDark)),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildSearchField(isDark),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: _buildStatusDropdown(isDark),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 150,
                  child: _buildDateDropdown(isDark),
                ),
                const SizedBox(width: 12),
                // Action button on far right
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Exporting remittance batches to CSV...')),
                    );
                  },
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: Text('Export', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    return TextField(
      controller: _searchController,
      style: GoogleFonts.inter(fontSize: 12.5),
      decoration: InputDecoration(
        hintText: 'Search batch #, bank, ref...',
        hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.grey),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 16),
                onPressed: () => _searchController.clear(),
              )
            : null,
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
    );
  }

  Widget _buildStatusDropdown(bool isDark) {
    return DropdownButtonFormField<String>(
      value: _selectedStatus,
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
        DropdownMenuItem(value: 'all', child: Text('All Statuses', style: TextStyle(fontSize: 12))),
        DropdownMenuItem(value: 'completed', child: Text('Settled & Paid', style: TextStyle(fontSize: 12))),
        DropdownMenuItem(value: 'remitted', child: Text('Pending Approval', style: TextStyle(fontSize: 12))),
      ],
      onChanged: (val) {
        if (val != null) setState(() => _selectedStatus = val);
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
            const Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(
              'No Remittance Batches Found',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Try adjusting your status or date filters to view finalized settlements.',
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
    List<ClientSettlement> list,
    bool isDark,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final s = list[idx];
        final isRemitted = s.isRemitted;

        return Material(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => _showSettlementDetailSheet(context, s, isDark),
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
                  // Line 1: Batch Number + Status Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s.settlementNumber,
                        style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isRemitted
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                              : const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isRemitted ? 'Pending Approval' : 'Settled',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isRemitted ? const Color(0xFFD97706) : const Color(0xFF059669),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Line 2: Settled Date + Orders Count + Bank
                  Row(
                    children: [
                      Text(
                        dateFormat.format(s.settledAt),
                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                      ),
                      Text(' • ', style: GoogleFonts.inter(color: Colors.grey)),
                      Text(
                        '${s.totalOrdersCount} orders',
                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                      ),
                      if (s.hasReceipt) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.attach_file_rounded, size: 12, color: Color(0xFF0D9488)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Line 3: Net Remitted Amount (bold) + Chevron
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Net Remitted to Bank', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                          Text(
                            '₦${currencyFormat.format(s.netPayoutAmount)}',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0D9488),
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

  Widget _buildDesktopTable(
    BuildContext context,
    List<ClientSettlement> list,
    bool isDark,
  ) {
    final profile = ref.read(clientPortalProvider).clientProfile;

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
                Expanded(flex: 2, child: Text('BATCH NUMBER', style: _tableHeaderStyle())),
                Expanded(flex: 2, child: Text('SETTLED DATE', style: _tableHeaderStyle())),
                Expanded(flex: 1, child: Text('ORDERS', style: _tableHeaderStyle())),
                Expanded(flex: 2, child: Text('GROSS COLLECTED', style: _tableHeaderStyle())),
                Expanded(flex: 2, child: Text('LOGISTICS DEDUCTION', style: _tableHeaderStyle())),
                Expanded(flex: 2, child: Text('NET DISBURSED', style: _tableHeaderStyle())),
                Expanded(flex: 2, child: Text('STATUS', style: _tableHeaderStyle())),
                SizedBox(width: 90, child: Text('ACTIONS', style: _tableHeaderStyle(), textAlign: TextAlign.right)),
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
              final s = list[idx];
              final isRemitted = s.isRemitted;

              return InkWell(
                onTap: () => _showSettlementDetailSheet(context, s, isDark),
                hoverColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Batch Number
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF0D9488)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                s.settlementNumber,
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Settled Date
                      Expanded(
                        flex: 2,
                        child: Text(
                          dateFormat.format(s.settledAt),
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ),
                      // Orders count
                      Expanded(
                        flex: 1,
                        child: Text(
                          '${s.totalOrdersCount}',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      // Gross Collected
                      Expanded(
                        flex: 2,
                        child: Text(
                          '₦${currencyFormat.format(s.grossCollections)}',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      // Logistics Deductions
                      Expanded(
                        flex: 2,
                        child: Text(
                          '-₦${currencyFormat.format(s.logisticsFeesDeducted)}',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFFEF4444)),
                        ),
                      ),
                      // Net Disbursed
                      Expanded(
                        flex: 2,
                        child: Text(
                          '₦${currencyFormat.format(s.netPayoutAmount)}',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                        ),
                      ),
                      // Status Badge
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: isRemitted
                                    ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                    : const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isRemitted ? 'Pending Approval' : 'Settled',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isRemitted ? const Color(0xFFD97706) : const Color(0xFF059669),
                                ),
                              ),
                            ),
                            if (s.hasReceipt) ...[
                              const SizedBox(width: 4),
                              Tooltip(
                                message: 'Transfer Receipt Attached',
                                child: const Icon(Icons.attach_file_rounded, size: 14, color: Color(0xFF0D9488)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Ghost Actions
                      SizedBox(
                        width: 90,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                              tooltip: 'View Breakdown',
                              onPressed: () {
                                ClientSettlementDetailModal.show(
                                  context: context,
                                  settlement: s,
                                  clientName: profile.companyName,
                                  clientLogo: profile.logoUrl,
                                );
                              },
                            ),
                            if (s.hasReceipt)
                              IconButton(
                                icon: const Icon(Icons.open_in_new_rounded, size: 15, color: Color(0xFF0D9488)),
                                tooltip: 'Open Receipt',
                                onPressed: () => launchUrl(Uri.parse(s.proofOfPaymentUrl!)),
                              ),
                          ],
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
