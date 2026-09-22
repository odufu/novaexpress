import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/services/signature_storage_service.dart';
import '../../../../core/widgets/app_skeleton_loader.dart';
import '../../../client_portal/domain/entities/client_settlement.dart';
import '../../../client_portal/domain/entities/client_profile.dart';
import '../../../client_portal/presentation/widgets/client_settlement_detail_modal.dart';
import '../../../client_portal/presentation/widgets/pangea_excel_data_table.dart';
import '../../domain/entities/dc_payout_claim.dart';
import '../providers/dc_console_provider.dart';

final dcPayoutFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');
final dcPayoutSearchProvider = StateProvider.autoDispose<String>((ref) => '');

class DCPayoutsPage extends ConsumerStatefulWidget {
  const DCPayoutsPage({super.key});

  @override
  ConsumerState<DCPayoutsPage> createState() => _DCPayoutsPageState();
}

class _DCPayoutsPageState extends ConsumerState<DCPayoutsPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _settlementSearchController = TextEditingController();
  String _payoutCategory = 'riders'; // 'riders' | 'merchants'
  String _settlementFilter = 'all'; // 'all' | 'remitted' | 'completed'
  Future<List<ClientSettlement>>? _settlementsFuture;

  @override
  void initState() {
    super.initState();
    _settlementsFuture = ref.read(dcConsoleProvider.notifier).fetchDcClientSettlements();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _settlementSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 700;

    final selectedFilter = ref.watch(dcPayoutFilterProvider);
    final searchQuery = ref.watch(dcPayoutSearchProvider);
    final dcState = ref.watch(dcConsoleProvider);
    final allClaims = dcState.payoutClaims;

    // Filter claims
    final filteredClaims = allClaims.where((claim) {
      if (selectedFilter == 'pending' && !claim.isPending) return false;
      if (selectedFilter == 'approved' && !claim.isApproved) return false;
      if (selectedFilter == 'rejected' && !claim.isRejected) return false;

      if (searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
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
                      _payoutCategory == 'riders'
                          ? 'Rider Payout Claims & Earnings Approvals'
                          : 'Merchant COD Financial Settlements',
                      style: GoogleFonts.inter(fontSize: isCompact ? 18 : 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _payoutCategory == 'riders'
                          ? 'Review rider "My Balance" withdrawal requests, verify compensation ledgers, and approve bank disbursements'
                          : 'Inspect merchant daily clearinghouse settlements, verified transfer receipts, and merchant portal acknowledgments',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh Payout Claims & Settlements',
                onPressed: () {
                  ref.read(dcConsoleProvider.notifier).loadPayoutClaimsFromDatabase();
                  setState(() {
                    _settlementsFuture = ref.read(dcConsoleProvider.notifier).fetchDcClientSettlements();
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Payout Category Switcher (Riders vs Merchants)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _buildCategoryTab(
                  title: 'Rider Payout Claims',
                  count: allClaims.length,
                  isSelected: _payoutCategory == 'riders',
                  icon: Icons.two_wheeler_rounded,
                  onTap: () => setState(() => _payoutCategory = 'riders'),
                  isDark: isDark,
                ),
                _buildCategoryTab(
                  title: 'Merchant COD Settlements',
                  isSelected: _payoutCategory == 'merchants',
                  icon: Icons.storefront_rounded,
                  onTap: () => setState(() => _payoutCategory = 'merchants'),
                  isDark: isDark,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (_payoutCategory == 'merchants') ...[
            _buildMerchantSettlementsSection(context, isDark, isCompact),
          ] else ...[
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
                        onChanged: (val) => ref.read(dcPayoutSearchProvider.notifier).state = val,
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search rider name, PDA code, account or claim #...',
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(dcPayoutSearchProvider.notifier).state = '';
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
                          searchQuery.isNotEmpty || selectedFilter != 'all'
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
                else if (isCompact)
                  _buildClaimsMobileList(context, filteredClaims, isDark)
                else
                  _buildClaimsExcelTable(context, filteredClaims, isDark),
              ],
            ),
          ),
          ],
        ],
      ),
    );
  }

  Widget _buildClaimsMobileList(BuildContext context, List<DCPayoutClaim> filteredClaims, bool isDark) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredClaims.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      itemBuilder: (ctx, i) {
        final claim = filteredClaims[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildClaimStatusBadge(claim),
                        if (claim.hasReceipt) ...[
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _showReceiptPreviewDialog(context, claim.proofOfPaymentUrl!, claim.claimNumber),
                            icon: const Icon(Icons.receipt_long_rounded, size: 14),
                            label: const Text('Receipt', style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClaimsExcelTable(BuildContext context, List<DCPayoutClaim> claims, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: PangeaExcelDataTable<DCPayoutClaim>(
        items: claims,
        brandPrimary: const Color(0xFFF37021),
        rowHeight: 52,
        enablePagination: true,
        initialPageSize: 10,
        onRowTap: (claim) {
          if (claim.isPending) {
            _showDisbursementModal(context, isDark, claim);
          } else if (claim.hasReceipt) {
            _showReceiptPreviewDialog(context, claim.proofOfPaymentUrl!, claim.claimNumber);
          }
        },
        columns: [
          ExcelColumnDef<DCPayoutClaim>(
            key: 'claim',
            label: 'CLAIM & DATE',
            defaultWidth: 170,
            minWidth: 140,
            sortValue: (c) => c.requestedAt,
            searchString: (c) => '${c.claimNumber} ${c.disbursementRef ?? ''}',
            cellBuilder: (context, c, row, isDark, brand) {
              final dateStr = DateFormat('MMM dd, yyyy • HH:mm').format(c.requestedAt);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    c.claimNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    dateStr,
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (c.disbursementRef != null && c.disbursementRef!.isNotEmpty)
                    Text(
                      'Ref: ${c.disbursementRef}',
                      style: GoogleFonts.firaCode(fontSize: 9.5, color: const Color(0xFF2563EB)),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              );
            },
          ),
          ExcelColumnDef<DCPayoutClaim>(
            key: 'rider',
            label: 'RIDER & CODE',
            defaultWidth: 200,
            minWidth: 160,
            sortValue: (c) => c.riderName,
            searchString: (c) => '${c.riderName} ${c.riderCode}',
            cellBuilder: (context, c, row, isDark, brand) {
              return Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    child: Text(
                      c.riderName.isNotEmpty ? c.riderName[0].toUpperCase() : 'R',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          c.riderName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          c.riderCode,
                          style: GoogleFonts.firaCode(fontSize: 10.5, color: const Color(0xFF2563EB)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          ExcelColumnDef<DCPayoutClaim>(
            key: 'bank',
            label: 'BANK & ACCOUNT',
            defaultWidth: 220,
            minWidth: 170,
            sortValue: (c) => c.bankName,
            searchString: (c) => '${c.bankName} ${c.accountNumber} ${c.accountName}',
            cellBuilder: (context, c, row, isDark, brand) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    c.bankName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${c.accountNumber} (${c.accountName})',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            },
          ),
          ExcelColumnDef<DCPayoutClaim>(
            key: 'balance',
            label: 'ACCRUED BALANCE',
            defaultWidth: 150,
            minWidth: 120,
            sortValue: (c) => c.currentBalance,
            searchString: (c) => '${c.currentBalance}',
            cellBuilder: (context, c, row, isDark, brand) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  CurrencyFormatter.formatNaira(c.currentBalance),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF059669),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
          ExcelColumnDef<DCPayoutClaim>(
            key: 'requested',
            label: 'REQUESTED AMOUNT',
            defaultWidth: 160,
            minWidth: 130,
            sortValue: (c) => c.requestedAmount,
            searchString: (c) => '${c.requestedAmount}',
            cellBuilder: (context, c, row, isDark, brand) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  CurrencyFormatter.formatNaira(c.requestedAmount),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              );
            },
          ),
          ExcelColumnDef<DCPayoutClaim>(
            key: 'status',
            label: 'STATUS',
            defaultWidth: 170,
            minWidth: 130,
            sortValue: (c) => c.status,
            searchString: (c) => c.status,
            cellBuilder: (context, c, row, isDark, brand) {
              return Align(
                alignment: Alignment.centerLeft,
                child: _buildClaimStatusBadge(c),
              );
            },
          ),
          ExcelColumnDef<DCPayoutClaim>(
            key: 'actions',
            label: 'ACTIONS',
            defaultWidth: 180,
            minWidth: 140,
            cellBuilder: (context, c, row, isDark, brand) {
              if (c.isPending) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: () => _showRejectModal(context, isDark, c),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Reject', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: () => _showDisbursementModal(context, isDark, c),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Approve', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                );
              } else if (c.hasReceipt) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _showReceiptPreviewDialog(context, c.proofOfPaymentUrl!, c.claimNumber),
                    icon: const Icon(Icons.receipt_long_rounded, size: 14),
                    label: const Text('Receipt', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClaimStatusBadge(DCPayoutClaim claim) {
    String label;
    Color bgColor;
    Color textColor;

    if (claim.isConfirmed) {
      label = 'CONFIRMED & SETTLED';
      bgColor = const Color(0xFFECFDF5);
      textColor = const Color(0xFF059669);
    } else if (claim.isApproved || claim.isDisbursed) {
      label = 'DISBURSED (AWAITING CONFIRMATION)';
      bgColor = const Color(0xFFEFF6FF);
      textColor = const Color(0xFF2563EB);
    } else if (claim.isRejected) {
      label = 'REJECTED';
      bgColor = const Color(0xFFFEF2F2);
      textColor = const Color(0xFFDC2626);
    } else {
      label = 'PENDING REVIEW';
      bgColor = const Color(0xFFFFFBEB);
      textColor = const Color(0xFFD97706);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String key, bool isDark) {
    final selectedFilter = ref.watch(dcPayoutFilterProvider);
    final isSelected = selectedFilter == key;
    return InkWell(
      onTap: () => ref.read(dcPayoutFilterProvider.notifier).state = key,
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
    final refController = TextEditingController(text: 'TRF/RIDER/${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}');
    Uint8List? pickedReceiptBytes;
    String? pickedReceiptName;
    String? pickedReceiptExt;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF151D36) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.payments_rounded, color: Color(0xFF10B981), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Disburse Rider Payout', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Attach bank transfer receipt for rider verification', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rider Beneficiary Card with 1-Tap Copy
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${claim.riderName} (${claim.riderCode})',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                CurrencyFormatter.formatNaira(claim.requestedAmount),
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF059669)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${claim.bankName} • ${claim.accountNumber}',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                                  ),
                                  Text(
                                    'Account Name: ${claim.accountName}',
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: claim.accountNumber));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('📋 Account number ${claim.accountNumber} copied to clipboard!'),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: const Color(0xFF2563EB),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF2563EB)),
                                    const SizedBox(width: 4),
                                    Text('Copy', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Reference Input
                  Text('Bank Transfer Reference / Session ID', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: refController,
                    style: GoogleFonts.inter(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'e.g. TRF/ACCESS/20260921/987654',
                      isDense: true,
                      prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Receipt File Attachment Dropzone
                  Text('Attach Bank Transfer Receipt (PDF or Image) *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  if (pickedReceiptBytes == null)
                    InkWell(
                      onTap: () async {
                        try {
                          final result = await FilePickerPlatform.instance.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
                          );
                          if (result.isNotEmpty) {
                            final pickedFile = result.first;
                            final bytes = await pickedFile.readAsBytes();
                            if (bytes.isNotEmpty) {
                              setModalState(() {
                                pickedReceiptBytes = bytes;
                                pickedReceiptName = pickedFile.name;
                                pickedReceiptExt = pickedFile.extension?.toLowerCase() ?? 'pdf';
                              });
                            }
                          }
                        } catch (pickerErr) {
                          debugPrint('[DC_PAYOUT] File picker error: $pickerErr');
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_upload_rounded, color: Color(0xFF2563EB), size: 24),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Upload Bank Transfer Slip', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
                                Text('Supports PDF documents, PNG and JPG images', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            pickedReceiptExt == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                            color: const Color(0xFF10B981),
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pickedReceiptName ?? 'Transfer_Receipt',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${(pickedReceiptBytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB • Attached Ready',
                                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF059669)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFEF4444)),
                            onPressed: () {
                              setModalState(() {
                                pickedReceiptBytes = null;
                                pickedReceiptName = null;
                                pickedReceiptExt = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final refCode = refController.text.trim();
                      if (refCode.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a bank disbursement reference.')),
                        );
                        return;
                      }

                      setModalState(() => isSubmitting = true);
                      String? receiptUrl;

                      try {
                        if (pickedReceiptBytes != null) {
                          receiptUrl = await SignatureStorageService.uploadPayoutReceipt(
                            bytes: pickedReceiptBytes!,
                            payoutCode: claim.claimNumber,
                            extension: pickedReceiptExt ?? 'pdf',
                          );
                        }

                        await ref.read(dcConsoleProvider.notifier).approvePayoutClaim(
                          claim.id,
                          disbursementRef: refCode,
                          proofOfPaymentUrl: receiptUrl,
                        );

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ Disbursement approved for ${claim.riderName}! Transfer ref: $refCode recorded.'),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        }
                      } catch (err) {
                        setModalState(() => isSubmitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error approving disbursement: $err'), backgroundColor: const Color(0xFFEF4444)),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Approve & Disburse Payout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiptPreviewDialog(BuildContext context, String receiptUrl, String claimNumber) {
    final isPdf = receiptUrl.toLowerCase().contains('.pdf') || receiptUrl.startsWith('data:application/pdf');

    if (isPdf) {
      final uri = Uri.tryParse(receiptUrl);
      if (uri != null) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 550, maxHeight: 650),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bank Transfer Proof • $claimNumber', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: receiptUrl.startsWith('data:image')
                      ? Image.memory(
                          Uri.parse(receiptUrl).data!.contentAsBytes(),
                          fit: BoxFit.contain,
                        )
                      : Image.network(
                          receiptUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (_, child, progress) =>
                              progress == null ? child : const Center(child: CircularProgressIndicator()),
                          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey)),
                        ),
                ),
              ),
            ],
          ),
        ),
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

  Widget _buildCategoryTab({
    required String title,
    int? count,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E293B) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF0D9488) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : const Color(0xFF64748B),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: (isSelected ? const Color(0xFF0D9488) : const Color(0xFF64748B)).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? const Color(0xFF0D9488) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMerchantSettlementsSection(BuildContext context, bool isDark, bool isCompact) {
    final dcState = ref.watch(dcConsoleProvider);
    return FutureBuilder<List<ClientSettlement>>(
      future: _settlementsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const CircularProgressIndicator(color: Color(0xFF0D9488)),
                  const SizedBox(height: 12),
                  Text('Loading Merchant Settlements...', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                ],
              ),
            ),
          );
        }

        final settlements = snapshot.data ?? [];
        final totalDisbursed = settlements.fold(0.0, (sum, s) => sum + s.netPayoutAmount);
        final pendingApproval = settlements.where((s) => s.isRemitted).toList();
        final pendingApprovalAmount = pendingApproval.fold(0.0, (sum, s) => sum + s.netPayoutAmount);
        final completedSettlements = settlements.where((s) => s.isCompleted).toList();

        // Filtering
        final filteredSettlements = settlements.where((s) {
          if (_settlementFilter == 'remitted' && !s.isRemitted) return false;
          if (_settlementFilter == 'completed' && !s.isCompleted) return false;
          if (_settlementSearchController.text.trim().isNotEmpty) {
            final q = _settlementSearchController.text.trim().toLowerCase();
            final matchNum = s.settlementNumber.toLowerCase().contains(q);
            final client = dcState.clients.where((c) => c.id == s.clientId).firstOrNull;
            final matchName = (client?.companyName ?? '').toLowerCase().contains(q);
            final matchBank = s.destinationBankName.toLowerCase().contains(q);
            final matchAcc = s.destinationAccountNumber.contains(q);
            final matchRef = (s.payoutReference ?? '').toLowerCase().contains(q);
            return matchNum || matchName || matchBank || matchAcc || matchRef;
          }
          return true;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Summary Cards
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
                        'Total Net Disbursed',
                        CurrencyFormatter.formatNaira(totalDisbursed),
                        isDark,
                        color: const Color(0xFF0D9488),
                        icon: Icons.account_balance_wallet_rounded,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildMetricTile(
                        'Pending Merchant Sign-off',
                        '${pendingApproval.length} Batches (${CurrencyFormatter.formatNaira(pendingApprovalAmount)})',
                        isDark,
                        color: const Color(0xFFF59E0B),
                        icon: Icons.pending_actions_rounded,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildMetricTile(
                        'Approved & Finalized',
                        '${completedSettlements.length} Batches Reconciled',
                        isDark,
                        color: const Color(0xFF10B981),
                        icon: Icons.check_circle_rounded,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // Settlement Batches Container
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
                      Text(
                        'Merchant COD Settlements Queue',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${filteredSettlements.length} batches',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0D9488)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Search Bar
                  TextField(
                    controller: _settlementSearchController,
                    onChanged: (val) => setState(() {}),
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search batch #, merchant name, bank account or reference...',
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: _settlementSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _settlementSearchController.clear();
                                setState(() {});
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

                  const SizedBox(height: 12),

                  // Status Filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildSettlementFilterChip('All Batches (${settlements.length})', 'all', isDark),
                        const SizedBox(width: 8),
                        _buildSettlementFilterChip('Pending Sign-off (${pendingApproval.length})', 'remitted', isDark),
                        const SizedBox(width: 8),
                        _buildSettlementFilterChip('Approved & Completed (${completedSettlements.length})', 'completed', isDark),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (filteredSettlements.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 48, color: const Color(0xFF94A3B8).withValues(alpha: 0.7)),
                          const SizedBox(height: 12),
                          Text(
                            _settlementSearchController.text.isNotEmpty || _settlementFilter != 'all'
                                ? 'No settlements match your search criteria'
                                : 'No merchant settlements processed yet',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Daily settlement batches remitted to merchants will automatically appear here with verified transfer receipts.',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else if (isCompact)
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredSettlements.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      itemBuilder: (context, idx) {
                        final s = filteredSettlements[idx];
                        final client = dcState.clients.where((c) => c.id == s.clientId).firstOrNull;
                        return _buildSettlementCard(context, s, client, isDark);
                      },
                    )
                  else
                    _buildSettlementsExcelTable(context, filteredSettlements, dcState.clients, isDark),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettlementsExcelTable(
    BuildContext context,
    List<ClientSettlement> settlements,
    List<ClientProfile> clients,
    bool isDark,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: PangeaExcelDataTable<ClientSettlement>(
        items: settlements,
        brandPrimary: const Color(0xFF0D9488),
        rowHeight: 52,
        enablePagination: true,
        initialPageSize: 10,
        onRowTap: (s) {
          final client = clients.where((c) => c.id == s.clientId).firstOrNull;
          ClientSettlementDetailModal.show(
            context: context,
            settlement: s,
            isDcView: true,
            clientName: client?.companyName,
            clientLogo: client?.logoUrl,
          );
        },
        columns: [
          ExcelColumnDef<ClientSettlement>(
            key: 'settlement',
            label: 'SETTLEMENT REF',
            defaultWidth: 180,
            minWidth: 140,
            sortValue: (s) => s.settlementNumber,
            searchString: (s) => '${s.settlementNumber} ${s.payoutReference ?? ''}',
            cellBuilder: (context, s, row, isDark, brand) {
              final dateStr = DateFormat('MMM dd, yyyy • HH:mm').format(s.createdAt);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    s.settlementNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    dateStr,
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (s.payoutReference != null && s.payoutReference!.isNotEmpty)
                    Text(
                      'Ref: ${s.payoutReference}',
                      style: GoogleFonts.firaCode(fontSize: 9.5, color: const Color(0xFF0D9488)),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              );
            },
          ),
          ExcelColumnDef<ClientSettlement>(
            key: 'merchant',
            label: 'MERCHANT CLIENT',
            defaultWidth: 230,
            minWidth: 180,
            sortValue: (s) {
              final client = clients.where((c) => c.id == s.clientId).firstOrNull;
              return client?.companyName ?? '';
            },
            searchString: (s) {
              final client = clients.where((c) => c.id == s.clientId).firstOrNull;
              return '${client?.companyName ?? ''} ${client?.code ?? ''}';
            },
            cellBuilder: (context, s, row, isDark, brand) {
              final client = clients.where((c) => c.id == s.clientId).firstOrNull;
              final name = client?.companyName ?? 'Merchant';
              return Row(
                children: [
                  _buildMerchantLogoAvatar(client?.logoUrl, name),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (client != null && client.code.isNotEmpty)
                          Text(
                            client.code,
                            style: GoogleFonts.firaCode(fontSize: 10, color: const Color(0xFF0D9488)),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          ExcelColumnDef<ClientSettlement>(
            key: 'period',
            label: 'PERIOD & ORDERS',
            defaultWidth: 170,
            minWidth: 130,
            sortValue: (s) => s.totalOrdersCount,
            searchString: (s) => '${s.totalOrdersCount} orders',
            cellBuilder: (context, s, row, isDark, brand) {
              final startStr = DateFormat('dd MMM').format(s.periodStart);
              final endStr = DateFormat('dd MMM yyyy').format(s.periodEnd);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${s.totalOrdersCount} Orders Settled',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  Text(
                    '$startStr - $endStr',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                  ),
                ],
              );
            },
          ),
          ExcelColumnDef<ClientSettlement>(
            key: 'gross',
            label: 'GROSS COD',
            defaultWidth: 140,
            minWidth: 110,
            sortValue: (s) => s.grossCollections,
            searchString: (s) => '${s.grossCollections}',
            cellBuilder: (context, s, row, isDark, brand) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  CurrencyFormatter.formatNaira(s.grossCollections),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              );
            },
          ),
          ExcelColumnDef<ClientSettlement>(
            key: 'fees',
            label: 'FEES & DEDUCTIONS',
            defaultWidth: 160,
            minWidth: 120,
            sortValue: (s) => s.logisticsFeesDeducted,
            searchString: (s) => '${s.logisticsFeesDeducted}',
            cellBuilder: (context, s, row, isDark, brand) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '- ${CurrencyFormatter.formatNaira(s.logisticsFeesDeducted)}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.w500),
                ),
              );
            },
          ),
          ExcelColumnDef<ClientSettlement>(
            key: 'net',
            label: 'NET PAYOUT',
            defaultWidth: 150,
            minWidth: 120,
            sortValue: (s) => s.netPayoutAmount,
            searchString: (s) => '${s.netPayoutAmount}',
            cellBuilder: (context, s, row, isDark, brand) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  CurrencyFormatter.formatNaira(s.netPayoutAmount),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                ),
              );
            },
          ),
          ExcelColumnDef<ClientSettlement>(
            key: 'status',
            label: 'STATUS',
            defaultWidth: 140,
            minWidth: 110,
            sortValue: (s) => s.status,
            searchString: (s) => s.isCompleted ? 'COMPLETED' : 'REMITTED',
            cellBuilder: (context, s, row, isDark, brand) {
              final isCompleted = s.isCompleted;
              return Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isCompleted ? 'COMPLETED' : 'REMITTED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFD97706),
                    ),
                  ),
                ),
              );
            },
          ),
          ExcelColumnDef<ClientSettlement>(
            key: 'actions',
            label: 'ACTIONS',
            defaultWidth: 100,
            minWidth: 80,
            cellBuilder: (context, s, row, isDark, brand) {
              final client = clients.where((c) => c.id == s.clientId).firstOrNull;
              return Center(
                child: IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF0D9488)),
                  tooltip: 'View Settlement',
                  onPressed: () {
                    ClientSettlementDetailModal.show(
                      context: context,
                      settlement: s,
                      isDcView: true,
                      clientName: client?.companyName,
                      clientLogo: client?.logoUrl,
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementFilterChip(String label, String value, bool isDark) {
    final isSelected = _settlementFilter == value;
    return InkWell(
      onTap: () => setState(() => _settlementFilter = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0D9488)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0D9488)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildMerchantLogoAvatar(String? logoUrl, String companyName) {
    const double size = 42;
    if (logoUrl != null && logoUrl.trim().isNotEmpty) {
      final trimmed = logoUrl.trim();
      if (trimmed.startsWith('data:image')) {
        try {
          final commaIdx = trimmed.indexOf(',');
          final base64Str = commaIdx != -1 ? trimmed.substring(commaIdx + 1) : trimmed;
          final bytes = base64Decode(base64Str);
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(bytes, width: size, height: size, fit: BoxFit.cover),
          );
        } catch (_) {}
      } else if (trimmed.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            trimmed,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackStoreAvatar(companyName, size),
          ),
        );
      }
    }
    return _buildFallbackStoreAvatar(companyName, size);
  }

  Widget _buildFallbackStoreAvatar(String companyName, double size) {
    final initial = companyName.isNotEmpty ? companyName[0].toUpperCase() : 'M';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF0D9488).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF0D9488)),
      ),
    );
  }

  Widget _buildSettlementCard(BuildContext context, ClientSettlement s, ClientProfile? client, bool isDark) {
    final currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 2);
    final isRemitted = s.isRemitted;
    final isCompleted = s.isCompleted;

    return InkWell(
      onTap: () => ClientSettlementDetailModal.show(
        context: context,
        settlement: s,
        isDcView: true,
        clientName: client?.companyName,
        clientLogo: client?.logoUrl,
      ),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            _buildMerchantLogoAvatar(client?.logoUrl, client?.companyName ?? s.destinationAccountName),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          client?.companyName ?? (s.destinationAccountName.isNotEmpty ? s.destinationAccountName : "Enterprise Merchant"),
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isCompleted
                                  ? const Color(0xFF10B981)
                                  : (isRemitted ? const Color(0xFFF59E0B) : const Color(0xFF0284C7)))
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isCompleted
                              ? 'Approved & Finalized'
                              : (isRemitted ? 'Pending Sign-off' : s.status.toUpperCase()),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isCompleted
                                ? const Color(0xFF10B981)
                                : (isRemitted ? const Color(0xFFD97706) : const Color(0xFF0284C7)),
                          ),
                        ),
                      ),
                      if (s.hasReceipt) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.attachment_rounded, size: 10, color: Color(0xFF0D9488)),
                              SizedBox(width: 3),
                              Text('Receipt', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF0D9488))),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${s.settlementNumber} • Disbursed ${DateFormat('dd MMM yyyy, hh:mm a').format(s.settledAt)} • ${s.destinationBankName}',
                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currency.format(s.netPayoutAmount),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: const Color(0xFF0D9488)),
                ),
                Text(
                  '${s.totalOrdersCount} orders • Tap for receipt →',
                  style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF0284C7)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
