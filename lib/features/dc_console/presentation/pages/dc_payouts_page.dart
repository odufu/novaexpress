import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/widgets/app_skeleton_loader.dart';
import '../../domain/entities/dc_payout_claim.dart';
import '../providers/dc_console_provider.dart';

class DCPayoutsPage extends ConsumerStatefulWidget {
  const DCPayoutsPage({super.key});

  @override
  ConsumerState<DCPayoutsPage> createState() => _DCPayoutsPageState();
}

class _DCPayoutsPageState extends ConsumerState<DCPayoutsPage> {
  String _selectedFilter = 'all'; // 'all', 'pending', 'approved', 'rejected'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 700;

    final dcState = ref.watch(dcConsoleProvider);
    final allClaims = dcState.payoutClaims;

    // Filter claims
    final filteredClaims = allClaims.where((claim) {
      if (_selectedFilter == 'pending' && !claim.isPending) return false;
      if (_selectedFilter == 'approved' && !claim.isApproved) return false;
      if (_selectedFilter == 'rejected' && !claim.isRejected) return false;

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchNum = claim.claimNumber.toLowerCase().contains(q);
        final matchRider = claim.riderName.toLowerCase().contains(q);
        final matchCode = claim.riderCode.toLowerCase().contains(q);
        final matchBank = claim.bankName.toLowerCase().contains(q);
        final matchAcc = claim.accountNumber.contains(q);
        return matchNum || matchRider || matchCode || matchBank || matchAcc;
      }
      return true;
    }).toList();

    // Summary metrics computed dynamically
    final pendingClaims = allClaims.where((c) => c.isPending).toList();
    final approvedClaims = allClaims.where((c) => c.isApproved).toList();
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
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh Payout Claims',
                onPressed: () => ref.read(dcConsoleProvider.notifier).loadPayoutClaimsFromDatabase(),
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
                      icon: Icons.hourglass_top_rounded,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricTile(
                      'Approved Disbursements',
                      CurrencyFormatter.formatNaira(approvedTotal),
                      isDark,
                      color: const Color(0xFF10B981),
                      icon: Icons.check_circle_rounded,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricTile(
                      'Total Processed Claims',
                      '${allClaims.length} Claims',
                      isDark,
                      color: const Color(0xFF2563EB),
                      icon: Icons.receipt_long_rounded,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // Claims Queue Container
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
                // Filter & Search Controls
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Payout Claims Queue',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${filteredClaims.length} records',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF3B82F6)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Search Bar and Filter Tabs
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search rider name, PDA code, account or claim #...',
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
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

                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All (${allClaims.length})', 'all', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pending Review (${pendingClaims.length})', 'pending', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('Approved (${approvedClaims.length})', 'approved', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('Rejected (${allClaims.where((c) => c.isRejected).length})', 'rejected', isDark),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Claims List
                if (dcState.isLoading)
                  Column(
                    children: List.generate(3, (index) => const PayoutCardSkeleton()),
                  )
                else if (filteredClaims.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 48, color: const Color(0xFF94A3B8).withValues(alpha: 0.7)),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty || _selectedFilter != 'all'
                              ? 'No claims match your search criteria'
                              : 'No payout claims logged yet',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Riders\' balance withdrawal requests will automatically sync here in real time.',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredClaims.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    itemBuilder: (ctx, i) {
                      final claim = filteredClaims[i];

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
                                          color: (claim.isApproved
                                                  ? const Color(0xFF10B981)
                                                  : (claim.isRejected ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)))
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          claim.isApproved
                                              ? Icons.check_circle_rounded
                                              : (claim.isRejected ? Icons.cancel_rounded : Icons.payments_rounded),
                                          color: claim.isApproved
                                              ? const Color(0xFF10B981)
                                              : (claim.isRejected ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)),
                                          size: 18,
                                        ),
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
                                              'Bank: ${claim.bankName} • ${claim.accountNumber} (${claim.accountName})',
                                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                            ),
                                            if (claim.currentBalance > 0)
                                              Text(
                                                'Accrued Balance: ${CurrencyFormatter.formatNaira(claim.currentBalance)}',
                                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF059669), fontWeight: FontWeight.bold),
                                              ),
                                            if (claim.disbursementRef != null && claim.disbursementRef!.isNotEmpty)
                                              Text(
                                                'Ref: ${claim.disbursementRef}',
                                                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
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
                                      if (claim.isPending)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            OutlinedButton(
                                              onPressed: () => _showRejectModal(context, isDark, claim),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(0xFFEF4444),
                                                side: const BorderSide(color: Color(0xFFEF4444)),
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              child: const Text('Reject', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              onPressed: () => _showDisbursementModal(context, isDark, claim),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF10B981),
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              child: const Text('Approve Payout', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: claim.isApproved ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            claim.isApproved ? 'DISBURSED' : 'REJECTED',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: claim.isApproved ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                            ),
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
                                          color: (claim.isApproved
                                                  ? const Color(0xFF10B981)
                                                  : (claim.isRejected ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)))
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          claim.isApproved
                                              ? Icons.check_circle_rounded
                                              : (claim.isRejected ? Icons.cancel_rounded : Icons.payments_rounded),
                                          color: claim.isApproved
                                              ? const Color(0xFF10B981)
                                              : (claim.isRejected ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)),
                                          size: 20,
                                        ),
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
                                            if (claim.currentBalance > 0)
                                              Text(
                                                'Accrued Balance: ${CurrencyFormatter.formatNaira(claim.currentBalance)}',
                                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF059669), fontWeight: FontWeight.bold),
                                              ),
                                            if (claim.disbursementRef != null && claim.disbursementRef!.isNotEmpty)
                                              Text(
                                                'Ref: ${claim.disbursementRef}',
                                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
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
                                    if (claim.isPending)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          OutlinedButton(
                                            onPressed: () => _showRejectModal(context, isDark, claim),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFFEF4444),
                                              side: const BorderSide(color: Color(0xFFEF4444)),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            child: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: () => _showDisbursementModal(context, isDark, claim),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF10B981),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            child: const Text('Approve Payout', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: claim.isApproved ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          claim.isApproved ? 'DISBURSED' : 'REJECTED',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: claim.isApproved ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                          ),
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

  Widget _buildFilterChip(String label, String key, bool isDark) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3B82F6)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, bool isDark, {required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                const SizedBox(height: 4),
                Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDisbursementModal(BuildContext context, bool isDark, DCPayoutClaim claim) {
    final refController = TextEditingController(text: 'DISB-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF151D36) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Approve Payout Disbursement', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17)),
        content: SingleChildScrollView(
          child: Column(
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
              TextField(
                controller: refController,
                style: GoogleFonts.inter(fontSize: 12),
                decoration: InputDecoration(
                  labelText: 'Bank Disbursement Reference',
                  labelStyle: GoogleFonts.inter(fontSize: 11),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Confirming this will approve the withdrawal of ₦${claim.requestedAmount.toStringAsFixed(0)}, update the Supabase financial ledger, and alert the rider.',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final refCode = refController.text.trim();
              Navigator.pop(ctx);
              await ref.read(dcConsoleProvider.notifier).approvePayoutClaim(claim.id, disbursementRef: refCode);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Disbursement approved for ${claim.riderName}! Transfer initiated (Ref: $refCode).'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Approve & Transfer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRejectModal(BuildContext context, bool isDark, DCPayoutClaim claim) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF151D36) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reject Payout Claim', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17, color: const Color(0xFFEF4444))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rider: ${claim.riderName} (${claim.riderCode})', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
            Text('Amount: ${CurrencyFormatter.formatNaira(claim.requestedAmount)}', style: GoogleFonts.inter(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              style: GoogleFonts.inter(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Enter reason for rejection (e.g., Unsettled COD balance)...',
                hintStyle: GoogleFonts.inter(fontSize: 11),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              Navigator.pop(ctx);
              await ref.read(dcConsoleProvider.notifier).rejectPayoutClaim(claim.id, reason: reason.isNotEmpty ? reason : null);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Payout claim for ${claim.riderName} was returned/rejected.'),
                    backgroundColor: const Color(0xFFEF4444),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Reject Claim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
