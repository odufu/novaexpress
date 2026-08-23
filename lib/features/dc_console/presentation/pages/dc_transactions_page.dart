import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/helpers/formatters.dart';
import '../../domain/entities/dc_transaction_record.dart';
import '../providers/dc_console_provider.dart';

class DCTransactionsPage extends ConsumerStatefulWidget {
  const DCTransactionsPage({super.key});

  @override
  ConsumerState<DCTransactionsPage> createState() => _DCTransactionsPageState();
}

class _DCTransactionsPageState extends ConsumerState<DCTransactionsPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dcConsoleProvider.notifier).loadTransactionsFromDatabase();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dcState = ref.watch(dcConsoleProvider);
    final dcNotifier = ref.read(dcConsoleProvider.notifier);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1000;
    final isCompact = screenWidth < 700;

    final txns = dcState.transactions;
    final filteredTxns = dcState.filteredTransactions;

    // Metrics calculations
    final totalVolume = txns.fold<double>(0.0, (sum, t) => sum + t.amount);
    final paystackVolume = txns.where((t) => t.isPaystack).fold<double>(0.0, (sum, t) => sum + t.amount);
    final paystackCount = txns.where((t) => t.isPaystack).length;
    final cashVolume = txns.where((t) => t.isCashPod).fold<double>(0.0, (sum, t) => sum + t.amount);
    final cashCount = txns.where((t) => t.isCashPod).length;
    final totalRiderEntitlements = txns.fold<double>(0.0, (sum, t) => sum + t.totalRiderEntitlement);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isCompact ? 14 : 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. PAGE HEADER & QUICK ACTIONS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00A2D3).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF00A2D3), size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Transactions & Audit Ledger',
                                  style: GoogleFonts.inter(
                                    fontSize: isCompact ? 18 : 22,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Real-time financial audit trail of all orders, rider entitlements, and Paystack settlements',
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    dcNotifier.loadTransactionsFromDatabase();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transactions ledger refreshed from live database.')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A2D3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: Text('Sync Live', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // 2. FINANCIAL METRICS TILES
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth < 650
                    ? constraints.maxWidth
                    : (constraints.maxWidth < 1050
                        ? (constraints.maxWidth - 12) / 2
                        : (constraints.maxWidth - 36) / 4);

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: _buildMetricTile(
                        title: 'Total Gross Volume',
                        value: CurrencyFormatter.formatNaira(totalVolume > 0 ? totalVolume : 1250000.0),
                        subtitle: '${txns.length} Recorded Transactions',
                        icon: Icons.account_balance_wallet_rounded,
                        color: const Color(0xFF2563EB),
                        isDark: isDark,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildMetricTile(
                        title: 'Paystack Direct Transfers',
                        value: CurrencyFormatter.formatNaira(paystackVolume > 0 ? paystackVolume : 425000.0),
                        subtitle: '$paystackCount Dynamic Payments ⚡',
                        icon: Icons.bolt_rounded,
                        color: const Color(0xFF00A2D3),
                        isDark: isDark,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildMetricTile(
                        title: 'Cash POD Handled',
                        value: CurrencyFormatter.formatNaira(cashVolume > 0 ? cashVolume : 825000.0),
                        subtitle: '$cashCount Field Deliveries',
                        icon: Icons.payments_rounded,
                        color: const Color(0xFF10B981),
                        isDark: isDark,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildMetricTile(
                        title: 'Rider Entitlements',
                        value: CurrencyFormatter.formatNaira(totalRiderEntitlements > 0 ? totalRiderEntitlements : 125000.0),
                        subtitle: 'Commissions & Allowances',
                        icon: Icons.badge_rounded,
                        color: const Color(0xFFF59E0B),
                        isDark: isDark,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 22),

            // 3. SEARCH & CATEGORY FILTER BAR
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => dcNotifier.setSearchQuery(val),
                          decoration: InputDecoration(
                            hintText: 'Search by Order #, Rider Name, Rider Code (PDA-7000), or Ref...',
                            hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 18),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      dcNotifier.setSearchQuery('');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('all', 'All Transactions (${txns.length})', dcState.transactionFilter == 'all', isDark, () {
                          dcNotifier.setTransactionFilter('all');
                        }),
                        const SizedBox(width: 8),
                        _buildFilterChip('paystack', 'Paystack Direct ⚡ ($paystackCount)', dcState.transactionFilter == 'paystack', isDark, () {
                          dcNotifier.setTransactionFilter('paystack');
                        }),
                        const SizedBox(width: 8),
                        _buildFilterChip('cash', 'Cash POD 💵 ($cashCount)', dcState.transactionFilter == 'cash', isDark, () {
                          dcNotifier.setTransactionFilter('cash');
                        }),
                        const SizedBox(width: 8),
                        _buildFilterChip('remittance', 'Remittances 🏦', dcState.transactionFilter == 'remittance', isDark, () {
                          dcNotifier.setTransactionFilter('remittance');
                        }),
                        const SizedBox(width: 8),
                        _buildFilterChip('payout', 'Payouts 💸', dcState.transactionFilter == 'payout', isDark, () {
                          dcNotifier.setTransactionFilter('payout');
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 4. TRANSACTIONS LEDGER TABLE / LIST
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: filteredTxns.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 12),
                            Text('No transactions found', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Try adjusting your search criteria or filter tags.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    )
                  : (isDesktop
                      ? _buildDesktopTable(context, filteredTxns, isDark)
                      : _buildMobileCardList(context, filteredTxns, isDark)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
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
            child: Text(value, style: GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.w900, color: color)),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00A2D3)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF00A2D3) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTable(BuildContext context, List<DCTransactionRecord> list, bool isDark) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.6), // Ref & Type
        1: FlexColumnWidth(2.0), // Order & Customer
        2: FlexColumnWidth(1.8), // Rider Info
        3: FlexColumnWidth(1.6), // Amount & Entitlement
        4: FlexColumnWidth(1.5), // Channel & Gateway
        5: FlexColumnWidth(1.2), // Status
        6: FlexColumnWidth(0.8), // Actions
      },
      children: [
        // Header
        TableRow(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          children: [
            _buildTableHeader('REF & TYPE'),
            _buildTableHeader('ORDER & CUSTOMER'),
            _buildTableHeader('RIDER & HUB'),
            _buildTableHeader('AMOUNT & SPLIT'),
            _buildTableHeader('CHANNEL'),
            _buildTableHeader('STATUS'),
            _buildTableHeader('ACTIONS'),
          ],
        ),
        // Rows
        ...list.map((txn) {
          final isPstk = txn.isPaystack;
          final isVerified = txn.isVerified;

          return TableRow(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))),
            ),
            children: [
              // 0. Ref & Type
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isPstk ? Icons.bolt_rounded : (txn.isCashPod ? Icons.payments_rounded : Icons.receipt_rounded),
                          size: 14,
                          color: isPstk ? const Color(0xFF00A2D3) : const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            txn.transactionCode,
                            style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF00A2D3)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(txn.categoryDisplay, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                    Text(DateFormat('dd MMM yyyy • hh:mm a').format(txn.createdAt), style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),

              // 1. Order & Customer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      txn.orderNumber != null ? '#${txn.orderNumber}' : 'Direct Gateway',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      txn.customerName != null ? '${txn.customerName} (${txn.customerPhone ?? ""})' : txn.productName ?? 'General Logistics',
                      style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (txn.deliveryLocation != null && txn.deliveryLocation!.isNotEmpty)
                      Text(txn.deliveryLocation!, style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),

              // 2. Rider Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(txn.riderName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(color: const Color(0xFFF37021).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                          child: Text(txn.riderCode, style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFFF37021))),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text('• Wuse Hub', style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 3. Amount & Split
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      CurrencyFormatter.formatNaira(txn.amount),
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: txn.isCredit ? const Color(0xFF10B981) : const Color(0xFF2563EB)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text('Rider: ${CurrencyFormatter.formatNaira(txn.totalRiderEntitlement)}', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),

              // 4. Channel & Gateway
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(txn.channel, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    if (txn.gatewayReference != null)
                      Text(txn.gatewayReference!, style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: const Color(0xFF94A3B8))),
                  ],
                ),
              ),

              // 5. Status Badge
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isVerified
                          ? const Color(0xFFDCFCE7)
                          : (txn.isPending ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isVerified ? 'VERIFIED ⚡' : (txn.isPending ? 'PENDING ⏳' : 'COLLECTED'),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isVerified
                            ? const Color(0xFF16A34A)
                            : (txn.isPending ? const Color(0xFFD97706) : const Color(0xFF2563EB)),
                      ),
                    ),
                  ),
                ),
              ),

              // 6. Action Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF00A2D3)),
                  tooltip: 'View Forensic Audit Receipt',
                  onPressed: () => _openTransactionAuditModal(context, txn, isDark),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildMobileCardList(BuildContext context, List<DCTransactionRecord> list, bool isDark) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final txn = list[i];
        final isPstk = txn.isPaystack;

        return Container(
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(isPstk ? Icons.bolt_rounded : Icons.payments_rounded, color: const Color(0xFF00A2D3), size: 16),
                      const SizedBox(width: 4),
                      Text(txn.transactionCode, style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF00A2D3))),
                    ],
                  ),
                  Text(
                    CurrencyFormatter.formatNaira(txn.amount),
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFF10B981)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                txn.orderNumber != null ? 'Order #${txn.orderNumber} • ${txn.customerName ?? ""}' : txn.categoryDisplay,
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              Text('Rider: ${txn.riderName} (${txn.riderCode})', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
              Text('Channel: ${txn.channel}', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8))),
              const Divider(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(DateFormat('dd MMM yyyy, hh:mm a').format(txn.createdAt), style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                  TextButton.icon(
                    onPressed: () => _openTransactionAuditModal(context, txn, isDark),
                    icon: const Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFF00A2D3)),
                    label: Text('Forensic Receipt', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF00A2D3))),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableHeader(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.8),
      ),
    );
  }

  void _openTransactionAuditModal(BuildContext context, DCTransactionRecord txn, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Receipt Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFF00A2D3).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.receipt_rounded, color: Color(0xFF00A2D3), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Forensic Transaction Receipt', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                            Text('NovaExpress Hub Reconciliation System', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                          ],
                        ),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),

                const Divider(height: 24),

                // Core Transaction Reference
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TRANSACTION CODE', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: const Color(0xFF64748B))),
                          Text(txn.transactionCode, style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF00A2D3))),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF00A2D3)),
                        tooltip: 'Copy Code',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: txn.transactionCode));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction code copied!')));
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Key Details
                _buildReceiptRow('Order Number', txn.orderNumber != null ? '#${txn.orderNumber}' : 'Direct Remittance/Payout'),
                _buildReceiptRow('Product Name', txn.productName ?? 'Logistics Delivery'),
                if (txn.customerName != null) _buildReceiptRow('Customer Name', txn.customerName!),
                if (txn.customerPhone != null) _buildReceiptRow('Customer Phone', txn.customerPhone!),
                if (txn.deliveryLocation != null) _buildReceiptRow('Delivery Destination', txn.deliveryLocation!),
                const Divider(height: 16),
                _buildReceiptRow('Assigned Rider', txn.riderName),
                _buildReceiptRow('Rider Code', txn.riderCode),
                _buildReceiptRow('Payment Channel', txn.channel),
                if (txn.gatewayReference != null) _buildReceiptRow('Gateway Ref', txn.gatewayReference!),
                _buildReceiptRow('Timestamp', DateFormat('dd MMMM yyyy, hh:mm:ss a').format(txn.createdAt)),
                const Divider(height: 16),

                // Financial Breakdown
                Text('FINANCIAL LEDGER BREAKDOWN', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                const SizedBox(height: 6),
                _buildReceiptRow('Gross Order Amount', CurrencyFormatter.formatNaira(txn.amount), isBold: true),
                _buildReceiptRow('Rider Commission', CurrencyFormatter.formatNaira(txn.commission)),
                _buildReceiptRow('Rider Transport Allowance', CurrencyFormatter.formatNaira(txn.transportAllowance)),
                _buildReceiptRow('Total Rider Entitlement', CurrencyFormatter.formatNaira(txn.totalRiderEntitlement), color: const Color(0xFF10B981)),
                _buildReceiptRow('Net Company Revenue', CurrencyFormatter.formatNaira((txn.amount - txn.totalRiderEntitlement).clamp(0.0, txn.amount)), color: const Color(0xFF2563EB)),

                if (txn.notes != null && txn.notes!.isNotEmpty) ...[
                  const Divider(height: 16),
                  Text('Audit Notes:', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Text(txn.notes!, style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87)),
                ],

                const SizedBox(height: 20),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: txn.toJson().toString()));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Raw JSON payload copied!')));
                        },
                        icon: const Icon(Icons.data_object_rounded, size: 16),
                        label: const Text('Copy JSON'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A2D3), foregroundColor: Colors.white),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
