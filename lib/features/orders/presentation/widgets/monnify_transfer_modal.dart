import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';

final monnifyReceivedProvider = StateProvider.autoDispose<bool>((ref) => false);

class MonnifyTransferModal extends ConsumerStatefulWidget {
  final String orderNumber;
  final double amount;
  final VoidCallback onPaymentConfirmed;

  const MonnifyTransferModal({
    super.key,
    required this.orderNumber,
    required this.amount,
    required this.onPaymentConfirmed,
  });

  static Future<void> show({
    required BuildContext context,
    required String orderNumber,
    required double amount,
    required VoidCallback onPaymentConfirmed,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MonnifyTransferModal(
        orderNumber: orderNumber,
        amount: amount,
        onPaymentConfirmed: onPaymentConfirmed,
      ),
    );
  }

  @override
  ConsumerState<MonnifyTransferModal> createState() => _MonnifyTransferModalState();
}

class _MonnifyTransferModalState extends ConsumerState<MonnifyTransferModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _pollingTimer;

  late String _virtualAccountNumber;
  final String _bankName = 'Wema Bank';
  final String _accountName = 'NovaExpress / Customer Settlement';

  @override
  void initState() {
    super.initState();
    // Deterministic virtual account based on order
    final hash = widget.orderNumber.replaceAll(RegExp(r'[^0-9]'), '');
    _virtualAccountNumber = '7890${hash.padRight(6, '892401').substring(0, 6)}';

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        content: Text('$label copied to clipboard! 📋'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _triggerInstantSettlement() {
    ref.read(monnifyReceivedProvider.notifier).state = true;

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        Navigator.pop(context);
        widget.onPaymentConfirmed();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isReceived = ref.watch(monnifyReceivedProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          if (isReceived) ...[
            // Payment Received Celebration
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF16A34A),
                size: 56,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Payment Verified & Received! 🎉',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF16A34A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${CurrencyFormatter.formatNaira(widget.amount)} confirmed via Monnify Direct Transfer.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
          ] else ...[
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.account_balance_rounded,
                        color: Color(0xFF2563EB),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Direct Bank Transfer',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Powered by Monnify Virtual Accounts',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Amount Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'EXACT AMOUNT TO TRANSFER',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF93C5FD),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.formatNaira(widget.amount),
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Order #${widget.orderNumber}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Virtual Account Details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    label: 'Bank Name',
                    value: _bankName,
                    onCopy: () => _copyToClipboard(_bankName, 'Bank Name'),
                    isDark: isDark,
                  ),
                  const Divider(height: 20),
                  _buildDetailRow(
                    label: 'Account Number',
                    value: _virtualAccountNumber,
                    isHighlighted: true,
                    onCopy: () => _copyToClipboard(_virtualAccountNumber, 'Account Number'),
                    isDark: isDark,
                  ),
                  const Divider(height: 20),
                  _buildDetailRow(
                    label: 'Beneficiary',
                    value: _accountName,
                    onCopy: () => _copyToClipboard(_accountName, 'Beneficiary Name'),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Realtime Listener Indicator
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Listening for customer transfer...',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Instant Settlement Simulator / Confirmation Action
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _triggerInstantSettlement,
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: Text(
                  'Confirm Transfer Received',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required VoidCallback onCopy,
    required bool isDark,
    bool isHighlighted = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: isHighlighted ? 18 : 13,
                fontWeight: isHighlighted ? FontWeight.w900 : FontWeight.w600,
                color: isHighlighted
                    ? const Color(0xFF2563EB)
                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
                letterSpacing: isHighlighted ? 1.0 : 0.0,
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: onCopy,
          icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF2563EB)),
          tooltip: 'Copy $label',
        ),
      ],
    );
  }
}
