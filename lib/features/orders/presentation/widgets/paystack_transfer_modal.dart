import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/paystack_constants.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/services/paystack_service.dart';
import '../../../../core/services/paystack_web_interop.dart';

class PaystackTransferModal extends StatefulWidget {
  final String orderNumber;
  final double amount;
  final String customerEmail;
  final String customerName;
  final String? customerPhone;
  final String? orderId;
  final String? agentId;
  final VoidCallback onPaymentConfirmed;

  const PaystackTransferModal({
    super.key,
    required this.orderNumber,
    required this.amount,
    this.customerEmail = 'customer@novaexpress.ng',
    this.customerName = 'Valued Customer',
    this.customerPhone,
    this.orderId,
    this.agentId,
    required this.onPaymentConfirmed,
  });

  static Future<void> show({
    required BuildContext context,
    required String orderNumber,
    required double amount,
    String customerEmail = 'customer@novaexpress.ng',
    String customerName = 'Valued Customer',
    String? customerPhone,
    String? orderId,
    String? agentId,
    required VoidCallback onPaymentConfirmed,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaystackTransferModal(
        orderNumber: orderNumber,
        amount: amount,
        customerEmail: customerEmail,
        customerName: customerName,
        customerPhone: customerPhone,
        orderId: orderId,
        agentId: agentId,
        onPaymentConfirmed: onPaymentConfirmed,
      ),
    );
  }

  @override
  State<PaystackTransferModal> createState() => _PaystackTransferModalState();
}

class _PaystackTransferModalState extends State<PaystackTransferModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isVerifying = false;
  bool _isReceived = false;

  late String _virtualAccountNumber;
  final String _bankName = PaystackConstants.defaultBankName;
  final String _accountName = PaystackConstants.defaultAccountName;
  late String _paymentReference;

  final PaystackService _paystackService = PaystackService();

  @override
  void initState() {
    super.initState();
    _paymentReference = 'PSTK-${widget.orderNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    _virtualAccountNumber = PaystackService.generateDeterministicAccountNumber(widget.orderNumber);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initPaystackSession();
  }

  void _initPaystackSession() async {
    await _paystackService.initializeTransaction(
      amount: widget.amount,
      email: widget.customerEmail,
      reference: _paymentReference,
      metadata: {
        'type': 'direct_transfer',
        'order_number': widget.orderNumber,
        'order_id': widget.orderId,
        'agent_id': widget.agentId,
      },
    );
  }

  void _openPaystackInline() {
    if (kIsWeb) {
      final amountKobo = (widget.amount * 100).toInt();
      launchPaystackInlineJs(
        publicKey: PaystackConstants.publicKey,
        email: widget.customerEmail,
        amountKobo: amountKobo,
        reference: _paymentReference,
        metadata: {
          'type': 'direct_transfer',
          'order_number': widget.orderNumber,
          'order_id': widget.orderId,
          'agent_id': widget.agentId,
        },
        onSuccess: (String ref) async {
          if (mounted) {
            setState(() {
              _isReceived = true;
            });
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) {
              Navigator.pop(context);
              widget.onPaymentConfirmed();
            }
          }
        },
        onClose: () {},
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
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

  void _verifyPayment() async {
    setState(() => _isVerifying = true);

    final res = await _paystackService.verifyTransaction(_paymentReference);

    if (!mounted) return;

    if (res.isSuccessful) {
      // Record transaction in Supabase Paystack ledger
      await _paystackService.recordTransaction(
        reference: _paymentReference,
        amount: widget.amount,
        transactionType: 'direct_transfer',
        orderId: widget.orderId,
        deliveryAgentId: widget.agentId,
        payerEmail: widget.customerEmail,
        payerName: widget.customerName,
        channel: res.channel ?? 'dedicated_nuban',
        responseData: res.rawData,
      );

      setState(() {
        _isVerifying = false;
        _isReceived = true;
      });

      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) {
          Navigator.pop(context);
          widget.onPaymentConfirmed();
        }
      });
    } else {
      setState(() => _isVerifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFEF4444),
          content: Text(
            res.gatewayResponse ?? 'Transfer not yet detected. Please check back in a moment.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header with Paystack Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C3F7).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_rounded, color: Color(0xFF00A2D3), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paystack Direct Transfer',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Instant Bank Transfer, USSD & Card Settlement',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C3F7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'PAYSTACK',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00A2D3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Amount Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF00C3F7).withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(
                  'AMOUNT TO PAY',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.formatNaira(widget.amount),
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF38BDF8),
                  ),
                ),
                Text(
                  'Order: ${widget.orderNumber} • Ref: $_paymentReference',
                  style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Account Details Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Bank Name', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                    Text(_bankName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Account Number', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text(
                          _virtualAccountNumber,
                          style: GoogleFonts.jetBrainsMono(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                        ),
                      ],
                    ),
                    IconButton.filledTonal(
                      onPressed: () => _copyToClipboard(_virtualAccountNumber, 'Account number'),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF00C3F7).withValues(alpha: 0.15),
                        foregroundColor: const Color(0xFF00A2D3),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Account Name', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                    Expanded(
                      child: Text(
                        _accountName,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Web inline trigger button if on web
          if (kIsWeb) ...[
            OutlinedButton.icon(
              onPressed: _openPaystackInline,
              icon: const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFF00A2D3)),
              label: Text(
                'Open Paystack Interactive Checkout Popup',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF00A2D3)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF00A2D3)),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Rider Earning Protection Banner
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Company receives funds directly. ₦0.00 cash held by PDA. Your ₦2,500 delivery entitlement will be credited to My Balance upon confirmation.',
                    style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF16A34A), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ScaleTransition(
                  scale: _isVerifying ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                  child: ElevatedButton.icon(
                    onPressed: _isVerifying ? null : _verifyPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isReceived ? const Color(0xFF16A34A) : const Color(0xFF00A2D3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isVerifying
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Icon(_isReceived ? Icons.check_circle_rounded : Icons.sync_rounded, size: 18),
                    label: Text(
                      _isReceived
                          ? 'Payment Verified! 🎉'
                          : (_isVerifying ? 'Verifying with Paystack...' : 'Check Payment Status'),
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
