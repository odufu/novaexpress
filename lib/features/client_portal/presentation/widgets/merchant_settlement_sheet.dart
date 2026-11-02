import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../dc_console/domain/entities/distribution_center.dart';
import '../../../orders/data/models/order_model.dart';
import '../../../orders/domain/entities/order.dart';
import '../../domain/entities/client_settlement.dart';
import '../providers/merchant_settlements_provider.dart';

/// Modal Sheet & Dialog displaying complete settlement details for Merchant Accountants
/// Supports both live ongoing accumulating settlements and finalized/cleared settlements.
class MerchantSettlementSheet extends ConsumerStatefulWidget {
  final LiveOngoingSettlement? ongoingSettlement;
  final ClientSettlement? settlement;
  final DistributionCenter? dc;

  const MerchantSettlementSheet({
    super.key,
    this.ongoingSettlement,
    this.settlement,
    this.dc,
  });

  static Future<void> show({
    required BuildContext context,
    LiveOngoingSettlement? ongoingSettlement,
    ClientSettlement? settlement,
    DistributionCenter? dc,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    if (isMobile) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => MerchantSettlementSheet(
          ongoingSettlement: ongoingSettlement,
          settlement: settlement,
          dc: dc,
        ),
      );
    } else {
      return showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 850),
            child: MerchantSettlementSheet(
              ongoingSettlement: ongoingSettlement,
              settlement: settlement,
              dc: dc,
            ),
          ),
        ),
      );
    }
  }

  @override
  ConsumerState<MerchantSettlementSheet> createState() => _MerchantSettlementSheetState();
}

class _MerchantSettlementSheetState extends ConsumerState<MerchantSettlementSheet> {
  final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 2);
  final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
  final shortDateFormat = DateFormat('MMM dd, yyyy');

  bool _isSubmitting = false;
  String _activeTab = 'breakdown'; // 'breakdown', 'manifest', 'receipt'

  void _showFullscreenReceiptDialog(BuildContext context, String receiptUrl) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 850),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF10B981), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Payment Receipt',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 5.0,
                      child: Center(
                        child: Image.network(
                          receiptUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                                const SizedBox(height: 12),
                                Text('Receipt Unreachable', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleValidateSettlement(ClientSettlement s) async {
    final remarksCtrl = TextEditingController(text: 'Validated by Merchant Accounting');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 10),
            Text('Validate Settlement', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirm receipt of payout transfer of ${currencyFormat.format(s.netPayoutAmount)} to your account.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: remarksCtrl,
              decoration: InputDecoration(
                labelText: 'Approval Notes',
                hintText: 'Optional remarks or ledger note',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign Off', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);
    final success = await ref
        .read(merchantSettlementsProvider.notifier)
        .validateAndClearSettlement(s.id, remarks: remarksCtrl.text.trim());
    setState(() => _isSubmitting = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Settlement Cleared', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            content: Text('Validation failed. Please retry.', style: GoogleFonts.inter()),
          ),
        );
      }
    }
  }

  Future<void> _handleDisputeSettlement(ClientSettlement s) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.flag_rounded, color: Color(0xFFEF4444), size: 20),
            ),
            const SizedBox(width: 10),
            Text('Dispute Batch', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the discrepancy reason. The DC Accountant will be notified to review and re-issue the remittance.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. Bank transfer not received, deductions mismatch...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: Text('Submit Flag', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);
    final success = await ref
        .read(merchantSettlementsProvider.notifier)
        .disputeSettlement(s.id, reason: reasonCtrl.text.trim());
    setState(() => _isSubmitting = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            content: Text('Settlement flagged for review', style: GoogleFonts.inter()),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOngoing = widget.ongoingSettlement != null;
    final ongoing = widget.ongoingSettlement;
    final settlement = widget.settlement;

    final dcName = ongoing?.dcName ??
        widget.dc?.name ??
        (settlement?.distributionCenterId != null && settlement!.distributionCenterId!.contains('cmd')
            ? 'Central Command DC'
            : 'Fulfillment DC');
    final dcCode = ongoing?.dcCode ?? widget.dc?.code ?? 'DC-CMD-01';
    final dcState = ongoing?.dcState ?? widget.dc?.state ?? 'Abuja (FCT)';

    final double gross = ongoing?.grossRemitted ?? settlement?.grossCollections ?? 0.0;
    final double logistics = ongoing?.logisticsFees ?? settlement?.logisticsFeesDeducted ?? 0.0;
    final double posFees = ongoing?.posGatewayFees ?? settlement?.gatewayFeesDeducted ?? 0.0;
    final int failedAttemptsCount = ongoing?.failedAttemptCount ??
        (settlement?.chargesBreakdown['failed_attempts_count'] is int
            ? settlement!.chargesBreakdown['failed_attempts_count'] as int
            : 0);
    final double failedAttemptsVal = ongoing?.failedAttemptValue ?? settlement?.failedAttemptFeesDeducted ?? 0.0;
    final double otherFees = ongoing?.otherFees ?? settlement?.otherChargesDeducted ?? 0.0;
    final String otherComment = ongoing?.otherFeesComment.isNotEmpty == true
        ? ongoing!.otherFeesComment
        : (settlement?.chargesBreakdown['other_charges_comment'] as String? ?? '');

    final double netPayout = ongoing?.expectedNetPayout ?? settlement?.netPayoutAmount ?? 0.0;
    final int totalPackages = ongoing?.deliveredCount ?? settlement?.totalOrdersCount ?? 0;

    final isCleared = settlement?.isCompleted == true;
    final isAwaiting = settlement != null && !isCleared && !settlement.isRejected;
    final isDisputed = settlement?.isRejected == true;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle for mobile
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // DC Avatar / Icon
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: isOngoing
                        ? const Color(0xFFF37021).withValues(alpha: 0.12)
                        : (isCleared
                            ? const Color(0xFF10B981).withValues(alpha: 0.12)
                            : const Color(0xFF3B82F6).withValues(alpha: 0.12)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isOngoing
                        ? Icons.bolt_rounded
                        : (isCleared ? Icons.verified_user_rounded : Icons.account_balance_rounded),
                    color: isOngoing
                        ? const Color(0xFFF37021)
                        : (isCleared ? const Color(0xFF10B981) : const Color(0xFF3B82F6)),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dcName,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              dcCode,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              dcState,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Status Pill
                _buildStatusPill(
                  isOngoing: isOngoing,
                  isCleared: isCleared,
                  isAwaiting: isAwaiting,
                  isDisputed: isDisputed,
                ),
                const SizedBox(width: 2),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Net Payout Highlight Card
                  _buildNetPayoutCard(
                    isDark: isDark,
                    isOngoing: isOngoing,
                    isCleared: isCleared,
                    netPayout: netPayout,
                    settlement: settlement,
                  ),

                  const SizedBox(height: 16),

                  // Tab Switcher (1 word each)
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        _buildTabButton(
                          id: 'breakdown',
                          label: 'Breakdown',
                          icon: Icons.pie_chart_rounded,
                          tooltip: 'Itemized fee calculations',
                          isDark: isDark,
                        ),
                        _buildTabButton(
                          id: 'manifest',
                          label: 'Manifest',
                          icon: Icons.inventory_2_rounded,
                          tooltip: 'Fulfilled orders & products',
                          isDark: isDark,
                        ),
                        if (settlement?.proofOfPaymentUrl != null && settlement!.proofOfPaymentUrl!.isNotEmpty)
                          _buildTabButton(
                            id: 'receipt',
                            label: 'Receipt',
                            icon: Icons.receipt_rounded,
                            tooltip: 'Bank transfer proof',
                            isDark: isDark,
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tab Views
                  if (_activeTab == 'breakdown') ...[
                    _buildBreakdownTab(
                      isDark: isDark,
                      gross: gross,
                      logistics: logistics,
                      posFees: posFees,
                      failedAttemptsCount: failedAttemptsCount,
                      failedAttemptsVal: failedAttemptsVal,
                      otherFees: otherFees,
                      otherComment: otherComment,
                      netPayout: netPayout,
                      totalPackages: totalPackages,
                      isOngoing: isOngoing,
                    ),
                  ] else if (_activeTab == 'manifest') ...[
                    _buildManifestTab(
                      isDark: isDark,
                      ongoing: ongoing,
                      settlement: settlement,
                    ),
                  ] else if (_activeTab == 'receipt') ...[
                    _buildReceiptTab(
                      isDark: isDark,
                      settlement: settlement,
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Destination Bank Info Card
                  _buildBankInfoCard(
                    isDark: isDark,
                    settlement: settlement,
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          if (isAwaiting)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSubmitting ? null : () => _handleDisputeSettlement(settlement),
                      icon: const Icon(Icons.flag_rounded, size: 18),
                      label: Text('Dispute', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: _isSubmitting ? null : () => _handleValidateSettlement(settlement),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text('Validate', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            )
          else if (isCleared)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Settlement Cleared',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusPill({
    required bool isOngoing,
    required bool isCleared,
    required bool isAwaiting,
    required bool isDisputed,
  }) {
    Color bg;
    Color fg;
    String label;
    IconData icon;
    String tooltip;

    if (isOngoing) {
      bg = const Color(0xFFF37021).withValues(alpha: 0.12);
      fg = const Color(0xFFF37021);
      label = 'Ongoing';
      icon = Icons.bolt_rounded;
      tooltip = 'Accumulating live from rider remittances today';
    } else if (isCleared) {
      bg = const Color(0xFF10B981).withValues(alpha: 0.12);
      fg = const Color(0xFF10B981);
      label = 'Cleared';
      icon = Icons.verified_rounded;
      tooltip = 'Validated and cleared by Merchant Accounting';
    } else if (isDisputed) {
      bg = const Color(0xFFEF4444).withValues(alpha: 0.12);
      fg = const Color(0xFFEF4444);
      label = 'Disputed';
      icon = Icons.flag_rounded;
      tooltip = 'Flagged for review with DC operations';
    } else {
      bg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
      fg = const Color(0xFFF59E0B);
      label = 'Validation';
      icon = Icons.hourglass_top_rounded;
      tooltip = 'Submitted by DC Accountant. Pending your sign-off';
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: fg.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                color: fg,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetPayoutCard({
    required bool isDark,
    required bool isOngoing,
    required bool isCleared,
    required double netPayout,
    required ClientSettlement? settlement,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCleared
              ? [const Color(0xFF065F46), const Color(0xFF047857)]
              : (isOngoing
                  ? [const Color(0xFF9A3412), const Color(0xFFC2410C)]
                  : [const Color(0xFF1E3A8A), const Color(0xFF1D4ED8)]),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isCleared
                    ? const Color(0xFF047857)
                    : (isOngoing ? const Color(0xFFC2410C) : const Color(0xFF1D4ED8)))
                .withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background seal watermark if cleared
          if (isCleared)
            Positioned(
              right: -10,
              bottom: -15,
              child: Opacity(
                opacity: 0.15,
                child: const Icon(Icons.verified_user_rounded, size: 120, color: Colors.white),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isOngoing ? 'Expected Payout' : 'Net Settlement',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (isCleared)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white38),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield_rounded, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'CLEARED SEAL',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  currencyFormat.format(netPayout),
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: Colors.white60, size: 14),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      isOngoing
                          ? 'Updated ${dateFormat.format(DateTime.now())}'
                          : (settlement != null ? 'Settled ${shortDateFormat.format(settlement.settledAt)}' : ''),
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String id,
    required String label,
    required IconData icon,
    required String tooltip,
    required bool isDark,
  }) {
    final isSelected = _activeTab == id;
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: () => setState(() => _activeTab = id),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? const Color(0xFFF37021)
                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.white : const Color(0xFF1E293B))
                        : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownTab({
    required bool isDark,
    required double gross,
    required double logistics,
    required double posFees,
    required int failedAttemptsCount,
    required double failedAttemptsVal,
    required double otherFees,
    required String otherComment,
    required double netPayout,
    required int totalPackages,
    required bool isOngoing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildItemizedRow(
            label: 'Rider Collections',
            sub: '$totalPackages delivered packages',
            amount: gross,
            isCredit: true,
            icon: Icons.payments_rounded,
            tooltip: 'Gross cash and transfers collected on fulfillment',
            isDark: isDark,
          ),
          const Divider(height: 20),
          _buildItemizedRow(
            label: 'Delivery Tariff',
            sub: 'Flat rate per drop',
            amount: -logistics,
            isCredit: false,
            icon: Icons.local_shipping_rounded,
            tooltip: 'NovaXpress flat logistics fulfillment rate',
            isDark: isDark,
          ),
          const Divider(height: 20),
          _buildItemizedRow(
            label: 'POS Gateway',
            sub: 'Direct bank transfer fee',
            amount: -posFees,
            isCredit: false,
            icon: Icons.credit_card_rounded,
            tooltip: 'Rider mobile POS terminal transfer processing fee',
            isDark: isDark,
          ),
          if (failedAttemptsCount > 0) ...[
            const Divider(height: 20),
            _buildItemizedRow(
              label: 'Failed Attempts',
              sub: '$failedAttemptsCount attempt(s)',
              amount: -failedAttemptsVal,
              isCredit: false,
              icon: Icons.cancel_outlined,
              tooltip: 'Unfulfilled customer deliveries or returns',
              isDark: isDark,
            ),
          ],
          if (otherFees > 0) ...[
            const Divider(height: 20),
            _buildItemizedRow(
              label: 'Other Deductions',
              sub: otherComment.isNotEmpty ? otherComment : 'Accountant adjustment',
              amount: -otherFees,
              isCredit: false,
              icon: Icons.tune_rounded,
              tooltip: 'Specific adjustments made by DC Accountant',
              isDark: isDark,
            ),
          ],
          const Divider(height: 24, thickness: 1.5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Net Total',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: isOngoing
                          ? 'Estimated net accumulation live today'
                          : 'Final credited disbursement amount',
                      child: const Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                currencyFormat.format(netPayout),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemizedRow({
    required String label,
    required String sub,
    required double amount,
    required bool isCredit,
    required IconData icon,
    required String tooltip,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isCredit
                ? const Color(0xFF10B981).withValues(alpha: 0.1)
                : const Color(0xFFEF4444).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: tooltip,
                    child: const Icon(Icons.info_outline_rounded, size: 12, color: Colors.grey),
                  ),
                ],
              ),
              Text(
                sub,
                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${amount < 0 ? "-" : "+"}${currencyFormat.format(amount.abs())}',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: isCredit
                ? const Color(0xFF10B981)
                : (isDark ? Colors.grey.shade300 : const Color(0xFF334155)),
          ),
        ),
      ],
    );
  }

  Widget _buildManifestTab({
    required bool isDark,
    required LiveOngoingSettlement? ongoing,
    required ClientSettlement? settlement,
  }) {
    List<OrderEntity> orders = ongoing?.orders ?? [];
    List<String> products = ongoing?.productsSummary ?? [];

    if (orders.isEmpty && settlement != null) {
      final allOrders = ref.watch(merchantSettlementsProvider).orders;
      final settlementRef = settlement.settlementNumber.toLowerCase().trim();
      final rawOrderIds = settlement.chargesBreakdown['order_ids'];
      final orderIdSet = <String>{};
      if (rawOrderIds is List) {
        for (final id in rawOrderIds) {
          orderIdSet.add(id.toString());
        }
      }

      // 1. Direct match by chargesBreakdown['order_ids'] or remittanceReference
      List<OrderEntity> matched = allOrders.where((o) {
        if (orderIdSet.isNotEmpty && orderIdSet.contains(o.id)) return true;
        final rr = (o.remittanceReference ?? '').trim().toLowerCase();
        if (rr.isNotEmpty && rr == settlementRef) {
          return true;
        }
        return false;
      }).toList();

      // 2. If empty (e.g. settlement recorded before order_ids were saved in charges_breakdown):
      // Match delivered/reconciled/settled orders belonging to this client (and DC if matched)
      if (matched.isEmpty) {
        matched = allOrders.where((o) {
          if (settlement.clientId.isNotEmpty && o.clientId != settlement.clientId) {
            return false;
          }
          if (settlement.distributionCenterId != null &&
              settlement.distributionCenterId!.isNotEmpty &&
              o.distributionCenterId != null &&
              o.distributionCenterId!.isNotEmpty &&
              o.distributionCenterId != settlement.distributionCenterId) {
            return false;
          }
          final fs = o.financialSettlementStatus.toLowerCase();
          final isDelivered = o.status.toLowerCase() == 'delivered';
          return isDelivered &&
              (fs == 'reconciled' ||
                  fs == 'client_settled' ||
                  fs == 'settled' ||
                  fs == 'pending_remittance' ||
                  fs == 'cash_remitted_verified' ||
                  fs == 'direct_transfer_settled');
        }).take(settlement.totalOrdersCount > 0 ? settlement.totalOrdersCount : allOrders.length).toList();
      }

      // 3. Fallback: If settlement.chargesBreakdown['orders'] was saved as a list of maps
      if (matched.isEmpty && settlement.chargesBreakdown['orders'] is List) {
        final rawOrders = settlement.chargesBreakdown['orders'] as List;
        matched = rawOrders.map<OrderEntity>((raw) {
          final m = Map<String, dynamic>.from(raw as Map);
          return OrderModel(
            id: m['id']?.toString() ?? '',
            orderNumber: m['order_number']?.toString() ?? 'ORD-000',
            customerName: m['customer_name']?.toString() ?? 'Customer',
            customerPhone: '08000000000',
            deliveryState: 'Abuja (FCT)',
            deliveryCity: 'Wuse 2',
            deliveryAddress: 'Abuja, Nigeria',
            productName: m['product_name']?.toString() ?? 'Product Consignment',
            quantity: 1,
            basePrice: (m['package_price'] ?? m['total_amount'] as num?)?.toDouble() ?? 0.0,
            upsellAmount: 0.0,
            totalAmount: (m['package_price'] ?? m['total_amount'] as num?)?.toDouble() ?? 0.0,
            status: 'delivered',
            paymentType: m['payment_method']?.toString() ?? 'CASH',
            paymentStatus: 'paid',
            financialSettlementStatus: 'client_settled',
            clientId: settlement.clientId,
            createdAt: DateTime.now(),
          );
        }).toList();
      }

      orders = matched;
      products = orders
          .map((o) => o.productName)
          .where((p) => p.isNotEmpty)
          .toSet()
          .toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (products.isNotEmpty) ...[
          Text(
            'Products Highlight',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: products
                .map(
                  (p) => ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: (MediaQuery.of(context).size.width - 80).clamp(100.0, 500.0),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFFF37021)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              p,
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          'Fulfilled Orders (${orders.length})',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        if (orders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'Manifest recorded in settlement batch',
                style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 12),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final o = orders[idx];
              final isDelivered = o.status.toLowerCase() == 'delivered';
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isDelivered ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isDelivered ? Icons.check_circle_outline : Icons.error_outline,
                        color: isDelivered ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                flex: 3,
                                child: Text(
                                  o.orderNumber,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              if (o.customerName.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Flexible(
                                  flex: 2,
                                  child: Text(
                                    '• ${o.customerName}',
                                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            '${o.productName} • ${o.paymentMethod.toUpperCase()}',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currencyFormat.format(o.totalAmount),
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildReceiptTab({
    required bool isDark,
    required ClientSettlement? settlement,
  }) {
    final receiptUrl = settlement?.proofOfPaymentUrl;
    if (receiptUrl == null || receiptUrl.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey),
              const SizedBox(height: 8),
              Text('No Receipt Attached', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              Text(
                'Payment voucher will appear once submitted by DC',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.network(
                    receiptUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (ctx, child, progress) =>
                        progress == null ? child : const Center(child: CircularProgressIndicator()),
                    errorBuilder: (ctx, err, st) => const Center(
                      child: Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'zoom_receipt',
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    tooltip: 'Zoom Receipt',
                    onPressed: () => _showFullscreenReceiptDialog(context, receiptUrl),
                    child: const Icon(Icons.fullscreen_rounded),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bank Transfer Proof',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                TextButton.icon(
                  onPressed: () => _showFullscreenReceiptDialog(context, receiptUrl),
                  icon: const Icon(Icons.zoom_in_rounded, size: 16),
                  label: Text('Inspect', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankInfoCard({
    required bool isDark,
    required ClientSettlement? settlement,
  }) {
    final bankName = settlement?.destinationBankName.isNotEmpty == true
        ? settlement!.destinationBankName
        : 'Access Bank';
    final accountNum = settlement?.destinationAccountNumber.isNotEmpty == true
        ? settlement!.destinationAccountNumber
        : '••••••••89';
    final accountName = settlement?.destinationAccountName.isNotEmpty == true
        ? settlement!.destinationAccountName
        : 'Merchant Corporate Account';
    final refCode = settlement?.payoutReference ?? 'AWAITING-REF';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_balance_rounded, color: Color(0xFF3B82F6), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$bankName • $accountNum',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  accountName,
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Transfer Reference ID',
            child: InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: refCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reference ID copied'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.copy_rounded, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      refCode.length > 10 ? '${refCode.substring(0, 10)}...' : refCode,
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
