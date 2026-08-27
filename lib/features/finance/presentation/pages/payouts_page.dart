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

final payoutsFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');
final payoutModalSelectedBankProvider = StateProvider.autoDispose<String>((ref) => 'Zenith Bank');

class PayoutsListNotifier extends StateNotifier<List<PayoutRequestItem>> {
  PayoutsListNotifier() : super([]);

  void setPayouts(List<PayoutRequestItem> list) {
    state = list;
  }

  void addPayout(PayoutRequestItem item) {
    state = [item, ...state];
  }
}

final payoutsListProvider =
    StateNotifierProvider.autoDispose<PayoutsListNotifier, List<PayoutRequestItem>>((ref) {
  return PayoutsListNotifier();
});

class PayoutsPage extends ConsumerStatefulWidget {
  const PayoutsPage({super.key});

  @override
  ConsumerState<PayoutsPage> createState() => _PayoutsPageState();
}

class _PayoutsPageState extends ConsumerState<PayoutsPage> {
  @override
  void initState() {
    super.initState();
    _fetchPayouts();
  }

  Future<void> _fetchPayouts() async {
    final user = ref.read(authProvider).user;
    final agentId = user?.deliveryAgentId ?? user?.id ?? '';
    if (agentId.isEmpty) return;

    final raw = await ref.read(financeProvider.notifier).loadPayoutRequests(agentId);
    if (mounted && raw.isNotEmpty) {
      final items = raw.map((map) {
        return PayoutRequestItem(
          id: map['id']?.toString() ?? 'PAY-0001',
          amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
          status: map['status']?.toString() ?? 'pending',
          date: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
          bankName: map['bank_name']?.toString() ?? 'Bank',
          accountNumber: map['account_number']?.toString() ?? '0000000000',
          accountName: map['account_name']?.toString() ?? 'Rider',
          disbursementRef: map['disbursement_reference']?.toString(),
          dcNotes: map['notes']?.toString(),
        );
      }).toList();
      ref.read(payoutsListProvider.notifier).setPayouts(items);
    }
  }

  void _showRequestPayoutModal(BuildContext context, double availableBalance) {
    final user = ref.read(authProvider).user;
    final defaultAccount = user?.bankAccountNumber.isNotEmpty == true ? user!.bankAccountNumber : '0123456789';
    final defaultBank = user?.bankName.isNotEmpty == true ? user!.bankName : 'Zenith Bank';
    final amountController = TextEditingController(text: availableBalance > 0 ? (availableBalance > 10000 ? '10000' : availableBalance.toInt().toString()) : '5000');
    final accountController = TextEditingController(text: defaultAccount);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer(
        builder: (ctx, modalRef, _) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final selectedBank = modalRef.watch(payoutModalSelectedBankProvider);

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
                    value: ['Zenith Bank', 'Access Bank', 'GTBank', 'Kuda Bank', 'Opay', 'Moniepoint', 'First Bank'].contains(selectedBank) ? selectedBank : defaultBank,
                    decoration: InputDecoration(
                      labelText: 'Select Bank',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: ['Zenith Bank', 'Access Bank', 'GTBank', 'Kuda Bank', 'Opay', 'Moniepoint', 'First Bank']
                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        modalRef.read(payoutModalSelectedBankProvider.notifier).state = v;
                      }
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
                    'Beneficiary Name: ${ref.read(authProvider).user?.bankAccountName ?? (ref.read(authProvider).user != null ? "${ref.read(authProvider).user!.firstName} ${ref.read(authProvider).user!.lastName}".trim() : "Field Agent")} (Verified)',
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
                        final riderName = auth.user != null ? '${auth.user!.firstName} ${auth.user!.lastName}'.trim() : 'Field Agent';

                        Navigator.pop(ctx);
                        ref.read(payoutsListProvider.notifier).addPayout(
                          PayoutRequestItem(
                            id: 'PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                            amount: reqAmount,
                            status: 'pending',
                            date: DateTime.now(),
                            bankName: selectedBank,
                            accountNumber: accountController.text.trim(),
                            accountName: riderName.isNotEmpty ? riderName : 'Field Agent',
                            dcNotes: 'New request submitted for DC review',
                          ),
                        );

                        // Call Edge Function
                        await ref.read(financeProvider.notifier).requestPayout(
                          agentId: agentId,
                          amount: reqAmount,
                          bankName: selectedBank,
                          accountNumber: accountController.text.trim(),
                          accountName: riderName.isNotEmpty ? riderName : 'Field Agent',
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
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
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
            _buildModalRow('Requested Amount', CurrencyFormatter.formatNaira(item.amount), isBold: true),
            _buildModalRow('Bank Name', item.bankName),
            _buildModalRow('Account Number', item.accountNumber),
            _buildModalRow('Account Name', item.accountName),
            _buildModalRow('Date', '${item.date.day}/${item.date.month}/${item.date.year} ${item.date.hour}:${item.date.minute.toString().padLeft(2, '0')}'),
            if (item.disbursementRef != null) _buildModalRow('Disbursement Ref', item.disbursementRef!),
            if (item.dcNotes != null) _buildModalRow('DC Notes', item.dcNotes!),
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
    final selectedFilter = ref.watch(payoutsFilterProvider);
    final payouts = ref.watch(payoutsListProvider);

    final summary = FinancialSummary.calculate(
      orders: ordersState.orders,
      remittances: financeState.remittances,
      user: user,
      manualEarnedBalance: financeState.totalEarnedBalance,
      transactions: financeState.transactions,
    );

    final availableBalance = summary.myDirectTransfersBalance;

    final filteredList = payouts.where((p) {
      if (selectedFilter == 'all') return true;
      return p.status == selectedFilter;
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TOP BALANCE CARD
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WITHDRAWABLE DIRECT TRANSFER BALANCE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    CurrencyFormatter.formatNaira(availableBalance),
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF60A5FA),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Net earnings from Paystack customer transfers held by company.',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () => _showRequestPayoutModal(context, availableBalance),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                      label: Text('Request Payout', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. FILTER PILLS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PAYOUT HISTORY & STATUS',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterPill('All (${payouts.length})', 'all', isDark, selectedFilter),
                        const SizedBox(width: 8),
                        _buildFilterPill('Pending (${payouts.where((p) => p.isPending).length})', 'pending', isDark, selectedFilter),
                        const SizedBox(width: 8),
                        _buildFilterPill('Approved (${payouts.where((p) => p.isApproved).length})', 'approved', isDark, selectedFilter),
                        const SizedBox(width: 8),
                        _buildFilterPill('Rejected (${payouts.where((p) => p.isRejected).length})', 'rejected', isDark, selectedFilter),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. PAYOUTS LIST
            if (filteredList.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: filteredList.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildPayoutCard(context, p, isDark, theme),
                  )).toList(),
                ),
              ),
            ] else ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(28),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Center(
                  child: Text(
                    'No payout requests in this filter.',
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

  Widget _buildFilterPill(String label, String value, bool isDark, String selectedFilter) {
    final isSelected = selectedFilter == value;

    return InkWell(
      onTap: () => ref.read(payoutsFilterProvider.notifier).state = value,
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

  Widget _buildPayoutCard(BuildContext context, PayoutRequestItem p, bool isDark, ThemeData theme) {
    return InkWell(
      onTap: () => _showPayoutDetailsModal(context, p),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(p.id, style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: p.isApproved
                        ? const Color(0xFFDCFCE7)
                        : (p.isPending ? const Color(0xFFFFF7ED) : const Color(0xFFFFE4E6)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    p.status.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: p.isApproved
                          ? const Color(0xFF16A34A)
                          : (p.isPending ? const Color(0xFFEA580C) : const Color(0xFFE11D48)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${p.bankName} • ${p.accountNumber}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                    const SizedBox(height: 2),
                    Text('${p.date.day}/${p.date.month}/${p.date.year}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                  ],
                ),
                Text(
                  CurrencyFormatter.formatNaira(p.amount),
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF2563EB)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B))),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
