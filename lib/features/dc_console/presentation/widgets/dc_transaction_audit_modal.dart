import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/helpers/formatters.dart';
import '../../domain/entities/dc_transaction_record.dart';

class DCTransactionAuditModal {
  static void show(BuildContext context, DCTransactionRecord txn, {required bool isDark}) {
    final isPstk = txn.isPaystack;
    final isPartial = txn.isPartialRemittance;
    final netCompanyRevenue = (txn.amount - txn.totalRiderEntitlement).clamp(0.0, txn.amount);
    final timestampFormatted = DateFormat('dd MMMM yyyy • hh:mm:ss a').format(txn.createdAt);

    showDialog(
      context: context,
      builder: (ctx) {
        final screenHeight = MediaQuery.of(ctx).size.height;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 580,
              maxHeight: screenHeight * 0.92,
            ),
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Top Header & Reference
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00A2D3).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isPstk ? Icons.bolt_rounded : Icons.receipt_long_rounded,
                          color: const Color(0xFF00A2D3),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transaction Forensic Receipt',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'NovaXpress Distribution Center Financial Ledger',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 2. HERO AMOUNT & STATUS CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPartial
                                ? const Color(0xFFFFF7ED)
                                : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isPartial ? const Color(0xFFFDBA74) : const Color(0xFF86EFAC),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPartial
                                    ? Icons.published_with_changes_rounded
                                    : (txn.isVerified ? Icons.check_circle_rounded : Icons.pending_rounded),
                                size: 14,
                                color: isPartial
                                    ? const Color(0xFFEA580C)
                                    : (txn.isVerified ? const Color(0xFF16A34A) : const Color(0xFFD97706)),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                txn.isRemittance
                                    ? (isPartial ? 'PARTIAL REMITTANCE' : 'COMPLETE REMITTANCE')
                                    : (txn.isVerified ? 'SUCCESSFUL / RECONCILED' : 'COLLECTED'),
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isPartial
                                      ? const Color(0xFFEA580C)
                                      : (txn.isVerified ? const Color(0xFF15803D) : const Color(0xFF2563EB)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'TOTAL SETTLED AMOUNT',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.formatNaira(txn.amount),
                          style: GoogleFonts.inter(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Reconciled via ${txn.channel} • Credited to DC Financial Pool',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 3. SETTLEMENT CONFIRMATION BANNER
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isPartial
                          ? (isDark ? const Color(0xFF7C2D12).withValues(alpha: 0.3) : const Color(0xFFFFF7ED))
                          : (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFF0FDF4)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isPartial ? const Color(0xFFF97316) : const Color(0xFF10B981)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isPartial ? Icons.published_with_changes_rounded : Icons.verified_rounded,
                          color: isPartial ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPartial
                                    ? 'Partial Remittance Reconciled'
                                    : (txn.isRemittance ? 'Complete Remittance Verified' : 'Settlement Verified & Reconciled'),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isPartial ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                                ),
                              ),
                              Text(
                                isPartial
                                    ? 'This remittance was recorded as a partial payment of ${CurrencyFormatter.formatNaira(txn.amount)}. Remaining shortage balance is audited in rider ledger.'
                                    : 'This transaction has been authenticated by Settlement Engine & booked into DC treasury.',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 4. FINANCIAL LEDGER BREAKDOWN MATRIX
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FINANCIAL LEDGER BREAKDOWN',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildReceiptRow('Gross Order Collections', CurrencyFormatter.formatNaira(txn.amount), isBold: true),
                        const Divider(height: 12),
                        _buildReceiptRow('Less: Delivery Commission', '-${CurrencyFormatter.formatNaira(txn.commission)}', color: const Color(0xFF16A34A)),
                        const Divider(height: 12),
                        _buildReceiptRow('Less: Transport Allowance', '-${CurrencyFormatter.formatNaira(txn.transportAllowance)}', color: const Color(0xFF2563EB)),
                        const Divider(height: 12),
                        _buildReceiptRow('Total Rider Entitlement', CurrencyFormatter.formatNaira(txn.totalRiderEntitlement), isBold: true, color: const Color(0xFF10B981)),
                        const Divider(height: 12),
                        _buildReceiptRow('Net Company Remittance / Revenue', CurrencyFormatter.formatNaira(netCompanyRevenue), isBold: true, color: const Color(0xFF2563EB)),
                        if (isPartial && txn.remainingShortage > 0) ...[
                          const Divider(height: 12),
                          _buildReceiptRow('Remaining Shortage Liability', '-${CurrencyFormatter.formatNaira(txn.remainingShortage)}', isBold: true, color: const Color(0xFFEA580C)),
                          if (txn.discrepancyReason != null && txn.discrepancyReason!.isNotEmpty) ...[
                            const Divider(height: 12),
                            _buildReceiptRow('Variance Reason', txn.discrepancyReason!, color: const Color(0xFFF97316)),
                          ],
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 5. AUDIT & FORENSIC METADATA
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AUDIT & FORENSIC METADATA',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildReceiptRow('Order Number', txn.orderNumber != null ? '#${txn.orderNumber}' : 'Direct Gateway Collection'),
                        const Divider(height: 12),
                        _buildReceiptRow('Product Details', txn.productName ?? 'General Logistics POD'),
                        if (txn.customerName != null) ...[
                          const Divider(height: 12),
                          _buildReceiptRow('Customer', '${txn.customerName!} (${txn.customerPhone ?? "N/A"})'),
                        ],
                        if (txn.deliveryLocation != null) ...[
                          const Divider(height: 12),
                          _buildReceiptRow('Delivery Destination', txn.deliveryLocation!),
                        ],
                        const Divider(height: 12),
                        _buildReceiptRow('Assigned Rider', '${txn.riderName} (${txn.riderCode})'),
                        const Divider(height: 12),
                        _buildReceiptRow('Payment Method', txn.channel),
                        const Divider(height: 12),
                        _buildCopyableReceiptRow(context, 'Transaction Reference', txn.transactionCode),
                        if (txn.gatewayReference != null && txn.gatewayReference != txn.transactionCode) ...[
                          const Divider(height: 12),
                          _buildCopyableReceiptRow(context, 'Gateway Auth Ref', txn.gatewayReference!),
                        ],
                        const Divider(height: 12),
                        _buildReceiptRow('Gateway Status', 'APPROVED / SUCCESSFUL (200 OK)', isBold: true, color: const Color(0xFF16A34A)),
                        const Divider(height: 12),
                        _buildReceiptRow('Settlement Timestamp', timestampFormatted),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 6. ACTION BUTTONS
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final receiptText = '''
========================================
NOVAXPRESS DC TRANSACTION RECEIPT
========================================
Transaction Code: ${txn.transactionCode}
Order: #${txn.orderNumber ?? "N/A"}
Amount: ${CurrencyFormatter.formatNaira(txn.amount)}
Rider Entitlement: ${CurrencyFormatter.formatNaira(txn.totalRiderEntitlement)}
Net Company Revenue: ${CurrencyFormatter.formatNaira(netCompanyRevenue)}
Channel: ${txn.channel}
Rider: ${txn.riderName} (${txn.riderCode})
Customer: ${txn.customerName ?? "N/A"}
Timestamp: $timestampFormatted
Status: ${isPartial ? "PARTIAL REMITTANCE" : (txn.isRemittance ? "COMPLETE REMITTANCE" : "APPROVED / SUCCESSFUL (200 OK)")}
========================================
NovaXpress Distribution Center Audit
''';
                            Clipboard.setData(ClipboardData(text: receiptText));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                                content: Row(
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Expanded(child: Text('Forensic receipt summary copied! Ready to share.')),
                                  ],
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.share_rounded, size: 16),
                          label: Text('Share Receipt', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Close Audit', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildReceiptRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildCopyableReceiptRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
          ),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied $label: $value'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF2563EB)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

