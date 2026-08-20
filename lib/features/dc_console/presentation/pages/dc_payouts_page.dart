import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';

class DCPayoutClaim {
  final String id;
  final String claimNumber;
  final String riderName;
  final String riderCode;
  final double requestedAmount;
  final double currentBalance;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final DateTime requestedAt;
  final String status; // 'pending_review', 'approved', 'rejected'

  const DCPayoutClaim({
    required this.id,
    required this.claimNumber,
    required this.riderName,
    required this.riderCode,
    required this.requestedAmount,
    required this.currentBalance,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.requestedAt,
    this.status = 'pending_review',
  });
}

class DCPayoutsPage extends ConsumerStatefulWidget {
  const DCPayoutsPage({super.key});

  @override
  ConsumerState<DCPayoutsPage> createState() => _DCPayoutsPageState();
}

class _DCPayoutsPageState extends ConsumerState<DCPayoutsPage> {
  final List<DCPayoutClaim> _claims = [
    DCPayoutClaim(
      id: 'pay-001',
      claimNumber: 'PAY-2026-0042',
      riderName: 'Emeka Rider',
      riderCode: 'PDA-7000',
      requestedAmount: 45000.0,
      currentBalance: 58500.0,
      bankName: 'Kuda Microfinance Bank',
      accountNumber: '2019847291',
      accountName: 'Emeka Rider',
      requestedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    DCPayoutClaim(
      id: 'pay-002',
      claimNumber: 'PAY-2026-0041',
      riderName: 'Babatunde Lawal',
      riderCode: 'RDR-102',
      requestedAmount: 25000.0,
      currentBalance: 32000.0,
      bankName: 'GTBank',
      accountNumber: '0129482910',
      accountName: 'Babatunde Lawal',
      requestedAt: DateTime.now().subtract(const Duration(hours: 5)),
      status: 'approved',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final pendingClaims = _claims.where((c) => c.status == 'pending_review').toList();
    final approvedClaims = _claims.where((c) => c.status == 'approved').toList();

    final pendingTotal = pendingClaims.fold(0.0, (sum, c) => sum + c.requestedAmount);
    final approvedTotal = approvedClaims.fold(0.0, (sum, c) => sum + c.requestedAmount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rider Payout Claims & Earnings Approvals',
                      style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Review rider "My Balance" withdrawal requests, verify compensation ledgers, and approve bank disbursements',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // KPI Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Pending Payout Claims',
                  '${pendingClaims.length} Claims (${CurrencyFormatter.formatNaira(pendingTotal)})',
                  isDark,
                  color: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  'Approved Disbursements Today',
                  CurrencyFormatter.formatNaira(approvedTotal),
                  isDark,
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  'Active Riders on Commission',
                  '4 Active PDAs',
                  isDark,
                  color: const Color(0xFF2563EB),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Claims Queue
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
                Text(
                  'Payout Claims Queue',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _claims.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF334155)),
                  itemBuilder: (ctx, i) {
                    final claim = _claims[i];
                    final isPending = claim.status == 'pending_review';

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
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.payments_rounded, color: Color(0xFF10B981), size: 20),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${claim.claimNumber} • ${claim.riderName} (${claim.riderCode})',
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Bank: ${claim.bankName} • ${claim.accountNumber} (${claim.accountName})',
                                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                  ),
                                  Text(
                                    'Accrued Balance: ${CurrencyFormatter.formatNaira(claim.currentBalance)}',
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF059669), fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                CurrencyFormatter.formatNaira(claim.requestedAmount),
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(width: 14),
                              if (isPending)
                                ElevatedButton(
                                  onPressed: () => _showDisbursementModal(context, isDark, claim),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Approve Payout', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12)),
                                  child: Text('DISBURSED', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF059669))),
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
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String val, bool isDark, {required Color color}) {
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
          Text(val, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  void _showDisbursementModal(BuildContext context, bool isDark, DCPayoutClaim claim) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Confirm Payout Disbursement', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Disburse funds from NovaExpress corporate payout wallet to delivery agent:', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
            const SizedBox(height: 14),
            _buildModalRow('Delivery Agent:', '${claim.riderName} (${claim.riderCode})'),
            _buildModalRow('Payout Amount:', CurrencyFormatter.formatNaira(claim.requestedAmount), isBold: true),
            _buildModalRow('Destination Bank:', claim.bankName),
            _buildModalRow('Account Number:', claim.accountNumber),
            _buildModalRow('Beneficiary Name:', claim.accountName),
            _buildModalRow('Remaining Balance After:', CurrencyFormatter.formatNaira(claim.currentBalance - claim.requestedAmount)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                final idx = _claims.indexWhere((c) => c.id == claim.id);
                if (idx != -1) {
                  _claims[idx] = DCPayoutClaim(
                    id: claim.id,
                    claimNumber: claim.claimNumber,
                    riderName: claim.riderName,
                    riderCode: claim.riderCode,
                    requestedAmount: claim.requestedAmount,
                    currentBalance: claim.currentBalance - claim.requestedAmount,
                    bankName: claim.bankName,
                    accountNumber: claim.accountNumber,
                    accountName: claim.accountName,
                    requestedAt: claim.requestedAt,
                    status: 'approved',
                  );
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Payout of ${CurrencyFormatter.formatNaira(claim.requestedAmount)} approved and disbursed to ${claim.riderName}.'),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Confirm Disbursement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
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
