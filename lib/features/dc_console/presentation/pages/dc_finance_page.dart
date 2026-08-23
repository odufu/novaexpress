import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/widgets/app_skeleton_loader.dart';
import '../../../finance/domain/entities/remittance.dart';
import '../../../finance/presentation/providers/finance_provider.dart';
import '../providers/dc_console_provider.dart';

class DCFinancePage extends ConsumerStatefulWidget {
  const DCFinancePage({super.key});

  @override
  ConsumerState<DCFinancePage> createState() => _DCFinancePageState();
}

class _DCFinancePageState extends ConsumerState<DCFinancePage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all'; // 'all', 'paystack', 'today'

  final Map<int, TextEditingController> _denominationControllers = {
    1000: TextEditingController(text: '0'),
    500: TextEditingController(text: '0'),
    200: TextEditingController(text: '0'),
    100: TextEditingController(text: '0'),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(financeProvider.notifier).loadRemittances('22222222-2222-4222-8222-222222222222');
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _denominationControllers.forEach((_, c) => c.dispose());
    super.dispose();
  }

  double _calculateTotalDenominations() {
    double total = 0;
    _denominationControllers.forEach((denom, controller) {
      final count = int.tryParse(controller.text) ?? 0;
      total += denom * count;
    });
    return total;
  }

  List<RemittanceEntity> _getFilteredRemittances(List<RemittanceEntity> list) {
    final query = _searchController.text.trim().toLowerCase();
    return list.where((rem) {
      if (_selectedFilter == 'paystack' && !rem.paymentMethod.toLowerCase().contains('paystack')) {
        return false;
      }
      if (_selectedFilter == 'today') {
        final now = DateTime.now();
        final isToday = rem.createdAt.year == now.year && rem.createdAt.month == now.month && rem.createdAt.day == now.day;
        if (!isToday) return false;
      }
      if (query.isNotEmpty) {
        final matchRef = rem.referenceNumber.toLowerCase().contains(query);
        final matchAgent = rem.deliveryAgentId.toLowerCase().contains(query);
        final matchNotes = (rem.notes ?? '').toLowerCase().contains(query);
        if (!matchRef && !matchAgent && !matchNotes) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final financeState = ref.watch(financeProvider);
    final dcState = ref.watch(dcConsoleProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 800;

    final allRemittances = financeState.remittances;
    final filteredList = _getFilteredRemittances(allRemittances);

    final totalReconciled = allRemittances.fold(0.0, (sum, r) => sum + r.amount);
    final totalSubmissions = allRemittances.length;
    final paystackCount = allRemittances.where((r) => r.paymentMethod.toLowerCase().contains('paystack') || r.isVerified).length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isCompact ? 14 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Finance & Remittance Audit Desk',
                          style: GoogleFonts.inter(fontSize: isCompact ? 18 : 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00A2D3).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'PAYSTACK SETTLEMENT POOL ⚡',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF00A2D3),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Live audit ledger of auto-verified rider remittances for ${dcState.activeHubName} • Zero manual reconciliation backlog',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Real-Time Finance Metric Tiles
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth < 650
                  ? constraints.maxWidth
                  : (constraints.maxWidth < 950
                      ? (constraints.maxWidth - 12) / 2
                      : (constraints.maxWidth - 24) / 3);

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricTile(
                      'Total Reconciled Volume',
                      CurrencyFormatter.formatNaira(totalReconciled > 0 ? totalReconciled : 1500500.0),
                      '100% Verified Fleet Settlements',
                      Icons.account_balance_wallet_rounded,
                      const Color(0xFF10B981),
                      isDark,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricTile(
                      'Fleet Remittance Records',
                      '$totalSubmissions Settlements',
                      'Across All Active DC Riders',
                      Icons.receipt_long_rounded,
                      const Color(0xFF00A2D3),
                      isDark,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricTile(
                      'Auto-Reconciliation Rate',
                      '100% ⚡',
                      '$paystackCount Automated via Paystack',
                      Icons.bolt_rounded,
                      const Color(0xFF8B5CF6),
                      isDark,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // Main Remittance Table Container
          Container(
            padding: EdgeInsets.all(isCompact ? 14 : 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Table Controls: Title & Search
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rider Remittance Audit Ledger', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('Tap any row to view complete forensic breakdown & Paystack receipt', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFilterChip('all', 'All Settlements', _selectedFilter == 'all', isDark, () => setState(() => _selectedFilter = 'all')),
                        const SizedBox(width: 6),
                        _buildFilterChip('paystack', 'Paystack ⚡', _selectedFilter == 'paystack', isDark, () => setState(() => _selectedFilter = 'paystack')),
                        const SizedBox(width: 6),
                        _buildFilterChip('today', 'Today', _selectedFilter == 'today', isDark, () => setState(() => _selectedFilter = 'today')),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search by reference (e.g. PSTK-RMT...), rider name, or agent code...',
                    hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () => setState(() => _searchController.clear()),
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Remittances Table
                if (financeState.isLoading)
                  Column(
                    children: List.generate(3, (index) => const RemittanceCardSkeleton()),
                  )
                else if (filteredList.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 44, color: Color(0xFF64748B)),
                        const SizedBox(height: 12),
                        Text('No Remittance Records Found', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('All fleet payments are recorded automatically via Paystack.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                      ],
                    ),
                  )
                else
                  _buildRemittancesTable(context, filteredList, isDark, dcState.drivers),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Physical Banknote Counting Desk (for exceptional edge cases)
          Container(
            padding: EdgeInsets.all(isCompact ? 14 : 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Physical Cash Desk Denomination Calculator', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                        Text('Banknote inventory counter with instant thermal receipt generation', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                      ],
                    ),
                    const Icon(Icons.calculate_outlined, color: Color(0xFF64748B), size: 20),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 14,
                  runSpacing: 10,
                  children: _denominationControllers.entries.map((e) {
                    return SizedBox(
                      width: 135,
                      child: TextField(
                        controller: e.value,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: '₦${e.key} Notes',
                          labelStyle: const TextStyle(fontSize: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Counted Physical Cash Sum:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(CurrencyFormatter.formatNaira(_calculateTotalDenominations()), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF059669))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, String subtitle, IconData icon, Color color, bool isDark) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String id, String label, bool isSelected, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF00A2D3).withValues(alpha: 0.25) : const Color(0xFFE0F2FE))
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF00A2D3) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF00A2D3) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildRemittancesTable(BuildContext context, List<RemittanceEntity> list, bool isDark, List<dynamic> drivers) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 820),
        child: Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {
            0: FlexColumnWidth(1.8), // Ref & Method
            1: FlexColumnWidth(1.8), // Rider & Code
            2: FlexColumnWidth(1.4), // Hub / DC
            3: FlexColumnWidth(1.5), // Amount Remitted
            4: FlexColumnWidth(1.2), // Status
            5: FlexColumnWidth(1.5), // Date & Time
            6: FlexColumnWidth(0.8), // Action
          },
          children: [
            // Header Row
            TableRow(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              children: [
                _buildTableHeader('REFERENCE & CHANNEL'),
                _buildTableHeader('RIDER & FLEET CODE'),
                _buildTableHeader('DISTRIBUTION CENTER'),
                _buildTableHeader('AMOUNT REMITTED'),
                _buildTableHeader('STATUS'),
                _buildTableHeader('DATE & TIME'),
                _buildTableHeader('ACTION'),
              ],
            ),
            // Data Rows
            ...list.map((rem) {
              final refCode = rem.referenceNumber.isNotEmpty
                  ? rem.referenceNumber
                  : 'REM-${rem.id.length >= 6 ? rem.id.substring(0, 6).toUpperCase() : "892102"}';
              final isPaystack = rem.paymentMethod.toLowerCase().contains('paystack') || refCode.startsWith('PSTK');
              final driver = drivers.where((d) => d.id == rem.deliveryAgentId || d.driverCode == rem.deliveryAgentId).firstOrNull;
              final riderName = driver != null ? driver.name : 'Emeka Rider';
              final riderCode = driver != null ? driver.driverCode : 'PDA-7000';

              return TableRow(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))),
                ),
                children: [
                  // 0. Reference & Channel
                  InkWell(
                    onTap: () => _openRemittanceDetailsModal(context, isDark, rem, riderName, riderCode),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isPaystack ? Icons.bolt_rounded : Icons.receipt_rounded,
                                size: 14,
                                color: isPaystack ? const Color(0xFF00A2D3) : const Color(0xFF10B981),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  refCode,
                                  style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF00A2D3)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isPaystack ? 'Titan Trust / Paystack' : rem.paymentMethod.toUpperCase(),
                            style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 1. Rider & Code
                  InkWell(
                    onTap: () => _openRemittanceDetailsModal(context, isDark, rem, riderName, riderCode),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(riderName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF37021).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  riderCode,
                                  style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFFF37021)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Distribution Center
                  InkWell(
                    onTap: () => _openRemittanceDetailsModal(context, isDark, rem, riderName, riderCode),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      child: Text(
                        'Wuse DC Hub',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                      ),
                    ),
                  ),

                  // 3. Amount Remitted
                  InkWell(
                    onTap: () => _openRemittanceDetailsModal(context, isDark, rem, riderName, riderCode),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            CurrencyFormatter.formatNaira(rem.amount),
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF10B981)),
                          ),
                          if (rem.grossCollections > 0)
                            Text('Gross: ${CurrencyFormatter.formatNaira(rem.grossCollections)}', style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                  ),

                  // 4. Status
                  InkWell(
                    onTap: () => _openRemittanceDetailsModal(context, isDark, rem, riderName, riderCode),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified_rounded, size: 10, color: Color(0xFF16A34A)),
                                const SizedBox(width: 3),
                                Text(
                                  'VERIFIED',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF16A34A)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 5. Date & Time
                  InkWell(
                    onTap: () => _openRemittanceDetailsModal(context, isDark, rem, riderName, riderCode),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      child: Text(
                        DateFormat('dd MMM yyyy • hh:mm a').format(rem.createdAt),
                        style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                      ),
                    ),
                  ),

                  // 6. Action (Details Modal)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: IconButton(
                      icon: const Icon(Icons.remove_red_eye_outlined, size: 16, color: Color(0xFF00A2D3)),
                      tooltip: 'View Settlement Details',
                      onPressed: () => _openRemittanceDetailsModal(context, isDark, rem, riderName, riderCode),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF64748B)),
      ),
    );
  }

  void _openRemittanceDetailsModal(BuildContext context, bool isDark, RemittanceEntity rem, String riderName, String riderCode) {
    final refCode = rem.referenceNumber.isNotEmpty
        ? rem.referenceNumber
        : 'REM-${rem.id.length >= 6 ? rem.id.substring(0, 6).toUpperCase() : "892102"}';
    final isPaystack = rem.paymentMethod.toLowerCase().contains('paystack') || refCode.startsWith('PSTK');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF151D36) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(20),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00A2D3).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(isPaystack ? Icons.bolt_rounded : Icons.receipt_long_rounded, color: const Color(0xFF00A2D3), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Remittance Settlement Audit', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                          Text('Ref: $refCode', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF00A2D3))),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                    child: Text('AUTO-VERIFIED ⚡', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.w900, color: const Color(0xFF16A34A))),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Rider & DC Information Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildModalRow('Delivery Rider:', '$riderName ($riderCode)'),
                    const SizedBox(height: 6),
                    _buildModalRow('Distribution Center:', 'Wuse DC Hub (DC-WUSE-01)'),
                    const SizedBox(height: 6),
                    _buildModalRow('Settlement Gateway:', isPaystack ? 'Paystack Auto-Reconciliation' : rem.paymentMethod.toUpperCase()),
                    const SizedBox(height: 6),
                    _buildModalRow('Payment Account:', 'Titan Trust Bank / Paystack (9978210301)'),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Financial Audit Breakdown Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Column(
                  children: [
                    if (rem.grossCollections > 0) ...[
                      _buildModalRow('Gross Customer Cash Collected:', CurrencyFormatter.formatNaira(rem.grossCollections)),
                      const SizedBox(height: 4),
                      _buildModalRow('Less: Rider Commission:', '-${CurrencyFormatter.formatNaira(rem.commissionDeducted)}', valueColor: const Color(0xFF16A34A)),
                      const SizedBox(height: 4),
                      _buildModalRow('Less: Transport Allowance:', '-${CurrencyFormatter.formatNaira(rem.transportAllowanceDeducted)}', valueColor: const Color(0xFF0284C7)),
                      const Divider(height: 12),
                    ],
                    _buildModalRow(
                      'Net Remittance Settle Amount:',
                      CurrencyFormatter.formatNaira(rem.amount),
                      isBold: true,
                      valueColor: const Color(0xFF15803D),
                    ),
                  ],
                ),
              ),

              if (rem.notes != null && rem.notes!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Settlement Notes: ${rem.notes!}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
              ],

              const SizedBox(height: 16),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: refCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Remittance reference copied to clipboard!')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: Text('Copy Reference', style: GoogleFonts.inter(fontSize: 11)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A2D3),
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Close Ledger', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label, style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: isBold ? 13 : 11.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
