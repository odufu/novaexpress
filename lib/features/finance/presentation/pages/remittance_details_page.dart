import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/remittance.dart';
import '../providers/finance_provider.dart';

class RemittanceDetailsPage extends ConsumerWidget {
  final String remittanceId;

  const RemittanceDetailsPage({
    super.key,
    required this.remittanceId,
  });

  RemittanceEntity _resolveRemittance(String id, List<RemittanceEntity> stateList) {
    // 1. Check if matches any item in state list
    final match = stateList.where(
      (r) => r.id == id || r.referenceNumber.toLowerCase() == id.toLowerCase(),
    ).toList();
    if (match.isNotEmpty) return match.first;

    final cleanId = id.toUpperCase().trim();

    // 2. Resolve known predefined records with realistic audit and payment info
    if (cleanId.contains('RMT-0005') || cleanId.contains('0005')) {
      return RemittanceEntity(
        id: 'RMT-0005',
        referenceNumber: 'RMT-0005',
        amount: 25000.0,
        grossCollections: 45000.0,
        commissionDeducted: 12000.0,
        transportAllowanceDeducted: 8000.0,
        paymentMethod: 'bank_transfer',
        status: 'pending',
        notes: 'Deliveries (8 orders) • Today collection awaiting settlement',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
    } else if (cleanId.contains('RMT-0004') || cleanId.contains('0004')) {
      return RemittanceEntity(
        id: 'RMT-0004',
        referenceNumber: 'RMT-0004',
        amount: 15000.0,
        grossCollections: 35000.0,
        commissionDeducted: 10000.0,
        transportAllowanceDeducted: 10000.0,
        paymentMethod: 'bank_transfer',
        status: 'verified',
        verifiedByName: 'Wuse DC — Finance Team',
        notes: 'TXN-88372921 • Bank Transfer verified',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        verifiedAt: DateTime.now().subtract(const Duration(days: 1, hours: -1)),
      );
    } else if (cleanId.contains('RMT-0003') || cleanId.contains('0003')) {
      return RemittanceEntity(
        id: 'RMT-0003',
        referenceNumber: 'RMT-0003',
        amount: 5000.0,
        grossCollections: 15000.0,
        commissionDeducted: 5000.0,
        transportAllowanceDeducted: 5000.0,
        paymentMethod: 'ussd',
        status: 'verified',
        verifiedByName: 'Central Treasury',
        notes: 'USSD-2283742 • Reconciled',
        createdAt: DateTime(2025, 5, 2, 14, 20),
        verifiedAt: DateTime(2025, 5, 2, 14, 35),
      );
    } else if (cleanId.contains('RMT-0002') || cleanId.contains('0002')) {
      return RemittanceEntity(
        id: 'RMT-0002',
        referenceNumber: 'RMT-0002',
        amount: 10000.0,
        grossCollections: 25000.0,
        commissionDeducted: 7500.0,
        transportAllowanceDeducted: 7500.0,
        paymentMethod: 'bank_transfer',
        status: 'verified',
        verifiedByName: 'Wuse DC — Finance Team',
        notes: 'TXN-77281920 • Bank Transfer verified',
        createdAt: DateTime(2025, 5, 1, 11, 10),
        verifiedAt: DateTime(2025, 5, 1, 11, 25),
      );
    }

    // 3. Fallback dynamically generated record
    return RemittanceEntity(
      id: id,
      referenceNumber: id.startsWith('RMT-') || id.startsWith('REM-') ? id : 'RMT-$id',
      amount: 0.0,
      grossCollections: 0.0,
      commissionDeducted: 0.0,
      transportAllowanceDeducted: 0.0,
      paymentMethod: 'bank_transfer',
      status: 'pending',
      createdAt: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final financeState = ref.watch(financeProvider);

    final remit = _resolveRemittance(remittanceId, financeState.remittances);

    final gross = remit.grossCollections > 0 ? remit.grossCollections : (remit.amount * 1.5);
    final comm = remit.commissionDeducted > 0 ? remit.commissionDeducted : (gross * 0.25);
    final transport = remit.transportAllowanceDeducted > 0 ? remit.transportAllowanceDeducted : (gross * 0.2);

    final isPending = remit.isPending;
    final isApproved = remit.isVerified;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remittance Details',
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              remit.referenceNumber,
              style: GoogleFonts.jetBrainsMono(
                color: const Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share_outlined, color: theme.colorScheme.onSurface, size: 20),
            tooltip: 'Share Receipt',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sharing ${remit.referenceNumber} summary...')),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HERO AMOUNT & STATUS CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Status Badge Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: isApproved
                          ? const Color(0xFFDCFCE7)
                          : (isPending ? const Color(0xFFFFF7ED) : const Color(0xFFFFE4E6)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isApproved
                            ? const Color(0xFF86EFAC)
                            : (isPending ? const Color(0xFFFED7AA) : const Color(0xFFFECDD3)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isApproved
                              ? Icons.check_circle_rounded
                              : (isPending ? Icons.access_time_rounded : Icons.error_rounded),
                          size: 14,
                          color: isApproved
                              ? const Color(0xFF16A34A)
                              : (isPending ? const Color(0xFFEA580C) : const Color(0xFFE11D48)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isApproved ? 'APPROVED' : (isPending ? 'PENDING' : 'DISPUTED'),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isApproved
                                ? const Color(0xFF16A34A)
                                : (isPending ? const Color(0xFFEA580C) : const Color(0xFFE11D48)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    isPending ? 'AMOUNT TO REMIT' : 'SETTLED REMITTANCE AMOUNT',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),

                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      CurrencyFormatter.formatNaira(remit.amount),
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: isPending
                            ? const Color(0xFFEA580C)
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  Text(
                    '${remit.paymentMethodDisplay} • NovaExpress Main Account',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. CONTEXTUAL STATUS BANNER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isApproved
                    ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFF0FDF4))
                    : (isPending
                        ? (isDark ? const Color(0xFF7C2D12).withValues(alpha: 0.3) : const Color(0xFFFFF7ED))
                        : (isDark ? const Color(0xFF881337).withValues(alpha: 0.3) : const Color(0xFFFFF1F2))),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isApproved
                      ? const Color(0xFF10B981)
                      : (isPending ? const Color(0xFFF97316) : const Color(0xFFF43F5E)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isApproved
                        ? Icons.verified_outlined
                        : (isPending ? Icons.pending_actions_rounded : Icons.warning_amber_rounded),
                    color: isApproved
                        ? const Color(0xFF16A34A)
                        : (isPending ? const Color(0xFFEA580C) : const Color(0xFFE11D48)),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isApproved
                              ? 'Reconciliation Verified'
                              : (isPending ? 'Action Required: Settle Cash' : 'Discrepancy Reported'),
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isApproved
                                ? const Color(0xFF16A34A)
                                : (isPending ? const Color(0xFFEA580C) : const Color(0xFFE11D48)),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isApproved
                              ? 'This collection was reconciled and verified by ${remit.verifiedByName ?? "Finance Operations"}.'
                              : (isPending
                                  ? 'Cash awaiting bank handover. Please remit before 6:00 PM to maintain account limits.'
                                  : 'Discrepancy flagged during DC count. Please contact DC finance cashier.'),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. SETTLEMENT RECONCILIATION BREAKDOWN MATRIX
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SETTLEMENT RECONCILIATION',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Customer Collections (POD)', CurrencyFormatter.formatNaira(gross), isDark),
                  const Divider(height: 14),
                  _buildDetailRow('Less: Delivery Commission', '-${CurrencyFormatter.formatNaira(comm)}', isDark, valColor: const Color(0xFF16A34A)),
                  const Divider(height: 14),
                  _buildDetailRow('Less: Transport Allowance', '-${CurrencyFormatter.formatNaira(transport)}', isDark, valColor: const Color(0xFF2563EB)),
                  const Divider(height: 14),
                  _buildDetailRow(
                    isPending ? 'Expected Handover Amount' : 'Net Handover Amount',
                    CurrencyFormatter.formatNaira(remit.amount),
                    isDark,
                    isBold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. AUDIT & VERIFICATION TRAIL
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AUDIT & TRANSACTION DETAILS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Remitted To', 'NovaExpress Main Account (Zenith Bank)', isDark),
                  const Divider(height: 14),
                  _buildDetailRow('Payment Method', remit.paymentMethodDisplay, isDark),
                  const Divider(height: 14),
                  _buildDetailRow('Transaction Reference', remit.notes != null && remit.notes!.contains('TXN-') ? remit.notes!.split('•').first.trim() : (remit.notes ?? remit.referenceNumber), isDark),
                  const Divider(height: 14),
                  _buildDetailRow('Timestamp', '${remit.createdAt.day} Aug 2026 • 10:15 AM', isDark),
                  const Divider(height: 14),
                  _buildDetailRow('Reconciled By', isApproved ? (remit.verifiedByName ?? 'Wuse DC — Operations') : 'Pending Operations Audit', isDark),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 5. DYNAMIC ACTIONS BASED ON REMITTANCE STATUS
            if (isPending) ...[
              // Action buttons for Pending Remittance
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => context.push('/cash/remit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Remit ${CurrencyFormatter.formatNaira(remit.amount)} Now',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface,
                    side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Back to Remittances'),
                ),
              ),
            ] else if (isApproved) ...[
              // Action buttons for Approved / Verified Remittance
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Downloading statement for ${remit.referenceNumber}...')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    'Download Statement (PDF)',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Receipt sent to your registered email.')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface,
                    side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.mail_outline_rounded, size: 18),
                  label: const Text('Email Receipt Copy'),
                ),
              ),
            ] else ...[
              // Action buttons for Disputed / Rejected Remittance
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/cash/remit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: Text(
                    'Re-submit Remittance Proof',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Calling DC Finance Support at +234-800-NOVACASH...')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface,
                    side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                  label: const Text('Contact DC Finance Support'),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String val, bool isDark, {bool isBold = false, Color? valColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
        Flexible(
          child: Text(
            val,
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valColor ?? (isBold ? AppColors.orange : (isDark ? Colors.white : const Color(0xFF1E293B))),
            ),
          ),
        ),
      ],
    );
  }
}
