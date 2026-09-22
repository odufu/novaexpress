import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../domain/entities/client_settlement.dart';
import '../providers/client_portal_provider.dart';

/// Interactive Universal Settlement Details & Full Receipt Modal
/// Accessible across all faces (Merchant Portal, DC Console, Finance/Admin).
/// Displays full-resolution embedded receipt preview with pan/zoom/lightbox,
/// comprehensive timestamps (execution time, period start/end, creation),
/// granular clearinghouse fee deductions, destination bank audit, and sign-off actions.
class ClientSettlementDetailModal extends ConsumerStatefulWidget {
  final ClientSettlement settlement;
  final bool isDcView;
  final String? clientName;
  final String? clientLogo;

  const ClientSettlementDetailModal({
    super.key,
    required this.settlement,
    this.isDcView = false,
    this.clientName,
    this.clientLogo,
  });

  static Future<void> show({
    required BuildContext context,
    required ClientSettlement settlement,
    bool isDcView = false,
    String? clientName,
    String? clientLogo,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ClientSettlementDetailModal(
        settlement: settlement,
        isDcView: isDcView,
        clientName: clientName,
        clientLogo: clientLogo,
      ),
    );
  }

  @override
  ConsumerState<ClientSettlementDetailModal> createState() => _ClientSettlementDetailModalState();
}

class _ClientSettlementDetailModalState extends ConsumerState<ClientSettlementDetailModal> {
  bool _isApproving = false;
  late ClientSettlement _settlement;

  @override
  void initState() {
    super.initState();
    _settlement = widget.settlement;
  }

  void _showFullscreenReceiptDialog(String url) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960, maxHeight: 850),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF0D9488), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transfer Receipt • ${_settlement.settlementNumber}',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              'Interactive High-Resolution Inspection • Pinch or scroll to zoom',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Container(
                    color: isDark ? const Color(0xFF020617) : const Color(0xFFF1F5F9),
                    child: InteractiveViewer(
                      panEnabled: true,
                      boundaryMargin: const EdgeInsets.all(40),
                      minScale: 0.5,
                      maxScale: 5.0,
                      child: Center(
                        child: _buildReceiptImage(url),
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pinch / Drag to zoom and pan',
                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: url));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Color(0xFF10B981),
                                  content: Text('Receipt link copied to clipboard!'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 15),
                            label: const Text('Copy URL'),
                          ),
                          if (url.startsWith('http')) ...[
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                              icon: const Icon(Icons.open_in_new_rounded, size: 15),
                              label: const Text('Open External'),
                            ),
                          ],
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D9488),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReceiptImage(String url) {
    if (url.startsWith('data:image')) {
      try {
        final bytes = Uri.parse(url).data!.contentAsBytes();
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildReceiptLoadError(),
        );
      } catch (e) {
        return _buildReceiptLoadError();
      }
    }

    return Image.network(
      url,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(color: Color(0xFF0D9488)),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _buildReceiptLoadError(),
    );
  }

  Widget _buildReceiptLoadError() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_rounded, color: Color(0xFFEF4444), size: 48),
          const SizedBox(height: 10),
          Text(
            'Unable to load receipt preview',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'The file format may require an external viewer or the storage resource is restricted.',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _handleMerchantApprove() async {
    final currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 2);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Confirm Settlement Receipt'),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to approve and confirm this settlement?',
                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Net Payout: ${currency.format(_settlement.netPayoutAmount)}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF0F766E)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Credited To: ${_settlement.destinationBankName} (${_settlement.destinationAccountNumber})',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0F766E)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'By approving, you confirm that the funds have been credited to your bank account as evidenced by the attached transfer receipt.',
                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Confirm & Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isApproving = true);
    try {
      final success = await ref.read(clientPortalProvider.notifier).approveSettlement(_settlement.id);
      if (success) {
        setState(() {
          _settlement = _settlement.copyWith(status: 'completed');
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              content: Text('Settlement ${_settlement.settlementNumber} approved & confirmed successfully!'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFFEF4444),
              content: Text('Failed to record settlement approval. Please check your connection.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Error approving settlement: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == ThemeMode.dark ||
        (ref.watch(themeProvider) == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 2);

    final isRemitted = _settlement.isRemitted;
    final isCompleted = _settlement.isCompleted;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 880),
        child: Column(
          children: [
            // Top Header Bar
            _buildModalHeader(context, isDark, isRemitted, isCompleted),
            const Divider(height: 1),

            // Scrollable Content Pane (Responsive Layout)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 760;

                  if (isWide) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Pane: Financial Details, Timelines & Bank Info
                          Expanded(
                            flex: 5,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(right: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildStatusAlertBanner(isRemitted, isCompleted),
                                  const SizedBox(height: 16),
                                  _buildHeroPayoutCard(isDark, currency),
                                  const SizedBox(height: 16),
                                  _buildAuditTimelineCard(isDark),
                                  const SizedBox(height: 16),
                                  _buildClearinghouseBreakdown(isDark, currency),
                                  if (_settlement.notes != null && _settlement.notes!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    _buildNotesCard(isDark),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          // Vertical Divider
                          Container(
                            width: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),

                          // Right Pane: Full Uploaded Receipt Preview Frame
                          Expanded(
                            flex: 5,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(left: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildReceiptSectionHeader(isDark),
                                  const SizedBox(height: 12),
                                  _buildFullReceiptViewer(isDark),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Compact / Mobile Layout: Vertically stacked
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatusAlertBanner(isRemitted, isCompleted),
                        const SizedBox(height: 16),
                        _buildHeroPayoutCard(isDark, currency),
                        const SizedBox(height: 16),
                        _buildReceiptSectionHeader(isDark),
                        const SizedBox(height: 10),
                        _buildFullReceiptViewer(isDark),
                        const SizedBox(height: 16),
                        _buildAuditTimelineCard(isDark),
                        const SizedBox(height: 16),
                        _buildClearinghouseBreakdown(isDark, currency),
                        if (_settlement.notes != null && _settlement.notes!.trim().isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildNotesCard(isDark),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Action Bar
            const Divider(height: 1),
            _buildModalFooter(context, currency, isRemitted),
          ],
        ),
      ),
    );
  }

  // --- Modal Header ---
  Widget _buildModalHeader(BuildContext context, bool isDark, bool isRemitted, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Settlement Batch Statement',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(isRemitted, isCompleted),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_settlement.settlementNumber}${widget.clientName != null ? " • ${widget.clientName}" : ""} • Disbursed ${DateFormat('dd MMM yyyy, hh:mm a').format(_settlement.settledAt)}',
                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close Modal',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // --- Status Alert Banner ---
  Widget _buildStatusAlertBanner(bool isRemitted, bool isCompleted) {
    if (isRemitted) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.pending_actions_rounded, color: Color(0xFFD97706), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isDcView
                        ? 'Remitted by Distribution Center — Pending Merchant Acknowledgment'
                        : 'Settlement Disbursed — Action Required: Verify Receipt & Approve Payout',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFB45309)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.isDcView
                        ? 'Funds were remitted to the merchant bank account with transfer receipt attached. Ledger finalizes once merchant acknowledges in portal.'
                        : 'Central DC has disbursed your net earnings. Inspect the attached transfer receipt on the right, then tap "Approve & Confirm Settlement".',
                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF92400E)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (isCompleted) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Settlement Reconciled, Verified & Acknowledged by Merchant.',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF065F46)),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // --- Hero Net Payout Card ---
  Widget _buildHeroPayoutCard(bool isDark, NumberFormat currency) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [const Color(0xFF021B3A), const Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
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
              Text(
                'NET DISBURSED PAYOUT',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.5),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_settlement.totalOrdersCount} Delivered Orders Cleared',
                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            currency.format(_settlement.netPayoutAmount),
            style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Colors.white24),
          const SizedBox(height: 12),

          // Destination Bank Info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance_rounded, color: Color(0xFF2DD4BF), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_settlement.destinationBankName.isNotEmpty ? _settlement.destinationBankName : "Bank Disbursement"} • ${_settlement.destinationAccountNumber.isNotEmpty ? _settlement.destinationAccountNumber : "Direct Account"}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                    Text(
                      'Beneficiary: ${_settlement.destinationAccountName.isNotEmpty ? _settlement.destinationAccountName : (widget.clientName ?? "Merchant Account")}',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFCBD5E1)),
                    ),
                  ],
                ),
              ),
              if (_settlement.destinationAccountNumber.isNotEmpty)
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _settlement.destinationAccountNumber));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Account number copied to clipboard!')),
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Copy', style: TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Audit Timelines & Timestamps Card ---
  Widget _buildAuditTimelineCard(bool isDark) {
    final dateFormatFull = DateFormat('EEEE, dd MMMM yyyy');
    final timeFormatFull = DateFormat('hh:mm:ss a');
    final rangeFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_filled_rounded, color: Color(0xFF0D9488), size: 16),
              const SizedBox(width: 8),
              Text(
                'DATE, TIME & CLEARING AUDIT',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTimelineRow(
            icon: Icons.payments_outlined,
            title: 'Settlement Disbursement Executed',
            date: dateFormatFull.format(_settlement.settledAt),
            time: timeFormatFull.format(_settlement.settledAt),
            isPrimary: true,
          ),
          const Divider(height: 16),
          _buildTimelineRow(
            icon: Icons.date_range_rounded,
            title: 'Reconciliation Accounting Period',
            date: '${rangeFormat.format(_settlement.periodStart)} —',
            time: rangeFormat.format(_settlement.periodEnd),
          ),
          const Divider(height: 16),
          _buildTimelineRow(
            icon: Icons.receipt_rounded,
            title: 'Batch Ledger Created At',
            date: dateFormatFull.format(_settlement.createdAt),
            time: timeFormatFull.format(_settlement.createdAt),
          ),
          if (_settlement.payoutReference != null && _settlement.payoutReference!.trim().isNotEmpty) ...[
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bank Payout Ref',
                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _settlement.payoutReference!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bank Reference copied to clipboard!')),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _settlement.payoutReference!,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0D9488)),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF0D9488)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineRow({
    required IconData icon,
    required String title,
    required String date,
    required String time,
    bool isPrimary = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: isPrimary ? const Color(0xFF0D9488) : const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 2),
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    date,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isPrimary ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: (isPrimary ? const Color(0xFF0D9488) : const Color(0xFF64748B)).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      time,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isPrimary ? const Color(0xFF0D9488) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Clearinghouse Breakdown ---
  Widget _buildClearinghouseBreakdown(bool isDark, NumberFormat currency) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CLEARINGHOUSE FINANCIAL AUDIT',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          _buildDetailRow('Gross Cash on Delivery (COD) Collected', currency.format(_settlement.grossCollections), isPositive: true),
          const Divider(height: 12),
          _buildDetailRow('Logistics & Shipping Fees', '- ${currency.format(_settlement.logisticsFeesDeducted)}', isNegative: true),
          _buildDetailRow('Platform Clearinghouse Commission', '- ${currency.format(_settlement.platformFeesDeducted)}', isNegative: true),
          _buildDetailRow('Payment Gateway Charges (POS / Card)', '- ${currency.format(_settlement.gatewayFeesDeducted)}', isNegative: true),
          if (_settlement.failedAttemptFeesDeducted > 0)
            _buildDetailRow('Return to Origin (RTO) Surcharges', '- ${currency.format(_settlement.failedAttemptFeesDeducted)}', isNegative: true),
          if (_settlement.otherChargesDeducted > 0)
            _buildDetailRow('Auxiliary / Warehousing Fees', '- ${currency.format(_settlement.otherChargesDeducted)}', isNegative: true),

          // Custom JSONB Deductions if present
          if (_settlement.chargesBreakdown.isNotEmpty) ...[
            const Divider(height: 12),
            ..._settlement.chargesBreakdown.entries.map((entry) {
              final val = entry.value is num ? (entry.value as num).toDouble() : double.tryParse(entry.value.toString()) ?? 0.0;
              final cleanKey = entry.key.replaceAll('_', ' ').toUpperCase();
              return _buildDetailRow(cleanKey, '- ${currency.format(val)}', isNegative: true);
            }),
          ],

          const Divider(height: 16),
          _buildDetailRow('Net Disbursed to Bank', currency.format(_settlement.netPayoutAmount), isBold: true, isHighlight: true),
        ],
      ),
    );
  }

  // --- Operational Notes ---
  Widget _buildNotesCard(bool isDark) {
    return Container(
      width: double.infinity,
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
            children: [
              const Icon(Icons.notes_rounded, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                'Operational Remarks / Notes',
                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _settlement.notes!,
            style: GoogleFonts.inter(fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  // --- Right Pane: Full Uploaded Receipt Preview ---
  Widget _buildReceiptSectionHeader(bool isDark) {
    final hasReceipt = _settlement.hasReceipt;
    final url = _settlement.proofOfPaymentUrl ?? '';
    final isPdf = url.toLowerCase().contains('.pdf');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.receipt_rounded, color: Color(0xFF0D9488), size: 18),
            const SizedBox(width: 8),
            Text(
              'UPLOADED TRANSFER RECEIPT',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: hasReceipt
                ? const Color(0xFF0D9488).withValues(alpha: 0.12)
                : const Color(0xFF64748B).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            hasReceipt ? (isPdf ? 'PDF DOCUMENT ATTACHED' : 'FULL IMAGE PROOF') : 'NO DIGITAL RECEIPT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: hasReceipt ? const Color(0xFF0D9488) : const Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFullReceiptViewer(bool isDark) {
    final hasReceipt = _settlement.hasReceipt;

    if (!hasReceipt) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF64748B).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_outlined, size: 40, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            Text(
              'Direct Remittance / Physical Voucher',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'No digital PDF or image receipt file was attached for this settlement batch.\nDisbursement was reconciled directly at the Central Distribution Center.',
              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B), height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final url = _settlement.proofOfPaymentUrl!;
    final isPdf = url.toLowerCase().contains('.pdf');

    if (isPdf) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEF4444), size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              'Transfer Receipt Document (PDF)',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'Attached electronic settlement payment receipt voucher.',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Open External PDF Reader'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PDF URL copied to clipboard!')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy PDF Link'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Full Interactive Image Viewer Frame
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF020617) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: Column(
        children: [
          // Receipt Frame Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.zoom_in_rounded, size: 16, color: Color(0xFF0D9488)),
                    const SizedBox(width: 6),
                    Text(
                      'Pinch / Scroll to Zoom',
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.fullscreen_rounded, size: 20),
                      tooltip: 'View High-Res Lightbox',
                      onPressed: () => _showFullscreenReceiptDialog(url),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Copy Receipt URL',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: url));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Receipt image URL copied!')),
                        );
                      },
                    ),
                    if (url.startsWith('http'))
                      IconButton(
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        tooltip: 'Open in Browser',
                        onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Embedded Full Image Display
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
            child: Container(
              constraints: const BoxConstraints(minHeight: 280, maxHeight: 520),
              width: double.infinity,
              color: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
              child: InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: _buildReceiptImage(url),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Footer Bar ---
  Widget _buildModalFooter(BuildContext context, NumberFormat currency, bool isRemitted) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            onPressed: () {
              final receiptText = '''
======================================================
NOVEXPS LOGISTICS & E-COMMERCE CLEARINGHOUSE
MERCHANT SETTLEMENT STATEMENT: ${_settlement.settlementNumber}
======================================================
Client / Merchant    : ${widget.clientName ?? _settlement.destinationAccountName}
Settlement Status    : ${_settlement.status.toUpperCase()}
Execution Timestamp  : ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_settlement.settledAt)}
Reconciliation Period: ${DateFormat('yyyy-MM-dd').format(_settlement.periodStart)} to ${DateFormat('yyyy-MM-dd').format(_settlement.periodEnd)}
Total Orders Cleared : ${_settlement.totalOrdersCount}
------------------------------------------------------
Gross COD Collected  : ${currency.format(_settlement.grossCollections)}
Logistics Fees       : - ${currency.format(_settlement.logisticsFeesDeducted)}
Platform Commission  : - ${currency.format(_settlement.platformFeesDeducted)}
Gateway Processing   : - ${currency.format(_settlement.gatewayFeesDeducted)}
Auxiliary Charges    : - ${currency.format(_settlement.otherChargesDeducted)}
------------------------------------------------------
NET DISBURSED PAYOUT : ${currency.format(_settlement.netPayoutAmount)}
Destination Bank     : ${_settlement.destinationBankName}
Account Number       : ${_settlement.destinationAccountNumber}
Account Name         : ${_settlement.destinationAccountName}
Payout Reference     : ${_settlement.payoutReference ?? "DIRECT-DC-TRANSFER"}
Receipt URL          : ${_settlement.proofOfPaymentUrl ?? "N/A"}
======================================================
''';
              Clipboard.setData(ClipboardData(text: receiptText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Color(0xFF10B981),
                  content: Text('Settlement statement voucher copied to clipboard!'),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Statement'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (!widget.isDcView && isRemitted) ...[
            ElevatedButton.icon(
              onPressed: _isApproving ? null : _handleMerchantApprove,
              icon: _isApproving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_rounded, size: 18),
              label: Text(
                _isApproving ? 'Approving...' : 'Approve & Confirm Settlement Payout',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Close'),
            ),
          ],
        ],
      ),
    );
  }

  // --- Badges and Row Helpers ---
  Widget _buildStatusBadge(bool isRemitted, bool isCompleted) {
    if (isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Approved & Acknowledged',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
        ),
      );
    }
    if (isRemitted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Disbursed • Pending Sign-off',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0284C7).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _settlement.status.toUpperCase(),
        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isPositive = false, bool isNegative = false, bool isBold = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: isBold ? 13.5 : 12.5, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isBold ? 15 : 12.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isHighlight
                  ? const Color(0xFF0D9488)
                  : isNegative
                      ? const Color(0xFFEF4444)
                      : null,
            ),
          ),
        ],
      ),
    );
  }
}
