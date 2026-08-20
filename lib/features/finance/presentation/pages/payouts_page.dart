import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../domain/entities/financial_summary.dart';
import '../providers/finance_provider.dart';

class PayoutRequestItem {
  final String id;
  final double amount;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime date;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final String? disbursementRef;
  final String? dcNotes;

  PayoutRequestItem({
    required this.id,
    required this.amount,
    required this.status,
    required this.date,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    this.disbursementRef,
    this.dcNotes,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}

class PayoutsPage extends ConsumerStatefulWidget {
  const PayoutsPage({super.key});

  @override
  ConsumerState<PayoutsPage> createState() => _PayoutsPageState();
}

class _PayoutsPageState extends ConsumerState<PayoutsPage> {
  String _selectedFilter = 'all'; // 'all', 'pending', 'approved', 'rejected'

  final List<PayoutRequestItem> _payouts = [
    PayoutRequestItem(
      id: 'PAY-0082',
      amount: 15000.0,
      status: 'pending',
      date: DateTime.now().subtract(const Duration(hours: 1, minutes: 20)),
      bankName: 'Zenith Bank',
      accountNumber: '0123456789',
      accountName: 'Emeka Rider',
      dcNotes: 'Under review by Wuse DC Finance desk',
    ),
    PayoutRequestItem(
      id: 'PAY-0079',
      amount: 20000.0,
      status: 'approved',
      date: DateTime.now().subtract(const Duration(days: 6)),
      bankName: 'Zenith Bank',
      accountNumber: '0123456789',
      accountName: 'Emeka Rider',
      disbursementRef: 'DISB-88374291',
      dcNotes: 'Disbursed via Central Treasury',
    ),
    PayoutRequestItem(
      id: 'PAY-0071',
      amount: 25000.0,
      status: 'approved',
      date: DateTime.now().subtract(const Duration(days: 21)),
      bankName: 'Zenith Bank',
      accountNumber: '0123456789',
      accountName: 'Emeka Rider',
      disbursementRef: 'DISB-77291044',
      dcNotes: 'Disbursed via Wuse DC Finance',
    ),
  ];

  void _showRequestPayoutModal(BuildContext context, double availableBalance) {
    final amountController = TextEditingController(text: '10000');
    final accountController = TextEditingController(text: '0123456789');
    String selectedBank = 'Zenith Bank';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Request Balance Payout',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Withdraw earnings accumulated from Monnify direct transfers. Subject to DC approval.',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),

                  // Available Balance Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Available Balance:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB))),
                        Text(CurrencyFormatter.formatNaira(availableBalance), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF2563EB))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Amount Field
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Payout Amount (₦)',
                      prefixText: '₦ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Bank Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: selectedBank,
                    decoration: InputDecoration(
                      labelText: 'Select Bank',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: ['Zenith Bank', 'Access Bank', 'GTBank', 'Kuda Bank', 'Opay', 'Moniepoint', 'First Bank']
                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => selectedBank = v);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Account Number Field
                  TextField(
                    controller: accountController,
                    keyboardType: TextInputType.number,
                    maxLength: 10,
                    decoration: InputDecoration(
                      labelText: 'Account Number',
                      hintText: '10 digits NUBAN',
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      suffixIcon: const Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 18),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Beneficiary Name: Emeka Rider (Verified)',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF16A34A), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 20),

                  // Submit CTA
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final reqAmount = double.tryParse(amountController.text.trim()) ?? 0.0;
                        if (reqAmount <= 0 || (availableBalance > 0 && reqAmount > availableBalance)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid amount within your available balance.')),
                          );
                          return;
                        }

                        final auth = ref.read(authProvider);
                        final agentId = auth.user?.deliveryAgentId ?? auth.user?.id ?? SupabaseConstants.defaultDeliveryAgentId;
                        final riderName = auth.user != null ? '${auth.user!.firstName} ${auth.user!.lastName}'.trim() : 'Emeka Rider';

                        Navigator.pop(ctx);
                        setState(() {
                          _payouts.insert(
                            0,
                            PayoutRequestItem(
                              id: 'PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                              amount: reqAmount,
                              status: 'pending',
                              date: DateTime.now(),
                              bankName: selectedBank,
                              accountNumber: accountController.text.trim(),
                              accountName: riderName.isNotEmpty ? riderName : 'Emeka Rider',
                              dcNotes: 'New request submitted for DC review',
                            ),
                          );
                        });

                        // Call Edge Function
                        await ref.read(financeProvider.notifier).requestPayout(
                          agentId: agentId,
                          amount: reqAmount,
                          bankName: selectedBank,
                          accountNumber: accountController.text.trim(),
                          accountName: riderName.isNotEmpty ? riderName : 'Emeka Rider',
                          notes: 'Mobile PDA withdrawal request',
                        );

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF16A34A),
                              content: Text(
                                'Payout request for ${CurrencyFormatter.formatNaira(reqAmount)} submitted to DC for approval.',
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Submit Payout Request', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPayoutDetailsModal(BuildContext context, PayoutRequestItem item) {
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
                Text(item.id, style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: item.isApproved
                        ? const Color(0xFFDCFCE7)
                        : (item.isPending ? const Color(0xFFFFF7ED) : const Color(0xFFFFE4E6)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.status.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: item.isApproved
                          ? const Color(0xFF16A34A)
                          : (item.isPending ? const Color(0xFFEA580C) : const Color(0xFFE11D48)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Amount: ${CurrencyFormatter.formatNaira(item.amount)}', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text('Bank: ${item.bankName} • ${item.accountNumber}', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
            Text('Account Name: ${item.accountName}', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
            if (item.disbursementRef != null) ...[
              const SizedBox(height: 6),
              Text('Disbursement Ref: ${item.disbursementRef}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF2563EB), fontWeight: FontWeight.w600)),
            ],
            if (item.dcNotes != null) ...[
              const SizedBox(height: 6),
              Text('DC Notes: ${item.dcNotes}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
            ],
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
    final user = ref.watch(authProvider).user;

    final summary = FinancialSummary.calculate(
      orders: ordersState.orders,
      remittances: financeState.remittances,
      user: user,
      manualEarnedBalance: financeState.totalEarnedBalance,
    );

    final availableBalance = summary.myDirectTransfersBalance;

    final filteredList = _payouts.where((p) {
      if (_selectedFilter == 'all') return true;
      return p.status == _selectedFilter;
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
          'Payout Requests & Balance',
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HERO BALANCE CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'MY EARNINGS BALANCE',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: const Color(0xFF93C5FD),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Direct Transfers',
                          style: GoogleFonts.inter(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    CurrencyFormatter.formatNaira(availableBalance),
                    style: GoogleFonts.inter(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Accumulated from Monnify customer direct transfers & allowances.',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => _showRequestPayoutModal(context, availableBalance),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                      label: Text(
                        'Request New Payout',
                        style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. PAYOUT HISTORY SECTION
            Text(
              'PAYOUT REQUESTS HISTORY',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 10),

            // Filter Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterPill('All (${_payouts.length})', 'all', isDark),
                  const SizedBox(width: 8),
                  _buildFilterPill('Pending (${_payouts.where((p) => p.isPending).length})', 'pending', isDark),
                  const SizedBox(width: 8),
                  _buildFilterPill('Approved (${_payouts.where((p) => p.isApproved).length})', 'approved', isDark),
                  const SizedBox(width: 8),
                  _buildFilterPill('Rejected (0)', 'rejected', isDark),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Payout Items List
            if (filteredList.isNotEmpty) ...[
              ...filteredList.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildPayoutCard(context, p, isDark, theme),
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
                    'No payout requests in this category.',
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String label, String value, bool isDark) {
    final isSelected = _selectedFilter == value;

    return InkWell(
      onTap: () => setState(() => _selectedFilter = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildPayoutCard(BuildContext context, PayoutRequestItem item, bool isDark, ThemeData theme) {
    return InkWell(
      onTap: () => _showPayoutDetailsModal(context, item),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.id,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: item.isApproved
                        ? const Color(0xFFDCFCE7)
                        : (item.isPending ? const Color(0xFFFFF7ED) : const Color(0xFFFFE4E6)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.isApproved ? 'APPROVED & PAID' : (item.isPending ? 'PENDING DC' : 'REJECTED'),
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: item.isApproved
                          ? const Color(0xFF16A34A)
                          : (item.isPending ? const Color(0xFFEA580C) : const Color(0xFFE11D48)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  CurrencyFormatter.formatNaira(item.amount),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: item.isApproved ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${item.bankName} • ${item.accountNumber.length >= 4 ? item.accountNumber.substring(0, 4) : item.accountNumber}***',
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  '${item.date.day} Aug 2026 • ${item.date.hour}:${item.date.minute.toString().padLeft(2, '0')}',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Details',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF2563EB), fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF2563EB)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
