import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/widgets/app_skeleton_loader.dart';

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
  String status; // 'pending_review', 'approved', 'rejected'

  DCPayoutClaim({
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
  bool _isLoading = false;
  late List<DCPayoutClaim> _claims;

  @override
  void initState() {
    super.initState();
    _claims = [
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
      DCPayoutClaim(
        id: 'pay-003',
        claimNumber: 'PAY-2026-0040',
        riderName: 'Sanni Abacha',
        riderCode: 'PDA-7588',
        requestedAmount: 18000.0,
        currentBalance: 24500.0,
        bankName: 'Zenith Bank',
        accountNumber: '2289104812',
        accountName: 'Sanni Abacha',
        requestedAt: DateTime.now().subtract(const Duration(hours: 8)),
        status: 'approved',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 700;

    final pendingClaims = _claims.where((c) => c.status == 'pending_review').toList();
    final approvedClaims = _claims.where((c) => c.status == 'approved').toList();

    final pendingTotal = pendingClaims.fold(0.0, (sum, c) => sum + c.requestedAmount);
    final approvedTotal = approvedClaims.fold(0.0, (sum, c) => sum + c.requestedAmount);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isCompact ? 14 : 20),
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
                      style: GoogleFonts.inter(fontSize: isCompact ? 18 : 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Review rider "My Balance" withdrawal requests, verify compensation ledgers, and approve bank disbursements',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Responsive KPI Summary Cards
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
                      'Pending Payout Claims',
                      '${pendingClaims.length} Claims (${CurrencyFormatter.formatNaira(pendingTotal)})',
                      isDark,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricTile(
                      'Approved Disbursements Today',
                      CurrencyFormatter.formatNaira(approvedTotal),
                      isDark,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricTile(
                      'Active Riders on Commission',
                      '4 Active PDAs',
                      isDark,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // Claims Queue
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
                Text(
                  'Payout Claims Queue',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),

                if (_isLoading)
                  Column(
                    children: List.generate(3, (index) => const PayoutCardSkeleton()),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _claims.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    itemBuilder: (ctx, i) {
                      final claim = _claims[i];
                      final isPending = claim.status == 'pending_review';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: LayoutBuilder(
                          builder: (context, rowConstraints) {
                            final isRowCompact = rowConstraints.maxWidth < 650;

                            if (isRowCompact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.payments_rounded, color: Color(0xFF10B981), size: 18),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${claim.claimNumber} • ${claim.riderName} (${claim.riderCode})',
                                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Bank: ${claim.bankName} • ${claim.accountNumber}',
                                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                            ),
                                            Text(
                                              'Accrued Balance: ${CurrencyFormatter.formatNaira(claim.currentBalance)}',
                                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF059669), fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        CurrencyFormatter.formatNaira(claim.requestedAmount),
                                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800),
                                      ),
                                      if (isPending)
                                        ElevatedButton(
                                          onPressed: () => _showDisbursementModal(context, isDark, claim),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF10B981),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: const Text('Approve Payout', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'DISBURSED',
                                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              );
                            }

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
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
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${claim.claimNumber} • ${claim.riderName} (${claim.riderCode})',
                                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              'Bank: ${claim.bankName} • ${claim.accountNumber} (${claim.accountName})',
                                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              'Accrued Balance: ${CurrencyFormatter.formatNaira(claim.currentBalance)}',
                                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF059669), fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      CurrencyFormatter.formatNaira(claim.requestedAmount),
                                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(width: 12),
                                    if (isPending)
                                      ElevatedButton(
                                        onPressed: () => _showDisbursementModal(context, isDark, claim),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: const Text('Approve Payout', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'DISBURSED',
                                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            );
                          },
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

  Widget _buildMetricTile(String label, String value, bool isDark, {required Color color}) {
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
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  void _showDisbursementModal(BuildContext context, bool isDark, DCPayoutClaim claim) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF151D36) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Approve Payout Disbursement', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rider: ${claim.riderName} (${claim.riderCode})', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            Text('Requested Amount: ${CurrencyFormatter.formatNaira(claim.requestedAmount)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF059669))),
            const SizedBox(height: 6),
            Text('Beneficiary Bank: ${claim.bankName}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
            Text('Account: ${claim.accountNumber} (${claim.accountName})', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
            const SizedBox(height: 14),
            Text('Confirming this will deduct ₦${claim.requestedAmount.toStringAsFixed(0)} from the rider\'s accrued balance and initiate enterprise bank disbursement.', style: GoogleFonts.inter(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                claim.status = 'approved';
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Disbursement approved for ${claim.riderName}! Transfer initiated.'),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Approve & Transfer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
