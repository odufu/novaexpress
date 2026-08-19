import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../providers/finance_provider.dart';

class TransactionItem {
  final String id;
  final String title;
  final String category; // 'earnings', 'remittance', 'direct_transfer', 'payout'
  final double amount;
  final bool isCredit;
  final DateTime timestamp;
  final String reference;
  final String status; // 'settled', 'verified', 'pending', 'approved'
  final String description;

  TransactionItem({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.isCredit,
    required this.timestamp,
    required this.reference,
    required this.status,
    required this.description,
  });
}

class TransactionHistoryPage extends ConsumerStatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  ConsumerState<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends ConsumerState<TransactionHistoryPage> {
  String _selectedCategory = 'all'; // 'all', 'earnings', 'direct_transfer', 'remittance', 'payout'

  final List<TransactionItem> _defaultTransactions = [
    TransactionItem(
      id: 'TXN-9021',
      title: 'Direct Transfer Credit (TRK-8924)',
      category: 'direct_transfer',
      amount: 2500.0,
      isCredit: true,
      timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
      reference: 'MNFY-TRK-8924',
      status: 'settled',
      description: 'Commission (₦1,000) + Transport Allowance (₦1,500) credited to My Balance from Monnify customer transfer.',
    ),
    TransactionItem(
      id: 'TXN-9018',
      title: 'Cash POD Collection (TRK-8923)',
      category: 'earnings',
      amount: 27500.0,
      isCredit: false,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      reference: 'POD-8923-CASH',
      status: 'pending',
      description: 'Cash in physical custody. Added to To Remit ledger for end of day settlement.',
    ),
    TransactionItem(
      id: 'TXN-9005',
      title: 'Balance Payout Requested',
      category: 'payout',
      amount: 15000.0,
      isCredit: false,
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
      reference: 'PAY-0082',
      status: 'pending',
      description: 'Withdrawal from My Balance to Zenith Bank (0123456789). Awaiting DC Approval.',
    ),
    TransactionItem(
      id: 'TXN-8992',
      title: 'Remittance Verified & Reconciled',
      category: 'remittance',
      amount: 15000.0,
      isCredit: false,
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      reference: 'RMT-0004',
      status: 'verified',
      description: 'Bank transfer remittance reconciled by Wuse DC Finance desk.',
    ),
    TransactionItem(
      id: 'TXN-8980',
      title: 'Delivery Commission Payout Disbursed',
      category: 'payout',
      amount: 20000.0,
      isCredit: true,
      timestamp: DateTime.now().subtract(const Duration(days: 6)),
      reference: 'DISB-88374291',
      status: 'approved',
      description: 'Disbursement paid into registered Zenith Bank account.',
    ),
    TransactionItem(
      id: 'TXN-8975',
      title: 'Remittance Verified & Reconciled',
      category: 'remittance',
      amount: 10000.0,
      isCredit: false,
      timestamp: DateTime.now().subtract(const Duration(days: 8)),
      reference: 'RMT-0002',
      status: 'verified',
      description: 'Bank transfer remittance reconciled by Wuse DC Finance desk.',
    ),
  ];

  void _showTransactionDetailsModal(BuildContext context, TransactionItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item.id, style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: item.status == 'verified' || item.status == 'approved' || item.status == 'settled'
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.status.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: item.status == 'verified' || item.status == 'approved' || item.status == 'settled'
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFEA580C),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '${item.isCredit ? '+' : '-'}${CurrencyFormatter.formatNaira(item.amount)}',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: item.isCredit ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
              ),
            ),
            const SizedBox(height: 4),
            Text(item.title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Reference: ${item.reference}', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: const Color(0xFF64748B))),
            Text('Timestamp: ${item.timestamp.day} Aug 2026 • ${item.timestamp.hour}:${item.timestamp.minute.toString().padLeft(2, '0')}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Text(item.description, style: GoogleFonts.inter(fontSize: 12, height: 1.35, color: const Color(0xFF475569))),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final financeState = ref.watch(financeProvider);
    final ordersState = ref.watch(ordersProvider);

    final double toRemit = financeState.cashInCustody > 0
        ? financeState.cashInCustody
        : ordersState.orders.where((o) => o.status == 'delivered' && o.paymentType != 'prepaid').fold(0.0, (acc, o) => acc + o.totalAmount);
    final double remitted = financeState.remittances.where((r) => r.status.toLowerCase() == 'approved').fold(0.0, (acc, r) => acc + r.amount);
    final double pendingApproval = financeState.remittances.where((r) => r.status.toLowerCase() == 'pending' || r.status.toLowerCase() == 'submitted').fold(0.0, (acc, r) => acc + r.amount);
    final double cashCollected = toRemit + remitted + pendingApproval;
    final double riderBalance = financeState.totalEarnedBalance > 0 ? financeState.totalEarnedBalance : 18500.0;
    final double monthlyEarnings = riderBalance;

    final filteredList = _defaultTransactions.where((t) {
      if (_selectedCategory == 'all') return true;
      return t.category == _selectedCategory;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Financial Breakdown & History',
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TOP BRAND DARK BLUE SUMMARY HEADER
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FINANCIAL SUMMARY OVERVIEW',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 4-Column Summary Container matching reference
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSummaryMetricColumn(
                            icon: Icons.account_balance_rounded,
                            iconColor: const Color(0xFF60A5FA),
                            label: 'My Balance',
                            sublabel: '(Direct Transfers)',
                            amount: CurrencyFormatter.formatNaira(riderBalance),
                            amountColor: const Color(0xFF60A5FA),
                          ),
                        ),
                        _buildVerticalDivider(),
                        Expanded(
                          child: _buildSummaryMetricColumn(
                            icon: Icons.account_balance_wallet_rounded,
                            iconColor: const Color(0xFF4ADE80),
                            label: 'Earnings',
                            sublabel: '(This month)',
                            amount: CurrencyFormatter.formatNaira(monthlyEarnings),
                            amountColor: const Color(0xFF4ADE80),
                          ),
                        ),
                        _buildVerticalDivider(),
                        Expanded(
                          child: _buildSummaryMetricColumn(
                            icon: Icons.payments_rounded,
                            iconColor: const Color(0xFFCBD5E1),
                            label: 'Collected',
                            sublabel: '(Today)',
                            amount: CurrencyFormatter.formatNaira(cashCollected),
                            amountColor: Colors.white,
                          ),
                        ),
                        _buildVerticalDivider(),
                        Expanded(
                          child: _buildSummaryMetricColumn(
                            icon: Icons.north_east_rounded,
                            iconColor: const Color(0xFFFB923C),
                            label: 'To Remit',
                            sublabel: '(Cash Custody)',
                            amount: CurrencyFormatter.formatNaira(toRemit),
                            amountColor: const Color(0xFFFB923C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quick Action Links: [ Request Payout ] | [ Remit Cash ]
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => context.push('/finance/payouts'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.payments_outlined, size: 15),
                          label: Text('Request Payout', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => context.push('/cash/remit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEA580C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                          label: Text('Remit Cash', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. TRANSACTIONS LIST SECTION
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TRANSACTION AUDIT LOG',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Filter Pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterPill('All (${_defaultTransactions.length})', 'all', isDark),
                        const SizedBox(width: 8),
                        _buildFilterPill('Direct Transfers', 'direct_transfer', isDark),
                        const SizedBox(width: 8),
                        _buildFilterPill('Remittances', 'remittance', isDark),
                        const SizedBox(width: 8),
                        _buildFilterPill('Earnings', 'earnings', isDark),
                        const SizedBox(width: 8),
                        _buildFilterPill('Payouts', 'payout', isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Transaction Cards List
                  if (filteredList.isNotEmpty) ...[
                    ...filteredList.map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildTransactionCard(context, t, isDark, theme),
                        )),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Center(
                        child: Text(
                          'No transactions found in this category.',
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetricColumn({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String sublabel,
    required String amount,
    required Color amountColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(height: 3),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            amount,
            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800, color: amountColor),
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: const Color(0xFF334155),
    );
  }

  Widget _buildFilterPill(String label, String value, bool isDark) {
    final isSelected = _selectedCategory == value;

    return InkWell(
      onTap: () => setState(() => _selectedCategory = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, TransactionItem item, bool isDark, ThemeData theme) {
    return InkWell(
      onTap: () => _showTransactionDetailsModal(context, item),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            // Category Icon Badge
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: item.isCredit
                    ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                    : const Color(0xFFEA580C).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: item.isCredit ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.reference} • ${item.timestamp.day} Aug, ${item.timestamp.hour}:${item.timestamp.minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Amount + Status Pill
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.isCredit ? '+' : '-'}${CurrencyFormatter.formatNaira(item.amount)}',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: item.isCredit ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.status.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: item.status == 'verified' || item.status == 'approved' || item.status == 'settled'
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFEA580C),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
