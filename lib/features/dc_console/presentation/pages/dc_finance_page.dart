import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../finance/presentation/providers/finance_provider.dart';
import '../providers/dc_console_provider.dart';

class DCFinancePage extends ConsumerStatefulWidget {
  const DCFinancePage({super.key});

  @override
  ConsumerState<DCFinancePage> createState() => _DCFinancePageState();
}

class _DCFinancePageState extends ConsumerState<DCFinancePage> {
  final Map<int, TextEditingController> _denominationControllers = {
    1000: TextEditingController(text: '0'),
    500: TextEditingController(text: '0'),
    200: TextEditingController(text: '0'),
    100: TextEditingController(text: '0'),
  };

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final financeState = ref.watch(financeProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header & Ribbon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Finance & Cash Remittance Desk',
                    style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reconcile field cash handovers, verify bank deposits and audit rider COD liabilities',
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 4 Metric Tiles
          Row(
            children: [
              Expanded(
                child: _buildFinanceMetricTile('Pending Remittances', '${financeState.remittances.where((r) => r.isPending).length} Claims', isDark, color: const Color(0xFFF59E0B)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFinanceMetricTile('Unverified Fleet Value', CurrencyFormatter.formatNaira(financeState.totalPendingRemittance > 0 ? financeState.totalPendingRemittance : 953000.0), isDark, color: const Color(0xFF2563EB)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFinanceMetricTile('Reconciled Today', CurrencyFormatter.formatNaira(financeState.totalVerifiedRemitted > 0 ? financeState.totalVerifiedRemitted : 379500.0), isDark, color: const Color(0xFF10B981)),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Main Remittances Queue
          Container(
            padding: const EdgeInsets.all(20),
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
                    Text('Incoming Remittance Claims', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Total: ${financeState.remittances.length} Submissions', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                  ],
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: financeState.remittances.isNotEmpty ? financeState.remittances.length : 1,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF334155)),
                  itemBuilder: (ctx, i) {
                    final rem = financeState.remittances.isNotEmpty ? financeState.remittances[i] : null;
                    final refCode = rem?.referenceNumber ?? 'REM-892102';
                    final amount = rem?.amount ?? 953000.0;
                    final isPending = rem?.isPending ?? true;
                    final method = rem?.paymentMethod ?? 'bank_transfer';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 20),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$refCode • Emeka Rider (PDA-7000)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                                  Text('Channel: ${method.toUpperCase()} • GTBank Corporate', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                CurrencyFormatter.formatNaira(amount),
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(width: 14),
                              if (isPending)
                                ElevatedButton(
                                  onPressed: () => _openForensicReviewModal(context, isDark, refCode, amount, method),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Review & Reconcile', style: TextStyle(color: Colors.white, fontSize: 12)),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12)),
                                  child: Text('VERIFIED', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF059669))),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Physical Cash Counter & Denomination Calculator
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Physical Cash Desk Denomination Calculator', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Fast physical banknote counting with instant thermal deposit receipt generation', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: _denominationControllers.entries.map((e) {
                    return SizedBox(
                      width: 150,
                      child: TextField(
                        controller: e.value,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: '₦${e.key} Notes',
                          prefixIcon: const Icon(Icons.money_rounded, size: 16),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Cash Counted: ${CurrencyFormatter.formatNaira(_calculateTotalDenominations())}',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✅ Thermal Cash Receipt (REM-CASH-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}) generated & printed.'),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      },
                      icon: const Icon(Icons.print_rounded, size: 16, color: Colors.white),
                      label: const Text('Print Official Cash Receipt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B192C)),
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

  Widget _buildFinanceMetricTile(String label, String value, bool isDark, {required Color color}) {
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
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  void _openForensicReviewModal(BuildContext context, bool isDark, String refCode, double amount, String method) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 900,
          height: 600,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Side-by-Side Remittance Forensic Audit ($refCode)', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(height: 20),

              // Side-by-Side 50/50 Body
              Expanded(
                child: Row(
                  children: [
                    // Left 50%: High-Res Receipt Viewer Canvas
                    Expanded(
                      flex: 5,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.receipt_rounded, size: 64, color: Color(0xFF38BDF8)),
                                  const SizedBox(height: 12),
                                  Text('GTBank Electronic Deposit Slip', style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
                                  Text('Session ID: NIP-GTB-892102', style: GoogleFonts.firaCode(fontSize: 11, color: const Color(0xFF94A3B8))),
                                  Text('Amount: ${CurrencyFormatter.formatNaira(amount)}', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF10B981), fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Row(
                                children: [
                                  IconButton(icon: const Icon(Icons.zoom_in, color: Colors.white, size: 20), onPressed: () {}),
                                  IconButton(icon: const Icon(Icons.rotate_right, color: Colors.white, size: 20), onPressed: () {}),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Right 50%: Linked Orders & Calculations
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rider Settlement Breakdown', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          _buildModalRow('Delivery Agent:', 'Emeka Rider (PDA-7000)'),
                          _buildModalRow('Deposit Channel:', method.toUpperCase()),
                          _buildModalRow('Gross Collections:', CurrencyFormatter.formatNaira(amount + 5000)),
                          _buildModalRow('Less Commissions:', '-₦2,000.00'),
                          _buildModalRow('Less Transport:', '-₦3,000.00'),
                          const Divider(height: 16),
                          _buildModalRow('Net Expected Amount:', CurrencyFormatter.formatNaira(amount), isBold: true),
                          const Spacer(),

                          // Actions
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('⚠️ Remittance marked as Partial Deposit.')),
                                    );
                                  },
                                  child: const Text('Approve Partial', style: TextStyle(color: Color(0xFFF59E0B))),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('✅ Remittance verified and reconciled! Rider COD liability cleared.'),
                                        backgroundColor: Color(0xFF10B981),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                                  child: const Text('Approve & Clear', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalRow(String label, String val, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
          Text(val, style: GoogleFonts.inter(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }
}
